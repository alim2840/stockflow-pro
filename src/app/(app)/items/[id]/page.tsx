import { notFound } from 'next/navigation';
import { createServerSupabase } from '@/lib/supabase/server';
import { Card, CardContent, CardHeader, CardTitle, Badge, statusTone } from '@/components/ui/primitives';
import { formatMoney, formatQty } from '@/lib/money';
import { formatInTz } from '@/lib/utils';

export const dynamic = 'force-dynamic';

// Next 15+: params is a Promise and must be awaited.
export default async function ItemDetail({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const supabase = await createServerSupabase();

  const { data: item } = await supabase.from('v_item_full').select('*').eq('id', id).maybeSingle();
  if (!item) notFound();

  const [{ data: byWh }, { data: ledger }, { data: settings }] = await Promise.all([
    supabase.from('v_item_warehouse_balance').select('warehouse_name, on_hand, reserved, available').eq('item_id', id),
    supabase.from('v_stock_ledger').select('ref_no, txn_type, status, txn_date, posted_at, warehouse_name, quantity, signed_quantity, unit_cost')
      .eq('item_id', id).order('posted_at', { ascending: false, nullsFirst: false }).limit(50),
    supabase.from('company_settings').select('base_currency, timezone').maybeSingle(),
  ]);

  const currency = settings?.base_currency ?? 'PKR';
  const tz = settings?.timezone ?? 'Asia/Karachi';

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <div className="flex items-center gap-2">
            <h1 className="text-2xl font-semibold">{item.name}</h1>
            {!item.is_active && <Badge tone="danger">Inactive</Badge>}
          </div>
          <p className="text-sm text-muted-foreground">
            {item.ref_no} · SKU {item.sku} · {String(item.item_type).replace(/_/g, ' ')}
          </p>
        </div>
      </div>

      <div className="grid gap-4 sm:grid-cols-4">
        <Card><CardHeader className="pb-2"><CardTitle>On hand</CardTitle></CardHeader><CardContent className="text-2xl font-semibold tabular-nums">{formatQty(item.on_hand)}</CardContent></Card>
        <Card><CardHeader className="pb-2"><CardTitle>Reserved</CardTitle></CardHeader><CardContent className="text-2xl font-semibold tabular-nums">{formatQty(item.reserved)}</CardContent></Card>
        <Card><CardHeader className="pb-2"><CardTitle>Available</CardTitle></CardHeader><CardContent className="text-2xl font-semibold tabular-nums text-success">{formatQty(item.available)}</CardContent></Card>
        <Card><CardHeader className="pb-2"><CardTitle>Stock value</CardTitle></CardHeader><CardContent className="text-2xl font-semibold tabular-nums">{formatMoney(item.stock_value, currency)}</CardContent></Card>
      </div>

      <div className="grid gap-6 lg:grid-cols-3">
        <Card>
          <CardHeader><CardTitle>Stock by warehouse</CardTitle></CardHeader>
          <CardContent className="space-y-2">
            {(byWh ?? []).map((w, i) => (
              <div key={i} className="flex items-center justify-between text-sm">
                <span>{w.warehouse_name}</span>
                <span className="tabular-nums">{formatQty(w.on_hand)} <span className="text-muted-foreground">({formatQty(w.available)} avail)</span></span>
              </div>
            ))}
            {(byWh ?? []).length === 0 && <p className="text-sm text-muted-foreground">No stock in any warehouse.</p>}
          </CardContent>
        </Card>

        <Card className="lg:col-span-2">
          <CardHeader><CardTitle>Stock ledger (last 50)</CardTitle></CardHeader>
          <CardContent className="overflow-x-auto p-0">
            <table className="w-full text-sm">
              <thead className="border-y bg-muted/40 text-left text-xs uppercase text-muted-foreground">
                <tr>
                  <th className="px-4 py-2 font-medium">Reference</th>
                  <th className="px-4 py-2 font-medium">Type</th>
                  <th className="px-4 py-2 font-medium">Warehouse</th>
                  <th className="px-4 py-2 text-right font-medium">Change</th>
                  <th className="px-4 py-2 font-medium">Date</th>
                </tr>
              </thead>
              <tbody>
                {(ledger ?? []).map((l, i) => (
                  <tr key={i} className="border-b last:border-0">
                    <td className="px-4 py-2 font-mono text-xs">{l.ref_no}</td>
                    <td className="px-4 py-2"><Badge tone={statusTone(l.status)}>{l.txn_type.replace(/_/g, ' ')}</Badge></td>
                    <td className="px-4 py-2 text-muted-foreground">{l.warehouse_name}</td>
                    <td className={`px-4 py-2 text-right tabular-nums ${Number(l.signed_quantity) < 0 ? 'text-destructive' : 'text-success'}`}>
                      {Number(l.signed_quantity) > 0 ? '+' : ''}{formatQty(l.signed_quantity)}
                    </td>
                    <td className="px-4 py-2 text-muted-foreground">{formatInTz(l.posted_at ?? l.txn_date, tz, false)}</td>
                  </tr>
                ))}
                {(ledger ?? []).length === 0 && (
                  <tr><td colSpan={5} className="px-4 py-8 text-center text-muted-foreground">No transactions yet.</td></tr>
                )}
              </tbody>
            </table>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
