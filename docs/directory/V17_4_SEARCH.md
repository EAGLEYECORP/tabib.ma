# V17.4 — National Search

Adds a public-search layer over the V17.3 directory using PostgreSQL trigram indexes and a security-definer RPC with bounded parameters.

## Deployment
1. Apply `supabase/schema_v17_4_search.sql` after the V17.3 migrations.
2. Verify RLS and function grants in staging.
3. Load only permitted/attributed professional directory records.
4. Run `npm run build` and Playwright in CI with installed dependencies.

## Data boundary
This module is for professional directory metadata only. Do not expose patient data, private identifiers, credentials, or sensitive clinical information. Source provenance and verification state must remain auditable.
