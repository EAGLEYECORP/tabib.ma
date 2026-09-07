import { NextResponse } from 'next/server';
import { createServerSupabaseClient } from '@/lib/supabase/server';
import { normalizeMatchInput, matchScore } from '@/lib/directory/matching';
export async function POST(req:Request){
 const supabase=await createServerSupabaseClient(); const {data:{user}}=await supabase.auth.getUser();
 if(!user)return NextResponse.json({error:'AUTH_REQUIRED'},{status:401});
 const {data:{is_admin}}=await supabase.rpc('is_platform_admin');
 if(!is_admin)return NextResponse.json({error:'ADMIN_REQUIRED'},{status:403});
 const body=await req.json().catch(()=>null); if(!body)return NextResponse.json({error:'INVALID_JSON'},{status:400});
 const a=normalizeMatchInput(body.left||{}), b=normalizeMatchInput(body.right||{}); const score=matchScore(a,b);
 return NextResponse.json({score,decision:score>=0.9?'high':score>=0.75?'review':'low',normalized:{left:a,right:b}});
}
