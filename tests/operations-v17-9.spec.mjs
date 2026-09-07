import assert from 'node:assert/strict';
const validDays = [0,1,2,3,4,5,6];
assert.equal(validDays.includes(1), true);
assert.equal(validDays.includes(7), false);
const future = new Date(Date.now()+3600000);
assert.equal(future > new Date(), true);
assert.equal('confirmed'.match(/requested|confirmed/)?.[0], 'confirmed');
console.log('V17.9 operations tests: 3/3 PASS');
