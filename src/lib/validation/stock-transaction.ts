import { z } from 'zod';

// Positive-quantity rule mirrors the DB CHECK(quantity > 0).
const positive = z.coerce.number().positive('Quantity must be greater than zero');
const nonNegative = z.coerce.number().min(0, 'Cannot be negative');

export const stockTxnTypeEnum = z.enum([
  'opening_balance', 'purchase_receipt', 'project_issue', 'general_issue',
  'project_consumption', 'production_consumption', 'project_return',
  'supplier_return', 'customer_return', 'transfer_out', 'transfer_in',
  'damage', 'expiry', 'loss', 'adjustment_increase', 'adjustment_decrease',
  'count_variance', 'assembly_output', 'disassembly',
]);

export const stockTxnLineSchema = z.object({
  item_id: z.string().uuid(),
  warehouse_id: z.string().uuid(),
  location_id: z.string().uuid().optional().nullable(),
  quantity: positive,
  unit_cost: nonNegative.default(0),
  batch_no: z.string().max(64).optional().nullable(),
  serial_no: z.string().max(64).optional().nullable(),
  expiry_date: z.string().date().optional().nullable(),
});

export const stockTxnSchema = z.object({
  txn_type: stockTxnTypeEnum,
  txn_date: z.string().date(),
  project_id: z.string().uuid().optional().nullable(),
  supplier_id: z.string().uuid().optional().nullable(),
  currency: z.string().length(3).optional(),
  reason: z.string().max(500).optional(),
  notes: z.string().max(2000).optional(),
  // Idempotency key prevents accidental double submits from creating dupes.
  idempotency_key: z.string().uuid(),
  lines: z.array(stockTxnLineSchema).min(1, 'At least one line is required'),
}).refine(
  (d) => d.txn_type !== 'transfer_out' ||
    new Set(d.lines.map((l) => l.warehouse_id)).size >= 1,
  { message: 'Transfer source and destination must differ', path: ['lines'] },
);

export type StockTxnInput = z.infer<typeof stockTxnSchema>;
