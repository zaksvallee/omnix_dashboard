import 'dart:math';

import '../domain/evidence/client_ledger_service.dart';
import 'dispatch_persistence_service.dart';

enum OfflineIncidentSpoolEntryStatus { queued, syncing, synced, failed }

class OfflineIncidentSpoolEntry {
  final String entryId;
  final String incidentReference;
  final String sourceType;
  final String provider;
  final String clientId;
  final String siteId;
  final DateTime createdAtUtc;
  final DateTime occurredAtUtc;
  final String summary;
  final Map<String, Object?> payload;
  final OfflineIncidentSpoolEntryStatus status;
  final int retryCount;
  final String? failureReason;
  final DateTime? syncedAtUtc;

  const OfflineIncidentSpoolEntry({
    required this.entryId,
    required this.incidentReference,
    required this.sourceType,
    required this.provider,
    required this.clientId,
    required this.siteId,
    required this.createdAtUtc,
    required this.occurredAtUtc,
    required this.summary,
    required this.payload,
    this.status = OfflineIncidentSpoolEntryStatus.queued,
    this.retryCount = 0,
    this.failureReason,
    this.syncedAtUtc,
  });

  bool get isPending =>
      status == OfflineIncidentSpoolEntryStatus.queued ||
      status == OfflineIncidentSpoolEntryStatus.failed;

  OfflineIncidentSpoolEntry copyWith({
    String? entryId,
    String? incidentReference,
    String? sourceType,
    String? provider,
    String? clientId,
    String? siteId,
    DateTime? createdAtUtc,
    DateTime? occurredAtUtc,
    String? summary,
    Map<String, Object?>? payload,
    OfflineIncidentSpoolEntryStatus? status,
    int? retryCount,
    Object? failureReason = _copySentinel,
    Object? syncedAtUtc = _copySentinel,
  }) {
    return OfflineIncidentSpoolEntry(
      entryId: entryId ?? this.entryId,
      incidentReference: incidentReference ?? this.incidentReference,
      sourceType: sourceType ?? this.sourceType,
      provider: provider ?? this.provider,
      clientId: clientId ?? this.clientId,
      siteId: siteId ?? this.siteId,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      occurredAtUtc: occurredAtUtc ?? this.occurredAtUtc,
      summary: summary ?? this.summary,
      payload: payload ?? this.payload,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      failureReason: identical(failureReason, _copySentinel)
          ? this.failureReason
          : failureReason as String?,
      syncedAtUtc: identical(syncedAtUtc, _copySentinel)
          ? this.syncedAtUtc
          : syncedAtUtc as DateTime?,
    );
  }

  Map<String, Object?> toJson() => {
    'entry_id': entryId,
    'incident_reference': incidentReference,
    'source_type': sourceType,
    'provider': provider,
    'client_id': clientId,
    'site_id': siteId,
    'created_at_utc': createdAtUtc.toIso8601String(),
    'occurred_at_utc': occurredAtUtc.toIso8601String(),
    'summary': summary,
    'payload': payload,
    'status': status.name,
    'retry_count': retryCount,
    'failure_reason': failureReason,
    'synced_at_utc': syncedAtUtc?.toIso8601String(),
  };

  factory OfflineIncidentSpoolEntry.fromJson(Map<String, Object?> json) {
    return OfflineIncidentSpoolEntry(
      entryId: json['entry_id']?.toString() ?? '',
      incidentReference: json['incident_reference']?.toString() ?? '',
      sourceType: json['source_type']?.toString() ?? '',
      provider: json['provider']?.toString() ?? '',
      clientId: json['client_id']?.toString() ?? '',
      siteId: json['site_id']?.toString() ?? '',
      createdAtUtc:
          DateTime.tryParse(json['created_at_utc']?.toString() ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      occurredAtUtc:
          DateTime.tryParse(json['occurred_at_utc']?.toString() ?? '')
              ?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      summary: json['summary']?.toString() ?? '',
      payload:
          (json['payload'] as Map?)
              ?.map((key, value) => MapEntry(key.toString(), value as Object?)) ??
          const <String, Object?>{},
      status: OfflineIncidentSpoolEntryStatus.values.firstWhere(
        (value) => value.name == json['status']?.toString(),
        orElse: () => OfflineIncidentSpoolEntryStatus.queued,
      ),
      retryCount: (json['retry_count'] as num?)?.toInt() ?? 0,
      failureReason: json['failure_reason']?.toString(),
      syncedAtUtc: DateTime.tryParse(json['synced_at_utc']?.toString() ?? '')
          ?.toUtc(),
    );
  }
}

class OfflineIncidentSpoolSyncState {
  final String statusLabel;
  final DateTime? lastSyncedAtUtc;
  final String? failureReason;
  final int retryCount;
  final int pendingCount;
  final DateTime? lastQueuedAtUtc;
  final List<String> history;

