-- UX Improvements Migration — Qata'ly (قطعلي)
-- Run this ONCE in Supabase Dashboard → SQL Editor.
-- Safe to re-run: everything is CREATE OR REPLACE / IF NOT EXISTS.

--------------------------------------------------------------------------------
-- 1. RPC: increment_weak_word
-- Fixes the bug where recordWeakWord() upsert resets mistake_count to 1 on
-- every conflict. This RPC atomically increments the counter instead.
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION increment_weak_word(p_user_id UUID, p_word VARCHAR)
RETURNS VOID AS $$
BEGIN
    INSERT INTO vocabulary_weaknesses (user_id, word, mistake_count, last_seen)
    VALUES (p_user_id, p_word, 1, NOW())
    ON CONFLICT (user_id, word)
    DO UPDATE
        SET mistake_count = vocabulary_weaknesses.mistake_count + 1,
            last_seen = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

--------------------------------------------------------------------------------
-- 2. RLS: allow authenticated users to READ all profiles
-- Without this, profiles_owner (auth.uid() = id) blocks both leaderboards and
-- the teacher dashboard from returning anyone except the requesting user.
-- Policies are OR-ed, so owner write access is unaffected.
--------------------------------------------------------------------------------
DROP POLICY IF EXISTS profiles_select_authenticated ON profiles;
CREATE POLICY profiles_select_authenticated ON profiles
    FOR SELECT TO authenticated USING (true);

--------------------------------------------------------------------------------
-- 3. RPC: top_weak_words(classroom_id)
-- Real aggregation behind the teacher dashboard "top 5 weak words" card
-- (replaces the hardcoded placeholder). SECURITY DEFINER bypasses the
-- per-user vocab RLS so the teacher can aggregate across the whole class.
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION top_weak_words(p_classroom_id UUID, p_limit INT DEFAULT 5)
RETURNS TABLE (word VARCHAR, total_mistakes BIGINT, students_count BIGINT) AS $$
BEGIN
    RETURN QUERY
    SELECT vw.word,
           SUM(vw.mistake_count)::BIGINT AS total_mistakes,
           COUNT(DISTINCT vw.user_id)::BIGINT AS students_count
    FROM vocabulary_weaknesses vw
    JOIN profiles p ON p.id = vw.user_id
    WHERE p.classroom_id = p_classroom_id
    GROUP BY vw.word
    ORDER BY total_mistakes DESC, students_count DESC
    LIMIT GREATEST(1, LEAST(p_limit, 20));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
