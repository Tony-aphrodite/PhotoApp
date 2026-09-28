import { test } from 'node:test';
import assert from 'node:assert/strict';
import { QUOTAS, rateLimit, resetRateLimits, take } from './rate-limit';

const quota = { capacity: 3, refillSeconds: 10 };

test('a full bucket allows the burst and then refuses', () => {
  let b = take(undefined, quota, 0);
  assert.equal(b.ok, true);
  assert.equal(b.bucket.tokens, 2);
  b = take(b.bucket, quota, 0);
  b = take(b.bucket, quota, 0);
  assert.equal(b.ok, true, 'three in a row is the burst');
  const refused = take(b.bucket, quota, 0);
  assert.equal(refused.ok, false);
  assert.equal(refused.retryAfterSeconds, 10, 'one token is 10 s away');
});

test('tokens come back with time, never above the capacity', () => {
  const empty = { tokens: 0, updatedAt: 0 };
  assert.equal(take(empty, quota, 9_000).ok, false, 'not yet');
  assert.equal(take(empty, quota, 10_000).ok, true, 'one token back');
  const long = take(empty, quota, 10 * 60 * 1000);
  assert.equal(long.ok, true);
  assert.equal(long.bucket.tokens, quota.capacity - 1, 'capped at the capacity');
});

test('each uid and action has its own bucket', () => {
  resetRateLimits();
  const flow = QUOTAS.flow.capacity;
  for (let i = 0; i < flow; i++) rateLimit('uid1', 'flow', 0);
  assert.throws(() => rateLimit('uid1', 'flow', 0), /Espera \d+ segundos/);
  rateLimit('uid2', 'flow', 0); // another técnico is unaffected
  rateLimit('uid1', 'admin', 0); // another action, own budget
});

test('the payment quota is the tightest — every call reaches Stripe', () => {
  assert.ok(QUOTAS.pago.capacity < QUOTAS.flow.capacity);
  assert.ok(QUOTAS.pago.refillSeconds > QUOTAS.flow.refillSeconds);
});
