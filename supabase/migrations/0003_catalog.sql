-- =============================================================================
-- StockFlow Pro — 0003_catalog.sql
-- Warehouses, storage locations, categories, units, items, suppliers.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Warehouses & storage hierarchy (zone > rack > shelf > bin via self-ref)
-- ---------------------------------------------------------------------------
create table warehouses (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references organisations(id) on delete cascade,
  code          text not null,
  name          text not null,
  kind          warehouse_kind not null default 'standard',
  country_code  char(2),
  address       text,
  timezone      text,
  manager_id    uuid references profiles(id),
  -- Special-purpose warehouses are excluded from "available" stock math.
  counts_as_available boolean not null default true,
  is_active     boolean not null default true,
  archived_at   timestamptz,
  created_at    timestamptz not null default now(),
  unique (org_id, code)
);

create table storage_locations (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references organisations(id) on delete cascade,
  warehouse_id  uuid not null references warehouses(id) on delete cascade,
  parent_id     uuid references storage_locations(id) on delete cascade,
  code          text not null,
  name          text,
  level         text,           -- 'zone' | 'rack' | 'shelf' | 'bin'
  is_active     boolean not null default true,
  unique (warehouse_id, code)
);

-- Deferred FK from 0002 now that warehouses exists.
alter table user_warehouse_access
  add constraint fk_uwa_warehouse
  foreign key (warehouse_id) references warehouses(id) on delete cascade;

-- ---------------------------------------------------------------------------
-- Categories, brands, units
-- ---------------------------------------------------------------------------
create table categories (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references organisations(id) on delete cascade,
  parent_id   uuid references categories(id),
  name        text not null,
  code        text,
  archived_at timestamptz,
  unique (org_id, name, parent_id)
);

create table brands (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references organisations(id) on delete cascade,
  name        text not null,
  archived_at timestamptz,
  unique (org_id, name)
);

create table units (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references organisations(id) on delete cascade,
  code        text not null,          -- 'pcs','kg','m','box'
  name        text not null,
  archived_at timestamptz,
  unique (org_id, code)
);

-- factor: how many base units are in 1 'from' unit (e.g. 1 box = 100 pcs).
create table unit_conversions (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references organisations(id) on delete cascade,
  from_unit_id  uuid not null references units(id),
  to_unit_id    uuid not null references units(id),
  factor        numeric(18,6) not null check (factor > 0),
  unique (org_id, from_unit_id, to_unit_id)
);

-- ---------------------------------------------------------------------------
-- Suppliers
-- ---------------------------------------------------------------------------
create table suppliers (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references organisations(id) on delete cascade,
  ref_no          text not null,           -- SUP-000001
  name            text not null,
  contact_person  text,
  email           citext,
  phone           text,
  website         text,
  country_code    char(2),
  address         text,
  tax_number      text,
  payment_terms   text,
  currency        char(3),
  lead_time_days  int check (lead_time_days is null or lead_time_days >= 0),
  -- Bank details are sensitive: RLS/permission gate reads (see 0010).
  bank_details    jsonb,
  notes           text,
  is_active       boolean not null default true,
  archived_at     timestamptz,
  created_at      timestamptz not null default now(),
  created_by      uuid references profiles(id),
  unique (org_id, ref_no)
);

-- ---------------------------------------------------------------------------
-- Items (the master record)
-- ---------------------------------------------------------------------------
create table items (
  id                 uuid primary key default gen_random_uuid(),
  org_id             uuid not null references organisations(id) on delete cascade,
  ref_no             text not null,                 -- ITM-000001 (internal id)
  sku                citext not null,               -- unique business key
  barcode            text,
  name               text not null,
  description        text,
  category_id        uuid references categories(id),
  brand_id           uuid references brands(id),
  manufacturer       text,
  manufacturer_pn    text,
  item_type          item_type not null default 'component',
  base_unit_id       uuid not null references units(id),
  purchase_unit_id   uuid references units(id),
  purchase_conversion numeric(18,6) not null default 1 check (purchase_conversion > 0),
  costing_method     costing_method not null default 'moving_average',
  standard_cost      numeric(18,4) not null default 0 check (standard_cost >= 0),
  average_cost       numeric(18,4) not null default 0 check (average_cost >= 0),
  selling_price      numeric(18,4) check (selling_price is null or selling_price >= 0),
  min_stock          numeric(18,4) not null default 0 check (min_stock >= 0),
  reorder_point      numeric(18,4) not null default 0 check (reorder_point >= 0),
  reorder_qty        numeric(18,4) not null default 0 check (reorder_qty >= 0),
  max_stock          numeric(18,4),
  preferred_supplier_id uuid references suppliers(id),
  lead_time_days     int,
  storage_conditions text,
  shelf_life_days    int,
  track_expiry       boolean not null default false,
  track_batch        boolean not null default false,
  track_serial       boolean not null default false,
  image_url          text,
  datasheet_url      text,
  notes              text,
  is_active          boolean not null default true,
  archived_at        timestamptz,
  created_at         timestamptz not null default now(),
  created_by         uuid references profiles(id),
  updated_at         timestamptz not null default now(),
  updated_by         uuid references profiles(id),
  version            int not null default 1,        -- optimistic concurrency
  constraint uq_item_ref  unique (org_id, ref_no),
  constraint uq_item_sku  unique (org_id, sku)       -- no duplicate SKUs
);

create index idx_items_org       on items(org_id);
create index idx_items_category  on items(category_id);
create index idx_items_active    on items(org_id) where is_active;
-- Trigram-friendly search index for name/sku (fast global search)
create index idx_items_name_lower on items (org_id, lower(name));

-- Item ↔ supplier catalog (many suppliers per item with their own price/lead).
create table item_suppliers (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references organisations(id) on delete cascade,
  item_id       uuid not null references items(id) on delete cascade,
  supplier_id   uuid not null references suppliers(id) on delete cascade,
  supplier_sku  text,
  last_price    numeric(18,4),
  currency      char(3),
  lead_time_days int,
  is_preferred  boolean not null default false,
  unique (item_id, supplier_id)
);

-- Item cost history (append-only; written by posting/costing functions).
create table item_cost_history (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references organisations(id) on delete cascade,
  item_id       uuid not null references items(id) on delete cascade,
  effective_at  timestamptz not null default now(),
  average_cost  numeric(18,4) not null,
  source_txn_id uuid,
  note          text
);
create index idx_cost_hist_item on item_cost_history(item_id, effective_at desc);
