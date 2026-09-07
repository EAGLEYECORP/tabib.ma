import { NextRequest, NextResponse } from 'next/server';
import { createServerSupabaseClient } from '@/lib/supabase/server';
import { requireSameOrigin, assertJsonBodySize } from '@/lib/validation';
const uuid=(v:unknown)=>typeof v==='string'&&/^[0-9a-f-]{36}$/i.test(v);

export async function GET(req:NextRequest){
  const s=await createServerSupabaseClient(),{data:{user}}=await s.auth.getUser();
  if(!user)return NextResponse.json({error:'AUTH_REQUIRED'},{status:401});
  const pharmacyId=new URL(req.url).searchParams.get('pharmacyId');
  if(!uuid(pharmacyId))return NextResponse.json({error:'INVALID_PHARMACY_ID'},{status:400});
  const {data:membership}=await s.rpc('is_active_pharmacy_staff_v19_8',{p_pharmacy_id:pharmacyId,p_user_id:user.id});
  if(!membership)return NextResponse.json({error:'FORBIDDEN'},{status:403});
  const {data:role}=await s.rpc('pharmacy_staff_role_v19_8',{p_pharmacy_id:pharmacyId,p_user_id:user.id});
  const columns=(role==='assistant')
    ? 'id,pharmacy_id,status,requested_at,accepted_at,ready_at,dispensed_at,cancelled_at,pickup_deadline,rejection_reason_code,created_at'
    : 'id,prescription_id,pharmacy_id,status,requested_at,accepted_at,ready_at,dispensed_at,cancelled_at,pickup_deadline,rejection_reason_code,created_at';
  const {data,error}=await s.from('pharmacy_orders_v19_6').select(columns).eq('pharmacy_id',pharmacyId).order('created_at',{ascending:false}).limit(100);
  if(error)return NextResponse.json({error:'ORDERS_FAILED'},{status:500});
  return NextResponse.json({orders:data??[]},{headers:{'Cache-Control':'no-store'}});
}
export async function POST(req:NextRequest){
  requireSameOrigin(req);assertJsonBodySize(req,4096);
  const s=await createServerSupabaseClient(),{data:{user}}=await s.auth.getUser();
  if(!user)return NextResponse.json({error:'AUTH_REQUIRED'},{status:401});
  const b=await req.json().catch(()=>({}));
  if(!uuid(b.prescriptionId)||!uuid(b.pharmacyId))return NextResponse.json({error:'INVALID_INPUT'},{status:400});
  const {data,error}=await s.rpc('request_pharmacy_order_v19_8',{p_prescription_id:b.prescriptionId,p_pharmacy_id:b.pharmacyId});
  if(error)return NextResponse.json({error:error.message},{status:400});
  return NextResponse.json({order:data},{status:201});
}
