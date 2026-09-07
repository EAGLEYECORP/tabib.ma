# V13 Security hardening

V13 hardens the application but is **not a certification**. Before real health data: perform an independent penetration test, legal/privacy review, provider security review and production threat-model sign-off.

## Implemented
- Security headers and HSTS in production.
- API response `no-store` to reduce accidental caching of private data.
- Request IDs without medical/user data.
- Basic per-IP/per-route rate limiting as a development safety net.
- Strict server-only service-role usage.
- Database trigger preventing self-service role escalation.
- Document-share recipient validation (doctor/pharmacy only).
- Revocation and expiry checks remain server-side.
- Audit metadata is sanitized by policy: never store secrets, tokens, document contents, diagnoses or free-form medical notes.
- Payment webhook replay/idempotency protection remains database-backed.

## Production requirements
The middleware rate limiter is process-local and is **not sufficient for multi-instance production**. Replace it with an external distributed limiter (e.g. provider-native/WAF/Redis/KV) and add bot/abuse controls.

Run SAST, dependency audit, secret scanning, DAST and an independent penetration test against staging. Configure CSP for the exact production providers before enforcing a stricter nonce-based policy.
