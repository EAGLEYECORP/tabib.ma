import { NextRequest, NextResponse } from 'next/server';
import { createServerSupabaseClient } from '@/lib/supabase/server';
import { validateString } from '@/lib/validation';
export async function GET(req: NextRequest) {
 const u=new URL(req.url), city=validateString(u.searchParams.get('city')||'',100)||null, medicationId=validateString(u.searchParams.get('medicationId')||'',80)||null;
 const lr=u.searchParams.get('lat'), gr=u.searchParams.get('lng'), lat=lr===null?null:Number(lr), lng=gr===null?null:Number(gr);
 if((lat!==null&&(!Number.isFinite(lat)||lat<-90||lat>90))||(lng!==null&&(!Number.isFinite(lng)||lng<-180||lng>180)))return NextResponse.json({error:'INVALID_COORDINATES'},{status:400});
 const s=await createServerSupabaseClient(), {data,error}=await s.rpc('search_pharmacies_v19_7',{p_city:city,p_medication_id:medicationId,p_lat:lat,p_lng:lng,p_limit:50});
 if(error)return NextResponse.json({error:'PHARMACY_SEARCH_FAILED'},{status:500}); return NextResponse.json({results:data??[]},{headers:{'Cache-Control':'no-store'}});
}
