import 'dart:convert';

import 'package:flutter/services.dart';

class GuardTelemetryReplayFixtureService {
  final Map<String, String> _fixtureAssetPaths;

  const GuardTelemetryReplayFixtureService({
    Map<String, String> fixtureAssetPaths = const {
      'standard_sample':
          'assets/telemetry_payload_fixtures/fsk_standard_sample.json',
      'legacy_ptt_sample':
          'assets/telemetry_payload_fixtures/fsk_legacy_ptt_sample.json',
      'hikvision_guardlink_sample':
          'assets/telemetry_payload_fixtures/fsk_hikvision_guardlink_sample.json',
    },
  }) : _fixtureAssetPaths = fixtureAssetPaths;

  List<String> availableFixtureIds() {
    final ids = _fixtureAssetPaths.keys.toList(growable: false)..sort();
    return ids;
  }

  Future<Map<String, Object?>> readFixture(String fixtureId) async {
    final assetPath = _fixtureAssetPaths[fixtureId];
    if (assetPath == null || assetPath.trim().isEmpty) {
      throw StateError('Unknown telemetry replay fixture: $fixtureId');
    }
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw StateError(
        'Telemetry replay fixture is not a JSON object: $fixtureId',
      );
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }
}
