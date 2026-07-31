import Link from 'next/link';
import { createServerSupabase } from '@/lib/supabase/server';
import { Card, Badge } from '@/components/ui/primitives';
import { formatMoney, formatQty } from '@/lib/money';
import type { ItemFull } from '@/types/database';
import { Search, PackageX } from 'lucide-react';

export const dynamic = 'force-dynamic';

// Server-side pagination + search. The DB never returns the whole table.
const PAGE_SIZE = 25;

// Next 15+: searchParams is a Promise and must be awaited.
export default async function ItemsPage(
  { searchParams }: { searchParams: Promise<{ q?: string; page?: string }> },
) {
  const sp = await searchParams;
  const supabase = await createServerSupabase();
  const q = (sp.q ?? '').trim();
  const page = Math.max(1, Number(sp.page ?? '1'));
  const from = (page - 1) * PAGE_SIZE;

  let query = supabase.from('v_item_full')
    .select('id, ref_no, sku, name, item_type, category_name, on_hand, reserved, available, average_cost, stock_value, reorder_point, is_active',
      { count: 'exact' })
    .order('name')
    .range(from, from + PAGE_SIZE - 1);
  if (q) query = query.or(`name.ilike.%${q}%,sku.ilike.%${q}%,ref_no.ilike.%${q}%`);

  const { data: items, count } = await query;
  const { data: settings } = await supabase.from('company_settings').select('base_currency').maybeSingle();
  const currency = settings?.base_currency ?? 'PKR';
  const total = count ?? 0;
  const pages = Math.max(1, Math.ceil(total / PAGE_SIZE));

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold">Inventory Items</h1>
          <p className="text-sm text-muted-foreground">{total} item{total === 1 ? '' : 's'}</p>
        </div>
        <form className="relative">
          <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <input name="q" defaultValue={q} placeholder="Search name, SKU, or ID…"
            className="h-10 w-72 rounded-md border border-input bg-background pl-9 pr-3 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring" />
        </form>
      </div>

      <Card className="overflow-hidden">
        {(!items || items.length === 0) ? (
          <div className="flex flex-col items-center gap-2 py-16 text-center">
            <PackageX className="h-8 w-8 text-muted-foreground" />
            <p className="font-medium">No items found</p>
            <p className="text-sm text-muted-foreground">
              {q ? 'Try a different search.' : 'Create your first item to get started.'}
            </p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="border-b bg-muted/40 text-left text-xs uppercase text-muted-foreground">
                <tr>
                  <th className="px-4 py-3 font-medium">SKU</th>
                  <th className="px-4 py-3 font-medium">Name</th>
                  <th className="px-4 py-3 font-medium">Category</th>
                  <th className="px-4 py-3 text-right font-medium">On hand</th>
                  <th className="px-4 py-3 text-right font-medium">Available</th>
                  <th className="px-4 py-3 text-right font-medium">Avg cost</th>
                  <th className="px-4 py-3 text-right font-medium">Value</th>
                </tr>
              </thead>
              <tbody>
                {(items as ItemFull[]).map((it) => {
                  const low = Number(it.available) <= Number(it.reorder_point);
                  return (
                    <tr key={it.id} className="border-b last:border-0 hover:bg-accent/40">
                      <td className="px-4 py-3 font-mono text-xs">{it.sku}</td>
                      <td className="px-4 py-3">
                        <Link href={`/items/${it.id}`} className="font-medium text-primary hover:underline">{it.name}</Link>
                      </td>
                      <td className="px-4 py-3 text-muted-foreground">{it.category_name ?? '—'}</td>
                      <td className="px-4 py-3 text-right tabular-nums">{formatQty(it.on_hand)}</td>
                      <td className="px-4 py-3 text-right tabular-nums">
                        <span className="inline-flex items-center gap-2">
                          {formatQty(it.available)}
                          {low && <Badge tone="warning">Low</Badge>}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-right tabular-nums">{formatMoney(it.average_cost, currency)}</td>
                      <td className="px-4 py-3 text-right tabular-nums">{formatMoney(it.stock_value, currency)}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      {pages > 1 && (
        <div className="flex items-center justify-between text-sm">
          <span className="text-muted-foreground">Page {page} of {pages}</span>
          <div className="flex gap-2">
            {page > 1 && <Link className="rounded-md border px-3 py-1.5 hover:bg-accent" href={`/items?q=${encodeURIComponent(q)}&page=${page - 1}`}>Previous</Link>}
            {page < pages && <Link className="rounded-md border px-3 py-1.5 hover:bg-accent" href={`/items?q=${encodeURIComponent(q)}&page=${page + 1}`}>Next</Link>}
          </div>
        </div>
      )}
    </div>
  );
}
