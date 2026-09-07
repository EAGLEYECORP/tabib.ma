-- Tabib.ma V14/V17 scale indexes. Apply after schema_v13_security.sql.
-- Safe to re-run.
create index if not exists idx_appointments_doctor_start on public.appointments(doctor_id,start_at);
create index if not exists idx_appointments_patient_start on public.appointments(patient_id,start_at);
create index if not exists idx_appointments_status_start on public.appointments(status,start_at);
create index if not exists idx_notification_queue_status_scheduled on public.notification_queue(status,scheduled_at);
create index if not exists idx_patient_documents_owner_created on public.patient_documents(owner_id,created_at desc);
create index if not exists idx_document_shares_document_expiry on public.document_shares(document_id,expires_at);
create index if not exists idx_audit_logs_created_at on public.audit_logs(created_at desc);
create index if not exists idx_clinic_members_clinic_user on public.clinic_members(clinic_id,user_id);
