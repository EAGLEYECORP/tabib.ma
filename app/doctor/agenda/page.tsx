import { createClient } from '@/lib/supabase/server';
import Link from 'next/link';
export default async function DoctorAgenda() {
  const sb = await createClient();
  const { data: { user } } = await sb.auth.getUser();
  if (!user) return <main className="wrap"><div className="card"><h1>Agenda médecin</h1><p>Connectez-vous pour accéder à votre agenda.</p><Link className="btn" href="/login?next=/doctor/agenda">Se connecter</Link></div></main>;
  const { data } = await sb.from('appointments').select('id,start_at,end_at,status,reason,patient_id,clinic_id,location_id,room_id').eq('doctor_id',user.id).in('status',['requested','confirmed']).gte('start_at',new Date().toISOString()).order('start_at').limit(100);
  return <main className="wrap"><div className="card"><div style={{display:'flex',justifyContent:'space-between',gap:12,alignItems:'center'}}><div><span className="tag">Opérations</span><h1>Agenda</h1><p className="muted">Rendez-vous à venir</p></div><Link className="btn" href="/doctor/availability">Gérer mes disponibilités</Link></div><div className="grid">{(data??[]).map((a:any)=><div className="card" key={a.id}><b>{new Date(a.start_at).toLocaleString('fr-FR',{timeZone:'Africa/Casablanca'})}</b><p>{a.status === 'requested' ? 'En attente de confirmation' : 'Confirmé'}</p>{a.reason && <p className="muted">Motif fourni par le patient</p>}<div style={{display:'flex',gap:8}}>{a.status==='requested'&&<form action="/api/appointments/confirm" method="post"><input type="hidden" name="appointment_id" value={a.id}/><span className="muted">Confirmation via API sécurisée</span></form>}<Link className="btn" href={`/dashboard?appointment=${a.id}`}>Voir</Link></div></div>)}{!data?.length&&<p className="muted">Aucun rendez-vous à venir.</p>}</div></div></main>
}
