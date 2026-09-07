# V7 — Notifications & Communication

## Architecture
Supabase queues notification jobs. PostgreSQL triggers create idempotent jobs when appointments are created or their status changes. Vercel Cron calls `/api/notifications/process` every 5 minutes. The server dispatches `in_app` directly or calls a configured provider adapter endpoint for email/SMS/WhatsApp.

Provider endpoints are intentionally generic. The expected POST payload is:
```json
{"to":"destination","template":"appointment.reminder_24h","data":{},"idempotency_key":"..."}
```
A provider may return `{ "id": "provider-message-id" }`.

## Required production setup
1. Apply `supabase/schema_v7_notifications.sql` after the V6 schema.
2. Configure `CRON_SECRET` in Vercel.
3. Configure only the contracted provider endpoints and credentials.
4. Do not place provider secrets in GitHub source code.
5. Verify provider webhook/status integration if delivery receipts are required.

## Semantics
- `notification_queue.idempotency_key` prevents duplicate jobs.
- `scheduled_at` controls reminders.
- Failed deliveries are recorded; a later retry strategy/worker can be added without changing the public API.
- Notification payloads contain appointment metadata only; do not put diagnoses, prescriptions or document contents into notification payloads.
- WhatsApp/SMS/email are opt-in/configurable by the user and remain disabled until the corresponding provider is configured.

## Cron note
Vercel Cron support and plan limits should be checked against the production Vercel plan before launch. The endpoint is protected by `CRON_SECRET`.
