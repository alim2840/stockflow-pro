'use client';
import { useEffect, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { Button, Card, CardContent, CardHeader, CardTitle } from '@/components/ui/primitives';
import { Loader2, Check, KeyRound, Eye, EyeOff, UserRound } from 'lucide-react';

// Self-service account page. Lets the signed-in user change their own password
// via Supabase Auth (supabase.auth.updateUser). Uses the browser client, which
// carries the user's session/JWT — so it only ever changes THEIR OWN password.
export default function AccountPage() {
  const [email, setEmail] = useState('');
  const [name, setName] = useState('');
  const [pw, setPw] = useState('');
  const [confirm, setConfirm] = useState('');
  const [show, setShow] = useState(false);
  const [loading, setLoading] = useState(false);
  const [msg, setMsg] = useState<{ type: 'ok' | 'err'; text: string } | null>(null);

  useEffect(() => {
    const sb = createClient();
    sb.auth.getUser().then(async ({ data }) => {
      setEmail(data.user?.email ?? '');
      if (data.user) {
        const { data: p } = await sb.from('profiles').select('full_name').eq('id', data.user.id).maybeSingle();
        setName(p?.full_name ?? '');
      }
    });
  }, []);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setMsg(null);
    if (pw.length < 8) return setMsg({ type: 'err', text: 'Use at least 8 characters.' });
    if (pw !== confirm) return setMsg({ type: 'err', text: 'The two passwords do not match.' });
    setLoading(true);
    const { error } = await createClient().auth.updateUser({ password: pw });
    setLoading(false);
    if (error) return setMsg({ type: 'err', text: error.message });
    setPw('');
    setConfirm('');
    setMsg({ type: 'ok', text: 'Password updated. Use your new password next time you sign in.' });
  }

  return (
    <div className="mx-auto max-w-2xl space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">My Account</h1>
        <p className="text-sm text-muted-foreground">Manage your sign-in details.</p>
      </div>

      <Card>
        <CardHeader><CardTitle>Profile</CardTitle></CardHeader>
        <CardContent className="space-y-2 text-sm">
          <div className="flex items-center gap-2">
            <UserRound className="h-4 w-4 text-muted-foreground" />
            <span className="font-medium">{name || '—'}</span>
          </div>
          <div className="text-muted-foreground">{email || '…'}</div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2 text-foreground">
            <KeyRound className="h-4 w-4" /> Change password
          </CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={onSubmit} className="space-y-4">
            <div>
              <label htmlFor="pw" className="mb-1.5 block text-sm font-medium">New password</label>
              <div className="relative">
                <input id="pw" type={show ? 'text' : 'password'} required autoComplete="new-password"
                  value={pw} onChange={(e) => setPw(e.target.value)}
                  className="h-10 w-full rounded-md border border-input bg-background px-3 pr-10 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring" />
                <button type="button" onClick={() => setShow((s) => !s)}
                  aria-label={show ? 'Hide password' : 'Show password'}
                  className="absolute right-2 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground">
                  {show ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                </button>
              </div>
              <p className="mt-1 text-xs text-muted-foreground">At least 8 characters.</p>
            </div>

            <div>
              <label htmlFor="confirm" className="mb-1.5 block text-sm font-medium">Confirm new password</label>
              <input id="confirm" type={show ? 'text' : 'password'} required autoComplete="new-password"
                value={confirm} onChange={(e) => setConfirm(e.target.value)}
                className="h-10 w-full rounded-md border border-input bg-background px-3 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring" />
            </div>

            {msg && (
              <div role="alert"
                className={`rounded-md px-3 py-2 text-sm ${msg.type === 'ok' ? 'bg-success/10 text-success' : 'bg-destructive/10 text-destructive'}`}>
                <span className="inline-flex items-center gap-1.5">
                  {msg.type === 'ok' && <Check className="h-4 w-4" />}{msg.text}
                </span>
              </div>
            )}

            <Button type="submit" disabled={loading}>
              {loading && <Loader2 className="h-4 w-4 animate-spin" />} Update password
            </Button>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
