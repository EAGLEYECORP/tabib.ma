# Tabib.ma V17.9 — Doctor/Clinic Operations

## Scope

V17.9 turns the verified directory into an operational appointment surface: recurring doctor availability, future booking constraints, patient/doctor cancellation, doctor confirmation, and agenda views.

## Security rules

- Only authenticated users can mutate operational data.
- A doctor can manage only their own availability through RLS.
- A patient or the assigned doctor can cancel an eligible appointment.
- Only the assigned doctor can confirm a requested appointment.
- Booking is future-only and capped at four hours per appointment.
- The database remains the final authority for slot availability and overlap prevention.
- Clinic/location/room references are validated against the doctor's clinic assignment.
- No patient medical content is placed in the operational UI or logs.

## Staging gate

Before production: apply the migration on a disposable staging database, run RLS/IDOR tests with patient/doctor/admin test identities, verify timezone behavior around DST and Morocco scheduling rules, exercise cancellation/confirmation races, and run a real Next.js build with the committed lockfile.
