# V17 File Integrity

This release intentionally includes the complete application tree inherited from V13 rather than a minimal replacement. `MANIFEST.sha256` is generated at packaging time and excludes `.git`, `node_modules`, build output and the archive itself.

Use `sha256sum -c MANIFEST.sha256` from the repository root to verify tracked release files.
