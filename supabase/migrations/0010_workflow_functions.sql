-- =============================================================================
-- StockFlow Pro — 0010_workflow_functions.sql
-- Higher-level document posters. Each builds ledger transactions then calls
-- post_stock_transaction() so all inventory effects flow through one gate.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Post a Goods Receipt -> purchase_receipt ledger txn; updates PO fulfilment.
-- Double-posting is blocked (status check) and over-receipt is blocked by the
-- purchase_order_lines.chk_not_over_received constraint.
-- ---------------------------------------------------------------------------
create or replace function post_goods_receipt(p_receipt_id uuid)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_r   goods_receipts;
  v_txn uuid;
  rec   record;
  v_open int;
begin
  perform require_permission('purchasing', 'post');

  select * into v_r from goods_receipts where id = p_receipt_id for update;
  if not found then raise exception 'Receipt % not found', p_receipt_id; end if;
  if v_r.status <> 'draft' then
    raise exception 'Receipt % already %; cannot re-post', v_r.ref_no, v_r.status
      using errcode = 'check_violation';
  end if;

  -- Warehouse lives on the lines; the header carries supplier/PO context.
  insert into stock_transactions(org_id, ref_no, txn_type, status, txn_date,
        supplier_id, purchase_order_id, goods_receipt_id, created_by)
  values (v_r.org_id, v_r.ref_no, 'purchase_receipt', 'draft', v_r.receipt_date,
          v_r.supplier_id, v_r.po_id, v_r.id, auth.uid())
  returning id into v_txn;

  insert into stock_transaction_lines(org_id, transaction_id, line_no, item_id,
        warehouse_id, location_id, quantity, unit_cost, batch_no, serial_no, expiry_date)
  select v_r.org_id, v_txn, row_number() over (order by grl.id), grl.item_id,
         v_r.warehouse_id, grl.location_id, grl.received_qty, grl.unit_cost,
         grl.batch_no, grl.serial_no, grl.expiry_date
  from goods_receipt_lines grl where grl.receipt_id = p_receipt_id;

  -- Update PO line fulfilment (constraint blocks over-receipt atomically).
  for rec in
    select grl.po_line_id, grl.received_qty
    from goods_receipt_lines grl
    where grl.receipt_id = p_receipt_id and grl.po_line_id is not null
  loop
    update purchase_order_lines
       set received_qty = received_qty + rec.received_qty
     where id = rec.po_line_id;
  end loop;

  perform post_stock_transaction(v_txn);

  update goods_receipts
     set status = 'posted', posted_at = now(), posted_by = auth.uid(), stock_txn_id = v_txn
   where id = p_receipt_id;

  -- Recompute PO status from line fulfilment.
  if v_r.po_id is not null then
    select count(*) into v_open from purchase_order_lines
      where po_id = v_r.po_id and received_qty < ordered_qty;
    update purchase_orders
       set status = case when v_open = 0 then 'received' else 'partially_received' end
     where id = v_r.po_id and status not in ('closed','cancelled');
  end if;

  return v_txn;
end $$;

-- ---------------------------------------------------------------------------
-- Warehouse transfer — dispatch (source -1). In-transit is DERIVED from the
-- transfer record (dispatched & not fully received), not from a fake balance.
-- ---------------------------------------------------------------------------
create or replace function post_transfer_dispatch(p_transfer_id uuid)
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_t warehouse_transfers; v_txn uuid;
begin
  perform require_permission('stock_txn', 'post');
  select * into v_t from warehouse_transfers where id = p_transfer_id for update;
  if not found then raise exception 'Transfer % not found', p_transfer_id; end if;
  if v_t.status not in ('draft','approved') then
    raise exception 'Transfer % cannot be dispatched from status %', v_t.ref_no, v_t.status
      using errcode = 'check_violation';
  end if;

  insert into stock_transactions(org_id, ref_no, txn_type, status, transfer_id, created_by)
  values (v_t.org_id, v_t.ref_no || '-OUT', 'transfer_out', 'draft', v_t.id, auth.uid())
  returning id into v_txn;

  insert into stock_transaction_lines(org_id, transaction_id, line_no, item_id, warehouse_id, quantity, unit_id)
  select v_t.org_id, v_txn, row_number() over (order by tl.id), tl.item_id, v_t.source_wh, tl.quantity, tl.unit_id
  from warehouse_transfer_lines tl where tl.transfer_id = p_transfer_id;

  perform post_stock_transaction(v_txn);   -- decrements source; blocks if short

  update warehouse_transfers
     set status = 'dispatched', dispatched_at = now(), dispatch_txn_id = v_txn
   where id = p_transfer_id;
  return v_txn;
