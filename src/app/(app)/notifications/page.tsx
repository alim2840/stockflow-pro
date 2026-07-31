import { createServerSupabase } from '@/lib/supabase/server';
import { Card } from '@/components/ui/primitives';
import { formatInTz } from '@/lib/utils';
import { Bell } from 'lucide-react';

export const dynamic = 'force-dynamic';

export default async function NotificationsPage() {
  const supabase = await createServerSupabase();
  const [{ data: { user } }, { data: settings }] = await Promise.all([
    supabase.auth.getUser(),
    supabase.from('company_settings').select('timezone').maybeSingle(),
  ]);
  const { data: notes } = await supabase.from('notifications')
    .select('id, kind, title, body, is_read, created_at')
    .or(`user_id.eq.${user?.id},user_id.is.null`)
    .order('created_at', { ascending: false }).limit(50);
  const tz = settings?.timezone ?? 'Asia/Karachi';

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Notifications</h1>
        <p className="text-sm text-muted-foreground">Low stock, approvals, transfers, backups and more</p>
      </div>
      <Card className="divide-y">
        {(notes ?? []).map((n) => (
          <div key={n.id} className="flex items-start gap-3 p-4">
            <div className={`mt-0.5 grid h-8 w-8 shrink-0 place-items-center rounded-md ${n.is_read ? 'bg-muted text-muted-foreground' : 'bg-primary/10 text-primary'}`}>
              <Bell className="h-4 w-4" />
            </div>
            <div className="min-w-0 flex-1">
              <div className="font-medium">{n.title}</div>
              {n.body && <div className="text-sm text-muted-foreground">{n.body}</div>}
              <div className="mt-1 text-xs text-muted-foreground">{formatInTz(n.created_at, tz)}</div>
            </div>
          </div>
        ))}
        {(notes ?? []).length === 0 && (
          <div className="p-10 text-center text-sm text-muted-foreground">You&apos;re all caught up.</div>
        )}
      </Card>
    </div>
  );
}
