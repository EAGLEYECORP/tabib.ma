# Tabib.ma V17.6 — National Ingestion Engine

V17.6 extends V17.5 with a controlled ingestion pipeline for authorized professional-directory datasets.

### Added
- deterministic input SHA-256 manifests
- JSON / NDJSON / CSV parser layer
- batch validation and duplicate detection
- dry-run preview API
- import mutation snapshots
- explicit admin rollback function
- ingestion preflight CLI
- V17.6 runbook and tests

### Safety boundary
No CAPTCHA bypass, authenticated scraping, anti-bot circumvention, or private/patient-data ingestion is implemented.

### Status
Technical staging candidate. A production national import still requires real source authorization/licensing, CNDP/legal validation where applicable, staging verification, backups/restore drill, and operational approval.
