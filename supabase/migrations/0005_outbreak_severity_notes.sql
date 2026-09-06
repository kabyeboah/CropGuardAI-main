-- Add severity and notes columns to public.outbreaks if they do not already exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'outbreaks'
          AND column_name = 'severity'
    ) THEN
        ALTER TABLE public.outbreaks ADD COLUMN severity TEXT DEFAULT 'medium';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'outbreaks'
          AND column_name = 'notes'
    ) THEN
        ALTER TABLE public.outbreaks ADD COLUMN notes TEXT DEFAULT '';
    END IF;
END $$;
