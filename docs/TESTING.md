# StockFlow Pro — Testing Report & Checklist

The database engine was executed and validated on **PostgreSQL 15.16** (all 14
migrations + seed applied with `ON_ERROR_STOP`, exit 0). Results below are from
real runs, not assertions on paper.

## A. Database engine (executed — PASS)

| # | Test | Expected | Result |
|---|------|----------|--------|
| 1 | Apply 14 migrations + seed | clean, exit 0 | ✅ `Seed complete` |
| 2 | Opening + partial receipt: PCB main | 1200 + 600 = 1800 | ✅ 1800 |
| 3 | Project issue reduces warehouse: battery | 2500−1000+120−30 = 1590 | ✅ 1590 |
| 4 | Issued ≠ consumed (project balance) | issued 1000, consumed 850, returned 120, damaged 30, with-project 0 | ✅ exact |
| 5 | Reservation reduces available, not on-hand | on-hand unchanged; available −reserved | ✅ |
| 6 | Transfer: USB main→US | main 2000→1800, US 0→200 | ✅ |
| 7 | In-transit not available at destination | dispatched 150 SPK leaves source, not yet at dest | ✅ main 1650, US 0 |
| 8 | Damage to non-available warehouse | Damaged Stock holds 40 boxes; excluded from available | ✅ |
| 9 | Count variance posts adjustment | flex 1600 → 1585 (−15) | ✅ 1585 |
| 10 | Valid issue via RPC (storekeeper) | battery −100 → 1490 | ✅ 1490 |
| 11 | **Idempotent re-post** | second post is a no-op | ✅ still 1490 |
| 12 | **Negative stock blocked** | issue 999,999 rejected | ✅ `check_violation` |
| 13 | **Posted txn immutable** | direct UPDATE rejected | ✅ `check_violation` |
| 14 | **Reversal restores balance** (inventory mgr) | 1490 → 1590, original marked `reversed` | ✅ |
| 15 | **Double reversal blocked** | second reverse rejected | ✅ `check_violation` |
| 16 | Reversal-safe balance math | reversed original + reversal net to 0 (Mic 1800) | ✅ (bug found & fixed) |
| 17 | Viewer cannot post | permission denied | ✅ `insufficient_privilege` |
| 18 | Storekeeper cannot reverse / make users | denied | ✅ |
| 19 | RLS warehouse scope (storekeeper) | 6 PK warehouses, no US | ✅ |
| 20 | RLS project scope (project mgr) | 0 warehouses, 1 project | ✅ |
| 21 | Audit log records post + reverse | rows present, immutable | ✅ |

Reproduce locally: `psql -f tests/db/engine_tests.sql` against a DB with all
migrations applied (see `docs/SETUP.md`).

## B. Application toolchain (executed — PASS)

| Check | Result |
|-------|--------|
| `npm install` | ✅ clean install, **0 vulnerabilities** (`npm audit`, prod + dev) |
| `tsc --noEmit` (strict) | ✅ exit 0 |
| Vitest unit suite | ✅ 6/6 pass (decimal money math, moving average, availability formula, direction map) |
| `next build` (production) | ✅ exit 0 — all 22 routes compile (static auth pages + dynamic app pages + middleware) |

Security hardening performed during this pass:
- **Next.js 14 → 16.2.10** — the entire Next 14 line carried 14 unpatched advisories
  (request smuggling, cache poisoning, XSS, DoS); 16.2.10 is npm's computed fix.
  Migrated `cookies()` and `params`/`searchParams` to the async APIs, added the
  required Suspense boundary around `useSearchParams()` on /login.
- **React 18 → 19.2**, **Vitest 2 → 4** (old chain had a critical advisory),
  nested `postcss` pinned to the patched line via npm `overrides`.

- **E2E (Playwright)** — `tests/e2e/`: valid/invalid login, password reset request,
  unauthorized-page redirect. Run: `npm run test:e2e` against a deployed/local app
  with a seeded Supabase project + demo users (needs real auth, so not runnable
  against placeholder env).
- **DB integration** — `tests/db/engine_tests.sql`: the 21 checks above.

## B2. Windows desktop packaging (Tauri) — verified vs. pending

Executed in this environment (Linux sandbox):
| Check | Result |
|-------|--------|
| Tauri project scaffolding (Cargo.toml, tauri.conf.json, capabilities, main.rs, connect screen) | ✅ authored; JSON validated |
| Icon set generated (`tauri icon`): .ico + all Windows PNG sizes | ✅ committed under `src-tauri/icons/` |
| Login footer developer credit server-renders | ✅ curl-verified: "Developed by Muhammad Ali", "MBA (Finance)", mailto link present in `/login` HTML |
| About screen required content | ✅ curl-verified: all 7 required strings + version 1.0.0 on `/about` (public route) |
| Offline banner component, Suspense-safe login, `tsc` + Vitest + `next build` | ✅ all green after changes |
| Installer metadata (publisher/copyright/developer) configured | ✅ in `tauri.conf.json`; CI step asserts "Muhammad Ali" present in the built EXE's VersionInfo |

Requires Windows (cannot execute on this Linux sandbox — run via the included CI or a Windows machine):
- Compile of `src-tauri` (MSVC), NSIS `.exe` + WiX `.msi` bundling, SHA256SUMS —
  automated in `.github/workflows/windows-release.yml` (windows-latest runner).
- Install/uninstall/reinstall/upgrade tests, Start Menu launch, Installed Apps
  entry, SmartScreen behaviour, WebView2 bootstrap, no-console check,
  window-state persistence, single-instance focus, mailto: → default mail app.
  A step-by-step manual checklist for these is in INSTALLATION-GUIDE.md and
  the workflow prints installer metadata for confirmation.
- Playwright screenshots of /login and /about are captured automatically by the
  workflow's `screenshots` job (uploaded as the `ui-screenshots` artifact).

## C. Manual UX acceptance checklist (§39)
- [ ] Dashboard understandable without training
- [ ] Inline validation on all forms
- [ ] Every transaction shows a status badge
- [ ] Posted transactions reflected in reports
- [ ] Filters persist across navigation
- [ ] Usable at 1366×768
- [ ] Destructive actions confirm
- [ ] Empty / loading / error states present
- [ ] No double-submit (idempotency keys)
- [ ] Logical keyboard tab order
- [ ] Light + dark polished

## Known limitations (documented, not hidden)
1. Moving-average **cost reversal** does not recompute historical average on
   reversal of a receipt (quantity is fully reversed; cost history keeps the
   forward entry). FIFO is scaffolded (`costing_method`) but not yet computed.
2. Email notifications are architected (`notification_preferences`) but delivery
   is in-app only until an email provider is wired.
3. The UI ships core screens (auth, dashboard, items, stock transactions) as a
   connected reference implementation; remaining screens are mapped in
   `docs/ARCHITECTURE.md` §Screen Map and follow the same data/RPC patterns.
