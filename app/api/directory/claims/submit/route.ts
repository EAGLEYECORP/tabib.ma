import { NextResponse } from 'next/server'
import { createServerSupabaseClient } from '@/lib/supabase/server'
import { requireSameOrigin, validateJsonBody } from '@/lib/validation'
export async function POST(req:Request){
 const o=requireSameOrigin(req); if(!o.ok)return NextResponse.json({error:o.error},{status:o.status})
 const s=await createServerSupabaseClient(); const {data:{user}}=await s.auth.getUser(); if(!user)return NextResponse.json({error:'AUTH_REQUIRED'},{status:401})
 const b=await validateJsonBody(req,100_000); if(!b.ok)return NextResponse.json({error:b.error},{status:b.status})
 const x=b.data as any; const {data,error}=await s.rpc('submit_directory_claim',{p_doctor_id:String(x.doctorId||''),p_evidence_type:String(x.evidenceType||''),p_evidence_reference:String(x.evidenceReference||''),p_evidence_hash:x.evidenceHash?String(x.evidenceHash):null,p_claimant_role:String(x.claimantRole||'doctor')})
 if(error)return NextResponse.json({error:'CLAIM_REJECTED',detail:error.message},{status:400}); return NextResponse.json({ok:true,claimId:data})
}
