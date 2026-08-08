/**
 * HTTPS Cloud Function invoked by the Flutter app when a client hits "Pagar".
 *
 * Creates a Stripe PaymentIntent using the marketplace pattern we agreed on:
 *
 *   - **`on_behalf_of` = técnico's Connect account** → the técnico is the
 *     settlement merchant. The customer's card statement shows the técnico's
 *     business name and the CFDI (issued by técnico via FacturAPI) matches
 *     the money flow exactly.
 *   - **`transfer_data.destination` = técnico's Connect account** → funds
 *     land in the técnico's Stripe balance automatically.
 *   - **`application_fee_amount`** → the platform (ServiTec) retains its
 *     configured commission (default 12%).
 *
 * This is what Stripe calls "destination charge with on_behalf_of" and is
 * functionally equivalent to Direct charges for the fiscal model
 * (técnico invoices the customer directly), while keeping the Flutter Stripe
 * SDK integration simple (no runtime `stripeAccount` switching required).
 */

import { onRequest } from 'firebase-functions/v2/https';
import { db } from './lib/admin';
import { stripe, applicationFeeCentavos } from './lib/stripe';

interface CreatePaymentIntentBody {
  servicioId?: string;
  amount?: number;      // integer, centavos (MXN)
  currency?: string;    // e.g. 'mxn'
}

export const createPaymentIntent = onRequest(
  { region: 'us-central1', memory: '256MiB', cors: true },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).send('Method not allowed');
      return;
    }

    const body = (req.body || {}) as CreatePaymentIntentBody;
    const { servicioId, amount, currency = 'mxn' } = body;

    if (!servicioId || !amount || amount <= 0) {
      res.status(400).json({
        error: 'servicioId and positive amount (centavos) are required',
      });
      return;
    }

    try {
      // Load the service and its assigned técnico.
      const serviceSnap = await db.collection('servicios').doc(servicioId).get();
      if (!serviceSnap.exists) {
        res.status(404).json({ error: 'Service not found' });
        return;
      }
      const service = serviceSnap.data()!;
      const tecnicoUid = service.tecnicoId as string | undefined;
      if (!tecnicoUid) {
        res.status(400).json({ error: 'Service has no assigned técnico' });
        return;
      }

      // Load the técnico's Stripe Connect account id from their user document.
      const tecnicoSnap = await db.collection('users').doc(tecnicoUid).get();
      const tecnico = tecnicoSnap.data();
      const connectedAccountId =
          tecnico?.stripeConnectAccountId as string | undefined;
      if (!connectedAccountId) {
        // The técnico hasn't completed Stripe Connect onboarding yet.
        res.status(400).json({
          error:
              'Técnico has not connected their Stripe account. Payout is not possible.',
          code: 'tecnico_not_onboarded',
        });
        return;
      }

      const feeCentavos = applicationFeeCentavos(amount);

      const paymentIntent = await stripe.paymentIntents.create({
        amount,
        currency,
        // Marketplace routing — funds land in técnico's Stripe balance and
        // técnico shows as the settlement merchant on the customer's statement.
        on_behalf_of: connectedAccountId,
        transfer_data: { destination: connectedAccountId },
        application_fee_amount: feeCentavos,
        automatic_payment_methods: { enabled: true },
        metadata: {
          servicioId,
          tecnicoUid,
          clienteUid: (service.clienteId as string) || '',
          platformCommissionCentavos: String(feeCentavos),
        },
      });

      res.status(200).json({
        clientSecret: paymentIntent.client_secret,
        paymentIntentId: paymentIntent.id,
        applicationFeeAmount: feeCentavos,
        currency,
      });
    } catch (err: any) {
      // eslint-disable-next-line no-console
      console.error('createPaymentIntent error', err);
      res.status(500).json({
        error: err?.message || 'Internal error creating PaymentIntent',
      });
    }
  },
);
