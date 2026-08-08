import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/factura_model.dart';

/// Reads and writes for the top-level `facturas` collection.
///
/// Writes are typically produced by Cloud Functions (on payment or the monthly
/// commission cron). This repository is the read-side + admin-side surface
/// used by the Flutter app.
class FacturaRepository {
  final FirebaseFirestore _firestore;

  FacturaRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('facturas');

  Future<FacturaModel?> getById(String facturaId) async {
    final doc = await _ref.doc(facturaId).get();
    if (!doc.exists) return null;
    return FacturaModel.fromFirestore(doc);
  }

  /// Facturas issued by / involving a técnico (either as emisor for CFDIs sold
  /// to clients, or as receptor for the monthly commission CFDIs).
  Stream<List<FacturaModel>> streamByTecnico(String tecnicoUid) {
    return _ref
        .where('tecnicoUid', isEqualTo: tecnicoUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => FacturaModel.fromFirestore(d)).toList());
  }

  /// Facturas received by a cliente (only [FacturaModel.tipoTecnicoCliente]).
  Stream<List<FacturaModel>> streamByCliente(String clienteUid) {
    return _ref
        .where('clienteUid', isEqualTo: clienteUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => FacturaModel.fromFirestore(d)).toList());
  }

  /// Facturas for a service (typically 0 or 1 tecnico_cliente row).
  ///
  /// **Admin-only.** Firestore rules grant non-admins access to a factura via
  /// `tecnicoUid` / `clienteUid`, and a query is only permitted when its own
  /// constraints prove every result is readable — filtering by `servicioId`
  /// alone proves nothing, so this is rejected for técnicos and clientes
  /// before it reads anything. They must use
  /// [getForServiceAsParticipant] instead.
  Future<List<FacturaModel>> getByService(String servicioId) async {
    final snap = await _ref
        .where('servicioId', isEqualTo: servicioId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => FacturaModel.fromFirestore(d)).toList();
  }

  /// The CFDI for [servicioId] as seen by one of its two participants.
  ///
  /// Leads with the caller's own uid so the query satisfies the rules (see
  /// [getByService]), then narrows to the service. Returns `null` when the
  /// CFDI hasn't been stamped yet, or when the técnico had no FacturAPI
  /// organization at payment time — both are normal states.
  Future<FacturaModel?> getForServiceAsParticipant({
    required String servicioId,
    required String uid,
    required bool asTecnico,
  }) async {
    final snap = await _ref
        .where(asTecnico ? 'tecnicoUid' : 'clienteUid', isEqualTo: uid)
        .where('servicioId', isEqualTo: servicioId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return FacturaModel.fromFirestore(snap.docs.first);
  }

  /// Monthly commission facturas for a técnico across periods.
  Stream<List<FacturaModel>> streamMonthlyComisiones(String tecnicoUid) {
    return _ref
        .where('tecnicoUid', isEqualTo: tecnicoUid)
        .where('tipo', isEqualTo: FacturaModel.tipoServitecComision)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => FacturaModel.fromFirestore(d)).toList());
  }
}
