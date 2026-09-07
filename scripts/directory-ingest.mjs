#!/usr/bin/env node
// V17.6 local preflight parser. It never fetches remote sites and never bypasses access controls.
import fs from 'node:fs'
import crypto from 'node:crypto'
const [,,file,format='json']=process.argv
if(!file || !['json','ndjson','csv'].includes(format)){console.error('Usage: node scripts/directory-ingest.mjs <file> <json|ndjson|csv>');process.exit(2)}
const content=fs.readFileSync(file)
const hash=crypto.createHash('sha256').update(content).digest('hex')
let rows
if(format==='json') rows=JSON.parse(content.toString())
else if(format==='ndjson') rows=content.toString().split(/\r?\n/).filter(Boolean).map(JSON.parse)
else {const lines=content.toString().split(/\r?\n/).filter(Boolean); const h=lines.shift().split(',').map(x=>x.trim()); rows=lines.map(l=>{const c=l.split(','); return Object.fromEntries(h.map((k,i)=>[k,c[i]??'']))})}
if(!Array.isArray(rows)) throw new Error('Input must contain an array of records')
if(rows.length>100000) throw new Error('BATCH_TOO_LARGE:100000')
const bad=rows.filter(r=>!r.sourceRecordKey || !r.fullName || String(r.fullName).trim().length<2)
console.log(JSON.stringify({format,records:rows.length,rejected:bad.length,inputSha256:hash,firstErrors:bad.slice(0,20).map(r=>r.sourceRecordKey||null)},null,2))
