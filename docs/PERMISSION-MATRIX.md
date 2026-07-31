# StockFlow Pro — Permission Matrix

Permissions are `(module, action)` pairs stored in `permissions`, granted to roles
via `role_permissions`, and enforced **in the database** (RLS policies +
`require_permission()` inside every posting RPC), not just in the UI.

## Granular actions
`view · create · edit_draft · post · approve · reverse · export · delete_draft · manage_settings`

## Roles → capability (● = full, ◐ = scoped/partial, — = none)

| Module          | Super Admin | Company Admin | Inventory Mgr | Project Mgr | Storekeeper | Accountant | Viewer/Auditor |
|-----------------|:-----------:|:-------------:|:-------------:|:-----------:|:-----------:|:----------:|:--------------:|
| Dashboard       | ●           | ●             | view          | view        | view        | view       | view           |
| Items           | ●           | ●             | ●             | view/export | view        | view/export| view/export    |
| Categories/Units| ●           | ●             | ●             | —           | —           | —          | view           |
| Warehouses      | ●           | ●             | ● (scoped)    | —           | view (scoped)| view      | view           |
| Stock Txn       | ●           | ●             | ● (+reverse)  | view/create/edit/post | view/create/edit/post | view/export | view/export |
| Purchasing      | ●           | ●             | ●             | —           | —           | view/export| view/export    |
| Suppliers       | ●           | ●             | ●             | —           | —           | view/export| view/export    |
| Projects        | ●           | ●             | view          | ● (assigned)| —           | view/export| view/export    |
| Production      | ●           | ●             | ●             | —           | —           | —          | view/export    |
| Stock Counts    | ●           | ●             | ●             | —           | create/edit/post | —     | view/export    |
| Reports         | ●           | ●             | view/export   | view/export | view/export | view/export| view/export    |
| Users & Roles   | ●           | ●             | —             | —           | —           | —          | —              |
| Backups         | ● (+restore)| view          | —             | —           | —           | —          | —              |
| Audit Log       | ●           | ●             | —             | —           | —           | —          | view/export    |
| Settings        | ●           | ●             | —             | —           | —           | —          | —              |

### Scope rules (row-level, enforced by RLS)
- **Warehouses / storage / stock lines** — a non-admin sees only warehouses in
  `user_warehouse_access`. `is_org_admin()` (holds `settings.manage_settings`)
  sees all warehouses **within their own org**. Platform admins see all orgs.
- **Projects** — a non-admin sees only projects in `user_project_access`.
- **Segregation of duties** — when `company_settings.segregation_of_duties` is on,
  a user may not approve their own high-risk transaction (enforced in approval RPC).
- **Reversal** is a distinct, higher-privilege action: Storekeepers can *post* but
  not *reverse* (verified in tests — a storekeeper reversal is correctly denied).

### Verified in automated tests
- Viewer cannot post (permission denied) ✔
- Storekeeper cannot manage users, cannot reverse ✔
- Storekeeper sees only 6 PK warehouses, not the US warehouse ✔
- Project Manager sees 0 warehouses but their 1 assigned project ✔
- Platform admin sees all 7 warehouses ✔
- Accountant sees costs (view/export) but holds no `post` ✔
