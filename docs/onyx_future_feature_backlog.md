# ONYX Future Feature Backlog

This document captures future ONYX platform ideas that are intentionally saved
outside the active CCTV, DVR, and listener rollout checklists.

Use this as a prioritization backlog, not as a release signoff sheet.

Related planning doc:
[ONYX Platform Operating Model](/Users/zaks/omnix_dashboard/docs/onyx_platform_operating_model.md)

## Now / Next / Future Reminder

This section is the short memory aid for new ONYX work sessions.

### Now

- Make ONYX truth deterministic before making it sound smarter.
  - `motion` = background activity metadata
  - `video loss` = system health fact
  - `line crossing`, `intrusion`, `FR`, and `LPR` = tactical truth buckets

- Keep `WS-01` as the lead domino.
  - Harden HikVision and Hik-Connect ingest.
  - Keep proxy and bridge health visible and boringly reliable.
  - Stop false `camera offline`, false `no movement`, and false live escalation drift.

- Keep resident Telegram factual, natural, and client-safe.
  - Do not mention YOLO, ByteTrack, temporary bridge paths, or internal monitoring plumbing to clients.
  - Only push client Telegram updates automatically when the event is routed as a real threat.
  - Client wording should feel conversational, but the underlying state must stay deterministic.

- Keep ONYX "eyes" fused into one operational truth.
  - Current-frame checks, continuous visual watch, Hik/DVR signals, YOLO semantic detections, FR/LPR, and tracked dwell should all resolve into one live site state.
  - The LLM should phrase truth, not invent it.

- Keep tracked behavior scoring grounded in persistent identity.
  - `trackId` is the continuity anchor.
  - Dwell time and zone sensitivity change posture.
  - Gate/perimeter loitering should feel more serious than the same dwell in a public approach lane.

### Next

- Finish `WS-01 / M3`.
  - Resident and operator answers should read from stable packetized truth across HikVision and Hik-Connect.
  - Add more representative Hik-Connect samples for face, plate, boundary, and camera-fault event families where needed.

- Push `WS-02` and `WS-03`.
  - FR needs a real gallery, allowlist/watchlist workflow, and operator approval surfaces.
  - LPR needs reliable normalization, flagged/allowed plate policy, and dependable visit intelligence.

- Keep expanding behavior intelligence.
  - Use tracked identity, dwell, first-seen, and zone context to distinguish passing by, dwell alert, and staging/critical loitering.
  - Extend this into stronger multi-camera continuity and higher-confidence threat posture.

- Decide `WS-04` cleanly.
  - Choose whether ONYX voice is outbound-only or full inbound telephony with STT/transcripts before adding premium voice layers.

### Future

- Grow ONYX into a dual-stream platform: security intelligence plus business/operational intelligence.
  - Retail and carwash: throughput, conversion, and service dwell.
  - Forecourt and garage: staging signatures and coordinated behavior.
  - Care and daycare: fall detection, welfare alerts, and child-exit protection.

- Add future integrations only after core truth stays reliable.
  - ElevenLabs for voice deterrence and calls.
  - Google Maps for routing, ETA, and site relationship intelligence.
  - MediaPipe or equivalent pose/welfare analysis.

- Keep external multimodal model vendors as optional later-stage augmentation, not as the ONYX core loop.
  - ONYX should stay operationally strong on local detection, tracking, policy, and truth first.

## Integration Stack Snapshot (April 2026)

This section reflects the current application and integration stack based on the
repo as it exists now, not just the desired end-state checklist.

### Active Now

- Telegram
  - Resident and operator messaging are core ONYX surfaces.
  - Keep this as the primary client comms lane.

- OpenAI
  - Already used in the visual review and AI assistant stack.
  - Keep this as the main narrative and reasoning layer until a strong reason exists to split providers.

- Supabase
  - Already acts as the primary persistence, messaging bridge, and sync layer.
  - Treat this as foundational infrastructure, not an optional add-on.

- HikVision DVR / local proxy path
  - ONYX already has a live HikVision ingest and proxy path.
  - This should be treated as active, with ongoing hardening work rather than as an unstarted integration.

### Partial / In Progress

- STT / telephony
  - VoIP staging and phone fallback paths exist.
  - Inbound calling, transcription, and operator voice workflows still need a clear production decision.

- FSK
  - FSK references and payload fixtures already exist.
  - Normalize this into a clear provider/integration lane instead of leaving it as an admin-only reference.

