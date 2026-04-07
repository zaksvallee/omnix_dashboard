import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/simulation/scenario_definition.dart';
import 'package:omnix_dashboard/domain/authority/onyx_command_brain_contract.dart';
import 'package:omnix_dashboard/domain/authority/onyx_task_protocol.dart';

void main() {
  test('ScenarioDefinition defaults scenarioSet to replay when omitted', () {
    final definition = ScenarioDefinition.fromJsonString('''
      {
        "scenarioId": "legacy_scenario_without_set_v1",
        "title": "Legacy scenario",
        "description": "Scenario set should default cleanly.",
        "category": "admin_portfolio_read",
        "tags": ["legacy"],
        "author": "zaks",
        "createdAt": "2026-03-30T12:00:00Z",
        "version": 1,
        "status": "draft",
        "runtimeContext": {
          "operatorRole": "admin",
          "authorityScope": "all_sites",
          "activeSiteIds": ["site_ms_vallee"],
          "viewportProfile": "desktop_standard",
          "sessionMode": "fresh_entry",
          "currentTime": "2026-03-30T19:30:00+02:00",
          "timezone": "Africa/Johannesburg"
        },
        "seedState": {
          "fixtures": {
            "events": [],
            "projections": [],
            "sessions": []
          },
          "onboardingState": "pending",
          "watchState": "stable",
          "dispatchState": "idle",
          "clientConversationState": "none",
          "siteStatusState": "normal"
        },
        "inputs": {
          "prompts": [],
          "inboundSignals": [],
          "telemetryInputs": [],
          "cameraInputs": [],
          "adminQueries": [],
          "clientMessages": []
        },
        "expectedOutcome": {
          "expectedRoute": "admin_all_sites_read",
          "expectedIntent": "portfolio_breach_lookup",
          "expectedEscalationState": "none",
          "expectedProjectionChanges": [],
          "expectedDrafts": [],
          "expectedBlockedActions": [],
          "expectedUiState": {
            "surface": "admin_read_result"
          }
        }
      }
    ''');

    expect(definition.scenarioSet, 'replay');
  });

  test(
    'ScenarioDefinition parses navigation steps for conditional sequences',
    () {
      final definition = ScenarioDefinition.fromJsonString('''
      {
        "scenarioId": "sequence_contract_probe_v1",
        "title": "Sequence contract",
        "description": "Scenario navigation should parse explicit step sequences.",
        "category": "monitoring_watch",
        "scenarioSet": "validation",
        "tags": ["sequence"],
        "author": "zaks",
        "createdAt": "2026-04-01T12:00:00Z",
        "version": 1,
        "status": "locked_validation",
        "runtimeContext": {
          "operatorRole": "controller",
          "authorityScope": "single_site",
          "activeSiteIds": ["site_ms_vallee"],
          "viewportProfile": "desktop_standard",
          "sessionMode": "fresh_entry",
          "currentTime": "2026-03-30T20:30:00+02:00",
          "timezone": "Africa/Johannesburg"
        },
        "seedState": {
          "fixtures": {
            "events": [],
            "projections": [],
            "sessions": []
          },
          "onboardingState": "none",
          "watchState": "stable",
          "dispatchState": "idle",
          "clientConversationState": "none",
          "siteStatusState": "normal"
        },
        "inputs": {
          "prompts": [],
          "inboundSignals": [],
          "telemetryInputs": [],
          "cameraInputs": [],
          "adminQueries": [],
          "clientMessages": [],
          "navigation": {
            "entryRoute": "live_operations_sequence",
            "steps": [
              {"stepId": "open_review_action"},
              {
                "stepId": "open_dispatch_handoff",
                "condition": {
                  "field": "dispatchBoard.dispatchAvailable",
                  "equals": true,
                  "otherwiseStepId": "open_track_handoff"
                }
              }
            ]
          }
        },
        "expectedOutcome": {
          "expectedRoute": "track_detailed_workspace",
          "expectedIntent": "open_live_ops_priority_sequence",
          "expectedEscalationState": "track_opened",
          "expectedProjectionChanges": [],
          "expectedDrafts": [],
          "expectedBlockedActions": [],
          "expectedUiState": {
            "surface": "live_ops_priority_sequence"
          },
          "commandBrainSnapshot": {
            "workItemId": "sequence_contract_probe_v1",
            "mode": "deterministic",
            "target": "tacticalTrack",
            "nextMoveLabel": "OPEN TACTICAL TRACK",
            "headline": "Tactical Track is the next move",
            "summary": "One next move is staged in Tactical Track.",
            "advisory": "Dispatch was unavailable, so ONYX kept the live-ops sequence moving in Tactical Track.",
            "confidence": 0.81,
            "primaryPressure": "active signal watch",
            "rationale": "Scenario replay preserved the live-ops sequence contract and applied the Track fallback when dispatch availability failed.",
            "supportingSpecialists": ["cctv", "track"],
            "contextHighlights": [
              "Track continuity held the next move after review."
            ],
            "decisionBias": {
              "source": "replayPolicy",
              "scope": "sequenceFallback",
              "preferredTarget": "tacticalTrack",
              "summary": "Dispatch was unavailable, so ONYX kept the live-ops sequence moving in Tactical Track.",
              "policySourceLabel": "scenario sequence policy"
            },
            "missingInfo": [],
            "followUpLabel": "",
            "followUpPrompt": "",
            "allowRouteExecution": true,
            "specialistAssessments": []
          },
          "commandBrainTimeline": [
            {
              "sequence": 1,
              "stage": "open_review_action",
              "note": "Review evidence staged for INC-LIVEOPS-CHAIN.",
              "snapshot": {
                "workItemId": "sequence_contract_probe_v1",
                "mode": "deterministic",
                "target": "cctvReview",
                "nextMoveLabel": "OPEN CCTV REVIEW",
                "headline": "CCTV Review is the next move",
                "summary": "One next move is staged in CCTV Review.",
                "advisory": "Review evidence is staged before the next desk opens.",
                "confidence": 0.81,
                "primaryPressure": "active signal watch",
                "rationale": "Scenario replay opened CCTV Review first to keep the next move attached to verified watch evidence.",
                "supportingSpecialists": ["cctv"],
                "contextHighlights": [
                  "Sequence replay executed CCTV review before the next desk."
                ],
                "missingInfo": [],
                "followUpLabel": "",
                "followUpPrompt": "",
                "allowRouteExecution": true,
                "specialistAssessments": []
              }
            },
            {
              "sequence": 2,
              "stage": "open_track_handoff",
              "note": "Track fallback staged after dispatch availability failed. Replay policy bias: Dispatch was unavailable, so ONYX kept the live-ops sequence moving in Tactical Track.",
              "snapshot": {
                "workItemId": "sequence_contract_probe_v1",
                "mode": "deterministic",
                "target": "tacticalTrack",
                "nextMoveLabel": "OPEN TACTICAL TRACK",
                "headline": "Tactical Track is the next move",
                "summary": "One next move is staged in Tactical Track.",
                "advisory": "Dispatch was unavailable, so ONYX kept the live-ops sequence moving in Tactical Track.",
                "confidence": 0.81,
                "primaryPressure": "active signal watch",
                "rationale": "Scenario replay preserved the live-ops sequence contract and applied the Track fallback when dispatch availability failed.",
                "supportingSpecialists": ["cctv", "track"],
                "contextHighlights": [
                  "Track continuity held the next move after review."
                ],
                "decisionBias": {
                  "source": "replayPolicy",
                  "scope": "sequenceFallback",
                  "preferredTarget": "tacticalTrack",
                  "summary": "Dispatch was unavailable, so ONYX kept the live-ops sequence moving in Tactical Track.",
                  "policySourceLabel": "scenario sequence policy"
                },
                "missingInfo": [],
                "followUpLabel": "",
                "followUpPrompt": "",
                "allowRouteExecution": true,
                "specialistAssessments": []
              }
            }
          ]
        }
      }
    ''');

      expect(definition.inputs.navigation, isNotNull);
      expect(
        definition.inputs.navigation!.entryRoute,
        'live_operations_sequence',
      );
      expect(
        definition.inputs.navigation!.steps.map((step) => step.stepId).toList(),
        ['open_review_action', 'open_dispatch_handoff'],
      );
      expect(definition.inputs.navigation!.steps.first.condition, isNull);
      expect(
        definition.inputs.navigation!.steps[1].condition?.field,
        'dispatchBoard.dispatchAvailable',
      );
      expect(definition.inputs.navigation!.steps[1].condition?.equals, isTrue);
      expect(
        definition.inputs.navigation!.steps[1].condition?.otherwiseStepId,
        'open_track_handoff',
      );
      expect(
        definition.expectedOutcome.commandBrainSnapshot?.mode,
        BrainDecisionMode.deterministic,
      );
      expect(
        definition.expectedOutcome.commandBrainSnapshot?.target.name,
        'tacticalTrack',
      );
      expect(
        definition.expectedOutcome.commandBrainSnapshot?.decisionBias?.scope,
        BrainDecisionBiasScope.sequenceFallback,
      );
      expect(definition.expectedOutcome.commandBrainTimeline, hasLength(2));
      expect(
        definition.expectedOutcome.commandBrainTimeline.first.stage,
        'open_review_action',
      );
      expect(
        definition
            .expectedOutcome
            .commandBrainTimeline
            .last
            .note,
        'Track fallback staged after dispatch availability failed. Replay policy bias: Dispatch was unavailable, so ONYX kept the live-ops sequence moving in Tactical Track.',
      );
      expect(
        definition
            .expectedOutcome
            .commandBrainTimeline
            .last
            .snapshot
            .decisionBias
            ?.source,
        BrainDecisionBiasSource.replayPolicy,
      );
      expect(
        definition
            .expectedOutcome
            .commandBrainTimeline
            .last
            .snapshot
            .target
            .name,
        'tacticalTrack',
      );
      expect(
        definition.toJson()['inputs'],
        containsPair(
          'navigation',
          containsPair('steps', [
            {'stepId': 'open_review_action'},
            {
              'stepId': 'open_dispatch_handoff',
              'condition': {
                'field': 'dispatchBoard.dispatchAvailable',
                'equals': true,
                'otherwiseStepId': 'open_track_handoff',
              },
            },
          ]),
        ),
      );
    },
  );

  test(
    'ScenarioDefinition parses specialist degradation metadata on steps',
    () {
      final definition = ScenarioDefinition.fromJsonString('''
      {
        "scenarioId": "specialist_delay_probe_v1",
        "title": "Specialist delay probe",
        "description": "Scenario navigation should parse deterministic specialist degradation metadata.",
        "category": "monitoring_watch",
        "scenarioSet": "replay",
        "tags": ["specialist_delay"],
        "author": "zaks",
        "createdAt": "2026-04-01T12:30:00Z",
        "version": 1,
        "status": "draft",
        "runtimeContext": {
          "operatorRole": "controller",
          "authorityScope": "single_site",
          "activeSiteIds": ["site_visual"],
          "viewportProfile": "desktop_standard",
          "sessionMode": "fresh_entry",
          "currentTime": "2026-03-30T20:45:00+02:00",
          "timezone": "Africa/Johannesburg"
        },
        "seedState": {
          "fixtures": {
            "events": [],
            "projections": [],
            "sessions": []
          },
          "onboardingState": "none",
          "watchState": "stable",
          "dispatchState": "idle",
          "clientConversationState": "none",
          "siteStatusState": "normal"
        },
        "inputs": {
          "prompts": [],
          "inboundSignals": [],
          "telemetryInputs": [],
          "cameraInputs": [],
          "adminQueries": [],
          "clientMessages": [],
          "navigation": {
            "entryRoute": "live_operations_sequence",
            "steps": [
              {
                "stepId": "open_review_action",
                "specialist": {
                  "name": "cctv",
                  "status": "delayed",
                  "delayMs": 45000,
                  "detail": "Live verification queue exceeded the CCTV review SLA."
                }
              }
            ]
          }
        },
        "expectedOutcome": {
          "expectedRoute": "monitoring_watch",
          "expectedIntent": "open_cctv_review_handoff",
          "expectedEscalationState": "review_opened",
          "expectedProjectionChanges": [],
          "expectedDrafts": [],
          "expectedBlockedActions": [],
          "expectedUiState": {
            "surface": "monitoring_watch_review"
          }
        }
      }
    ''');

      expect(definition.inputs.navigation, isNotNull);
      expect(definition.inputs.navigation!.steps, hasLength(1));
      final specialist = definition.inputs.navigation!.steps.single.specialist;
      expect(specialist, isNotNull);
      expect(specialist?.specialist, OnyxSpecialist.cctv);
      expect(specialist?.status, ScenarioStepSpecialistStatus.delayed);
      expect(specialist?.delayMs, 45000);
      expect(
        specialist?.detail,
        'Live verification queue exceeded the CCTV review SLA.',
      );
      expect(
        definition.toJson()['inputs'],
        containsPair(
          'navigation',
          containsPair('steps', [
            {
              'stepId': 'open_review_action',
              'specialist': {
                'name': 'cctv',
                'status': 'delayed',
                'delayMs': 45000,
                'detail':
                    'Live verification queue exceeded the CCTV review SLA.',
              },
            },
          ]),
        ),
      );
    },
  );

  test(
    'ScenarioDefinition parses signal-loss specialist fallback metadata',
    () {
      final definition = ScenarioDefinition.fromJsonString('''
      {
        "scenarioId": "specialist_signal_loss_probe_v1",
        "title": "Specialist signal loss probe",
        "description": "Scenario navigation should parse signal-loss fallback metadata.",
        "category": "monitoring_watch",
        "scenarioSet": "replay",
        "tags": ["specialist_signal_loss"],
        "author": "zaks",
        "createdAt": "2026-04-02T07:00:00Z",
        "version": 1,
        "status": "draft",
        "runtimeContext": {
          "operatorRole": "controller",
          "authorityScope": "single_site",
          "activeSiteIds": ["site_ms_vallee"],
          "viewportProfile": "desktop_standard",
          "sessionMode": "fresh_entry",
          "currentTime": "2026-03-30T20:40:00+02:00",
          "timezone": "Africa/Johannesburg"
        },
        "seedState": {
          "fixtures": {
            "events": [],
            "projections": [],
            "sessions": []
          },
          "onboardingState": "none",
          "watchState": "stable",
          "dispatchState": "idle",
          "clientConversationState": "none",
          "siteStatusState": "normal"
        },
        "inputs": {
          "prompts": [],
          "inboundSignals": [],
          "telemetryInputs": [],
          "cameraInputs": [],
          "adminQueries": [],
          "clientMessages": [],
          "navigation": {
            "entryRoute": "live_operations_sequence",
            "steps": [
              {
                "stepId": "open_review_action",
                "specialist": {
                  "name": "cctv",
                  "status": "signal_lost",
                  "detail": "Primary CCTV uplink dropped during live review handoff.",
                  "fallbackStepId": "open_track_handoff"
                }
              }
            ]
          }
        },
        "expectedOutcome": {
          "expectedRoute": "track_detailed_workspace",
          "expectedIntent": "open_track_handoff",
          "expectedEscalationState": "track_opened",
          "expectedProjectionChanges": [],
          "expectedDrafts": [],
          "expectedBlockedActions": [],
          "expectedUiState": {
            "surface": "live_ops_track_handoff"
          }
        }
      }
    ''');

      final specialist = definition.inputs.navigation!.steps.single.specialist;
      expect(specialist, isNotNull);
      expect(specialist?.specialist, OnyxSpecialist.cctv);
      expect(specialist?.status, ScenarioStepSpecialistStatus.signalLost);
      expect(
        specialist?.detail,
        'Primary CCTV uplink dropped during live review handoff.',
      );
      expect(specialist?.fallbackStepId, 'open_track_handoff');
      expect(
        definition.toJson()['inputs'],
        containsPair(
          'navigation',
          containsPair('steps', [
            {
              'stepId': 'open_review_action',
              'specialist': {
                'name': 'cctv',
                'status': 'signal_lost',
                'detail':
                    'Primary CCTV uplink dropped during live review handoff.',
                'fallbackStepId': 'open_track_handoff',
              },
            },
          ]),
        ),
      );
    },
  );

  test(
    'ScenarioDefinition parses conflicting specialist assessments on steps',
    () {
      final definition = ScenarioDefinition.fromJsonString('''
      {
        "scenarioId": "specialist_conflict_probe_v1",
        "title": "Specialist conflict probe",
        "description": "Scenario navigation should parse conflicting specialist assessments.",
        "category": "monitoring_watch",
        "scenarioSet": "replay",
        "tags": ["specialist_conflict"],
        "author": "zaks",
        "createdAt": "2026-04-02T10:45:00Z",
        "version": 1,
        "status": "draft",
        "runtimeContext": {
          "operatorRole": "controller",
          "authorityScope": "single_site",
          "activeSiteIds": ["site_visual"],
          "viewportProfile": "desktop_standard",
          "sessionMode": "fresh_entry",
          "currentTime": "2026-03-30T20:25:00+02:00",
          "timezone": "Africa/Johannesburg"
        },
        "seedState": {
          "fixtures": {
            "events": [],
            "projections": [],
            "sessions": []
          },
          "onboardingState": "none",
          "watchState": "stable",
          "dispatchState": "idle",
          "clientConversationState": "none",
          "siteStatusState": "normal"
        },
        "inputs": {
          "prompts": [],
          "inboundSignals": [],
          "telemetryInputs": [],
          "cameraInputs": [],
          "adminQueries": [],
          "clientMessages": [],
          "navigation": {
            "entryRoute": "live_operations_sequence",
            "steps": [
              {
                "stepId": "open_review_action",
                "specialistAssessments": [
                  {
                    "specialist": "cctv",
                    "sourceLabel": "scenario_replay",
                    "summary": "CCTV specialist wants live review to stay open.",
                    "recommendedTarget": "cctvReview",
                    "confidence": 0.84,
                    "priority": "high",
                    "evidence": ["Visual verification queue is ready."],
                    "missingInfo": [],
                    "allowRouteExecution": true,
                    "isHardConstraint": false
                  },
                  {
                    "specialist": "track",
                    "sourceLabel": "scenario_replay",
                    "summary": "Track specialist wants Tactical Track open immediately.",
                    "recommendedTarget": "tacticalTrack",
                    "confidence": 0.61,
                    "priority": "medium",
                    "evidence": ["Perimeter continuity is under pressure."],
                    "missingInfo": ["Fresh CCTV confirmation has not landed yet."],
                    "allowRouteExecution": true,
                    "isHardConstraint": false
                  }
                ]
              }
            ]
          }
        },
        "expectedOutcome": {
          "expectedRoute": "monitoring_watch",
          "expectedIntent": "open_cctv_review_handoff",
          "expectedEscalationState": "review_opened",
          "expectedProjectionChanges": [],
          "expectedDrafts": [],
          "expectedBlockedActions": [],
          "expectedUiState": {
            "surface": "monitoring_watch_review"
          }
        }
      }
    ''');

      final step = definition.inputs.navigation!.steps.single;
      expect(step.specialistAssessments, hasLength(2));
      expect(
        step.specialistAssessments.first.recommendedTarget,
        OnyxToolTarget.cctvReview,
      );
      expect(
        step.specialistAssessments.last.recommendedTarget,
        OnyxToolTarget.tacticalTrack,
      );
      expect(
        definition.toJson()['inputs'],
        containsPair(
          'navigation',
          containsPair('steps', [
            {
              'stepId': 'open_review_action',
              'specialistAssessments': [
                {
                  'specialist': 'cctv',
                  'sourceLabel': 'scenario_replay',
                  'summary': 'CCTV specialist wants live review to stay open.',
                  'recommendedTarget': 'cctvReview',
                  'confidence': 0.84,
                  'priority': 'high',
                  'evidence': ['Visual verification queue is ready.'],
                  'missingInfo': [],
                  'allowRouteExecution': true,
                  'isHardConstraint': false,
                },
                {
                  'specialist': 'track',
                  'sourceLabel': 'scenario_replay',
                  'summary':
                      'Track specialist wants Tactical Track open immediately.',
                  'recommendedTarget': 'tacticalTrack',
                  'confidence': 0.61,
                  'priority': 'medium',
                  'evidence': ['Perimeter continuity is under pressure.'],
                  'missingInfo': [
                    'Fresh CCTV confirmation has not landed yet.',
                  ],
                  'allowRouteExecution': true,
                  'isHardConstraint': false,
                },
              ],
            },
          ]),
        ),
      );
    },
  );
}
