-- =============================================================================
-- StockFlow Pro — seed_auth.sql  (DEMO ONLY)
-- Creates Supabase Auth login credentials for the demo profiles created by
-- migration 0014, WITHOUT remapping any ids (profiles.id already == the id we
-- insert into auth.users). Run AFTER migrations, against your Supabase DB:
--     psql "$SUPABASE_DB_URL" -f supabase/seed_auth.sql
-- Default password for every demo account:  StockFlow!123   (change immediately)
-- Do NOT run this in a real production tenant.
-- =============================================================================

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data, is_super_admin
)
select
  '00000000-0000-0000-0000-000000000000', p.id, 'authenticated', 'authenticated',
  p.email, crypt('StockFlow!123', gen_salt('bf')),
  now(), now(), now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  jsonb_build_object('full_name', p.full_name),
  false
from profiles p
where p.email like '%@mindtune.test'
on conflict (id) do nothing;

-- Identity rows (required by GoTrue for email/password sign-in).
insert into auth.identities (
  provider_id, user_id, identity_data, provider,
  last_sign_in_at, created_at, updated_at
)
select
  p.id::text, p.id,
  jsonb_build_object('sub', p.id::text, 'email', p.email),
  'email', now(), now(), now()
from profiles p
where p.email like '%@mindtune.test'
on conflict do nothing;

-- Demo logins:
--   admin@mindtune.test      Super Admin
--   inventory@mindtune.test  Inventory Manager
--   pm@mindtune.test         Project Manager
--   store@mindtune.test      Storekeeper
--   accounts@mindtune.test   Accountant
--   viewer@mindtune.test     Viewer / Auditor
