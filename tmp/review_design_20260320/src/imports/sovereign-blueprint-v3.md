check this: Here is the Complete ONYX Sovereign Blueprint v3.0
The Sovereign Data Dictionary + Autonomous Operating Model (PSIRA & POPIA Compliant)
The Single Source of Truth for the Entire Sovereign Spine
This document merges every single element we have discussed across all conversations — the original “A Day in the Life of ONYX”, the full data dictionary, image gap analysis, operational norms and scenarios, UI enhancements, Visual Norm baseline, Client Onboarding flow, Moat features, Tactical Map requirements, Action Ladder, Human-in-the-Loop transparency, and the non-negotiable core philosophy:
The Foundational Principle: Human-Parallel Execution
The AI never operates in a black box. It must execute every single process exactly as an experienced human controller would — step by step, in the exact same logical order a veteran controller follows, with deliberate 2–3 second “think-time” delays between actions. This makes the AI’s reasoning fully transparent and observable on the dashboard at all times. The controller can watch the AI “thinking”, understand why each step is being taken, override or edit any action instantly, or seize full manual control with one tap. Transparency is not a nice-to-have — it is the entire product. The controller remains the “Editor of Truth”; the AI is simply the tireless, perfectly consistent “Author of Action” that never forgets a step, never skips a compliance check, and logs everything immutably.
1. ONYX Sovereign Data Dictionary v3.0 (Built for Compliance, AI Execution & Scalability)
All personnel live in one unified Employees table (role discriminator) so permissions, payroll, compliance and dispatch logic are centralised.
Employees (Central Registry of Force)











































































Field NameData TypeDescription / LogicidUUIDPrimary Keyfull_name / surnameStringLegal names for PSIRA/UIF contractsid_numberStringSA ID or Passport (unique)roleEnumcontroller, supervisor, guard, reaction_officer, adminreporting_toUUIDForeign key to supervisorpsira_number / psira_gradeString/EnumGrade A–E + registration numberpsira_expiryDate30-day auto-alert + blocks shift assignmenthas_driver_license / license_codeBoolean/StringCode 8/10/14 etc.pdp_expiryDatePublic Driving Permit (mandatory for Reaction)firearm_competencyJSONB{“handgun”: true, “shotgun”: false…} + serial numbersdevice_uidStringPaired smartphone for Guard Appbiometric_template_hashStringShift-start verification (hash only)employment_statusEnumactive / suspended / on_leave / terminated
Clients (The Service Counterparty)













































Field NameData TypeDescription / LogicidUUIDPrimary Keylegal_nameStringHOA / company nameclient_typeEnumguarding / armed_response / remote_watch / hybridvat_numberStringTax-compliant invoicingsovereign_contact / contact_phoneStringApex emergency decision-makersafe_word_hashStringFor AI VoIP verificationcontract_startDateService commencement
Sites (The Deployment Environment)























































Field NameData TypeDescription / LogicidUUIDPrimary Keyclient_idUUIDForeign keysite_nameString“Blue Ridge North Gate”physical_addressTextStreet addressgps_lat / gps_longDecimalGeofencing & closest-unit routingvisual_norm_idsArrayLinks to baseline Norm photosentry_protocolTextGate codes, intercoms, keysrisk_ratingInteger1–5 (auto-adjusts nudges & SLA)site_layout_mapFileUploaded PDF/JPG for zone drawing
Incidents (Immutable EventStore – Insurance & Legal Grade)




























































Field NameData TypeDescription / LogicidUUIDPrimary Keyevent_uidStringEvidence Bundle IDsite_idUUIDForeign keytype / priorityEnumbreach/fire/panic… + P1–P4statusEnumdetected → verified → dispatched → on_site → securedtimestamp_ingest / arrival / closureDateTimeMicrosecond precisionmedia_linksArraySupabase URLs (photos, VoIP audio, CCTV)integrity_hashStringSHA-256 chain to previous eventvisual_match_scoreInteger0–100 % (AI Norm comparison)closure_notesTextFinal Controller/AI summary
Vehicles (Reaction & Supervisor Assets)



































Field NameData TypeDescription / Logicid / callsignString“Echo 1”license_plateStringRegistrationvehicle_typeEnumArmed Response / Supervisor Bakkiemaintenance_statusEnumService Due / Roadworthy Expiryfuel_odometer_logJSONBPrevents unauthorised use
Add Client / New Site Flow (Your Current Mission): Multi-step stepper so the user is never overwhelmed. Mandatory Risk Profiler (“Is this site High-Risk Industrial or Residential?”) that auto-sets nudge frequency, escalation triggers and SLA timers. Mandatory Visual Norm Upload module during onboarding.
2. The Visual Norm — AI’s Source of Truth (Eliminates Subjective Reporting)

Onboarding: Technician uploads high-resolution baseline photos of every critical point (gates locked, perimeters clear, alarm panels ready, guard handover pose) with GPS + viewing-angle metadata.
During any signal or random check: AI pulls the exact matching Norm, performs pixel-level differential analysis, and calculates Visual Integrity Score.
95 %+ match → auto-secure & close. <60 % → flags Structural Anomaly, highlights in red, alerts controller with Ghost overlay.
Also used for shift-change Handover Norm (guard uniform + post photo) and random Selfie checks.

