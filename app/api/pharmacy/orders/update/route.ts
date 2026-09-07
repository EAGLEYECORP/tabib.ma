import { NextRequest, NextResponse } from 'next/server';
import { createServerSupabaseClient } from '@/lib/supabase/server';
import { requireSameOrigin, assertJsonBodySize } from '@/lib/validation';
export async function POST(req:NextRequest){
  requireSameOrigin(req);assertJsonBodySize(req,4096);
  const s=await createServerSupabaseClient(),{data:{user}}=await s.auth.getUser();
  if(!user)return NextResponse.json({error:'AUTH_REQUIRED'},{status:401});
  const b=await req.json().catch(()=>({}));
  if(typeof b.orderId!=='string'||!/^[0-9a-f-]{36}$/i.test(b.orderId)||typeof b.status!=='string')return NextResponse.json({error:'INVALID_INPUT'},{status:400});
  const key=typeof b.idempotencyKey==='string'?b.idempotencyKey:null;
  if(key!==null&& (key.length<16||key.length>128))return NextResponse.json({error:'INVALID_IDEMPOTENCY_KEY'},{status:400});
  const reason=b.reasonCode==null?null:String(b.reasonCode).slice(0,80);
  const {data,error}=await s.rpc('update_pharmacy_order_v19_8',{p_order_id:b.orderId,p_new_status:b.status,p_reason_code:reason,p_idempotency_key:key});
  if(error)return NextResponse.json({error:error.message},{status:400});
  return NextResponse.json({order:data});
}
