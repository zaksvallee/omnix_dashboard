I have enough data to produce the inventory. Delivering it now.

---

# ONYX Dashboard — Design Inventory

Source of truth for Figma design brief. All paths absolute from repo root `/Users/zaks/omnix_dashboard`.

> Note on scope: Several pages exceed 5k–45k lines (admin_page 44,891; live_operations 19,476; governance 14,748; onyx_agent 11,410; client_intelligence_reports 11,327; client_app 10,976). For those, class/enum-level structure, constructor-parameter surface, and the feature tokens extracted via grep are captured below. Where finer-grained button enumeration was not possible within read-budget, that is flagged as [PARTIAL].

---

## 1. Navigation Structure

### 1.1 Route enum — `/Users/zaks/omnix_dashboard/lib/domain/authority/onyx_route.dart`

Authoritative `enum OnyxRoute` (15 routes) — the ONLY route definition allowed in the system.

| # | Enum | Path | Nav label | Shell header | Icon | Section | Autopilot narration | Shell badge kind | Badge color | Agent scope source | Shell intel ticker |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `dashboard` | `/dashboard` | Command | COMMAND | `bolt_rounded` | COMMAND CENTER | "Operational overview." | `activeIncidents` | `0xFFEF4444` (red) | `operationsRoute` | **false** |
| 2 | `agent` | `/agent` | Agent | AGENT | `auto_awesome_rounded` | COMMAND CENTER | "Local-first controller brain with specialist agent handoffs." | — | — | `selectedScope` | true |
| 3 | `aiQueue` | `/ai-queue` | AI Queue | AI QUEUE | `videocam_rounded` | COMMAND CENTER | "AI-powered surveillance and alert review." | `aiActions` | `0xFF22D3EE` (cyan) | `aiQueueFocus` | true |
| 4 | `tactical` | `/tactical` | Track | TRACK | `map_rounded` | COMMAND CENTER | "Verify units, geofence, and site posture." | `tacticalSosAlerts` | `0xFFEF4444` | `tacticalRoute` | true |
| 5 | `dispatches` | `/dispatches` | Dispatches | DISPATCHES | `send_rounded` | COMMAND CENTER | "Execute with focused dispatch context." | — | — | `dispatchRoute` | true |
| 6 | `vip` | `/vip` | VIP | VIP | `shield_outlined` | OPERATIONS | "Quiet convoy posture and upcoming VIP details." | — | — | `selectedScope` | true |
| 7 | `intel` | `/intel` | Intel | INTEL | `trending_up_rounded` | OPERATIONS | "Threat posture and intelligence watch." | — | — | `selectedScope` | true |
| 8 | `clients` | `/clients` | Clients | COMMS | `chat_bubble_rounded` | OPERATIONS | "Client-facing confidence and Client Comms desk." | — | — | `clientsRoute` | true |
| 9 | `sites` | `/sites` | Sites | SITES | `apartment_rounded` | OPERATIONS | "Deployment footprint and zone definitions." | — | — | `selectedScope` | true |
| 10 | `guards` | `/guards` | Guards | GUARDS | `groups_rounded` | OPERATIONS | "Field force state and sync health." | — | — | `selectedScope` | true |
| 11 | `events` | `/events` | Events | EVENTS | `timeline_rounded` | OPERATIONS | "Replay immutable incident timeline." | — | — | `selectedScope` | true |
| 12 | `governance` | `/governance` | Governance | GOVERNANCE | `shield_rounded` | GOVERNANCE | "Show compliance and readiness controls." | `complianceIssues` | `0xFF60A5FA` (blue) | `selectedScope` | true |
| 13 | `ledger` | `/ledger` | OB Log | LEDGER | `menu_book_rounded` | EVIDENCE | "Review clean operational records and linked continuity." | — | — | `selectedScope` | true |
| 14 | `reports` | `/reports` | Reports | REPORTS | `summarize_rounded` | EVIDENCE | "Review export proof and generated reports." | — | — | `selectedScope` | true |
| 15 | `admin` | `/admin` | Admin | ADMIN | `settings_rounded` | SYSTEM | "Manage runtime controls and system settings." | — | — | `selectedScope` | true |

### 1.2 Section groupings — `enum OnyxRouteSection`

- `commandCenter` → "COMMAND CENTER" → [dashboard, agent, aiQueue, tactical, dispatches]
- `operations` → "OPERATIONS" → [vip, intel, clients, sites, guards, events]
- `governance` → "GOVERNANCE" → [governance]
- `evidence` → "EVIDENCE" → [ledger, reports]
- `system` → "SYSTEM" → [admin]

### 1.3 Badge kinds — `enum OnyxRouteShellBadgeKind`
`activeIncidents`, `aiActions`, `tacticalSosAlerts`, `complianceIssues`

### 1.4 Agent focus / scope sources
- `enum OnyxRouteAgentFocusSource` — `operations`, `aiQueue`
- `enum OnyxRouteAgentScopeSource` — `selectedScope`, `operationsRoute`, `aiQueueFocus`, `tacticalRoute`, `clientsRoute`, `dispatchRoute`

### 1.5 Route registry — `/Users/zaks/omnix_dashboard/lib/ui/onyx_route_registry.dart`
Asserts every `OnyxRoute.values` has a builder — enforces 1:1 with the enum.

### 1.6 Route dispatcher — `/Users/zaks/omnix_dashboard/lib/ui/onyx_route_dispatcher.dart`
`part of '../main.dart'` — main.dart owns the GoRouter configuration.

### 1.7 App shell — `/Users/zaks/omnix_dashboard/lib/ui/app_shell.dart`

- Sidebar: 228px wide on desktop, 320px as mobile drawer.
- Top bar: 56px tall.
- Intel ticker strip appears when current route has `showsShellIntelTicker = true` (i.e. all routes except `dashboard`).
- Cmd/Ctrl+K opens a Quick-Jump dialog with label/header/autopilot-key matching.
- Autopilot bar with Stop / Pause / Next controls.
- Operator session chip (principal + role label).
- READY status pill.
- Notification icon with red alert dot.

### 1.8 Conditional navigation
- Login gate: `ControllerLoginPage` renders until a `ControllerLoginAccount` is selected; the account's `landingRoute` (one of `OnyxRoute`) is pushed on sign-in.
- Admin-only persona gating: `_AgentPersona.adminOnly` filters agent personas inside Agent page.
- VIP / Dispatch / Tactical pages deep-link via `agentScopeSource` so the Agent drawer inherits the correct scope.

---

## 2. Pages (per `lib/ui/*_page.dart`)

### 2.1 `/Users/zaks/omnix_dashboard/lib/ui/controller_login_page.dart` (473 lines)

- Route: pre-router gate (not in OnyxRoute).
- Model: `ControllerLoginAccount(username, password, displayName, roleLabel, accessLabel, landingRoute)`.
- Demo accounts (seeded in main.dart:1793):
  1. `admin / onyx123` — Emily Davis — Admin — Full Access → `OnyxRoute.dashboard`
  2. `supervisor / onyx123` — Mike Wilson — Supervisor — Reports → `OnyxRoute.reports`
  3. `controller1 / onyx123` — John Smith — Controller — Operations → `OnyxRoute.dashboard`
- UI: ONYX SECURITY logo, tagline "Operations Control Platform".
- Fields: username (autofocus, `person` icon), password (obscured, `lock` icon).
- Buttons: Sign In (cyan filled), Clear Cache & Reset (red outlined), three tappable demo account cards.

