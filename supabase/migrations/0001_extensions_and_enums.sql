-- =============================================================================
-- StockFlow Pro — 0001_extensions_and_enums.sql
-- Extensions + all enumerated types (single source of truth for domain states)
-- =============================================================================
-- Design notes:
--   * pgcrypto           -> gen_random_uuid() for surrogate keys
--   * citext             -> case-insensitive email / SKU comparisons
--   * All money uses numeric(18,4); all quantities numeric(18,4). NEVER float.
--   * All timestamps are timestamptz (stored UTC). The app converts to the
--     user's timezone for display only.
-- =============================================================================

create extension if not exists "pgcrypto";
create extension if not exists "citext";
create extension if not exists "btree_gist";   -- exclusion constraints if needed later

-- ---------------------------------------------------------------------------
-- Identity / access
-- ---------------------------------------------------------------------------
create type user_status as enum ('invited', 'active', 'suspended', 'inactive');

-- Permission "actions" — the granular verbs from the permission matrix.
create type perm_action as enum (
  'view', 'create', 'edit_draft', 'post', 'approve',
  'reverse', 'export', 'delete_draft', 'manage_settings'
);

-- ---------------------------------------------------------------------------
-- Catalog
-- ---------------------------------------------------------------------------
create type item_type as enum (
  'raw_material', 'component', 'finished_good', 'consumable',
  'packaging', 'tool', 'spare_part', 'service', 'non_stock'
);

create type costing_method as enum ('moving_average', 'fifo', 'standard');

create type warehouse_kind as enum (
  'standard', 'production', 'rnd', 'quality_control',
  'damaged', 'quarantine', 'in_transit'
);

-- ---------------------------------------------------------------------------
-- Stock ledger
-- ---------------------------------------------------------------------------
-- Direction is derived from the type at posting time and frozen into
-- stock_transaction_lines.signed_quantity so balance queries are a plain SUM.
create type stock_txn_type as enum (
  'opening_balance',
  'purchase_receipt',
  'project_issue',
  'general_issue',
  'project_consumption',
  'production_consumption',
  'project_return',
  'supplier_return',
  'customer_return',
  'transfer_out',
  'transfer_in',
  'damage',
  'expiry',
  'loss',
  'adjustment_increase',
  'adjustment_decrease',
  'count_variance',
  'assembly_output',
  'disassembly',
  'reversal'
);

create type stock_txn_status as enum (
  'draft', 'pending_approval', 'approved', 'posted', 'rejected', 'reversed'
);

-- ---------------------------------------------------------------------------
-- Purchasing
-- ---------------------------------------------------------------------------
create type requisition_status as enum (
  'draft', 'pending_approval', 'approved', 'rejected', 'converted', 'cancelled'
);

create type po_status as enum (
  'draft', 'pending_approval', 'approved', 'partially_received',
  'received', 'closed', 'cancelled'
);

create type receipt_status as enum ('draft', 'posted', 'reversed');

-- ---------------------------------------------------------------------------
-- Projects
-- ---------------------------------------------------------------------------
create type project_status as enum (
  'planning', 'approved', 'active', 'on_hold',
  'completed', 'cancelled', 'archived'
);

create type reservation_status as enum ('active', 'released', 'consumed', 'expired');

-- ---------------------------------------------------------------------------
-- Transfers / counts / production
-- ---------------------------------------------------------------------------
create type transfer_status as enum (
  'draft', 'pending_approval', 'approved', 'dispatched',
  'partially_received', 'completed', 'cancelled'
);

create type count_status as enum (
  'draft', 'counting', 'pending_approval', 'approved', 'posted', 'cancelled'
);

create type production_status as enum (
  'draft', 'planned', 'released', 'in_progress', 'completed', 'cancelled'
);

-- ---------------------------------------------------------------------------
-- Cross-cutting
-- ---------------------------------------------------------------------------
create type approval_status as enum ('pending', 'approved', 'rejected');

create type notification_kind as enum (
  'low_stock', 'out_of_stock', 'pending_approval', 'po_overdue',
  'delivery_overdue', 'transfer_awaiting_receipt', 'project_shortage',
  'expiring_item', 'backup_failure', 'count_variance', 'suspicious_login',
  'failed_transaction', 'project_deadline'
);

create type backup_status as enum ('queued', 'running', 'success', 'failed');
create type backup_frequency as enum ('manual', 'daily', 'weekly', 'monthly');

comment on type stock_txn_type is
  'Ledger movement types. Sign (+/-) is resolved at posting time via txn_direction().';
