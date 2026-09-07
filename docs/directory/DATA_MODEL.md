# Data model

- `directory_doctors`: public professional profile.
- `directory_sources`: registry of allowed sources and their reuse status.
- `directory_doctor_sources`: provenance and source record identity.
- `directory_claims`: doctor claim workflow.
- `directory_import_runs`: immutable-ish operational history of imports.
- `directory_import_records`: per-record decision trail.

No patient records are stored in this module.
