-- =============================================================================
-- StockFlow Pro — 0007_transfers_counts_production.sql
-- Warehouse transfers (with in-transit state), stock counts, BOM & production.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Warehouse transfers. Dispatch moves stock source -> IN-TRANSIT warehouse;
-- receipt moves IN-TRANSIT -> destination. Dispatched stock is NEVER counted
-- as available at destination until received.
-- ---------------------------------------------------------------------------
create table warehouse_transfers (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null references organisations(id) on delete cascade,
  ref_no         text not null,               -- TRF-2026-000001
  status         transfer_status not null default 'draft',
  source_wh      uuid not null references warehouses(id),
  dest_wh        uuid not null references warehouses(id),
  transit_wh     uuid references warehouses(id),
  dispatched_at  timestamptz,
  received_at    timestamptz,
  dispatch_txn_id uuid references stock_transactions(id),
  receipt_txn_id  uuid references stock_transactions(id),
  notes          text,
  created_by     uuid references profiles(id),
  approved_by    uuid references profiles(id),
  created_at     timestamptz not null default now(),
  unique (org_id, ref_no),
  constraint chk_diff_wh check (source_wh <> dest_wh)   -- src/dest must differ
);

create table warehouse_transfer_lines (
  id            uuid primary key default gen_random_uuid(),
  transfer_id   uuid not null references warehouse_transfers(id) on delete cascade,
  item_id       uuid not null references items(id),
  quantity      numeric(18,4) not null check (quantity > 0),
  received_qty  numeric(18,4) not null default 0 check (received_qty >= 0),
  unit_id       uuid references units(id),
  constraint chk_transfer_not_over_received check (received_qty <= quantity)
);

alter table stock_transactions
  add constraint fk_txn_transfer foreign key (transfer_id) references warehouse_transfers(id);

-- ---------------------------------------------------------------------------
-- Stock counts. Expected qty is frozen at snapshot; adjustments are only
-- created when an approved count is posted.
-- ---------------------------------------------------------------------------
create table stock_counts (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references organisations(id) on delete cascade,
  ref_no        text not null,               -- CNT-2026-000001
  warehouse_id  uuid not null references warehouses(id),
  status        count_status not null default 'draft',
  is_full_count boolean not null default false,
  snapshot_at   timestamptz,
  posted_at     timestamptz,
  adjustment_txn_id uuid references stock_transactions(id),
  notes         text,
  created_by    uuid references profiles(id),
  approved_by   uuid references profiles(id),
  created_at    timestamptz not null default now(),
  unique (org_id, ref_no)
);

create table stock_count_lines (
  id            uuid primary key default gen_random_uuid(),
  count_id      uuid not null references stock_counts(id) on delete cascade,
  item_id       uuid not null references items(id),
  location_id   uuid references storage_locations(id),
  expected_qty  numeric(18,4) not null default 0,   -- frozen at snapshot
  counted_qty   numeric(18,4),
  recount_qty   numeric(18,4),
  variance      numeric(18,4) generated always as
                (coalesce(coalesce(recount_qty, counted_qty),0) - expected_qty) stored,
  counted_by    uuid references profiles(id),
  notes         text
);

alter table stock_transactions
  add constraint fk_txn_count foreign key (count_id) references stock_counts(id);

-- ---------------------------------------------------------------------------
-- Bills of material & production (optional assembly module)
-- ---------------------------------------------------------------------------
create table bills_of_material (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references organisations(id) on delete cascade,
  product_item_id uuid not null references items(id),   -- finished good
  version       int not null default 1,
  output_qty    numeric(18,4) not null default 1 check (output_qty > 0),
  is_active     boolean not null default true,
  notes         text,
  created_at    timestamptz not null default now(),
  unique (product_item_id, version)
);

create table bill_of_material_lines (
  id            uuid primary key default gen_random_uuid(),
  bom_id        uuid not null references bills_of_material(id) on delete cascade,
  component_item_id uuid not null references items(id),
  quantity      numeric(18,4) not null check (quantity > 0),
  wastage_pct   numeric(9,4) not null default 0 check (wastage_pct >= 0),
  unit_id       uuid references units(id)
);

create table production_orders (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references organisations(id) on delete cascade,
  ref_no        text not null,               -- ASM-2026-000001
  bom_id        uuid references bills_of_material(id),
  product_item_id uuid not null references items(id),
  warehouse_id  uuid not null references warehouses(id),
  planned_qty   numeric(18,4) not null check (planned_qty > 0),
  actual_qty    numeric(18,4) not null default 0 check (actual_qty >= 0),
  status        production_status not null default 'draft',
  batch_no      text,
  consumption_txn_id uuid references stock_transactions(id),
  output_txn_id      uuid references stock_transactions(id),
  posted_at     timestamptz,
  project_id    uuid references projects(id),
  notes         text,
  created_by    uuid references profiles(id),
  created_at    timestamptz not null default now(),
  unique (org_id, ref_no)
);

alter table stock_transactions
  add constraint fk_txn_production foreign key (production_id) references production_orders(id);

-- ---------------------------------------------------------------------------
-- Exchange rates (org base currency <- transaction currency)
-- ---------------------------------------------------------------------------
create table exchange_rates (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references organisations(id) on delete cascade,
  from_currency char(3) not null,
  to_currency   char(3) not null,
  rate          numeric(18,6) not null check (rate > 0),
  as_of_date    date not null,
  unique (org_id, from_currency, to_currency, as_of_date)
);
