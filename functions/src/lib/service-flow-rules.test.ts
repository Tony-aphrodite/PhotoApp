import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  ESTADO,
  FlowError,
  closingFor,
  priceQuotation,
  quotationKindFor,
  stateAfterResponse,
  stateAfterSubmit,
  stateAfterWorkAction,
  validateStop,
} from './service-flow-rules';

const item = (over: Record<string, unknown> = {}) => ({
  descripcion: 'Instalación',
  tipo: 'mano_obra',
  cantidad: 1,
  precioUnitario: 1000,
  ...over,
});

test('prices a quotation server-side with 16% IVA', () => {
  const q = priceQuotation([item(), item({ tipo: 'material', cantidad: 3, precioUnitario: 33.333 })]);
  // 33.333 rounds to 33.33; 3 × 33.33 = 99.99
  assert.equal(q.subtotal, 1099.99);
  assert.equal(q.impuestos, 176);
  assert.equal(q.total, 1275.99);
});

test('rejects malformed quotation items', () => {
  assert.throws(() => priceQuotation([]), FlowError);
  assert.throws(() => priceQuotation([item({ descripcion: '  ' })]), FlowError);
  assert.throws(() => priceQuotation([item({ tipo: 'regalo' })]), FlowError);
  assert.throws(() => priceQuotation([item({ cantidad: 1.5 })]), FlowError);
  assert.throws(() => priceQuotation([item({ cantidad: 0 })]), FlowError);
  assert.throws(() => priceQuotation([item({ precioUnitario: -5 })]), FlowError);
  assert.throws(() => priceQuotation([item({ precioUnitario: '100' })]), FlowError);
  assert.throws(() => priceQuotation([item({ precioUnitario: 1 })]), FlowError, 'below Stripe minimum');
});

test('initial quote before work, revision once working, nothing otherwise', () => {
  assert.equal(quotationKindFor(ESTADO.asignado), 'inicial');
  assert.equal(quotationKindFor(ESTADO.cotizacionRechazada), 'inicial');
  assert.equal(quotationKindFor(ESTADO.enProgreso), 'revision');
  assert.equal(quotationKindFor(ESTADO.revisionRechazada), 'revision');
  for (const e of [ESTADO.pendiente, ESTADO.cotizacionEnviada, ESTADO.cotizacionAprobada,
    ESTADO.revisionEnviada, ESTADO.detenido, ESTADO.completado, ESTADO.pagado]) {
    assert.equal(quotationKindFor(e), null, e);
  }
});

test('quotation responses move the service correctly', () => {
  assert.equal(stateAfterSubmit('inicial'), ESTADO.cotizacionEnviada);
  assert.equal(stateAfterSubmit('revision'), ESTADO.revisionEnviada);
  assert.equal(stateAfterResponse('inicial', true), ESTADO.cotizacionAprobada);
  assert.equal(stateAfterResponse('inicial', false), ESTADO.cotizacionRechazada);
  assert.equal(stateAfterResponse('revision', true), ESTADO.enProgreso);
  assert.equal(stateAfterResponse('revision', false), ESTADO.revisionRechazada);
});

test('work cannot start without an approved quotation', () => {
  assert.equal(stateAfterWorkAction('iniciar', ESTADO.asignado), null);
  assert.equal(stateAfterWorkAction('iniciar', ESTADO.cotizacionEnviada), null);
  assert.equal(stateAfterWorkAction('iniciar', ESTADO.cotizacionAprobada), ESTADO.enProgreso);
  assert.equal(stateAfterWorkAction('completar', ESTADO.revisionEnviada), null, 'pending revision blocks completion');
  assert.equal(stateAfterWorkAction('completar', ESTADO.enProgreso), ESTADO.completado);
  assert.equal(stateAfterWorkAction('continuar_original', ESTADO.revisionRechazada), ESTADO.enProgreso);
  assert.equal(stateAfterWorkAction('continuar_original', ESTADO.enProgreso), null);
});

test('stopping work requires evidence and caps the amount', () => {
  const ok = { motivo: 'riesgo_seguridad', descripcion: 'Cableado dañado en el muro', fotos: ['https://x/1.jpg'], montoPropuesto: 500 };
  assert.deepEqual(validateStop(ok, 1200), ok);
  assert.throws(() => validateStop({ ...ok, fotos: [] }, 1200), FlowError);
  assert.throws(() => validateStop({ ...ok, motivo: 'flojera' }, 1200), FlowError);
  assert.throws(() => validateStop({ ...ok, descripcion: 'no' }, 1200), FlowError);
  assert.throws(() => validateStop({ ...ok, montoPropuesto: 1200.01 }, 1200), FlowError);
  assert.equal(validateStop({ ...ok, montoPropuesto: 1200 }, 1200).montoPropuesto, 1200);
});

test('a closing amount below the Stripe minimum closes with nothing to pay', () => {
  assert.deepEqual(closingFor(500), { estado: ESTADO.completado, costoFinal: 500 });
  assert.deepEqual(closingFor(0), { estado: ESTADO.cancelado, costoFinal: null });
  assert.deepEqual(closingFor(9.99), { estado: ESTADO.cancelado, costoFinal: null });
});
