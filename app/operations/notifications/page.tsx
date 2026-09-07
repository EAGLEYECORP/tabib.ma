'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';

type Item = {
  id: string; template_key: string; priority: 'info'|'action_required'|'urgent';
  action_url: string | null; appointment_id: string | null; created_at: string; read_at: string | null;
};

const copy: Record<string, { title: string; body: string }> = {
  'staff.appointment.created': { title: 'Nouveau rendez-vous', body: 'Un nouveau rendez-vous nécessite votre attention.' },
  'staff.appointment.confirmed': { title: 'Rendez-vous confirmé', body: 'Un rendez-vous a été confirmé dans votre agenda.' },
  'staff.appointment.cancelled': { title: 'Rendez-vous annulé', body: 'Un rendez-vous de votre agenda a été annulé.' },
  'staff.appointment.rescheduled': { title: 'Rendez-vous reprogrammé', body: 'Un rendez-vous de votre agenda a changé de créneau.' },
  'staff.appointment.reminder_24h': { title: 'Rappel agenda', body: 'Un rendez-vous est prévu demain.' },
  'staff.appointment.reminder_2h': { title: 'Rappel agenda', body: 'Un rendez-vous est prévu dans environ 2 heures.' },
};

export default function OperationsNotifications() {
  const [items, setItems] = useState<Item[]>([]);
  const [error, setError] = useState('');

  async function load() {
    const r = await fetch('/api/operations/notifications', { cache: 'no-store' });
    const j = await r.json().catch(() => ({}));
    if (!r.ok) return setError(j.error || 'Erreur');
    setItems(j.notifications || []);
  }
  useEffect(() => { void load(); }, []);

  async function markRead(id: string) {
    const r = await fetch('/api/notifications/read', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ notificationId: id }) });
    if (r.ok) await load();
  }

  return <main className="wrap">
    <div className="card">
      <h1>Centre opérationnel</h1>
      <p>Alertes d’agenda pour médecins et équipes d’établissement. Aucune donnée médicale n’est affichée ici.</p>
      {error && <p role="alert">{error}</p>}
      {!items.length && <p>Aucune alerte opérationnelle.</p>}
      <div style={{display:'grid',gap:12}}>
        {items.map(n => {
          const c = copy[n.template_key] ?? { title: 'Notification', body: 'Nouvel événement opérationnel.' };
          return <article key={n.id} style={{border:'1px solid #ddd',borderRadius:10,padding:14}}>
            <div style={{display:'flex',justifyContent:'space-between',gap:12}}>
              <strong>{c.title}</strong>
              <span className="tag">{n.priority}</span>
            </div>
            <p>{c.body}</p>
            <small>{new Date(n.created_at).toLocaleString('fr-FR')}</small>
            <div style={{display:'flex',gap:8,marginTop:10}}>
              {!n.read_at && <button onClick={() => void markRead(n.id)}>Marquer comme lue</button>}
              {n.action_url && <Link className="btn" href={n.action_url}>Ouvrir l’agenda</Link>}
            </div>
          </article>;
        })}
      </div>
    </div>
  </main>;
}
