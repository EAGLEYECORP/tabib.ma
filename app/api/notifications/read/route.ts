import { createClient } from '../../../../lib/supabase/server';
import { requireSameOrigin, assertJsonBodySize } from '../../../../lib/validation';

export async function POST(req: Request) {
  requireSameOrigin(req);
  assertJsonBodySize(req, 4096);
  const sb = await createClient();
  const { data: { user } } = await sb.auth.getUser();
  if (!user) return Response.json({ error: 'Authentication required' }, { status: 401 });
  const body = await req.json().catch(() => null);
  const id = typeof body?.notificationId === 'string' ? body.notificationId : '';
  if (!/^[0-9a-f-]{36}$/i.test(id)) return Response.json({ error: 'Invalid notificationId' }, { status: 400 });
  const { data, error } = await sb.rpc('mark_notification_read', { p_notification: id });
  if (error) return Response.json({ error: error.message }, { status: 400 });
  if (!data) return Response.json({ error: 'NOTIFICATION_NOT_FOUND' }, { status: 404 });
  return Response.json({ ok: true });
}
