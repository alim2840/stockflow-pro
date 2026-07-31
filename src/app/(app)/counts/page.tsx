import { ModuleScaffold } from '@/components/module-scaffold';
export const dynamic = 'force-dynamic';
export default function Page() {
  return <ModuleScaffold title="Stock Counts"
    blurb="Cycle & full counts. Expected qty is frozen at snapshot; adjustments post only after approval."
    backedBy={['stock_counts', 'post_stock_count()']} />;
}
