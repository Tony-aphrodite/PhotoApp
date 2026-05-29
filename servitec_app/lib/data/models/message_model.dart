import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class MessageModel extends Equatable {
  static const String tipoTexto = 'texto';
  static const String tipoImagen = 'imagen';
  static const String tipoSistema = 'sistema';

  final String id;
  final String userId;
  final String nombreUsuario;
  final String mensaje;
  final DateTime timestamp;
  final bool leido;
  final String tipo;
  final String? imageData;
  final Map<String, dynamic>? metadata;

  const MessageModel({
    required this.id,
    required this.userId,
    required this.nombreUsuario,
    required this.mensaje,
    required this.timestamp,
    this.leido = false,
    this.tipo = tipoTexto,
    this.imageData,
    this.metadata,
  });

  bool get isImage => tipo == tipoImagen;
  bool get isSystem => tipo == tipoSistema;

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      nombreUsuario: data['nombreUsuario'] ?? '',
      mensaje: data['mensaje'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      leido: data['leido'] ?? false,
      tipo: data['tipo'] ?? tipoTexto,
      imageData: data['imageData'],
      metadata: data['metadata'] != null
          ? Map<String, dynamic>.from(data['metadata'])
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'userId': userId,
      'nombreUsuario': nombreUsuario,
      'mensaje': mensaje,
      'timestamp': Timestamp.fromDate(timestamp),
      'leido': leido,
      'tipo': tipo,
    };
    if (imageData != null) map['imageData'] = imageData;
    if (metadata != null) map['metadata'] = metadata;
    return map;
  }

  @override
  List<Object?> get props =>
      [id, userId, nombreUsuario, mensaje, timestamp, leido, tipo, imageData, metadata];
}
