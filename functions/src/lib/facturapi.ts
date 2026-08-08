/**
 * FacturAPI client factories.
 *
 * Two scopes are in play:
 *   - **Parent (ServiTec) org** — creates per-técnico organizations and stamps
 *     the monthly commission CFDI (ServiTec → técnico).
 *   - **Per-técnico org** — stamps the service CFDI (técnico → cliente) using
 *     the organization API key saved on the técnico's user document.
 *
 * Both factories return `any`: the shipped FacturAPI typings have drifted
 * across 4.x releases (see DEPLOY.md step 1), and pinning to them would make
 * `tsc` fail on method names that exist perfectly well at runtime. Runtime
 * behaviour is verified by the smoke test in TESTER_QUICKSTART.md.
 */

import Facturapi from 'facturapi';

// The package ships both an ESM default and a CJS module.exports; which one
// `import` resolves to depends on the bundler/transpiler. Normalize here.
const FacturapiCtor: any = (Facturapi as any)?.default ?? Facturapi;

/** Client bound to the ServiTec parent account. */
export function facturapiParent(): any {
  const key = process.env.FACTURAPI_API_KEY;
  if (!key) {
    throw new Error('FACTURAPI_API_KEY is not set — cannot reach FacturAPI.');
  }
  return new FacturapiCtor(key);
}

/** Client bound to one técnico's FacturAPI organization. */
export function facturapiForOrg(organizationApiKey: string): any {
  if (!organizationApiKey) {
    throw new Error('Missing organization API key for técnico.');
  }
  return new FacturapiCtor(organizationApiKey);
}

/** ServiTec's own organization id — receptor/emisor of the commission CFDI. */
export function servitecOrgId(): string | undefined {
  return process.env.FACTURAPI_SERVITEC_ORG_ID;
}
