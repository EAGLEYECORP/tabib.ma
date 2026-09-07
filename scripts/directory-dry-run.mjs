import fs from 'node:fs'
import crypto from 'node:crypto'
const [,,file] = process.argv
if(!file){console.error('Usage: node scripts/directory-dry-run.mjs doctors.json');process.exit(2)}
const input=JSON.parse(fs.readFileSync(file,'utf8')); const rows=Array.isArray(input)?input:input.records
if(!Array.isArray(rows)) throw new Error('Expected JSON array or {records:[]}')
const norm=s=>String(s||'').normalize('NFKD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9]+/g,' ').trim().replace(/\s+/g,' ')
const seen=new Set(); let rejected=0,dup=0,accepted=0
for(const r of rows){const key=String(r.sourceRecordKey||'');if(!key||!r.fullName||String(r.fullName).trim().length<2){rejected++;continue}const k=[norm(r.fullName),norm(r.specialty),norm(r.city)].join('|');if(seen.has(k)){dup++;continue}seen.add(k);accepted++}
console.log(JSON.stringify({sha256:crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex'),recordsSeen:rows.length,accepted,rejected,duplicates:dup},null,2))
