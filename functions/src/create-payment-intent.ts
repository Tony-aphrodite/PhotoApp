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
import { db, admin } from './lib/admin';
import { stripe, applicationFeeCentavos } from './lib/stripe';
import { remainingAfterVisit, visitPaidOf } from './lib/visit-rules';

interface CreatePaymentIntentBody {
  servicioId?: string;
}

/** States in which the cliente is shown the "Pagar" button. */
const PAYABLE_STATES = ['completado', 'pago_pendiente'];

/**
 * What the service costs, decided here and never taken from the request.
 *
 * This endpoint used to charge whatever `amount` the app sent, with no sign-in
 * check at all. The price is now `costoFinal`, which only Cloud Functions
 * write (firestore.rules forbid clients): the approved cotización total, the
 * approved revision, or the amount accepted/resolved after work was stopped —
 * see service-flow.ts. Services created before that flow fall back to the
 * tariff-based `estimacionCosto`.
 */
function serviceAmountCentavos(service: FirebaseFirestore.DocumentData): number {
  const total =
    (service.costoFinal as number | undefined) ??
    (service.estimacionCosto as number | undefined) ??
    0;
  // Diagnostic flow: the visit fee was charged separately and is credited.
  const paid = visitPaidOf(service);
  const mxn = paid > 0 ? remainingAfterVisit(total, paid) : total;
  return Math.round(mxn * 100);
}

export const createPaymentIntent = onRequest(
  { region: 'us-central1', memory: '256MiB', cors: true },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).send('Method not allowed');
      return;
    }

    // A plain HTTPS function has no built-in auth, so verify the Firebase ID
    // token the app sends by hand.
    const match = /^Bearer (.+)$/.exec(req.get('Authorization') || '');
    let token: admin.auth.DecodedIdToken;
    try {
      if (!match) throw new Error('missing token');
      token = await admin.auth().verifyIdToken(match[1]);
    } catch {
      res.status(401).json({ error: 'Debes iniciar sesión.', code: 'unauthenticated' });
      return;
    }
    if (!token.email_verified) {
      res.status(403).json({ error: 'Verifica tu correo antes de pagar.', code: 'email_not_verified' });
      return;
    }

    const { servicioId } = (req.body || {}) as CreatePaymentIntentBody;
    const currency = 'mxn';
    if (!servicioId) {
      res.status(400).json({ error: 'servicioId is required' });
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

      if (service.clienteId !== token.uid) {
        res.status(403).json({ error: 'Solo el cliente del servicio puede pagarlo.', code: 'not_owner' });
        return;
      }
      if (!PAYABLE_STATES.includes(service.estado as string)) {
        res.status(409).json({
          error: service.estado === 'pagado'
            ? 'Este servicio ya está pagado.'
            : 'El servicio todavía no está listo para pagarse.',
          code: 'not_payable',
        });
        return;
      }

      const amount = serviceAmountCentavos(service);
      // Stripe's MXN minimum is $10.00.
      if (amount < 1000) {
        res.status(400).json({ error: 'El servicio no tiene un monto válido para cobrar.', code: 'no_amount' });
        return;
      }

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
          // 'saldo' = the rest of a diagnostic service after its visit fee;
          // on-payment-succeeded tells the two charges apart by this.
          concepto: visitPaidOf(service) > 0 ? 'saldo' : 'servicio',
        },
      });

      res.status(200).json({
        clientSecret: paymentIntent.client_secret,
        paymentIntentId: paymentIntent.id,
        amount,
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
