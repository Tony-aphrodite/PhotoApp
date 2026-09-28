/**
 * Stamping CFDIs at FacturAPI: the single pipeline every comprobante goes
 * through — ingreso for a charge, egreso (nota de crédito) for a refund.
 *
 * The emisor is always the *técnico*, through their own FacturAPI
 * organization; ServiTec only stamps its monthly commission (see
 * monthly-commission-cron.ts). A técnico who is still in the grace period has
 * no organization key, so the comprobante is queued for an admin instead of
 * failing the flow that called us — money movements must never depend on the
 * SAT being reachable.
 *
 * Every entry point takes a deterministic `facturas` document id, so a retried
 * callable or a redelivered webhook finds the existing row and stamps nothing.
 */

import { db, FieldValue } from './admin';
import { Data } from './flow-helpers';
import { facturapiForOrg } from './facturapi';
import { renderBrandedCfdiPdf } from './pdf';
import { uploadCfdiPdf, uploadCfdiXml } from './storage';
import { buildCadenaOriginalTfd, downloadAsBuffer, extractXmlAttr } from './cfdi-xml';
import { categoryConfig } from './visit-store';
import { visitPaidOf } from './visit-rules';
import {
  CfdiLine,
  Concepto,
  SAT_KEY_DEFAULT,
  chargeLines,
  creditNoteId,
  creditNoteLine,
  splitIva,
  usoFor,
  visitFacturaId,
  visitLine,
} from './cfdi-rules';

export interface Receptor {
  legal_name: string;
  tax_id: string;
  tax_system: string;
  address: { zip: string };
}

export interface StampResult {
  facturaId: string;
  folioFiscal: string;
}

/**
 * The SAT key for a category, as the admin panel stores it. Falls back to the
 * generic technical-services key while the accountant's list is pending, so
 * nothing blocks on it.
 */
export async function claveProdServFor(
  categoria: string,
  kind: 'servicio' | 'diagnostico',
): Promise<string> {
  const c = await categoryConfig(categoria);
  const key = kind === 'diagnostico' ? c.claveDiagnostico : c.claveProdServ;
  return typeof key === 'string' && key.trim().length >= 8 ? key.trim() : SAT_KEY_DEFAULT;
}

/**
 * Receptor data for a cliente. Without an RFC on their profile the CFDI goes
 * to público en general (SAT's generic RFC), which needs a ZIP all the same —
 * the emisor's stands in.
 */
export function receptorFor(cliente: Data, tecnico: Data): { receptor: Receptor; hasRfc: boolean } {
  const hasRfc = typeof cliente.rfc === 'string' && cliente.rfc.length >= 12;
  const zip = (cliente.codigoPostalFiscal as string) || (tecnico.codigoPostalFiscal as string) || '00000';
  return {
    hasRfc,
    receptor: hasRfc
      ? {
          legal_name: (cliente.razonSocial as string) ||
            `${cliente.nombre ?? ''} ${cliente.apellido ?? ''}`.trim(),
          tax_id: cliente.rfc as string,
          tax_system: (cliente.regimenFiscal as string) || '616',
          address: { zip },
        }
      : {
          legal_name: 'PUBLICO EN GENERAL',
          tax_id: 'XAXX010101000',
          tax_system: '616', // Sin obligaciones fiscales
          address: { zip: (tecnico.codigoPostalFiscal as string) || '00000' },
        },
  };
}

const itemsFor = (lines: CfdiLine[]) =>
  lines.map((l) => ({
    quantity: 1,
    product: {
      description: l.descripcion,
      product_key: l.claveProdServ,
      // Our prices are quoted with IVA included; say so rather than relying on
      // whichever default the SDK version ships with.
      price: l.importe,
      tax_included: true,
    },
  }));

async function flag(type: string, payload: Data): Promise<void> {
  await db.collection('admin_flags').add({
    type,
    ...payload,
    estado: 'pendiente',
    createdAt: FieldValue.serverTimestamp(),
  });
}

async function systemMessage(servicioId: string, mensaje: string, metadata: Data): Promise<void> {
  await db.collection('servicios').doc(servicioId).collection('mensajes').add({
    userId: 'system',
    nombreUsuario: 'ServiTec',
    mensaje,
    tipo: 'sistema',
    timestamp: FieldValue.serverTimestamp(),
    leido: false,
    metadata,
  });
}

