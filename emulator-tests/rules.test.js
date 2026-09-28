// Firestore security rules, exercised as real clients would call them.
// Run by run.sh inside `firebase emulators:exec`.
const fs = require('fs');
const path = require('path');
const { test, before, after, beforeEach } = require('node:test');
const {
  initializeTestEnvironment, assertSucceeds, assertFails,
} = require('@firebase/rules-unit-testing');
const {
  doc, setDoc, updateDoc, writeBatch, serverTimestamp, Timestamp,
} = require('firebase/firestore');

let env;
const verified = (uid) => env.authenticatedContext(uid, { email_verified: true }).firestore();

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-rules',
    firestore: { rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8') },
  });
});
after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/cli'), { rol: 'cliente', activo: true, telefono: '5511111111' });
    await setDoc(doc(db, 'users/tec'), { rol: 'tecnico', activo: true, telefono: '5522222222' });
    const base = { clienteId: 'cli', tecnicoId: 'tec', tipoAsignacion: 'automatica' };
    await setDoc(doc(db, 'servicios/std'), { ...base, estado: 'asignado', flujo: 'estandar' });
    await setDoc(doc(db, 'servicios/diag'), { ...base, estado: 'asignado', flujo: 'diagnostico', visita: { precio: 400 } });
    await setDoc(doc(db, 'servicios/pend'), { clienteId: 'cli', estado: 'pendiente', tipoAsignacion: 'automatica' });
  });
});

test('cliente cannot set money or flow fields on their service', async () => {
  const db = verified('cli');
  await assertFails(updateDoc(doc(db, 'servicios/pend'), { costoFinal: 1 }));
  await assertFails(updateDoc(doc(db, 'servicios/pend'), { flujo: 'estandar' }));
  await assertFails(updateDoc(doc(db, 'servicios/pend'), { visita: { precio: 0 } }));
  await assertFails(updateDoc(doc(db, 'servicios/pend'), { estado: 'completado' }), 'no state jumps');
  await assertSucceeds(updateDoc(doc(db, 'servicios/pend'), { descripcion: 'ok' }));
});

test('cliente cannot create a service carrying server fields', async () => {
  const db = verified('cli');
  const base = { clienteId: 'cli', estado: 'pendiente', tipoAsignacion: 'automatica' };
  // As the app writes it: the request plus the profile stamp, in one batch.
  const request = (id, data) => {
    const b = writeBatch(db);
    b.set(doc(db, `servicios/${id}`), data);
    b.update(doc(db, 'users/cli'), { ultimaSolicitudAt: serverTimestamp() });
    return b.commit();
  };
  // Refused ones first: a failed batch writes nothing, so the stamp stays
  // empty and only the server field can be what the rule refuses.
  await assertFails(request('n2', { ...base, flujo: 'estandar' }));
  await assertFails(request('n3', { ...base, costoFinal: 5 }));
  await assertSucceeds(request('n1', base));
});

test('a cliente cannot create requests in bursts', async () => {
  const db = verified('cli');
  const base = { clienteId: 'cli', estado: 'pendiente', tipoAsignacion: 'automatica' };
  const stamp = { ultimaSolicitudAt: serverTimestamp() };
  // What the app does: the request and the stamp in one batch.
  const request = (id) => {
    const b = writeBatch(db);
    b.set(doc(db, `servicios/${id}`), base);
    b.update(doc(db, 'users/cli'), stamp);
    return b.commit();
  };
  const stampedAt = (ms) => env.withSecurityRulesDisabled((ctx) =>
    updateDoc(doc(ctx.firestore(), 'users/cli'), { ultimaSolicitudAt: Timestamp.fromMillis(ms) }));

  await assertSucceeds(request('b1'), 'first request');
  await assertFails(request('b2'), 'second one within 30 s');
  await assertFails(setDoc(doc(db, 'servicios/b3'), base), 'a request that does not renew the stamp');

  await stampedAt(Date.now() - 31 * 1000);
  await assertSucceeds(request('b4'), 'allowed again after 30 s');

  // The stamp can only be set to the server's time: backdating it would
  // defeat the limit.
  await assertFails(updateDoc(doc(db, 'users/cli'), { ultimaSolicitudAt: Timestamp.fromMillis(0) }));
  await assertSucceeds(updateDoc(doc(db, 'users/cli'), stamp));
});

test('parallel requests: only one gets through', async () => {
  const db = verified('cli');
  const base = { clienteId: 'cli', estado: 'pendiente', tipoAsignacion: 'automatica' };
  // Five batches fired at once, as a script would: each writes the same
  // profile, so Firestore serializes them and the rule sees the first stamp.
  const results = await Promise.allSettled([1, 2, 3, 4, 5].map((i) => {
    const b = writeBatch(db);
    b.set(doc(db, `servicios/p${i}`), base);
    b.update(doc(db, 'users/cli'), { ultimaSolicitudAt: serverTimestamp() });
    return b.commit();
  }));
  const ok = results.filter((r) => r.status === 'fulfilled').length;
  if (ok !== 1) throw new Error(`expected exactly 1 of 5 parallel requests to succeed, got ${ok}`);
});

test('direct cancel: allowed for standard flow, refused for diagnostic', async () => {
  const db = verified('cli');
  await assertSucceeds(updateDoc(doc(db, 'servicios/std'), { estado: 'cancelado', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(db, 'servicios/diag'), { estado: 'cancelado', updatedAt: serverTimestamp() }));
});

test('técnico cannot write service state; nobody writes quotations', async () => {
  const tec = verified('tec');
  await assertFails(updateDoc(doc(tec, 'servicios/std'), { estado: 'completado' }));
  await assertFails(setDoc(doc(tec, 'cotizaciones/q1'), {
    servicioId: 'std', tecnicoId: 'tec', clienteId: 'cli', estado: 'pendiente', total: 1,
  }));
});

test('users cannot touch their incidents, rating or phone', async () => {
  const tec = verified('tec');
  await assertFails(updateDoc(doc(tec, 'users/tec'), { 'incidencias.noSePresento': 0 }));
  await assertFails(updateDoc(doc(tec, 'users/tec'), { telefono: '5599999999' }));
  await assertSucceeds(updateDoc(doc(tec, 'users/tec'), { disponible: false }));
});

test('registration claims the phone; a second account cannot take it', async () => {
  const a = env.authenticatedContext('newA').firestore();
  const batchA = writeBatch(a);
  batchA.set(doc(a, 'users/newA'), { rol: 'cliente', telefono: '5533333333' });
  batchA.set(doc(a, 'telefonos/5533333333'), { uid: 'newA', createdAt: serverTimestamp() });
  await assertSucceeds(batchA.commit());

  const b = env.authenticatedContext('newB').firestore();
  const batchB = writeBatch(b);
  batchB.set(doc(b, 'users/newB'), { rol: 'cliente', telefono: '5533333333' });
  batchB.set(doc(b, 'telefonos/5533333333'), { uid: 'newB', createdAt: serverTimestamp() });
  await assertFails(batchB.commit());

  const c = env.authenticatedContext('newC').firestore();
  await assertFails(setDoc(doc(c, 'users/newC'), { rol: 'admin', telefono: '5544444444' }), 'never admin');
});

test('activity writes need a verified email', async () => {
  const unverified = env.authenticatedContext('cli', { email_verified: false }).firestore();
  await assertFails(setDoc(doc(unverified, 'servicios/n9'), {
    clienteId: 'cli', estado: 'pendiente', tipoAsignacion: 'automatica',
  }));
});
