// Hand-written slim types for the rows/views the app reads. Replace with the
// full generated file via:  supabase gen types typescript --linked > src/types/supabase.ts

export interface DashboardKpis {
  org_id: string;
  total_inventory_value: number;
  total_items: number;
  total_on_hand: number;
  total_available: number;
  total_reserved: number;
  low_stock_items: number;
  out_of_stock_items: number;
  active_projects: number;
  pending_pos: number;
  pending_approvals: number;
  received_this_month: number;
  consumed_this_month: number;
  damaged_value: number;
}

export interface ItemFull {
  id: string;
  ref_no: string;
  sku: string;
  name: string;
  item_type: string;
  category_name: string | null;
  base_unit_code: string | null;
  on_hand: number;
  reserved: number;
  available: number;
  average_cost: number;
  stock_value: number;
  reorder_point: number;
  min_stock: number;
  is_active: boolean;
}

export interface StockLedgerRow {
  txn_id: string;
  ref_no: string;
  txn_type: string;
  status: string;
  txn_date: string;
  posted_at: string | null;
  item_name: string;
  warehouse_name: string;
  quantity: number;
  signed_quantity: number;
  unit_cost: number;
  total_cost: number;
}

export interface WarehouseBalance {
  warehouse_id: string;
  warehouse_name: string;
  on_hand: number;
  reserved: number;
  available: number;
}
