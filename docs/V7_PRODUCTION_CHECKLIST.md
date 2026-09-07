# V7 production checklist
- [ ] Apply `schema_v7_notifications.sql` in Supabase.
- [ ] Configure `CRON_SECRET` in Vercel.
- [ ] Configure contracted email/SMS/WhatsApp providers.
- [ ] Test confirmation, cancellation, reschedule/status change and reminders.
- [ ] Verify idempotency under repeated cron calls.
- [ ] Verify provider failures do not expose secrets or medical data.
- [ ] Verify notification preferences are protected by RLS.
- [ ] Verify no provider credentials are committed.
- [ ] Confirm Vercel Cron availability/limits for the production plan.
