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

  // ── In-memory cache ──────────────────────────────────────────────────────
  Map<String, TarifaInfo>? _tarifasCache;
  DateTime? _tarifasCachedAt;
  static const _tarifasCacheTtl = Duration(hours: 24);

  Map<String, double>? _comisionCache;
  DateTime? _comisionCachedAt;
  static const _comisionCacheTtl = Duration(hours: 1);
  // ─────────────────────────────────────────────────────────────────────────

  /// Get all tariffs — cached for 24 hours
  Future<Map<String, TarifaInfo>> getTarifas() async {
    final now = DateTime.now();
    if (_tarifasCache != null &&
        _tarifasCachedAt != null &&
        now.difference(_tarifasCachedAt!) < _tarifasCacheTtl) {
      return _tarifasCache!;
    }

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

    _tarifasCache = tarifas;
    _tarifasCachedAt = now;
    return tarifas;
  }

  /// Invalidate tariff cache (call after admin updates a tariff)
  void invalidateTarifasCache() {
    _tarifasCache = null;
    _tarifasCachedAt = null;
  }

  // Stream tariffs for real-time updates (bypasses cache — used in admin screens)
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

      // Keep cache in sync with stream updates
      _tarifasCache = tarifas;
      _tarifasCachedAt = DateTime.now();

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

  /// Get commission config — cached for 1 hour
  Future<Map<String, double>> getComisionConfig() async {
    final now = DateTime.now();
    if (_comisionCache != null &&
        _comisionCachedAt != null &&
        now.difference(_comisionCachedAt!) < _comisionCacheTtl) {
      return _comisionCache!;
    }

    final doc = await _firestore
        .collection(AppConstants.configCollection)
        .doc('comisiones')
        .get();

    Map<String, double> result;

    if (!doc.exists) {
      result = {
        'porcentajePlataforma': 15.0,
        'porcentajeStripe': 2.9,
      };
    } else {
      final data = doc.data() ?? {};
      result = {
        'porcentajePlataforma':
            (data['porcentajePlataforma'] as num?)?.toDouble() ?? 15.0,
        'porcentajeStripe':
            (data['porcentajeStripe'] as num?)?.toDouble() ?? 2.9,
      };
    }

    _comisionCache = result;
    _comisionCachedAt = now;
    return result;
  }

  /// Invalidate commission cache (call after admin updates commission rate)
  void invalidateComisionCache() {
    _comisionCache = null;
    _comisionCachedAt = null;
  }

  // Update tariff (admin) — also invalidates cache
  Future<void> updateTarifa(
      String categoria, Map<String, dynamic> data) async {
    await _firestore
        .collection(AppConstants.configCollection)
        .doc('tarifas')
        .update({categoria: data});
    invalidateTarifasCache();
  }

  // Update commission rate (admin) — also invalidates cache
  Future<void> updateComision(double porcentajePlataforma) async {
    await _firestore
        .collection(AppConstants.configCollection)
        .doc('comisiones')
        .set({'porcentajePlataforma': porcentajePlataforma}, SetOptions(merge: true));
    invalidateComisionCache();
  }
}
