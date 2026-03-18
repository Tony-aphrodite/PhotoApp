import 'package:cloud_firestore/cloud_firestore.dart';
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
  final List<String> fotos;
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
  });

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
        ubicacion, ubicacionTexto, geohash, fotos, estado,
        tipoAsignacion, seleccionadoPorCliente, estimacionCosto,
        costoFinal, createdAt, updatedAt, asignadoAt, completadoAt,
      ];
}
