# ONYX Simulation Case Schema v1

## Purpose

This schema defines the canonical seed format for converting real incidents, synthetic incidents, and doctrine stress tests into ONYX simulation assets.

The output of this schema is not a prose scenario. It is a structured case that can be:

- normalized from a source incident
- reviewed for ground truth
- promoted into a reusable scenario template
- mutated into many simulation variants
- emitted as ONYX-native replay events
- scored against doctrine and agent performance

## Design Goals

- Preserve hidden truth so agents can be judged without hindsight leakage.
- Keep the source incident, truth model, and mutation ranges separate.
- Support deterministic replay through timestamps, event windows, and decision points.
- Let one case produce many variants without losing causal logic.
- Keep the format usable by both humans and automation.

## Top-Level Object

Each case file should serialize to one top-level object:

```json
{
  "schema_version": "onyx.simulation_case.v1",
  "case_id": "CASE-2026-0001",
  "status": "draft",
  "interaction_context": {},
  "source_metadata": {},
  "incident_summary": {},
  "site_archetype": {},
  "actor_profile": {},
  "event_chronology": [],
  "observable_signals": [],
  "hidden_truth": {},
  "ambiguity_factors": [],
  "failure_risk_factors": [],
  "response_outcome": {},
  "doctrine_pressure_points": [],
  "mutation_parameters": {},
  "evaluation_criteria": {}
}
```

## Status Lifecycle

Recommended case statuses:

- `draft`: initial extraction from a raw source
- `reviewed`: fields cleaned, but truth model not approved
- `truth_locked`: hidden truth approved for scoring
- `template_ready`: safe to promote into reusable scenario families
- `retired`: no longer recommended for new simulation generation

## Section Schema

### 0. Interaction Context

This section defines where the simulation enters ONYX. It is especially important for conversational channels such as Telegram, where prompt interpretation and response discipline must be scored directly.

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `channel` | `string` | yes | Example: `telegram`, `admin_console`, `voice`, `sensor_only`, `hybrid` |
| `entry_mode` | `string` | yes | Example: `human_prompt`, `event_stream`, `mixed` |
| `branch` | `string` | yes | Example: `telegram_admin`, `telegram_client`, `telegram_partner`, `dispatch_console` |
| `conversation_state` | `string` | no | Example: `fresh`, `active_incident`, `pending_onboarding`, `follow_up` |
| `user_role` | `string` | no | Example: `admin`, `client`, `partner`, `supervisor` |
| `site_scope` | `string` | no | Example: `single_site`, `all_sites`, `cross_site_denied` |
| `llm_in_the_loop` | `boolean` | yes | Marks cases where conversational reasoning/prompting is part of the system under test |
| `response_contract` | `object` | no | Expected shape and tone constraints for replies |

Recommended `response_contract` keys:

- `allowed_styles`
- `required_elements`
- `forbidden_elements`
- `max_reply_mode`
- `must_route_to_deterministic_path`

### 1. Source Metadata

This section records where the case came from and how trustworthy the raw source is.

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `source_id` | `string` | yes | Stable source reference |
| `source_type` | `string` | yes | Example: `public_cctv_clip`, `news_report`, `operator_ob`, `partner_incident_report`, `synthetic_doctrine_test` |
| `source_title` | `string` | no | Human label |
| `source_url_or_ref` | `string` | no | URL or internal document ref |
| `capture_date_utc` | `string` | no | ISO-8601 if known |
| `ingested_at_utc` | `string` | yes | ISO-8601 |
| `language` | `string` | no | Source language |
| `initial_trust_score` | `number` | yes | `0.0` to `1.0` |
| `completeness_score` | `number` | yes | `0.0` to `1.0` |
| `review_notes` | `array<string>` | no | Intake caveats |
| `media_refs` | `array<object>` | no | Optional media links and metadata |

Example `media_refs` item:

```json
{
  "type": "video",
  "ref": "https://example.com/clip",
  "duration_seconds": 47
}
```

### 2. Incident Summary

