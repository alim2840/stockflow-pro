import { createServerClient, type CookieOptions } from '@supabase/ssr';
import { cookies } from 'next/headers';
import { createClient as createSbClient } from '@supabase/supabase-js';

type CookieToSet = { name: string; value: string; options?: CookieOptions };

// Server client bound to the request cookies -> runs as the signed-in user, so
// RLS is enforced. Use this for all normal reads/writes in Server Components,
// Server Actions and Route Handlers. Async because Next 15+ made cookies() async.
export async function createServerSupabase() {
  const cookieStore = await cookies();
  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => cookieStore.getAll(),
        setAll: (list: CookieToSet[]) => {
          try {
            list.forEach(({ name, value, options }) => cookieStore.set(name, value, options));
          } catch {
            /* called from a Server Component render — safe to ignore */
          }
        },
      },
    },
  );
}

// SERVICE-ROLE client — bypasses RLS. Use ONLY in trusted server code
// (setup script, backup jobs, admin routes) and NEVER expose to the browser.
// Guarded so it can never be imported into a client bundle.
export function createServiceClient() {
  if (typeof window !== 'undefined') {
    throw new Error('Service-role client must never run in the browser');
  }
  return createSbClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
}
