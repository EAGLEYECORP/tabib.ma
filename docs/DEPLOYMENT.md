# Deployment — GitHub → Vercel → Supabase

1. Create/choose a Supabase project.
2. Run `supabase/schema.sql` in the Supabase SQL editor on a clean project or adapt it as a migration for an existing project.
3. Copy `.env.example` values into local `.env.local` and Vercel Project Settings → Environment Variables.
4. Never commit `SUPABASE_SERVICE_ROLE_KEY`.
5. Import the GitHub repository into Vercel; framework should auto-detect Next.js.
6. Deploy Preview first. Test `/api/health`, auth, doctor directory and document access.
7. Promote only after RLS, concurrency and document scanning tests pass.
