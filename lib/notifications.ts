import { createAdminClient } from './supabase/admin';

type Channel = 'email' | 'sms' | 'whatsapp';

const endpointByChannel: Record<Channel, string | undefined> = {
  email: process.env.EMAIL_PROVIDER_BASE_URL,
  sms: process.env.SMS_PROVIDER_BASE_URL,
  whatsapp: process.env.WHATSAPP_PROVIDER_BASE_URL,
};

export function providerConfigured(channel: Channel) {
  return Boolean(endpointByChannel[channel]);
}

export async function dispatchNotification(id: string) {
  const admin = createAdminClient();
  const { data: n, error } = await admin.from('notification_queue').select('*').eq('id', id).single();
  if (error || !n) throw new Error('NOTIFICATION_NOT_FOUND');
  if (n.status === 'sent' || n.status === 'cancelled') return { status: n.status };
  if (n.status !== 'processing') throw new Error('NOTIFICATION_NOT_CLAIMED');
  if (n.channel === 'in_app') {
    const { error: e } = await admin.from('notification_queue').update({ status: 'sent', sent_at: new Date().toISOString(), updated_at: new Date().toISOString() }).eq('id', id);
    if (e) throw e;
    return { status: 'sent', channel: 'in_app' };
  }
  const channel = n.channel as Channel;
  const endpoint = endpointByChannel[channel];
  if (!endpoint) {
    await admin.from('notification_queue').update({ status: 'failed', attempts: n.attempts, last_error: 'PROVIDER_NOT_CONFIGURED', updated_at: new Date().toISOString() }).eq('id', id);
    await admin.from('notification_delivery_logs').insert({ notification_id: id, channel, outcome: 'failed', error_code: 'PROVIDER_NOT_CONFIGURED' });
    return { status: 'failed', reason: 'PROVIDER_NOT_CONFIGURED' };
  }
  const { data: authUser } = await admin.auth.admin.getUserById(n.recipient_id);
  const destination = channel === 'email' ? authUser.user?.email : authUser.user?.phone;
  if (!destination) {
    await admin.from('notification_queue').update({ status: 'failed', attempts: n.attempts, last_error: 'DESTINATION_NOT_AVAILABLE', updated_at: new Date().toISOString() }).eq('id', id);
    await admin.from('notification_delivery_logs').insert({ notification_id: id, channel, outcome: 'failed', error_code: 'DESTINATION_NOT_AVAILABLE' });
    return { status: 'failed', reason: 'DESTINATION_NOT_AVAILABLE' };
  }
  const res = await fetch(endpoint, { method: 'POST', headers: { 'content-type': 'application/json', ...(process.env.NOTIFICATION_PROVIDER_API_KEY ? { authorization: `Bearer ${process.env.NOTIFICATION_PROVIDER_API_KEY}` } : {}) }, body: JSON.stringify({ to: destination, template: n.template_key, data: n.payload, idempotency_key: n.idempotency_key }) });
  const text = await res.text();
  if (!res.ok) {
    await admin.from('notification_queue').update({ status: 'failed', attempts: n.attempts, last_error: `PROVIDER_HTTP_${res.status}`, updated_at: new Date().toISOString() }).eq('id', id);
    await admin.from('notification_delivery_logs').insert({ notification_id: id, channel, outcome: 'failed', error_code: `HTTP_${res.status}` });
    return { status: 'failed', reason: `HTTP_${res.status}` };
  }
  let providerMessageId: string | null = null;
  try { providerMessageId = JSON.parse(text)?.id ?? null; } catch {}
  await admin.from('notification_queue').update({ status: 'sent', attempts: n.attempts, provider_message_id: providerMessageId, sent_at: new Date().toISOString(), updated_at: new Date().toISOString() }).eq('id', id);
  await admin.from('notification_delivery_logs').insert({ notification_id: id, channel, outcome: 'sent', provider: channel, provider_message_id: providerMessageId });
  return { status: 'sent', channel, providerMessageId };
}
