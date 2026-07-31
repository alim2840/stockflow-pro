import { createServerSupabase } from '@/lib/supabase/server';
import { Card, CardContent, CardHeader, CardTitle, Badge, statusTone } from '@/components/ui/primitives';
import { formatMoney, formatQty } from '@/lib/money';
import { formatInTz } from '@/lib/utils';
import { InventoryValueChart } from '@/components/charts';
import type { DashboardKpis } from '@/types/database';
import {
  Boxes, PackageCheck, PackageX, AlertTriangle, FolderKanban, ShoppingCart,
  Clock, TrendingDown, TrendingUp, ShieldAlert,
} from 'lucide-react';

export const dynamic = 'force-dynamic';

function Kpi({ title, value, icon: Icon, tone = 'info' }: {
  title: string; value: string; icon: React.ElementType; tone?: 'info' | 'success' | 'warning' | 'danger';
}) {
  const toneCls = { info: 'text-primary', success: 'text-success', warning: 'text-amber-600', danger: 'text-destructive' }[tone];
  return (
    <Card>
      <CardHeader className="flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle>{title}</CardTitle>
        <Icon className={`h-4 w-4 ${toneCls}`} />
      </CardHeader>
      <CardContent><div className="text-2xl font-semibold tabular-nums">{value}</div></CardContent>
    </Card>
  );
}

export default async function DashboardPage() {
  const supabase = await createServerSupabase();

  const [{ data: kpi }, { data: settings }, { data: activity }, { data: byCat }] = await Promise.all([
    supabase.from('v_dashboard_kpis').select('*').maybeSingle<DashboardKpis>(),
    supabase.from('company_settings').select('base_currency, timezone').maybeSingle(),
    supabase.from('v_stock_ledger').select('ref_no, txn_type, status, item_name, quantity, posted_at')
      .eq('status', 'posted').order('posted_at', { ascending: false }).limit(8),
    supabase.from('v_item_full').select('category_name, stock_value'),
  ]);

  const currency = settings?.base_currency ?? 'PKR';
  const tz = settings?.timezone ?? 'Asia/Karachi';
  const k = kpi ?? ({} as DashboardKpis);

  // Aggregate inventory value by category (server-side; chart never loads the ledger).
  const catMap = new Map<string, number>();
  for (const r of byCat ?? []) {
    const key = r.category_name ?? 'Uncategorised';
    catMap.set(key, (catMap.get(key) ?? 0) + Number(r.stock_value ?? 0));
  }
  const chartData = [...catMap.entries()].map(([name, value]) => ({ name, value: Math.round(value) }));

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Dashboard</h1>
        <p className="text-sm text-muted-foreground">Live operational overview — every figure from the ledger.</p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Kpi title="Total inventory value" value={formatMoney(k.total_inventory_value ?? 0, currency)} icon={Boxes} />
        <Kpi title="Total items" value={formatQty(k.total_items ?? 0)} icon={PackageCheck} />
        <Kpi title="Available stock" value={formatQty(k.total_available ?? 0)} icon={TrendingUp} tone="success" />
        <Kpi title="Reserved stock" value={formatQty(k.total_reserved ?? 0)} icon={Clock} />
        <Kpi title="Low-stock items" value={formatQty(k.low_stock_items ?? 0)} icon={AlertTriangle} tone="warning" />
        <Kpi title="Out-of-stock items" value={formatQty(k.out_of_stock_items ?? 0)} icon={PackageX} tone="danger" />
        <Kpi title="Active projects" value={formatQty(k.active_projects ?? 0)} icon={FolderKanban} />
        <Kpi title="Pending POs" value={formatQty(k.pending_pos ?? 0)} icon={ShoppingCart} />
        <Kpi title="Pending approvals" value={formatQty(k.pending_approvals ?? 0)} icon={ShieldAlert} tone="warning" />
        <Kpi title="Received this month" value={formatQty(k.received_this_month ?? 0)} icon={TrendingUp} tone="success" />
        <Kpi title="Consumed this month" value={formatQty(k.consumed_this_month ?? 0)} icon={TrendingDown} />
        <Kpi title="Damaged value" value={formatMoney(k.damaged_value ?? 0, currency)} icon={AlertTriangle} tone="danger" />
      </div>

      <div className="grid gap-6 lg:grid-cols-3">
        <Card className="lg:col-span-2">
          <CardHeader><CardTitle>Inventory value by category</CardTitle></CardHeader>
          <CardContent><InventoryValueChart data={chartData} currency={currency} /></CardContent>
        </Card>

        <Card>
          <CardHeader><CardTitle>Recent activity</CardTitle></CardHeader>
          <CardContent className="space-y-3">
            {(activity ?? []).length === 0 && (
              <p className="text-sm text-muted-foreground">No posted transactions yet.</p>
            )}
            {(activity ?? []).map((a, i) => (
              <div key={i} className="flex items-center justify-between gap-2 text-sm">
                <div className="min-w-0">
                  <div className="truncate font-medium">{a.item_name}</div>
                  <div className="text-xs text-muted-foreground">{a.ref_no} · {formatInTz(a.posted_at, tz)}</div>
                </div>
                <div className="flex shrink-0 items-center gap-2">
                  <span className="tabular-nums text-muted-foreground">{formatQty(a.quantity)}</span>
                  <Badge tone={statusTone(a.status)}>{a.txn_type.replace(/_/g, ' ')}</Badge>
                </div>
              </div>
            ))}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
