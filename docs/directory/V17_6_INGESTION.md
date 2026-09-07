# Tabib.ma V17.6 — National Ingestion Engine

## Purpose
Controlled ingestion of professional directory data from **authorized/licensed inputs**. The engine supports JSON, NDJSON and CSV. It is deliberately not a general web scraper.

## Pipeline
`authorized source -> immutable input hash -> parser -> validation -> normalization -> intra-batch dedup -> dry-run -> admin commit -> mutation log -> publish`

Rollback uses the mutation log and is restricted to platform admins.

## Source policy
A source must have `permitted_for_import=true` in `directory_sources`. CNOM public pages remain a reference source until reuse/technical access conditions are explicitly confirmed. The official CNOM site states that the Order groups doctors practicing in Morocco; its digital platform also provides authenticated services for registered doctors. Do not automate access to authenticated areas or bypass CAPTCHA/anti-bot controls.

The Morocco Open Data portal currently lists 18 health datasets. Individual dataset/resource licences must be checked before reuse; some health datasets are complementary rather than a physician registry.

## Supported inputs
- JSON array of doctor records
- NDJSON, one doctor record per line
- CSV with headers such as `sourceRecordKey,fullName,specialty,city,region,address,phone,email,website,sourceProfileUrl`

## Operational controls
- 100,000 records per batch
- 6 MB API preview body limit
- SHA-256 input fingerprint
- deterministic JSON hashing
- dry-run before commit
- per-record import audit
- mutation snapshots for rollback
- no patient data
- no credential/CIN collection in directory imports
- no remote fetching in the local preflight script

## Production gates
Before a national import: verify source licence/permission, retention and publication basis, CNDP/legal assessment where applicable, test on a staging project, review a sample, execute dry-run, obtain two-person admin approval, then commit and retain the manifest/hash.
