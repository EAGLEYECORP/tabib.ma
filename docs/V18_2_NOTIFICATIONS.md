# V18.2 — Notifications & Communication Center

## Scope

V18.2 adds a patient-facing in-app notification center, explicit communication preference/consent records, and a server-side read operation.

### Surfaces

- `/notifications` — in-app notification center.
- `GET /api/notifications/inbox` — authenticated user's last 50 in-app notifications.
- `POST /api/notifications/read` — marks one notification read, only for its owner.
- `GET/PATCH /api/notifications/consents` — communication preference/consent records by channel and purpose.

## Security

- No notification endpoint accepts a recipient/user ID from the caller.
- Read marking is performed by a `security definer` RPC constrained by `auth.uid()`.
- Mutating browser requests require Same-Origin protection.
- JSON bodies are bounded.
- Responses are `no-store` where notification data is returned.
- Notification payloads must remain operational and must not contain diagnoses, document contents, secrets, tokens, or unnecessary health information.

## Consent / legal note

The consent table is an auditable record of communication choices. It does not assert that consent is the legal basis for every operational healthcare notification. The final legal basis, wording, retention, and channel rules must be validated for Morocco and the actual providers used.

## Provider boundary

V7 provider adapters remain responsible for email/SMS/WhatsApp delivery. V18.2 does not add provider credentials or claim a provider is production-ready.

## Production gate

Before production:

1. Apply migrations in a disposable Supabase staging project.
2. Test RLS and IDOR with multiple patient accounts.
3. Verify provider webhook/signature/idempotency behavior.
4. Validate notification templates and localization.
5. Perform accessibility/mobile QA.
6. Confirm retention, CNDP/privacy documentation, provider contracts and data-transfer posture.
7. Run failure/retry/load tests for the queue.
