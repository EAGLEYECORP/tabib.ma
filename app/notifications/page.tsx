'use client';

import { useEffect, useState } from 'react';

type Item = { id: string; template_key: string; payload: Record<string, unknown>; created_at: string; read_at: string | null };

export default function NotificationsPage() {
  const [items, setItems] = useState<Item[]>([]);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  async function load() {
    const r = await fetch('/api/notifications/inbox', { cache: 'no-store' });
    const j = await r.json();
    if (!r.ok) return setError(j.error || 'Erreur');
    setItems(j.notifications || []);
  }
  useEffect(() => { void load(); }, []);

  async function markRead(id: string) {
    setBusy(true);
    try {
      const r = await fetch('/api/notifications/read', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ notificationId: id }) });
      if (r.ok) await load();
    } finally { setBusy(false); }
  }

  return <main style={{ maxWidth: 760, margin: '2rem auto', padding: '0 1rem' }}>
    <h1>Notifications</h1>
    {error && <p role="alert">{error}</p>}
    {!items.length && <p>Aucune notification.</p>}
    <div style={{ display: 'grid', gap: 12 }}>
      {items.map(n => <article key={n.id} style={{ border: '1px solid #ddd', borderRadius: 10, padding: 14 }}>
        <strong>{n.template_key}</strong>
        <p>{new Date(n.created_at).toLocaleString('fr-FR')}</p>
        {!n.read_at && <button disabled={busy} onClick={() => void markRead(n.id)}>Marquer comme lue</button>}
      </article>)}
    </div>
  </main>;
}
