export type DirectorySearch = { query?: string; city?: string; specialty?: string; verifiedOnly?: boolean; limit?: number; offset?: number };
export function normalizeSearch(input: DirectorySearch): DirectorySearch {
  return { query: input.query?.trim().slice(0,120) || undefined, city: input.city?.trim().slice(0,80) || undefined, specialty: input.specialty?.trim().slice(0,120) || undefined, verifiedOnly: Boolean(input.verifiedOnly), limit: Math.min(Math.max(input.limit ?? 20,1),100), offset: Math.max(input.offset ?? 0,0) };
}
