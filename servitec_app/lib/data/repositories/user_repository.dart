import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../../core/constants/app_constants.dart';

class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _usersRef =>
      _firestore.collection(AppConstants.usersCollection);

  // Get user by ID
  Future<UserModel> getUser(String uid) async {
    final doc = await _usersRef.doc(uid).get();
    if (!doc.exists) throw Exception('User not found');
    return UserModel.fromFirestore(doc);
  }

  // Stream user
  Stream<UserModel> streamUser(String uid) {
    return _usersRef.doc(uid).snapshots().map(
          (doc) => UserModel.fromFirestore(doc),
        );
  }

  // Get available technicians
  Stream<List<UserModel>> getAvailableTechnicians({String? especialidad}) {
    Query query = _usersRef
        .where('rol', isEqualTo: AppConstants.roleTechnician)
        .where('disponible', isEqualTo: true)
        .where('activo', isEqualTo: true);

    if (especialidad != null) {
      query = query.where('especialidades', arrayContains: especialidad);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList());
  }

  // Get all technicians (admin)
  Stream<List<UserModel>> getAllTechnicians() {
    return _usersRef
        .where('rol', isEqualTo: AppConstants.roleTechnician)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList());
  }

  // Get all users (admin)
  Stream<List<UserModel>> getAllUsers() {
    return _usersRef.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList());
  }

  // Update user
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _usersRef.doc(uid).update(data);
  }

  // Toggle technician availability
  Future<void> toggleAvailability(String uid, bool available) async {
    await _usersRef.doc(uid).update({'disponible': available});
  }

  // Update technician rating
  Future<void> updateTechnicianRating(
    String technicianId, {
    required double newRating,
    required int totalReviews,
  }) async {
    await _usersRef.doc(technicianId).update({
      'calificacionPromedio': newRating,
      'totalResenas': totalReviews,
    });
  }

  // Increment completed services
  Future<void> incrementCompletedServices(String technicianId) async {
    await _usersRef.doc(technicianId).update({
      'serviciosCompletados': FieldValue.increment(1),
      'ultimaAsignacion': Timestamp.now(),
    });
  }
}
