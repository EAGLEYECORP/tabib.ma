# V19.7 — Pharmacy Network

## Scope
Adds a verified pharmacy network, public pharmacy discovery, medication availability visibility and a pharmacy fulfillment workspace.

## Security model
- Only `verified=true` and `accepting_orders=true` pharmacies are discoverable publicly.
- Pharmacy inventory is owner-scoped by RLS.
- Order transitions execute server-side through a `security definer` RPC and a strict transition matrix.
- Dispensing is refused when the linked prescription is no longer active.
- Rejection requires a reason code.
- Operational audit events are written for transitions.
- Patient/clinical text is never returned by the public pharmacy search.

## Important production gates
Real pharmacy licensing/verification, contractual onboarding, CNDP/privacy review, staging RLS/IDOR tests, concurrency tests, observability, backup/restore and independent security testing remain mandatory.
