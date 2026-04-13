import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:crypto/crypto.dart';
import 'package:supabase/supabase.dart';

import '../../engine/dispatch/action_status.dart';
import '../../engine/dispatch/dispatch_action.dart';
import '../events/decision_created.dart';
import '../events/dispatch_decided_event.dart';
import '../events/dispatch_event.dart';
import '../events/execution_completed.dart';
import '../events/execution_completed_event.dart';
import '../events/execution_denied.dart';
import '../events/guard_checked_in.dart';
import '../events/incident_closed.dart';
import '../events/intelligence_received.dart';
import '../events/listener_alarm_advisory_recorded.dart';
import '../events/listener_alarm_feed_cycle_recorded.dart';
import '../events/listener_alarm_parity_cycle_recorded.dart';
import '../events/partner_dispatch_status_declared.dart';
import '../events/patrol_completed.dart';
import '../events/report_generated.dart';
import '../events/response_arrived.dart';
import '../events/vehicle_visit_review_recorded.dart';
import 'event_store.dart';

class InMemoryEventStore implements EventStore {
  static const String _genesisHash = 'GENESIS';
  static const String _unscopedSiteId = 'UNSCOPED';

  final List<DispatchEvent> _events = [];
  final Set<String> _eventIds = {};
  final SupabaseClient? _supabaseClient;
  final String _restoreSiteId;
  final int _restoreLimit;
  final Duration _retryInterval;
  final Map<String, int> _persistedSequenceBySite = <String, int>{};
  final Map<String, String> _lastHashBySite = <String, String>{};
  final Map<String, _PersistedEventEnvelope> _retryQueueByEventId =
      <String, _PersistedEventEnvelope>{};

  Future<void>? _restoreFuture;
  bool _retryInFlight = false;
  int _currentSequence = 0;

  InMemoryEventStore({
    SupabaseClient? supabaseClient,
    String restoreSiteId = '',
    int restoreLimit = 100,
    Duration retryInterval = const Duration(seconds: 30),
  }) : _supabaseClient = supabaseClient,
       _restoreSiteId = restoreSiteId.trim(),
       _restoreLimit = restoreLimit,
       _retryInterval = retryInterval {
    if (_supabaseClient != null) {
      Timer.periodic(_retryInterval, (_) {
        unawaited(_flushRetryQueue());
      });
    }
  }

  Future<void> restoreFromSupabase() {
    if (_supabaseClient == null) {
      return Future<void>.value();
    }
    return _restoreFuture ??= _restoreFromSupabase();
  }

  @override
  void append(DispatchEvent event) {
    if (_eventIds.contains(event.eventId)) {
      throw StateError('Duplicate eventId detected: ${event.eventId}');
    }

    _currentSequence++;
    final sequencedEvent = event.copyWithSequence(_currentSequence);

    _events.add(sequencedEvent);
    _eventIds.add(sequencedEvent.eventId);

    if (_supabaseClient != null) {
      unawaited(_persistSequencedEvent(sequencedEvent));
    }
  }

  @override
  List<DispatchEvent> allEvents() {
    return List.unmodifiable(_events);
  }

  void clear() {
    _events.clear();
    _eventIds.clear();
    _retryQueueByEventId.clear();
    _persistedSequenceBySite.clear();
    _lastHashBySite.clear();
    _currentSequence = 0;
  }

  Future<void> _persistSequencedEvent(DispatchEvent event) async {
    final resolvedScope = _resolvedScopeForEvent(event);
    final siteScope = _normalizeSiteScope(resolvedScope.siteId);
    final previousHash = _lastHashBySite[siteScope] ?? _genesisHash;
    final persistedSequence = (_persistedSequenceBySite[siteScope] ?? 0) + 1;
    final eventData = _eventData(event);
    final canonicalEventData = _canonicalJson(eventData);
    final hashInput = <String>[
      '$persistedSequence',
      siteScope,
      event.toAuditTypeKey(),
      canonicalEventData,
      previousHash,
    ].join('|');
    final currentHash = sha256.convert(utf8.encode(hashInput)).toString();

    _persistedSequenceBySite[siteScope] = persistedSequence;
    _lastHashBySite[siteScope] = currentHash;

    final envelope = _PersistedEventEnvelope(
      eventId: event.eventId,
      persistedSequence: persistedSequence,
      siteId: siteScope,
      clientId: resolvedScope.clientId,
      eventType: event.toAuditTypeKey(),
      eventData: eventData,
      occurredAt: event.occurredAt.toUtc(),
      hash: currentHash,
      previousHash: previousHash,
    );
    await _upsertEnvelope(envelope, enqueueOnFailure: true);
  }

