import { RawDoctor } from './normalize'

export function parseNdjson(text:string): RawDoctor[] {
  return text.split(/\r?\n/).map(x=>x.trim()).filter(Boolean).map((line,i)=>{
    let value: unknown
    try { value=JSON.parse(line) } catch { throw new Error(`INVALID_NDJSON_LINE:${i+1}`) }
    if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error(`INVALID_RECORD:${i+1}`)
    return value as RawDoctor
  })
}

export function parseJson(text:string): RawDoctor[] {
  let value: unknown
  try { value=JSON.parse(text) } catch { throw new Error('INVALID_JSON') }
  if (!Array.isArray(value)) throw new Error('JSON_MUST_BE_ARRAY')
  return value as RawDoctor[]
}

function splitCsvLine(line:string): string[] {
  const out:string[]=[]; let cur=''; let quoted=false
  for(let i=0;i<line.length;i++){const c=line[i]; if(c==='"'){if(quoted && line[i+1]==='"'){cur+='"';i++}else quoted=!quoted}else if(c===','&&!quoted){out.push(cur);cur=''}else cur+=c} out.push(cur); return out.map(x=>x.trim())
}
export function parseCsv(text:string): RawDoctor[] {
  const lines=text.replace(/^\uFEFF/,'').split(/\r?\n/).filter(x=>x.trim())
  if(!lines.length) return []
  const headers=splitCsvLine(lines[0]).map(x=>x.toLowerCase())
  return lines.slice(1).map((line,i)=>{const cols=splitCsvLine(line);const r:any={};headers.forEach((h,j)=>r[h]=cols[j]??''); if(!r.sourceRecordKey && r.source_record_key)r.sourceRecordKey=r.source_record_key; if(!r.fullName && r.full_name)r.fullName=r.full_name; if(!r.sourceProfileUrl && r.source_profile_url)r.sourceProfileUrl=r.source_profile_url; if(!r.fullName) throw new Error(`MISSING_FULL_NAME_ROW:${i+2}`); return r as RawDoctor})
}

export function parseImport(text:string, format:'json'|'ndjson'|'csv'):RawDoctor[]{
  if(format==='json')return parseJson(text); if(format==='ndjson')return parseNdjson(text); return parseCsv(text)
}
