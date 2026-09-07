import { createAdminClient } from './supabase/admin';

export type PaymentProvider = {
  name: string;
  createPayment: (input: { paymentId: string; amountMad: number; idempotencyKey: string; returnUrl: string }) => Promise<{ providerPaymentId: string; checkoutUrl?: string; requiresAction?: boolean }>;
  refundPayment?: (input: { providerPaymentId: string; amountMad: number; idempotencyKey: string }) => Promise<{ providerRefundId: string }>;
};

/** Provider boundary. Configure a real Moroccan payment provider before production. */
export function getPaymentProvider(): PaymentProvider | null {
  const base = process.env.PAYMENT_PROVIDER_BASE_URL;
  if (!base) return null;
  const apiKey = process.env.PAYMENT_PROVIDER_API_KEY;
  return {
    name: process.env.PAYMENT_PROVIDER_NAME || 'configured-provider',
    async createPayment(input) {
      const r = await fetch(`${base.replace(/\/$/, '')}/payments`, {
        method: 'POST', headers: { 'content-type': 'application/json', ...(apiKey ? { authorization: `Bearer ${apiKey}` } : {}) },
        body: JSON.stringify(input),
      });
      if (!r.ok) throw new Error(`PAYMENT_PROVIDER_HTTP_${r.status}`);
      const data = await r.json();
      if (!data?.providerPaymentId) throw new Error('PAYMENT_PROVIDER_INVALID_RESPONSE');
      return data;
    },
    async refundPayment(input) {
      const r = await fetch(`${base.replace(/\/$/, '')}/refunds`, {
        method: 'POST', headers: { 'content-type': 'application/json', ...(apiKey ? { authorization: `Bearer ${apiKey}` } : {}) },
        body: JSON.stringify(input),
      });
      if (!r.ok) throw new Error(`PAYMENT_PROVIDER_REFUND_HTTP_${r.status}`);
      const data = await r.json();
      if (!data?.providerRefundId) throw new Error('PAYMENT_PROVIDER_INVALID_REFUND_RESPONSE');
      return data;
    },
  };
}

export async function markPaymentFailed(paymentId: string, reason: string) {
  const admin = createAdminClient();
  await admin.from('payments').update({ status: 'failed', metadata: { failure_reason: reason }, updated_at: new Date().toISOString() }).eq('id', paymentId);
}
