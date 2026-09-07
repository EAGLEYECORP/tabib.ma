import { NextRequest, NextResponse } from 'next/server';
import { createServerSupabaseClient } from '@/lib/supabase/server';
import { requireSameOrigin } from '@/lib/validation';

export async function POST(req: NextRequest) {
  requireSameOrigin(req);
  const s = await createServerSupabaseClient();
  const { data: { user } } = await s.auth.getUser();
  if (!user) return NextResponse.json({ error: 'AUTH_REQUIRED' }, { status: 401 });
  const b = await req.json().catch(() => ({}));
  if (typeof b.token !== 'string' || b.token.length < 32 || b.token.length > 200) return NextResponse.json({ error: 'INVALID_TOKEN' }, { status: 400 });
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(b.token));
  const tokenHash = Buffer.from(digest).toString('hex');
  const { data, error } = await s.rpc('accept_pharmacy_staff_invitation_v19_8', { p_token_hash: tokenHash });
  if (error) return NextResponse.json({ error: error.message }, { status: 400 });
  return NextResponse.json({ ok: true, staff: data });
}
