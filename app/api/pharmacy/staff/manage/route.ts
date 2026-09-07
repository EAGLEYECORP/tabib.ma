import { NextRequest, NextResponse } from 'next/server';
import { createServerSupabaseClient } from '@/lib/supabase/server';
import { requireSameOrigin, assertJsonBodySize } from '@/lib/validation';

export async function POST(req: NextRequest) {
  requireSameOrigin(req); assertJsonBodySize(req, 4096);
  const s = await createServerSupabaseClient();
  const { data: { user } } = await s.auth.getUser();
  if (!user) return NextResponse.json({ error: 'AUTH_REQUIRED' }, { status: 401 });
  const b = await req.json().catch(() => ({}));
  if (typeof b.pharmacyId !== 'string' || typeof b.userId !== 'string' || !/^[0-9a-f-]{36}$/i.test(b.pharmacyId) || !/^[0-9a-f-]{36}$/i.test(b.userId)) {
    return NextResponse.json({ error: 'INVALID_INPUT' }, { status: 400 });
  }
  let data, error;
  if (b.action === 'role') ({ data, error } = await s.rpc('change_pharmacy_staff_role_v19_8', { p_pharmacy_id: b.pharmacyId, p_user_id: b.userId, p_role: b.role }));
  else if (b.action === 'status') ({ data, error } = await s.rpc('set_pharmacy_staff_status_v19_8', { p_pharmacy_id: b.pharmacyId, p_user_id: b.userId, p_status: b.status }));
  else if (b.action === 'remove') ({ data, error } = await s.rpc('remove_pharmacy_staff_access_v19_8', { p_pharmacy_id: b.pharmacyId, p_user_id: b.userId }));
  else return NextResponse.json({ error: 'INVALID_ACTION' }, { status: 400 });
  if (error) return NextResponse.json({ error: error.message }, { status: 400 });
  return NextResponse.json({ ok: true, staff: data });
}
