import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/dispatch_clipboard_service.dart';
import 'package:omnix_dashboard/ui/dispatch_page.dart';

void main() {
  const service = DispatchClipboardService();

  final profile = IntakeStressPreset.medium.profile.copyWith(
    regressionThroughputDrop: 40,
    regressionVerifyIncreaseMs: 200,
  );
  final telemetry = IntakeTelemetry.zero.add(
    label: 'STR-CLIP',
    cancelled: false,
    attempted: 1000,
    appended: 900,
    skipped: 100,
    decisions: 40,
    throughput: 210,
    p50Throughput: 200,
    p95Throughput: 220,
    verifyMs: 80,
    chunkSize: 600,
    chunks: 2,
    avgChunkMs: 22,
    maxChunkMs: 40,
    slowChunks: 0,
    duplicatesInjected: 10,
    uniqueFeeds: 2,
    peakPending: 1000,
    siteDistribution: const {'SITE-SANDTON': 600, 'SITE-MIDRAND': 400},
    feedDistribution: const {'feed-01': 500, 'feed-02': 500},
    burstSize: 1000,
  );

  group('DispatchClipboardService', () {
    test('round-trips telemetry json', () {
      final raw = service.exportTelemetryJson(telemetry);
      final restored = service.importTelemetryJson(raw);

      expect(restored.toJson(), telemetry.toJson());
    });

    test('round-trips profile json', () {
      final raw = service.exportProfileJson(profile);
      final restored = service.importProfileJson(raw);

      expect(restored.toJson(), profile.toJson());
    });

    test('round-trips filter preset json', () {
      const preset = DispatchBenchmarkFilterPreset(
        name: 'Ops View',
        revision: 2,
        updatedAtUtc: '2026-03-03T12:00:00.000Z',
        showCancelledRuns: false,
        statusFilters: ['DEGRADED'],
        scenarioFilter: 'Hotspot replay',
        tagFilter: 'soak',
        noteFilter: 'handoff',
        sort: 'verifyAsc',
        historyLimit: 3,
      );

      final raw = service.exportFilterPresetJson(preset);
      final restored = service.importFilterPresetJson(raw);

      expect(restored.toJson(), preset.toJson());
    });

    test('round-trips snapshot json', () {
      const filterPresets = [
        DispatchBenchmarkFilterPreset(
          name: 'Ops View',
          updatedAtUtc: '2026-03-03T12:00:00.000Z',
          showCancelledRuns: false,
          statusFilters: ['DEGRADED'],
          scenarioFilter: 'Hotspot replay',
          tagFilter: 'soak',
          noteFilter: 'handoff',
          sort: 'verifyAsc',
          historyLimit: 3,
        ),
      ];
      final raw = service.exportSnapshotJson(
        scenarioLabel: 'Hotspot replay',
        tags: const ['soak', 'skew'],
        runNote: 'Shift handoff',
        filterPresets: filterPresets,
        profile: profile,
        telemetry: telemetry,
      );
      final restored = service.importSnapshotJson(raw);

      expect(restored.scenarioLabel, 'Hotspot replay');
      expect(restored.version, 2);
      expect(restored.tags, const ['soak', 'skew']);
      expect(restored.runNote, 'Shift handoff');
      expect(
        restored.filterPresets.first.toJson(),
        filterPresets.first.toJson(),
      );
      expect(restored.profile.toJson(), profile.toJson());
      expect(restored.telemetry.toJson(), telemetry.toJson());
    });

    test('exports csv with header and row', () {
      final csv = service.exportTelemetryCsv(telemetry);

      expect(csv, contains('label,cancelled,scenarioLabel,tags,note,ranAtUtc'));
      expect(csv, contains('"STR-CLIP"'));
      expect(csv, contains('"feed-01"'));
    });

    test('throws descriptive errors for invalid payloads', () {
      expect(
        () => service.importTelemetryJson('[]'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('telemetry JSON'),
          ),
        ),
      );
      expect(
        () => service.importProfileJson('{broken'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Failed to import profile JSON'),
          ),
        ),
      );
    });
  });
}
