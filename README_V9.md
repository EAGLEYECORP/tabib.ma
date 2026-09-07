# Tabib.ma V9

V9 extends V8 with a provider-agnostic teleconsultation boundary.

Apply Supabase migrations in order: `schema.sql`, `schema_v7_notifications.sql`, `schema_v8_payments.sql`, `schema_v9_teleconsultation.sql`.

The included UI intentionally does not fake a production video provider. Configure a real provider server-side before production. No recordings are enabled by default.
