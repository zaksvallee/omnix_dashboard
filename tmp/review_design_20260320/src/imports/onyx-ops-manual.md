🏛️ ONYX SOVEREIGN OPERATIONS MANUAL
SOM v4.3 — FULL SYSTEM BLUEPRINT
Status: DOCTRINE LOCKED Scope: AI-Driven Security Operations Platform Purpose: Human-Parallel Command System for Guarding & Response

SECTION 1 — THE SOVEREIGN DOCTRINE
1.1 Human-Parallel Execution
ONYX is built on a single governing principle:
The AI executes like a veteran controller. The human controller edits the truth.
The AI performs operational tasks in real time while the controller supervises and intervenes when required.
The system must never operate as a black box.
Every AI action must be:
• visible • explainable • interruptible • logged
Controllers must always see:
• what the AI just did • what the AI is doing now • what the AI intends to do next
ONYX therefore functions as a digital twin of an experienced control-room operator, not a background automation engine.

1.2 The 3-Second Rule
To preserve operational transparency, AI actions occur with a 2.5–3 second think-time delay.
This ensures:
• controllers can anticipate the next step • overrides can occur before automation proceeds • the system behaves like a disciplined human operator rather than an instant black box

1.3 The Sovereign Ledger
ONYX is built on an Immutable EventStore.
Every operational action becomes a cryptographically chained entry in the Sovereign Ledger.
This provides:
• legal-grade audit trails • forensic replay capability • client transparency • automated incident reports
Core Doctrine
If an action is not in the EventStore, it did not happen.

SECTION 2 — DATA ARCHITECTURE (THE SOVEREIGN SPINE)
The ONYX data model supports:
• operational execution • regulatory compliance (PSIRA / transport compliance) • evidentiary integrity

2.1 Employees — Registry of Force
All personnel exist in a unified employee registry.
Roles are distinguished through role fields rather than separate tables.
This allows centralized management of:
• dispatch eligibility • compliance status • operational hierarchy • device pairing

Core Identity Fields
• employee_id (UUID) • internal_employee_serial • full_name • surname • id_number / passport • date_of_birth

Compliance Fields
• psira_number • psira_grade • psira_expiry • license_code • driver_license_expiry • pdp_expiry • firearm_competency

Technical Identity
• device_uid • biometric_verification_hash • employment_status

2.1.1 Registry of Force — Readiness State Machine
Dispatch eligibility is governed by a state machine rather than a simple active flag.
Operational States
Off-Duty On-Shift (Available) On-Shift (Dispatched) On-Shift (Static Post) Suspended (Compliance Lock)

Dispatch Eligibility Logic
A reaction officer may only be selected if:
Employee_State = On-Shift (Available) AND Vehicle_Status = Ready AND PSIRA_expiry > Today AND Employment_Status = Active
If any condition fails, ONYX must block dispatch selection.

2.2 Clients & Sites
Clients
Legal contracting entities.
Fields:
• client_id • legal_name • client_type • billing_address • VAT number • sovereign_contact • contact_phone • contract_start_date
Client types:
• Guarding • Armed Response • Remote Watch • Hybrid

Sites
Physical deployment environments.
Fields:
• site_id • client_id • site_name • physical_address • GPS coordinates • entry_protocols • hardware_ids • risk_rating • SLA tier
Sites also store:
• patrol zones • checkpoints • geofences • site layout maps • baseline images (“The Norm”)

2.3 Vehicles — Response Assets
Vehicles are operational assets.
Fields:
• vehicle_callsign • license_plate • vehicle_type • maintenance_status • service_due_date • roadworthy_expiry • odometer_log
Vehicles failing readiness are hard-blocked from dispatch.

SECTION 3 — VISUAL BASELINE DOCTRINE (“THE NORM”)
Each site stores a visual reference model used for AI verification.
Baseline captures include:
• gates closed • perimeter fences intact • entry points secure • alarm hardware ready

3.1 Differential Vision Matrix
Each monitored zone stores:
• Day Norm • Night Norm • IR / Low-Light Norm
Combat Window Logic
After 22:00, ONYX prioritizes:
• Night Norm • IR baseline

Match Score Logic
95% → Secure 60–95% → Controller review <60% → Structural anomaly detected
Detected anomalies appear in the Verification Lens.

SECTION 4 — SYSTEM-WIDE ENVIRONMENT VARIABLES
ONYX adapts automatically to environmental conditions.

4.1 Load Shedding Intelligence
Load shedding acts as a global operational modifier.
Stage 4+ triggers:
• reduced guard inactivity thresholds • faster gateway heartbeats • battery-critical sites highlighted on map
Gateway heartbeat:
Normal → 10 minutes High risk → 2 minutes

4.2 Signal Storm Collapsing
Multiple signals are clustered into Incident Bundles.
Example:
15 power failures → 1 Grid Event Cluster
Clustering factors:
• geographic proximity • time window • signal type

