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

  // Get services by client (paginated — 10 per page)
  static const int _clientPageSize = 10;
  static const int _technicianPageSize = 15;
  static const int _adminPageSize = 20;

  Stream<List<ServiceModel>> getClientServices(String clientId) {
    return _servicesRef
        .where('clienteId', isEqualTo: clientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ServiceModel.fromFirestore(doc)).toList());
  }

  /// Paginated client services — returns first page
  Future<ServicePage> getClientServicesPage(
      String clientId, {
      DocumentSnapshot? lastDocument,
    }) async {
    Query query = _servicesRef
        .where('clienteId', isEqualTo: clientId)
        .orderBy('createdAt', descending: true)
        .limit(_clientPageSize);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    final snap = await query.get();
    return ServicePage(
      services: snap.docs.map((d) => ServiceModel.fromFirestore(d)).toList(),
      lastDocument: snap.docs.isNotEmpty ? snap.docs.last : null,
      hasMore: snap.docs.length == _clientPageSize,
    );
  }

  // Get services by technician (paginated — 15 per page)
  Stream<List<ServiceModel>> getTechnicianServices(String technicianId,
      {String? statusFilter}) {
    Query query = _servicesRef
        .where('tecnicoId', isEqualTo: technicianId)
        .orderBy('createdAt', descending: true);
    if (statusFilter != null) {
      query = query.where('estado', isEqualTo: statusFilter);
    }
    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => ServiceModel.fromFirestore(doc)).toList());
  }

  Future<ServicePage> getTechnicianServicesPage(
      String technicianId, {
      String? statusFilter,
      DocumentSnapshot? lastDocument,
    }) async {
    Query query = _servicesRef
        .where('tecnicoId', isEqualTo: technicianId)
        .orderBy('createdAt', descending: true)
        .limit(_technicianPageSize);

    if (statusFilter != null) {
      query = query.where('estado', isEqualTo: statusFilter);
    }
    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    final snap = await query.get();
    return ServicePage(
      services: snap.docs.map((d) => ServiceModel.fromFirestore(d)).toList(),
      lastDocument: snap.docs.isNotEmpty ? snap.docs.last : null,
      hasMore: snap.docs.length == _technicianPageSize,
    );
  }

  // Get all services (admin — paginated 20 per page)
  Stream<List<ServiceModel>> getAllServices({String? statusFilter}) {
    Query query = _servicesRef.orderBy('createdAt', descending: true);
    if (statusFilter != null) {
      query = query.where('estado', isEqualTo: statusFilter);
    }
    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => ServiceModel.fromFirestore(doc)).toList());
  }

  Future<ServicePage> getAllServicesPage({
    String? statusFilter,
    String? categoryFilter,
    DocumentSnapshot? lastDocument,
  }) async {
    Query query = _servicesRef
        .orderBy('createdAt', descending: true)
        .limit(_adminPageSize);

    if (statusFilter != null) {
      query = query.where('estado', isEqualTo: statusFilter);
    }
    if (categoryFilter != null) {
      query = query.where('categoria', isEqualTo: categoryFilter);
    }
    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    final snap = await query.get();
    return ServicePage(
      services: snap.docs.map((d) => ServiceModel.fromFirestore(d)).toList(),
      lastDocument: snap.docs.isNotEmpty ? snap.docs.last : null,
      hasMore: snap.docs.length == _adminPageSize,
    );
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

  static const int _initialMessageLimit = 50;

  // Stream messages — initial 50, most recent
  Stream<List<MessageModel>> getMessages(String serviceId) {
    return _servicesRef
        .doc(serviceId)
        .collection(AppConstants.messagesSubcollection)
        .orderBy('timestamp', descending: false)
        .limitToLast(_initialMessageLimit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => MessageModel.fromFirestore(doc)).toList());
  }

  /// Load older messages before a given timestamp (lazy loading)
  Future<List<MessageModel>> getMessagesBefore(
      String serviceId, DateTime before) async {
    const olderPageSize = 30;
    final snap = await _servicesRef
        .doc(serviceId)
        .collection(AppConstants.messagesSubcollection)
        .orderBy('timestamp', descending: true)
        .where('timestamp',
            isLessThan: Timestamp.fromDate(before))
        .limit(olderPageSize)
        .get();
    // Reverse to maintain chronological order
    return snap.docs
        .map((d) => MessageModel.fromFirestore(d))
        .toList()
        .reversed
        .toList();
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

/// Pagination result wrapper
class ServicePage {
  final List<ServiceModel> services;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;

  const ServicePage({
    required this.services,
    required this.lastDocument,
    required this.hasMore,
  });
}
