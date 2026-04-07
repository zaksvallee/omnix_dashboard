import 'dart:convert';

import 'package:http/http.dart' as http;

class MonitoringYoloDetectorModuleSnapshot {
  final String name;
  final bool enabled;
  final bool configured;
  final bool ready;
  final String detail;
  final Map<String, Object?> metadata;

  const MonitoringYoloDetectorModuleSnapshot({
    required this.name,
    required this.enabled,
    required this.configured,
    required this.ready,
    this.detail = '',
    this.metadata = const <String, Object?>{},
  });

  bool get healthy => !enabled || ready;
}

class MonitoringYoloDetectorHealthSnapshot {
  final Uri endpoint;
  final bool reachable;
  final bool ready;
  final String backend;
  final String detail;
  final String? lastError;
  final DateTime? lastRequestAtUtc;
  final DateTime? lastSuccessAtUtc;
  final int successfulRequestCount;
  final Map<String, MonitoringYoloDetectorModuleSnapshot> modules;

  const MonitoringYoloDetectorHealthSnapshot({
    required this.endpoint,
    required this.reachable,
    required this.ready,
    this.backend = '',
    this.detail = '',
    this.lastError,
    this.lastRequestAtUtc,
    this.lastSuccessAtUtc,
    this.successfulRequestCount = 0,
    this.modules = const <String, MonitoringYoloDetectorModuleSnapshot>{},
  });

  bool get healthy => reachable && ready;

  Iterable<MonitoringYoloDetectorModuleSnapshot> get unhealthyEnabledModules {
    return modules.values.where((module) => module.enabled && !module.ready);
  }
}

abstract class MonitoringYoloDetectorHealthService {
  Future<MonitoringYoloDetectorHealthSnapshot?> read(Uri detectEndpoint);
}

class HttpMonitoringYoloDetectorHealthService
    implements MonitoringYoloDetectorHealthService {
  final http.Client client;
  final Duration timeout;
  final String authToken;

  const HttpMonitoringYoloDetectorHealthService({
    required this.client,
    this.timeout = const Duration(seconds: 2),
    this.authToken = '',
  });

  @override
  Future<MonitoringYoloDetectorHealthSnapshot?> read(Uri detectEndpoint) async {
    final healthEndpoint = detectEndpoint.replace(
      path: '/health',
      query: null,
      fragment: null,
    );
    try {
      final response = await client
          .get(
            healthEndpoint,
            headers: <String, String>{
              'Accept': 'application/json',
              if (authToken.trim().isNotEmpty)
                'Authorization': 'Bearer ${authToken.trim()}',
            },
          )
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return MonitoringYoloDetectorHealthSnapshot(
          endpoint: healthEndpoint,
          reachable: false,
          ready: false,
          detail: 'YOLO health HTTP ${response.statusCode}',
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return MonitoringYoloDetectorHealthSnapshot(
          endpoint: healthEndpoint,
          reachable: false,
          ready: false,
          detail: 'YOLO health returned an invalid payload.',
        );
      }
      final payload = decoded.cast<Object?, Object?>();
      return MonitoringYoloDetectorHealthSnapshot(
        endpoint: healthEndpoint,
        reachable: true,
        ready: payload['ready'] == true,
        backend: (payload['backend'] ?? '').toString().trim(),
        detail: (payload['detail'] ?? '').toString().trim(),
        lastError: _normalizedString(
          payload['last_request_error'] ?? payload['last_error'],
        ),
        lastRequestAtUtc: _epochSecondsToUtc(payload['last_request_at_epoch']),
        lastSuccessAtUtc: _epochSecondsToUtc(payload['last_success_at_epoch']),
        successfulRequestCount:
            _intValue(payload['successful_request_count']) ?? 0,
        modules: _moduleSnapshots(payload['modules']),
      );
    } catch (error) {
      return MonitoringYoloDetectorHealthSnapshot(
        endpoint: healthEndpoint,
        reachable: false,
        ready: false,
        detail: error.toString(),
      );
    }
  }

  static String? _normalizedString(Object? value) {
    final normalized = (value ?? '').toString().trim();
    return normalized.isEmpty ? null : normalized;
  }

  static DateTime? _epochSecondsToUtc(Object? rawValue) {
    final seconds = switch (rawValue) {
      int value => value.toDouble(),
      num value => value.toDouble(),
      String value => double.tryParse(value.trim()),
      _ => null,
    };
    if (seconds == null || !seconds.isFinite) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(
      (seconds * 1000).round(),
      isUtc: true,
    );
  }

  static int? _intValue(Object? rawValue) {
    return switch (rawValue) {
      int value => value,
      num value => value.round(),
      String value => int.tryParse(value.trim()),
      _ => null,
    };
  }

  static Map<String, MonitoringYoloDetectorModuleSnapshot> _moduleSnapshots(
    Object? rawModules,
  ) {
    if (rawModules is! Map) {
      return const <String, MonitoringYoloDetectorModuleSnapshot>{};
    }
    final modules = <String, MonitoringYoloDetectorModuleSnapshot>{};
    for (final entry in rawModules.entries) {
      final name = entry.key.toString().trim();
      final value = entry.value;
      if (name.isEmpty || value is! Map) {
        continue;
      }
      final payload = value.cast<Object?, Object?>();
      final metadata = <String, Object?>{};
      for (final item in payload.entries) {
        final key = item.key.toString().trim();
        if (key.isEmpty ||
            key == 'enabled' ||
            key == 'configured' ||
            key == 'ready' ||
            key == 'detail') {
          continue;
        }
        metadata[key] = item.value;
      }
      modules[name] = MonitoringYoloDetectorModuleSnapshot(
        name: name,
        enabled: payload['enabled'] == true,
        configured: payload['configured'] == true,
        ready: payload['ready'] == true,
        detail: (payload['detail'] ?? '').toString().trim(),
        metadata: Map<String, Object?>.unmodifiable(metadata),
      );
    }
    return Map<String, MonitoringYoloDetectorModuleSnapshot>.unmodifiable(
      modules,
    );
  }
}
