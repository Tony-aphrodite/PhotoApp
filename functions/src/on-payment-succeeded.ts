/**
 * Stripe webhook — fired after a customer's payment succeeds.
 *
 * Payment model: destination charge with `on_behalf_of` (see
 * create-payment-intent.ts). The técnico is the settlement merchant; the
 * platform retains 12% as `application_fee_amount`. The PaymentIntent lives
 * on the platform account, so this webhook must be registered as a
 * **platform-account webhook** (NOT a Connect webhook) in the Stripe
 * dashboard.
 *
 * Steps:
 *   1. Verify Stripe signature.
 *   2. Load `servicioId` from PaymentIntent metadata → fetch the service +
 *      técnico documents.
 *   3. Stamp the CFDI técnico → cliente for the amount actually charged
 *      (lib/cfdi.ts: FacturAPI, branded PDF, Storage, `facturas` row). A
 *      diagnostic visit is invoiced separately, when the diagnosis ends.
 *   7. Post a system message into the service chat.
 *   8. Record the transaction in Firestore for the earnings / commissions view.
 *
 * The 12% commission is NOT invoiced here — the monthly cron aggregates it.
 */

import { onRequest } from 'firebase-functions/v2/https';
import { visitPaidOf } from './lib/visit-rules';
import { db, FieldValue } from './lib/admin';
import { stripe } from './lib/stripe';
import { cfdiSafely, stampChargeCfdi } from './lib/cfdi';