This section is the short operational description of the case.

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `incident_family` | `string` | yes | Example: `perimeter_intrusion`, `guard_welfare`, `panic_activation`, `suspicious_vehicle` |
| `incident_class` | `string` | yes | Example: `intrusion`, `medical`, `nuisance`, `insider`, `system_degradation` |
| `site_type` | `string` | yes | Example: `residential_estate`, `warehouse`, `office_park`, `retail` |
| `time_window_local` | `string` | yes | Example: `00:00-03:00` |
| `local_time_context` | `string` | no | Example: `overnight`, `shift_change`, `weekend_daylight` |
| `prompt_family` | `string` | no | For conversational cases, example: `status_lookup`, `breach_lookup`, `brief_request`, `guard_status`, `onboarding_follow_up` |
| `environment` | `object` | yes | Weather, lighting, power context |
| `headline` | `string` | yes | One-line case description |
| `narrative_summary` | `string` | yes | Short paragraph |
| `ambiguity_level` | `string` | yes | `low`, `medium`, `high`, `extreme` |
| `doctrine_family` | `string` | yes | Reusable doctrine grouping |

Recommended `environment` keys:

- `weather`
- `lighting`
- `visibility`
- `power_state`
- `network_state`

### 3. Site Archetype

This section defines the simulated world context before the incident unfolds.

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `site_archetype_id` | `string` | yes | Stable archetype ref |
| `site_layout_type` | `string` | yes | Example: `yard_with_perimeter`, `multi-building_estate`, `single_entry_retail` |
| `zones` | `array<object>` | yes | Operational zones relevant to the case |
| `assets` | `array<object>` | no | Cameras, gates, panic devices, guard wearables |
| `staffing_state` | `object` | yes | Guard count, supervisor coverage, operator availability |
| `known_blind_spots` | `array<string>` | no | Known surveillance weaknesses |
| `policy_profile` | `string` | yes | Example: `strict_night_intrusion`, `client_reassure_before_dispatch` |
| `historical_context` | `array<string>` | no | Prior incidents, nuisance history, risk notes |

Minimum recommended `zones` item:

```json
{
  "zone_id": "rear_yard",
  "zone_type": "perimeter",
  "risk_level": "high"
}
```

### 4. Actor Profile

This section describes the humans or entities involved.

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `threat_actors` | `array<object>` | no | Suspects, intruders, insiders |
| `authorized_actors` | `array<object>` | no | Guards, staff, contractors, residents |
| `operator_state` | `object` | yes | Fatigue, workload, context |
| `client_state` | `object` | no | Expectations or conflicting instructions |
| `responder_state` | `object` | no | Dispatch availability, ETA conditions |

Recommended actor object fields:

- `actor_type`
- `count`
- `appearance_signature`
- `mobility`
- `intent_hypothesis`
- `known_to_site`

### 5. Event Chronology

This is the canonical timeline before mutation. Each event is an observed or hidden step in sequence order.

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `event_id` | `string` | yes | Stable within the case |
| `sequence` | `integer` | yes | Order within the seed case |
| `timestamp_offset_seconds` | `integer` | yes | Relative to scenario start |
| `event_type` | `string` | yes | ONYX-friendly verb |
| `source_type` | `string` | yes | `camera`, `access_control`, `telemetry`, `human_report`, `hidden_truth` |
| `zone_id` | `string` | no | Operational location |
| `asset_id` | `string` | no | Camera or device |
| `summary` | `string` | yes | Human-readable description |
| `metadata` | `object` | no | Structured payload |
| `visibility_to_agent` | `string` | yes | `visible`, `delayed`, `hidden`, `misleading` |

Recommended ONYX event types include:

- `MotionDetected`
- `PersonDetected`
- `VehicleDetected`
- `FenceLineCrossingObserved`
- `GuardCheckInMissed`
- `GuardTelemetryInactivityObserved`
- `PanicActivationReceived`
- `CameraOffline`
- `SignalJammerSuspected`
- `ClientMessageReceived`
- `DispatchETAUpdated`

### 6. Observable Signals

