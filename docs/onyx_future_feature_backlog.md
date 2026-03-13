# ONYX Future Feature Backlog

This document captures future ONYX platform ideas that are intentionally saved
outside the active CCTV, DVR, and listener rollout checklists.

Use this as a prioritization backlog, not as a release signoff sheet.

Related planning doc:
[ONYX Platform Operating Model](/Users/zaks/omnix_dashboard/docs/onyx_platform_operating_model.md)

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
