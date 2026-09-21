import 'package:cloud_firestore/cloud_firestore.dart';
import 'visit_info.dart';
import 'work_stop.dart';
import 'package:equatable/equatable.dart';

class ServiceModel extends Equatable {
  final String id;
  final String clienteId;
  final String clienteNombre;
  final String clienteTelefono;
  final String? tecnicoId;
  final String? tecnicoNombre;
  final String titulo;
  final String descripcion;
  final String categoria;
  final String urgencia;
  final GeoPoint ubicacion;
  final String ubicacionTexto;
  final String? geohash;
  /// Full-size photo URLs, for the detail screen.
  ///
  /// Historically these were base64 `data:` URLs stored inline; since the move
  /// to Cloud Storage they are https download URLs. Both render, so services
  /// created before the migration keep working.
  final List<String> fotos;

  /// Thumbnail URLs, same order as [fotos]. Lists and cards must read these —
  /// pulling [fotos] into a list view downloads full-resolution images for
  /// every row. Empty on pre-migration services, where callers fall back to
  /// [fotos].
  final List<String> fotosThumbs;

  /// The image a list or card should show: the thumbnail when one exists,
  /// otherwise the full-size photo (services created before the Cloud Storage
  /// migration have no thumbnails). Null when the service has no photos.
  String? get fotoPreview {
    if (fotosThumbs.isNotEmpty) return fotosThumbs.first;
    if (fotos.isNotEmpty) return fotos.first;
    return null;
  }
  final String estado;
  final String tipoAsignacion;
  final bool seleccionadoPorCliente;
  final double? estimacionCosto;
  final double? costoFinal;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? asignadoAt;
  final DateTime? completadoAt;

  // Phase 2 fields (prepared)
  final double? montoPagado;
  final double? comisionPlataforma;
  final double? montoTecnico;
  final String? estadoPago;

  // Quotation and work flow — written only by Cloud Functions.
  final String? cotizacionPendienteId;
  final String? cotizacionAprobadaId;
  final WorkStop? detencion;
  final String? resolucionNota;

  // Diagnostic-visit flow — written only by Cloud Functions.
  /// 'estandar' or 'diagnostico'; null until the server sets it on creation.
  final String? flujo;
  final VisitInfo? visita;

  /// How a service that ended paid was closed, e.g. 'solo_diagnostico'.
  final String? cierre;

  /// When a diagnostic service waiting on someone closes by itself.
  final DateTime? autoCierreAt;

  const ServiceModel({
    required this.id,
    required this.clienteId,
    required this.clienteNombre,
    required this.clienteTelefono,
    this.tecnicoId,
    this.tecnicoNombre,
    required this.titulo,
    required this.descripcion,
    required this.categoria,
    required this.urgencia,
    required this.ubicacion,
    required this.ubicacionTexto,
    this.geohash,
    required this.fotos,
    this.fotosThumbs = const [],
    required this.estado,
    required this.tipoAsignacion,
    this.seleccionadoPorCliente = false,
    this.estimacionCosto,
    this.costoFinal,
    required this.createdAt,
    required this.updatedAt,
    this.asignadoAt,
    this.completadoAt,
    this.montoPagado,
    this.comisionPlataforma,
    this.montoTecnico,
    this.estadoPago,
    this.cotizacionPendienteId,
    this.cotizacionAprobadaId,
    this.detencion,
    this.resolucionNota,
    this.flujo,
    this.visita,
    this.cierre,
    this.autoCierreAt,
  });

  bool get isDiagnostic => flujo == 'diagnostico';

  /// Visit fee already charged, credited against the total (0 otherwise).
  double get visitPaid =>
      isDiagnostic && (visita?.isCharged ?? false) ? (visita!.montoCobrado ?? 0) : 0;

  /// What the cliente still owes on completion. Mirrors remainingAfterVisit()
  /// on the server, which is what actually decides the charge.
  double get amountDue {
    final total = costoFinal ?? estimacionCosto ?? 0;
    if (visitPaid <= 0) return total;
    final rest = total - visitPaid;
    return rest >= 10 ? rest : 0;
  }

  bool get isPending => estado == 'pendiente';
  bool get isAssigned => estado == 'asignado';
  bool get isInProgress => estado == 'en_progreso';
  bool get isCompleted => estado == 'completado';
  bool get isCancelled => estado == 'cancelado';