### 2.2 `/Users/zaks/omnix_dashboard/lib/ui/dashboard_page.dart` (5,467 lines) [PARTIAL]

- Route: `/dashboard`.
- Constructor: `DashboardPage` takes `InMemoryEventStore` + ~30 guard-sync, dispatch, telemetry parameters.
- Threat-state palette: `CRITICAL 0xFFFF6A6F`, `ELEVATED 0xFFFFB44D`, `STABLE 0xFF49D2FF`.
- Triage counters: `advisoryCount`, `watchCount`, `dispatchCandidateCount`, `escalateCount`.
- Persists a rolling `SovereignReport` history.
- Layouts: `_DesktopDashboard` / `_CompactDashboard` split at 980px breakpoint.

### 2.3 `/Users/zaks/omnix_dashboard/lib/ui/onyx_agent_page.dart` (11,410 lines) [PARTIAL]

- Route: `/agent`.
- 12 agent action kinds — `enum _AgentActionKind`: `seedPrompt, executeRecommendation, dryProbeCamera, stageCameraChange, approveCameraChange, logCameraRollback, draftClientReply, summarizeIncident, openCctv, openComms, openAlarms, openTrack`.
- Brain providers — `enum _AgentBrainProvider`: `local, cloud, none`.
- Message kinds — `enum _AgentMessageKind`: `user, agent, tool`.
- `_AgentPersona` has `adminOnly` flag (admin-only personas hidden for non-admins).

### 2.4 `/Users/zaks/omnix_dashboard/lib/ui/ai_queue_page.dart` (5,876 lines) [PARTIAL]

- Route: `/ai-queue`.
- Priority enum `_AiIncidentPriority`: `p1Critical`, `p2High`, `p3Medium`.
- Status enum `_AiActionStatus`: `pending`, `executing`, `paused`.
- Lane filter `_AiQueueLaneFilter`: `live`, `queued`, `drafts`, `shadow`.
- Workspace tabs `_AiQueueWorkspaceView`: `runbook`, `policy`, `context`.
- Classes: `_AiQueueAction` (with countdown timer), `_CctvBoardAlert`, `_CctvBoardFeed`.
- Default command receipt pill: "AI CALL READY".

### 2.5 `/Users/zaks/omnix_dashboard/lib/ui/tactical_page.dart` (7,440 lines) [PARTIAL]

- Route: `/tactical`.
- Uses `flutter_map` (`FlutterMap`, `MapController`, `LatLng`).
- Marker types `_MarkerType`: `guard`, `vehicle`, `incident`, `site`.
- Marker status `_MarkerStatus`: `active`, `responding`, `staticMarker`, `sos`.
- Geofence status `_FenceStatus`: `safe`, `breach`, `stationary`.
- Map filter `_TacticalMapFilter`: `all`, `responding`, `incidents`.
- Verification queue `_VerificationQueueTab`: `anomalies`, `matches`, `assets`.
- CCTV lens telemetry fields: `totalSignals`, `frMatches`, `lprHits`, `anomalies`, `snapshotsReady`, `clipsReady`, `anomalyTrend`.

### 2.6 `/Users/zaks/omnix_dashboard/lib/ui/vip_protection_page.dart` (1,027 lines)

- Route: `/vip`.
- Models: `VipScheduledDetail(title, subtitle, badgeLabel, facts)`, `VipAutoAuditReceipt`, `VipDetailFact`.
- Buttons: Open Package Desk, Stage Detail, OPEN PACKAGE REVIEW, View Audit, Cancel, Acknowledge.
- Dialog fields: Protectee, Route Corridor, Start Time.
- Empty state: "No Live VIP Run" (accent `0xFF9D4BFF` purple).

### 2.7 `/Users/zaks/omnix_dashboard/lib/ui/risk_intelligence_page.dart` (1,457 lines)

- Route: `/intel`.
- Models: `RiskIntelAreaSummary`, `RiskIntelFeedItem`, `RiskIntelAutoAuditReceipt`.
- Subpanels: `_IntelAuditReceipt`, `_IntelStatusStrip`, `_IntelPriorityPanel`, `_IntelAreaPanel`, `_IntelAreaCard`, `_IntelRecentPanel`, `_IntelItemCard`, `_IntelDialogFrame`, `_IntelDialogSection`.

### 2.8 `/Users/zaks/omnix_dashboard/lib/ui/clients_page.dart` (4,501 lines) [PARTIAL]

- Route: `/clients` (shell label "COMMS").
- Handoff model: `ClientsAgentDraftHandoff(id, clientId, siteId, room, incidentReference, draftText, severity)`.
- Handoff target enum `ClientsRouteHandoffTarget`: `none`, `pendingDrafts`, `threadContext`, `channelReview`.
- Flag `usePlaceholderDataWhenEmpty = true` (placeholder data marked as TODO in several spots).

### 2.9 `/Users/zaks/omnix_dashboard/lib/ui/client_intelligence_reports_page.dart` (11,327 lines) [PARTIAL]

- Companion report viewer for clients (no direct OnyxRoute entry — invoked from Clients / Reports flows).
- Top-level class: `ClientIntelligenceReportsPage extends StatefulWidget` (line 67).

### 2.10 `/Users/zaks/omnix_dashboard/lib/ui/client_app_page.dart` (10,976 lines) [PARTIAL]

- Client-facing app preview surface.
- `enum ClientAppLocale`: `en`, `zu`, `af` (English, isiZulu, Afrikaans — South African product).
- `enum ClientPushDeliveryProvider`: `inApp`, `telegram`.
- `enum ClientAppComposerPrefillType`: `update`, `advisory`, `closure`, `dispatch`.
- `enum ClientAppViewerRole`.
- `class ClientAppEvidenceReturnReceipt`.

### 2.11 `/Users/zaks/omnix_dashboard/lib/ui/sites_page.dart` (2,580 lines) [PARTIAL]

- Route: `/sites`.
- Lane filter `_SiteLaneFilter`: `all`, `watch`, `active`, `strong`.
- Workspace view `_SiteWorkspaceView`: `command`, `outcomes`, `trace`.
- Ghost-site filter: excludes `site-unknown`.
- Uses `OperationsHealthProjection.build()`.

### 2.12 `/Users/zaks/omnix_dashboard/lib/ui/sites_command_page.dart` (2,783 lines) [PARTIAL]

- Sites command-view variant (dispatch-adjacent).
- Model: `SitesAutoAuditReceipt`.
- Lane filter `_SiteLaneFilter`: `all`, `healthy`, `watch`, `strong`.
- Workspace view `_SiteWorkspaceView`: `response`, `coverage`, `checkpoints`.

### 2.13 `/Users/zaks/omnix_dashboard/lib/ui/guards_page.dart` (3,916 lines) [PARTIAL]

- Route: `/guards`.
- Hard-coded guard records: T. Nkosi (GRD-441), J. van Wyk (GRD-442), … with `siteCode`, `employeeId`, `contactPhone`, `status`, `shiftWindow`.
- Status enum `_GuardStatus`: `onDuty`, `offDuty`.
- Contact mode `_GuardContactMode`: `message`, `call`.
- View enum `_GuardsView`: `active`, `roster`, `history`.
- Roster planner status `_RosterPlannerStatus`: `published`, `draft`, `gap`.
- Roster month: March 2026; reference date: 2026-03-27.

### 2.14 `/Users/zaks/omnix_dashboard/lib/ui/guard_mobile_shell_page.dart` (6,851 lines) [PARTIAL]

