import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  SAT_KEY_DEFAULT,
  USO_EGRESO,
  USO_INGRESO,
  USO_PUBLICO,
  chargeLines,
  creditNoteId,
  creditNoteLine,
  splitIva,
  usoFor,
  visitFacturaId,
  visitLine,
} from './cfdi-rules';

test('splitIva breaks an IVA-included total the way the PDF prints it', () => {
  assert.deepEqual(splitIva(1160), { subtotal: 1000, iva: 160, total: 1160 });
  assert.deepEqual(splitIva(400), { subtotal: 344.83, iva: 55.17, total: 400 });
});

test('a standard charge is invoiced for what was charged', () => {
  assert.deepEqual(
    chargeLines({ titulo: 'Fuga en cocina', cobradoMxn: 1160, visitaPagadaMxn: 0, claveProdServ: SAT_KEY_DEFAULT }),
    [{ descripcion: 'Fuga en cocina', claveProdServ: SAT_KEY_DEFAULT, importe: 1160 }],
  );
});

test('with a visit already invoiced, only the balance is invoiced again', () => {
  // Price 1160, visit 400 already paid and stamped: this CFDI is for 760.
  const lines = chargeLines({
    titulo: 'Fuga en cocina', cobradoMxn: 760, visitaPagadaMxn: 400, claveProdServ: '81111500',
  });
  assert.equal(lines.length, 1);
  assert.equal(lines[0].importe, 760, 'never the full costoFinal — the visit would be billed twice');
  assert.match(lines[0].descripcion, /^Saldo de reparación/);
});

test('the visit line carries its own SAT key', () => {
  assert.deepEqual(visitLine({ titulo: 'No enfría', importeMxn: 400, claveProdServ: '81101500' }), {
    descripcion: 'Visita y diagnóstico técnico — No enfría',
    claveProdServ: '81101500',
    importe: 400,
  });
});

test('a nota de crédito keeps the concept and carries the amount returned', () => {
  const origen = { descripcion: 'Visita y diagnóstico técnico — No enfría', claveProdServ: '81101500' };
  assert.deepEqual(creditNoteLine({ origen, importeMxn: 100, motivo: 'reembolso parcial' }), {
    descripcion: 'Devolución — Visita y diagnóstico técnico — No enfría (reembolso parcial)',
    claveProdServ: '81101500',
    importe: 100,
  });
});

test('uso: público en general always S01, egreso G02', () => {
  assert.equal(usoFor(true), USO_INGRESO);
  assert.equal(usoFor(true, true), USO_EGRESO);
  assert.equal(usoFor(false), USO_PUBLICO);
  assert.equal(usoFor(false, true), USO_PUBLICO);
});

test('ids are deterministic, so a retry cannot stamp a second CFDI', () => {
  assert.equal(visitFacturaId('svc1'), 'vis_svc1');
  assert.equal(creditNoteId('vis_svc1', 100), 'nc_vis_svc1_10000');
  assert.equal(creditNoteId('vis_svc1', 100), creditNoteId('vis_svc1', 100.0));
  assert.notEqual(creditNoteId('vis_svc1', 100), creditNoteId('vis_svc1', 400));
});
