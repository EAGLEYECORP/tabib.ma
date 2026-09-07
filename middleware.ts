import { NextResponse, type NextRequest } from 'next/server';

const RATE_WINDOW_MS = 60_000;
const RATE_LIMIT = 120;
const buckets = new Map<string, { count: number; resetAt: number }>();

function clientKey(req: NextRequest) {
  const forwarded = req.headers.get('x-forwarded-for')?.split(',')[0]?.trim();
  return forwarded || req.headers.get('x-real-ip') || 'unknown';
}

export function middleware(req: NextRequest) {
  const nonce = crypto.randomUUID().replaceAll('-', '');
  const headers = new Headers(req.headers);
  headers.set('x-request-id', nonce);
  const response = NextResponse.next({ request: { headers } });
  response.headers.set('X-Request-ID', nonce);
  response.headers.set('X-Content-Type-Options', 'nosniff');
  response.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
  response.headers.set('X-Frame-Options', 'DENY');
  response.headers.set('Permissions-Policy', 'camera=(self), microphone=(self), geolocation=()');
  response.headers.set('Cross-Origin-Opener-Policy', 'same-origin');
  response.headers.set('Cross-Origin-Resource-Policy', 'same-origin');
  response.headers.set('Content-Security-Policy', "default-src 'self'; base-uri 'self'; frame-ancestors 'none'; object-src 'none'; form-action 'self'; img-src 'self' data: blob:; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; connect-src 'self' https://*.supabase.co wss://*.supabase.co;");
  if (process.env.NODE_ENV === 'production') response.headers.set('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');

  if (req.nextUrl.pathname.startsWith('/api/')) {
    if (['POST','PUT','PATCH','DELETE'].includes(req.method)) {
      const origin = req.headers.get('origin');
      const expected = process.env.NEXT_PUBLIC_APP_URL;
      if (origin && expected) {
        try { if (new URL(origin).origin !== new URL(expected).origin) return NextResponse.json({ error: 'BAD_ORIGIN' }, { status: 403 }); }
        catch { return NextResponse.json({ error: 'BAD_ORIGIN' }, { status: 403 }); }
      }
    }
    const now = Date.now();
    const key = `${clientKey(req)}:${req.nextUrl.pathname}`;
    const bucket = buckets.get(key);
    if (!bucket || bucket.resetAt <= now) buckets.set(key, { count: 1, resetAt: now + RATE_WINDOW_MS });
    else if (++bucket.count > RATE_LIMIT) {
      return NextResponse.json({ error: 'RATE_LIMITED' }, { status: 429, headers: { 'Retry-After': String(Math.ceil((bucket.resetAt - now) / 1000)) } });
    }
    response.headers.set('Cache-Control', 'no-store');
  }
  return response;
}

export const config = { matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'] };
