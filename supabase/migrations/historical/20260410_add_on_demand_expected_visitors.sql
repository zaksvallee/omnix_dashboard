ALTER TABLE public.site_expected_visitors
ADD COLUMN IF NOT EXISTS visit_type text DEFAULT 'scheduled';

ALTER TABLE public.site_expected_visitors
ADD COLUMN IF NOT EXISTS visit_date date;

UPDATE public.site_expected_visitors
SET visit_type = 'scheduled'
WHERE visit_type IS NULL
   OR length(btrim(visit_type)) = 0;