3. A Day in the Life of ONYX (Human-Parallel Execution in Real Time)
🌅 06:00 – Handover (Verification Phase)
The morning shift arrives. They shouldn’t have to ask “What happened?” — they see it instantly.

AI-generated Sovereign Morning Report: summary of night’s open dispatches, stale guard syncs, Visual Integrity Scores.
One-button “Verify Ledger” (tamper-proof hash check).
Compliance Dashboard: guards on-site, PSIRA/driver licences expiring today, vehicles marked Red (overdue service).
Fleet & Handover Norm photos auto-compared.

🕒 10:00 – Business as Usual (Governance Phase)
Quiet time = prevention time.

The “Nudge” System: guard stationary or missed checkpoint for 15 min → haptic notification. No reply in 2 min → escalates to controller.
Ghost Prevention: checkpoint scan rejected if GPS >50 m off.
Intelligence Engine: monitors live feeds for “protest”, “load-shedding” etc. within 5 km → auto-elevates site Risk Rating and patrol frequency.
Client Onboarding enhancements: Drag-and-Drop Zones on uploaded site map, Site Templates (“Standard Estate” vs “Industrial Warehouse”), SLA Tiering (Gold = 30-sec response, Silver = 2-min).
Broadcast Mode, Batch Actions, Global Cmd+K search, Vigilance Timers on every guard card.

🔥 22:00 – Combat Window (Execution Phase)
An alarm triggers. The app becomes a High-Pressure Command Interface. The AI immediately runs the exact Action Ladder a veteran controller would follow, step by step, with visible think-time delays:

Ingest & Triage: Review evidence (opens CCTV, clusters alarms into single Active Breach Cluster if multiple from same site, pulls Visual Norm).
Pre-emptive Dispatch: One-tap (or auto) to closest Reaction Officer (calculates & shows 3 closest with live distance).
Advisory & VoIP Handshake: Pre-filled message + AI triggers VoIP call to sovereign contact, shows live transcription.
• Correct safe-word → logs “Safe Word Verified”, sends Stand-Down.
• No answer/incorrect → upgrades to P1 Critical, UI pulses red, CCTV hijack, officer proceeds.
Evidence Closure: Officer uploads photo → AI Vision compares to Norm → score calculated → auto-close with integrity hash.

4. Human-in-the-Loop Dashboard — Full AI Transparency (Live Narrative Flow)
The UI is designed so you always see the AI thinking like a human controller.
Active Intelligence Lane (Central Workspace)

Intent Header: “Onyx is investigating a P1 Perimeter Breach at Site-Sandton”.
Vertical Process Ladder: Action Pills light up sequentially with think-time delays:
[AUTO-DISPATCH] (Green – Guard-1 moving) → [VOIP-CLIENT] (Pulsing – Dialing…) → [CCTV-ACTIVATE] → [VISION-VERIFY].
Every pill has [X] Override + [Edit].
Live Transcription Feed + Sentiment Indicator + [TAKE OVER CALL] button.
Tactical Map Overlay (replaces cards during P1): live guard pings, site perimeters, active incident pings, projected officer paths, closest-unit suggestion, re-route capability.
Verification Lens: split-screen “Norm” vs “Current” photo with AI red highlights + one-tap Ghost overlay.
Sovereign Ledger Feed at bottom: immutable audit trail (e.g. “19:42: AI-Generated Dispatch created”, “19:43: Automated VoIP call initiated”, “19:44: Incident closed via AI Vision Verification (Confidence 98 %)”).

Dashboard Structural Amendments

Dispatch Queue: cards move automatically; drag back to Manual for full control.
Pressure Heatmap: visualises which site is driving the Pressure Index.
Visual Urgency: Active Breach cards pulse red and jump to top.
Media Carousel in Events feed (thumbnails instead of text logs).
Role-Based Surfaces: Controller sees Matrix (Maps, Queues, Live Video); Supervisor sees Audit (performance, SLA breaches); Owner/Admin sees Revenue (growth, renewals).

Post-Incident Client Replay
Shareable immutable timeline that kills every “Where were you?” argument: exact timestamps for alarm, AI dispatch, VoIP call, arrival (GPS verified), photo match, closure.
5. The Moat Features

Panic Interaction: Guard-side Dead Man’s Switch (no tap every 30 min in high-risk hours → alert); Client-side Silent Panic button (instant live audio stream to Control Room).
Intelligence Engine (Triage): collapses multiple alarms into one Active Breach Cluster.
Voice Control: “Onyx, escalate Dispatch-4”.
Autonomous Report Bundling at 06:00 (no human click needed).
One-Click Macro Buttons: [REQUEST ETA], [UNIT ARRIVED], [SEND POLICE].

6. Operational Norm Summary (Traditional vs ONYX Human-Parallel)



































ServiceTraditional Manual ActionONYX AI-Parallel Action (Visible Steps + Think-Time)AlarmDispatcher calls officerAI auto-dispatches closest unit + shows distanceVerificationController calls clientAI VoIP + live transcription + safe-word checkEscalationSupervisor decidesAI timer-based escalation with overrideEvidenceGuard says “all clear”AI Vision vs Norm photo + confidence scorePatrolController watches dotsAI nudges + GPS drift rejection + auto-log