# Directory import runbook

1. Register the source in `directory_sources`.
2. Confirm license/terms and set `permitted_for_import=true` only when the intended reuse is authorized.
3. Convert the authorized export to the Tabib public schema.
4. Run `node scripts/directory-dry-run.mjs input.json`.
5. Review rejected/duplicate records.
6. On staging, POST to `/api/directory/import` with `mode=dry_run`.
7. Review the resulting summary.
8. Commit only on staging first.
9. Verify search quality and provenance.
10. Promote to production with an auditable import run.
11. For corrections/removals, preserve provenance and use verification/suspension/removal states rather than silently overwriting history.
