'use client';

import { useEffect, useMemo, useState } from 'react';

type Pharmacy={pharmacy_id:string;pharmacy_name:string;city:string;address:string;role:string;status:string};
type Order={id:string;prescription_id?:string;pharmacy_id:string;status:string;requested_at:string;accepted_at?:string|null;ready_at?:string|null;dispensed_at?:string|null;cancelled_at?:string|null;pickup_deadline?:string|null;rejection_reason_code?:string|null};
type Item={id:string;pharmacy_id:string;medication_id:string;quantity_available:number;reorder_threshold:number;availability_status:string;updated_at:string};
type Staff={user_id:string;full_name:string|null;email:string|null;role:string;status:string;invited_at:string|null;activated_at:string|null;suspended_at:string|null};

const next:Record<string,string[]> = {
  requested:['accepted','rejected','cancelled'],
  accepted:['preparing','cancelled'],
  preparing:['ready','cancelled'],
  ready:['dispensed']
};
const labels:Record<string,string> = {
  requested:'Demandes entrantes',accepted:'Acceptées',preparing:'En préparation',
  ready:'Prêtes',dispensed:'Délivrées',rejected:'Rejetées',cancelled:'Annulées'
};

export default function PharmacyWorkspace(){
  const [pharmacies,setPharmacies]=useState<Pharmacy[]>([]);
  const [pharmacyId,setPharmacyId]=useState('');
  const [orders,setOrders]=useState<Order[]>([]);
  const [inventory,setInventory]=useState<Item[]>([]);
  const [staff,setStaff]=useState<Staff[]>([]);
  const [error,setError]=useState('');

  async function loadContext(){
    const r=await fetch('/api/pharmacy/context'); const j=await r.json();
    if(!r.ok){setError(j.error||'Contexte pharmacie indisponible');return}
    setPharmacies(j.pharmacies||[]);
    if(!pharmacyId && j.pharmacies?.[0]?.pharmacy_id)setPharmacyId(j.pharmacies[0].pharmacy_id);
  }
  async function load(){
    if(!pharmacyId)return;
    setError('');
    const [o,i]=await Promise.all([
      fetch(`/api/pharmacy/orders?pharmacyId=${encodeURIComponent(pharmacyId)}`),
      fetch(`/api/pharmacy/inventory?pharmacyId=${encodeURIComponent(pharmacyId)}`)
    ]);
    const oj=await o.json(),ij=await i.json();
    if(!o.ok||!i.ok){setError(oj.error||ij.error||'Erreur de chargement');return}
    setOrders(oj.orders||[]);setInventory(ij.inventory||[]);
    const me=pharmacies.find(p=>p.pharmacy_id===pharmacyId);
    if(me?.role==='owner'||me?.role==='pharmacy_admin'){
      const sr=await fetch(`/api/pharmacy/staff?pharmacyId=${encodeURIComponent(pharmacyId)}`);
      const sj=await sr.json(); if(sr.ok)setStaff(sj.staff||[]);
    } else setStaff([]);
  }
  useEffect(()=>{loadContext()},[]);
  useEffect(()=>{load()},[pharmacyId,pharmacies.length]);

  async function transition(id:string,status:string){
    setError('');
    const r=await fetch('/api/pharmacy/orders/update',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({
      orderId:id,status,reasonCode:status==='rejected'?'UNAVAILABLE':undefined,idempotencyKey:crypto.randomUUID()
    })});
    const j=await r.json();if(!r.ok){setError(j.error||'Transition refusée');return}load();
  }
  async function staffAction(userId:string,action:string,value?:string){
    const r=await fetch('/api/pharmacy/staff/manage',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({pharmacyId,userId,action,...(action==='role'?{role:value}:{status:value})})});
    const j=await r.json();if(!r.ok){setError(j.error||'Action refusée');return}load();
  }

  const counts=useMemo(()=>Object.fromEntries(Object.keys(labels).map(s=>[s,orders.filter(o=>o.status===s).length])),[orders]);
  const pharmacy=pharmacies.find(p=>p.pharmacy_id===pharmacyId);

  return <main className="wrap">
    <div className="card">
      <h1>Pharmacy Workspace</h1>
      <p className="muted">Opérations pharmacie V19.8 · isolation stricte par pharmacie · autorisation serveur.</p>
      {pharmacies.length>1&&<label>Pharmacie<select value={pharmacyId} onChange={e=>setPharmacyId(e.target.value)}>{pharmacies.map(p=><option key={p.pharmacy_id} value={p.pharmacy_id}>{p.pharmacy_name} — {p.city}</option>)}</select></label>}
      {error&&<p className="error">{error}</p>}
    </div>

    <section className="grid" style={{marginTop:18}}>
      {Object.entries(labels).map(([key,label])=><div className="card" key={key}><strong>{label}</strong><div style={{fontSize:28,marginTop:6}}>{counts[key]||0}</div></div>)}
    </section>

    <section className="grid" style={{marginTop:18}}>
      <div className="card">
        <h2>Commandes</h2>
        {orders.length===0?<p className="muted">Aucune commande.</p>:orders.map(o=><article key={o.id} className="card" style={{marginTop:10}}>
          <strong>{o.id.slice(0,8)}…</strong>
          <p className="muted">Statut : {o.status}{o.prescription_id?` · Prescription ${o.prescription_id.slice(0,8)}…`:''}</p>
          {o.pickup_deadline&&<p className="muted">Retrait avant {new Date(o.pickup_deadline).toLocaleString('fr-FR')}</p>}
          <div style={{display:'flex',gap:8,flexWrap:'wrap'}}>{(next[o.status]||[]).map(s=><button className={s==='cancelled'||s==='rejected'?'btn danger':'btn'} key={s} onClick={()=>transition(o.id,s)}>{s}</button>)}</div>
        </article>)}
      </div>
      <div className="card">
        <h2>Inventaire</h2>
        <p className="muted">{inventory.length} références suivies.</p>
        {inventory.slice(0,50).map(i=><div key={i.id} style={{padding:'10px 0',borderBottom:'1px solid var(--line)'}}>
          <strong>{i.medication_id.slice(0,8)}…</strong><br/>
          <span className="muted">Qté {i.quantity_available} · seuil {i.reorder_threshold} · {i.availability_status}</span>
        </div>)}
      </div>
    </section>

    {(pharmacy?.role==='owner'||pharmacy?.role==='pharmacy_admin')&&<section className="card" style={{marginTop:18}}>
      <h2>Équipe pharmacie</h2>
      <p className="muted">Invitation, activation/suspension, rôle et retrait d'accès. Le serveur contrôle chaque action.</p>
      {staff.map(s=><div key={s.user_id} style={{padding:'12px 0',borderBottom:'1px solid var(--line)'}}>
        <strong>{s.full_name||s.email||s.user_id.slice(0,8)}</strong> <span className="muted">· {s.role} · {s.status}</span>
        {s.role!=='owner'&&<div style={{display:'flex',gap:8,flexWrap:'wrap',marginTop:8}}>
          <button className="btn" onClick={()=>staffAction(s.user_id,'status',s.status==='active'?'suspended':'active')}>{s.status==='active'?'Suspendre':'Activer'}</button>
          <button className="btn danger" onClick={()=>staffAction(s.user_id,'remove')}>Retirer l'accès</button>
        </div>}
      </div>)}
      <p style={{marginTop:12}}><a href="/pharmacy/staff">Gérer les invitations et rôles →</a></p>
    </section>
  </main>
}
