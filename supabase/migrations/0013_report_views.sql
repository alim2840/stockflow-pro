-- =============================================================================
-- StockFlow Pro — 0013_report_views.sql
-- Read-optimised views for the dashboard and reports. All figures derive from
-- the posted ledger; the browser never sums the ledger client-side.
-- =============================================================================

-- Item with balances + valuation (one row per item).
create view v_item_full as
select
  i.*,
  coalesce(b.on_hand, 0)   as on_hand,
  coalesce(b.reserved, 0)  as reserved,
  coalesce(b.available, 0) as available,
  round(coalesce(b.on_hand,0) * i.average_cost, 4) as stock_value,
  cat.name as category_name,
  br.name  as brand_name,
  u.code   as base_unit_code
from items i
left join v_item_balance b on b.item_id = i.id
left join categories cat on cat.id = i.category_id
left join brands br      on br.id = i.brand_id
left join units u        on u.id = i.base_unit_id;

-- Low-stock: usable available at or below reorder point (active, stockable).
create view v_low_stock as
select org_id, id as item_id, ref_no, sku, name, available, reorder_point, min_stock,
       reorder_qty, average_cost
from v_item_full
where is_active
  and item_type not in ('service','non_stock')
  and available <= greatest(reorder_point, min_stock);

-- Inventory valuation (per warehouse, only usable warehouses count as value on hand).
create view v_inventory_valuation as
select
  b.org_id,
  b.warehouse_id,
  w.name as warehouse_name,
  b.item_id,
  b.on_hand,
  i.average_cost,
  round(b.on_hand * i.average_cost, 4) as value
from v_item_warehouse_balance b
join items i on i.id = b.item_id
join warehouses w on w.id = b.warehouse_id
where b.on_hand <> 0;

-- Flattened stock ledger for the ledger/movement reports.
create view v_stock_ledger as
select
  t.org_id, t.id as txn_id, t.ref_no, t.txn_type, t.status, t.txn_date, t.posted_at,
  l.item_id, it.sku, it.name as item_name,
  l.warehouse_id, w.name as warehouse_name,
  l.quantity, l.signed_quantity, l.unit_cost, l.total_cost,
  t.project_id, t.supplier_id,
  t.created_by, t.posted_by
from stock_transactions t
join stock_transaction_lines l on l.transaction_id = t.id
join items it on it.id = l.item_id
join warehouses w on w.id = l.warehouse_id;

-- Per-org dashboard KPIs (single row). Month windows use posted_at (UTC).
create view v_dashboard_kpis as
select
  o.id as org_id,
  (select round(coalesce(sum(on_hand * average_cost),0),2) from v_item_full f where f.org_id = o.id) as total_inventory_value,
  (select count(*) from items i where i.org_id = o.id and i.is_active)                                as total_items,
  (select coalesce(sum(on_hand),0)  from v_item_balance b where b.org_id = o.id)                      as total_on_hand,
  (select coalesce(sum(available),0) from v_item_balance b where b.org_id = o.id)                     as total_available,
  (select coalesce(sum(reserved),0) from v_item_balance b where b.org_id = o.id)                      as total_reserved,
  (select count(*) from v_low_stock ls where ls.org_id = o.id and ls.available > 0)                   as low_stock_items,
  (select count(*) from v_low_stock ls where ls.org_id = o.id and ls.available <= 0)                  as out_of_stock_items,
  (select count(*) from projects p where p.org_id = o.id and p.status = 'active')                     as active_projects,
  (select count(*) from purchase_orders p where p.org_id = o.id and p.status in ('approved','partially_received')) as pending_pos,
  (select count(*) from approvals a where a.org_id = o.id and a.status = 'pending')                   as pending_approvals,
  (select coalesce(sum(l.quantity),0) from stock_transactions t
     join stock_transaction_lines l on l.transaction_id = t.id
     where t.org_id = o.id and t.status='posted' and t.txn_type='purchase_receipt'
       and t.posted_at >= date_trunc('month', now()))                                                as received_this_month,
  (select coalesce(sum(l.quantity),0) from stock_transactions t
     join stock_transaction_lines l on l.transaction_id = t.id
     where t.org_id = o.id and t.status='posted'
       and t.txn_type in ('project_consumption','general_issue','production_consumption')
       and t.posted_at >= date_trunc('month', now()))                                                as consumed_this_month,
  (select round(coalesce(sum(b.on_hand * i.average_cost),0),2)
     from v_item_warehouse_balance b join warehouses w on w.id=b.warehouse_id
     join items i on i.id=b.item_id
     where b.org_id = o.id and w.kind = 'damaged')                                                    as damaged_value
from organisations o;

comment on view v_dashboard_kpis is 'One row per org. Every card on the dashboard reads from here.';
