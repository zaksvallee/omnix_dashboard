import 'listener_serial_ingestor.dart';

class ListenerParityMatch {
  final ListenerSerialEnvelope serialEvent;
  final ListenerSerialEnvelope legacyEvent;
  final int skewSeconds;

  const ListenerParityMatch({
    required this.serialEvent,
    required this.legacyEvent,
    required this.skewSeconds,
  });

  Map<String, Object?> toJson() {
    return {
      'serial_external_id': serialEvent.externalId,
      'legacy_external_id': legacyEvent.externalId,
      'site_id': serialEvent.siteId,
      'account_number': serialEvent.accountNumber,
      'event_code': serialEvent.eventCode,
      'zone': serialEvent.zone,
      'skew_seconds': skewSeconds,
    };
  }
}

class ListenerParityReport {
  final int serialCount;
  final int legacyCount;
  final int matchedCount;
  final List<ListenerParityMatch> matches;
  final List<ListenerSerialEnvelope> unmatchedSerial;
  final List<ListenerSerialEnvelope> unmatchedLegacy;
  final int maxAllowedSkewSeconds;

  const ListenerParityReport({
    required this.serialCount,
    required this.legacyCount,
    required this.matchedCount,
    required this.matches,
    required this.unmatchedSerial,
    required this.unmatchedLegacy,
    required this.maxAllowedSkewSeconds,
  });

  int get unmatchedSerialCount => unmatchedSerial.length;
  int get unmatchedLegacyCount => unmatchedLegacy.length;

  String summaryLabel() {
    return 'serial $serialCount • legacy $legacyCount • matched $matchedCount • serial_only $unmatchedSerialCount • legacy_only $unmatchedLegacyCount • skew<=${maxAllowedSkewSeconds}s';
  }

  Map<String, Object?> toJson() {
    return {
      'serial_count': serialCount,
      'legacy_count': legacyCount,
      'matched_count': matchedCount,
      'unmatched_serial_count': unmatchedSerialCount,
      'unmatched_legacy_count': unmatchedLegacyCount,
      'max_allowed_skew_seconds': maxAllowedSkewSeconds,
      'summary': summaryLabel(),
      'matches': matches.map((entry) => entry.toJson()).toList(growable: false),
      'unmatched_serial':
          unmatchedSerial.map((entry) => entry.toJson()).toList(growable: false),
      'unmatched_legacy':
          unmatchedLegacy.map((entry) => entry.toJson()).toList(growable: false),
    };
  }
}

class ListenerParityService {
  final Duration maxSkew;

  const ListenerParityService({
    this.maxSkew = const Duration(seconds: 90),
  });

  ListenerParityReport compare({
    required List<ListenerSerialEnvelope> serialEvents,
    required List<ListenerSerialEnvelope> legacyEvents,
  }) {
    final sortedSerial = [...serialEvents]..sort(_compareEnvelope);
    final sortedLegacy = [...legacyEvents]..sort(_compareEnvelope);
    final availableLegacy = <ListenerSerialEnvelope>[...sortedLegacy];
    final matches = <ListenerParityMatch>[];
    final unmatchedSerial = <ListenerSerialEnvelope>[];

    for (final serial in sortedSerial) {
      final legacyIndex = _bestLegacyIndex(serial, availableLegacy);
      if (legacyIndex == null) {
        unmatchedSerial.add(serial);
        continue;
      }
      final legacy = availableLegacy.removeAt(legacyIndex);
      matches.add(
        ListenerParityMatch(
          serialEvent: serial,
          legacyEvent: legacy,
          skewSeconds:
              serial.occurredAtUtc.difference(legacy.occurredAtUtc).inSeconds.abs(),
        ),
      );
    }

    return ListenerParityReport(
      serialCount: sortedSerial.length,
      legacyCount: sortedLegacy.length,
      matchedCount: matches.length,
      matches: matches,
      unmatchedSerial: unmatchedSerial,
      unmatchedLegacy: availableLegacy,
      maxAllowedSkewSeconds: maxSkew.inSeconds,
    );
  }

  int? _bestLegacyIndex(
    ListenerSerialEnvelope serial,
    List<ListenerSerialEnvelope> legacyEvents,
  ) {
    var bestIndex = -1;
    var bestSkew = maxSkew.inSeconds + 1;
    for (var index = 0; index < legacyEvents.length; index += 1) {
      final candidate = legacyEvents[index];
      if (!_sameLogicalEvent(serial, candidate)) {
        continue;
      }
      final skew = serial.occurredAtUtc
          .difference(candidate.occurredAtUtc)
          .inSeconds
          .abs();
      if (skew > maxSkew.inSeconds) {
        continue;
      }
      if (skew < bestSkew) {
        bestSkew = skew;
        bestIndex = index;
      }
    }
    return bestIndex >= 0 ? bestIndex : null;
  }

  bool _sameLogicalEvent(
    ListenerSerialEnvelope left,
    ListenerSerialEnvelope right,
  ) {
    if (left.siteId != right.siteId) {
      return false;
    }
    if (left.accountNumber != right.accountNumber) {
      return false;
    }
    if (left.eventCode != right.eventCode) {
      return false;
    }
    if (left.partition.isNotEmpty &&
        right.partition.isNotEmpty &&
        left.partition != right.partition) {
      return false;
    }
    if (left.zone.isNotEmpty && right.zone.isNotEmpty && left.zone != right.zone) {
      return false;
    }
    return true;
  }

  int _compareEnvelope(
    ListenerSerialEnvelope left,
    ListenerSerialEnvelope right,
  ) {
    final ts = left.occurredAtUtc.compareTo(right.occurredAtUtc);
    if (ts != 0) {
      return ts;
    }
    final site = left.siteId.compareTo(right.siteId);
    if (site != 0) {
      return site;
    }
    final account = left.accountNumber.compareTo(right.accountNumber);
    if (account != 0) {
      return account;
    }
    return left.externalId.compareTo(right.externalId);
  }
}
