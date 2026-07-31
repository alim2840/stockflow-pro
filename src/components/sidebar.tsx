'use client';
import { useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { cn } from '@/lib/utils';
import type { Module } from '@/lib/permissions';
import {
  LayoutDashboard, Package, FolderKanban, ShoppingCart, Users, Warehouse,
  ArrowLeftRight, ClipboardList, FileBarChart, Bell, Settings, ShieldCheck,
  DatabaseBackup, Boxes, ChevronLeft, Factory,
} from 'lucide-react';

type NavItem = { href: string; label: string; icon: React.ElementType; module: Module };

const NAV: NavItem[] = [
  { href: '/dashboard', label: 'Dashboard', icon: LayoutDashboard, module: 'dashboard' },
  { href: '/items', label: 'Inventory', icon: Package, module: 'items' },
  { href: '/warehouses', label: 'Warehouses', icon: Warehouse, module: 'warehouses' },
  { href: '/stock', label: 'Stock Transactions', icon: ArrowLeftRight, module: 'stock_txn' },
  { href: '/purchasing', label: 'Purchasing', icon: ShoppingCart, module: 'purchasing' },
  { href: '/suppliers', label: 'Suppliers', icon: Users, module: 'suppliers' },
  { href: '/projects', label: 'Projects', icon: FolderKanban, module: 'projects' },
  { href: '/production', label: 'Production', icon: Factory, module: 'production' },
  { href: '/counts', label: 'Stock Counts', icon: ClipboardList, module: 'counts' },
  { href: '/reports', label: 'Reports', icon: FileBarChart, module: 'reports' },
  { href: '/users', label: 'Users & Roles', icon: Users, module: 'users' },
  { href: '/backups', label: 'Backups', icon: DatabaseBackup, module: 'backups' },
  { href: '/audit', label: 'Audit Log', icon: ShieldCheck, module: 'audit' },
  { href: '/notifications', label: 'Notifications', icon: Bell, module: 'notifications' },
  { href: '/settings', label: 'Settings', icon: Settings, module: 'settings' },
];

export function Sidebar({ appName, allowed }: { appName: string; allowed: Module[] }) {
  const pathname = usePathname();
  const [collapsed, setCollapsed] = useState(false);
  const visible = NAV.filter((n) => allowed.includes(n.module)); // permission-based visibility

  return (
    <aside className={cn('flex h-screen flex-col border-r bg-card transition-all duration-200',
      collapsed ? 'w-16' : 'w-64')}>
      <div className="flex h-14 items-center gap-2 border-b px-3">
        <div className="grid h-8 w-8 shrink-0 place-items-center rounded-md bg-primary text-primary-foreground">
          <Boxes className="h-5 w-5" />
        </div>
        {!collapsed && <span className="truncate font-semibold">{appName}</span>}
        <button onClick={() => setCollapsed((c) => !c)} aria-label="Toggle sidebar"
          className="ml-auto text-muted-foreground hover:text-foreground">
          <ChevronLeft className={cn('h-4 w-4 transition-transform', collapsed && 'rotate-180')} />
        </button>
      </div>

      <nav className="flex-1 space-y-0.5 overflow-y-auto p-2">
        {visible.map((n) => {
          const active = pathname === n.href || pathname.startsWith(n.href + '/');
          return (
            <Link key={n.href} href={n.href} title={collapsed ? n.label : undefined}
              className={cn(
                'flex items-center gap-3 rounded-md px-3 py-2 text-sm transition-colors',
                active ? 'bg-primary/10 font-medium text-primary' : 'text-muted-foreground hover:bg-accent hover:text-foreground',
              )}>
              <n.icon className="h-4 w-4 shrink-0" />
              {!collapsed && <span className="truncate">{n.label}</span>}
            </Link>
          );
        })}
      </nav>
    </aside>
  );
}