- Facial recognition
  - Face-match hooks exist in the detector and policy stack.
  - This becomes operational only once the approved gallery and approval workflow are fully maintained.

- LPR
  - Plate capture, policy matching, and vehicle intelligence are already wired.
  - This should be treated as a hardening and operational quality effort, not as a blank-sheet feature.

### Not Started or Not Yet Committed

- ElevenLabs
  - Useful for voice warnings, outbound calls, or premium client voice lanes.
  - Not required for ONYX core truth, detection, or escalation logic.

- Google Maps
  - Valuable for ETA, responder routing, patrol geofencing, and site relationship views.
  - Important only once field response and dispatch routing need map-native intelligence.

- Amecor
  - No clear committed integration path is present yet.
  - Keep separate from FSK so the team does not treat them as one unresolved bucket.

- MediaPipe
  - Useful for pose, fall, fight, and welfare-style analysis.
  - Best added after the current detection, tracking, and dwell stack is trusted.

- LangChain / Semantic Kernel
  - Not recommended as a near-term dependency.
  - ONYX's current bottleneck is deterministic truth, routing, and operational policy, not missing orchestration middleware.

## Integration Roadmap

### Execution Cut (This Month / Next Month / Parked)

Use this section as the practical execution lens for the integration roadmap.

Recommended owner lanes:

- Edge / Vision Runtime
  - Primary surfaces:
    - `lib/application/local_hikvision_dvr_proxy_service.dart`
    - `lib/application/dvr_ingest_contract.dart`
    - `lib/application/cctv_bridge_service.dart`
    - `tool/monitoring_yolo_detector_service.py`

- Detection / Identity Intelligence
  - Primary surfaces:
    - `lib/application/monitoring_yolo_detection_service.dart`
    - `lib/application/monitoring_watch_scene_assessment_service.dart`
    - `lib/application/monitoring_identity_policy_service.dart`
    - `lib/application/site_activity_intelligence_service.dart`

- Client Comms / Voice
  - Primary surfaces:
    - `lib/application/telegram_ai_assistant_service.dart`
    - `lib/application/onyx_telegram_operational_command_service.dart`
    - `lib/application/voip_call_service.dart`
    - `lib/application/client_delivery_message_formatter.dart`

- Ops Integrations / Admin
  - Primary surfaces:
    - `lib/application/ops_integration_profile.dart`
    - `lib/ui/admin_page.dart`
    - `lib/application/client_messaging_bridge_repository.dart`
    - `lib/main.dart`

#### This Month

- HikVision ingest reliability and event truth
  - Owner lane: Edge / Vision Runtime
  - Definition of done:
    - DVR proxy health is visible and boringly reliable.
    - `motion`, `video loss`, `line crossing`, and plate-style events normalize consistently into ONYX event truth.
    - Resident and operator surfaces stop drifting into false `camera offline` or false movement claims because the ingest path is stable.

- FR operationalization
  - Owner lane: Detection / Identity Intelligence
  - Definition of done:
    - Approved gallery is populated and managed.
    - Face matches can be allowlisted, flagged, and temporarily approved without engineering edits.
    - Identity hits are visible in the operator review path and influence posture safely.

- LPR hardening
  - Owner lane: Detection / Identity Intelligence
  - Definition of done:
    - Plate reads normalize consistently.
    - Known/flagged plate policy works end to end.
    - Plate hits become dependable site and dispatch context instead of noisy auxiliary metadata.

- Telephony decision and production shape
  - Owner lane: Client Comms / Voice
  - Definition of done:
    - ONYX has a clear voice position:
      - outbound stage-and-call only, or
      - real inbound telephony with STT and transcript handling
    - Provider and operator workflow are chosen deliberately instead of staying half-wired.

- FSK normalization and Amecor scoping
  - Owner lane: Ops Integrations / Admin
  - Definition of done:
    - FSK and Amecor are separated into distinct integration stories.
    - Each has a defined purpose:
      - telemetry source
      - dispatch/response partner
      - admin directory
      - or not in scope

#### This Month Workstreams

