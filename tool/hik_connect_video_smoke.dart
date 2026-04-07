import 'dart:io';

import 'package:omnix_dashboard/application/hik_connect_video_payload_loader.dart';
import 'package:omnix_dashboard/application/hik_connect_video_smoke_service.dart';

Future<void> main() async {
  final env = Platform.environment;
  final livePath = (env['ONYX_DVR_LIVE_ADDRESS_PAYLOAD_PATH'] ?? '').trim();
  final playbackPath = (env['ONYX_DVR_PLAYBACK_PAYLOAD_PATH'] ?? '').trim();
  final downloadPath =
      (env['ONYX_DVR_VIDEO_DOWNLOAD_PAYLOAD_PATH'] ?? '').trim();

  if (livePath.isEmpty && playbackPath.isEmpty && downloadPath.isEmpty) {
    stderr.writeln('Hik-Connect video smoke is missing payload paths.');
    stderr.writeln();
    stderr.writeln('Provide at least one of:');
    stderr.writeln('- ONYX_DVR_LIVE_ADDRESS_PAYLOAD_PATH');
    stderr.writeln('- ONYX_DVR_PLAYBACK_PAYLOAD_PATH');
    stderr.writeln('- ONYX_DVR_VIDEO_DOWNLOAD_PAYLOAD_PATH');
    stderr.writeln();
    stderr.writeln('Then run: dart run tool/hik_connect_video_smoke.dart');
    exitCode = 64;
    return;
  }

  try {
    const loader = HikConnectVideoPayloadLoader();
    const service = HikConnectVideoSmokeService();
    final liveResponse = livePath.isEmpty
        ? null
        : await loader.loadResponseFromFile(livePath);
    final playbackResponse = playbackPath.isEmpty
        ? null
        : await loader.loadResponseFromFile(playbackPath);
    final downloadResponse = downloadPath.isEmpty
        ? null
        : await loader.loadResponseFromFile(downloadPath);

    final result = service.evaluate(
      liveAddressResponse: liveResponse,
      playbackSearchResponse: playbackResponse,
      videoDownloadResponse: downloadResponse,
    );

    if (!result.hasAnyData) {
      stdout.writeln('No video payload data was parsed.');
      return;
    }

    if (result.liveAddress != null) {
      stdout.writeln('Live Address');
      stdout.writeln('- primary: ${result.liveAddress!.primaryUrl}');
      if (result.liveAddress!.urlsByKey.isNotEmpty) {
        for (final entry in result.liveAddress!.urlsByKey.entries) {
          stdout.writeln('- ${entry.key}: ${entry.value}');
        }
      }
      stdout.writeln();
    }

    if (result.playbackCatalog != null) {
      stdout.writeln('Playback Catalog');
      stdout.writeln(
        '- total: ${result.playbackCatalog!.totalCount} '
        '(page ${result.playbackCatalog!.pageIndex}, size ${result.playbackCatalog!.pageSize})',
      );
      for (final record in result.playbackCatalog!.records) {
        stdout.writeln('- ${record.recordId}');
        stdout.writeln('  begin: ${record.beginTime}');
        stdout.writeln('  end: ${record.endTime}');
        stdout.writeln('  playback: ${record.playbackUrl}');
      }
      stdout.writeln();
    }

    if (result.downloadResult != null) {
      stdout.writeln('Download URL');
      stdout.writeln('- ${result.downloadResult!.downloadUrl}');
    }
  } on Object catch (error, stackTrace) {
    stderr.writeln('Hik-Connect video smoke failed: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}
