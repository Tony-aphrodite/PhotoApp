/**
 * Automatic assignment, decided without Firestore so it can be tested:
 * how candidates are scored, and which profile changes make a técnico worth
 * matching against the requests still waiting.
 *
 * Scoring is a port of `AutoAssignmentService` in
 * servitec_app/lib/core/utils/auto_assignment_service.dart.
 */

export interface GeoLike {
  latitude: number;
  longitude: number;
}

/** Haversine distance in km. */
export function distanceKm(a: GeoLike, b: GeoLike): number {
  const earthRadius = 6371;
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(b.latitude - a.latitude);
  const dLon = toRad(b.longitude - a.longitude);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a.latitude)) * Math.cos(toRad(b.latitude)) * Math.sin(dLon / 2) ** 2;
  return earthRadius * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
}

export interface CandidateInput {
  calificacionPromedio?: number;
  serviciosCompletados?: number;
  ubicacionDefecto?: GeoLike;
  /** Services the técnico already has in flight. */
  activos: number;
}

/**
 * 0–100: rating 0–40, workload 0–30 (−10 per job in flight), proximity
 * 0–20 (−1 per km), experience 0–10.
 */
export function scoreTechnician(t: CandidateInput, serviceLocation?: GeoLike): number {
  let score = (Number(t.calificacionPromedio) || 0) * 8;
  score += Math.max(0, 30 - t.activos * 10);
  if (serviceLocation && t.ubicacionDefecto) {
    score += Math.max(0, 20 - distanceKm(serviceLocation, t.ubicacionDefecto));
  }
  score += Math.min(10, Number(t.serviciosCompletados) || 0);
  return score;
}

export interface TechnicianProfile {
  rol?: string;
  disponible?: boolean;
  activo?: boolean;
  especialidades?: string[];
  stripeConnectAccountId?: string;
  correoVerificadoAt?: unknown;
}

const sameList = (a: string[] = [], b: string[] = []) =>
  a.length === b.length && a.every((x) => b.includes(x));

/**
 * Whether a profile update could have made this técnico a match for a
 * request that was waiting: he became available or active again, gained a
 * specialty, connected his payout account (diagnostic jobs need it), or the
 * app reported his email as verified. Anything else — a new push token, a
 * counter — is not, which keeps this trigger from querying on every write.
 */
export function technicianBecameAssignable(
  before: TechnicianProfile | undefined,
  after: TechnicianProfile | undefined,
): boolean {
  if (!after || after.rol !== 'tecnico') return false;
  if (after.disponible !== true || after.activo !== true) return false;
  if (!after.especialidades?.length) return false;
  const b = before ?? {};
  return (
    b.disponible !== true ||
    b.activo !== true ||
    !sameList(b.especialidades, after.especialidades) ||
    (!b.stripeConnectAccountId && !!after.stripeConnectAccountId) ||
    String(b.correoVerificadoAt ?? '') !== String(after.correoVerificadoAt ?? '')
  );
}

/** Firestore `in` takes at most 30 values. */
export const MAX_IN = 30;
