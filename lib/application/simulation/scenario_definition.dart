import 'dart:convert';

import '../../domain/authority/onyx_command_brain_contract.dart';

class ScenarioDefinition {
  ScenarioDefinition({
    required this.scenarioId,
    required this.title,
    required this.description,
    required this.category,
    required this.scenarioSet,
    required this.tags,
    required this.author,
    required this.createdAt,
    required this.version,
    required this.status,
    required this.runtimeContext,
    required this.seedState,
    required this.inputs,
    required this.expectedOutcome,
  });

  factory ScenarioDefinition.fromJson(Map<String, dynamic> json) {
    return ScenarioDefinition(
      scenarioId: _readString(json, 'scenarioId'),
      title: _readString(json, 'title'),
      description: _readString(json, 'description'),
      category: _readString(json, 'category'),
      scenarioSet: _readOptionalString(json, 'scenarioSet') ?? 'replay',
      tags: _readStringList(json, 'tags'),
      author: _readString(json, 'author'),
      createdAt: DateTime.parse(_readString(json, 'createdAt')).toUtc(),
      version: _readInt(json, 'version'),
      status: _readString(json, 'status'),
      runtimeContext: ScenarioRuntimeContext.fromJson(
        _readMap(json, 'runtimeContext'),
      ),
      seedState: ScenarioSeedState.fromJson(_readMap(json, 'seedState')),
      inputs: ScenarioInputs.fromJson(_readMap(json, 'inputs')),
      expectedOutcome: ScenarioExpectedOutcome.fromJson(
        _readMap(json, 'expectedOutcome'),
      ),
    );
  }

  static ScenarioDefinition fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException(
        'Scenario definition must decode to a JSON object.',
      );
    }
    return ScenarioDefinition.fromJson(_stringKeyedMap(decoded));
  }

  final String scenarioId;
  final String title;
  final String description;
  final String category;
  final String scenarioSet;
  final List<String> tags;
  final String author;
  final DateTime createdAt;
  final int version;
  final String status;
  final ScenarioRuntimeContext runtimeContext;
  final ScenarioSeedState seedState;
  final ScenarioInputs inputs;
  final ScenarioExpectedOutcome expectedOutcome;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'scenarioId': scenarioId,
      'title': title,
      'description': description,
      'category': category,
      'scenarioSet': scenarioSet,
      'tags': tags,
      'author': author,
      'createdAt': createdAt.toIso8601String(),
      'version': version,
      'status': status,
      'runtimeContext': runtimeContext.toJson(),
      'seedState': seedState.toJson(),
      'inputs': inputs.toJson(),
      'expectedOutcome': expectedOutcome.toJson(),
    };
  }

  String toJsonString({bool pretty = false}) {
    if (!pretty) {
      return jsonEncode(toJson());
    }
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }

  ScenarioDefinition copyWith({
    String? scenarioId,
    String? title,
    String? description,
    String? category,
    String? scenarioSet,
    List<String>? tags,
    String? author,
    DateTime? createdAt,
    int? version,
    String? status,
    ScenarioRuntimeContext? runtimeContext,
    ScenarioSeedState? seedState,
    ScenarioInputs? inputs,
    ScenarioExpectedOutcome? expectedOutcome,
  }) {
    return ScenarioDefinition(
      scenarioId: scenarioId ?? this.scenarioId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      scenarioSet: scenarioSet ?? this.scenarioSet,
      tags: tags ?? this.tags,
      author: author ?? this.author,
      createdAt: createdAt ?? this.createdAt,
      version: version ?? this.version,
      status: status ?? this.status,
      runtimeContext: runtimeContext ?? this.runtimeContext,
      seedState: seedState ?? this.seedState,
      inputs: inputs ?? this.inputs,
      expectedOutcome: expectedOutcome ?? this.expectedOutcome,
    );
  }
}

class ScenarioRuntimeContext {
  ScenarioRuntimeContext({
    required this.operatorRole,
    required this.authorityScope,
    required this.activeSiteIds,
    required this.viewportProfile,
    required this.sessionMode,
    required this.currentTime,
    required this.timezone,
  });

