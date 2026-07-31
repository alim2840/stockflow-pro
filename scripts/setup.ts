/**
 * StockFlow Pro — production bootstrap.
 *
 *   npx tsx scripts/setup.ts
 *
 * Creates the first Super Admin Supabase Auth user and a clean organisation via
 * the bootstrap_organisation() RPC. Uses the SERVICE ROLE key — run locally /
 * in CI only, never in the browser.
 *
 * For the DEMO org logins instead, apply migrations then run:
 *   psql "$SUPABASE_DB_URL" -f supabase/seed_auth.sql
 *
 * Env: NEXT_PUBLIC_SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY,
 *      ADMIN_EMAIL, ADMIN_PASSWORD, ORG_NAME, ORG_SLUG, TIMEZONE, CURRENCY
 */
import { createClient } from '@supabase/supabase-js';

const url = required('NEXT_PUBLIC_SUPABASE_URL');
const serviceKey = required('SUPABASE_SERVICE_ROLE_KEY');
const email = process.env.ADMIN_EMAIL ?? 'admin@yourcompany.com';
const password = process.env.ADMIN_PASSWORD ?? cryptoRandom();
const orgName = process.env.ORG_NAME ?? 'Your Company';
const orgSlug = process.env.ORG_SLUG ?? 'your-company';
const timezone = process.env.TIMEZONE ?? 'Asia/Karachi';
const currency = process.env.CURRENCY ?? 'PKR';

function required(name: string): string {
  const v = process.env[name];
  if (!v) { console.error(`Missing env var: ${name}`); process.exit(1); }
  return v;
}
function cryptoRandom() {
  return 'Sf-' + Math.random().toString(36).slice(2, 10) + 'A1!';
}

async function main() {
  const sb = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });

  console.log(`Creating Super Admin ${email} …`);
  const { data: created, error: cErr } = await sb.auth.admin.createUser({
    email, password, email_confirm: true,
  });
  if (cErr || !created.user) throw new Error(`createUser failed: ${cErr?.message}`);

  console.log(`Bootstrapping organisation "${orgName}" …`);
  const { data: orgId, error: bErr } = await sb.rpc('bootstrap_organisation', {
    p_name: orgName, p_slug: orgSlug, p_user_id: created.user.id, p_email: email,
    p_full_name: 'Super Admin', p_timezone: timezone, p_currency: currency,
  });
  if (bErr) throw new Error(`bootstrap_organisation failed: ${bErr.message}`);

  console.log('\n✅ Setup complete.');
  console.log(`   Organisation id: ${orgId}`);
  console.log(`   Login:           ${email}`);
  console.log(`   Password:        ${password}`);
  console.log('   (Store the password securely and rotate after first login.)');
}

main().catch((e) => { console.error('\n❌', e.message); process.exit(1); });
