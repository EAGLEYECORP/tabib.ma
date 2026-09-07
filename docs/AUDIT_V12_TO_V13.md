# V12 → V13 security audit

## Findings addressed
- **Role escalation risk:** V12 allowed a profile owner to update their own row; V13 adds a database trigger that rejects self role changes.
- **Appointment tampering:** V13 prevents direct changes to patient, doctor or appointment timing through generic UPDATE operations.
- **Verification tampering:** V13 prevents non-admin changes to doctor/clinic/pharmacy verification flags.
- **Document recipient overreach:** V13 restricts patient shares to doctor/pharmacy roles and limits expiry to 30 days.
- **File spoofing:** V13 checks file magic bytes in addition to MIME and size before storage.
- **Browser/API abuse:** V13 adds origin checks for state-changing browser API calls, security headers and a basic rate limiter.
- **Private-data caching:** API responses are marked `no-store` by middleware.
- **V10 directory defect:** the clinic team view is corrected to join `doctor_profiles.id` to the profile identity used by V10.
- **Anonymous access:** V13 explicitly revokes anonymous table privileges for highly sensitive tables.

## Not falsely marked complete
- Distributed production rate limiting/WAF.
- Malware scanning/quarantine activation.
- MFA enforcement for privileged users.
- Independent penetration test.
- DAST/SAST results from a production-like environment.
- Regulatory/legal certification.
- Provider-specific security validation.

These remain production gates and are documented separately.
