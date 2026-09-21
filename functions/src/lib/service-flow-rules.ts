/**
 * The service flow's rules, kept free of Firebase so they can be unit-tested.
 *
 * One flow for every service (Phase 1 — no paid diagnostic yet):
 *
 *   asignado ──submit──▶ cotizacion_enviada ──approve──▶ cotizacion_aprobada
 *      ▲                        │ reject                        │ iniciar
 *      └──── cotizacion_rechazada ◀┘                            ▼
 *                                                          en_progreso ──completar──▶ completado ──pay──▶ pagado
 *                                          submit revision │    ▲ approve
 *                                                          ▼    │
 *                                                   revision_enviada
 *                                                          │ reject
 *                                                          ▼
 *                                                  revision_rechazada ──continuar_original──▶ en_progreso
 *                                                          │ (also from en_progreso)
 *                                                          ▼ detener
 *                                                      detenido ──cliente acepta──▶ completado / cancelado
 *                                                          │ cliente disputa
 *                                                          ▼
 *                                                     en_disputa ──admin resuelve──▶ completado / cancelado
 *
 * Every price the cliente pays is one they approved: an approved cotización
 * total, or — when work was stopped — an amount they accepted or an admin
 * set after a dispute. The Dart mirror of these state names lives in
 * AppConstants; keep both in step.
 */

export const ESTADO = {
  pendiente: 'pendiente',
  asignado: 'asignado',
  cotizacionEnviada: 'cotizacion_enviada',
  cotizacionRechazada: 'cotizacion_rechazada',
  cotizacionAprobada: 'cotizacion_aprobada',
  enProgreso: 'en_progreso',
  revisionEnviada: 'revision_enviada',
  revisionRechazada: 'revision_rechazada',
  detenido: 'detenido',
  enDisputa: 'en_disputa',
  completado: 'completado',
  pagado: 'pagado',
  cancelado: 'cancelado',
  // Diagnostic-visit flow (Phase 2) — see lib/visit-rules.ts.
  visitaPropuesta: 'visita_propuesta',
  visitaConfirmada: 'visita_confirmada',
  enCamino: 'en_camino',
  diagnosticoRealizado: 'diagnostico_realizado',
  reporteNoLlego: 'reporte_no_llego',
  // Written by the old client-side approval before this flow existed.
  legacyEnReparacion: 'en_reparacion',
} as const;

/** States where the técnico is working (or was, until a stop). */
export const ACTIVE_WORK_STATES: string[] = [
  ESTADO.asignado,
  ESTADO.visitaPropuesta,
  ESTADO.visitaConfirmada,
  ESTADO.enCamino,
  ESTADO.diagnosticoRealizado,
  ESTADO.reporteNoLlego,
  ESTADO.cotizacionEnviada,
  ESTADO.cotizacionRechazada,
  ESTADO.cotizacionAprobada,
  ESTADO.enProgreso,
  ESTADO.revisionEnviada,
  ESTADO.revisionRechazada,
  ESTADO.detenido,
  ESTADO.enDisputa,
];

/** Stripe's minimum charge in MXN. A closing amount below it means no charge. */
export const MIN_CHARGE_MXN = 10;

export const ITEM_TYPES = ['mano_obra', 'material', 'pieza'] as const;
export const IVA_RATE = 0.16;

export const STOP_REASONS: Record<string, string> = {
  riesgo_seguridad: 'Riesgo de seguridad',
  dano_impide_terminar: 'Un daño impide terminar el trabajo',
  pieza_indispensable: 'Falta una pieza indispensable',
  otro: 'Otro motivo',
};

/** A rule was broken; `message` is Spanish and safe to show the user. */
export class FlowError extends Error {}

export const round2 = (n: number): number => Math.round(n * 100) / 100;

export type QuotationKind = 'inicial' | 'revision';

export interface QuotationItem {
  descripcion: string;
  tipo: string;
  cantidad: number;
  precioUnitario: number;
  subtotal: number;
}

/**
 * Validates the técnico's line items and prices them. Totals are always
 * computed here — never taken from the app — so what the cliente approves is
 * exactly the sum of the lines they are shown.
 */
export function priceQuotation(rawItems: unknown): {
  items: QuotationItem[];
  subtotal: number;
  impuestos: number;
  total: number;
} {
  if (!Array.isArray(rawItems) || rawItems.length === 0) {
    throw new FlowError('Agrega al menos un concepto a la cotización.');
  }
  if (rawItems.length > 30) {
    throw new FlowError('La cotización admite máximo 30 conceptos.');
  }

  const items = rawItems.map((raw, i): QuotationItem => {
    const n = i + 1;
    const r = (raw ?? {}) as Record<string, unknown>;
    const descripcion = typeof r.descripcion === 'string' ? r.descripcion.trim() : '';
    if (!descripcion) throw new FlowError(`El concepto ${n} no tiene descripción.`);
    if (descripcion.length > 200) {
      throw new FlowError(`La descripción del concepto ${n} es demasiado larga.`);
    }
    const tipo = r.tipo as string;
    if (!(ITEM_TYPES as readonly string[]).includes(tipo)) {
      throw new FlowError(`El concepto ${n} tiene un tipo inválido.`);
    }
    const cantidad = r.cantidad;
    if (typeof cantidad !== 'number' || !Number.isInteger(cantidad) || cantidad < 1 || cantidad > 999) {
      throw new FlowError(`La cantidad del concepto ${n} debe ser un número entero entre 1 y 999.`);
    }
    const precio = r.precioUnitario;
    if (typeof precio !== 'number' || !Number.isFinite(precio) || precio < 0 || precio > 1_000_000) {
      throw new FlowError(`El precio del concepto ${n} no es válido.`);
    }
    const precioUnitario = round2(precio);
    return { descripcion, tipo, cantidad, precioUnitario, subtotal: round2(cantidad * precioUnitario) };
  });

  const subtotal = round2(items.reduce((s, it) => s + it.subtotal, 0));
  const impuestos = round2(subtotal * IVA_RATE);
  const total = round2(subtotal + impuestos);
  if (total < MIN_CHARGE_MXN) {
    throw new FlowError(`El total de la cotización debe ser de al menos $${MIN_CHARGE_MXN} MXN.`);
  }
  return { items, subtotal, impuestos, total };
}

