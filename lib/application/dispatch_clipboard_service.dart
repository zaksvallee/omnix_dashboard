import 'dart:convert';

import '../ui/dispatch_models.dart';

class DispatchClipboardService {
  const DispatchClipboardService();

  String exportTelemetryJson(IntakeTelemetry telemetry) {
    return jsonEncode(telemetry.toJson());
  }

  IntakeTelemetry importTelemetryJson(String raw) {
    final map = _decodeMap(raw, expected: 'telemetry JSON');
    return IntakeTelemetry.fromJson(map);
  }

  String exportTelemetryCsv(IntakeTelemetry telemetry) {
    const header =
        'label,cancelled,scenarioLabel,tags,note,ranAtUtc,attempted,appended,skipped,decisions,throughput,p50,p95,verifyMs,chunkSize,chunks,avgChunkMs,maxChunkMs,slowChunks,duplicatesInjected,uniqueFeeds,peakPending,topSite,topSiteCount,topFeed,topFeedCount';
    final rows = telemetry.recentRuns
        .map((run) {
          final fields = [
            run.label,
            run.cancelled.toString(),
            run.scenarioLabel,
            run.tags.join('|'),
            run.note,
            run.ranAtUtc.toIso8601String(),
            run.attempted.toString(),
            run.appended.toString(),
            run.skipped.toString(),
            run.decisions.toString(),
            run.throughput.toStringAsFixed(3),
            run.p50.toStringAsFixed(3),
            run.p95.toStringAsFixed(3),
            run.verifyMs.toString(),
            run.chunkSize.toString(),
            run.chunks.toString(),
            run.avgChunkMs.toStringAsFixed(3),
            run.maxChunkMs.toString(),
            run.slowChunks.toString(),
            run.duplicatesInjected.toString(),
            run.uniqueFeeds.toString(),
            run.peakPending.toString(),
            run.hottestSite?.key ?? '',
            (run.hottestSite?.value ?? 0).toString(),
            run.hottestFeed?.key ?? '',
            (run.hottestFeed?.value ?? 0).toString(),
          ];
          return fields.map(_csvEscape).join(',');
        })
        .join('\n');

    return rows.isEmpty ? header : '$header\n$rows';
  }

  String exportProfileJson(IntakeStressProfile profile) {
    return jsonEncode(profile.toJson());
  }

  IntakeStressProfile importProfileJson(String raw) {
    final map = _decodeMap(raw, expected: 'profile JSON');
    return IntakeStressProfile.fromJson(map);
  }

  String exportFilterPresetJson(DispatchBenchmarkFilterPreset preset) {
    return jsonEncode(preset.toJson());
  }

  DispatchBenchmarkFilterPreset importFilterPresetJson(String raw) {
    final map = _decodeMap(raw, expected: 'filter preset JSON');
    return DispatchBenchmarkFilterPreset.fromJson(map);
  }

  String exportSnapshotJson({
    String scenarioLabel = '',
    List<String> tags = const [],
    String runNote = '',
    List<DispatchBenchmarkFilterPreset> filterPresets = const [],
    required IntakeStressProfile profile,
    required IntakeTelemetry telemetry,
  }) {
    return jsonEncode(
      DispatchSnapshot(
        scenarioLabel: scenarioLabel,
        tags: tags,
        runNote: runNote,
        filterPresets: filterPresets,
        profile: profile,
        telemetry: telemetry,
      ).toJson(),
    );
  }

  DispatchSnapshot importSnapshotJson(String raw) {
    final map = _decodeMap(raw, expected: 'snapshot JSON');
    return DispatchSnapshot.fromJson(map);
  }

  Map<String, Object?> _decodeMap(String raw, {required String expected}) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw FormatException('Clipboard does not contain $expected');
      }
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value as Object?),
      );
    } on FormatException catch (error) {
      if (error.message.toString().startsWith('Clipboard does not contain')) {
        rethrow;
      }
      throw FormatException('Failed to import $expected');
    } catch (_) {
      throw FormatException('Failed to import $expected');
    }
  }

  String _csvEscape(String raw) {
    final escaped = raw.replaceAll('"', '""');
    return '"$escaped"';
  }
}
