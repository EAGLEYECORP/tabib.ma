import { normalizeText, NormalizedDoctor } from './normalize'
export function canonicalKey(d: Pick<NormalizedDoctor,'normalizedName'|'normalizedSpecialty'|'city'>) {
  return [d.normalizedName, d.normalizedSpecialty, normalizeText(d.city || '')].join('|')
}
export function likelyDuplicate(a: NormalizedDoctor, b: NormalizedDoctor): boolean {
  if (a.normalizedName !== b.normalizedName) return false
  const sameCity = !!a.city && !!b.city && normalizeText(a.city) === normalizeText(b.city)
  const sameSpecialty = !!a.specialty && !!b.specialty && a.normalizedSpecialty === b.normalizedSpecialty
  return sameCity || sameSpecialty || (!a.city && !b.city)
}
