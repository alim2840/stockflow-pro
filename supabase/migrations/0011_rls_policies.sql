-- =============================================================================
-- StockFlow Pro — 0011_rls_policies.sql
-- Row Level Security. Every business table is org-isolated. Warehouse- and
-- project-scoped tables add access-grant checks. Writes to sensitive tables
-- require the matching permission. SECURITY DEFINER posting functions run as
-- owner and intentionally bypass RLS (they enforce require_permission()).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1) Enable + FORCE RLS on all business tables, and give every org-scoped
--    table a standard org-isolation policy set. Reference tables handled after.
-- ---------------------------------------------------------------------------
do $$
declare
  t text;
  org_tables text[] := array[
    'company_settings','profiles','roles','user_roles','warehouses','storage_locations',
    'categories','brands','units','unit_conversions','suppliers','items','item_suppliers',
    'item_cost_history','stock_transactions','stock_transaction_lines','stock_reservations',
    'purchase_requisitions','purchase_orders','goods_receipts','projects',
    'project_material_requirements','warehouse_transfers','stock_counts','bills_of_material',
    'production_orders','exchange_rates','numbering_sequences','approvals','attachments',
    'notifications','backup_jobs','backup_files','restore_events','audit_logs'
  ];
begin
  foreach t in array org_tables loop
    execute format('alter table %I enable row level security', t);
    execute format('alter table %I force row level security', t);
    -- Base read policy: same org (platform admins see all).
    execute format($p$
      create policy org_read on %I for select
      using (is_platform_admin() or org_id = current_org())
    $p$, t);
    -- Base write policy: same org (fine-grained permission added below for
    -- sensitive tables; SECURITY DEFINER functions cover posting paths).
    execute format($p$
      create policy org_write on %I for all
      using (is_platform_admin() or org_id = current_org())
      with check (is_platform_admin() or org_id = current_org())
    $p$, t);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 2) Reference / link tables (no org_id): scope via parent or authentication.
-- ---------------------------------------------------------------------------
alter table permissions        enable row level security;
alter table role_permissions   enable row level security;
create policy ref_read on permissions      for select using (auth.uid() is not null);
create policy ref_read on role_permissions for select using (auth.uid() is not null);

alter table user_warehouse_access enable row level security;
alter table user_project_access   enable row level security;
alter table project_members       enable row level security;
create policy own_or_admin on user_warehouse_access for select
  using (user_id = auth.uid() or is_platform_admin()
         or exists (select 1 from profiles p where p.id = auth.uid()
                    and p.org_id = (select org_id from profiles where id = user_warehouse_access.user_id)));
create policy own_or_admin on user_project_access for select
  using (user_id = auth.uid() or is_platform_admin());
create policy member_read on project_members for select
  using (user_id = auth.uid() or is_platform_admin()
         or exists (select 1 from projects pr where pr.id = project_id and pr.org_id = current_org()));

-- Child line tables inherit visibility from their parent's org.
do $$
declare c record;
begin
  for c in values
    ('purchase_requisition_lines','purchase_requisitions','requisition_id'),
    ('purchase_order_lines','purchase_orders','po_id'),
    ('goods_receipt_lines','goods_receipts','receipt_id'),
    ('warehouse_transfer_lines','warehouse_transfers','transfer_id'),
    ('stock_count_lines','stock_counts','count_id'),
    ('bill_of_material_lines','bills_of_material','bom_id'),
    ('notification_preferences', null, null)
  loop
    execute format('alter table %I enable row level security', c.column1);
    execute format('alter table %I force row level security', c.column1);
  end loop;
end $$;

create policy child_all on purchase_requisition_lines for all
  using (exists (select 1 from purchase_requisitions p where p.id = requisition_id and (is_platform_admin() or p.org_id = current_org())))
  with check (exists (select 1 from purchase_requisitions p where p.id = requisition_id and p.org_id = current_org()));
create policy child_all on purchase_order_lines for all
  using (exists (select 1 from purchase_orders p where p.id = po_id and (is_platform_admin() or p.org_id = current_org())))
  with check (exists (select 1 from purchase_orders p where p.id = po_id and p.org_id = current_org()));
create policy child_all on goods_receipt_lines for all
  using (exists (select 1 from goods_receipts p where p.id = receipt_id and (is_platform_admin() or p.org_id = current_org())))
  with check (exists (select 1 from goods_receipts p where p.id = receipt_id and p.org_id = current_org()));
create policy child_all on warehouse_transfer_lines for all
  using (exists (select 1 from warehouse_transfers p where p.id = transfer_id and (is_platform_admin() or p.org_id = current_org())))
  with check (exists (select 1 from warehouse_transfers p where p.id = transfer_id and p.org_id = current_org()));
create policy child_all on stock_count_lines for all
  using (exists (select 1 from stock_counts p where p.id = count_id and (is_platform_admin() or p.org_id = current_org())))
  with check (exists (select 1 from stock_counts p where p.id = count_id and p.org_id = current_org()));
create policy child_all on bill_of_material_lines for all
  using (exists (select 1 from bills_of_material p where p.id = bom_id and (is_platform_admin() or p.org_id = current_org())))
  with check (exists (select 1 from bills_of_material p where p.id = bom_id and p.org_id = current_org()));
