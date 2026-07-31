import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import './globals.css';
import { ThemeProvider } from '@/components/theme-provider';
import { ConnectionStatus } from '@/components/connection-status';

const inter = Inter({ subsets: ['latin'], variable: '--font-sans' });

export const metadata: Metadata = {
  title: 'StockFlow Pro',
  description: 'Premium Inventory and Project Management System — published by Mindtune Innovations, developed by Muhammad Ali (alim2840@gmail.com)',
  authors: [{ name: 'Muhammad Ali', url: 'mailto:alim2840@gmail.com' }],
  applicationName: 'StockFlow Pro',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className={inter.variable}>
        <ThemeProvider>
          <ConnectionStatus />
          {children}
        </ThemeProvider>
      </body>
    </html>
  );
}
