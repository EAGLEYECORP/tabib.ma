import {test,expect} from '@playwright/test';
test('home renders',async({page})=>{await page.goto('/');await expect(page.getByText('Trouvez un professionnel')).toBeVisible();});
test('health endpoint',async({request})=>{const r=await request.get('/api/health');expect(r.ok()).toBeTruthy();});
