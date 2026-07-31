// Client/server-shared permission types + helpers. Authoritative enforcement is
// in the database (RLS + require_permission); this drives UI visibility only.

export type PermAction =
  | 'view' | 'create' | 'edit_draft' | 'post' | 'approve'
  | 'reverse' | 'export' | 'delete_draft' | 'manage_settings';

export type Module =
  | 'dashboard' | 'items' | 'categories' | 'warehouses' | 'stock_txn'
  | 'purchasing' | 'suppliers' | 'projects' | 'production' | 'counts'
  | 'reports' | 'users' | 'backups' | 'audit' | 'notifications' | 'settings';

export type PermissionSet = Set<`${Module}:${PermAction}`>;

export function can(perms: PermissionSet, module: Module, action: PermAction, isPlatformAdmin = false) {
  return isPlatformAdmin || perms.has(`${module}:${action}`);
}

// Fetch the current user's granted (module,action) pairs. RLS lets a user read
// their own role_permissions via the permissions/role_permissions ref policies.
export async function loadPermissions(
  supabase: { rpc: Function; from: Function },
  userId: string,
): Promise<PermissionSet> {
  const { data } = await supabase
    .from('user_roles')
    .select('roles!inner(role_permissions(permissions(module, action)))')
    .eq('user_id', userId);
  const set: PermissionSet = new Set();
  for (const ur of data ?? []) {
    for (const rp of ur.roles?.role_permissions ?? []) {
      const p = rp.permissions;
      if (p) set.add(`${p.module}:${p.action}` as `${Module}:${PermAction}`);
    }
  }
  return set;
}
