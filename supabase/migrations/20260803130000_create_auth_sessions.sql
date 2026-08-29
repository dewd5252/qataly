-- Migration: create_auth_sessions_table
CREATE TABLE IF NOT EXISTS public.auth_sessions (
  id TEXT PRIMARY KEY,
  status TEXT NOT NULL DEFAULT 'pending',
  user_data JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS & allow public access for auth flow
ALTER TABLE public.auth_sessions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public auth_sessions policy" ON public.auth_sessions;
CREATE POLICY "Public auth_sessions policy" ON public.auth_sessions FOR ALL USING (true) WITH CHECK (true);
