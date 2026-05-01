ALTER TABLE public.clients
  ADD COLUMN IF NOT EXISTS zara_tier text;

UPDATE public.clients
SET zara_tier = CASE
  WHEN lower(trim(coalesce(zara_tier, ''))) IN ('standard', 'premium', 'tactical')
    THEN lower(trim(zara_tier))
  WHEN lower(trim(coalesce(metadata->>'zara_tier', ''))) IN ('standard', 'premium', 'tactical')
    THEN lower(trim(metadata->>'zara_tier'))
  ELSE 'standard'
END;

ALTER TABLE public.clients
  ALTER COLUMN zara_tier SET DEFAULT 'standard';

ALTER TABLE public.clients
  ALTER COLUMN zara_tier SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'clients_zara_tier_check'
  ) THEN
    ALTER TABLE public.clients
      ADD CONSTRAINT clients_zara_tier_check
      CHECK (zara_tier IN ('standard', 'premium', 'tactical'));
  END IF;
END
$$;

COMMENT ON COLUMN public.clients.zara_tier IS
  'Zara product access tier for this client. Used by the Telegram Zara runtime for capability gating.';