4.3 Silent Duress Detection
During VoIP verification AI analyzes:
• voice stress • hesitation • background noise
If duress is suspected:
The Active Intelligence Lane pulses red.
Forced Dispatch Macro
The interface presents:
FORCED DISPATCH
Dispatch proceeds immediately.

SECTION 5 — THE SOVEREIGN INCIDENT BUNDLE
The Incident Bundle is the operational object that moves through the Action Ladder and becomes the ledger record.
Example structure:

{
  "incident_id": "INC-8829-QX",
  "event_uid": "uuid-v4-hash",
  "metadata": {
    "priority": "P1-CRITICAL",
    "type": "BREACH_DETECTION",
    "site_id": "SITE-SANDTON-04",
    "client_id": "CLIENT-XYZ-CORP"
  },
  "action_ladder": [
    {
      "step": "SIGNAL_TRIAGE",
      "status": "COMPLETED"
    }
  ]
}

This bundle becomes the canonical evidence record.

SECTION 5.1 — THE SOVEREIGN MORNING REPORT
At 06:00, ONYX generates a Morning Sovereign Report.
This report provides a forensic replay of the night shift.
Metric	Source	Significance
Ledger Integrity	Cryptographic Hash	Ensures no ledger tampering
AI / Human Delta	Override Reason Codes	Shows where controllers overruled AI
Norm Drift	Vision Match Scores	Detects degrading site security
Compliance Blockage	Registry of Force	Lists PSIRA/PDP lockouts
SECTION 6 — USER INTERFACE DOCTRINE
ONYX uses progressive disclosure.
Controllers see only the information required for the current step.

UI Pattern 1 — Active Intelligence Lane
Vertical Process Ladder showing:
AUTO-DISPATCH VOIP CLIENT CALL CCTV ACTIVATION VISION VERIFICATION
Each step shows:
• timestamp • status • override controls

UI Pattern 2 — VoIP Handshake Monitor
Displays live transcript:
AI: “Please provide your safe word.” Client: “Phoenix.”
Status becomes:
SAFE WORD VERIFIED or SILENT DURESS DETECTED

UI Pattern 3 — Tactical Map
Displays:
• guard pings • vehicle locations • site boundaries • incident markers • response routes

Safety Geofence Protocol
When a reaction officer arrives on-site:
1. Vehicle GPS location is recorded
2. A 50m Safety Geofence is created
If the officer exits the zone or becomes stationary for >120 seconds, ONYX triggers:
P1 Officer SOS

UI Pattern 4 — Verification Lens
Side-by-side view:
Left → baseline image Right → incident image
AI highlights anomalies.

SECTION 7 — CORE COMMAND SCREENS
ONYX revolves around three operational surfaces.

Live Operations Screen
Purpose: real-time incident command
Layout:
Left → incident queue Center → action ladder Right → incident context Bottom → sovereign ledger feed

Tactical Screen
Purpose: spatial awareness
Displays:
• tactical map • responder pings • geofences • verification lens

Governance Screen
Purpose: operational discipline
Displays:
• compliance alerts • vigilance monitoring • fleet readiness • morning reports

Vigilance Decay Monitor
Guard vigilance follows a decay model.
Level	Status	Action
75%	Green	Normal
90%	Orange	Nudge
100%	Red	Escalate
Visualized as a Decay Sparkline beside each guard.

SECTION 8 — SOVEREIGN LEDGER GUARDRAILS
Every manual override must include a Reason Code.
Valid codes:
DUPLICATE_SIGNAL FALSE_ALARM TEST_EVENT CLIENT_VERIFIED_SAFE HARDWARE_FAULT
Overrides without reason codes are rejected.

SECTION 9 — ONYX SYSTEM ARCHITECTURE MAP
The system operates as a layered command stack.
External Signal Layer
Alarm Panels IoT Gateways CCTV Systems Guard Mobile App Client Panic Buttons Intelligence Feeds
↓
Signal Ingestion Layer
Signal normalization Event classification Signal storm collapse Incident bundle creation
↓
AI Execution Engine
Dispatch engine Guard proximity calculator VoIP verification engine Vision comparison engine Silent duress detector Patrol vigilance engine
↓
Sovereign EventStore
Immutable ledger Incident bundles Dispatch events AI decisions Controller overrides
↓
Operational Read Models
Incident projection Guard performance projection Tactical map projection Compliance projection
↓
Operational Interfaces
Operations Screen Tactical Screen Governance Screen
↓
Mobile Field Layer
Guard app telemetry Checkpoint scanning Evidence capture Offline sync buffer

FINAL OBJECTIVE
ONYX must behave like a disciplined senior controller embedded inside the machine.
The AI executes operations. The human verifies reality. The Sovereign Ledger records the truth.
Incidents become transparent operational narratives, not simple log entries.
