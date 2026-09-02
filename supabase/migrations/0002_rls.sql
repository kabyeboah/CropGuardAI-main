-- ==============================================================================
-- CropGuard AI — 0002_rls.sql
-- Row Level Security (RLS) policies for all public tables
-- ==============================================================================

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.outbreaks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.treatments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.missing_crops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expert_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_candidates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reported_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

-- ─── 1. Profiles Policies ─────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Profiles are viewable by authenticated users" ON public.profiles;
CREATE POLICY "Profiles are viewable by authenticated users"
    ON public.profiles FOR SELECT
    TO authenticated
    USING (true);

DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
CREATE POLICY "Users can insert their own profile"
    ON public.profiles FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid()::text = id::text);

DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile"
    ON public.profiles FOR UPDATE
    TO authenticated
    USING (auth.uid()::text = id::text)
    WITH CHECK (auth.uid()::text = id::text);

-- ─── 2. Posts Policies ────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Posts are viewable by everyone" ON public.posts;
CREATE POLICY "Posts are viewable by everyone"
    ON public.posts FOR SELECT
    TO authenticated, anon
    USING (true);

DROP POLICY IF EXISTS "Authenticated users can create posts" ON public.posts;
CREATE POLICY "Authenticated users can create posts"
    ON public.posts FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid()::text = user_id::text);

DROP POLICY IF EXISTS "Users can update their own posts" ON public.posts;
CREATE POLICY "Users can update their own posts"
    ON public.posts FOR UPDATE
    TO authenticated
    USING (auth.uid()::text = user_id::text)
    WITH CHECK (auth.uid()::text = user_id::text);

DROP POLICY IF EXISTS "Users can delete their own posts" ON public.posts;
CREATE POLICY "Users can delete their own posts"
    ON public.posts FOR DELETE
    TO authenticated
    USING (auth.uid()::text = user_id::text);

-- ─── 3. Outbreak Reports Policies ─────────────────────────────────────────────
DROP POLICY IF EXISTS "Outbreaks are viewable by everyone" ON public.outbreaks;
CREATE POLICY "Outbreaks are viewable by everyone"
    ON public.outbreaks FOR SELECT
    TO authenticated, anon
    USING (true);

DROP POLICY IF EXISTS "Authenticated users can submit outbreak reports" ON public.outbreaks;
CREATE POLICY "Authenticated users can submit outbreak reports"
    ON public.outbreaks FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid()::text = user_id::text);

DROP POLICY IF EXISTS "Users can update their own outbreaks directly" ON public.outbreaks;
CREATE POLICY "Users can update their own outbreaks directly"
    ON public.outbreaks FOR UPDATE
    TO authenticated
    USING (auth.uid()::text = user_id::text);

-- ─── 4. Cloud Scans Policies ──────────────────────────────────────────────────
DROP POLICY IF EXISTS "Users can read their own scans" ON public.scans;
CREATE POLICY "Users can read their own scans"
    ON public.scans FOR SELECT
    TO authenticated
    USING (auth.uid()::text = user_id::text);

DROP POLICY IF EXISTS "Users can insert their own scans" ON public.scans;
CREATE POLICY "Users can insert their own scans"
    ON public.scans FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid()::text = user_id::text);

DROP POLICY IF EXISTS "Users can update their own scans" ON public.scans;
CREATE POLICY "Users can update their own scans"
    ON public.scans FOR UPDATE
    TO authenticated
    USING (auth.uid()::text = user_id::text)
    WITH CHECK (auth.uid()::text = user_id::text);

DROP POLICY IF EXISTS "Users can delete their own scans" ON public.scans;
CREATE POLICY "Users can delete their own scans"
    ON public.scans FOR DELETE
    TO authenticated
    USING (auth.uid()::text = user_id::text);

-- ─── 5. Treatments Policies ───────────────────────────────────────────────────
DROP POLICY IF EXISTS "Users can view their own treatments" ON public.treatments;
CREATE POLICY "Users can view their own treatments"
    ON public.treatments FOR SELECT
    TO authenticated
    USING (auth.uid()::text = user_id::text);

DROP POLICY IF EXISTS "Users can create their own treatments" ON public.treatments;
CREATE POLICY "Users can create their own treatments"
    ON public.treatments FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid()::text = user_id::text);

DROP POLICY IF EXISTS "Users can update their own treatments" ON public.treatments;
CREATE POLICY "Users can update their own treatments"
    ON public.treatments FOR UPDATE
    TO authenticated
    USING (auth.uid()::text = user_id::text)
    WITH CHECK (auth.uid()::text = user_id::text);

DROP POLICY IF EXISTS "Users can delete their own treatments" ON public.treatments;
CREATE POLICY "Users can delete their own treatments"
    ON public.treatments FOR DELETE
    TO authenticated
    USING (auth.uid()::text = user_id::text);

-- ─── 6. Feedback Policies ─────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Users can view their submitted feedback" ON public.feedback;
CREATE POLICY "Users can view their submitted feedback"
    ON public.feedback FOR SELECT
    TO authenticated
    USING (auth.uid()::text = user_id::text);

DROP POLICY IF EXISTS "Users can submit feedback" ON public.feedback;
CREATE POLICY "Users can submit feedback"
    ON public.feedback FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid()::text = user_id::text);

-- ─── 7. Missing Crops Policies ────────────────────────────────────────────────
DROP POLICY IF EXISTS "Users can view their submitted missing crops" ON public.missing_crops;
CREATE POLICY "Users can view their submitted missing crops"
    ON public.missing_crops FOR SELECT
    TO authenticated
    USING (auth.uid()::text = user_id::text);

DROP POLICY IF EXISTS "Users can report missing crops" ON public.missing_crops;
CREATE POLICY "Users can report missing crops"
    ON public.missing_crops FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid()::text = user_id::text);

-- ─── 8. Expert Requests Policies ──────────────────────────────────────────────
DROP POLICY IF EXISTS "Users can view their expert consultation requests" ON public.expert_requests;
CREATE POLICY "Users can view their expert consultation requests"
    ON public.expert_requests FOR SELECT
    TO authenticated
    USING (auth.uid()::text = user_id::text);

DROP POLICY IF EXISTS "Users can create expert consultation requests" ON public.expert_requests;
CREATE POLICY "Users can create expert consultation requests"
    ON public.expert_requests FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid()::text = user_id::text);

-- ─── 9. Training Candidates Policies ──────────────────────────────────────────
DROP POLICY IF EXISTS "Authenticated users can submit training candidates" ON public.training_candidates;
CREATE POLICY "Authenticated users can submit training candidates"
    ON public.training_candidates FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid()::text = user_id::text);

-- ─── 10. Reported Posts Policies ──────────────────────────────────────────────
DROP POLICY IF EXISTS "Users can view posts they reported" ON public.reported_posts;
CREATE POLICY "Users can view posts they reported"
    ON public.reported_posts FOR SELECT
    TO authenticated
    USING (auth.uid()::text = reporter_id::text);

DROP POLICY IF EXISTS "Users can report posts" ON public.reported_posts;
CREATE POLICY "Users can report posts"
    ON public.reported_posts FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid()::text = reporter_id::text);

-- ─── 11. App Config Policies ──────────────────────────────────────────────────
DROP POLICY IF EXISTS "App config is readable by everyone" ON public.app_config;
CREATE POLICY "App config is readable by everyone"
    ON public.app_config FOR SELECT
    TO authenticated, anon
    USING (true);
