# ONYX Operational Memory Engine

Deterministic Replay + Learning + Coaching

## 1. Why This Matters

Most security systems store logs. ONYX is designed to store replayable operational truth.

Typical systems capture:
- patrol logs
- incidents
- GPS points
- occasional media

But cannot reliably:
- reconstruct what happened
- detect drift over time
- connect weak signals to outcomes
- improve patrol doctrine

ONYX is built to do exactly that.

## 2. Core Principle

ONYX uses append-only, ordered events with offline-first deterministic sync.

This enables:
- deterministic replay
- cross-shift pattern learning
- AI supervision
- evidence-backed coaching and rewards
- predictive operational optimization

## 3. Determinism Definition (Technical)

For ONYX, deterministic means:
- append-only event model (no mutable historical edits)
- per-shift monotonic `sequence`
- immutable identifiers (`event_id`, `media_id`)
- idempotent sync constraints in backend (`shift_id + sequence`, `event_id`)
- normalized UTC timestamps:
  - `occurred_at`: field-time
  - `received_at`: backend ingest-time

Replay correctness target:
- re-running timeline queries yields identical ordered operation flow for a given shift and filters.

## 4. Event Model (Current + Future-Ready)

Representative event types:
- `SHIFT_START`
- `SHIFT_VERIFICATION_IMAGE`
- `WEARABLE_HEARTBEAT`
- `GPS_HEARTBEAT`
- `DISPATCH_RECEIVED`
- `DISPATCH_ACKED`
- `STATUS_CHANGED`
- `CHECKPOINT_SCANNED`
- `PATROL_IMAGE_CAPTURED`
- `INCIDENT_REPORTED`
- `PANIC_TRIGGERED`
- `PANIC_CLEARED`
- `DEVICE_HEALTH`
- `SYNC_STATUS`

Event envelope:
- `event_id`
- `guard_id`
- `site_id`
- `shift_id`
- `sequence`
- `occurred_at`
- `event_type`
- `payload` (json)
- `device_id`
- `app_version`

## 5. What This Unlocks

### A. Patrol Effectiveness Learning

Correlate:
- patrol timing
- zone coverage
- checkpoint adherence
- incident outcomes

Output:
- risk-weighted patrol recommendations by time window and zone.

### B. Evidence-Based Guard Performance

Track:
- route compliance
- checkpoint miss patterns
- response latency
- patrol image quality consistency

Output:
- fair performance review, coaching, and recognition.

### C. Welfare + Fatigue Monitoring

Correlate:
- wearable activity
- heart-rate trends
- stationary duration
- shift phase/time

Output:
- guard welfare prompts, control-room escalation for high-risk patterns.

### D. Environmental Visual Drift Detection

Model baseline per checkpoint and detect anomalies:
- open gate
- unknown vehicle
- damaged fence
- suspicious object/person

Critical precursor:
- image quality gates before acceptance (blur, low light, glare).

### E. Incident Prediction

Detect repeated weak signals:
- loitering by location/time
- recurring near-miss patterns
- checkpoint degradation trends

Output:
- proactive patrol adjustments before incidents escalate.

### F. Dynamic Patrol Optimization

Shift from static patrol frequency to:
- adaptive route intensity
- risk-window scheduling
- outcome-driven coverage.

### G. Coaching + Rewards Engine

Use live and post-shift intelligence for:
- actionable prompts
- positive reinforcement
- achievement tracking
- reward integration.

## 6. Outcome Label Taxonomy (Must Be Standardized Early)

Minimum canonical labels:
- `true_threat`
- `false_alarm`
- `maintenance_issue`
- `policy_violation`
- `medical_welfare`
- `unknown`

Optional confidence fields:
- `label_confidence`
- `reviewed_by`
- `reviewed_at`

Without robust outcome labels, model quality plateaus.

## 7. Decision Safety Model

Separate:
- inference (risk score / anomaly confidence)
- action policy (what ONYX is allowed to trigger)

Near-term rule:
- model suggests
- policy gate decides
- human can override
- override is logged

This reduces unsafe automation and creates training feedback.

## 8. Governance + Compliance Requirements

### Data Governance
- per-signal retention schedules
- PII minimization by default
- scoped access by role/site/client

### Model Governance
- false-positive/false-negative monitoring
- drift detection by site and season/time bucket
- retraining cadence with explicit dataset versions
- human-review sampling strategy

### Operational Governance
- decision audit logs
- escalation policy versioning
- rollback-safe model deployment process

## 9. Current Build Alignment

ONYX currently has key building blocks:
- append-only guard ops model and migration path
- deterministic per-shift sequencing
- offline queue with sync retry behavior
- capture enforcement hooks for shift/patrol images
- sync observability (pending, failed, last success/failure, history rows)

These are the correct prerequisites for learning and predictive layers.

## 10. 12-Week Execution Roadmap

### Weeks 1-2: Data Integrity Hardening
- apply canonical event/media migrations in production Supabase
- enforce append-only constraints and idempotency uniqueness
- finalize event schema versioning in payloads
- enable RLS + scoped policies

KPIs:
- duplicate sync rate < 0.1%
- event replay ordering accuracy 100%

### Weeks 3-4: Capture Quality + Labeling
- implement image quality gates (blur/low-light/glare checks)
- add mandatory review outcomes for priority incidents
- add label capture UI for controllers

KPIs:
- unusable image rate < 8%
- labeled incident coverage > 85%

### Weeks 5-6: Baseline Analytics + Drift
- zone/time risk heatmaps
- checkpoint compliance trend tracking
- guard stationary-pattern drift detection

KPIs:
- weekly drift report generated for all active sites
- missed-checkpoint recurrence reduced by 20%

### Weeks 7-8: Coaching + Welfare Engine
- real-time low/medium/high coaching prompts
- welfare escalation thresholds + review queue
- achievement counters for positive behavior

KPIs:
- prompt acknowledgment rate > 75%
- welfare escalation response median < 3 min

### Weeks 9-10: Predictive Patrol Recommendations
- risk-window patrol suggestions per site
- route intensity tuning based on outcomes
- supervisor approval workflow for recommended changes

KPIs:
- recommendation adoption > 60%
- incident rate in targeted windows reduced by 10-15%

### Weeks 11-12: Operational Rollout + Measurement
- pilot across selected high-variance sites
- controlled comparison vs baseline operations
- finalize stage-gate for wider rollout

KPIs:
- response-time median improvement > 15%
- verified patrol compliance > 95%
- client incident confidence score uplift (survey-based)

## 11. Stage Progression Model

- Stage 1: Guard operations platform
- Stage 2: AI-supervised guarding
- Stage 3: Multi-signal security intelligence
- Stage 4: Predictive patrol optimization
- Stage 5: Autonomous orchestration (CCTV/sensors/drones/guards)

## 12. Most Important Execution Rule

Do not rush model autonomy before data quality and labels are mature.

Priority order:
1. high-integrity event capture
2. strict replayability and auditability
3. quality controls and labeling
4. supervised learning loops
5. controlled automation expansion

This is the path that creates durable operational advantage.
