import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/facturapi_ref.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/analytics_service.dart';
import '../../core/utils/fiscal_status.dart';
import '../../core/utils/notification_service.dart';

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
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) throw Exception('Registration failed');

    final userModel = UserModel(
      uid: user.uid,
      email: email,
      nombre: nombre,
      apellido: apellido,
      telefono: telefono,
      rol: AppConstants.roleClient,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .set(userModel.toFirestore());

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
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) throw Exception('Registration failed');

    final now = DateTime.now();
    final userModel = UserModel(
      uid: user.uid,
      email: email,
      nombre: nombre,
      apellido: apellido,
      telefono: telefono,
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
    );

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .set(userModel.toFirestore());

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