- Mobile/handset shell for guards (separate from desktop `/guards` page).
- Classes/enums:
  - `enum _GuardMobileScreen`
  - `enum GuardMobileInitialScreen`: `dispatch`, `sync`
  - `enum GuardMobileOperatorRole`: `guard`, `reaction`, `supervisor`
  - `enum _SyncRowFilter`: `all`, `failed`, `pending`, `synced`
  - `enum _ExportAuditFilter`
  - `enum GuardSyncOperationModeFilter`: `all`, `live`, `stub`, `unknown`
  - `enum GuardSyncHistoryFilter`: `queued`, `synced`, `failed`, `all`

### 2.15 `/Users/zaks/omnix_dashboard/lib/ui/dispatch_page.dart` (8,002 lines) [PARTIAL]

- Route: `/dispatches`.
- Constructor has 80+ parameters (radio ops, CCTV ops, wearable ops, news sources, telemetry, intake-stress profiles, fleet-scope health, scene reviews, evidence receipts, agent return references).
- `isSeededPlaceholder` flag per dispatch.

### 2.16 `/Users/zaks/omnix_dashboard/lib/ui/events_page.dart` (3,837 lines)

- Route: `/events`.
- Filters: `typeFilter`, `siteFilter`, `guardFilter`, `_TimeWindow.last24h`, `_EventLaneFilter.all`, `_EventWorkspaceView.casefile`.
- Limits: `_maxTimelineRows = 50`, `_maxDetailRows = 24`.
- Chain-integrity check driven by `ExecutionDenied` / `ExecutionCompleted(success=false)` events.
- End drawer used for mobile event-detail view.

### 2.17 `/Users/zaks/omnix_dashboard/lib/ui/events_review_page.dart` (7,354 lines) [PARTIAL]

- Companion review surface (not a direct OnyxRoute — invoked from governance/evidence flows).
- `class EventsReviewPage extends StatefulWidget` (line 39).
- Seeded event class `_SeededDispatchEvent extends DispatchEvent`.
- Late-file enums/models: `_VisitTimelineStage(entry, service, exit, observed)`, `_VisitTimelineStatus(completed, active, incomplete)`, `_PartnerScopeSummary`, `_ActivityScopeSummary`, `_ShadowScopeSummary`, `_ReadinessScopeSummary`, `_SyntheticScopeSummary`, `_PromotionShadowAnchorSummary`, `_TomorrowPostureScopeSummary`, `_TomorrowPostureHistorySummary`, `_TomorrowPostureHistoryPoint`, `_ShadowHistorySummary`, `_ShadowHistoryPoint`, `_SyntheticHistorySummary`, `_SyntheticHistoryPoint`, `_ActivityHistorySummary`, `_ActivityHistoryPoint`, `_PartnerScopeDetail`, `_PartnerTrendSummary`.

### 2.18 `/Users/zaks/omnix_dashboard/lib/ui/governance_page.dart` (14,748 lines) [PARTIAL]

- Route: `/governance`.
- Constructor takes `events`, `sceneReviewByIntelligenceId`, `morningSovereignReport`, partner scopes, `operationalFeedsLoader`, `GovernanceSceneActionFocus`.
- Tracks compliance issue resolutions and vehicle exception review overrides.

### 2.19 `/Users/zaks/omnix_dashboard/lib/ui/live_operations_page.dart` (19,476 lines) [PARTIAL]

- Large live-ops surface (not a direct shell route — embedded in the dispatch/ops flow).
- `class LiveOperationsPage` constructor has 50+ parameters.
- Override reason codes: `DUPLICATE_SIGNAL`, `FALSE_ALARM`, `TEST_EVENT`, `CLIENT_VERIFIED_SAFE`, `HARDWARE_FAULT`.
- `enum _ContextTab`: `details`, `voip`, `visual`.
- Client-lane camera health auto-refreshes every 5 seconds.
- Surfaces: VoIP staging, lane voice profile, learned-style management.

### 2.20 `/Users/zaks/omnix_dashboard/lib/ui/ledger_page.dart` (2,788 lines) [PARTIAL]

- Route: `/ledger` (shell label "OB Log") — the top-level Ledger/Evidence view.
- `class LedgerPage extends StatefulWidget` (line 32).
- `class _LedgerTimelineRow` (line 2596).
- `enum _LedgerLaneFilter` (line 2626).
- `enum _LedgerWorkspaceView` (line 2639).
- `class _LedgerReviewRow` (line 2651).

### 2.21 `/Users/zaks/omnix_dashboard/lib/ui/sovereign_ledger_page.dart` (3,966 lines) [PARTIAL]

- Deep-dive ledger with chain-of-custody integrity proofs (OB Log).
- `SovereignLedgerPinnedAuditEntry` includes `hash` + `previousHash` chain.
- Dispatches `DispatchAuditOpenRequest` back to the dispatch flow.
- Manual OB-entry composer: `_guardNameController`, `_callsignController`, `_locationController`, `_descriptionController`.
- `enum _ObCategory`.
- `enum _ChainIntegrity`: includes `pending`.

### 2.22 `/Users/zaks/omnix_dashboard/lib/ui/admin_page.dart` (44,891 lines) [PARTIAL]

- Route: `/admin`.
- 4 top-level tabs — `enum AdministrationPageTab`: `guards`, `sites`, `clients`, `system`.
- Constructor has 100+ parameters: telegram bridge config, identity policy, monitoring services, partner-endpoint counts, AI assistant settings, camera bridge, DVR auth.
- Roles referenced in onboarding flows: `guard`, `reaction_officer`, `controller`, `staff`.
- Dialog widgets: `_ClientOnboardingDialog`, `_SiteOnboardingDialog`, `_EmployeeOnboardingDialog`, `_ClientMessagingBridgeDialog`.

---

## 3. Application Services — `lib/application/*.dart`

Total: 150+ files. Grouped by domain; filenames are authoritative.

### 3.1 Admin / directory
- `admin/admin_directory_service.dart` — lists `clients`, `sites`, `employees`, `employee_site_assignments`, `client_messaging_endpoints`, `client_contacts`.
- `admin_write_follow_up_policy.dart`

### 3.2 Agent brain / camera bridge
- `onyx_agent_camera_bridge_health_service.dart`
- `onyx_agent_camera_bridge_receiver.dart`
- `onyx_agent_camera_bridge_server_contract.dart`, `_io.dart`, `_stub.dart`, `_server.dart`
- `onyx_agent_camera_change_service.dart`
- `onyx_agent_camera_probe_service.dart`
- `onyx_agent_client_draft_service.dart`
- `onyx_agent_cloud_boost_service.dart`
- `onyx_agent_context_snapshot_service.dart`
- `onyx_agent_local_brain_service.dart`
- `onyx_agent_tcp_probe_io.dart`, `_stub.dart`

### 3.3 Alarm / listener pipeline
- `alarm_account_registry.dart` — tables `alarm_accounts`, `onyx_settings`.
- `alarm_triage_gateway.dart`
- `listener_alarm_advisory_pipeline_service.dart`
- `listener_alarm_advisory_resolution_service.dart`
- `listener_alarm_feed_service.dart`
- `listener_alarm_partner_advisory_service.dart`
- `listener_alarm_scope_mapping_service.dart`
- `listener_alarm_scope_registry_repository.dart`
- `listener_parity_service.dart`
- `listener_serial_ingestor.dart`

### 3.4 App state
- `app_state.dart`

### 3.5 Browser / web links
- `browser_link_service.dart`, `_stub.dart`, `_web.dart`

