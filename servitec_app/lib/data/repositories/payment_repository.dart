import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/transaction_model.dart';
import '../../core/constants/app_constants.dart';

class PaymentRepository {
  final FirebaseFirestore _firestore;

  // Derived from the Firebase project the app was built against, so a dev
  // build calls servitec-dev's functions and a prod build calls prod's.
  static String get _cloudFunctionBaseUrl =>
      'https://us-central1-${Firebase.app().options.projectId}.cloudfunctions.net';

  PaymentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _transactionsRef =>
      _firestore.collection(AppConstants.transactionsCollection);

  /// Create a PaymentIntent via Cloud Function. Returns the `clientSecret`
  /// used to present Stripe's PaymentSheet.
  ///
  /// There is deliberately no client-side bookkeeping after a payment: the
  /// transaction row and the `pagado` state are written only by the Stripe
  /// webhook (on-payment-succeeded), which firestore.rules reserve them for.
  ///
  /// The server decides the amount from the service itself; the app only says
  /// which service. The ID token proves who is paying — the function refuses
  /// anyone but the service's cliente.
  Future<PaymentIntentCreation> createPaymentIntent({
    required String servicioId,
  }) async {
    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (idToken == null) throw const PaymentException('Debes iniciar sesión.');

    final response = await http.post(
      Uri.parse('$_cloudFunctionBaseUrl/createPaymentIntent'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'servicioId': servicioId}),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw PaymentException(
        (data['error'] as String?) ?? 'No se pudo iniciar el pago.',
      );
    }

    return PaymentIntentCreation(
      clientSecret: data['clientSecret'] as String,
      paymentIntentId: data['paymentIntentId'] as String,
      amountMxn: (data['amount'] as num).toDouble() / 100,
    );
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
}

/// Result of [PaymentRepository.createPaymentIntent].
class PaymentIntentCreation {
  final String clientSecret;
  final String paymentIntentId;

  /// What Stripe will actually charge, as decided by the server.
  final double amountMxn;

  const PaymentIntentCreation({
    required this.clientSecret,
    required this.paymentIntentId,
    required this.amountMxn,
  });
}

/// A payment could not be started; [message] is safe to show the user.
class PaymentException implements Exception {
  final String message;
  const PaymentException(this.message);

  @override
  String toString() => message;
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
