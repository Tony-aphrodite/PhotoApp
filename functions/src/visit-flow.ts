/**
 * The diagnostic-visit flow (Phase 2): one callable, `visitAction`, whose
 * `accion` selects the step, plus the hourly cron that runs timed steps.
 *
 * One callable rather than a dozen keeps cold starts and deploy time down;
 * every step still checks, on the server, who is calling and what state the
 * service is in. Rules and arithmetic live in lib/visit-rules.ts (tested).
 *
 *   técnico: requerir_diagnostico, proponer, en_camino, diagnostico_terminado,
 *            retirarse
 *   cliente: pedir_otro_horario, autorizar, confirmar_autorizacion, cancelar,
 *            reportar_no_llego, cerrar_solo_diagnostico
 *   admin:   resolver_no_llego (and cancelar, on the cliente's behalf)
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { db, admin } from './lib/admin';
import { sendPushToUsers } from './lib/push';
import {
  Data,
  OPTS,
  guarded,
  isAdminUid,
  now,
  readService,
  requireVerified,
  systemMessage,
  wrongState,
} from './lib/flow-helpers';
import { ESTADO, FlowError, fmtMxn } from './lib/service-flow-rules';
import {
  FLUJO,
  PAGO,
  AUTO_CLOSE_STATES,
  canGoOnTheWay,
  canReportNoShow,
  cancellationIsTechnicianNoShow,
  holdNeedsRenewal,
  validateVisitDate,
} from './lib/visit-rules';
import {
  captureVisit,
  categoryFlow,
  createVisitHold,
  fmtFecha,
  incidentUpdate,
  refundVisit,
  releaseVisit,
  retrievePaymentIntent,
  scheduleFor,
} from './lib/visit-store';

const FieldValue = admin.firestore.FieldValue;
const Timestamp = admin.firestore.Timestamp;

type Role = 'tecnico' | 'cliente' | 'admin';

interface Ctx {
  uid: string;
  role: Role;
  data: Data;
}

const fechaMs = (s: Data): number => (s.visita?.fecha as FirebaseFirestore.Timestamp).toMillis();
const isDiag = (s: Data) => s.flujo === FLUJO.diagnostico;

/** States reached before the técnico leaves: cancelling here costs nothing. */
const PRE_TRIP_STATES: string[] = [
  ESTADO.pendiente,
  ESTADO.asignado,
  ESTADO.visitaPropuesta,
  ESTADO.visitaConfirmada,
];

/** After the visit was charged, until the repair is approved. */
const VISIT_CHARGED_STATES: string[] = [ESTADO.enCamino, ...AUTO_CLOSE_STATES];

/** Standard-flow states that may still be cancelled for free. */
const STANDARD_CANCELLABLE: string[] = [
  ESTADO.pendiente,
  ESTADO.asignado,
  ESTADO.cotizacionEnviada,
  ESTADO.cotizacionRechazada,
  ESTADO.cotizacionAprobada,
];

async function notifyAdmins(title: string, body: string, data: Record<string, string>) {
  const admins = await db.collection('users').where('rol', '==', 'admin').where('activo', '==', true).get();
  await sendPushToUsers(admins.docs.map((d) => d.id), { title, body, data });
}

/** Fields that return a service to the unassigned pool for reassignment. */
function unassignFields(s: Data): Data {
  return {
    estado: ESTADO.pendiente,
    tecnicoId: FieldValue.delete(),
    tecnicoNombre: FieldValue.delete(),
    costoFinal: FieldValue.delete(),
    cotizacionPendienteId: FieldValue.delete(),
    cotizacionAprobadaId: FieldValue.delete(),
    // Keep the flow and the fee; drop everything tied to the old técnico.
    visita: isDiag(s) ? { precio: s.visita?.precio ?? 0, pagoEstado: PAGO.sinAutorizar } : FieldValue.delete(),
    autoCierre: FieldValue.delete(),
    revisionAt: FieldValue.delete(),
    revisionTarea: FieldValue.delete(),
    tipoAsignacion: 'admin',
  };
}

// ---------------------------------------------------------------------------
// Técnico
// ---------------------------------------------------------------------------

