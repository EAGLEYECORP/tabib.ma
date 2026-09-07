'use client';

import { useEffect, useState } from 'react';

type Pharmacy={pharmacy_id:string;pharmacy_name:string;city:string;role:string};
type Staff={user_id:string;full_name:string|null;email:string|null;role:string;status:string};

export default function StaffManagement(){
  const [pharmacies,setPharmacies]=useState<Pharmacy[]>([]);
  const [pharmacyId,setPharmacyId]=useState('');
  const [staff,setStaff]=useState<Staff[]>([]);
  const [email,setEmail]=useState('');
  const [role,setRole]=useState('pharmacist');
  const [inviteUrl,setInviteUrl]=useState('');
  const [error,setError]=useState('');

  async function load(){
    const c=await fetch('/api/pharmacy/context');const cj=await c.json();
    if(!c.ok){setError(cj.error||'Contexte indisponible');return}
    const eligible=(cj.pharmacies||[]).filter((p:Pharmacy)=>p.role==='owner'||p.role==='pharmacy_admin');
    setPharmacies(eligible); if(!pharmacyId&&eligible[0])setPharmacyId(eligible[0].pharmacy_id);
  }
  async function loadStaff(){
    if(!pharmacyId)return;
    const r=await fetch(`/api/pharmacy/staff?pharmacyId=${encodeURIComponent(pharmacyId)}`);const j=await r.json();
    if(!r.ok){setError(j.error||'Lecture équipe refusée');return}setStaff(j.staff||[]);
  }
  useEffect(()=>{load()},[]);
  useEffect(()=>{loadStaff()},[pharmacyId]);

  async function invite(e:React.FormEvent){
    e.preventDefault();setError('');setInviteUrl('');
    const r=await fetch('/api/pharmacy/staff',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({pharmacyId,email,role})});
    const j=await r.json();if(!r.ok){setError(j.error||'Invitation refusée');return}
    setInviteUrl(j.inviteUrl);setEmail('');loadStaff();
  }
  async function action(userId:string,action:string,value?:string){
    const r=await fetch('/api/pharmacy/staff/manage',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({pharmacyId,userId,action,...(action==='role'?{role:value}:{status:value}))});
    const j=await r.json();if(!r.ok){setError(j.error||'Action refusée');return}loadStaff();
  }

  return <main className="wrap"><div className="card"><h1>Pharmacy Staff</h1><p className="muted">Gestion opérationnelle des collaborateurs. Aucun privilège n’est accordé par le frontend.</p>
    {pharmacies.length===0?<p className="error">Aucun rôle owner/pharmacy_admin actif.</p>:<>
      {pharmacies.length>1&&<label>Pharmacie<select value={pharmacyId} onChange={e=>setPharmacyId(e.target.value)}>{pharmacies.map(p=><option key={p.pharmacy_id} value={p.pharmacy_id}>{p.pharmacy_name} — {p.city}</option>)}</select></label>}
      <form onSubmit={invite} style={{marginTop:18}}><h2>Inviter</h2><input required type="email" value={email} onChange={e=>setEmail(e.target.value)} placeholder="collaborateur@exemple.ma"/><select value={role} onChange={e=>setRole(e.target.value)}><option value="pharmacy_admin">pharmacy_admin</option><option value="pharmacist">pharmacist</option><option value="assistant">assistant</option></select><button className="btn" type="submit">Créer l’invitation</button></form>
      {inviteUrl&&<p className="muted">Invitation créée. Lien à transmettre au collaborateur : <code>{inviteUrl}</code></p>}
      {error&&<p className="error">{error}</p>}
      <h2 style={{marginTop:24}}>Collaborateurs</h2>
      {staff.map(s=><div key={s.user_id} style={{padding:'12px 0',borderBottom:'1px solid var(--line)'}}><strong>{s.full_name||s.email||s.user_id.slice(0,8)}</strong><span className="muted"> · {s.role} · {s.status}</span>
        {s.role!=='owner'&&<div style={{display:'flex',gap:8,flexWrap:'wrap',marginTop:8}}><select value={s.role} onChange={e=>action(s.user_id,'role',e.target.value)}><option value="pharmacy_admin">pharmacy_admin</option><option value="pharmacist">pharmacist</option><option value="assistant">assistant</option></select><button className="btn" onClick={()=>action(s.user_id,'status',s.status==='active'?'suspended':'active')}>{s.status==='active'?'Suspendre':'Activer'}</button><button className="btn danger" onClick={()=>action(s.user_id,'remove')}>Supprimer l’accès</button></div>}</div>)}
    </>}
  </div></main>
}