### 3.6 CCTV / camera
- `cctv_bridge_service.dart`
- `cctv_evidence_probe_service.dart`
- `cctv_false_positive_policy.dart`

### 3.7 Chat / casefile history
- `chat_casefile_history_text_formatter.dart`

### 3.8 Client comms
- `client_backend_probe_coordinator.dart`
- `client_camera_health_fact_packet_service.dart`
- `client_comms_delivery_policy_service.dart`
- `client_conversation_repository.dart` — tables `client_conversation_messages`, `client_conversation_acknowledgements`, `client_conversation_push_queue`, `client_conversation_push_sync_state`.
- `client_delivery_message_formatter.dart`
- `client_messaging_bridge_repository.dart` — tables `client_contact_endpoint_subscriptions`, `client_contacts`, `client_messaging_endpoints`, `sites`.
- `client_push_delivery_freshness.dart`

### 3.9 Dispatch
- `dispatch_application_service.dart`
- `dispatch_benchmark_presenter.dart`
- `dispatch_clipboard_service.dart`
- `dispatch_models.dart`
- `dispatch_persistence_service.dart`
- `dispatch_snapshot_file_service.dart`, `_stub.dart`, `_web.dart`

### 3.10 DVR / local proxy
- `dvr_bridge_service.dart`
- `dvr_evidence_probe_service.dart`
- `dvr_http_auth.dart`
- `dvr_ingest_contract.dart`
- `dvr_scope_config.dart`
- `local_hikvision_dvr_proxy_runtime_config.dart`
- `local_hikvision_dvr_proxy_service.dart`

### 3.11 Email
- `email_bridge_service.dart`, `_stub.dart`, `_web.dart`

### 3.12 Evidence / export
- `evidence_certificate_export_service.dart`
- `export_coordinator.dart`

### 3.13 Guard telemetry / ops / performance / sync
- `guard_media_capture_service.dart`
- `guard_ops_repository.dart` — tables `guard_ops_events`, `guard_ops_media`.
- `guard_performance_service.dart`
- `guard_sync_repository.dart` — tables `guard_assignments`, `guard_sync_operations`.
- `guard_telemetry_bridge_writer.dart`
- `guard_telemetry_ingestion_adapter.dart`
- `guard_telemetry_replay_fixture_service.dart`

### 3.14 Hazard / intake
- `hazard_response_directive_service.dart`
- `intake_stress_service.dart`

### 3.15 Hik-Connect (Hikvision cloud) — 26 files
`hik_connect_alarm_batch.dart`, `_alarm_payload_loader.dart`, `_alarm_smoke_service.dart`, `_bootstrap_orchestrator_service.dart`, `_bootstrap_packet_service.dart`, `_bootstrap_runtime_config.dart`, `_bundle_sanitizer.dart`, `_bundle_status_service.dart`, `_camera_bootstrap_service.dart`, `_camera_catalog.dart`, `_camera_payload_loader.dart`, `_camera_resolver.dart`, `_env_seed_formatter.dart`, `_openapi_client.dart`, `_openapi_config.dart`, `_payload_bundle_collector_service.dart`, `_payload_bundle_locator.dart`, `_payload_bundle_template_service.dart`, `_preflight_bundle_health_service.dart`, `_preflight_manifest_status_service.dart`, `_preflight_next_step_service.dart`, `_preflight_payload_inventory_service.dart`, `_preflight_report_service.dart`, `_preflight_runner_service.dart`, `_scope_seed_formatter.dart`, `_video_payload_loader.dart`, `_video_session.dart`, `_video_smoke_service.dart`.

### 3.16 Intelligence / MO ontology
- `intelligence_event_object_semantics.dart`
- `mo_extraction_service.dart`
- `mo_feedback_learning_service.dart`
- `mo_knowledge_repository.dart`
- `mo_ontology_service.dart`
- `mo_promotion_application_service.dart`
- `mo_promotion_decision_store.dart`
- `mo_runtime_matching_service.dart`
- `shadow_mo_dossier_contract.dart`
- `shadow_mo_validation_summary.dart`
- `synthetic_promotion_summary_formatter.dart`

### 3.17 Monitoring / YOLO / watch
- `monitoring_global_posture_service.dart`
- `monitoring_identity_policy_service.dart`
- `monitoring_orchestrator_service.dart`
- `monitoring_scene_review_store.dart`
- `monitoring_shift_notification_service.dart`
- `monitoring_shift_schedule_service.dart`
- `monitoring_shift_scope_config.dart`
- `monitoring_site_narrative_service.dart`
- `monitoring_synthetic_war_room_service.dart`
- `monitoring_temporary_identity_approval_service.dart`
- `monitoring_watch_action_plan.dart`
- `monitoring_watch_autonomy_service.dart`
- `monitoring_watch_availability_service.dart`
- `monitoring_watch_client_notification_gate_service.dart`
- `monitoring_watch_continuous_visual_service.dart`
- `monitoring_watch_escalation_policy_service.dart`
- `monitoring_watch_outcome_cue_store.dart`
- `monitoring_watch_recovery_policy.dart`
- `monitoring_watch_recovery_scope_resolver.dart`
- `monitoring_watch_recovery_store.dart`
- `monitoring_watch_resync_outcome_recorder.dart`
- `monitoring_watch_resync_plan_service.dart`
- `monitoring_watch_runtime_store.dart`
- `monitoring_watch_scene_assessment_service.dart`
- `monitoring_watch_schedule_sync_plan_service.dart`
- `monitoring_watch_vision_review_service.dart`
- `monitoring_yolo_detection_service.dart`
- `monitoring_yolo_detector_health_service.dart`
- `monitoring_yolo_semantic_probe_scheduler.dart`

### 3.18 Morning sovereign report / news
- `morning_sovereign_report_service.dart`
- `news_source_diagnostic.dart`

### 3.19 Offline / awareness latency / power mode
- `offline_incident_spool_service.dart`
- `onyx_awareness_latency_service.dart` — tables `onyx_awareness_latency`.
- `onyx_power_mode_service.dart` — tables `onyx_power_mode_events`.
- `onyx_environment_engine.dart`

### 3.20 Olarm (MQTT alarm panels)
- `olarm/onyx_olarm_bridge_service.dart`
- `olarm/onyx_olarm_device.dart`
- `olarm/onyx_olarm_exceptions.dart`
- `olarm/onyx_olarm_mqtt_client_factory.dart`, `_io.dart`, `_web.dart`
- `olarm/onyx_olarm_service.dart`

### 3.21 ONVIF cameras
- `onvif/onyx_onvif_bridge_service.dart`
- `onvif/onyx_onvif_device.dart`
- `onvif/onyx_onvif_exceptions.dart`

