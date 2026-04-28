-- 20260428193000_incident_notes.sql
-- Incident note-taking v1: append-only timeline notes per incident.
-- Audit reference: ONYX v2 audit 2026-04-19, critical-path item #3.
-- author_id (FK to auth.users) deferred until auth middleware lands;
-- v1 uses author_label text matching incidents.controller_notes convention.

-- ============================================================================
-- TABLE: incident_notes
-- ============================================================================

CREATE TABLE public.incident_notes (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id   text        NOT NULL REFERENCES public.incidents(id) ON DELETE RESTRICT,
  author_label  text        NOT NULL DEFAULT 'Operator',
  body          text        NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT incident_notes_body_not_blank
    CHECK (length(btrim(body)) > 0),

  CONSTRAINT incident_notes_author_label_not_blank
    CHECK (length(btrim(author_label)) > 0)
);

COMMENT ON TABLE  public.incident_notes IS 'Append-only timeline notes attached to incidents. v1 schema; author_id FK deferred until auth middleware lands. Append-only enforced at RLS layer (SELECT + INSERT policies only).';
COMMENT ON COLUMN public.incident_notes.author_label IS 'Free-text author identifier. Mirrors incidents.controller_notes caller-supplied-string convention. Will be supplemented (not replaced) by author_id uuid FK when auth lands.';
COMMENT ON COLUMN public.incident_notes.body IS 'Note body. Plain text. No markdown, no formatting. Append-only — corrections via a new note that supersedes.';

-- ============================================================================
-- INDEXES
-- ============================================================================

CREATE INDEX incident_notes_incident_created_idx
  ON public.incident_notes (incident_id, created_at ASC);

-- ============================================================================
-- RLS POLICIES
-- ============================================================================
-- v1 wide-open SELECT + INSERT, matching shift_instances and other v2 tables
-- prior to auth landing. NO update/delete policies — append-only is enforced
-- at the policy boundary. Tighten USING/WITH CHECK predicates when
-- middleware.ts + session client are wired (audit critical-path item #1).

ALTER TABLE public.incident_notes ENABLE ROW LEVEL SECURITY;

CREATE POLICY incident_notes_select_all
  ON public.incident_notes
  FOR SELECT
  TO authenticated, anon
  USING (true);

CREATE POLICY incident_notes_insert_all
  ON public.incident_notes
  FOR INSERT
  TO authenticated, anon
  WITH CHECK (true);
