import { createClient } from '@/lib/supabase/server';
import { requireSameOrigin } from '@/lib/validation';

export async function GET() {
  const sb = await createClient();
  const { data: { user } } = await sb.auth.getUser();
  if (!user) return Response.json({ error: 'Authentication required' }, { status: 401 });
  const { data: doctor } = await sb.from('doctor_profiles').select('id').eq('id', user.id).maybeSingle();
  if (!doctor) return Response.json({ error: 'Doctor profile required' }, { status: 403 });
  const { data, error } = await sb.from('doctor_availability').select('*').eq('doctor_id', user.id).order('day_of_week').order('start_time');
  if (error) return Response.json({ error: error.message }, { status: 400 });
  return Response.json({ availability: data ?? [] });
}

export async function POST(req: Request) {
  requireSameOrigin(req);
  const sb = await createClient();
  const { data: { user } } = await sb.auth.getUser();
  if (!user) return Response.json({ error: 'Authentication required' }, { status: 401 });
  const body = await req.json();
  const day = Number(body.day_of_week), slot = Number(body.slot_minutes ?? 30), buffer = Number(body.buffer_minutes ?? 0);
  if (!Number.isInteger(day) || day < 0 || day > 6 || !/^\d{2}:\d{2}$/.test(body.start_time ?? '') || !/^\d{2}:\d{2}$/.test(body.end_time ?? '') || !Number.isInteger(slot) || slot < 5 || slot > 240 || !Number.isInteger(buffer) || buffer < 0 || buffer > 120) {
    return Response.json({ error: 'Invalid availability payload' }, { status: 400 });
  }
  const { data, error } = await sb.from('doctor_availability').insert({ doctor_id: user.id, day_of_week: day, start_time: body.start_time, end_time: body.end_time, slot_minutes: slot, buffer_minutes: buffer, active: body.active !== false }).select('*').single();
  if (error) return Response.json({ error: error.message }, { status: 400 });
  return Response.json({ availability: data }, { status: 201 });
}
