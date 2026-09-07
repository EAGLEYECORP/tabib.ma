import { createHash } from 'node:crypto'
import { RawDoctor } from './normalize'
import { normalizeDoctor } from './normalize'
import { likelyDuplicate } from './dedup'

export type IngestionAction = 'new'|'update_candidate'|'duplicate'|'rejected'
export type IngestionResult = { index:number; sourceRecordKey?:string; action:IngestionAction; reason?:string; hash:string; doctor?:ReturnType<typeof normalizeDoctor> }

export function stableJson(value: unknown): string {
  if (value === null || typeof value !== 'object') return JSON.stringify(value)
  if (Array.isArray(value)) return '[' + value.map(stableJson).join(',') + ']'
  const obj = value as Record<string, unknown>
  return '{' + Object.keys(obj).sort().map(k => JSON.stringify(k)+':'+stableJson(obj[k])).join(',') + '}'
}
export function recordHash(value: unknown) { return createHash('sha256').update(stableJson(value)).digest('hex') }
export function sourceFileHash(content: string|Buffer) { return createHash('sha256').update(content).digest('hex') }

export function validateBatch(rows: RawDoctor[], maxRecords=100_000): IngestionResult[] {
  if (rows.length > maxRecords) throw new Error(`BATCH_TOO_LARGE:${maxRecords}`)
  const seen: ReturnType<typeof normalizeDoctor>[] = []
  return rows.map((raw,index) => {
    const hash = recordHash(raw)
    if (!raw.sourceRecordKey?.trim()) return {index, action:'rejected', reason:'MISSING_SOURCE_RECORD_KEY', hash}
    if (!raw.fullName?.trim() || raw.fullName.trim().length < 2 || raw.fullName.length > 160) return {index, sourceRecordKey:raw.sourceRecordKey, action:'rejected', reason:'INVALID_NAME', hash}
    const doctor = normalizeDoctor(raw)
    if (seen.some(x => likelyDuplicate(x, doctor))) return {index, sourceRecordKey:raw.sourceRecordKey, action:'duplicate', reason:'DUPLICATE_WITHIN_BATCH', hash, doctor}
    seen.push(doctor)
    return {index, sourceRecordKey:raw.sourceRecordKey, action:'new', hash, doctor}
  })
}

export function summarize(results: IngestionResult[]) {
  return results.reduce((a,r)=>{a.seen++; a[r.action]++; return a},{seen:0,new:0,update_candidate:0,duplicate:0,rejected:0})
}
