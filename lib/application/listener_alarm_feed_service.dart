import 'dart:convert';

import 'package:http/http.dart' as http;

import 'listener_serial_ingestor.dart';

class ListenerAlarmFeedBatch {
  final List<ListenerSerialEnvelope> envelopes;
  final List<ListenerSerialReject> rejectedEntries;
  final String sourceLabel;

  const ListenerAlarmFeedBatch({
    required this.envelopes,
    required this.rejectedEntries,
    required this.sourceLabel,
  });

  int get acceptedCount => envelopes.length;

  int get rejectedCount => rejectedEntries.length;

  Map<String, int> get rejectReasonCounts {
    final counts = <String, int>{};
    for (final entry in rejectedEntries) {
      counts.update(entry.reason, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }
}

class ListenerAlarmFeedService {
  final Uri? feedUri;
  final Map<String, String> headers;
  final http.Client client;
  final ListenerSerialIngestor serialIngestor;

  const ListenerAlarmFeedService({
    required this.feedUri,
    required this.headers,
    required this.client,
    this.serialIngestor = const ListenerSerialIngestor(),
  });

  Future<ListenerAlarmFeedBatch> fetchLatest({
    required String clientId,
    required String regionId,
    required String siteId,
  }) async {
    final uri = feedUri;
    if (uri == null) {
      throw const FormatException('Listener alarm feed is not configured.');
    }
    final response = await client.get(
      uri,
      headers: {'Accept': 'application/json', ...headers},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FormatException(
        'Listener alarm feed returned HTTP ${response.statusCode}.',
      );
    }
    return parseJson(
      response.body,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      sourceLabel: uri.host.trim().isEmpty ? uri.toString() : uri.host,
    );
  }

  ListenerAlarmFeedBatch parseJson(
    String rawPayload, {
    required String clientId,
    required String regionId,
    required String siteId,
    String sourceLabel = 'listener alarm feed',
  }) {
    final decoded = jsonDecode(rawPayload);
    final entries = _extractEntries(decoded);
    final accepted = <ListenerSerialEnvelope>[];
    final rejected = <ListenerSerialReject>[];

    for (var index = 0; index < entries.length; index += 1) {
      final entry = entries[index];
      final lineNumber = index + 1;
      final parseAttempt = _parseEntry(
        entry,
        clientId: clientId,
        regionId: regionId,
        siteId: siteId,
      );
      if (parseAttempt.envelope != null) {
        accepted.add(parseAttempt.envelope!);
      } else {
        rejected.add(
          ListenerSerialReject(
            line: _entryLabel(entry),
            lineNumber: lineNumber,
            reason: parseAttempt.rejectReason ?? 'unsupported_entry',
          ),
        );
      }
    }

    return ListenerAlarmFeedBatch(
      envelopes: accepted,
      rejectedEntries: rejected,
      sourceLabel: sourceLabel,
    );
  }

  ListenerSerialParseAttempt _parseEntry(
    Object? entry, {
    required String clientId,
    required String regionId,
    required String siteId,
  }) {
    if (entry is String) {
      return serialIngestor.parseLineDetailed(
        line: entry,
        clientId: clientId,
        regionId: regionId,
        siteId: siteId,
      );
    }

    final map = _asObjectMap(entry);
    if (map == null) {
      return ListenerSerialParseAttempt.rejected('unsupported_entry');
    }
    final rawLine = map['line']?.toString().trim() ?? '';
    if (rawLine.isNotEmpty) {
      return serialIngestor.parseLineDetailed(
        line: rawLine,
        clientId: _scopedValue(map['client_id'], fallback: clientId),
        regionId: _scopedValue(map['region_id'], fallback: regionId),
        siteId: _scopedValue(map['site_id'], fallback: siteId),
      );
    }

    return serialIngestor.parseLineDetailed(
      line: jsonEncode(map),
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
    );
  }

  List<Object?> _extractEntries(Object? decoded) {
    if (decoded is List) {
      return List<Object?>.from(decoded);
    }
    final map = _asObjectMap(decoded);
    if (map == null) {
      throw const FormatException(
        'Listener alarm feed must decode to a JSON object or array.',
      );
    }

    for (final key in const [
      'events',
      'payloads',
      'lines',
      'envelopes',
      'records',
    ]) {
      final nested = map[key];
      if (nested is List) {
        return List<Object?>.from(nested);
      }
    }

    return <Object?>[map];
  }

  Map<String, Object?>? _asObjectMap(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, entry) => MapEntry(key.toString(), entry as Object?),
      );
    }
    return null;
  }

  String _entryLabel(Object? entry) {
    if (entry is String) {
      return entry;
    }
    final map = _asObjectMap(entry);
    if (map == null) {
      return entry?.toString() ?? '';
    }
    final line = map['line']?.toString().trim() ?? '';
    if (line.isNotEmpty) {
      return line;
    }
    return jsonEncode(map);
  }

  String _scopedValue(Object? raw, {required String fallback}) {
    final trimmed = raw?.toString().trim() ?? '';
    return trimmed.isEmpty ? fallback : trimmed;
  }
}
