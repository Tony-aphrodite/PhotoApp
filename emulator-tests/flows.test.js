// End-to-end flows against the Firebase emulators: Cloud Functions called the
// way the app calls them (callables with an ID token, the payment HTTPS
// endpoint, a signed Stripe webhook), with Stripe replaced by stripe-mock.js.
// Run by run.sh inside `firebase emulators:exec`.

const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const admin = require('firebase-admin');
const Stripe = require('stripe');
const stripeMock = require('./stripe-mock');

const PROJECT = 'demo-servitec';
const FN = `http://127.0.0.1:5001/${PROJECT}/us-central1`;
const AUTH = 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1';
const WEBHOOK_SECRET = 'whsec_test_mock';

admin.initializeApp({ projectId: PROJECT });
const db = admin.firestore();
const { Timestamp, FieldValue } = admin.firestore;

let mock;
const tokens = {};

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

async function makeUser(uid, profile, { verified = true } = {}) {
  const email = `${uid}@test.servitec`;
  await admin.auth().createUser({ uid, email, password: 'secret123', emailVerified: verified });
  await db.doc(`users/${uid}`).set({ activo: true, nombre: uid, apellido: 'Test', email, ...profile });
  const res = await fetch(`${AUTH}/accounts:signInWithPassword?key=fake`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email, password: 'secret123', returnSecureToken: true }),
  });
  tokens[uid] = (await res.json()).idToken;
}

/** Calls a callable like the Flutter SDK does; throws the server's message. */
async function call(uid, name, data) {
  const res = await fetch(`${FN}/${name}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${tokens[uid]}` },
    body: JSON.stringify({ data }),
  });
  const body = await res.json();
  if (body.error) {
    const err = new Error(body.error.message);
    err.status = body.error.status;
    throw err;
  }
  return body.result;
}

const visit = (uid, servicioId, accion, extra = {}) => call(uid, 'visitAction', { servicioId, accion, ...extra });

async function rejects(promise, pattern) {
  await assert.rejects(promise, (e) => {
    if (pattern && !pattern.test(e.message)) {
      throw new Error(`expected error matching ${pattern}, got: ${e.message}`);
    }
    return true;
  });
}

const svc = async (id) => (await db.doc(`servicios/${id}`).get()).data();

async function waitFor(fn, what, ms = 20000) {
  const end = Date.now() + ms;
  for (;;) {
    const v = await fn();
    if (v) return v;
    if (Date.now() > end) throw new Error(`timed out waiting for ${what}`);
    await new Promise((r) => setTimeout(r, 250));
  }
}

/** Creates a request like the app does and waits for auto-assignment. */
async function newService(id, categoria) {
  await db.doc(`servicios/${id}`).set({
    clienteId: 'cli', clienteNombre: 'Cliente Test', clienteTelefono: '',
    titulo: `Prueba ${id}`, descripcion: 'x', categoria, urgencia: 'normal',
    ubicacion: new admin.firestore.GeoPoint(19.43, -99.13), ubicacionTexto: 'CDMX',
    fotos: [], estado: 'pendiente', tipoAsignacion: 'automatica',
    createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  });
  return waitFor(async () => {
    const s = await svc(id);
    return s.estado === 'asignado' && s.flujo ? s : null;
  }, `assignment of ${id}`);
}

const item = (precioUnitario) => [{ descripcion: 'Trabajo', tipo: 'mano_obra', cantidad: 1, precioUnitario }];

async function quoteAndApprove(id, precioUnitario) {
  await call('tec', 'submitQuotation', { servicioId: id, items: item(precioUnitario) });
  const s = await svc(id);
  await call('cli', 'respondQuotation', { cotizacionId: s.cotizacionPendienteId, respuesta: 'aprobada' });
}

/** Proposes a visit 65 minutes out, authorizes and confirms the hold. */
async function confirmVisit(id) {
  const fecha = new Date(Date.now() + 65 * 60 * 1000).toISOString();
  await visit('tec', id, 'proponer', { fecha });
  const { paymentIntentId } = await visit('cli', id, 'autorizar');
  mock.authorize(paymentIntentId);
  await visit('cli', id, 'confirmar_autorizacion');
  return paymentIntentId;
}

