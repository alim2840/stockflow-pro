-- =============================================================================
-- StockFlow Pro — 0012_permissions_and_roles.sql
-- The permission catalog (module x action) and the seven default system roles
-- with their grants. System roles have org_id = null and are shared by all orgs.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Permission catalog
-- ---------------------------------------------------------------------------
insert into permissions(module, action)
select m, a::perm_action
from (values
  ('dashboard'), ('items'), ('categories'), ('warehouses'), ('stock_txn'),
  ('purchasing'), ('suppliers'), ('projects'), ('production'), ('counts'),
  ('reports'), ('users'), ('backups'), ('audit'), ('notifications'), ('settings')
) as mods(m)
cross join (values
  ('view'), ('create'), ('edit_draft'), ('post'), ('approve'),
  ('reverse'), ('export'), ('delete_draft'), ('manage_settings')
) as acts(a)
on conflict (module, action) do nothing;

-- ---------------------------------------------------------------------------
-- Default system roles
-- ---------------------------------------------------------------------------
insert into roles(org_id, key, name, description, is_system) values
  (null,'super_admin','Super Admin','Full platform access across all organisations',true),
  (null,'company_admin','Company Admin','Full access within their organisation',true),
  (null,'inventory_manager','Inventory Manager','Items, purchasing, stock movements, transfers, counts',true),
  (null,'project_manager','Project Manager','Assigned projects, requirements, issue/consume/return',true),
  (null,'storekeeper','Storekeeper','Receive, issue, return, transfer, count',true),
  (null,'accountant','Accountant','Costs, valuations, financial reports (read)',true),
  (null,'viewer','Viewer / Auditor','Read-only access to authorised modules',true)
on conflict (org_id, key) do nothing;

-- Helper: grant (module,action) pairs to a role by key.
create or replace function _grant(p_role_key text, p_modules text[], p_actions text[])
returns void language plpgsql as $$
begin
  insert into role_permissions(role_id, permission_id)
  select r.id, p.id
  from roles r
  join permissions p on p.module = any(p_modules) and p.action::text = any(p_actions)
  where r.key = p_role_key and r.is_system
  on conflict do nothing;
end $$;

-- Super Admin + Company Admin: everything.
insert into role_permissions(role_id, permission_id)
  select r.id, p.id from roles r cross join permissions p
  where r.key in ('super_admin','company_admin') on conflict do nothing;

-- Inventory Manager
select _grant('inventory_manager',
  array['dashboard','items','categories','warehouses','stock_txn','purchasing','suppliers','counts','production','reports','notifications'],
  array['view','create','edit_draft','post','approve','reverse','export','delete_draft']);

-- Project Manager
select _grant('project_manager', array['dashboard','notifications'], array['view']);
select _grant('project_manager', array['projects'], array['view','create','edit_draft','post','approve','export']);
select _grant('project_manager', array['stock_txn'], array['view','create','edit_draft','post']);
select _grant('project_manager', array['items','reports'], array['view','export']);

-- Storekeeper
select _grant('storekeeper', array['dashboard','notifications','items','warehouses'], array['view']);
select _grant('storekeeper', array['stock_txn','counts'], array['view','create','edit_draft','post','export']);

-- Accountant (read + export of financial views; cannot post physical stock)
select _grant('accountant',
  array['dashboard','reports','items','stock_txn','suppliers','projects','purchasing','notifications'],
  array['view','export']);

-- Viewer / Auditor
select _grant('viewer',
  array['dashboard','items','categories','warehouses','stock_txn','purchasing','suppliers','projects','production','counts','reports','audit','notifications'],
  array['view','export']);

drop function _grant(text, text[], text[]);

-- ---------------------------------------------------------------------------
-- Bootstrap: create an organisation, its settings, the first Super Admin
-- profile, and grant the super_admin role. Called once during setup.
-- ---------------------------------------------------------------------------
create or replace function bootstrap_organisation(
  p_name text, p_slug text, p_user_id uuid, p_email text,
  p_full_name text default null, p_timezone text default 'Asia/Karachi',
  p_currency char(3) default 'PKR'
) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_org uuid; v_role uuid;
begin
  insert into organisations(name, slug) values (p_name, p_slug) returning id into v_org;
  insert into company_settings(org_id, base_currency, timezone) values (v_org, p_currency, p_timezone);
  insert into profiles(id, org_id, email, full_name, status, is_platform_admin, activated_at)
    values (p_user_id, v_org, p_email, p_full_name, 'active', true, now());
  select id into v_role from roles where key = 'super_admin' and is_system;
  insert into user_roles(user_id, role_id, org_id) values (p_user_id, v_role, v_org);
  return v_org;
end $$;
