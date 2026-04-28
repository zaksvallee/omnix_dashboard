BEGIN;

CREATE POLICY fr_person_registry_authenticated_select
  ON public.fr_person_registry
  FOR SELECT
  TO authenticated
  USING (
    public.onyx_is_control_role()
    AND public.onyx_has_site(site_id)
  );

COMMIT;