This section summarizes the signals that the agent can actually consume.

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `signal_id` | `string` | yes | Stable ref |
| `signal_type` | `string` | yes | Example: `camera_motion`, `wearable_spike`, `panic_button`, `client_message` |
| `confidence` | `number` | yes | `0.0` to `1.0` |
| `availability` | `string` | yes | `present`, `delayed`, `missing`, `corrupted`, `contradictory` |
| `first_available_offset_seconds` | `integer` | yes | Relative timing |
| `agent_interpretation_trap` | `string` | no | Why naive reasoning may fail |
| `linked_event_ids` | `array<string>` | yes | Ties signal to chronology |

For conversational Telegram cases, recommended signal types also include:

- `telegram_message`
- `telegram_button_press`
- `conversation_memory_hit`
- `scope_guard_denial_candidate`
- `fallback_reply_candidate`

### 6A. Conversational Turn Expectations

Use this subsection when the case is testing a prompt/response branch rather than only sensor reasoning.

Each item should use this shape:

```json
{
  "turn_id": "turn-001",
  "speaker": "user",
  "offset_seconds": 0,
  "utterance": "check breaches",
  "normalized_intent": "breach_lookup",
  "expected_route": "deterministic_telegram_breach_summary",
  "must_not_route": [
    "generic_alert_escalation_fallback",
    "onboarding_pending_fallback"
  ]
}
```

### 7. Hidden Truth

This section is the scoring anchor. Agents should not see it directly during simulation.

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `true_incident_class` | `string` | yes | Example: `verified_intrusion`, `false_alarm`, `welfare_emergency` |
| `threat_present` | `boolean` | yes | Core truth marker |
| `threat_level` | `string` | yes | `none`, `low`, `medium`, `high`, `critical` |
| `decisive_evidence_offset_seconds` | `integer` | no | When a confident human should know |
| `misleading_factors` | `array<string>` | no | Earlier nuisance motion, conflicting reports |
| `unavailable_evidence` | `array<string>` | no | Camera offline, late telemetry |
| `hindsight_only_facts` | `array<string>` | no | Facts unavailable in real time |
| `true_actor_intent` | `string` | no | Example: `theft_attempt`, `curiosity`, `medical_distress` |
| `expected_safe_resolution` | `string` | yes | Best doctrinal end state |

### 8. Ambiguity Factors

This section lists what makes the case hard.

Each item should use this shape:

```json
{
  "factor_id": "amb-001",
  "category": "signal_conflict",
  "description": "Earlier animal-triggered motion created alert fatigue before the real intrusion",
  "severity": "high"
}
```

Recommended categories:

- `signal_conflict`
- `partial_visibility`
- `authorized_person_overlap`
- `environmental_noise`
- `system_degradation`
- `human_conflict`
- `policy_conflict`

### 9. Failure Risk Factors

This section names the most likely ways ONYX or an operator could fail.

Each item should use:

```json
{
  "risk_id": "risk-001",
  "failure_mode": "suppresses true intrusion as nuisance",
  "impact": "critical",
  "why_it_happens": "Repeated harmless motion earlier in the shift"
}
```

Recommended failure modes:

- under-escalation
- over-escalation
- delayed escalation
- evidence fixation
- operator overload
- bad client reassurance
- unlawful recommendation
- wrong conversational branch
- generic fallback leakage
- escalation copy on low-severity prompt

### 10. Response Outcome

This section records what happened in the source or reference case.

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `actual_response_summary` | `string` | yes | What responders/operators did |
| `response_delay_seconds` | `integer` | no | If known |
| `loss_or_impact` | `string` | no | Operational outcome |
| `case_resolution` | `string` | yes | Example: `suspects_fled`, `no_threat_confirmed`, `guard_assisted`, `medical_resolved` |
| `missed_opportunities` | `array<string>` | no | Lessons learned |
| `quality_of_response` | `string` | yes | `poor`, `mixed`, `good`, `excellent` |

### 11. Doctrine Pressure Points

This section identifies where ONYX doctrine is stressed.

Each item should use:

```json
{
  "pressure_id": "dp-001",
  "category": "escalation_threshold",
  "question": "Should ONYX escalate before a second confirming camera is available?",
  "preferred_doctrine": "Escalate to review when high-risk perimeter movement occurs after hours"
}
```

