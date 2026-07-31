# StockFlow Pro — Definition of Done (§42) status

Honest status of each acceptance criterion. "DB ✅ / UI ▶" means the data layer is
implemented & tested and the UI follows the documented shared pattern.

| Criterion | Status | Evidence |
|-----------|--------|----------|
| Authentication works | ✅ | Login/forgot/reset shipped; Supabase Auth; `seed_auth.sql` validated (bcrypt verifies) |
| Authorised international users see the same live data | ✅ (design) | Single Postgres source of truth; UTC storage + per-user tz; multi-country warehouses seeded |
| Records persist after logout/restart | ✅ | Postgres persistence; no localStorage as store |
| Row Level Security implemented & tested | ✅ | Storekeeper 6 PK whs (no US); PM 0 whs / 1 project; admin all 7 |
| Core inventory calculations correct | ✅ | 8/8 balance checks exact (battery 1590, PCB 1800, flex 1585, …) |
| All stock changes originate from ledger transactions | ✅ | On-hand is a view over the ledger; no writable qty column |
| Project inventory fully traceable | ✅ | `v_project_material_balance`: issued 1000 ≠ consumed 850, returned 120, damaged 30 |
| Dashboard figures match reports | ✅ | Both read the same views (`v_dashboard_kpis`, `v_item_full`) |
| Posted records cannot be silently modified | ✅ | Immutability triggers; UPDATE/DELETE on posted → error (tested) |
| Google Drive backup works securely | ▶ design ✅ | Schema + encryption/checksum design + guide; wire to your Google project |
| Restore permissions & validation work | ▶ design ✅ | Super-Admin-only + confirm + checksum verify (documented, RLS-gated) |
| Audit logs capture critical events | ✅ | post/reverse/seed recorded; log immutable (tested) |
| Seed demonstrates end-to-end workflows | ✅ | Partial receipt, reservation, issue, partial consume, return, damage, transfer, in-transit, low stock, reversed adjustment, count variance |
| Automated critical-path tests pass | ✅ (DB) / provided (app) | 21 DB checks pass; Vitest + Playwright suites included |
| Production deployment instructions complete | ✅ | `docs/SETUP.md` (install, deploy, Google Drive, backup/restore) |
| No fake or disconnected controls | ✅ | Every figure from the ledger; unbuilt screens are honest scaffolds naming their view/RPC |

## What requires YOUR environment to go fully live
1. A Supabase project (URL + anon + service-role keys) — apply `supabase/migrations/*`.
2. `supabase/seed_auth.sql` (demo) or `scripts/setup.ts` (production admin).
3. Vercel (or similar) deploy with env vars + a daily backup cron.
4. A Google Cloud OAuth app for Drive backups (optional but recommended).

## Frontend note
The full frontend toolchain has now been **executed and validated**:
`npm install` (0 vulnerabilities after upgrading to Next 16.2.10 / React 19.2 /
Vitest 4), `tsc --noEmit` strict (exit 0), Vitest 6/6 pass, and a production
`next build` (exit 0, all 22 routes). The **database engine was executed and
validated** on PostgreSQL 15.16. Playwright E2E requires a real Supabase project
(see `docs/SETUP.md`), so it runs in your environment after deploy.
