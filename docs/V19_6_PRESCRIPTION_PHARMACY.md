# V19.6 — Prescription & Pharmacy Fulfillment

## Scope
- Bind prescriptions to the national medication catalog.
- Separate clinical prescription content from pharmacy operational status.
- Server-side issuance and pharmacy status transitions.
- Patient-controlled pharmacy request.
- Audit trail for issuance and fulfillment events.

## Security invariants
- A patient can read only their own issued/dispensed/expired prescriptions.
- A doctor can manage only prescriptions they own.
- A pharmacy can read only its own orders.
- Prescription issuance requires at least one catalog item and an expiry within 365 days.
- Pharmacy transitions are a strict state machine; direct client status tampering is not the authority.
- Dosage instructions are stored as `*_ciphertext`; encryption/key management must be implemented with the production secret-management design before real clinical data.

## Important production gates
This feature does **not** by itself establish legal authorization to prescribe/dispense medicines, pharmacy integration, CNDP authorization, telemedicine authorization, or clinical compliance. Validate Moroccan legal/professional requirements, signing requirements, retention, data residency, and pharmacy workflows before production use.
