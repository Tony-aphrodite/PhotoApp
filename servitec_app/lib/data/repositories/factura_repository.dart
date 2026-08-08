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
  Future<List<FacturaModel>> getByService(String servicioId) async {
    final snap = await _ref
        .where('servicioId', isEqualTo: servicioId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => FacturaModel.fromFirestore(d)).toList();
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