async function requerirDiagnostico(ctx: Ctx, servicioId: string) {
  const tecnico = (await db.collection('users').doc(ctx.uid).get()).data() ?? {};
  if (!tecnico.stripeConnectAccountId) {
    throw new FlowError('Conecta tu cuenta bancaria (Stripe) para ofrecer visitas de diagnóstico.');
  }
  return db.runTransaction(async (tx) => {
    const s = await readService(tx, servicioId);
    if (s.data.tecnicoId !== ctx.uid) throw new HttpsError('permission-denied', 'Solo el técnico asignado.');
    if (s.data.estado !== ESTADO.asignado || isDiag(s.data)) wrongState();
    const cat = await categoryFlow(s.data.categoria);
    if (!(cat.precioDiagnostico > 0)) {
      throw new FlowError('Esta categoría no tiene precio de diagnóstico configurado. Avisa a ServiTec.');
    }
    tx.update(s.ref, {
      flujo: FLUJO.diagnostico,
      visita: { precio: cat.precioDiagnostico, pagoEstado: PAGO.sinAutorizar },
      updatedAt: now(),
    });
    systemMessage(tx, s.id,
      `El técnico indicó que el servicio requiere una visita de diagnóstico (${fmtMxn(cat.precioDiagnostico)}). ` +
      'Te propondrá un horario. Si apruebas la reparación después, el diagnóstico se descuenta del total.',
      { event: 'diagnosis_required', precio: cat.precioDiagnostico });
    return { estado: ESTADO.asignado };
  });
}

async function proponer(ctx: Ctx, servicioId: string, fechaIso: unknown) {
  const ms = typeof fechaIso === 'string' ? Date.parse(fechaIso) : NaN;
  validateVisitDate(ms, Date.now());
  return db.runTransaction(async (tx) => {
    const s = await readService(tx, servicioId);
    if (s.data.tecnicoId !== ctx.uid) throw new HttpsError('permission-denied', 'Solo el técnico asignado.');
    if (!isDiag(s.data) || ![ESTADO.asignado, ESTADO.visitaPropuesta].includes(s.data.estado)) wrongState();
    tx.update(s.ref, {
      estado: ESTADO.visitaPropuesta,
      'visita.fecha': Timestamp.fromMillis(ms),
      'visita.solicitudCambio': FieldValue.delete(),
      updatedAt: now(),
    });
    systemMessage(tx, s.id,
      `El técnico propone la visita de diagnóstico para el ${fmtFecha(ms)}. ` +
      `Confírmala y autoriza ${fmtMxn(s.data.visita?.precio ?? 0)} para agendarla.`,
      { event: 'visit_proposed', fecha: ms });
    return { estado: ESTADO.visitaPropuesta };
  });
}

async function enCamino(ctx: Ctx, servicioId: string) {
  // 1. Validate.
  const pre = await db.runTransaction(async (tx) => {
    const s = await readService(tx, servicioId);
    if (s.data.tecnicoId !== ctx.uid) throw new HttpsError('permission-denied', 'Solo el técnico asignado.');
    if (s.data.estado !== ESTADO.visitaConfirmada) wrongState();
    if (s.data.visita?.pagoEstado !== PAGO.retenido) {
      throw new FlowError('El cliente todavía no ha autorizado el pago de la visita.');
    }
    if (!canGoOnTheWay(fechaMs(s.data), Date.now())) {
      throw new FlowError('Podrás marcar "Voy en camino" desde 2 horas antes de la cita.');
    }
    return s.data;
  });
  // 2. Charge the held amount (idempotent).
  const pi = await captureVisit(pre.visita.paymentIntentId);
  // 3. Commit.
  return db.runTransaction(async (tx) => {
    const s = await readService(tx, servicioId);
    if (s.data.estado !== ESTADO.visitaConfirmada) wrongState();
    const monto = (pi.amount_received || pi.amount) / 100;
    tx.update(s.ref, {
      estado: ESTADO.enCamino,
      'visita.pagoEstado': PAGO.cobrado,
      'visita.montoCobrado': monto,
      'visita.cobradoAt': now(),
      'visita.enCaminoAt': now(),
      ...scheduleFor(s.data, ESTADO.enCamino),
      updatedAt: now(),
    });
    systemMessage(tx, s.id,
      `El técnico va en camino. Se cobró la visita de diagnóstico (${fmtMxn(monto)}). ` +
      'A partir de ahora la visita ya no es reembolsable si cancelas.',
      { event: 'visit_on_the_way', monto });
    return { estado: ESTADO.enCamino };
  });
}

