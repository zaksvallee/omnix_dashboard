ALTER TABLE public.site_alert_config
ADD COLUMN IF NOT EXISTS vehicle_daytime_threshold text NOT NULL DEFAULT 'quiet_hours_only';

UPDATE public.site_alert_config
SET vehicle_daytime_threshold = 'quiet_hours_only'
WHERE site_id = 'SITE-MS-VALLEE-RESIDENCE';
