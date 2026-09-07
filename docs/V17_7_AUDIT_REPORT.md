# V17.7 Technical Audit

Scope: directory intelligence only.

- No patient data introduced.
- Quality score cannot change verification state.
- Stale detection creates review events; it does not auto-remove profiles.
- Geospatial ranking uses approximate Haversine distance.
- Public search remains limited to approved directory verification states.
- Static/unit checks included; full Next.js build requires installed dependencies and a configured staging Supabase project.

Status: technical staging candidate; external legal, source-licensing, security and operational gates remain mandatory.
