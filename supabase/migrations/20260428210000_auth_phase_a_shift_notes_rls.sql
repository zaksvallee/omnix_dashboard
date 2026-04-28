-- 20260428210000_auth_phase_a_shift_notes_rls.sql
-- Auth Phase A groundwork: tighten the two v1 wide-open tables that were
-- introduced before session-aware clients landed in onyx_dashboard_v2.
--
-- Scope intentionally limited to:
--   * shift_instances
--   * incident_notes
--
-- Follow-up auth sessions still need to reconcile older permissive policies on
-- guards and migrate the rest of the dashboard off service-role reads/writes.

-- ============================================================================
-- shift_instances
-- ============================================================================

DROP POLICY IF EXISTS shift_instances_all ON public.shift_instances;

CREATE POLICY shift_instances_select_policy
  ON public.shift_instances
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.guards g
      WHERE g.id = shift_instances.guard_id
        AND g.client_id = public.onyx_client_id()
        AND public.onyx_has_site(shift_instances.site_id)
        AND (
          public.onyx_is_control_role()
          OR g.guard_id = public.onyx_guard_id()
        )
    )
  );

CREATE POLICY shift_instances_insert_policy
  ON public.shift_instances
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.guards g
      WHERE g.id = shift_instances.guard_id
        AND g.client_id = public.onyx_client_id()
        AND public.onyx_has_site(shift_instances.site_id)
        AND public.onyx_is_control_role()
    )
  );

CREATE POLICY shift_instances_update_policy
  ON public.shift_instances
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.guards g
      WHERE g.id = shift_instances.guard_id
        AND g.client_id = public.onyx_client_id()
        AND public.onyx_has_site(shift_instances.site_id)
        AND public.onyx_is_control_role()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.guards g
      WHERE g.id = shift_instances.guard_id
        AND g.client_id = public.onyx_client_id()
        AND public.onyx_has_site(shift_instances.site_id)
        AND public.onyx_is_control_role()
    )
  );

CREATE POLICY shift_instances_delete_policy
  ON public.shift_instances
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.guards g
      WHERE g.id = shift_instances.guard_id
        AND g.client_id = public.onyx_client_id()
        AND public.onyx_has_site(shift_instances.site_id)
        AND public.onyx_is_control_role()
    )
  );

-- ============================================================================
-- incident_notes
-- ============================================================================

DROP POLICY IF EXISTS incident_notes_select_all ON public.incident_notes;
DROP POLICY IF EXISTS incident_notes_insert_all ON public.incident_notes;

CREATE POLICY incident_notes_select_policy
  ON public.incident_notes
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.incidents i
      WHERE i.id = incident_notes.incident_id
        AND i.client_id = public.onyx_client_id()
        AND public.onyx_has_site(i.site_id)
    )
  );

CREATE POLICY incident_notes_insert_policy
  ON public.incident_notes
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.incidents i
      WHERE i.id = incident_notes.incident_id
        AND i.client_id = public.onyx_client_id()
        AND public.onyx_has_site(i.site_id)
        AND public.onyx_is_control_role()
    )
  );
