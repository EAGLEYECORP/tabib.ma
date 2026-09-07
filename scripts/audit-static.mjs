import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
const failures=[]; const warnings=[];
const walk=(dir)=>{let out=[]; for(const e of readdirSync(dir)){if(['.git','node_modules','.next','coverage'].includes(e))continue;const p=join(dir,e),s=statSync(p);s.isDirectory()?out.push(...walk(p)):out.push(p)} return out};
const files=walk('.').filter(f=>!['scripts/audit-static.mjs','scripts/release-check.mjs'].includes(f));
for(const f of files){
 if(!/\.(ts|tsx|js|mjs|json|sql|env|md)$/.test(f)) continue;
 const s=readFileSync(f,'utf8');
 if(/(sk_live_|-----BEGIN .*PRIVATE KEY-----|SUPABASE_SERVICE_ROLE_KEY\s*=\s*eyJ)/.test(s)) failures.push(`Possible secret: ${f}`);
 if(/https?:\/\/localhost(?::\d+)?/.test(s) && !f.endsWith('.env.example')) warnings.push(`Localhost reference: ${f}`);
}
if(!existsSync('supabase/schema_v17_1_hardening.sql')) failures.push('Missing V17.1 hardening migration');
if(!existsSync('compliance/MOROCCO_LEGAL_MATRIX.md')) failures.push('Missing Morocco legal matrix');
if(!existsSync('security/V17_1_THREAT_MODEL.md')) failures.push('Missing threat model');
if(failures.length){console.error(failures.join('\n'));process.exit(1)}
console.log(`static-audit: PASS (${warnings.length} warnings)`);
if(warnings.length) console.log(warnings.join('\n'));
