import 'dart:convert';

import '../../domain/authority/onyx_command_brain_contract.dart';

class ScenarioActualOutcome {
  ScenarioActualOutcome({
    required this.actualRoute,
    required this.actualIntent,
    required this.actualEscalationState,
    required this.actualProjectionChanges,
    required this.actualDrafts,
    required this.actualBlockedActions,
    required this.actualUiState,
    required this.appendedEvents,
    required this.notes,
    this.commandBrainSnapshot,
    this.commandBrainTimeline = const <OnyxCommandBrainTimelineEntry>[],
  });

  factory ScenarioActualOutcome.fromJson(Map<String, dynamic> json) {
    final commandBrainSnapshot = _readOptionalMap(json, 'commandBrainSnapshot');
    return ScenarioActualOutcome(
      actualRoute: _readString(json, 'actualRoute'),
      actualIntent: _readString(json, 'actualIntent'),
      actualEscalationState: _readString(json, 'actualEscalationState'),
      actualProjectionChanges: _readList(json, 'actualProjectionChanges'),
      actualDrafts: _readList(json, 'actualDrafts'),
      actualBlockedActions: _readStringList(json, 'actualBlockedActions'),
      actualUiState: _readMap(json, 'actualUiState'),
      appendedEvents: _readList(json, 'appendedEvents'),
      notes: _readString(json, 'notes'),
      commandBrainSnapshot: commandBrainSnapshot == null
          ? null
          : OnyxCommandBrainSnapshot.fromJson(commandBrainSnapshot),
      commandBrainTimeline: _readOptionalObjectList(
        json,
        'commandBrainTimeline',
      ).map(OnyxCommandBrainTimelineEntry.fromJson).toList(growable: false),
    );
  }

  final String actualRoute;
  final String actualIntent;
  final String actualEscalationState;
  final List<dynamic> actualProjectionChanges;
  final List<dynamic> actualDrafts;
  final List<String> actualBlockedActions;
  final Map<String, dynamic> actualUiState;
  final List<dynamic> appendedEvents;
  final String notes;
  final OnyxCommandBrainSnapshot? commandBrainSnapshot;
  final List<OnyxCommandBrainTimelineEntry> commandBrainTimeline;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'actualRoute': actualRoute,
      'actualIntent': actualIntent,
      'actualEscalationState': actualEscalationState,
      'actualProjectionChanges': actualProjectionChanges,
      'actualDrafts': actualDrafts,
      'actualBlockedActions': actualBlockedActions,
      'actualUiState': actualUiState,
      'appendedEvents': appendedEvents,
      'notes': notes,
      if (commandBrainSnapshot != null)
        'commandBrainSnapshot': commandBrainSnapshot!.toJson(),
      if (commandBrainTimeline.isNotEmpty)
        'commandBrainTimeline': commandBrainTimeline
            .map((entry) => entry.toJson())
            .toList(growable: false),
    };
  }
}

class ScenarioMismatch {
  ScenarioMismatch({
    required this.field,
    required this.expected,
    required this.actual,
  });

  factory ScenarioMismatch.fromJson(Map<String, dynamic> json) {
    return ScenarioMismatch(
      field: _readString(json, 'field'),
      expected: json['expected'],
      actual: json['actual'],
    );
  }

  final String field;
  final Object? expected;
  final Object? actual;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'field': field,
      'expected': expected,
      'actual': actual,
    };
  }
}

class ScenarioResult {
  ScenarioResult({
    required this.scenarioId,
    required this.runId,
    required this.actualOutcome,
    required this.mismatches,
  });

  factory ScenarioResult.fromJson(Map<String, dynamic> json) {
    return ScenarioResult(
      scenarioId: _readString(json, 'scenarioId'),
      runId: DateTime.parse(_readString(json, 'runId')).toUtc(),
      actualOutcome: ScenarioActualOutcome.fromJson(
        _readMap(json, 'actualOutcome'),
      ),
      mismatches: _readObjectList(
        json,
        'mismatches',
      ).map(ScenarioMismatch.fromJson).toList(growable: false),
    );
  }

  static ScenarioResult fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('Scenario result must decode to an object.');
    }
    return ScenarioResult.fromJson(_stringKeyedMap(decoded));
  }

  final String scenarioId;
  final DateTime runId;
  final ScenarioActualOutcome actualOutcome;
  final List<ScenarioMismatch> mismatches;

  bool get passed => mismatches.isEmpty;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'scenarioId': scenarioId,
      'runId': runId.toUtc().toIso8601String(),
      'passed': passed,
      'actualOutcome': actualOutcome.toJson(),
      'mismatches': mismatches.map((mismatch) => mismatch.toJson()).toList(),
    };
  }

  String toJsonString({bool pretty = false}) {
    if (!pretty) {
      return jsonEncode(toJson());
    }
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }
}

String _readString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) {
    return value;
  }
  throw FormatException('Expected "$key" to be a string.');
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

List<dynamic> _readList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is List) {
    return List<dynamic>.from(value);
  }
  throw FormatException('Expected "$key" to be a list.');
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
