# Production security gate

## Must pass before real medical data
1. Independent penetration test.
2. RLS tests for every sensitive table.
3. Cross-tenant authorization tests.
4. IDOR tests for appointments, documents, shares, payments and teleconsultation rooms.
5. Secret scanning clean.
6. Dependency audit clean or exceptions documented.
7. SAST + DAST results reviewed.
8. Distributed rate limiting/WAF enabled.
9. MFA enforced for privileged roles.
10. Document antivirus/quarantine pipeline active.
11. Backups + restore test completed.
12. Monitoring/alerting and incident runbook approved.
13. Privacy/legal review completed.
