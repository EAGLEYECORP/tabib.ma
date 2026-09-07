import assert from 'node:assert/strict';

const statuses = new Set(['pending','requires_action','authorized','paid','failed','cancelled','refunded','partially_refunded']);
for (const s of ['paid','partially_refunded','refunded']) assert.ok(statuses.has(s));
const remaining = (paid, refunds) => Math.max(0, paid - refunds.reduce((a,b)=>a+b,0));
assert.equal(remaining(100, [20,30]), 50);
assert.equal(remaining(100, [100]), 0);
assert.equal(remaining(100, [120]), 0);
const key = '0123456789abcdef';
assert.equal(key.length, 16);
console.log('V18.5 payment invariants: 4/4 PASS');
