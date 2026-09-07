# V17 Production Runbook

## Deploy
1. Merge only a green PR.
2. Apply and verify Supabase migrations in staging.
3. Run synthetic end-to-end checks.
4. Promote the exact commit to production.
5. Verify `/api/health` and application login/booking flows.
6. Monitor errors, latency, database connections and notification queue.

## Rollback
- Roll back the application deployment to the previous known-good commit.
- Never blindly roll back database migrations. Use a forward-fix migration or restore a verified backup in an incident procedure.

## Incident rules
- Never put patient content, document names, tokens, payment secrets or provider credentials in logs.
- Revoke compromised credentials immediately.
- Preserve audit evidence while minimizing exposure.
- Follow applicable legal/security notification procedures.
