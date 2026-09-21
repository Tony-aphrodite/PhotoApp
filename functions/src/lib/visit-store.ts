/**
 * Side-effecting helpers for the diagnostic-visit flow: Stripe hold / charge /
 * release / refund, the category config lookup, técnico incident counters and
 * the translation of a planned schedule into Firestore fields.
 *
 * Stripe calls are never made inside a Firestore transaction (a retried
 * transaction would repeat them). Callers validate in a transaction, call
 * Stripe here with an idempotency key, then commit in a second transaction.
 */

import { db, admin, FieldValue, Timestamp } from './admin';
import { stripe, applicationFeeCentavos } from './stripe';
import { Data } from './flow-helpers';
import { FLUJO, Schedule, ScheduleInput, planSchedule } from './visit-rules';


// ---------------------------------------------------------------------------
// Category config (flow type and visit fee), cached per function instance.
// ---------------------------------------------------------------------------

export interface CategoryFlow {
  flujo: string;
  precioDiagnostico: number;
}

let categoriesCache: { at: number; data: Data } | null = null;
const CATEGORY_TTL_MS = 5 * 60 * 1000;

/** One document read per instance every 5 minutes, however many services. */
export async function categoryFlow(categoria: string): Promise<CategoryFlow> {
  if (!categoriesCache || Date.now() - categoriesCache.at > CATEGORY_TTL_MS) {
    const snap = await db.collection('configuracion').doc('categorias').get();
    categoriesCache = { at: Date.now(), data: snap.data() ?? {} };
  }
  const c = (categoriesCache.data[categoria] ?? {}) as Data;
  const precio = Number(c.precioDiagnostico) || 0;
  return {
    // A diagnostic category without a fee would charge nothing; fall back to
    // the standard flow rather than holding $0.
    flujo: c.flujo === FLUJO.diagnostico && precio > 0 ? FLUJO.diagnostico : FLUJO.estandar,
    precioDiagnostico: precio,
  };
}

// ---------------------------------------------------------------------------
// Stripe
// ---------------------------------------------------------------------------

/** Card-only hold of the visit fee; charged later by [captureVisit]. */
export async function createVisitHold(p: {
  servicioId: string;
  clienteUid: string;
  tecnicoUid: string;
  connectedAccountId: string;
  precioMxn: number;
}) {
  const amount = Math.round(p.precioMxn * 100);
  const fee = applicationFeeCentavos(amount);
  return stripe.paymentIntents.create({
    amount,
    currency: 'mxn',
    capture_method: 'manual',
    // Only cards support holding funds; OXXO / SPEI cannot.
    payment_method_types: ['card'],
    on_behalf_of: p.connectedAccountId,
    transfer_data: { destination: p.connectedAccountId },
    application_fee_amount: fee,
    metadata: {
      servicioId: p.servicioId,
      tecnicoUid: p.tecnicoUid,
      clienteUid: p.clienteUid,
      concepto: 'visita',
      platformCommissionCentavos: String(fee),
    },
  });
}

export const retrievePaymentIntent = (id: string) => stripe.paymentIntents.retrieve(id);

export const captureVisit = (piId: string) =>
  stripe.paymentIntents.capture(piId, {}, { idempotencyKey: `capture-${piId}` });

/** Releases a hold. A hold that is already gone is not an error. */
export async function releaseVisit(piId: string | undefined): Promise<void> {
  if (!piId) return;
  const pi = await stripe.paymentIntents.retrieve(piId);
  if (pi.status === 'canceled' || pi.status === 'succeeded') return;
  await stripe.paymentIntents.cancel(piId, {}, { idempotencyKey: `release-${piId}` });
}

/**
 * Refunds a charged visit (all of it, or `amountMxn`). ServiTec's commission
 * is returned in proportion and the transfer to the técnico reversed, as
 * agreed; Stripe's own processing fee is not refundable and stays a cost.
 */
export async function refundVisit(piId: string, amountMxn?: number) {
  const amount = amountMxn == null ? undefined : Math.round(amountMxn * 100);
  return stripe.refunds.create(
    {
      payment_intent: piId,
      ...(amount ? { amount } : {}),
      refund_application_fee: true,
      reverse_transfer: true,
    },
    { idempotencyKey: `refund-${piId}-${amount ?? 'full'}` },
  );
}

// ---------------------------------------------------------------------------
// Técnico incidents — denormalized counters, so the admin list reads them
// with the profile instead of counting services.
// ---------------------------------------------------------------------------

export type Incident = 'noSePresento' | 'cancelaciones' | 'detenidos';

export function incidentUpdate(kind: Incident): Data {
  return { [`incidencias.${kind}`]: FieldValue.increment(1) };
}

// ---------------------------------------------------------------------------
// Schedule
// ---------------------------------------------------------------------------

const toMs = (t: unknown): number | undefined =>
  t instanceof Timestamp ? t.toMillis() : undefined;

/** Builds the planner input from a service document plus its next state. */
export function scheduleInput(service: Data, estado: string, patch: Data = {}): ScheduleInput {
  const v = { ...(service.visita ?? {}), ...(patch.visita ?? {}) } as Data;
  const ac = service.autoCierre as Data | undefined;
  return {
    flujo: patch.flujo ?? service.flujo,
    estado,
    prevEstado: service.estado,
    visita: {
      fechaMs: toMs(v.fecha),
      pagoEstado: v.pagoEstado,
      renovarAutorizacion: v.renovarAutorizacion === true,
    },
    autoCierre: ac && toMs(ac.at) ? { atMs: toMs(ac.at)!, avisos: Number(ac.avisos) || 0 } : null,
  };
}

/** Firestore fields for a planned schedule; clears whatever is not planned. */
export function scheduleFields(s: Schedule): Data {
  return {
    autoCierre: s.autoCierre
      ? { at: Timestamp.fromMillis(s.autoCierre.atMs), avisos: s.autoCierre.avisos }
      : FieldValue.delete(),
    revisionAt: s.revisionAtMs != null ? Timestamp.fromMillis(s.revisionAtMs) : FieldValue.delete(),
    revisionTarea: s.revisionTarea ?? FieldValue.delete(),
  };
}

/** Convenience: plan and translate in one go. */
export const scheduleFor = (service: Data, estado: string, patch: Data = {}, nowMs = Date.now()): Data =>
  scheduleFields(planSchedule(scheduleInput(service, estado, patch), nowMs));

export const fmtFecha = (ms: number): string =>
  new Date(ms).toLocaleString('es-MX', {
    timeZone: 'America/Mexico_City',
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    hour: '2-digit',
    minute: '2-digit',
  });
