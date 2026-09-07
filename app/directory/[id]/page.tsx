import { createServerSupabaseClient } from '@/lib/supabase/server';
export default async function DirectoryProfile({params}:{params:Promise<{id:string}>}){
 const {id}=await params; const supabase=await createServerSupabaseClient();
 const {data}=await supabase.from('directory_doctors').select('id,full_name,specialty,city,region,verification_status,professional_address,website_url,public_phone,public_email,profile_claimed_by').eq('id',id).maybeSingle();
 if(!data)return <main style={{padding:40}}><h1>Profil introuvable</h1></main>;
 const {data:locs}=await supabase.from('directory_doctor_locations').select('location_name,address_line1,postal_code,city,region,latitude,longitude,verified').eq('doctor_id',id).eq('active',true);
 return <main style={{maxWidth:900,margin:'40px auto',padding:20}}><h1>Dr {data.full_name}</h1><p><a href={`/book?doctor=${encodeURIComponent(id)}`}>Prendre rendez-vous</a></p><p>{data.specialty||'Médecin'} · {data.city||'Maroc'}</p><p>Statut : <strong>{data.verification_status}</strong></p>{data.professional_address&&<p>{data.professional_address}</p>}<h2>Lieux d’exercice</h2>{(locs||[]).map((l:any)=><article key={l.location_name+l.address_line1} style={{padding:12,borderBottom:'1px solid #ddd'}}><strong>{l.location_name||'Cabinet'}</strong><div>{l.address_line1||''} {l.postal_code||''} · {l.city}</div></article>)}</main>
}
