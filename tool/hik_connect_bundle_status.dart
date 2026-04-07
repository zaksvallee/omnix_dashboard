import 'dart:io';
import 'dart:convert';

import 'package:omnix_dashboard/application/hik_connect_payload_bundle_locator.dart';
import 'package:omnix_dashboard/application/hik_connect_bundle_status_service.dart';

Future<void> main(List<String> args) async {
  final env = Platform.environment;
  final jsonMode = args.any((arg) => arg.trim() == '--json');
  final strictMode = args.any((arg) => arg.trim() == '--strict');
  final maxAgeHours = _readMaxAgeHours(args, env);
  final positionalArgs = args
      .map((arg) => arg.trim())
      .where(
        (arg) =>
            arg.isNotEmpty &&
            arg != '--json' &&
            arg != '--strict' &&
            !arg.startsWith('--max-age-hours='),
      )
      .toList(growable: false);
  final bundleDirectoryPath = positionalArgs.isNotEmpty
      ? positionalArgs.first
      : (env['ONYX_DVR_PREFLIGHT_DIR'] ?? '').trim();

  if (bundleDirectoryPath.isEmpty) {
    stderr.writeln(
      'Provide a bundle directory as the first argument or set ONYX_DVR_PREFLIGHT_DIR.',
    );
    stderr.writeln();
    stderr.writeln(
      'Example: dart run tool/hik_connect_bundle_status.dart /absolute/path/to/bundle',
    );
    exitCode = 64;
    return;
  }

  try {
    const locator = HikConnectPayloadBundleLocator();
    final bundle = locator.resolveFromEnvironment(<String, String>{
      ...env,
      'ONYX_DVR_PREFLIGHT_DIR': bundleDirectoryPath,
    });
    final effectiveMaxAgeHours = maxAgeHours > 0
        ? maxAgeHours
        : bundle.statusMaxAgeHours;
    const service = HikConnectBundleStatusService();
    final result = await service.load(
      bundleDirectoryPath: bundleDirectoryPath,
      maxAllowedAgeHours: effectiveMaxAgeHours,
    );
    if (jsonMode) {
      final encoded = const JsonEncoder.withIndent('  ').convert(result.toJson());
      stdout.writeln(encoded);
    } else {
      stdout.writeln(result.buildSummary());
    }
    if (strictMode && !result.strictReady) {
      exitCode = 2;
    }
  } on Object catch (error, stackTrace) {
    stderr.writeln('Hik-Connect bundle status failed: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}

int _readMaxAgeHours(List<String> args, Map<String, String> env) {
  for (final arg in args) {
    final trimmed = arg.trim();
    if (!trimmed.startsWith('--max-age-hours=')) {
      continue;
    }
    final value = trimmed.substring('--max-age-hours='.length).trim();
    final parsed = int.tryParse(value);
    if (parsed != null && parsed > 0) {
      return parsed;
    }
  }
  final envValue = (env['ONYX_DVR_BUNDLE_MAX_AGE_HOURS'] ?? '').trim();
  final parsed = int.tryParse(envValue);
  if (parsed != null && parsed > 0) {
    return parsed;
  }
  return 0;
}
