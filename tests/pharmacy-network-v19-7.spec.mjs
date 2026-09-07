import fs from 'node:fs'; import assert from 'node:assert/strict';
const root=new URL('..',import.meta.url).pathname;
const schema=fs.readFileSync(root+'supabase/schema_v19_7_pharmacy_network.sql','utf8');
const page=fs.readFileSync(root+'app/pharmacy/page.tsx','utf8');
for(const token of ['pharmacy_inventory_v19_7','search_pharmacies_v19_7','update_pharmacy_order_v19_7','REJECTION_REASON_REQUIRED','PRESCRIPTION_NOT_ACTIVE']) assert.ok(schema.includes(token),token);
for(const token of ['/api/pharmacy/orders/update','/api/pharmacy/inventory','requested','dispensed']) assert.ok(page.includes(token),token);
console.log('V19.7 pharmacy network static test PASS');
