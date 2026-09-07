export type MatchInput = { name?: string; specialty?: string; city?: string; address?: string; clinicName?: string }
export function normalizeMatchInput(x: MatchInput) {
 const clean=(v?:string,n=160)=>v?.trim().replace(/\s+/g,' ').slice(0,n)||undefined;
 return {name:clean(x.name), specialty:clean(x.specialty,120), city:clean(x.city,80), address:clean(x.address,240), clinicName:clean(x.clinicName,160)};
}
export function matchScore(a:MatchInput,b:MatchInput) {
 const n=(x?:string)=> (x||'').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/[^a-z0-9]+/g,' ').trim();
 const sim=(x?:string,y?:string)=>{const A=n(x),B=n(y); if(!A||!B)return 0;if(A===B)return 1; const sa=new Set(A.split(' ')), sb=new Set(B.split(' ')); let i=0;sa.forEach(v=>{if(sb.has(v))i++});return i/Math.max(sa.size,sb.size)};
 return +(0.5*sim(a.name,b.name)+0.2*sim(a.specialty,b.specialty)+0.15*sim(a.city,b.city)+0.1*sim(a.address,b.address)+0.05*sim(a.clinicName,b.clinicName)).toFixed(4);
}
