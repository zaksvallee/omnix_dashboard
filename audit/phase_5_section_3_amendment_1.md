Phase 5 §3 — Amendment 1 (2026-04-23)
Appends to: audit/phase_5_section_3_cutover_policy.md
Trigger: Phase A diagnostic run surfaced gaps between §3.1 categorical clusters and live schema reality.
Status: Additive amendment. Existing §3 text is not replaced; this section extends and clarifies.

3.1.3 (clarification)
Original text stated that zone-to-alert-rule mappings "do not yet exist in the schema." This is literally incorrect — the site_zone_rules table exists in baseline. Operationally the statement holds: the table is empty (0 rows at cutover prep time). site_zone_rules is therefore in the untouched set per §3.3 (empty, no rows to act on). No policy change; wording correction only.

3.1.5 (confirmation)
Camera credentials (RTSP, ISAPI) are stored on the Pi filesystem via environment variables ONYX_HIK_PASSWORD and ONYX_DVR_PASSWORD, read at worker startup in bin/onyx_camera_worker.dart. No Supabase table holds camera credentials. §3.1.5 cluster has zero DB tables at current schema. Re-provisioning cameras post-cutover is a Pi-side concern (redeploy env file), not a Supabase concern. This is confirmed, not a gap.

3.1.7 (pending)
Edge device registration cluster has one remaining ambiguity: operational_nodes (3 rows) is the candidate table. Resolution requires inspection of the 3 rows — if any represent the live Pi at 192.168.0.67, cluster becomes preservation; if none do, cluster remains empty and operational_nodes is classified per its actual contents. Deferred to follow-on Phase A query.

3.1.9 Expansion — site-scoped intelligence and geography
The following tables extend §3.1.4 (site configuration cluster). They are preserved on the "don't remember creating, can't cheaply reconstruct" principle — row counts are low (1–4), contents may encode real operator decisions that would be expensive to recover if wiped:

site_expected_visitors — expected-visitor entries tied to MS Vallee
site_intelligence_profiles — site-scoped intel configuration
area_sites — area-to-site geography mapping

Rationale: these are small-volume, plausibly-real configuration tables where preservation cost is zero and wipe regret is irrecoverable.

3.1.10 Vehicle registry — parallel table disposition
public.vehicles (3 rows) is preserved alongside public.site_vehicle_registry (4 rows, §3.1.2). Purpose distinction between the two tables is currently unresolved — possibilities include fleet vs site-visiting vehicle separation, or legacy schema not yet migrated. Preservation avoids data loss while the distinction is investigated in a later layer. Both tables remain in preservation until §3.1.2 is rewritten with a clearer model.

3.2.1 Explicit wipe categories — expansion
The following categories of tables are confirmed wipe, per owner-operator confirmation that all non-MS-Vallee data is test-grade dummy content seeded during Flutter dashboard development:

Personnel cluster (8 tables): guards, employees, staff, controllers, guard_profiles, guard_documents, guard_assignments, guard_sites, employee_site_assignments. Test data. No real operators or guards are currently registered.
Threat rule engine (4 tables): ThreatCategories, ThreatLevels, ThreatMatrix, threat_decay_profiles. Dummy rule-engine configuration. No hand-curated threat taxonomy.
Alert/dispatch catalogues (2 tables): alert_rules, dispatch_actions. Dummy scaffolding.
Reference catalogues (3 tables): roles, mo_library, public.users. Dummy.
Intel configuration (2 tables): intel_source_weights, global_patterns. Dummy.
Patrol configuration (4 tables): patrol_routes, patrol_checkpoints, patrols, posts. No real patrol routes configured; MS Vallee is a residential site with no guard patrols.
Scenario scaffolding: zara_scenarios. Dummy.

Total wipe category additions: 24 tables. All confirmed test-grade per owner statement.

3.3.1 Untouched set — explicit enumeration
The following tables are classified untouched per §3.3 criteria. Empty tables are listed first, auto-regenerating tables second:
Empty (0 rows, §3.3 bullet 1):

site_identity_profiles, site_identity_approval_decisions — face-gallery adjacency, decidable on emptiness
site_zone_rules — per §3.1.3 clarification above
alarm_accounts — armed response linkage candidate, vacuously empty
deployments — empty at cutover
checkins — resolves the patrol_triggers CASCADE concern from Phase A Gap N (empty child = no-op cascade)

Auto-regenerating (§3.3 bullet 2):

demo_state (1 row) — regenerates on next demo event
watch_current_state (1 row) — regenerates on next watch event
client_conversation_push_sync_state (2 rows) — regenerates on next push sync per operator

3.4.1 Sites table — Path A confirmation
public.sites contains 8 rows at cutover prep time. MS Vallee is the only live site; the other 7 are dummy rows from earlier schema iterations. Preservation action: Path A — preserve all 8 as-is. Rationale: Layer 2 is scoped to event-corpus wipe, not configuration tidying. Dummy site rows are inert and referentially safe to leave in place. Layer 4 (v1 decommission + v2 polish) is the correct scope for site-row cleanup, where a proper audit of which preservation-set rows FK back to dummy sites can be performed.
During Phase A manifest drafting, CC should spot-check preservation tables for site_id FK distribution — if any preservation table has rows pointing at non-MS-Vallee site IDs, those rows are preserved alongside their parent dummy site per Path A. No action taken, but the finding should be reported so Layer 4 has a starting inventory.
