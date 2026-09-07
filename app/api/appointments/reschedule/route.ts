import { createClient } from '@/lib/supabase/server';
import { requireSameOrigin, readJsonWithLimit, isValidUUID } from '@/lib/validation';

export async function POST(req: Request) {
  requireSameOrigin(req);
  const body = await readJsonWithLimit(req, 4000);
  if (!isValidUUID(String(body.appointment_id ?? '')) || typeof body.start_at !== 'string' || typeof body.end_at !== 'string')
    return Response.json({ error: 'Invalid reschedule payload' }, { status: 400 });
  const sb = await createClient();
  const { data: { user } } = await sb.auth.getUser();
  if (!user) return Response.json({ error: 'Authentication required' }, { status: 401 });
  const { data, error } = await sb.rpc('reschedule_patient_appointment_v18_1', {
    p_appointment_id: body.appointment_id, p_start_at: body.start_at, p_end_at: body.end_at
  });
  if (error) return Response.json({ error: error.message }, { status: 409 });
  return Response.json({ appointment: Array.isArray(data) ? data[0] : data }, { headers: { 'Cache-Control': 'no-store' } });
}
