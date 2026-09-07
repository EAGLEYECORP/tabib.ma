import assert from 'node:assert/strict';
const route = await import('../app/api/appointments/book/route.ts').catch(()=>null);
assert.ok(route, 'booking route module exists');
const fs = await import('node:fs/promises');
const sql = await fs.readFile('../supabase/schema_v18_0_booking.sql','utf8');
assert.match(sql,/get_public_booking_slots/); assert.match(sql,/book_appointment_v18/); assert.match(sql,/BOOKING_WINDOW_TOO_LARGE/);
console.log('V18.0 booking tests: PASS');
