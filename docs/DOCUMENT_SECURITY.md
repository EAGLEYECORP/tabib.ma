# Document security V6

- Bucket `patient-documents` is private.
- Files are limited to PDF/JPEG/PNG/WebP and 25 MB.
- Storage path starts with the authenticated owner's UUID.
- Metadata starts in `quarantined` state.
- A document cannot be shared or signed until it is `available`.
- Access is authorized server-side and results in a 120-second signed URL.
- Shares have explicit recipient, purpose, expiry and revocation.
- Access events are recorded without storing medical content in logs.
- The service-role key is server-only.

Before production with real health data, connect an actual malware-scanning/quarantine workflow and define retention, deletion, incident response, DPA/privacy and regulatory controls.