  Future<void> _upsertEnvelope(
    _PersistedEventEnvelope envelope, {
    required bool enqueueOnFailure,
  }) async {
    final client = _supabaseClient;
    if (client == null) {
      return;
    }
    try {
      await client.from('onyx_event_store').upsert(<String, Object?>{
        'sequence': envelope.persistedSequence,
        'site_id': envelope.siteId,
        'client_id': envelope.clientId,
        'event_type': envelope.eventType,
        'event_data': envelope.eventData,
        'occurred_at': envelope.occurredAt.toIso8601String(),
        'hash': envelope.hash,
        'previous_hash': envelope.previousHash,
      }, onConflict: 'site_id,sequence');
      _retryQueueByEventId.remove(envelope.eventId);
    } catch (error, stackTrace) {
      if (enqueueOnFailure) {
        _retryQueueByEventId[envelope.eventId] = envelope;
        developer.log(
          '[ONYX] EventStore persist failed — queued for retry',
          name: 'InMemoryEventStore',
          error: error,
          stackTrace: stackTrace,
          level: 900,
        );
      }
    }
  }

  Future<void> _flushRetryQueue() async {
    if (_retryInFlight || _retryQueueByEventId.isEmpty) {
      return;
    }
    _retryInFlight = true;
    try {
      final envelopes = _retryQueueByEventId.values.toList(growable: false);
      for (final envelope in envelopes) {
        await _upsertEnvelope(envelope, enqueueOnFailure: true);
      }
    } finally {
      _retryInFlight = false;
    }
  }

  Future<void> _restoreFromSupabase() async {
    final client = _supabaseClient;
    final requestedSiteId = _restoreSiteId.trim();
    if (client == null || requestedSiteId.isEmpty) {
      return;
    }
    try {
      final rowsRaw = await client
          .from('onyx_event_store')
          .select(
            'sequence, site_id, client_id, event_type, event_data, occurred_at, hash, previous_hash',
          )
          .eq('site_id', _normalizeSiteScope(requestedSiteId))
          .order('sequence', ascending: false)
          .limit(_restoreLimit);
      final rows = List<Map<String, dynamic>>.from(rowsRaw);
      final ordered = rows.reversed;
      var restoredCount = 0;
      for (final row in ordered) {
        final event = _eventFromRow(row);
        if (event == null || _eventIds.contains(event.eventId)) {
          continue;
        }
        _events.add(event);
        _eventIds.add(event.eventId);
        if (event.sequence > _currentSequence) {
          _currentSequence = event.sequence;
        }
        final siteScope = _normalizeSiteScope(
          (row['site_id'] ?? '').toString().trim(),
        );
        final persistedSequence = _readInt(row['sequence']) ?? 0;
        if (persistedSequence > (_persistedSequenceBySite[siteScope] ?? 0)) {
          _persistedSequenceBySite[siteScope] = persistedSequence;
          _lastHashBySite[siteScope] =
              (row['hash'] ?? _genesisHash).toString().trim().isEmpty
              ? _genesisHash
              : (row['hash'] ?? _genesisHash).toString().trim();
        }
        restoredCount += 1;
      }
      developer.log(
        '[ONYX] EventStore restored: $restoredCount events from Supabase',
        name: 'InMemoryEventStore',
      );
    } catch (error, stackTrace) {
      developer.log(
        '[ONYX] EventStore restore failed — continuing with in-memory state',
        name: 'InMemoryEventStore',
        error: error,
        stackTrace: stackTrace,
        level: 900,
      );
    }
  }

