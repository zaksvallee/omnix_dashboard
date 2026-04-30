import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../application/ai/ollama_service.dart';
import '../application/event_sourcing_service.dart';
import '../application/onyx_agent_cloud_boost_service.dart';
import '../application/runtime_config.dart';
import '../application/supabase/supabase_service.dart';
import '../application/zara/theatre/zara_action.dart';
import '../application/zara/theatre/zara_action_executor.dart';
import '../application/zara/theatre/zara_intent_parser.dart';
import '../application/zara/theatre/zara_scenario.dart';
import '../application/zara/theatre/zara_theatre_orchestrator.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/listener_alarm_advisory_recorded.dart';
import '../ui/app_shell.dart';
import '../ui/live_operations_page.dart';
import '../ui/theme/onyx_theme.dart';
import '../ui/zara_theatre_panel.dart';

const String _smokeScenarioPrefix = 'SCENARIO-SMOKE-';
const String _smokeEventPrefix = 'EVENT-SMOKE-';
const String _smokeAlarmPrefix = 'ALARM-SMOKE-';
const String _smokeClientId = String.fromEnvironment(
  'ONYX_CLIENT_ID',
  defaultValue: 'CLIENT-SMOKE-TEST',
);
const String _smokeRegionId = String.fromEnvironment(
  'ONYX_REGION_ID',
  defaultValue: 'REGION-SMOKE-TEST',
);
const String _smokeSiteId = String.fromEnvironment(
  'ONYX_SITE_ID',
  defaultValue: 'SITE-SMOKE-TEST',
);
const String _smokeSiteLabel = 'Smoke Test Site';
const String _smokeOllamaModel = String.fromEnvironment(
  'ONYX_AGENT_LOCAL_MODEL',
  defaultValue: 'mistral:7b-instruct-q5_K_M',
);
const String _smokeOllamaEndpoint = String.fromEnvironment(
  'ONYX_AGENT_LOCAL_ENDPOINT',
  defaultValue: 'http://127.0.0.1:11434',
);
const bool _allowFontRuntimeFetching = bool.fromEnvironment(
  'ONYX_ALLOW_FONT_RUNTIME_FETCHING',
  defaultValue: false,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = _allowFontRuntimeFetching;

  final launch = await _prepareSmokeLaunch();
  runApp(_ZaraTheatreSmokeApp(launch: launch));
}

class _ZaraTheatreSmokeApp extends StatefulWidget {
  final _SmokeLaunch launch;

  const _ZaraTheatreSmokeApp({required this.launch});

  @override
  State<_ZaraTheatreSmokeApp> createState() => _ZaraTheatreSmokeAppState();
}

class _ZaraTheatreSmokeAppState extends State<_ZaraTheatreSmokeApp> {
  late final http.Client _ollamaClient;
  late final ZaraTheatreOrchestrator _orchestrator;
  OnyxRoute _route = OnyxRoute.dashboard;

  @override
  void initState() {
    super.initState();
    _ollamaClient = http.Client();
    _orchestrator = ZaraTheatreOrchestrator(
      intentParser: ZaraIntentParser(
        ollamaService: _buildOllamaService(),
        cloudBoostService: const UnconfiguredOnyxAgentCloudBoostService(),
        localModel: _smokeOllamaModel.trim().isEmpty
            ? 'mistral:7b-instruct-q5_K_M'
            : _smokeOllamaModel.trim(),
      ),
      actionExecutor: _SmokeSafeZaraActionExecutor(),
      supabaseService: widget.launch.supabaseService,
      controllerUserIdProvider: () => widget.launch.controllerUserId,
    );
    _orchestrator.debugSurfaceScenario(widget.launch.scenario);
  }

