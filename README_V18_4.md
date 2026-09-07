# Tabib.ma V18.4 — Day-of-Appointment Care Flow

V18.4 adds a non-clinical operational lifecycle for appointments:
`confirmed -> checked_in -> in_consultation -> completed`, plus `no_show` from active operational states.

## Security
- Server-side authenticated RPC and role checks.
- Doctor or authorized clinic staff can transition appointments.
- Invalid transitions are rejected transactionally.
- Audit log records the transition.
- UI does not expose patient medical notes or clinical content.

## Apply migration
Run `supabase/schema_v18_4_care_flow.sql` after the previous migrations.

## Route
`POST /api/appointments/transition` with `{ appointment_id, target }`.

## Staging gate
This release is staging-ready only. Validate RLS, clinic-member authorization, concurrency, notification side effects, backups/restore, DAST and independent security testing against real Supabase infrastructure before production.
