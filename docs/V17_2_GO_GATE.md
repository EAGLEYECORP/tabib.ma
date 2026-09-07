# Tabib.ma V17.2 — Production GO Gate

## Status

**Technical GO candidate — conditional.**

This repository must never represent CNDP authorization, legal approval, medical authorization, HDS certification, pentest completion, or production provider approval as already obtained unless evidence is attached by the responsible organization.

## Executed in build environment

- Static security audit: PASS
- Release structure audit: PASS
- Dependency versions pinned: PASS
- Required compliance/security documents: PASS
- Secret-pattern scan: PASS
- Payment amount authorization hardened at database boundary: PASS
- TypeScript configuration/path contract corrected: PASS

## Cannot be truthfully completed here without the real environment

- npm dependency installation/build
- Playwright browser E2E
- real Supabase RLS attack tests
- backup/restore drill
- load test
- DAST
- independent penetration test
- production provider verification
- CNDP authorization/transfer authorization
- legal counsel sign-off

## Production activation gates

1. Configure production Supabase project and private storage.
2. Apply migrations in documented order.
3. Enable MFA for privileged accounts.
4. Replace in-process rate limiting with distributed/WAF controls.
5. Configure malware scanning/quarantine for uploaded medical files.
6. Validate every processor/subprocessor and data location.
7. Complete CNDP formalities applicable to health data and international transfers.
8. Obtain legal/medical validation for telemedicine workflows.
9. Run external pentest and remediate all High/Critical findings.
10. Run backup restore and disaster-recovery exercise.
11. Run E2E and load tests against staging.
12. Only then set the operational deployment status to GO.
