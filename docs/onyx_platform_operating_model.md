# ONYX Platform Operating Model

This document captures product-structure and rollout decisions that sit outside
the active CCTV, DVR, and listener implementation checklists.

Use it to keep operating-model choices stable while the platform expands.

## Rollout Decisions

### Training Modules

Build the training tracks as part of rollout, not as a post-launch cleanup.

- Guard module
  - device use
  - dispatch flow
  - NFC patrol flow
  - image quality and evidence capture
  - panic usage
  - offline behavior

- Controller module
  - ONYX web triage
  - dispatch lifecycle
  - replay and evidence review
  - governance labels
  - escalation handling

- Supervisor module
  - coaching workflow
  - override decisions
  - welfare checks
  - KPI and trend review

- Support and admin module
  - onboarding users, sites, and devices
  - config checks
  - pilot-gate execution
  - incident audit export

### Language Strategy

- Guard app
  - keep the primary UI in English for command consistency, operator training, and evidence records
  - add critical dual-language prompts later where comprehension risk is highest

- Client app
  - support multilingual UX from the early client-facing MVP
  - start with English plus the key local languages needed for trust and comms quality

### Commercial and Billing Strategy

- Treat ONYX as the system of operational truth.
- Push invoice-ready operational evidence into accounting software instead of building a full billing engine first.
- Prefer integration-first billing until there is a clear need for:
  - custom contract logic
  - deeply usage-based charging
  - marketplace-style multi-tenant billing

### Bounded Contexts

Recommended context split:

- Identity and access
- Operations command
  - dispatch
  - status
  - escalation
- Guard field ops
  - shifts
  - patrol
  - panic
  - telemetry
  - offline sync
- Client communications
  - chat
  - notifications
  - acknowledgements
- Intelligence ingestion
  - news
  - community feeds
  - vendor feeds
  - normalization
- Evidence and replay
  - append-only timeline
  - integrity
  - exports
- Governance and coaching
  - outcome policy
  - prompts
  - supervisor actions
- Commercial
  - contracts
  - SLA plans
  - invoicing integration
  - reporting

## Feature Placement Notes

### Build Next

- training modules for all operator types
- multilingual client app
- integration-first commercial billing
- bounded-context driven platform split

### Build Later

- in-house billing engine
  - only after ONYX needs contract-native billing that accounting integrations cannot support cleanly

## Positioning Notes

- Keep operator and evidence-critical surfaces English-first where exact wording matters.
- Put multilingual effort first where it affects client trust, onboarding, and acknowledgement quality.
- Avoid expanding into a full in-house billing platform too early.
- Keep context boundaries stable as CCTV, DVR, listener, provenance, and future edge features grow.
