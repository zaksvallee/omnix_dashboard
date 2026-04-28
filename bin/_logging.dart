import 'dart:io';

/// Shared plain-text logging helpers for compiled ONYX binaries in `bin/`.
///
/// Why this exists:
/// `developer.log(...)` calls are invisible to journald in `dart compile exe`
/// builds running under systemd, so binaries need stdout/stderr-bound helpers
/// for production-visible logs.
///
/// Who uses it:
/// Other binaries in `bin/` import this file directly via `import '_logging.dart';`.
///
/// Why these functions are public:
/// Dart underscore-prefixed identifiers are library-private, so shared helpers
/// must be public to remain callable across multiple `bin/*.dart` entrypoints.
///
/// Audit reference:
/// Codex developer.log audit on 2026-04-28 found 107 `developer.log(...)`
/// calls across `bin/*.dart`, including 105 in `onyx_camera_worker.dart`.

void logInfo(String message) {
  stdout.writeln('[ONYX] $message');
}

void logWarn(String message, {Object? error, StackTrace? stackTrace}) {
  stderr.writeln('[ONYX] $message');
  if (error != null) {
    stderr.writeln('[ONYX]   error: $error');
  }
  if (stackTrace != null) {
    stderr.writeln('[ONYX]   stack: $stackTrace');
  }
}

void logError(String message, {Object? error, StackTrace? stackTrace}) {
  stderr.writeln('[ONYX] $message');
  if (error != null) {
    stderr.writeln('[ONYX]   error: $error');
  }
  if (stackTrace != null) {
    stderr.writeln('[ONYX]   stack: $stackTrace');
  }
}
