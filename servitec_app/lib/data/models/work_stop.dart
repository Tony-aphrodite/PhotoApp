import 'package:cloud_firestore/cloud_firestore.dart';

/// A técnico stopped work before finishing — `servicios/{id}.detencion`,
/// written only by the stopWork callable.
class WorkStop {
  final String motivo;
  final String descripcion;
  final List<String> fotos;
  final double montoPropuesto;

  /// What the cliente had approved when work stopped; the cap on any
  /// closing amount.
  final double montoAprobadoPrevio;
  final DateTime? creadoAt;

  /// 'aceptada' | 'disputada' once the cliente has answered.
  final String? respuestaCliente;
  final String? comentarioCliente;

  const WorkStop({
    required this.motivo,
    required this.descripcion,
    required this.fotos,
    required this.montoPropuesto,
    required this.montoAprobadoPrevio,
    this.creadoAt,
    this.respuestaCliente,
    this.comentarioCliente,
  });

  /// Reason codes accepted by the server, with their Spanish labels. Keep in
  /// step with STOP_REASONS in functions/src/lib/service-flow-rules.ts.
  static const Map<String, String> reasons = {
    'riesgo_seguridad': 'Riesgo de seguridad',
    'dano_impide_terminar': 'Un daño impide terminar el trabajo',
    'pieza_indispensable': 'Falta una pieza indispensable',
    'otro': 'Otro motivo',
  };

  String get motivoLabel => reasons[motivo] ?? motivo;

  static WorkStop? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final d = Map<String, dynamic>.from(raw);
    return WorkStop(
      motivo: d['motivo'] as String? ?? 'otro',
      descripcion: d['descripcion'] as String? ?? '',
      fotos: d['fotos'] != null ? List<String>.from(d['fotos']) : const [],
      montoPropuesto: (d['montoPropuesto'] as num?)?.toDouble() ?? 0,
      montoAprobadoPrevio: (d['montoAprobadoPrevio'] as num?)?.toDouble() ?? 0,
      creadoAt: (d['creadoAt'] as Timestamp?)?.toDate(),
      respuestaCliente: d['respuestaCliente'] as String?,
      comentarioCliente: d['comentarioCliente'] as String?,
    );
  }
}
