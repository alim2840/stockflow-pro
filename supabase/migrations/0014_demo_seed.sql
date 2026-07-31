-- =============================================================================
-- StockFlow Pro — 0014_demo_seed.sql
-- Realistic demo data for "Mindtune Innovations" that exercises EVERY workflow:
-- partial receipt, reservation, issue, partial consumption, return, damage,
-- transfer (completed + in-transit), low stock, reversed adjustment, count
-- variance. Profiles are created without auth.users rows; scripts/setup.ts links
-- real Supabase Auth users to these ids so the demo accounts can sign in.
--
-- NOTE: seed_post/seed_reverse replicate posting math WITHOUT the permission
-- gate (the seed runs as owner, outside any JWT). They are DROPPED at the end
-- so they can never be used as a backdoor at runtime.
-- =============================================================================

create or replace function seed_post(p_txn uuid) returns void
language plpgsql as $$
declare v_type stock_txn_type; v_dir int;
begin
  select txn_type into v_type from stock_transactions where id = p_txn;
  v_dir := txn_direction(v_type);
  update stock_transaction_lines
     set signed_quantity = case when v_dir = 0 then signed_quantity else quantity * v_dir end,
         total_cost = round(quantity * unit_cost, 4)
   where transaction_id = p_txn;
  update stock_transactions set status='posted', posted_at = now() where id = p_txn;
end $$;

create or replace function seed_reverse(p_txn uuid, p_reason text) returns uuid
language plpgsql as $$
declare v_txn stock_transactions; v_new uuid; v_ref text;
begin
  select * into v_txn from stock_transactions where id = p_txn;
  v_ref := next_reference(v_txn.org_id,'REV','REV',2026);
  insert into stock_transactions(org_id,ref_no,txn_type,status,reversal_of,reason,created_by)
    values (v_txn.org_id,v_ref,'reversal','draft',p_txn,p_reason,v_txn.created_by)
    returning id into v_new;
  insert into stock_transaction_lines(org_id,transaction_id,line_no,item_id,warehouse_id,quantity,signed_quantity,unit_cost,total_cost)
    select org_id,v_new,line_no,item_id,warehouse_id,quantity,-signed_quantity,unit_cost,total_cost
    from stock_transaction_lines where transaction_id = p_txn;
  perform seed_post(v_new);
  update stock_transactions set status='reversed', reversed_by=v_new where id = p_txn;
  return v_new;
end $$;

do $seed$
declare
  v_org uuid; v_admin uuid; v_invmgr uuid; v_pm uuid; v_store uuid; v_acct uuid; v_viewer uuid;
  wh_main uuid; wh_rnd uuid; wh_prod uuid; wh_qc uuid; wh_dmg uuid; wh_us uuid; wh_transit uuid;
  cat_elec uuid; cat_mech uuid; cat_pack uuid; u_pcs uuid;
  sup1 uuid; sup2 uuid;
  prj uuid; po1 uuid; grn1 uuid;
  txn uuid; poline uuid;
  it_batt uuid; it_pcb uuid; it_flex uuid; it_spk uuid; it_mic uuid; it_screw uuid; it_box uuid; it_usb uuid;
