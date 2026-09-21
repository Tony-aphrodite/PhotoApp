/**
 * Rules of the diagnostic-visit flow (Phase 2), free of Firebase and Stripe so
 * they can be unit-tested. The callables in visit-flow.ts and the hourly
 * schedule cron only apply what these functions decide.
 *
 *   asignado ──proponer──▶ visita_propuesta ──autorizar + confirmar──▶ visita_confirmada
 *      ▲  pedir_otro_horario │                     (card hold, not charged)    │ en_camino (charge)
 *      └────────────────────┘                                                ▼
 *                                                                        en_camino ──diagnóstico──▶ diagnostico_realizado
 *                                                    reportar_no_llego │      │ repair quote          │ repair quote
 *                                                                      ▼      ▼                       ▼
 *                                                          reporte_no_llego   cotizacion_enviada → the Phase 1 flow
 *
 * Money rules agreed with the client (2026-09-16):
 *   - The visit fee is held on the card when the cliente confirms and charged
 *     when the técnico taps "Voy en camino".
 *   - An approved repair is credited with the visit fee: visit 400 + repair
 *     1,500 → 1,100 more. The visit fee is also the minimum: repair 300 → no
 *     second charge, no refund.
 *   - 12% commission on each charge, so the total is 12% of the service.
 */

import { ESTADO, FlowError, MIN_CHARGE_MXN, round2 } from './service-flow-rules';

export const FLUJO = { estandar: 'estandar', diagnostico: 'diagnostico' } as const;

const HOUR = 60 * 60 * 1000;
const DAY = 24 * HOUR;

export const VISIT = {
  /** A proposed visit must be at least this far in the future… */
  minLeadMs: 1 * HOUR,
  /** …and no further than this. */
  maxAheadMs: 60 * DAY,
  /** Card networks drop an uncaptured hold after ~7 days; renew past this. */
  holdSafeMs: 6 * DAY,
  /** When a renewed authorization is requested / must be done by. */
  reauthRequestBeforeMs: 48 * HOUR,
  reauthDeadlineBeforeMs: 24 * HOUR,
  /** "Voy en camino" unlocks this long before the appointment, so the
   * técnico cannot make the visit non-refundable days in advance. */
  onTheWayFromMs: 2 * HOUR,
  /** The cliente may report a no-show this long after the appointment. */
  noShowReportAfterMs: 30 * 60 * 1000,
  /** Cancelling a confirmed visit this long after the appointment, without
   * the técnico ever leaving, counts as a técnico no-show. */
  noShowIncidentAfterMs: 1 * HOUR,
  /** Auto-close after the last pending action, with two reminders. */
  autoCloseMs: 7 * DAY,
  reminderOffsetsMs: [48 * HOUR, 24 * HOUR],
} as const;

/** Where the visit payment stands. */
export const PAGO = {
  sinAutorizar: 'sin_autorizar',
  retenido: 'retenido',
  reautorizacionPendiente: 'reautorizacion_pendiente',
  cobrado: 'cobrado',
  liberado: 'liberado',
  reembolsado: 'reembolsado',
} as const;

export function validateVisitDate(fechaMs: number, nowMs: number): void {
  if (!Number.isFinite(fechaMs)) throw new FlowError('Fecha de visita inválida.');
  if (fechaMs < nowMs + VISIT.minLeadMs) {
    throw new FlowError('La visita debe proponerse con al menos 1 hora de anticipación.');
  }
  if (fechaMs > nowMs + VISIT.maxAheadMs) {
    throw new FlowError('La visita no puede ser a más de 60 días.');
  }
}

/** A hold placed at `heldAtMs` would lapse before the visit is charged. */
export const holdNeedsRenewal = (fechaMs: number, heldAtMs: number): boolean =>
  fechaMs - heldAtMs > VISIT.holdSafeMs;

export const canGoOnTheWay = (fechaMs: number, nowMs: number): boolean =>
  nowMs >= fechaMs - VISIT.onTheWayFromMs;

export const canReportNoShow = (fechaMs: number, nowMs: number): boolean =>
  nowMs >= fechaMs + VISIT.noShowReportAfterMs;

export const cancellationIsTechnicianNoShow = (fechaMs: number, nowMs: number): boolean =>
  nowMs >= fechaMs + VISIT.noShowIncidentAfterMs;

/**
 * What is still owed on a service whose visit fee was already charged. The
 * fee is credited; anything below Stripe's minimum is not worth a charge and
 * is treated as covered (the visit fee is the minimum price anyway).
 */
export function remainingAfterVisit(totalMxn: number, visitPaidMxn: number): number {
  const rest = round2(totalMxn - visitPaidMxn);
  return rest >= MIN_CHARGE_MXN ? rest : 0;
}

