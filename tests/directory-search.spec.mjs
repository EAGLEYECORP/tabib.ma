import test from 'node:test'; import assert from 'node:assert/strict';
import { normalizeSearch } from '../lib/directory/search.ts';
test('bounds search inputs',()=>{const s=normalizeSearch({query:' x '.repeat(100),limit:999,offset:-4}); assert.equal(s.limit,100); assert.equal(s.offset,0); assert.ok(s.query.length<=120)});
test('empty filters normalize',()=>{const s=normalizeSearch({}); assert.equal(s.query,undefined); assert.equal(s.limit,20)});