begin
  -- ---- Organisation & settings -------------------------------------------
  insert into organisations(name, slug) values ('Mindtune Innovations','mindtune')
    returning id into v_org;
  insert into company_settings(org_id, legal_name, country_code, base_currency, timezone,
      brand_primary, brand_secondary, low_stock_check_enabled)
    values (v_org,'Mindtune Innovations (Pvt) Ltd','PK','PKR','Asia/Karachi',
      '#3730A3','#0891B2', true);

  -- ---- Users (roles assigned below) --------------------------------------
  insert into profiles(id,org_id,email,full_name,status,is_platform_admin,activated_at) values
    (gen_random_uuid(), v_org,'admin@mindtune.test','Ayesha Khan (Admin)','active',true, now())
    returning id into v_admin;
  insert into profiles(id,org_id,email,full_name,status,activated_at) values
    (gen_random_uuid(), v_org,'inventory@mindtune.test','Bilal Ahmed (Inventory)','active',now())
    returning id into v_invmgr;
  insert into profiles(id,org_id,email,full_name,status,activated_at) values
    (gen_random_uuid(), v_org,'pm@mindtune.test','Sara Malik (Project Mgr)','active',now())
    returning id into v_pm;
  insert into profiles(id,org_id,email,full_name,status,activated_at) values
    (gen_random_uuid(), v_org,'store@mindtune.test','Imran Shah (Storekeeper)','active',now())
    returning id into v_store;
  insert into profiles(id,org_id,email,full_name,status,activated_at) values
    (gen_random_uuid(), v_org,'accounts@mindtune.test','Nadia Riaz (Accountant)','active',now())
    returning id into v_acct;
  insert into profiles(id,org_id,email,full_name,status,activated_at) values
    (gen_random_uuid(), v_org,'viewer@mindtune.test','Omar Farooq (Auditor)','active',now())
    returning id into v_viewer;

  insert into user_roles(user_id, role_id, org_id)
    select v_admin, id, v_org from roles where key='super_admin';
  insert into user_roles(user_id, role_id, org_id)
    select v_invmgr, id, v_org from roles where key='inventory_manager';
  insert into user_roles(user_id, role_id, org_id)
    select v_pm, id, v_org from roles where key='project_manager';
  insert into user_roles(user_id, role_id, org_id)
    select v_store, id, v_org from roles where key='storekeeper';
  insert into user_roles(user_id, role_id, org_id)
    select v_acct, id, v_org from roles where key='accountant';
  insert into user_roles(user_id, role_id, org_id)
    select v_viewer, id, v_org from roles where key='viewer';

  -- ---- Warehouses ---------------------------------------------------------
  insert into warehouses(org_id,code,name,kind,country_code,counts_as_available) values
    (v_org,'PK-MAIN','Pakistan Main Warehouse','standard','PK',true)         returning id into wh_main;
  insert into warehouses(org_id,code,name,kind,country_code,counts_as_available) values
    (v_org,'RND','R&D Store','rnd','PK',true)                                returning id into wh_rnd;
  insert into warehouses(org_id,code,name,kind,country_code,counts_as_available) values
    (v_org,'PROD','Production Floor','production','PK',true)                  returning id into wh_prod;
  insert into warehouses(org_id,code,name,kind,country_code,counts_as_available) values
    (v_org,'QC','Quality Control','quality_control','PK',false)              returning id into wh_qc;
  insert into warehouses(org_id,code,name,kind,country_code,counts_as_available) values
    (v_org,'DMG','Damaged Stock','damaged','PK',false)                       returning id into wh_dmg;
  insert into warehouses(org_id,code,name,kind,country_code,counts_as_available) values
    (v_org,'US-WH','US Warehouse','standard','US',true)                      returning id into wh_us;
  insert into warehouses(org_id,code,name,kind,country_code,counts_as_available) values
    (v_org,'TRANSIT','In Transit','in_transit','PK',false)                   returning id into wh_transit;

  -- Access grants (Storekeeper -> PK warehouses only; PM -> project).
  insert into user_warehouse_access(user_id,warehouse_id,can_post)
    select v_store, id, true from warehouses where org_id=v_org and country_code='PK';
  insert into user_warehouse_access(user_id,warehouse_id,can_post)
    select v_invmgr, id, true from warehouses where org_id=v_org;
  insert into user_warehouse_access(user_id,warehouse_id,can_post)
    select v_acct, id, false from warehouses where org_id=v_org;
  insert into user_warehouse_access(user_id,warehouse_id,can_post)
    select v_viewer, id, false from warehouses where org_id=v_org;

  -- ---- Categories & unit --------------------------------------------------
  insert into categories(org_id,name) values (v_org,'Electronics') returning id into cat_elec;
  insert into categories(org_id,name) values (v_org,'Mechanical')  returning id into cat_mech;
  insert into categories(org_id,name) values (v_org,'Packaging')   returning id into cat_pack;
  insert into units(org_id,code,name) values (v_org,'pcs','Pieces') returning id into u_pcs;

  -- ---- Suppliers ----------------------------------------------------------
  insert into suppliers(org_id,ref_no,name,country_code,currency,lead_time_days,created_by)
    values (v_org, next_reference(v_org,'SUP','SUP'),'Shenzhen Components Co.','CN','USD',21,v_admin)
    returning id into sup1;
  insert into suppliers(org_id,ref_no,name,country_code,currency,lead_time_days,created_by)
    values (v_org, next_reference(v_org,'SUP','SUP'),'Karachi Packaging Ltd','PK','PKR',7,v_admin)
    returning id into sup2;

  -- ---- Items (15) ---------------------------------------------------------
  insert into items(org_id,ref_no,sku,name,category_id,base_unit_id,item_type,average_cost,standard_cost,min_stock,reorder_point,reorder_qty,created_by)
  values
   (v_org,next_reference(v_org,'ITM','ITM'),'BAT-EAR-001','Earbud battery',cat_elec,u_pcs,'component',120.00,120,500,800,2000,v_admin),
   (v_org,next_reference(v_org,'ITM','ITM'),'PCB-MAIN-001','Main PCB',cat_elec,u_pcs,'component',450.00,450,300,600,1500,v_admin),
   (v_org,next_reference(v_org,'ITM','ITM'),'PCB-FLEX-001','Flexible PCB',cat_elec,u_pcs,'component',95.00,95,400,700,1500,v_admin),
   (v_org,next_reference(v_org,'ITM','ITM'),'SPK-DRV-001','Speaker driver',cat_elec,u_pcs,'component',210.00,210,400,700,1500,v_admin),
   (v_org,next_reference(v_org,'ITM','ITM'),'MIC-001','Microphone',cat_elec,u_pcs,'component',85.00,85,400,700,1500,v_admin),
   (v_org,next_reference(v_org,'ITM','ITM'),'BAT-CASE-001','Charging-case battery',cat_elec,u_pcs,'component',160.00,160,300,500,1000,v_admin),
   (v_org,next_reference(v_org,'ITM','ITM'),'PCB-CASE-001','Charging-case PCB',cat_elec,u_pcs,'component',180.00,180,300,500,1000,v_admin),
   (v_org,next_reference(v_org,'ITM','ITM'),'MESH-001','Mesh grill',cat_mech,u_pcs,'component',12.00,12,1000,1500,4000,v_admin),
   (v_org,next_reference(v_org,'ITM','ITM'),'HOUS-001','Housing shell',cat_mech,u_pcs,'component',55.00,55,800,1200,3000,v_admin),
   (v_org,next_reference(v_org,'ITM','ITM'),'PIN-001','Charging pins',cat_mech,u_pcs,'component',8.00,8,2000,3000,8000,v_admin),
   (v_org,next_reference(v_org,'ITM','ITM'),'SCR-001','Screws',cat_mech,u_pcs,'consumable',1.50,1.5,5000,8000,20000,v_admin),
   (v_org,next_reference(v_org,'ITM','ITM'),'ADH-001','Adhesive',cat_mech,u_pcs,'consumable',25.00,25,200,400,1000,v_admin),
   (v_org,next_reference(v_org,'ITM','ITM'),'BOX-001','Packaging box',cat_pack,u_pcs,'packaging',18.00,18,1000,1500,4000,v_admin),
   (v_org,next_reference(v_org,'ITM','ITM'),'USB-C-001','USB-C cable',cat_elec,u_pcs,'component',40.00,40,1000,1500,4000,v_admin),
   (v_org,next_reference(v_org,'ITM','ITM'),'MAN-001','User manual',cat_pack,u_pcs,'packaging',6.00,6,1000,1500,4000,v_admin);

  select id into it_batt from items where org_id=v_org and sku='BAT-EAR-001';
  select id into it_pcb  from items where org_id=v_org and sku='PCB-MAIN-001';
  select id into it_flex from items where org_id=v_org and sku='PCB-FLEX-001';
  select id into it_spk  from items where org_id=v_org and sku='SPK-DRV-001';
  select id into it_mic  from items where org_id=v_org and sku='MIC-001';
  select id into it_screw from items where org_id=v_org and sku='SCR-001';
  select id into it_box  from items where org_id=v_org and sku='BOX-001';
  select id into it_usb  from items where org_id=v_org and sku='USB-C-001';

  -- ---- Opening balances (stock into PK Main) ------------------------------
  insert into stock_transactions(org_id,ref_no,txn_type,status,created_by)
    values (v_org, next_reference(v_org,'OPN','OPN',2026),'opening_balance','draft',v_admin)
    returning id into txn;
  insert into stock_transaction_lines(org_id,transaction_id,line_no,item_id,warehouse_id,quantity,unit_cost)
  values
   (v_org,txn,1,it_batt,wh_main,2500,120),
   (v_org,txn,2,it_pcb, wh_main,1200,450),
   (v_org,txn,3,it_flex,wh_main,1600,95),
   (v_org,txn,4,it_spk, wh_main,1800,210),
   (v_org,txn,5,it_mic, wh_main,1800,85),
   (v_org,txn,6,it_box, wh_main,3000,18),
   (v_org,txn,7,it_usb, wh_main,2000,40),
   (v_org,txn,8,it_screw,wh_main,6000,1.5);   -- deliberately low vs reorder 8000 -> low-stock
  perform seed_post(txn);

  -- ---- Purchasing: PO with PARTIAL receipt --------------------------------
  insert into purchase_orders(org_id,ref_no,supplier_id,status,order_date,expected_date,warehouse_id,currency,created_by,approved_by)
    values (v_org, next_reference(v_org,'PO','PO',2026), sup1,'approved', current_date-7, current_date+14, wh_main,'USD',v_invmgr,v_admin)
    returning id into po1;
  insert into purchase_order_lines(po_id,line_no,item_id,ordered_qty,unit_id,unit_price,line_total)
    values (po1,1,it_pcb,1000,u_pcs,450,450000) returning id into poline;
  insert into purchase_order_lines(po_id,line_no,item_id,ordered_qty,unit_id,unit_price,line_total)
    values (po1,2,it_spk,1000,u_pcs,210,210000);

  -- Receive 600 of 1000 main PCBs (partial) via a posted GRN.
  insert into goods_receipts(org_id,ref_no,po_id,supplier_id,warehouse_id,status,created_by)
    values (v_org, next_reference(v_org,'GRN','GRN',2026), po1, sup1, wh_main,'draft',v_store)
    returning id into grn1;
  insert into goods_receipt_lines(receipt_id,po_line_id,item_id,received_qty,unit_cost)
    values (grn1, poline, it_pcb, 600, 450);
  -- Post GRN: build ledger txn, update PO line, then mark posted (seed variant).
  insert into stock_transactions(org_id,ref_no,txn_type,status,supplier_id,purchase_order_id,goods_receipt_id,created_by)
    values (v_org, (select ref_no from goods_receipts where id=grn1),'purchase_receipt','draft',sup1,po1,grn1,v_store)
    returning id into txn;
  insert into stock_transaction_lines(org_id,transaction_id,line_no,item_id,warehouse_id,quantity,unit_cost)
    values (v_org,txn,1,it_pcb,wh_main,600,450);
  perform seed_post(txn);
  update purchase_order_lines set received_qty=600 where id=poline;
  update purchase_orders set status='partially_received' where id=po1;
  update goods_receipts set status='posted', posted_at=now(), stock_txn_id=txn where id=grn1;

  -- ---- Project: reserve -> issue -> partial consume -> return -> damage ----
  insert into projects(org_id,ref_no,code,name,status,manager_id,country_code,budget,currency,start_date,target_date,created_by)
    values (v_org, next_reference(v_org,'PRJ','PRJ',2026),'ZONE-1K','Zone Earbuds – Initial 1,000 Units','active',v_pm,'PK',5000000,'PKR',current_date-20,current_date+40,v_admin)
    returning id into prj;
  insert into project_members(project_id,user_id,role_in_project) values (prj,v_pm,'Project Manager');
  insert into user_project_access(user_id,project_id,role_in_project) values (v_pm,prj,'manager'),(v_admin,prj,'admin');
  insert into project_warehouses(project_id,warehouse_id) values (prj,wh_main),(prj,wh_prod);
  insert into project_material_requirements(org_id,project_id,item_id,required_qty,unit_id) values
    (v_org,prj,it_batt,1000,u_pcs),(v_org,prj,it_pcb,1000,u_pcs),(v_org,prj,it_spk,1000,u_pcs),
    (v_org,prj,it_mic,1000,u_pcs),(v_org,prj,it_box,1000,u_pcs);

  -- Reserve 1000 batteries for the project (reduces available, not on-hand).
  insert into stock_reservations(org_id,item_id,warehouse_id,project_id,quantity,reference,created_by)
    values (v_org,it_batt,wh_main,prj,1000,'ZONE-1K reservation',v_pm);

  -- Issue 1000 batteries to the project (out of PK Main).
  insert into stock_transactions(org_id,ref_no,txn_type,status,project_id,created_by)
    values (v_org, next_reference(v_org,'ISS','ISS',2026),'project_issue','draft',prj,v_store)
    returning id into txn;
  insert into stock_transaction_lines(org_id,transaction_id,line_no,item_id,warehouse_id,quantity,unit_cost)
    values (v_org,txn,1,it_batt,wh_main,1000,120);
  perform seed_post(txn);
  -- Release the reservation now that stock has been issued.
  update stock_reservations set status='consumed', released_at=now()
    where project_id=prj and item_id=it_batt and status='active';

  -- Record PARTIAL consumption of 850 (issued 1000 != consumed 850).
  insert into stock_transactions(org_id,ref_no,txn_type,status,project_id,created_by)
    values (v_org, next_reference(v_org,'CON','CON',2026),'project_consumption','draft',prj,v_pm)
    returning id into txn;
  insert into stock_transaction_lines(org_id,transaction_id,line_no,item_id,warehouse_id,quantity,unit_cost)
    values (v_org,txn,1,it_batt,wh_main,850,120);  -- dir=0 => no warehouse effect
  perform seed_post(txn);

  -- Return 120 unused batteries to PK Main.
  insert into stock_transactions(org_id,ref_no,txn_type,status,project_id,created_by)
    values (v_org, next_reference(v_org,'RTN','RTN',2026),'project_return','draft',prj,v_store)
    returning id into txn;
  insert into stock_transaction_lines(org_id,transaction_id,line_no,item_id,warehouse_id,quantity,unit_cost)
    values (v_org,txn,1,it_batt,wh_main,120,120);
  perform seed_post(txn);

  -- Damage 30 batteries at the project (project damaged column).
  insert into stock_transactions(org_id,ref_no,txn_type,status,project_id,reason,created_by)
    values (v_org, next_reference(v_org,'DMG','DMG',2026),'damage','draft',prj,'handling damage',v_store)
    returning id into txn;
  insert into stock_transaction_lines(org_id,transaction_id,line_no,item_id,warehouse_id,quantity,unit_cost)
    values (v_org,txn,1,it_batt,wh_main,30,120);
  perform seed_post(txn);

  -- ---- Warehouse transfer: PK Main -> US Warehouse (completed) ------------
  -- Move 200 USB-C cables. Dispatch (out of main) then receive (into US).
  insert into stock_transactions(org_id,ref_no,txn_type,status,created_by)
    values (v_org, next_reference(v_org,'TRF','TRF',2026)||'-OUT','transfer_out','draft',v_store)
    returning id into txn;
  insert into stock_transaction_lines(org_id,transaction_id,line_no,item_id,warehouse_id,quantity,unit_cost)
    values (v_org,txn,1,it_usb,wh_main,200,40);
  perform seed_post(txn);
  insert into stock_transactions(org_id,ref_no,txn_type,status,created_by)
    values (v_org,'TRF-2026-000001-IN','transfer_in','draft',v_store)
    returning id into txn;
  insert into stock_transaction_lines(org_id,transaction_id,line_no,item_id,warehouse_id,quantity,unit_cost)
    values (v_org,txn,1,it_usb,wh_us,200,40);
  perform seed_post(txn);

  -- Damaged-stock quarantine: move 40 boxes main -> Damaged Stock (in-transit style).
  insert into stock_transactions(org_id,ref_no,txn_type,status,reason,created_by)
    values (v_org,'TRF-2026-000002-OUT','transfer_out','draft','quarantine damaged boxes',v_store)
    returning id into txn;
  insert into stock_transaction_lines(org_id,transaction_id,line_no,item_id,warehouse_id,quantity,unit_cost)
    values (v_org,txn,1,it_box,wh_main,40,18);
  perform seed_post(txn);
  insert into stock_transactions(org_id,ref_no,txn_type,status,reason,created_by)
    values (v_org,'TRF-2026-000002-IN','transfer_in','draft','quarantine damaged boxes',v_store)
    returning id into txn;
  insert into stock_transaction_lines(org_id,transaction_id,line_no,item_id,warehouse_id,quantity,unit_cost)
    values (v_org,txn,1,it_box,wh_dmg,40,18);
  perform seed_post(txn);

  -- A transfer left IN-TRANSIT (dispatched, not received) via the transfer doc.
  declare v_trf uuid;
  begin
    insert into warehouse_transfers(org_id,ref_no,status,source_wh,dest_wh,dispatched_at,created_by,approved_by)
      values (v_org,'TRF-2026-000003','dispatched',wh_main,wh_us,now(),v_store,v_invmgr)
      returning id into v_trf;
    insert into warehouse_transfer_lines(transfer_id,item_id,quantity,unit_id)
      values (v_trf,it_spk,150,u_pcs);
    insert into stock_transactions(org_id,ref_no,txn_type,status,transfer_id,created_by)
      values (v_org,'TRF-2026-000003-OUT','transfer_out','draft',v_trf,v_store) returning id into txn;
    insert into stock_transaction_lines(org_id,transaction_id,line_no,item_id,warehouse_id,quantity,unit_cost)
      values (v_org,txn,1,it_spk,wh_main,150,210);
    perform seed_post(txn);
    update warehouse_transfers set dispatch_txn_id=txn where id=v_trf;
  end;

  -- ---- Reversed adjustment (demonstrates reversal) -----------------------
  insert into stock_transactions(org_id,ref_no,txn_type,status,reason,created_by)
    values (v_org, next_reference(v_org,'ADJ','ADJ',2026),'adjustment_increase','draft','found extra stock',v_invmgr)
    returning id into txn;
  insert into stock_transaction_lines(org_id,transaction_id,line_no,item_id,warehouse_id,quantity,unit_cost)
    values (v_org,txn,1,it_mic,wh_main,50,85);
  perform seed_post(txn);
  perform seed_reverse(txn,'entered against wrong item');

  -- ---- Stock-count variance (approved + posted) --------------------------
  declare v_cnt uuid;
  begin
    insert into stock_counts(org_id,ref_no,warehouse_id,status,is_full_count,snapshot_at,approved_by,created_by)
      values (v_org, next_reference(v_org,'CNT','CNT',2026), wh_main,'approved',false, now(), v_invmgr, v_store)
      returning id into v_cnt;
    -- Expected 1600 flex PCBs, counted 1585 -> variance -15.
    insert into stock_count_lines(count_id,item_id,expected_qty,counted_qty,counted_by)
      values (v_cnt, it_flex, 1600, 1585, v_store);
    insert into stock_transactions(org_id,ref_no,txn_type,status,count_id,reason,created_by)
      values (v_org,(select ref_no from stock_counts where id=v_cnt),'count_variance','draft',v_cnt,'cycle count',v_store)
      returning id into txn;
    insert into stock_transaction_lines(org_id,transaction_id,line_no,item_id,warehouse_id,quantity,signed_quantity,unit_cost)
      values (v_org,txn,1,it_flex,wh_main,15,-15,95);
    perform seed_post(txn);
    update stock_counts set status='posted', posted_at=now(), adjustment_txn_id=txn where id=v_cnt;
  end;

  -- ---- Notifications, approvals, audit sample ----------------------------
  insert into notifications(org_id,user_id,kind,title,body,link) values
    (v_org,v_invmgr,'low_stock','Low stock: Screws','Screws (SCR-001) are at or below reorder point','/items'),
    (v_org,v_invmgr,'transfer_awaiting_receipt','Transfer TRF-2026-000003 in transit','150 speaker drivers dispatched to US Warehouse','/transfers');
  insert into approvals(org_id,entity_type,entity_id,status,requested_by,threshold_value)
    values (v_org,'purchase_order',po1,'pending',v_invmgr,660000);
  insert into audit_logs(org_id,user_id,action,module,record_type,record_id,reference_no,result)
    values (v_org,v_admin,'seed','settings','organisation',v_org,'mindtune','success');

  raise notice 'Seed complete for org %', v_org;
end $seed$;

-- Remove seed-only helpers (no runtime backdoor).
drop function seed_post(uuid);
drop function seed_reverse(uuid, text);