- `WS-01` HikVision ingest reliability and event truth
  - Owner lane: Edge / Vision Runtime
  - Dependencies:
    - none; this should start first
  - Milestones:
    - `M1` Proxy and bridge health are visible in operator/admin surfaces with last-success, last-error, and scope-level status.
    - `M2` HikVision event normalization is clean for `motion`, `video loss`, `line crossing`, and plate-style events.
    - `M3` Resident and operator replies stop drifting because ingest truth is stable and packetized correctly.
  - Key files:
    - `lib/application/local_hikvision_dvr_proxy_service.dart`
    - `lib/application/dvr_ingest_contract.dart`
    - `lib/application/cctv_bridge_service.dart`
    - `lib/application/client_camera_health_fact_packet_service.dart`
    - `lib/main.dart`

- `WS-02` FR operationalization
  - Owner lane: Detection / Identity Intelligence
  - Dependencies:
    - `WS-01` should be stable enough that camera/event truth is trustworthy
  - Milestones:
    - `M1` Approved gallery structure and admin workflow are finalized.
    - `M2` Allowlisted, flagged, and temporarily approved face matches work end to end.
    - `M3` Face matches influence posture and operator review without bypassing policy controls.
  - Key files:
    - `tool/face_gallery/README.md`
    - `tool/monitoring_yolo_detector_service.py`
    - `lib/application/monitoring_yolo_detection_service.dart`
    - `lib/application/monitoring_identity_policy_service.dart`
    - `lib/ui/admin_page.dart`

- `WS-03` LPR hardening
  - Owner lane: Detection / Identity Intelligence
  - Dependencies:
    - can run in parallel with `WS-02`
    - benefits from `WS-01` normalized ingest
  - Milestones:
    - `M1` Plate capture and normalization are consistent across DVR and YOLO paths.
    - `M2` Flagged and allowed plate policy is controllable from admin/runtime config without code edits.
    - `M3` Plate hits become dependable inputs to site posture, dispatch, and vehicle visit history.
  - Key files:
    - `lib/application/monitoring_yolo_detection_service.dart`
    - `lib/application/cctv_bridge_service.dart`
    - `lib/application/vehicle_visit_ledger_projector.dart`
    - `lib/application/monitoring_identity_policy_service.dart`
    - `lib/ui/events_review_page.dart`

- `WS-04` Telephony decision and production shape
  - Owner lane: Client Comms / Voice
  - Dependencies:
    - no hard dependency on `WS-01`
    - should be decided before any ElevenLabs work begins
  - Milestones:
    - `M1` Decide the production posture:
      - outbound stage-and-call only, or
      - real inbound telephony with STT/transcripts
    - `M2` Align provider/runtime configuration with the chosen posture.
    - `M3` Ensure operator, client comms, and fallback messaging all reflect the same voice workflow.
  - Key files:
    - `lib/application/voip_call_service.dart`
    - `lib/application/client_comms_delivery_policy_service.dart`
    - `lib/application/client_delivery_message_formatter.dart`
    - `lib/ui/clients_page.dart`
    - `lib/ui/live_operations_page.dart`

- `WS-05` FSK normalization and Amecor scoping
  - Owner lane: Ops Integrations / Admin
  - Dependencies:
    - no hard dependency, but should finish before broader partner/dispatch integration work
  - Milestones:
    - `M1` Separate FSK and Amecor in docs, admin surfaces, and integration vocabulary.
    - `M2` Decide for each one whether it is:
      - telemetry ingest
      - response partner integration
      - admin directory reference
      - or not in scope
    - `M3` Remove ambiguous combined labeling from the operator/admin experience.
  - Key files:
    - `lib/application/ops_integration_profile.dart`
    - `lib/ui/admin_page.dart`
    - `assets/telemetry_payload_fixtures/fsk_hikvision_guardlink_sample.json`
    - `docs/onyx_future_feature_backlog.md`

#### Recommended Sequence

- Week 1
  - Start `WS-01`
  - Scope `WS-04`
  - Clarify `WS-05`

- Week 2
  - Finish `WS-01 M2`
  - Start `WS-02 M1`
  - Start `WS-03 M1`

- Week 3
  - Push `WS-02 M2`
  - Push `WS-03 M2`
  - Lock `WS-04 M1`

- Week 4
  - Close `WS-02 M3`
  - Close `WS-03 M3`
  - Close `WS-04 M2-M3`
  - Close `WS-05 M2-M3`

#### Next Month

- Google Maps / geo intelligence
  - Owner lane: Ops Integrations / Admin
  - Success shape:
    - responder ETA
    - site routing context
    - useful geospatial awareness in dispatch and response flows

