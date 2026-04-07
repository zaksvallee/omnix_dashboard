import 'dart:io';

import 'package:omnix_dashboard/application/hik_connect_alarm_payload_loader.dart';
import 'package:omnix_dashboard/application/hik_connect_alarm_smoke_service.dart';

Future<void> main() async {
  final env = Platform.environment;
  final clientId = (env['ONYX_DVR_CLIENT_ID'] ?? '').trim();
  final regionId = (env['ONYX_DVR_REGION_ID'] ?? '').trim();
  final siteId = (env['ONYX_DVR_SITE_ID'] ?? '').trim();
  final payloadPath = (env['ONYX_DVR_ALARM_PAYLOAD_PATH'] ?? '').trim();
  final apiBaseUrl =
      (env['ONYX_DVR_API_BASE_URL'] ?? 'https://api.hik-connect.example.com')
          .trim();

  final errors = <String>[];
  if (clientId.isEmpty) {
    errors.add('Missing ONYX_DVR_CLIENT_ID.');
  }
  if (regionId.isEmpty) {
    errors.add('Missing ONYX_DVR_REGION_ID.');
  }
  if (siteId.isEmpty) {
    errors.add('Missing ONYX_DVR_SITE_ID.');
  }
  if (payloadPath.isEmpty) {
    errors.add('Missing ONYX_DVR_ALARM_PAYLOAD_PATH.');
  }
  final baseUri = Uri.tryParse(apiBaseUrl);
  if (baseUri == null || !baseUri.hasScheme || baseUri.host.trim().isEmpty) {
    errors.add(
      'Missing or invalid ONYX_DVR_API_BASE_URL. Use a full HTTPS base URL.',
    );
  }
  if (errors.isNotEmpty) {
    stderr.writeln('Hik-Connect alarm smoke is missing required env values:');
    for (final error in errors) {
      stderr.writeln('- $error');
    }
    stderr.writeln();
    stderr.writeln('Required env keys:');
    stderr.writeln('- ONYX_DVR_CLIENT_ID');
    stderr.writeln('- ONYX_DVR_REGION_ID');
    stderr.writeln('- ONYX_DVR_SITE_ID');
    stderr.writeln('- ONYX_DVR_ALARM_PAYLOAD_PATH');
    stderr.writeln();
    stderr.writeln(
      'Optional env key: ONYX_DVR_API_BASE_URL (defaults to https://api.hik-connect.example.com)',
    );
    stderr.writeln();
    stderr.writeln('Then run: dart run tool/hik_connect_alarm_smoke.dart');
    exitCode = 64;
    return;
  }

  try {
    const loader = HikConnectAlarmPayloadLoader();
    const service = HikConnectAlarmSmokeService();
    final batch = await loader.loadBatchFromFile(payloadPath);
    final result = service.evaluateBatch(
      batch,
      baseUri: baseUri!,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
    );

    stdout.writeln(
      'NORMALIZED ${result.normalizedRecords.length}/${result.totalMessages}',
    );
    if (batch.batchId.trim().isNotEmpty) {
      stdout.writeln('Batch ${batch.batchId}');
    }
    if (result.droppedMessages > 0) {
      stdout.writeln('Dropped ${result.droppedMessages} message(s)');
    }
    stdout.writeln();
    for (final record in result.normalizedRecords) {
      stdout.writeln('- ${record.headline}');
      stdout.writeln('  externalId: ${record.externalId}');
      stdout.writeln('  occurredAtUtc: ${record.occurredAtUtc.toUtc().toIso8601String()}');
      stdout.writeln('  cameraId: ${record.cameraId ?? ''}');
      stdout.writeln('  zone: ${record.zone ?? ''}');
      if ((record.plateNumber ?? '').isNotEmpty) {
        stdout.writeln('  plate: ${record.plateNumber}');
      }
      stdout.writeln('  risk: ${record.riskScore}');
      stdout.writeln('  summary: ${record.summary}');
      if ((record.snapshotUrl ?? '').isNotEmpty) {
        stdout.writeln('  snapshot: ${record.snapshotUrl}');
      }
      if ((record.clipUrl ?? '').isNotEmpty) {
        stdout.writeln('  clip: ${record.clipUrl}');
      }
      stdout.writeln();
    }
  } on Object catch (error, stackTrace) {
    stderr.writeln('Hik-Connect alarm smoke failed: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}
