import { redirect } from 'next/navigation';
import { createServerSupabase } from '@/lib/supabase/server';
import { Sidebar } from '@/components/sidebar';
import type { Module } from '@/lib/permissions';

// Authenticated shell. Loads the user, company branding, and the set of modules
// the user may see (permission-based menu visibility, resolved server-side).
export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const supabase = await createServerSupabase();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/login');

  const [{ data: profile }, { data: settings }, { data: perms }] = await Promise.all([
    supabase.from('profiles').select('full_name, is_platform_admin, org_id').eq('id', user.id).single(),
    supabase.from('company_settings').select('app_name').maybeSingle(),
    supabase.from('user_roles').select('roles!inner(role_permissions(permissions(module)))').eq('user_id', user.id),
  ]);

  const allowed = new Set<Module>();
  if (profile?.is_platform_admin) {
    (['dashboard','items','categories','warehouses','stock_txn','purchasing','suppliers','projects','production','counts','reports','users','backups','audit','notifications','settings'] as Module[])
      .forEach((m) => allowed.add(m));
  } else {
    for (const ur of perms ?? []) {
      for (const rp of (ur as any).roles?.role_permissions ?? []) {
        const m = rp.permissions?.module as Module | undefined;
        if (m) allowed.add(m);
      }
    }
  }

  return (
    <div className="flex">
      <Sidebar appName={settings?.app_name ?? 'StockFlow Pro'} allowed={[...allowed]} />
      <div className="flex h-screen flex-1 flex-col overflow-hidden">
        <header className="flex h-14 items-center justify-between border-b bg-card px-6">
          <div className="text-sm text-muted-foreground">Welcome{profile?.full_name ? `, ${profile.full_name}` : ''}</div>
          <div className="flex items-center gap-4">
            <a href="/account" className="text-sm text-muted-foreground hover:text-foreground">My account</a>
            <form action="/auth/signout" method="post">
              <button className="text-sm text-muted-foreground hover:text-foreground">Sign out</button>
            </form>
          </div>
        </header>
        <main className="flex-1 overflow-y-auto p-6">{children}</main>
      </div>
    </div>
  );
}
