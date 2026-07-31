# StockFlow Pro — Setup, Deployment, Backup & Restore

## 1. Prerequisites
- Node.js 20+, npm
- A Supabase project (free tier is fine to start)
- (Optional) Google Cloud project for Drive backups
- (Optional) Vercel account for deployment

## 2. Local setup
```bash
git clone <your-repo> stockflow-pro && cd stockflow-pro
cp .env.example .env.local          # fill in Supabase URL + keys
npm install
```

### 2.1 Apply the database
Using the Supabase CLI (recommended):
```bash
supabase link --project-ref YOUR_PROJECT_REF
supabase db push                    # applies supabase/migrations/*.sql in order
```
Or with psql directly:
```bash
for f in supabase/migrations/00*.sql; do psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f "$f"; done
```
Supabase already provides `auth.uid()`; do **not** run the vanilla-Postgres shim
in production.

### 2.2 Create the first admin & link demo users
The SQL seed creates demo **profiles** (business data) but not login credentials.
`scripts/setup.ts` creates Supabase Auth users and links them to the seed profiles.
```bash
npx tsx scripts/setup.ts            # uses SUPABASE_SERVICE_ROLE_KEY (server only)
```
This will:
1. Create an auth user for each `*@mindtune.test` demo profile (password printed once).
2. Set `profiles.id = auth user id` so RLS/permissions resolve.
3. Optionally bootstrap a fresh org via `bootstrap_organisation()` for real use.

### 2.3 Run
```bash
npm run dev            # http://localhost:3000
```
Demo logins (after step 2.2): `admin@mindtune.test` (Super Admin),
`inventory@…`, `pm@…`, `store@…`, `accounts@…`, `viewer@…`.

## 3. Deployment (Vercel)
1. Push the repo to GitHub.
2. Import into Vercel; set all env vars from `.env.example` (mark server-only ones
   as **not** exposed to the browser — only `NEXT_PUBLIC_*` are public).
3. Set the production `NEXT_PUBLIC_APP_URL` and Google redirect URI.
4. Add a Vercel Cron hitting `/api/backups/run` daily with header
   `Authorization: Bearer $CRON_SECRET`.
5. Deploy. Supabase RLS keeps data safe even though the app is internet-facing.

Security headers, HTTPS, secure cookies and CSRF protection ship in
`next.config.mjs` / middleware. Never commit `.env.local`.

## 4. Google Drive backups
1. In Google Cloud Console: create OAuth 2.0 credentials (Web), scope
   `https://www.googleapis.com/auth/drive.file`.
2. Put client id/secret + redirect URI in server env.
3. In-app: **Settings → Backups → Connect Google** (Super Admin). The OAuth
   **refresh token is stored encrypted in the DB** (AES-256-GCM using
   `BACKUP_ENCRYPTION_KEY`) — never in the browser or in backup files.
4. Choose/create a backup folder; set frequency + retention.

### What a backup contains
Structured export of: inventory masters, the full stock ledger, projects, purchase
records, users/roles config, plus reports & attachment manifests. Each file is
**encrypted before upload** and stored with a **SHA-256 checksum**; the checksum is
verified on upload. Database credentials are never placed inside backups.

### Restore (Super Admin only)
1. **Settings → Backups → Restore** → pick a verified backup.
2. Explicit typed confirmation required.
3. Checksum verified → decrypt → staged apply → `audit_logs` records the restore.
Non-admins cannot download or restore (RLS + `backups` permission).

> Google Drive is a **secondary** layer. Keep Supabase's native PITR/automated
> backups enabled as the primary disaster-recovery mechanism.

## 5. Admin operational notes
- **Add users:** Settings → Users → Invite (status `invited` → `active`). Assign
  roles + warehouse/project scope.
- **Company/inventory/security settings:** Settings tabs — currency, timezone, date
  format, brand colour/logo, negative-stock toggle, approval thresholds, numbering
  formats, session timeout, password policy, 2FA, audit retention.
- **Corrections:** never edit a posted transaction — use **Reverse** (creates equal
  & opposite entries) then re-post correctly.
