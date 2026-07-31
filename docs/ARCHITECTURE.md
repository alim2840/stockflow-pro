# StockFlow Pro — System Architecture (Phase 1)

A production-grade, internet-connected inventory & project management platform.
PostgreSQL is the single source of truth; the same live database serves
authorised users in Pakistan, the US, or anywhere. Google Drive is a *secondary*
encrypted-backup layer only — never the operational store.

---

## 1. High-level architecture

```
        Windows desktop / laptop (Chromium, Edge) ── optional Tauri shell
                              │  HTTPS (TLS)
                              ▼
              ┌─────────────────────────────────┐
              │  Next.js 16 (App Router, TS)     │  Vercel edge/serverless
              │  • Server Components (reads)      │
              │  • Server Actions / Route Handlers│  ← service role NEVER in browser
              │  • Middleware: session refresh    │
              └───────────────┬─────────────────┘
                              │  supabase-js (anon key + user JWT)
                              ▼
   ┌──────────────────────────────────────────────────────────────┐
   │                         Supabase                               │
   │  Auth (email/pw, reset, 2FA)   Storage (attachments, private)  │
   │  PostgreSQL 15                                                  │
   │   • Normalised schema + constraints + indexes                  │
   │   • Immutable stock ledger (source of truth)                   │
   │   • SECURITY DEFINER posting/reversal RPCs                     │
   │   • Row Level Security (org + warehouse + project scope)       │
   │   • Immutable audit log                                        │
   └───────────────┬───────────────────────────────┬──────────────┘
                   │ pg native PITR backups         │ nightly job (server)
                   ▼                                 ▼
        Supabase automated backups        Encrypted export → Google Drive
                                          (AES-256-GCM, checksum, retention)
```

**Why this shape**
- Reads run as **Server Components** using the caller's JWT, so RLS applies
  automatically and no service-role key touches the browser.
- All *writes that change stock* go through **database RPCs** (`post_stock_transaction`,
  `reverse_stock_transaction`, `post_goods_receipt`, `post_transfer_*`,
  `post_stock_count`). This guarantees atomicity, permission checks, negative-stock
  protection and audit — regardless of which client calls them.
- Multi-country correctness: **all timestamps are `timestamptz` (UTC)**; the UI
  converts to each user's timezone. Money is `numeric(18,4)` — never float.

---

## 2. Request/trust boundaries

| Concern | Where enforced |
|--------|----------------|
| Authentication | Supabase Auth (hashed pw, email verify, reset, optional 2FA) |
| Authorisation (action) | `require_permission()` inside every RPC + RLS write policies |
| Authorisation (row scope) | RLS: `current_org()`, `has_warehouse_access()`, `has_project_access()`, `is_org_admin()` |
| Secrets | Server env only; service role + Google creds never shipped to client |
| Integrity | FK/unique/check constraints, immutability triggers, idempotency keys |
| Concurrency | Row locks + `pg_advisory_xact_lock` per (item,warehouse); upsert-locked numbering |

---

## 3. Inventory model (the core idea)

- **On-hand is never stored.** It is `SUM(signed_quantity)` over ledger lines whose
  transaction is `posted` or `reversed` (a reversed original and its reversal cancel
  to zero). See `v_item_warehouse_balance`.
- **`signed_quantity`** is frozen at posting from `txn_direction(type)`; the
  user-entered `quantity` is always positive (business rule).
- **Available = on-hand − reserved** (usable warehouses only). Reservations reduce
  available, never on-hand.
- **In-transit** is derived from transfer records dispatched-but-not-received, so a
  dispatched transfer never appears as available destination stock.
- **Damage/quarantine** live in warehouses flagged `counts_as_available = false`.

State machine for a stock transaction:

```
draft ──▶ pending_approval ──▶ approved ──▶ posted ──▶ (reversed)
   │             │                              ▲
   └── rejected ─┘                              └─ immutable; corrections via reversal
```

---

## 4. Workflow diagrams

### 4.1 Login & account recovery
```
User → login (email+pw) → Supabase Auth → JWT (+ optional 2FA)
  fail → failed_login counter; lockout after N; audit 'failed_login'
Forgot pw → email link (never reveal if account exists) → reset → audit
Invite → invited → activate (set pw) → active | suspend → suspended
```

### 4.2 Purchase requisition → stock receipt
```
Requisition(draft) → approve → PO(draft) → approve → send to supplier
   → Goods Receipt(draft, partial allowed) → POST GRN
        → post_goods_receipt(): ledger 'purchase_receipt' (+qty), moving-avg cost,
          PO line received_qty += , PO status = partially_received | received
```
*Ledger entries are created only when the GRN is posted. Over-receipt is blocked by
`purchase_order_lines.chk_not_over_received`.*

### 4.3 Project requirement → reservation → issue → consumption → return
```
Requirement → check available → create_reservation() (available−, on-hand unchanged)
   → approve issue → project_issue (warehouse −qty; reservation released)
   → project_consumption (records usage; issued ≠ consumed)
   → project_return (warehouse +qty)   → damage/loss (project-held reduced)
Close project only when with-project balance resolved.
```

