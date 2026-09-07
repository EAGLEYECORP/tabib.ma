import { createClient } from '../../../../lib/supabase/server';

export async function GET() {
  const sb = await createClient();
  const { data: { user } } = await sb.auth.getUser();
  if (!user) return Response.json({ error: 'Authentication required' }, { status: 401, headers: { 'Cache-Control': 'no-store' } });

  const { data, error } = await sb.from('notification_queue')
    .select('id,template_key,priority,audience,action_url,appointment_id,created_at,read_at,status,payload')
    .eq('recipient_id', user.id)
    .eq('channel', 'in_app')
    .in('audience', ['doctor', 'clinic_staff', 'platform_admin'])
    .neq('status', 'cancelled')
    .order('created_at', { ascending: false })
    .limit(100);

  if (error) return Response.json({ error: error.message }, { status: 500, headers: { 'Cache-Control': 'no-store' } });
  const notifications = data ?? [];
  return Response.json({ notifications, unread: notifications.filter(n => !n.read_at).length }, { headers: { 'Cache-Control': 'no-store' } });
}