  DispatchEvent? _eventFromRow(Map<String, dynamic> row) {
    final eventType = (row['event_type'] ?? '').toString().trim();
    final payloadRaw = row['event_data'];
    final payload = payloadRaw is Map
        ? Map<String, Object?>.from(
            payloadRaw.map((key, value) => MapEntry(key.toString(), value)),
          )
        : <String, Object?>{};
    final eventId = _stringValue(payload['eventId']);
    final sequence = _readInt(payload['sequence']) ?? 0;
    final version = _readInt(payload['version']) ?? 1;
    final occurredAt =
        _readDateTime(payload['occurredAtUtc']) ??
        _readDateTime(row['occurred_at']) ??
        DateTime.now().toUtc();
    if (eventId.isEmpty) {
      return null;
    }
    switch (eventType) {
      case DecisionCreated.auditTypeKey:
        return DecisionCreated(
          eventId: eventId,
          sequence: sequence,
          version: version,
          occurredAt: occurredAt,
          dispatchId: _stringValue(payload['dispatchId']),
          clientId: _stringValue(payload['clientId']),
          regionId: _stringValue(payload['regionId']),
          siteId: _stringValue(payload['siteId']),
        );
      case DispatchDecidedEvent.auditTypeKey:
        return DispatchDecidedEvent(
          eventId: eventId,
          sequence: sequence,
          version: version,
          occurredAt: occurredAt,
          action: DispatchAction(
            dispatchId: _stringValue(payload['dispatchId']),
            status:
                _enumByName(
                  ActionStatus.values,
                  _stringValue(payload['status']),
                ) ??
                ActionStatus.decided,
          ),
        );
      case ExecutionCompleted.auditTypeKey:
        return ExecutionCompleted(
          eventId: eventId,
          sequence: sequence,
          version: version,
          occurredAt: occurredAt,
          dispatchId: _stringValue(payload['dispatchId']),
          clientId: _stringValue(payload['clientId']),
          regionId: _stringValue(payload['regionId']),
          siteId: _stringValue(payload['siteId']),
          success: _boolValue(payload['success']),
        );
      case ExecutionCompletedEvent.auditTypeKey:
        return ExecutionCompletedEvent(
          eventId: eventId,
          sequence: sequence,
          version: version,
          occurredAt: occurredAt,
          dispatchId: _stringValue(payload['dispatchId']),
          outcome:
              _enumByName(
                ExecutionOutcome.values,
                _stringValue(payload['outcome']),
              ) ??
              ExecutionOutcome.success,
          failureType: _nullableStringValue(payload['failureType']),
        );
      case ExecutionDenied.auditTypeKey:
        return ExecutionDenied(
          eventId: eventId,
          sequence: sequence,
          version: version,
          occurredAt: occurredAt,
          dispatchId: _stringValue(payload['dispatchId']),
          clientId: _stringValue(payload['clientId']),
          regionId: _stringValue(payload['regionId']),
          siteId: _stringValue(payload['siteId']),
          operatorId: _stringValue(payload['operatorId']),
          reason: _stringValue(payload['reason']),
        );
      case GuardCheckedIn.auditTypeKey:
        return GuardCheckedIn(
          eventId: eventId,
          sequence: sequence,
          version: version,
          occurredAt: occurredAt,
          guardId: _stringValue(payload['guardId']),
          clientId: _stringValue(payload['clientId']),
          regionId: _stringValue(payload['regionId']),
          siteId: _stringValue(payload['siteId']),
        );
      case IncidentClosed.auditTypeKey:
        return IncidentClosed(
          eventId: eventId,
          sequence: sequence,
          version: version,
          occurredAt: occurredAt,
          dispatchId: _stringValue(payload['dispatchId']),
          resolutionType: _stringValue(payload['resolutionType']),
          clientId: _stringValue(payload['clientId']),
          regionId: _stringValue(payload['regionId']),
          siteId: _stringValue(payload['siteId']),
        );
      case IntelligenceReceived.auditTypeKey:
        return IntelligenceReceived(
          eventId: eventId,
          sequence: sequence,
          version: version,
          occurredAt: occurredAt,
          intelligenceId: _stringValue(payload['intelligenceId']),
          provider: _stringValue(payload['provider']),
          sourceType: _stringValue(payload['sourceType']),
          externalId: _stringValue(payload['externalId']),
          clientId: _stringValue(payload['clientId']),
          regionId: _stringValue(payload['regionId']),
          siteId: _stringValue(payload['siteId']),
          cameraId: _nullableStringValue(payload['cameraId']),
          zone: _nullableStringValue(payload['zone']),
          objectLabel: _nullableStringValue(payload['objectLabel']),
          objectConfidence: _doubleValue(payload['objectConfidence']),
          trackId: _nullableStringValue(payload['trackId']),
          faceMatchId: _nullableStringValue(payload['faceMatchId']),
          faceConfidence: _doubleValue(payload['faceConfidence']),
          plateNumber: _nullableStringValue(payload['plateNumber']),
          plateConfidence: _doubleValue(payload['plateConfidence']),
          headline: _stringValue(payload['headline']),
          summary: _stringValue(payload['summary']),
          riskScore: _readInt(payload['riskScore']) ?? 0,
          snapshotUrl: _nullableStringValue(payload['snapshotUrl']),
          clipUrl: _nullableStringValue(payload['clipUrl']),
          canonicalHash: _stringValue(payload['canonicalHash']),
          snapshotReferenceHash: _nullableStringValue(
            payload['snapshotReferenceHash'],
          ),
          clipReferenceHash: _nullableStringValue(payload['clipReferenceHash']),
          evidenceRecordHash: _nullableStringValue(
            payload['evidenceRecordHash'],
          ),
        );
      case ListenerAlarmAdvisoryRecorded.auditTypeKey:
        return ListenerAlarmAdvisoryRecorded(
          eventId: eventId,
          sequence: sequence,
          version: version,
          occurredAt: occurredAt,
          clientId: _stringValue(payload['clientId']),
          regionId: _stringValue(payload['regionId']),
          siteId: _stringValue(payload['siteId']),
          externalAlarmId: _stringValue(payload['externalAlarmId']),
          accountNumber: _stringValue(payload['accountNumber']),
          partition: _stringValue(payload['partition']),
          zone: _stringValue(payload['zone']),
          zoneLabel: _stringValue(payload['zoneLabel']),
          eventLabel: _stringValue(payload['eventLabel']),
          dispositionLabel: _stringValue(payload['dispositionLabel']),
          summary: _stringValue(payload['summary']),
          recommendation: _stringValue(payload['recommendation']),
          deliveredCount: _readInt(payload['deliveredCount']) ?? 0,
          failedCount: _readInt(payload['failedCount']) ?? 0,
        );
      case ListenerAlarmFeedCycleRecorded.auditTypeKey:
        return ListenerAlarmFeedCycleRecorded(
          eventId: eventId,
          sequence: sequence,
          version: version,
          occurredAt: occurredAt,
          sourceLabel: _stringValue(payload['sourceLabel']),
          acceptedCount: _readInt(payload['acceptedCount']) ?? 0,
          mappedCount: _readInt(payload['mappedCount']) ?? 0,
          unmappedCount: _readInt(payload['unmappedCount']) ?? 0,
          duplicateCount: _readInt(payload['duplicateCount']) ?? 0,
          rejectedCount: _readInt(payload['rejectedCount']) ?? 0,
          normalizationSkippedCount:
              _readInt(payload['normalizationSkippedCount']) ?? 0,
          deliveredCount: _readInt(payload['deliveredCount']) ?? 0,
          failedCount: _readInt(payload['failedCount']) ?? 0,
          clearCount: _readInt(payload['clearCount']) ?? 0,
          suspiciousCount: _readInt(payload['suspiciousCount']) ?? 0,
          unavailableCount: _readInt(payload['unavailableCount']) ?? 0,
          pendingCount: _readInt(payload['pendingCount']) ?? 0,
          rejectSummary: _stringValue(payload['rejectSummary']),
        );
      case ListenerAlarmParityCycleRecorded.auditTypeKey:
        return ListenerAlarmParityCycleRecorded(
          eventId: eventId,
          sequence: sequence,
          version: version,
          occurredAt: occurredAt,
          sourceLabel: _stringValue(payload['sourceLabel']),
          legacySourceLabel: _stringValue(payload['legacySourceLabel']),
          statusLabel: _stringValue(payload['statusLabel']),
          serialCount: _readInt(payload['serialCount']) ?? 0,
          legacyCount: _readInt(payload['legacyCount']) ?? 0,
          matchedCount: _readInt(payload['matchedCount']) ?? 0,
          unmatchedSerialCount: _readInt(payload['unmatchedSerialCount']) ?? 0,
          unmatchedLegacyCount: _readInt(payload['unmatchedLegacyCount']) ?? 0,
          maxAllowedSkewSeconds:
              _readInt(payload['maxAllowedSkewSeconds']) ?? 0,
          maxSkewSecondsObserved:
              _readInt(payload['maxSkewSecondsObserved']) ?? 0,
          averageSkewSeconds: _doubleValue(payload['averageSkewSeconds']) ?? 0,
          driftSummary: _stringValue(payload['driftSummary']),
          driftReasonCounts: _intMap(payload['driftReasonCounts']),
        );
      case PartnerDispatchStatusDeclared.auditTypeKey:
        return PartnerDispatchStatusDeclared(
          eventId: eventId,
          sequence: sequence,
          version: version,
          occurredAt: occurredAt,
          dispatchId: _stringValue(payload['dispatchId']),
          clientId: _stringValue(payload['clientId']),
          regionId: _stringValue(payload['regionId']),
          siteId: _stringValue(payload['siteId']),
          partnerLabel: _stringValue(payload['partnerLabel']),
          actorLabel: _stringValue(payload['actorLabel']),
          status:
              _enumByName(
                PartnerDispatchStatus.values,
                _stringValue(payload['status']),
              ) ??
              PartnerDispatchStatus.unknown,
          sourceChannel: _stringValue(payload['sourceChannel']),
          sourceMessageKey: _stringValue(payload['sourceMessageKey']),
        );
      case PatrolCompleted.auditTypeKey:
        return PatrolCompleted(
          eventId: eventId,
          sequence: sequence,
          version: version,
          occurredAt: occurredAt,
          guardId: _stringValue(payload['guardId']),
          routeId: _stringValue(payload['routeId']),
          clientId: _stringValue(payload['clientId']),
          regionId: _stringValue(payload['regionId']),
          siteId: _stringValue(payload['siteId']),
          durationSeconds: _readInt(payload['durationSeconds']) ?? 0,
        );
      case ReportGenerated.auditTypeKey:
        return ReportGenerated(
          eventId: eventId,
          sequence: sequence,
          version: version,
          occurredAt: occurredAt,
          clientId: _stringValue(payload['clientId']),
          siteId: _stringValue(payload['siteId']),
          month: _stringValue(payload['month']),
          contentHash: _stringValue(payload['contentHash']),
          pdfHash: _stringValue(payload['pdfHash']),
          eventRangeStart: _readInt(payload['eventRangeStart']) ?? 0,
          eventRangeEnd: _readInt(payload['eventRangeEnd']) ?? 0,
          eventCount: _readInt(payload['eventCount']) ?? 0,
          reportSchemaVersion: _readInt(payload['reportSchemaVersion']) ?? 0,
          projectionVersion: _readInt(payload['projectionVersion']) ?? 0,
          primaryBrandLabel: _stringValue(payload['primaryBrandLabel']),
          endorsementLine: _stringValue(payload['endorsementLine']),
          brandingSourceLabel: _stringValue(payload['brandingSourceLabel']),
          brandingUsesOverride: _boolValue(payload['brandingUsesOverride']),
          investigationContextKey: _stringValue(
            payload['investigationContextKey'],
          ),
          includeTimeline: _boolValue(
            payload['includeTimeline'],
            fallback: true,
          ),
          includeDispatchSummary: _boolValue(
            payload['includeDispatchSummary'],
            fallback: true,
          ),
          includeCheckpointCompliance: _boolValue(
            payload['includeCheckpointCompliance'],
            fallback: true,
          ),
          includeAiDecisionLog: _boolValue(
            payload['includeAiDecisionLog'],
            fallback: true,
          ),
          includeGuardMetrics: _boolValue(
            payload['includeGuardMetrics'],
            fallback: true,
          ),
        );
      case ResponseArrived.auditTypeKey:
        return ResponseArrived(
          eventId: eventId,
          sequence: sequence,
          version: version,
          occurredAt: occurredAt,
          dispatchId: _stringValue(payload['dispatchId']),
          guardId: _stringValue(payload['guardId']),
          clientId: _stringValue(payload['clientId']),
          regionId: _stringValue(payload['regionId']),
          siteId: _stringValue(payload['siteId']),
        );
      case VehicleVisitReviewRecorded.auditTypeKey:
        return VehicleVisitReviewRecorded(
          eventId: eventId,
          sequence: sequence,
          version: version,
          occurredAt: occurredAt,
          vehicleVisitKey: _stringValue(payload['vehicleVisitKey']),
          primaryEventId: _stringValue(payload['primaryEventId']),
          clientId: _stringValue(payload['clientId']),
          regionId: _stringValue(payload['regionId']),
          siteId: _stringValue(payload['siteId']),
          vehicleLabel: _stringValue(payload['vehicleLabel']),
          actorLabel: _stringValue(payload['actorLabel']),
          reviewed: _boolValue(payload['reviewed']),
          statusOverride: _stringValue(payload['statusOverride']),
          effectiveStatusLabel: _stringValue(payload['effectiveStatusLabel']),
          reasonLabel: _stringValue(payload['reasonLabel']),
          workflowSummary: _stringValue(payload['workflowSummary']),
          sourceSurface: _stringValue(payload['sourceSurface']),
        );
      default:
        return null;
    }
  }

