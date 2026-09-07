# Tabib.ma V18.3 — Doctor / Clinic Operational Notification Center

## Scope
In-app operational alerts for doctors and active clinic owners, clinic admins and secretaries.

Notifications deliberately contain only scheduling metadata: appointment id, status, start/end and location identifiers. They do not include patient names, reasons, diagnoses, documents or other clinical content.

## Events
- appointment created → doctor + active clinic staff
- appointment confirmed/cancelled → doctor + active clinic staff
- appointment rescheduled (slot/location/room change) → doctor + active clinic staff
- 24h reminder → doctor + active clinic staff (service-role scheduler)

## Authorization
`notification_queue` remains recipient-scoped through the existing V7 RLS policy. The operational inbox additionally filters `audience` server-side. Read operations use the existing owner-only RPC.

## Deployment
Apply `supabase/schema_v18_3_staff_notifications.sql` after V18.2. Run the reminder function from a trusted scheduler/service role; never expose it as an unauthenticated HTTP endpoint.

## Production gate
Still requires real Supabase staging tests for RLS/IDOR/concurrency, provider tests, backup/restore drill, load testing, DAST/pentest, and Morocco/CNDP legal gates.