### 3.22 ONYX core services
- `onyx_alert_reason_builder.dart`
- `onyx_behaviour_monitor_service.dart` — classes `InactivityAlert`, `TillAlert`.
- `onyx_claude_report_config.dart`
- `onyx_client_trust_service.dart` — tables `onyx_client_trust_snapshots`, `incidents`, `onyx_alert_outcomes`, `patrol_compliance`, `patrol_checkpoint_scans`, `site_awareness_snapshots`, `onyx_awareness_latency`, `onyx_evidence_certificates`.
- `onyx_command_brain_orchestrator.dart`
- `onyx_command_parser.dart`
- `onyx_command_specialist_assessment_service.dart`
- `onyx_elevenlabs_service.dart` — ElevenLabs TTS.
- `onyx_evidence_certificate_service.dart` — tables `onyx_evidence_certificates`, `onyx_event_store`, `incidents`.
- `onyx_fr_service.dart` — face recognition.
- `onyx_lpr_service.dart` — licence plate recognition.
- `onyx_operator_discipline_service.dart` — tables `incidents`, `onyx_operator_simulations`, `onyx_operator_scores`.
- `onyx_operator_orchestrator.dart`
- `onyx_outcome_feedback_service.dart` — tables `onyx_alert_outcomes`.
- `onyx_patrol_monitor_service.dart` — class `OnyxMissedPatrolAlert`.
- `onyx_proactive_alert_service.dart` — enums `OnyxAlertSensitivity(allMotion, suspiciousOnly, off)`, `OnyxProactiveDetectionKind(human, vehicle)`, `OnyxTelegramAlertKind(perimeterBreach, unknownVehicleAtGate, loitering, generalMovement)`; model `SiteAlertConfig`.
- `onyx_scope_guard.dart`
- `onyx_site_profile_service.dart` — `enum AlertLevel(info, warning, critical)`.
- `onyx_site_provisioning_service.dart` — tables `clients`, `sites`, `site_awareness_snapshots`, `site_shift_schedules`.
- `onyx_telegram_command_gateway.dart`
- `onyx_telegram_operational_command_service.dart`
- `onyx_tool_bridge.dart`

### 3.23 OpenAI
- `openai_runtime_config.dart`

### 3.24 Ops integration / runtime
- `ops_integration_profile.dart`
- `oversight_focus_formatter.dart`
- `readiness_summary_formatter.dart`
- `review_shortcut_contract.dart`
- `runtime_config.dart`

### 3.25 Radio / VoIP / wearable
- `radio_bridge_service.dart`
- `voip_call_service.dart`
- `wearable_bridge_service.dart`

### 3.26 Reports
- `report_entry_context.dart`
- `report_generation_service.dart`
- `report_output_mode.dart`
- `report_partner_comparison_window.dart`
- `report_preview_request.dart`
- `report_preview_surface.dart`
- `report_receipt_export_payload.dart`
- `report_receipt_history_copy.dart`
- `report_receipt_history_lookup.dart`
- `report_receipt_history_presenter.dart`
- `report_receipt_scene_filter.dart`
- `report_receipt_scene_review_presenter.dart`
- `report_scene_review_snapshot_builder.dart`
- `report_shell_binding.dart`
- `report_shell_state.dart`
- `reports_workspace_agent.dart`

### 3.27 Simulation
- `simulation/scenario_definition.dart`
- `simulation/scenario_fixture_loader.dart`
- `simulation/scenario_replay_history_signal_service.dart`
- `simulation/scenario_result.dart`
- `simulation/scenario_runner.dart`

### 3.28 Site awareness
- `site_activity_intelligence_service.dart`
- `site_activity_telegram_formatter.dart`
- `site_awareness/onyx_hik_isapi_stream_awareness_service.dart`
- `site_awareness/onyx_live_snapshot_yolo_service.dart`
- `site_awareness/onyx_site_awareness_repository.dart` — tables `site_awareness_snapshots`, `site_occupancy_config`, `site_camera_zones`, `site_alert_config`, `site_intelligence_profiles`, `site_zone_rules`, `site_expected_visitors`, `site_vehicle_registry`, `fr_person_registry`, `site_occupancy_sessions`, `site_vehicle_presence`, `site_alarm_events`.
- `site_awareness/onyx_site_awareness_service.dart`
- `site_awareness/onyx_site_awareness_snapshot.dart` — class `OnyxSiteAlert`.
- `site_identity_registry_repository.dart` — tables `site_identity_profiles`, `site_identity_approval_decisions`, `telegram_identity_intake`.
- `models/site_performance_summary.dart`

### 3.29 SMS
- `sms_delivery_service.dart`

### 3.30 Telegram (21 files)
- `telegram_admin_command_formatter.dart`
- `telegram_ai_assistant_camera_health.dart`
- `telegram_ai_assistant_clarifiers.dart`
- `telegram_ai_assistant_service.dart`
- `telegram_ai_assistant_site_view.dart`
- `telegram_ai_starter_examples.dart`
- `telegram_bridge_delivery_memory.dart`
- `telegram_bridge_resolver.dart`
- `telegram_bridge_service.dart`
- `telegram_client_approval_service.dart`
- `telegram_client_prompt_signals.dart`
- `telegram_client_quick_action_audit_formatter.dart`
- `telegram_client_quick_action_service.dart`
- `telegram_client_router_policy.dart`
- `telegram_command_router.dart` — `enum OnyxTelegramCommandType`.
- `telegram_endpoint_scope_resolution.dart`
- `telegram_high_risk_classifier.dart`
- `telegram_identity_intake_service.dart`
- `telegram_partner_dispatch_service.dart`
- `telegram_poll_tab_lock.dart`, `_stub.dart`, `_web.dart`
- `telegram_push_coordinator.dart`
- `telegram/telegram_push_sync_coordinator.dart`

### 3.31 Text share / vehicle / video fleet
- `text_share_service.dart`, `_stub.dart`, `_web.dart`
- `vehicle_throughput_summary_formatter.dart`
- `vehicle_visit_ledger_projector.dart`
- `video_bridge_health_formatter.dart`
- `video_bridge_runtime.dart`
- `video_edge_ingest_contract.dart`
- `video_fleet_scope_activity_projector.dart`
- `video_fleet_scope_health_projector.dart`
- `video_fleet_scope_presentation_service.dart`
- `video_fleet_scope_runtime_state_resolver.dart`
- `video_fleet_scope_runtime_state.dart`
- `video_fleet_scope_summary_formatter.dart`

---

## 4. Supabase Tables

Grep of all `.from('...')` references across `lib/`.