  factory ServiceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ServiceModel(
      id: doc.id,
      clienteId: data['clienteId'] ?? '',
      clienteNombre: data['clienteNombre'] ?? '',
      clienteTelefono: data['clienteTelefono'] ?? '',
      tecnicoId: data['tecnicoId'],
      tecnicoNombre: data['tecnicoNombre'],
      titulo: data['titulo'] ?? '',
      descripcion: data['descripcion'] ?? '',
      categoria: data['categoria'] ?? '',
      urgencia: data['urgencia'] ?? 'normal',
      ubicacion: data['ubicacion'] as GeoPoint? ?? const GeoPoint(0, 0),
      ubicacionTexto: data['ubicacionTexto'] ?? '',
      geohash: data['geohash'],
      fotos: data['fotos'] != null ? List<String>.from(data['fotos']) : [],
      fotosThumbs: data['fotosThumbs'] != null
          ? List<String>.from(data['fotosThumbs'])
          : const [],
      estado: data['estado'] ?? 'pendiente',
      tipoAsignacion: data['tipoAsignacion'] ?? 'automatica',
      seleccionadoPorCliente: data['seleccionadoPorCliente'] ?? false,
      estimacionCosto: (data['estimacionCosto'] as num?)?.toDouble(),
      costoFinal: (data['costoFinal'] as num?)?.toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      asignadoAt: (data['asignadoAt'] as Timestamp?)?.toDate(),
      completadoAt: (data['completadoAt'] as Timestamp?)?.toDate(),
      montoPagado: (data['montoPagado'] as num?)?.toDouble(),
      comisionPlataforma: (data['comisionPlataforma'] as num?)?.toDouble(),
      montoTecnico: (data['montoTecnico'] as num?)?.toDouble(),
      estadoPago: data['estadoPago'],
      cotizacionPendienteId: data['cotizacionPendienteId'] as String?,
      cotizacionAprobadaId: data['cotizacionAprobadaId'] as String?,
      detencion: WorkStop.fromMap(data['detencion']),
      resolucionNota: (data['resolucion'] as Map?)?['nota'] as String?,
      flujo: data['flujo'] as String?,
      visita: VisitInfo.fromMap(data['visita']),
      cierre: data['cierre'] as String?,
      autoCierreAt: ((data['autoCierre'] as Map?)?['at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'clienteId': clienteId,
      'clienteNombre': clienteNombre,
      'clienteTelefono': clienteTelefono,
      'titulo': titulo,
      'descripcion': descripcion,
      'categoria': categoria,
      'urgencia': urgencia,
      'ubicacion': ubicacion,
      'ubicacionTexto': ubicacionTexto,
      'fotos': fotos,
      'fotosThumbs': fotosThumbs,
      'estado': estado,
      'tipoAsignacion': tipoAsignacion,
      'seleccionadoPorCliente': seleccionadoPorCliente,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };

    if (tecnicoId != null) map['tecnicoId'] = tecnicoId;
    if (tecnicoNombre != null) map['tecnicoNombre'] = tecnicoNombre;
    if (geohash != null) map['geohash'] = geohash;
    if (estimacionCosto != null) map['estimacionCosto'] = estimacionCosto;
    if (costoFinal != null) map['costoFinal'] = costoFinal;
    if (asignadoAt != null) map['asignadoAt'] = Timestamp.fromDate(asignadoAt!);
    if (completadoAt != null) map['completadoAt'] = Timestamp.fromDate(completadoAt!);

    return map;
  }

  ServiceModel copyWith({
    String? id,
    String? clienteId,
    String? clienteNombre,
    String? clienteTelefono,
    String? tecnicoId,
    String? tecnicoNombre,
    String? titulo,
    String? descripcion,
    String? categoria,
    String? urgencia,
    GeoPoint? ubicacion,
    String? ubicacionTexto,
    String? geohash,
    List<String>? fotos,
    List<String>? fotosThumbs,
    String? estado,
    String? tipoAsignacion,
    bool? seleccionadoPorCliente,
    double? estimacionCosto,
    double? costoFinal,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? asignadoAt,
    DateTime? completadoAt,
  }) {
    return ServiceModel(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      clienteNombre: clienteNombre ?? this.clienteNombre,
      clienteTelefono: clienteTelefono ?? this.clienteTelefono,
      tecnicoId: tecnicoId ?? this.tecnicoId,
      tecnicoNombre: tecnicoNombre ?? this.tecnicoNombre,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      categoria: categoria ?? this.categoria,
      urgencia: urgencia ?? this.urgencia,
      ubicacion: ubicacion ?? this.ubicacion,
      ubicacionTexto: ubicacionTexto ?? this.ubicacionTexto,
      geohash: geohash ?? this.geohash,
      fotos: fotos ?? this.fotos,
      fotosThumbs: fotosThumbs ?? this.fotosThumbs,
      estado: estado ?? this.estado,
      tipoAsignacion: tipoAsignacion ?? this.tipoAsignacion,
      seleccionadoPorCliente: seleccionadoPorCliente ?? this.seleccionadoPorCliente,
      estimacionCosto: estimacionCosto ?? this.estimacionCosto,
      costoFinal: costoFinal ?? this.costoFinal,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      asignadoAt: asignadoAt ?? this.asignadoAt,
      completadoAt: completadoAt ?? this.completadoAt,
    );
  }

  @override
  List<Object?> get props => [
        id, clienteId, clienteNombre, clienteTelefono, tecnicoId,
        tecnicoNombre, titulo, descripcion, categoria, urgencia,
        ubicacion, ubicacionTexto, geohash, fotos, fotosThumbs, estado,
        tipoAsignacion, seleccionadoPorCliente, estimacionCosto,
        costoFinal, createdAt, updatedAt, asignadoAt, completadoAt,
      ];
}
