import { NextResponse } from 'next/server'
import { createServerSupabaseClient } from '@/lib/supabase/server'
import { requireSameOrigin, validateJsonBody } from '@/lib/validation'
export async function POST(req:Request){
 const o=requireSameOrigin(req); if(!o.ok)return NextResponse.json({error:o.error},{status:o.status})
 const s=await createServerSupabaseClient(); const {data:{user}}=await s.auth.getUser(); if(!user)return NextResponse.json({error:'AUTH_REQUIRED'},{status:401})
 const {data:p}=await s.from('profiles').select('role').eq('id',user.id).single(); if(p?.role!=='platform_admin')return NextResponse.json({error:'FORBIDDEN'},{status:403})
 const b=await validateJsonBody(req,100_000); if(!b.ok)return NextResponse.json({error:b.error},{status:b.status}); const x=b.data as any
 const {data,error}=await s.rpc('review_directory_claim',{p_claim_id:String(x.claimId||''),p_decision:String(x.decision||''),p_reason_code:String(x.reasonCode||''),p_notes:x.notes?String(x.notes):null})
 if(error)return NextResponse.json({error:'REVIEW_REJECTED',detail:error.message},{status:400}); return NextResponse.json({ok:Boolean(data)})
}