| Table | Operations | Referencing files |
|---|---|---|
| `client_evidence_ledger` | SELECT, INSERT | `lib/infrastructure/events/supabase_client_ledger_repository.dart` |
| `site_alarm_events` | SELECT, INSERT | `lib/main.dart` (×2), `lib/application/site_awareness/onyx_site_awareness_repository.dart` |
| `sites` | SELECT, UPSERT | `lib/main.dart`, `lib/ui/admin_page.dart` (×3), `lib/application/onyx_site_provisioning_service.dart`, `lib/application/admin/admin_directory_service.dart`, `lib/application/client_messaging_bridge_repository.dart` |
| `dispatches` | INSERT | `lib/main.dart` |
| `events` | SELECT, INSERT/UPSERT | `lib/main.dart` (×2) |
| `site_awareness_snapshots` | SELECT, UPSERT | `lib/main.dart` (×5), `lib/application/onyx_site_provisioning_service.dart`, `lib/application/site_awareness/onyx_site_awareness_repository.dart`, `lib/application/onyx_client_trust_service.dart` |
| `client_messaging_endpoints` | SELECT, UPSERT | `lib/main.dart` (×3), `lib/application/admin/admin_directory_service.dart`, `lib/application/client_messaging_bridge_repository.dart` (×9) |
| `clients` | SELECT, UPSERT | `lib/main.dart`, `lib/ui/admin_page.dart` (×2), `lib/application/onyx_site_provisioning_service.dart`, `lib/application/admin/admin_directory_service.dart` |
| `site_occupancy_config` | SELECT | `lib/main.dart`, `lib/application/site_awareness/onyx_site_awareness_repository.dart` |
| `site_intelligence_profiles` | SELECT | `lib/main.dart`, `lib/application/site_awareness/onyx_site_awareness_repository.dart` |
| `site_zone_rules` | SELECT | `lib/main.dart`, `lib/application/site_awareness/onyx_site_awareness_repository.dart` |
| `site_expected_visitors` | SELECT, INSERT, DELETE | `lib/main.dart` (×4), `lib/application/site_awareness/onyx_site_awareness_repository.dart` |
| `fr_person_registry` | SELECT | `lib/main.dart`, `lib/application/site_awareness/onyx_site_awareness_repository.dart` |
| `site_occupancy_sessions` | SELECT, UPSERT | `lib/main.dart`, `lib/application/site_awareness/onyx_site_awareness_repository.dart` |
| `incidents` | SELECT, UPSERT | `lib/main.dart`, `lib/ui/admin_page.dart`, `lib/application/onyx_operator_discipline_service.dart` (×4), `lib/application/onyx_evidence_certificate_service.dart`, `lib/application/onyx_client_trust_service.dart` |
| `site_vehicle_registry` | SELECT | `lib/main.dart`, `lib/application/site_awareness/onyx_site_awareness_repository.dart` |
| `site_vehicle_presence` | SELECT, INSERT | `lib/main.dart` (×2), `lib/application/site_awareness/onyx_site_awareness_repository.dart` |
| `vehicle_visits` | UPSERT, SELECT | `lib/main.dart`, `lib/infrastructure/bi/vehicle_visit_repository.dart` (×2) |
| `hourly_throughput` | UPSERT | `lib/infrastructure/bi/vehicle_visit_repository.dart` |
| `guard_assignments` | SELECT, UPSERT | `lib/main.dart`, `lib/application/guard_sync_repository.dart` (×3) |
| `patrol_checkpoints` | SELECT | `lib/main.dart` |
| `patrol_checkpoint_scans` | SELECT | `lib/main.dart`, `lib/application/onyx_client_trust_service.dart` |
| `patrol_compliance` | SELECT | `lib/main.dart`, `lib/application/onyx_client_trust_service.dart` |
| `onyx_event_store` | UPSERT, SELECT | `lib/domain/store/in_memory_event_store.dart` (×2), `lib/application/onyx_evidence_certificate_service.dart` |
| `site_camera_zones` | SELECT | `lib/application/site_awareness/onyx_site_awareness_repository.dart` |
| `site_alert_config` | SELECT | `lib/application/site_awareness/onyx_site_awareness_repository.dart` |
| `employees` | SELECT, UPSERT | `lib/ui/admin_page.dart` (×3), `lib/application/admin/admin_directory_service.dart` |
| `vehicles` | UPSERT | `lib/ui/admin_page.dart` |
| `employee_site_assignments` | UPSERT | `lib/ui/admin_page.dart`, `lib/application/admin/admin_directory_service.dart` |
| `site_identity_profiles` | SELECT, UPSERT, INSERT | `lib/application/site_identity_registry_repository.dart` (×4) |
| `site_identity_approval_decisions` | SELECT | `lib/application/site_identity_registry_repository.dart` |
| `telegram_identity_intake` | INSERT, SELECT | `lib/application/site_identity_registry_repository.dart` (×3) |
| `client_contact_endpoint_subscriptions` | UPSERT, SELECT, DELETE | `lib/application/client_messaging_bridge_repository.dart` (×5) |
| `client_contacts` | SELECT, UPSERT, DELETE | `lib/application/client_messaging_bridge_repository.dart` (×7) |
| `onyx_awareness_latency` | UPSERT, SELECT | `lib/application/onyx_awareness_latency_service.dart` (×2), `lib/application/onyx_client_trust_service.dart` |
| `onyx_operator_simulations` | SELECT, UPSERT | `lib/application/onyx_operator_discipline_service.dart` (×7) |
| `onyx_operator_scores` | SELECT, UPSERT | `lib/application/onyx_operator_discipline_service.dart` (×2) |
| `client_conversation_messages` | SELECT, INSERT, UPDATE | `lib/application/client_conversation_repository.dart` (×4) |
| `client_conversation_acknowledgements` | SELECT, INSERT | `lib/application/client_conversation_repository.dart` (×4) |
| `client_conversation_push_queue` | SELECT, UPSERT, UPDATE | `lib/application/client_conversation_repository.dart` (×6) |
| `client_conversation_push_sync_state` | SELECT, UPSERT | `lib/application/client_conversation_repository.dart` (×2) |
| `onyx_evidence_certificates` | SELECT, UPSERT | `lib/application/onyx_evidence_certificate_service.dart` (×4), `lib/application/onyx_client_trust_service.dart` |
| `onyx_alert_outcomes` | UPSERT, SELECT | `lib/application/onyx_outcome_feedback_service.dart` (×2), `lib/application/onyx_client_trust_service.dart` |
| `onyx_client_trust_snapshots` | SELECT | `lib/application/onyx_client_trust_service.dart` |
| `site_shift_schedules` | UPSERT | `lib/application/onyx_site_provisioning_service.dart` |
| `alarm_accounts` | SELECT | `lib/application/alarm_account_registry.dart` |
| `onyx_settings` | SELECT | `lib/application/alarm_account_registry.dart` |
| `onyx_power_mode_events` | INSERT, SELECT | `lib/application/onyx_power_mode_service.dart` (×3), `lib/application/onyx_environment_engine.dart` |
| `guard_sync_operations` | SELECT, UPSERT | `lib/application/guard_sync_repository.dart` (×6) |
| `guard_ops_events` | SELECT | `lib/application/guard_ops_repository.dart` |
| `guard_ops_media` | SELECT | `lib/application/guard_ops_repository.dart` |

---

## 5. Telegram Integration

### 5.1 Command types — `/Users/zaks/omnix_dashboard/lib/application/telegram_command_router.dart`

`enum OnyxTelegramCommandType`:
1. `liveStatus`
2. `gateAccess`
3. `incident`
4. `dispatch`
5. `guard`
6. `report`
7. `camera`
8. `intelligence`
9. `actionRequest`
10. `visitorRegistration`
11. `frOnboarding`
12. `clientStatement`
13. `unknown`

### 5.2 Trigger-phrase sets (natural language classifier)

- **liveStatus**: status, "what's happening", "whats happening", "any activity", "everything okay", "all good", "whats on site", "what's on site", "how many people", "how many", count, "people on site", "anyone on site", "who is on site", occupancy, "how many residents", "anyone home", "anyone there", "who is home", "whos home", "which cars are home", "which car is home".
- **gateAccess**: gate, door, locked, closed, open, access, entry.
- **incident**: incident, "what happened", "last night", today, yesterday, … (continues in file).
- Additional trigger sets (defined in file, names seen in grep): `dispatchTriggers`, `guardTriggers`, `reportTriggers`, `cameraTriggers`, `intelligenceTriggers`, `actionRequestTriggers`, `visitorRegistrationTriggers`, `frOnboardingTriggers`, `identityPhrases`, `statementPrefixes`.

### 5.3 Role policy — `/Users/zaks/omnix_dashboard/lib/domain/authority/telegram_role_policy.dart`

| Role | Allowed actions |
|---|---|
| `guard` | `read`, `propose` |
| `client` | `read`, `propose` |
| `supervisor` | `read`, `propose`, `stage` |
| `admin` | `read`, `propose`, `stage`, `execute` |

### 5.4 Main-file proactive-alert kinds
`lib/main.dart:41551` — `enum _TelegramProactiveAlertKind` (values defined inline; push composer selects one per fire).

### 5.5 Telegram services

