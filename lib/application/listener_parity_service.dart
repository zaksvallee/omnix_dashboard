import 'listener_serial_ingestor.dart';

class ListenerParityDrift {
  final ListenerSerialEnvelope event;
  final String reason;
  final String counterpartExternalId;
  final int observedSkewSeconds;

  const ListenerParityDrift({
    required this.event,
    required this.reason,
    this.counterpartExternalId = '',
    this.observedSkewSeconds = 0,
  });

  Map<String, Object?> toJson() {
    return {
      'reason': reason,
      'counterpart_external_id': counterpartExternalId,
      'observed_skew_seconds': observedSkewSeconds,
      'event': event.toJson(),
    };
  }
}

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
  final List<ListenerParityDrift> unmatchedSerialDrifts;
  final List<ListenerParityDrift> unmatchedLegacyDrifts;
  final int maxAllowedSkewSeconds;

  const ListenerParityReport({
    required this.serialCount,
    required this.legacyCount,
    required this.matchedCount,
    required this.matches,
    required this.unmatchedSerial,
    required this.unmatchedLegacy,
    required this.unmatchedSerialDrifts,
    required this.unmatchedLegacyDrifts,
    required this.maxAllowedSkewSeconds,
  });

  int get unmatchedSerialCount => unmatchedSerial.length;
  int get unmatchedLegacyCount => unmatchedLegacy.length;
  double get matchRatePercent {
    if (legacyCount <= 0) {
      return serialCount <= 0 ? 100 : 0;
    }
    return (matchedCount / legacyCount) * 100;
  }

  int get maxSkewSecondsObserved {
    if (matches.isEmpty) {
      return 0;
    }
    return matches
        .map((entry) => entry.skewSeconds)
        .reduce((left, right) => left > right ? left : right);
  }

  double get averageSkewSeconds {
    if (matches.isEmpty) {
      return 0;
    }
    final total = matches.fold<int>(
      0,
      (sum, entry) => sum + entry.skewSeconds,
    );
    return total / matches.length;
  }

  Map<String, int> get driftReasonCounts {
    final counts = <String, int>{};
    for (final drift in [...unmatchedSerialDrifts, ...unmatchedLegacyDrifts]) {
      counts.update(drift.reason, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  String summaryLabel() {
    final matchRate = matchRatePercent.toStringAsFixed(1);
    final averageSkew = averageSkewSeconds.toStringAsFixed(1);
    final driftSummary = driftReasonCounts.entries
        .map((entry) => '${entry.key} ${entry.value}')
        .join(', ');
    final driftSegment =
        driftSummary.isEmpty ? '' : ' • drift[$driftSummary]';
    return 'serial $serialCount • legacy $legacyCount • matched $matchedCount • serial_only $unmatchedSerialCount • legacy_only $unmatchedLegacyCount • match_rate $matchRate% • max_skew ${maxSkewSecondsObserved}s • avg_skew ${averageSkew}s • skew<=${maxAllowedSkewSeconds}s$driftSegment';
  }

  Map<String, Object?> toJson() {
    return {
      'serial_count': serialCount,
      'legacy_count': legacyCount,
      'matched_count': matchedCount,
      'unmatched_serial_count': unmatchedSerialCount,
      'unmatched_legacy_count': unmatchedLegacyCount,
      'max_allowed_skew_seconds': maxAllowedSkewSeconds,
      'match_rate_percent': double.parse(matchRatePercent.toStringAsFixed(2)),
      'max_skew_seconds_observed': maxSkewSecondsObserved,
      'average_skew_seconds':
          double.parse(averageSkewSeconds.toStringAsFixed(2)),
      'drift_reason_counts': driftReasonCounts,
      'summary': summaryLabel(),
      'matches': matches.map((entry) => entry.toJson()).toList(growable: false),
      'unmatched_serial':
          unmatchedSerial.map((entry) => entry.toJson()).toList(growable: false),
      'unmatched_legacy':
          unmatchedLegacy.map((entry) => entry.toJson()).toList(growable: false),
      'unmatched_serial_drifts':
          unmatchedSerialDrifts.map((entry) => entry.toJson()).toList(
                growable: false,
              ),
      'unmatched_legacy_drifts':
          unmatchedLegacyDrifts.map((entry) => entry.toJson()).toList(
                growable: false,
              ),
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
    final unmatchedSerialDrifts = <ListenerParityDrift>[];

    for (final serial in sortedSerial) {
      final legacyIndex = _bestLegacyIndex(serial, availableLegacy);
      if (legacyIndex == null) {
        unmatchedSerial.add(serial);
        unmatchedSerialDrifts.add(_classifyDrift(serial, availableLegacy));
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
      unmatchedSerialDrifts: unmatchedSerialDrifts,
      unmatchedLegacyDrifts: availableLegacy
          .map((legacy) => _classifyDrift(legacy, unmatchedSerial))
          .toList(growable: false),
      maxAllowedSkewSeconds: maxSkew.inSeconds,
    );
  }

  ListenerParityDrift _classifyDrift(
    ListenerSerialEnvelope event,
    List<ListenerSerialEnvelope> candidates,
  ) {
    if (candidates.isEmpty) {
      return ListenerParityDrift(
        event: event,
        reason: 'no_counterpart_available',
      );
    }

    ListenerSerialEnvelope? bestSite;
    ListenerSerialEnvelope? bestAccount;
    ListenerSerialEnvelope? bestEventCode;
    ListenerSerialEnvelope? bestPartition;
    ListenerSerialEnvelope? bestZone;
    ListenerSerialEnvelope? bestLogical;
    var bestLogicalSkew = 1 << 30;

    for (final candidate in candidates) {
      if (candidate.siteId == event.siteId) {
        bestSite ??= candidate;
      }
      if (candidate.siteId == event.siteId &&
          candidate.accountNumber == event.accountNumber) {
        bestAccount ??= candidate;
      }
      if (candidate.siteId == event.siteId &&
          candidate.accountNumber == event.accountNumber &&
          candidate.eventCode == event.eventCode) {
        bestEventCode ??= candidate;
      }
      if (candidate.siteId == event.siteId &&
          candidate.accountNumber == event.accountNumber &&
          candidate.eventCode == event.eventCode &&
          (event.partition.isEmpty ||
              candidate.partition.isEmpty ||
              candidate.partition == event.partition)) {
        bestPartition ??= candidate;
      }
      if (candidate.siteId == event.siteId &&
          candidate.accountNumber == event.accountNumber &&
          candidate.eventCode == event.eventCode &&
          (event.partition.isEmpty ||
              candidate.partition.isEmpty ||
              candidate.partition == event.partition) &&
          (event.zone.isEmpty || candidate.zone.isEmpty || candidate.zone == event.zone)) {
        bestZone ??= candidate;
      }
      if (_sameLogicalEvent(event, candidate)) {
        final skew = event.occurredAtUtc
            .difference(candidate.occurredAtUtc)
            .inSeconds
            .abs();
        if (skew < bestLogicalSkew) {
          bestLogicalSkew = skew;
          bestLogical = candidate;
        }
      }
    }

    if (bestSite == null) {
      return ListenerParityDrift(
        event: event,
        reason: 'site_id_mismatch',
        counterpartExternalId: candidates.first.externalId,
      );
    }
    if (bestAccount == null) {
      return ListenerParityDrift(
        event: event,
        reason: 'account_number_mismatch',
        counterpartExternalId: bestSite.externalId,
      );
    }
    if (bestEventCode == null) {
      return ListenerParityDrift(
        event: event,
        reason: 'event_code_mismatch',
        counterpartExternalId: bestAccount.externalId,
      );
    }
    if (bestPartition == null) {
      return ListenerParityDrift(
        event: event,
        reason: 'partition_mismatch',
        counterpartExternalId: bestEventCode.externalId,
      );
    }
    if (bestZone == null) {
      return ListenerParityDrift(
        event: event,
        reason: 'zone_mismatch',
        counterpartExternalId: bestPartition.externalId,
      );
    }
    if (bestLogical != null && bestLogicalSkew > maxSkew.inSeconds) {
      return ListenerParityDrift(
        event: event,
        reason: 'skew_exceeded',
        counterpartExternalId: bestLogical.externalId,
        observedSkewSeconds: bestLogicalSkew,
      );
    }
    return ListenerParityDrift(
      event: event,
      reason: 'unclassified_mismatch',
      counterpartExternalId: bestZone.externalId,
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