  Map<String, Object?> _eventData(DispatchEvent event) {
    final base = <String, Object?>{
      'eventId': event.eventId,
      'sequence': event.sequence,
      'version': event.version,
      'occurredAtUtc': event.occurredAt.toUtc().toIso8601String(),
    };
    switch (event) {
      case DecisionCreated():
        return <String, Object?>{
          ...base,
          'dispatchId': event.dispatchId,
          'clientId': event.clientId,
          'regionId': event.regionId,
          'siteId': event.siteId,
        };
      case DispatchDecidedEvent():
        return <String, Object?>{
          ...base,
          'dispatchId': event.action.dispatchId,
          'status': event.action.status.name,
        };
      case ExecutionCompleted():
        return <String, Object?>{
          ...base,
          'dispatchId': event.dispatchId,
          'clientId': event.clientId,
          'regionId': event.regionId,
          'siteId': event.siteId,
          'success': event.success,
        };
      case ExecutionCompletedEvent():
        return <String, Object?>{
          ...base,
          'dispatchId': event.dispatchId,
          'outcome': event.outcome.name,
          'failureType': event.failureType,
        };
      case ExecutionDenied():
        return <String, Object?>{
          ...base,
          'dispatchId': event.dispatchId,
          'clientId': event.clientId,
          'regionId': event.regionId,
          'siteId': event.siteId,
          'operatorId': event.operatorId,
          'reason': event.reason,
        };
      case GuardCheckedIn():
        return <String, Object?>{
          ...base,
          'guardId': event.guardId,
          'clientId': event.clientId,
          'regionId': event.regionId,
          'siteId': event.siteId,
        };
      case IncidentClosed():
        return <String, Object?>{
          ...base,
          'dispatchId': event.dispatchId,
          'resolutionType': event.resolutionType,
          'clientId': event.clientId,
          'regionId': event.regionId,
          'siteId': event.siteId,
        };
      case IntelligenceReceived():
        return <String, Object?>{
          ...base,
          'intelligenceId': event.intelligenceId,
          'provider': event.provider,
          'sourceType': event.sourceType,
          'externalId': event.externalId,
          'clientId': event.clientId,
          'regionId': event.regionId,
          'siteId': event.siteId,
          'cameraId': event.cameraId,
          'zone': event.zone,
          'objectLabel': event.objectLabel,
          'objectConfidence': event.objectConfidence,
          'trackId': event.trackId,
          'faceMatchId': event.faceMatchId,
          'faceConfidence': event.faceConfidence,
          'plateNumber': event.plateNumber,
          'plateConfidence': event.plateConfidence,
          'headline': event.headline,
          'summary': event.summary,
          'riskScore': event.riskScore,
          'snapshotUrl': event.snapshotUrl,
          'clipUrl': event.clipUrl,
          'canonicalHash': event.canonicalHash,
          'snapshotReferenceHash': event.snapshotReferenceHash,
          'clipReferenceHash': event.clipReferenceHash,
          'evidenceRecordHash': event.evidenceRecordHash,
        };
      case ListenerAlarmAdvisoryRecorded():
        return <String, Object?>{
          ...base,
          'clientId': event.clientId,
          'regionId': event.regionId,
          'siteId': event.siteId,
          'externalAlarmId': event.externalAlarmId,
          'accountNumber': event.accountNumber,
          'partition': event.partition,
          'zone': event.zone,
          'zoneLabel': event.zoneLabel,
          'eventLabel': event.eventLabel,
          'dispositionLabel': event.dispositionLabel,
          'summary': event.summary,
          'recommendation': event.recommendation,
          'deliveredCount': event.deliveredCount,
          'failedCount': event.failedCount,
        };
      case ListenerAlarmFeedCycleRecorded():
        return <String, Object?>{
          ...base,
          'sourceLabel': event.sourceLabel,
          'acceptedCount': event.acceptedCount,
          'mappedCount': event.mappedCount,
          'unmappedCount': event.unmappedCount,
          'duplicateCount': event.duplicateCount,
          'rejectedCount': event.rejectedCount,
          'normalizationSkippedCount': event.normalizationSkippedCount,
          'deliveredCount': event.deliveredCount,
          'failedCount': event.failedCount,
          'clearCount': event.clearCount,
          'suspiciousCount': event.suspiciousCount,
          'unavailableCount': event.unavailableCount,
          'pendingCount': event.pendingCount,
          'rejectSummary': event.rejectSummary,
        };
      case ListenerAlarmParityCycleRecorded():
        return <String, Object?>{
          ...base,
          'sourceLabel': event.sourceLabel,
          'legacySourceLabel': event.legacySourceLabel,
          'statusLabel': event.statusLabel,
          'serialCount': event.serialCount,
          'legacyCount': event.legacyCount,
          'matchedCount': event.matchedCount,
          'unmatchedSerialCount': event.unmatchedSerialCount,
          'unmatchedLegacyCount': event.unmatchedLegacyCount,
          'maxAllowedSkewSeconds': event.maxAllowedSkewSeconds,
          'maxSkewSecondsObserved': event.maxSkewSecondsObserved,
          'averageSkewSeconds': event.averageSkewSeconds,
          'driftSummary': event.driftSummary,
          'driftReasonCounts': event.driftReasonCounts,
        };
      case PartnerDispatchStatusDeclared():
        return <String, Object?>{
          ...base,
          'dispatchId': event.dispatchId,
          'clientId': event.clientId,
          'regionId': event.regionId,
          'siteId': event.siteId,
          'partnerLabel': event.partnerLabel,
          'actorLabel': event.actorLabel,
          'status': event.status.name,
          'sourceChannel': event.sourceChannel,
          'sourceMessageKey': event.sourceMessageKey,
        };
      case PatrolCompleted():
        return <String, Object?>{
          ...base,
          'guardId': event.guardId,
          'routeId': event.routeId,
          'clientId': event.clientId,
          'regionId': event.regionId,
          'siteId': event.siteId,
          'durationSeconds': event.durationSeconds,
        };
      case ReportGenerated():
        return <String, Object?>{
          ...base,
          'clientId': event.clientId,
          'siteId': event.siteId,
          'month': event.month,
          'contentHash': event.contentHash,
          'pdfHash': event.pdfHash,
          'eventRangeStart': event.eventRangeStart,
          'eventRangeEnd': event.eventRangeEnd,
          'eventCount': event.eventCount,
          'reportSchemaVersion': event.reportSchemaVersion,
          'projectionVersion': event.projectionVersion,
          'primaryBrandLabel': event.primaryBrandLabel,
          'endorsementLine': event.endorsementLine,
          'brandingSourceLabel': event.brandingSourceLabel,
          'brandingUsesOverride': event.brandingUsesOverride,
          'investigationContextKey': event.investigationContextKey,
          'includeTimeline': event.includeTimeline,
          'includeDispatchSummary': event.includeDispatchSummary,
          'includeCheckpointCompliance': event.includeCheckpointCompliance,
          'includeAiDecisionLog': event.includeAiDecisionLog,
          'includeGuardMetrics': event.includeGuardMetrics,
        };
      case ResponseArrived():
        return <String, Object?>{
          ...base,
          'dispatchId': event.dispatchId,
          'guardId': event.guardId,
          'clientId': event.clientId,
          'regionId': event.regionId,
          'siteId': event.siteId,
        };
      case VehicleVisitReviewRecorded():
        return <String, Object?>{
          ...base,
          'vehicleVisitKey': event.vehicleVisitKey,
          'primaryEventId': event.primaryEventId,
          'clientId': event.clientId,
          'regionId': event.regionId,
          'siteId': event.siteId,
          'vehicleLabel': event.vehicleLabel,
          'actorLabel': event.actorLabel,
          'reviewed': event.reviewed,
          'statusOverride': event.statusOverride,
          'effectiveStatusLabel': event.effectiveStatusLabel,
          'reasonLabel': event.reasonLabel,
          'workflowSummary': event.workflowSummary,
          'sourceSurface': event.sourceSurface,
        };
    }
    throw StateError(
      'Unsupported dispatch event type for persistence: ${event.runtimeType}',
    );
  }

