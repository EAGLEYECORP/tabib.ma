# Agenda V6

The availability engine is PostgreSQL-backed. A doctor has recurring weekly rules plus explicit blocks/absences. Candidate slots are generated in the doctor's timezone (default `Africa/Casablanca`), then existing `requested`/`confirmed` appointments and blocks are removed. The appointment table has a PostgreSQL exclusion constraint on `(doctor_id, time range)` as the final concurrency guard.

Production hardening still required: minimum lead time, maximum booking horizon, clinic rooms/resources, holidays, DST test matrix, cancellation policy, rescheduling rules and load/concurrency tests.
