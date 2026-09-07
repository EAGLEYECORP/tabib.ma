# V17.1 Security Test Matrix

| Test | Patient | Doctor | Secretary | Clinic admin | Platform admin |
|---|---:|---:|---:|---:|---:|
| Read own profile | YES | YES | YES | YES | YES |
| Read another patient's profile | NO | NO unless explicit legal workflow | NO | NO | controlled |
| Read shared document | only own | only explicit share | NO by default | NO by default | controlled/audited |
| Change role | NO | NO | NO | NO | controlled |
| Change verification | NO | NO | NO | NO | controlled |
| Access another clinic | NO | NO | NO | only assigned tenant | controlled |
| Process notification queue | NO | NO | NO | NO | service worker only |
| Payment webhook | NO | NO | NO | NO | signed provider endpoint |
