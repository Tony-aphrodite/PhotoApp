/**
 * Cloud Storage persistence for CFDI artifacts.
 *
 * Layout (mirrors the paths `storage.rules` gates on):
 *   facturas/{facturaId}.xml
 *   facturas/{facturaId}.pdf
 *
 * On access control: the returned URL carries a Firebase download token rather
 * than being a rules-checked path. That is deliberate — the token is only ever
 * written into `facturas/{facturaId}`, and that document is already restricted
 * to the emisor técnico, the receptor cliente, and admins. Anyone who can read
 * the URL could read the invoice anyway, so the effective audience matches what
 * `storage.rules` describes, while staying valid indefinitely (v4 signed URLs
 * cap at 7 days — far too short for a document the SAT expects to be
 * retrievable for five years).
 */

import { randomUUID } from 'crypto';
import { admin } from './admin';

async function uploadArtifact(
  objectPath: string,
  buffer: Buffer,
  contentType: string,
): Promise<string> {
  const bucket = admin.storage().bucket();
  const file = bucket.file(objectPath);
  const downloadToken = randomUUID();

  await file.save(buffer, {
    resumable: false,
    contentType,
    metadata: {
      contentType,
      cacheControl: 'private, max-age=31536000',
      metadata: {
        firebaseStorageDownloadTokens: downloadToken,
      },
    },
  });

  return (
    `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/` +
    `${encodeURIComponent(objectPath)}?alt=media&token=${downloadToken}`
  );
}

/** Store the SAT-stamped XML. Returns its download URL. */
export function uploadCfdiXml(
  facturaId: string,
  xml: Buffer,
): Promise<string> {
  return uploadArtifact(`facturas/${facturaId}.xml`, xml, 'application/xml');
}

/** Store the ServiTec-branded PDF. Returns its download URL. */
export function uploadCfdiPdf(
  facturaId: string,
  pdf: Buffer,
): Promise<string> {
  return uploadArtifact(`facturas/${facturaId}.pdf`, pdf, 'application/pdf');
}
