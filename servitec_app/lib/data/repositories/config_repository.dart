import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';

class TarifaInfo {
  final String categoria;
  final String descripcion;
  final double tarifaBase;
  final double multiplicadorUrgente;
  final double recargoPorKm;

  const TarifaInfo({
    required this.categoria,
    required this.descripcion,
    required this.tarifaBase,
    this.multiplicadorUrgente = 1.5,
    this.recargoPorKm = 2.0,
  });

  factory TarifaInfo.fromMap(String key, Map<String, dynamic> data) {
    return TarifaInfo(
      categoria: key,
      descripcion: data['descripcion'] ?? '',
      tarifaBase: (data['tarifaBase'] as num?)?.toDouble() ?? 0.0,
      multiplicadorUrgente:
          (data['multiplicadorUrgente'] as num?)?.toDouble() ?? 1.5,
      recargoPorKm: (data['recargoPorKm'] as num?)?.toDouble() ?? 2.0,
    );
  }
}

class ConfigRepository {
  final FirebaseFirestore _firestore;

  ConfigRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Get all tariffs
  Future<Map<String, TarifaInfo>> getTarifas() async {
    final doc = await _firestore
        .collection(AppConstants.configCollection)
        .doc('tarifas')
        .get();

    if (!doc.exists) return {};

    final data = doc.data() ?? {};
    final tarifas = <String, TarifaInfo>{};

    for (final entry in data.entries) {
      if (entry.value is Map) {
        tarifas[entry.key] = TarifaInfo.fromMap(
          entry.key,
          Map<String, dynamic>.from(entry.value as Map),
        );
      }
    }

    return tarifas;
  }

  // Stream tariffs for real-time updates
  Stream<Map<String, TarifaInfo>> streamTarifas() {
    return _firestore
        .collection(AppConstants.configCollection)
        .doc('tarifas')
        .snapshots()
        .map((doc) {
      if (!doc.exists) return {};

      final data = doc.data() ?? {};
      final tarifas = <String, TarifaInfo>{};

      for (final entry in data.entries) {
        if (entry.value is Map) {
          tarifas[entry.key] = TarifaInfo.fromMap(
            entry.key,
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }

      return tarifas;
    });
  }

  // Calculate cost estimation
  double calculateEstimation({
    required double tarifaBase,
    required String urgencia,
    double distanciaKm = 0,
    double multiplicadorUrgente = 1.5,
    double recargoPorKm = 2.0,
  }) {
    final multiplicador =
        urgencia == AppConstants.urgencyUrgent ? multiplicadorUrgente : 1.0;

    final recargoDistancia = distanciaKm > AppConstants.baseDistanceKm
        ? (distanciaKm - AppConstants.baseDistanceKm) * recargoPorKm
        : 0.0;

    return (tarifaBase * multiplicador) + recargoDistancia;
  }

  // Get commission config
  Future<Map<String, double>> getComisionConfig() async {
    final doc = await _firestore
        .collection(AppConstants.configCollection)
        .doc('comisiones')
        .get();

    if (!doc.exists) {
      return {
        'porcentajePlataforma': 15.0,
        'porcentajeStripe': 2.9,
      };
    }

    final data = doc.data() ?? {};
    return {
      'porcentajePlataforma':
          (data['porcentajePlataforma'] as num?)?.toDouble() ?? 15.0,
      'porcentajeStripe':
          (data['porcentajeStripe'] as num?)?.toDouble() ?? 2.9,
    };
  }

  // Update tariff (admin)
  Future<void> updateTarifa(
      String categoria, Map<String, dynamic> data) async {
    await _firestore
        .collection(AppConstants.configCollection)
        .doc('tarifas')
        .update({categoria: data});
  }
}
