import { createClient } from '../../lib/supabase/server'

export default async function AdminPage(){
 const supabase=await createClient()
 const {data:{user}}=await supabase.auth.getUser()
 if(!user) return <main><h1>Administration Tabib</h1><p>Connexion requise.</p></main>
 const {data:profile}=await supabase.from('profiles').select('role,suspended_at').eq('id',user.id).single()
 if(profile?.role!=='platform_admin' || profile.suspended_at) return <main><h1>Accès refusé</h1><p>Cette zone est réservée à l'administration plateforme.</p></main>
 const {count:pending}=await supabase.from('professional_verifications').select('*',{count:'exact',head:true}).eq('status','pending')
 const {count:openCases}=await supabase.from('platform_cases').select('*',{count:'exact',head:true}).in('status',['open','in_progress'])
 return <main><h1>Tabib — Administration nationale</h1><div className="grid"><section><h2>Vérifications</h2><strong>{pending??0}</strong><p>Dossiers en attente</p></section><section><h2>Support / opérations</h2><strong>{openCases??0}</strong><p>Cas ouverts</p></section></div><p>Les actions sensibles doivent rester journalisées et soumises aux permissions serveur.</p></main>
}
