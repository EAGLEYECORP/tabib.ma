import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
const required = ['app','lib','supabase','tests','middleware.ts','.env.example','package.json','README.md','README_V17.md','docs/V17_RELEASE_CANDIDATE.md','docs/V17_1_AUDIT_REPORT.md','compliance/MOROCCO_LEGAL_MATRIX.md','security/V17_1_THREAT_MODEL.md','docs/RATE_LIMITING.md','docs/CSP_HARDENING.md','compliance/SUBPROCESSOR_REGISTER.md'];
for (const p of required) if (!existsSync(p)) throw new Error(`Missing required path: ${p}`);
const pkg = JSON.parse(readFileSync('package.json','utf8'));
for (const section of ['dependencies','devDependencies']) for (const [name,version] of Object.entries(pkg[section]||{})) if (version === 'latest' || version === '*') throw new Error(`Unpinned dependency: ${name}=${version}`);
const env = readFileSync('.env.example','utf8');
for (const key of ['SUPABASE_SERVICE_ROLE_KEY','PAYMENT_PROVIDER_API_KEY','VIDEO_API_SECRET']) if (!env.includes(key)) throw new Error(`Missing env contract: ${key}`);
const forbidden = /(sk_live_[A-Za-z0-9]+|AIza[0-9A-Za-z_-]{20,}|-----BEGIN (RSA|EC|OPENSSH) PRIVATE KEY-----)/;
const skip = new Set(['.git','node_modules','.next','coverage']);
function walk(dir){let out=[]; for(const e of readdirSync(dir)){if(skip.has(e))continue; const p=join(dir,e),s=statSync(p); if(s.isDirectory())out.push(...walk(p)); else out.push(p)} return out}
for(const f of walk('.')) { if(!/\.(ts|tsx|js|mjs|json|sql|md|env)$/.test(f)) continue; const s=readFileSync(f,'utf8'); if(forbidden.test(s)) throw new Error(`Possible secret in ${f}`); }
console.log('release-check: PASS');
