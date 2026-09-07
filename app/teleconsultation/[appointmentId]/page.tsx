'use client'
import { useState } from 'react'
export default function Teleconsultation({params}:{params:{appointmentId:string}}){
 const [room,setRoom]=useState<any>(null); const [loading,setLoading]=useState(false); const [error,setError]=useState('')
 async function start(){setLoading(true);setError(''); const r=await fetch('/api/teleconsultation/room',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({appointmentId:params.appointmentId})}); const j=await r.json(); setLoading(false); if(!r.ok)return setError(j.error||'Erreur'); setRoom(j.room)}
 return <main className="container"><h1>Téléconsultation Tabib</h1><p>Salon privé temporaire associé au rendez-vous. Aucun enregistrement par défaut.</p>{error&&<p role="alert">{error}</p>}{!room?<button onClick={start} disabled={loading}>{loading?'Création…':'Entrer dans la téléconsultation'}</button>:<section><h2>Salon créé</h2><p>ID technique : {room.id}</p><div className="video-placeholder">Connecteur vidéo à brancher via VIDEO_PROVIDER_*<br/>La salle reste privée et liée au rendez-vous.</div></section>}</main>
}
