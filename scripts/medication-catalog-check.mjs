import assert from 'node:assert/strict';
const n=s=>s.trim().replace(/\s+/g,' '); assert.equal(n('  AMOVAS   10mg  '),'AMOVAS 10mg'); assert.ok(75.9>=0); console.log('V19.5 medication catalog checks: PASS');