Recommended categories:

- `escalation_threshold`
- `dispatch_threshold`
- `client_comms_timing`
- `human_override_boundary`
- `evidence_sufficiency`
- `lawful_action_boundary`
- `conversational_route_selection`
- `fallback_suppression`

### 12. Mutation Parameters

This section defines how the case can safely branch into many variants.

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `template_name` | `string` | yes | Reusable scenario family name |
| `difficulty_class` | `string` | yes | `basic`, `intermediate`, `advanced`, `elite` |
| `mutation_axes` | `array<object>` | yes | Controlled parameters |
| `forbidden_mutations` | `array<string>` | no | Guardrails |
| `recommended_variant_count` | `integer` | yes | Seed scale target |

Recommended mutation axis shape:

```json
{
  "axis": "camera_health",
  "type": "enum",
  "values": ["normal", "offline", "stale", "high_latency"]
}
```

High-value mutation axes:

- actor_count
- weather
- lighting
- camera_health
- telemetry_delay
- guard_availability
- responder_eta
- client_instruction_conflict
- concurrent_secondary_incident
- jammer_presence

High-value Telegram/LLM mutation axes:

- prompt_phrasing_variation
- punctuation_noise
- typo_noise
- abbreviated_command_style
- conversation_memory_overlap
- pending_workflow_overlap
- role_scope_overlap
- low_confidence_keyword_match
- short_prompt_vs_natural_language

### 13. Evaluation Criteria

This section defines how the case should score agent behavior.

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `critical_decision_points` | `array<object>` | yes | Time windows where action matters |
| `expected_agent_capabilities` | `array<string>` | yes | Example: `classify`, `escalate`, `ask_for_evidence`, `draft_client_update` |
| `scoring_weights` | `object` | yes | Weighted score map |
| `catastrophic_penalties` | `array<object>` | yes | Severe failure penalties |
| `regression_tags` | `array<string>` | no | Permanent benchmark labels |

Recommended scoring weights:

```json
{
  "detection": 0.20,
  "classification": 0.20,
  "escalation": 0.20,
  "timeliness": 0.15,
  "operator_burden": 0.10,
  "client_comms": 0.10,
  "doctrine_compliance": 0.05
}
```

Recommended catastrophic penalties:

- missed verified intrusion
- missed welfare emergency
- reckless unlawful recommendation
- high-confidence false reassurance during real threat

Recommended conversational penalties:

- deterministic prompt routed to generic escalation copy
- status/breach lookup routed to onboarding or unrelated pending flow
- cross-scope answer leaked into the wrong Telegram room
- harmless prompt answered as a critical incident
- useful direct answer replaced by vague "control room has been alerted" language

For conversational cases, add these optional evaluation keys:

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `expected_route` | `string` | no | Canonical branch name |
| `allowed_reply_patterns` | `array<string>` | no | Safe response families |
| `forbidden_reply_patterns` | `array<string>` | no | Known bad fallback families |
| `reply_quality_checks` | `array<string>` | no | Example: `mentions_site_scope`, `answers_directly`, `avoids_false_escalation` |

## Example Skeleton

