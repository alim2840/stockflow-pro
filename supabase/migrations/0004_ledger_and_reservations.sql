-- =============================================================================
-- StockFlow Pro — 0004_ledger_and_reservations.sql
-- The permanent, immutable stock transaction ledger. This is the SINGLE
-- source of truth for inventory. On-hand balances are NEVER stored as a
-- mutable column — they are always SUM(signed_quantity) over posted lines.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Transaction header
-- ---------------------------------------------------------------------------
create table stock_transactions (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null references organisations(id) on delete cascade,
  ref_no         text not null,                 -- ISS-2026-000001 etc.
  txn_type       stock_txn_type not null,
  status         stock_txn_status not null default 'draft',
  txn_date       date not null default (now() at time zone 'utc'),
  posted_at      timestamptz,                   -- set atomically on posting
  -- optional context links
  project_id     uuid,                          -- FK added in 0006
  supplier_id    uuid references suppliers(id),
  purchase_order_id uuid,                        -- FK added in 0005
  goods_receipt_id  uuid,
  transfer_id    uuid,
  count_id       uuid,
  production_id  uuid,
  currency       char(3),
  exchange_rate  numeric(18,6) not null default 1 check (exchange_rate > 0),
  reason         text,
  notes          text,
  -- correction lineage
  reversal_of    uuid references stock_transactions(id),
  reversed_by    uuid references stock_transactions(id),
  -- idempotency: a client-supplied key makes "post" safe to retry.
  idempotency_key text,
  -- audit stamps
  created_by     uuid references profiles(id),
  approved_by    uuid references profiles(id),
  posted_by      uuid references profiles(id),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  version        int not null default 1,
  constraint uq_txn_ref  unique (org_id, ref_no),
  constraint uq_txn_idem unique (org_id, idempotency_key),
  -- a transaction can only be a reversal of one other, once
  constraint uq_reversal_of unique (reversal_of)
);

create index idx_txn_org_status on stock_transactions(org_id, status);
create index idx_txn_type       on stock_transactions(org_id, txn_type);
create index idx_txn_date       on stock_transactions(org_id, txn_date);
create index idx_txn_project    on stock_transactions(project_id);

-- ---------------------------------------------------------------------------
-- Transaction lines — the actual ledger entries
-- ---------------------------------------------------------------------------
create table stock_transaction_lines (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references organisations(id) on delete cascade,
  transaction_id  uuid not null references stock_transactions(id) on delete cascade,
  line_no         int not null default 1,
  item_id         uuid not null references items(id),
  warehouse_id    uuid not null references warehouses(id),
  location_id     uuid references storage_locations(id),
  -- User-entered quantity is ALWAYS positive (business rule).
  quantity        numeric(18,4) not null check (quantity > 0),
  -- Direction (+1 in / -1 out) is frozen at posting time; balances = SUM(this).
  signed_quantity numeric(18,4) not null default 0,
  unit_id         uuid references units(id),
  unit_cost       numeric(18,4) not null default 0 check (unit_cost >= 0),
  total_cost      numeric(18,4) not null default 0,
  batch_no        text,
  serial_no       text,
  expiry_date     date,
  notes           text,
  unique (transaction_id, line_no)
);

create index idx_txn_lines_item_wh
  on stock_transaction_lines(item_id, warehouse_id);
create index idx_txn_lines_txn
  on stock_transaction_lines(transaction_id);

-- ---------------------------------------------------------------------------
-- IMMUTABILITY GUARD
-- Posted / reversed transactions cannot be edited or deleted. Corrections
-- happen ONLY through reversal or adjustment transactions.
-- ---------------------------------------------------------------------------
create or replace function guard_posted_txn() returns trigger
language plpgsql as $$
begin
  if (tg_op = 'DELETE') then
    if old.status in ('posted','reversed') then
      raise exception 'Posted/reversed transaction % cannot be deleted. Use a reversal.', old.ref_no
        using errcode = 'check_violation';
    end if;
    return old;
  end if;

  -- UPDATE: allow the controlled status transitions used by posting/reversal,
  -- but forbid any mutation of a row that is already posted (except the
  -- reversed_by / status='reversed' stamp applied by reverse_stock_transaction).
  if old.status = 'posted' then
    if new.status = 'reversed'
       and new.reversed_by is not null
       and new.txn_type = old.txn_type
       and new.ref_no = old.ref_no then
      return new;      -- the single legal mutation: marking it reversed
    end if;
    raise exception 'Posted transaction % is immutable.', old.ref_no
      using errcode = 'check_violation';
  end if;

  if old.status = 'reversed' then
    raise exception 'Reversed transaction % is immutable.', old.ref_no
      using errcode = 'check_violation';
  end if;

  return new;
