# Tabib.ma V17 — Full Production Candidate

V17 is a consolidation release built from the complete V13 application tree. It preserves the V6–V13 application files and adds release/production controls without replacing the application with a prototype.

## Scope
- Agenda, booking, blocks and concurrency protection
- Patient documents, temporary sharing and audit trail
- Notifications and reminders
- Payments and signed webhook/idempotency foundation
- Teleconsultation room authorization
- Multi-tenant clinics, members, locations and rooms
- Platform administration and verification workflow
- PWA/mobile shell
- Security headers, validation, MIME/magic-byte checks, origin checks and rate limiting
- Scale indexes, readiness/health, CI and release gates

## Database order
1. `supabase/schema.sql`
2. `supabase/schema_v7_notifications.sql`
3. `supabase/schema_v8_payments.sql`
4. `supabase/schema_v9_teleconsultation.sql`
5. `supabase/schema_v10_clinics.sql`
6. `supabase/schema_v11_admin.sql`
7. `supabase/schema_v13_security.sql`
8. `supabase/schema_v14_scale.sql`

Apply migrations in a controlled Supabase environment and verify each step before proceeding.

## Mandatory production gates
Do not use real patient data until external legal/privacy review, provider contracts, malware scanning, backup/restore validation, penetration testing, DAST, load testing, privileged-user MFA and operational monitoring are complete.

No healthcare certification is claimed by this repository.
