import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { validateJsonBody, requireSameOrigin } from '@/lib/validation'
export async function POST(req: Request) {
  const origin=requireSameOrigin(req); if(!origin.ok) return NextResponse.json({error:origin.error},{status:origin.status})
  const supabase=await createClient(); const {data:{user}}=await supabase.auth.getUser(); if(!user) return NextResponse.json({error:'AUTH_REQUIRED'},{status:401})
  const {data:me}=await supabase.from('profiles').select('role').eq('id',user.id).single(); if(me?.role!=='platform_admin') return NextResponse.json({error:'FORBIDDEN'},{status:403})
  const body=await validateJsonBody(req); if(!body.ok) return NextResponse.json({error:body.error},{status:body.status})
  const b=body.data as any; const doctorId=String(b.doctorId||''); const status=String(b.status||'verified')
  if(!doctorId || !['source_verified','verified','suspended','removed'].includes(status)) return NextResponse.json({error:'INVALID_INPUT'},{status:400})
  const patch:any={verification_status:status,updated_at:new Date().toISOString()}; if(status==='verified') patch.verified_at=new Date().toISOString(); if(status==='suspended') patch.suspended_at=new Date().toISOString(); if(status==='removed') patch.removed_at=new Date().toISOString()
  const {error}=await supabase.from('directory_doctors').update(patch).eq('id',doctorId); if(error) return NextResponse.json({error:error.message},{status:400})
  await supabase.from('audit_logs').insert({actor_id:user.id,action:'directory.doctor.verify',entity_type:'directory_doctor',entity_id:doctorId,metadata:{status}})
  return NextResponse.json({ok:true})
}
