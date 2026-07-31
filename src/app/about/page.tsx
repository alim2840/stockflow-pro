'use client';
import { useState } from 'react';
import { Boxes, Mail, Copy, RefreshCw, Check, ArrowLeft } from 'lucide-react';
import { Button, Card, CardContent } from '@/components/ui/primitives';

// Public About screen (no business data). The developer attribution below is a
// contractual product credit — it must not be altered or removed in builds.
const VERSION = process.env.NEXT_PUBLIC_APP_VERSION ?? '1.0.0';
const BUILD_DATE = process.env.NEXT_PUBLIC_BUILD_DATE ?? '—';
const BUILD_NUMBER = process.env.NEXT_PUBLIC_BUILD_NUMBER ?? 'local';
const ENVIRONMENT = process.env.NODE_ENV === 'production' ? 'Production' : 'Development';
const RELEASES_URL = 'https://github.com/alim2840/stockflow-pro/releases';

export default function AboutPage() {
  const [copied, setCopied] = useState(false);

  async function copySystemInfo() {
    const info = [
      `StockFlow Pro ${VERSION} (build ${BUILD_NUMBER}, ${BUILD_DATE}, ${ENVIRONMENT})`,
      `Developed by Muhammad Ali — Accounts & Finance Expert, MBA (Finance) — alim2840@gmail.com`,
      `Published by Mindtune Innovations`,
      `Platform: ${navigator.userAgent}`,
    ].join('\n');
    await navigator.clipboard.writeText(info);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-gradient-to-br from-background to-muted p-4">
      <Card className="w-full max-w-lg">
        <CardContent className="p-8">
          <a href="/login" className="mb-4 inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground">
            <ArrowLeft className="h-4 w-4" /> Back to sign in
          </a>

          <div className="mb-6 flex items-center gap-4">
            <div className="grid h-14 w-14 place-items-center rounded-xl bg-primary text-primary-foreground">
              <Boxes className="h-8 w-8" />
            </div>
            <div>
              <h1 className="text-2xl font-semibold">StockFlow Pro</h1>
              <p className="text-sm text-muted-foreground">Premium Inventory and Project Management System</p>
            </div>
          </div>

          <div className="space-y-4 rounded-lg border bg-muted/30 p-5 text-sm">
            <div>
              <div className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Developed by</div>
              <div className="mt-1 font-semibold">Muhammad Ali</div>
              <div className="text-muted-foreground">Accounts &amp; Finance Expert</div>
              <div className="text-muted-foreground">MBA (Finance)</div>
            </div>
            <div>
              <div className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Email</div>
              <a href="mailto:alim2840@gmail.com" className="mt-1 inline-flex items-center gap-1.5 font-medium text-primary hover:underline">
                <Mail className="h-3.5 w-3.5" /> alim2840@gmail.com
              </a>
            </div>
            <div>
              <div className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Published by</div>
              <div className="mt-1 font-medium">Mindtune Innovations</div>
            </div>
            <div className="grid grid-cols-2 gap-3 border-t pt-3">
              <div><div className="text-xs text-muted-foreground">Version</div><div className="font-medium tabular-nums">{VERSION}</div></div>
              <div><div className="text-xs text-muted-foreground">Build</div><div className="font-medium tabular-nums">{BUILD_NUMBER}</div></div>
              <div><div className="text-xs text-muted-foreground">Build date</div><div className="font-medium">{BUILD_DATE}</div></div>
              <div><div className="text-xs text-muted-foreground">Environment</div><div className="font-medium">{ENVIRONMENT}</div></div>
            </div>
          </div>

          <div className="mt-5 grid grid-cols-2 gap-3">
            <Button variant="outline" onClick={() => window.open(RELEASES_URL, '_blank', 'noopener,noreferrer')}>
              <RefreshCw className="h-4 w-4" /> Check for updates
            </Button>
            <Button variant="outline" onClick={copySystemInfo}>
              {copied ? <Check className="h-4 w-4 text-success" /> : <Copy className="h-4 w-4" />}
              {copied ? 'Copied' : 'Copy system info'}
            </Button>
          </div>

          <div className="mt-5 flex items-center justify-center gap-4 text-xs text-muted-foreground">
            <span title="Placeholder — replace with your organisation's policy" className="cursor-default hover:text-foreground">Privacy policy</span>
            <span aria-hidden>·</span>
            <span title="Placeholder — replace with your organisation's terms" className="cursor-default hover:text-foreground">Terms &amp; conditions</span>
            <span aria-hidden>·</span>
            <a href="mailto:alim2840@gmail.com?subject=StockFlow%20Pro%20support" className="text-primary hover:underline">Support</a>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
