import fs from 'node:fs';
import assert from 'node:assert/strict';

const root = new URL('..', import.meta.url).pathname;
const schema = fs.readFileSync(root + 'supabase/schema_v19_8_national_pharmacy_operations.sql', 'utf8');
const page = fs.readFileSync(root + 'app/pharmacy/page.tsx', 'utf8');
const staff = fs.readFileSync(root + 'app/pharmacy/staff/page.tsx', 'utf8');
const inventoryApi = fs.readFileSync(root + 'app/api/pharmacy/inventory/route.ts', 'utf8');
const orderApi = fs.readFileSync(root + 'app/api/pharmacy/orders/update/route.ts', 'utf8');

const must = [
  'pharmacy_staff_v19_8','pharmacy_staff_invitations_v19_8',
  'pharmacy_inventory_v19_7','reorder_threshold',
  'pharmacy_inventory_events_v19_8','pharmacy_audit_events_v19_8',
  'pharmacy_operational_notifications_v19_8',
  'is_active_pharmacy_staff_v19_8','pharmacy_staff_role_v19_8',
  'invite_pharmacy_staff_v19_8','accept_pharmacy_staff_invitation_v19_8',
  'change_pharmacy_staff_role_v19_8','set_pharmacy_staff_status_v19_8',
  'remove_pharmacy_staff_access_v19_8','update_pharmacy_inventory_v19_8',
  'update_pharmacy_order_v19_8','request_pharmacy_order_v19_8',
  'INVALID_TRANSITION','PRESCRIPTION_NOT_ACTIVE','MEDICATION_NOT_AVAILABLE',
  'INSUFFICIENT_STOCK','REJECTION_REASON_REQUIRED','STAFF_SUSPENDED',
  'ORDER_ACCEPTED','ORDER_PREPARING','ORDER_READY','ORDER_DISPENSED',
  'ORDER_REJECTED','ORDER_CANCELLED','STOCK_ALERT',
  'pharmacy_order_idempotency_v19_8',
  "status in('requested','accepted','preparing','ready','dispensed','rejected','cancelled')"
];
for (const token of must) assert.ok(schema.includes(token), `missing: ${token}`);

for (const transition of [
  "('requested','accepted')","('accepted','preparing')","('preparing','ready')",
  "('ready','dispensed')","('requested','rejected')","('requested','cancelled')",
  "('accepted','cancelled')","('preparing','cancelled')"
]) assert.ok(schema.includes(transition), `transition missing: ${transition}`);

for (const forbidden of [
  "('ready','cancelled')","('preparing','dispensed')","('requested','ready')",
  "('accepted','dispensed')"
]) assert.ok(!schema.includes(forbidden), `illegal transition present: ${forbidden}`);

for (const token of [
  'pharmacyId','pharmacy_id','idempotencyKey','/api/pharmacy/staff','/api/pharmacy/orders/update',
  'requested','preparing','ready','dispensed','rejected','cancelled'
]) assert.ok(page.includes(token), `page missing: ${token}`);

for (const token of ['invite','pharmacy_admin','pharmacist','assistant','suspend','remove','role'])
  assert.ok(staff.toLowerCase().includes(token), `staff UI missing: ${token}`);

assert.match(inventoryApi, /update_pharmacy_inventory_v19_8/);
assert.match(orderApi, /update_pharmacy_order_v19_8/);
assert.match(orderApi, /idempotencyKey/);

// Client cannot directly mutate inventory or orders in V19.8.
assert.match(schema, /revoke insert,update,delete on public\.pharmacy_inventory_v19_7 from authenticated/);
assert.match(schema, /revoke insert,update,delete on public\.pharmacy_orders_v19_6 from authenticated/);

// Server derives authorization from active membership and role.
assert.match(schema, /is_active_pharmacy_staff_v19_8\(pharmacy_id/);
assert.match(schema, /can_dispense_pharmacy_order_v19_8\(o\.pharmacy_id,uid\)/);

// Dispense validation is performed in the DB function, not by a status-only API.
for (const token of ['status=\'issued\'','expires_at','prescription_items_v19_6','medication_id','quantity_available'])
  assert.ok(schema.includes(token), `dispense validation missing: ${token}`);

console.log('V19.8 National Pharmacy Operations static security test PASS');
