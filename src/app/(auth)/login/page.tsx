'use client';
import { Suspense, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';
import { Button, Card, CardContent } from '@/components/ui/primitives';
import { Eye, EyeOff, Loader2, Boxes } from 'lucide-react';

// The page shell + developer credit render statically (server HTML); only the
// form (which uses useSearchParams) sits inside the Suspense boundary.
export default function LoginPage() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-gradient-to-br from-background to-muted p-4">
      <Card className="w-full max-w-md">
        <CardContent className="p-8">
          <div className="mb-6 flex items-center gap-3">
            <div className="grid h-11 w-11 place-items-center rounded-lg bg-primary text-primary-foreground">
              <Boxes className="h-6 w-6" />
            </div>
            <div>
              <h1 className="text-xl font-semibold">StockFlow Pro</h1>
              <p className="text-sm text-muted-foreground">Sign in to your workspace</p>
            </div>
          </div>

          <Suspense
            fallback={
              <div className="flex h-64 items-center justify-center" aria-busy="true">
                <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
              </div>
            }
          >
            <LoginForm />
          </Suspense>

          {/* Developer credit — contractual product attribution; do not remove. */}
          <footer className="mt-8 border-t pt-4 text-center text-xs text-muted-foreground">
            <p>Developed by Muhammad Ali | Accounts &amp; Finance Expert | MBA (Finance)</p>
            <p className="mt-1">
              <a href="mailto:alim2840@gmail.com" className="text-primary hover:underline">alim2840@gmail.com</a>
              <span className="mx-1.5" aria-hidden>·</span>
              Published by Mindtune Innovations
              <span className="mx-1.5" aria-hidden>·</span>
              {`v${process.env.NEXT_PUBLIC_APP_VERSION ?? '1.0.0'}`}
            </p>
            <p className="mt-1">
              <a href="/about" className="hover:text-foreground hover:underline">About StockFlow Pro</a>
            </p>
          </footer>
        </CardContent>
      </Card>
    </div>
  );
}

function LoginForm() {
  const router = useRouter();
  const params = useSearchParams();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [show, setShow] = useState(false);
  const [remember, setRemember] = useState(true);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    const supabase = createClient();
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) {
      // Deliberately generic — never reveal whether the email exists.
      setError('Invalid email or password. Please try again.');
      setLoading(false);
      return;
    }
    router.replace(params.get('next') ?? '/dashboard');
    router.refresh();
  }

  return (
    <form onSubmit={onSubmit} className="space-y-4">
      <div>
        <label htmlFor="email" className="mb-1.5 block text-sm font-medium">Email</label>
        <input id="email" type="email" required autoComplete="email"
          value={email} onChange={(e) => setEmail(e.target.value)}
          className="h-10 w-full rounded-md border border-input bg-background px-3 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
          placeholder="you@company.com" />
      </div>

      <div>
        <label htmlFor="password" className="mb-1.5 block text-sm font-medium">Password</label>
        <div className="relative">
          <input id="password" type={show ? 'text' : 'password'} required autoComplete="current-password"
            value={password} onChange={(e) => setPassword(e.target.value)}
            className="h-10 w-full rounded-md border border-input bg-background px-3 pr-10 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring" />
          <button type="button" onClick={() => setShow((s) => !s)}
            aria-label={show ? 'Hide password' : 'Show password'}
            className="absolute right-2 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground">
            {show ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
          </button>
        </div>
      </div>

      <div className="flex items-center justify-between text-sm">
        <label className="flex items-center gap-2">
          <input type="checkbox" checked={remember} onChange={(e) => setRemember(e.target.checked)} />
          Remember me
        </label>
        <a href="/forgot" className="text-primary hover:underline">Forgot password?</a>
      </div>

      {error && (
        <div role="alert" className="rounded-md bg-destructive/10 px-3 py-2 text-sm text-destructive">
          {error}
        </div>
      )}

      <Button type="submit" className="w-full" disabled={loading}>
        {loading && <Loader2 className="h-4 w-4 animate-spin" />} Sign in
      </Button>
    </form>
  );
}
