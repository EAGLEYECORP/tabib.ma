import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { requireSameOrigin, validateJsonBody } from '@/lib/validation'
import { parseImport } from '@/lib/directory/import-formats'
import { sourceFileHash, summarize, validateBatch } from '@/lib/directory/ingestion'

export async function POST(req:Request){
 const origin=requireSameOrigin(req); if(!origin.ok)return NextResponse.json({error:origin.error},{status:origin.status})
 const s=await createClient(); const {data:{user}}=await s.auth.getUser(); if(!user)return NextResponse.json({error:'AUTH_REQUIRED'},{status:401})
 const {data:p}=await s.from('profiles').select('role').eq('id',user.id).single(); if(p?.role!=='platform_admin')return NextResponse.json({error:'FORBIDDEN'},{status:403})
 const body=await validateJsonBody(req, 6_000_000); if(!body.ok)return NextResponse.json({error:body.error},{status:body.status})
 const b=body.data as any; const sourceCode=String(b.sourceCode||''); const format=b.format as 'json'|'ndjson'|'csv'; const text=String(b.content||'')
 if(!['json','ndjson','csv'].includes(format))return NextResponse.json({error:'UNSUPPORTED_FORMAT'},{status:400})
 if(!sourceCode||!text)return NextResponse.json({error:'SOURCE_AND_CONTENT_REQUIRED'},{status:400})
 const {data:source}=await s.from('directory_sources').select('id,code,permitted_for_import').eq('code',sourceCode).single(); if(!source)return NextResponse.json({error:'UNKNOWN_SOURCE'},{status:400})
 if(!source.permitted_for_import)return NextResponse.json({error:'IMPORT_NOT_PERMITTED'},{status:403})
 try {const rows=parseImport(text,format); const results=validateBatch(rows); return NextResponse.json({dryRun:true,source:source.code,inputSha256:sourceFileHash(text),summary:summarize(results),sample:results.slice(0,200)})} catch(e){return NextResponse.json({error:String(e)},{status:400})}
}
