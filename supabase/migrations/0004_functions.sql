-- ==============================================================================
-- CropGuard AI — 0004_functions.sql
-- Atomic stored procedures (RPC) for outbreak verification and data operations
-- ==============================================================================

-- ─── 1. Atomic Outbreak Verification Function ────────────────────────────────
-- Resolves race conditions when multiple users simultaneously verify/refute outbreaks.
CREATE OR REPLACE FUNCTION public.verify_outbreak(
    p_report_id UUID,
    p_user_id TEXT,
    p_confirm BOOLEAN
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF p_user_id IS NULL OR TRIM(p_user_id) = '' THEN
        RAISE EXCEPTION 'User ID cannot be null or empty';
    END IF;

    IF p_confirm THEN
        UPDATE public.outbreaks
        SET 
            verified_by = array_append(array_remove(verified_by, p_user_id), p_user_id),
            refuted_by = array_remove(refuted_by, p_user_id),
            updated_at = now()
        WHERE id = p_report_id;
    ELSE
        UPDATE public.outbreaks
        SET 
            refuted_by = array_append(array_remove(refuted_by, p_user_id), p_user_id),
            verified_by = array_remove(verified_by, p_user_id),
            updated_at = now()
        WHERE id = p_report_id;
    END IF;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Outbreak report with ID % not found', p_report_id;
    END IF;
END;
$$;

-- Grant execution permissions
GRANT EXECUTE ON FUNCTION public.verify_outbreak(UUID, TEXT, BOOLEAN) TO authenticated;

-- ─── 2. Full Account Data Purge (Cascading User Cleanup) ─────────────────────
CREATE OR REPLACE FUNCTION public.delete_user_data(
    p_user_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    DELETE FROM public.profiles WHERE id = p_user_id;
    DELETE FROM public.posts WHERE user_id = p_user_id;
    DELETE FROM public.treatments WHERE user_id = p_user_id;
    DELETE FROM public.scans WHERE user_id = p_user_id;
    DELETE FROM public.feedback WHERE user_id = p_user_id;
    DELETE FROM public.missing_crops WHERE user_id = p_user_id;
    DELETE FROM public.expert_requests WHERE user_id = p_user_id;
    DELETE FROM public.reported_posts WHERE user_id = p_user_id OR reporter_id = p_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_user_data(UUID) TO authenticated;
