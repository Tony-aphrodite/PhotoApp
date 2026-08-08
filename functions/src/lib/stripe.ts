/**
 * Stripe client + platform commission helpers.
 *
 * Env (see .env.example):
 *   STRIPE_SECRET_KEY        — sk_test_... / sk_live_...
 *   PLATFORM_COMMISSION_PCT  — integer percentage retained by ServiTec (default 12)
 */

import Stripe from 'stripe';

const secretKey = process.env.STRIPE_SECRET_KEY;

if (!secretKey) {
  // Don't throw at module load — that would break `firebase deploy`'s function
  // discovery pass on a machine without .env. The first real API call fails
  // with a clear Stripe auth error instead.
  // eslint-disable-next-line no-console
  console.warn('STRIPE_SECRET_KEY is not set — Stripe calls will fail.');
}

/** Shared Stripe client. `apiVersion` is intentionally omitted so the SDK
 * uses the version it was built against (avoids a pinned-literal type error
 * whenever the stripe package is bumped). */
export const stripe = new Stripe(secretKey || 'sk_test_unconfigured');

/** Percentage of the gross service price that ServiTec retains. */
export const platformCommissionPct: number = (() => {
  const raw = Number(process.env.PLATFORM_COMMISSION_PCT);
  return Number.isFinite(raw) && raw > 0 && raw < 100 ? raw : 12;
})();

/**
 * Platform fee for a charge, in centavos.
 *
 * @param amountCentavos gross charge amount in centavos (integer)
 * @returns the `application_fee_amount` to pass to Stripe (integer centavos)
 */
export function applicationFeeCentavos(amountCentavos: number): number {
  return Math.round(amountCentavos * (platformCommissionPct / 100));
}
