import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omnix_dashboard/application/dispatch_persistence_service.dart';
import 'package:omnix_dashboard/main.dart';
import 'package:omnix_dashboard/ui/app_shell.dart';
import 'package:omnix_dashboard/ui/onyx_agent_page.dart';

import 'support/admin_route_state_harness.dart';

const _agentRouteScopeKey =
    'dashboard|CLIENT-MS-VALLEE|SITE-MS-VALLEE-RESIDENCE|none';

DateTime _agentRouteNowUtc() =>
    DateTime.parse('2026-03-31T08:32:00.000Z').toUtc();

DateTime _freshCameraBridgeCheckedAtUtc() =>
    _agentRouteNowUtc().subtract(const Duration(minutes: 5));

Future<Map<String, dynamic>> _persistedAgentScopeSessionState() async {
  final prefs = await SharedPreferences.getInstance();
  final persistedThreadSessions = prefs.getString(
    DispatchPersistenceService.onyxAgentThreadSessionStateKey,
  );
  expect(persistedThreadSessions, isNotNull);
  final decoded = jsonDecode(persistedThreadSessions!) as Map<String, dynamic>;
  final sessionsByScope =
      decoded['sessions_by_scope'] as Map<String, dynamic>;
  return (sessionsByScope[_agentRouteScopeKey] as Map<String, dynamic>);
}

