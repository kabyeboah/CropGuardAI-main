-- ==============================================================================
-- CropGuard AI — 0001_schema.sql
-- Core relational tables for Supabase backend
-- ==============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─── 1. Profiles Table ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    display_name TEXT DEFAULT 'Farmer',
    photo_url TEXT,
    phone_number TEXT,
    region TEXT,
    district TEXT,
    language_preference TEXT DEFAULT 'en',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Trigger to create profile automatically on auth.users creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO public.profiles (id, email, display_name, created_at, updated_at)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(
            NEW.raw_user_meta_data->>'full_name',
            NEW.raw_user_meta_data->>'display_name',
            NEW.raw_user_meta_data->>'name',
            'Farmer'
        ),
        now(),
        now()
    )
    ON CONFLICT (id) DO UPDATE
        SET email = EXCLUDED.email,
            display_name = COALESCE(EXCLUDED.display_name, public.profiles.display_name),
            updated_at = now();
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        -- Prevent profile insert errors from failing user registration
        RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ─── 2. Community Posts Table ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    author_name TEXT NOT NULL DEFAULT 'Farmer',
    crop_type TEXT DEFAULT 'General',
    title TEXT,
    content TEXT NOT NULL,
    image_url TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_posts_user_id ON public.posts(user_id);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON public.posts(created_at DESC);

-- ─── 3. Outbreak Reports Table ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.outbreaks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    disease_name TEXT NOT NULL,
    crop_type TEXT NOT NULL,
    confidence FLOAT8 DEFAULT 0.0,
    latitude FLOAT8 NOT NULL,
    longitude FLOAT8 NOT NULL,
    district TEXT,
    region TEXT,
    verified_by TEXT[] DEFAULT '{}'::TEXT[],
    refuted_by TEXT[] DEFAULT '{}'::TEXT[],
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_outbreaks_coords ON public.outbreaks(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_outbreaks_disease ON public.outbreaks(disease_name);
CREATE INDEX IF NOT EXISTS idx_outbreaks_created_at ON public.outbreaks(created_at DESC);

-- ─── 4. Cloud Scans Table ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.scans (
    id TEXT PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    disease_name TEXT NOT NULL,
    crop_type TEXT,
    confidence FLOAT8,
    image_url TEXT,
    data JSONB DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_scans_user_id ON public.scans(user_id);
CREATE INDEX IF NOT EXISTS idx_scans_created_at ON public.scans(created_at DESC);

-- ─── 5. Treatments Table ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.treatments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT,
    crop TEXT,
    disease TEXT,
    date TIMESTAMPTZ,
    notes TEXT,
    reminder_enabled BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_treatments_user_id ON public.treatments(user_id);

-- ─── 6. Feedback Table ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.feedback (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    detection_id BIGINT,
    original_label TEXT,
    corrected_label TEXT,
    image_path TEXT,
    confidence FLOAT8,
    model_version TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_feedback_user_id ON public.feedback(user_id);

-- ─── 7. Missing Crops Table ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.missing_crops (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    suggested_crop TEXT,
    observed_symptoms TEXT,
    image_path TEXT,
    status TEXT DEFAULT 'review_pending',
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_missing_crops_user_id ON public.missing_crops(user_id);

-- ─── 8. Expert Requests Table ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.expert_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    detection_id TEXT,
    message TEXT,
    disease_name TEXT,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_expert_requests_user_id ON public.expert_requests(user_id);

-- ─── 9. Training Candidates Table ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.training_candidates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    disease_label TEXT,
    crop_type TEXT,
    image_url TEXT,
    confidence FLOAT8,
    metadata JSONB DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ─── 10. Reported Posts Table ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.reported_posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
    reporter_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    reason TEXT DEFAULT 'inappropriate_content',
    status TEXT DEFAULT 'pending_review',
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reported_posts_post_id ON public.reported_posts(post_id);

-- ─── 11. Remote App Configuration Table ──────────────────────────────────────
-- Dynamic runtime configuration and feature flags store
CREATE TABLE IF NOT EXISTS public.app_config (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Seed initial default configuration
INSERT INTO public.app_config (key, value, description)
VALUES 
    ('min_app_version', '"1.0.0"'::jsonb, 'Minimum supported mobile app version'),
    ('latest_app_version', '"1.0.0"'::jsonb, 'Latest recommended app version'),
    ('force_update', 'false'::jsonb, 'Emergency killswitch requiring immediate app update'),
    ('ai_confidence_threshold', '0.65'::jsonb, 'Threshold for confident classification'),
    ('offline_sync_batch_size', '15'::jsonb, 'Maximum records synced per background execution')
ON CONFLICT (key) DO NOTHING;
