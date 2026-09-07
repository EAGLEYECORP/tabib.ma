import { createClient } from '@/lib/supabase/server';
import { requireSameOrigin, assertJsonBodySize } from '@/lib/validation';

const targets = new Set(['checked_in','in_consultation','completed','no_show']);

export async function POST(req: Request) {
  requireSameOrigin(req);
  await assertJsonBodySize(req, 16_384);
  const body = await req.json();
  if (typeof body.appointment_id !== 'string' || typeof body.target !== 'string' || !targets.has(body.target)) {
    return Response.json({ error: 'appointment_id and valid target required' }, { status: 400, headers: {'Cache-Control':'no-store'} });
  }
  const sb = await createClient();
  const { data: { user } } = await sb.auth.getUser();
  if (!user) return Response.json({ error: 'Authentication required' }, { status: 401 });
  const { data, error } = await sb.rpc('transition_appointment_operational', { p_appointment_id: body.appointment_id, p_target: body.target });
  if (error) return Response.json({ error: error.message }, { status: error.message === 'NOT_ALLOWED' ? 403 : 409, headers: {'Cache-Control':'no-store'} });
  return Response.json({ appointment: data }, { headers: {'Cache-Control':'no-store'} });
}