async function diagnosticoTerminado(ctx: Ctx, servicioId: string) {
  return db.runTransaction(async (tx) => {
    const s = await readService(tx, servicioId);
    if (s.data.tecnicoId !== ctx.uid) throw new HttpsError('permission-denied', 'Solo el técnico asignado.');
    if (s.data.estado !== ESTADO.enCamino) wrongState();
    tx.update(s.ref, {
      estado: ESTADO.diagnosticoRealizado,
      'visita.diagnosticoAt': now(),
      ...scheduleFor(s.data, ESTADO.diagnosticoRealizado),
      updatedAt: now(),
    });
    systemMessage(tx, s.id,
      'El técnico terminó el diagnóstico y te enviará la cotización de la reparación.',
      { event: 'diagnosis_done' });
    return { estado: ESTADO.diagnosticoRealizado };
  });
}

const WITHDRAWABLE: string[] = [
  ESTADO.asignado,
  ESTADO.visitaPropuesta,
  ESTADO.visitaConfirmada,
  ESTADO.enCamino,
  ESTADO.cotizacionEnviada,
  ESTADO.cotizacionRechazada,
  ESTADO.cotizacionAprobada,
];

/** The técnico gives the job back: hold released or visit refunded, an
 * incident recorded, and the service returned to admins for reassignment. */
async function retirarse(ctx: Ctx, servicioId: string) {
  const pre = await db.runTransaction(async (tx) => {
    const s = await readService(tx, servicioId);
    if (s.data.tecnicoId !== ctx.uid) throw new HttpsError('permission-denied', 'Solo el técnico asignado.');
    if (!WITHDRAWABLE.includes(s.data.estado)) {
      throw new FlowError('Ya no puedes retirarte de este servicio. Si hay un problema, detén el trabajo o contacta a ServiTec.');
    }
    return s.data;
  });
  const pago = pre.visita?.pagoEstado;
  const pi = pre.visita?.paymentIntentId;
  let refunded = 0;
  if (pago === PAGO.retenido || pago === PAGO.reautorizacionPendiente) await releaseVisit(pi);
  if (pago === PAGO.cobrado && pi) {
    await refundVisit(pi);
    refunded = pre.visita.montoCobrado ?? 0;
  }

  await db.runTransaction(async (tx) => {
    const s = await readService(tx, servicioId);
    if (s.data.tecnicoId !== ctx.uid) wrongState();
    if (s.data.cotizacionPendienteId) {
      tx.update(db.collection('cotizaciones').doc(s.data.cotizacionPendienteId), { estado: 'retirada' });
    }
    tx.update(s.ref, { ...unassignFields(s.data), updatedAt: now() });
    tx.update(db.collection('users').doc(ctx.uid), incidentUpdate('cancelaciones'));
    systemMessage(tx, s.id,
      refunded > 0
        ? `El técnico canceló. Se te reembolsará la visita (${fmtMxn(refunded)}) y ServiTec te asignará otro técnico.`
        : 'El técnico canceló. ServiTec te asignará otro técnico; no se te cobró nada.',
      { event: 'technician_withdrew', refunded });
    tx.set(db.collection('admin_flags').doc(), {
      type: 'technician_withdrew',
      servicioId,
      tecnicoId: ctx.uid,
      clienteId: s.data.clienteId,
      estadoPrevio: s.data.estado,
      reembolso: refunded,
      estado: 'pendiente',
      createdAt: now(),
    });
  });
  await notifyAdmins('Servicio sin técnico', 'Un técnico canceló un servicio. Reasígnalo desde el panel.', {
    type: 'technician_withdrew', servicioId,
  });
  return { estado: ESTADO.pendiente };
}

