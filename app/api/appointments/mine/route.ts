import { createClient } from '@/lib/supabase/server';

export async function GET() {
  const sb = await createClient();
  const { data: { user } } = await sb.auth.getUser();
  if (!user) return Response.json({ error: 'Authentication required' }, { status: 401 });
  const { data, error } = await sb.from('appointments')
    .select('id,start_at,end_at,status,reason,created_at,doctor_profiles(id,display_name,specialty,city,timezone)')
    .eq('patient_id', user.id).order('start_at', { ascending: true });
  if (error) return Response.json({ error: 'Unable to load appointments' }, { status: 500 });
  return Response.json({ appointments: data ?? [] }, { headers: { 'Cache-Control': 'private, no-store' } });
}
