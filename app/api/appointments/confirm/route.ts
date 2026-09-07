import { createClient } from '@/lib/supabase/server';
import { requireSameOrigin } from '@/lib/validation';
export async function POST(req: Request) {
  requireSameOrigin(req);
  const sb = await createClient();
  const { data: { user } } = await sb.auth.getUser();
  if (!user) return Response.json({ error: 'Authentication required' }, { status: 401 });
  const body = await req.json();
  if (typeof body.appointment_id !== 'string') return Response.json({ error: 'appointment_id required' }, { status: 400 });
  const { data: appt } = await sb.from('appointments').select('id,doctor_id,status').eq('id', body.appointment_id).maybeSingle();
  if (!appt || appt.doctor_id !== user.id) return Response.json({ error: 'Not allowed' }, { status: 403 });
  if (appt.status !== 'requested') return Response.json({ error: 'Appointment is not pending' }, { status: 409 });
  const { data, error } = await sb.from('appointments').update({ status: 'confirmed' }).eq('id', appt.id).eq('status','requested').select('*').single();
  if (error) return Response.json({ error: error.message }, { status: 400 });
  return Response.json({ appointment: data });
}
