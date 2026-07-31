import { ModuleScaffold } from '@/components/module-scaffold';
export const dynamic = 'force-dynamic';
export default function Page() {
  return <ModuleScaffold title="Production & Assembly"
    blurb="BOM-driven assembly: consumes components, produces finished goods, computes assembly cost."
    backedBy={['bills_of_material', 'production_orders']} />;
}
