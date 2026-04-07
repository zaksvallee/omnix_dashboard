import 'dart:convert';
import 'dart:io';

class HikConnectBundleSanitizer {
  const HikConnectBundleSanitizer();

  Future<List<String>> sanitizeBundleDirectory({
    required String sourceDirectoryPath,
    required String targetDirectoryPath,
  }) async {
    final source = Directory(sourceDirectoryPath.trim());
    final target = Directory(targetDirectoryPath.trim());
    if (!source.existsSync()) {
      throw ArgumentError('Source bundle directory does not exist: ${source.path}');
    }
    if (!target.existsSync()) {
      await target.create(recursive: true);
    }

    final written = <String>[];
    await for (final entity in source.list(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final relativePath = entity.path.substring(source.path.length + 1);
      final output = File('${target.path}/$relativePath');
      if (!output.parent.existsSync()) {
        await output.parent.create(recursive: true);
      }
      final lowerPath = relativePath.toLowerCase();
      if (lowerPath.endsWith('.json')) {
        final raw = await entity.readAsString();
        final sanitized = sanitizeJsonString(raw);
        await output.writeAsString('$sanitized\n');
      } else if (_isTextArtifact(lowerPath)) {
        final raw = await entity.readAsString();
        final sanitized = sanitizeText(raw);
        await output.writeAsString(sanitized);
      } else {
        await entity.copy(output.path);
      }
      written.add(output.path);
    }
    return List<String>.unmodifiable(written);
  }

  String sanitizeJsonString(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '{}';
    }
    final decoded = jsonDecode(trimmed);
    final sanitized = _sanitizeValue(decoded, parentKey: '');
    return const JsonEncoder.withIndent('  ').convert(sanitized);
  }

  String sanitizeText(String raw) {
    final urlSanitized = raw.replaceAllMapped(
      RegExp("([A-Za-z]+://[^\\s`'\\\"]+)"),
      (match) => _sanitizeUrlString(match.group(1) ?? ''),
    );
    return urlSanitized
        .split('\n')
        .map(_sanitizeTextLine)
        .join('\n');
  }

  Object? _sanitizeValue(Object? value, {required String parentKey}) {
    final normalizedKey = parentKey.trim().toLowerCase();
    if (value is Map) {
      final output = <String, Object?>{};
      for (final entry in value.entries) {
        output[entry.key.toString()] = _sanitizeValue(
          entry.value,
          parentKey: entry.key.toString(),
        );
      }
      return output;
    }
    if (value is List) {
      return value
          .map((entry) => _sanitizeValue(entry, parentKey: parentKey))
          .toList(growable: false);
    }
    if (value is String) {
      if (_looksSensitiveKey(normalizedKey)) {
        return '[REDACTED]';
      }
      if (_looksLikeUrl(value)) {
        return _sanitizeUrlString(value);
      }
      if (_looksSensitiveToken(value)) {
        return '[REDACTED]';
      }
      return value;
    }
    return value;
  }

  bool _looksSensitiveKey(String key) {
    return key.contains('token') ||
        key.contains('secret') ||
        key.contains('app_key') ||
        key.contains('appkey') ||
        key.contains('app_secret') ||
        key.contains('appsecret') ||
        key.contains('password') ||
        key.contains('bearer') ||
        key == 'appkey' ||
        key == 'app_key' ||
        key == 'appsecret' ||
        key == 'app_secret';
  }

  bool _looksLikeUrl(String raw) {
    final value = raw.trim().toLowerCase();
    return value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('ws://') ||
        value.startsWith('wss://') ||
        value.startsWith('rtsp://') ||
        value.startsWith('rtmp://');
  }

  bool _looksSensitiveToken(String raw) {
    final value = raw.trim();
    if (value.length < 24) {
      return false;
    }
    if (value.contains('.') && !value.contains(' ')) {
      return true;
    }
    return RegExp(r'^[A-Za-z0-9_\-+=/]{24,}$').hasMatch(value);
  }

  String _sanitizeUrlString(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.host.trim().isEmpty || uri.scheme.trim().isEmpty) {
      return '[REDACTED_URL]';
    }
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port/[REDACTED]';
  }

  String _sanitizeSensitiveLine(String line) {
    final assignmentIndex = line.indexOf('=');
    if (assignmentIndex != -1) {
      final prefix = line.substring(0, assignmentIndex + 1);
      return "$prefix '[REDACTED]'";
    }
    final index = line.indexOf(':');
    if (index != -1) {
      final prefix = line.substring(0, index + 1);
      return '$prefix [REDACTED]';
    }
    return '[REDACTED]';
  }

  bool _isTextArtifact(String lowerPath) {
    return lowerPath.endsWith('.md') ||
        lowerPath.endsWith('.txt') ||
        lowerPath.endsWith('.sh') ||
        lowerPath.endsWith('.env');
  }

  String _sanitizeTextLine(String line) {
    final normalized = line.toLowerCase();
    if (normalized.contains('token') ||
        normalized.contains('secret') ||
        normalized.contains('password') ||
        normalized.contains('bearer') ||
        normalized.contains('app_key') ||
        normalized.contains('appkey') ||
        normalized.contains('app_secret') ||
        normalized.contains('appsecret')) {
      return _sanitizeSensitiveLine(line);
    }
    return line;
  }
}
