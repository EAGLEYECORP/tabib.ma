'use client';
import { useEffect, useState } from 'react';

export default function AcceptInvitation(){
  const [state,setState]=useState('Validation de l’invitation…');
  useEffect(()=>{
    const token=new URLSearchParams(window.location.search).get('token');
    if(!token){setState('Invitation invalide.');return}
    fetch('/api/pharmacy/staff/accept',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({token})})
      .then(async r=>{const j=await r.json();setState(r.ok?'Invitation activée. Vous pouvez accéder à votre espace pharmacie.':j.error||'Invitation refusée.');})
      .catch(()=>setState('Erreur de validation.'));
  },[]);
  return <main className="wrap"><div className="card"><h1>Invitation pharmacie</h1><p>{state}</p><a href="/pharmacy">Ouvrir l’espace pharmacie →</a></div></main>
}
