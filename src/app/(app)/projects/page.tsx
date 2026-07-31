import { createServerSupabase } from '@/lib/supabase/server';
import { Card, Badge } from '@/components/ui/primitives';
import { formatInTz } from '@/lib/utils';
import { FolderKanban } from 'lucide-react';

export const dynamic = 'force-dynamic';

type Tone = 'success' | 'warning' | 'danger' | 'info';
const tone = (s: string): Tone =>
  s === 'active' ? 'success'
  : s === 'on_hold' ? 'warning'
  : ['cancelled', 'archived'].includes(s) ? 'danger'
  : 'info';

export default async function ProjectsPage() {
  const supabase = await createServerSupabase();
  // RLS returns only assigned projects (org admins see all in-org).
  const { data: projects } = await supabase.from('projects')
    .select('id, ref_no, code, name, status, country_code, start_date, target_date')
    .order('created_at', { ascending: false });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Projects</h1>
        <p className="text-sm text-muted-foreground">{projects?.length ?? 0} project(s)</p>
      </div>
      <div className="grid gap-4 md:grid-cols-2">
        {(projects ?? []).map((p) => (
          <Card key={p.id} className="p-5">
            <div className="flex items-start justify-between gap-2">
              <div className="flex items-center gap-3">
                <div className="grid h-9 w-9 place-items-center rounded-md bg-primary/10 text-primary">
                  <FolderKanban className="h-5 w-5" />
                </div>
                <div>
                  <div className="font-medium">{p.name}</div>
                  <div className="text-xs text-muted-foreground">{p.ref_no} · {p.code}</div>
                </div>
              </div>
              <Badge tone={tone(p.status)}>{p.status.replace(/_/g, ' ')}</Badge>
            </div>
            <div className="mt-3 text-xs text-muted-foreground">
              {p.country_code ?? '—'} · {formatInTz(p.start_date, 'UTC', false)} → {formatInTz(p.target_date, 'UTC', false)}
            </div>
          </Card>
        ))}
        {(projects ?? []).length === 0 && (
          <Card className="col-span-full p-10 text-center text-sm text-muted-foreground">
            No projects assigned to you yet.
          </Card>
        )}
      </div>
    </div>
  );
}