  const OfflineIncidentSpoolSyncState({
    this.statusLabel = 'idle',
    this.lastSyncedAtUtc,
    this.failureReason,
    this.retryCount = 0,
    this.pendingCount = 0,
    this.lastQueuedAtUtc,
    this.history = const <String>[],
  });

  OfflineIncidentSpoolSyncState copyWith({
    String? statusLabel,
    Object? lastSyncedAtUtc = _copySentinel,
    Object? failureReason = _copySentinel,
    int? retryCount,
    int? pendingCount,
    Object? lastQueuedAtUtc = _copySentinel,
    List<String>? history,
  }) {
    return OfflineIncidentSpoolSyncState(
      statusLabel: statusLabel ?? this.statusLabel,
      lastSyncedAtUtc: identical(lastSyncedAtUtc, _copySentinel)
          ? this.lastSyncedAtUtc
          : lastSyncedAtUtc as DateTime?,
      failureReason: identical(failureReason, _copySentinel)
          ? this.failureReason
          : failureReason as String?,
      retryCount: retryCount ?? this.retryCount,
      pendingCount: pendingCount ?? this.pendingCount,
      lastQueuedAtUtc: identical(lastQueuedAtUtc, _copySentinel)
          ? this.lastQueuedAtUtc
          : lastQueuedAtUtc as DateTime?,
      history: history ?? this.history,
    );
  }

  Map<String, Object?> toJson() => {
    'status_label': statusLabel,
    'last_synced_at_utc': lastSyncedAtUtc?.toIso8601String(),
    'failure_reason': failureReason,
    'retry_count': retryCount,
    'pending_count': pendingCount,
    'last_queued_at_utc': lastQueuedAtUtc?.toIso8601String(),
    'history': history,
  };

  factory OfflineIncidentSpoolSyncState.fromJson(Map<String, Object?> json) {
    return OfflineIncidentSpoolSyncState(
      statusLabel: json['status_label']?.toString() ?? 'idle',
      lastSyncedAtUtc:
          DateTime.tryParse(json['last_synced_at_utc']?.toString() ?? '')
              ?.toUtc(),
      failureReason: json['failure_reason']?.toString(),
      retryCount: (json['retry_count'] as num?)?.toInt() ?? 0,
      pendingCount: (json['pending_count'] as num?)?.toInt() ?? 0,
      lastQueuedAtUtc:
          DateTime.tryParse(json['last_queued_at_utc']?.toString() ?? '')
              ?.toUtc(),
      history: (json['history'] as List?)
              ?.map((entry) => entry?.toString() ?? '')
              .where((entry) => entry.trim().isNotEmpty)
              .map((entry) => entry.trim())
              .toList(growable: false) ??
          const <String>[],
    );
  }
}

class OfflineIncidentSpoolSyncResult {
  final int syncedCount;
  final int failedCount;
  final int pendingCount;
  final String? failureReason;

  const OfflineIncidentSpoolSyncResult({
    required this.syncedCount,
    required this.failedCount,
    required this.pendingCount,
    this.failureReason,
  });
}

abstract class OfflineIncidentSpoolRemoteGateway {
  Future<void> flushEntries(List<OfflineIncidentSpoolEntry> entries);
}

class NoopOfflineIncidentSpoolRemoteGateway
    implements OfflineIncidentSpoolRemoteGateway {
  const NoopOfflineIncidentSpoolRemoteGateway();

  @override
  Future<void> flushEntries(List<OfflineIncidentSpoolEntry> entries) async {
    throw StateError('Offline incident spool remote sync is not configured.');
  }
}

class LedgerBackedOfflineIncidentSpoolRemoteGateway
    implements OfflineIncidentSpoolRemoteGateway {
  final ClientLedgerService ledgerService;

  const LedgerBackedOfflineIncidentSpoolRemoteGateway({
    required this.ledgerService,
  });

  static String ledgerDispatchIdFor(String entryId) {
    return 'SPOOL-$entryId';
  }

  @override
  Future<void> flushEntries(List<OfflineIncidentSpoolEntry> entries) async {
    final ordered = [...entries]
      ..sort((a, b) {
        final ts = a.createdAtUtc.compareTo(b.createdAtUtc);
        if (ts != 0) return ts;
        return a.entryId.compareTo(b.entryId);
      });

    for (final entry in ordered) {
      await ledgerService.sealCanonicalRecord(
        clientId: entry.clientId,
        recordId: ledgerDispatchIdFor(entry.entryId),
        canonicalPayload: {
          'type': 'offline_incident_spool_entry',
          ...entry.toJson(),
        },
      );
    }
  }
}

class OfflineIncidentSpoolService {
  final DispatchPersistenceService persistence;
  final OfflineIncidentSpoolRemoteGateway remote;
  final Random _random;

