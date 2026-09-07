import assert from 'node:assert/strict';

const schema = await import('node:fs/promises').then(fs => fs.readFile('supabase/schema_v18_2_notifications.sql', 'utf8'));
assert.match(schema, /notification_channel_consents/);
assert.match(schema, /mark_notification_read/);
assert.match(schema, /recipient_id = auth\.uid\(\)/);
assert.match(schema, /where channel = 'in_app'/);

const inbox = await import('node:fs/promises').then(fs => fs.readFile('app/api/notifications/inbox/route.ts', 'utf8'));
assert.match(inbox, /Cache-Control/);
assert.match(inbox, /eq\('recipient_id', user\.id\)/);

const read = await import('node:fs/promises').then(fs => fs.readFile('app/api/notifications/read/route.ts', 'utf8'));
assert.match(read, /requireSameOrigin/);
assert.match(read, /mark_notification_read/);

console.log('V18.2 notification tests: 3/3 PASS');
