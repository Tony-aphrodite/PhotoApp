/**
 * Firestore trigger — a client just created a service request.
 *
 * Every *later* lifecycle event (assignment, cotización, inicio, pago) already
 * reaches both parties: those code paths post a system message into
 * `servicios/{id}/mensajes`, and `onChatMessageCreated` fans that out as a push.
 * Creation is the one event with no chat thread to hang a message on, so it
 * needs its own trigger — this one, which replaces `onServiceCreated` from the
 * legacy `servitec_app/functions` codebase.
 *
 * Two paths, keyed on `tipoAsignacion` (defaults to `automatica`):
 *
 *   automatica → score the eligible técnicos, assign the best one, and post the
 *                "Técnico asignado" system message. The push then rides the
 *                existing chat fan-out, so the técnico is notified exactly once.
 *   manual     → nobody is assigned yet, so notify the admins who will do it and
 *                broadcast to eligible técnicos in case they self-assign.
 *
 * When no técnico matches the category at all, admins are alerted either way —
 * the request would otherwise sit in `pendiente` unnoticed.
 *
 * A request nobody could take when it was created is not left to the admin:
 * onTechnicianProfileChanged assigns it as soon as a matching técnico becomes
 * able to take it, and the hourly schedule retries as a backup. The
 * assignment itself (scoring, the transactional claim) is lib/assignment.ts.
 */

import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { db, admin, FieldValue } from './lib/admin';
import { sendPushToUsers } from './lib/push';
import { FLUJO } from './lib/visit-rules';
import {
  assignAutomatically,
  assignPendingRequests,
  eligibleTechnicians,
  flowFieldsFor,
} from './lib/assignment';
import { technicianBecameAssignable } from './lib/assignment-rules';

async function notifyAdmins(
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<void> {
  const admins = await db
    .collection('users')
    .where('rol', '==', 'admin')
    .where('activo', '==', true)
    .get();
  await sendPushToUsers(
    admins.docs.map((d) => d.id),
    { title, body, data },
  );
}

export const onServiceCreated = onDocumentCreated(
  {
    document: 'servicios/{servicioId}',
    region: 'us-central1',
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const service = snap.data();
    const servicioId = event.params.servicioId as string;

    // Only brand-new, unassigned requests are interesting here.
    if (service.estado !== 'pendiente') return;

    const categoria = (service.categoria as string) || '';
    const titulo = (service.titulo as string) || 'Nuevo servicio';
    const urgencia = (service.urgencia as string) || 'normal';
    const tipoAsignacion = (service.tipoAsignacion as string) || 'automatica';

    if (tipoAsignacion === 'automatica') {
      // Writes the flow, the técnico and the "Técnico asignado" message in
      // one transaction — or nothing, when nobody can take it yet.
      const outcome = await assignAutomatically(snap.ref, { service });
      if (outcome !== 'sin_tecnicos') return;
    }

    // No assignment happened, so this is the write that records the flow.
    const flow = await flowFieldsFor(categoria);
    await snap.ref.update(flow);

    const candidates = tipoAsignacion === 'automatica'
      ? []
      : await eligibleTechnicians(categoria, flow.flujo === FLUJO.diagnostico);

    if (candidates.length === 0) {
      // eslint-disable-next-line no-console
      console.log(`No técnicos available for category "${categoria}"`);
      await notifyAdmins(
        'Sin técnicos disponibles',
        `Nadie cubre "${categoria}" para «${titulo}» todavía. Se asignará solo en cuanto haya un técnico disponible.`,
        { type: 'no_technician_available', servicioId, categoria },
      );
      await db.collection('admin_flags').add({
        type: 'no_technician_available',
        servicioId,
        categoria,
        estado: 'pendiente',
        createdAt: FieldValue.serverTimestamp(),
      });
      return;
    }

    // Manual assignment: the admin picks. Tell them, and let matching
    // técnicos know a job is up for grabs.
    await notifyAdmins(
      'Nuevo servicio pendiente',
      `${categoria}: ${titulo}`,
      { type: 'service_awaiting_assignment', servicioId, categoria },
    );
    await sendPushToUsers(
      candidates.map((d) => d.id),
      {
        title: 'Nuevo servicio disponible',
        body: `${categoria}: ${titulo}`,
        data: { type: 'service_available', servicioId, categoria, urgencia },
      },
    );
  },
);

/**
 * A técnico just became able to take work he could not before — verified his
 * email (the app stamps `correoVerificadoAt`), became available or active,
 * gained a specialty, or connected his payout account. Requests in his
 * categories that are still waiting are assigned now, oldest first, instead of
 * waiting for an admin or for the hourly backup.
 *
 * Fires on every profile write; technicianBecameAssignable() turns away the
 * ones that cannot matter (push tokens, counters) before anything is read.
 */
export const onTechnicianProfileChanged = onDocumentUpdated(
  {
    document: 'users/{uid}',
    region: 'us-central1',
  },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!technicianBecameAssignable(before, after)) return;

    const user = await admin.auth().getUser(event.params.uid as string).catch(() => null);
    if (!user?.emailVerified) return;

    const { revisadas, asignadas } = await assignPendingRequests({
      categorias: after?.especialidades as string[],
    });
    if (revisadas) {
      // eslint-disable-next-line no-console
      console.log(`Técnico ${event.params.uid} became assignable: ${asignadas}/${revisadas} waiting requests assigned.`);
    }
  },
);
