/**
 * Automatic assignment of service requests to técnicos.
 *
 * Three moments use it:
 *   - a request is created (onServiceCreated);
 *   - a técnico becomes able to take requests that were waiting — verified
 *     his email, became available, gained a specialty, connected payouts
 *     (onTechnicianProfileChanged);
 *   - the hourly schedule, as a backup for anything the first two missed.
 *
 * Every assignment is claimed in a transaction that re-reads the request, so
 * when two of those run at once only one técnico gets it. Waiting requests
 * are taken oldest first. Scoring lives in assignment-rules.ts (tested).
 */

import { db, admin, FieldValue } from './admin';
import { Data } from './flow-helpers';
import { ACTIVE_WORK_STATES } from './service-flow-rules';
import { FLUJO, PAGO } from './visit-rules';
import { categoryFlow } from './visit-store';
import { MAX_IN, scoreTechnician } from './assignment-rules';

type Ref = FirebaseFirestore.DocumentReference;

/**
 * Técnicos who are active, available, hold the required specialty, and have
 * verified their email (looked up on the Auth user, one getUsers() call per
 * 100). A diagnostic visit is paid up front to the técnico's Stripe account,
 * so for those only técnicos who can receive it qualify.
 */
export async function eligibleTechnicians(
  categoria: string,
  requiresPayouts = false,
): Promise<FirebaseFirestore.QueryDocumentSnapshot[]> {
  const snap = await db
    .collection('users')
    .where('rol', '==', 'tecnico')
    .where('disponible', '==', true)
    .where('activo', '==', true)
    .where('especialidades', 'array-contains', categoria)
    .get();

  const verified = new Set<string>();
  for (let i = 0; i < snap.docs.length; i += 100) {
    const chunk = snap.docs.slice(i, i + 100).map((d) => ({ uid: d.id }));
    const { users } = await admin.auth().getUsers(chunk);
    users.filter((u) => u.emailVerified).forEach((u) => verified.add(u.uid));
  }
  return snap.docs.filter((d) =>
    verified.has(d.id) && (!requiresPayouts || !!d.get('stripeConnectAccountId')));
}

/**
 * The flow (standard or with a paid diagnostic visit) and the visit fee, from
 * the category config — set server-side, so the cliente cannot choose a
 * cheaper flow.
 */
export async function flowFieldsFor(categoria: string): Promise<Data> {
  const cat = await categoryFlow(categoria);
  return cat.flujo === FLUJO.diagnostico
    ? { flujo: FLUJO.diagnostico, visita: { precio: cat.precioDiagnostico, pagoEstado: PAGO.sinAutorizar } }
    : { flujo: FLUJO.estandar };
}

export type AssignOutcome = 'asignado' | 'sin_tecnicos' | 'ya_no_pendiente';

const isWaiting = (s: Data | undefined) =>
  !!s && s.estado === 'pendiente' && !s.tecnicoId &&
  (s.tipoAsignacion ?? 'automatica') === 'automatica';

/**
 * Assigns the best eligible técnico to one waiting request. `service` saves
 * the read when the caller already has the document; `resolveFlag` closes the
 * "no técnicos available" alert an earlier attempt left for the admins.
 */
