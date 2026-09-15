/**
 * Callables that move a service through its quotation and work flow.
 *
 * Every transition lives here rather than in the app because each one decides
 * money — which amount the cliente will be charged — and firestore.rules no
 * longer let either party write a service's state or price directly. Each
 * callable re-reads the service inside a transaction, checks the caller's role
 * on that service and the current state, and posts the chat narration that
 * doubles as the push notification (see chat-message-guard).
 *
 * The rules themselves are in lib/service-flow-rules.ts, with tests.
 */

import { onCall, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import { db, admin } from './lib/admin';
import { sendPushToUsers } from './lib/push';
import {
  ESTADO,
  FlowError,
  QuotationKind,
  STOPPABLE_STATES,
  STOP_REASONS,
  awaitingStateFor,
  closingFor,
  fmtMxn,
  priceQuotation,
  quotationKindFor,
  round2,
  stateAfterResponse,
  stateAfterSubmit,
  stateAfterWorkAction,
  validateStop,
} from './lib/service-flow-rules';

type Tx = FirebaseFirestore.Transaction;
type Data = FirebaseFirestore.DocumentData;

const OPTS = { region: 'us-central1', memory: '256MiB' as const };
const now = () => admin.firestore.FieldValue.serverTimestamp();

/** Signed in with a verified email; returns the uid. */
function requireVerified(req: CallableRequest<unknown>): string {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
  if (req.auth?.token.email_verified !== true) {
    throw new HttpsError('failed-precondition', 'Verifica tu correo antes de continuar.');
  }
  return uid;
}

/** Runs `fn`, turning a broken flow rule into a user-facing HttpsError. */
async function guarded<T>(fn: () => Promise<T>): Promise<T> {
  try {
    return await fn();
  } catch (err) {
    if (err instanceof FlowError) throw new HttpsError('failed-precondition', err.message);
    throw err;
  }
}

async function readService(tx: Tx, servicioId: unknown) {
  if (typeof servicioId !== 'string' || !servicioId) {
    throw new HttpsError('invalid-argument', 'Falta el servicio.');
  }
  const ref = db.collection('servicios').doc(servicioId);
  const snap = await tx.get(ref);
  if (!snap.exists) throw new HttpsError('not-found', 'Servicio no encontrado.');
  return { ref, id: servicioId, data: snap.data() as Data };
}

function systemMessage(tx: Tx, servicioId: string, mensaje: string, metadata: Data) {
  tx.set(db.collection('servicios').doc(servicioId).collection('mensajes').doc(), {
    userId: 'system',
    nombreUsuario: 'ServiTec',
    mensaje,
    tipo: 'sistema',
    timestamp: now(),
    leido: false,
    metadata,
  });
}

function wrongState(): never {
  throw new FlowError(
    'El servicio cambió de estado. Actualiza la pantalla e inténtalo de nuevo.',
  );
}

// ---------------------------------------------------------------------------
// Quotations
// ---------------------------------------------------------------------------

interface SubmitQuotationInput {
  servicioId?: string;
  items?: unknown;
  notas?: string;
  fotos?: unknown;
}

/**
 * The assigned técnico sends a cotización: the initial quote before work, or a
 * revision once working (e.g. an extra problem found mid-job).
 */
export const submitQuotation = onCall<SubmitQuotationInput>(OPTS, (req) =>
  guarded(async () => {
    const uid = requireVerified(req);
    const priced = priceQuotation(req.data?.items);
    const notas = typeof req.data?.notas === 'string' ? req.data.notas.trim().slice(0, 1000) : '';
    const fotos = (Array.isArray(req.data?.fotos) ? req.data!.fotos : [])
      .filter((f): f is string => typeof f === 'string' && f.startsWith('https://'))
      .slice(0, 10);

    return db.runTransaction(async (tx) => {
      const s = await readService(tx, req.data?.servicioId);
      if (s.data.tecnicoId !== uid) {
        throw new HttpsError('permission-denied', 'Solo el técnico asignado puede cotizar.');
      }
      const kind = quotationKindFor(s.data.estado);
      if (!kind) wrongState();

      const previous = await tx.get(
        db.collection('cotizaciones').where('servicioId', '==', s.id).where('tecnicoId', '==', uid),
      );
      const montoAnterior = kind === 'revision' ? (s.data.costoFinal as number | undefined) ?? null : null;

      const cotRef = db.collection('cotizaciones').doc();
      tx.set(cotRef, {
        servicioId: s.id,
        clienteId: s.data.clienteId,
        tecnicoId: uid,
        tipo: kind,
        version: previous.size + 1,
        ...priced,
        montoAnterior,
        estado: 'pendiente',
        notasTecnico: notas || null,
        fotosDiagnostico: fotos,
        fechaCreacion: now(),
      });
      tx.update(s.ref, {
        estado: stateAfterSubmit(kind),
        cotizacionPendienteId: cotRef.id,
        updatedAt: now(),
      });
      systemMessage(
        tx,
        s.id,
        kind === 'inicial'
          ? `Cotización enviada — Total: ${fmtMxn(priced.total)} (IVA incluido). Revísala para aprobarla o rechazarla.`
          : `Cotización revisada enviada — de ${fmtMxn(montoAnterior ?? 0)} a ${fmtMxn(priced.total)}. El trabajo adicional requiere tu aprobación.`,
        { event: kind === 'inicial' ? 'quotation_sent' : 'quotation_revision_sent', cotizacionId: cotRef.id, total: priced.total },
      );
      return { cotizacionId: cotRef.id, total: priced.total };
    });
  }),
);

/** The cliente approves or rejects the pending cotización. */
export const respondQuotation = onCall<{ cotizacionId?: string; respuesta?: string }>(OPTS, (req) =>
  guarded(async () => {
    const uid = requireVerified(req);
    const { cotizacionId, respuesta } = req.data ?? {};
    if (respuesta !== 'aprobada' && respuesta !== 'rechazada') {
      throw new HttpsError('invalid-argument', 'Respuesta inválida.');
    }
    if (!cotizacionId) throw new HttpsError('invalid-argument', 'Falta la cotización.');
    const aprobada = respuesta === 'aprobada';

    return db.runTransaction(async (tx) => {
      const cotRef = db.collection('cotizaciones').doc(cotizacionId);
      const cotSnap = await tx.get(cotRef);
      if (!cotSnap.exists) throw new HttpsError('not-found', 'Cotización no encontrada.');
      const cot = cotSnap.data() as Data;

      const s = await readService(tx, cot.servicioId);
      if (s.data.clienteId !== uid) {
        throw new HttpsError('permission-denied', 'Solo el cliente del servicio puede responder.');
      }
      const kind = cot.tipo as QuotationKind;
      if (
        cot.estado !== 'pendiente' ||
        s.data.cotizacionPendienteId !== cotizacionId ||
        s.data.estado !== awaitingStateFor(kind)
      ) {
        throw new FlowError('Esta cotización ya no está pendiente.');
      }

      tx.update(cotRef, { estado: respuesta, fechaRespuesta: now() });
      tx.update(s.ref, {
        estado: stateAfterResponse(kind, aprobada),
        cotizacionPendienteId: admin.firestore.FieldValue.delete(),
        ...(aprobada ? { costoFinal: cot.total, cotizacionAprobadaId: cotizacionId } : {}),
        updatedAt: now(),
      });

      const total = fmtMxn(cot.total);
      const mensaje = kind === 'inicial'
        ? aprobada
          ? `Cotización aprobada — Total: ${total}. El técnico puede iniciar el trabajo.`
          : 'Cotización rechazada por el cliente. El técnico puede enviar una nueva cotización.'
        : aprobada
          ? `Cotización revisada aprobada — nuevo total: ${total}. El técnico continúa con el trabajo.`
          : `Cotización revisada rechazada. El monto aprobado sigue siendo ${fmtMxn(s.data.costoFinal ?? 0)}.`;
      systemMessage(tx, s.id, mensaje, {
        event: `quotation_${kind}_${respuesta}`,
        cotizacionId,
        total: cot.total,
      });
      return { estado: stateAfterResponse(kind, aprobada) };
    });
  }),
);

// ---------------------------------------------------------------------------
// Work
// ---------------------------------------------------------------------------

const WORK_MESSAGES: Record<string, (s: Data) => string> = {
  iniciar: () => 'El técnico inició el trabajo.',
  continuar_original: (s) =>
    `El técnico continuará únicamente con el trabajo aprobado originalmente (${fmtMxn(s.costoFinal ?? 0)}).`,
  completar: (s) => `Trabajo terminado. Total a pagar: ${fmtMxn(s.costoFinal ?? 0)}.`,
};

/** The técnico starts, resumes the original scope, or finishes the work. */
export const serviceWorkAction = onCall<{ servicioId?: string; accion?: string }>(OPTS, (req) =>
  guarded(async () => {
    const uid = requireVerified(req);
    const accion = req.data?.accion ?? '';
    if (!(accion in WORK_MESSAGES)) throw new HttpsError('invalid-argument', 'Acción inválida.');

    return db.runTransaction(async (tx) => {
      const s = await readService(tx, req.data?.servicioId);
      if (s.data.tecnicoId !== uid) {
        throw new HttpsError('permission-denied', 'Solo el técnico asignado puede hacer esto.');
      }
      const next = stateAfterWorkAction(accion, s.data.estado);
      if (!next) wrongState();
      if (accion === 'completar' && !((s.data.costoFinal as number) > 0)) {
        throw new FlowError('El servicio no tiene un monto aprobado.');
      }

      tx.update(s.ref, {
        estado: next,
        ...(accion === 'iniciar' ? { iniciadoAt: now() } : {}),
        ...(accion === 'completar' ? { completadoAt: now() } : {}),
        updatedAt: now(),
      });
      systemMessage(tx, s.id, WORK_MESSAGES[accion](s.data), { event: `work_${accion}`, estado: next });
      return { estado: next };
    });
  }),
);

// ---------------------------------------------------------------------------
// Stopping work
// ---------------------------------------------------------------------------

/**
 * The técnico stops because continuing is unsafe or technically wrong, with
 * evidence and a proposed amount for the work actually done. Every stop is
 * logged for admins, so a técnico who stops unusually often is visible.
 */
export const stopWork = onCall<Data>(OPTS, (req) =>
  guarded(async () => {
    const uid = requireVerified(req);

    return db.runTransaction(async (tx) => {
      const s = await readService(tx, req.data?.servicioId);
      if (s.data.tecnicoId !== uid) {
        throw new HttpsError('permission-denied', 'Solo el técnico asignado puede hacer esto.');
      }
      if (!STOPPABLE_STATES.includes(s.data.estado)) wrongState();
      const montoAprobado = (s.data.costoFinal as number | undefined) ?? 0;
      const stop = validateStop(req.data, montoAprobado);

      tx.update(s.ref, {
        estado: ESTADO.detenido,
        detencion: { ...stop, montoAprobadoPrevio: montoAprobado, creadoAt: now() },
        updatedAt: now(),
      });
      tx.set(db.collection('admin_flags').doc(), {
        type: 'work_stopped',
        servicioId: s.id,
        clienteId: s.data.clienteId,
        tecnicoId: uid,
        motivo: stop.motivo,
        montoPropuesto: stop.montoPropuesto,
        estado: 'pendiente',
        createdAt: now(),
      });
      systemMessage(
        tx,
        s.id,
        `El técnico detuvo el trabajo: ${STOP_REASONS[stop.motivo]}. Propone cobrar ${fmtMxn(stop.montoPropuesto)} por lo realizado. Revisa el detalle para aceptar o no.`,
        { event: 'work_stopped', motivo: stop.motivo, montoPropuesto: stop.montoPropuesto },
      );
      return { estado: ESTADO.detenido };
    });
  }),
);

/** The cliente accepts the proposed amount for a stopped job, or disputes it. */
export const respondStop = onCall<{ servicioId?: string; respuesta?: string; comentario?: string }>(OPTS, (req) =>
  guarded(async () => {
    const uid = requireVerified(req);
    const { respuesta } = req.data ?? {};
    if (respuesta !== 'aceptar' && respuesta !== 'disputar') {
      throw new HttpsError('invalid-argument', 'Respuesta inválida.');
    }
    const comentario = typeof req.data?.comentario === 'string' ? req.data.comentario.trim().slice(0, 1000) : '';

    const result = await db.runTransaction(async (tx) => {
      const s = await readService(tx, req.data?.servicioId);
      if (s.data.clienteId !== uid) {
        throw new HttpsError('permission-denied', 'Solo el cliente del servicio puede responder.');
      }
      if (s.data.estado !== ESTADO.detenido) wrongState();
      const monto = (s.data.detencion?.montoPropuesto as number | undefined) ?? 0;

      if (respuesta === 'aceptar') {
        const close = closingFor(monto);
        tx.update(s.ref, {
          estado: close.estado,
          ...(close.costoFinal != null ? { costoFinal: close.costoFinal, completadoAt: now() } : {}),
          'detencion.respuestaCliente': 'aceptada',
          updatedAt: now(),
        });
        systemMessage(
          tx,
          s.id,
          close.costoFinal != null
            ? `El cliente aceptó el monto de ${fmtMxn(close.costoFinal)} por el trabajo realizado.`
            : 'El cliente aceptó cerrar el servicio sin cobro.',
          { event: 'work_stop_accepted', monto },
        );
        return { estado: close.estado, disputa: false, tecnicoId: s.data.tecnicoId as string };
      }

      if (comentario.length < 5) throw new FlowError('Cuéntanos por qué no estás de acuerdo.');
      tx.update(s.ref, {
        estado: ESTADO.enDisputa,
        'detencion.respuestaCliente': 'disputada',
        'detencion.comentarioCliente': comentario,
        updatedAt: now(),
      });
      tx.set(db.collection('admin_flags').doc(), {
        type: 'work_stop_dispute',
        servicioId: s.id,
        clienteId: uid,
        tecnicoId: s.data.tecnicoId,
        montoPropuesto: monto,
        comentarioCliente: comentario,
        estado: 'pendiente',
        createdAt: now(),
      });
      systemMessage(
        tx,
        s.id,
        'El cliente no está de acuerdo con el monto propuesto. ServiTec revisará el caso y definirá el monto final.',
        { event: 'work_stop_disputed', monto },
      );
      return { estado: ESTADO.enDisputa, disputa: true, tecnicoId: s.data.tecnicoId as string };
    });

    if (result.disputa) {
      const admins = await db.collection('users').where('rol', '==', 'admin').where('activo', '==', true).get();
      await sendPushToUsers(admins.docs.map((d) => d.id), {
        title: 'Disputa por trabajo detenido',
        body: 'Un cliente no aceptó el monto propuesto. Revisa el caso.',
        data: { type: 'work_stop_dispute', servicioId: req.data!.servicioId! },
      });
    }
    return { estado: result.estado };
  }),
);

/** An admin sets the final amount of a disputed stopped job. */
export const adminResolveDispute = onCall<{ servicioId?: string; monto?: number; nota?: string }>(OPTS, (req) =>
  guarded(async () => {
    const uid = req.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    const caller = await db.collection('users').doc(uid).get();
    if (caller.get('rol') !== 'admin') throw new HttpsError('permission-denied', 'Solo administradores.');

    const monto = req.data?.monto;
    const nota = typeof req.data?.nota === 'string' ? req.data.nota.trim().slice(0, 1000) : '';
    if (typeof monto !== 'number' || !Number.isFinite(monto) || monto < 0) {
      throw new HttpsError('invalid-argument', 'Monto inválido.');
    }
    if (nota.length < 5) throw new FlowError('Agrega una nota que explique la resolución.');

    return db.runTransaction(async (tx) => {
      const s = await readService(tx, req.data?.servicioId);
      if (s.data.estado !== ESTADO.enDisputa) wrongState();
      const tope = (s.data.detencion?.montoAprobadoPrevio as number | undefined) ?? 0;
      if (round2(monto) > round2(tope)) {
        throw new FlowError(`El monto no puede superar lo aprobado por el cliente (${fmtMxn(tope)}).`);
      }
      const close = closingFor(monto);
      tx.update(s.ref, {
        estado: close.estado,
        ...(close.costoFinal != null ? { costoFinal: close.costoFinal, completadoAt: now() } : {}),
        resolucion: { monto: round2(monto), nota, adminUid: uid, resueltoAt: now() },
        updatedAt: now(),
      });
      systemMessage(
        tx,
        s.id,
        close.costoFinal != null
          ? `ServiTec resolvió el caso: monto final ${fmtMxn(close.costoFinal)}. Nota: ${nota}`
          : `ServiTec resolvió el caso: el servicio se cierra sin cobro. Nota: ${nota}`,
        { event: 'dispute_resolved', monto: round2(monto) },
      );
      return { estado: close.estado };
    });
  }),
);
