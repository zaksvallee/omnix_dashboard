import 'dart:convert';

enum MonitoringIdentityPolicyAuditSource {
  unknown,
  manualEdit,
  importAll,
  importSite,
  clearSite,
  saveRuntime,
  resetRuntime,
}

extension MonitoringIdentityPolicyAuditSourceX
    on MonitoringIdentityPolicyAuditSource {
  String get persistenceKey {
    return switch (this) {
      MonitoringIdentityPolicyAuditSource.unknown => 'unknown',
      MonitoringIdentityPolicyAuditSource.manualEdit => 'manual_edit',
      MonitoringIdentityPolicyAuditSource.importAll => 'import_all',
      MonitoringIdentityPolicyAuditSource.importSite => 'import_site',
      MonitoringIdentityPolicyAuditSource.clearSite => 'clear_site',
      MonitoringIdentityPolicyAuditSource.saveRuntime => 'save_runtime',
      MonitoringIdentityPolicyAuditSource.resetRuntime => 'reset_runtime',
    };
  }

  String get label {
    return switch (this) {
      MonitoringIdentityPolicyAuditSource.unknown => 'Unknown',
      MonitoringIdentityPolicyAuditSource.manualEdit => 'Manual edit',
      MonitoringIdentityPolicyAuditSource.importAll => 'Runtime import',
      MonitoringIdentityPolicyAuditSource.importSite => 'Site import',
      MonitoringIdentityPolicyAuditSource.clearSite => 'Site clear',
      MonitoringIdentityPolicyAuditSource.saveRuntime => 'Runtime save',
      MonitoringIdentityPolicyAuditSource.resetRuntime => 'Reset to defaults',
    };
  }

  static MonitoringIdentityPolicyAuditSource fromPersistenceKey(String raw) {
    final normalized = raw.trim().toLowerCase();
    return MonitoringIdentityPolicyAuditSource.values.firstWhere(
      (value) => value.persistenceKey == normalized,
      orElse: () => MonitoringIdentityPolicyAuditSource.unknown,
    );
  }
}

class MonitoringIdentityPolicyAuditRecord {
  final DateTime recordedAtUtc;
  final MonitoringIdentityPolicyAuditSource source;
  final String message;

  const MonitoringIdentityPolicyAuditRecord({
    required this.recordedAtUtc,
    required this.source,
    required this.message,
  });

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'recorded_at_utc': recordedAtUtc.toIso8601String(),
      'source': source.persistenceKey,
      'message': message,
    };
  }

  String get recordedAtLabel {
    final year = recordedAtUtc.year.toString().padLeft(4, '0');
    final month = recordedAtUtc.month.toString().padLeft(2, '0');
    final day = recordedAtUtc.day.toString().padLeft(2, '0');
    final hour = recordedAtUtc.hour.toString().padLeft(2, '0');
    final minute = recordedAtUtc.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute UTC';
  }

  String get displayText {
    return '$recordedAtLabel • Source ${source.label} • $message';
  }

  static MonitoringIdentityPolicyAuditRecord? fromJson(Object? raw) {
    if (raw is String) {
      return fromLegacyString(raw);
    }
    if (raw is! Map) {
      return null;
    }
    final recordedAtRaw = (raw['recorded_at_utc'] ?? '').toString().trim();
    final message = (raw['message'] ?? '').toString().trim();
    if (recordedAtRaw.isEmpty || message.isEmpty) {
      return null;
    }
    final recordedAtUtc = DateTime.tryParse(recordedAtRaw)?.toUtc();
    if (recordedAtUtc == null) {
      return null;
    }
    final source = MonitoringIdentityPolicyAuditSourceX.fromPersistenceKey(
      (raw['source'] ?? '').toString(),
    );
    return MonitoringIdentityPolicyAuditRecord(
      recordedAtUtc: recordedAtUtc,
      source: source,
      message: message,
    );
  }

  static MonitoringIdentityPolicyAuditRecord? fromLegacyString(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final legacyMatch = RegExp(
      r'^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}) UTC • Source ([^•]+) • (.+)$',
    ).firstMatch(trimmed);
    if (legacyMatch != null) {
      final recordedAtUtc = DateTime.tryParse(
        '${legacyMatch.group(1)!.replaceFirst(' ', 'T')}:00Z',
      );
      if (recordedAtUtc != null) {
        final sourceLabel = legacyMatch.group(2)!.trim();
        final source = MonitoringIdentityPolicyAuditSource.values.firstWhere(
          (value) => value.label == sourceLabel,
          orElse: () => MonitoringIdentityPolicyAuditSource.unknown,
        );
        return MonitoringIdentityPolicyAuditRecord(
          recordedAtUtc: recordedAtUtc.toUtc(),
          source: source,
          message: legacyMatch.group(3)!.trim(),
        );
      }
    }
    return MonitoringIdentityPolicyAuditRecord(
      recordedAtUtc: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      source: MonitoringIdentityPolicyAuditSource.unknown,
      message: trimmed,
    );
  }
}

