import 'package:flutter_test/flutter_test.dart';
import 'package:servitec_app/core/services/analytics_service.dart';

/// Pure-constants test. We don't invoke FirebaseAnalytics methods here (that
/// requires platform-channel mocking that adds no signal) — instead we lock
/// down the event name / user-property schema so future edits can't silently
/// break the marketing agency's dashboards.
void main() {
  group('AnalyticsService event names — GA4 spec compliance', () {
    // GA4 event names must:
    //  - be 1–40 chars
    //  - contain only letters, digits, underscores
    //  - start with a letter
    //  - use snake_case (convention, enforced here for consistency)
    final validGa4 = RegExp(r'^[a-z][a-z0-9_]{0,39}$');

    final events = <String, String>{
      'eventSignUp': AnalyticsService.eventSignUp,
      'eventLogin': AnalyticsService.eventLogin,
      'eventPurchase': AnalyticsService.eventPurchase,
      'eventServiceRequested': AnalyticsService.eventServiceRequested,
      'eventTechnicianAssigned': AnalyticsService.eventTechnicianAssigned,
      'eventQuotationSent': AnalyticsService.eventQuotationSent,
      'eventQuotationApproved': AnalyticsService.eventQuotationApproved,
      'eventQuotationRejected': AnalyticsService.eventQuotationRejected,
      'eventServiceStarted': AnalyticsService.eventServiceStarted,
      'eventServiceCompleted': AnalyticsService.eventServiceCompleted,
      'eventServiceCancelled': AnalyticsService.eventServiceCancelled,
      'eventFiscalOnboardingCompleted':
          AnalyticsService.eventFiscalOnboardingCompleted,
    };

    for (final entry in events.entries) {
      test('${entry.key} = "${entry.value}" is valid GA4 event name', () {
        expect(validGa4.hasMatch(entry.value), isTrue,
            reason: '${entry.value} must match ${validGa4.pattern}');
      });
    }

    test('all event constants are unique (no accidental duplicates)', () {
      final values = events.values.toList();
      final unique = values.toSet();
      expect(unique.length, values.length,
          reason: 'Duplicate event name found — collisions destroy funnel data.');
    });
  });

  group('GA4 built-in event names match spec exactly', () {
    // If these drift, GA4's automatic revenue / conversion reports break.
    test('sign_up is the GA4 built-in name', () {
      expect(AnalyticsService.eventSignUp, 'sign_up');
    });

    test('login is the GA4 built-in name', () {
      expect(AnalyticsService.eventLogin, 'login');
    });

    test('purchase is the GA4 built-in name (revenue reporting)', () {
      expect(AnalyticsService.eventPurchase, 'purchase');
    });
  });

  group('User property names — GA4 spec compliance', () {
    // GA4 user-property names have the same rules as event names.
    final validGa4 = RegExp(r'^[a-z][a-z0-9_]{0,23}$');

    final props = <String, String>{
      'userPropRole': AnalyticsService.userPropRole,
      'userPropTechStatus': AnalyticsService.userPropTechStatus,
      'userPropCity': AnalyticsService.userPropCity,
    };

    for (final entry in props.entries) {
      test('${entry.key} = "${entry.value}" is valid GA4 user property', () {
        expect(validGa4.hasMatch(entry.value), isTrue,
            reason: '${entry.value} must be snake_case ≤24 chars.');
      });
    }
  });
}