/**
 * Downloads the stamped XML, renders the branded PDF and stores both. A
 * failure here is not fatal: the CFDI already exists at the SAT, so the row is
 * saved without URLs and an admin can regenerate the artifacts.
 */
async function artifacts(p: {
  fx: any;
  invoice: any;
  facturaId: string;
  servicioId: string;
  tecnico: Data;
  receptor: Receptor;
  uso: string;
  lines: CfdiLine[];
  egreso: boolean;
}): Promise<{ xmlUrl: string | null; pdfUrl: string | null }> {
  try {
    const xmlBuf = await downloadAsBuffer(await p.fx.invoices.downloadXml(p.invoice.id));
    const xmlUrl = await uploadCfdiXml(p.facturaId, xmlBuf);
    const xmlText = xmlBuf.toString('utf8');
    const noCertSat = extractXmlAttr(xmlText, 'NoCertificadoSAT') ?? '';
    const totals = splitIva(p.lines.reduce((a, l) => a + l.importe, 0));

    const pdfBuf = await renderBrandedCfdiPdf({
      folioFiscal: p.invoice.uuid,
      fechaTimbrado: extractXmlAttr(xmlText, 'FechaTimbrado') ?? new Date().toISOString(),
      emisor: {
        rfc: (p.tecnico.rfc as string) ?? '',
        razonSocial: (p.tecnico.razonSocial as string) ??
          `${p.tecnico.nombre ?? ''} ${p.tecnico.apellido ?? ''}`.trim(),
        regimenFiscal: (p.tecnico.regimenFiscal as string) ?? '',
      },
      receptor: { rfc: p.receptor.tax_id, razonSocial: p.receptor.legal_name, usoCfdi: p.uso },
      items: p.lines.map((l) => {
        const { subtotal } = splitIva(l.importe);
        return { description: l.descripcion, quantity: 1, unitPrice: subtotal, subtotal };
      }),
      subtotal: totals.subtotal,
      iva: totals.iva,
      total: totals.total,
      selloEmisor: extractXmlAttr(xmlText, 'Sello') ?? '',
      selloSat: (extractXmlAttr(xmlText, 'SelloSAT') ?? '') + (noCertSat ? ` (Cert ${noCertSat})` : ''),
      cadenaOriginalTfd: buildCadenaOriginalTfd(xmlText),
    });
    return { xmlUrl, pdfUrl: await uploadCfdiPdf(p.facturaId, pdfBuf) };
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('CFDI artifact generation failed', err);
    await flag('cfdi_artifact_generation_failed', {
      servicioId: p.servicioId,
      facturapiInvoiceId: p.invoice.id,
      egreso: p.egreso,
      error: (err as Error).message,
    });
    return { xmlUrl: null, pdfUrl: null };
  }
}

export interface StampInput {
  /** Deterministic id — the same input never stamps twice. */
  facturaId: string;
  servicioId: string;
  tecnicoUid: string;
  clienteUid: string;
  concepto: Concepto;
  lines: CfdiLine[];
  /** Already-loaded documents, to avoid reading them a second time. */
  tecnico?: Data;
  cliente?: Data;
  /** Extra fields for the admin_flag raised if stamping has to be deferred. */
  meta?: Data;
}

