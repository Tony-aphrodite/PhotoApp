import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// A moderation or operations alert raised by a Cloud Function.
///
/// Five producers write into `admin_flags`, and they do not share a shape —
/// a blocked chat message carries an offender and the original text, a failed
/// CFDI carries an error string. This model reads the union and leaves the
/// irrelevant fields null, so one screen can present all of them.
///
/// Flags are evidence: only the server creates them, and firestore.rules lets
/// an admin change nothing but the review state.
class AdminFlagModel extends Equatable {
  // --- types written by the backend ---
  static const String typeContactLeak = 'chat_contact_info_leak_attempt';
  static const String typeNoTechnician = 'no_technician_available';
  static const String typeCfdiDeferred = 'cfdi_pending_technician_not_configured';
  static const String typeCfdiFailed = 'cfdi_artifact_generation_failed';
  static const String typeCommissionCfdiFailed =
      'commission_cfdi_artifact_generation_failed';

  static const String estadoPendiente = 'pendiente';
  static const String estadoRevisada = 'revisada';

  final String id;
  final String type;
  final String estado;
  final DateTime createdAt;

  /// Service this alert belongs to, when there is one.
  final String? servicioId;
  final String? clienteId;
  final String? tecnicoId;

  // --- contact-leak specific ---
  final String? messageId;
  final String? offenderUid;
  final String? offenderName;

  /// What the user actually tried to send. Kept verbatim for moderation — it
  /// is the whole point of the record.
  final String? originalText;

  /// Which detector fired: phone, email, externalLink, bypassKeyword.
  final String? reason;

  // --- operational failures ---
  final String? error;
  final String? categoria;
  final String? periodo;

  // --- review trail ---
  final String? revisadoPor;
  final DateTime? revisadoAt;
  final String? notaAdmin;

  const AdminFlagModel({
    required this.id,
    required this.type,
    required this.estado,
    required this.createdAt,
    this.servicioId,
    this.clienteId,
    this.tecnicoId,
    this.messageId,
    this.offenderUid,
    this.offenderName,
    this.originalText,
    this.reason,
    this.error,
    this.categoria,
    this.periodo,
    this.revisadoPor,
    this.revisadoAt,
    this.notaAdmin,
  });

  bool get isPendiente => estado == estadoPendiente;
  bool get isContactLeak => type == typeContactLeak;

  /// True when this alert is about someone trying to take the job off the
  /// platform, as opposed to a backend failure. These are the ones with a
  /// commercial cost.
  bool get isModeration => isContactLeak;

  factory AdminFlagModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdminFlagModel(
      id: doc.id,
      type: data['type'] as String? ?? 'desconocido',
      // Flags written before the review state existed are treated as pending,
      // which is the safe default — they still need looking at.
      estado: data['estado'] as String? ?? estadoPendiente,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      // `serviceId` is the legacy spelling from the chat guard's first version.
      servicioId: data['servicioId'] as String? ?? data['serviceId'] as String?,
      clienteId: data['clienteId'] as String?,
      tecnicoId: data['tecnicoId'] as String? ?? data['tecnicoUid'] as String?,
      messageId: data['messageId'] as String?,
      offenderUid: data['offenderUid'] as String?,
      offenderName: data['offenderName'] as String?,
      originalText: data['originalText'] as String?,
      reason: data['reason'] as String?,
      error: data['error'] as String?,
      categoria: data['categoria'] as String?,
      periodo: data['periodo'] as String?,
      revisadoPor: data['revisadoPor'] as String?,
      revisadoAt: (data['revisadoAt'] as Timestamp?)?.toDate(),
      notaAdmin: data['notaAdmin'] as String?,
    );
  }

  /// Spanish label for the alert type, for the admin panel.
  String get tipoLabel {
    switch (type) {
      case typeContactLeak:
        return 'Intento de contacto fuera de la app';
      case typeNoTechnician:
        return 'Sin técnicos disponibles';
      case typeCfdiDeferred:
        return 'CFDI pendiente — técnico sin datos fiscales';
      case typeCfdiFailed:
        return 'Falló la generación del CFDI';
      case typeCommissionCfdiFailed:
        return 'Falló el CFDI de comisión mensual';
      case 'phone_released':
        return 'Teléfono liberado por un administrador';
      case 'work_stopped':
        return 'Trabajo detenido por el técnico';
      case 'work_stop_dispute':
        return 'Disputa por trabajo detenido';
      case 'technician_withdrew':
        return 'El técnico canceló — reasignar servicio';
      case 'technician_no_show_report':
        return 'Reporte: el técnico no llegó';
      case 'cfdi_diagnostico_pendiente':
        return 'CFDI de visita de diagnóstico pendiente';
      default:
        return type;
    }
  }

  /// What exactly was detected, for the contact-leak alerts. Edgar asked to
  /// see phone vs WhatsApp vs other at a glance.
  String get motivoLabel {
    switch (reason) {
      case 'phone':
        return 'Número telefónico';
      case 'email':
        return 'Correo electrónico';
      case 'externalLink':
        return 'Enlace de WhatsApp o Telegram';
      case 'bypassKeyword':
        return 'Mención de pago o contacto por fuera';
      default:
        return reason ?? '—';
    }
  }

  @override
  List<Object?> get props => [id, type, estado, createdAt, servicioId, reason];
}
