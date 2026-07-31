import Link from 'next/link';
import { Card, CardContent } from '@/components/ui/primitives';
import { ModuleScaffold } from '@/components/module-scaffold';
import { Info, Mail } from 'lucide-react';

export const dynamic = 'force-dynamic';

export default function Page() {
  return (
    <div className="space-y-6">
      {/* Settings → About (required placement of the product/developer credit) */}
      <Card>
        <CardContent className="flex flex-wrap items-center justify-between gap-4 p-5">
          <div className="flex items-center gap-3">
            <div className="grid h-10 w-10 place-items-center rounded-md bg-primary/10 text-primary">
              <Info className="h-5 w-5" />
            </div>
            <div>
              <div className="font-medium">About StockFlow Pro</div>
              <div className="text-sm text-muted-foreground">
                Version {process.env.NEXT_PUBLIC_APP_VERSION ?? '1.0.0'} · Published by Mindtune Innovations ·
                Developed by Muhammad Ali — Accounts &amp; Finance Expert, MBA (Finance)
              </div>
            </div>
          </div>
          <div className="flex items-center gap-3 text-sm">
            <a href="mailto:alim2840@gmail.com" className="inline-flex items-center gap-1.5 text-primary hover:underline">
              <Mail className="h-3.5 w-3.5" /> alim2840@gmail.com
            </a>
            <Link href="/about" className="rounded-md border px-3 py-1.5 hover:bg-accent">Open About</Link>
          </div>
        </CardContent>
      </Card>

      <ModuleScaffold title="Settings"
        blurb="Company (name, logo, currency, timezone, date/number format, brand colour), inventory, security and backup settings."
        backedBy={['company_settings']} />
    </div>
  );
}