/** Stamps the CFDI de ingreso for a charge. Returns null if it was deferred. */
export async function stampCfdi(input: StampInput): Promise<StampResult | null> {
  const ref = db.collection('facturas').doc(input.facturaId);
  const existing = await ref.get();
  if (existing.exists) {
    return { facturaId: ref.id, folioFiscal: (existing.data()?.folioFiscal as string) ?? '' };
  }

  const tecnico = input.tecnico ??
    (await db.collection('users').doc(input.tecnicoUid).get()).data() ?? {};
  const orgApiKey: string | undefined = (tecnico.facturapi as Data | undefined)?.organizationApiKey;
  if (!orgApiKey) {
    await flag('cfdi_pending_technician_not_configured', {
      servicioId: input.servicioId,
      tecnicoUid: input.tecnicoUid,
      concepto: input.concepto,
      monto: input.lines.reduce((a, l) => a + l.importe, 0),
      ...(input.meta ?? {}),
    });
    return null;
  }

  const cliente = input.cliente ??
    (await db.collection('users').doc(input.clienteUid).get()).data() ?? {};
  const { receptor, hasRfc } = receptorFor(cliente, tecnico);
  const uso = usoFor(hasRfc);

  const fx = facturapiForOrg(orgApiKey);
  const invoice = await fx.invoices.create({
    customer: receptor,
    items: itemsFor(input.lines),
    payment_form: '04', // tarjeta de crédito
    payment_method: 'PUE',
    use: uso,
  });

  const urls = await artifacts({
    fx, invoice, facturaId: ref.id, servicioId: input.servicioId,
    tecnico, receptor, uso, lines: input.lines, egreso: false,
  });
  const totals = splitIva(input.lines.reduce((a, l) => a + l.importe, 0));

  await ref.set({
    tipo: 'tecnico_cliente',
    concepto: input.concepto,
    tecnicoUid: input.tecnicoUid,
    clienteUid: input.clienteUid,
    servicioId: input.servicioId,
    facturapiInvoiceId: invoice.id,
    folioFiscal: invoice.uuid,
    fechaTimbrado: FieldValue.serverTimestamp(),
    subtotal: totals.subtotal,
    iva: totals.iva,
    total: totals.total,
    // Kept for the nota de crédito: it must repeat the receptor and the
    // concept of the comprobante it relates to, even if the cliente edits
    // their fiscal data afterwards.
    receptor,
    conceptos: input.lines,
    xmlUrl: urls.xmlUrl,
    pdfUrl: urls.pdfUrl,
    estado: 'vigente',
    createdAt: FieldValue.serverTimestamp(),
  });

  await systemMessage(input.servicioId, `CFDI emitido — folio ${invoice.uuid}`, {
    event: 'cfdi_emitted',
    facturaId: ref.id,
    folioFiscal: invoice.uuid,
    concepto: input.concepto,
  });
  return { facturaId: ref.id, folioFiscal: invoice.uuid };
}

/**
 * The CFDI of the diagnostic visit, stamped when the técnico finishes the
 * diagnosis — not when the card is charged, and never when the visit was
 * charged but no diagnosis happened (accountant, 2026-09-23).
 */
export async function stampVisitCfdi(servicioId: string): Promise<StampResult | null> {
  const snap = await db.collection('servicios').doc(servicioId).get();
  const s = snap.data();
  if (!s) return null;
  const importe = visitPaidOf(s);
  if (!(importe > 0)) return null;

  return stampCfdi({
    facturaId: visitFacturaId(servicioId),
    servicioId,
    tecnicoUid: s.tecnicoId as string,
    clienteUid: s.clienteId as string,
    concepto: 'visita',
    lines: [
      visitLine({
        titulo: (s.titulo as string) ?? 'Servicio',
        importeMxn: importe,
        claveProdServ: await claveProdServFor(s.categoria as string, 'diagnostico'),
      }),
    ],
  });
}

/** The CFDI for a charge that just succeeded (standard service or balance). */
export async function stampChargeCfdi(p: {
  servicioId: string;
  service: Data;
  paymentIntentId: string;
  cobradoMxn: number;
  tecnicoUid: string;
  clienteUid: string;
  tecnico?: Data;
  cliente?: Data;
}): Promise<StampResult | null> {
  const visitaPagada = visitPaidOf(p.service);
  return stampCfdi({
    facturaId: `pi_${p.paymentIntentId}`,
    servicioId: p.servicioId,
    tecnicoUid: p.tecnicoUid,
    clienteUid: p.clienteUid,
    concepto: visitaPagada > 0 ? 'saldo' : 'servicio',
    tecnico: p.tecnico,
    cliente: p.cliente,
    meta: { stripePaymentIntentId: p.paymentIntentId },
    lines: chargeLines({
      titulo: (p.service.titulo as string) ?? 'Servicio',
      cobradoMxn: p.cobradoMxn,
      visitaPagadaMxn: visitaPagada,
      claveProdServ: await claveProdServFor(p.service.categoria as string, 'servicio'),
    }),
  });
}

/**
 * The nota de crédito for a refund: a CFDI de egreso related (SAT relation
 * type 01) to the CFDI de ingreso it returns money from. A partial refund
 * carries only the amount returned.
 *
 * Returns null when there is nothing to relate to — a visit refunded before
 * the diagnosis was finished never had a CFDI, which is exactly the case the
 * accountant said not to invoice.
 */