  OfflineIncidentSpoolService({
    required this.persistence,
    required this.remote,
    Random? random,
  }) : _random = random ?? Random();

  Future<OfflineIncidentSpoolEntry> enqueue({
    required String incidentReference,
    required String sourceType,
    required String provider,
    required String clientId,
    required String siteId,
    required String summary,
    required Map<String, Object?> payload,
    DateTime? occurredAtUtc,
  }) async {
    final createdAt = DateTime.now().toUtc();
    final entry = OfflineIncidentSpoolEntry(
      entryId: _nextEntryId(createdAt),
      incidentReference: incidentReference.trim(),
      sourceType: sourceType.trim(),
      provider: provider.trim(),
      clientId: clientId.trim(),
      siteId: siteId.trim(),
      createdAtUtc: createdAt,
      occurredAtUtc: (occurredAtUtc ?? createdAt).toUtc(),
      summary: summary.trim(),
      payload: Map<String, Object?>.from(payload),
    );
    final entries = [
      ...await persistence.readOfflineIncidentSpoolEntries(),
    ];
    entries.add(entry);
    await persistence.saveOfflineIncidentSpoolEntries(entries);
    final pendingCount = entries.where((item) => item.isPending).length;
    final state = (await persistence.readOfflineIncidentSpoolSyncState())
        .copyWith(
          statusLabel: 'buffering',
          failureReason: null,
          pendingCount: pendingCount,
          lastQueuedAtUtc: createdAt,
          history: _appendHistory(
            await persistence.readOfflineIncidentSpoolSyncState(),
            'Queued ${entry.incidentReference} • ${entry.sourceType}',
          ),
        );
    await persistence.saveOfflineIncidentSpoolSyncState(state);
    return entry;
  }

  Future<List<OfflineIncidentSpoolEntry>> readPendingEntries() async {
    final entries = await persistence.readOfflineIncidentSpoolEntries();
    final pending = entries.where((entry) => entry.isPending).toList();
    pending.sort((a, b) => a.createdAtUtc.compareTo(b.createdAtUtc));
    return pending;
  }

  Future<List<OfflineIncidentSpoolEntry>> readRecentEntries({
    int limit = 20,
  }) async {
    final entries = await persistence.readOfflineIncidentSpoolEntries();
    entries.sort((a, b) => b.createdAtUtc.compareTo(a.createdAtUtc));
    return entries.take(limit).toList(growable: false);
  }

  Future<OfflineIncidentSpoolSyncState> readSyncState() {
    return persistence.readOfflineIncidentSpoolSyncState();
  }

  Future<int> retryFailedEntries() async {
    final entries = await persistence.readOfflineIncidentSpoolEntries();
    var retried = 0;
    final updated = entries.map((entry) {
      if (entry.status != OfflineIncidentSpoolEntryStatus.failed) {
        return entry;
      }
      retried += 1;
      return entry.copyWith(
        status: OfflineIncidentSpoolEntryStatus.queued,
        failureReason: null,
        retryCount: entry.retryCount + 1,
      );
    }).toList(growable: false);
    await persistence.saveOfflineIncidentSpoolEntries(updated);
    if (retried == 0) {
      return 0;
    }
    final pendingCount = updated.where((entry) => entry.isPending).length;
    final currentState = await persistence.readOfflineIncidentSpoolSyncState();
    await persistence.saveOfflineIncidentSpoolSyncState(
      currentState.copyWith(
        statusLabel: 'buffering',
        pendingCount: pendingCount,
        history: _appendHistory(
          currentState,
          'Retried $retried failed offline incident entries',
        ),
      ),
    );
    return retried;
  }

