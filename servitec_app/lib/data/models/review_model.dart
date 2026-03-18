import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class ReviewModel extends Equatable {
  final String id;
  final String servicioId;
  final String clienteId;
  final String tecnicoId;
  final int calificacion;
  final String comentario;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ReviewModel({
    required this.id,
    required this.servicioId,
    required this.clienteId,
    required this.tecnicoId,
    required this.calificacion,
    required this.comentario,
    required this.createdAt,
    this.updatedAt,
  });

  factory ReviewModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReviewModel(
      id: doc.id,
      servicioId: data['servicioId'] ?? '',
      clienteId: data['clienteId'] ?? '',
      tecnicoId: data['tecnicoId'] ?? '',
      calificacion: data['calificacion'] ?? 0,
      comentario: data['comentario'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'servicioId': servicioId,
      'clienteId': clienteId,
      'tecnicoId': tecnicoId,
      'calificacion': calificacion,
      'comentario': comentario,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  @override
  List<Object?> get props => [id, servicioId, clienteId, tecnicoId, calificacion, comentario, createdAt];
}