  _ResolvedEventScope _resolvedScopeForEvent(DispatchEvent event) {
    switch (event) {
      case DecisionCreated():
        return _ResolvedEventScope(
          siteId: event.siteId.trim(),
          clientId: event.clientId.trim(),
        );
      case IntelligenceReceived():
        return _ResolvedEventScope(
          siteId: event.siteId.trim(),
          clientId: event.clientId.trim(),
        );
      case ResponseArrived():
        return _ResolvedEventScope(
          siteId: event.siteId.trim(),
          clientId: event.clientId.trim(),
        );
      case IncidentClosed():
        return _ResolvedEventScope(
          siteId: event.siteId.trim(),
          clientId: event.clientId.trim(),
        );
      case PatrolCompleted():
        return _ResolvedEventScope(
          siteId: event.siteId.trim(),
          clientId: event.clientId.trim(),
        );
      case GuardCheckedIn():
        return _ResolvedEventScope(
          siteId: event.siteId.trim(),
          clientId: event.clientId.trim(),
        );
      case PartnerDispatchStatusDeclared():
        return _ResolvedEventScope(
          siteId: event.siteId.trim(),
          clientId: event.clientId.trim(),
        );
      case ExecutionCompleted():
        return _ResolvedEventScope(
          siteId: event.siteId.trim(),
          clientId: event.clientId.trim(),
        );
      case ExecutionDenied():
        return _ResolvedEventScope(
          siteId: event.siteId.trim(),
          clientId: event.clientId.trim(),
        );
      case ReportGenerated():
        return _ResolvedEventScope(
          siteId: event.siteId.trim(),
          clientId: event.clientId.trim(),
        );
      case ListenerAlarmAdvisoryRecorded():
        return _ResolvedEventScope(
          siteId: event.siteId.trim(),
          clientId: event.clientId.trim(),
        );
      case VehicleVisitReviewRecorded():
        return _ResolvedEventScope(
          siteId: event.siteId.trim(),
          clientId: event.clientId.trim(),
        );
      case DispatchDecidedEvent():
        return _scopeForDispatchId(event.action.dispatchId);
      case ExecutionCompletedEvent():
        return _scopeForDispatchId(event.dispatchId);
      case ListenerAlarmFeedCycleRecorded():
      case ListenerAlarmParityCycleRecorded():
        return const _ResolvedEventScope(siteId: _unscopedSiteId, clientId: '');
    }
    return const _ResolvedEventScope(siteId: _unscopedSiteId, clientId: '');
  }