### 4.4 Warehouse transfer (in-transit safe)
```
Transfer(draft) → approve → dispatch: transfer_out (source −qty), status=dispatched
   [in transit — derived, not available anywhere]
receive: transfer_in (dest +qty), status=completed  (cannot complete twice)
```

### 4.5 Stock count & variance
```
Count session → snapshot expected qty (frozen) → count → recount → variance
   → approve → post_stock_count(): count_variance adjustment (signed per line)
Nothing changes stock until an APPROVED count is posted.
```

### 4.6 Transaction reversal
```
reverse_stock_transaction(id, reason):
  guard: must be 'posted' and not already reversed (single-use)
  create 'reversal' txn with equal & opposite lines → post → mark original 'reversed'
  audit 'reverse'
```

### 4.7 Production / assembly
```
Production order(planned) → release → in_progress →
  post: production_consumption (components −, incl. wastage) + assembly_output
        (finished good +, cost = Σ component cost / qty). Prevent duplicate completion.
```

### 4.8 Backup & restore
```
Backup (manual|scheduled) → structured export → AES-256-GCM encrypt → checksum
   → upload to Google Drive folder → record backup_files → alert on failure
Restore (Super Admin only) → explicit confirm → verify checksum/decrypt
   → staged apply → audit 'restore'
```

---

## 5. Screen map (§35) & build status

| Area | Screens | Status |
|------|---------|--------|
| Auth | Login, Forgot pw, Reset pw, Profile | Login shipped; others scaffolded |
| Dashboard | Operational dashboard (KPIs + charts + activity) | Shipped (reads `v_dashboard_kpis`) |
| Inventory | Item list, Item detail, New item, Categories, Warehouses, Locations, Stock ledger | Item list + detail shipped; rest patterned |
| Stock txn | New txn, Txn detail, Approval, Reversal | New/detail shipped; approval/reversal call RPCs |
| Purchasing | Requisitions, POs, Goods receipts, Suppliers | Data layer + patterns provided |
| Projects | List, Detail, Requirements, Reservations, Issues, Consumption, Returns | Data layer + views provided |
| Ops | Transfers, Stock counts, BOM, Production orders | RPCs provided |
| System | Reports, Notifications, Users, Roles, Audit, Backups, Settings (company/inventory/security) | Data layer + RPCs provided |

All screens share one pattern: **Server Component reads a view/table under RLS →
TanStack Table with server pagination/filter → mutations call a Server Action that
invokes an RPC**. `docs/DATABASE.md` lists the exact view/RPC for each.

---

## 6. Implementation plan (phased)

- **Phase 1 — Planning (this document set):** architecture, ERD, permission matrix,
  formulas, workflow & state diagrams, screen map, risks. ✅
- **Phase 2 — Foundation:** schema, RLS, roles, numbering, org/user/warehouse/item. ✅ (DB) + app config/auth ✅
- **Phase 3 — Inventory engine:** immutable ledger, posting, reservations, reversals,
  balances, concurrency, tests. ✅ **built & tested on real Postgres.**
- **Phase 4 — Business modules:** purchasing, suppliers, projects, transfers, counts,
  production, reports, notifications. DB layer ✅; UI build-out follows the shared pattern.
- **Phase 5 — Backup & security:** Google Drive OAuth, encrypted backups, scheduling,
  restore, security review. Design + schema + docs ✅; wire to your Google project.
- **Phase 6 — Quality:** seed ✅, automated tests ✅ (DB) + Vitest/Playwright provided,
  responsive/a11y passes.
- **Phase 7 — Delivery:** source, migrations, seed, env template, setup/deploy/backup
  guides, permission matrix, DB docs, testing report. ✅

---

## 7. Technical risks & mitigations

| Risk | Impact | Mitigation (implemented) |
|------|--------|--------------------------|
| Concurrent double-posting / race on balances | Wrong stock, oversell | Header row lock + `pg_advisory_xact_lock` per (item,warehouse); idempotency key unique |
| Duplicate reference numbers under load | Data collision | `next_reference()` upsert takes a row lock; unique `(org,ref_no)` |
| Silent edit/delete of posted records | Fraud, untraceable | Immutability triggers on ledger + audit; corrections only via reversal |
| Negative inventory | Impossible balances | Posting blocks negative unless `allow_negative_stock`; checked post-aggregate |
| Cross-tenant/data leakage | Security breach | Force-RLS on all tables; org + scope policies; command-specific writes (leak found & fixed in test) |
| Service-role/Google secret exposure | Full compromise | Server-only env; RPC-mediated writes; refresh tokens encrypted server-side |
| Issued treated as consumed | Cost & availability errors | Separate ledger types; `v_project_material_balance` distinguishes both |
| Reversal double-counting | Balance drift | Balance includes `posted`+`reversed`; single-use reversal guard (bug caught in test) |
| Dashboard loading whole ledger | Perf collapse | All figures via aggregate views (`v_dashboard_kpis`); server pagination everywhere |
| Backup integrity/tamper | Bad DR | AES-256-GCM + SHA-256 checksum + verify on upload; Super-Admin-only restore with confirm |
| Moving-average cost on reversal | Cost drift (minor) | Documented limitation; forward costing correct; FIFO scaffolded |
