-- ==============================================================================
-- CropGuard AI — 0003_storage.sql
-- Storage buckets and security policies for crop images and community uploads
-- ==============================================================================

-- ─── 1. Create Storage Buckets ────────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
    ('community-images', 'community-images', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp']),
    ('scans', 'scans', false, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp']),
    ('feedback-images', 'feedback-images', false, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- ─── 2. Community Images Bucket Policies ──────────────────────────────────────
DROP POLICY IF EXISTS "Public Read Access for Community Images" ON storage.objects;
CREATE POLICY "Public Read Access for Community Images"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'community-images');

DROP POLICY IF EXISTS "Authenticated users can upload community images" ON storage.objects;
CREATE POLICY "Authenticated users can upload community images"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'community-images');

DROP POLICY IF EXISTS "Users can update their own community images" ON storage.objects;
CREATE POLICY "Users can update their own community images"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (bucket_id = 'community-images' AND auth.uid()::text = (storage.foldername(name))[1]);

DROP POLICY IF EXISTS "Users can delete their own community images" ON storage.objects;
CREATE POLICY "Users can delete their own community images"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (bucket_id = 'community-images' AND auth.uid()::text = (storage.foldername(name))[1]);

-- ─── 3. Scans Bucket Policies ─────────────────────────────────────────────────
DROP POLICY IF EXISTS "Users can view their own scan images" ON storage.objects;
CREATE POLICY "Users can view their own scan images"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (bucket_id = 'scans' AND auth.uid()::text = (storage.foldername(name))[1]);

DROP POLICY IF EXISTS "Users can upload scan images" ON storage.objects;
CREATE POLICY "Users can upload scan images"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'scans' AND auth.uid()::text = (storage.foldername(name))[1]);

DROP POLICY IF EXISTS "Users can delete their own scan images" ON storage.objects;
CREATE POLICY "Users can delete their own scan images"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (bucket_id = 'scans' AND auth.uid()::text = (storage.foldername(name))[1]);

-- ─── 4. Feedback Images Bucket Policies ──────────────────────────────────────
DROP POLICY IF EXISTS "Users can upload feedback images" ON storage.objects;
CREATE POLICY "Users can upload feedback images"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'feedback-images');

DROP POLICY IF EXISTS "Users can view their own feedback images" ON storage.objects;
CREATE POLICY "Users can view their own feedback images"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (bucket_id = 'feedback-images' AND auth.uid()::text = (storage.foldername(name))[1]);

