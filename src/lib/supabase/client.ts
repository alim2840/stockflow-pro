'use client';
import { createBrowserClient } from '@supabase/ssr';

// Browser client: uses the PUBLIC anon key + the signed-in user's JWT.
// RLS applies to every query. The service-role key is NEVER used here.
export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
  );
}