end $$;

create trigger trg_guard_posted_txn
  before update or delete on stock_transactions
  for each row execute function guard_posted_txn();

-- Lines are frozen once their header is posted/reversed.
create or replace function guard_posted_lines() returns trigger
language plpgsql as $$
declare v_status stock_txn_status;
begin
  select status into v_status from stock_transactions
    where id = coalesce(new.transaction_id, old.transaction_id);
  if v_status in ('posted','reversed') then
    raise exception 'Cannot modify lines of a % transaction.', v_status
      using errcode = 'check_violation';
  end if;
  return coalesce(new, old);
end $$;

create trigger trg_guard_posted_lines
  before insert or update or delete on stock_transaction_lines
  for each row execute function guard_posted_lines();

-- ---------------------------------------------------------------------------
-- Reservations — soft holds that reduce AVAILABLE but never ON-HAND.
-- ---------------------------------------------------------------------------
create table stock_reservations (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references organisations(id) on delete cascade,
  item_id       uuid not null references items(id),
  warehouse_id  uuid not null references warehouses(id),
  project_id    uuid,                          -- FK added in 0006
  quantity      numeric(18,4) not null check (quantity > 0),
  status        reservation_status not null default 'active',
  reference     text,
  created_by    uuid references profiles(id),
  created_at    timestamptz not null default now(),
  released_at   timestamptz
);
create index idx_resv_item_wh on stock_reservations(item_id, warehouse_id) where status = 'active';
create index idx_resv_project on stock_reservations(project_id) where status = 'active';

-- ---------------------------------------------------------------------------
-- BALANCE VIEWS — derived, never stored.
-- ---------------------------------------------------------------------------
-- On-hand per item/warehouse = sum of signed quantities across posted AND
-- reversed transactions. A reversed original stays in the ledger and is offset
-- by its (posted) reversal, so the two net to zero — never silently removed.
create view v_item_warehouse_onhand as
select
  l.org_id,
  l.item_id,
  l.warehouse_id,
  sum(l.signed_quantity) as on_hand
from stock_transaction_lines l
join stock_transactions t on t.id = l.transaction_id
where t.status in ('posted','reversed')
group by l.org_id, l.item_id, l.warehouse_id;

-- Active reservations per item/warehouse.
create view v_item_warehouse_reserved as
select org_id, item_id, warehouse_id, sum(quantity) as reserved
from stock_reservations
where status = 'active'
group by org_id, item_id, warehouse_id;

-- Combined balance: on_hand, reserved, available (available excludes
-- quarantine/damaged warehouses via warehouses.counts_as_available).
create view v_item_warehouse_balance as
select
  w.org_id,
  oh.item_id,
  w.id  as warehouse_id,
  w.name as warehouse_name,
  w.counts_as_available,
  coalesce(oh.on_hand, 0)                              as on_hand,
  coalesce(r.reserved, 0)                              as reserved,
  case when w.counts_as_available
       then greatest(coalesce(oh.on_hand,0) - coalesce(r.reserved,0), 0)
       else 0 end                                       as available
from warehouses w
join v_item_warehouse_onhand oh on oh.warehouse_id = w.id
left join v_item_warehouse_reserved r
       on r.warehouse_id = w.id and r.item_id = oh.item_id;

-- Org-wide per-item rollup used by the dashboard & item pages.
create view v_item_balance as
select
  b.org_id,
  b.item_id,
  sum(b.on_hand)                                       as on_hand,
  sum(b.reserved)                                      as reserved,
  sum(b.available)                                     as available,
  sum(b.on_hand) filter (where not b.counts_as_available) as unavailable_qty
from v_item_warehouse_balance b
group by b.org_id, b.item_id;

comment on view v_item_balance is
  'Inventory availability formula: available = on_hand - reserved (usable warehouses only).';
