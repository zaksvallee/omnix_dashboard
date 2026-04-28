BEGIN;

ALTER TABLE public.dispatch_intents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dispatch_transitions ENABLE ROW LEVEL SECURITY;

CREATE POLICY dispatch_intents_service_role_all
  ON public.dispatch_intents
  AS PERMISSIVE
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE POLICY dispatch_intents_authenticated_select
  ON public.dispatch_intents
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING (
    public.onyx_is_control_role()
    AND public.onyx_has_site(COALESCE(ati_snapshot ->> 'site_id', ''))
  );

CREATE POLICY dispatch_transitions_service_role_all
  ON public.dispatch_transitions
  AS PERMISSIVE
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE POLICY dispatch_transitions_authenticated_select
  ON public.dispatch_transitions
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING (
    public.onyx_is_control_role()
    AND EXISTS (
      SELECT 1
      FROM public.dispatch_intents di
      WHERE di.dispatch_id = dispatch_transitions.dispatch_id
        AND public.onyx_has_site(COALESCE(di.ati_snapshot ->> 'site_id', ''))
    )
  );

REVOKE ALL ON TABLE public.dispatch_current_state FROM anon, authenticated;

COMMIT;