  factory ScenarioRuntimeContext.fromJson(Map<String, dynamic> json) {
    return ScenarioRuntimeContext(
      operatorRole: _readString(json, 'operatorRole'),
      authorityScope: _readString(json, 'authorityScope'),
      activeSiteIds: _readStringList(json, 'activeSiteIds'),
      viewportProfile: _readString(json, 'viewportProfile'),
      sessionMode: _readString(json, 'sessionMode'),
      currentTime: DateTime.parse(_readString(json, 'currentTime')),
      timezone: _readString(json, 'timezone'),
    );
  }

  final String operatorRole;
  final String authorityScope;
  final List<String> activeSiteIds;
  final String viewportProfile;
  final String sessionMode;
  final DateTime currentTime;
  final String timezone;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'operatorRole': operatorRole,
      'authorityScope': authorityScope,
      'activeSiteIds': activeSiteIds,
      'viewportProfile': viewportProfile,
      'sessionMode': sessionMode,
      'currentTime': currentTime.toIso8601String(),
      'timezone': timezone,
    };
  }
}

class ScenarioSeedState {
  ScenarioSeedState({
    required this.fixtures,
    required this.onboardingState,
    required this.watchState,
    required this.dispatchState,
    required this.clientConversationState,
    required this.siteStatusState,
  });

  factory ScenarioSeedState.fromJson(Map<String, dynamic> json) {
    return ScenarioSeedState(
      fixtures: ScenarioFixtures.fromJson(_readMap(json, 'fixtures')),
      onboardingState: _readString(json, 'onboardingState'),
      watchState: _readString(json, 'watchState'),
      dispatchState: _readString(json, 'dispatchState'),
      clientConversationState: _readString(json, 'clientConversationState'),
      siteStatusState: _readString(json, 'siteStatusState'),
    );
  }

  final ScenarioFixtures fixtures;
  final String onboardingState;
  final String watchState;
  final String dispatchState;
  final String clientConversationState;
  final String siteStatusState;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'fixtures': fixtures.toJson(),
      'onboardingState': onboardingState,
      'watchState': watchState,
      'dispatchState': dispatchState,
      'clientConversationState': clientConversationState,
      'siteStatusState': siteStatusState,
    };
  }
}

class ScenarioFixtures {
  ScenarioFixtures({
    required this.events,
    required this.projections,
    required this.sessions,
  });

  factory ScenarioFixtures.fromJson(Map<String, dynamic> json) {
    return ScenarioFixtures(
      events: _readStringList(json, 'events'),
      projections: _readStringList(json, 'projections'),
      sessions: _readStringList(json, 'sessions'),
    );
  }

  final List<String> events;
  final List<String> projections;
  final List<String> sessions;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'events': events,
      'projections': projections,
      'sessions': sessions,
    };
  }
}

class ScenarioInputs {
  ScenarioInputs({
    required this.prompts,
    required this.inboundSignals,
    required this.telemetryInputs,
    required this.cameraInputs,
    required this.adminQueries,
    required this.clientMessages,
    this.navigation,
  });

  factory ScenarioInputs.fromJson(Map<String, dynamic> json) {
    return ScenarioInputs(
      prompts: _readObjectList(
        json,
        'prompts',
      ).map(ScenarioPrompt.fromJson).toList(growable: false),
      inboundSignals: _readDynamicList(json, 'inboundSignals'),
      telemetryInputs: _readDynamicList(json, 'telemetryInputs'),
      cameraInputs: _readDynamicList(json, 'cameraInputs'),
      adminQueries: _readDynamicList(json, 'adminQueries'),
      clientMessages: _readDynamicList(json, 'clientMessages'),
      navigation: json.containsKey('navigation')
          ? ScenarioNavigation.fromJson(_readMap(json, 'navigation'))
          : null,
    );
  }

  final List<ScenarioPrompt> prompts;
  final List<dynamic> inboundSignals;
  final List<dynamic> telemetryInputs;
  final List<dynamic> cameraInputs;
  final List<dynamic> adminQueries;
  final List<dynamic> clientMessages;
  final ScenarioNavigation? navigation;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'prompts': prompts.map((prompt) => prompt.toJson()).toList(),
      'inboundSignals': inboundSignals,
      'telemetryInputs': telemetryInputs,
      'cameraInputs': cameraInputs,
      'adminQueries': adminQueries,
      'clientMessages': clientMessages,
      if (navigation != null) 'navigation': navigation!.toJson(),
    };
  }
}

