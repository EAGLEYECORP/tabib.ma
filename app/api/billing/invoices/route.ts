import { NextResponse } from 'next/server';
import { createServerClient } from '@/lib/supabase/server';
import { requireSameOrigin } from '@/lib/validation';

export async function POST(req: Request) {
  requireSameOrigin(req);
  const supabase = await createServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: 'AUTH_REQUIRED' }, { status: 401 });
  const body = await req.json().catch(() => ({}));
  const paymentId = String(body.paymentId || '');
  if (!paymentId) return NextResponse.json({ error: 'INVALID_INPUT' }, { status: 400 });
  const { data, error } = await supabase.rpc('issue_paid_invoice', { p_payment_id: paymentId });
  if (error) return NextResponse.json({ error: error.message }, { status: 400 });
  return NextResponse.json({ invoice: data });
}
