# Tabib.ma V8 — Payments

## Scope
- Currency: MAD only in V8 foundation.
- Payment intent is created server-side through `create_payment_intent`.
- Provider-specific operations are isolated in `lib/payments.ts`.
- Webhooks require HMAC verification and provider event idempotency.
- Refunds require an existing paid payment and a provider refund adapter.
- Payment secrets stay server-side.

## Production gate
Before real payments: complete PSP contract/onboarding, 3DS/SCA or local equivalent as applicable, reconciliation, refund policy, chargeback/dispute handling, webhook retry strategy, accounting/tax validation, fraud controls, PCI scope review, and end-to-end sandbox tests.
