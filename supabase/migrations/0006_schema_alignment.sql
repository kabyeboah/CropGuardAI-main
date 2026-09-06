-- ==============================================================================
-- CropGuard AI — 0006_schema_alignment.sql
-- Storage bucket alignment, treatments & training candidate columns,
-- missing RLS delete policies, and realtime publications.
-- ==============================================================================

-- ─── 1. Storage: 'cropguard-media' Bucket & Policies ─────────────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'cropguard-media',
    'cropguard-media',
    true,
    10485760, -- 10MB
    ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Public read access for cropguard-media
DROP POLICY IF EXISTS "Public Read Access for cropguard-media" ON storage.objects;
CREATE POLICY "Public Read Access for cropguard-media"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'cropguard-media');

-- Authenticated upload access for cropguard-media
DROP POLICY IF EXISTS "Authenticated users can upload to cropguard-media" ON storage.objects;
CREATE POLICY "Authenticated users can upload to cropguard-media"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'cropguard-media');

-- Authenticated owner update access for cropguard-media
-- Accommodates both direct (<uid>/...) and categorized (community_posts/<uid>/..., profiles/<uid>/...) paths
DROP POLICY IF EXISTS "Users can update their own cropguard-media uploads" ON storage.objects;
CREATE POLICY "Users can update their own cropguard-media uploads"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'cropguard-media' AND (
            auth.uid()::text = (storage.foldername(name))[1] OR
            auth.uid()::text = (storage.foldername(name))[2]
        )
    );

-- Authenticated owner delete access for cropguard-media
DROP POLICY IF EXISTS "Users can delete their own cropguard-media uploads" ON storage.objects;
CREATE POLICY "Users can delete their own cropguard-media uploads"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'cropguard-media' AND (
            auth.uid()::text = (storage.foldername(name))[1] OR
            auth.uid()::text = (storage.foldername(name))[2]
        )
    );


-- ─── 2. Treatments Table Schema Alignment ─────────────────────────────────────
-- Add columns used by TreatmentPlan and TreatmentTrackerProvider
ALTER TABLE public.treatments ADD COLUMN IF NOT EXISTS detection_id BIGINT;
ALTER TABLE public.treatments ADD COLUMN IF NOT EXISTS crop_type TEXT;
ALTER TABLE public.treatments ADD COLUMN IF NOT EXISTS disease_name TEXT;
ALTER TABLE public.treatments ADD COLUMN IF NOT EXISTS step TEXT;
ALTER TABLE public.treatments ADD COLUMN IF NOT EXISTS completed BOOLEAN DEFAULT false;
ALTER TABLE public.treatments ADD COLUMN IF NOT EXISTS due_date TIMESTAMPTZ;
ALTER TABLE public.treatments ADD COLUMN IF NOT EXISTS due_date_ms BIGINT;
ALTER TABLE public.treatments ADD COLUMN IF NOT EXISTS created_at_ms BIGINT;

CREATE INDEX IF NOT EXISTS idx_treatments_due_date ON public.treatments(due_date);
CREATE INDEX IF NOT EXISTS idx_treatments_completed ON public.treatments(completed);


-- ─── 3. Training Candidates Table Schema Alignment ────────────────────────────
-- Add columns submitted by LowConfidenceScreen
ALTER TABLE public.training_candidates ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending_review';
ALTER TABLE public.training_candidates ADD COLUMN IF NOT EXISTS model_version TEXT;
ALTER TABLE public.training_candidates ADD COLUMN IF NOT EXISTS device_info TEXT;
ALTER TABLE public.training_candidates ADD COLUMN IF NOT EXISTS angles_used INTEGER DEFAULT 1;
ALTER TABLE public.training_candidates ADD COLUMN IF NOT EXISTS top_candidates JSONB DEFAULT '[]'::JSONB;

CREATE INDEX IF NOT EXISTS idx_training_candidates_user_id ON public.training_candidates(user_id);
CREATE INDEX IF NOT EXISTS idx_training_candidates_status ON public.training_candidates(status);


-- ─── 4. Missing RLS DELETE Policies ──────────────────────────────────────────
DROP POLICY IF EXISTS "Users can delete their own profile" ON public.profiles;
CREATE POLICY "Users can delete their own profile"
    ON public.profiles FOR DELETE
    TO authenticated
    USING (auth.uid()::text = id::text);

DROP POLICY IF EXISTS "Users can delete their submitted feedback" ON public.feedback;
CREATE POLICY "Users can delete their submitted feedback"
    ON public.feedback FOR DELETE
    TO authenticated
    USING (auth.uid()::text = user_id::text);

DROP POLICY IF EXISTS "Users can delete their submitted missing crops" ON public.missing_crops;
CREATE POLICY "Users can delete their submitted missing crops"
    ON public.missing_crops FOR DELETE
    TO authenticated
    USING (auth.uid()::text = user_id::text);

DROP POLICY IF EXISTS "Users can delete their expert consultation requests" ON public.expert_requests;
CREATE POLICY "Users can delete their expert consultation requests"
    ON public.expert_requests FOR DELETE
    TO authenticated
    USING (auth.uid()::text = user_id::text);

DROP POLICY IF EXISTS "Users can delete their submitted training candidates" ON public.training_candidates;
CREATE POLICY "Users can delete their submitted training candidates"
    ON public.training_candidates FOR DELETE
    TO authenticated
    USING (auth.uid()::text = user_id::text);

DROP POLICY IF EXISTS "Users can delete posts they reported" ON public.reported_posts;
CREATE POLICY "Users can delete posts they reported"
    ON public.reported_posts FOR DELETE
    TO authenticated
    USING (auth.uid()::text = reporter_id::text);


-- ─── 5. Realtime Publication & Replica Identity ──────────────────────────────
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime' AND tablename = 'posts'
        ) THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.posts;
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime' AND tablename = 'treatments'
        ) THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.treatments;
        END IF;
    END IF;
END $$;

ALTER TABLE public.posts REPLICA IDENTITY FULL;
ALTER TABLE public.treatments REPLICA IDENTITY FULL;