  @override
  void dispose() {
    _orchestrator.dispose();
    _ollamaClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = EventSourcingService.rebuild(
      events: widget.launch.events,
      guardsOnlineCount: 0,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: OnyxTheme.dark(),
      home: AppShell(
        currentRoute: _route,
        onRouteChanged: (route) {
          setState(() {
            _route = route;
          });
        },
        activeIncidentCount: 1,
        aiActionCount: _pendingActionCount(_orchestrator.activeScenario),
        guardsOnlineCount: 0,
        operatorLabel: 'Zara Smoke',
        operatorRoleLabel: 'Controller Preview',
        operatorShiftLabel: 'SMOKE',
        complianceIssuesCount: 0,
        tacticalSosAlerts: 0,
        elevatedRiskCount: EventSourcingService.elevatedRiskSignalCount(
          widget.launch.events,
        ),
        liveAlarmCount: EventSourcingService.liveMonitoringAlarmCount(
          widget.launch.events,
        ),
        intelTickerItems: const <OnyxIntelTickerItem>[],
        incidentLifecycleSnapshot: snapshot.lifecycle,
        eventSourcingSnapshot: snapshot,
        demoAutopilotStatusLabel: widget.launch.reusedExistingScenario
            ? 'Smoke scenario reused from the latest seeded run.'
            : 'Fresh Zara Theatre smoke scenario seeded.',
        child: _buildSmokeChild(),
      ),
    );
  }

  Widget _buildSmokeChild() {
    if (_route != OnyxRoute.dashboard) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zara Theatre smoke is pinned to Command Center.',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Use the Command route in the nav rail to return to the smoke scenario. Other routes stay untouched so this harness can remain isolated.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return LiveOperationsPage(
      events: widget.launch.events,
      initialScopeClientId: _smokeClientId,
      initialScopeSiteId: _smokeSiteId,
      focusIncidentReference: widget.launch.alarmId,
      previousTomorrowUrgencySummary:
          'Smoke harness running against live Supabase.',
      theatrePanel: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        child: ZaraTheatrePanel(orchestrator: _orchestrator),
      ),
    );
  }

  OllamaService _buildOllamaService() {
    final endpoint = Uri.tryParse(_smokeOllamaEndpoint.trim());
    if (endpoint == null) {
      return const UnconfiguredOllamaService();
    }
    return HttpOllamaService(client: _ollamaClient, endpoint: endpoint);
  }

  int _pendingActionCount(ZaraScenario? scenario) {
    if (scenario == null) {
      return 0;
    }
    return scenario.proposedActions.where((action) {
      return action.state == ZaraActionState.proposed ||
          action.state == ZaraActionState.awaitingConfirmation ||
          action.state == ZaraActionState.executing ||
          action.state == ZaraActionState.autoExecuting;
    }).length;
  }
}

class _SmokeLaunch {
  final ZaraScenario scenario;
  final List<DispatchEvent> events;
  final SupabaseService supabaseService;
  final String controllerUserId;
  final bool reusedExistingScenario;
  final String alarmId;

  const _SmokeLaunch({
    required this.scenario,
    required this.events,
    required this.supabaseService,
    required this.controllerUserId,
    required this.reusedExistingScenario,
    required this.alarmId,
  });
}

