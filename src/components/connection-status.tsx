'use client';
import { useEffect, useState } from 'react';
import { WifiOff, Wifi } from 'lucide-react';

// Global online/offline banner. Non-blocking: forms keep their state during an
// outage (we never navigate on failure), and saves simply retry once online.
export function ConnectionStatus() {
  const [online, setOnline] = useState(true);
  const [justRestored, setJustRestored] = useState(false);

  useEffect(() => {
    setOnline(navigator.onLine);
    const goOffline = () => { setOnline(false); setJustRestored(false); };
    const goOnline = () => {
      setOnline(true);
      setJustRestored(true);
      setTimeout(() => setJustRestored(false), 4000);
    };
    window.addEventListener('offline', goOffline);
    window.addEventListener('online', goOnline);
    return () => {
      window.removeEventListener('offline', goOffline);
      window.removeEventListener('online', goOnline);
    };
  }, []);

  if (online && !justRestored) return null;

  return (
    <div
      role="status"
      aria-live="assertive"
      className={`fixed inset-x-0 top-0 z-[100] flex items-center justify-center gap-2 px-4 py-2 text-sm font-medium ${
        online ? 'bg-success text-success-foreground' : 'bg-warning text-warning-foreground'
      }`}
    >
      {online ? (
        <><Wifi className="h-4 w-4" /> Back online — you can continue working.</>
      ) : (
        <><WifiOff className="h-4 w-4" /> You&apos;re offline. Your entries are kept on screen — reconnecting automatically…</>
      )}
    </div>
  );
}
