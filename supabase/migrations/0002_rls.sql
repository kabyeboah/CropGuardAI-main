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
CREATE POLICY "Profiles are viewable by authenticated users"
    ON public.profiles FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Users can insert their own profile"
    ON public.profiles FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
    ON public.profiles FOR UPDATE
    TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- ─── 2. Posts Policies ────────────────────────────────────────────────────────
CREATE POLICY "Posts are viewable by everyone"
    ON public.posts FOR SELECT
    TO authenticated, anon
    USING (true);

CREATE POLICY "Authenticated users can create posts"
    ON public.posts FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own posts"
    ON public.posts FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own posts"
    ON public.posts FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

-- ─── 3. Outbreak Reports Policies ─────────────────────────────────────────────
CREATE POLICY "Outbreaks are viewable by everyone"
    ON public.outbreaks FOR SELECT
    TO authenticated, anon
    USING (true);

CREATE POLICY "Authenticated users can submit outbreak reports"
    ON public.outbreaks FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own outbreaks directly"
    ON public.outbreaks FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id);

-- ─── 4. Cloud Scans Policies ──────────────────────────────────────────────────
CREATE POLICY "Users can read their own scans"
    ON public.scans FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own scans"
    ON public.scans FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own scans"
    ON public.scans FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own scans"
    ON public.scans FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

-- ─── 5. Treatments Policies ───────────────────────────────────────────────────
CREATE POLICY "Users can view their own treatments"
    ON public.treatments FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own treatments"
    ON public.treatments FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own treatments"
    ON public.treatments FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own treatments"
    ON public.treatments FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

-- ─── 6. Feedback Policies ─────────────────────────────────────────────────────
CREATE POLICY "Users can view their submitted feedback"
    ON public.feedback FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can submit feedback"
    ON public.feedback FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- ─── 7. Missing Crops Policies ────────────────────────────────────────────────
CREATE POLICY "Users can view their submitted missing crops"
    ON public.missing_crops FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can report missing crops"
    ON public.missing_crops FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- ─── 8. Expert Requests Policies ──────────────────────────────────────────────
CREATE POLICY "Users can view their expert consultation requests"
    ON public.expert_requests FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create expert consultation requests"
    ON public.expert_requests FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- ─── 9. Training Candidates Policies ──────────────────────────────────────────
CREATE POLICY "Authenticated users can submit training candidates"
    ON public.training_candidates FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- ─── 10. Reported Posts Policies ──────────────────────────────────────────────
CREATE POLICY "Users can view posts they reported"
    ON public.reported_posts FOR SELECT
    TO authenticated
    USING (auth.uid() = reporter_id);

CREATE POLICY "Users can report posts"
    ON public.reported_posts FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = reporter_id);

-- ─── 11. App Config Policies ──────────────────────────────────────────────────
CREATE POLICY "App config is readable by everyone"
    ON public.app_config FOR SELECT
    TO authenticated, anon
    USING (true);
