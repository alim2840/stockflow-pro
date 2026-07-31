'use client';
import { useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { Button, Card, CardContent } from '@/components/ui/primitives';
import { Loader2, MailCheck } from 'lucide-react';

export default function ForgotPage() {
  const [email, setEmail] = useState('');
  const [sent, setSent] = useState(false);
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    const supabase = createClient();
    await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/reset`,
    });
    // Always show the same confirmation — never reveal whether the email exists.
    setSent(true);
    setLoading(false);
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-gradient-to-br from-background to-muted p-4">
      <Card className="w-full max-w-md">
        <CardContent className="p-8">
          {sent ? (
            <div className="space-y-3 text-center">
              <MailCheck className="mx-auto h-10 w-10 text-success" />
              <h1 className="text-xl font-semibold">Check your email</h1>
              <p className="text-sm text-muted-foreground">
                If an account exists for that address, we&apos;ve sent a password reset link.
              </p>
              <a href="/login" className="text-sm text-primary hover:underline">Back to sign in</a>
            </div>
          ) : (
            <>
              <h1 className="mb-1 text-xl font-semibold">Reset your password</h1>
              <p className="mb-6 text-sm text-muted-foreground">Enter your email and we&apos;ll send a reset link.</p>
              <form onSubmit={onSubmit} className="space-y-4">
                <input type="email" required value={email} onChange={(e) => setEmail(e.target.value)}
                  placeholder="you@company.com" aria-label="Email"
                  className="h-10 w-full rounded-md border border-input bg-background px-3 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring" />
                <Button type="submit" className="w-full" disabled={loading}>
                  {loading && <Loader2 className="h-4 w-4 animate-spin" />} Send reset link
                </Button>
              </form>
            </>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