See section 3.30 for the 21 telegram service files. Key orchestration files:
- `telegram_command_router.dart` — classifies message → command.
- `onyx_telegram_command_gateway.dart` — enforces role policy.
- `onyx_telegram_operational_command_service.dart` — applies the classified command to live ops.
- `telegram_ai_assistant_service.dart` — long-form AI replies.
- `telegram_client_quick_action_service.dart` — client-side quick-action buttons.
- `telegram_identity_intake_service.dart` — onboarding flow tied to `telegram_identity_intake` table.
- `telegram_partner_dispatch_service.dart` — partner-dispatch handoffs.
- `telegram_push_coordinator.dart` / `telegram/telegram_push_sync_coordinator.dart` — outbound push queue.

---

## 6. External Integrations

### 6.1 Supabase
- Client: `Supabase.instance.client` throughout. Tables listed in section 4.
- Realtime: `in_memory_event_store.dart` subscribes to `onyx_event_store` + batches upserts.
- Storage: referenced by evidence export flows (see `evidence_certificate_export_service.dart`).

### 6.2 Hikvision — NVR/DVR & Hik-Connect
- ISAPI streams — `lib/application/site_awareness/onyx_hik_isapi_stream_awareness_service.dart`.
- Hik-Connect OpenAPI client — `hik_connect_openapi_client.dart` + `hik_connect_openapi_config.dart`.
- Local DVR proxy — `local_hikvision_dvr_proxy_service.dart`.
- 26-file Hik-Connect bootstrap + preflight suite (section 3.15).
- DVR HTTP auth — `dvr_http_auth.dart`; ingest contract — `dvr_ingest_contract.dart`; scope config — `dvr_scope_config.dart`.

### 6.3 YOLO (object detection)
- `monitoring_yolo_detection_service.dart`
- `monitoring_yolo_detector_health_service.dart`
- `monitoring_yolo_semantic_probe_scheduler.dart`
- `site_awareness/onyx_live_snapshot_yolo_service.dart`

### 6.4 LPR / Plate Recognition
- `onyx_lpr_service.dart`

### 6.5 Face Recognition
- `onyx_fr_service.dart`
- Table: `fr_person_registry`.

### 6.6 OpenAI
- `openai_runtime_config.dart`
- Consumed by Agent brain + `onyx_agent_cloud_boost_service.dart`.

### 6.7 ElevenLabs
- `onyx_elevenlabs_service.dart` (TTS voices for client comms / agent speech).

### 6.8 Telegram Bot API
- `telegram_bridge_service.dart` + 20 ancillary services (section 3.30).

### 6.9 Olarm (MQTT alarm panels)
- 7 files under `lib/application/olarm/` (section 3.20).
- MQTT factory per-platform: IO + Web variants.

### 6.10 ONVIF cameras
- 3 files under `lib/application/onvif/` (section 3.21).

### 6.11 SIA DC-09 / Contact-ID alarm protocols
- `lib/domain/alarms/contact_id_event.dart` — `enum SiaParseFailureReason`, `enum ContactIdQualifier {newEvent, restore, status}`, `class ContactIdEvent`.
- `lib/domain/alarms/contact_id_event_mapper.dart` — `class ContactIdEventMapper`.
- `lib/application/listener_serial_ingestor.dart`, `listener_parity_service.dart`, `listener_alarm_feed_service.dart`.

### 6.12 VoIP / Radio / Wearable bridges
- `voip_call_service.dart`
- `radio_bridge_service.dart`
- `wearable_bridge_service.dart`

### 6.13 SMS / Email
- `sms_delivery_service.dart`
- `email_bridge_service.dart` (+ IO/Web variants)

### 6.14 Maps
- `flutter_map` (OpenStreetMap tiles) consumed in `tactical_page.dart`.

---

## 7. Alert and Event Types

### 7.1 Incident domain — `lib/domain/incidents/incident_enums.dart`

- `enum IncidentType` (12): `intrusion, loitering, perimeterBreach, accessViolation, alarmTrigger, panicAlert, suspiciousActivity, guardMisconduct, equipmentFailure, systemAnomaly, civicRisk, other`.
- `enum IncidentSeverity` (4): `low, medium, high, critical`.
- `enum IncidentStatus` (6): `detected, classified, dispatchLinked, resolved, closed, escalated`.

### 7.2 Dispatch event sourcing — `lib/domain/events/*.dart`

`abstract class DispatchEvent` (in `dispatch_event.dart`) — concrete subclasses (17):

1. `DecisionCreated` — `decision_created.dart`
2. `DispatchDecidedEvent` — `dispatch_decided_event.dart`
3. `ExecutionCompleted` — `execution_completed.dart`
4. `ExecutionCompletedEvent` — `execution_completed_event.dart`
5. `ExecutionDenied` — `execution_denied.dart`
6. `GuardCheckedIn` — `guard_checked_in.dart`
7. `IncidentClosed` — `incident_closed.dart`
8. `IntelligenceReceived` — `intelligence_received.dart`
9. `ListenerAlarmAdvisoryRecorded` — `listener_alarm_advisory_recorded.dart`
10. `ListenerAlarmFeedCycleRecorded` — `listener_alarm_feed_cycle_recorded.dart`
11. `ListenerAlarmParityCycleRecorded` — `listener_alarm_parity_cycle_recorded.dart`
12. `PartnerDispatchStatusDeclared` — `partner_dispatch_status_declared.dart`
13. `PatrolCompleted` — `patrol_completed.dart`
14. `ReportGenerated` — `report_generated.dart`
15. `ResponseArrived` — `response_arrived.dart`
16. `VehicleVisitReviewRecorded` — `vehicle_visit_review_recorded.dart`
17. (seed) `_SeededDispatchEvent` — `lib/ui/events_review_page.dart:73`.

### 7.3 Guard ops events — `lib/domain/guard/guard_ops_event.dart`

- `enum GuardOpsEventType` — 20 values.
- `enum GuardMediaUploadStatus`: `queued, uploaded, failed`.
- `enum GuardVisualNormMode`: `day, night, ir`.
- Classes: `GuardOpsEvent`, `GuardOpsMediaUpload`.

### 7.4 Contact-ID alarm events — `lib/domain/alarms/contact_id_event.dart`

- `enum SiaParseFailureReason`.
- `enum ContactIdQualifier`: `newEvent, restore, status`.
- `class ContactIdEvent`.

### 7.5 Other domain events / logs

- `lib/domain/incidents/incident_event.dart` — `class IncidentEvent`.
- `lib/domain/crm/crm_event.dart` — `class CRMEvent`.
- `lib/domain/logging/execution_event.dart` — `class ExecutionEvent`.

### 7.6 Alert-centric classes

- `lib/application/onyx_proactive_alert_service.dart`:
  - `enum OnyxAlertSensitivity`: `allMotion, suspiciousOnly, off`.
  - `enum OnyxProactiveDetectionKind`: `human, vehicle`.
  - `enum OnyxTelegramAlertKind`: `perimeterBreach, unknownVehicleAtGate, loitering, generalMovement`.
  - `class SiteAlertConfig` (perimeter / semi-perimeter / indoor sensitivity, loiter minutes, perimeter sequence alert, quiet-hours sensitivity, day sensitivity, vehicle-daytime threshold).
- `lib/application/onyx_patrol_monitor_service.dart:191` — `class OnyxMissedPatrolAlert`.
- `lib/application/site_awareness/onyx_site_awareness_snapshot.dart:214` — `class OnyxSiteAlert`.
- `lib/application/onyx_outcome_feedback_service.dart:3` — `enum OnyxAlertOutcome`.
- `lib/application/onyx_behaviour_monitor_service.dart`:
  - `class InactivityAlert` (line 5)
  - `class TillAlert` (line 19)
