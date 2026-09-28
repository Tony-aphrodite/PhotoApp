/**
 * Per-caller rate limiting for the callables and the payment endpoint.
 *
 * A token bucket held in the function instance's memory: no Firestore reads or
 * writes on the hot path, which matters because this runs on *every* call. The
 * trade-off is that the limit is per instance — with `maxInstances: 20` a
 * determined caller can get at most 20× the quota, which still turns "thousands
 * of requests a minute" into a bounded number, and App Check keeps scripts from
 * reaching the endpoints at all.
 *
 * The buckets themselves are pure (take() below) and tested.
 */

import { HttpsError } from 'firebase-functions/v2/https';

export interface Bucket {
  tokens: number;
  updatedAt: number;
}

export interface Quota {
  /** Burst size: how many calls in a row are allowed. */
  capacity: number;
  /** How long one token takes to come back, in seconds. */
  refillSeconds: number;
}

/**
 * Multiplies every quota below. Production leaves it at 1; the emulator suite
 * sets it high in functions/.env.demo-servitec, because the tests drive a
 * whole service flow in a few hundred milliseconds — faster than any person
 * can tap. The algorithm itself is covered by rate-limit.test.ts.
 */
const SCALE = Math.max(1, Number(process.env.RATE_LIMIT_SCALE) || 1);

const quota = (capacity: number, refillSeconds: number): Quota => ({
  capacity: capacity * SCALE,
  refillSeconds: refillSeconds / SCALE,
});

/** What each kind of call costs. Humans stay far below these. */
export const QUOTAS: Record<string, Quota> = {
  // Moving a service through its flow: a tap each, seconds apart.
  flow: quota(12, 5),
  // Creates a Stripe PaymentIntent — an external call that costs us quota.
  pago: quota(6, 20),
  // Stripe Connect / FacturAPI onboarding: a couple of taps, ever.
  externo: quota(5, 60),
  // Admin tools, including the broadcast that fans out to every user.
  admin: quota(20, 3),
};

/**
 * Spends one token. Returns the new bucket and, when empty, how long the
 * caller has to wait. Pure: the caller passes the clock.
 */
export function take(
  bucket: Bucket | undefined,
  quota: Quota,
  nowMs: number,
): { ok: boolean; bucket: Bucket; retryAfterSeconds: number } {
  const refilled = bucket
    ? Math.min(
        quota.capacity,
        bucket.tokens + (nowMs - bucket.updatedAt) / (quota.refillSeconds * 1000),
      )
    : quota.capacity;
  if (refilled < 1) {
    return {
      ok: false,
      bucket: { tokens: refilled, updatedAt: nowMs },
      retryAfterSeconds: Math.ceil((1 - refilled) * quota.refillSeconds),
    };
  }
  return { ok: true, bucket: { tokens: refilled - 1, updatedAt: nowMs }, retryAfterSeconds: 0 };
}

/** Buckets are dropped once they have been full again for a while. */
export const STALE_MS = 10 * 60 * 1000;
const MAX_ENTRIES = 5000;

const buckets = new Map<string, Bucket>();

function prune(nowMs: number): void {
  for (const [key, b] of buckets) {
    if (nowMs - b.updatedAt > STALE_MS) buckets.delete(key);
  }
  // A flood of distinct uids must not grow the map without end.
  if (buckets.size > MAX_ENTRIES) {
    const excess = buckets.size - MAX_ENTRIES;
    let i = 0;
    for (const key of buckets.keys()) {
      if (i++ >= excess) break;
      buckets.delete(key);
    }
  }
}

/**
 * Spends one token for `uid` on `action`, or throws the error the app shows.
 * `nowMs` is injectable for the tests.
 */
export function rateLimit(uid: string, action: keyof typeof QUOTAS | string, nowMs = Date.now()): void {
  const quota = QUOTAS[action] ?? QUOTAS.flow;
  const key = `${action}:${uid}`;
  const result = take(buckets.get(key), quota, nowMs);
  buckets.set(key, result.bucket);
  if (buckets.size > MAX_ENTRIES / 2) prune(nowMs);
  if (!result.ok) {
    throw new HttpsError(
      'resource-exhausted',
      `Demasiadas solicitudes seguidas. Espera ${result.retryAfterSeconds} segundos e inténtalo de nuevo.`,
    );
  }
}

/** Same limit for the plain HTTPS endpoint, which answers with a status code. */
export function rateLimitOk(uid: string, action: string, nowMs = Date.now()): { ok: boolean; retryAfterSeconds: number } {
  try {
    rateLimit(uid, action, nowMs);
    return { ok: true, retryAfterSeconds: 0 };
  } catch (err) {
    const m = /(\d+) segundos/.exec((err as HttpsError).message);
    return { ok: false, retryAfterSeconds: m ? Number(m[1]) : 30 };
  }
}

/** Test seam: forget every bucket. */
export function resetRateLimits(): void {
  buckets.clear();
}
