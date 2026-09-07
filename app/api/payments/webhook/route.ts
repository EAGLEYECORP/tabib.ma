import { NextResponse } from 'next/server';
import crypto from 'node:crypto';
import { createAdminClient } from '@/lib/supabase/admin';

function validSignature(raw: string, signature: string | null) {
  const secret = process.env.PAYMENT_WEBHOOK_SECRET;
  if (!secret || !signature) return false;
  const expected = crypto.createHmac('sha256', secret).update(raw).digest('hex');
  try { return crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(signature)); } catch { return false; }
}

export async function POST(req: Request) {
  const raw = await req.text();
  if (!validSignature(raw, req.headers.get('x-payment-signature'))) return NextResponse.json({ error: 'INVALID_SIGNATURE' }, { status: 401 });
  const body = JSON.parse(raw);
  const provider = String(body.provider || process.env.PAYMENT_PROVIDER_NAME || 'configured-provider');
  const eventId = String(body.eventId || '');
  const eventType = String(body.type || '');
  const paymentId = body.paymentId ? String(body.paymentId) : null;
  if (!eventId || !eventType) return NextResponse.json({ error: 'INVALID_EVENT' }, { status: 400 });
  const admin = createAdminClient();
  const { error: insertError } = await admin.from('payment_events').insert({ payment_id: paymentId, provider, event_id: eventId, event_type: eventType, payload_hash: crypto.createHash('sha256').update(raw).digest('hex') });
  if (insertError && !/duplicate/i.test(insertError.message)) return NextResponse.json({ error: 'EVENT_PERSISTENCE_FAILED' }, { status: 500 });
  if (insertError) return NextResponse.json({ ok: true, duplicate: true });
  const statusMap: Record<string, string> = { payment_succeeded: 'paid', paid: 'paid', payment_failed: 'failed', payment_cancelled: 'cancelled', payment_refunded: 'refunded' };
  const status = statusMap[eventType];
  if (paymentId && status) await admin.from('payments').update({ status, paid_at: status === 'paid' ? new Date().toISOString() : undefined, refunded_at: status === 'refunded' ? new Date().toISOString() : undefined, updated_at: new Date().toISOString() }).eq('id', paymentId);
  if (paymentId) await admin.from('payment_events').update({ processed_at: new Date().toISOString() }).eq('provider', provider).eq('event_id', eventId);
  return NextResponse.json({ ok: true });
}
