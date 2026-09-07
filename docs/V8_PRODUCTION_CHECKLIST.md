# V8 Production Checklist

- [ ] Supabase V8 migration applied after V6/V7.
- [ ] Moroccan payment provider contracted and sandbox tested.
- [ ] `PAYMENT_PROVIDER_*` and `PAYMENT_WEBHOOK_SECRET` stored only in Vercel environment variables.
- [ ] Webhook signature verified against the provider's official specification.
- [ ] Event IDs are unique and duplicate deliveries are harmless.
- [ ] Refunds tested for full and partial cases.
- [ ] Appointment/payment state machine reviewed by product + finance.
- [ ] Reconciliation process and ledger exports validated.
- [ ] No card PAN/CVV or sensitive payment credentials stored in Tabib.
- [ ] Monitoring and alerting configured for payment failures.