export const onPaymentSucceededStripeWebhook = onRequest(
  { region: 'us-central1', memory: '512MiB' },
  async (req, res) => {
    const sig = req.headers['stripe-signature'];
    const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
    if (!sig || !webhookSecret) {
      res.status(400).send('Missing signature or webhook secret');
      return;
    }

    let event;
    try {
      event = stripe.webhooks.constructEvent(
        (req as any).rawBody,
        sig,
        webhookSecret,
      );
    } catch (err) {
      res.status(400).send(`Webhook signature verification failed: ${err}`);
      return;
    }

    if (event.type !== 'payment_intent.succeeded') {
      res.status(200).send('ignored');
      return;
    }

    const pi = event.data.object as any;
    const servicioId = pi.metadata?.servicioId;
    const tecnicoUidFromMeta = pi.metadata?.tecnicoUid;
    const clienteUidFromMeta = pi.metadata?.clienteUid;
    const platformFeeCentavos = Number(pi.metadata?.platformCommissionCentavos || 0);
    // 'visita' = the diagnostic visit fee (charged when the técnico leaves);
    // 'saldo' = the rest of that service; 'servicio' = a standard service.
    const concepto = (pi.metadata?.concepto as string) || 'servicio';
    if (!servicioId) {
      res.status(200).send('missing servicioId in metadata');
      return;
    }

    // Load service + técnico + cliente
    const serviceDoc = await db.collection('servicios').doc(servicioId).get();
    if (!serviceDoc.exists) {
      res.status(404).send('service not found');
      return;
    }
    const service = serviceDoc.data()!;
    const tecnicoUid = (service.tecnicoId as string) || tecnicoUidFromMeta;
    const clienteUid = (service.clienteId as string) || clienteUidFromMeta;

    // Amounts in MXN (Stripe returns centavos as integer amount).
    const totalMxn = (pi.amount as number) / 100;
    const platformFeeMxn = platformFeeCentavos / 100;
    const tecnicoNetMxn = totalMxn - platformFeeMxn;

    // Persist the transaction row regardless of CFDI outcome — earnings /
    // commissions views depend on this row existing. Keyed by PaymentIntent
    // id so the client's optimistic write and this webhook converge to a
    // single document (idempotent under Stripe's at-least-once delivery).
    await db.collection('transacciones').doc(pi.id).set({
      servicioId,
      clienteId: clienteUid,
      tecnicoId: tecnicoUid,
      montoTotal: totalMxn,
      comisionPlataforma: platformFeeMxn,
      montoTecnico: tecnicoNetMxn,
      stripePaymentIntentId: pi.id,
      concepto,
      estado: 'completado',
      createdAt: FieldValue.serverTimestamp(),
      completedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    if (concepto === 'visita') {
      // The visit fee gets its own CFDI, but only once the técnico has
      // actually diagnosed something — it is stamped by visitAction
      // ('diagnostico_terminado'), not here (accountant, 2026-09-23). The
      // service state was already moved by the "Voy en camino" callable, and
      // the job is not finished, so no counters either.
      res.status(200).send('visit charge recorded');
      return;
    }
    const visitPaid = visitPaidOf(service);

    // Only needed from here on (CFDI), so a visit charge skips this read.
    const tecnicoDoc = await db.collection('users').doc(tecnicoUid).get();
    const tecnico = tecnicoDoc.data()!;

    // The técnico's completed-services counter. Clients cannot write it
    // (firestore.rules protects it, correctly — it feeds assignment scoring),
    // and nothing else server-side incremented it, so it sat at zero for
    // everyone. A paid service is the one unambiguous "completed" signal.
    // Keyed off the PaymentIntent id via the transaction doc above, so a
    // redelivered webhook does not double-count.
    if (!(await db.collection('transacciones').doc(pi.id).get()).data()?.contadoParaTecnico) {
      await db.collection('users').doc(tecnicoUid).update({
        serviciosCompletados: FieldValue.increment(1),
      });
      await db.collection('transacciones').doc(pi.id).update({
        contadoParaTecnico: true,
      });

      // Narrate the payment once, from here. The app used to post this after
      // its own bookkeeping write — which firestore.rules refuse — so it
      // never got that far. Inside this block so a redelivered webhook does
      // not post it twice.
      await db
        .collection('servicios')
        .doc(servicioId)
        .collection('mensajes')
        .add({
          userId: 'system',
          nombreUsuario: 'ServiTec',
          mensaje: `Pago recibido — $${totalMxn.toFixed(2)} MXN. Comisión plataforma: $${platformFeeMxn.toFixed(2)} MXN.`,
          tipo: 'sistema',
          timestamp: FieldValue.serverTimestamp(),
          leido: false,
          metadata: {
            event: 'payment_received',
            montoTotal: totalMxn,
            comisionPlataforma: platformFeeMxn,
            montoTecnico: tecnicoNetMxn,
          },
        });
    }

    // Advance the service to `pagado` so downstream flows (cron, admin view)
    // see it as completed and paid.
    await db.collection('servicios').doc(servicioId).update({
      estado: 'pagado',
      // Diagnostic flow: the service's price was paid in two charges.
      montoPagado: totalMxn + visitPaid,
      ...(visitPaid > 0 ? { montoSaldo: totalMxn } : {}),
      comisionPlataforma: platformFeeMxn,
      montoTecnico: tecnicoNetMxn,
      estadoPago: 'pagado',
      stripePaymentIntentId: pi.id,
      paidAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    // CFDI for what was charged *now*. In the diagnostic flow that is the
    // balance: the visit was invoiced on its own when the diagnosis ended, so
    // invoicing `costoFinal` here would bill it twice. A técnico still in the
    // grace period has no FacturAPI organization, in which case stampCfdi
    // flags it for an admin rather than failing — the money has moved either
    // way.
    const cliente = (await db.collection('users').doc(clienteUid).get()).data() ?? {};
    await cfdiSafely('cobro', servicioId, () => stampChargeCfdi({
      servicioId,
      service,
      paymentIntentId: pi.id,
      cobradoMxn: totalMxn,
      tecnicoUid,
      clienteUid,
      tecnico,
      cliente,
    }));

    res.status(200).send('ok');
  },
);

// Stamping lives in ./lib/cfdi — the diagnostic visit and the notas de
// crédito of a refund go through the same pipeline.