class MonitoringIdentityScopePolicy {
  final Set<String> allowedFaceMatchIds;
  final Set<String> flaggedFaceMatchIds;
  final Set<String> allowedPlateNumbers;
  final Set<String> flaggedPlateNumbers;

  const MonitoringIdentityScopePolicy({
    this.allowedFaceMatchIds = const <String>{},
    this.flaggedFaceMatchIds = const <String>{},
    this.allowedPlateNumbers = const <String>{},
    this.flaggedPlateNumbers = const <String>{},
  });

  MonitoringIdentityScopePolicy copyWith({
    Set<String>? allowedFaceMatchIds,
    Set<String>? flaggedFaceMatchIds,
    Set<String>? allowedPlateNumbers,
    Set<String>? flaggedPlateNumbers,
  }) {
    return MonitoringIdentityScopePolicy(
      allowedFaceMatchIds: allowedFaceMatchIds ?? this.allowedFaceMatchIds,
      flaggedFaceMatchIds: flaggedFaceMatchIds ?? this.flaggedFaceMatchIds,
      allowedPlateNumbers: allowedPlateNumbers ?? this.allowedPlateNumbers,
      flaggedPlateNumbers: flaggedPlateNumbers ?? this.flaggedPlateNumbers,
    );
  }

  bool get isEmpty =>
      allowedFaceMatchIds.isEmpty &&
      flaggedFaceMatchIds.isEmpty &&
      allowedPlateNumbers.isEmpty &&
      flaggedPlateNumbers.isEmpty;

  bool matchesAllowedFace(String? faceMatchId) {
    final normalized = _normalize(faceMatchId);
    return normalized.isNotEmpty && allowedFaceMatchIds.contains(normalized);
  }

  bool matchesFlaggedFace(String? faceMatchId) {
    final normalized = _normalize(faceMatchId);
    return normalized.isNotEmpty && flaggedFaceMatchIds.contains(normalized);
  }

  bool matchesAllowedPlate(String? plateNumber) {
    final normalized = _normalize(plateNumber);
    return normalized.isNotEmpty && allowedPlateNumbers.contains(normalized);
  }

  bool matchesFlaggedPlate(String? plateNumber) {
    final normalized = _normalize(plateNumber);
    return normalized.isNotEmpty && flaggedPlateNumbers.contains(normalized);
  }

  static String _normalize(String? value) {
    return (value ?? '').trim().toUpperCase();
  }
}

class MonitoringIdentityScopePolicyEntry {
  final String clientId;
  final String siteId;
  final MonitoringIdentityScopePolicy policy;

  const MonitoringIdentityScopePolicyEntry({
    required this.clientId,
    required this.siteId,
    required this.policy,
  });
}

class MonitoringIdentityPolicyService {
  final Map<String, MonitoringIdentityScopePolicy> _policiesByScope;

  const MonitoringIdentityPolicyService({
    Map<String, MonitoringIdentityScopePolicy> policiesByScope = const {},
  }) : _policiesByScope = policiesByScope;

  MonitoringIdentityPolicyService copyWith({
    Map<String, MonitoringIdentityScopePolicy>? policiesByScope,
  }) {
    return MonitoringIdentityPolicyService(
      policiesByScope: policiesByScope ?? _policiesByScope,
    );
  }

