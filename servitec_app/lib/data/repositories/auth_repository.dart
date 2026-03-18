import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../../core/constants/app_constants.dart';

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
    return await getUserProfile(user.uid);
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

    final userModel = UserModel(
      uid: user.uid,
      email: email,
      nombre: nombre,
      apellido: apellido,
      telefono: telefono,
      rol: AppConstants.roleTechnician,
      createdAt: DateTime.now(),
      especialidades: especialidades,
      calificacionPromedio: 0.0,
      totalResenas: 0,
      tarifasPorEspecialidad: tarifas ?? {},
      disponible: true,
      serviciosCompletados: 0,
    );

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .set(userModel.toFirestore());

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
    await _auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
