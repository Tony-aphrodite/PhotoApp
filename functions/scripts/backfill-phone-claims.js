#!/usr/bin/env node
/**
 * Claims the phone numbers of accounts created before phone uniqueness existed.
 *
 * Registration now writes `telefonos/{10 digits}` alongside the profile, and
 * firestore.rules refuse a second claim on the same number. Accounts that
 * already existed have no claim, so without this script a new sign-up could
 * still take their number.
 *
 * For every users/{uid} with a phone, it normalises the number the same way
 * the app does (RegistrationValidators.normalizeMxPhone) and creates the claim
 * if nobody holds it yet. When several existing accounts share a number, the
 * oldest keeps it; the rest are listed in the log for an admin to resolve —
 * the script never edits or deletes a user.
 *
 * Idempotent: existing claims are left alone, so it is safe on every deploy.
 */

const admin = require('firebase-admin');

// Keep in step with servitec_app/lib/core/utils/registration_validators.dart.
function normalizeMxPhone(input) {
  let digits = String(input || '').replace(/\D/g, '');
  if (digits.length === 13 && digits.startsWith('521')) digits = digits.slice(3);
  else if (digits.length === 12 && digits.startsWith('52')) digits = digits.slice(2);
  if (digits.length !== 10 || /^[01]/.test(digits)) return null;
  return digits;
}

async function main() {
  admin.initializeApp();
  const db = admin.firestore();

  // Sorted here rather than with orderBy('createdAt'): a Firestore orderBy
  // silently drops documents without the field, and the accounts most likely
  // to lack it are exactly the old ones this script exists for.
  const snapshot = await db.collection('users').get();
  const millis = (d) => d.get('createdAt')?.toMillis?.() ?? Number.MAX_SAFE_INTEGER;
  const users = [...snapshot.docs].sort((a, b) => millis(a) - millis(b));

  let claimed = 0;
  let alreadyClaimed = 0;
  const unparseable = [];
  const conflicts = [];

  for (const doc of users) {
    const raw = doc.get('telefono');
    if (!raw) continue;

    const phone = normalizeMxPhone(raw);
    if (!phone) {
      unparseable.push(`${doc.id} (${doc.get('email') || 'sin correo'}): "${raw}"`);
      continue;
    }

    const ref = db.collection('telefonos').doc(phone);
    try {
      await ref.create({ uid: doc.id, createdAt: admin.firestore.FieldValue.serverTimestamp() });
      claimed++;
    } catch (err) {
      // 6 = ALREADY_EXISTS
      if (err.code !== 6) throw err;
      const owner = (await ref.get()).get('uid');
      if (owner === doc.id) {
        alreadyClaimed++;
      } else {
        conflicts.push(`${phone}: ${doc.id} (${doc.get('email') || 'sin correo'}) — ya pertenece a ${owner}`);
      }
    }
  }

  console.log(`Phone claims: ${claimed} created, ${alreadyClaimed} already in place.`);
  if (unparseable.length) {
    console.log(`\n${unparseable.length} account(s) with a phone that is not 10 digits (not claimed):`);
    unparseable.forEach((l) => console.log('  ' + l));
  }
  if (conflicts.length) {
    console.log(`\n${conflicts.length} account(s) share a number with an older account:`);
    conflicts.forEach((l) => console.log('  ' + l));
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
