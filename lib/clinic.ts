import { createClient } from '@/lib/supabase/server'

export async function getMyClinics() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return []
  const { data } = await supabase.from('clinic_members').select('clinic_id, role, status, clinics(*)').eq('user_id', user.id).eq('status','active')
  return data ?? []
}

export async function getClinicContext(clinicId: string) {
  const supabase = await createClient()
  const { data: member } = await supabase.from('clinic_members').select('clinic_id, role, status').eq('clinic_id', clinicId).single()
  if (!member || member.status !== 'active') return null
  const [{ data: clinic }, { data: locations }, { data: team }] = await Promise.all([
    supabase.from('clinics').select('*').eq('id', clinicId).single(),
    supabase.from('clinic_locations').select('*').eq('clinic_id', clinicId).order('name'),
    supabase.from('clinic_team_directory').select('*').eq('clinic_id', clinicId).order('full_name')
  ])
  return { member, clinic, locations: locations ?? [], team: team ?? [] }
}