- `lib/application/onyx_site_profile_service.dart:6` — `enum AlertLevel`: `info, warning, critical`.
- `lib/main.dart:41551` — `enum _TelegramProactiveAlertKind`.

### 7.7 Severity palette (UI)

`OnyxSeverity` in `onyx_status_banner.dart`: `critical, warning, info, success`. Mapped to `OnyxDesignTokens.statusCritical/Warning/Info/Success` + `OnyxColorTokens.redSurface/amberSurface/cyanSurface/greenSurface` and `accentRed/accentAmber/accentSky/accentGreen` text colors.

---

## 8. User Roles

### 8.1 Authority model — `lib/domain/authority/onyx_authority_scope.dart`

- `enum OnyxAuthorityRole`: `guard, client, supervisor, admin` (4 values).
- `enum OnyxAuthorityAction`: `read, propose, stage, execute` (4 values).
- `class OnyxAuthorityScope`: `principalId`, `role`, `allowedClientIds: Set<String>`, `allowedSiteIds: Set<String>`, `allowedActions: Set<OnyxAuthorityAction>`, `sourceLabel`.
- Methods: `allowsAction(action)`, `allowsClient(clientId)`, `allowsSite(siteId)`.

### 8.2 Telegram role matrix — `lib/domain/authority/telegram_role_policy.dart`

(Per section 5.3.) Admin is the only role with `execute`; supervisor adds `stage`; guard and client are capped at `read + propose`.

### 8.3 Files performing role checks
`OnyxAuthorityRole` / `OnyxAuthorityAction` or role-string equality referenced in 11 files:
- `lib/ui/client_app_page.dart`
- `lib/ui/admin_page.dart`
- `lib/main.dart`
- `lib/application/onyx_telegram_operational_command_service.dart`
- `lib/application/onyx_telegram_command_gateway.dart`
- `lib/application/onyx_scope_guard.dart`
- `lib/application/client_messaging_bridge_repository.dart`
- `lib/application/admin/admin_directory_service.dart`
- `lib/domain/authority/onyx_authority_scope.dart`
- `lib/domain/authority/telegram_role_policy.dart`
- `lib/domain/authority/telegram_scope_binding.dart`

### 8.4 Controller-login roles — `main.dart:1793-1816`

`ControllerLoginAccount.roleLabel` values: `Admin`, `Supervisor`, `Controller`. Plus `accessLabel`: `Full Access`, `Reports`, `Operations`.

### 8.5 Admin-page onboarding role taxonomy
Strings used when creating new employees (`admin_page.dart` onboarding dialogs): `guard`, `reaction_officer`, `controller`, `staff`.

### 8.6 Guard-mobile operator roles
`lib/ui/guard_mobile_shell_page.dart:26` — `enum GuardMobileOperatorRole`: `guard, reaction, supervisor`.

### 8.7 Client-app viewer role
`lib/ui/client_app_page.dart` — `enum ClientAppViewerRole`.

### 8.8 Agent personas
`onyx_agent_page.dart` — `_AgentPersona.adminOnly: bool` filters personas by current operator.

---

## 9. Widget Inventory — `lib/ui/components/`

Directory `lib/ui/components/` currently contains **one** shared component. All other widgets live inline inside their page files.

### 9.1 `/Users/zaks/omnix_dashboard/lib/ui/components/onyx_status_banner.dart` (108 lines)

- `enum OnyxSeverity`: `critical, warning, info, success`.
- `class OnyxStatusBanner extends StatelessWidget`:
  - Props: `message: String`, `severity: OnyxSeverity`, `action: String?`.
  - Layout: full-width container, 16h × 10v padding, 3-px left accent border, severity-mapped background.
  - Contents: leading severity icon (16 px), message text (13 px, weight 500, line height 1.4), optional action label (12 px, weight 600, letter-spacing 0.3).
  - Severity → icon map:
    - `critical` → `Icons.error_outline`
    - `warning` → `Icons.warning_amber_outlined`
    - `info` → `Icons.info_outline`
    - `success` → `Icons.check_circle_outline`
  - Severity → palette map (via `OnyxDesignTokens` + `OnyxColorTokens`):
    - `critical` → accent `statusCritical`, bg `redSurface`, text `accentRed`.
    - `warning` → accent `statusWarning`, bg `amberSurface`, text `accentAmber`.
    - `info` → accent `statusInfo`, bg `cyanSurface`, text `accentSky`.
    - `success` → accent `statusSuccess`, bg `greenSurface`, text `accentGreen`.
- Private helper: `class _BannerColors(accent, background, text)`.

### 9.2 Inline page widgets (sample — not exhaustive)

The codebase otherwise inlines widgets inside each `*_page.dart`. Representative examples already enumerated:
- `risk_intelligence_page.dart`: `_IntelAuditReceipt`, `_IntelStatusStrip`, `_IntelPriorityPanel`, `_IntelAreaPanel`, `_IntelAreaCard`, `_IntelRecentPanel`, `_IntelItemCard`, `_IntelDialogFrame`, `_IntelDialogSection` (9 inline widgets).
- `ledger_page.dart`: `_LedgerTimelineRow`, `_LedgerReviewRow`.
- `events_review_page.dart`: 14 summary classes (partner / activity / shadow / readiness / synthetic / posture scope summaries + history points).
- `dashboard_page.dart`: `_DesktopDashboard`, `_CompactDashboard`.
- `admin_page.dart`: `_ClientOnboardingDialog`, `_SiteOnboardingDialog`, `_EmployeeOnboardingDialog`, `_ClientMessagingBridgeDialog`.

---

## Appendix: Design tokens referenced

`lib/ui/theme/onyx_design_tokens.dart` (referenced by the banner):
- `OnyxDesignTokens.statusCritical`, `statusWarning`, `statusInfo`, `statusSuccess`.
- `OnyxColorTokens.redSurface`, `amberSurface`, `cyanSurface`, `greenSurface`.
- `OnyxColorTokens.accentRed`, `accentAmber`, `accentSky`, `accentGreen`.

Shell badge colors (onyx_route.dart):
- `0xFFEF4444` — red (activeIncidents, tacticalSosAlerts).
- `0xFF22D3EE` — cyan (aiActions).
- `0xFF60A5FA` — blue (complianceIssues).

Dashboard threat-state palette:
- CRITICAL `0xFFFF6A6F`
- ELEVATED `0xFFFFB44D`
- STABLE `0xFF49D2FF`

VIP empty-state accent: `0xFF9D4BFF` (purple).

---

### Gaps still worth a follow-up pass (if you need deeper detail)

1. **Per-page button/action enumeration** for the large pages (dashboard, ai_queue, tactical, onyx_agent, dispatch, governance, live_operations, admin, sovereign_ledger, client_app, client_intelligence_reports, events_review, guard_mobile_shell) — only their enum/class surface is captured above, not every on-tap button.
2. **Telegram message templates / callback handlers** — the router's trigger sets are captured, but the outbound template strings live across the 21 telegram services and were not fully read.
3. **`lib/main.dart`** (42k+ lines) — only grep-sampled. It contains the GoRouter setup, the demo accounts, the route dispatcher, and dozens of Supabase initializers.
4. **Per-service descriptions** for the 150+ application services — listed by filename with purpose where inferrable; several would benefit from a one-line contract description pulled from their doc comments.

If you want any of these expanded, point me at the subset and I will drill in.