class _SmokeSafeZaraActionExecutor extends ZaraActionExecutor {
  @override
  Future<ZaraActionResult> execute({
    required ZaraScenario scenario,
    required ZaraAction action,
    String draftOverride = '',
  }) async {
    final smokePayload = <String, Object?>{
      ...action.payload.toJson(),
      'smoke_mode': true,
      'scenario_id': scenario.id.value,
    };
    switch (action.kind) {
      case ZaraActionKind.checkFootage:
        const summary =
            'Smoke footage review completed. No threat detected on $_smokeSiteLabel.';
        return ZaraActionResult(
          actionId: action.id,
          outcome: ZaraActionExecutionOutcome.autoExecuted,
          success: true,
          sideEffectsSummary: summary,
          resultData: <String, Object?>{
            ...smokePayload,
            'side_effects_summary': summary,
          },
        );
      case ZaraActionKind.checkWeather:
        const summary =
            'Smoke weather review completed. High wind remains the most likely cause.';
        return ZaraActionResult(
          actionId: action.id,
          outcome: ZaraActionExecutionOutcome.autoExecuted,
          success: true,
          sideEffectsSummary: summary,
          resultData: <String, Object?>{
            ...smokePayload,
            'side_effects_summary': summary,
          },
        );
      case ZaraActionKind.draftClientMessage:
        final payload = action.payload as ZaraClientMessagePayload;
        final appliedText = draftOverride.trim().isEmpty
            ? payload.draftText
            : draftOverride.trim();
        const summary =
            'Smoke client update staged successfully. No live Telegram message was sent.';
        return ZaraActionResult(
          actionId: action.id,
          outcome: draftOverride.trim().isEmpty
              ? ZaraActionExecutionOutcome.approved
              : ZaraActionExecutionOutcome.modified,
          success: true,
          sideEffectsSummary: summary,
          resultData: <String, Object?>{
            ...smokePayload,
            'message_text': appliedText,
            'side_effects_suppressed': true,
            'side_effects_summary': summary,
          },
        );
      case ZaraActionKind.dispatchReaction:
        const summary =
            'Smoke dispatch marked as executed. No live responder was dispatched.';
        return ZaraActionResult(
          actionId: action.id,
          outcome: ZaraActionExecutionOutcome.approved,
          success: true,
          sideEffectsSummary: summary,
          resultData: <String, Object?>{
            ...smokePayload,
            'side_effects_suppressed': true,
            'side_effects_summary': summary,
          },
        );
      case ZaraActionKind.standDownDispatch:
        const summary =
            'Smoke dispatch stand-down recorded. No live dispatch state changed.';
        return ZaraActionResult(
          actionId: action.id,
          outcome: ZaraActionExecutionOutcome.approved,
          success: true,
          sideEffectsSummary: summary,
          resultData: <String, Object?>{
            ...smokePayload,
            'side_effects_suppressed': true,
            'side_effects_summary': summary,
          },
        );
      case ZaraActionKind.continueMonitoring:
        const summary =
            'Smoke monitoring continued. Zara remains focused on $_smokeSiteLabel.';
        return ZaraActionResult(
          actionId: action.id,
          outcome: ZaraActionExecutionOutcome.approved,
          success: true,
          sideEffectsSummary: summary,
          resultData: <String, Object?>{
            ...smokePayload,
            'side_effects_suppressed': true,
            'side_effects_summary': summary,
          },
        );
      case ZaraActionKind.logOB:
      case ZaraActionKind.issueGuardWarning:
      case ZaraActionKind.escalateSupervisor:
        final summary =
            'Smoke harness does not implement ${action.kind.name} yet.';
        return ZaraActionResult(
          actionId: action.id,
          outcome: ZaraActionExecutionOutcome.failed,
          success: false,
          sideEffectsSummary: summary,
          resultData: <String, Object?>{
            ...smokePayload,
            'side_effects_summary': summary,
          },
        );
    }
  }
}

Future<_SmokeLaunch> _prepareSmokeLaunch() async {
  final supabaseService = await _initializeSupabaseService();
  final client = Supabase.instance.client;
  final controllerUserId = client.auth.currentUser?.id ?? '';
  final existingRow = await _readMostRecentSmokeScenarioRow(client);
  if (existingRow != null) {
    final scenarioId = (existingRow['id'] ?? '').toString().trim();
    final actionLogRows = await _readSmokeActionLogRows(
      client: client,
      scenarioId: scenarioId,
    );
    final scenario = _scenarioFromStoredRows(
      scenarioRow: existingRow,
      actionLogRows: actionLogRows,
    );
    return _SmokeLaunch(
      scenario: scenario,
      events: <DispatchEvent>[_buildSmokeAlarmEvent(scenario)],
      supabaseService: supabaseService,
      controllerUserId: controllerUserId,
      reusedExistingScenario: true,
      alarmId: _alarmIdForScenario(scenario.id.value),
    );
  }

  final scenario = _freshSmokeScenario();
  await supabaseService.upsertZaraScenario(
    scenario: scenario,
    controllerUserId: controllerUserId,
  );
  for (final action in scenario.proposedActions.where((candidate) {
    return candidate.kind == ZaraActionKind.checkFootage ||
        candidate.kind == ZaraActionKind.checkWeather;
  })) {
    await supabaseService.appendZaraActionLog(
      scenario: scenario,
      action: action,
      outcome: ZaraActionExecutionOutcome.autoExecuted,
      resultJson: <String, Object?>{
        ...action.payload.toJson(),
        'smoke_mode': true,
        'seeded': true,
      },
    );
  }
  return _SmokeLaunch(
    scenario: scenario,
    events: <DispatchEvent>[_buildSmokeAlarmEvent(scenario)],
    supabaseService: supabaseService,
    controllerUserId: controllerUserId,
    reusedExistingScenario: false,
    alarmId: _alarmIdForScenario(scenario.id.value),
  );
}

