# TABIB.MA V17.3 — National Doctor Directory

V17.3 extends V17.2 with an auditable national professional-directory layer.

## Included
- source registry with permission gate
- normalization and deduplication primitives
- dry-run JSON import
- transactional-ish staged import run tracking
- source provenance
- doctor claim workflow
- platform-admin verification workflow
- admin directory dashboard
- audit trail
- directory tests and runbooks

## Important
The implementation does **not** blindly scrape the web. The CNOM source is intentionally disabled for automated import until the applicable permission/API/export and reuse conditions are confirmed. Morocco Open Data sources are allowed only where the individual resource licence supports the intended reuse.
