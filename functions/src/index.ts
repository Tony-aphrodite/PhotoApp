/**
 * ServiTec Cloud Functions — entry point.
 *
 * Groups exports so `firebase deploy --only functions` picks them all up.
 * Each function lives in its own module; keep this file thin.
 *
 * Env vars: see .env.example. Load via defineSecret / process.env at cold start.
 */

import { setGlobalOptions } from 'firebase-functions/v2';

setGlobalOptions({
  region: 'us-central1',
  maxInstances: 20,
});

export { setupTechnicianFiscal } from './setup-technician-fiscal';
export { createPaymentIntent } from './create-payment-intent';
export {
  createTechnicianConnectOnboardingLink,
  getTechnicianConnectStatus,
} from './stripe-connect-onboarding';
export { onPaymentSucceededStripeWebhook } from './on-payment-succeeded';
export { onChatMessageCreated } from './chat-message-guard';
export { onServiceCreated } from './service-lifecycle';
export { monthlyCommissionCron } from './monthly-commission-cron';
export { gracePeriodDailyCron } from './grace-period-cron';
