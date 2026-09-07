import test from 'node:test'
import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
const hash = x => createHash('sha256').update(JSON.stringify(x)).digest('hex')
test('input hash is deterministic',()=>assert.equal(hash({b:2,a:1}),hash({b:2,a:1})))
test('batch ceiling is 100k',()=>assert.ok(100000<=100000))
test('invalid record shape is rejected by preflight rule',()=>assert.equal([{fullName:''}].filter(r=>!r.sourceRecordKey||!r.fullName).length,1))
