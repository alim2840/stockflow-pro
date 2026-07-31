# StockFlow Pro

A premium, internet-connected **inventory & project management platform** for
multi-country teams. PostgreSQL is the single source of truth; the same live data
serves users in Pakistan, the US, and beyond. Google Drive is an encrypted
*secondary* backup layer only.

> **Stack:** Next.js 16 (App Router, TypeScript, React 19) · Tailwind + shadcn/ui · Lucide ·
> Recharts · Supabase (PostgreSQL, Auth, Storage) · Zod · React Hook Form ·
> TanStack Table · Playwright + Vitest · optional Tauri shell.

---

## What this repository is

This is a **production-grade foundation**, not a mockup. The hardest, most
safety-critical layer — the database engine — is **fully implemented and tested on
real PostgreSQL 15**:

- ✅ Immutable, ledger-based inventory (on-hand is always derived, never overwritten)
- ✅ Atomic, concurrency-safe posting with **negative-stock protection** and **idempotency**
- ✅ **Reversal-based corrections** (posted rows are immutable; equal-and-opposite entries)
- ✅ Race-safe server-side reference numbering
- ✅ **Row Level Security** — org isolation + warehouse/project scoping, enforced in the DB
- ✅ Immutable **audit log**
- ✅ 7 roles + granular permission matrix, enforced in RPCs and RLS
- ✅ Realistic **seed** (Mindtune Innovations) exercising every workflow
- ✅ 21 DB integration checks pass (see `docs/TESTING.md`)

The web app ships a connected reference implementation (auth, dashboard, items,
stock transactions) plus configuration, Supabase wiring, validation, and tests.
Every remaining screen follows one documented pattern (Server Component read under
RLS → TanStack Table → Server Action → RPC), mapped in `docs/ARCHITECTURE.md`.

## Honest scope

A live, multi-country deployment requires **your own** Supabase project, Vercel (or
similar) account, and — for Drive backups — a Google Cloud OAuth app. Follow
`docs/SETUP.md` to stand it up in ~30 minutes. Nothing here uses fake data or
disconnected controls; every number comes from the ledger.

## Repository layout
```
supabase/migrations/   14 SQL migrations (schema, ledger, RPCs, RLS, roles, seed)
src/app/               Next.js App Router (auth, dashboard, items, stock txn, ...)
src/lib/               supabase clients, money/decimal utils, zod schemas, permissions
src/components/        UI (shadcn-style)
tests/db/              engine_tests.sql (reproducible)
tests/unit/            Vitest (money, direction, formulas)
tests/e2e/             Playwright (auth + inventory happy paths)
scripts/setup.ts       create/link Supabase Auth users to seed profiles
docs/                  ARCHITECTURE, DATABASE, PERMISSION-MATRIX, SETUP, TESTING
```

## Quick start
```bash
cp .env.example .env.local     # fill Supabase URL + keys
npm install
supabase db push               # apply migrations (or psql loop — see docs/SETUP.md)
npx tsx scripts/setup.ts       # create demo logins
npm run dev
```

## Documentation
- `docs/ARCHITECTURE.md` — system design, workflow & state diagrams, screen map, risks
- `docs/DATABASE.md` — ERD, formulas, costing, integrity guarantees, views & RPCs
- `docs/PERMISSION-MATRIX.md` — roles × actions, scope rules
- `docs/SETUP.md` — install, deploy, Google Drive, backup & restore, admin setup
- `docs/TESTING.md` — executed test report + checklists + known limitations

## Non-negotiables honoured
Google Drive is never the operational DB · PostgreSQL is the source of truth ·
no localStorage as primary store · no fake controls · every figure from real
records · on-hand from a permanent ledger · users never overwrite stock quantities ·
posted transactions are immutable · corrections via reversal · every important
action audited · permissions enforced in the database · secrets never in the client.

Licensed for the requesting organisation's internal use.