class ScenarioPrompt {
  ScenarioPrompt({required this.channel, required this.text});

  factory ScenarioPrompt.fromJson(Map<String, dynamic> json) {
    return ScenarioPrompt(
      channel: _readString(json, 'channel'),
      text: _readString(json, 'text'),
    );
  }

  final String channel;
  final String text;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'channel': channel, 'text': text};
  }
}

class ScenarioNavigation {
  ScenarioNavigation({required this.entryRoute, this.steps = const []});

  factory ScenarioNavigation.fromJson(Map<String, dynamic> json) {
    return ScenarioNavigation(
      entryRoute: _readString(json, 'entryRoute'),
      steps: json.containsKey('steps')
          ? _readObjectList(
              json,
              'steps',
            ).map(ScenarioNavigationStep.fromJson).toList(growable: false)
          : const <ScenarioNavigationStep>[],
    );
  }

  final String entryRoute;
  final List<ScenarioNavigationStep> steps;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'entryRoute': entryRoute,
      if (steps.isNotEmpty)
        'steps': steps.map((step) => step.toJson()).toList(growable: false),
    };
  }
}

class ScenarioNavigationStep {
  ScenarioNavigationStep({
    required this.stepId,
    this.condition,
    this.specialist,
    this.specialistAssessments = const <SpecialistAssessment>[],
  });

  factory ScenarioNavigationStep.fromJson(Map<String, dynamic> json) {
    return ScenarioNavigationStep(
      stepId: _readString(json, 'stepId'),
      condition: json.containsKey('condition')
          ? ScenarioStepCondition.fromJson(_readMap(json, 'condition'))
          : null,
      specialist: json.containsKey('specialist')
          ? ScenarioStepSpecialistSignal.fromJson(_readMap(json, 'specialist'))
          : null,
      specialistAssessments: json.containsKey('specialistAssessments')
          ? _readObjectList(json, 'specialistAssessments')
                .map(
                  (assessment) => SpecialistAssessment.fromJson(
                    Map<String, Object?>.from(assessment),
                  ),
                )
                .toList(growable: false)
          : const <SpecialistAssessment>[],
    );
  }

  final String stepId;
  final ScenarioStepCondition? condition;
  final ScenarioStepSpecialistSignal? specialist;
  final List<SpecialistAssessment> specialistAssessments;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'stepId': stepId,
      if (condition != null) 'condition': condition!.toJson(),
      if (specialist != null) 'specialist': specialist!.toJson(),
      if (specialistAssessments.isNotEmpty)
        'specialistAssessments': specialistAssessments
            .map((assessment) => assessment.toJson())
            .toList(growable: false),
    };
  }
}

enum ScenarioStepSpecialistStatus { ready, delayed, signalLost }

class ScenarioStepSpecialistSignal {
  ScenarioStepSpecialistSignal({
    required this.specialist,
    required this.status,
    this.delayMs = 0,
    this.detail = '',
    this.fallbackStepId,
  });

  factory ScenarioStepSpecialistSignal.fromJson(Map<String, dynamic> json) {
    final specialistName =
        _readOptionalString(json, 'name') ??
        _readOptionalString(json, 'specialist');
    if (specialistName == null || specialistName.trim().isEmpty) {
      throw const FormatException('Expected "specialist.name" to be a string.');
    }
    return ScenarioStepSpecialistSignal(
      specialist: _onyxSpecialistFromName(specialistName),
      status: _scenarioStepSpecialistStatusFromName(
        _readOptionalString(json, 'status'),
      ),
      delayMs: _readOptionalInt(json, 'delayMs') ?? 0,
      detail: _readOptionalString(json, 'detail') ?? '',
      fallbackStepId: _readOptionalString(json, 'fallbackStepId'),
    );
  }

  final OnyxSpecialist specialist;
  final ScenarioStepSpecialistStatus status;
  final int delayMs;
  final String detail;
  final String? fallbackStepId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': specialist.name,
      'status': _scenarioStepSpecialistStatusName(status),
      if (delayMs > 0) 'delayMs': delayMs,
      if (detail.trim().isNotEmpty) 'detail': detail,
      if (fallbackStepId != null) 'fallbackStepId': fallbackStepId,
    };
  }
}

