import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
export default async function AvailabilityPage(){
 const sb=await createClient(); const {data:{user}}=await sb.auth.getUser();
 if(!user)return <main className="wrap"><div className="card"><h1>Disponibilités</h1><p>Connectez-vous pour gérer votre agenda.</p><Link className="btn" href="/login?next=/doctor/availability">Se connecter</Link></div></main>;
 const {data}=await sb.from('doctor_availability').select('*').eq('doctor_id',user.id).order('day_of_week').order('start_time');
 const days=['Dimanche','Lundi','Mardi','Mercredi','Jeudi','Vendredi','Samedi'];
 return <main className="wrap"><div className="card"><span className="tag">Agenda</span><h1>Disponibilités récurrentes</h1><p className="muted">Fuseau opérationnel : Africa/Casablanca.</p><div className="grid">{(data??[]).map((x:any)=><div className="card" key={x.id}><b>{days[x.day_of_week]}</b><p>{String(x.start_time).slice(0,5)} → {String(x.end_time).slice(0,5)}</p><small>{x.slot_minutes} min · buffer {x.buffer_minutes} min · {x.active?'active':'inactive'}</small></div>)}{!data?.length&&<p className="muted">Aucune disponibilité configurée.</p>}</div><p style={{marginTop:16}}><Link className="btn" href="/doctor/agenda">Retour à l’agenda</Link></p></div></main>
}
