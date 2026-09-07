# V17.8 — Claim & Verification Center

## Workflow
1. Public directory profile exists from an authorized source or direct submission.
2. Authenticated claimant submits a claim with an opaque evidence reference.
3. Platform admin reviews the claim.
4. Approved claim moves `source_verified` → `claimed` where applicable.
5. A separate verification action may move `claimed` → `verified`.

## Security rules
- No patient information is part of this workflow.
- Evidence contents are not stored in `directory_claims`; only an opaque reference and optional SHA-256 fingerprint are stored.
- Never accept a URL as proof by itself.
- Never mark a doctor verified solely because a profile was claimed.
- Review decisions are immutable audit records.
- Administrative actions require platform-admin authorization and same-origin protection.

## Production gate
The evidence storage/provider, professional-document validation procedure, identity checks, retention period, and Moroccan legal/CNDP requirements must be defined before production use with real professional documents.