class ScenarioStepCondition {
  ScenarioStepCondition({
    required this.field,
    this.equals = true,
    this.otherwiseStepId,
  });

  factory ScenarioStepCondition.fromJson(Map<String, dynamic> json) {
    final equalsValue = json['equals'];
    final existsValue = json['exists'];
    if (equalsValue != null && equalsValue is! bool) {
      throw const FormatException(
        'Expected "condition.equals" to be a bool when present.',
      );
    }
    if (existsValue != null && existsValue is! bool) {
      throw const FormatException(
        'Expected "condition.exists" to be a bool when present.',
      );
    }
    final field =
        _readOptionalString(json, 'field') ??
        _readOptionalString(json, 'projectionPath');
    if (field == null) {
      throw const FormatException('Expected "condition.field" to be a string.');
    }
    return ScenarioStepCondition(
      field: field,
      equals: equalsValue as bool? ?? existsValue as bool? ?? true,
      otherwiseStepId: _readOptionalString(json, 'otherwiseStepId'),
    );
  }

  final String field;
  final bool equals;
  final String? otherwiseStepId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'field': field,
      'equals': equals,
      if (otherwiseStepId != null) 'otherwiseStepId': otherwiseStepId,
    };
  }
}

class ScenarioExpectedOutcome {
  ScenarioExpectedOutcome({
    required this.expectedRoute,
    required this.expectedIntent,
    required this.expectedEscalationState,
    required this.expectedProjectionChanges,
    required this.expectedDrafts,
    required this.expectedBlockedActions,
    required this.expectedUiState,
    this.commandBrainSnapshot,
    this.commandBrainTimeline = const <OnyxCommandBrainTimelineEntry>[],
  });

  factory ScenarioExpectedOutcome.fromJson(Map<String, dynamic> json) {
    final commandBrainSnapshot = _readOptionalMap(json, 'commandBrainSnapshot');
    final commandBrainTimeline = _readOptionalObjectList(
      json,
      'commandBrainTimeline',
    );
    return ScenarioExpectedOutcome(
      expectedRoute: _readString(json, 'expectedRoute'),
      expectedIntent: _readString(json, 'expectedIntent'),
      expectedEscalationState: _readString(json, 'expectedEscalationState'),
      expectedProjectionChanges: _readDynamicList(
        json,
        'expectedProjectionChanges',
      ),
      expectedDrafts: _readDynamicList(json, 'expectedDrafts'),
      expectedBlockedActions: _readStringList(json, 'expectedBlockedActions'),
      expectedUiState: _readMap(json, 'expectedUiState'),
      commandBrainSnapshot: commandBrainSnapshot == null
          ? null
          : OnyxCommandBrainSnapshot.fromJson(commandBrainSnapshot),
      commandBrainTimeline: commandBrainTimeline
          .map(OnyxCommandBrainTimelineEntry.fromJson)
          .toList(growable: false),
    );
  }

  final String expectedRoute;
  final String expectedIntent;
  final String expectedEscalationState;
  final List<dynamic> expectedProjectionChanges;
  final List<dynamic> expectedDrafts;
  final List<String> expectedBlockedActions;
  final Map<String, dynamic> expectedUiState;
  final OnyxCommandBrainSnapshot? commandBrainSnapshot;
  final List<OnyxCommandBrainTimelineEntry> commandBrainTimeline;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'expectedRoute': expectedRoute,
      'expectedIntent': expectedIntent,
      'expectedEscalationState': expectedEscalationState,
      'expectedProjectionChanges': expectedProjectionChanges,
      'expectedDrafts': expectedDrafts,
      'expectedBlockedActions': expectedBlockedActions,
      'expectedUiState': expectedUiState,
      if (commandBrainSnapshot != null)
        'commandBrainSnapshot': commandBrainSnapshot!.toJson(),
      if (commandBrainTimeline.isNotEmpty)
        'commandBrainTimeline': commandBrainTimeline
            .map((entry) => entry.toJson())
            .toList(growable: false),
    };
  }

  ScenarioExpectedOutcome copyWith({
    String? expectedRoute,
    String? expectedIntent,
    String? expectedEscalationState,
    List<dynamic>? expectedProjectionChanges,
    List<dynamic>? expectedDrafts,
    List<String>? expectedBlockedActions,
    Map<String, dynamic>? expectedUiState,
    OnyxCommandBrainSnapshot? commandBrainSnapshot,
    List<OnyxCommandBrainTimelineEntry>? commandBrainTimeline,
  }) {
    return ScenarioExpectedOutcome(
      expectedRoute: expectedRoute ?? this.expectedRoute,
      expectedIntent: expectedIntent ?? this.expectedIntent,
      expectedEscalationState:
          expectedEscalationState ?? this.expectedEscalationState,
      expectedProjectionChanges:
          expectedProjectionChanges ?? this.expectedProjectionChanges,
      expectedDrafts: expectedDrafts ?? this.expectedDrafts,
      expectedBlockedActions:
          expectedBlockedActions ?? this.expectedBlockedActions,
      expectedUiState: expectedUiState ?? this.expectedUiState,
      commandBrainSnapshot: commandBrainSnapshot ?? this.commandBrainSnapshot,
      commandBrainTimeline: commandBrainTimeline ?? this.commandBrainTimeline,
    );
  }
}

