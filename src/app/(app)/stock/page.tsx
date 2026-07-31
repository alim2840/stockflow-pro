import Link from 'next/link';
import { createServerSupabase } from '@/lib/supabase/server';
import { Card, Badge, statusTone } from '@/components/ui/primitives';
import { formatInTz } from '@/lib/utils';
import { ArrowLeftRight } from 'lucide-react';

export const dynamic = 'force-dynamic';
const PAGE_SIZE = 30;

// Next 15+: searchParams is a Promise and must be awaited.
export default async function StockTxnPage(
  { searchParams }: { searchParams: Promise<{ type?: string; page?: string }> },
) {
  const sp = await searchParams;
  const supabase = await createServerSupabase();
  const page = Math.max(1, Number(sp.page ?? '1'));
  const from = (page - 1) * PAGE_SIZE;

  let q = supabase.from('stock_transactions')
    .select('id, ref_no, txn_type, status, txn_date, posted_at', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(from, from + PAGE_SIZE - 1);
  if (sp.type) q = q.eq('txn_type', sp.type);

  const [{ data: txns, count }, { data: settings }] = await Promise.all([
    q, supabase.from('company_settings').select('timezone').maybeSingle(),
  ]);
  const tz = settings?.timezone ?? 'Asia/Karachi';
  const pages = Math.max(1, Math.ceil((count ?? 0) / PAGE_SIZE));

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold">Stock Transactions</h1>
          <p className="text-sm text-muted-foreground">{count ?? 0} transactions · immutable ledger</p>
        </div>
      </div>

      <Card className="overflow-hidden">
        {(!txns || txns.length === 0) ? (
          <div className="flex flex-col items-center gap-2 py-16 text-center">
            <ArrowLeftRight className="h-8 w-8 text-muted-foreground" />
            <p className="font-medium">No transactions yet</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="border-b bg-muted/40 text-left text-xs uppercase text-muted-foreground">
                <tr>
                  <th className="px-4 py-3 font-medium">Reference</th>
                  <th className="px-4 py-3 font-medium">Type</th>
                  <th className="px-4 py-3 font-medium">Status</th>
                  <th className="px-4 py-3 font-medium">Date</th>
                  <th className="px-4 py-3 font-medium">Posted</th>
                </tr>
              </thead>
              <tbody>
                {txns.map((t) => (
                  <tr key={t.id} className="border-b last:border-0 hover:bg-accent/40">
                    <td className="px-4 py-3 font-mono text-xs">{t.ref_no}</td>
                    <td className="px-4 py-3">{t.txn_type.replace(/_/g, ' ')}</td>
                    <td className="px-4 py-3"><Badge tone={statusTone(t.status)}>{t.status.replace(/_/g, ' ')}</Badge></td>
                    <td className="px-4 py-3 text-muted-foreground">{formatInTz(t.txn_date, tz, false)}</td>
                    <td className="px-4 py-3 text-muted-foreground">{formatInTz(t.posted_at, tz)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      {pages > 1 && (
        <div className="flex items-center justify-between text-sm">
          <span className="text-muted-foreground">Page {page} of {pages}</span>
          <div className="flex gap-2">
            {page > 1 && <Link className="rounded-md border px-3 py-1.5 hover:bg-accent" href={`/stock?page=${page - 1}`}>Previous</Link>}
            {page < pages && <Link className="rounded-md border px-3 py-1.5 hover:bg-accent" href={`/stock?page=${page + 1}`}>Next</Link>}
          </div>
        </div>
      )}
    </div>
  );
}