// ---------------------------------------------------------------------------
// Cliente
// ---------------------------------------------------------------------------

async function pedirOtroHorario(ctx: Ctx, servicioId: string, comentario: string) {
  return db.runTransaction(async (tx) => {
    const s = await readService(tx, servicioId);
    if (s.data.clienteId !== ctx.uid) throw new HttpsError('permission-denied', 'Solo el cliente del servicio.');
    if (s.data.estado !== ESTADO.visitaPropuesta) wrongState();
    tx.update(s.ref, {
      estado: ESTADO.asignado,
      'visita.solicitudCambio': comentario || 'El cliente pidió otro horario.',
      updatedAt: now(),
    });
    systemMessage(tx, s.id,
      `El cliente pidió otro horario para la visita${comentario ? `: "${comentario}"` : '.'} El técnico propondrá uno nuevo.`,
      { event: 'visit_reschedule_requested' });
    return { estado: ESTADO.asignado };
  });
}

/** Creates the card hold and returns its client secret for the PaymentSheet. */
async function autorizar(ctx: Ctx, servicioId: string) {
  const s = (await db.collection('servicios').doc(servicioId).get()).data();
  if (!s) throw new HttpsError('not-found', 'Servicio no encontrado.');
  if (s.clienteId !== ctx.uid) throw new HttpsError('permission-denied', 'Solo el cliente del servicio.');
  const renewing = s.estado === ESTADO.visitaConfirmada && s.visita?.pagoEstado === PAGO.reautorizacionPendiente;
  if (s.estado !== ESTADO.visitaPropuesta && !renewing) wrongState();

  const tecnico = (await db.collection('users').doc(s.tecnicoId).get()).data() ?? {};
  if (!tecnico.stripeConnectAccountId) {
    throw new FlowError('El técnico todavía no puede recibir pagos. ServiTec te asignará otro técnico.');
  }
  // A previous, abandoned attempt would otherwise stay open on the card.
  const previous = s.visita?.intentoPaymentIntentId;
  if (previous) await releaseVisit(previous).catch(() => undefined);

  const pi = await createVisitHold({
    servicioId,
    clienteUid: s.clienteId,
    tecnicoUid: s.tecnicoId,
    connectedAccountId: tecnico.stripeConnectAccountId,
    precioMxn: s.visita.precio,
  });
  await db.collection('servicios').doc(servicioId).update({ 'visita.intentoPaymentIntentId': pi.id });
  return { clientSecret: pi.client_secret, paymentIntentId: pi.id, monto: s.visita.precio };
}

/** After the PaymentSheet: verifies with Stripe that the hold exists. */
async function confirmarAutorizacion(ctx: Ctx, servicioId: string) {
  const pre = (await db.collection('servicios').doc(servicioId).get()).data();
  if (!pre) throw new HttpsError('not-found', 'Servicio no encontrado.');
  if (pre.clienteId !== ctx.uid) throw new HttpsError('permission-denied', 'Solo el cliente del servicio.');
  const piId = pre.visita?.intentoPaymentIntentId as string | undefined;
  if (!piId) throw new FlowError('No hay una autorización en curso.');
  const pi = await retrievePaymentIntent(piId);
  if (pi.status !== 'requires_capture' || pi.metadata?.servicioId !== servicioId) {
    throw new FlowError('La autorización del pago no se completó. Intenta de nuevo.');
  }

  return db.runTransaction(async (tx) => {
    const s = await readService(tx, servicioId);
    const renewing = s.data.estado === ESTADO.visitaConfirmada &&
      s.data.visita?.pagoEstado === PAGO.reautorizacionPendiente;
    if (s.data.estado !== ESTADO.visitaPropuesta && !renewing) wrongState();
    const fecha = fechaMs(s.data);
    const visitaPatch = {
      paymentIntentId: piId,
      pagoEstado: PAGO.retenido,
      renovarAutorizacion: holdNeedsRenewal(fecha, Date.now()),
    };
    tx.update(s.ref, {
      estado: ESTADO.visitaConfirmada,
      'visita.paymentIntentId': piId,
      'visita.pagoEstado': PAGO.retenido,
      'visita.retenidoAt': now(),
      'visita.renovarAutorizacion': visitaPatch.renovarAutorizacion,
      'visita.intentoPaymentIntentId': FieldValue.delete(),
      ...scheduleFor(s.data, ESTADO.visitaConfirmada, { visita: visitaPatch }),
      updatedAt: now(),
    });
    systemMessage(tx, s.id,
      renewing
        ? `El cliente renovó la autorización de la visita del ${fmtFecha(fecha)}.`
        : `Visita confirmada para el ${fmtFecha(fecha)}. Se retuvieron ${fmtMxn(s.data.visita?.precio ?? 0)} ` +
          'en la tarjeta; se cobrarán cuando el técnico salga hacia tu domicilio.',
      { event: renewing ? 'visit_reauthorized' : 'visit_confirmed', fecha });
    return { estado: ESTADO.visitaConfirmada };
  });
}