  _ResolvedEventScope _scopeForDispatchId(String dispatchId) {
    final normalizedDispatchId = dispatchId.trim();
    if (normalizedDispatchId.isEmpty) {
      return const _ResolvedEventScope(siteId: _unscopedSiteId, clientId: '');
    }
    for (final event in _events.reversed) {
      final candidateDispatchId = _dispatchIdForEvent(event);
      if (candidateDispatchId != normalizedDispatchId) {
        continue;
      }
      final scope = _directScopeForEvent(event);
      if (scope != null) {
        return scope;
      }
    }
    return const _ResolvedEventScope(siteId: _unscopedSiteId, clientId: '');
  }

  _ResolvedEventScope? _directScopeForEvent(DispatchEvent event) {
    switch (event) {
      case DecisionCreated():
        return _ResolvedEventScope(
          siteId: event.siteId.trim(),
          clientId: event.clientId.trim(),
        );
      case IntelligenceReceived():
        return _ResolvedEventScope(
          siteId: event.siteId.trim(),
          clientId: event.clientId.trim(),
        );
      case ResponseArrived():
        return _ResolvedEventScope(
          siteId: event.siteId.trim(),
          clientId: event.clientId.trim(),
        );
      case IncidentClosed():
        return _ResolvedEventScope(
          siteId: event.siteId.trim(),
          clientId: event.clientId.trim(),
        );
      case PartnerDispatchStatusDeclared():
        return _ResolvedEventScope(
          siteId: event.siteId.trim(),
          clientId: event.clientId.trim(),
        );
      case ExecutionCompleted():
        return _ResolvedEventScope(
          siteId: event.siteId.trim(),
          clientId: event.clientId.trim(),
        );
      case ExecutionDenied():
        return _ResolvedEventScope(
          siteId: event.siteId.trim(),
          clientId: event.clientId.trim(),
        );
      default:
        return null;
    }
  }

