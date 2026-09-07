# Production Rate Limiting

The middleware rate limiter is process-local and is defense-in-depth only. It must not be treated as the production abuse-control boundary on a multi-instance deployment.

Production requirements:
- enforce rate limits at the CDN/WAF/edge layer using a trusted client-IP signal;
- rate-limit authentication, document upload, appointment creation, payment, teleconsultation-room creation and webhook endpoints more strictly;
- alert on credential stuffing and anomalous access;
- never use an untrusted `x-forwarded-for` value as a sole identity signal without a trusted proxy configuration.
