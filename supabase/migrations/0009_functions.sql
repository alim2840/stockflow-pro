-- =============================================================================
-- StockFlow Pro — 0009_functions.sql
-- Business logic that MUST live in the database: permission checks, race-safe
-- numbering, atomic posting, reversal, reservations, moving-average costing.
-- All state-changing functions are SECURITY DEFINER with a pinned search_path.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Auth / permission helpers
-- ---------------------------------------------------------------------------
create or replace function current_uid() returns uuid
language sql stable as $$ select auth.uid() $$;

create or replace function current_org() returns uuid
language sql stable security definer set search_path = public as $$
  select org_id from profiles where id = auth.uid()
$$;

create or replace function is_platform_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select is_platform_admin from profiles where id = auth.uid()), false)
$$;

-- Does the current user hold (module, action)? Platform admins always do.
create or replace function has_permission(p_module text, p_action perm_action)
returns boolean
language sql stable security definer set search_path = public as $$
  select is_platform_admin()
      or exists (
        select 1
        from user_roles ur
        join role_permissions rp on rp.role_id = ur.role_id
        join permissions p       on p.id = rp.permission_id
        where ur.user_id = auth.uid()
          and p.module = p_module
          and p.action = p_action
      )
$$;

create or replace function require_permission(p_module text, p_action perm_action)
returns void
language plpgsql as $$
begin
  if not has_permission(p_module, p_action) then
    raise exception 'Permission denied: % on %', p_action, p_module
      using errcode = 'insufficient_privilege';
  end if;
end $$;

