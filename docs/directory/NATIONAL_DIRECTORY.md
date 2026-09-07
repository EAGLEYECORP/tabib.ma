# V17.3 — National doctor directory

## Objective
Create a scalable, auditable professional directory without blind scraping. The CNOM states that it brings together doctors practicing in Morocco across public/private sectors, making it the institutional reference to engage for authoritative registry access. The public CNOM website also exposes a digital physician-services platform.

## Source hierarchy
1. **CNOM / official institutional feed or export**, if CNOM authorizes and provides it.
2. **Morocco Open Data**, where the individual dataset/resource license permits the intended reuse. The health catalogue currently contains 18 datasets; it is complementary and does not by itself establish a complete national doctor registry.
3. **Doctor self-claim** and direct professional confirmation.

## Non-negotiable ingestion rules
- Public/professional fields only.
- Respect robots.txt, terms, licenses and rate limits where applicable.
- Never bypass CAPTCHA, authentication, paywalls, anti-bot controls or technical access restrictions.
- Store source, source record key, observation timestamp and provenance.
- Keep source verification separate from identity verification.
- Never infer that a profile is "CNOM verified" merely because it came from a third-party directory.

## Production path
`authorized source -> dry run -> normalization -> deduplication -> commit -> source_verified -> doctor claim -> human/admin verification -> verified`

## Current limitation
`cnom_public` is deliberately marked `permitted_for_import=false`. Before enabling automated CNOM ingestion, obtain the applicable permission/export/API and record the terms in `directory_sources`.
