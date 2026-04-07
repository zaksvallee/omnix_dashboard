import 'dart:io';

import 'package:omnix_dashboard/application/hik_connect_payload_bundle_template_service.dart';

Future<void> main(List<String> args) async {
  final env = Platform.environment;
  final targetPath = args.isNotEmpty
      ? args.first.trim()
      : (env['ONYX_DVR_PREFLIGHT_DIR'] ?? '').trim();
  if (targetPath.isEmpty) {
    stderr.writeln(
      'Provide a target directory as the first argument or set ONYX_DVR_PREFLIGHT_DIR.',
    );
    stderr.writeln();
    stderr.writeln(
      'Example: dart run tool/hik_connect_init_bundle.dart /absolute/path/to/bundle',
    );
    exitCode = 64;
    return;
  }

  final clientId = (env['ONYX_DVR_CLIENT_ID'] ?? 'CLIENT-REPLACE-ME').trim();
  final regionId = (env['ONYX_DVR_REGION_ID'] ?? 'REGION-REPLACE-ME').trim();
  final siteId = (env['ONYX_DVR_SITE_ID'] ?? 'SITE-REPLACE-ME').trim();
  final apiBaseUrl =
      (env['ONYX_DVR_API_BASE_URL'] ?? 'https://api.hik-connect.example.com')
          .trim();

  try {
    const service = HikConnectPayloadBundleTemplateService();
    final result = await service.createBundle(
      directoryPath: targetPath,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      apiBaseUrl: apiBaseUrl,
    );

    stdout.writeln('HIK-CONNECT BUNDLE READY');
    stdout.writeln(result.directoryPath);
    stdout.writeln('- manifest: ${result.manifestPath}');
    for (final path in result.payloadPaths) {
      stdout.writeln('- payload: $path');
    }
    stdout.writeln();
    stdout.writeln(
      'Next: replace the placeholder JSON files, then run:',
    );
    stdout.writeln(
      'ONYX_DVR_PREFLIGHT_DIR="${result.directoryPath}" dart run tool/hik_connect_preflight.dart',
    );
  } on Object catch (error, stackTrace) {
    stderr.writeln('Hik-Connect bundle init failed: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}
