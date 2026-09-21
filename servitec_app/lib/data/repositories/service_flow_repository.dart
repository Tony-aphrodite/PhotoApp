import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/quotation_model.dart';

/// A flow step was refused; [message] is the server's Spanish explanation.
class FlowException implements Exception {
  final String message;
  const FlowException(this.message);

  @override
  String toString() => message;
}

/// The quotation and work flow, driven through Cloud Functions
/// (functions/src/service-flow.ts).
///
/// The app never writes a service's state or price itself: each step decides
/// what the cliente will pay, so the server validates it and firestore.rules
/// refuse direct writes.
class ServiceFlowRepository {
  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;

  ServiceFlowRepository({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
  })  : _functions = functions ?? FirebaseFunctions.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  Future<Map<String, dynamic>> _call(
      String name, Map<String, dynamic> data) async {
    try {
      final result = await _functions
          .httpsCallable(name)
          .call<Map<String, dynamic>>(data);
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw FlowException(e.message ?? 'No se pudo completar la acción.');
    }
  }

  /// Every cotización of a service, newest first.
  ///
  /// Filtered by the caller's own uid as well as the service: firestore.rules
  /// only let a cliente or técnico read cotizaciones that name them, and a
  /// query must be provably limited to those. Admins may omit [participantUid].
  Stream<List<QuotationModel>> streamQuotations({
    required String servicioId,
    String? participantUid,
    bool asTecnico = false,
  }) {
    Query query = _firestore
        .collection('cotizaciones')
        .where('servicioId', isEqualTo: servicioId);
    if (participantUid != null) {
      query = query.where(asTecnico ? 'tecnicoId' : 'clienteId',
          isEqualTo: participantUid);
    }
    return query.snapshots().map((snap) {
      final list = snap.docs.map(QuotationModel.fromFirestore).toList()
        ..sort((a, b) => b.version.compareTo(a.version));
      return list;
    });
  }

  Future<void> submitQuotation({
    required String servicioId,
    required List<QuotationItem> items,
    String? notas,
    List<String> fotos = const [],
  }) =>
      _call('submitQuotation', {
        'servicioId': servicioId,
        'items': items
            .map((i) => {
                  'descripcion': i.descripcion,
                  'tipo': i.tipo,
                  'cantidad': i.cantidad,
                  'precioUnitario': i.precioUnitario,
                })
            .toList(),
        if (notas != null && notas.isNotEmpty) 'notas': notas,
        'fotos': fotos,
      });

  Future<void> respondQuotation({
    required String cotizacionId,
    required bool aprobar,
  }) =>
      _call('respondQuotation', {
        'cotizacionId': cotizacionId,
        'respuesta': aprobar ? 'aprobada' : 'rechazada',
      });

  /// 'iniciar', 'continuar_original' or 'completar'.
  Future<void> workAction(String servicioId, String accion) =>
      _call('serviceWorkAction', {'servicioId': servicioId, 'accion': accion});

  Future<void> stopWork({
    required String servicioId,
    required String motivo,
    required String descripcion,
    required List<String> fotos,
    required double montoPropuesto,
  }) =>
      _call('stopWork', {
        'servicioId': servicioId,
        'motivo': motivo,
        'descripcion': descripcion,
        'fotos': fotos,
        'montoPropuesto': montoPropuesto,
      });

  Future<void> respondStop({
    required String servicioId,
    required bool aceptar,
    String? comentario,
  }) =>
      _call('respondStop', {
        'servicioId': servicioId,
        'respuesta': aceptar ? 'aceptar' : 'disputar',
        if (comentario != null) 'comentario': comentario,
      });

  /// A step of the diagnostic-visit flow — or any cancellation, in either
  /// flow (see functions/src/visit-flow.ts for the list of `accion` values).
  Future<Map<String, dynamic>> visitAction(
    String servicioId,
    String accion, [
    Map<String, dynamic> extra = const {},
  ]) =>
      _call('visitAction', {'servicioId': servicioId, 'accion': accion, ...extra});

  Future<void> resolveDispute({
    required String servicioId,
    required double monto,
    required String nota,
  }) =>
      _call('adminResolveDispute', {
        'servicioId': servicioId,
        'monto': monto,
        'nota': nota,
      });
}
