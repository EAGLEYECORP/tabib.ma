# TABIB.MA V19.8 — National Pharmacy Operations

## Scope lock

V19.8 is an incremental hardening/operations release on top of V19.7 Pharmacy Network.

Included:

- pharmacy workspace
- pharmacy staff roles and access lifecycle
- server-authoritative inventory
- exact fulfillment state machine
- server-side prescription validation before dispensing
- multi-tenant isolation and RLS
- pharmacy audit events
- operational notifications without unnecessary clinical content
- release/security checks

Explicitly excluded:

- national delivery
- advanced pharmacy payments
- marketplace
- insurance
- CNOM integration
- official Ministry integration
- external pharmacy APIs
- medical AI
- diagnosis
- therapeutic recommendations
- clinical automation
- regulatory certification

## Tenant model

`public.pharmacies` remains backward compatible with V19.7. V19.8 adds:

- `owner_user_id`
- `pharmacy_staff_v19_8`

A staff member belongs to a pharmacy through `pharmacy_staff_v19_8`. The active membership and role are checked by security-definer database functions. Client-supplied `pharmacy_id` is a selector only; it is never accepted as proof of authorization.

## Roles

| Role | Scope |
|---|---|
| owner | full pharmacy control |
| pharmacy_admin | operational management + staff |
| pharmacist | prescriptions, fulfillment, stock, dispensing |
| assistant | authorized operations, no dispensing privilege |

Role checks are performed in PostgreSQL RPCs. Frontend controls are not security boundaries.

## Inventory authority

Inventory writes go through `update_pharmacy_inventory_v19_8`.

The server/database controls:

- pharmacy membership
- medication existence
- quantity bounds
- reorder threshold
- availability status
- operational history
- audit events
- stock alerts

Direct authenticated INSERT/UPDATE/DELETE on inventory is revoked.

On dispensing, prescription item quantities are checked against the pharmacy inventory and stock is decremented atomically. Negative inventory is impossible through the V19.8 path.

## Fulfillment state machine

```text
requested
  └─> accepted
        └─> preparing
              └─> ready
                    └─> dispensed

requested  ──> rejected
requested  ──> cancelled
accepted   ──> cancelled
preparing  ──> cancelled
```

All transitions are checked server-side.

`ready -> cancelled` is intentionally not allowed by the V19.8 specification.

## Dispensing validation

Before `dispensed`, the server checks:

1. order belongs to an active pharmacy staff member
2. user has a dispensing-capable role
3. prescription exists
4. prescription is `issued`
5. prescription is not expired
6. prescription contains items
7. each medication exists in the prescription
8. requested quantity is available
9. stock can be decremented without becoming negative

A client cannot obtain dispensing by posting only:

```json
{"prescription_id":"...","status":"dispensed"}
```

The API only invokes the server-side transition function.

## Audit

`pharmacy_audit_events_v19_8` records:

- `actor_user_id`
- `pharmacy_id`
- `operation`
- `entity_type`
- `entity_id`
- `timestamp`
- `metadata`

The V19.8 audit stream intentionally avoids prescription text, dosage instructions and other unnecessary clinical payloads.

## Notifications

Operational notification events:

- `NEW_REQUEST`
- `ORDER_ACCEPTED`
- `ORDER_PREPARING`
- `ORDER_READY`
- `ORDER_REJECTED`
- `ORDER_CANCELLED`
- `STOCK_ALERT`

Notification messages are operational and deliberately avoid prescription/medication content.

## Idempotence

Order transitions accept an optional idempotency key. A repeated request with the same pharmacy + key returns the previously committed order instead of applying the transition again.

The UI generates a fresh key per user action.

## Security release checks

Run:

```bash
npm run v19.8:release-check
```

The check verifies the V19.8 schema, API paths, state machine, server authorization, RLS mutation restrictions and dispense validation.

## Migration

Apply:

```text
supabase/schema_v19_8_national_pharmacy_operations.sql
```

after the V19.7 migration.

No V19.7 table is dropped. The existing V19.7 pharmacy network remains available for backward compatibility.

## Definition of DONE

The V19.8 path is complete when:

`patient → prescription → pharmacy → authorized staff → prescription revalidation → preparation → ready → dispensing → audit`

works across multiple pharmacies with server-side authorization and tenant isolation, without breaking V19.7 behavior.

Production deployment still requires execution against the target Supabase project plus integration/security testing with real data policies and operational credentials.
