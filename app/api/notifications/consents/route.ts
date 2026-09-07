import { createClient } from '../../../../lib/supabase/server';
import { requireSameOrigin, assertJsonBodySize } from '../../../../lib/validation';

const channels = new Set(['email','sms','whatsapp','in_app']);
const purposes = new Set(['appointment_communications','marketing']);

export async function GET() {
  const sb = await createClient();
  const { data: { user } } = await sb.auth.getUser();
  if (!user) return Response.json({ error: 'Authentication required' }, { status: 401 });
  const { data, error } = await sb.from('notification_channel_consents').select('*').eq('user_id', user.id);
  if (error) return Response.json({ error: error.message }, { status: 500 });
  return Response.json({ consents: data || [] }, { headers: { 'Cache-Control': 'no-store' } });
}

export async function PATCH(req: Request) {
  requireSameOrigin(req);
  assertJsonBodySize(req, 8192);
  const sb = await createClient();
  const { data: { user } } = await sb.auth.getUser();
  if (!user) return Response.json({ error: 'Authentication required' }, { status: 401 });
  const body = await req.json().catch(() => null);
  if (!channels.has(body?.channel) || !purposes.has(body?.purpose) || typeof body?.granted !== 'boolean') {
    return Response.json({ error: 'Invalid consent payload' }, { status: 400 });
  }
  const now = new Date().toISOString();
  const patch = { user_id: user.id, channel: body.channel, purpose: body.purpose, status: body.granted ? 'granted' : 'revoked', granted_at: body.granted ? now : null, revoked_at: body.granted ? null : now, source: 'account_settings', updated_at: now };
  const { error } = await sb.from('notification_channel_consents').upsert(patch, { onConflict: 'user_id,channel,purpose' });
  if (error) return Response.json({ error: error.message }, { status: 400 });
  return Response.json({ ok: true });
}
