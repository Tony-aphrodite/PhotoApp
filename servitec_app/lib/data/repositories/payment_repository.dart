import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/transaction_model.dart';
import '../../core/constants/app_constants.dart';

class PaymentRepository {
  final FirebaseFirestore _firestore;

  // Cloud Function URL - update after deploying
  static const String _cloudFunctionBaseUrl =
      'https://us-central1-servicios-domicilio-mvp.cloudfunctions.net';

  PaymentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _transactionsRef =>
      _firestore.collection(AppConstants.transactionsCollection);

  /// Create a PaymentIntent via Cloud Function
  /// Returns the client secret for Stripe
  Future<String> createPaymentIntent({
    required String servicioId,
    required double amount,
    required String currency,
  }) async {
    final response = await http.post(
      Uri.parse('$_cloudFunctionBaseUrl/createPaymentIntent'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'servicioId': servicioId,
        'amount': (amount * 100).round(), // Stripe uses cents
        'currency': currency,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to create payment intent: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['clientSecret'] as String;
  }

  /// Calculate commission breakdown
  CommissionBreakdown calculateCommission({
    required double montoTotal,
    required double porcentajePlataforma,
    double porcentajeStripe = 2.9,
    double fijoStripe = 0.30,
  }) {
    final comisionPlataforma = montoTotal * (porcentajePlataforma / 100);
    final comisionStripe = (montoTotal * (porcentajeStripe / 100)) + fijoStripe;
    final montoTecnico = montoTotal - comisionPlataforma - comisionStripe;

    return CommissionBreakdown(
      montoTotal: montoTotal,
      comisionPlataforma: comisionPlataforma,
      comisionStripe: comisionStripe,
      montoTecnico: montoTecnico,
      porcentajePlataforma: porcentajePlataforma,
    );
  }

  /// Get transactions for a technician
  Stream<List<TransactionModel>> getTechnicianTransactions(String technicianId) {
    return _transactionsRef
        .where('tecnicoId', isEqualTo: technicianId)
        .where('estado', isEqualTo: 'completado')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => TransactionModel.fromFirestore(d)).toList());
  }

  /// Get all transactions (admin)
  Stream<List<TransactionModel>> getAllTransactions({
    DateTime? from,
    DateTime? to,
  }) {
    Query query = _transactionsRef.orderBy('createdAt', descending: true);

    if (from != null) {
      query = query.where('createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(from));
    }
    if (to != null) {
      query =
          query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(to));
    }

    return query.snapshots().map((snap) =>
        snap.docs.map((d) => TransactionModel.fromFirestore(d)).toList());
  }

