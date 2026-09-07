import { createHash } from 'node:crypto'
import { likelyDuplicate } from './dedup'
import { normalizeDoctor, RawDoctor, NormalizedDoctor } from './normalize'
import { assertImportPermitted, SourcePolicy } from './source-policy'

export type ImportDecision = { action: 'accepted'|'rejected'|'duplicate'; reason?: string; doctor?: NormalizedDoctor }
export function hashRecord(value: unknown) { return createHash('sha256').update(JSON.stringify(value)).digest('hex') }
export function validateRawDoctor(r: RawDoctor): string | null {
  if (!r.sourceRecordKey?.trim()) return 'MISSING_SOURCE_RECORD_KEY'
  if (!r.fullName?.trim() || r.fullName.trim().length < 2) return 'INVALID_NAME'
  if (r.fullName.length > 160) return 'NAME_TOO_LONG'
  if (r.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(r.email)) return 'INVALID_EMAIL'
  if (r.website && !/^https?:\/\//i.test(r.website)) return 'INVALID_WEBSITE'
  return null
}
export function decideRecord(r: RawDoctor, source: SourcePolicy, seen: NormalizedDoctor[] = []): ImportDecision {
  try { assertImportPermitted(source) } catch (e) { return { action:'rejected', reason:String(e) } }
  const error = validateRawDoctor(r); if (error) return { action:'rejected', reason:error }
  const doctor = normalizeDoctor(r)
  if (seen.some(x => likelyDuplicate(x, doctor))) return { action:'duplicate', reason:'LIKELY_DUPLICATE', doctor }
  return { action:'accepted', doctor }
}
