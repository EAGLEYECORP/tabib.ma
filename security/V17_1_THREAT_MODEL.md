# V17.1 Threat Model

## Assets
- patient identity and contact data
- health documents
- appointment data
- professional verification data
- payment records
- audit/security logs
- authentication sessions

## Threat actors
- unauthenticated internet attacker
- compromised patient account
- compromised professional account
- malicious clinic staff member
- malicious tenant administrator
- compromised provider/subprocessor
- insider with service-role access

## Highest-risk attack paths
1. IDOR against patient documents or appointments.
2. RLS bypass / cross-clinic data access.
3. Role escalation to platform admin.
4. Malicious document upload.
5. Payment amount manipulation or webhook replay.
6. Notification duplication or abuse.
7. Credential/session theft.
8. Provider compromise / international data exposure.

## Required verification
- RLS matrix tests for every sensitive table.
- IDOR tests for every object identifier.
- privilege-boundary tests for every role.
- upload parser/malware tests.
- webhook signature/replay tests.
- rate-limit and abuse tests.
- dependency/SCA + SAST + DAST.
- external penetration test.
