# V17 Release Candidate Gate

## Automated
- TypeScript no-emit
- production build
- Playwright smoke/security tests
- dependency audit (high+)
- secret-pattern scan
- migration filename/order check
- forbidden sensitive cache/log patterns scan

## Manual before production
- Supabase migrations executed on staging
- RLS tests for patient/doctor/clinic/admin isolation
- booking race/concurrency test
- document upload + quarantine + share + revoke test
- notification retry/idempotency test
- payment webhook signature + replay test
- teleconsultation authorization test
- restore a backup into an isolated environment
- load test against realistic synthetic data
- DAST + external penetration test
- privileged accounts protected with MFA
- real provider contracts and DPAs/legal review

A green CI pipeline is not a healthcare certification.
