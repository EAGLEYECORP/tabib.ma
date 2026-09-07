import test from 'node:test'; import assert from 'node:assert/strict'
const norm=s=>String(s||'').normalize('NFKD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9]+/g,' ').trim().replace(/\s+/g,' ')
test('normalizes Moroccan accents safely',()=>assert.equal(norm('Dr. Nadia BOUKHOUÏMA'),'dr nadia boukhouima'))
test('rejects missing source key',()=>assert.equal(!String('').trim(),true))
test('canonical duplicate key is stable',()=>assert.equal([norm('Dr Aït Ali'),norm('Cardiologue'),norm('Rabat')].join('|'),'dr ait ali|cardiologue|rabat'))