  Future<OfflineIncidentSpoolSyncResult> syncPendingEntries({
    int batchSize = 50,
  }) async {
    final all = await persistence.readOfflineIncidentSpoolEntries();
    final pending = all
        .where((entry) => entry.status == OfflineIncidentSpoolEntryStatus.queued)
        .toList(growable: false);
    if (pending.isEmpty) {
      final currentState = await persistence.readOfflineIncidentSpoolSyncState();
      await persistence.saveOfflineIncidentSpoolSyncState(
        currentState.copyWith(
          statusLabel: 'idle',
          pendingCount: 0,
          failureReason: null,
        ),
      );
      return const OfflineIncidentSpoolSyncResult(
        syncedCount: 0,
        failedCount: 0,
        pendingCount: 0,
      );
    }
    final batch = pending.take(batchSize).toList(growable: false);
    final syncingIds = batch.map((entry) => entry.entryId).toSet();
    final syncingEntries = all
        .map(
          (entry) => syncingIds.contains(entry.entryId)
              ? entry.copyWith(status: OfflineIncidentSpoolEntryStatus.syncing)
              : entry,
        )
        .toList(growable: false);
    await persistence.saveOfflineIncidentSpoolEntries(syncingEntries);
    final currentState = await persistence.readOfflineIncidentSpoolSyncState();
    await persistence.saveOfflineIncidentSpoolSyncState(
      currentState.copyWith(
        statusLabel: 'syncing',
        failureReason: null,
        pendingCount: pending.length,
        history: _appendHistory(
          currentState,
          'Syncing ${batch.length} offline incident entries',
        ),
      ),
    );
    try {
      await remote.flushEntries(batch);
      final syncedAt = DateTime.now().toUtc();
      final updated = syncingEntries
          .map(
            (entry) => syncingIds.contains(entry.entryId)
                ? entry.copyWith(
                    status: OfflineIncidentSpoolEntryStatus.synced,
                    syncedAtUtc: syncedAt,
                    failureReason: null,
                  )
                : entry,
          )
          .toList(growable: false);
      await persistence.saveOfflineIncidentSpoolEntries(updated);
      final pendingCount = updated.where((entry) => entry.isPending).length;
      final refreshedState = await persistence.readOfflineIncidentSpoolSyncState();
      await persistence.saveOfflineIncidentSpoolSyncState(
        refreshedState.copyWith(
          statusLabel: pendingCount == 0 ? 'synced' : 'buffering',
          lastSyncedAtUtc: syncedAt,
          failureReason: null,
          pendingCount: pendingCount,
          history: _appendHistory(
            refreshedState,
            'Synced ${batch.length} offline incident entries',
          ),
        ),
      );
      return OfflineIncidentSpoolSyncResult(
        syncedCount: batch.length,
        failedCount: 0,
        pendingCount: pendingCount,
      );
    } catch (error) {
      final updated = syncingEntries
          .map(
            (entry) => syncingIds.contains(entry.entryId)
                ? entry.copyWith(
                    status: OfflineIncidentSpoolEntryStatus.failed,
                    retryCount: entry.retryCount + 1,
                    failureReason: error.toString(),
                  )
                : entry,
          )
          .toList(growable: false);
      await persistence.saveOfflineIncidentSpoolEntries(updated);
      final pendingCount = updated.where((entry) => entry.isPending).length;
      final refreshedState = await persistence.readOfflineIncidentSpoolSyncState();
      await persistence.saveOfflineIncidentSpoolSyncState(
        refreshedState.copyWith(
          statusLabel: 'failed',
          failureReason: error.toString(),
          retryCount: refreshedState.retryCount + 1,
          pendingCount: pendingCount,
          history: _appendHistory(
            refreshedState,
            'Sync failed • ${error.toString()}',
          ),
        ),
      );
      return OfflineIncidentSpoolSyncResult(
        syncedCount: 0,
        failedCount: batch.length,
        pendingCount: pendingCount,
        failureReason: error.toString(),
      );
    }
  }

  String _nextEntryId(DateTime nowUtc) {
    final randomPart = _random
        .nextInt(0x100000000)
        .toRadixString(16)
        .padLeft(8, '0');
    return 'spool-${nowUtc.millisecondsSinceEpoch}-$randomPart';
  }

  List<String> _appendHistory(
    OfflineIncidentSpoolSyncState state,
    String entry,
  ) {
    final next = <String>[...state.history, entry];
    if (next.length <= 12) {
      return next;
    }
    return next.sublist(next.length - 12);
  }
}

const Object _copySentinel = Object();