Future<SupabaseService> _initializeSupabaseService() async {
  const rawSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const rawSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  final usableSupabaseUrl = OnyxRuntimeConfig.usableSupabaseUrl(rawSupabaseUrl);
  final usableSupabaseAnonKey = OnyxRuntimeConfig.usableSecret(
    rawSupabaseAnonKey,
  );
  if (usableSupabaseUrl.isEmpty || usableSupabaseAnonKey.isEmpty) {
    throw StateError(
      'SUPABASE_URL and SUPABASE_ANON_KEY must be configured for Zara Theatre smoke.',
    );
  }
  await Supabase.initialize(
    url: usableSupabaseUrl,
    anonKey: usableSupabaseAnonKey,
  );
  final client = Supabase.instance.client;
  if (client.auth.currentSession == null) {
    await client.auth.signInAnonymously();
  }
  return SupabaseService(client: client);
}

Future<Map<String, Object?>?> _readMostRecentSmokeScenarioRow(
  SupabaseClient client,
) async {
  final rows = await client
      .from('zara_scenarios')
      .select()
      .like('id', '$_smokeScenarioPrefix%')
      .order('created_at', ascending: false)
      .limit(1);
  if (rows.isEmpty) {
    return null;
  }
  return Map<String, Object?>.from(rows.first as Map);
}

Future<List<Map<String, Object?>>> _readSmokeActionLogRows({
  required SupabaseClient client,
  required String scenarioId,
}) async {
  final rows = await client
      .from('zara_action_log')
      .select()
      .eq('scenario_id', scenarioId)
      .order('executed_at', ascending: true);
  return rows.map((row) => Map<String, Object?>.from(row as Map)).toList();
}

ZaraScenario _freshSmokeScenario() {
  final createdAt = DateTime.now().toUtc();
  final scenarioId =
      '$_smokeScenarioPrefix${createdAt.microsecondsSinceEpoch.toString()}';
  return _buildScenarioTemplate(
    scenarioId: scenarioId,
    createdAt: createdAt,
    lifecycleState: ZaraScenarioLifecycleState.awaitingController,
    actionStateByKind: const <ZaraActionKind, ZaraActionState>{
      ZaraActionKind.checkFootage: ZaraActionState.completed,
      ZaraActionKind.checkWeather: ZaraActionState.completed,
    },
  );
}

ZaraScenario _scenarioFromStoredRows({
  required Map<String, Object?> scenarioRow,
  required List<Map<String, Object?>> actionLogRows,
}) {
  final scenarioId = (scenarioRow['id'] ?? '').toString().trim();
  final createdAt =
      DateTime.tryParse(
        (scenarioRow['created_at'] ?? '').toString(),
      )?.toUtc() ??
      DateTime.now().toUtc();
  final actionStateByKind = <ZaraActionKind, ZaraActionState>{
    ZaraActionKind.checkFootage: ZaraActionState.completed,
    ZaraActionKind.checkWeather: ZaraActionState.completed,
  };
  final resolutionSummaryByKind = <ZaraActionKind, String>{
    ZaraActionKind.checkFootage:
        'Smoke footage review completed. No threat detected on $_smokeSiteLabel.',
    ZaraActionKind.checkWeather:
        'Smoke weather review completed. High wind remains the most likely cause.',
  };
  for (final row in actionLogRows) {
    final kind = _actionKindFromLabel((row['action_kind'] ?? '').toString());
    if (kind == null) {
      continue;
    }
    actionStateByKind[kind] = _actionStateFromOutcome(
      (row['outcome'] ?? '').toString(),
    );
    final resultJson = _asJsonMap(row['result_jsonb']);
    final sideEffectSummary = (resultJson['side_effects_summary'] ?? '')
        .toString()
        .trim();
    if (sideEffectSummary.isNotEmpty) {
      resolutionSummaryByKind[kind] = sideEffectSummary;
    }
  }
  return _buildScenarioTemplate(
    scenarioId: scenarioId,
    createdAt: createdAt,
    lifecycleState: _scenarioLifecycleFromLabel(
      (scenarioRow['lifecycle_state'] ?? '').toString(),
    ),
    actionStateByKind: actionStateByKind,
    resolutionSummaryByKind: resolutionSummaryByKind,
  );
}

