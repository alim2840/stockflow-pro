import { createServerSupabase } from '@/lib/supabase/server';
import { Card, Badge } from '@/components/ui/primitives';
import { formatInTz } from '@/lib/utils';

export const dynamic = 'force-dynamic';

export default async function AuditPage() {
  const supabase = await createServerSupabase();
  // RLS: only users with audit.view (or admins) receive rows. The log is immutable.
  const [{ data: logs }, { data: settings }] = await Promise.all([
    supabase.from('audit_logs')
      .select('id, action, module, record_type, reference_no, result, created_at')
      .order('created_at', { ascending: false }).limit(100),
    supabase.from('company_settings').select('timezone').maybeSingle(),
  ]);
  const tz = settings?.timezone ?? 'Asia/Karachi';

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Audit Log</h1>
        <p className="text-sm text-muted-foreground">Immutable record of critical actions (latest 100)</p>
      </div>
      <Card className="overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="border-b bg-muted/40 text-left text-xs uppercase text-muted-foreground">
              <tr>
                <th className="px-4 py-3 font-medium">When</th>
                <th className="px-4 py-3 font-medium">Action</th>
                <th className="px-4 py-3 font-medium">Module</th>
                <th className="px-4 py-3 font-medium">Reference</th>
                <th className="px-4 py-3 font-medium">Result</th>
              </tr>
            </thead>
            <tbody>
              {(logs ?? []).map((l) => (
                <tr key={l.id} className="border-b last:border-0">
                  <td className="px-4 py-3 text-muted-foreground">{formatInTz(l.created_at, tz)}</td>
                  <td className="px-4 py-3 font-medium">{l.action}</td>
                  <td className="px-4 py-3 text-muted-foreground">{l.module ?? '—'}</td>
                  <td className="px-4 py-3 font-mono text-xs">{l.reference_no ?? '—'}</td>
                  <td className="px-4 py-3">
                    <Badge tone={l.result === 'success' ? 'success' : 'danger'}>{l.result ?? '—'}</Badge>
                  </td>
                </tr>
              ))}
              {(logs ?? []).length === 0 && (
                <tr><td colSpan={5} className="px-4 py-10 text-center text-muted-foreground">No audit entries visible.</td></tr>
              )}
            </tbody>
          </table>
        </div>
      </Card>
    </div>
  );
}
