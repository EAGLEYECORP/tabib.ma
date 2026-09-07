import { createServerSupabaseClient } from './supabase/server'

export async function createTeleconsultationRoom(appointmentId: string) {
  const supabase = await createServerSupabaseClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('UNAUTHORIZED')
  const { data: appointment, error } = await supabase.from('appointments').select('id,patient_id,doctor_id,start_at,end_at,status').eq('id', appointmentId).single()
  if (error || !appointment) throw new Error('APPOINTMENT_NOT_FOUND')
  if (appointment.patient_id !== user.id && appointment.doctor_id !== user.id) throw new Error('FORBIDDEN')
  if (appointment.status !== 'confirmed') throw new Error('APPOINTMENT_NOT_CONFIRMED')
  const { data, error: upsertError } = await supabase.from('teleconsultation_rooms').upsert({ appointment_id: appointment.id, status: 'scheduled' }, { onConflict: 'appointment_id' }).select().single()
  if (upsertError) throw upsertError
  return data
}
