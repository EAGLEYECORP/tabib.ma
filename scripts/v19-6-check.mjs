import fs from 'node:fs';
const files=['supabase/schema_v19_6_prescription_pharmacy.sql','lib/prescriptions.ts','app/prescriptions/page.tsx','docs/V19_6_PRESCRIPTION_PHARMACY.md','docs/V19_6_RELEASE_GATE.md'];
for (const f of files) if(!fs.existsSync(f)) throw new Error(`MISSING:${f}`);
const sql=fs.readFileSync(files[0],'utf8');
for(const token of ['issue_prescription_v19_6','request_pharmacy_order_v19_6','update_pharmacy_order_v19_6','enable row level security']) if(!sql.includes(token)) throw new Error(`MISSING_TOKEN:${token}`);
console.log('V19.6 CHECK PASS');