ZaraScenario _buildScenarioTemplate({
  required String scenarioId,
  required DateTime createdAt,
  required ZaraScenarioLifecycleState lifecycleState,
  required Map<ZaraActionKind, ZaraActionState> actionStateByKind,
  Map<ZaraActionKind, String> resolutionSummaryByKind =
      const <ZaraActionKind, String>{},
}) {
  final alarmId = _alarmIdForScenario(scenarioId);
  final originEventId = _eventIdForScenario(scenarioId);
  return ZaraScenario(
    id: ZaraScenarioId(scenarioId),
    kind: ZaraScenarioKind.alarmTriage,
    createdAt: createdAt,
    originEventIds: <String>[originEventId],
    summary:
        "Alarm at $_smokeSiteLabel. I've checked footage and see no threat or movement on property. Weather shows high wind that could explain the trigger. Would you like me to draft a client update, dispatch reaction, stand down dispatch, or keep monitoring?",
    proposedActions: <ZaraAction>[
      ZaraAction(
        id: ZaraActionId('$scenarioId-checkFootage'),
        kind: ZaraActionKind.checkFootage,
        label: 'Checked footage',
        reversible: true,
        confirmRequired: false,
        payload: const ZaraMonitoringPayload(
          siteId: _smokeSiteId,
          detail: 'Smoke footage review saw no threat or movement.',
        ),
        state:
            actionStateByKind[ZaraActionKind.checkFootage] ??
            ZaraActionState.completed,
        resolutionSummary:
            resolutionSummaryByKind[ZaraActionKind.checkFootage] ??
            'Smoke footage review completed. No threat detected on $_smokeSiteLabel.',
      ),
      ZaraAction(
        id: ZaraActionId('$scenarioId-checkWeather'),
        kind: ZaraActionKind.checkWeather,
        label: 'Checked weather',
        reversible: true,
        confirmRequired: false,
        payload: const ZaraMonitoringPayload(
          siteId: _smokeSiteId,
          detail:
              'Smoke weather review shows high wind near the perimeter beam.',
        ),
        state:
            actionStateByKind[ZaraActionKind.checkWeather] ??
            ZaraActionState.completed,
        resolutionSummary:
            resolutionSummaryByKind[ZaraActionKind.checkWeather] ??
            'Smoke weather review completed. High wind remains the most likely cause.',
      ),
      ZaraAction(
        id: ZaraActionId('$scenarioId-draftClientMessage'),
        kind: ZaraActionKind.draftClientMessage,
        label: 'Draft and send client update',
        reversible: false,
        confirmRequired: true,
        payload: ZaraClientMessagePayload(
          clientId: _smokeClientId,
          siteId: _smokeSiteId,
          room: 'Residents',
          incidentReference: alarmId,
          draftText:
              'Control update: We investigated the alarm at $_smokeSiteLabel. Footage shows no threat, high wind appears to be contributing to the trigger, and Zara is continuing to monitor the property.',
          originalDraftText:
              'Control update: We investigated the alarm at $_smokeSiteLabel. Footage shows no threat, high wind appears to be contributing to the trigger, and Zara is continuing to monitor the property.',
        ),
        state:
            actionStateByKind[ZaraActionKind.draftClientMessage] ??
            ZaraActionState.proposed,
        resolutionSummary:
            resolutionSummaryByKind[ZaraActionKind.draftClientMessage] ?? '',
      ),
      ZaraAction(
        id: ZaraActionId('$scenarioId-dispatchReaction'),
        kind: ZaraActionKind.dispatchReaction,
        label: 'Dispatch reaction as a precaution',
        reversible: false,
        confirmRequired: true,
        payload: ZaraDispatchPayload(
          clientId: _smokeClientId,
          regionId: _smokeRegionId,
          siteId: _smokeSiteId,
          dispatchId: alarmId,
          note: 'Smoke harness precautionary dispatch.',
        ),
        state:
            actionStateByKind[ZaraActionKind.dispatchReaction] ??
            ZaraActionState.proposed,
        resolutionSummary:
            resolutionSummaryByKind[ZaraActionKind.dispatchReaction] ?? '',
      ),
      ZaraAction(
        id: ZaraActionId('$scenarioId-standDownDispatch'),
        kind: ZaraActionKind.standDownDispatch,
        label: 'Stand down reaction dispatch',
        reversible: false,
        confirmRequired: true,
        payload: ZaraDispatchPayload(
          clientId: _smokeClientId,
          regionId: _smokeRegionId,
          siteId: _smokeSiteId,
          dispatchId: alarmId,
          note: 'Smoke harness stand-down.',
        ),
        state:
            actionStateByKind[ZaraActionKind.standDownDispatch] ??
            ZaraActionState.proposed,
        resolutionSummary:
            resolutionSummaryByKind[ZaraActionKind.standDownDispatch] ?? '',
      ),
      ZaraAction(
        id: ZaraActionId('$scenarioId-continueMonitoring'),
        kind: ZaraActionKind.continueMonitoring,
        label: 'Keep monitoring the property',
        reversible: false,
        confirmRequired: true,
        payload: const ZaraMonitoringPayload(
          siteId: _smokeSiteId,
          detail:
              'Keep Zara monitoring the smoke test property after decision.',
        ),
        state:
            actionStateByKind[ZaraActionKind.continueMonitoring] ??
            ZaraActionState.proposed,
        resolutionSummary:
            resolutionSummaryByKind[ZaraActionKind.continueMonitoring] ?? '',
      ),
    ],
    relatedSiteId: _smokeSiteId,
    relatedDispatchIds: <String>[alarmId],
    urgency: ZaraScenarioUrgency.attention,
    lifecycleState: lifecycleState,
  );
}