  /// Get transactions for a technician filtered by period
  Stream<List<TransactionModel>> getTechnicianTransactionsByPeriod(
      String technicianId, EarningPeriod period) {
    Query query = _transactionsRef
        .where('tecnicoId', isEqualTo: technicianId)
        .where('estado', isEqualTo: 'completado')
        .orderBy('createdAt', descending: true);

    final from = _periodStart(period);
    if (from != null) {
      query = query.where('createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(from));
    }

    return query.snapshots().map(
        (snap) => snap.docs.map((d) => TransactionModel.fromFirestore(d)).toList());
  }

  /// Get earning stats for a technician filtered by period
  Future<EarningStats> getTechnicianEarnings(String technicianId,
      {EarningPeriod period = EarningPeriod.all}) async {
    Query query = _transactionsRef
        .where('tecnicoId', isEqualTo: technicianId)
        .where('estado', isEqualTo: 'completado');

    final from = _periodStart(period);
    if (from != null) {
      query = query.where('createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(from));
    }

    final snap = await query.get();

    double totalEarned = 0;
    double totalCommission = 0;
    int totalServices = snap.docs.length;

    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      totalEarned += (data['montoTecnico'] as num?)?.toDouble() ?? 0;
      totalCommission +=
          (data['comisionPlataforma'] as num?)?.toDouble() ?? 0;
    }

    // This month (always shown separately for reference)
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthSnap = await _transactionsRef
        .where('tecnicoId', isEqualTo: technicianId)
        .where('estado', isEqualTo: 'completado')
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
        .get();

    double monthEarned = 0;
    for (final doc in monthSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      monthEarned += (data['montoTecnico'] as num?)?.toDouble() ?? 0;
    }

    return EarningStats(
      totalEarned: totalEarned,
      totalCommission: totalCommission,
      totalServices: totalServices,
      monthEarned: monthEarned,
      monthServices: monthSnap.docs.length,
    );
  }

  /// Get all transactions (admin) filtered by period
  Stream<List<TransactionModel>> getAllTransactionsByPeriod(
      EarningPeriod period) {
    Query query = _transactionsRef
        .where('estado', isEqualTo: 'completado')
        .orderBy('createdAt', descending: true);

    final from = _periodStart(period);
    if (from != null) {
      query = query.where('createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(from));
    }

    return query.snapshots().map(
        (snap) => snap.docs.map((d) => TransactionModel.fromFirestore(d)).toList());
  }

  /// Get platform revenue stats (admin) filtered by period
  Future<PlatformStats> getPlatformStats(
      {EarningPeriod period = EarningPeriod.all}) async {
    Query query =
        _transactionsRef.where('estado', isEqualTo: 'completado');

    final from = _periodStart(period);
    if (from != null) {
      query = query.where('createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(from));
    }

    final snap = await query.get();

    double totalRevenue = 0;
    double totalCommission = 0;
    double totalPaidToTechnicians = 0;
    int totalTransactions = snap.docs.length;

    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      totalRevenue += (data['montoTotal'] as num?)?.toDouble() ?? 0;
      totalCommission +=
          (data['comisionPlataforma'] as num?)?.toDouble() ?? 0;
      totalPaidToTechnicians +=
          (data['montoTecnico'] as num?)?.toDouble() ?? 0;
    }

    // This month
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthSnap = await _transactionsRef
        .where('estado', isEqualTo: 'completado')
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
        .get();

    double monthCommission = 0;
    for (final doc in monthSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      monthCommission +=
          (data['comisionPlataforma'] as num?)?.toDouble() ?? 0;
    }

    return PlatformStats(
      totalRevenue: totalRevenue,
      totalCommission: totalCommission,
      totalPaidToTechnicians: totalPaidToTechnicians,
      totalTransactions: totalTransactions,
      monthCommission: monthCommission,
      monthTransactions: monthSnap.docs.length,
    );
  }

  /// Returns the start DateTime for a given period (null = all time)
  DateTime? _periodStart(EarningPeriod period) {
    final now = DateTime.now();
    switch (period) {
      case EarningPeriod.week:
        // Monday of the current week
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return DateTime(monday.year, monday.month, monday.day);
      case EarningPeriod.month:
        return DateTime(now.year, now.month, 1);
      case EarningPeriod.year:
        return DateTime(now.year, 1, 1);
      case EarningPeriod.all:
        return null;
    }
  }

  /// Update service to payment pending after completion
  Future<void> markServiceForPayment(String servicioId) async {
    await _firestore
        .collection(AppConstants.servicesCollection)
        .doc(servicioId)
        .update({
      'estado': AppConstants.statusPaymentPending,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Record a completed payment (normally done by Cloud Function webhook)
  Future<void> recordPayment({
    required String servicioId,
    required String clienteId,
    required String tecnicoId,
    required double montoTotal,
    required double comisionPlataforma,
    required double comisionStripe,
    required double montoTecnico,
    String? stripePaymentIntentId,
  }) async {
    final batch = _firestore.batch();

    // Create transaction record
    final txRef = _transactionsRef.doc();
    batch.set(txRef, {
      'servicioId': servicioId,
      'clienteId': clienteId,
      'tecnicoId': tecnicoId,
      'montoTotal': montoTotal,
      'comisionPlataforma': comisionPlataforma,
      'comisionStripe': comisionStripe,
      'montoTecnico': montoTecnico,
      'stripePaymentIntentId': stripePaymentIntentId,
      'estado': 'completado',
      'createdAt': Timestamp.now(),
      'completedAt': Timestamp.now(),
    });

    // Update service
    final serviceRef = _firestore
        .collection(AppConstants.servicesCollection)
        .doc(servicioId);
    batch.update(serviceRef, {
      'estado': AppConstants.statusPaid,
      'montoPagado': montoTotal,
      'comisionPlataforma': comisionPlataforma,
      'montoTecnico': montoTecnico,
      'estadoPago': 'pagado',
      'stripePaymentIntentId': stripePaymentIntentId,
      'updatedAt': Timestamp.now(),
    });

    await batch.commit();
  }
}

enum EarningPeriod { week, month, year, all }

extension EarningPeriodLabel on EarningPeriod {
  String get label {
    switch (this) {
      case EarningPeriod.week:
        return 'Esta Semana';
      case EarningPeriod.month:
        return 'Este Mes';
      case EarningPeriod.year:
        return 'Este Año';
      case EarningPeriod.all:
        return 'Todo';
    }
  }
}

class CommissionBreakdown {
  final double montoTotal;
  final double comisionPlataforma;
  final double comisionStripe;
  final double montoTecnico;
  final double porcentajePlataforma;

  const CommissionBreakdown({
    required this.montoTotal,
    required this.comisionPlataforma,
    required this.comisionStripe,
    required this.montoTecnico,
    required this.porcentajePlataforma,
  });
}

class EarningStats {
  final double totalEarned;
  final double totalCommission;
  final int totalServices;
  final double monthEarned;
  final int monthServices;

  const EarningStats({
    required this.totalEarned,
    required this.totalCommission,
    required this.totalServices,
    required this.monthEarned,
    required this.monthServices,
  });
}

class PlatformStats {
  final double totalRevenue;
  final double totalCommission;
  final double totalPaidToTechnicians;
  final int totalTransactions;
  final double monthCommission;
  final int monthTransactions;

  const PlatformStats({
    required this.totalRevenue,
    required this.totalCommission,
    required this.totalPaidToTechnicians,
    required this.totalTransactions,
    required this.monthCommission,
    required this.monthTransactions,
  });
}
