# V17.7 — National Directory Intelligence

Adds quality scoring, freshness/staleness detection, geospatial distance and quality-aware ranking.

## Production boundary
- Ranking is not medical advice and does not imply endorsement.
- `verified` remains a separate administrative state; quality score never upgrades verification.
- Coordinates must come from an authorized source or a permitted geocoding workflow.
- Stale records are flagged for review rather than silently deleted.

## SQL
Apply `supabase/schema_v17_7_intelligence.sql` after V17.6 migrations. Run quality refresh from a privileged operational job and review stale events before publication changes.
