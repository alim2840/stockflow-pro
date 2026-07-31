-- =============================================================================
-- StockFlow Pro — 0006_projects.sql
-- Projects, membership, material requirements, and the per-project material
-- balance view. Key rule: ISSUED and CONSUMED are separate events.
-- =============================================================================

create table projects (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid not null references organisations(id) on delete cascade,
  ref_no         text not null,               -- PRJ-2026-0001
  code           text not null,
  name           text not null,
  description    text,
  customer       text,
  manager_id     uuid references profiles(id),
  country_code   char(2),
  status         project_status not null default 'planning',
  priority       text,
  budget         numeric(18,4),
  currency       char(3),
  start_date     date,
  target_date    date,
  actual_end     date,
  tags           text[],
  notes          text,
  archived_at    timestamptz,
  created_by     uuid references profiles(id),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  version        int not null default 1,
  unique (org_id, ref_no),
  unique (org_id, code)
);
create index idx_projects_status on projects(org_id, status);

create table project_members (
  project_id  uuid not null references projects(id) on delete cascade,
  user_id     uuid not null references profiles(id) on delete cascade,
  role_in_project text,
  primary key (project_id, user_id)
);

create table project_material_requirements (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references organisations(id) on delete cascade,
  project_id    uuid not null references projects(id) on delete cascade,
  item_id       uuid not null references items(id),
  required_qty  numeric(18,4) not null check (required_qty > 0),
  unit_id       uuid references units(id),
  needed_by     date,
  notes         text,
  created_at    timestamptz not null default now(),
  unique (project_id, item_id)
);

-- Warehouses assigned to a project (scopes issue/return sources).
create table project_warehouses (
  project_id    uuid not null references projects(id) on delete cascade,
  warehouse_id  uuid not null references warehouses(id) on delete cascade,
  primary key (project_id, warehouse_id)
);

-- Deferred FKs from earlier migrations now that projects exists.
alter table stock_transactions
  add constraint fk_txn_project foreign key (project_id) references projects(id);
alter table stock_reservations
  add constraint fk_resv_project foreign key (project_id) references projects(id);
alter table user_project_access
  add constraint fk_upa_project foreign key (project_id) references projects(id) on delete cascade;
alter table purchase_orders
  add constraint fk_po_project foreign key (project_id) references projects(id);
alter table purchase_requisitions
  add constraint fk_req_project foreign key (project_id) references projects(id);

-- ---------------------------------------------------------------------------
-- Per-project material ledger view.
--   issued    = project_issue           (stock left warehouse FOR the project)
--   consumed  = project_consumption     (actually used up)
--   returned  = project_return          (came back to warehouse)
--   damaged   = damage txns tagged to project
--   with_project = issued - consumed - returned - damaged  (still held)
-- ---------------------------------------------------------------------------
create view v_project_material_balance as
with moved as (
  select
    t.org_id, t.project_id, l.item_id, t.txn_type, l.quantity, l.total_cost
  from stock_transactions t
  join stock_transaction_lines l on l.transaction_id = t.id
  where t.status = 'posted' and t.project_id is not null
)
select
  m.org_id,
  m.project_id,
  m.item_id,
  coalesce(r.required_qty, 0)                                              as required,
  coalesce(sum(m.quantity) filter (where m.txn_type = 'project_issue'), 0)        as issued,
  coalesce(sum(m.quantity) filter (where m.txn_type = 'project_consumption'), 0)  as consumed,
  coalesce(sum(m.quantity) filter (where m.txn_type = 'project_return'), 0)       as returned,
  coalesce(sum(m.quantity) filter (where m.txn_type in ('damage','loss','expiry')), 0) as damaged,
  coalesce(sum(m.total_cost) filter (where m.txn_type = 'project_consumption'), 0) as consumed_cost
from moved m
left join project_material_requirements r
       on r.project_id = m.project_id and r.item_id = m.item_id
group by m.org_id, m.project_id, m.item_id, r.required_qty;

comment on view v_project_material_balance is
  'with_project (still held) = issued - consumed - returned - damaged. Issued != consumed.';
