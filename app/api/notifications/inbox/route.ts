import { createClient } from '../../../../lib/supabase/server';

export async function GET() {
  const sb = await createClient();
  const { data: { user } } = await sb.auth.getUser();
  if (!user) return Response.json({ error: 'Authentication required' }, { status: 401, headers: { 'Cache-Control': 'no-store' } });
  const { data, error } = await sb.from('notification_queue')
    .select('id,template_key,payload,created_at,read_at,status')
    .eq('recipient_id', user.id).eq('channel', 'in_app').neq('status', 'cancelled')
    .order('created_at', { ascending: false }).limit(50);
  if (error) return Response.json({ error: error.message }, { status: 500, headers: { 'Cache-Control': 'no-store' } });
  const unread = (data || []).filter(x => !x.read_at).length;
  return Response.json({ notifications: data || [], unread }, { headers: { 'Cache-Control': 'no-store' } });
}
