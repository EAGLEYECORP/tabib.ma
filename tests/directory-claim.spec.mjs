import { test, expect } from '@playwright/test';
import fs from 'node:fs';

test('V17.8 claim routes enforce same-origin and admin split', async () => {
 const a=fs.readFileSync('app/api/directory/claims/submit/route.ts','utf8');
 const r=fs.readFileSync('app/api/directory/claims/review/route.ts','utf8');
 const v=fs.readFileSync('app/api/directory/verify-claimed/route.ts','utf8');
 expect(a).toContain('requireSameOrigin'); expect(r).toContain("p?.role!=='platform_admin'"); expect(v).toContain("p?.role!=='platform_admin'");
});

test('V17.8 migration separates claim approval from verification', async () => {
 const s=fs.readFileSync('supabase/schema_v17_8_claim_verification.sql','utf8');
 expect(s).toContain("verification_status='verified'"); expect(s).toContain("verification_status='claimed'"); expect(s).toContain('directory_claim_reviews');
});
