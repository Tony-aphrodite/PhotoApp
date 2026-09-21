import 'package:cloud_firestore/cloud_firestore.dart';

/// The diagnostic visit of a service — `servicios/{id}.visita`, written only
/// by the server (functions/src/visit-flow.ts). Time windows mirror
/// functions/src/lib/visit-rules.ts; the server re-checks every one of them.
class VisitInfo {
  final double precio;
  final DateTime? fecha;

  /// sin_autorizar | retenido | reautorizacion_pendiente | cobrado |
  /// liberado | reembolsado
  final String pagoEstado;
  final double? montoCobrado;
  final String? solicitudCambio;

  const VisitInfo({
    required this.precio,
    this.fecha,
    this.pagoEstado = 'sin_autorizar',
    this.montoCobrado,
    this.solicitudCambio,
  });

  static const onTheWayWindow = Duration(hours: 2);
  static const noShowReportAfter = Duration(minutes: 30);

  bool get isHeld => pagoEstado == 'retenido';
  bool get needsReauthorization => pagoEstado == 'reautorizacion_pendiente';
  bool get isCharged => pagoEstado == 'cobrado';

  /// When "Voy en camino" unlocks for the técnico.
  DateTime? get onTheWayFrom => fecha?.subtract(onTheWayWindow);

  /// When the cliente may report that the técnico never arrived.
  DateTime? get noShowReportFrom => fecha?.add(noShowReportAfter);

  static VisitInfo? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final d = Map<String, dynamic>.from(raw);
    return VisitInfo(
      precio: (d['precio'] as num?)?.toDouble() ?? 0,
      fecha: (d['fecha'] as Timestamp?)?.toDate(),
      pagoEstado: d['pagoEstado'] as String? ?? 'sin_autorizar',
      montoCobrado: (d['montoCobrado'] as num?)?.toDouble(),
      solicitudCambio: d['solicitudCambio'] as String?,
    );
  }
}
