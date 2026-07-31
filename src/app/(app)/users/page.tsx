import { ModuleScaffold } from '@/components/module-scaffold';
export const dynamic = 'force-dynamic';
export default function Page() {
  return <ModuleScaffold title="Users & Roles"
    blurb="Invite users, assign roles, and scope warehouse/project access. Permissions are enforced in the database."
    backedBy={['profiles', 'roles', 'user_roles', 'user_warehouse_access']} />;
}
