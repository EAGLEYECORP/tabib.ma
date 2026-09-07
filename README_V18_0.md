# Tabib.ma V18.0 — Patient Booking Experience

Public journey: directory/profile → date → available slot → authenticated booking → confirmation.

Security boundaries:
- Public availability exposes only verified doctor identity and future slots.
- Availability is capped to one calendar day per request and 31 days server-side.
- Booking requires an authenticated patient and same-origin mutation.
- PostgreSQL remains authoritative for slot availability and overlap prevention.
- Appointment confirmation is readable only by the authenticated patient through RLS.
- No patient clinical data is placed in public responses.

Apply `supabase/schema_v18_0_booking.sql` after V17.9 migrations.

Production gate remains dependent on real Supabase staging, RLS/IDOR/concurrency tests, provider validation, and Moroccan legal/CNDP gates.
