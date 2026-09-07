# V18.2 Release Gate

## Static checks
- [x] Notification inbox is authenticated
- [x] Recipient is derived from session, never request input
- [x] Read RPC constrains recipient to auth.uid()
- [x] Mutating endpoints require Same-Origin
- [x] JSON request size bounded
- [x] Sensitive notification payloads prohibited by documented contract
- [x] No provider secret added to repository

## Not verified in sandbox
- [ ] npm install/build against real dependency tree
- [ ] Supabase RLS integration
- [ ] provider delivery integration
- [ ] load/failure testing
- [ ] external security test
- [ ] Moroccan legal/CNDP production gates
