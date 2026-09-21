import { test } from 'node:test';
import assert from 'node:assert/strict';
import { ESTADO, FlowError } from './service-flow-rules';
import {
  FLUJO,
  PAGO,
  VISIT,
  canGoOnTheWay,
  canReportNoShow,
  cancellationIsTechnicianNoShow,
  finalClose,
  holdNeedsRenewal,
  planSchedule,
  remainingAfterVisit,
  settleAgainstVisit,
  validateVisitDate,
} from './visit-rules';

const H = 60 * 60 * 1000;
const D = 24 * H;
const now = Date.UTC(2026, 8, 21, 12);

test('visit date must be 1 hour to 60 days ahead', () => {
  assert.throws(() => validateVisitDate(now + 30 * 60 * 1000, now), FlowError);
  assert.throws(() => validateVisitDate(now + 61 * D, now), FlowError);
  assert.doesNotThrow(() => validateVisitDate(now + 2 * H, now));
});

test('a hold is renewed only when the visit is beyond its safe window', () => {
  assert.equal(holdNeedsRenewal(now + 5 * D, now), false);
  assert.equal(holdNeedsRenewal(now + 6 * D + 1, now), true);
});

test('"On my way" unlocks 2 hours before the appointment', () => {
  const fecha = now + 3 * H;
  assert.equal(canGoOnTheWay(fecha, now), false);
  assert.equal(canGoOnTheWay(fecha, fecha - 2 * H), true);
  assert.equal(canGoOnTheWay(fecha, fecha + 5 * H), true, 'late is allowed');
});

test('no-show report and incident windows', () => {
  const fecha = now;
  assert.equal(canReportNoShow(fecha, fecha + 29 * 60 * 1000), false);
  assert.equal(canReportNoShow(fecha, fecha + 30 * 60 * 1000), true);
  assert.equal(cancellationIsTechnicianNoShow(fecha, fecha + 59 * 60 * 1000), false);
  assert.equal(cancellationIsTechnicianNoShow(fecha, fecha + H), true);
});

test('the visit fee is credited and acts as the minimum', () => {
  assert.equal(remainingAfterVisit(1500, 400), 1100, 'client example');
  assert.equal(remainingAfterVisit(300, 400), 0, 'repair below the visit: no second charge, no refund');
  assert.equal(remainingAfterVisit(405, 400), 0, 'below Stripe minimum counts as covered');
  assert.equal(remainingAfterVisit(410, 400), 10);
});

test('settling a stop or dispute against the visit fee', () => {
  assert.deepEqual(settleAgainstVisit(900, 400), { remaining: 500, refund: 0 });
  assert.deepEqual(settleAgainstVisit(400, 400), { remaining: 0, refund: 0 });
  assert.deepEqual(settleAgainstVisit(150, 400), { remaining: 0, refund: 250 }, 'admin reduces below the fee');
  assert.deepEqual(settleAgainstVisit(0, 400), { remaining: 0, refund: 400 }, 'admin refunds the visit');
});

test('schedule: renew a long-range hold 48h before, expire it 24h before', () => {
  const fecha = now + 10 * D;
  const held = planSchedule({
    flujo: FLUJO.diagnostico, estado: ESTADO.visitaConfirmada,
    visita: { fechaMs: fecha, pagoEstado: PAGO.retenido, renovarAutorizacion: true },
  }, now);
  assert.equal(held.revisionTarea, 'pedir_reautorizacion');
  assert.equal(held.revisionAtMs, fecha - 48 * H);

  const pending = planSchedule({
    flujo: FLUJO.diagnostico, estado: ESTADO.visitaConfirmada,
    visita: { fechaMs: fecha, pagoEstado: PAGO.reautorizacionPendiente },
  }, now);
  assert.equal(pending.revisionTarea, 'vencer_reautorizacion');
  assert.equal(pending.revisionAtMs, fecha - 24 * H);

  const short = planSchedule({
    flujo: FLUJO.diagnostico, estado: ESTADO.visitaConfirmada,
    visita: { fechaMs: now + D, pagoEstado: PAGO.retenido, renovarAutorizacion: false },
  }, now);
  assert.equal(short.revisionAtMs, null, 'short-range hold needs no cron');
});

test('schedule: 7-day auto-close with reminders at 48h and 24h', () => {
  const entered = planSchedule({
    flujo: FLUJO.diagnostico, estado: ESTADO.diagnosticoRealizado, prevEstado: ESTADO.enCamino,
  }, now);
  assert.equal(entered.autoCierre!.atMs, now + VISIT.autoCloseMs);
  assert.equal(entered.revisionAtMs, now + 5 * D);
  assert.equal(entered.revisionTarea, 'aviso_cierre');

  const afterFirst = planSchedule({
    flujo: FLUJO.diagnostico, estado: ESTADO.diagnosticoRealizado, prevEstado: ESTADO.diagnosticoRealizado,
    autoCierre: { atMs: now + 7 * D, avisos: 1 },
  }, now);
  assert.equal(afterFirst.revisionAtMs, now + 6 * D);

  const due = planSchedule({
    flujo: FLUJO.diagnostico, estado: ESTADO.cotizacionEnviada, prevEstado: ESTADO.cotizacionEnviada,
    autoCierre: { atMs: now + 7 * D, avisos: 2 },
  }, now);
  assert.equal(due.revisionTarea, 'cierre_automatico');
  assert.equal(due.revisionAtMs, now + 7 * D);

  const restarted = planSchedule({
    flujo: FLUJO.diagnostico, estado: ESTADO.cotizacionEnviada, prevEstado: ESTADO.diagnosticoRealizado,
    autoCierre: { atMs: now + D, avisos: 2 },
  }, now);
  assert.equal(restarted.autoCierre!.atMs, now + 7 * D, 'a new pending action restarts the clock');
});

test('schedule: nothing for the standard flow or finished services', () => {
  assert.equal(planSchedule({ flujo: FLUJO.estandar, estado: ESTADO.cotizacionEnviada }, now).revisionAtMs, null);
  assert.equal(planSchedule({ flujo: FLUJO.diagnostico, estado: ESTADO.pagado }, now).revisionAtMs, null);
});

test('final close in both flows', () => {
  assert.deepEqual(finalClose(1200, 0), { estado: ESTADO.completado, costoFinal: 1200, refund: 0, cierre: null });
  assert.deepEqual(finalClose(5, 0), { estado: ESTADO.cancelado, costoFinal: null, refund: 0, cierre: null });
  assert.deepEqual(finalClose(1500, 400), { estado: ESTADO.completado, costoFinal: 1500, refund: 0, cierre: null });
  assert.deepEqual(finalClose(300, 400), { estado: ESTADO.pagado, costoFinal: 300, refund: 100, cierre: 'cubierto_por_visita' },
    'only an admin can get here below the fee; the difference is refunded');
  assert.deepEqual(finalClose(400, 400), { estado: ESTADO.pagado, costoFinal: 400, refund: 0, cierre: 'cubierto_por_visita' });
});
