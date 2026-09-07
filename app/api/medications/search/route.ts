import { NextRequest, NextResponse } from 'next/server';
import { createServerSupabaseClient } from '@/lib/supabase/server';
import { validateString } from '@/lib/validation';
export async function GET(req: NextRequest) {
 const q=validateString(new URL(req.url).searchParams.get('q')||'',100);
 if(q.length<2) return NextResponse.json({results:[]},{headers:{'Cache-Control':'no-store'}});
 const supabase=await createServerSupabaseClient();
 const {data,error}=await supabase.from('medication_catalog').select('id,name,active_ingredient,strength,pharmaceutical_form,pack_description,manufacturer,pph_mad,hospital_price_mad,effective_from,effective_to,source_reference').ilike('name',`%${q}%`).limit(25);
 if(error) return NextResponse.json({error:'SEARCH_FAILED'},{status:500,headers:{'Cache-Control':'no-store'}});
 return NextResponse.json({results:data??[]},{headers:{'Cache-Control':'no-store'}});
}
