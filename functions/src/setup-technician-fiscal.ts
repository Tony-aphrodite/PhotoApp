/**
 * Callable Cloud Function invoked from the fiscal onboarding wizard.
 *
 * Input (from Flutter app):
 *   - rfc, razonSocial, regimenFiscal, codigoPostalFiscal
 *   - cerBase64, keyBase64, csdPassword
 *
 * Steps:
 *   1. Create a per-técnico FacturAPI organization under the parent account.
 *   2. Upload the CSD (.cer + .key + password) to that org's certificate slot.
 *   3. Retrieve the organization API key and store the reference on the
 *      técnico's user document (facturapi.organizationId, ...status=active).
 *   4. Return { ok: true } to the app.
 *
 * Sensitive material (.cer, .key, password) is never persisted here — it
 * flows from the app to FacturAPI in memory and the local reference is
 * discarded once the org is provisioned.
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { db, admin } from './lib/admin';
import { facturapiParent } from './lib/facturapi';

interface SetupTechnicianFiscalInput {
  rfc: string;
  razonSocial: string;
  regimenFiscal: string;
  codigoPostalFiscal: string;
  cerBase64: string;
  keyBase64: string;
  csdPassword: string;
}

export const setupTechnicianFiscal = onCall<SetupTechnicianFiscalInput>(
  { region: 'us-central1', memory: '512MiB' },
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }

    const {
      rfc,
      razonSocial,
      regimenFiscal,
      codigoPostalFiscal,
      cerBase64,
      keyBase64,
      csdPassword,
    } = req.data;

    if (!rfc || !razonSocial || !regimenFiscal || !codigoPostalFiscal) {
      throw new HttpsError('invalid-argument', 'Datos fiscales incompletos.');
    }
    if (!cerBase64 || !keyBase64 || !csdPassword) {
      throw new HttpsError('invalid-argument', 'CSD incompleto.');
    }

    const fx = facturapiParent();

    // Method signatures verified against
    // github.com/facturapi/facturapi-node/src/resources/organizations.ts
    // (methods listed there: create, updateLegal, uploadCertificate,
    // getTestApiKey, renewLiveApiKey, listLiveApiKeys, ...).

    // 1. Create the FacturAPI organization for this técnico.
    const org = await fx.organizations.create({ name: razonSocial });

    // 2. Set the legal / fiscal data (RFC, régimen, CP, dirección) via
    //    PUT /organizations/{id}/legal.
    await fx.organizations.updateLegal(org.id, {
      legal_name: razonSocial,
      tax_id: rfc,
      tax_system: regimenFiscal,
      address: { zip: codigoPostalFiscal },
    });

    // 3. Upload CSD certificate via PUT /organizations/{id}/certificate.
    //    The SDK signature is `uploadCertificate(id, cerFile, keyFile, password)`
    //    (positional args, not an object).
    const cerBuffer = Buffer.from(cerBase64, 'base64');
    const keyBuffer = Buffer.from(keyBase64, 'base64');
    await fx.organizations.uploadCertificate(
      org.id,
      cerBuffer,
      keyBuffer,
      csdPassword,
    );

    // 4. Retrieve organization API key (for later per-org invoice stamping).
    //    Derive test/live from the parent FacturAPI key prefix so this Cloud
    //    Function works in both sandbox and production without code changes.
    const isTestMode = (process.env.FACTURAPI_API_KEY || '').startsWith('sk_test_');
    let orgKey: string;
    if (isTestMode) {
      // getTestApiKey → GET /organizations/{id}/apikeys/test.
      // Returns the plaintext key string (or an object with the key inside;
      // handle both shapes defensively).
      const testKey = await fx.organizations.getTestApiKey(org.id);
      orgKey = typeof testKey === 'string'
        ? testKey
        : (testKey as any).key || (testKey as any).plain_key || (testKey as any).apiKey;
    } else {
      // Live keys are created (rotated) with renewLiveApiKey.
      const liveKey = await fx.organizations.renewLiveApiKey(org.id);
      orgKey = typeof liveKey === 'string'
        ? liveKey
        : (liveKey as any).key || (liveKey as any).plain_key || (liveKey as any).apiKey;
    }
    if (!orgKey) {
      throw new HttpsError(
        'internal',
        'FacturAPI did not return an API key for the new organization.',
      );
    }

    // 5. Persist reference on user document.
    await db.collection('users').doc(uid).update({
      'facturapi': {
        organizationId: org.id,
        organizationApiKey: orgKey, // stored for CFDI stamping calls
        csdUploadedAt: admin.firestore.FieldValue.serverTimestamp(),
        csdExpiresAt: admin.firestore.Timestamp.fromDate(
          // Rough estimate — CSDs are valid ~4 years. Read actual expiry from
          // the FacturAPI response when the SDK exposes it and store that.
          new Date(Date.now() + 4 * 365 * 24 * 60 * 60 * 1000),
        ),
        status: 'active',
      },
    });

    return { ok: true, organizationId: org.id };
  },
);