/**
 * Which kind of cotización the técnico may send from `estado`, or null when
 * none may be sent. Before work starts it is the initial quote (resent after a
 * rejection); once working it is a revision.
 */
export function quotationKindFor(estado: string): QuotationKind | null {
  switch (estado) {
    case ESTADO.asignado:
    case ESTADO.cotizacionRechazada:
    // Diagnostic flow: the repair quote comes once the técnico is on site.
    case ESTADO.enCamino:
    case ESTADO.diagnosticoRealizado:
      return 'inicial';
    case ESTADO.enProgreso:
    case ESTADO.revisionRechazada:
      return 'revision';
    default:
      return null;
  }
}

export function stateAfterSubmit(kind: QuotationKind): string {
  return kind === 'inicial' ? ESTADO.cotizacionEnviada : ESTADO.revisionEnviada;
}

/** The state a service must be in for a pending cotización of `kind` to be answered. */
export function awaitingStateFor(kind: QuotationKind): string {
  return stateAfterSubmit(kind);
}

export function stateAfterResponse(kind: QuotationKind, aprobada: boolean): string {
  if (kind === 'inicial') {
    return aprobada ? ESTADO.cotizacionAprobada : ESTADO.cotizacionRechazada;
  }
  // An approved revision puts the técnico straight back to work; a rejected
  // one leaves them to choose between the original scope and stopping.
  return aprobada ? ESTADO.enProgreso : ESTADO.revisionRechazada;
}

export type WorkAction = 'iniciar' | 'continuar_original' | 'completar';

/** Next state for a técnico work action, or null if it is not allowed now. */
export function stateAfterWorkAction(accion: string, estado: string): string | null {
  switch (accion) {
    case 'iniciar':
      return estado === ESTADO.cotizacionAprobada || estado === ESTADO.legacyEnReparacion
        ? ESTADO.enProgreso
        : null;
    case 'continuar_original':
      return estado === ESTADO.revisionRechazada ? ESTADO.enProgreso : null;
    case 'completar':
      return estado === ESTADO.enProgreso ? ESTADO.completado : null;
    default:
      return null;
  }
}

export const STOPPABLE_STATES: string[] = [ESTADO.enProgreso, ESTADO.revisionRechazada];

export interface StopInput {
  motivo: string;
  descripcion: string;
  fotos: string[];
  montoPropuesto: number;
}

/**
 * Validates a técnico's request to stop work. Evidence is mandatory — a
 * reason, an explanation and at least one photo — because the stop may end in
 * a dispute an admin has to judge from what was recorded here.
 *
 * The proposed amount can never exceed what the cliente already approved.
 */
export function validateStop(raw: unknown, montoAprobado: number, montoMinimo = 0): StopInput {
  const r = (raw ?? {}) as Record<string, unknown>;
  const motivo = r.motivo as string;
  if (!(motivo in STOP_REASONS)) throw new FlowError('Selecciona el motivo para detener el trabajo.');

  const descripcion = typeof r.descripcion === 'string' ? r.descripcion.trim() : '';
  if (descripcion.length < 10) {
    throw new FlowError('Explica con más detalle por qué se detiene el trabajo.');
  }
  if (descripcion.length > 1000) throw new FlowError('La explicación es demasiado larga.');

  const fotos = Array.isArray(r.fotos) ? r.fotos.filter((f): f is string => typeof f === 'string') : [];
  if (fotos.length < 1) throw new FlowError('Agrega al menos una foto como evidencia.');
  if (fotos.length > 5) throw new FlowError('Máximo 5 fotos de evidencia.');
  if (fotos.some((f) => !f.startsWith('https://'))) throw new FlowError('Hay una foto inválida.');

  const monto = r.montoPropuesto;
  if (typeof monto !== 'number' || !Number.isFinite(monto) || monto < 0) {
    throw new FlowError('Indica el monto por el trabajo realizado.');
  }
  // In the diagnostic flow the visit already charged is the floor; only an
  // admin, resolving a dispute, may go below it.
  if (round2(monto) < round2(montoMinimo)) {
    throw new FlowError(
      `El monto no puede ser menor que la visita de diagnóstico ya cobrada ($${round2(montoMinimo).toFixed(2)}).`,
    );
  }
  if (round2(monto) > round2(montoAprobado)) {
    throw new FlowError(
      `El monto no puede ser mayor al aprobado por el cliente ($${round2(montoAprobado).toFixed(2)}).`,
    );
  }
  return { motivo, descripcion, fotos, montoPropuesto: round2(monto) };
}

/**
 * How a stopped service closes for a given final amount: charged, or — below
 * Stripe's minimum — closed with nothing to pay.
 */
export function closingFor(monto: number): { estado: string; costoFinal: number | null } {
  const m = round2(monto);
  return m >= MIN_CHARGE_MXN
    ? { estado: ESTADO.completado, costoFinal: m }
    : { estado: ESTADO.cancelado, costoFinal: null };
}

export const fmtMxn = (n: number): string =>
  `$${round2(n).toLocaleString('es-MX', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