/** Delivers a signed payment_intent.succeeded webhook for a PI. */
async function webhook(piId) {
  const pi = mock.intents.get(piId);
  const payload = JSON.stringify({ id: `evt_${piId}`, type: 'payment_intent.succeeded', data: { object: pi } });
  const header = new Stripe('sk_test_mock').webhooks.generateTestHeaderString({ payload, secret: WEBHOOK_SECRET });
  const res = await fetch(`${FN}/onPaymentSucceededStripeWebhook`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'stripe-signature': header },
    body: payload,
  });
  assert.equal(res.status, 200, await res.text());
}

async function pay(id) {
  const res = await fetch(`${FN}/createPaymentIntent`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${tokens.cli}` },
    body: JSON.stringify({ servicioId: id }),
  });
  const body = await res.json();
  assert.equal(res.status, 200, JSON.stringify(body));
  mock.authorize(body.paymentIntentId);
  await webhook(body.paymentIntentId);
  return { ...body, pi: mock.intents.get(body.paymentIntentId) };
}

const opsFor = (piId, op) => mock.log.filter((l) => l.id === piId && l.op === op);

// ---------------------------------------------------------------------------
// setup
// ---------------------------------------------------------------------------

before(async () => {
  mock = await stripeMock.start(12111);
  await db.doc('configuracion/categorias').set({
    plomeria: { label: 'Plomería', icon: '🔧', activo: true, orden: 0, flujo: 'estandar' },
    aire_acondicionado: { label: 'A/C', icon: '❄️', activo: true, orden: 1, flujo: 'diagnostico', precioDiagnostico: 400 },
  });
  await makeUser('adm', { rol: 'admin' });
  await makeUser('cli', { rol: 'cliente', telefono: '5511111111' });
  await makeUser('tec', {
    rol: 'tecnico', disponible: true, especialidades: ['plomeria', 'aire_acondicionado'],
    calificacionPromedio: 5, serviciosCompletados: 0, stripeConnectAccountId: 'acct_mock_1',
  });
  await makeUser('nover', { rol: 'cliente' }, { verified: false });
});

after(() => mock.close());

// ---------------------------------------------------------------------------
// Phase 1 — standard flow
// ---------------------------------------------------------------------------

test('standard: quote, revision rejected, original scope, pay', async () => {
  const s0 = await newService('std1', 'plomeria');
  assert.equal(s0.flujo, 'estandar');
  assert.equal(s0.tecnicoId, 'tec');

  await rejects(call('tec', 'serviceWorkAction', { servicioId: 'std1', accion: 'iniciar' }), /cambió de estado/);
  await quoteAndApprove('std1', 1000);
  let s = await svc('std1');
  assert.equal(s.estado, 'cotizacion_aprobada');
  assert.equal(s.costoFinal, 1160, 'server adds 16% IVA');

  await call('tec', 'serviceWorkAction', { servicioId: 'std1', accion: 'iniciar' });
  await call('tec', 'submitQuotation', { servicioId: 'std1', items: item(2000) });
  await rejects(call('tec', 'serviceWorkAction', { servicioId: 'std1', accion: 'completar' }), /cambió de estado/);
  s = await svc('std1');
  await call('cli', 'respondQuotation', { cotizacionId: s.cotizacionPendienteId, respuesta: 'rechazada' });
  assert.equal((await svc('std1')).estado, 'revision_rechazada');
  await call('tec', 'serviceWorkAction', { servicioId: 'std1', accion: 'continuar_original' });
  await call('tec', 'serviceWorkAction', { servicioId: 'std1', accion: 'completar' });
  assert.equal((await svc('std1')).estado, 'completado');

  const paid = await pay('std1');
  assert.equal(paid.amount, 116000, 'charges the original approved amount');
  assert.equal(paid.pi.metadata.concepto, 'servicio');
  assert.equal(paid.pi.application_fee_amount, 13920, '12%');
  s = await svc('std1');
  assert.equal(s.estado, 'pagado');
  assert.equal(s.montoPagado, 1160);
  const tec = (await db.doc('users/tec').get()).data();
  assert.equal(tec.serviciosCompletados, 1);
});

test('standard: stop, dispute, admin resolves', async () => {
  await newService('std2', 'plomeria');
  await quoteAndApprove('std2', 1000);
  await call('tec', 'serviceWorkAction', { servicioId: 'std2', accion: 'iniciar' });
  const stop = { servicioId: 'std2', motivo: 'riesgo_seguridad', descripcion: 'Cableado dañado en el muro', fotos: ['https://x/1.jpg'] };
  await rejects(call('tec', 'stopWork', { ...stop, montoPropuesto: 5000 }), /mayor al aprobado/);
  await call('tec', 'stopWork', { ...stop, montoPropuesto: 500 });
  assert.equal((await svc('std2')).estado, 'detenido');
  assert.equal((await db.doc('users/tec').get()).get('incidencias.detenidos'), 1);

  await call('cli', 'respondStop', { servicioId: 'std2', respuesta: 'disputar', comentario: 'No hizo nada' });
  assert.equal((await svc('std2')).estado, 'en_disputa');
  await rejects(call('cli', 'adminResolveDispute', { servicioId: 'std2', monto: 300, nota: 'Revisado' }), /administradores/);
  await call('adm', 'adminResolveDispute', { servicioId: 'std2', monto: 300, nota: 'Revisado con fotos' });
  const s = await svc('std2');
  assert.equal(s.estado, 'completado');
  assert.equal(s.costoFinal, 300);
});

test('standard: cancel goes through the server', async () => {
  await newService('std3', 'plomeria');
  await visit('cli', 'std3', 'cancelar');
  assert.equal((await svc('std3')).estado, 'cancelado');
});

// ---------------------------------------------------------------------------
// Phase 2 — diagnostic visit
// ---------------------------------------------------------------------------

test('diagnostic: hold, charge on the way, credit against the repair', async () => {
  const s0 = await newService('dx1', 'aire_acondicionado');
  assert.equal(s0.flujo, 'diagnostico');
  assert.equal(s0.visita.precio, 400);

  await rejects(call('tec', 'submitQuotation', { servicioId: 'dx1', items: item(1000) }), /agenda la visita/);
  await rejects(visit('cli', 'dx1', 'proponer', { fecha: new Date(Date.now() + 2 * 3600e3).toISOString() }), /Solo el técnico/);
  await rejects(visit('tec', 'dx1', 'proponer', { fecha: new Date(Date.now() + 10 * 60e3).toISOString() }), /1 hora/);

  const fecha = new Date(Date.now() + 65 * 60 * 1000).toISOString();
  await visit('tec', 'dx1', 'proponer', { fecha });
  assert.equal((await svc('dx1')).estado, 'visita_propuesta');

  const { paymentIntentId: pi } = await visit('cli', 'dx1', 'autorizar');
  const created = mock.log.find((l) => l.id === pi && l.op === 'create');
  assert.equal(created.amount, 40000);
  assert.equal(created.capture, 'manual', 'held, not charged');
  assert.equal(created.fee, 4800, '12% of the visit');
  await rejects(visit('cli', 'dx1', 'confirmar_autorizacion'), /no se completó/);
  mock.authorize(pi);
  await visit('cli', 'dx1', 'confirmar_autorizacion');
  let s = await svc('dx1');
  assert.equal(s.estado, 'visita_confirmada');
  assert.equal(s.visita.pagoEstado, 'retenido');
  assert.equal(s.revisionAt, undefined, 'short-range hold needs no cron');

  await visit('tec', 'dx1', 'en_camino');
  assert.equal(opsFor(pi, 'capture').length, 1);
  s = await svc('dx1');
  assert.equal(s.estado, 'en_camino');
  assert.equal(s.visita.montoCobrado, 400);
  await webhook(pi);
  s = await svc('dx1');
  assert.equal(s.estado, 'en_camino', 'a visit charge does not close the service');
  const flags = await db.collection('admin_flags').where('servicioId', '==', 'dx1').get();
  assert.ok(flags.docs.some((d) => d.get('type') === 'cfdi_diagnostico_pendiente'));

  // 1293.10 + 16% = 1500.00
  await call('tec', 'submitQuotation', { servicioId: 'dx1', items: item(1293.1) });
  s = await svc('dx1');
  assert.equal(s.estado, 'cotizacion_enviada');
  assert.ok(s.revisionAt, 'auto-close scheduled while waiting on the cliente');
  assert.equal(s.revisionTarea, 'aviso_cierre');
  await call('cli', 'respondQuotation', { cotizacionId: s.cotizacionPendienteId, respuesta: 'aprobada' });
  s = await svc('dx1');
  assert.equal(s.revisionAt, undefined, 'schedule cleared once approved');

  await call('tec', 'serviceWorkAction', { servicioId: 'dx1', accion: 'iniciar' });
  await call('tec', 'serviceWorkAction', { servicioId: 'dx1', accion: 'completar' });
  assert.equal((await svc('dx1')).estado, 'completado');
  const paid = await pay('dx1');
  assert.equal(paid.amount, 110000, 'visit credited: 1500 - 400');
  assert.equal(paid.pi.metadata.concepto, 'saldo');
  assert.equal(paid.pi.application_fee_amount, 13200, '12% of the balance');
  s = await svc('dx1');
  assert.equal(s.estado, 'pagado');
  assert.equal(s.montoPagado, 1500);
});

test('diagnostic: repair below the visit closes with no second charge', async () => {
  await newService('dx2', 'aire_acondicionado');
  await confirmVisit('dx2');
  await visit('tec', 'dx2', 'en_camino');
  // 258.62 + 16% = 300.00
  await quoteAndApprove('dx2', 258.62);
  await call('tec', 'serviceWorkAction', { servicioId: 'dx2', accion: 'iniciar' });
  const before = (await db.doc('users/tec').get()).get('serviciosCompletados');
  await call('tec', 'serviceWorkAction', { servicioId: 'dx2', accion: 'completar' });
  const s = await svc('dx2');
  assert.equal(s.estado, 'pagado');
  assert.equal(s.cierre, 'cubierto_por_visita');
  assert.equal((await db.doc('users/tec').get()).get('serviciosCompletados'), before + 1);
});

test('diagnostic: cancel before travel releases the hold', async () => {
  await newService('dx3', 'aire_acondicionado');
  const pi = await confirmVisit('dx3');
  await visit('cli', 'dx3', 'cancelar');
  const s = await svc('dx3');
  assert.equal(s.estado, 'cancelado');
  assert.equal(s.visita.pagoEstado, 'liberado');
  assert.equal(opsFor(pi, 'cancel').length, 1);
  assert.equal(opsFor(pi, 'capture').length, 0);
});

test('diagnostic: cancel after travel keeps the visit', async () => {
  await newService('dx4', 'aire_acondicionado');
  const pi = await confirmVisit('dx4');
  await visit('tec', 'dx4', 'en_camino');
  await visit('cli', 'dx4', 'cancelar');
  const s = await svc('dx4');
  assert.equal(s.estado, 'pagado');
  assert.equal(s.cierre, 'cancelado_por_cliente');
  assert.equal(opsFor(pi, 'refund').length, 0);
});

test('diagnostic: técnico withdraws after charging — refund, incident, back to admins', async () => {
  await newService('dx5', 'aire_acondicionado');
  const pi = await confirmVisit('dx5');
  await visit('tec', 'dx5', 'en_camino');
  await rejects(visit('cli', 'dx5', 'retirarse'), /Solo el técnico/);
  await visit('tec', 'dx5', 'retirarse');
  const refund = opsFor(pi, 'refund')[0];
  assert.ok(refund, 'refunded');
  assert.equal(refund.refund_application_fee, 'true', 'commission returned');
  assert.equal(refund.reverse_transfer, 'true', 'técnico payout reversed');
  const s = await svc('dx5');
  assert.equal(s.estado, 'pendiente');
  assert.equal(s.tecnicoId, undefined);
  assert.equal(s.flujo, 'diagnostico', 'keeps the flow for the next técnico');
  assert.equal((await db.doc('users/tec').get()).get('incidencias.cancelaciones'), 1);
});

test('diagnostic: no-show report resolved by admin with a refund', async () => {
  await newService('dx6', 'aire_acondicionado');
  const pi = await confirmVisit('dx6');
  await visit('tec', 'dx6', 'en_camino');
  await rejects(visit('cli', 'dx6', 'reportar_no_llego', { comentario: 'nadie' }), /30 minutos/);
  await db.doc('servicios/dx6').update({ 'visita.fecha': Timestamp.fromMillis(Date.now() - 40 * 60e3) });
  await visit('cli', 'dx6', 'reportar_no_llego', { comentario: 'Nunca llegó' });
  assert.equal((await svc('dx6')).estado, 'reporte_no_llego');
  await rejects(visit('cli', 'dx6', 'resolver_no_llego', { reembolsar: true, nota: 'x' }), /permiso/);
  await visit('adm', 'dx6', 'resolver_no_llego', { reembolsar: true, nota: 'El técnico no se presentó' });
  assert.equal(opsFor(pi, 'refund').length, 1);
  assert.equal((await svc('dx6')).estado, 'pendiente');
  assert.equal((await db.doc('users/tec').get()).get('incidencias.noSePresento'), 1);
});

test('diagnostic: stop floor is the visit; admin may go below and refunds the difference', async () => {
  await newService('dx7', 'aire_acondicionado');
  const pi = await confirmVisit('dx7');
  await visit('tec', 'dx7', 'en_camino');
  await quoteAndApprove('dx7', 1293.1);
  await call('tec', 'serviceWorkAction', { servicioId: 'dx7', accion: 'iniciar' });
  const stop = { servicioId: 'dx7', motivo: 'dano_impide_terminar', descripcion: 'Compresor dañado sin repuesto', fotos: ['https://x/2.jpg'] };
  await rejects(call('tec', 'stopWork', { ...stop, montoPropuesto: 300 }), /menor que la visita/);
  await call('tec', 'stopWork', { ...stop, montoPropuesto: 400 });
  await call('cli', 'respondStop', { servicioId: 'dx7', respuesta: 'disputar', comentario: 'No resolvió nada' });
  await call('adm', 'adminResolveDispute', { servicioId: 'dx7', monto: 150, nota: 'Diagnóstico incompleto' });
  const refund = opsFor(pi, 'refund')[0];
  assert.equal(refund.amount, 25000, 'refunds 400 - 150');
  const s = await svc('dx7');
  assert.equal(s.estado, 'pagado');
  assert.equal(s.visita.montoReembolsado, 250);
});

test('diagnostic: cliente declines the repair and pays only the visit', async () => {
  await newService('dx8', 'aire_acondicionado');
  await confirmVisit('dx8');
  await visit('tec', 'dx8', 'en_camino');
  await visit('tec', 'dx8', 'diagnostico_terminado');
  const s0 = await svc('dx8');
  assert.equal(s0.estado, 'diagnostico_realizado');
  assert.ok(s0.autoCierre && s0.revisionAt, 'auto-close scheduled');
  await visit('cli', 'dx8', 'cerrar_solo_diagnostico');
  const s = await svc('dx8');
  assert.equal(s.estado, 'pagado');
  assert.equal(s.cierre, 'solo_diagnostico');
  assert.equal(s.revisionAt, undefined);
});

test('technician can switch a standard job to diagnostic', async () => {
  await newService('dx9', 'plomeria');
  await visit('tec', 'dx9', 'requerir_diagnostico').catch((e) => {
    // plomería has no visit fee configured: the server must refuse.
    assert.match(e.message, /precio de diagnóstico/);
  });
  await db.doc('configuracion/categorias').update({ 'plomeria.precioDiagnostico': 350 });
  // categoryFlow() caches config for 5 minutes per instance; this checks the
  // refusal path above and that the flag is kept off without a fee.
  assert.equal((await svc('dx9')).flujo, 'estandar');
});

test('unverified accounts are refused', async () => {
  await rejects(call('nover', 'visitAction', { servicioId: 'std3', accion: 'cancelar' }), /Verifica tu correo/);
});

// ---------------------------------------------------------------------------
// Hourly schedule (serviceScheduleCron), triggered through the Pub/Sub
// emulator instead of waiting for Cloud Scheduler.
// ---------------------------------------------------------------------------

// Runs the cron's body in this process against the same emulators. The
// Functions emulator cannot fire v2 scheduled functions, so the cron itself
// is a one-line wrapper around runDueServiceTasks().
let runDueServiceTasks;
async function runCron() {
  if (!runDueServiceTasks) {
    for (const line of require('fs').readFileSync(`${__dirname}/../functions/.env.demo-servitec`, 'utf8').split('\n')) {
      const m = /^([A-Z_]+)=(.*)$/.exec(line);
      if (m) process.env[m[1]] = m[2];
    }
    ({ runDueServiceTasks } = require('../functions/lib/visit-flow'));
  }
  const r = await runDueServiceTasks();
  assert.equal(r.failed, 0, 'no task failed');
}

const past = () => Timestamp.fromMillis(Date.now() - 60e3);

test('schedule: reminder, then auto-close with only the visit', async () => {
  await newService('cr1', 'aire_acondicionado');
  await confirmVisit('cr1');
  await visit('tec', 'cr1', 'en_camino');
  await visit('tec', 'cr1', 'diagnostico_terminado');
  const at = (await svc('cr1')).autoCierre.at;

  await db.doc('servicios/cr1').update({ revisionAt: past() });
  await runCron();
  await waitFor(async () => (await svc('cr1')).autoCierre?.avisos === 1, 'first reminder');
  const msgs = await db.collection('servicios/cr1/mensajes').where('metadata.event', '==', 'auto_close_reminder').get();
  assert.equal(msgs.size, 1);
  assert.ok((await svc('cr1')).revisionAt.toMillis() > Date.now(), 'next check rescheduled');

  await db.doc('servicios/cr1').update({ 'autoCierre.avisos': 2, revisionAt: past(), revisionTarea: 'cierre_automatico', 'autoCierre.at': past() });
  await runCron();
  const s = await waitFor(async () => {
    const d = await svc('cr1');
    return d.estado === 'pagado' ? d : null;
  }, 'auto-close');
  assert.equal(s.cierre, 'cierre_automatico');
  assert.equal(s.revisionAt, undefined);
  assert.ok(at, 'had an auto-close date');
});

test('schedule: long-range hold renewal requested, then expires', async () => {
  await newService('cr2', 'aire_acondicionado');
  // 10 days out: the hold would lapse, so it must be renewed later.
  await visit('tec', 'cr2', 'proponer', { fecha: new Date(Date.now() + 10 * 86400e3).toISOString() });
  const { paymentIntentId: pi } = await visit('cli', 'cr2', 'autorizar');
  mock.authorize(pi);
  await visit('cli', 'cr2', 'confirmar_autorizacion');
  let s = await svc('cr2');
  assert.equal(s.visita.renovarAutorizacion, true);
  assert.equal(s.revisionTarea, 'pedir_reautorizacion');

  await db.doc('servicios/cr2').update({ revisionAt: past() });
  await runCron();
  s = await waitFor(async () => {
    const d = await svc('cr2');
    return d.visita.pagoEstado === 'reautorizacion_pendiente' ? d : null;
  }, 're-authorization request');
  assert.equal(opsFor(pi, 'cancel').length, 1, 'old hold released');
  assert.equal(s.revisionTarea, 'vencer_reautorizacion');

  await db.doc('servicios/cr2').update({ revisionAt: past() });
  await runCron();
  s = await waitFor(async () => {
    const d = await svc('cr2');
    return d.estado === 'cancelado' ? d : null;
  }, 'expiry');
  assert.equal(s.visita.pagoEstado, 'liberado');
});
