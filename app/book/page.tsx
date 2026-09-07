'use client';
import { useEffect, useMemo, useState } from 'react';
import { createClient } from '@/lib/supabase/client';

export default function BookPage() {
  const params = useMemo(() => new URLSearchParams(typeof window === 'undefined' ? '' : window.location.search), []);
  const doctorId = params.get('doctor') ?? '';
  const [date, setDate] = useState(() => new Date().toISOString().slice(0,10));
  const [doctor, setDoctor] = useState<any>(null); const [slots, setSlots] = useState<any[]>([]);
  const [selected, setSelected] = useState<any>(null); const [reason, setReason] = useState(''); const [busy,setBusy]=useState(false); const [message,setMessage]=useState('');
  async function load(){ if(!doctorId)return; setMessage(''); const r=await fetch(`/api/public/doctors/${doctorId}/slots?date=${date}`,{cache:'no-store'}); const j=await r.json(); if(!r.ok){setMessage(j.error||'Erreur');return;} setDoctor(j.doctor);setSlots(j.slots||[]);setSelected(null); }
  useEffect(()=>{load()},[date]);
  async function book(){ if(!selected)return; setBusy(true); setMessage(''); try { const sb=createClient(); const {data:{user}}=await sb.auth.getUser(); if(!user){window.location.href=`/login?next=${encodeURIComponent(`/book?doctor=${doctorId}`)}`;return;} const r=await fetch('/api/appointments/book',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({doctor_id:doctorId,start_at:selected.start_at,end_at:selected.end_at,reason})}); const j=await r.json(); if(!r.ok){setMessage(j.error||'Créneau indisponible');return;} window.location.href=`/booking/confirmation?id=${encodeURIComponent(j.appointment.id)}`; } finally {setBusy(false)} }
  if(!doctorId)return <main style={{padding:40}}><h1>Réservation</h1><p>Médecin manquant.</p></main>;
  return <main style={{maxWidth:850,margin:'30px auto',padding:20}}><h1>Prendre rendez-vous</h1>{doctor&&<><h2>Dr {doctor.display_name}</h2><p>{doctor.specialty} · {doctor.city}</p></>}<label>Date<br/><input type="date" value={date} min={new Date().toISOString().slice(0,10)} onChange={e=>setDate(e.target.value)}/></label><h2>Créneaux disponibles</h2><div style={{display:'grid',gridTemplateColumns:'repeat(3,1fr)',gap:10}}>{slots.map(s=><button key={s.start_at} onClick={()=>setSelected(s)} aria-pressed={selected?.start_at===s.start_at}>{new Date(s.start_at).toLocaleTimeString('fr-FR',{hour:'2-digit',minute:'2-digit',timeZone:doctor?.timezone||'Africa/Casablanca'})}</button>)}</div><label style={{display:'block',marginTop:20}}>Motif (optionnel)<br/><textarea maxLength={1000} value={reason} onChange={e=>setReason(e.target.value)} /></label><button disabled={!selected||busy} onClick={book} style={{marginTop:15}}>{busy?'Réservation…':'Confirmer le rendez-vous'}</button>{message&&<p role="alert">{message}</p>}</main>
}
