/**
 * Shared options for every callable, so App Check enforcement is one switch.
 *
 * `enforceAppCheck` rejects any call whose App Check token is missing or
 * invalid — i.e. anything that is not our app on a genuine device. It stays
 * off until the app ships through Google Play (Play Integrity cannot attest a
 * sideloaded build), which is what `APP_CHECK_ENFORCE` in the functions' env
 * file controls; the Firebase console meanwhile charts how many calls arrive
 * verified.
 */

export const APP_CHECK_ENFORCED = process.env.APP_CHECK_ENFORCE === 'true';

export const CALLABLE_OPTS = {
  region: 'us-central1',
  memory: '256MiB' as const,
  enforceAppCheck: APP_CHECK_ENFORCED,
};

/** Same defaults with a per-function override (memory, timeout…). */
export const callableOpts = <T extends Record<string, unknown>>(extra: T) => ({
  ...CALLABLE_OPTS,
  ...extra,
});
