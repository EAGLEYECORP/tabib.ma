import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';

const labels: Record<string,string> = { requested:'En attente', confirmed:'Confirmé', checked_in:'Arrivé', in_consultation:'En consultation', completed:'Terminé', no_show:'Absent', cancelled:'Annulé' };

export default async function DoctorDayPage() {
  const sb = await createClient();
  const { data: { user } } = await sb.auth.getUser();
  if (!user) return <main className="wrap"><div className="card"><h1>Journée médecin</h1><p>Connectez-vous pour accéder aux opérations.</p><Link className="btn" href="/login?next=/doctor/day">Se connecter</Link></div></main>;
  const now = new Date(); const start = new Date(now); start.setHours(0,0,0,0); const end = new Date(start); end.setDate(end.getDate()+1);
  const { data } = await sb.from('appointments').select('id,start_at,end_at,status,clinic_id,location_id,room_id').eq('doctor_id', user.id).gte('start_at', start.toISOString()).lt('start_at', end.toISOString()).neq('status','cancelled').order('start_at');
  return <main className="wrap"><div className="card"><div style={{display:'flex',justifyContent:'space-between',alignItems:'center',gap:12}}><div><span className="tag">Opérations</span><h1>Journée du jour</h1><p className="muted">Flux administratif uniquement — aucune note clinique.</p></div><Link className="btn" href="/doctor/agenda">Agenda</Link></div><div className="grid">{(data??[]).map((a:any)=><div className="card" key={a.id}><b>{new Date(a.start_at).toLocaleTimeString('fr-FR',{hour:'2-digit',minute:'2-digit',timeZone:'Africa/Casablanca'})} → {new Date(a.end_at).toLocaleTimeString('fr-FR',{hour:'2-digit',minute:'2-digit',timeZone:'Africa/Casablanca'})}</b><p>{labels[a.status] ?? a.status}</p><div style={{display:'flex',gap:8,flexWrap:'wrap'}}>{a.status==='confirmed'&&<Transition id={a.id} target="checked_in" label="Marquer arrivé"/>}{a.status==='checked_in'&&<Transition id={a.id} target="in_consultation" label="Démarrer"/>}{a.status==='in_consultation'&&<Transition id={a.id} target="completed" label="Terminer"/>}{['confirmed','checked_in'].includes(a.status)&&<Transition id={a.id} target="no_show" label="Absent"/>}</div></div>)}{!data?.length&&<p className="muted">Aucun rendez-vous aujourd’hui.</p>}</div></div></main>
}

function Transition({id,target,label}:{id:string;target:string;label:string}) {
  return <form action="/api/appointments/transition" method="post"><input type="hidden" name="appointment_id" value={id}/><input type="hidden" name="target" value={target}/><span className="muted">Action via endpoint sécurisé: {label}</span></form>;
}
