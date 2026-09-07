export type SourcePolicy = { code: string; permittedForImport: boolean; robotsRequired: boolean; termsUrl?: string; license?: string }
export function assertImportPermitted(source: SourcePolicy) {
  if (!source.permittedForImport) throw new Error(`IMPORT_NOT_PERMITTED:${source.code}`)
}
export function assertPublicHttpUrl(url: string) {
  const u = new URL(url)
  if (!['https:','http:'].includes(u.protocol)) throw new Error('UNSAFE_SOURCE_URL')
  return u
}
