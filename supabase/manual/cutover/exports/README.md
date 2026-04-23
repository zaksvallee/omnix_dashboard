# cutover/exports/

Per-run JSON output directory for the Layer 2 cutover scripts:

- `scripts/cutover_qa_corpus_freeze.py` writes `<run_timestamp>/qa_corpus/`
  and `<run_timestamp>/qa_corpus_index.json` (per phase 5 §3.4 step 3).
- `scripts/cutover_preservation_export.py` writes
  `<run_timestamp>/preservation/` and `<run_timestamp>/preservation_index.json`
  (per §3.4 step 4).

`<run_timestamp>` is ISO 8601 UTC compact (`%Y%m%dT%H%M%SZ`). When both
scripts run as part of a single cutover invocation, the operator passes
the same `--run-timestamp` to both so outputs land in one subdirectory.

Payload files are gitignored — they contain operational data (potentially
sensitive) and would bloat the repo. Only `.gitkeep` and this README are
tracked, so the directory layout ships even when no run has happened.

The runbook for executing a cutover lives at
`supabase/manual/cutover/RUNBOOK.md` once Phase C of Layer 2 prep lands.
Until then, refer to phase 5 §3.4 in `audit/phase_5_section_3_cutover_policy.md`.
