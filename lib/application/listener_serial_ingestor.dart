import 'dart:convert';

import '../domain/intelligence/intel_ingestion.dart';

class ListenerSerialEnvelope {
  final String provider;
  final String transport;
  final String externalId;
  final String rawLine;
  final String accountNumber;
  final String partition;
  final String eventCode;
  final String eventQualifier;
  final String zone;
  final String userCode;
  final String siteId;
  final String clientId;
  final String regionId;
  final DateTime occurredAtUtc;
  final Map<String, Object?> metadata;

  const ListenerSerialEnvelope({
    required this.provider,
    required this.transport,
    required this.externalId,
    required this.rawLine,
    required this.accountNumber,
    required this.partition,
    required this.eventCode,
    required this.eventQualifier,
    required this.zone,
    required this.userCode,
    required this.siteId,
    required this.clientId,
    required this.regionId,
    required this.occurredAtUtc,
    this.metadata = const {},
  });

  Map<String, Object?> toJson() {
    return {
      'provider': provider,
      'transport': transport,
      'external_id': externalId,
      'raw_line': rawLine,
      'account_number': accountNumber,
      'partition': partition,
      'event_code': eventCode,
      'event_qualifier': eventQualifier,
      'zone': zone,
      'user_code': userCode,
      'site_id': siteId,
      'client_id': clientId,
      'region_id': regionId,
      'occurred_at_utc': occurredAtUtc.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory ListenerSerialEnvelope.fromJson(Map<String, Object?> json) {
    return ListenerSerialEnvelope(
      provider: (json['provider'] ?? '').toString().trim(),
      transport: (json['transport'] ?? '').toString().trim(),
      externalId: (json['external_id'] ?? '').toString().trim(),
      rawLine: (json['raw_line'] ?? '').toString(),
      accountNumber: (json['account_number'] ?? '').toString().trim(),
      partition: (json['partition'] ?? '').toString().trim(),
      eventCode: (json['event_code'] ?? '').toString().trim(),
      eventQualifier: (json['event_qualifier'] ?? '').toString().trim(),
      zone: (json['zone'] ?? '').toString().trim(),
      userCode: (json['user_code'] ?? '').toString().trim(),
      siteId: (json['site_id'] ?? '').toString().trim(),
      clientId: (json['client_id'] ?? '').toString().trim(),
      regionId: (json['region_id'] ?? '').toString().trim(),
      occurredAtUtc:
          DateTime.tryParse((json['occurred_at_utc'] ?? '').toString())
              ?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      metadata: _objectMap(json['metadata']),
    );
  }
}

class ListenerSerialBenchParseResult {
  final List<ListenerSerialEnvelope> accepted;
  final List<ListenerSerialReject> rejectedEntries;

  const ListenerSerialBenchParseResult({
    required this.accepted,
    required this.rejectedEntries,
  });

  List<String> get rejected =>
      rejectedEntries.map((entry) => entry.line).toList(growable: false);

  Map<String, int> get rejectReasonCounts {
    final counts = <String, int>{};
    for (final entry in rejectedEntries) {
      counts.update(entry.reason, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  Map<String, int> get timestampSourceCounts {
    final counts = <String, int>{};
    for (final envelope in accepted) {
      final source = envelope.metadata['timestamp_source']?.toString().trim();
      if (source == null || source.isEmpty) {
        continue;
      }
      counts.update(source, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  Map<String, int> get warningCounts {
    final counts = <String, int>{};
    for (final envelope in accepted) {
      final warnings = envelope.metadata['normalization_warnings'];
      if (warnings is List) {
        for (final warning in warnings) {
          final value = warning?.toString().trim() ?? '';
          if (value.isEmpty) {
            continue;
          }
          counts.update(value, (count) => count + 1, ifAbsent: () => 1);
        }
        continue;
      }
      final warning = envelope.metadata['normalization_warning']
          ?.toString()
          .trim();
      if (warning == null || warning.isEmpty) {
        continue;
      }
      counts.update(warning, (count) => count + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  Map<String, int> get eventCodeCounts {
    final counts = <String, int>{};
    for (final envelope in accepted) {
      final eventCode = envelope.eventCode.trim();
      if (eventCode.isEmpty) {
        continue;
      }
      counts.update(eventCode, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  Map<String, int> get qualifierCounts {
    final counts = <String, int>{};
    for (final envelope in accepted) {
      final qualifier = envelope.eventQualifier.trim();
      if (qualifier.isEmpty) {
        continue;
      }
      counts.update(qualifier, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  Map<String, int> get parseModeCounts {
    final counts = <String, int>{};
    for (final envelope in accepted) {
      final parseMode = envelope.metadata['parse_mode']?.toString().trim();
      if (parseMode == null || parseMode.isEmpty) {
        continue;
      }
      counts.update(parseMode, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  Map<String, int> get captureSignatureCounts {
    final counts = <String, int>{};
    for (final envelope in accepted) {
      final signature = envelope.metadata['capture_signature']?.toString().trim();
      if (signature == null || signature.isEmpty) {
        continue;
      }
      counts.update(signature, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }
}

class ListenerSerialReject {
  final String line;
  final int lineNumber;
  final String reason;

  const ListenerSerialReject({
    required this.line,
    required this.lineNumber,
    required this.reason,
  });

  Map<String, Object?> toJson() {
    return {
      'line': line,
      'line_number': lineNumber,
      'reason': reason,
    };
  }
}

class ListenerSerialParseAttempt {
  final ListenerSerialEnvelope? envelope;
  final String? rejectReason;

  const ListenerSerialParseAttempt._({
    this.envelope,
    this.rejectReason,
  });

  factory ListenerSerialParseAttempt.accepted(ListenerSerialEnvelope envelope) {
    return ListenerSerialParseAttempt._(envelope: envelope);
  }

  factory ListenerSerialParseAttempt.rejected(String reason) {
    return ListenerSerialParseAttempt._(rejectReason: reason);
  }
}

class ListenerSerialIngestor {
  final String provider;
  final String transport;

  const ListenerSerialIngestor({
    this.provider = 'falcon_serial',
    this.transport = 'serial',
  });

  ListenerSerialBenchParseResult parseLines({
    required List<String> lines,
    required String clientId,
    required String regionId,
    required String siteId,
  }) {
    final accepted = <ListenerSerialEnvelope>[];
    final rejectedEntries = <ListenerSerialReject>[];
    for (var index = 0; index < lines.length; index += 1) {
      final line = lines[index];
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        continue;
      }
      final parsed = parseLineDetailed(
        line: line,
        clientId: clientId,
        regionId: regionId,
        siteId: siteId,
      );
      if (parsed.envelope == null) {
        rejectedEntries.add(
          ListenerSerialReject(
            line: line,
            lineNumber: index + 1,
            reason: parsed.rejectReason ?? 'unknown_reject_reason',
          ),
        );
      } else {
        accepted.add(parsed.envelope!);
      }
    }
    return ListenerSerialBenchParseResult(
      accepted: accepted,
      rejectedEntries: rejectedEntries,
    );
  }

  ListenerSerialEnvelope? parseLine({
    required String line,
    required String clientId,
    required String regionId,
    required String siteId,
  }) {
    return parseLineDetailed(
      line: line,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
    ).envelope;
  }

  ListenerSerialParseAttempt parseLineDetailed({
    required String line,
    required String clientId,
    required String regionId,
    required String siteId,
  }) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      return ListenerSerialParseAttempt.rejected('empty_line');
    }
    if (trimmed.startsWith('#')) {
      return ListenerSerialParseAttempt.rejected('comment_line');
    }

    final jsonCandidate = _tryParseJsonEnvelopeDetailed(
      trimmed,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
    );
    if (jsonCandidate.envelope != null || jsonCandidate.rejectReason != null) {
      return jsonCandidate;
    }

    final tokens = trimmed.split(RegExp(r'\s+'));
    if (tokens.length < 4) {
      return ListenerSerialParseAttempt.rejected('insufficient_tokens');
    }

    final qualifierCode = tokens[0].trim();
    if (qualifierCode.length < 4) {
      return ListenerSerialParseAttempt.rejected('invalid_qualifier_code');
    }
    final qualifier = qualifierCode.substring(0, 1);
    final eventCode = qualifierCode.substring(1);
    final partition = tokens.length > 1 ? tokens[1].trim() : '';
    final zone = tokens.length > 2 ? tokens[2].trim() : '';
    final account = tokens.length > 3 ? tokens[3].trim() : '';
    final userCode = tokens.length > 4 ? tokens[4].trim() : '';
    if (!_digitsOnly(eventCode) || !_digitsOnly(qualifier)) {
      return ListenerSerialParseAttempt.rejected('invalid_qualifier_code');
    }
    if (account.isEmpty) {
      return ListenerSerialParseAttempt.rejected('missing_account_number');
    }
    if (!_digitsOnly(account)) {
      return ListenerSerialParseAttempt.rejected('invalid_account_number');
    }
    if (partition.isNotEmpty && !_digitsOnly(partition)) {
      return ListenerSerialParseAttempt.rejected('invalid_partition');
    }
    if (zone.isNotEmpty && !_digitsOnly(zone)) {
      return ListenerSerialParseAttempt.rejected('invalid_zone');
    }

    final timestamp = _timestampFromTokensDetailed(tokens);
    final occurredAtUtc = timestamp.occurredAtUtc ?? DateTime.now().toUtc();
    final eventInfo = _eventInfoForCode(eventCode);
    final qualifierWarnings = _qualifierWarningsFor(qualifier);
    final normalizationWarnings = [
      ...eventInfo.normalizationWarnings,
      ...qualifierWarnings,
    ];
    final captureSignature = _captureSignature(
      parseMode: 'tokenized',
      tokenCount: tokens.length,
      timestampSource: timestamp.source,
      partition: partition,
      zone: zone,
      userCode: userCode,
      eventQualifier: qualifier,
    );
    final externalId = '$provider-$account-$partition-$eventCode-$zone-${occurredAtUtc.millisecondsSinceEpoch}';
    return ListenerSerialParseAttempt.accepted(
      ListenerSerialEnvelope(
        provider: provider,
        transport: transport,
        externalId: externalId,
        rawLine: line,
        accountNumber: account,
        partition: partition,
        eventCode: eventCode,
        eventQualifier: qualifier,
        zone: zone,
        userCode: userCode,
        siteId: siteId,
        clientId: clientId,
        regionId: regionId,
        occurredAtUtc: occurredAtUtc,
        metadata: {
          'parse_mode': 'tokenized',
          'token_count': tokens.length,
          'timestamp_source': timestamp.source,
          'capture_signature': captureSignature,
          'normalized_event_label': eventInfo.label,
          'risk_score': eventInfo.riskScore,
          'normalization_status': normalizationWarnings.isEmpty
              ? 'known_event_code'
              : 'warning',
          if (normalizationWarnings.isNotEmpty)
            'normalization_warning': normalizationWarnings.first,
          if (normalizationWarnings.isNotEmpty)
            'normalization_warnings': normalizationWarnings,
          if (timestamp.rawToken != null) 'timestamp_token': timestamp.rawToken,
        },
      ),
    );
  }

  NormalizedIntelRecord? normalizeEnvelope(ListenerSerialEnvelope envelope) {
    if (envelope.externalId.isEmpty ||
        envelope.clientId.isEmpty ||
        envelope.regionId.isEmpty ||
        envelope.siteId.isEmpty) {
      return null;
    }
    final eventInfo = _eventInfoFor(envelope);
    final zoneLabel = envelope.zone.trim();
    final partitionLabel = envelope.partition.trim().isEmpty
        ? 'partition n/a'
        : 'partition ${envelope.partition.trim()}';
    final accountLabel = envelope.accountNumber.trim().isEmpty
        ? 'acct n/a'
        : 'acct ${envelope.accountNumber.trim()}';
    final qualifierLabel = envelope.eventQualifier.trim().isEmpty
        ? ''
        : ' qualifier:${envelope.eventQualifier.trim()}';
    final userLabel = envelope.userCode.trim().isEmpty
        ? ''
        : ' user:${envelope.userCode.trim()}';
    return NormalizedIntelRecord(
      provider: envelope.provider,
      sourceType: 'hardware',
      externalId: envelope.externalId,
      clientId: envelope.clientId,
      regionId: envelope.regionId,
      siteId: envelope.siteId,
      zone: zoneLabel.isEmpty ? null : zoneLabel,
      objectLabel: eventInfo.label,
      headline: '${envelope.provider.toUpperCase()} ${eventInfo.label}',
      summary:
          '${eventInfo.label} • $accountLabel • $partitionLabel${zoneLabel.isEmpty ? '' : ' • zone:$zoneLabel'} • code:${envelope.eventCode}$qualifierLabel$userLabel',
      riskScore: eventInfo.riskScore,
      occurredAtUtc: envelope.occurredAtUtc,
    );
  }

  List<NormalizedIntelRecord> normalizeBatch(List<ListenerSerialEnvelope> items) {
    return items
        .map(normalizeEnvelope)
        .whereType<NormalizedIntelRecord>()
        .toList(growable: false);
  }

  ListenerSerialParseAttempt _tryParseJsonEnvelopeDetailed(
    String line, {
    required String clientId,
    required String regionId,
    required String siteId,
  }) {
    if (!line.startsWith('{')) {
      return const ListenerSerialParseAttempt._();
    }
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map) {
        return ListenerSerialParseAttempt.rejected('json_not_object');
      }
      final map = decoded.map(
        (key, value) => MapEntry(key.toString(), value as Object?),
      );
      final externalId = (map['external_id'] ?? map['id'] ?? '')
          .toString()
          .trim();
      final eventCode = (map['event_code'] ?? map['code'] ?? '').toString().trim();
      final accountNumber =
          (map['account_number'] ?? map['account'] ?? '').toString().trim();
      final occurredAtUtc =
          DateTime.tryParse((map['occurred_at_utc'] ?? map['timestamp'] ?? '')
                  .toString())
              ?.toUtc();
      if (occurredAtUtc == null) {
        return ListenerSerialParseAttempt.rejected('json_missing_timestamp');
      }
      if (eventCode.isEmpty) {
        return ListenerSerialParseAttempt.rejected('json_missing_event_code');
      }
      if (accountNumber.isEmpty) {
        return ListenerSerialParseAttempt.rejected('json_missing_account_number');
      }
      if (!_digitsOnly(eventCode) || !_digitsOnly(accountNumber)) {
        return ListenerSerialParseAttempt.rejected('json_invalid_numeric_fields');
      }
      final partition = (map['partition'] ?? '').toString().trim();
      final zone = (map['zone'] ?? '').toString().trim();
      final eventQualifier =
          (map['event_qualifier'] ?? map['qualifier'] ?? '').toString().trim();
      if (partition.isNotEmpty && !_digitsOnly(partition)) {
        return ListenerSerialParseAttempt.rejected('json_invalid_partition');
      }
      if (zone.isNotEmpty && !_digitsOnly(zone)) {
        return ListenerSerialParseAttempt.rejected('json_invalid_zone');
      }
      if (eventQualifier.isNotEmpty && !_digitsOnly(eventQualifier)) {
        return ListenerSerialParseAttempt.rejected('json_invalid_qualifier');
      }
      final timestampField = map['occurred_at_utc'] != null
          ? 'occurred_at_utc'
          : (map['timestamp'] != null ? 'timestamp' : '');
      final eventInfo = _eventInfoForCode(eventCode);
      final qualifierWarnings = _qualifierWarningsFor(eventQualifier);
      final normalizationWarnings = [
        ...eventInfo.normalizationWarnings,
        ...qualifierWarnings,
      ];
      final captureSignature = _captureSignature(
        parseMode: 'json_line',
        timestampSource: 'embedded_json',
        timestampField: timestampField,
        partition: partition,
        zone: zone,
        userCode: (map['user_code'] ?? map['user'] ?? '').toString().trim(),
        eventQualifier: eventQualifier,
      );
      return ListenerSerialParseAttempt.accepted(ListenerSerialEnvelope(
        provider: (map['provider'] ?? provider).toString().trim().ifEmpty(provider),
        transport: (map['transport'] ?? transport).toString().trim().ifEmpty(transport),
        externalId: externalId.isEmpty
            ? '$provider-${occurredAtUtc.millisecondsSinceEpoch}'
            : externalId,
        rawLine: line,
        accountNumber: accountNumber,
        partition: partition,
        eventCode: eventCode,
        eventQualifier: eventQualifier,
        zone: zone,
        userCode: (map['user_code'] ?? map['user'] ?? '').toString().trim(),
        siteId: (map['site_id'] ?? siteId).toString().trim().ifEmpty(siteId),
        clientId:
            (map['client_id'] ?? clientId).toString().trim().ifEmpty(clientId),
        regionId:
            (map['region_id'] ?? regionId).toString().trim().ifEmpty(regionId),
        occurredAtUtc: occurredAtUtc,
        metadata: {
          ..._objectMap(map['metadata']),
          'parse_mode': 'json_line',
          'timestamp_source': 'embedded_json',
          'capture_signature': captureSignature,
          'normalized_event_label': eventInfo.label,
          'risk_score': eventInfo.riskScore,
          'normalization_status': normalizationWarnings.isEmpty
              ? 'known_event_code'
              : 'warning',
          if (normalizationWarnings.isNotEmpty)
            'normalization_warning': normalizationWarnings.first,
          if (normalizationWarnings.isNotEmpty)
            'normalization_warnings': normalizationWarnings,
          if (timestampField.isNotEmpty) 'timestamp_field': timestampField,
        },
      ));
    } on FormatException {
      return ListenerSerialParseAttempt.rejected('invalid_json');
    } catch (_) {
      return ListenerSerialParseAttempt.rejected('invalid_json');
    }
  }

  _TimestampParseResult _timestampFromTokensDetailed(List<String> tokens) {
    for (final token in tokens.reversed) {
      final parsed = DateTime.tryParse(token);
      if (parsed != null) {
        return _TimestampParseResult(
          occurredAtUtc: parsed.toUtc(),
          source: 'embedded_token',
          rawToken: token,
        );
      }
    }
    return const _TimestampParseResult(
      occurredAtUtc: null,
      source: 'fallback_now',
    );
  }

  _ListenerEventInfo _eventInfoFor(ListenerSerialEnvelope envelope) {
    return _eventInfoForCode(envelope.eventCode.trim());
  }

  _ListenerEventInfo _eventInfoForCode(String eventCode) {
    switch (eventCode.trim()) {
      case '130':
        return const _ListenerEventInfo(
          label: 'BURGLARY_ALARM',
          riskScore: 96,
        );
      case '131':
        return const _ListenerEventInfo(
          label: 'PERIMETER_ALARM',
          riskScore: 91,
        );
      case '140':
        return const _ListenerEventInfo(
          label: 'GENERAL_ALARM',
          riskScore: 88,
        );
      case '301':
        return const _ListenerEventInfo(
          label: 'OPENING',
          riskScore: 35,
        );
      case '302':
        return const _ListenerEventInfo(
          label: 'CLOSING',
          riskScore: 35,
        );
      default:
        return const _ListenerEventInfo(
          label: 'LISTENER_EVENT',
          riskScore: 55,
          normalizationWarnings: ['unknown_event_code'],
        );
    }
  }

  List<String> _qualifierWarningsFor(String qualifier) {
    if (qualifier.trim().isEmpty) {
      return const [];
    }
    switch (qualifier.trim()) {
      case '1':
      case '3':
      case '6':
        return const [];
      default:
        return const ['nonstandard_event_qualifier'];
    }
  }
}

String _captureSignature({
  required String parseMode,
  int? tokenCount,
  required String timestampSource,
  String? timestampField,
  required String partition,
  required String zone,
  required String userCode,
  required String eventQualifier,
}) {
  final segments = <String>[
    parseMode,
    if (tokenCount != null) 'tokens=$tokenCount',
    'timestamp=$timestampSource',
    if (timestampField != null && timestampField.trim().isNotEmpty)
      'timestamp_field=${timestampField.trim()}',
    'partition=${partition.trim().isEmpty ? 'absent' : 'present'}',
    'zone=${zone.trim().isEmpty ? 'absent' : 'present'}',
    'user=${userCode.trim().isEmpty ? 'absent' : 'present'}',
    'qualifier=${eventQualifier.trim().isEmpty ? 'absent' : 'present'}',
  ];
  return segments.join('|');
}

class _ListenerEventInfo {
  final String label;
  final int riskScore;
  final List<String> normalizationWarnings;

  const _ListenerEventInfo({
    required this.label,
    required this.riskScore,
    this.normalizationWarnings = const [],
  });
}

class _TimestampParseResult {
  final DateTime? occurredAtUtc;
  final String source;
  final String? rawToken;

  const _TimestampParseResult({
    required this.occurredAtUtc,
    required this.source,
    this.rawToken,
  });
}

bool _digitsOnly(String value) {
  return RegExp(r'^\d+$').hasMatch(value.trim());
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is Map) {
    return value.map(
      (key, value) => MapEntry(key.toString(), value as Object?),
    );
  }
  return const {};
}

extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}