  String? _dispatchIdForEvent(DispatchEvent event) {
    switch (event) {
      case DecisionCreated():
        return event.dispatchId.trim();
      case ResponseArrived():
        return event.dispatchId.trim();
      case IncidentClosed():
        return event.dispatchId.trim();
      case PartnerDispatchStatusDeclared():
        return event.dispatchId.trim();
      case ExecutionCompleted():
        return event.dispatchId.trim();
      case ExecutionDenied():
        return event.dispatchId.trim();
      case DispatchDecidedEvent():
        return event.action.dispatchId.trim();
      case ExecutionCompletedEvent():
        return event.dispatchId.trim();
      default:
        return null;
    }
  }

  String _normalizeSiteScope(String siteId) {
    final normalized = siteId.trim();
    return normalized.isEmpty ? _unscopedSiteId : normalized;
  }

  String _canonicalJson(Map<String, Object?> value) {
    return jsonEncode(_canonicalizeJsonValue(value));
  }

  Object? _canonicalizeJsonValue(Object? value) {
    if (value is Map) {
      final normalized = value.map(
        (key, nestedValue) => MapEntry(key.toString(), nestedValue),
      );
      final keys = normalized.keys.toList(growable: false)..sort();
      return <String, Object?>{
        for (final key in keys) key: _canonicalizeJsonValue(normalized[key]),
      };
    }
    if (value is List) {
      return value.map(_canonicalizeJsonValue).toList(growable: false);
    }
    return value;
  }
}