String _readString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) {
    return value;
  }
  throw FormatException('Expected "$key" to be a string.');
}

String? _readOptionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  throw FormatException('Expected "$key" to be a string when present.');
}

int _readInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  throw FormatException('Expected "$key" to be an int.');
}

int? _readOptionalInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  throw FormatException('Expected "$key" to be an int when present.');
}

Map<String, dynamic> _readMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map) {
    return _stringKeyedMap(value);
  }
  throw FormatException('Expected "$key" to be an object.');
}

Map<String, dynamic>? _readOptionalMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is Map) {
    return _stringKeyedMap(value);
  }
  throw FormatException('Expected "$key" to be an object.');
}

List<String> _readStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Expected "$key" to be a list.');
  }
  return value
      .map((item) {
        if (item is! String) {
          throw FormatException('Expected all items in "$key" to be strings.');
        }
        return item;
      })
      .toList(growable: false);
}

List<dynamic> _readDynamicList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Expected "$key" to be a list.');
  }
  return List<dynamic>.from(value);
}

List<Map<String, dynamic>> _readObjectList(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Expected "$key" to be a list.');
  }
  return value
      .map((item) {
        if (item is! Map) {
          throw FormatException('Expected all items in "$key" to be objects.');
        }
        return _stringKeyedMap(item);
      })
      .toList(growable: false);
}

List<Map<String, dynamic>> _readOptionalObjectList(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value == null) {
    return const <Map<String, dynamic>>[];
  }
  if (value is! List) {
    throw FormatException('Expected "$key" to be a list.');
  }
  return value
      .map((item) {
        if (item is! Map) {
          throw FormatException('Expected all items in "$key" to be objects.');
        }
        return _stringKeyedMap(item);
      })
      .toList(growable: false);
}

Map<String, dynamic> _stringKeyedMap(Map value) {
  return value.map<String, dynamic>(
    (key, entryValue) => MapEntry(key.toString(), entryValue),
  );
}

OnyxSpecialist _onyxSpecialistFromName(String value) {
  final normalized = value.trim();
  return OnyxSpecialist.values.firstWhere(
    (entry) => entry.name == normalized,
    orElse: () {
      throw FormatException('Unknown specialist "$value".');
    },
  );
}

ScenarioStepSpecialistStatus _scenarioStepSpecialistStatusFromName(
  String? value,
) {
  final normalized = value?.trim() ?? 'delayed';
  return switch (normalized) {
    'ready' => ScenarioStepSpecialistStatus.ready,
    'delayed' => ScenarioStepSpecialistStatus.delayed,
    'signal_lost' => ScenarioStepSpecialistStatus.signalLost,
    _ => throw FormatException('Unknown specialist status "$normalized".'),
  };
}

String _scenarioStepSpecialistStatusName(ScenarioStepSpecialistStatus status) {
  return switch (status) {
    ScenarioStepSpecialistStatus.ready => 'ready',
    ScenarioStepSpecialistStatus.delayed => 'delayed',
    ScenarioStepSpecialistStatus.signalLost => 'signal_lost',
  };
}