ListenerAlarmAdvisoryRecorded _buildSmokeAlarmEvent(ZaraScenario scenario) {
  return ListenerAlarmAdvisoryRecorded(
    eventId: _eventIdForScenario(scenario.id.value),
    sequence: 0,
    version: 1,
    occurredAt: scenario.createdAt,
    clientId: _smokeClientId,
    regionId: _smokeRegionId,
    siteId: _smokeSiteId,
    externalAlarmId: _alarmIdForScenario(scenario.id.value),
    accountNumber: 'ACC-SMOKE-001',
    partition: 'Perimeter',
    zone: 'Front beam',
    zoneLabel: 'Front beam',
    eventLabel: 'Intrusion alarm',
    dispositionLabel: 'clear',
    summary: 'No threat and no movement detected on property.',
    recommendation: 'High wind could be interfering with the perimeter beam.',
    deliveredCount: 0,
    failedCount: 0,
  );
}

String _eventIdForScenario(String scenarioId) {
  final suffix = scenarioId.replaceFirst(_smokeScenarioPrefix, '');
  return '$_smokeEventPrefix$suffix';
}

String _alarmIdForScenario(String scenarioId) {
  final suffix = scenarioId.replaceFirst(_smokeScenarioPrefix, '');
  return '$_smokeAlarmPrefix$suffix';
}

ZaraScenarioLifecycleState _scenarioLifecycleFromLabel(String raw) {
  return switch (raw.trim()) {
    'awaiting_controller' => ZaraScenarioLifecycleState.awaitingController,
    'executing' => ZaraScenarioLifecycleState.executing,
    'complete' => ZaraScenarioLifecycleState.complete,
    'dismissed' => ZaraScenarioLifecycleState.dismissed,
    _ => ZaraScenarioLifecycleState.awaitingController,
  };
}

ZaraActionState _actionStateFromOutcome(String raw) {
  return switch (raw.trim()) {
    'autoExecuted' => ZaraActionState.completed,
    'approved' => ZaraActionState.completed,
    'modified' => ZaraActionState.completed,
    'rejected' => ZaraActionState.rejected,
    'failed' => ZaraActionState.failed,
    'timedOut' => ZaraActionState.failed,
    _ => ZaraActionState.proposed,
  };
}

ZaraActionKind? _actionKindFromLabel(String raw) {
  for (final kind in ZaraActionKind.values) {
    if (kind.name == raw.trim()) {
      return kind;
    }
  }
  return null;
}

Map<String, Object?> _asJsonMap(Object? raw) {
  if (raw is Map) {
    return raw.map((key, value) {
      return MapEntry(key.toString(), value as Object?);
    });
  }
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((key, value) {
          return MapEntry(key.toString(), value as Object?);
        });
      }
    } catch (_) {
      return const <String, Object?>{};
    }
  }
  return const <String, Object?>{};
}
