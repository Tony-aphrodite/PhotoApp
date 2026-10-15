import { test } from 'node:test';
import assert from 'node:assert/strict';
import { distanceKm, scoreTechnician, technicianBecameAssignable } from './assignment-rules';

test('score: rating, workload, proximity and experience', () => {
  assert.equal(scoreTechnician({ activos: 0 }), 30, 'free and unrated');
  assert.equal(scoreTechnician({ activos: 3 }), 0, 'three jobs in flight: no workload points');
  assert.equal(scoreTechnician({ calificacionPromedio: 5, serviciosCompletados: 50, activos: 0 }), 80);
  const here = { latitude: 19.43, longitude: -99.13 };
  assert.ok(scoreTechnician({ activos: 0, ubicacionDefecto: here }, here) > 49.9, 'same spot: full proximity');
  assert.ok(distanceKm(here, { latitude: 19.52, longitude: -99.13 }) > 9);
});

test('a técnico becomes assignable on the changes that can make him match', () => {
  const ready = { rol: 'tecnico', disponible: true, activo: true, especialidades: ['pintura'] };
  assert.equal(technicianBecameAssignable({ ...ready, disponible: false }, ready), true, 'back to available');
  assert.equal(technicianBecameAssignable({ ...ready, especialidades: ['plomeria'] }, ready), true, 'new specialty');
  assert.equal(technicianBecameAssignable(ready, { ...ready, stripeConnectAccountId: 'acct_1' }), true, 'payouts connected');
  assert.equal(technicianBecameAssignable(ready, { ...ready, correoVerificadoAt: 'ts' }), true, 'email verified');
});

test('and not on anything else', () => {
  const ready = { rol: 'tecnico', disponible: true, activo: true, especialidades: ['pintura'] };
  assert.equal(technicianBecameAssignable(ready, { ...ready }), false, 'push token, counters…');
  assert.equal(technicianBecameAssignable(ready, { ...ready, disponible: false }), false, 'went unavailable');
  assert.equal(technicianBecameAssignable({ ...ready, rol: 'cliente' }, { ...ready, rol: 'cliente' }), false);
  assert.equal(technicianBecameAssignable(undefined, { ...ready, especialidades: [] }), false, 'no specialty');
});
