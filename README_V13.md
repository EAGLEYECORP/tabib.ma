# Tabib.ma V13 — Security, Privacy & Compliance Hardening

V13 is a security hardening release built on the V12 repository. It does not claim medical, GDPR, HDS, ISO or Moroccan regulatory certification.

## Apply database migration
Run `supabase/schema.sql`, then V7, V8, V9, V10, V11 and finally `supabase/schema_v13_security.sql` in the intended migration order. For an existing environment, use your normal migration tooling and review changes before execution.

## CI/security
The repository includes TypeScript/build checks. Before production, enable GitHub secret scanning/push protection, Dependabot/dependency review and code scanning, then add DAST against staging.

## Rate limiting
A small in-process limiter protects development/staging. It is not a distributed production control. Use a WAF/provider-native or shared Redis/KV limiter before national production.

## Compliance
See `docs/COMPLIANCE_V13.md` and `docs/SECURITY_V13.md`. Independent security testing and legal/privacy validation remain mandatory.
