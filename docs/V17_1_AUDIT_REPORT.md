# Tabib.ma V17.1 — Audit Report

Date: 2026-09-05
Scope: repository static review, security design review, data-protection/compliance readiness review, database migration review.

## Executive verdict

**STAGING GO / REAL-PATIENT PRODUCTION NO-GO.**

V17.1 hardens the V17 release candidate, but a repository audit cannot establish legal compliance, CNDP authorization, provider contractual compliance, or resistance to real-world attacks.

## Findings remediated in V17.1

| ID | Finding | Severity | Status |
|---|---|---:|---|
| V17.1-01 | Notification workers could race and dispatch the same queue item | High | Fixed with atomic `claim_due_notifications()` |
| V17.1-02 | Browser mutating APIs did not consistently require an Origin | High | Fixed on browser mutation routes |
| V17.1-03 | JSON body limit depended on Content-Length | Medium | Fixed with actual body-size check |
| V17.1-04 | Payment amount was client-supplied without server-side price validation when pricing rules exist | High | Fixed in V8 RPC |
| V17.1-05 | Production dependency versions used `latest` | High | Release gate now rejects `latest`; pin versions before production |
| V17.1-06 | Notification operational tables allowed anonymous grants | Medium | Revoked in V17.1 migration |

## Remaining technical blockers

1. Run `npm install` in a networked CI environment and commit a lockfile.
2. Run TypeScript/build/E2E against a real Supabase staging project.
3. Execute adversarial RLS/IDOR tests with patient, doctor, secretary, clinic admin and platform-admin identities.
4. Add distributed rate limiting/WAF for production; in-process middleware limiting is not a multi-instance security boundary.
5. Replace CSP `unsafe-eval` and minimize `unsafe-inline` after testing Next.js production output.
6. Integrate malware scanning before documents can move from `quarantined` to `available`.
7. Test backup restoration and disaster recovery.
8. Perform external penetration test and application security review.
9. Validate payment and teleconsultation providers contractually and technically.

## Legal/compliance blockers

See `compliance/MOROCCO_LEGAL_MATRIX.md`. In particular, health-data processing requires the appropriate CNDP formalities; international transfers must be assessed; telemedicine must follow the medical-law framework; legal texts in the repository are templates and require counsel validation.

## Evidence limitation

This audit was performed on the supplied repository files. No live production infrastructure, Supabase project, Vercel account, provider account, CNDP file, penetration-test evidence, or backup restore evidence was available. Therefore findings are readiness findings, not certifications.

## Dependency/toolchain review

The V17.1 package manifest is now exact-versioned rather than using `latest`. The selected versions were checked against the npm registry on 2026-09-05: Next 16.3.4, React 19.2.8, `@supabase/ssr` 0.12.6, `@supabase/supabase-js` 2.112.4, TypeScript 7.0.2, Playwright Test 1.62.1, `@types/react` 19.2.18 and `@types/react-dom` 19.2.7. citeturn2search3turn4search6turn1search1turn2search2turn3search8turn3search5turn3search0turn4search0

The environment used for this audit could not complete dependency installation within the available execution window, so `typecheck`, production build, browser E2E and `npm audit` are **not claimed as passed**. They remain CI gates.
