import fs from 'node:fs';
import assert from 'node:assert/strict';

const root = new URL('..', import.meta.url).pathname;
const files = [
  'supabase/schema_v19_8_national_pharmacy_operations.sql',
  'docs/V19_8_NATIONAL_PHARMACY_OPERATIONS.md',
  'tests/pharmacy-operations-v19-8.spec.mjs',
  'app/pharmacy/page.tsx',
  'app/pharmacy/staff/page.tsx',
  'app/api/pharmacy/context/route.ts',
  'app/api/pharmacy/staff/route.ts',
  'app/api/pharmacy/staff/manage/route.ts',
  'app/api/pharmacy/staff/accept/route.ts',
  'app/api/pharmacy/inventory/route.ts',
  'app/api/pharmacy/orders/route.ts',
  'app/api/pharmacy/orders/update/route.ts'
];
for (const f of files) assert.ok(fs.existsSync(root + f), `missing ${f}`);
const schema=fs.readFileSync(root+'supabase/schema_v19_8_national_pharmacy_operations.sql','utf8');
for(const t of ['RLS','INVALID_TRANSITION','PRESCRIPTION_NOT_ACTIVE','pharmacy_staff_v19_8','pharmacy_audit_events_v19_8','pharmacy_order_idempotency_v19_8'])
  assert.ok(schema.toLowerCase().includes(t.toLowerCase()),`missing ${t}`);
console.log('V19.8 release check PASS');