/**
 * Settles a final amount decided after a stop or a dispute, against a visit
 * fee already charged. The amount may be below the fee only when an admin
 * decides so; then the difference is refunded.
 */
export function settleAgainstVisit(
  finalMxn: number,
  visitPaidMxn: number,
): { remaining: number; refund: number } {
  const final = round2(Math.max(0, finalMxn));
  if (final < visitPaidMxn) return { remaining: 0, refund: round2(visitPaidMxn - final) };
  return { remaining: remainingAfterVisit(final, visitPaidMxn), refund: 0 };
}

/** States in which a diagnostic service waits on someone and auto-closes. */
export const AUTO_CLOSE_STATES: string[] = [
  ESTADO.diagnosticoRealizado,
  ESTADO.cotizacionEnviada,
  ESTADO.cotizacionRechazada,
];

export interface ScheduleInput {
  flujo?: string;
  estado: string;
  /** Previous state, to restart the 7-day clock when entering a waiting state. */
  prevEstado?: string;
  visita?: {
    fechaMs?: number;
    pagoEstado?: string;
    renovarAutorizacion?: boolean;
  };
  autoCierre?: { atMs: number; avisos: number } | null;
}

export interface Schedule {
  autoCierre: { atMs: number; avisos: number } | null;
  revisionAtMs: number | null;
  revisionTarea: string | null;
}

/**
 * The next time the hourly cron must look at a service, and what to do then.
 * Stored on the service as one indexed timestamp (`revisionAt`), so the cron
 * reads only services that are actually due instead of scanning them all.
 */
export function planSchedule(s: ScheduleInput, nowMs: number): Schedule {
  const none: Schedule = { autoCierre: null, revisionAtMs: null, revisionTarea: null };
  if (s.flujo !== FLUJO.diagnostico) return none;
  const v = s.visita ?? {};

  if (s.estado === ESTADO.visitaConfirmada && v.fechaMs) {
    if (v.pagoEstado === PAGO.retenido && v.renovarAutorizacion) {
      return { ...none, revisionAtMs: v.fechaMs - VISIT.reauthRequestBeforeMs, revisionTarea: 'pedir_reautorizacion' };
    }
    if (v.pagoEstado === PAGO.reautorizacionPendiente) {
      return { ...none, revisionAtMs: v.fechaMs - VISIT.reauthDeadlineBeforeMs, revisionTarea: 'vencer_reautorizacion' };
    }
    return none;
  }

  if (AUTO_CLOSE_STATES.includes(s.estado)) {
    const restart = !s.autoCierre || s.prevEstado !== s.estado;
    const autoCierre = restart ? { atMs: nowMs + VISIT.autoCloseMs, avisos: 0 } : s.autoCierre!;
    const [first, second] = VISIT.reminderOffsetsMs;
    if (autoCierre.avisos === 0) {
      return { autoCierre, revisionAtMs: autoCierre.atMs - first, revisionTarea: 'aviso_cierre' };
    }
    if (autoCierre.avisos === 1) {
      return { autoCierre, revisionAtMs: autoCierre.atMs - second, revisionTarea: 'aviso_cierre' };
    }
    return { autoCierre, revisionAtMs: autoCierre.atMs, revisionTarea: 'cierre_automatico' };
  }

  return none;
}

/**
 * How a service closes for a final amount (work completed, a stop accepted,
 * or a dispute resolved), in either flow. `visitPaidMxn` is 0 in the standard
 * flow. Returns the next state, the amount that becomes the service price,
 * and any part of the visit fee to refund.
 */
export function finalClose(
  montoMxn: number,
  visitPaidMxn: number,
): { estado: string; costoFinal: number | null; refund: number; cierre: string | null } {
  const monto = round2(Math.max(0, montoMxn));
  if (!(visitPaidMxn > 0)) {
    return monto >= MIN_CHARGE_MXN
      ? { estado: ESTADO.completado, costoFinal: monto, refund: 0, cierre: null }
      : { estado: ESTADO.cancelado, costoFinal: null, refund: 0, cierre: null };
  }
  const { remaining, refund } = settleAgainstVisit(monto, visitPaidMxn);
  if (remaining > 0) return { estado: ESTADO.completado, costoFinal: monto, refund: 0, cierre: null };
  // Nothing more to charge: the visit already paid covers it.
  return { estado: ESTADO.pagado, costoFinal: monto, refund, cierre: 'cubierto_por_visita' };
}

/** The visit fee already charged on a service (0 in the standard flow). */
export function visitPaidOf(service: { flujo?: string; visita?: { pagoEstado?: string; montoCobrado?: number } }): number {
  return service.flujo === FLUJO.diagnostico && service.visita?.pagoEstado === PAGO.cobrado
    ? Number(service.visita.montoCobrado) || 0
    : 0;
}