- ElevenLabs or equivalent voice synthesis
  - Owner lane: Client Comms / Voice
  - Success shape:
    - approved voice briefings or voice actions with clear policy gates
    - no ungoverned autonomous audio output

- MediaPipe or dedicated pose / welfare analysis
  - Owner lane: Detection / Identity Intelligence
  - Success shape:
    - fall / fight / distress posture signals augment ONYX perception without muddying the current object + track stack

#### Parked

- LangChain / Semantic Kernel
  - Keep parked unless ONYX truly needs framework-level agent orchestration.
  - Current pain is still truth resolution, policy, and operational reliability, not middleware absence.

- Additional model vendors
  - Keep parked until ONYX local detection, tracking, posture, and identity layers are trusted in production.
  - Add vendors only when they solve a proven gap rather than creating stack sprawl.

### Build Now

- HikVision reliability and event normalization
  - Harden the ingest, proxy, and alert interpretation path until DVR truth is boringly reliable.
  - Make sure `motion`, `video loss`, `line crossing`, and other event classes are consistently normalized before they hit ONYX posture logic.

- FR operationalization
  - Populate and maintain the approved face gallery.
  - Ship a clean approval, allowlist, and flagged-identity workflow for controllers.
  - Treat this as controlled identity assurance, not as generic always-on surveillance.

- LPR hardening
  - Improve plate-read reliability, normalization, allowlists, and flagged-plate workflows.
  - Keep vehicle identity as first-class operational context in site and dispatch lanes.

- Telephony direction
  - Decide whether ONYX needs only outbound call staging, or true inbound voice + STT.
  - Avoid half-committing to a telephony lane without deciding the real control-room use case.

- FSK normalization and Amecor scoping
  - Split these into separate workstreams.
  - Define whether each one is a telemetry source, response partner integration, directory system, or dispatch lane.

### Build Next

- Google Maps / geo intelligence
  - Add route ETA, responder distance, and site geography once the dispatch and field-response lanes need it.
  - Keep it operational: map intelligence should improve response decisions, not just add a map widget.

- ElevenLabs or equivalent voice synthesis
  - Add this only if ONYX is ready for approved automated voice output, outbound client calls, or premium voice briefings.
  - Pair it with explicit policy gates and logging for every autonomous voice action.

- MediaPipe or dedicated pose/welfare analysis
  - Use this when ONYX is ready to score falls, fights, collapse, distress posture, or other body-state signals.
  - Keep this separate from the current object/tracking lane.

### Build Later

- LangChain / Semantic Kernel
  - Revisit only if ONYX genuinely needs multi-agent tool orchestration that the current services cannot express cleanly.
  - Do not add this while core truth resolution and operational routing are still being tuned.

- Additional model vendors
  - Only add new reasoning/model providers after ONYX has a stable local detection and state-fusion backbone.
  - Prefer stronger deterministic local capability over framework sprawl.

## Build Next

- Edge AI resilience and offline incident continuity
  - Keep all primary detection on the Sovereign Edge box.
  - Store incidents locally during WAN loss and sync them when connectivity returns.
  - Preserve local Blackview action-ladder continuity even when cloud links fail.

- LEO failover bridge
  - Detect fiber heartbeat failure and switch the edge to low-bandwidth metadata mode.
  - Send AI snapshots, GPS pings, and incident metadata over satellite instead of full video.
  - Treat this as a sovereignty and continuity layer, not a full-video backup lane.

- Evidence provenance and tamper-evident ledger
  - Hash video clips, snapshots, and serial signals at ingest time.
  - Record signed provenance metadata and export a certificate of integrity with evidence.
  - Position this as signed chain-of-custody and evidence provenance, not as an NFT feature.

- AI dispatcher and drafted SITREPs
  - Auto-trigger approved talk-down phrases through on-site IP speakers for approved alert classes.
  - Draft structured incident summaries from visual and telemetry context before the controller opens the alert.
  - Keep strict policy gates, cooldowns, and audit logging on every autonomous action.

- Flash-SITREP generation
  - Draft end-of-incident reports from detections, comms, transcripts, and telemetry.
  - Keep this in review-and-confirm mode for controllers rather than automatic final publication.
  - Every generated statement must remain traceable to source evidence.

