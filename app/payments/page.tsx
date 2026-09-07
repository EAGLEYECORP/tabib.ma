import { createServerClient } from '@/lib/supabase/server';

export default async function PaymentsPage() {
  const supabase = await createServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return <main><h1>Paiements & facturation</h1><p>Connectez-vous pour accéder à votre espace.</p></main>;
  const { data } = await supabase.from('payments').select('id,appointment_id,amount_mad,currency,status,provider,created_at').order('created_at', { ascending: false }).limit(50);
  const { data: invoices } = await supabase.from('billing_invoices').select('id,invoice_number,payment_id,amount_mad,tax_mad,status,issued_at,paid_at').order('issued_at', { ascending: false }).limit(50);
  return <main><h1>Paiements & facturation</h1><section><h2>Paiements</h2><div className="stack">{(data ?? []).map((p) => <article className="card" key={p.id}><strong>{p.amount_mad} {p.currency}</strong><div>Statut : {p.status}</div><small>RDV : {p.appointment_id}</small></article>)}{!data?.length && <p>Aucun paiement.</p>}</div></section><section><h2>Factures</h2><div className="stack">{(invoices ?? []).map((i) => <article className="card" key={i.id}><strong>{i.invoice_number}</strong><div>{i.amount_mad} MAD · {i.status}</div><small>Émise le {new Date(i.issued_at).toLocaleDateString('fr-MA')}</small></article>)}{!invoices?.length && <p>Aucune facture disponible.</p>}</div></section></main>;
}
