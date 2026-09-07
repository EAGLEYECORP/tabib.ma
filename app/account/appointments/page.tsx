import { createClient } from '@/lib/supabase/server';
import Link from 'next/link';

function label(status: string) {
  return ({ requested: 'En attente', confirmed: 'Confirmé', cancelled: 'Annulé', completed: 'Terminé', no_show: 'Absent' } as Record<string,string>)[status] ?? status;
}

export default async function AppointmentCenter() {
  const sb = await createClient();
  const { data: { user } } = await sb.auth.getUser();
  if (!user) return <main className="wrap"><div className="card"><h1>Mes rendez-vous</h1><p>Connectez-vous pour accéder à votre agenda.</p><Link className="btn" href="/login?next=%2Faccount%2Fappointments">Connexion</Link></div></main>;
  const { data: appts } = await sb.from('appointments').select('id,start_at,end_at,status,reason,doctor_profiles(display_name,specialty,city,timezone)').eq('patient_id', user.id).order('start_at', { ascending: true });
  return <main className="wrap"><div className="card"><div style={{display:'flex',justifyContent:'space-between',gap:16,alignItems:'center',flexWrap:'wrap'}}><div><h1>Mes rendez-vous</h1><p className="muted">Consultez, annulez ou reprogrammez vos rendez-vous.</p></div><Link className="btn secondary" href="/directory">Trouver un médecin</Link></div>{!appts?.length && <p className="muted" style={{marginTop:24}}>Aucun rendez-vous.</p>}{appts?.map((a:any)=><article key={a.id} className="card" style={{marginTop:16}}><div style={{display:'flex',justifyContent:'space-between',gap:12}}><div><h2 style={{marginTop:0}}>Dr {a.doctor_profiles?.display_name ?? 'Médecin'}</h2><p>{a.doctor_profiles?.specialty} · {a.doctor_profiles?.city}</p></div><strong>{label(a.status)}</strong></div><p><b>{new Date(a.start_at).toLocaleString('fr-FR',{timeZone:a.doctor_profiles?.timezone || 'Africa/Casablanca'})}</b></p>{a.reason && <p className="muted">Motif enregistré</p>}{['requested','confirmed'].includes(a.status) && <div style={{display:'flex',gap:10,flexWrap:'wrap'}}><Link className="btn" href={`/account/appointments/${a.id}/reschedule`}>Reprogrammer</Link><Link className="btn secondary" href={`/account/appointments/${a.id}/cancel`}>Annuler</Link></div>}</article>)}</div></main>;
}