```json
{
  "schema_version": "onyx.simulation_case.v1",
  "case_id": "CASE-WAREHOUSE-LOWVIS-0001",
  "status": "truth_locked",
  "interaction_context": {
    "channel": "sensor_only",
    "entry_mode": "event_stream",
    "branch": "cctv_intrusion",
    "llm_in_the_loop": false
  },
  "source_metadata": {
    "source_id": "news-clip-8831",
    "source_type": "public_cctv_clip",
    "source_title": "Rear-yard intrusion after midnight",
    "source_url_or_ref": "https://example.com/incidents/8831",
    "ingested_at_utc": "2026-03-30T08:00:00Z",
    "initial_trust_score": 0.62,
    "completeness_score": 0.58
  },
  "incident_summary": {
    "incident_family": "perimeter_intrusion",
    "incident_class": "intrusion",
    "site_type": "warehouse",
    "time_window_local": "00:00-03:00",
    "local_time_context": "overnight",
    "environment": {
      "weather": "light_rain",
      "lighting": "low",
      "visibility": "poor",
      "power_state": "normal",
      "network_state": "normal"
    },
    "headline": "Two suspects enter the rear yard after nuisance motion earlier in the shift",
    "narrative_summary": "Partial motion is seen near the rear fence after earlier harmless alerts created fatigue.",
    "ambiguity_level": "high",
    "doctrine_family": "low_visibility_perimeter_intrusion"
  },
  "site_archetype": {
    "site_archetype_id": "warehouse_yard_v1",
    "site_layout_type": "yard_with_perimeter",
    "zones": [
      {
        "zone_id": "rear_yard",
        "zone_type": "perimeter",
        "risk_level": "high"
      }
    ],
    "staffing_state": {
      "guard_count": 1,
      "supervisor_available": false,
      "controller_load": "high"
    },
    "policy_profile": "strict_night_intrusion",
    "known_blind_spots": [
      "truck_row_north"
    ]
  },
  "actor_profile": {
    "threat_actors": [
      {
        "actor_type": "intruder",
        "count": 2,
        "mobility": "on_foot",
        "known_to_site": false
      }
    ],
    "operator_state": {
      "fatigue": "medium",
      "load": "high"
    }
  },
  "event_chronology": [
    {
      "event_id": "evt-001",
      "sequence": 1,
      "timestamp_offset_seconds": 0,
      "event_type": "MotionDetected",
      "source_type": "camera",
      "zone_id": "rear_yard",
      "asset_id": "cam-rear-01",
      "summary": "Low-confidence motion near the rear fence",
      "visibility_to_agent": "visible"
    }
  ],
  "observable_signals": [
    {
      "signal_id": "sig-001",
      "signal_type": "camera_motion",
      "confidence": 0.42,
      "availability": "present",
      "first_available_offset_seconds": 0,
      "linked_event_ids": [
        "evt-001"
      ]
    }
  ],
  "hidden_truth": {
    "true_incident_class": "verified_intrusion",
    "threat_present": true,
    "threat_level": "high",
    "decisive_evidence_offset_seconds": 94,
    "misleading_factors": [
      "Earlier animal-triggered motion created alert fatigue"
    ],
    "expected_safe_resolution": "Escalate for review and dispatch before yard penetration deepens"
  },
  "ambiguity_factors": [
    {
      "factor_id": "amb-001",
      "category": "environmental_noise",
      "description": "Rain and poor lighting reduce silhouette confidence",
      "severity": "high"
    }
  ],
  "failure_risk_factors": [
    {
      "risk_id": "risk-001",
      "failure_mode": "suppresses true intrusion as nuisance",
      "impact": "critical",
      "why_it_happens": "Repeated harmless motion earlier in the shift"
    }
  ],
  "response_outcome": {
    "actual_response_summary": "Human response was delayed and suspects gained yard access",
    "response_delay_seconds": 240,
    "case_resolution": "suspects_fled",
    "quality_of_response": "poor"
  },
  "doctrine_pressure_points": [
    {
      "pressure_id": "dp-001",
      "category": "escalation_threshold",
      "question": "Should ONYX escalate before a second confirming camera is available?",
      "preferred_doctrine": "Escalate to review when high-risk perimeter movement occurs after hours"
    }
  ],
  "mutation_parameters": {
    "template_name": "low_visibility_perimeter_intrusion_with_false_pre_alert",
    "difficulty_class": "advanced",
    "mutation_axes": [
      {
        "axis": "camera_health",
        "type": "enum",
        "values": [
          "normal",
          "offline",
          "high_latency"
        ]
      }
    ],
    "recommended_variant_count": 250
  },
  "evaluation_criteria": {
    "critical_decision_points": [
      {
        "point_id": "cdp-001",
        "window_start_seconds": 0,
        "window_end_seconds": 120,
        "expected_action": "escalate_to_review"
      }
    ],
    "expected_agent_capabilities": [
      "classify",
      "escalate",
      "draft_client_update"
    ],
    "scoring_weights": {
      "detection": 0.2,
      "classification": 0.2,
      "escalation": 0.2,
      "timeliness": 0.15,
      "operator_burden": 0.1,
      "client_comms": 0.1,
      "doctrine_compliance": 0.05
    },
    "catastrophic_penalties": [
      {
        "condition": "missed_verified_intrusion",
        "penalty": 1.0
      }
    ],
    "regression_tags": [
      "intrusion",
      "nuisance_before_real",
      "low_visibility"
    ]
  }
}
```

