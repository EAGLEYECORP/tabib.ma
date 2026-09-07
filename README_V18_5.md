# Tabib.ma V18.5 — Payments & Billing Experience

Continuation of V18.4.

## Scope
- Server-authorized appointment price before payment creation.
- Payment-provider boundary remains provider-agnostic.
- Idempotent payment intents and webhooks remain supported.
- Paid invoice creation is idempotent by payment.
- Refunds are restricted to platform-admin authorization and cannot exceed remaining refundable balance.
- Patient-facing payment/invoice history is isolated by Supabase RLS.

## Migration
Apply `supabase/schema_v18_5_billing.sql` after the existing V8/V17.2 payment migrations.

## Production gates
A real PSP contract/configuration, staging payment flows, webhook signature tests, replay tests, refund reconciliation, accounting review, RLS/IDOR tests and legal/compliance review are still required before production.
