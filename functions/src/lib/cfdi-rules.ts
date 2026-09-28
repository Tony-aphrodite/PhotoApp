/**
 * What goes on a CFDI — decided without touching Firestore, FacturAPI or the
 * clock, so every case the accountant described is covered by a test.
 *
 * The accountant's rules (2026-09-23):
 *   - The diagnostic visit and the repair are two independent CFDIs. The
 *     visit's is stamped when the diagnosis is *finished*, never when the card
 *     is charged, and not at all if the técnico never diagnosed anything.
 *   - A refund is never a cancellation: it is a CFDI de egreso (nota de
 *     crédito) related to the CFDI de ingreso, for the amount returned.
 *   - When the repair ends up costing less than the visit, both concepts
 *     ideally travel on the single CFDI that was charged.
 *
 * Every `importe` here is in MXN **with IVA included**, which is how ServiTec
 * quotes and charges; FacturAPI is told so explicitly (`tax_included`).
 */

/** SAT ClaveProdServ used until the accountant confirms one per category:
 * "Instalación y mantenimiento de equipos y sistemas". */
export const SAT_KEY_DEFAULT = '81111500';

export const IVA_RATE = 0.16;

/** `use` (UsoCFDI) — a receptor without an RFC is billed as público en
 * general, which SAT requires to carry S01 on any comprobante. */
export const USO_INGRESO = 'G03'; // Gastos en general
export const USO_EGRESO = 'G02'; // Devoluciones, descuentos o bonificaciones
export const USO_PUBLICO = 'S01'; // Sin efectos fiscales

export type Concepto = 'servicio' | 'saldo' | 'visita';

export interface CfdiLine {
  descripcion: string;
  claveProdServ: string;
  /** MXN, IVA included. */
  importe: number;
}

export const round2 = (n: number): number => Math.round(n * 100) / 100;

/** Splits an IVA-included total the way the printed representation shows it. */
export function splitIva(totalConIva: number): { subtotal: number; iva: number; total: number } {
  const total = round2(totalConIva);
  const subtotal = round2(total / (1 + IVA_RATE));
  return { subtotal, iva: round2(total - subtotal), total };
}

export const usoFor = (hasRfc: boolean, egreso = false): string =>
  !hasRfc ? USO_PUBLICO : egreso ? USO_EGRESO : USO_INGRESO;

/**
 * The line(s) for the charge that just succeeded.
 *
 * In the diagnostic flow the client pays twice, so this CFDI covers only what
 * was actually charged now — the visit already has its own. Invoicing
 * `costoFinal` here would bill the visit a second time.
 */
export function chargeLines(p: {
  titulo: string;
  cobradoMxn: number;
  visitaPagadaMxn: number;
  claveProdServ: string;
}): CfdiLine[] {
  const saldo = p.visitaPagadaMxn > 0;
  return [
    {
      descripcion: saldo ? `Saldo de reparación — ${p.titulo}` : p.titulo,
      claveProdServ: p.claveProdServ,
      importe: round2(p.cobradoMxn),
    },
  ];
}

/** The line for the diagnostic visit, stamped once the diagnosis is done. */
export function visitLine(p: { titulo: string; importeMxn: number; claveProdServ: string }): CfdiLine {
  return {
    descripcion: `Visita y diagnóstico técnico — ${p.titulo}`,
    claveProdServ: p.claveProdServ,
    importe: round2(p.importeMxn),
  };
}

/**
 * The line of a nota de crédito. A partial refund keeps the original concept
 * and carries only the amount returned, as the accountant asked.
 */
export function creditNoteLine(p: {
  origen: CfdiLine | { descripcion: string; claveProdServ: string };
  importeMxn: number;
  motivo: string;
}): CfdiLine {
  return {
    descripcion: `Devolución — ${p.origen.descripcion} (${p.motivo})`,
    claveProdServ: p.origen.claveProdServ,
    importe: round2(p.importeMxn),
  };
}

/** Deterministic `facturas` ids, so a retry never stamps a second CFDI. */
export const visitFacturaId = (servicioId: string): string => `vis_${servicioId}`;
export const creditNoteId = (origenFacturaId: string, importeMxn: number): string =>
  `nc_${origenFacturaId}_${Math.round(round2(importeMxn) * 100)}`;
