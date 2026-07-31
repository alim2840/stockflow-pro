import { ModuleScaffold } from '@/components/module-scaffold';
export const dynamic = 'force-dynamic';
export default function Page() {
  return <ModuleScaffold title="Backups"
    blurb="Encrypted Google Drive backups (secondary layer). Manual + scheduled, with checksum verification and Super-Admin-only restore."
    backedBy={['backup_jobs', 'backup_files', 'restore_events']} />;
}
