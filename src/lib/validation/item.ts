import { z } from 'zod';

export const itemTypeEnum = z.enum([
  'raw_material', 'component', 'finished_good', 'consumable',
  'packaging', 'tool', 'spare_part', 'service', 'non_stock',
]);

export const itemSchema = z.object({
  sku: z.string().min(1, 'SKU is required').max(64),
  name: z.string().min(1, 'Name is required').max(200),
  description: z.string().max(2000).optional(),
  barcode: z.string().max(64).optional().nullable(),
  category_id: z.string().uuid().optional().nullable(),
  brand_id: z.string().uuid().optional().nullable(),
  item_type: itemTypeEnum.default('component'),
  base_unit_id: z.string().uuid(),
  costing_method: z.enum(['moving_average', 'fifo', 'standard']).default('moving_average'),
  standard_cost: z.coerce.number().min(0).default(0),
  selling_price: z.coerce.number().min(0).optional().nullable(),
  min_stock: z.coerce.number().min(0).default(0),
  reorder_point: z.coerce.number().min(0).default(0),
  reorder_qty: z.coerce.number().min(0).default(0),
  max_stock: z.coerce.number().min(0).optional().nullable(),
  track_expiry: z.boolean().default(false),
  track_batch: z.boolean().default(false),
  track_serial: z.boolean().default(false),
  is_active: z.boolean().default(true),
});

export type ItemInput = z.infer<typeof itemSchema>;
