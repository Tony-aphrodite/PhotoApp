import 'package:firebase_analytics/firebase_analytics.dart';

/// Central wrapper around FirebaseAnalytics with typed methods for every
/// event the app emits. Purposes:
///
/// - **One source of truth for event names / param keys.** Prevents typos
///   from silently splitting funnel data.
/// - **Marketing-ready schema.** Uses GA4 built-in events where available
///   (`sign_up`, `purchase`) so they light up out of the box in Firebase
///   Analytics, Google Ads conversion tracking, and any MMP that maps
///   from Firebase (AppsFlyer OneLink, Adjust integration, etc.).
/// - **Thin abstraction.** Later we swap in an MMP SDK (AppsFlyer/Adjust)
///   by adding parallel calls inside these methods — every call site
///   already funnels through here.
///
/// See marketing-agency plan (Phase A) in the delivery notes.
class AnalyticsService {
  AnalyticsService._();

  static final _analytics = FirebaseAnalytics.instance;

  // --- Event names (GA4-compatible; snake_case) ---
  // Built-in GA4 event names — trigger special reporting behavior.
  static const eventSignUp = 'sign_up';          // GA4 built-in
  static const eventLogin = 'login';             // GA4 built-in
  static const eventPurchase = 'purchase';       // GA4 built-in (revenue)

  // Custom events — funnel & product analytics.
  static const eventServiceRequested = 'service_requested';
  static const eventTechnicianAssigned = 'technician_assigned';
  static const eventQuotationSent = 'quotation_sent';
  static const eventQuotationApproved = 'quotation_approved';
  static const eventQuotationRejected = 'quotation_rejected';
  static const eventServiceStarted = 'service_started';
  static const eventServiceCompleted = 'service_completed';
  static const eventServiceCancelled = 'service_cancelled';
  static const eventFiscalOnboardingCompleted = 'fiscal_onboarding_completed';

  // --- User property names ---
  static const userPropRole = 'role';
  static const userPropTechStatus = 'technician_status';
  static const userPropCity = 'city';

  // --- Session / identity ---

  static Future<void> setUserId(String? uid) => _analytics.setUserId(id: uid);

  static Future<void> setRole(String role) =>
      _analytics.setUserProperty(name: userPropRole, value: role);

  static Future<void> setTechnicianStatus(String? status) =>
      _analytics.setUserProperty(name: userPropTechStatus, value: status);

  static Future<void> setCity(String? city) =>
      _analytics.setUserProperty(name: userPropCity, value: city);

  // --- Auth events ---

  /// Fires after successful account creation. [role] should be
  /// 'cliente' | 'tecnico' | 'admin'.
  static Future<void> logSignUp({required String role}) => _analytics.logSignUp(
        signUpMethod: 'email',
        parameters: {'role': role},
      );

  static Future<void> logLogin({String method = 'email'}) =>
      _analytics.logLogin(loginMethod: method);

  // --- Service lifecycle ---

  static Future<void> logServiceRequested({
    required String servicioId,
    required String categoria,
    required String urgencia,
    double? estimacionCosto,
  }) =>
      _analytics.logEvent(name: eventServiceRequested, parameters: {
        'service_id': servicioId,
        'category': categoria,
        'urgency': urgencia,
        if (estimacionCosto != null) 'estimated_cost': estimacionCosto,
      });

  static Future<void> logTechnicianAssigned({
    required String servicioId,
    required String tipoAsignacion,
  }) =>
      _analytics.logEvent(name: eventTechnicianAssigned, parameters: {
        'service_id': servicioId,
        'assignment_type': tipoAsignacion,
      });

  static Future<void> logQuotationSent({
    required String servicioId,
    required double total,
  }) =>
      _analytics.logEvent(name: eventQuotationSent, parameters: {
        'service_id': servicioId,
        'total': total,
      });

  static Future<void> logQuotationApproved({
    required String servicioId,
    required double total,
  }) =>
      _analytics.logEvent(name: eventQuotationApproved, parameters: {
        'service_id': servicioId,
        'total': total,
      });

  static Future<void> logQuotationRejected({
    required String servicioId,
  }) =>
      _analytics.logEvent(name: eventQuotationRejected, parameters: {
        'service_id': servicioId,
      });

  static Future<void> logServiceStarted({required String servicioId}) =>
      _analytics.logEvent(name: eventServiceStarted, parameters: {
        'service_id': servicioId,
      });

  static Future<void> logServiceCompleted({required String servicioId}) =>
      _analytics.logEvent(name: eventServiceCompleted, parameters: {
        'service_id': servicioId,
      });

  static Future<void> logServiceCancelled({
    required String servicioId,
    String? reason,
  }) =>
      _analytics.logEvent(name: eventServiceCancelled, parameters: {
        'service_id': servicioId,
        if (reason != null) 'reason': reason,
      });

  // --- Revenue ---

  /// GA4 built-in `purchase` event. Reports as revenue automatically in
  /// Firebase Analytics + GA4 + any linked MMP.
  static Future<void> logPurchase({
    required String servicioId,
    required double amount,
    String currency = 'MXN',
    double? platformCommission,
  }) =>
      _analytics.logPurchase(
        transactionId: servicioId,
        value: amount,
        currency: currency,
        parameters: {
          'service_id': servicioId,
          if (platformCommission != null)
            'platform_commission': platformCommission,
        },
      );

  // --- Onboarding / fiscal ---

  static Future<void> logFiscalOnboardingCompleted({
    required String regimenFiscal,
  }) =>
      _analytics.logEvent(name: eventFiscalOnboardingCompleted, parameters: {
        'regimen_fiscal': regimenFiscal,
      });

  // --- Route observer (auto screen tracking) ---
  //
  // Attach in app_router.dart with `observers: [AnalyticsService.observer]`
  // once route tracking is desired. Kept out of the router by default so we
  // don't accidentally log every internal navigation as a screen view.
  static FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);
}