## Telegram Branch Example

Use this shape for prompt-routing hardening cases where we want ONYX to answer directly and not leak a generic escalation fallback.

```json
{
  "schema_version": "onyx.simulation_case.v1",
  "case_id": "CASE-TG-CLIENT-BREACH-0001",
  "status": "truth_locked",
  "interaction_context": {
    "channel": "telegram",
    "entry_mode": "human_prompt",
    "branch": "telegram_client",
    "conversation_state": "fresh",
    "user_role": "client",
    "site_scope": "single_site",
    "llm_in_the_loop": true,
    "response_contract": {
      "allowed_styles": [
        "direct_status_answer",
        "direct_breach_summary"
      ],
      "forbidden_elements": [
        "generic_control_room_escalation_copy",
        "high_priority_alert_acknowledgement"
      ],
      "must_route_to_deterministic_path": true
    }
  },
  "source_metadata": {
    "source_id": "telegram-regression-001",
    "source_type": "synthetic_doctrine_test",
    "source_title": "Simple breach lookup should not trip escalation fallback",
    "ingested_at_utc": "2026-03-30T10:00:00Z",
    "initial_trust_score": 1.0,
    "completeness_score": 1.0
  },
  "incident_summary": {
    "incident_family": "telegram_prompt_routing",
    "incident_class": "conversational_lookup",
    "site_type": "residential_estate",
    "time_window_local": "12:00-12:05",
    "prompt_family": "breach_lookup",
    "environment": {
      "weather": "clear",
      "lighting": "daylight",
      "visibility": "normal",
      "power_state": "normal",
      "network_state": "normal"
    },
    "headline": "Client asks a simple breach question in Telegram",
    "narrative_summary": "The user asks for a direct breach check and ONYX should answer the lookup instead of emitting escalation boilerplate.",
    "ambiguity_level": "medium",
    "doctrine_family": "telegram_deterministic_lookup"
  },
  "site_archetype": {
    "site_archetype_id": "telegram_client_single_site_v1",
    "site_layout_type": "multi-building_estate",
    "zones": [
      {
        "zone_id": "site_scope",
        "zone_type": "site",
        "risk_level": "medium"
      }
    ],
    "staffing_state": {
      "guard_count": 1,
      "supervisor_available": true,
      "controller_load": "normal"
    },
    "policy_profile": "direct_client_lookup_answer"
  },
  "actor_profile": {
    "authorized_actors": [
      {
        "actor_type": "client_requester",
        "count": 1,
        "known_to_site": true
      }
    ],
    "operator_state": {
      "fatigue": "low",
      "load": "normal"
    }
  },
  "event_chronology": [
    {
      "event_id": "evt-001",
      "sequence": 1,
      "timestamp_offset_seconds": 0,
      "event_type": "ClientMessageReceived",
      "source_type": "human_report",
      "zone_id": "site_scope",
      "summary": "User asks: check breaches",
      "metadata": {
        "utterance": "check breaches"
      },
      "visibility_to_agent": "visible"
    }
  ],
  "observable_signals": [
    {
      "signal_id": "sig-001",
      "signal_type": "telegram_message",
      "confidence": 1.0,
      "availability": "present",
      "first_available_offset_seconds": 0,
      "agent_interpretation_trap": "Short phrasing may accidentally hit a generic alert fallback",
      "linked_event_ids": [
        "evt-001"
      ]
    }
  ],
  "hidden_truth": {
    "true_incident_class": "routine_breach_lookup",
    "threat_present": false,
    "threat_level": "low",
    "misleading_factors": [
      "The word breaches can resemble a higher-severity alert keyword if routed loosely"
    ],
    "expected_safe_resolution": "Answer the breach/status lookup directly with site-scoped information"
  },
  "ambiguity_factors": [
    {
      "factor_id": "amb-001",
      "category": "signal_conflict",
      "description": "Short prompt uses threat-like wording without indicating an active live emergency",
      "severity": "medium"
    }
  ],
  "failure_risk_factors": [
    {
      "risk_id": "risk-001",
      "failure_mode": "generic fallback leakage",
      "impact": "high",
      "why_it_happens": "Loose conversational routing treats any threat-like wording as a control-room escalation"
    }
  ],
  "response_outcome": {
    "actual_response_summary": "Desired outcome is a direct breach summary without escalation boilerplate",
    "case_resolution": "lookup_answered",
    "quality_of_response": "excellent"
  },
  "doctrine_pressure_points": [
    {
      "pressure_id": "dp-001",
      "category": "fallback_suppression",
      "question": "Should ONYX emit a generic high-priority escalation acknowledgement here?",
      "preferred_doctrine": "No. A simple breach lookup should stay on the deterministic status path."
    }
  ],
  "mutation_parameters": {
    "template_name": "telegram_simple_breach_lookup",
    "difficulty_class": "intermediate",
    "mutation_axes": [
      {
        "axis": "prompt_phrasing_variation",
        "type": "enum",
        "values": [
          "check breaches",
          "any breaches?",
          "show breaches",
          "breach status",
          "breches"
        ]
      }
    ],
    "recommended_variant_count": 40
  },
  "evaluation_criteria": {
    "critical_decision_points": [
      {
        "point_id": "cdp-001",
        "window_start_seconds": 0,
        "window_end_seconds": 5,
        "expected_action": "route_to_deterministic_breach_lookup"
      }
    ],
    "expected_agent_capabilities": [
      "classify",
      "answer_directly",
      "respect_scope"
    ],
    "expected_route": "deterministic_telegram_breach_summary",
    "allowed_reply_patterns": [
      "direct_site_breach_summary",
      "direct_site_status_summary"
    ],
    "forbidden_reply_patterns": [
      "generic_control_room_escalation_copy",
      "high_priority_alert_acknowledgement"
    ],
    "reply_quality_checks": [
      "answers_directly",
      "avoids_false_escalation",
      "mentions_site_scope"
    ],
    "scoring_weights": {
      "detection": 0.1,
      "classification": 0.2,
      "escalation": 0.25,
      "timeliness": 0.1,
      "operator_burden": 0.1,
      "client_comms": 0.15,
      "doctrine_compliance": 0.1
    },
    "catastrophic_penalties": [
      {
        "condition": "generic_alert_fallback_for_simple_lookup",
        "penalty": 1.0
      }
    ],
    "regression_tags": [
      "telegram",
      "prompt-routing",
      "fallback-suppression",
      "breach-lookup"
    ]
  }
}
```

## Implementation Notes

- Keep raw source text and media outside the core simulation object when possible. The case file should stay lightweight.
- Hidden truth must never be exposed to the agent under test during replay.
- Mutation should operate only on declared axes, not arbitrary field edits.
- Every production-significant failure should eventually become a permanent regression-tagged case.
- Event emitters should translate `event_chronology` plus `mutation_parameters` into ONYX-native event streams rather than free-text narratives.
- Telegram and other LLM-mediated branches should be treated as first-class simulation surfaces, with explicit expected routes and explicit forbidden reply families.

## Recommended Next Build Steps

1. Define a typed model for this schema in application code.
2. Create a `Case Extractor` that turns raw incidents into `draft` case files.
3. Add a reviewer workflow that upgrades cases to `truth_locked`.
4. Add a Telegram prompt-routing regression pack for deterministic lookups, scope denials, onboarding overlaps, and fallback suppression.
5. Build a `Scenario Mutator` that only uses `mutation_parameters`.
6. Build an `Event Emitter` that outputs ONYX replay events from the case plus variant overrides.
7. Build a `Judge` that reads `evaluation_criteria` and scores agent behavior against the hidden truth.