end $$;

-- Warehouse transfer — receive at destination (dest +1); completes transfer.
create or replace function post_transfer_receive(p_transfer_id uuid)
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_t warehouse_transfers; v_txn uuid;
begin
  perform require_permission('stock_txn', 'post');
  select * into v_t from warehouse_transfers where id = p_transfer_id for update;
  if not found then raise exception 'Transfer % not found', p_transfer_id; end if;
  if v_t.status <> 'dispatched' then
    raise exception 'Transfer % must be dispatched before receipt (is %)', v_t.ref_no, v_t.status
      using errcode = 'check_violation';   -- cannot complete twice
  end if;

  insert into stock_transactions(org_id, ref_no, txn_type, status, transfer_id, created_by)
  values (v_t.org_id, v_t.ref_no || '-IN', 'transfer_in', 'draft', v_t.id, auth.uid())
  returning id into v_txn;

  insert into stock_transaction_lines(org_id, transaction_id, line_no, item_id, warehouse_id, quantity, unit_id)
  select v_t.org_id, v_txn, row_number() over (order by tl.id), tl.item_id, v_t.dest_wh, tl.quantity, tl.unit_id
  from warehouse_transfer_lines tl where tl.transfer_id = p_transfer_id;

  perform post_stock_transaction(v_txn);

  update warehouse_transfer_lines set received_qty = quantity where transfer_id = p_transfer_id;
  update warehouse_transfers
     set status = 'completed', received_at = now(), receipt_txn_id = v_txn
   where id = p_transfer_id;
  return v_txn;
end $$;

-- ---------------------------------------------------------------------------
-- Post an approved stock count -> count_variance adjustment (per-line signs).
-- Nothing changes stock until an APPROVED count is posted here.
-- ---------------------------------------------------------------------------
create or replace function post_stock_count(p_count_id uuid)
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_c stock_counts; v_txn uuid;
begin
  perform require_permission('stock_txn', 'post');
  select * into v_c from stock_counts where id = p_count_id for update;
  if not found then raise exception 'Count % not found', p_count_id; end if;
  if v_c.status <> 'approved' then
    raise exception 'Only an approved count can be posted (% is %)', v_c.ref_no, v_c.status
      using errcode = 'check_violation';
  end if;

  insert into stock_transactions(org_id, ref_no, txn_type, status, count_id, reason, created_by)
  values (v_c.org_id, v_c.ref_no, 'count_variance', 'draft', v_c.id, 'stock count adjustment', auth.uid())
  returning id into v_txn;

  -- signed_quantity = variance (may be + or -); quantity is its magnitude.
  insert into stock_transaction_lines(org_id, transaction_id, line_no, item_id,
        warehouse_id, location_id, quantity, signed_quantity)
  select v_c.org_id, v_txn, row_number() over (order by cl.id), cl.item_id,
         v_c.warehouse_id, cl.location_id, abs(cl.variance), cl.variance
  from stock_count_lines cl where cl.count_id = p_count_id and cl.variance <> 0;

  perform post_stock_transaction(v_txn);   -- dir(count_variance)=0 keeps our signs

  update stock_counts
     set status = 'posted', posted_at = now(), adjustment_txn_id = v_txn
   where id = p_count_id;
  return v_txn;
end $$;