export async function emitCreditNote(p: {
  servicioId: string;
  concepto: Concepto;
  importeMxn?: number;
  motivo: string;
}): Promise<StampResult | null> {
  const origenSnap = await db.collection('facturas')
    .where('servicioId', '==', p.servicioId)
    .where('concepto', '==', p.concepto)
    .where('tipo', '==', 'tecnico_cliente')
    .limit(1)
    .get();
  if (origenSnap.empty) return null;

  const origenRef = origenSnap.docs[0].ref;
  const origen = origenSnap.docs[0].data();
  const importe = p.importeMxn == null ? (origen.total as number) : p.importeMxn;
  if (!(importe > 0)) return null;

  const ref = db.collection('facturas').doc(creditNoteId(origenRef.id, importe));
  const existing = await ref.get();
  if (existing.exists) {
    return { facturaId: ref.id, folioFiscal: (existing.data()?.folioFiscal as string) ?? '' };
  }

  const tecnicoUid = origen.tecnicoUid as string;
  const tecnico = (await db.collection('users').doc(tecnicoUid).get()).data() ?? {};
  const orgApiKey: string | undefined = (tecnico.facturapi as Data | undefined)?.organizationApiKey;
  if (!orgApiKey) {
    await flag('nota_credito_pendiente', {
      servicioId: p.servicioId,
      tecnicoUid,
      facturaOrigenId: origenRef.id,
      folioOrigen: origen.folioFiscal,
      monto: importe,
      motivo: p.motivo,
    });
    return null;
  }

  const receptor = (origen.receptor as Receptor | undefined) ??
    receptorFor((await db.collection('users').doc(origen.clienteUid as string).get()).data() ?? {}, tecnico).receptor;
  const uso = usoFor(receptor.tax_id !== 'XAXX010101000', true);
  const origenLine = (origen.conceptos as CfdiLine[] | undefined)?.[0] ??
    { descripcion: (origen.concepto as string) ?? 'Servicio', claveProdServ: SAT_KEY_DEFAULT, importe };
  const lines = [creditNoteLine({ origen: origenLine, importeMxn: importe, motivo: p.motivo })];

  const fx = facturapiForOrg(orgApiKey);
  const invoice = await fx.invoices.create({
    type: 'E', // egreso
    customer: receptor,
    items: itemsFor(lines),
    relation: '01', // nota de crédito de los documentos relacionados
    related: [origen.folioFiscal],
    payment_form: '04',
    payment_method: 'PUE',
    use: uso,
  });

  const urls = await artifacts({
    fx, invoice, facturaId: ref.id, servicioId: p.servicioId,
    tecnico, receptor, uso, lines, egreso: true,
  });
  const totals = splitIva(importe);

  await ref.set({
    tipo: 'nota_credito',
    concepto: p.concepto,
    motivo: p.motivo,
    facturaOrigenId: origenRef.id,
    folioOrigen: origen.folioFiscal,
    tecnicoUid,
    clienteUid: origen.clienteUid,
    servicioId: p.servicioId,
    facturapiInvoiceId: invoice.id,
    folioFiscal: invoice.uuid,
    fechaTimbrado: FieldValue.serverTimestamp(),
    subtotal: totals.subtotal,
    iva: totals.iva,
    total: totals.total,
    receptor,
    conceptos: lines,
    xmlUrl: urls.xmlUrl,
    pdfUrl: urls.pdfUrl,
    estado: 'vigente',
    createdAt: FieldValue.serverTimestamp(),
  });
  await origenRef.update({
    montoDevuelto: FieldValue.increment(totals.total),
    notasCredito: FieldValue.arrayUnion(ref.id),
  });

  await systemMessage(p.servicioId,
    `Nota de crédito emitida por $${totals.total.toFixed(2)} MXN (${p.motivo}) — folio ${invoice.uuid}`,
    { event: 'cfdi_credit_note', facturaId: ref.id, folioFiscal: invoice.uuid, monto: totals.total });
  return { facturaId: ref.id, folioFiscal: invoice.uuid };
}

/**
 * CFDI work that must never break the flow that triggered it: the money has
 * already moved, so a FacturAPI outage becomes an admin task, not an error
 * thrown back at the técnico or the cliente.
 */
export async function cfdiSafely<T>(
  what: string,
  servicioId: string,
  fn: () => Promise<T>,
): Promise<T | null> {
  try {
    return await fn();
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(`CFDI step "${what}" failed for ${servicioId}`, err);
    await flag('cfdi_fallido', { servicioId, paso: what, error: (err as Error).message })
      .catch(() => undefined);
    return null;
  }
}
