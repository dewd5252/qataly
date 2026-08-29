-- Migration: fix_profile_trigger
-- Ensures profiles row is automatically inserted when a new user is created in auth.users

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name, mmr, daily_streak, last_active_date, is_premium)
    VALUES (
        new.id,
        COALESCE(new.raw_user_meta_data->>'full_name', 'طالب جديد'),
        1000,
        0,
        CURRENT_DATE,
        FALSE
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Re-bind Auth Trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
