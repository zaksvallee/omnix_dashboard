import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/dispatch_decided_event.dart';
import 'package:omnix_dashboard/domain/events/execution_completed.dart';
import 'package:omnix_dashboard/domain/events/execution_completed_event.dart';
import 'package:omnix_dashboard/domain/events/execution_denied.dart';
import 'package:omnix_dashboard/domain/events/guard_checked_in.dart';
import 'package:omnix_dashboard/domain/events/incident_closed.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/domain/events/listener_alarm_advisory_recorded.dart';
import 'package:omnix_dashboard/domain/events/listener_alarm_feed_cycle_recorded.dart';
import 'package:omnix_dashboard/domain/events/listener_alarm_parity_cycle_recorded.dart';
import 'package:omnix_dashboard/domain/events/partner_dispatch_status_declared.dart';
import 'package:omnix_dashboard/domain/events/patrol_completed.dart';
import 'package:omnix_dashboard/domain/events/report_generated.dart';
import 'package:omnix_dashboard/domain/events/response_arrived.dart';
import 'package:omnix_dashboard/domain/events/vehicle_visit_review_recorded.dart';
import 'package:omnix_dashboard/domain/models/dispatch_action.dart';
import 'package:omnix_dashboard/engine/dispatch/action_status.dart';

void main() {
  test('dispatch event audit type keys remain hardcoded and stable', () {
    final eventTypeKeys = <Object, String>{
      DecisionCreated(
        eventId: 'DEC-1',
        sequence: 1,
        version: 1,
        occurredAt: DateTime.utc(2026, 4, 7, 8),
        dispatchId: 'DSP-1',
        clientId: 'CLIENT-1',
        regionId: 'REGION-1',
        siteId: 'SITE-1',
      ): 'decision_created',
      DispatchDecidedEvent(
        eventId: 'DECIDE-1',
        sequence: 2,
        version: 1,
        occurredAt: DateTime.utc(2026, 4, 7, 8, 1),
        action: const DispatchAction(
          dispatchId: 'DSP-1',
          status: ActionStatus.decided,
        ),
      ): 'dispatch_decided_event',
      ExecutionCompleted(
        eventId: 'EXEC-1',
        sequence: 3,
        version: 1,
        occurredAt: DateTime.utc(2026, 4, 7, 8, 2),
        dispatchId: 'DSP-1',
        clientId: 'CLIENT-1',
        regionId: 'REGION-1',
        siteId: 'SITE-1',
        success: true,
      ): 'execution_completed',
      ExecutionCompletedEvent(
        eventId: 'EXEC-EVT-1',
        sequence: 4,
        version: 1,
        occurredAt: DateTime.utc(2026, 4, 7, 8, 3),
        dispatchId: 'DSP-1',
        outcome: ExecutionOutcome.success,
      ): 'execution_completed_event',
      ExecutionDenied(
        eventId: 'DENY-1',
        sequence: 5,
        version: 1,
        occurredAt: DateTime.utc(2026, 4, 7, 8, 4),
        dispatchId: 'DSP-1',
        clientId: 'CLIENT-1',
        regionId: 'REGION-1',
        siteId: 'SITE-1',
        operatorId: 'OP-1',
        reason: 'alarm',
      ): 'execution_denied',
      GuardCheckedIn(
        eventId: 'CHECK-1',
        sequence: 6,
        version: 1,
        occurredAt: DateTime.utc(2026, 4, 7, 8, 5),
        guardId: 'GUARD-1',
        clientId: 'CLIENT-1',
        regionId: 'REGION-1',
        siteId: 'SITE-1',
      ): 'guard_checked_in',
      IncidentClosed(
        eventId: 'CLOSE-1',
        sequence: 7,
        version: 1,
        occurredAt: DateTime.utc(2026, 4, 7, 8, 6),
        dispatchId: 'DSP-1',
        resolutionType: 'all_clear',
        clientId: 'CLIENT-1',
        regionId: 'REGION-1',
        siteId: 'SITE-1',
      ): 'incident_closed',
      IntelligenceReceived(
        eventId: 'INT-1',
        sequence: 8,
        version: 1,
        occurredAt: DateTime.utc(2026, 4, 7, 8, 7),
        intelligenceId: 'INTEL-1',
        provider: 'hikvision',
        sourceType: 'dvr',
        externalId: 'evt-1',
        clientId: 'CLIENT-1',
        regionId: 'REGION-1',
        siteId: 'SITE-1',
        headline: 'Vehicle detected',
        summary: 'Vehicle entered the site.',
        riskScore: 42,
        canonicalHash: 'canon-1',
      ): 'intelligence_received',
      ListenerAlarmAdvisoryRecorded(
        eventId: 'ALARM-ADV-1',
        sequence: 9,
        version: 1,
        occurredAt: DateTime.utc(2026, 4, 7, 8, 8),
        clientId: 'CLIENT-1',
        regionId: 'REGION-1',
        siteId: 'SITE-1',
        externalAlarmId: 'EXT-1',
        accountNumber: 'ACC-1',
        partition: '1',
        zone: '2',
        zoneLabel: 'Front gate',
        eventLabel: 'BURGLARY',
        dispositionLabel: 'pending',
        summary: 'Alarm pending verification.',
        recommendation: 'Call site.',
        deliveredCount: 1,
        failedCount: 0,
      ): 'listener_alarm_advisory_recorded',
      ListenerAlarmFeedCycleRecorded(
        eventId: 'ALARM-FEED-1',
        sequence: 10,
        version: 1,
        occurredAt: DateTime.utc(2026, 4, 7, 8, 9),
        sourceLabel: 'listener',
        acceptedCount: 3,
        mappedCount: 3,
        unmappedCount: 0,
        duplicateCount: 0,
        rejectedCount: 0,
        normalizationSkippedCount: 0,
        deliveredCount: 3,
        failedCount: 0,
        clearCount: 1,
        suspiciousCount: 0,
        unavailableCount: 0,
        pendingCount: 2,
        rejectSummary: '',
      ): 'listener_alarm_feed_cycle_recorded',
      ListenerAlarmParityCycleRecorded(
        eventId: 'ALARM-PARITY-1',
        sequence: 11,
        version: 1,
        occurredAt: DateTime.utc(2026, 4, 7, 8, 10),
        sourceLabel: 'serial',
        legacySourceLabel: 'legacy',
        statusLabel: 'ok',
        serialCount: 4,
        legacyCount: 4,
        matchedCount: 4,
        unmatchedSerialCount: 0,
        unmatchedLegacyCount: 0,
        maxAllowedSkewSeconds: 120,
        maxSkewSecondsObserved: 0,
        averageSkewSeconds: 0,
        driftSummary: 'aligned',
      ): 'listener_alarm_parity_cycle_recorded',
      PartnerDispatchStatusDeclared(
        eventId: 'PARTNER-1',
        sequence: 12,
        version: 1,
        occurredAt: DateTime.utc(2026, 4, 7, 8, 11),
        dispatchId: 'DSP-1',
        clientId: 'CLIENT-1',
        regionId: 'REGION-1',
        siteId: 'SITE-1',
        partnerLabel: 'Armed Response',
        actorLabel: 'Dispatcher',
        status: PartnerDispatchStatus.accepted,
        sourceChannel: 'radio',
        sourceMessageKey: 'msg-1',
      ): 'partner_dispatch_status_declared',
      PatrolCompleted(
        eventId: 'PATROL-1',
        sequence: 13,
        version: 1,
        occurredAt: DateTime.utc(2026, 4, 7, 8, 12),
        guardId: 'GUARD-1',
        routeId: 'ROUTE-1',
        clientId: 'CLIENT-1',
        regionId: 'REGION-1',
        siteId: 'SITE-1',
        durationSeconds: 600,
      ): 'patrol_completed',
      ReportGenerated(
        eventId: 'REPORT-1',
        sequence: 14,
        version: 1,
        occurredAt: DateTime.utc(2026, 4, 7, 8, 13),
        clientId: 'CLIENT-1',
        siteId: 'SITE-1',
        month: '2026-04',
        contentHash: 'content-hash',
        pdfHash: 'pdf-hash',
        eventRangeStart: 1,
        eventRangeEnd: 10,
        eventCount: 10,
        reportSchemaVersion: 1,
        projectionVersion: 1,
      ): 'report_generated',
      ResponseArrived(
        eventId: 'RESP-1',
        sequence: 15,
        version: 1,
        occurredAt: DateTime.utc(2026, 4, 7, 8, 14),
        dispatchId: 'DSP-1',
        guardId: 'GUARD-1',
        clientId: 'CLIENT-1',
        regionId: 'REGION-1',
        siteId: 'SITE-1',
      ): 'response_arrived',
      VehicleVisitReviewRecorded(
        eventId: 'VISIT-1',
        sequence: 16,
        version: 1,
        occurredAt: DateTime.utc(2026, 4, 7, 8, 15),
        vehicleVisitKey: 'visit-1',
        primaryEventId: 'EVT-1',
        clientId: 'CLIENT-1',
        regionId: 'REGION-1',
        siteId: 'SITE-1',
        vehicleLabel: 'CA123456',
        actorLabel: 'Operator',
        reviewed: true,
        statusOverride: 'COMPLETED',
        effectiveStatusLabel: 'COMPLETED',
        reasonLabel: 'Short completed visit',
        workflowSummary: 'ENTRY -> EXIT (COMPLETED)',
        sourceSurface: 'governance',
      ): 'vehicle_visit_review_recorded',
    };

    for (final entry in eventTypeKeys.entries) {
      final event = entry.key;
      final expectedKey = entry.value;
      switch (event) {
        case DecisionCreated():
          expect(event.toAuditTypeKey(), expectedKey);
        case DispatchDecidedEvent():
          expect(event.toAuditTypeKey(), expectedKey);
        case ExecutionCompleted():
          expect(event.toAuditTypeKey(), expectedKey);
        case ExecutionCompletedEvent():
          expect(event.toAuditTypeKey(), expectedKey);
        case ExecutionDenied():
          expect(event.toAuditTypeKey(), expectedKey);
        case GuardCheckedIn():
          expect(event.toAuditTypeKey(), expectedKey);
        case IncidentClosed():
          expect(event.toAuditTypeKey(), expectedKey);
        case IntelligenceReceived():
          expect(event.toAuditTypeKey(), expectedKey);
        case ListenerAlarmAdvisoryRecorded():
          expect(event.toAuditTypeKey(), expectedKey);
        case ListenerAlarmFeedCycleRecorded():
          expect(event.toAuditTypeKey(), expectedKey);
        case ListenerAlarmParityCycleRecorded():
          expect(event.toAuditTypeKey(), expectedKey);
        case PartnerDispatchStatusDeclared():
          expect(event.toAuditTypeKey(), expectedKey);
        case PatrolCompleted():
          expect(event.toAuditTypeKey(), expectedKey);
        case ReportGenerated():
          expect(event.toAuditTypeKey(), expectedKey);
        case ResponseArrived():
          expect(event.toAuditTypeKey(), expectedKey);
        case VehicleVisitReviewRecorded():
          expect(event.toAuditTypeKey(), expectedKey);
        default:
          fail('Unhandled event type: $event');
      }
    }
  });
}