create or replace function has_warehouse_access(p_wh uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select is_platform_admin()
      or exists (select 1 from user_warehouse_access
                 where user_id = auth.uid() and warehouse_id = p_wh)
$$;

create or replace function has_project_access(p_prj uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select is_platform_admin()
      or exists (select 1 from user_project_access
                 where user_id = auth.uid() and project_id = p_prj)
$$;

-- Org-wide administrator: sees every warehouse/project WITHIN their own org
-- (company admin holds settings.manage_settings). Combined with an org_id check
-- in each policy so it never leaks across organisations.
create or replace function is_org_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select is_platform_admin() or has_permission('settings','manage_settings')
$$;

-- ---------------------------------------------------------------------------
-- Generic updated_at / version bump
-- ---------------------------------------------------------------------------
create or replace function bump_row_version() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  if tg_op = 'UPDATE' and new.version = old.version then
    new.version := old.version + 1;
  end if;
  return new;
end $$;

create trigger trg_items_bump   before update on items
  for each row execute function bump_row_version();
create trigger trg_projects_bump before update on projects
  for each row execute function bump_row_version();
create trigger trg_po_bump      before update on purchase_orders
  for each row execute function bump_row_version();

-- ---------------------------------------------------------------------------
-- CONCURRENCY-SAFE REFERENCE NUMBERS
-- The upsert takes a row lock on (org, doc_type, year); simultaneous callers
-- serialise and can never receive the same value -> no duplicate refs.
-- ---------------------------------------------------------------------------
create or replace function next_reference(
  p_org uuid, p_doc_type text, p_prefix text, p_year int default 0, p_padding int default 6
) returns text
language plpgsql security definer set search_path = public as $$
declare v_val bigint;
begin
  insert into numbering_sequences(org_id, doc_type, year, prefix, padding, current_value)
  values (p_org, p_doc_type, p_year, p_prefix, p_padding, 1)
  on conflict (org_id, doc_type, year)
    do update set current_value = numbering_sequences.current_value + 1
  returning current_value into v_val;

  return p_prefix
       || case when p_year > 0 then '-' || p_year::text else '' end
       || '-' || lpad(v_val::text, p_padding, '0');
end $$;

-- ---------------------------------------------------------------------------
-- Direction resolver. +1 increases warehouse on-hand, -1 decreases, 0 means
-- the posting routine sets signed_quantity explicitly per line
-- (project_consumption, count_variance, reversal, assembly/disassembly).
-- ---------------------------------------------------------------------------
create or replace function txn_direction(p_type stock_txn_type) returns int
language sql immutable as $$
  select case p_type
    when 'opening_balance'        then  1
    when 'purchase_receipt'       then  1
    when 'customer_return'        then  1
    when 'project_return'         then  1
    when 'transfer_in'            then  1
    when 'adjustment_increase'    then  1
    when 'supplier_return'        then -1
    when 'project_issue'          then -1
    when 'general_issue'          then -1
    when 'production_consumption' then -1
    when 'transfer_out'           then -1
    when 'damage'                 then -1
    when 'expiry'                 then -1
    when 'loss'                   then -1
    when 'adjustment_decrease'    then -1
    else 0    -- project_consumption, count_variance, reversal, assembly_*
  end
$$;

-- ---------------------------------------------------------------------------
-- POST A STOCK TRANSACTION  (atomic, idempotent, negative-stock-safe)
-- ---------------------------------------------------------------------------
create or replace function post_stock_transaction(p_txn_id uuid)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_txn        stock_transactions;
  v_allow_neg  boolean;
  v_dir        int;
  rec          record;
  v_onhand     numeric(18,4);
  v_old_qty    numeric(18,4);
  v_old_avg    numeric(18,4);
  v_new_avg    numeric(18,4);
begin
  perform require_permission('stock_txn', 'post');

  -- Lock the header to serialise concurrent posts of the SAME transaction.
  select * into v_txn from stock_transactions where id = p_txn_id for update;
  if not found then
    raise exception 'Transaction % not found', p_txn_id using errcode = 'no_data_found';
  end if;

  -- Idempotent: posting an already-posted txn is a no-op (safe retry).
  if v_txn.status = 'posted' then
    return v_txn.id;
  end if;
  if v_txn.status in ('reversed','rejected') then
    raise exception 'Transaction % is % and cannot be posted', v_txn.ref_no, v_txn.status
      using errcode = 'check_violation';
  end if;

  select allow_negative_stock into v_allow_neg from company_settings where org_id = v_txn.org_id;
  v_dir := txn_direction(v_txn.txn_type);

  -- Freeze signed_quantity + total_cost on every line (header still draft here,
  -- so the line guard permits these writes).
  update stock_transaction_lines l
     set signed_quantity =
           case when v_dir = 0 then l.signed_quantity     -- caller pre-set sign
                else l.quantity * v_dir end,
         total_cost = round(l.quantity * l.unit_cost, 4)
   where l.transaction_id = p_txn_id;

  -- Negative-stock guard, aggregated per (item, warehouse), with an advisory
  -- lock per bucket so concurrent posts to the same item/warehouse serialise.
  for rec in
    select item_id, warehouse_id, sum(signed_quantity) as delta
    from stock_transaction_lines
    where transaction_id = p_txn_id
    group by item_id, warehouse_id
  loop
    perform pg_advisory_xact_lock(
      hashtextextended(rec.item_id::text || ':' || rec.warehouse_id::text, 0));

    select coalesce(sum(l.signed_quantity), 0) into v_onhand
    from stock_transaction_lines l
    join stock_transactions t on t.id = l.transaction_id
    where t.status in ('posted','reversed')   -- match balance view (reversal-safe)
      and l.item_id = rec.item_id
      and l.warehouse_id = rec.warehouse_id;

    if (v_onhand + rec.delta) < 0 and not v_allow_neg then
      raise exception
        'Negative stock blocked: item % at warehouse % would fall to % (on hand %, change %).',
        rec.item_id, rec.warehouse_id, v_onhand + rec.delta, v_onhand, rec.delta
        using errcode = 'check_violation',
              hint = 'Enable controlled negative stock in settings, or receive/transfer stock first.';
    end if;
  end loop;

  -- Moving-average cost update for value-bearing inbound receipts.
  if v_txn.txn_type in ('purchase_receipt','opening_balance','assembly_output') then
    for rec in
      select item_id, sum(quantity) qty, sum(total_cost) cost
      from stock_transaction_lines
      where transaction_id = p_txn_id and unit_cost > 0
      group by item_id
    loop
      select coalesce(sum(available),0), average_cost
        into v_old_qty, v_old_avg
      from items i
      left join v_item_balance b on b.item_id = i.id
      where i.id = rec.item_id
      group by i.average_cost;

      v_new_avg := case
        when (coalesce(v_old_qty,0) + rec.qty) > 0
        then round(((coalesce(v_old_qty,0) * coalesce(v_old_avg,0)) + rec.cost)
                   / (coalesce(v_old_qty,0) + rec.qty), 4)
        else v_old_avg end;

      update items set average_cost = v_new_avg where id = rec.item_id;
      insert into item_cost_history(org_id, item_id, average_cost, source_txn_id, note)
      values (v_txn.org_id, rec.item_id, v_new_avg, p_txn_id, 'moving average on ' || v_txn.txn_type);
    end loop;
  end if;

  -- Flip to posted (immutable from here; guard trigger enforces it).
  update stock_transactions
     set status = 'posted', posted_at = now(), posted_by = auth.uid()
   where id = p_txn_id;

  insert into audit_logs(org_id, user_id, action, module, record_type, record_id, reference_no, result)
  values (v_txn.org_id, auth.uid(), 'post', 'stock_txn', 'stock_transaction',
          p_txn_id, v_txn.ref_no, 'success');

  return p_txn_id;
end $$;

-- ---------------------------------------------------------------------------
-- REVERSE A POSTED TRANSACTION  (equal & opposite entries; single-use)
-- ---------------------------------------------------------------------------
create or replace function reverse_stock_transaction(p_txn_id uuid, p_reason text)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_txn  stock_transactions;
  v_new  uuid;
  v_ref  text;
begin
  perform require_permission('stock_txn', 'reverse');

  select * into v_txn from stock_transactions where id = p_txn_id for update;
  if not found then
    raise exception 'Transaction % not found', p_txn_id using errcode = 'no_data_found';
  end if;
  if v_txn.status <> 'posted' then
    raise exception 'Only posted transactions can be reversed (% is %)', v_txn.ref_no, v_txn.status
      using errcode = 'check_violation';
  end if;
  if v_txn.reversed_by is not null then
    raise exception 'Transaction % is already reversed', v_txn.ref_no
      using errcode = 'check_violation';   -- prevents double reversal
  end if;

  v_ref := next_reference(v_txn.org_id, 'REV', 'REV', extract(year from now())::int);

  insert into stock_transactions(
    org_id, ref_no, txn_type, status, txn_date, project_id, supplier_id,
    currency, exchange_rate, reason, reversal_of, created_by)
  values (
    v_txn.org_id, v_ref, 'reversal', 'draft', (now() at time zone 'utc')::date,
    v_txn.project_id, v_txn.supplier_id, v_txn.currency, v_txn.exchange_rate,
    coalesce(p_reason,'reversal of ' || v_txn.ref_no), p_txn_id, auth.uid())
  returning id into v_new;

  -- Opposite signs; quantity stays positive per business rule.
  insert into stock_transaction_lines(
    org_id, transaction_id, line_no, item_id, warehouse_id, location_id,
    quantity, signed_quantity, unit_id, unit_cost, total_cost, batch_no, serial_no)
  select org_id, v_new, line_no, item_id, warehouse_id, location_id,
         quantity, -signed_quantity, unit_id, unit_cost, total_cost, batch_no, serial_no
  from stock_transaction_lines where transaction_id = p_txn_id;

  perform post_stock_transaction(v_new);

  -- Stamp the original as reversed (the single mutation the guard permits).
  update stock_transactions
     set status = 'reversed', reversed_by = v_new
   where id = p_txn_id;

  insert into audit_logs(org_id, user_id, action, module, record_type, record_id,
                         reference_no, reason, related_id, result)
  values (v_txn.org_id, auth.uid(), 'reverse', 'stock_txn', 'stock_transaction',
          p_txn_id, v_txn.ref_no, p_reason, v_new, 'success');

  return v_new;
end $$;

-- ---------------------------------------------------------------------------
-- RESERVATIONS  (reduce available, never on-hand)
-- ---------------------------------------------------------------------------
create or replace function create_reservation(
  p_item uuid, p_wh uuid, p_project uuid, p_qty numeric, p_reference text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_org uuid; v_avail numeric; v_id uuid;
begin
  perform require_permission('stock_txn', 'create');
  if p_qty <= 0 then
    raise exception 'Reservation quantity must be positive' using errcode = 'check_violation';
  end if;
  select org_id into v_org from items where id = p_item;

  perform pg_advisory_xact_lock(hashtextextended(p_item::text || ':' || p_wh::text, 0));
  select coalesce(available,0) into v_avail
  from v_item_warehouse_balance where item_id = p_item and warehouse_id = p_wh;

  if coalesce(v_avail,0) < p_qty then
    raise exception 'Insufficient available stock to reserve (% available, % requested)', coalesce(v_avail,0), p_qty
      using errcode = 'check_violation';
  end if;

  insert into stock_reservations(org_id, item_id, warehouse_id, project_id, quantity, reference, created_by)
  values (v_org, p_item, p_wh, p_project, p_qty, p_reference, auth.uid())
  returning id into v_id;
  return v_id;
end $$;

create or replace function release_reservation(p_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  update stock_reservations
     set status = 'released', released_at = now()
   where id = p_id and status = 'active';
end $$;
