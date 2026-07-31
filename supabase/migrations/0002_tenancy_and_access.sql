-- =============================================================================
-- StockFlow Pro — 0002_tenancy_and_access.sql
-- Organisations, profiles, roles, granular permissions, scoped access grants.
-- =============================================================================
-- Multi-tenant model: every business row carries org_id. RLS (migration 0010)
-- restricts every query to the caller's organisation + their scoped grants.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Organisations & company settings
-- ---------------------------------------------------------------------------
create table organisations (
  id              uuid primary key default gen_random_uuid(),
  name            text not null,
  slug            citext not null unique,
  created_at      timestamptz not null default now(),
  archived_at     timestamptz
);

create table company_settings (
  org_id              uuid primary key references organisations(id) on delete cascade,
  app_name            text not null default 'StockFlow Pro',
  legal_name          text,
  logo_url            text,
  brand_primary       text not null default '#3730A3',  -- deep indigo
  brand_secondary     text not null default '#0891B2',  -- cyan
  address             text,
  country_code        char(2) not null default 'PK',
  tax_number          text,
  email               citext,
  phone               text,
  website             text,
  base_currency       char(3) not null default 'PKR',
  timezone            text not null default 'Asia/Karachi',   -- IANA tz
  date_format         text not null default 'DD-MMM-YYYY',
  number_format       text not null default '#,##0.00',
  fiscal_year_start   int not null default 1 check (fiscal_year_start between 1 and 12),
  -- inventory settings
  allow_negative_stock       boolean not null default false,
  default_costing_method     costing_method not null default 'moving_average',
  low_stock_check_enabled    boolean not null default true,
  serial_tracking_default    boolean not null default false,
  batch_tracking_default     boolean not null default false,
  expiry_tracking_default    boolean not null default false,
  -- security settings
  session_timeout_minutes    int not null default 480,
  max_failed_logins          int not null default 5,
  enforce_2fa                boolean not null default false,
  audit_retention_days       int not null default 2555,   -- ~7 years
  segregation_of_duties      boolean not null default true,
  updated_at          timestamptz not null default now(),
  updated_by          uuid
);

-- ---------------------------------------------------------------------------
-- Profiles — mirrors auth.users (Supabase Auth owns credentials/passwords)
-- ---------------------------------------------------------------------------
create table profiles (
  id              uuid primary key,                 -- == auth.users.id
  org_id          uuid not null references organisations(id) on delete cascade,
  email           citext not null,
  full_name       text,
  avatar_url      text,
  phone           text,
  timezone        text,                             -- per-user override of company tz
  status          user_status not null default 'invited',
  is_platform_admin boolean not null default false, -- Super Admin (cross-org)
  invited_by      uuid references profiles(id),
  invited_at      timestamptz,
  activated_at    timestamptz,
  last_login_at   timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (org_id, email)
);

create index idx_profiles_org on profiles(org_id);

-- ---------------------------------------------------------------------------
-- Roles & permissions (permissions enforced in DB, not just UI)
-- ---------------------------------------------------------------------------
create table roles (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid references organisations(id) on delete cascade, -- null => system role
  key             text not null,          -- e.g. 'company_admin'
  name            text not null,
  description     text,
  is_system       boolean not null default false,
  created_at      timestamptz not null default now(),
  unique (org_id, key)
);

-- A permission is (module, action). Modules mirror the navigation.
create table permissions (
  id      serial primary key,
  module  text not null,               -- 'items','stock_txn','projects','users'...
  action  perm_action not null,
  unique (module, action)
);

create table role_permissions (
  role_id        uuid not null references roles(id) on delete cascade,
  permission_id  int  not null references permissions(id) on delete cascade,
  primary key (role_id, permission_id)
);

create table user_roles (
  user_id   uuid not null references profiles(id) on delete cascade,
  role_id   uuid not null references roles(id) on delete cascade,
  org_id    uuid not null references organisations(id) on delete cascade,
  primary key (user_id, role_id)
);

-- Scoped access: a user only sees warehouses / projects granted to them.
create table user_warehouse_access (
  user_id       uuid not null references profiles(id) on delete cascade,
  warehouse_id  uuid not null,           -- FK added in 0003 after warehouses exists
  can_post      boolean not null default false,
  primary key (user_id, warehouse_id)
);

create table user_project_access (
  user_id     uuid not null references profiles(id) on delete cascade,
  project_id  uuid not null,             -- FK added in 0006
  role_in_project text,
  primary key (user_id, project_id)
);

create index idx_user_roles_user on user_roles(user_id);
create index idx_uwa_user on user_warehouse_access(user_id);
create index idx_upa_user on user_project_access(user_id);

comment on table user_warehouse_access is
  'Row-level scope. Empty grant set for a non-platform-admin => no warehouse rows visible.';
