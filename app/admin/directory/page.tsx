import { createClient } from '@/lib/supabase/server'
export default async function DirectoryAdmin(){
 const s=await createClient(); const {data:{user}}=await s.auth.getUser(); if(!user)return <main><h1>Annuaire national</h1><p>Connexion requise.</p></main>
 const {data:p}=await s.from('profiles').select('role').eq('id',user.id).single(); if(p?.role!=='platform_admin')return <main><h1>Accès refusé</h1></main>
 const {count}=await s.from('directory_doctors').select('*',{count:'exact',head:true}); const {data:statuses}=await s.from('directory_doctors').select('verification_status');
 const counts=(statuses||[]).reduce((a:any,x:any)=>(a[x.verification_status]=(a[x.verification_status]||0)+1,a),{})
 return <main><h1>Tabib — Annuaire national des médecins</h1><p>{count??0} profils importés.</p><div className="grid">{Object.entries(counts).map(([k,v])=><section key={k}><h2>{k}</h2><strong>{String(v)}</strong></section>)}</div><section><h2>Garde-fous</h2><ul><li>Sources autorisées uniquement.</li><li>Aucun contournement de CAPTCHA, authentification ou anti-bot.</li><li>Données professionnelles publiques seulement.</li><li>Chaque import est traçable et peut être audité.</li></ul></section></main>
}
