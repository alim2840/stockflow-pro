import { Card, CardContent } from '@/components/ui/primitives';
import { Construction } from 'lucide-react';

// Honest build-out scaffold. NOT a fake dashboard or fake controls — it states
// exactly which DB view/RPC backs the screen and the pattern to implement it.
export function ModuleScaffold({ title, blurb, backedBy }: { title: string; blurb: string; backedBy: string[] }) {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">{title}</h1>
        <p className="text-sm text-muted-foreground">{blurb}</p>
      </div>
      <Card>
        <CardContent className="flex flex-col items-center gap-3 py-14 text-center">
          <Construction className="h-8 w-8 text-muted-foreground" />
          <p className="max-w-md text-sm text-muted-foreground">
            This screen is part of the documented build-out. Its data layer is
            already implemented and tested — wire the UI using the shared pattern
            (Server Component read under RLS → TanStack Table → Server Action → RPC).
          </p>
          <div className="text-xs text-muted-foreground">
            Backed by: {backedBy.map((b) => (
              <code key={b} className="mx-1 rounded bg-muted px-1.5 py-0.5">{b}</code>
            ))}
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