/**
 * Every cancellation by the cliente (or an admin on their behalf), in both
 * flows. Free until the técnico leaves: a hold is released. Once the visit
 * was charged it is not refundable and the service closes as paid.
 */
async function cancelar(ctx: Ctx, servicioId: string) {
  const pre = await db.runTransaction(async (tx) => {
    const s = await readService(tx, servicioId);
    if (ctx.role !== 'admin' && s.data.clienteId !== ctx.uid) {
      throw new HttpsError('permission-denied', 'Solo el cliente del servicio.');
    }
    const diag = isDiag(s.data);
    const allowed = diag
      ? [...PRE_TRIP_STATES, ...VISIT_CHARGED_STATES].includes(s.data.estado)
      : STANDARD_CANCELLABLE.includes(s.data.estado);
    if (!allowed) throw new FlowError('El trabajo ya empezó; este servicio ya no se puede cancelar.');
    return s.data;
  });

  const pago = pre.visita?.pagoEstado;
  if (pago === PAGO.retenido || pago === PAGO.reautorizacionPendiente) {
    await releaseVisit(pre.visita.paymentIntentId);
  }
  if (pre.visita?.intentoPaymentIntentId) {
    await releaseVisit(pre.visita.intentoPaymentIntentId).catch(() => undefined);
  }

  return db.runTransaction(async (tx) => {
    const s = await readService(tx, servicioId);
    if (s.data.estado !== pre.estado) wrongState();
    const charged = s.data.visita?.pagoEstado === PAGO.cobrado;
    const lateNoShow = s.data.estado === ESTADO.visitaConfirmada && s.data.tecnicoId &&
      cancellationIsTechnicianNoShow(fechaMs(s.data), Date.now());

    if (s.data.cotizacionPendienteId) {
      tx.update(db.collection('cotizaciones').doc(s.data.cotizacionPendienteId), { estado: 'cancelada' });
    }
    const estado = charged ? ESTADO.pagado : ESTADO.cancelado;
    tx.update(s.ref, {
      estado,
      ...(charged ? { cierre: 'cancelado_por_cliente' } : {}),
      ...(pago === PAGO.retenido || pago === PAGO.reautorizacionPendiente ? { 'visita.pagoEstado': PAGO.liberado } : {}),
      autoCierre: FieldValue.delete(),
      revisionAt: FieldValue.delete(),
      revisionTarea: FieldValue.delete(),
      updatedAt: now(),
    });
    if (lateNoShow) tx.update(db.collection('users').doc(s.data.tecnicoId), incidentUpdate('noSePresento'));
    systemMessage(tx, s.id,
      charged
        ? `Servicio cancelado por el cliente. La visita de diagnóstico (${fmtMxn(s.data.visita.montoCobrado ?? 0)}) no es reembolsable porque el técnico ya había salido.`
        : 'Servicio cancelado. No se realizó ningún cobro.',
      { event: 'service_cancelled', cobrado: charged });
    return { estado };
  });
}

