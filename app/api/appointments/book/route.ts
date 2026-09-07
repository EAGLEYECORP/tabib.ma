import { createClient } from '@/lib/supabase/server';
import { requireSameOrigin, readJsonWithLimit, isValidUUID } from '@/lib/validation';

export async function POST(req: Request) {
  requireSameOrigin(req);
  const body = await readJsonWithLimit(req, 12000);
  if (!isValidUUID(String(body.doctor_id ?? '')) || typeof body.start_at !== 'string' || typeof body.end_at !== 'string')
    return Response.json({ error: 'Invalid booking payload' }, { status: 400 });
  const sb = await createClient();
  const { data: { user } } = await sb.auth.getUser();
  if (!user) return Response.json({ error: 'Authentication required' }, { status: 401 });
  const { data, error } = await sb.rpc('book_appointment_v18', {
    p_doctor_id: body.doctor_id, p_start_at: body.start_at, p_end_at: body.end_at,
    p_reason: typeof body.reason === 'string' ? body.reason : null,
    p_clinic_id: isValidUUID(String(body.clinic_id ?? '')) ? body.clinic_id : null,
    p_location_id: isValidUUID(String(body.location_id ?? '')) ? body.location_id : null,
    p_room_id: isValidUUID(String(body.room_id ?? '')) ? body.room_id : null,
  });
  if (error) return Response.json({ error: error.message }, { status: 409 });
  const appointment = Array.isArray(data) ? data[0] : data;
  return Response.json({ appointment }, { status: 201, headers: { 'Cache-Control': 'no-store' } });
}
