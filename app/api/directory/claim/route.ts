import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { validateJsonBody, requireSameOrigin } from '@/lib/validation'
export async function POST(req: Request) {
  const origin = requireSameOrigin(req); if (!origin.ok) return NextResponse.json({error:origin.error},{status:origin.status})
  const supabase = await createClient(); const {data:{user}} = await supabase.auth.getUser(); if (!user) return NextResponse.json({error:'AUTH_REQUIRED'},{status:401})
  const body = await validateJsonBody(req); if (!body.ok) return NextResponse.json({error:body.error},{status:body.status})
  const doctorId = String((body.data as any)?.doctorId || ''); const evidenceType = String((body.data as any)?.evidenceType || 'account')
  if (!doctorId || !['account','professional_document','institutional_confirmation','other'].includes(evidenceType)) return NextResponse.json({error:'INVALID_INPUT'},{status:400})
  const {data,error} = await supabase.from('directory_claims').insert({doctor_id:doctorId,claimant_id:user.id,evidence_type:evidenceType}).select('id,status').single()
  if (error) return NextResponse.json({error:error.message},{status:400});
  await supabase.from('audit_logs').insert({actor_id:user.id,action:'directory.claim.create',entity_type:'directory_doctor',entity_id:doctorId,metadata:{evidence_type:evidenceType}})
  return NextResponse.json(data,{status:201})
}
