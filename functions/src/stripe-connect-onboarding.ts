/**
 * Callable Cloud Function that returns a Stripe-hosted onboarding URL for a
 * técnico to link their Stripe Connect account (KYC, bank account, etc.).
 *
 * Flow:
 *   1. If the técnico doesn't have a Stripe Connect account yet, create one
 *      (Standard account, Mexico) and store its id on the user document.
 *   2. Generate a fresh account link — these are single-use, short-lived URLs.
 *   3. Return the URL for the Flutter app to open in a webview / external browser.
 *
 * The técnico completes Stripe's own hosted onboarding (identity docs, bank
 * account, etc.). After completion Stripe redirects back to the app.
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { db } from './lib/admin';
import { stripe } from './lib/stripe';

interface Input {
  refreshUrl?: string;
  returnUrl?: string;
}

// Deep-link fallbacks — custom URL scheme registered by the Android/iOS app
// (see servitec_app/android/app/src/main/AndroidManifest.xml intent-filter
// for `servitec://`). When we have the marketing agency's real domain
// (Phase C), we can switch these to https:// Universal Links so the same
// URL works even for users who don't have the app installed.
const DEFAULT_REFRESH_URL = 'servitec://stripe/refresh';
const DEFAULT_RETURN_URL = 'servitec://stripe/return';

export const createTechnicianConnectOnboardingLink = onCall<Input>(
  { region: 'us-central1', memory: '256MiB' },
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }

    const userDoc = await db.collection('users').doc(uid).get();
    if (!userDoc.exists) {
      throw new HttpsError('not-found', 'Usuario no encontrado.');
    }
    const user = userDoc.data()!;
    if (user.rol !== 'tecnico') {
      throw new HttpsError('permission-denied', 'Solo técnicos.');
    }

    let connectedAccountId: string | undefined = user.stripeConnectAccountId;

    // 1) Provision the Connect account on first call.
    if (!connectedAccountId) {
      const account = await stripe.accounts.create({
        type: 'standard',
        country: 'MX',
        email: user.email,
        business_type: 'individual',
        metadata: { firebaseUid: uid },
      });
      connectedAccountId = account.id;
      await db.collection('users').doc(uid).update({
        stripeConnectAccountId: connectedAccountId,
      });
    }

    // 2) Generate a fresh account link (single-use, expires in a few minutes).
    const link = await stripe.accountLinks.create({
      account: connectedAccountId,
      refresh_url: req.data.refreshUrl || DEFAULT_REFRESH_URL,
      return_url: req.data.returnUrl || DEFAULT_RETURN_URL,
      type: 'account_onboarding',
    });

    return {
      url: link.url,
      accountId: connectedAccountId,
      expiresAt: link.expires_at,
    };
  },
);

/**
 * Callable — returns the current Stripe onboarding status for the técnico's
 * connected account. Used by the app to decide whether to show "Connect your
 * bank account" or "You're all set".
 */
export const getTechnicianConnectStatus = onCall(
  { region: 'us-central1', memory: '256MiB' },
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }
    const userDoc = await db.collection('users').doc(uid).get();
    const user = userDoc.data();
    const accountId: string | undefined = user?.stripeConnectAccountId;
    if (!accountId) {
      return { status: 'not_started' };
    }
    const account = await stripe.accounts.retrieve(accountId);
    return {
      status: account.details_submitted ? 'active' : 'incomplete',
      chargesEnabled: account.charges_enabled,
      payoutsEnabled: account.payouts_enabled,
      requirementsCurrentlyDue: account.requirements?.currently_due || [],
    };
  },
);
