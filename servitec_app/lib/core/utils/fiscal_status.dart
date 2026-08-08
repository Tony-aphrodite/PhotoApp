import '../../data/models/facturapi_ref.dart';

/// Pure logic for the technician fiscal / CSD state machine.
///
/// Rules (final policy from 2026-07-09):
/// - New técnicos get a grace period of 60 days from onboarding.
/// - During grace they can work, but a warning banner reminds them to complete
///   fiscal setup so CFDIs can be issued.
/// - Once CSD is successfully uploaded → status becomes [FacturapiRef.statusActive].
/// - If grace expires without a valid CSD → status becomes [FacturapiRef.statusSuspended]
///   (a daily Cloud Function performs the transition — see grace-period cron).
///
/// The technician's home banner uses [resolveDisplay] to decide what to show.
class FiscalStatus {
  FiscalStatus._();

  /// Number of days a técnico has to complete fiscal onboarding before suspension.
  static const int graceDays = 60;

  /// Computes the initial [FacturapiRef] to write on a new técnico signup.
  static FacturapiRef initial({required DateTime now}) => FacturapiRef(
        status: FacturapiRef.statusGracePeriod,
      );

  /// Computes the initial `graciaExpiraAt` value to store on the user document.
  static DateTime initialGraceExpiry({required DateTime now}) =>
      now.add(const Duration(days: graceDays));

  /// True if the grace period has expired at [now].
  static bool graceExpired({
    required DateTime? graciaExpiraAt,
    required DateTime now,
  }) =>
      graciaExpiraAt != null && !now.isBefore(graciaExpiraAt);

  /// Returns the display-level state the UI should render.
  ///
  /// Independent of the raw `status` string so the UI has one branch to switch on.
  static FiscalDisplay resolveDisplay({
    required FacturapiRef? ref,
    required DateTime? graciaExpiraAt,
    required DateTime now,
  }) {
    if (ref == null) return FiscalDisplay.needsSetup;
    if (ref.isSuspended) return FiscalDisplay.suspended;
    if (ref.isActive) return FiscalDisplay.active;
    // Grace period or pending_csd. Distinguish by grace expiry.
    if (graceExpired(graciaExpiraAt: graciaExpiraAt, now: now)) {
      return FiscalDisplay.graceExpired;
    }
    return FiscalDisplay.needsSetup;
  }

  /// Days remaining in the grace period (0 if expired or unset).
  static int daysRemaining({
    required DateTime? graciaExpiraAt,
    required DateTime now,
  }) {
    if (graciaExpiraAt == null) return 0;
    final diff = graciaExpiraAt.difference(now).inDays;
    return diff < 0 ? 0 : diff;
  }
}

enum FiscalDisplay {
  /// Fiscal profile not started or CSD not uploaded, within grace — show CTA banner.
  needsSetup,

  /// Grace expired, CSD still missing — home is blocked until a Cloud Function
  /// runs the daily transition to `suspended`, or admin intervenes.
  graceExpired,

  /// Everything set up correctly, técnico can issue CFDIs.
  active,

  /// Admin-suspended or auto-suspended after grace — blocks new services.
  suspended,
}
