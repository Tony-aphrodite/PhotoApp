import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_flag_model.dart';

/// Reads and reviews the `admin_flags` moderation queue.
///
/// Admin-only: firestore.rules restricts reads to admins and refuses every
/// client write except the review-state fields.
class AdminFlagRepository {
  final FirebaseFirestore _firestore;

  AdminFlagRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('admin_flags');

  /// Most recent alerts first.
  ///
  /// [estado] filters to `pendiente` or `revisada`; null returns everything.
  /// [limit] caps the read — an unbounded listener over a queue that grows
  /// with every blocked message would get expensive quickly.
  Stream<List<AdminFlagModel>> watch({String? estado, int limit = 100}) {
    Query<Map<String, dynamic>> query = _ref;
    if (estado != null) {
      query = query.where('estado', isEqualTo: estado);
    }
    return query
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map(AdminFlagModel.fromFirestore).toList());
  }

  /// Marks an alert reviewed (or reopens it).
  ///
  /// Records who and when, so the queue doubles as an audit trail of what the
  /// admin actually looked at. The rules reject any attempt to touch the
  /// evidence itself.
  Future<void> setEstado({
    required String flagId,
    required String estado,
    required String adminUid,
    String? nota,
  }) {
    return _ref.doc(flagId).update({
      'estado': estado,
      'revisadoPor': adminUid,
      'revisadoAt': Timestamp.now(),
      if (nota != null && nota.trim().isNotEmpty) 'notaAdmin': nota.trim(),
    });
  }
}
