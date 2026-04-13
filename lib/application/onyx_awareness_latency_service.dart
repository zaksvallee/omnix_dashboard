import 'dart:convert';

import 'package:supabase/supabase.dart';

class OnyxLatencyRecord {
  final String alertId;
  final String eventId;
  final String siteId;
  final String clientId;
  final DateTime dvrEventAt;
  final DateTime? snapshotAt;
  final DateTime? yoloAt;
  final DateTime? telegramAt;
  final int? totalMs;

  const OnyxLatencyRecord({
    required this.alertId,
    required this.eventId,
    required this.siteId,
    required this.clientId,
    required this.dvrEventAt,
    this.snapshotAt,
    this.yoloAt,
    this.telegramAt,
    this.totalMs,
  });

  OnyxLatencyRecord copyWith({
    String? alertId,
    String? eventId,
    String? siteId,
    String? clientId,
    DateTime? dvrEventAt,
    DateTime? snapshotAt,
    DateTime? yoloAt,
    DateTime? telegramAt,
    int? totalMs,
  }) {
    return OnyxLatencyRecord(
      alertId: alertId ?? this.alertId,
      eventId: eventId ?? this.eventId,
      siteId: siteId ?? this.siteId,
      clientId: clientId ?? this.clientId,
      dvrEventAt: dvrEventAt ?? this.dvrEventAt,
      snapshotAt: snapshotAt ?? this.snapshotAt,
      yoloAt: yoloAt ?? this.yoloAt,
      telegramAt: telegramAt ?? this.telegramAt,
      totalMs: totalMs ?? this.totalMs,
    );
  }

  Map<String, Object?> toJsonMap() {
    return <String, Object?>{
      'alert_id': alertId,
      'event_id': eventId,
      'site_id': siteId,
      'client_id': clientId,
      'dvr_event_at': dvrEventAt.toUtc().toIso8601String(),
      'snapshot_at': snapshotAt?.toUtc().toIso8601String(),
      'yolo_at': yoloAt?.toUtc().toIso8601String(),
      'telegram_at': telegramAt?.toUtc().toIso8601String(),
      'total_ms': totalMs,
    };
  }

  factory OnyxLatencyRecord.fromJsonMap(Map<String, Object?> json) {
    return OnyxLatencyRecord(
      alertId: (json['alert_id'] ?? '').toString().trim(),
      eventId: (json['event_id'] ?? '').toString().trim(),
      siteId: (json['site_id'] ?? '').toString().trim(),
      clientId: (json['client_id'] ?? '').toString().trim(),
      dvrEventAt:
          DateTime.tryParse((json['dvr_event_at'] ?? '').toString())?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      snapshotAt: DateTime.tryParse(
        (json['snapshot_at'] ?? '').toString(),
      )?.toUtc(),
      yoloAt: DateTime.tryParse((json['yolo_at'] ?? '').toString())?.toUtc(),
      telegramAt: DateTime.tryParse(
        (json['telegram_at'] ?? '').toString(),
      )?.toUtc(),
      totalMs: _asInt(json['total_ms']),
    );
  }
}

class OnyxAwarenessLatencyStats {
  final String siteId;
  final Duration period;
  final double avgMs;
  final double p95Ms;
  final int minMs;
  final int maxMs;
  final int alertCount;

  const OnyxAwarenessLatencyStats({
    required this.siteId,
    required this.period,
    required this.avgMs,
    required this.p95Ms,
    required this.minMs,
    required this.maxMs,
    required this.alertCount,
  });
}

class OnyxAwarenessLatencyService {
  final SupabaseClient _client;
  final DateTime Function() _clock;

  const OnyxAwarenessLatencyService({
    required SupabaseClient client,
    DateTime Function()? clock,
  }) : _client = client,
       _clock = clock ?? DateTime.now;

  Future<void> recordLatency(OnyxLatencyRecord record) async {
    final normalized = record.copyWith(
      totalMs: record.totalMs ?? _computedTotalMs(record),
    );
    await _client
        .from('onyx_awareness_latency')
        .upsert(normalized.toJsonMap(), onConflict: 'alert_id');
  }

  Future<OnyxAwarenessLatencyStats> getSiteStats(String siteId) async {
    final normalizedSiteId = siteId.trim();
    final period = const Duration(hours: 24);
    if (normalizedSiteId.isEmpty) {
      return OnyxAwarenessLatencyStats(
        siteId: normalizedSiteId,
        period: period,
        avgMs: 0,
        p95Ms: 0,
        minMs: 0,
        maxMs: 0,
        alertCount: 0,
      );
    }
    final sinceUtc = _clock().toUtc().subtract(period).toIso8601String();
    final dynamic rows = await _client
        .from('onyx_awareness_latency')
        .select('total_ms')
        .eq('site_id', normalizedSiteId)
        .gte('telegram_at', sinceUtc)
        .order('telegram_at', ascending: false)
        .limit(1000);
    final totals = <int>[];
    if (rows is List) {
      for (final row in rows) {
        if (row is! Map) {
          continue;
        }
        final totalMs = _asInt(row['total_ms']);
        if (totalMs == null || totalMs < 0) {
          continue;
        }
        totals.add(totalMs);
      }
    }
    if (totals.isEmpty) {
      return OnyxAwarenessLatencyStats(
        siteId: normalizedSiteId,
        period: period,
        avgMs: 0,
        p95Ms: 0,
        minMs: 0,
        maxMs: 0,
        alertCount: 0,
      );
    }
    totals.sort();
    final sum = totals.fold<int>(0, (current, value) => current + value);
    final p95Index = ((totals.length - 1) * 0.95).round();
    return OnyxAwarenessLatencyStats(
      siteId: normalizedSiteId,
      period: period,
      avgMs: sum / totals.length,
      p95Ms: totals[p95Index].toDouble(),
      minMs: totals.first,
      maxMs: totals.last,
      alertCount: totals.length,
    );
  }

  int? _computedTotalMs(OnyxLatencyRecord record) {
    final telegramAt = record.telegramAt;
    if (telegramAt == null) {
      return null;
    }
    return telegramAt
        .toUtc()
        .difference(record.dvrEventAt.toUtc())
        .inMilliseconds;
  }
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

String canonicalLatencyJson(Map<String, Object?> json) {
  return jsonEncode(json);
}