async function reportarNoLlego(ctx: Ctx, servicioId: string, comentario: string) {
  const result = await db.runTransaction(async (tx) => {
    const s = await readService(tx, servicioId);
    if (s.data.clienteId !== ctx.uid) throw new HttpsError('permission-denied', 'Solo el cliente del servicio.');
    if (s.data.estado !== ESTADO.enCamino) wrongState();
    if (!canReportNoShow(fechaMs(s.data), Date.now())) {
      throw new FlowError('Podrás reportarlo 30 minutos después de la hora de la cita.');
    }
    tx.update(s.ref, {
      estado: ESTADO.reporteNoLlego,
      'visita.reporte': { comentario, creadoAt: now() },
      updatedAt: now(),
    });
    tx.set(db.collection('admin_flags').doc(), {
      type: 'technician_no_show_report',
      servicioId,
      clienteId: ctx.uid,
      tecnicoId: s.data.tecnicoId,
      comentario,
      monto: s.data.visita?.montoCobrado ?? 0,
      estado: 'pendiente',
      createdAt: now(),
    });
    systemMessage(tx, s.id,
      'El cliente reportó que el técnico no llegó. ServiTec revisará el caso y decidirá si procede el reembolso.',
      { event: 'no_show_reported' });
    return { estado: ESTADO.reporteNoLlego };
  });
  await notifyAdmins('Reporte: el técnico no llegó', 'Un cliente reportó que el técnico no llegó. Revisa el caso.', {
    type: 'technician_no_show_report', servicioId,
  });
  return result;
}

/** The cliente declines the repair after the diagnosis: only the visit is paid. */
async function cerrarSoloDiagnostico(ctx: Ctx, servicioId: string) {
  return db.runTransaction(async (tx) => {
    const s = await readService(tx, servicioId);
    if (s.data.clienteId !== ctx.uid) throw new HttpsError('permission-denied', 'Solo el cliente del servicio.');
    if (!isDiag(s.data) || !AUTO_CLOSE_STATES.includes(s.data.estado)) wrongState();
    closeWithVisitOnly(tx, s.ref, s.data, 'solo_diagnostico');
    systemMessage(tx, s.id,
      `El cliente decidió no continuar con la reparación. El servicio se cierra con el pago de la visita (${fmtMxn(s.data.visita?.montoCobrado ?? 0)}).`,
      { event: 'closed_diagnosis_only' });
    return { estado: ESTADO.pagado };
  });
}

/** Closes a diagnostic service whose only charge is the visit already paid. */
export function closeWithVisitOnly(tx: FirebaseFirestore.Transaction, ref: FirebaseFirestore.DocumentReference, s: Data, cierre: string) {
  if (s.cotizacionPendienteId) {
    tx.update(db.collection('cotizaciones').doc(s.cotizacionPendienteId), { estado: 'vencida' });
  }
  tx.update(ref, {
    estado: ESTADO.pagado,
    cierre,
    cotizacionPendienteId: FieldValue.delete(),
    autoCierre: FieldValue.delete(),
    revisionAt: FieldValue.delete(),
    revisionTarea: FieldValue.delete(),
    updatedAt: now(),
  });
}

// ---------------------------------------------------------------------------
// Admin
// ---------------------------------------------------------------------------

