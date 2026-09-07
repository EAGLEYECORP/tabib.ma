import { requireSameOrigin } from '@/lib/validation';
import { NextResponse } from 'next/server';
import { createServerClient } from '@/lib/supabase/server';
import { getPaymentProvider, markPaymentFailed } from '@/lib/payments';

export async function POST(req: Request) {
  requireSameOrigin(req);
  const supabase = await createServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: 'AUTH_REQUIRED' }, { status: 401 });
  const body = await req.json().catch(() => ({}));
  const appointmentId = String(body.appointmentId || '');
  const amountMad = Number(body.amountMad);
  const idempotencyKey = String(body.idempotencyKey || '');
  if (!appointmentId || !Number.isFinite(amountMad) || amountMad <= 0 || !Number.isSafeInteger(Math.round(amountMad * 100)) || idempotencyKey.length < 16 || idempotencyKey.length > 128) {
    return NextResponse.json({ error: 'INVALID_INPUT' }, { status: 400 });
  }
  const { data: expected, error: priceError } = await supabase.rpc('get_authorized_appointment_price', { p_appointment_id: appointmentId });
  if (priceError) return NextResponse.json({ error: priceError.message }, { status: 400 });
  if (Number(expected) !== amountMad) return NextResponse.json({ error: 'AMOUNT_NOT_AUTHORIZED' }, { status: 400 });
  const { data: payment, error } = await supabase.rpc('create_payment_intent', { p_appointment_id: appointmentId, p_amount_mad: Number(expected), p_idempotency_key: idempotencyKey });
  if (error) return NextResponse.json({ error: error.message }, { status: 400 });
  const provider = getPaymentProvider();
  if (!provider) return NextResponse.json({ payment, providerConfigured: false, message: 'PAYMENT_PROVIDER_NOT_CONFIGURED' }, { status: 202 });
  try {
    const result = await provider.createPayment({ paymentId: payment.id, amountMad: Number(payment.amount_mad), idempotencyKey, returnUrl: `${process.env.NEXT_PUBLIC_APP_URL}/payments?payment=${payment.id}` });
    const admin = (await import('@/lib/supabase/admin')).createAdminClient();
    await admin.from('payments').update({ provider: provider.name, provider_payment_id: result.providerPaymentId, status: result.requiresAction ? 'requires_action' : 'authorized', updated_at: new Date().toISOString() }).eq('id', payment.id);
    return NextResponse.json({ paymentId: payment.id, amountMad: Number(payment.amount_mad), ...result });
  } catch (e) {
    await markPaymentFailed(payment.id, e instanceof Error ? e.message : 'PAYMENT_PROVIDER_ERROR');
    return NextResponse.json({ error: 'PAYMENT_PROVIDER_ERROR', paymentId: payment.id }, { status: 502 });
  }
}
