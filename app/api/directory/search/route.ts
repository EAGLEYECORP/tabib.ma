import { NextRequest, NextResponse } from 'next/server';
import { createServerSupabaseClient } from '@/lib/supabase/server';
import { normalizeSearch } from '@/lib/directory/search';

export async function GET(req: NextRequest) {
  const url = new URL(req.url);
  const s = normalizeSearch({ query:url.searchParams.get('q')||undefined, city:url.searchParams.get('city')||undefined, specialty:url.searchParams.get('specialty')||undefined, verifiedOnly:url.searchParams.get('verified')==='true', limit:Number(url.searchParams.get('limit')||20), offset:Number(url.searchParams.get('offset')||0) });
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc('search_public_doctors', { p_query:s.query||null, p_city:s.city||null, p_specialty:s.specialty||null, p_verified_only:s.verifiedOnly, p_limit:s.limit, p_offset:s.offset });
  if (error) return NextResponse.json({ error:'directory_search_failed' }, { status:500, headers:{'Cache-Control':'no-store'} });
  return NextResponse.json({ data:data||[], search:s }, { headers:{'Cache-Control':'no-store'} });
}