- Tactical IoT tripwires
  - Add non-visual LoRaWAN sensors for dark perimeters and privacy-sensitive zones.
  - Prioritize fence vibration, gate tamper, tilt, and glass-break style signals.
  - Use the Sovereign Edge box as the local gateway so the tripwire lane survives load shedding and WAN loss.

- RF anti-jamming and SIGINT sniffing
  - Use a low-cost SDR on the Sovereign Edge box or responder vehicle to watch for Wi-Fi de-authentication, jammer noise, and suspicious RF spikes near protected sites.
  - Trigger pre-emptive technical-breach alerts before camera or telemetry lanes actually fail.
  - Treat this as an edge-resilience and breach-detection feature, not as broad-spectrum surveillance.

- Managed Edge-as-a-Service
  - Package ONYX Nodes as a managed resilience product instead of software-only deployment.
  - Keep local inference, local comms bridge, local speaker actions, and degraded-mode continuity on the node even when WAN links fail.
  - Position this as a physical guarantee of continuity for high-value sites.

## Build Later

- Behavioral anomaly detection
  - Add fight detection, fall detection, dwell anomalies, patrol-route deviation, and welfare triggers.
  - Keep these outputs in investigate and welfare lanes before promoting them into alarm automation.

- Pre-incident anomaly engine
  - Learn site rhythm across motion, lighting, and vehicle patterns.
  - Surface tiered investigate alerts when off-pattern behavior appears before a clear crime signal exists.
  - Gate this behind site-specific baselines and suppression controls to avoid alert fatigue.

- Acoustic detection worker
  - Add gunshot, glass-break, and distress-audio detection from camera audio channels.
  - Treat gunshot and glass-break as higher-confidence use cases than scream detection.
  - Keep audio inference as a separate worker from the video path.

- Cognitive denial and deception routines
  - Add controlled deterrence patterns such as alternate light activation, approved radio-chatter playback, or dog-bark simulation after a high-confidence breach.
  - Keep this behind explicit site policy, confidence gates, and audited action logs.
  - Treat it as a controlled deterrence layer, not an always-on autonomy feature.

- Agentic briefing and multi-agent collaboration
  - Move from single-model alert summarization into coordinated agents for visual, comms, logistics, and SOP checks.
  - Keep the first versions in briefing and recommendation lanes before allowing broader autonomous control.
  - Require evidence-linked reasoning and explicit source traceability for every briefing claim.

- Digital guard fleet management
  - Add responder vehicle OBD-II, siren, speed, impact, and GPS telemetry.
  - Support vehicle-specific live dashboards, collision detection, and officer-down escalation flows.

- Biometric proof-of-life patrols
  - Add liveness-verified patrol confirmation in the Blackview app through face or voice checks.
  - Position this as high-assurance patrol verification, not continuous biometric surveillance.
  - Treat privacy, consent, and storage controls as mandatory prerequisites.

- Strategic crime heat-mapping
  - Use temporal and spatial analysis across serial signals and AI detections to suggest high-risk routes and timing windows.
  - Keep the first version advisory for supervisors rather than fully autonomous patrol assignment.

- Digital twin tactical mapping
  - Add site-level 3D operational views and cross-camera subject continuity.
  - Defer until camera calibration, re-identification quality, and site-model upkeep are operationally defensible.

- Tactical AR overlays
  - Add waypoint-style AR guidance on Blackview devices for responder navigation to panic, intruder, or welfare events.
  - Defer until core field workflows and site-positioning accuracy are stable enough to avoid misleading responders.

- Drone-in-a-box first response
  - Add autonomous drone launch, spotlight, and thermal reconnaissance for high-confidence incidents.
  - Treat this as a premium future lane after edge autonomy, evidence integrity, and legal/airspace controls are mature.

- UEBA for guard and controller operations
  - Detect operational fatigue, missed checkpoints, and degraded response behavior from field and controller telemetry.
  - Keep the first versions supervisory and welfare-oriented, not punitive automation.

## Working Notes

- Core platform priorities remain:
  - sovereign edge resilience
  - forensic integrity
  - reliable field validation

- Product language should prefer:
  - evidence provenance
  - tamper-evident ledger
  - certificate of integrity
  - chain of custody
  and avoid hype-heavy terms such as NFT in external-facing positioning.

- Advanced prediction and immersive UX should follow only after:
  - CCTV and DVR live pilots are field-proven
  - listener hardware validation is complete
  - evidence integrity and degraded-mode operation are trusted in production
