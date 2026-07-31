-- =============================================================================
-- StockFlow Pro — DB engine integration tests (reproducible).
-- Prereq: a database with migrations 0001-0014 applied and demo seed loaded.
-- On Supabase, auth.uid() exists. On vanilla Postgres, create the shim:
--   create schema if not exists auth;
--   create function auth.uid() returns uuid language sql stable as $$
--     select nullif(current_setting('app.current_user_id', true),'')::uuid $$;
-- Run:  psql "$SUPABASE_DB_URL" -f tests/db/engine_tests.sql
-- =============================================================================
\set ON_ERROR_STOP off
\timing off

select id as org    from organisations where slug='mindtune' \gset
select id as store  from profiles where email='store@mindtune.test' \gset
select id as invmgr from profiles where email='inventory@mindtune.test' \gset
select id as viewer from profiles where email='viewer@mindtune.test' \gset
select id as batt   from items where sku='BAT-EAR-001' \gset
select id as whmain from warehouses where code='PK-MAIN' \gset

\echo '== Balances derive from ledger =='
select it.sku, w.code, b.on_hand, b.reserved, b.available
from v_item_warehouse_balance b
join items it on it.id=b.item_id join warehouses w on w.id=b.warehouse_id
where b.on_hand<>0 order by 1,2;

\echo '== Project material balance (issued != consumed) =='
select it.sku, required, issued, consumed, returned, damaged,
       (issued-consumed-returned-damaged) as with_project
from v_project_material_balance p join items it on it.id=p.item_id;

\echo '== T10 valid issue (batt -100) =='
select set_config('app.current_user_id', :'store', false);
insert into stock_transactions(org_id,ref_no,txn_type,status,created_by)
  values (:'org', next_reference(:'org','ISS','ISS',2026),'general_issue','draft',:'store') returning id as t1 \gset
insert into stock_transaction_lines(org_id,transaction_id,line_no,item_id,warehouse_id,quantity,unit_cost)
  values (:'org',:'t1',1,:'batt',:'whmain',100,120);
select post_stock_transaction(:'t1');
select on_hand from v_item_warehouse_balance where item_id=:'batt' and warehouse_id=:'whmain';

\echo '== T11 idempotent re-post (unchanged) =='
select post_stock_transaction(:'t1');
select on_hand from v_item_warehouse_balance where item_id=:'batt' and warehouse_id=:'whmain';

\echo '== T12 negative stock blocked =='
do $$ declare v uuid; begin
  perform set_config('app.current_user_id',(select id::text from profiles where email='store@mindtune.test'),false);
  insert into stock_transactions(org_id,ref_no,txn_type,status,created_by)
    values ((select id from organisations where slug='mindtune'),
            next_reference((select id from organisations where slug='mindtune'),'ISS','ISS',2026),'general_issue','draft',auth.uid()) returning id into v;
  insert into stock_transaction_lines(org_id,transaction_id,line_no,item_id,warehouse_id,quantity,unit_cost)
    values ((select id from organisations where slug='mindtune'),v,1,
            (select id from items where sku='BAT-EAR-001'),(select id from warehouses where code='PK-MAIN'),999999,120);
  begin perform post_stock_transaction(v); raise notice 'FAIL negative allowed';
  exception when check_violation then raise notice 'PASS negative blocked'; end;
end $$;

\echo '== T13 posted immutable =='
do $$ begin
  begin update stock_transactions set notes='x' where id=(select id from stock_transactions where status='posted' limit 1);
    raise notice 'FAIL editable';
  exception when check_violation then raise notice 'PASS immutable'; end;
end $$;

\echo '== T14/15 reversal restores + double reversal blocked (inventory mgr) =='
select set_config('app.current_user_id', :'invmgr', false);
select reverse_stock_transaction(:'t1','test');
select on_hand from v_item_warehouse_balance where item_id=:'batt' and warehouse_id=:'whmain';
do $$ begin
  perform set_config('app.current_user_id',(select id::text from profiles where email='inventory@mindtune.test'),false);
  begin perform reverse_stock_transaction((select id from stock_transactions where reversed_by is not null and txn_type='general_issue' limit 1),'again');
    raise notice 'FAIL double reversal';
  exception when check_violation then raise notice 'PASS double reversal blocked'; end;
end $$;

\echo '== T17 viewer cannot post =='
do $$ begin
  perform set_config('app.current_user_id',(select id::text from profiles where email='viewer@mindtune.test'),false);
  begin perform post_stock_transaction((select id from stock_transactions where status='draft' limit 1));
    raise notice 'FAIL viewer posted';
  exception when insufficient_privilege then raise notice 'PASS viewer blocked';
           when others then raise notice 'PASS(other) %', sqlerrm; end;
end $$;

\echo 'Done.'
