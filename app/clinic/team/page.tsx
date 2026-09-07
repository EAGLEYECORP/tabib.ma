import { getMyClinics, getClinicContext } from '@/lib/clinic'

export default async function TeamPage() {
  const clinics = await getMyClinics(); const clinicId = clinics[0]?.clinic_id
  if (!clinicId) return <main><h1>Équipe clinique</h1><p>Aucune clinique associée à votre compte.</p></main>
  const ctx = await getClinicContext(clinicId)
  if (!ctx) return <main><h1>Accès refusé</h1></main>
  return <main><h1>Équipe — {ctx.clinic?.name ?? 'Clinique'}</h1><p>Rôles séparés : owner, administrateur, secrétaire, médecin.</p><div className="grid">{ctx.team.map((m:any)=><article className="card" key={m.user_id}><strong>{m.full_name ?? m.user_id}</strong><p>{m.role} · {m.status}</p>{m.specialty && <small>{m.specialty}</small>}</article>)}</div></main>
}
