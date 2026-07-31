import { createServerSupabase } from '@/lib/supabase/server';
import { Card, Badge } from '@/components/ui/primitives';
import { Warehouse } from 'lucide-react';

export const dynamic = 'force-dynamic';

export default async function WarehousesPage() {
  const supabase = await createServerSupabase();
  // RLS returns only warehouses the user may access.
  const { data: warehouses } = await supabase.from('warehouses')
    .select('id, code, name, kind, country_code, counts_as_available, is_active')
    .order('name');

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Warehouses</h1>
        <p className="text-sm text-muted-foreground">{warehouses?.length ?? 0} accessible location(s)</p>
      </div>
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {(warehouses ?? []).map((w) => (
          <Card key={w.id} className="p-5">
            <div className="flex items-start justify-between">
              <div className="grid h-9 w-9 place-items-center rounded-md bg-primary/10 text-primary">
                <Warehouse className="h-5 w-5" />
              </div>
              {!w.counts_as_available && <Badge tone="warning">Non-available</Badge>}
            </div>
            <div className="mt-3 font-medium">{w.name}</div>
            <div className="text-xs text-muted-foreground">
              {w.code} · {w.country_code ?? '—'} · {String(w.kind).replace(/_/g, ' ')}
            </div>
          </Card>
        ))}
        {(warehouses ?? []).length === 0 && (
          <Card className="col-span-full p-10 text-center text-sm text-muted-foreground">
            You don&apos;t have access to any warehouses yet.
          </Card>
        )}
      </div>
    </div>
  );
}
