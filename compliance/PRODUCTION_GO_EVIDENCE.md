# Production GO Evidence Register

Use this file as the evidence index for the final production decision.

| Gate | Evidence | Status |
|---|---|---|
| Repository integrity | V17.2 release archive + SHA256 | READY |
| Static security | `scripts/audit-static.mjs` | PASS |
| Release structure | `scripts/release-check.mjs` | PASS |
| Dependency install | CI log | PENDING ENV |
| Typecheck | CI log | PENDING ENV |
| Build | Vercel/CI log | PENDING ENV |
| E2E | Playwright report | PENDING ENV |
| RLS adversarial tests | Supabase staging report | PENDING ENV |
| Pentest | Independent report | PENDING EXTERNAL |
| CNDP health-data formalities | CNDP evidence | PENDING EXTERNAL |
| International transfers | CNDP/provider evidence | PENDING EXTERNAL |
| Telemedicine legal review | Counsel/medical governance | PENDING EXTERNAL |
| Backup restore | Drill report | PENDING ENV |
| Provider contracts | Signed contracts/DPA | PENDING BUSINESS |
