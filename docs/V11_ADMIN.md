# V11 Administration

## Controls
- platform_admin is never self-assigned from public registration.
- Verification decisions require platform-admin authorization.
- Suspension is an operational control and must be logged.
- Support/payment/security cases contain operational metadata only; do not put medical content into case descriptions.
- Production should add MFA, dual-control for high-risk actions, immutable audit export, alerting and incident procedures.

## Rollout
1. Apply prior migrations in order.
2. Apply `schema_v11_admin.sql`.
3. Create platform admin accounts through a controlled server-side process.
4. Test RLS with patient, doctor, clinic admin, pharmacy and platform admin identities.
5. Verify no admin service key reaches browser bundles.
