-- =============================================================================
-- StockFlow Pro — 0005_purchasing.sql
-- Requisitions -> Purchase Orders -> Goods Receipts. Receiving posts to the
-- ledger ONLY when a goods receipt is posted (see post_goods_receipt in 0009).
-- =============================================================================

create table purchase_requisitions (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references organisations(id) on delete cascade,
  ref_no        text not null,
  status        requisition_status not null default 'draft',
  project_id    uuid,
  warehouse_id  uuid references warehouses(id),
  needed_by     date,
  notes         text,
  created_by    uuid references profiles(id),
  approved_by   uuid references profiles(id),
  created_at    timestamptz not null default now(),
  unique (org_id, ref_no)
);

create table purchase_requisition_lines (
  id            uuid primary key default gen_random_uuid(),
  requisition_id uuid not null references purchase_requisitions(id) on delete cascade,
  item_id       uuid not null references items(id),
  quantity      numeric(18,4) not null check (quantity > 0),
  unit_id       uuid references units(id),
  notes         text
);

-- ---------------------------------------------------------------------------
-- Purchase orders
-- ---------------------------------------------------------------------------
create table purchase_orders (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null references organisations(id) on delete cascade,
  ref_no         text not null,               -- PO-2026-000001
  supplier_id    uuid not null references suppliers(id),
  status         po_status not null default 'draft',
  order_date     date not null default (now() at time zone 'utc'),
  expected_date  date,
  warehouse_id   uuid references warehouses(id),
  project_id     uuid,
  currency       char(3) not null default 'PKR',
  exchange_rate  numeric(18,6) not null default 1 check (exchange_rate > 0),
  tax_total      numeric(18,4) not null default 0 check (tax_total >= 0),
  freight        numeric(18,4) not null default 0 check (freight >= 0),
  other_charges  numeric(18,4) not null default 0 check (other_charges >= 0),
  discount       numeric(18,4) not null default 0 check (discount >= 0),
  payment_terms  text,
  delivery_terms text,
  notes          text,
  created_by     uuid references profiles(id),
  approved_by    uuid references profiles(id),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  version        int not null default 1,
  unique (org_id, ref_no)
);
create index idx_po_supplier on purchase_orders(supplier_id);
create index idx_po_status   on purchase_orders(org_id, status);

create table purchase_order_lines (
  id            uuid primary key default gen_random_uuid(),
  po_id         uuid not null references purchase_orders(id) on delete cascade,
  line_no       int not null default 1,
  item_id       uuid not null references items(id),
  ordered_qty   numeric(18,4) not null check (ordered_qty > 0),
  -- received_qty is maintained by the receipt-posting function, never by UI.
  received_qty  numeric(18,4) not null default 0 check (received_qty >= 0),
  unit_id       uuid references units(id),
  unit_price    numeric(18,4) not null default 0 check (unit_price >= 0),
  tax_rate      numeric(9,4) not null default 0,
  discount      numeric(18,4) not null default 0,
  line_total    numeric(18,4) not null default 0,
  unique (po_id, line_no),
  -- Cannot receive more than ordered (data-integrity requirement).
  constraint chk_not_over_received check (received_qty <= ordered_qty)
);

-- Deferred FKs from the ledger now that PO exists.
alter table stock_transactions
  add constraint fk_txn_po
  foreign key (purchase_order_id) references purchase_orders(id);

-- ---------------------------------------------------------------------------
-- Goods receipts (GRN)
-- ---------------------------------------------------------------------------
create table goods_receipts (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references organisations(id) on delete cascade,
  ref_no        text not null,               -- GRN-2026-000001
  po_id         uuid references purchase_orders(id),
  supplier_id   uuid references suppliers(id),
  warehouse_id  uuid not null references warehouses(id),
  status        receipt_status not null default 'draft',
  receipt_date  date not null default (now() at time zone 'utc'),
  supplier_invoice_ref text,
  posted_at     timestamptz,
  posted_by     uuid references profiles(id),
  stock_txn_id  uuid references stock_transactions(id),  -- link to ledger entry
  notes         text,
  created_by    uuid references profiles(id),
  created_at    timestamptz not null default now(),
  unique (org_id, ref_no)
);

create table goods_receipt_lines (
  id            uuid primary key default gen_random_uuid(),
  receipt_id    uuid not null references goods_receipts(id) on delete cascade,
  po_line_id    uuid references purchase_order_lines(id),
  item_id       uuid not null references items(id),
  received_qty  numeric(18,4) not null check (received_qty > 0),
  unit_cost     numeric(18,4) not null default 0 check (unit_cost >= 0),
  location_id   uuid references storage_locations(id),
  batch_no      text,
  serial_no     text,
  expiry_date   date
);

alter table stock_transactions
  add constraint fk_txn_grn
  foreign key (goods_receipt_id) references goods_receipts(id);
