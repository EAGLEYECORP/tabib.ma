export const MAX_JSON_BYTES = 256 * 1024;

export function requireSameOrigin(req: Request) {
  const origin = req.headers.get('origin');
  const allowed = process.env.NEXT_PUBLIC_APP_URL;
  if (!origin || !allowed) throw new Error('BAD_ORIGIN');
  let actual: URL, expected: URL;
  try { actual = new URL(origin); expected = new URL(allowed); } catch { throw new Error('BAD_ORIGIN'); }
  if (actual.origin !== expected.origin) throw new Error('BAD_ORIGIN');
}

export async function readJson<T = unknown>(req: Request): Promise<T> {
  const declared = Number(req.headers.get('content-length') || 0);
  if (declared > MAX_JSON_BYTES) throw new Error('PAYLOAD_TOO_LARGE');
  const buf = new Uint8Array(await req.arrayBuffer());
  if (buf.byteLength > MAX_JSON_BYTES) throw new Error('PAYLOAD_TOO_LARGE');
  try { return JSON.parse(new TextDecoder().decode(buf)) as T; }
  catch { throw new Error('INVALID_JSON'); }
}

export function text(value: unknown, max = 500) {
  return typeof value === 'string' ? value.trim().slice(0, max) : '';
}
export function uuid(value: unknown) {
  return typeof value === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value) ? value : null;
}
