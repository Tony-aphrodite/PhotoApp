/**
 * Minimal CFDI XML readers.
 *
 * We need roughly six values out of a stamped CFDI (sellos, timbre, emisor and
 * receptor identity) to render the printed representation. Regex reads keep a
 * full XML parser out of the function bundle; the input is always FacturAPI's
 * own well-formed, single-line-per-node output, never arbitrary user XML.
 */

/** First value of `Attr="…"` anywhere in the document.
 *
 * Fine for attributes that appear once (`UUID`, `SelloSAT`) or where the first
 * occurrence is the one wanted — CFDI orders Emisor before Receptor, so a bare
 * `Nombre` lookup resolves to the emisor. Use {@link extractNodeAttr} when the
 * distinction matters. */
export function extractXmlAttr(xml: string, attrName: string): string | null {
  const re = new RegExp(`${attrName}\\s*=\\s*"([^"]*)"`);
  const m = xml.match(re);
  return m ? m[1] : null;
}

/** Value of an attribute scoped to a named node, e.g.
 * `extractNodeAttr(xml, 'cfdi:Receptor', 'Rfc')`. Namespace prefix optional —
 * `Receptor` matches `<cfdi:Receptor …>` too. */
export function extractNodeAttr(
  xml: string,
  nodeName: string,
  attrName: string,
): string | null {
  const bare = nodeName.includes(':') ? nodeName.split(':')[1] : nodeName;
  const nodeRe = new RegExp(`<[A-Za-z0-9_.-]*:?${bare}\\b([^>]*)>`);
  const node = xml.match(nodeRe);
  if (!node) return null;
  return extractXmlAttr(node[1], attrName);
}

/**
 * Reconstruct the "cadena original" of the TimbreFiscalDigital complement.
 *
 * SAT layout:
 *   ||{version}|{UUID}|{FechaTimbrado}|{RfcProvCertif}|{SelloCFD}|{NoCertificadoSAT}||
 *
 * SelloSAT is deliberately absent — it is the signature *over* this string,
 * not part of it.
 */
export function buildCadenaOriginalTfd(xml: string): string {
  const version = extractNodeAttr(xml, 'TimbreFiscalDigital', 'Version') ?? '1.1';
  const uuid = extractXmlAttr(xml, 'UUID') ?? '';
  const fecha = extractXmlAttr(xml, 'FechaTimbrado') ?? '';
  const rfcPac = extractXmlAttr(xml, 'RfcProvCertif') ?? '';
  const selloCfd =
    extractXmlAttr(xml, 'SelloCFD') ?? extractXmlAttr(xml, 'Sello') ?? '';
  const noCertSat = extractXmlAttr(xml, 'NoCertificadoSAT') ?? '';
  return `||${version}|${uuid}|${fecha}|${rfcPac}|${selloCfd}|${noCertSat}||`;
}

/**
 * Normalize whatever FacturAPI's download helpers return — Buffer, Blob, or
 * Node stream, depending on SDK version — into a Buffer.
 */
export async function downloadAsBuffer(payload: unknown): Promise<Buffer> {
  if (Buffer.isBuffer(payload)) return payload;
  // Blob (Web API) — how newer SDK versions wrap responses.
  if (payload && typeof (payload as any).arrayBuffer === 'function') {
    const ab = await (payload as any).arrayBuffer();
    return Buffer.from(ab);
  }
  // Node readable stream.
  if (payload && typeof (payload as any).on === 'function') {
    const chunks: Buffer[] = [];
    for await (const chunk of payload as any) chunks.push(Buffer.from(chunk));
    return Buffer.concat(chunks);
  }
  return Buffer.from(payload as any);
}
