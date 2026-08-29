-- Supabase SQL Database Schema
-- Project: Qata'ly (قطعلي) - Adaptive EdTech Engine

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Classrooms Table
CREATE TABLE classrooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    teacher_name VARCHAR(100) NOT NULL,
    school_code VARCHAR(20) UNIQUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Profiles Table (Linked to Supabase Auth)
CREATE TABLE profiles (
    id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
    full_name VARCHAR(150),
    classroom_id UUID REFERENCES classrooms(id) ON DELETE SET NULL,
    mmr INT DEFAULT 1000 CHECK (mmr >= 400),
    daily_streak INT DEFAULT 0,
    last_active_date DATE DEFAULT CURRENT_DATE,
    is_premium BOOLEAN DEFAULT FALSE,
    premium_until TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Passages Table
CREATE TABLE passages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    passage_text TEXT NOT NULL,
    difficulty_level INT NOT NULL CHECK (difficulty_level BETWEEN 1 AND 5),
    vocabulary_used TEXT[] DEFAULT '{}',
    qa_json JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. User Progress Table
CREATE TABLE user_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    passage_id UUID REFERENCES passages(id),
    score_percentage DECIMAL(5,2) NOT NULL,
    old_mmr INT, -- Populated by trigger
    new_mmr INT, -- Populated by trigger
    solved_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Vocabulary Weaknesses Table
CREATE TABLE vocabulary_weaknesses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    word VARCHAR(100) NOT NULL,
    mistake_count INT DEFAULT 1,
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, word)
);

-- 6. Activation Codes Table
CREATE TABLE activation_codes (
    code VARCHAR(12) PRIMARY KEY,
    duration_days INT DEFAULT 30 NOT NULL,
    claimed_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    claimed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance optimization
CREATE INDEX idx_profiles_classroom ON profiles(classroom_id);
CREATE INDEX idx_profiles_mmr ON profiles(mmr DESC);
CREATE INDEX idx_passages_difficulty ON passages(difficulty_level);
CREATE INDEX idx_vocab_weakness_user ON vocabulary_weaknesses(user_id);
CREATE INDEX idx_user_progress_user ON user_progress(user_id);

--------------------------------------------------------------------------------
-- Database Triggers & Functions
--------------------------------------------------------------------------------

-- Trigger Function: Update Student MMR and Daily Streak
CREATE OR REPLACE FUNCTION update_student_mmr_and_streak()
RETURNS TRIGGER AS $$
DECLARE
    v_old_mmr INT;
    v_passage_difficulty INT;
    v_difficulty_mmr INT;
    v_expected_score DOUBLE PRECISION;
    v_actual_score DOUBLE PRECISION;
    v_k_factor INT := 32;
    v_new_mmr INT;
    v_last_active DATE;
    v_current_streak INT;
BEGIN
    -- 1. Fetch current student stats
    SELECT mmr, last_active_date, daily_streak INTO v_old_mmr, v_last_active, v_current_streak 
    FROM profiles WHERE id = NEW.user_id;
    
    -- 2. Fetch passage difficulty
    SELECT difficulty_level INTO v_passage_difficulty 
    FROM passages WHERE id = NEW.passage_id;

    -- Map difficulty (1-5) to MMR level (600-1400)
    v_difficulty_mmr := 600 + (v_passage_difficulty * 200);

    -- 3. Calculate Expected Score
    v_expected_score := 1.0 / (1.0 + power(10.0, (v_difficulty_mmr - v_old_mmr)::double precision / 400.0));
    
    -- Actual score (percentage representation 0.0 - 1.0)
    v_actual_score := NEW.score_percentage / 100.0;

    -- 4. Calculate New MMR
    v_new_mmr := v_old_mmr + ROUND(v_k_factor * (v_actual_score - v_expected_score));
    
    -- Bound check for MMR floor
    IF v_new_mmr < 400 THEN
        v_new_mmr := 400;
    END IF;

    -- 5. Calculate Daily Streak
    IF v_last_active = CURRENT_DATE THEN
        -- Already solved today, retain streak
        NULL;
    ELSIF v_last_active = CURRENT_DATE - INTERVAL '1 day' THEN
        v_current_streak := v_current_streak + 1;
    ELSE
        v_current_streak := 1; -- Broke streak, reset to 1
    END IF;

    -- 6. Apply updates to the profile
    UPDATE profiles 
    SET mmr = v_new_mmr,
        daily_streak = v_current_streak,
        last_active_date = CURRENT_DATE
    WHERE id = NEW.user_id;

    -- Record historical MMR inside the progress log
    NEW.old_mmr := v_old_mmr;
    NEW.new_mmr := v_new_mmr;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Bind Trigger
CREATE TRIGGER trigger_on_solve_passage
BEFORE INSERT ON user_progress
FOR EACH ROW
EXECUTE FUNCTION update_student_mmr_and_streak();

--------------------------------------------------------------------------------

-- RPC Function: Claim Activation Code with Concurrency Locks
CREATE OR REPLACE FUNCTION claim_activation_code(p_user_id UUID, p_code VARCHAR)
RETURNS BOOLEAN AS $$
DECLARE
    v_duration INT;
    v_claimed_by UUID;
BEGIN
    -- Query code record and apply row level lock to prevent race conditions (FOR UPDATE)
    SELECT duration_days, claimed_by INTO v_duration, v_claimed_by
    FROM activation_codes
    WHERE code = p_code
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'هذا الكود غير صحيح!';
    END IF;

    IF v_claimed_by IS NOT NULL THEN
        RAISE EXCEPTION 'تم استخدام هذا الكود مسبقاً!';
    END IF;

    -- Consume activation code
    UPDATE activation_codes
    SET claimed_by = p_user_id,
        claimed_at = NOW()
    WHERE code = p_code;

    -- Update student premium status and add duration
    UPDATE profiles
    SET is_premium = TRUE,
        premium_until = COALESCE(premium_until, NOW()) + (v_duration || ' days')::INTERVAL
    WHERE id = p_user_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

--------------------------------------------------------------------------------

-- Trigger Function: Automatic Profile Creation on Supabase Auth Signup
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
    );
    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Bind Auth Trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

--------------------------------------------------------------------------------
-- Row Level Security (RLS) Configuration
--------------------------------------------------------------------------------

ALTER TABLE classrooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE passages ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE vocabulary_weaknesses ENABLE ROW LEVEL SECURITY;
ALTER TABLE activation_codes ENABLE ROW LEVEL SECURITY;

-- 1. Classrooms Policies: Authenticated users can search and view classrooms
CREATE POLICY classrooms_select ON classrooms
    FOR SELECT TO authenticated USING (true);

-- 2. Profiles Policies: Users can view/modify only their own profiles
CREATE POLICY profiles_owner ON profiles
    FOR ALL TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- 3. Passages Policies: Authenticated users can view reading passages
CREATE POLICY passages_select ON passages
    FOR SELECT TO authenticated USING (true);

-- 4. User Progress Policies: Users can view and log progress for themselves only
CREATE POLICY progress_owner ON user_progress
    FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 5. Vocabulary Weaknesses Policies: Users can manage their own vocabulary items
CREATE POLICY vocab_owner ON vocabulary_weaknesses
    FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 6. Activation Codes Policies: Access is fully locked from client side
-- Operations are performed safely via 'claim_activation_code' RPC (SECURITY DEFINER)
CREATE POLICY code_admin ON activation_codes
    FOR ALL TO service_role USING (true) WITH CHECK (true);
