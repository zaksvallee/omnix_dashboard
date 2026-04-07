import 'dart:io';

import 'package:omnix_dashboard/application/hik_connect_bundle_sanitizer.dart';

Future<void> main(List<String> args) async {
  final env = Platform.environment;
  final source = args.isNotEmpty
      ? args.first.trim()
      : (env['ONYX_DVR_PREFLIGHT_DIR'] ?? '').trim();
  final target = args.length > 1
      ? args[1].trim()
      : (env['ONYX_DVR_SANITIZED_BUNDLE_DIR'] ?? '').trim();

  if (source.isEmpty || target.isEmpty) {
    stderr.writeln(
      'Provide source and target bundle directories as arguments, or set ONYX_DVR_PREFLIGHT_DIR and ONYX_DVR_SANITIZED_BUNDLE_DIR.',
    );
    stderr.writeln();
    stderr.writeln(
      'Example: dart run tool/hik_connect_export_sanitized_bundle.dart /path/to/source /path/to/sanitized',
    );
    exitCode = 64;
    return;
  }

  try {
    const sanitizer = HikConnectBundleSanitizer();
    final written = await sanitizer.sanitizeBundleDirectory(
      sourceDirectoryPath: source,
      targetDirectoryPath: target,
    );
    stdout.writeln('HIK-CONNECT SANITIZED BUNDLE READY');
    stdout.writeln(target);
    stdout.writeln('- files: ${written.length}');
  } on Object catch (error, stackTrace) {
    stderr.writeln('Hik-Connect sanitized export failed: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}
