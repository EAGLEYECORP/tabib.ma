import { createClient } from '@/lib/supabase/server';
import { isValidUUID } from '@/lib/validation';

export async function GET(req: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  if (!isValidUUID(id)) return Response.json({ error: 'Invalid doctor id' }, { status: 400 });
  const url = new URL(req.url);
  const date = url.searchParams.get('date');
  if (!date || !/^\d{4}-\d{2}-\d{2}$/.test(date)) return Response.json({ error: 'date must be YYYY-MM-DD' }, { status: 400 });
  const from = `${date}T00:00:00+00:00`;
  const toDate = new Date(`${date}T00:00:00Z`); toDate.setUTCDate(toDate.getUTCDate() + 1);
  const to = toDate.toISOString();
  const sb = await createClient();
  const { data: doctor } = await sb.from('doctor_profiles').select('id,display_name,specialty,city,timezone').eq('id', id).eq('verified', true).maybeSingle();
  if (!doctor) return Response.json({ error: 'Doctor not bookable' }, { status: 404 });
  const { data, error } = await sb.rpc('get_public_booking_slots', { p_doctor_id: id, p_from: from, p_to: to });
  if (error) return Response.json({ error: 'Unable to load availability' }, { status: 400 });
  return Response.json({ doctor, slots: data ?? [] }, { headers: { 'Cache-Control': 'no-store' } });
}
