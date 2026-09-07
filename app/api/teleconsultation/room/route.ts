import { requireSameOrigin } from '@/lib/validation';
import { NextResponse } from 'next/server'
import { createTeleconsultationRoom } from '@/lib/teleconsultation'
export async function POST(req: Request) {
  requireSameOrigin(req);
  try { const { appointmentId } = await req.json(); if (!appointmentId) return NextResponse.json({error:'appointmentId required'},{status:400}); return NextResponse.json({room: await createTeleconsultationRoom(appointmentId)},{status:201}) }
  catch (e:any) { const code=e?.message==='UNAUTHORIZED'?401:e?.message==='FORBIDDEN'?403:400; return NextResponse.json({error:e?.message||'BAD_REQUEST'},{status:code}) }
}