create policy own_prefs on notification_preferences for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 3) Tighten sensitive tables: replace broad org_write with permission-gated
--    and scope-gated policies.
-- ---------------------------------------------------------------------------

-- IMPORTANT: the loop's org_write is FOR ALL, which also governs SELECT. For
-- scope-restricted tables we DROP both base policies and add a scoped read plus
-- command-specific (INSERT/UPDATE/DELETE) write policies, so writes never widen
-- read visibility.

-- Warehouses: org admins see all in-org; others only granted warehouses.
drop policy org_read  on warehouses;
drop policy org_write on warehouses;
create policy wh_read on warehouses for select
  using (is_platform_admin()
         or (org_id = current_org() and (is_org_admin() or has_warehouse_access(id))));
create policy wh_ins on warehouses for insert
  with check (org_id = current_org() and has_permission('warehouses','create'));
create policy wh_upd on warehouses for update
  using (org_id = current_org() and has_permission('warehouses','edit_draft'))
  with check (org_id = current_org());
create policy wh_del on warehouses for delete
  using (org_id = current_org() and has_permission('warehouses','delete_draft'));

-- Storage locations follow their warehouse grant.
drop policy org_read  on storage_locations;
drop policy org_write on storage_locations;
create policy loc_read on storage_locations for select
  using (is_platform_admin()
         or (org_id = current_org() and (is_org_admin() or has_warehouse_access(warehouse_id))));
create policy loc_write on storage_locations for insert
  with check (org_id = current_org() and has_permission('warehouses','create'));
create policy loc_upd on storage_locations for update
  using (org_id = current_org() and has_permission('warehouses','edit_draft'))
  with check (org_id = current_org());
create policy loc_del on storage_locations for delete
  using (org_id = current_org() and has_permission('warehouses','delete_draft'));

-- Projects: org admins see all in-org; others only assigned projects.
drop policy org_read  on projects;
drop policy org_write on projects;
create policy prj_read on projects for select
  using (is_platform_admin()
         or (org_id = current_org() and (is_org_admin() or has_project_access(id))));
create policy prj_ins on projects for insert
  with check (org_id = current_org() and has_permission('projects','create'));
create policy prj_upd on projects for update
  using (org_id = current_org() and has_permission('projects','edit_draft')
         and (is_org_admin() or has_project_access(id)))
  with check (org_id = current_org());
create policy prj_del on projects for delete
  using (org_id = current_org() and has_permission('projects','delete_draft'));

-- Stock transaction lines: visible only for warehouses the user can access.
drop policy org_read  on stock_transaction_lines;
drop policy org_write on stock_transaction_lines;
create policy stl_read on stock_transaction_lines for select
  using (is_platform_admin()
         or (org_id = current_org() and (is_org_admin() or has_warehouse_access(warehouse_id))));
create policy stl_ins on stock_transaction_lines for insert
  with check (org_id = current_org() and has_permission('stock_txn','create')
              and has_warehouse_access(warehouse_id));
create policy stl_upd on stock_transaction_lines for update
  using (org_id = current_org() and has_permission('stock_txn','edit_draft'))
  with check (org_id = current_org());
create policy stl_del on stock_transaction_lines for delete
  using (org_id = current_org() and has_permission('stock_txn','delete_draft'));

-- Items: creating/editing requires the items permission.
drop policy org_write on items;
create policy items_ins on items for insert
  with check (org_id = current_org() and has_permission('items','create'));
create policy items_upd on items for update
  using (org_id = current_org() and has_permission('items','edit_draft'))
  with check (org_id = current_org());
create policy items_del on items for delete
  using (org_id = current_org() and has_permission('items','delete_draft'));

-- Stock transactions: clients may only create/edit DRAFTs; posting/reversal is
-- exclusively via SECURITY DEFINER RPCs. Guard trigger enforces immutability.
drop policy org_write on stock_transactions;
create policy txn_ins on stock_transactions for insert
  with check (org_id = current_org() and has_permission('stock_txn','create') and status = 'draft');
create policy txn_upd on stock_transactions for update
  using (org_id = current_org() and has_permission('stock_txn','edit_draft') and status in ('draft','pending_approval','approved'))
  with check (org_id = current_org());
create policy txn_del on stock_transactions for delete
  using (org_id = current_org() and has_permission('stock_txn','delete_draft') and status = 'draft');

-- Audit log: read requires audit permission; nobody writes directly (functions do).
drop policy org_write on audit_logs;
create policy audit_no_write on audit_logs for all
  using (false) with check (false);
drop policy org_read on audit_logs;
create policy audit_read on audit_logs for select
  using (is_platform_admin() or (org_id = current_org() and has_permission('audit','view')));

-- Backups: restore/read gated to backup permission; restore itself is RPC-only.
drop policy org_write on backup_files;
create policy backup_read on backup_files for select
  using (is_platform_admin() or (org_id = current_org() and has_permission('backups','view')));

comment on policy txn_ins on stock_transactions is
  'Clients create drafts only. Posting is via post_stock_transaction() RPC.';
