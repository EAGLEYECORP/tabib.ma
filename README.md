# Tabib.ma — V8

Original clean-room implementation of a Moroccan appointment-platform foundation. It is **not Doctolib source code, branding or proprietary assets** and is not a certification of healthcare compliance.

## Stack
GitHub · Next.js · TypeScript · Vercel · Supabase Auth/Postgres/Storage.

## V7 delivered
- Everything from V6: doctor directory, recurring availability, blocks, slot generation, DB anti-double-booking, private documents and controlled sharing.
- Notification preferences for in-app, email, SMS and WhatsApp.
- Idempotent notification queue in PostgreSQL.
- Automatic appointment confirmation/status notifications.
- 24h and 2h reminder jobs.
- Vercel Cron worker endpoint.
- Provider-agnostic email/SMS/WhatsApp adapter boundary.
- Delivery logs and failure states.
- Notification center and preferences UI.
- RLS on notification data.

## Setup
```bash
npm install
cp .env.example .env.local
npm run dev
```
Apply `supabase/schema.sql`, then `supabase/schema_v7_notifications.sql`.

For real email/SMS/WhatsApp delivery, configure the provider endpoints and secrets in Vercel Environment Variables. No provider credentials are included in this repository.

See `docs/NOTIFICATIONS.md` and `docs/V7_PRODUCTION_CHECKLIST.md`.

## Important
This is production-oriented engineering scaffolding, not a claim of national healthcare certification. Real deployment requires security testing, privacy/legal validation, provider contracts, monitoring, backups, incident response and a malware-scanning pipeline for patient documents.


## V8 — Payments & billing
V8 adds MAD-denominated payment intents, provider adapters, signed webhook processing with idempotency, refunds, billing/invoice foundations, and a ledger model. No payment credentials or real provider are bundled. Configure a contracted Moroccan PSP through the V8 environment variables before enabling real money flows.

Apply `supabase/schema_v8_payments.sql` after the V6 and V7 SQL migrations. Never put healthcare data or payment secrets in source control.

## V11
National administration, verification, support/security/payment cases, suspension workflow and platform audit controls.


## V13
Security, privacy and compliance hardening is documented in `README_V13.md`, `docs/SECURITY_V13.md`, `docs/COMPLIANCE_V13.md` and `docs/PRODUCTION_SECURITY_V13.md`. V13 is not a regulatory or security certification.

## V17.1 status

V17.1 is the compliance/security hardening release. See `README_V17_1.md`, `docs/V17_1_AUDIT_REPORT.md`, `compliance/MOROCCO_LEGAL_MATRIX.md`, and `docs/PRODUCTION_GO_NO_GO_V17_1.md`.

## V17.2 — Technical GO hardening

V17.2 is the technical production-gate release. It adds a database-enforced active pricing rule for payment intents, strengthens TypeScript path/type contracts, and provides a production evidence register.

**Important:** technical GO is not a legal authorization. Real patient-data production remains blocked until the documented CNDP, provider, medical, security and infrastructure gates are evidenced.
