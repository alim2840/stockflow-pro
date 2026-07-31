# StockFlow Pro 1.0.0 — Release Notes

**Publisher:** Mindtune Innovations
**Developer:** Muhammad Ali — Accounts & Finance Expert, MBA (Finance) — alim2840@gmail.com
**Date:** 2026-07-16 · **Platforms:** Windows 10 / 11, 64-bit

## Release contents
| File | Purpose |
|---|---|
| `StockFlow-Pro-Setup-x64.exe` | Recommended installer (NSIS). Installs WebView2 automatically, creates Start Menu + optional desktop shortcut, appears in Installed Apps, clean uninstall. |
| `StockFlow-Pro-x64.msi` | MSI package for managed/enterprise deployment (Intune/GPO). |
| `StockFlow-Pro-Portable-x64.zip` | Portable build — run without installation. |
| `SHA256SUMS.txt` | Integrity checksums for every file above. |
| `INSTALLATION-GUIDE.md` / `ADMIN-DEPLOYMENT-GUIDE.md` / `USER-GUIDE.md` | Documentation. |
| `LICENSE.txt` | End-user license. |

## Highlights (1.0.0)
- **Windows desktop application** (Tauri): single-instance, remembered window size/position, professional installer with full product metadata, no console window, no Node.js/tooling required on the user's PC.
- **First-run connect screen:** checks internet + cloud reachability, asks once for the company server address, remembers it, auto-reconnects, offline status with automatic retry.
- **Cloud, multi-country:** one live Supabase PostgreSQL database; users in Pakistan, the US, or anywhere see the same data under Row Level Security.
- **Inventory engine (validated on real PostgreSQL):** immutable stock ledger, atomic posting, negative-stock protection, idempotent (double-post-safe) posting, reversal-based corrections, in-transit transfers, reservations that never touch on-hand, partial receiving, approved-count adjustments, immutable audit log.
- **Security:** permissions enforced in the database (RLS + SECURITY DEFINER RPCs), org/warehouse/project scoping, secrets never shipped in the desktop app.
- **Branding:** light/dark themes, premium enterprise UI, About screen and login footer with product & developer attribution.

## Code signing status
This build is **not digitally signed** (no code-signing certificate was available
at build time). Windows SmartScreen may show "Windows protected your PC" —
click **More info → Run anyway**. To sign future builds, see
`INSTALLATION-GUIDE.md → Code signing`.

## Known limitations
- Google Drive backup: schema, security design and guides are complete; the OAuth
  connection UI ships in the next release. Supabase's native automated backups
  (PITR) protect data today — Drive is a secondary layer by design.
- Purchasing/production/counts/users/backups screens: data layer + posting
  functions are complete and tested; the remaining UI follows the documented
  shared pattern (see ARCHITECTURE.md screen map).
- Moving-average cost is not retro-recomputed by a reversal (documented in
  TESTING.md).
- Playwright E2E requires a deployed Supabase project (see docs/SETUP.md).
