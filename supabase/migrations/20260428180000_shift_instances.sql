-- 20260428180000_shift_instances.sql
-- Shift rostering v1: single-table timeclock with forward-compat for pattern automation.
-- Audit reference: docs/audit-2026-04-19.md line 235.

-- ============================================================================
-- TABLE: shift_instances
-- ============================================================================

CREATE TABLE public.shift_instances (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  guard_id        uuid        NOT NULL REFERENCES public.guards(id) ON DELETE CASCADE,
  site_id         text        NOT NULL,
  assignment_id   uuid        NULL,
  planned_start   timestamptz NOT NULL,
  planned_end     timestamptz NOT NULL,
  actual_start    timestamptz NULL,
  actual_end      timestamptz NULL,
  status          text        NOT NULL DEFAULT 'planned',
  shift_type      text        NULL,
  notes           text        NULL,
  created_by      uuid        NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT shift_instances_status_check
    CHECK (status IN ('planned', 'in_progress', 'completed', 'missed', 'cancelled')),
  CONSTRAINT shift_instances_shift_type_check
    CHECK (shift_type IS NULL OR shift_type IN ('day', 'night')),
  CONSTRAINT shift_instances_planned_window_check
    CHECK (planned_end > planned_start),
  CONSTRAINT shift_instances_actual_window_check
    CHECK (actual_end IS NULL OR actual_start IS NULL OR actual_end > actual_start)
);

COMMENT ON TABLE  public.shift_instances IS 'Individual clocked shifts. Each row is one shift; pattern-driven generation deferred to a future shift_assignments table.';
COMMENT ON COLUMN public.shift_instances.assignment_id IS 'Reserved for future shift_assignments table. Always NULL in v1.';
COMMENT ON COLUMN public.shift_instances.site_id IS 'Text reference to a site, matching guards.primary_site_id convention. No FK enforcement.';
COMMENT ON COLUMN public.shift_instances.status IS 'Canonical enum: planned | in_progress | completed | missed | cancelled. Display order: in_progress > planned > completed > missed > cancelled.';
COMMENT ON COLUMN public.shift_instances.shift_type IS 'Canonical enum: day | night | null. NULL for ad-hoc/improvised shifts.';

CREATE INDEX shift_instances_guard_planned_start_idx
  ON public.shift_instances (guard_id, planned_start DESC);

CREATE INDEX shift_instances_site_planned_start_idx
  ON public.shift_instances (site_id, planned_start DESC);

CREATE INDEX shift_instances_active_idx
  ON public.shift_instances (status, planned_start DESC)
  WHERE status IN ('planned', 'in_progress');

CREATE UNIQUE INDEX shift_instances_one_active_per_guard_idx
  ON public.shift_instances (guard_id)
  WHERE status = 'in_progress';

CREATE OR REPLACE FUNCTION public.set_shift_instances_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER set_shift_instances_updated_at
  BEFORE UPDATE ON public.shift_instances
  FOR EACH ROW
  EXECUTE FUNCTION public.set_shift_instances_updated_at();

ALTER TABLE public.shift_instances ENABLE ROW LEVEL SECURITY;

CREATE POLICY shift_instances_all
  ON public.shift_instances
  FOR ALL
  TO authenticated, anon
  USING (true)
  WITH CHECK (true);
