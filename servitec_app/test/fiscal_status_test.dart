import 'package:flutter_test/flutter_test.dart';
import 'package:servitec_app/core/utils/fiscal_status.dart';
import 'package:servitec_app/data/models/facturapi_ref.dart';

void main() {
  final now = DateTime(2026, 7, 9, 12, 0);

  group('FiscalStatus.initial + initialGraceExpiry', () {
    test('new técnico starts in grace_period status', () {
      final ref = FiscalStatus.initial(now: now);
      expect(ref.status, FacturapiRef.statusGracePeriod);
      expect(ref.organizationId, isNull);
      expect(ref.csdUploadedAt, isNull);
    });

    test('initial grace expiry is exactly 60 days after now', () {
      final expiry = FiscalStatus.initialGraceExpiry(now: now);
      final diff = expiry.difference(now).inDays;
      expect(diff, FiscalStatus.graceDays);
      expect(diff, 60);
    });
  });

  group('FiscalStatus.graceExpired', () {
    test('null graciaExpiraAt is not expired (unset)', () {
      expect(
        FiscalStatus.graceExpired(graciaExpiraAt: null, now: now),
        isFalse,
      );
    });

    test('future expiry means not expired', () {
      final future = now.add(const Duration(days: 5));
      expect(
        FiscalStatus.graceExpired(graciaExpiraAt: future, now: now),
        isFalse,
      );
    });

    test('past expiry means expired', () {
      final past = now.subtract(const Duration(days: 1));
      expect(
        FiscalStatus.graceExpired(graciaExpiraAt: past, now: now),
        isTrue,
      );
    });

    test('exactly now counts as expired (boundary)', () {
      expect(
        FiscalStatus.graceExpired(graciaExpiraAt: now, now: now),
        isTrue,
      );
    });
  });

  group('FiscalStatus.daysRemaining', () {
    test('null expiry returns 0', () {
      expect(
        FiscalStatus.daysRemaining(graciaExpiraAt: null, now: now),
        0,
      );
    });

    test('30 days in the future returns 30', () {
      expect(
        FiscalStatus.daysRemaining(
          graciaExpiraAt: now.add(const Duration(days: 30)),
          now: now,
        ),
        30,
      );
    });

    test('past expiry returns 0, not negative', () {
      expect(
        FiscalStatus.daysRemaining(
          graciaExpiraAt: now.subtract(const Duration(days: 5)),
          now: now,
        ),
        0,
      );
    });
  });

  group('FiscalStatus.resolveDisplay', () {
    const active = FacturapiRef(status: FacturapiRef.statusActive);
    const suspended = FacturapiRef(status: FacturapiRef.statusSuspended);
    const grace = FacturapiRef(status: FacturapiRef.statusGracePeriod);
    const pendingCsd = FacturapiRef(status: FacturapiRef.statusPendingCsd);

    test('null ref → needsSetup', () {
      final d = FiscalStatus.resolveDisplay(
        ref: null,
        graciaExpiraAt: null,
        now: now,
      );
      expect(d, FiscalDisplay.needsSetup);
    });

    test('active ref → active', () {
      final d = FiscalStatus.resolveDisplay(
        ref: active,
        graciaExpiraAt: null,
        now: now,
      );
      expect(d, FiscalDisplay.active);
    });

    test('suspended ref → suspended', () {
      final d = FiscalStatus.resolveDisplay(
        ref: suspended,
        graciaExpiraAt: null,
        now: now,
      );
      expect(d, FiscalDisplay.suspended);
    });

    test('grace_period + expiry in future → needsSetup', () {
      final d = FiscalStatus.resolveDisplay(
        ref: grace,
        graciaExpiraAt: now.add(const Duration(days: 30)),
        now: now,
      );
      expect(d, FiscalDisplay.needsSetup);
    });

    test('grace_period + expiry in past → graceExpired', () {
      final d = FiscalStatus.resolveDisplay(
        ref: grace,
        graciaExpiraAt: now.subtract(const Duration(days: 1)),
        now: now,
      );
      expect(d, FiscalDisplay.graceExpired);
    });

    test('pending_csd + expiry in past → graceExpired', () {
      final d = FiscalStatus.resolveDisplay(
        ref: pendingCsd,
        graciaExpiraAt: now.subtract(const Duration(days: 1)),
        now: now,
      );
      expect(d, FiscalDisplay.graceExpired);
    });

    test('pending_csd + expiry in future → needsSetup', () {
      final d = FiscalStatus.resolveDisplay(
        ref: pendingCsd,
        graciaExpiraAt: now.add(const Duration(days: 30)),
        now: now,
      );
      expect(d, FiscalDisplay.needsSetup);
    });
  });

  group('FacturapiRef serialization round-trip', () {
    test('minimal → toMap → fromMap preserves status', () {
      const original = FacturapiRef(status: FacturapiRef.statusActive);
      final map = original.toMap();
      expect(map['status'], 'active');
      // Round-trip via a synthetic map (no need for Firestore snapshot).
      final rebuilt = FacturapiRef.fromMap(map);
      expect(rebuilt.status, original.status);
      expect(rebuilt.organizationId, isNull);
    });

    test('full → toMap → fromMap round-trips', () {
      final uploaded = DateTime(2026, 3, 1);
      final expires = DateTime(2030, 3, 1);
      final original = FacturapiRef(
        organizationId: 'org_abc',
        csdUploadedAt: uploaded,
        csdExpiresAt: expires,
        status: FacturapiRef.statusActive,
      );
      final map = original.toMap();
      final rebuilt = FacturapiRef.fromMap(map);
      expect(rebuilt.organizationId, 'org_abc');
      expect(rebuilt.status, 'active');
      expect(rebuilt.csdUploadedAt, uploaded);
      expect(rebuilt.csdExpiresAt, expires);
    });
  });
}
