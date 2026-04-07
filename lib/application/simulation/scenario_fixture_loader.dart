import 'dart:convert';
import 'dart:io';

import 'scenario_definition.dart';

class ScenarioLoadedFixtures {
  ScenarioLoadedFixtures({
    required this.eventFixtures,
    required this.projectionFixtures,
    required this.sessionFixtures,
  });

  final List<Map<String, dynamic>> eventFixtures;
  final List<Map<String, dynamic>> projectionFixtures;
  final List<Map<String, dynamic>> sessionFixtures;

  List<dynamic> get existingEvents {
    final events = <dynamic>[];
    for (final fixture in eventFixtures) {
      final fixtureEvents = fixture['events'];
      if (fixtureEvents is List) {
        events.addAll(fixtureEvents);
      }
    }
    return List<dynamic>.unmodifiable(events);
  }

  Map<String, dynamic> get projectionState {
    return _mergeMaps(projectionFixtures);
  }

  Map<String, dynamic> get sessionState {
    return _mergeMaps(sessionFixtures);
  }
}

class ScenarioFixtureLoader {
  ScenarioFixtureLoader({required this.workspaceRoot});

  final String workspaceRoot;

  Future<ScenarioLoadedFixtures> loadFixtures(
    ScenarioDefinition definition,
  ) async {
    return ScenarioLoadedFixtures(
      eventFixtures: await _loadFixtureGroup(
        directoryName: 'events',
        fileNames: definition.seedState.fixtures.events,
      ),
      projectionFixtures: await _loadFixtureGroup(
        directoryName: 'projections',
        fileNames: definition.seedState.fixtures.projections,
      ),
      sessionFixtures: await _loadFixtureGroup(
        directoryName: 'sessions',
        fileNames: definition.seedState.fixtures.sessions,
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadFixtureGroup({
    required String directoryName,
    required List<String> fileNames,
  }) async {
    final fixtures = <Map<String, dynamic>>[];
    for (final fileName in fileNames) {
      final filePath = _normalizePath(
        '$workspaceRoot/simulations/fixtures/$directoryName/$fileName',
      );
      final file = File(filePath);
      if (!file.existsSync()) {
        throw FileSystemException('Fixture file does not exist.', filePath);
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        throw FormatException(
          'Fixture file "$fileName" must decode to a JSON object.',
        );
      }
      fixtures.add(_stringKeyedMap(decoded));
    }
    return fixtures;
  }
}

Map<String, dynamic> _mergeMaps(List<Map<String, dynamic>> maps) {
  final merged = <String, dynamic>{};
  for (final map in maps) {
    _deepMergeInto(merged, map);
  }
  return merged;
}

void _deepMergeInto(Map<String, dynamic> target, Map<String, dynamic> source) {
  source.forEach((key, value) {
    final existing = target[key];
    if (existing is Map && value is Map) {
      final nestedTarget = _stringKeyedMap(existing);
      _deepMergeInto(nestedTarget, _stringKeyedMap(value));
      target[key] = nestedTarget;
      return;
    }
    target[key] = value;
  });
}

Map<String, dynamic> _stringKeyedMap(Map value) {
  return value.map<String, dynamic>(
    (key, entryValue) => MapEntry(key.toString(), entryValue),
  );
}

String _normalizePath(String value) => value.replaceAll('//', '/');