async function resolverNoLlego(ctx: Ctx, servicioId: string, reembolsar: boolean, nota: string) {
  if (nota.length < 5) throw new FlowError('Agrega una nota que explique la decisión.');
  const pre = await db.runTransaction(async (tx) => {
    const s = await readService(tx, servicioId);
    if (s.data.estado !== ESTADO.reporteNoLlego) wrongState();
    return s.data;
  });
  if (reembolsar && pre.visita?.paymentIntentId) await refundVisit(pre.visita.paymentIntentId);

  return db.runTransaction(async (tx) => {
    const s = await readService(tx, servicioId);
    if (s.data.estado !== ESTADO.reporteNoLlego) wrongState();
    if (reembolsar) {
      tx.update(s.ref, {
        ...unassignFields(s.data),
        resolucion: { tipo: 'no_llego', reembolso: s.data.visita?.montoCobrado ?? 0, nota, adminUid: ctx.uid, resueltoAt: now() },
        updatedAt: now(),
      });
      tx.update(db.collection('users').doc(s.data.tecnicoId), incidentUpdate('noSePresento'));
    } else {
      tx.update(s.ref, {
        estado: ESTADO.enCamino,
        resolucion: { tipo: 'no_llego_rechazado', nota, adminUid: ctx.uid, resueltoAt: now() },
        updatedAt: now(),
      });
    }
    systemMessage(tx, s.id,
      reembolsar
        ? `ServiTec reembolsará la visita (${fmtMxn(s.data.visita?.montoCobrado ?? 0)}) y asignará otro técnico. Nota: ${nota}`
        : `ServiTec revisó el reporte y no procede el reembolso. Nota: ${nota}`,
      { event: reembolsar ? 'no_show_refunded' : 'no_show_rejected' });
    return { estado: reembolsar ? ESTADO.pendiente : ESTADO.enCamino };
  });
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

const ACTIONS: Record<string, Role[]> = {
  requerir_diagnostico: ['tecnico'],
  proponer: ['tecnico'],
  en_camino: ['tecnico'],
  diagnostico_terminado: ['tecnico'],
  retirarse: ['tecnico'],
  pedir_otro_horario: ['cliente'],
  autorizar: ['cliente'],
  confirmar_autorizacion: ['cliente'],
  cancelar: ['cliente', 'admin'],
  reportar_no_llego: ['cliente'],
  cerrar_solo_diagnostico: ['cliente'],
  resolver_no_llego: ['admin'],
};

export const visitAction = onCall<Data>(OPTS, (req) =>
  guarded(async () => {
    const uid = requireVerified(req);
    const accion = String(req.data?.accion ?? '');
    const roles = ACTIONS[accion];
    if (!roles) throw new HttpsError('invalid-argument', 'Acción inválida.');
    const servicioId = String(req.data?.servicioId ?? '');
    if (!servicioId) throw new HttpsError('invalid-argument', 'Falta el servicio.');

    // Role on this service: participant checks happen inside each step; only
    // the admin role needs a profile read, and only for admin actions.
    const role: Role = roles.includes('admin') && (await isAdminUid(uid))
      ? 'admin'
      : roles.includes('tecnico') ? 'tecnico' : 'cliente';
    if (!roles.includes(role)) throw new HttpsError('permission-denied', 'No tienes permiso para esta acción.');
    const ctx: Ctx = { uid, role, data: req.data ?? {} };
    const comentario = typeof req.data?.comentario === 'string' ? req.data.comentario.trim().slice(0, 1000) : '';

    switch (accion) {
      case 'requerir_diagnostico': return requerirDiagnostico(ctx, servicioId);
      case 'proponer': return proponer(ctx, servicioId, req.data?.fecha);
      case 'en_camino': return enCamino(ctx, servicioId);
      case 'diagnostico_terminado': return diagnosticoTerminado(ctx, servicioId);
      case 'retirarse': return retirarse(ctx, servicioId);
      case 'pedir_otro_horario': return pedirOtroHorario(ctx, servicioId, comentario);
      case 'autorizar': return autorizar(ctx, servicioId);
      case 'confirmar_autorizacion': return confirmarAutorizacion(ctx, servicioId);
      case 'cancelar': return cancelar(ctx, servicioId);
      case 'reportar_no_llego': return reportarNoLlego(ctx, servicioId, comentario);
      case 'cerrar_solo_diagnostico': return cerrarSoloDiagnostico(ctx, servicioId);
      case 'resolver_no_llego':
        return resolverNoLlego(ctx, servicioId, req.data?.reembolsar === true,
          typeof req.data?.nota === 'string' ? req.data.nota.trim().slice(0, 1000) : '');
    }
    throw new HttpsError('invalid-argument', 'Acción inválida.');
  }),
);

// ---------------------------------------------------------------------------
// Hourly schedule: renew long-range holds, expire them, remind and auto-close.
// ---------------------------------------------------------------------------

async function runTask(ref: FirebaseFirestore.DocumentReference) {
  const snap = await ref.get();
  const s = snap.data();
  if (!s || !s.revisionAt || s.revisionAt.toMillis() > Date.now()) return;
  const tarea = s.revisionTarea as string;

  if (tarea === 'pedir_reautorizacion') {
    // The long-range hold would lapse before the visit: drop it and ask again.
    await releaseVisit(s.visita?.paymentIntentId);
    await db.runTransaction(async (tx) => {
      const cur = (await tx.get(ref)).data()!;
      if (cur.estado !== ESTADO.visitaConfirmada || cur.visita?.pagoEstado !== PAGO.retenido) return;
      const patch = { visita: { pagoEstado: PAGO.reautorizacionPendiente } };
      tx.update(ref, {
        'visita.pagoEstado': PAGO.reautorizacionPendiente,
        'visita.renovarAutorizacion': false,
        ...scheduleFor(cur, ESTADO.visitaConfirmada, patch),
        updatedAt: now(),
      });
      systemMessage(tx, ref.id,
        `Tu visita es el ${fmtFecha(fechaMs(cur))}. Para mantenerla, vuelve a autorizar el pago ` +
        `(${fmtMxn(cur.visita.precio)}) antes de 24 horas de la cita; si no, se cancelará sin costo.`,
        { event: 'visit_reauth_requested' });
    });
    return;
  }

  await db.runTransaction(async (tx) => {
    const cur = (await tx.get(ref)).data()!;
    if (!cur.revisionAt || cur.revisionAt.toMillis() > Date.now() || cur.revisionTarea !== tarea) return;

    if (tarea === 'vencer_reautorizacion') {
      if (cur.estado !== ESTADO.visitaConfirmada || cur.visita?.pagoEstado !== PAGO.reautorizacionPendiente) return;
      tx.update(ref, {
        estado: ESTADO.cancelado,
        'visita.pagoEstado': PAGO.liberado,
        revisionAt: FieldValue.delete(),
        revisionTarea: FieldValue.delete(),
        updatedAt: now(),
      });
      systemMessage(tx, ref.id,
        'La visita se canceló sin costo porque el pago no se volvió a autorizar a tiempo.',
        { event: 'visit_reauth_expired' });
      return;
    }

    if (tarea === 'aviso_cierre') {
      const avisos = Number(cur.autoCierre?.avisos) || 0;
      const horas = avisos === 0 ? 48 : 24;
      const esperaTecnico = cur.estado === ESTADO.diagnosticoRealizado || cur.estado === ESTADO.cotizacionRechazada;
      const next = { ...cur, autoCierre: { ...cur.autoCierre, avisos: avisos + 1 } };
      tx.update(ref, { ...scheduleFor(next, cur.estado), updatedAt: now() });
      systemMessage(tx, ref.id,
        esperaTecnico
          ? `Recordatorio: si el técnico no envía la cotización de la reparación en ${horas} horas, el servicio se cerrará solo con el pago de la visita.`
          : `Recordatorio: si no respondes la cotización en ${horas} horas, el servicio se cerrará solo con el pago de la visita.`,
        { event: 'auto_close_reminder', horas });
      return;
    }

    if (tarea === 'cierre_automatico') {
      if (!AUTO_CLOSE_STATES.includes(cur.estado)) return;
      closeWithVisitOnly(tx, ref, cur, 'cierre_automatico');
      systemMessage(tx, ref.id,
        'El servicio se cerró automáticamente tras 7 días sin respuesta. Solo se cobró la visita de diagnóstico.',
        { event: 'auto_closed' });
    }
  });
}

export const serviceScheduleCron = onSchedule(
  { schedule: 'every 60 minutes', region: 'us-central1', timeoutSeconds: 300 },
  async () => {
    // Single-field range on `revisionAt`: only services that are due are read.
    const due = await db.collection('servicios')
      .where('revisionAt', '<=', Timestamp.now())
      .orderBy('revisionAt')
      .limit(200)
      .get();
    let failed = 0;
    for (const doc of due.docs) {
      try {
        await runTask(doc.ref);
      } catch (err) {
        failed++;
        // eslint-disable-next-line no-console
        console.error(`schedule task failed for ${doc.id}`, err);
      }
    }
    // eslint-disable-next-line no-console
    console.log(`Schedule: ${due.size} due, ${failed} failed.`);
  },
);
