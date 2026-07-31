import { ModuleScaffold } from '@/components/module-scaffold';
export const dynamic = 'force-dynamic';
export default function Page() {
  return <ModuleScaffold title="Purchasing"
    blurb="Requisitions → POs → goods receipts. Receiving posts to the ledger only when a GRN is posted."
    backedBy={['purchase_orders', 'goods_receipts', 'post_goods_receipt()']} />;
}
