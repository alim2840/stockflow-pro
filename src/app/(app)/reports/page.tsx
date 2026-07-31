import { ModuleScaffold } from '@/components/module-scaffold';
export const dynamic = 'force-dynamic';
export default function Page() {
  return <ModuleScaffold title="Reports"
    blurb="Stock, valuation, ledger, movement, low stock, project material, supplier spend — all filterable & exportable."
    backedBy={['v_inventory_valuation', 'v_stock_ledger', 'v_low_stock', 'v_project_material_balance']} />;
}
