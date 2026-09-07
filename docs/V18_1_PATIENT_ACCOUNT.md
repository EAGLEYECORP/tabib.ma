# V18.1 — Patient Account & Appointment Center

Adds a patient-facing appointment center with secure cancellation and rescheduling.

## Security model
- Patients cannot mutate doctor, date, time, reason, clinic, location or room through generic appointment UPDATE.
- Patients may only cancel their own requested/confirmed appointments.
- Rescheduling is an authenticated RPC that verifies ownership, future time, availability and the database overlap constraint.
- Appointment data is private through existing RLS; public directory pages never expose patient identity or appointment details.
- Mutating HTTP routes enforce Same-Origin and bounded JSON payloads.

## Apply migration
Run `supabase/schema_v18_1_patient_account.sql` after the V18.0 booking migration.

## UX
- `/account/appointments`
- `/account/appointments/[id]/reschedule`
- `/account/appointments/[id]/cancel`

This release does not add patient medical history or diagnosis fields.
