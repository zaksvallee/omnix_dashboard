BEGIN;

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.decision_audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.onyx_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY users_service_role_all
  ON public.users
  AS PERMISSIVE
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE POLICY users_authenticated_control_select
  ON public.users
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING (public.onyx_is_control_role());

CREATE POLICY roles_service_role_all
  ON public.roles
  AS PERMISSIVE
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE POLICY roles_authenticated_control_select
  ON public.roles
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING (public.onyx_is_control_role());

CREATE POLICY decision_audit_log_service_role_all
  ON public.decision_audit_log
  AS PERMISSIVE
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE POLICY decision_audit_log_authenticated_control_select
  ON public.decision_audit_log
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING (public.onyx_is_control_role());

CREATE POLICY onyx_settings_service_role_all
  ON public.onyx_settings
  AS PERMISSIVE
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE OR REPLACE FUNCTION public.admin_onyx_settings_count()
RETURNS bigint
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  select
    case
      when public.onyx_is_control_role()
        then (select count(*)::bigint from public.onyx_settings)
      else 0::bigint
    end;
$$;

REVOKE ALL ON FUNCTION public.admin_onyx_settings_count() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_onyx_settings_count() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_onyx_settings_count() TO service_role;

COMMIT;
