import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class QuotationItem {
  final String descripcion;
  final String tipo; // mano_obra, material, pieza
  final int cantidad;
  final double precioUnitario;
  final double subtotal;

  const QuotationItem({
    required this.descripcion,
    required this.tipo,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
  });

  factory QuotationItem.fromMap(Map<String, dynamic> data) {
    return QuotationItem(
      descripcion: data['descripcion'] ?? '',
      tipo: data['tipo'] ?? 'material',
      cantidad: data['cantidad'] ?? 1,
      precioUnitario: (data['precioUnitario'] as num?)?.toDouble() ?? 0,
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'descripcion': descripcion,
        'tipo': tipo,
        'cantidad': cantidad,
        'precioUnitario': precioUnitario,
        'subtotal': subtotal,
      };
}

class QuotationModel extends Equatable {
  final String id;
  final String servicioId;
  final String tecnicoId;
  final List<QuotationItem> items;
  final double subtotal;
  final double impuestos;
  final double total;
  final String estado; // pendiente, aprobada, rechazada
  final String? notasTecnico;
  final List<String> fotosDiagnostico;
  final DateTime fechaCreacion;
  final DateTime? fechaRespuesta;

  const QuotationModel({
    required this.id,
    required this.servicioId,
    required this.tecnicoId,
    required this.items,
    required this.subtotal,
    required this.impuestos,
    required this.total,
    required this.estado,
    this.notasTecnico,
    this.fotosDiagnostico = const [],
    required this.fechaCreacion,
    this.fechaRespuesta,
  });

  factory QuotationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return QuotationModel(
      id: doc.id,
      servicioId: data['servicioId'] ?? '',
      tecnicoId: data['tecnicoId'] ?? '',
      items: (data['items'] as List?)
              ?.map((e) => QuotationItem.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0,
      impuestos: (data['impuestos'] as num?)?.toDouble() ?? 0,
      total: (data['total'] as num?)?.toDouble() ?? 0,
      estado: data['estado'] ?? 'pendiente',
      notasTecnico: data['notasTecnico'],
      fotosDiagnostico: data['fotosDiagnostico'] != null
          ? List<String>.from(data['fotosDiagnostico'])
          : [],
      fechaCreacion:
          (data['fechaCreacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fechaRespuesta: (data['fechaRespuesta'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'servicioId': servicioId,
        'tecnicoId': tecnicoId,
        'items': items.map((e) => e.toMap()).toList(),
        'subtotal': subtotal,
        'impuestos': impuestos,
        'total': total,
        'estado': estado,
        'notasTecnico': notasTecnico,
        'fotosDiagnostico': fotosDiagnostico,
        'fechaCreacion': Timestamp.fromDate(fechaCreacion),
        if (fechaRespuesta != null)
          'fechaRespuesta': Timestamp.fromDate(fechaRespuesta!),
      };

  @override
  List<Object?> get props => [id, servicioId, tecnicoId, total, estado];
}
