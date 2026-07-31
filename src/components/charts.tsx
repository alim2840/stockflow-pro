'use client';
import {
  ResponsiveContainer, BarChart, Bar, XAxis, YAxis, Tooltip, CartesianGrid, Cell,
} from 'recharts';
import { formatMoney } from '@/lib/money';

const COLORS = ['#3730A3', '#0891B2', '#059669', '#D97706', '#DC2626', '#7C3AED', '#0D9488'];

export function InventoryValueChart({ data, currency }: { data: { name: string; value: number }[]; currency: string }) {
  if (!data.length) return <p className="py-10 text-center text-sm text-muted-foreground">No inventory data yet.</p>;
  return (
    <ResponsiveContainer width="100%" height={280}>
      <BarChart data={data} margin={{ top: 8, right: 8, left: 8, bottom: 8 }}>
        <CartesianGrid strokeDasharray="3 3" className="stroke-border" vertical={false} />
        <XAxis dataKey="name" tick={{ fontSize: 12 }} className="fill-muted-foreground" />
        <YAxis tick={{ fontSize: 12 }} className="fill-muted-foreground"
          tickFormatter={(v) => new Intl.NumberFormat('en', { notation: 'compact' }).format(v)} />
        <Tooltip formatter={(v: number) => formatMoney(v, currency)}
          contentStyle={{ borderRadius: 8, border: '1px solid hsl(var(--border))', background: 'hsl(var(--card))' }} />
        <Bar dataKey="value" radius={[6, 6, 0, 0]}>
          {data.map((_, i) => <Cell key={i} fill={COLORS[i % COLORS.length]} />)}
        </Bar>
      </BarChart>
    </ResponsiveContainer>
  );
}
