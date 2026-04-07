# ONYX Backlog

## Planned Integration: ONYX Alarm Receiver

Status: research phase only

### Updated Architecture

1. Alarm panel
2. SIA DC-09 / panel-specific transport
3. ONYX virtual receiver / bridge
4. ONYX alarm trigger
5. Incident Triage Agent classifies
6. Escalation Agent responds
7. Synthetic guard / dispatch / client comms

### Phase 1 — Build First When Ready

SIA DC-09 Virtual Receiver

- Standard: `ANSI/SIA DC-09-2026`
- Transport: `TCP` primary, `UDP` backup
- Encryption: `AES-128`
- Port: configurable, default `5072`
- Covers: `Ajax`, `Honeywell`, `Jablotron`, `Resideo`, and any `DC-09`
  compatible panel

Files to create:

- `lib/infrastructure/alarm/sia_dc09_receiver_service.dart`
- `lib/infrastructure/alarm/sia_dc09_message_parser.dart`
- `lib/domain/alarms/contact_id_event_mapper.dart` (already exists)
- `lib/domain/alarms/sia_event.dart`

Decision rationale:

1. Open standard, no NDA needed
2. `AES-128` encryption supports PSIRA-aligned deployment expectations
3. Widest panel compatibility
4. One receiver can cover multiple panel brands

### Phase 2 — After Phase 1

Texecom Connect Bridge

- Protocol: `JSON over TCP`
- Port: `10001/10002`
- Covers: `Premier Elite` panels

### Phase 3 — Partnership Approach

Olarm Integration

- Action: contact `Olarm` directly
- Location: South African company, Johannesburg based
- Covers: `IDS X-Series` panels in the local market

### Phase 4 — Fallback

Contact ID Receiver

- Covers: legacy panels

### Research Notes

- Keep receiver transport isolated from domain event mapping.
- Preserve raw alarm payloads for audit and evidence workflows.
- Design for replay safety, buffering, ordered ingest, and reconnect recovery
  before any live panel integration starts.
- Prefer software-only receiver deployment where possible.

## Planned Product Layer: ONYX Business Intelligence (ONYX-BI)

Status: backlog only

### Overview

- Second product layer running on the same camera / YOLO infrastructure as
  security monitoring
- Zero marginal hardware cost per client

### Phase 1 — Analytics Foundation

Hold until core security platform is launch-ready.

- Vehicle / person counter per defined zone
- Dwell time tracking per zone
- Peak hour heatmaps
- Daily / weekly / monthly business reports

Files to create:

- `lib/application/bi/zone_traffic_counter_service.dart`
- `lib/application/bi/dwell_time_tracker_service.dart`
- `lib/domain/bi/zone_traffic_snapshot.dart`
- `lib/domain/bi/business_analytics_report.dart`

### Phase 2 — License Plate Recognition

- LPR module integration (`OpenALPR` or similar)
- Repeat customer detection
- Fleet vehicle identification

Files to create:

- `lib/infrastructure/lpr/lpr_service.dart`
- `lib/domain/bi/vehicle_identity.dart`

### Phase 3 — Custom Pattern Recognition

- Client-defined threat / behaviour patterns
- Pattern definition interface in ONYX UI
- Pattern match scoring engine
- MO-specific alerts per client

Files to create:

- `lib/domain/patterns/custom_pattern.dart`
- `lib/application/patterns/pattern_match_service.dart`
- `lib/ui/pattern_definition_page.dart`

### Phase 4 — BI Dashboard

- Business analytics screen in ONYX
- Per-client BI reports via Reports Workspace Agent
- Exportable CSV / PDF reports for clients

### Target Markets

- Carwashes
- Filling stations
- Retail stores
- Restaurants / takeaways
- Shopping centres
- Warehouses

### Commercial Note

- Pricing uplift target: `3-5x` security-only monthly fee