Map<String, dynamic> _expectPersistedPlannerHandoffSession(
  Map<String, dynamic> sessionState, {
  required String selectedThreadId,
  int? expectedMessageCount,
}) {
  expect(sessionState['selected_thread_id'], selectedThreadId);
  expect(sessionState.containsKey('selected_thread_operator_id'), isFalse);
  expect(sessionState.containsKey('selected_thread_operator_at_utc'), isFalse);

  final threads = (sessionState['threads'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final selectedThread = threads.firstWhere(
    (thread) => thread['id'] == selectedThreadId,
  );
  final memory = selectedThread['memory'] as Map<String, dynamic>;
  expect(memory.containsKey('stale_follow_up_surface_count'), isFalse);
  expect(memory.containsKey('last_auto_follow_up_surfaced_at_utc'), isFalse);

  if (expectedMessageCount != null) {
    final messages =
        (selectedThread['messages'] as List<dynamic>).cast<Map<String, dynamic>>();
    expect(messages, hasLength(expectedMessageCount));
  }

  return sessionState;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onyx app renders the dedicated agent route', (tester) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.agent),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OnyxAgentPage), findsOneWidget);
    expect(find.byKey(const ValueKey('onyx-agent-page')), findsOneWidget);
    expect(find.text('Junior Analyst'), findsOneWidget);
    expect(
      tester.widget<OnyxAgentPage>(find.byType(OnyxAgentPage)).sourceRouteLabel,
      'Operations',
    );
    expect(
      tester.widget<OnyxAgentPage>(find.byType(OnyxAgentPage)).scopeClientId,
      'CLIENT-MS-VALLEE',
    );
    expect(
      tester.widget<OnyxAgentPage>(find.byType(OnyxAgentPage)).scopeSiteId,
      'SITE-MS-VALLEE-RESIDENCE',
    );
    expect(
      tester
          .widget<OnyxAgentPage>(find.byType(OnyxAgentPage))
          .focusIncidentReference,
      isEmpty,
    );
  });

  testWidgets(
    'onyx app persists agent thread memory and transcript after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.agent),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('onyx-agent-composer-field')),
        'Triage the active incident and stage one obvious next move',
      );
      await tester.tap(find.byKey(const ValueKey('onyx-agent-send-button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('onyx-agent-thread-memory-banner')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onyx-agent-thread-memory-thread-1')),
        findsOneWidget,
      );
      final prefs = await SharedPreferences.getInstance();
      final persistedThreadSessions = prefs.getString(
        DispatchPersistenceService.onyxAgentThreadSessionStateKey,
      );
      expect(persistedThreadSessions, isNotNull);
      expect(
        persistedThreadSessions,
        contains('Triage the active incident and stage one obvious next move'),
      );
      expect(persistedThreadSessions, contains('tacticalTrack'));
      expect(
        persistedThreadSessions,
        contains('One next move is staged in Tactical Track.'),
      );

      await tester.pumpWidget(
        OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.agent),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('onyx-agent-thread-memory-banner')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onyx-agent-thread-memory-thread-1')),
        findsOneWidget,
      );
      expect(find.text('Triage the active incident a...'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('onyx-agent-thread-memory-banner')),
          matching: find.textContaining('Last recommendation: Tactical Track.'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'onyx app restores thread rail ordering from persisted primary pressure',
    (tester) async {
      final persistedState = <String, Object?>{
        'sessions_by_scope': <String, Object?>{
          _agentRouteScopeKey: <String, Object?>{
                'version': 7,
                'thread_counter': 2,
                'selected_thread_id': 'thread-1',
                'threads': <Object?>[
                  <String, Object?>{
                    'id': 'thread-1',
                    'title': 'Signal watch',
                    'summary': 'Primary: active signal watch.',
                    'memory': <String, Object?>{
                      'last_primary_pressure': 'active signal watch',
                      'last_recommendation_summary':
                          'Keep the signal watch warm.',
                      'updated_at_utc': DateTime.utc(
                        2026,
                        3,
                        31,
                        8,
                        20,
                      ).toIso8601String(),
                    },
                    'messages': <Object?>[
                      <String, Object?>{
                        'id': 'msg-1',
                        'kind': 'agent',
                        'persona_id': 'main',
                        'headline': 'Signal watch remains open',
                        'body': 'Keep the signal watch warm.',
                        'created_at_utc': DateTime.utc(
                          2026,
                          3,
                          31,
                          8,
                          20,
                        ).toIso8601String(),
                      },
                    ],
                  },
                  <String, Object?>{
                    'id': 'thread-2',
                    'title': 'Planner maintenance hot',
                    'summary': 'Primary: planner maintenance.',
                    'memory': <String, Object?>{
                      'last_primary_pressure': 'planner maintenance',
                      'last_recommendation_summary':
                          'Planner maintenance is the top pressure.',
                      'next_follow_up_label': 'RECHECK PRIORITY RULE',
                      'next_follow_up_prompt':
                          'Recheck the priority rule and confirm whether the planner maintenance path still needs review.',
                      'pending_confirmations': <Object?>[
                        'priority rule review'
                      ],
                      'last_advisory':
                          'Planner maintenance remains the highest pressure.',
                      'updated_at_utc': _agentRouteNowUtc()
                          .subtract(const Duration(minutes: 12))
                          .toIso8601String(),
                    },
                    'messages': <Object?>[
                      <String, Object?>{
                        'id': 'msg-2',
                        'kind': 'agent',
                        'persona_id': 'policy',
                        'headline': 'Planner maintenance remains active',
                        'body': 'Keep the planner maintenance rule in view.',
                        'created_at_utc': DateTime.utc(
                          2026,
                          3,
                          31,
                          8,
                          22,
                        ).toIso8601String(),
                      },
                    ],
                  },
                ],
              },
        },
      };
      SharedPreferences.setMockInitialValues(<String, Object>{
        DispatchPersistenceService.onyxAgentThreadSessionStateKey: jsonEncode(
          persistedState,
        ),
      });
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.agent),
      );
      await tester.pumpAndSettle();

      final restoredSessionState = await _persistedAgentScopeSessionState();
      _expectPersistedPlannerHandoffSession(
        restoredSessionState,
        selectedThreadId: 'thread-2',
        expectedMessageCount: 1,
      );

      expect(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('onyx-agent-thread-thread-2')),
            )
            .dy,
        lessThan(
          tester
              .getTopLeft(
                find.byKey(const ValueKey('onyx-agent-thread-thread-1')),
              )
              .dy,
        ),
      );
      expect(find.text('Planner maintenance remains active'), findsOneWidget);
      expect(find.text('Signal watch remains open'), findsNothing);
      expect(
        find.byKey(const ValueKey('onyx-agent-restored-pressure-banner')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onyx-agent-thread-pressure-focus-thread-2')),
        findsOneWidget,
      );
      expect(
        find.text(
          'Restored over Signal watch because planner maintenance was stronger.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Restored the highest-pressure thread because planner maintenance outranked the previously saved Signal watch thread.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'onyx app restores second-look conflict telemetry into the agent route',
    (tester) async {
      final persistedState = <String, Object?>{
        'sessions_by_scope': <String, Object?>{
          'dashboard|CLIENT-MS-VALLEE|SITE-MS-VALLEE-RESIDENCE|none':
              <String, Object?>{
                'version': 1,
                'thread_counter': 1,
                'selected_thread_id': 'thread-1',
                'threads': <Object?>[
                  <String, Object?>{
                    'id': 'thread-1',
                    'title': 'Track triage disagreement',
                    'summary': 'Typed triage kept Tactical Track.',
                    'memory': <String, Object?>{
                      'last_recommended_target': 'tacticalTrack',
                      'last_recommendation_summary':
                          'One next move is staged in Tactical Track.',
                      'last_advisory':
                          'Live field posture kept Tactical Track hot.',
                      'second_look_conflict_count': 1,
                      'last_second_look_conflict_summary':
                          'OpenAI second look: kept Tactical Track over CCTV Review.',
                      'last_second_look_conflict_at_utc': DateTime.utc(
                        2026,
                        3,
                        31,
                        8,
                        8,
                      ).toIso8601String(),
                      'updated_at_utc': DateTime.utc(
                        2026,
                        3,
                        31,
                        8,
                        7,
                      ).toIso8601String(),
                    },
                    'messages': <Object?>[
                      <String, Object?>{
                        'id': 'msg-1',
                        'kind': 'agent',
                        'persona_id': 'policy',
                        'headline':
                            'Typed triage overruled the model suggestion',
                        'body':
                            'Typed triage kept Tactical Track as the active desk.',
                        'created_at_utc': DateTime.utc(
                          2026,
                          3,
                          31,
                          8,
                          8,
                        ).toIso8601String(),
                      },
                    ],
                  },
                ],
              },
        },
      };
      SharedPreferences.setMockInitialValues(<String, Object>{
        DispatchPersistenceService.onyxAgentThreadSessionStateKey: jsonEncode(
          persistedState,
        ),
      });
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.agent),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('onyx-agent-second-look-telemetry')),
        findsOneWidget,
      );
      expect(
        find.textContaining('1 second-look disagreement recorded.'),
        findsWidgets,
      );
      expect(
        find.textContaining(
          'OpenAI second look: kept Tactical Track over CCTV Review.',
        ),
        findsWidgets,
      );
      expect(
        find.byKey(const ValueKey('onyx-agent-thread-memory-thread-1')),
        findsOneWidget,
      );
      expect(find.textContaining('1 model conflict'), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app restores cross-thread planner conflict report into the agent route',
    (tester) async {
      final persistedState = <String, Object?>{
        'sessions_by_scope': <String, Object?>{
          'dashboard|CLIENT-MS-VALLEE|SITE-MS-VALLEE-RESIDENCE|none': <String, Object?>{
            'version': 2,
            'thread_counter': 2,
            'selected_thread_id': 'thread-2',
            'planner_signal_snapshot': <String, Object?>{
              'signal_counts': <String, Object?>{
                'drift:cctvReview:tacticalTrack': 2,
              },
              'captured_at_utc': DateTime.utc(
                2026,
                3,
                31,
                8,
                10,
              ).toIso8601String(),
            },
            'previous_planner_signal_snapshot': <String, Object?>{
              'signal_counts': <String, Object?>{
                'drift:cctvReview:tacticalTrack': 2,
              },
              'captured_at_utc': DateTime.utc(
                2026,
                3,
                31,
                8,
                9,
              ).toIso8601String(),
            },
            'threads': <Object?>[
              <String, Object?>{
                'id': 'thread-1',
                'title': 'Track triage disagreement',
                'summary': 'Typed triage kept Tactical Track.',
                'memory': <String, Object?>{
                  'last_recommended_target': 'tacticalTrack',
                  'second_look_conflict_count': 2,
                  'last_second_look_conflict_summary':
                      'OpenAI second look: kept Tactical Track over CCTV Review.',
                  'second_look_model_target_counts': <String, Object?>{
                    'cctvReview': 2,
                  },
                  'second_look_typed_target_counts': <String, Object?>{
                    'tacticalTrack': 2,
                  },
                  'updated_at_utc': DateTime.utc(
                    2026,
                    3,
                    31,
                    8,
                    7,
                  ).toIso8601String(),
                },
                'messages': <Object?>[
                  <String, Object?>{
                    'id': 'msg-1',
                    'kind': 'agent',
                    'persona_id': 'policy',
                    'headline': 'Typed triage overruled the model suggestion',
                    'body':
                        'Typed triage kept Tactical Track as the active desk.',
                    'created_at_utc': DateTime.utc(
                      2026,
                      3,
                      31,
                      8,
                      8,
                    ).toIso8601String(),
                  },
                ],
              },
              <String, Object?>{
                'id': 'thread-2',
                'title': 'Safety hold',
                'summary': 'Typed triage kept the route closed.',
                'memory': <String, Object?>{
                  'second_look_conflict_count': 1,
                  'last_second_look_conflict_summary':
                      'OpenAI second look: kept the route closed while the model pushed Client Comms.',
                  'second_look_model_target_counts': <String, Object?>{
                    'clientComms': 1,
                  },
                  'second_look_typed_target_counts': <String, Object?>{
                    'dispatchBoard': 1,
                  },
                  'second_look_route_closed_conflict_count': 1,
                  'updated_at_utc': DateTime.utc(
                    2026,
                    3,
                    31,
                    8,
                    9,
                  ).toIso8601String(),
                },
                'messages': <Object?>[
                  <String, Object?>{
                    'id': 'msg-2',
                    'kind': 'agent',
                    'persona_id': 'policy',
                    'headline': 'Typed triage overruled the model suggestion',
                    'body': 'Safety guardrails kept the route closed.',
                    'created_at_utc': DateTime.utc(
                      2026,
                      3,
                      31,
                      8,
                      9,
                    ).toIso8601String(),
                  },
                ],
              },
            ],
          },
        },
      };
      SharedPreferences.setMockInitialValues(<String, Object>{
        DispatchPersistenceService.onyxAgentThreadSessionStateKey: jsonEncode(
          persistedState,
        ),
      });
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.agent),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('onyx-agent-planner-conflict-report')),
        findsOneWidget,
      );
      expect(
        find.text('3 second-look disagreements across 2 threads.'),
        findsOneWidget,
      );
      expect(
        find.text('Model drifted most toward CCTV Review (2).'),
        findsOneWidget,
      );
      expect(
        find.text('Typed planner held Tactical Track most often (2).'),
        findsOneWidget,
      );
      expect(find.text('Safety kept routes closed 1 time.'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('onyx-agent-planner-route-closed-summary')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey('onyx-agent-planner-section-focus-safety-holds'),
        ),
        findsOneWidget,
      );
      expect(find.text('Focused safety hold detail.'), findsOneWidget);
      expect(find.text('CCTV Review 2'), findsOneWidget);
      expect(find.text('Client Comms 1'), findsOneWidget);
      expect(
        find.text(
          'Route safety guardrails held 1 route closed while second-look pressure disagreed.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Stabilizing: Revisit Tactical Track vs CCTV Review threshold. The model keeps asking for visual confirmation while typed triage holds field posture.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('onyx app restores planner self-tuning cues for worsening drift', (
    tester,
  ) async {
    final persistedState = <String, Object?>{
      'sessions_by_scope': <String, Object?>{
        'dashboard|CLIENT-MS-VALLEE|SITE-MS-VALLEE-RESIDENCE|none':
            <String, Object?>{
              'version': 3,
              'thread_counter': 1,
              'selected_thread_id': 'thread-1',
              'planner_backlog_scores': <String, Object?>{
                'drift:cctvReview:tacticalTrack': 2,
              },
              'planner_signal_snapshot': <String, Object?>{
                'signal_counts': <String, Object?>{
                  'drift:cctvReview:tacticalTrack': 3,
                },
                'captured_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  12,
                ).toIso8601String(),
              },
              'previous_planner_signal_snapshot': <String, Object?>{
                'signal_counts': <String, Object?>{
                  'drift:cctvReview:tacticalTrack': 2,
                },
                'captured_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  11,
                ).toIso8601String(),
              },
              'threads': <Object?>[
                <String, Object?>{
                  'id': 'thread-1',
                  'title': 'Track drift warning',
                  'summary': 'Typed triage kept Tactical Track.',
                  'memory': <String, Object?>{
                    'last_recommended_target': 'tacticalTrack',
                    'second_look_conflict_count': 3,
                    'last_second_look_conflict_summary':
                        'OpenAI second look: kept Tactical Track over CCTV Review.',
                    'second_look_model_target_counts': <String, Object?>{
                      'cctvReview': 3,
                    },
                    'second_look_typed_target_counts': <String, Object?>{
                      'tacticalTrack': 3,
                    },
                    'updated_at_utc': DateTime.utc(
                      2026,
                      3,
                      31,
                      8,
                      12,
                    ).toIso8601String(),
                  },
                  'messages': <Object?>[
                    <String, Object?>{
                      'id': 'msg-1',
                      'kind': 'agent',
                      'persona_id': 'policy',
                      'headline': 'Typed triage overruled the model suggestion',
                      'body':
                          'Typed triage kept Tactical Track as the active desk.',
                      'created_at_utc': DateTime.utc(
                        2026,
                        3,
                        31,
                        8,
                        12,
                      ).toIso8601String(),
                    },
                  ],
                },
              ],
            },
      },
    };
    SharedPreferences.setMockInitialValues(<String, Object>{
      DispatchPersistenceService.onyxAgentThreadSessionStateKey: jsonEncode(
        persistedState,
      ),
    });
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.agent),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Tune now: Increase Tactical Track weighting when field posture is already live and CCTV is still only a confirmation step.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Priority 2 · hot now · Increase Tactical Track weighting when field posture is already live and CCTV is still only a confirmation step.',
      ),
      findsOneWidget,
    );
    final tuningCueShortcut = find.byKey(
      const ValueKey(
        'onyx-agent-planner-tuning-cue-drift-cctvReview-tacticalTrack',
      ),
    );
    await tester.ensureVisible(tuningCueShortcut);
    await tester.pumpAndSettle();
    await tester.tap(tuningCueShortcut);
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey(
          'onyx-agent-planner-backlog-focus-drift-cctvReview-tacticalTrack',
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('Focused from planner tuning cue.'), findsOneWidget);
  });

  testWidgets(
    'onyx app restores planner backlog review statuses and suppresses tuning cues after restart',
    (tester) async {
      final persistedState = <String, Object?>{
        'sessions_by_scope': <String, Object?>{
          'dashboard|CLIENT-MS-VALLEE|SITE-MS-VALLEE-RESIDENCE|none':
              <String, Object?>{
                'version': 4,
                'thread_counter': 1,
                'selected_thread_id': 'thread-1',
                'planner_backlog_scores': <String, Object?>{
                  'drift:cctvReview:tacticalTrack': 2,
                },
                'planner_backlog_review_statuses': <String, Object?>{
                  'drift:cctvReview:tacticalTrack': 'muted',
                },
                'planner_signal_snapshot': <String, Object?>{
                  'signal_counts': <String, Object?>{
                    'drift:cctvReview:tacticalTrack': 3,
                  },
                  'captured_at_utc': DateTime.utc(
                    2026,
                    3,
                    31,
                    8,
                    12,
                  ).toIso8601String(),
                },
                'previous_planner_signal_snapshot': <String, Object?>{
                  'signal_counts': <String, Object?>{
                    'drift:cctvReview:tacticalTrack': 2,
                  },
                  'captured_at_utc': DateTime.utc(
                    2026,
                    3,
                    31,
                    8,
                    11,
                  ).toIso8601String(),
                },
                'threads': <Object?>[
                  <String, Object?>{
                    'id': 'thread-1',
                    'title': 'Track drift warning',
                    'summary': 'Typed triage kept Tactical Track.',
                    'memory': <String, Object?>{
                      'last_recommended_target': 'tacticalTrack',
                      'second_look_conflict_count': 3,
                      'last_second_look_conflict_summary':
                          'OpenAI second look: kept Tactical Track over CCTV Review.',
                      'second_look_model_target_counts': <String, Object?>{
                        'cctvReview': 3,
                      },
                      'second_look_typed_target_counts': <String, Object?>{
                        'tacticalTrack': 3,
                      },
                      'updated_at_utc': DateTime.utc(
                        2026,
                        3,
                        31,
                        8,
                        12,
                      ).toIso8601String(),
                    },
                    'messages': <Object?>[
                      <String, Object?>{
                        'id': 'msg-1',
                        'kind': 'agent',
                        'persona_id': 'policy',
                        'headline':
                            'Typed triage overruled the model suggestion',
                        'body':
                            'Typed triage kept Tactical Track as the active desk.',
                        'created_at_utc': DateTime.utc(
                          2026,
                          3,
                          31,
                          8,
                          12,
                        ).toIso8601String(),
                      },
                    ],
                  },
                ],
              },
        },
      };
      SharedPreferences.setMockInitialValues(<String, Object>{
        DispatchPersistenceService.onyxAgentThreadSessionStateKey: jsonEncode(
          persistedState,
        ),
      });
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.agent),
      );
      await tester.pumpAndSettle();

      expect(find.text('SELF-TUNING CUES'), findsNothing);
      expect(
        find.text(
          'Tune now: Increase Tactical Track weighting when field posture is already live and CCTV is still only a confirmation step.',
        ),
        findsNothing,
      );
      expect(find.text('CHANGE NEXT'), findsOneWidget);
      expect(find.text('MUTED'), findsOneWidget);
      expect(
        find.text(
          'Priority 2 · hot now · Increase Tactical Track weighting when field posture is already live and CCTV is still only a confirmation step.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'onyx app keeps archived planner backlog items hidden after restart',
    (tester) async {
      final persistedState = <String, Object?>{
        'sessions_by_scope': <String, Object?>{
          'dashboard|CLIENT-MS-VALLEE|SITE-MS-VALLEE-RESIDENCE|none':
              <String, Object?>{
                'version': 5,
                'thread_counter': 1,
                'selected_thread_id': 'thread-1',
                'planner_backlog_archived_signal_counts': <String, Object?>{
                  'drift:cctvReview:tacticalTrack': 3,
                },
                'planner_signal_snapshot': <String, Object?>{
                  'signal_counts': <String, Object?>{
                    'drift:cctvReview:tacticalTrack': 3,
                  },
                  'captured_at_utc': DateTime.utc(
                    2026,
                    3,
                    31,
                    8,
                    12,
                  ).toIso8601String(),
                },
                'previous_planner_signal_snapshot': <String, Object?>{
                  'signal_counts': <String, Object?>{
                    'drift:cctvReview:tacticalTrack': 2,
                  },
                  'captured_at_utc': DateTime.utc(
                    2026,
                    3,
                    31,
                    8,
                    11,
                  ).toIso8601String(),
                },
                'threads': <Object?>[
                  <String, Object?>{
                    'id': 'thread-1',
                    'title': 'Track drift warning',
                    'summary': 'Typed triage kept Tactical Track.',
                    'memory': <String, Object?>{
                      'last_recommended_target': 'tacticalTrack',
                      'second_look_conflict_count': 3,
                      'last_second_look_conflict_summary':
                          'OpenAI second look: kept Tactical Track over CCTV Review.',
                      'second_look_model_target_counts': <String, Object?>{
                        'cctvReview': 3,
                      },
                      'second_look_typed_target_counts': <String, Object?>{
                        'tacticalTrack': 3,
                      },
                      'updated_at_utc': DateTime.utc(
                        2026,
                        3,
                        31,
                        8,
                        12,
                      ).toIso8601String(),
                    },
                    'messages': <Object?>[
                      <String, Object?>{
                        'id': 'msg-1',
                        'kind': 'agent',
                        'persona_id': 'policy',
                        'headline':
                            'Typed triage overruled the model suggestion',
                        'body':
                            'Typed triage kept Tactical Track as the active desk.',
                        'created_at_utc': DateTime.utc(
                          2026,
                          3,
                          31,
                          8,
                          12,
                        ).toIso8601String(),
                      },
                    ],
                  },
                ],
              },
        },
      };
      SharedPreferences.setMockInitialValues(<String, Object>{
        DispatchPersistenceService.onyxAgentThreadSessionStateKey: jsonEncode(
          persistedState,
        ),
      });
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.agent),
      );
      await tester.pumpAndSettle();

      expect(find.text('SELF-TUNING CUES'), findsNothing);
      expect(find.text('CHANGE NEXT'), findsNothing);
      expect(
        find.text('1 reviewed item is archived until the drift worsens again.'),
        findsOneWidget,
      );
      final archivedSummaryShortcut = find.byKey(
        const ValueKey('onyx-agent-planner-archived-summary'),
      );
      await tester.ensureVisible(archivedSummaryShortcut);
      await tester.pumpAndSettle();
      await tester.tap(archivedSummaryShortcut);
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey(
            'onyx-agent-planner-archived-focus-drift-cctvReview-tacticalTrack',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Focused archived rule bucket.'), findsOneWidget);
      expect(find.text('ARCHIVED WATCH'), findsOneWidget);
    },
  );

  testWidgets('onyx app restores planner reactivation notices after restart', (
    tester,
  ) async {
    final reactivatedAt = _agentRouteNowUtc();
    final reviewQueuedAt = reactivatedAt.add(const Duration(minutes: 3));
    final persistedState = <String, Object?>{
      'sessions_by_scope': <String, Object?>{
        'dashboard|CLIENT-MS-VALLEE|SITE-MS-VALLEE-RESIDENCE|none':
            <String, Object?>{
              'version': 7,
              'thread_counter': 1,
              'selected_thread_id': 'thread-1',
              'planner_backlog_scores': <String, Object?>{
                'drift:cctvReview:tacticalTrack': 2,
              },
              'planner_backlog_reactivated_signal_counts': <String, Object?>{
                'drift:cctvReview:tacticalTrack': 2,
              },
              'planner_backlog_reactivation_counts': <String, Object?>{
                'drift:cctvReview:tacticalTrack': 4,
              },
              'planner_backlog_last_reactivated_at_utc': <String, Object?>{
                'drift:cctvReview:tacticalTrack': reactivatedAt
                    .toIso8601String(),
              },
              'planner_maintenance_review_queued_at_utc': <String, Object?>{
                'drift:cctvReview:tacticalTrack': reviewQueuedAt
                    .toIso8601String(),
              },
              'planner_signal_snapshot': <String, Object?>{
                'signal_counts': <String, Object?>{
                  'drift:cctvReview:tacticalTrack': 3,
                },
                'captured_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  12,
                ).toIso8601String(),
              },
              'previous_planner_signal_snapshot': <String, Object?>{
                'signal_counts': <String, Object?>{
                  'drift:cctvReview:tacticalTrack': 2,
                },
                'captured_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  11,
                ).toIso8601String(),
              },
              'threads': <Object?>[
                <String, Object?>{
                  'id': 'thread-1',
                  'title': 'Track drift warning',
                  'summary': 'Typed triage kept Tactical Track.',
                  'memory': <String, Object?>{
                    'last_recommended_target': 'tacticalTrack',
                    'second_look_conflict_count': 3,
                    'last_second_look_conflict_summary':
                        'OpenAI second look: kept Tactical Track over CCTV Review.',
                    'second_look_model_target_counts': <String, Object?>{
                      'cctvReview': 3,
                    },
                    'second_look_typed_target_counts': <String, Object?>{
                      'tacticalTrack': 3,
                    },
                    'updated_at_utc': DateTime.utc(
                      2026,
                      3,
                      31,
                      8,
                      12,
                    ).toIso8601String(),
                  },
                  'messages': <Object?>[
                    <String, Object?>{
                      'id': 'msg-1',
                      'kind': 'agent',
                      'persona_id': 'policy',
                      'headline': 'Typed triage overruled the model suggestion',
                      'body':
                          'Typed triage kept Tactical Track as the active desk.',
                      'created_at_utc': DateTime.utc(
                        2026,
                        3,
                        31,
                        8,
                        12,
                      ).toIso8601String(),
                    },
                  ],
                },
              ],
            },
      },
    };
    SharedPreferences.setMockInitialValues(<String, Object>{
      DispatchPersistenceService.onyxAgentThreadSessionStateKey: jsonEncode(
        persistedState,
      ),
    });
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.agent),
    );
    await tester.pumpAndSettle();

    expect(find.text('REACTIVATED'), findsOneWidget);
    expect(
      find.textContaining(
        'Reactivated from archive: Increase Tactical Track weighting when field posture is already live and CCTV is still only a confirmation step. returned after drift worsened from 2 to 3.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        '1 planner maintenance alert active. Highest severity: chronic drift from archived watch.',
      ),
      findsOneWidget,
    );
    expect(find.text('MAINTENANCE ALERTS'), findsOneWidget);
    expect(find.text('RULE REVIEW QUEUED'), findsOneWidget);
    expect(
      find.textContaining(
        'Maintenance alert: Chronic drift from archived watch on Increase Tactical Track weighting when field posture is already live and CCTV is still only a confirmation step.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Rule review is queued.'), findsOneWidget);
    expect(find.textContaining('Queued for rule review:'), findsOneWidget);
    expect(find.text('Clear review mark'), findsOneWidget);
    expect(find.text('FROM ARCHIVE'), findsOneWidget);
    expect(
      find.text(
        'Archive lineage: escalated from archived watch after drift rose from 2 to 3.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Severity: chronic drift.'), findsOneWidget);
    expect(find.textContaining('Reactivation count: 4.'), findsOneWidget);
    expect(find.textContaining('Last reactivated:'), findsOneWidget);
    expect(find.text('CHANGE NEXT'), findsOneWidget);
    final lineageButton = find.byKey(
      const ValueKey(
        'onyx-agent-planner-maintenance-lineage-drift-cctvReview-tacticalTrack',
      ),
    );
    await tester.ensureVisible(lineageButton);
    await tester.pumpAndSettle();
    await tester.tap(lineageButton);
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey(
          'onyx-agent-planner-reactivation-focus-drift-cctvReview-tacticalTrack',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.text('Focused archive lineage from maintenance alert.'),
      findsOneWidget,
    );
    final reactivatedShortcut = find.byKey(
      const ValueKey(
        'onyx-agent-planner-reactivated-drift-cctvReview-tacticalTrack',
      ),
    );
    await tester.ensureVisible(reactivatedShortcut);
    await tester.pumpAndSettle();
    await tester.tap(reactivatedShortcut);
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey(
          'onyx-agent-planner-maintenance-focus-drift-cctvReview-tacticalTrack',
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('Focused from reactivated rule.'), findsOneWidget);
  });

  testWidgets('onyx app restores completed planner maintenance reviews after restart', (
    tester,
  ) async {
    final reactivatedAt = _agentRouteNowUtc();
    final reviewQueuedAt = reactivatedAt.add(const Duration(minutes: 2));
    final reviewCompletedAt = reviewQueuedAt.add(const Duration(minutes: 4));
    final persistedState = <String, Object?>{
      'sessions_by_scope': <String, Object?>{
        'dashboard|CLIENT-MS-VALLEE|SITE-MS-VALLEE-RESIDENCE|none':
            <String, Object?>{
              'version': 7,
              'thread_counter': 1,
              'selected_thread_id': 'thread-1',
              'planner_backlog_scores': <String, Object?>{
                'drift:cctvReview:tacticalTrack': 2,
              },
              'planner_backlog_reactivated_signal_counts': <String, Object?>{
                'drift:cctvReview:tacticalTrack': 2,
              },
              'planner_backlog_reactivation_counts': <String, Object?>{
                'drift:cctvReview:tacticalTrack': 4,
              },
              'planner_backlog_last_reactivated_at_utc': <String, Object?>{
                'drift:cctvReview:tacticalTrack': reactivatedAt
                    .toIso8601String(),
              },
              'planner_maintenance_review_queued_at_utc': <String, Object?>{
                'drift:cctvReview:tacticalTrack': reviewQueuedAt
                    .toIso8601String(),
              },
              'planner_maintenance_review_completed_at_utc': <String, Object?>{
                'drift:cctvReview:tacticalTrack': reviewCompletedAt
                    .toIso8601String(),
              },
              'planner_signal_snapshot': <String, Object?>{
                'signal_counts': <String, Object?>{
                  'drift:cctvReview:tacticalTrack': 3,
                },
                'captured_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  12,
                ).toIso8601String(),
              },
              'previous_planner_signal_snapshot': <String, Object?>{
                'signal_counts': <String, Object?>{
                  'drift:cctvReview:tacticalTrack': 2,
                },
                'captured_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  11,
                ).toIso8601String(),
              },
              'threads': <Object?>[
                <String, Object?>{
                  'id': 'thread-1',
                  'title': 'Track drift warning',
                  'summary': 'Typed triage kept Tactical Track.',
                  'memory': <String, Object?>{
                    'last_recommended_target': 'tacticalTrack',
                    'second_look_conflict_count': 3,
                    'last_second_look_conflict_summary':
                        'OpenAI second look: kept Tactical Track over CCTV Review.',
                    'second_look_model_target_counts': <String, Object?>{
                      'cctvReview': 3,
                    },
                    'second_look_typed_target_counts': <String, Object?>{
                      'tacticalTrack': 3,
                    },
                    'updated_at_utc': DateTime.utc(
                      2026,
                      3,
                      31,
                      8,
                      12,
                    ).toIso8601String(),
                  },
                  'messages': <Object?>[
                    <String, Object?>{
                      'id': 'msg-1',
                      'kind': 'agent',
                      'persona_id': 'policy',
                      'headline': 'Typed triage overruled the model suggestion',
                      'body':
                          'Typed triage kept Tactical Track as the active desk.',
                      'created_at_utc': DateTime.utc(
                        2026,
                        3,
                        31,
                        8,
                        12,
                      ).toIso8601String(),
                    },
                  ],
                },
              ],
            },
      },
    };
    SharedPreferences.setMockInitialValues(<String, Object>{
      DispatchPersistenceService.onyxAgentThreadSessionStateKey: jsonEncode(
        persistedState,
      ),
    });
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.agent),
    );
    await tester.pumpAndSettle();

    expect(find.text('MAINTENANCE ALERTS'), findsOneWidget);
    expect(
      find.text(
        '1 planner maintenance review completed. Chronic drift from archived watch is still tracked.',
      ),
      findsOneWidget,
    );
    expect(find.text('REVIEW COMPLETED'), findsOneWidget);
    expect(
      find.textContaining(
        'Maintenance review completed for chronic drift from archived watch on Increase Tactical Track weighting when field posture is already live and CCTV is still only a confirmation step.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Queued for rule review:'), findsOneWidget);
    expect(find.textContaining('Review completed:'), findsOneWidget);
    expect(find.text('Reopen review'), findsOneWidget);
  });

  testWidgets('onyx app restores reopened planner maintenance reviews after restart', (
    tester,
  ) async {
    final reactivatedAt = _agentRouteNowUtc();
    final reviewCompletedAt = reactivatedAt.add(const Duration(minutes: 4));
    final reviewReopenedAt = reviewCompletedAt.add(const Duration(minutes: 6));
    final persistedState = <String, Object?>{
      'sessions_by_scope': <String, Object?>{
        'dashboard|CLIENT-MS-VALLEE|SITE-MS-VALLEE-RESIDENCE|none':
            <String, Object?>{
              'version': 7,
              'thread_counter': 1,
              'selected_thread_id': 'thread-1',
              'planner_backlog_scores': <String, Object?>{
                'drift:cctvReview:tacticalTrack': 2,
              },
              'planner_backlog_reactivated_signal_counts': <String, Object?>{
                'drift:cctvReview:tacticalTrack': 2,
              },
              'planner_backlog_reactivation_counts': <String, Object?>{
                'drift:cctvReview:tacticalTrack': 4,
              },
              'planner_backlog_last_reactivated_at_utc': <String, Object?>{
                'drift:cctvReview:tacticalTrack': reactivatedAt
                    .toIso8601String(),
              },
              'planner_maintenance_review_queued_at_utc': <String, Object?>{
                'drift:cctvReview:tacticalTrack': reviewReopenedAt
                    .toIso8601String(),
              },
              'planner_maintenance_review_completed_at_utc': <String, Object?>{
                'drift:cctvReview:tacticalTrack': reviewCompletedAt
                    .toIso8601String(),
              },
              'planner_maintenance_review_completed_signal_counts':
                  <String, Object?>{'drift:cctvReview:tacticalTrack': 3},
              'planner_maintenance_review_completed_reactivation_counts':
                  <String, Object?>{'drift:cctvReview:tacticalTrack': 4},
              'planner_maintenance_review_reopened_counts': <String, Object?>{
                'drift:cctvReview:tacticalTrack': 2,
              },
              'planner_signal_snapshot': <String, Object?>{
                'signal_counts': <String, Object?>{
                  'drift:cctvReview:tacticalTrack': 4,
                },
                'captured_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  18,
                ).toIso8601String(),
              },
              'previous_planner_signal_snapshot': <String, Object?>{
                'signal_counts': <String, Object?>{
                  'drift:cctvReview:tacticalTrack': 3,
                },
                'captured_at_utc': DateTime.utc(
                  2026,
                  3,
                  31,
                  8,
                  12,
                ).toIso8601String(),
              },
              'threads': <Object?>[
                <String, Object?>{
                  'id': 'thread-1',
                  'title': 'Client reassurance',
                  'summary': 'No urgent planner drift on this thread.',
                  'memory': <String, Object?>{
                    'last_recommended_target': 'clientComms',
                    'updated_at_utc': DateTime.utc(
                      2026,
                      3,
                      31,
                      8,
                      10,
                    ).toIso8601String(),
                  },
                  'messages': <Object?>[
                    <String, Object?>{
                      'id': 'msg-0',
                      'kind': 'agent',
                      'persona_id': 'main',
                      'headline': 'Client reassurance ready',
                      'body':
                          'No operational drift is attached to this thread.',
                      'created_at_utc': DateTime.utc(
                        2026,
                        3,
                        31,
                        8,
                        10,
                      ).toIso8601String(),
                    },
                  ],
                },
                <String, Object?>{
                  'id': 'thread-2',
                  'title': 'Track drift warning',
                  'summary': 'Typed triage kept Tactical Track.',
                  'memory': <String, Object?>{
                    'last_recommended_target': 'tacticalTrack',
                    'second_look_conflict_count': 4,
                    'last_second_look_conflict_summary':
                        'OpenAI second look: kept Tactical Track over CCTV Review.',
                    'second_look_model_target_counts': <String, Object?>{
                      'cctvReview': 4,
                    },
                    'second_look_typed_target_counts': <String, Object?>{
                      'tacticalTrack': 4,
                    },
                    'updated_at_utc': DateTime.utc(
                      2026,
                      3,
                      31,
                      8,
                      18,
                    ).toIso8601String(),
                  },
                  'messages': <Object?>[
                    <String, Object?>{
                      'id': 'msg-1',
                      'kind': 'agent',
                      'persona_id': 'policy',
                      'headline': 'Typed triage overruled the model suggestion',
                      'body':
                          'Typed triage kept Tactical Track as the active desk.',
                      'created_at_utc': DateTime.utc(
                        2026,
                        3,
                        31,
                        8,
                        18,
                      ).toIso8601String(),
                    },
                  ],
                },
              ],
            },
      },
    };
    SharedPreferences.setMockInitialValues(<String, Object>{
      DispatchPersistenceService.onyxAgentThreadSessionStateKey: jsonEncode(
        persistedState,
      ),
    });
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.agent),
    );
    await tester.pumpAndSettle();

    expect(find.text('MAINTENANCE ALERTS'), findsOneWidget);
    expect(
      find.text(
        '1 planner maintenance alert active. Highest severity: chronic drift from archived watch. Top burn rate: review reopened 2 times.',
      ),
      findsOneWidget,
    );
    expect(find.text('HIGHEST BURN'), findsOneWidget);
    expect(
      find.textContaining(
        'Most regressed rule: Increase Tactical Track weighting when field posture is already live and CCTV is still only a confirmation step from archived watch reopened after review 2 times.',
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('onyx-agent-planner-most-regressed-rule')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey(
          'onyx-agent-planner-maintenance-focus-drift-cctvReview-tacticalTrack',
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('Focused from planner summary.'), findsOneWidget);
    expect(find.text('REVIEW REOPENED'), findsOneWidget);
    expect(find.text('Prioritize review now'), findsOneWidget);
    expect(
      find.textContaining('has gone stale after the drift worsened again.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Review reopened after worsening:'),
      findsOneWidget,
    );
    expect(find.textContaining('Review completed:'), findsOneWidget);
    expect(
      find.textContaining(
        'Review reopened after completion 2 times. Rule keeps regressing after repeated review cycles.',
      ),
      findsOneWidget,
    );
    expect(find.text('Mark review completed'), findsOneWidget);
  });

  testWidgets(
    'onyx app restores prioritized highest-burn maintenance reviews after restart',
    (tester) async {
      final reactivatedAt = _agentRouteNowUtc();
      final reviewCompletedAt = reactivatedAt.add(const Duration(minutes: 4));
      final reviewReopenedAt = reviewCompletedAt.add(
        const Duration(minutes: 6),
      );
      final prioritizedAt = reviewReopenedAt.add(const Duration(minutes: 1));
      final persistedState = <String, Object?>{
        'sessions_by_scope': <String, Object?>{
          _agentRouteScopeKey: <String, Object?>{
                'version': 7,
                'thread_counter': 1,
                'selected_thread_id': 'thread-1',
                'planner_backlog_scores': <String, Object?>{
                  'drift:cctvReview:tacticalTrack': 2,
                },
                'planner_backlog_reactivated_signal_counts': <String, Object?>{
                  'drift:cctvReview:tacticalTrack': 2,
                },
                'planner_backlog_reactivation_counts': <String, Object?>{
                  'drift:cctvReview:tacticalTrack': 4,
                },
                'planner_backlog_last_reactivated_at_utc': <String, Object?>{
                  'drift:cctvReview:tacticalTrack': reactivatedAt
                      .toIso8601String(),
                },
                'planner_maintenance_review_queued_at_utc': <String, Object?>{
                  'drift:cctvReview:tacticalTrack': reviewReopenedAt
                      .toIso8601String(),
                },
                'planner_maintenance_review_completed_at_utc':
                    <String, Object?>{
                      'drift:cctvReview:tacticalTrack': reviewCompletedAt
                          .toIso8601String(),
                    },
                'planner_maintenance_review_prioritized_at_utc':
                    <String, Object?>{
                      'drift:cctvReview:tacticalTrack': prioritizedAt
                          .toIso8601String(),
                    },
                'planner_maintenance_review_completed_signal_counts':
                    <String, Object?>{'drift:cctvReview:tacticalTrack': 3},
                'planner_maintenance_review_completed_reactivation_counts':
                    <String, Object?>{'drift:cctvReview:tacticalTrack': 4},
                'planner_maintenance_review_reopened_counts': <String, Object?>{
                  'drift:cctvReview:tacticalTrack': 2,
                },
                'planner_signal_snapshot': <String, Object?>{
                  'signal_counts': <String, Object?>{
                    'drift:cctvReview:tacticalTrack': 4,
                  },
                  'captured_at_utc': DateTime.utc(
                    2026,
                    3,
                    31,
                    8,
                    18,
                  ).toIso8601String(),
                },
                'previous_planner_signal_snapshot': <String, Object?>{
                  'signal_counts': <String, Object?>{
                    'drift:cctvReview:tacticalTrack': 3,
                  },
                  'captured_at_utc': DateTime.utc(
                    2026,
                    3,
                    31,
                    8,
                    12,
                  ).toIso8601String(),
                },
                'threads': <Object?>[
                  <String, Object?>{
                    'id': 'thread-1',
                    'title': 'Client reassurance',
                    'summary': 'No urgent planner drift on this thread.',
                    'memory': <String, Object?>{
                      'last_recommended_target': 'clientComms',
                      'updated_at_utc': DateTime.utc(
                        2026,
                        3,
                        31,
                        8,
                        10,
                      ).toIso8601String(),
                    },
                    'messages': <Object?>[
                      <String, Object?>{
                        'id': 'msg-0',
                        'kind': 'agent',
                        'persona_id': 'main',
                        'headline': 'Client reassurance ready',
                        'body':
                            'No operational drift is attached to this thread.',
                        'created_at_utc': DateTime.utc(
                          2026,
                          3,
                          31,
                          8,
                          10,
                        ).toIso8601String(),
                      },
                    ],
                  },
                  <String, Object?>{
                    'id': 'thread-2',
                    'title': 'Track drift warning',
                    'summary': 'Typed triage kept Tactical Track.',
                    'memory': <String, Object?>{
                      'last_primary_pressure': 'overdue follow-up',
                      'last_recommended_target': 'tacticalTrack',
                      'second_look_conflict_count': 4,
                      'last_second_look_conflict_summary':
                          'OpenAI second look: kept Tactical Track over CCTV Review.',
                      'second_look_model_target_counts': <String, Object?>{
                        'cctvReview': 4,
                      },
                      'second_look_typed_target_counts': <String, Object?>{
                        'tacticalTrack': 4,
                      },
                      'next_follow_up_label': 'RECHECK RESPONDER ETA',
                      'next_follow_up_prompt':
                          'Check the responder ETA and confirm whether dispatch has arrived.',
                      'pending_confirmations': <Object?>['responder ETA'],
                      'last_advisory': 'Response delay detected.',
                      'updated_at_utc': _agentRouteNowUtc()
                          .subtract(const Duration(minutes: 12))
                          .toIso8601String(),
                    },
                    'messages': <Object?>[
                      <String, Object?>{
                        'id': 'msg-1',
                        'kind': 'agent',
                        'persona_id': 'policy',
                        'headline':
                            'Typed triage overruled the model suggestion',
                        'body':
                            'Typed triage kept Tactical Track as the active desk.',
                        'created_at_utc': DateTime.utc(
                          2026,
                          3,
                          31,
                          8,
                          18,
                        ).toIso8601String(),
                      },
                    ],
                  },
                ],
              },
        },
      };
      SharedPreferences.setMockInitialValues(<String, Object>{
        DispatchPersistenceService.onyxAgentThreadSessionStateKey: jsonEncode(
          persistedState,
        ),
      });
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.agent),
      );
      await tester.pumpAndSettle();

      final restoredSessionState = await _persistedAgentScopeSessionState();
      _expectPersistedPlannerHandoffSession(
        restoredSessionState,
        selectedThreadId: 'thread-2',
        expectedMessageCount: 1,
      );

      expect(find.text('MAINTENANCE ALERTS'), findsOneWidget);
      expect(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('onyx-agent-thread-thread-2')),
            )
            .dy,
        lessThan(
          tester
              .getTopLeft(
                find.byKey(const ValueKey('onyx-agent-thread-thread-1')),
              )
              .dy,
        ),
      );
      expect(find.text('URGENT REVIEW'), findsOneWidget);
      expect(
        find.text('Typed triage overruled the model suggestion'),
        findsOneWidget,
      );
      expect(find.text('Client reassurance ready'), findsNothing);
      expect(
        find.byKey(const ValueKey('onyx-agent-thread-urgent-reason-thread-2')),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Urgent rule: Increase Tactical Track weighting when field posture is already live and CCTV is still only a confirmation step • chronic drift • review reopened 2 times',
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('onyx-agent-thread-urgent-reason-thread-2')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey(
            'onyx-agent-planner-maintenance-focus-drift-cctvReview-tacticalTrack',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Focused from the thread rail.'), findsOneWidget);
      expect(
        find.text(
          '1 planner maintenance alert active. Highest severity: chronic drift from archived watch. Top burn rate: review reopened 2 times. Urgent review active.',
        ),
        findsOneWidget,
      );
      expect(find.text('OPERATOR FOCUS'), findsNothing);
      expect(
        find.byKey(const ValueKey('onyx-agent-operator-focus-banner')),
        findsNothing,
      );
      expect(find.text('HIGHEST BURN'), findsOneWidget);
      expect(find.text('URGENT MAINTENANCE'), findsOneWidget);
      expect(
        find.textContaining('Urgent maintenance prioritized:'),
        findsOneWidget,
      );
      expect(find.text('Refresh priority'), findsOneWidget);
      expect(find.text('Mark review completed'), findsOneWidget);
    },
  );

  testWidgets(
    'onyx app restores camera bridge health receipt into the agent route',
    (tester) async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      await saveTelegramAdminRuntimeState({
        'camera_bridge_health_snapshot': <String, Object?>{
          'requested_endpoint': 'http://127.0.0.1:11634',
          'health_endpoint': 'http://127.0.0.1:11634/health',
          'reported_endpoint': 'http://127.0.0.1:11634',
          'reachable': true,
          'running': true,
          'status_code': 200,
          'status_label': 'Healthy',
          'detail':
              'GET /health succeeded and the bridge reported packet ingress ready.',
          'execute_path': '/execute',
          'checked_at_utc': _freshCameraBridgeCheckedAtUtc().toIso8601String(),
          'operator_id': 'CONTROL-11',
        },
      });
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.agent),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('onyx-agent-camera-bridge-health-result')),
        findsOneWidget,
      );
      expect(find.text('HEALTHY'), findsOneWidget);
      expect(find.textContaining('Validated by: CONTROL-11'), findsOneWidget);
      expect(
        find.textContaining('POST http://127.0.0.1:11634/execute'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'onyx app clears camera bridge health receipt from the agent route and keeps it cleared after restart',
    (tester) async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      await saveTelegramAdminRuntimeState({
        'camera_bridge_health_snapshot': <String, Object?>{
          'requested_endpoint': 'http://127.0.0.1:11634',
          'health_endpoint': 'http://127.0.0.1:11634/health',
          'reported_endpoint': 'http://127.0.0.1:11634',
          'reachable': true,
          'running': true,
          'status_code': 200,
          'status_label': 'Healthy',
          'detail':
              'GET /health succeeded and the bridge reported packet ingress ready.',
          'execute_path': '/execute',
          'checked_at_utc': _freshCameraBridgeCheckedAtUtc().toIso8601String(),
          'operator_id': 'CONTROL-22',
        },
      });
      await tester.binding.setSurfaceSize(const Size(1440, 980));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.agent),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('onyx-agent-camera-bridge-health-result')),
        findsOneWidget,
      );

      final clearBridgeReceiptButton = find.byKey(
        const ValueKey('onyx-agent-camera-bridge-clear-health'),
      );
      await tester.ensureVisible(clearBridgeReceiptButton);
      await tester.tap(clearBridgeReceiptButton);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('onyx-agent-camera-bridge-health-result')),
        findsNothing,
      );

      await tester.pumpWidget(
        OnyxApp(supabaseReady: false, initialRouteOverride: OnyxRoute.agent),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('onyx-agent-camera-bridge-health-result')),
        findsNothing,
      );
    },
  );
}
