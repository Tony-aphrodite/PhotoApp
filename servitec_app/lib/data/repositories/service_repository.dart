import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/service_model.dart';
import '../models/service_private_contact.dart';
import '../models/message_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/analytics_service.dart';
import '../../core/utils/service_state_machine.dart';

class ServiceRepository {
  final FirebaseFirestore _firestore;

  ServiceRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _servicesRef =>
      _firestore.collection(AppConstants.servicesCollection);

  // Create service. The public service body (`servicios/{id}`) is created
  // WITHOUT the client's phone — that lives in `servicios/{id}/private/contact`
  // and is gated by security rules keyed off `estado` (see firestore.rules).
  // This makes the phone unavailable via direct Firestore access until the
  // service reaches en_progreso/completado/pagado.
  Future<ServiceModel> createService(ServiceModel service) async {
    // Write the public body with `clienteTelefono` blanked so nothing sensitive
    // leaks even if rules are misconfigured.
    final publicBody = service.copyWith(clienteTelefono: '');
    final docRef = await _servicesRef.add(publicBody.toFirestore());

    // Write the private contact subdoc.
    if (service.clienteTelefono.isNotEmpty) {
      await docRef
          .collection('private')
          .doc('contact')
          .set(ServicePrivateContact(
            telefonoCliente: service.clienteTelefono,
          ).toFirestore());
    }

    // Analytics — top-of-funnel event for the marketing team.
    await AnalyticsService.logServiceRequested(
      servicioId: docRef.id,
      categoria: service.categoria,
      urgencia: service.urgencia,
      estimacionCosto: service.estimacionCosto,
    );
    return service.copyWith(id: docRef.id);
  }

  /// Stream the private contact subdoc for a service. Firestore rules only
  /// allow reads when the requester is admin OR the assigned técnico AND the
  /// service status warrants revealing the phone. If unauthorized, the stream
  /// emits `null` (permission denied is silently swallowed).
  Stream<ServicePrivateContact?> streamServicePrivateContact(String serviceId) {
    return _servicesRef
        .doc(serviceId)
        .collection('private')
        .doc('contact')
        .snapshots()
        .map((snap) =>
            snap.exists ? ServicePrivateContact.fromFirestore(snap) : null)
        .handleError((_) => null);
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
        .snapshots()
        .map((snapshot) {
      final list =
          snapshot.docs.map((doc) => ServiceModel.fromFirestore(doc)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
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

    // Narrate the transition in the service chat thread so both parties have
    // a single, audit-ready timeline (no reason to leave the app).
    final label = _statusLabel(newStatus);
    if (label != null) {
      await postSystemMessage(
        serviceId,
        label,
        metadata: {'event': 'status_change', 'estado': newStatus},
      );
    }

    // Analytics — funnel milestones for the marketing team.
    switch (newStatus) {
      case AppConstants.statusInProgress:
        await AnalyticsService.logServiceStarted(servicioId: serviceId);
        break;
      case AppConstants.statusCompleted:
        await AnalyticsService.logServiceCompleted(servicioId: serviceId);
        break;
      case AppConstants.statusCancelled:
        await AnalyticsService.logServiceCancelled(servicioId: serviceId);
        break;
    }
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

    await postSystemMessage(
      serviceId,
      'Técnico asignado: $technicianName',
      metadata: {
        'event': 'technician_assigned',
        'tecnicoId': technicianId,
        'tipoAsignacion': assignmentType,
      },
    );

    await AnalyticsService.logTechnicianAssigned(
      servicioId: serviceId,
      tipoAsignacion: assignmentType,
    );
  }

  static String? _statusLabel(String status) {
    switch (status) {
      case AppConstants.statusAssigned:
        return 'Servicio asignado a un técnico';
      case AppConstants.statusInProgress:
        return 'El técnico inició el servicio';
      case AppConstants.statusCompleted:
        return 'Servicio marcado como completado';
      case AppConstants.statusPaymentPending:
        return 'Pago pendiente';
      case AppConstants.statusPaid:
        return 'Pago recibido';
      case AppConstants.statusCancelled:
        return 'Servicio cancelado';
      default:
        return null;
    }
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

  /// Post a system message into the service chat thread.
  ///
  /// Used for lifecycle narration (assignment, status changes, quotation
  /// events, payment) so the in-app thread is the single source of truth and
  /// users have no operational reason to jump to WhatsApp.
  Future<void> postSystemMessage(
    String serviceId,
    String text, {
    Map<String, dynamic>? metadata,
  }) async {
    final message = MessageModel(
      id: '',
      userId: 'system',
      nombreUsuario: 'ServiTec',
      mensaje: text,
      timestamp: DateTime.now(),
      tipo: MessageModel.tipoSistema,
      metadata: metadata,
    );
    await sendMessage(serviceId, message);
  }

  /// Send an image message (data URL stored inline, matching existing
  /// base64-in-Firestore storage strategy).
  Future<void> sendImageMessage({
    required String serviceId,
    required String userId,
    required String userName,
    required String imageDataUrl,
    String caption = '',
  }) async {
    final message = MessageModel(
      id: '',
      userId: userId,
      nombreUsuario: userName,
      mensaje: caption,
      timestamp: DateTime.now(),
      tipo: MessageModel.tipoImagen,
      imageData: imageDataUrl,
    );
    await sendMessage(serviceId, message);
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
