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
class FacturaModel extends Equatable {
  static const String tipoTecnicoCliente = 'tecnico_cliente';
  static const String tipoServitecComision = 'servitec_comision';

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
  bool get isCancelled => estado == estadoCancelada;

  factory FacturaModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FacturaModel(
      id: doc.id,
      tipo: data['tipo'] as String? ?? tipoTecnicoCliente,
      tecnicoUid: data['tecnicoUid'] as String? ?? '',
      clienteUid: data['clienteUid'] as String?,
      servicioId: data['servicioId'] as String?,
      periodo: data['periodo'] as String?,
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
