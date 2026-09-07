# Tabib.ma V12 — Mobile / PWA

V12 builds on V11 and adds a production-oriented Progressive Web App foundation: responsive mobile navigation, installable web app metadata, service-worker shell caching and offline fallback.

This is an original clean-room implementation, not Doctolib source code or branding. It is not a medical, legal, HDS or government security certification.

## Deployment
Use the same Supabase migrations from V6 through V11, then deploy the Next.js app to Vercel. No new database migration is required for the PWA shell.

## Important
The service worker does not cache `/api/*` routes. Do not cache private medical data, documents, payment data or authenticated API responses without a formal security review.
