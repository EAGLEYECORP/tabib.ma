import { NextRequest, NextResponse } from 'next/server';
import { createServerSupabaseClient } from '@/lib/supabase/server';
import { requireSameOrigin, assertJsonBodySize } from '@/lib/validation';

const uuid = (v: unknown) => typeof v === 'string' && /^[0-9a-f-]{36}$/i.test(v);

export async function GET(req: NextRequest) {
  const s = await createServerSupabaseClient();
  const { data: { user } } = await s.auth.getUser();
  if (!user) return NextResponse.json({ error: 'AUTH_REQUIRED' }, { status: 401 });
  const pharmacyId = new URL(req.url).searchParams.get('pharmacyId');
  if (!uuid(pharmacyId)) return NextResponse.json({ error: 'INVALID_PHARMACY_ID' }, { status: 400 });
  const { data, error } = await s.rpc('get_pharmacy_staff_v19_8', { p_pharmacy_id: pharmacyId });
  if (error) return NextResponse.json({ error: 'STAFF_READ_FAILED' }, { status: 403 });
  return NextResponse.json({ staff: data ?? [] }, { headers: { 'Cache-Control': 'no-store' } });
}

export async function POST(req: NextRequest) {
  requireSameOrigin(req); assertJsonBodySize(req, 8192);
  const s = await createServerSupabaseClient();
  const { data: { user } } = await s.auth.getUser();
  if (!user) return NextResponse.json({ error: 'AUTH_REQUIRED' }, { status: 401 });
  const b = await req.json().catch(() => ({}));
  if (!uuid(b.pharmacyId) || typeof b.email !== 'string' || !['pharmacy_admin','pharmacist','assistant'].includes(b.role)) {
    return NextResponse.json({ error: 'INVALID_INPUT' }, { status: 400 });
  }
  const email = b.email.trim().toLowerCase();
  if (!/^\S+@\S+\.\S+$/.test(email) || email.length > 254) return NextResponse.json({ error: 'INVALID_EMAIL' }, { status: 400 });
  const raw = `${crypto.randomUUID()}${crypto.randomUUID()}`;
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(raw));
  const tokenHash = Buffer.from(digest).toString('hex');
  const expiresAt = new Date(Date.now() + 7 * 86400000).toISOString();
  const { data, error } = await s.rpc('invite_pharmacy_staff_v19_8', {
    p_pharmacy_id: b.pharmacyId, p_email: email, p_role: b.role, p_token_hash: tokenHash, p_expires_at: expiresAt
  });
  if (error) return NextResponse.json({ error: error.message }, { status: 400 });
  const origin = new URL(req.url).origin;
  return NextResponse.json({ invitation: data, inviteUrl: `${origin}/pharmacy/staff/accept?token=${encodeURIComponent(raw)}` }, { status: 201 });
}
