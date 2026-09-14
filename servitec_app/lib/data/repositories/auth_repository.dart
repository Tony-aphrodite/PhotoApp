import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/facturapi_ref.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/analytics_service.dart';
import '../../core/utils/fiscal_status.dart';
import '../../core/utils/notification_service.dart';
import '../../core/utils/registration_validators.dart';

/// The phone number is already claimed by another account.
class PhoneAlreadyInUseException implements Exception {
  const PhoneAlreadyInUseException();
}

/// The phone number is not a valid 10-digit Mexican number.
class InvalidPhoneException implements Exception {
  const InvalidPhoneException();
}

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) throw Exception('Login failed');
    final profile = await getUserProfile(user.uid);
    // Analytics: identify user + role for cohort/funnel analysis.
    await AnalyticsService.setUserId(user.uid);
    await AnalyticsService.setRole(profile.rol);
    if (profile.isTechnician && profile.facturapi != null) {
      await AnalyticsService.setTechnicianStatus(profile.facturapi!.status);
    }
    await AnalyticsService.logLogin();
    // Persist FCM token so Cloud Functions can send push notifications to
    // this user (chat messages, service assignments, payments, etc.).
    await NotificationService().saveTokenToUser(user.uid);
    return profile;
  }

  Future<UserModel> registerClient({
    required String email,
    required String password,
    required String nombre,
    required String apellido,
    required String telefono,
  }) async {
    final userModel = await _createAccount(
      email: email,
      password: password,
      telefono: telefono,
      buildProfile: (uid, phone, now) => UserModel(
        uid: uid,
        email: email,
        nombre: nombre,
        apellido: apellido,
        telefono: phone,
        rol: AppConstants.roleClient,
        createdAt: now,
      ),
    );
    final user = _auth.currentUser!;

    // Analytics: sign_up event + identify.
    await AnalyticsService.setUserId(user.uid);
    await AnalyticsService.setRole(AppConstants.roleClient);
    await AnalyticsService.logSignUp(role: AppConstants.roleClient);
    await NotificationService().saveTokenToUser(user.uid);

    return userModel;
  }

  Future<UserModel> registerTechnician({
    required String email,
    required String password,
    required String nombre,
    required String apellido,
    required String telefono,
    required List<String> especialidades,
    Map<String, double>? tarifas,
  }) async {
    final userModel = await _createAccount(
      email: email,
      password: password,
      telefono: telefono,
      buildProfile: (uid, phone, now) => UserModel(
        uid: uid,
        email: email,
        nombre: nombre,
        apellido: apellido,
        telefono: phone,
        rol: AppConstants.roleTechnician,
        createdAt: now,
        especialidades: especialidades,
        calificacionPromedio: 0.0,
        totalResenas: 0,
        tarifasPorEspecialidad: tarifas ?? {},
        disponible: true,
        serviciosCompletados: 0,
        // Fiscal defaults for a new técnico: grace period starts now.
        facturapi: FiscalStatus.initial(now: now),
        graciaExpiraAt: FiscalStatus.initialGraceExpiry(now: now),
      ),
    );
    final user = _auth.currentUser!;

    // Analytics: sign_up event + identify + initial technician_status.
    await AnalyticsService.setUserId(user.uid);
    await AnalyticsService.setRole(AppConstants.roleTechnician);
    await AnalyticsService.setTechnicianStatus(
      userModel.facturapi?.status ?? FacturapiRef.statusGracePeriod,
    );
    await AnalyticsService.logSignUp(role: AppConstants.roleTechnician);
    await NotificationService().saveTokenToUser(user.uid);

    return userModel;
  }

  /// Creates the Auth user, then writes the profile and claims the phone
  /// number in one atomic batch.
  ///
  /// The claim is a `telefonos/{10 digits}` document. firestore.rules only let
  /// it be *created*, so if another account already holds the number the
  /// write lands as an update, is refused, and the whole batch — profile
  /// included — is rejected. That makes the uniqueness check race-free and
  /// impossible to skip from a modified client, without ever letting anyone
  /// read who owns which number.
  ///
  /// If the batch fails for any reason the Auth user is deleted again. Before,
  /// a failed profile write left an account that could sign in but had no
  /// profile, and its email could never be registered again.
  Future<UserModel> _createAccount({
    required String email,
    required String password,
    required String telefono,
    required UserModel Function(String uid, String phone, DateTime now)
        buildProfile,
  }) async {
    // The form validates first, so this only trips for a caller that skipped it.
    final phone = RegistrationValidators.normalizeMxPhone(telefono);
    if (phone == null) throw const InvalidPhoneException();

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) throw Exception('Registration failed');

    final userModel = buildProfile(user.uid, phone, DateTime.now());
    final batch = _firestore.batch()
      ..set(
        _firestore.collection(AppConstants.usersCollection).doc(user.uid),
        userModel.toFirestore(),
      )
      ..set(
        _firestore.collection(AppConstants.phoneClaimsCollection).doc(phone),
        {'uid': user.uid, 'createdAt': FieldValue.serverTimestamp()},
      );

    try {
      await batch.commit();
    } catch (e) {
      try {
        await user.delete();
      } catch (_) {
        // Deleting a user seconds after creating it does not need a fresh
        // login, so this should not fail. If it does, signing out at least
        // keeps the half-made session from being used.
        await _auth.signOut();
      }
      // A profile write refused by rules is, in practice, the phone claim:
      // the users/{uid} create rule is otherwise satisfied by construction.
      if (e is FirebaseException && e.code == 'permission-denied') {
        throw const PhoneAlreadyInUseException();
      }
      rethrow;
    }
    return userModel;
  }

  Future<UserModel> getUserProfile(String uid) async {
    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .get();
    if (!doc.exists) throw Exception('User profile not found');
    return UserModel.fromFirestore(doc);
  }

  Future<void> updateUserProfile(UserModel user) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .update(user.toFirestore());
  }

  Future<void> signOut() async {
    // Clear analytics identity so the next user's session isn't attributed
    // to the previous account.
    await AnalyticsService.setUserId(null);
    await AnalyticsService.setTechnicianStatus(null);
    await _auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
