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
  const { data, error } = await s.from('pharmacy_inventory_v19_7')
    .select('id,pharmacy_id,medication_id,quantity_available,reorder_threshold,availability_status,updated_at')
    .eq('pharmacy_id', pharmacyId).order('updated_at', { ascending: false }).limit(500);
  if (error) return NextResponse.json({ error: 'INVENTORY_FAILED' }, { status: 403 });
  return NextResponse.json({ inventory: data ?? [] }, { headers: { 'Cache-Control': 'no-store' } });
}

export async function POST(req: NextRequest) {
  requireSameOrigin(req); assertJsonBodySize(req, 4096);
  const s = await createServerSupabaseClient();
  const { data: { user } } = await s.auth.getUser();
  if (!user) return NextResponse.json({ error: 'AUTH_REQUIRED' }, { status: 401 });
  const b = await req.json().catch(() => ({}));
  if (!uuid(b.pharmacyId) || !uuid(b.medicationId) || !Number.isFinite(Number(b.quantityAvailable)) || Number(b.quantityAvailable) < 0 || !Number.isFinite(Number(b.reorderThreshold ?? 0)) || Number(b.reorderThreshold ?? 0) < 0) {
    return NextResponse.json({ error: 'INVALID_INPUT' }, { status: 400 });
  }
  const { data, error } = await s.rpc('update_pharmacy_inventory_v19_8', {
    p_pharmacy_id: b.pharmacyId, p_medication_id: b.medicationId,
    p_quantity: Number(b.quantityAvailable), p_reorder_threshold: Number(b.reorderThreshold ?? 0)
  });
  if (error) return NextResponse.json({ error: error.message }, { status: 400 });
  return NextResponse.json({ item: data });
}