export async function assignAutomatically(
  ref: Ref,
  opts: { service?: Data; resolveFlag?: boolean } = {},
): Promise<AssignOutcome> {
  const service = opts.service ?? (await ref.get()).data();
  if (!isWaiting(service)) return 'ya_no_pendiente';
  const s = service as Data;

  const categoria = (s.categoria as string) || '';
  const flow = s.flujo ? null : await flowFieldsFor(categoria);
  const diag = (s.flujo ?? flow?.flujo) === FLUJO.diagnostico;
  const candidates = await eligibleTechnicians(categoria, diag);
  if (candidates.length === 0) return 'sin_tecnicos';

  // Jobs already in flight per candidate. count() is billed as one read per
  // 1,000 matches instead of one per service.
  const workloads = await Promise.all(candidates.map(async (doc) => {
    const active = await db.collection('servicios')
      .where('tecnicoId', '==', doc.id)
      .where('estado', 'in', ACTIVE_WORK_STATES)
      .count()
      .get();
    return active.data().count;
  }));
  const location = s.ubicacion as FirebaseFirestore.GeoPoint | undefined;
  const best = candidates
    .map((doc, i) => {
      const t = doc.data();
      return {
        uid: doc.id,
        nombre: `${t.nombre ?? ''} ${t.apellido ?? ''}`.trim(),
        score: scoreTechnician({
          calificacionPromedio: t.calificacionPromedio,
          serviciosCompletados: t.serviciosCompletados,
          ubicacionDefecto: t.ubicacionDefecto,
          activos: workloads[i],
        }, location),
      };
    })
    .sort((a, b) => b.score - a.score)[0];

  const assigned = await db.runTransaction(async (tx) => {
    const cur = (await tx.get(ref)).data();
    if (!isWaiting(cur)) return false;
    tx.update(ref, {
      ...(cur?.flujo ? {} : flow ?? {}),
      tecnicoId: best.uid,
      tecnicoNombre: best.nombre,
      estado: 'asignado',
      tipoAsignacion: 'automatica',
      asignadoAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    // The gray "Técnico asignado" pill, which onChatMessageCreated also turns
    // into the push for both participants. Same shape as a manual assignment
    // from the app (ServiceRepository.assignTechnician).
    tx.set(ref.collection('mensajes').doc(), {
      userId: 'system',
      nombreUsuario: 'ServiTec',
      mensaje: `Técnico asignado: ${best.nombre}`,
      tipo: 'sistema',
      timestamp: FieldValue.serverTimestamp(),
      leido: false,
      metadata: { event: 'technician_assigned', tecnicoId: best.uid, tipoAsignacion: 'automatica' },
    });
    return true;
  });
  if (!assigned) return 'ya_no_pendiente';

  if (opts.resolveFlag) {
    const flags = await db.collection('admin_flags')
      .where('servicioId', '==', ref.id)
      .where('type', '==', 'no_technician_available')
      .where('estado', '==', 'pendiente')
      .get();
    await Promise.all(flags.docs.map((f) => f.ref.update({
      estado: 'revisada',
      revisadoPor: 'sistema',
      revisadoAt: FieldValue.serverTimestamp(),
      notaAdmin: `Asignado automáticamente a ${best.nombre} cuando hubo un técnico disponible.`,
    })));
  }
  // eslint-disable-next-line no-console
  console.log(`Auto-assigned ${best.nombre} (${best.uid}) to ${ref.id} — score ${best.score.toFixed(1)}`);
  return 'asignado';
}

/**
 * Assigns waiting requests, oldest first: those of `categorias` when given
 * (a técnico who just became assignable), otherwise any (the hourly backup).
 * A category found to have no eligible técnico is skipped for the rest of the
 * run instead of being asked again for every request in it.
 */
export async function assignPendingRequests(
  opts: { categorias?: string[]; limit?: number } = {},
): Promise<{ revisadas: number; asignadas: number }> {
  let query: FirebaseFirestore.Query = db.collection('servicios')
    .where('estado', '==', 'pendiente')
    .where('tipoAsignacion', '==', 'automatica');
  if (opts.categorias?.length) {
    query = query.where('categoria', 'in', opts.categorias.slice(0, MAX_IN));
  }
  const pending = await query.orderBy('createdAt', 'asc').limit(opts.limit ?? 20).get();

  const noTechnicians = new Set<string>();
  let asignadas = 0;
  for (const doc of pending.docs) {
    const s = doc.data();
    const key = `${s.categoria}|${s.flujo ?? ''}`;
    if (noTechnicians.has(key)) continue;
    // One at a time, so each assignment sees the workload the previous one
    // added and two waiting jobs spread across técnicos.
    const outcome = await assignAutomatically(doc.ref, { service: s, resolveFlag: true });
    if (outcome === 'sin_tecnicos') noTechnicians.add(key);
    if (outcome === 'asignado') asignadas++;
  }
  return { revisadas: pending.size, asignadas };
}
