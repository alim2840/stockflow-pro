# StockFlow Pro — Administrator Deployment Guide

**Audience:** the IT administrator who sets up the company's cloud backend once.
End users never do any of this — they only install the EXE and enter the server
address you give them.

## Architecture you are deploying

```
Windows PCs (Pakistan, US, anywhere)          ┌─ Supabase (your account)
  StockFlow Pro desktop app (Tauri shell) ──▶ │   PostgreSQL  = live data (RLS)
        │  remembers your server address      │   Auth        = logins
        ▼                                     │   Storage     = attachments
  Your server (Vercel, your account)  ───────▶┘
  Next.js app = UI + server actions           Google Drive = encrypted BACKUPS
  (service keys live ONLY here)               (never the live database)
```

## Step 1 — Create the Supabase project (once, ~10 min)
1. Create a project at supabase.com (choose a region near most users).
2. Apply the database (all 14 migrations):
   `supabase link --project-ref <ref> && supabase db push`
   (or run each `supabase/migrations/*.sql` in the SQL editor, in order).
3. **Demo data (optional, for evaluation):** run `supabase/seed_auth.sql` to
   enable the six demo logins listed in `docs/SETUP.md`.
4. **Production:** create the first Super Admin instead:
   `ADMIN_EMAIL=you@company.com ORG_NAME="Your Company" npx tsx scripts/setup.ts`
   (uses the service-role key from your env; prints the initial password once).
5. In Supabase → Auth → URL configuration, set the Site URL to your server
   address (Step 2) so password-reset emails link correctly.

## Step 2 — Deploy the server (once, ~10 min)
1. Push this repository to GitHub; import it in Vercel.
2. Set environment variables from `.env.production.example`:
   - `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` (public, safe)
   - `SUPABASE_SERVICE_ROLE_KEY`, `BACKUP_ENCRYPTION_KEY`, `CRON_SECRET`,
     Google OAuth credentials (server-only — never in the desktop app)
3. Deploy. Your **company server address** is the Vercel URL (add a custom
   domain like `https://stock.yourcompany.com` if you wish).
4. This address is what every employee types once on first launch.

## Step 3 — Build/download the Windows installer (once)
- **No tools needed:** GitHub → Actions → **Windows release** → Run workflow →
  download the `StockFlow-Pro-Windows` artifact (Setup EXE, MSI, portable ZIP,
  checksums, guides).
- Or on any Windows build machine: `powershell -File scripts/build-windows.ps1`.
- Code signing: see INSTALLATION-GUIDE.md §6.

## Step 4 — First administrator login & company setup
1. Install StockFlow Pro, enter the server address, sign in as the Super Admin
   created in Step 1.
2. Settings → Company: set company name, logo, country, base currency,
   timezone, date format, brand colour.
3. Users & Roles: invite staff by email; assign roles (Company Admin, Inventory
   Manager, Project Manager, Storekeeper, Accountant, Viewer) and grant
   warehouse/project access. Permissions are enforced by the database (RLS),
   not just the interface.
4. Warehouses/Items: create your real warehouses and item master (or start from
   the demo org to evaluate first).

## Step 5 — Google Drive backups (optional but recommended)
Supabase's own automated backups protect the database from day one; Drive is a
second, org-controlled layer.
1. Google Cloud Console → create OAuth 2.0 credentials (Web application),
   scope `https://www.googleapis.com/auth/drive.file`; set the redirect URI to
   `https://<your-server>/api/backups/google/callback`.
2. Put the client ID/secret in the server env (Step 2). They are never shipped
   to desktops; refresh tokens are stored encrypted (AES-256-GCM) server-side.
3. In-app: Settings → Backups → Connect Google (Super Admin only) → choose the
   Drive folder, frequency and retention. Backups are encrypted before upload
   and checksummed; restore is Super-Admin-only with explicit confirmation and
   is fully audited. See `docs/SETUP.md §4` for details.

## Security checklist
- [ ] Service-role key, DB password, Google secret, encryption key: **server env only**
- [ ] `.env*` files never committed (repo `.gitignore` already enforces)
- [ ] Supabase Auth: email confirmations ON; leaked-password protection ON
- [ ] RLS verified (`tests/db/engine_tests.sql` — 21 checks)
- [ ] Only invited users can sign in; suspended users are blocked
- [ ] Periodically download `SHA256SUMS.txt` + installer to verify integrity

## Updating the app later
Bump `version` in `package.json` + `src-tauri/tauri.conf.json` + Cargo.toml,
run the workflow again, and distribute the new Setup EXE — it upgrades in place
(cloud data is untouched). Tag `v1.x.y` to publish a GitHub Release automatically.
