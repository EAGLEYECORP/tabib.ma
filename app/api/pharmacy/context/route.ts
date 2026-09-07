import { NextResponse } from 'next/server';
import { createServerSupabaseClient } from '@/lib/supabase/server';

export async function GET() {
  const s = await createServerSupabaseClient();
  const { data: { user } } = await s.auth.getUser();
  if (!user) return NextResponse.json({ error: 'AUTH_REQUIRED' }, { status: 401 });
  const { data, error } = await s.rpc('get_my_pharmacy_context_v19_8');
  if (error) return NextResponse.json({ error: 'PHARMACY_CONTEXT_FAILED' }, { status: 500 });
  return NextResponse.json({ pharmacies: data ?? [] }, { headers: { 'Cache-Control': 'no-store' } });
}
