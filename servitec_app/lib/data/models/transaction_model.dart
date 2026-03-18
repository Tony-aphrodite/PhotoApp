import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class TransactionModel extends Equatable {
  final String id;
  final String servicioId;
  final String clienteId;
  final String tecnicoId;
  final double montoTotal;
  final double comisionPlataforma;
  final double comisionStripe;
  final double montoTecnico;
  final String? stripePaymentIntentId;
  final String? stripeChargeId;
  final String estado; // pendiente, completado, fallido, reembolsado
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? metodoPago;
  final String? ultimos4Digitos;
  final String? marcaTarjeta;

  const TransactionModel({
    required this.id,
    required this.servicioId,
    required this.clienteId,
    required this.tecnicoId,
    required this.montoTotal,
    required this.comisionPlataforma,
    required this.comisionStripe,
    required this.montoTecnico,
    this.stripePaymentIntentId,
    this.stripeChargeId,
    required this.estado,
    required this.createdAt,
    this.completedAt,
    this.metodoPago,
    this.ultimos4Digitos,
    this.marcaTarjeta,
  });

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      servicioId: data['servicioId'] ?? '',
      clienteId: data['clienteId'] ?? '',
      tecnicoId: data['tecnicoId'] ?? '',
      montoTotal: (data['montoTotal'] as num?)?.toDouble() ?? 0,
      comisionPlataforma: (data['comisionPlataforma'] as num?)?.toDouble() ?? 0,
      comisionStripe: (data['comisionStripe'] as num?)?.toDouble() ?? 0,
      montoTecnico: (data['montoTecnico'] as num?)?.toDouble() ?? 0,
      stripePaymentIntentId: data['stripePaymentIntentId'],
      stripeChargeId: data['stripeChargeId'],
      estado: data['estado'] ?? 'pendiente',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      metodoPago: data['metadata']?['metodoPago'],
      ultimos4Digitos: data['metadata']?['ultimos4Digitos'],
      marcaTarjeta: data['metadata']?['marcaTarjeta'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'servicioId': servicioId,
      'clienteId': clienteId,
      'tecnicoId': tecnicoId,
      'montoTotal': montoTotal,
      'comisionPlataforma': comisionPlataforma,
      'comisionStripe': comisionStripe,
      'montoTecnico': montoTecnico,
      'stripePaymentIntentId': stripePaymentIntentId,
      'stripeChargeId': stripeChargeId,
      'estado': estado,
      'createdAt': Timestamp.fromDate(createdAt),
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
      'metadata': {
        if (metodoPago != null) 'metodoPago': metodoPago,
        if (ultimos4Digitos != null) 'ultimos4Digitos': ultimos4Digitos,
        if (marcaTarjeta != null) 'marcaTarjeta': marcaTarjeta,
      },
    };
  }

  @override
  List<Object?> get props => [
        id, servicioId, clienteId, tecnicoId, montoTotal,
        comisionPlataforma, comisionStripe, montoTecnico, estado, createdAt,
      ];
}