class _PersistedEventEnvelope {
  final String eventId;
  final int persistedSequence;
  final String siteId;
  final String clientId;
  final String eventType;
  final Map<String, Object?> eventData;
  final DateTime occurredAt;
  final String hash;
  final String previousHash;

  const _PersistedEventEnvelope({
    required this.eventId,
    required this.persistedSequence,
    required this.siteId,
    required this.clientId,
    required this.eventType,
    required this.eventData,
    required this.occurredAt,
    required this.hash,
    required this.previousHash,
  });
}

class _ResolvedEventScope {
  final String siteId;
  final String clientId;

  const _ResolvedEventScope({required this.siteId, required this.clientId});
}

int? _readInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

double? _doubleValue(Object? value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '');
}

DateTime? _readDateTime(Object? value) {
  if (value is DateTime) {
    return value.toUtc();
  }
  final normalized = value?.toString().trim() ?? '';
  if (normalized.isEmpty) {
    return null;
  }
  return DateTime.tryParse(normalized)?.toUtc();
}

String _stringValue(Object? value) => value?.toString().trim() ?? '';

String? _nullableStringValue(Object? value) {
  final normalized = _stringValue(value);
  return normalized.isEmpty ? null : normalized;
}

bool _boolValue(Object? value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  if (normalized == 'true') {
    return true;
  }
  if (normalized == 'false') {
    return false;
  }
  return fallback;
}

Map<String, int> _intMap(Object? value) {
  if (value is! Map) {
    return const <String, int>{};
  }
  return <String, int>{
    for (final entry in value.entries)
      entry.key.toString(): _readInt(entry.value) ?? 0,
  };
}

T? _enumByName<T extends Enum>(List<T> values, String raw) {
  final normalized = raw.trim();
  if (normalized.isEmpty) {
    return null;
  }
  for (final value in values) {
    if (value.name == normalized) {
      return value;
    }
  }
  return null;
}
