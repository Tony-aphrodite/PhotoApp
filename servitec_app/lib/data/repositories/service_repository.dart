import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/service_model.dart';
import '../models/message_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/service_state_machine.dart';

class ServiceRepository {
  final FirebaseFirestore _firestore;

  ServiceRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _servicesRef =>
      _firestore.collection(AppConstants.servicesCollection);

  // Create service
  Future<ServiceModel> createService(ServiceModel service) async {
    final docRef = await _servicesRef.add(service.toFirestore());
    return service.copyWith(id: docRef.id);
  }

  // Get service by ID
  Future<ServiceModel> getService(String serviceId) async {
    final doc = await _servicesRef.doc(serviceId).get();
    if (!doc.exists) throw Exception('Service not found');
    return ServiceModel.fromFirestore(doc);
  }

  // Stream single service
  Stream<ServiceModel> streamService(String serviceId) {
    return _servicesRef.doc(serviceId).snapshots().map(
          (doc) => ServiceModel.fromFirestore(doc),
        );
  }

  // Get services by client
  Stream<List<ServiceModel>> getClientServices(String clientId) {
    return _servicesRef
        .where('clienteId', isEqualTo: clientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ServiceModel.fromFirestore(doc)).toList());
  }

  // Get services by technician
  Stream<List<ServiceModel>> getTechnicianServices(String technicianId) {
    return _servicesRef
        .where('tecnicoId', isEqualTo: technicianId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ServiceModel.fromFirestore(doc)).toList());
  }

  // Get all services (admin)
  Stream<List<ServiceModel>> getAllServices({String? statusFilter}) {
    Query query = _servicesRef.orderBy('createdAt', descending: true);
    if (statusFilter != null) {
      query = query.where('estado', isEqualTo: statusFilter);
    }
    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => ServiceModel.fromFirestore(doc)).toList());
  }

  // Get pending services (admin)
  Stream<List<ServiceModel>> getPendingServices() {
    return _servicesRef
        .where('estado', isEqualTo: AppConstants.statusPending)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ServiceModel.fromFirestore(doc)).toList());
  }

  // Update service status with validation
  Future<void> updateServiceStatus(String serviceId, String newStatus) async {
    // Validate transition
    final currentDoc = await _servicesRef.doc(serviceId).get();
    final currentStatus = (currentDoc.data() as Map<String, dynamic>?)?['estado'] ?? '';
    final error = ServiceStateMachine.validateTransition(currentStatus, newStatus);
    if (error != null) throw Exception(error);

    final updates = <String, dynamic>{
      'estado': newStatus,
      'updatedAt': Timestamp.now(),
    };

    if (newStatus == AppConstants.statusAssigned) {
      updates['asignadoAt'] = Timestamp.now();
    } else if (newStatus == AppConstants.statusCompleted) {
      updates['completadoAt'] = Timestamp.now();
    }

    await _servicesRef.doc(serviceId).update(updates);
  }

  // Assign technician to service
  Future<void> assignTechnician({
    required String serviceId,
    required String technicianId,
    required String technicianName,
    required String assignmentType,
  }) async {
    await _servicesRef.doc(serviceId).update({
      'tecnicoId': technicianId,
      'tecnicoNombre': technicianName,
      'estado': AppConstants.statusAssigned,
      'tipoAsignacion': assignmentType,
      'asignadoAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
  }

  // Update service
  Future<void> updateService(String serviceId, Map<String, dynamic> data) async {
    data['updatedAt'] = Timestamp.now();
    await _servicesRef.doc(serviceId).update(data);
  }

  // === Chat Messages ===

  // Send message
  Future<void> sendMessage(String serviceId, MessageModel message) async {
    await _servicesRef
        .doc(serviceId)
        .collection(AppConstants.messagesSubcollection)
        .add(message.toFirestore());
  }

  // Stream messages
  Stream<List<MessageModel>> getMessages(String serviceId) {
    return _servicesRef
        .doc(serviceId)
        .collection(AppConstants.messagesSubcollection)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => MessageModel.fromFirestore(doc)).toList());
  }

  // Mark message as read
  Future<void> markMessageRead(String serviceId, String messageId) async {
    await _servicesRef
        .doc(serviceId)
        .collection(AppConstants.messagesSubcollection)
        .doc(messageId)
        .update({'leido': true});
  }

  // Get unread message count
  Stream<int> getUnreadMessageCount(String serviceId, String userId) {
    return _servicesRef
        .doc(serviceId)
        .collection(AppConstants.messagesSubcollection)
        .where('leido', isEqualTo: false)
        .where('userId', isNotEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
