export type RawDoctor = { fullName: string; specialty?: string; city?: string; region?: string; address?: string; phone?: string; email?: string; website?: string; sourceRecordKey: string; sourceProfileUrl?: string }
export type NormalizedDoctor = RawDoctor & { normalizedName: string; normalizedSpecialty: string }

export function normalizeText(value = ''): string {
  return value.normalize('NFKD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim().replace(/\s+/g, ' ')
}
export function normalizeDoctor(raw: RawDoctor): NormalizedDoctor {
  return { ...raw, fullName: raw.fullName.trim().replace(/\s+/g,' '), specialty: raw.specialty?.trim() || undefined, city: raw.city?.trim() || undefined, normalizedName: normalizeText(raw.fullName), normalizedSpecialty: normalizeText(raw.specialty || '') }
}
