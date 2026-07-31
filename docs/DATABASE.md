# StockFlow Pro — Database Design

PostgreSQL 15. 14 migrations in `supabase/migrations/`. Applied and tested
end-to-end (see `docs/TESTING.md`).

## Migration map
| File | Contents |
|------|----------|
| 0001 | extensions (pgcrypto, citext, btree_gist) + all enums |
| 0002 | organisations, company_settings, profiles, roles, permissions, scoped access |
| 0003 | warehouses, storage_locations, categories, brands, units, suppliers, items |
| 0004 | **stock ledger** (immutable), reservations, balance views |
| 0005 | requisitions, purchase orders, goods receipts |
| 0006 | projects, members, requirements, project material balance view |
| 0007 | transfers, stock counts, BOM, production orders, exchange rates |
| 0008 | numbering sequences, approvals, attachments, notifications, backups, **audit log** |
| 0009 | permission helpers, numbering fn, `post_stock_transaction`, `reverse_*`, reservations, costing |
| 0010 | `post_goods_receipt`, `post_transfer_dispatch/receive`, `post_stock_count` |
| 0011 | Row Level Security (org + warehouse/project scope, command-specific writes) |
| 0012 | permission catalog, 7 default roles + grants, `bootstrap_organisation()` |
| 0013 | report/dashboard views |
| 0014 | Mindtune Innovations demo seed (all workflows) |

## Entity-relationship (core)

```mermaid
erDiagram
  organisations ||--o{ profiles : has
  organisations ||--|| company_settings : configures
  organisations ||--o{ warehouses : owns
  organisations ||--o{ items : owns
  organisations ||--o{ projects : owns
  roles ||--o{ role_permissions : grants
  permissions ||--o{ role_permissions : in
  profiles ||--o{ user_roles : assigned
  roles ||--o{ user_roles : to
  profiles ||--o{ user_warehouse_access : scoped
  profiles ||--o{ user_project_access : scoped
  warehouses ||--o{ storage_locations : contains
  items ||--o{ stock_transaction_lines : moves
  warehouses ||--o{ stock_transaction_lines : at
  stock_transactions ||--o{ stock_transaction_lines : has
  stock_transactions ||--o| stock_transactions : reverses
  items ||--o{ stock_reservations : reserved
  projects ||--o{ project_material_requirements : needs
  suppliers ||--o{ purchase_orders : receives
  purchase_orders ||--o{ purchase_order_lines : has
  purchase_orders ||--o{ goods_receipts : fulfilled_by
  goods_receipts ||--o{ goods_receipt_lines : has
  warehouse_transfers ||--o{ warehouse_transfer_lines : has
  stock_counts ||--o{ stock_count_lines : has
  bills_of_material ||--o{ bill_of_material_lines : has
  production_orders }o--|| bills_of_material : uses
  organisations ||--o{ audit_logs : records
  organisations ||--o{ backup_jobs : schedules
```

## Key formulas

```
on_hand(item, warehouse)   = Σ signed_quantity  over lines where txn.status ∈ {posted, reversed}
reserved(item, warehouse)  = Σ quantity         over active reservations
available(item, warehouse) = max(on_hand − reserved, 0)   -- usable warehouses only
org available(item)        = Σ available over warehouses where counts_as_available
stock_value(item)          = on_hand × average_cost
project with_project(item) = issued − consumed − returned − damaged
```

`signed_quantity = quantity × txn_direction(type)` (frozen at posting). Direction:
`+1` opening/receipt/customer_return/project_return/transfer_in/adjustment_increase;
`−1` issue/consumption(prod)/supplier_return/transfer_out/damage/expiry/loss/adjustment_decrease;
`0` project_consumption, count_variance, reversal, assembly_* (sign set explicitly per line).

## Costing
- **Moving weighted average** (default): on posting a `purchase_receipt` /
  `opening_balance` / `assembly_output` with cost,
  `new_avg = (old_qty·old_avg + recv_qty·unit_cost) / (old_qty + recv_qty)`; written to
  `items.average_cost` and appended to `item_cost_history`.
- **FIFO** scaffolded via `items.costing_method` for future layered costing.
- **Landed cost**: PO `freight` / `other_charges` / `tax_total` fields support
  allocation into unit cost at receipt (allocation hook documented).

## Data-integrity guarantees (§32) → mechanism
| Must prevent | Mechanism |
|--------------|-----------|
| Duplicate SKUs / reference numbers | `unique(org,sku)`, `unique(org,ref_no)`, locked `next_reference()` |
| Negative/zero quantities | `check(quantity > 0)`; posting negative-stock guard |
| Unauthorised warehouse/project access | RLS scope policies |
| Over-receipt | `chk_not_over_received` on PO lines |
| Return/consume more than held | project balance checks in issue/return RPC + tests |
| Reversing/completing/posting twice | single-use reversal guard, status guards, idempotency key |
| Deleting referenced masters | FK `on delete` restrictions + archival columns |
| Closing project with unresolved stock | close guard on `with_project ≠ 0` |
| Concurrent double posting | row lock + advisory lock |
| Editing posted records | immutability triggers (`guard_posted_txn`, `guard_posted_lines`) |
| Editing audit log | `guard_audit_immutable` (no UPDATE/DELETE) |

## Views ↔ screens
| View | Used by |
|------|---------|
| `v_item_full`, `v_item_balance` | Item list/detail, valuation |
| `v_item_warehouse_balance` | Stock by warehouse, availability |
| `v_low_stock` | Low/out-of-stock reports, alerts |
| `v_inventory_valuation` | Valuation report, dashboard value |
| `v_stock_ledger` | Stock ledger / item movement report |
| `v_project_material_balance` | Project material balance screen |
| `v_dashboard_kpis` | Dashboard cards |

## RPCs (server-mediated writes)
`post_stock_transaction`, `reverse_stock_transaction`, `create_reservation`,
`release_reservation`, `post_goods_receipt`, `post_transfer_dispatch`,
`post_transfer_receive`, `post_stock_count`, `next_reference`,
`bootstrap_organisation`. All are `SECURITY DEFINER` with pinned `search_path` and
call `require_permission()`.
