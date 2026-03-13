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
  final List<String> rejected;

  const ListenerSerialBenchParseResult({
    required this.accepted,
    required this.rejected,
  });
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
    final rejected = <String>[];
    for (final line in lines) {
      if (line.trim().isEmpty) {
        continue;
      }
      final parsed = parseLine(
        line: line,
        clientId: clientId,
        regionId: regionId,
        siteId: siteId,
      );
      if (parsed == null) {
        rejected.add(line);
      } else {
        accepted.add(parsed);
      }
    }
    return ListenerSerialBenchParseResult(
      accepted: accepted,
      rejected: rejected,
    );
  }

  ListenerSerialEnvelope? parseLine({
    required String line,
    required String clientId,
    required String regionId,
    required String siteId,
  }) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final jsonCandidate = _tryParseJsonEnvelope(
      trimmed,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
    );
    if (jsonCandidate != null) {
      return jsonCandidate;
    }

    final tokens = trimmed.split(RegExp(r'\s+'));
    if (tokens.length < 4) {
      return null;
    }

    final qualifierCode = tokens[0].trim();
    if (qualifierCode.length < 4) {
      return null;
    }
    final qualifier = qualifierCode.substring(0, 1);
    final eventCode = qualifierCode.substring(1);
    final partition = tokens.length > 1 ? tokens[1].trim() : '';
    final zone = tokens.length > 2 ? tokens[2].trim() : '';
    final account = tokens.length > 3 ? tokens[3].trim() : '';
    final userCode = tokens.length > 4 ? tokens[4].trim() : '';
    if (eventCode.isEmpty || account.isEmpty) {
      return null;
    }

    final occurredAtUtc = _timestampFromTokens(tokens) ?? DateTime.now().toUtc();
    final externalId = '$provider-$account-$partition-$eventCode-$zone-${occurredAtUtc.millisecondsSinceEpoch}';
    return ListenerSerialEnvelope(
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
      },
    );
  }

  NormalizedIntelRecord? normalizeEnvelope(ListenerSerialEnvelope envelope) {
    if (envelope.externalId.isEmpty ||
        envelope.clientId.isEmpty ||
        envelope.regionId.isEmpty ||
        envelope.siteId.isEmpty) {
      return null;
    }
    final label = _eventLabelFor(envelope);
    final riskScore = _riskScoreFor(envelope);
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
      objectLabel: label,
      headline: '${envelope.provider.toUpperCase()} $label',
      summary:
          '$label • $accountLabel • $partitionLabel${zoneLabel.isEmpty ? '' : ' • zone:$zoneLabel'} • code:${envelope.eventCode}$qualifierLabel$userLabel',
      riskScore: riskScore,
      occurredAtUtc: envelope.occurredAtUtc,
    );
  }

  List<NormalizedIntelRecord> normalizeBatch(List<ListenerSerialEnvelope> items) {
    return items
        .map(normalizeEnvelope)
        .whereType<NormalizedIntelRecord>()
        .toList(growable: false);
  }

  ListenerSerialEnvelope? _tryParseJsonEnvelope(
    String line, {
    required String clientId,
    required String regionId,
    required String siteId,
  }) {
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map) {
        return null;
      }
      final map = decoded.map(
        (key, value) => MapEntry(key.toString(), value as Object?),
      );
      final externalId = (map['external_id'] ?? map['id'] ?? '')
          .toString()
          .trim();
      final occurredAtUtc =
          DateTime.tryParse((map['occurred_at_utc'] ?? map['timestamp'] ?? '')
                  .toString())
              ?.toUtc();
      if (occurredAtUtc == null) {
        return null;
      }
      return ListenerSerialEnvelope(
        provider: (map['provider'] ?? provider).toString().trim().ifEmpty(provider),
        transport: (map['transport'] ?? transport).toString().trim().ifEmpty(transport),
        externalId: externalId.isEmpty
            ? '$provider-${occurredAtUtc.millisecondsSinceEpoch}'
            : externalId,
        rawLine: line,
        accountNumber: (map['account_number'] ?? map['account'] ?? '').toString().trim(),
        partition: (map['partition'] ?? '').toString().trim(),
        eventCode: (map['event_code'] ?? map['code'] ?? '').toString().trim(),
        eventQualifier:
            (map['event_qualifier'] ?? map['qualifier'] ?? '').toString().trim(),
        zone: (map['zone'] ?? '').toString().trim(),
        userCode: (map['user_code'] ?? map['user'] ?? '').toString().trim(),
        siteId: (map['site_id'] ?? siteId).toString().trim().ifEmpty(siteId),
        clientId:
            (map['client_id'] ?? clientId).toString().trim().ifEmpty(clientId),
        regionId:
            (map['region_id'] ?? regionId).toString().trim().ifEmpty(regionId),
        occurredAtUtc: occurredAtUtc,
        metadata: _objectMap(map['metadata']),
      );
    } catch (_) {
      return null;
    }
  }

  DateTime? _timestampFromTokens(List<String> tokens) {
    for (final token in tokens.reversed) {
      final parsed = DateTime.tryParse(token);
      if (parsed != null) {
        return parsed.toUtc();
      }
    }
    return null;
  }

  String _eventLabelFor(ListenerSerialEnvelope envelope) {
    switch (envelope.eventCode.trim()) {
      case '130':
        return 'BURGLARY_ALARM';
      case '131':
        return 'PERIMETER_ALARM';
      case '140':
        return 'GENERAL_ALARM';
      case '301':
        return 'OPENING';
      case '302':
        return 'CLOSING';
      default:
        return 'LISTENER_EVENT';
    }
  }

  int _riskScoreFor(ListenerSerialEnvelope envelope) {
    switch (envelope.eventCode.trim()) {
      case '130':
        return 96;
      case '131':
        return 91;
      case '140':
        return 88;
      case '301':
      case '302':
        return 35;
      default:
        return 55;
    }
  }
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
