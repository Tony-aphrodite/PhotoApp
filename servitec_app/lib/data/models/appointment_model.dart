import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class AppointmentModel extends Equatable {
  final String id;
  final String servicioId;
  final String tecnicoId;
  final String clienteId;
  final DateTime fechaHora;
  final int duracionMinutos;
  final String estado; // programada, confirmada, completada, cancelada, no_asistio
  final String tipo; // taller, domicilio
  final String? notas;

  const AppointmentModel({
    required this.id,
    required this.servicioId,
    required this.tecnicoId,
    required this.clienteId,
    required this.fechaHora,
    required this.duracionMinutos,
    required this.estado,
    required this.tipo,
    this.notas,
  });

  factory AppointmentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppointmentModel(
      id: doc.id,
      servicioId: data['servicioId'] ?? '',
      tecnicoId: data['tecnicoId'] ?? '',
      clienteId: data['clienteId'] ?? '',
      fechaHora: (data['fechaHora'] as Timestamp?)?.toDate() ?? DateTime.now(),
      duracionMinutos: data['duracionMinutos'] ?? 60,
      estado: data['estado'] ?? 'programada',
      tipo: data['tipo'] ?? 'domicilio',
      notas: data['notas'],
    );
  }

  Map<String, dynamic> toFirestore() => {
        'servicioId': servicioId,
        'tecnicoId': tecnicoId,
        'clienteId': clienteId,
        'fechaHora': Timestamp.fromDate(fechaHora),
        'duracionMinutos': duracionMinutos,
        'estado': estado,
        'tipo': tipo,
        if (notas != null) 'notas': notas,
      };

  DateTime get endTime => fechaHora.add(Duration(minutes: duracionMinutos));

  @override
  List<Object?> get props =>
      [id, servicioId, tecnicoId, clienteId, fechaHora, estado];
}
