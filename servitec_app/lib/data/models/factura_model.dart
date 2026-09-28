import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// A stamped CFDI record kept in Firestore for audit + admin queries.
///
/// Actual XML and (branded) PDF live in Cloud Storage; only their URLs are
/// referenced here. Two `tipo` variants:
///
/// * [tipoTecnicoCliente] — issued at payment time, técnico → cliente,
///   for a specific service.
/// * [tipoServitecComision] — issued monthly by the platform, ServiTec → técnico,
///   aggregating that month's 12% commissions with line items per service.
/// * [tipoNotaCredito] — CFDI de egreso, issued when money is returned. It
///   never replaces the CFDI it relates to ([folioOrigen]); both stay valid,
///   as the accountant asked.
///
/// A service in the diagnostic flow has more than one: the visit is invoiced
/// when the diagnosis ends, the balance when the repair is paid — hence
/// [concepto].
class FacturaModel extends Equatable {
  static const String tipoTecnicoCliente = 'tecnico_cliente';
  static const String tipoServitecComision = 'servitec_comision';
  static const String tipoNotaCredito = 'nota_credito';

  static const String conceptoVisita = 'visita';
  static const String conceptoSaldo = 'saldo';
  static const String conceptoServicio = 'servicio';

  static const String estadoVigente = 'vigente';
  static const String estadoCancelada = 'cancelada';

  final String id;
  final String tipo;
  final String tecnicoUid;

  /// Cliente user id — only for [tipoTecnicoCliente].
  final String? clienteUid;

  /// Service id — only for [tipoTecnicoCliente].
  final String? servicioId;

  /// Period tag `YYYY-MM` — only for [tipoServitecComision].
  final String? periodo;

  /// What this comprobante covers: `visita`, `saldo` or `servicio`.
  final String? concepto;

  /// Why money was returned — only for [tipoNotaCredito].
  final String? motivo;

  /// UUID of the CFDI this nota de crédito relates to.
  final String? folioOrigen;

  /// FacturAPI invoice id returned from POST /invoices.
  final String? facturapiInvoiceId;

  /// SAT UUID (folio fiscal) — the canonical CFDI identifier.
  final String? folioFiscal;

  final DateTime? fechaTimbrado;

  final double subtotal;
  final double iva;
  final double total;

  /// Storage URLs for the signed XML and the ServiTec-branded PDF.
  final String? xmlUrl;
  final String? pdfUrl;

  final String estado;
  final DateTime createdAt;

  const FacturaModel({
    required this.id,
    required this.tipo,
    required this.tecnicoUid,
    this.clienteUid,
    this.servicioId,
    this.periodo,
    this.concepto,
    this.motivo,
    this.folioOrigen,
    this.facturapiInvoiceId,
    this.folioFiscal,
    this.fechaTimbrado,
    required this.subtotal,
    required this.iva,
    required this.total,
    this.xmlUrl,
    this.pdfUrl,
    this.estado = estadoVigente,
    required this.createdAt,
  });

  bool get isTecnicoCliente => tipo == tipoTecnicoCliente;
  bool get isComision => tipo == tipoServitecComision;
  bool get isNotaCredito => tipo == tipoNotaCredito;
  bool get isCancelled => estado == estadoCancelada;

  /// Title shown wherever a CFDI is listed, in Spanish.
  String get titulo {
    if (isComision) {
      return 'Comisión ServiTec${periodo != null ? ' · $periodo' : ''}';
    }
    if (isNotaCredito) return 'Nota de crédito (devolución)';
    switch (concepto) {
      case conceptoVisita:
        return 'CFDI de la visita de diagnóstico';
      case conceptoSaldo:
        return 'CFDI del saldo de la reparación';
      default:
        return 'CFDI de servicio';
    }
  }

  factory FacturaModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FacturaModel(
      id: doc.id,
      tipo: data['tipo'] as String? ?? tipoTecnicoCliente,
      tecnicoUid: data['tecnicoUid'] as String? ?? '',
      clienteUid: data['clienteUid'] as String?,
      servicioId: data['servicioId'] as String?,
      periodo: data['periodo'] as String?,
      concepto: data['concepto'] as String?,
      motivo: data['motivo'] as String?,
      folioOrigen: data['folioOrigen'] as String?,
      facturapiInvoiceId: data['facturapiInvoiceId'] as String?,
      folioFiscal: data['folioFiscal'] as String?,
      fechaTimbrado: (data['fechaTimbrado'] as Timestamp?)?.toDate(),
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0,
      iva: (data['iva'] as num?)?.toDouble() ?? 0,
      total: (data['total'] as num?)?.toDouble() ?? 0,
      xmlUrl: data['xmlUrl'] as String?,
      pdfUrl: data['pdfUrl'] as String?,
      estado: data['estado'] as String? ?? estadoVigente,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'tipo': tipo,
      'tecnicoUid': tecnicoUid,
      'subtotal': subtotal,
      'iva': iva,
      'total': total,
      'estado': estado,
      'createdAt': Timestamp.fromDate(createdAt),
    };
    if (clienteUid != null) map['clienteUid'] = clienteUid;
    if (servicioId != null) map['servicioId'] = servicioId;
    if (periodo != null) map['periodo'] = periodo;
    if (concepto != null) map['concepto'] = concepto;
    if (motivo != null) map['motivo'] = motivo;
    if (folioOrigen != null) map['folioOrigen'] = folioOrigen;
    if (facturapiInvoiceId != null) {
      map['facturapiInvoiceId'] = facturapiInvoiceId;
    }
    if (folioFiscal != null) map['folioFiscal'] = folioFiscal;
    if (fechaTimbrado != null) {
      map['fechaTimbrado'] = Timestamp.fromDate(fechaTimbrado!);
    }
    if (xmlUrl != null) map['xmlUrl'] = xmlUrl;
    if (pdfUrl != null) map['pdfUrl'] = pdfUrl;
    return map;
  }

  @override
  List<Object?> get props => [
        id,
        tipo,
        tecnicoUid,
        clienteUid,
        servicioId,
        periodo,
        concepto,
        motivo,
        folioOrigen,
        facturapiInvoiceId,
        folioFiscal,
        fechaTimbrado,
        subtotal,
        iva,
        total,
        xmlUrl,
        pdfUrl,
        estado,
        createdAt,
      ];
}
