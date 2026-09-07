# Tabib.ma V12 — Mobile / PWA

## Scope
V12 adds a Progressive Web App foundation for patient/doctor mobile use: responsive UI, installable manifest, service worker shell/offline fallback, mobile navigation and an install prompt.

## Security boundary
The service worker intentionally does **not** cache `/api/*` responses. Authentication, documents, appointments, payments and other private data remain network-only. Do not add private API responses to the cache without a reviewed threat model.

## Push notifications
V12 prepares the client shell only. Web Push requires a real push provider/browser subscription flow and VAPID keys before production. Existing V7 notification adapters remain the server-side delivery boundary.

## Native apps
A PWA is the first mobile delivery layer. Native Android/iOS applications can later consume the same authenticated APIs if required.

## Acceptance checklist
- [ ] Install on Android Chrome
- [ ] Install on iOS Safari
- [ ] Test offline public shell
- [ ] Verify no private API response is cached
- [ ] Verify login/session after offline/online transitions
- [ ] Test safe-area and small-screen layouts
- [ ] Run Lighthouse/PWA audit
- [ ] Add real Web Push provider before enabling push in production