  MonitoringIdentityScopePolicy policyFor({
    required String clientId,
    required String siteId,
  }) {
    final scopeKey = _scopeKey(clientId, siteId);
    return _policiesByScope[scopeKey] ?? const MonitoringIdentityScopePolicy();
  }

  List<MonitoringIdentityScopePolicyEntry> get entries {
    final output = <MonitoringIdentityScopePolicyEntry>[];
    for (final entry in _policiesByScope.entries) {
      final parts = entry.key.split('|');
      if (parts.length != 2) {
        continue;
      }
      output.add(
        MonitoringIdentityScopePolicyEntry(
          clientId: parts.first,
          siteId: parts.last,
          policy: entry.value,
        ),
      );
    }
    output.sort((a, b) {
      final clientCompare = a.clientId.compareTo(b.clientId);
      if (clientCompare != 0) {
        return clientCompare;
      }
      return a.siteId.compareTo(b.siteId);
    });
    return output;
  }

  MonitoringIdentityPolicyService updateScopePolicy({
    required String clientId,
    required String siteId,
    required MonitoringIdentityScopePolicy policy,
  }) {
    final nextPolicies = Map<String, MonitoringIdentityScopePolicy>.from(
      _policiesByScope,
    );
    final scopeKey = _scopeKey(clientId, siteId);
    if (policy.isEmpty) {
      nextPolicies.remove(scopeKey);
    } else {
      nextPolicies[scopeKey] = policy;
    }
    return MonitoringIdentityPolicyService(policiesByScope: nextPolicies);
  }

  List<Map<String, Object?>> toJsonItems() {
    return entries
        .map(
          (entry) => <String, Object?>{
            'client_id': entry.clientId,
            'site_id': entry.siteId,
            'allowed_face_match_ids': entry.policy.allowedFaceMatchIds.toList()
              ..sort(),
            'flagged_face_match_ids': entry.policy.flaggedFaceMatchIds.toList()
              ..sort(),
            'allowed_plate_numbers': entry.policy.allowedPlateNumbers.toList()
              ..sort(),
            'flagged_plate_numbers': entry.policy.flaggedPlateNumbers.toList()
              ..sort(),
          },
        )
        .toList(growable: false);
  }

  String toCanonicalJsonString() {
    return jsonEncode(toJsonItems());
  }

  static MonitoringIdentityPolicyService parseJson(String rawJson) {
    final trimmed = rawJson.trim();
    if (trimmed.isEmpty) {
      return const MonitoringIdentityPolicyService();
    }
    final decoded = jsonDecode(trimmed);
    final rawItems = switch (decoded) {
      List value => value,
      Map value => value['items'] is List ? value['items'] as List : const [],
      _ => const [],
    };
    final policies = <String, MonitoringIdentityScopePolicy>{};
    for (final item in rawItems.whereType<Map>()) {
      String readString(String key) => (item[key] ?? '').toString().trim();
      Set<String> readSet(String key) {
        final raw = item[key];
        final values = switch (raw) {
          List value => value,
          String value when value.trim().isNotEmpty => value.split(','),
          _ => const [],
        };
        return values
            .map((entry) => entry.toString().trim().toUpperCase())
            .where((entry) => entry.isNotEmpty)
            .toSet();
      }

      final clientId = readString('client_id');
      final siteId = readString('site_id');
      if (clientId.isEmpty || siteId.isEmpty) {
        continue;
      }
      final policy = MonitoringIdentityScopePolicy(
        allowedFaceMatchIds: readSet('allowed_face_match_ids'),
        flaggedFaceMatchIds: readSet('flagged_face_match_ids'),
        allowedPlateNumbers: readSet('allowed_plate_numbers'),
        flaggedPlateNumbers: readSet('flagged_plate_numbers'),
      );
      if (policy.isEmpty) {
        continue;
      }
      policies[_scopeKey(clientId, siteId)] = policy;
    }
    return MonitoringIdentityPolicyService(policiesByScope: policies);
  }

  static String _scopeKey(String clientId, String siteId) {
    return '${clientId.trim()}|${siteId.trim()}';
  }
}
