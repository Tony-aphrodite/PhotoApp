import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class MessageModel extends Equatable {
  final String id;
  final String userId;
  final String nombreUsuario;
  final String mensaje;
  final DateTime timestamp;
  final bool leido;
  final String tipo; // 'texto' | 'sistema'

  const MessageModel({
    required this.id,
    required this.userId,
    required this.nombreUsuario,
    required this.mensaje,
    required this.timestamp,
    this.leido = false,
    this.tipo = 'texto',
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      nombreUsuario: data['nombreUsuario'] ?? '',
      mensaje: data['mensaje'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      leido: data['leido'] ?? false,
      tipo: data['tipo'] ?? 'texto',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'nombreUsuario': nombreUsuario,
      'mensaje': mensaje,
      'timestamp': Timestamp.fromDate(timestamp),
      'leido': leido,
      'tipo': tipo,
    };
  }

  @override
  List<Object?> get props => [id, userId, nombreUsuario, mensaje, timestamp, leido, tipo];
}
