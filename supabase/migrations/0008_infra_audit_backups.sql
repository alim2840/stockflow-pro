-- =============================================================================
-- StockFlow Pro — 0008_infra_audit_backups.sql
-- Numbering sequences, approvals, attachments, notifications, backups,
-- and the immutable audit log.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Concurrency-safe reference numbering.
-- One row per (org, doc_type, year). next_reference() (0009) locks the row.
-- ---------------------------------------------------------------------------
create table numbering_sequences (
  org_id        uuid not null references organisations(id) on delete cascade,
  doc_type      text not null,               -- 'ITM','PO','GRN','ISS','PRJ'...
  year          int  not null,               -- 0 => non-year-scoped (e.g. ITM)
  prefix        text not null,
  padding       int  not null default 6,
  current_value bigint not null default 0,
  primary key (org_id, doc_type, year)
);

-- ---------------------------------------------------------------------------
-- Reusable approval workflow (polymorphic: entity_type + entity_id)
-- ---------------------------------------------------------------------------
create table approvals (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references organisations(id) on delete cascade,
  entity_type   text not null,               -- 'purchase_order','stock_txn'...
  entity_id     uuid not null,
  status        approval_status not null default 'pending',
  requested_by  uuid references profiles(id),
  decided_by    uuid references profiles(id),
  decided_at    timestamptz,
  threshold_value numeric(18,4),
  comment       text,
  rejection_reason text,
  created_at    timestamptz not null default now()
);
create index idx_approvals_entity on approvals(entity_type, entity_id);
create index idx_approvals_pending on approvals(org_id) where status = 'pending';

-- ---------------------------------------------------------------------------
-- Attachments (files live in Supabase Storage; this is metadata + ACL anchor)
-- ---------------------------------------------------------------------------
create table attachments (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references organisations(id) on delete cascade,
  entity_type   text not null,
  entity_id     uuid not null,
  file_name     text not null,
  storage_path  text not null,               -- bucket path (private)
  mime_type     text,
  size_bytes    bigint,
  checksum_sha256 text,
  uploaded_by   uuid references profiles(id),
  created_at    timestamptz not null default now()
);
create index idx_attach_entity on attachments(entity_type, entity_id);

-- ---------------------------------------------------------------------------
-- Notifications
-- ---------------------------------------------------------------------------
create table notifications (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references organisations(id) on delete cascade,
  user_id       uuid references profiles(id) on delete cascade,  -- null => org broadcast
  kind          notification_kind not null,
  title         text not null,
  body          text,
  link          text,
  entity_type   text,
  entity_id     uuid,
  is_read       boolean not null default false,
  created_at    timestamptz not null default now()
);
create index idx_notif_user_unread on notifications(user_id) where not is_read;

create table notification_preferences (
  user_id       uuid not null references profiles(id) on delete cascade,
  kind          notification_kind not null,
  in_app        boolean not null default true,
  email         boolean not null default false,
  primary key (user_id, kind)
);

-- ---------------------------------------------------------------------------
-- Backups (Google Drive secondary layer). Refresh tokens are NEVER stored
-- here in plaintext — see docs/GOOGLE-DRIVE.md (server-side encrypted store).
-- ---------------------------------------------------------------------------
create table backup_jobs (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null references organisations(id) on delete cascade,
  frequency      backup_frequency not null default 'manual',
  status         backup_status not null default 'queued',
  started_at     timestamptz,
  finished_at    timestamptz,
  initiated_by   uuid references profiles(id),
  failure_reason text,
  created_at     timestamptz not null default now()
);

create table backup_files (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null references organisations(id) on delete cascade,
  job_id         uuid references backup_jobs(id) on delete cascade,
  drive_file_id  text,
  file_name      text not null,
  size_bytes     bigint,
  checksum_sha256 text not null,
  encrypted      boolean not null default true,
  created_at     timestamptz not null default now()
);

create table restore_events (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null references organisations(id) on delete cascade,
  backup_file_id uuid references backup_files(id),
  requested_by   uuid references profiles(id),
  confirmed_by   uuid references profiles(id),
  status         backup_status not null default 'queued',
  notes          text,
  created_at     timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- IMMUTABLE AUDIT LOG. No UPDATE/DELETE permitted (guard trigger below).
-- ---------------------------------------------------------------------------
create table audit_logs (
  id             bigint generated always as identity primary key,
  org_id         uuid references organisations(id) on delete cascade,
  user_id        uuid,
  user_role      text,
  action         text not null,               -- 'post','reverse','login'...
  module         text,
  record_type    text,
  record_id      uuid,
  reference_no   text,
  old_values     jsonb,
  new_values     jsonb,
  result         text,                        -- 'success' | 'failure'
  reason         text,
  ip_address     inet,
  user_agent     text,
  related_id     uuid,
  created_at     timestamptz not null default now()
);
create index idx_audit_org_time on audit_logs(org_id, created_at desc);
create index idx_audit_record   on audit_logs(record_type, record_id);

create or replace function guard_audit_immutable() returns trigger
language plpgsql as $$
begin
  raise exception 'Audit log is immutable (% not allowed).', tg_op
    using errcode = 'insufficient_privilege';
end $$;

create trigger trg_audit_immutable
  before update or delete on audit_logs
  for each row execute function guard_audit_immutable();
