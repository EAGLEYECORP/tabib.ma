import { createAdminClient } from '../../../../lib/supabase/admin';
import { dispatchNotification } from '../../../../lib/notifications';

export async function POST(req: Request) {
  const secret = process.env.CRON_SECRET;
  if (!secret || req.headers.get('authorization') !== `Bearer ${secret}`) return Response.json({ error: 'Unauthorized' }, { status: 401 });
  const admin = createAdminClient();
  const { data: rows, error } = await admin.rpc('claim_due_notifications', { p_limit: 50 });
  if (error) return Response.json({ error: 'QUEUE_CLAIM_FAILED' }, { status: 500 });
  const results = [];
  for (const row of rows ?? []) {
    try { results.push(await dispatchNotification(row.id)); }
    catch (e) {
      await admin.from('notification_queue').update({ status: 'failed', last_error: 'DISPATCH_FAILED', updated_at: new Date().toISOString() }).eq('id', row.id).eq('status','processing');
      results.push({ status: 'failed', reason: 'DISPATCH_FAILED' });
    }
  }
  return Response.json({ processed: results.length, results });
}
