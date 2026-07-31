import { ModuleScaffold } from '@/components/module-scaffold';
export const dynamic = 'force-dynamic';
export default function Page() {
  return <ModuleScaffold title="Suppliers"
    blurb="Supplier profiles, spend, outstanding POs and performance. Bank details are permission-gated."
    backedBy={['suppliers', 'purchase_orders']} />;
}
