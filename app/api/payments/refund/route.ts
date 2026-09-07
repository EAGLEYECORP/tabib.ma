import { requireSameOrigin } from '@/lib/validation';
import { NextResponse } from 'next/server';
import { createServerClient } from '@/lib/supabase/server';
import { createAdminClient } from '@/lib/supabase/admin';
import { getPaymentProvider } from '@/lib/payments';

export async function POST(req: Request) {
  requireSameOrigin(req);
  const supabase = await createServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: 'AUTH_REQUIRED' }, { status: 401 });
  const body = await req.json().catch(() => ({}));
  const paymentId = String(body.paymentId || '');
  const amountMad = Number(body.amountMad);
  const idempotencyKey = String(body.idempotencyKey || '');
  const reason = String(body.reason || '').slice(0, 500);
  if (!paymentId || !Number.isFinite(amountMad) || amountMad <= 0 || idempotencyKey.length < 16 || idempotencyKey.length > 128) return NextResponse.json({ error: 'INVALID_INPUT' }, { status: 400 });
  const { data: payment } = await supabase.from('payments').select('*').eq('id', paymentId).single();
  const isAdmin = Boolean((await supabase.rpc('is_platform_admin')).data);
  if (!payment || (!isAdmin && payment.payer_id !== user.id && payment.payee_id !== user.id)) return NextResponse.json({ error: 'FORBIDDEN' }, { status: 403 });
  if (!isAdmin) return NextResponse.json({ error: 'REFUND_REQUIRES_PLATFORM_ADMIN' }, { status: 403 });
  if (!['paid','partially_refunded'].includes(payment.status)) return NextResponse.json({ error: 'PAYMENT_NOT_REFUNDABLE' }, { status: 400 });
  const { data: capacity, error: capacityError } = await supabase.rpc('refund_capacity', { p_payment_id: paymentId });
  if (capacityError || Number(capacity) < amountMad) return NextResponse.json({ error: 'REFUND_EXCEEDS_REMAINING_BALANCE' }, { status: 400 });
  const provider = getPaymentProvider();
  if (!provider?.refundPayment || !payment.provider_payment_id) return NextResponse.json({ error: 'REFUND_PROVIDER_NOT_CONFIGURED' }, { status: 503 });
  try {
    const result = await provider.refundPayment({ providerPaymentId: payment.provider_payment_id, amountMad, idempotencyKey });
    const admin = createAdminClient();
    const { error: refundError } = await admin.from('refunds').insert({ payment_id: paymentId, amount_mad: amountMad, status: 'refunded', provider_refund_id: result.providerRefundId, idempotency_key: idempotencyKey, reason, completed_at: new Date().toISOString() });
    if (refundError) return NextResponse.json({ error: 'REFUND_RECORD_FAILED' }, { status: 500 });
    const full = Number(capacity) === amountMad;
    await admin.from('payments').update({ status: full ? 'refunded' : 'partially_refunded', refunded_at: new Date().toISOString(), updated_at: new Date().toISOString() }).eq('id', paymentId);
    return NextResponse.json({ ok: true, ...result });
  } catch { return NextResponse.json({ error: 'REFUND_PROVIDER_ERROR' }, { status: 502 }); }
}
