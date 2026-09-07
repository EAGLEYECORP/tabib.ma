# Tabib.ma V17.1 — Compliance & Security Hardened Release

V17.1 is the hardened release candidate built on the full V17 application tree.

## Status

**STAGING READY / PRODUCTION NO-GO until external and regulatory gates are completed.**

## Run

```bash
npm install
npm run audit:static
npm run release:check
npm run typecheck
npm run build
npm test
```

A lockfile must be committed before using `npm ci` in production CI.

## Database migration order

1. `schema.sql`
2. `schema_v7_notifications.sql`
3. `schema_v8_payments.sql`
4. `schema_v9_teleconsultation.sql`
5. `schema_v10_clinics.sql`
6. `schema_v11_admin.sql`
7. `schema_v13_security.sql`
8. `schema_v14_scale.sql`
9. `schema_v17_1_hardening.sql`

## Compliance

See `compliance/` and `docs/V17_1_AUDIT_REPORT.md`.

The project does not claim CNDP approval, DGSSI qualification, medical authorization, or certification. Those require evidence outside the repository.
