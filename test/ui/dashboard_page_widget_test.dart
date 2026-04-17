import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/morning_sovereign_report_service.dart';
import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/execution_completed.dart';
import 'package:omnix_dashboard/domain/events/execution_denied.dart';
import 'package:omnix_dashboard/domain/events/guard_checked_in.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/domain/events/partner_dispatch_status_declared.dart';
import 'package:omnix_dashboard/domain/events/patrol_completed.dart';
import 'package:omnix_dashboard/domain/guard/guard_ops_event.dart';
import 'package:omnix_dashboard/domain/store/in_memory_event_store.dart';
import 'package:omnix_dashboard/ui/dashboard_page.dart';

DateTime _dashboardTriageOccurredAtUtc(int minute) =>
    DateTime.utc(2026, 3, 6, 12, minute);

DateTime _dashboardActivityOccurredAtUtc(int hour, int minute) =>
    DateTime.utc(2026, 3, 9, hour, minute);

DateTime _dashboardMorningReportGeneratedAtUtc(int day) =>
    DateTime.utc(2026, 3, day, 6, 0);

DateTime _dashboardNightShiftStartedAtUtc(int day) =>
    DateTime.utc(2026, 3, day, 22, 0);

DateTime _dashboardPartnerProgressionOccurredAtUtc(int minute) =>
    DateTime.utc(2026, 3, 9, 23, minute);

DateTime _dashboardWorkspaceOccurredAtUtc(int minute) =>
    DateTime.utc(2026, 3, 10, 10, minute);

DateTime _dashboardNowUtc() => DateTime.now().toUtc();

void main() {
  void expectTextButtonDisabled(WidgetTester tester, String label) {
    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, label),
    );
    expect(button.onPressed, isNull, reason: '$label should be disabled');
  }

  void expectTextButtonEnabled(WidgetTester tester, String label) {
    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, label),
    );
    expect(button.onPressed, isNotNull, reason: '$label should be enabled');
  }

  void expectRailMetric(String label, String value) {
    final row = find.ancestor(of: find.text(label), matching: find.byType(Row));
    expect(
      find.descendant(of: row.first, matching: find.text(value)),
      findsOneWidget,
    );
  }

  testWidgets('dashboard stays stable on phone viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(home: DashboardPage(eventStore: InMemoryEventStore())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Command Dashboard'), findsOneWidget);
    expect(find.text('KPI Band'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard stays stable on landscape phone viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(home: DashboardPage(eventStore: InMemoryEventStore())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Command Dashboard'), findsOneWidget);
    expect(find.text('KPI Band'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard guard sync card shows alert badges and opens guard sync', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final nowUtc = _dashboardNowUtc();
    final store = InMemoryEventStore();
    store.append(
      IntelligenceReceived(
        eventId: 'evt-activity-1',
        sequence: 1,
        version: 1,
        occurredAt: _dashboardActivityOccurredAtUtc(0, 10),
        intelligenceId: 'intel-activity-1',
        provider: 'hikvision_dvr_monitor_only',
        sourceType: 'dvr',
        externalId: 'ext-activity-1',
        clientId: 'CLIENT-1',
        regionId: 'REGION-1',
        siteId: 'SITE-1',
        cameraId: 'gate-cam',
        objectLabel: 'vehicle',
        objectConfidence: 0.92,
        plateNumber: 'CA111111',
        headline: 'Known visitor vehicle entered',
        summary: 'Known visitor vehicle entered the gate lane.',
        riskScore: 58,
        snapshotUrl: 'https://edge.example.com/vehicle.jpg',
        canonicalHash: 'hash-activity-1',
      ),
    );
    store.append(
      IntelligenceReceived(
        eventId: 'evt-activity-2',
        sequence: 1,
        version: 1,
        occurredAt: _dashboardActivityOccurredAtUtc(2, 40),
        intelligenceId: 'intel-activity-2',
        provider: 'hikvision_dvr_monitor_only',
        sourceType: 'dvr',
        externalId: 'ext-activity-2',
        clientId: 'CLIENT-1',
        regionId: 'REGION-1',
        siteId: 'SITE-1',
        cameraId: 'gate-cam',
        objectLabel: 'human',
        objectConfidence: 0.87,
        headline: 'Guard conversation observed',
        summary: 'Guard talking to unknown individual near the gate.',
        riskScore: 66,
        snapshotUrl: 'https://edge.example.com/person.jpg',
        canonicalHash: 'hash-activity-2',
      ),
    );

    var openCount = 0;
    var clearPolicyCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          eventStore: store,
          guardSyncBackendEnabled: false,
          guardSyncInFlight: false,
          guardSyncQueueDepth: 60,
          guardPendingEvents: 5,
          guardPendingMedia: 2,
          guardFailedEvents: 3,
          guardFailedMedia: 1,
          guardOutcomePolicyDeniedCount: 4,
          guardOutcomePolicyDeniedLastReason:
              'Confirmation role "control" is not allowed for true_threat.',
          guardOutcomePolicyDenied24h: 3,
          guardOutcomePolicyDenied7d: 6,
          guardOutcomePolicyDeniedHistoryUtc: [
            nowUtc.subtract(const Duration(hours: 2)),
            nowUtc.subtract(const Duration(days: 2)),
          ],
          guardCoachingAckCount: 5,
          guardCoachingSnoozeCount: 2,
          guardCoachingSnoozeExpiryCount: 1,
          guardCoachingRecentHistory: const [
            '[2026-03-05T12:10:00.000Z] high_failure_backlog acknowledged @ sync by guard',
            '[2026-03-05T12:20:00.000Z] high_failure_backlog snoozed 10m @ dispatch by supervisor',
          ],
          guardLastSuccessfulSyncAtUtc: nowUtc.subtract(
            const Duration(minutes: 20),
          ),
          guardLastFailureReason: 'network unavailable',
          guardRecentEvents: [
            GuardOpsEvent(
              eventId: 'EVT-1',
              guardId: 'GUARD-001',
              siteId: 'SITE-SANDTON',
              shiftId: 'SHIFT-1',
              eventType: GuardOpsEventType.panicTriggered,
              sequence: 44,
              occurredAt: nowUtc,
              deviceId: 'DEVICE-1',
              appVersion: '1.0.0',
              payload: const {},
              failureReason: 'event sync timeout',
            ),
          ],
          guardRecentMedia: [
            GuardOpsMediaUpload(
              mediaId: 'MEDIA-1',
              eventId: 'EVT-1',
              guardId: 'GUARD-001',
              siteId: 'SITE-SANDTON',
              shiftId: 'SHIFT-1',
              bucket: 'guard-incident-media',
              path: 'guards/GUARD-001/incident/evidence.jpg',
              localPath: '/tmp/evidence.jpg',
              capturedAt: nowUtc,
              status: GuardMediaUploadStatus.failed,
              failureReason: 'upload timeout',
            ),
          ],
          morningSovereignReport: SovereignReport(
            date: '2026-03-09',
            generatedAtUtc: _dashboardMorningReportGeneratedAtUtc(9),
            shiftWindowStartUtc: _dashboardNightShiftStartedAtUtc(8),
            shiftWindowEndUtc: _dashboardMorningReportGeneratedAtUtc(9),
            ledgerIntegrity: const SovereignReportLedgerIntegrity(
              totalEvents: 42,
              hashVerified: true,
              integrityScore: 100,
            ),
            aiHumanDelta: const SovereignReportAiHumanDelta(
              aiDecisions: 12,
              humanOverrides: 3,
              overrideReasons: {'HARDWARE_FAULT': 2, 'FALSE_ALARM': 1},
            ),
            normDrift: const SovereignReportNormDrift(
              sitesMonitored: 4,
              driftDetected: 1,
              avgMatchScore: 87.5,
            ),
            complianceBlockage: const SovereignReportComplianceBlockage(
              psiraExpired: 0,
              pdpExpired: 1,
              totalBlocked: 2,
            ),
            receiptPolicy: const SovereignReportReceiptPolicy(
              generatedReports: 2,
              trackedConfigurationReports: 1,
              legacyConfigurationReports: 1,
              fullyIncludedReports: 0,
              reportsWithOmittedSections: 1,
              omittedAiDecisionLogReports: 1,
              omittedGuardMetricsReports: 1,
              standardBrandingReports: 1,
              defaultPartnerBrandingReports: 0,
              customBrandingOverrideReports: 1,
              governanceHandoffReports: 1,
              routineReviewReports: 1,
              executiveSummary:
                  '1 client-facing receipt omitted sections • 1 legacy receipt lacked tracked policy',
              brandingExecutiveSummary:
                  '1 receipt used custom branding override',
              investigationExecutiveSummary:
                  '1 receipt investigation came from Governance branding drift • 1 receipt investigation remained routine review',
              headline: '1 generated reports omitted sections',
              summaryLine:
                  'Reports 2 • Tracked 1 • Legacy 1 • Full 0 • Omitted 1 • AI log omitted 1 • Guard metrics omitted 1 • Standard branding 1 • Default partner branding 0 • Custom branding 1',
              latestReportSummary:
                  'CLIENT-1/SITE-1 2026-03 omitted AI Decision Log, Guard Metrics.',
              latestBrandingSummary:
                  'CLIENT-1/SITE-1 2026-03 used standard ONYX branding.',
            ),
            vehicleThroughput: const SovereignReportVehicleThroughput(
              totalVisits: 6,
              completedVisits: 5,
              activeVisits: 1,
              incompleteVisits: 0,
              uniqueVehicles: 6,
              repeatVehicles: 0,
              unknownVehicleEvents: 0,
              peakHourLabel: '23:00-00:00',
              peakHourVisitCount: 3,
              averageCompletedDwellMinutes: 18.5,
              suspiciousShortVisitCount: 0,
              loiteringVisitCount: 0,
              workflowHeadline:
                  '5 completed visits reached EXIT • 1 active visit remains in SERVICE',
              summaryLine:
                  'Visits 6 • Entry 6 • Completed 5 • Active 1 • Incomplete 0 • Unique 6 • Avg dwell 18.5m • Peak 23:00-00:00 (3)',
            ),
            partnerProgression: SovereignReportPartnerProgression(
              dispatchCount: 2,
              declarationCount: 5,
              acceptedCount: 2,
              onSiteCount: 1,
              allClearCount: 1,
              cancelledCount: 0,
              workflowHeadline:
                  '1 partner dispatch reached ALL CLEAR • 1 partner dispatch remains ON SITE',
              performanceHeadline: '1 strong response • 1 on-track response',
              slaHeadline: 'Avg accept 5.0m • Avg on site 12.0m',
              summaryLine:
                  'Dispatches 2 • Declarations 5 • Accept 2 • On site 1 • All clear 1 • Cancelled 0',
              scopeBreakdowns: [
                SovereignReportPartnerScopeBreakdown(
                  clientId: 'CLIENT-1',
                  siteId: 'SITE-1',
                  dispatchCount: 2,
                  declarationCount: 5,
                  latestStatus: PartnerDispatchStatus.onSite,
                  latestOccurredAtUtc:
                      _dashboardPartnerProgressionOccurredAtUtc(44),
                  summaryLine:
                      'Dispatches 2 • Declarations 5 • Latest ON SITE @ 2026-03-09T23:44:00.000Z',
                ),
              ],
              dispatchChains: [
                SovereignReportPartnerDispatchChain(
                  dispatchId: 'DSP-1',
                  clientId: 'CLIENT-1',
                  siteId: 'SITE-1',
                  partnerLabel: 'Partner Alpha',
                  declarationCount: 3,
                  latestStatus: PartnerDispatchStatus.allClear,
                  latestOccurredAtUtc:
                      _dashboardPartnerProgressionOccurredAtUtc(20),
                  dispatchCreatedAtUtc:
                      _dashboardPartnerProgressionOccurredAtUtc(0),
                  acceptedAtUtc: _dashboardPartnerProgressionOccurredAtUtc(5),
                  onSiteAtUtc: _dashboardPartnerProgressionOccurredAtUtc(12),
                  allClearAtUtc: _dashboardPartnerProgressionOccurredAtUtc(20),
                  acceptedDelayMinutes: 5.0,
                  onSiteDelayMinutes: 12.0,
                  scoreLabel: 'STRONG',
                  scoreReason:
                      'Partner reached ALL CLEAR inside target acceptance and on-site windows.',
                  workflowSummary:
                      'ACCEPT -> ON SITE -> ALL CLEAR (LATEST ALL CLEAR)',
                ),
              ],
            ),
          ),
          morningSovereignReportHistory: [
            SovereignReport(
              date: '2026-03-08',
              generatedAtUtc: _dashboardMorningReportGeneratedAtUtc(8),
              shiftWindowStartUtc: _dashboardNightShiftStartedAtUtc(7),
              shiftWindowEndUtc: _dashboardMorningReportGeneratedAtUtc(8),
              ledgerIntegrity: const SovereignReportLedgerIntegrity(
                totalEvents: 38,
                hashVerified: true,
                integrityScore: 100,
              ),
              aiHumanDelta: const SovereignReportAiHumanDelta(
                aiDecisions: 10,
                humanOverrides: 2,
                overrideReasons: {'FALSE_ALARM': 2},
              ),
              normDrift: const SovereignReportNormDrift(
                sitesMonitored: 4,
                driftDetected: 0,
                avgMatchScore: 91.0,
              ),
              complianceBlockage: const SovereignReportComplianceBlockage(
                psiraExpired: 0,
                pdpExpired: 0,
                totalBlocked: 0,
              ),
              receiptPolicy: const SovereignReportReceiptPolicy(
                generatedReports: 1,
                trackedConfigurationReports: 1,
                legacyConfigurationReports: 0,
                fullyIncludedReports: 1,
                reportsWithOmittedSections: 0,
                omittedAiDecisionLogReports: 0,
                omittedGuardMetricsReports: 0,
                standardBrandingReports: 1,
                defaultPartnerBrandingReports: 0,
                customBrandingOverrideReports: 0,
                governanceHandoffReports: 0,
                routineReviewReports: 1,
                executiveSummary:
                    '1 client-facing receipt used full tracked policy',
                brandingExecutiveSummary:
                    '1 receipt used standard ONYX branding',
                headline: 'All generated reports included every section',
                summaryLine:
                    'Reports 1 • Tracked 1 • Legacy 0 • Full 1 • Omitted 0 • AI log omitted 0 • Guard metrics omitted 0 • Standard branding 1 • Default partner branding 0 • Custom branding 0',
                latestReportSummary:
                    'CLIENT-1/SITE-1 2026-03 included all configured sections.',
                latestBrandingSummary:
                    'CLIENT-1/SITE-1 2026-03 used standard ONYX branding.',
              ),
            ),
          ],
          morningSovereignReportAutoStatusLabel:
              'Auto generated for shift ending 2026-03-09. Next generation runs at 06:00 local.',
          onGenerateMorningSovereignReport: () async {},
          onOpenGuardSync: () {
            openCount += 1;
          },
          onClearGuardOutcomePolicyTelemetry: () {
            clearPolicyCount += 1;
          },
          guardFailureAlertThreshold: 1,
          guardQueuePressureAlertThreshold: 25,
          guardStaleSyncAlertMinutes: 10,
        ),
      ),
    );

    expect(find.text('Guard Sync Health'), findsOneWidget);
    expect(find.text('Failures'), findsOneWidget);
    expect(find.text('Queue Pressure'), findsOneWidget);
    expect(find.text('Stale Sync'), findsOneWidget);
    expect(find.text('Local Only'), findsOneWidget);
    expect(find.text('Policy Denied'), findsOneWidget);
    expect(
      find.text(
        '5 completed visits reached EXIT • 1 active visit remains in SERVICE',
      ),
      findsOneWidget,
    );
    expect(find.text('Receipt policy'), findsOneWidget);
    expect(
      find.text(
        '1 client-facing receipt omitted sections • 1 legacy receipt lacked tracked policy • 1 receipt used custom branding override • 1 receipt investigation came from Governance branding drift • 1 receipt investigation remained routine review',
      ),
      findsOneWidget,
    );
    expect(find.text('Receipt policy trend'), findsOneWidget);
    expect(
      find.text(
        'SLIPPING • Latest receipt fell back to legacy policy capture.',
      ),
      findsOneWidget,
    );
    expect(find.text('Receipt investigation'), findsOneWidget);
    expect(
      find.text(
        '1 receipt investigation came from Governance branding drift • 1 receipt investigation remained routine review',
      ),
      findsWidgets,
    );
    expect(find.text('Receipt investigation trend'), findsOneWidget);
    expect(
      find.text(
        'OVERSIGHT RISING • Latest receipt reviews introduced Governance handoffs above recent routine baseline.',
      ),
      findsOneWidget,
    );
    expect(find.text('Partner progression'), findsOneWidget);
    expect(
      find.text('1 strong response • 1 on-track response'),
      findsOneWidget,
    );
    expect(find.text('Diagnostics and coaching telemetry'), findsOneWidget);
    await tester.ensureVisible(find.text('Diagnostics and coaching telemetry'));
    await tester.tap(find.text('Diagnostics and coaching telemetry'));
    await tester.pumpAndSettle();
    expect(find.text('Policy denied'), findsOneWidget);
    expect(find.text('Denied (24h)'), findsOneWidget);
    expect(find.text('Denied (7d)'), findsOneWidget);
    expect(find.text('Coaching Ack'), findsOneWidget);
    expect(find.text('Coaching Snooze'), findsOneWidget);
    expect(find.text('Snooze Expiry'), findsOneWidget);
    expectRailMetric('Policy denied', '4');
    expectRailMetric('Denied (24h)', '3');
    expectRailMetric('Denied (7d)', '6');
    expectRailMetric('Coaching Ack', '5');
    expectRailMetric('Coaching Snooze', '2');
    expectRailMetric('Snooze Expiry', '1');
    expect(find.text('Recent Coaching Telemetry'), findsOneWidget);
    expect(find.textContaining('acknowledged @ sync by guard'), findsOneWidget);
    expect(find.textContaining('Policy denied (latest):'), findsOneWidget);
    expect(find.text('Advanced export and share'), findsOneWidget);
    expect(find.text('Morning Sovereign Report'), findsOneWidget);
    expect(find.text('Vehicle throughput'), findsOneWidget);
    expect(find.text('Site activity'), findsOneWidget);
    expect(
      find.text(
        'Signals 2 • Vehicles 1 • People 1 • Known IDs 1 • Unknown 1 • Guard interactions 1',
      ),
      findsOneWidget,
    );
    expect(find.text('Site activity trend'), findsOneWidget);
    expect(
      find.text(
        'ACTIVITY RISING • Unknown or flagged site activity increased against recent shifts.',
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Advanced export and share'));
    await tester.tap(find.text('Advanced export and share'));
    await tester.pumpAndSettle();
    expect(find.text('Copy Policy Telemetry JSON'), findsOneWidget);
    expect(find.text('Copy Policy Telemetry CSV'), findsOneWidget);
    expect(find.text('Download Policy JSON'), findsOneWidget);
    expect(find.text('Download Policy CSV'), findsOneWidget);
    expect(find.text('Share Policy Pack'), findsOneWidget);
    expect(find.text('Copy Coaching Telemetry JSON'), findsOneWidget);
    expect(find.text('Copy Coaching Telemetry CSV'), findsOneWidget);
    expect(find.text('Download Coaching JSON'), findsOneWidget);
    expect(find.text('Share Coaching Pack'), findsOneWidget);
    expect(find.text('Copy Site Activity JSON'), findsOneWidget);
    expect(find.text('Copy Site Activity CSV'), findsOneWidget);
    expect(find.text('Copy Site Activity Review JSON'), findsOneWidget);
    expect(find.text('Share Site Activity Pack'), findsOneWidget);
    expect(find.text('Copy Site Activity Telegram'), findsOneWidget);
    expect(find.text('Share Site Activity Telegram'), findsOneWidget);
    expect(
      find.text('Generation and delivery controls moved to Governance screen.'),
      findsOneWidget,
    );
    expect(find.text('Generate Now'), findsNothing);
    expect(find.text('Copy Morning JSON'), findsNothing);
    expect(find.text('Copy Morning CSV'), findsNothing);
    expect(find.text('Download Morning JSON'), findsNothing);
    expect(find.text('Download Morning CSV'), findsNothing);
    expect(find.text('Share Morning Pack'), findsNothing);
    expect(find.text('Email Morning Report'), findsNothing);
    expect(find.text('Recent Failure Trace'), findsOneWidget);
    expect(find.text('Events'), findsOneWidget);
    expect(find.text('Media'), findsOneWidget);
    expect(
      find.textContaining('Event panicTriggered seq 44: event sync timeout'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Media guard-incident-media: upload timeout'),
      findsOneWidget,
    );
    expect(find.text('Copy Failure Trace'), findsOneWidget);
    expect(find.text('Download Failure Trace'), findsOneWidget);
    expect(find.text('Share Failure Trace'), findsOneWidget);
    expect(find.text('Email Failure Trace'), findsOneWidget);
    expectTextButtonDisabled(tester, 'Download Failure Trace');
    expectTextButtonDisabled(tester, 'Download Policy JSON');
    expectTextButtonDisabled(tester, 'Download Policy CSV');
    expectTextButtonDisabled(tester, 'Download Coaching JSON');
    expectTextButtonEnabled(tester, 'Share Policy Pack');
    expectTextButtonEnabled(tester, 'Share Coaching Pack');
    expectTextButtonEnabled(tester, 'Share Site Activity Pack');
    expectTextButtonEnabled(tester, 'Share Site Activity Telegram');
    expectTextButtonEnabled(tester, 'Share Failure Trace');
    expectTextButtonEnabled(tester, 'Email Failure Trace');

    await tester.ensureVisible(find.text('Open Guard Sync'));
    await tester.tap(find.text('Open Guard Sync'));
    await tester.pumpAndSettle();
    expect(openCount, 1);
    await tester.ensureVisible(find.text('Clear Policy Telemetry'));
    await tester.tap(find.text('Clear Policy Telemetry'));
    await tester.pumpAndSettle();
    expect(clearPolicyCount, 1);
  });

  testWidgets('dashboard copies site activity truth json', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? copiedPayload;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          copiedPayload = args['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final store = InMemoryEventStore();
    store.append(
      IntelligenceReceived(
        eventId: 'evt-activity-copy-1',
        sequence: 1,
        version: 1,
        occurredAt: _dashboardActivityOccurredAtUtc(0, 10),
        intelligenceId: 'intel-activity-copy-1',
        provider: 'hikvision_dvr_monitor_only',
        sourceType: 'dvr',
        externalId: 'ext-activity-copy-1',
        clientId: 'CLIENT-1',
        regionId: 'REGION-1',
        siteId: 'SITE-1',
        cameraId: 'gate-cam',
        objectLabel: 'vehicle',
        objectConfidence: 0.92,
        plateNumber: 'CA111111',
        headline: 'Known visitor vehicle entered',
        summary: 'Known visitor vehicle entered the gate lane.',
        riskScore: 58,
        snapshotUrl: 'https://edge.example.com/vehicle.jpg',
        canonicalHash: 'hash-activity-copy-1',
      ),
    );
    store.append(
      IntelligenceReceived(
        eventId: 'evt-activity-copy-2',
        sequence: 1,
        version: 1,
        occurredAt: _dashboardActivityOccurredAtUtc(2, 40),
        intelligenceId: 'intel-activity-copy-2',
        provider: 'hikvision_dvr_monitor_only',
        sourceType: 'dvr',
        externalId: 'ext-activity-copy-2',
        clientId: 'CLIENT-1',
        regionId: 'REGION-1',
        siteId: 'SITE-1',
        cameraId: 'gate-cam',
        objectLabel: 'human',
        objectConfidence: 0.87,
        headline: 'Guard conversation observed',
        summary: 'Guard talking to unknown individual near the gate.',
        riskScore: 66,
        snapshotUrl: 'https://edge.example.com/person.jpg',
        canonicalHash: 'hash-activity-copy-2',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          eventStore: store,
          morningSovereignReport: SovereignReport(
            date: '2026-03-09',
            generatedAtUtc: _dashboardMorningReportGeneratedAtUtc(9),
            shiftWindowStartUtc: _dashboardNightShiftStartedAtUtc(8),
            shiftWindowEndUtc: _dashboardMorningReportGeneratedAtUtc(9),
            ledgerIntegrity: const SovereignReportLedgerIntegrity(
              totalEvents: 42,
              hashVerified: true,
              integrityScore: 100,
            ),
            aiHumanDelta: const SovereignReportAiHumanDelta(
              aiDecisions: 12,
              humanOverrides: 3,
              overrideReasons: {'HARDWARE_FAULT': 2, 'FALSE_ALARM': 1},
            ),
            normDrift: const SovereignReportNormDrift(
              sitesMonitored: 4,
              driftDetected: 1,
              avgMatchScore: 87.5,
            ),
            complianceBlockage: const SovereignReportComplianceBlockage(
              psiraExpired: 0,
              pdpExpired: 1,
              totalBlocked: 2,
            ),
          ),
          morningSovereignReportHistory: [
            SovereignReport(
              date: '2026-03-08',
              generatedAtUtc: _dashboardMorningReportGeneratedAtUtc(8),
              shiftWindowStartUtc: _dashboardNightShiftStartedAtUtc(7),
              shiftWindowEndUtc: _dashboardMorningReportGeneratedAtUtc(8),
              ledgerIntegrity: const SovereignReportLedgerIntegrity(
                totalEvents: 38,
                hashVerified: true,
                integrityScore: 100,
              ),
              aiHumanDelta: const SovereignReportAiHumanDelta(
                aiDecisions: 10,
                humanOverrides: 2,
                overrideReasons: {'FALSE_ALARM': 2},
              ),
              normDrift: const SovereignReportNormDrift(
                sitesMonitored: 4,
                driftDetected: 0,
                avgMatchScore: 91.0,
              ),
              complianceBlockage: const SovereignReportComplianceBlockage(
                psiraExpired: 0,
                pdpExpired: 0,
                totalBlocked: 0,
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Advanced export and share'));
    await tester.tap(find.text('Advanced export and share'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('dashboard-advanced-export-receipt')),
      findsOneWidget,
    );
    expect(find.text('Export relay ready'), findsOneWidget);

    await tester.tap(find.text('Copy Site Activity JSON'));
    await tester.pump();

    expect(copiedPayload, isNotNull);
    expect(copiedPayload, contains('"siteActivity"'));
    expect(copiedPayload, contains('"totalSignals": 2'));
    expect(copiedPayload, contains('"vehicleSignals": 1'));
    expect(copiedPayload, contains('"personSignals": 1'));
    expect(copiedPayload, contains('"knownIdentitySignals": 1'));
    expect(copiedPayload, contains('"trend"'));
    expect(copiedPayload, contains('"label": "ACTIVITY RISING"'));
    expect(copiedPayload, contains('"reviewShortcuts"'));
    expect(
      copiedPayload,
      contains(
        '"currentShiftReviewCommand": "/activityreview CLIENT-1 SITE-1 2026-03-09"',
      ),
    );
    expect(
      copiedPayload,
      contains(
        '"currentShiftCaseFileCommand": "/activitycase json CLIENT-1 SITE-1 2026-03-09"',
      ),
    );
    expect(find.text('Site activity JSON copied'), findsOneWidget);

    await tester.tap(find.text('Copy Site Activity CSV'));
    await tester.pump();

    expect(
      copiedPayload,
      contains(
        'current_review_command,/activityreview CLIENT-1 SITE-1 2026-03-09',
      ),
    );
    expect(
      copiedPayload,
      contains(
        'current_case_file_command,/activitycase json CLIENT-1 SITE-1 2026-03-09',
      ),
    );
    expect(find.text('Site activity CSV copied'), findsOneWidget);
  });

  testWidgets(
    'dashboard stages site activity pack when share bridge is unavailable',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? copiedPayload;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<dynamic, dynamic>;
            copiedPayload = args['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final store = InMemoryEventStore();
      store.append(
        IntelligenceReceived(
          eventId: 'evt-activity-share-1',
          sequence: 1,
          version: 1,
          occurredAt: _dashboardActivityOccurredAtUtc(0, 10),
          intelligenceId: 'intel-activity-share-1',
          provider: 'hikvision_dvr_monitor_only',
          sourceType: 'dvr',
          externalId: 'ext-activity-share-1',
          clientId: 'CLIENT-1',
          regionId: 'REGION-1',
          siteId: 'SITE-1',
          cameraId: 'gate-cam',
          objectLabel: 'vehicle',
          objectConfidence: 0.92,
          plateNumber: 'CA111111',
          headline: 'Known visitor vehicle entered',
          summary: 'Known visitor vehicle entered the gate lane.',
          riskScore: 58,
          snapshotUrl: 'https://edge.example.com/vehicle.jpg',
          canonicalHash: 'hash-activity-share-1',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: DashboardPage(eventStore: store)),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Advanced export and share'));
      await tester.tap(find.text('Advanced export and share'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Share Site Activity Pack'));
      await tester.pump();

      expect(copiedPayload, isNotNull);
      expect(copiedPayload, startsWith('ONYX Site Activity Truth'));
      expect(copiedPayload, contains('"siteActivity"'));
      expect(find.text('Site activity pack staged'), findsOneWidget);
      expect(find.textContaining('copied for manual handoff'), findsOneWidget);
    },
  );

  testWidgets('dashboard copies site activity telegram summary', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? copiedPayload;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          copiedPayload = args['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final store = InMemoryEventStore();
    store.append(
      IntelligenceReceived(
        eventId: 'evt-activity-telegram-1',
        sequence: 1,
        version: 1,
        occurredAt: _dashboardActivityOccurredAtUtc(0, 10),
        intelligenceId: 'intel-activity-telegram-1',
        provider: 'hikvision_dvr_monitor_only',
        sourceType: 'dvr',
        externalId: 'ext-activity-telegram-1',
        clientId: 'CLIENT-1',
        regionId: 'REGION-1',
        siteId: 'SITE-1',
        cameraId: 'gate-cam',
        objectLabel: 'vehicle',
        objectConfidence: 0.92,
        plateNumber: 'CA111111',
        headline: 'Known visitor vehicle entered',
        summary: 'Known visitor vehicle entered the gate lane.',
        riskScore: 58,
        snapshotUrl: 'https://edge.example.com/vehicle.jpg',
        canonicalHash: 'hash-activity-telegram-1',
      ),
    );
    store.append(
      IntelligenceReceived(
        eventId: 'evt-activity-telegram-2',
        sequence: 1,
        version: 1,
        occurredAt: _dashboardActivityOccurredAtUtc(2, 40),
        intelligenceId: 'intel-activity-telegram-2',
        provider: 'hikvision_dvr_monitor_only',
        sourceType: 'dvr',
        externalId: 'ext-activity-telegram-2',
        clientId: 'CLIENT-1',
        regionId: 'REGION-1',
        siteId: 'SITE-1',
        cameraId: 'gate-cam',
        objectLabel: 'human',
        objectConfidence: 0.87,
        headline: 'Guard conversation observed',
        summary: 'Guard talking to unknown individual near the gate.',
        riskScore: 66,
        snapshotUrl: 'https://edge.example.com/person.jpg',
        canonicalHash: 'hash-activity-telegram-2',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          eventStore: store,
          morningSovereignReport: SovereignReport(
            date: '2026-03-09',
            generatedAtUtc: _dashboardMorningReportGeneratedAtUtc(9),
            shiftWindowStartUtc: _dashboardNightShiftStartedAtUtc(8),
            shiftWindowEndUtc: _dashboardMorningReportGeneratedAtUtc(9),
            ledgerIntegrity: const SovereignReportLedgerIntegrity(
              totalEvents: 42,
              hashVerified: true,
              integrityScore: 100,
            ),
            aiHumanDelta: const SovereignReportAiHumanDelta(
              aiDecisions: 12,
              humanOverrides: 3,
              overrideReasons: {'HARDWARE_FAULT': 2, 'FALSE_ALARM': 1},
            ),
            normDrift: const SovereignReportNormDrift(
              sitesMonitored: 4,
              driftDetected: 1,
              avgMatchScore: 87.5,
            ),
            complianceBlockage: const SovereignReportComplianceBlockage(
              psiraExpired: 0,
              pdpExpired: 1,
              totalBlocked: 2,
            ),
          ),
          morningSovereignReportHistory: [
            SovereignReport(
              date: '2026-03-08',
              generatedAtUtc: _dashboardMorningReportGeneratedAtUtc(8),
              shiftWindowStartUtc: _dashboardNightShiftStartedAtUtc(7),
              shiftWindowEndUtc: _dashboardMorningReportGeneratedAtUtc(8),
              ledgerIntegrity: const SovereignReportLedgerIntegrity(
                totalEvents: 38,
                hashVerified: true,
                integrityScore: 100,
              ),
              aiHumanDelta: const SovereignReportAiHumanDelta(
                aiDecisions: 10,
                humanOverrides: 2,
                overrideReasons: {'FALSE_ALARM': 2},
              ),
              normDrift: const SovereignReportNormDrift(
                sitesMonitored: 4,
                driftDetected: 0,
                avgMatchScore: 91.0,
              ),
              complianceBlockage: const SovereignReportComplianceBlockage(
                psiraExpired: 0,
                pdpExpired: 0,
                totalBlocked: 0,
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Advanced export and share'));
    await tester.tap(find.text('Advanced export and share'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Copy Site Activity Telegram'));
    await tester.pump();

    expect(copiedPayload, isNotNull);
    expect(copiedPayload, contains('Site activity summary: Dashboard scope'));
    expect(copiedPayload, contains('Window: 2026-03-09'));
    expect(copiedPayload, contains('Signals seen: 2.'));
    expect(copiedPayload, contains('Seen: 1 vehicles • 1 people'));
    expect(copiedPayload, contains('Identity mix: 1 known IDs • 1 unknown'));
    expect(copiedPayload, contains('Patterns: 1 guard interactions'));
    expect(copiedPayload, contains('Trend: ACTIVITY RISING -'));
  });

  testWidgets('dashboard opens and copies site activity review handoff', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? copiedPayload;
    List<String>? openedEventIds;
    String? openedSelectedEventId;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          copiedPayload = args['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final store = InMemoryEventStore();
    store.append(
      IntelligenceReceived(
        eventId: 'ACTIVITY-7',
        sequence: 1,
        version: 1,
        occurredAt: _dashboardActivityOccurredAtUtc(0, 10),
        intelligenceId: 'INT-ACTIVITY-7',
        provider: 'hikvision_dvr_monitor_only',
        sourceType: 'dvr',
        externalId: 'ext-activity-review-1',
        clientId: 'CLIENT-1',
        regionId: 'REGION-1',
        siteId: 'SITE-1',
        cameraId: 'gate-cam',
        objectLabel: 'human',
        objectConfidence: 0.91,
        headline: 'Watchlist person observed',
        summary: 'Watchlist person lingered at the gate.',
        riskScore: 78,
        snapshotUrl: 'https://edge.example.com/review-1.jpg',
        canonicalHash: 'hash-activity-review-1',
      ),
    );
    store.append(
      IntelligenceReceived(
        eventId: 'ACTIVITY-11',
        sequence: 1,
        version: 1,
        occurredAt: _dashboardActivityOccurredAtUtc(3, 10),
        intelligenceId: 'INT-ACTIVITY-11',
        provider: 'hikvision_dvr_monitor_only',
        sourceType: 'dvr',
        externalId: 'ext-activity-review-2',
        clientId: 'CLIENT-1',
        regionId: 'REGION-1',
        siteId: 'SITE-1',
        cameraId: 'gate-cam',
        objectLabel: 'human',
        objectConfidence: 0.86,
        headline: 'Guard conversation observed',
        summary: 'Guard interaction with an unknown person near the gate.',
        riskScore: 66,
        snapshotUrl: 'https://edge.example.com/review-2.jpg',
        canonicalHash: 'hash-activity-review-2',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          eventStore: store,
          onOpenEventsForScope: (eventIds, selectedEventId, {originLabel = ''}) {
            openedEventIds = eventIds;
            openedSelectedEventId = selectedEventId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Advanced export and share'));
    await tester.tap(find.text('Advanced export and share'));
    await tester.pumpAndSettle();

    expect(find.text('Copy Site Activity Review JSON'), findsOneWidget);
    expect(find.text('Open Site Activity Events Review'), findsOneWidget);
    expect(find.text('Export relay ready'), findsOneWidget);

    await tester.tap(find.text('Copy Site Activity Review JSON'));
    await tester.pump();

    expect(copiedPayload, isNotNull);
    expect(copiedPayload, contains('"siteActivityReview"'));
    expect(copiedPayload, contains('"eventIds": ['));
    expect(copiedPayload, contains('"ACTIVITY-7"'));
    expect(copiedPayload, contains('"ACTIVITY-11"'));
    expect(copiedPayload, contains('"selectedEventId": "ACTIVITY-11"'));
    expect(copiedPayload, contains('"evidenceEventIds": ['));
    expect(find.text('Review JSON copied'), findsOneWidget);

    await tester.tap(find.text('Open Site Activity Events Review'));
    await tester.pumpAndSettle();

    expect(openedEventIds, equals(const ['ACTIVITY-7', 'ACTIVITY-11']));
    expect(openedSelectedEventId, 'ACTIVITY-11');
    expect(find.text('Events review opened'), findsOneWidget);
  });

  testWidgets(
    'dashboard stages failure trace mail when mail bridge is unavailable',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? copiedPayload;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<dynamic, dynamic>;
            copiedPayload = args['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardPage(
            eventStore: InMemoryEventStore(),
            guardLastFailureReason: 'event sync timeout',
            guardFailedEvents: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Advanced export and share'));
      await tester.tap(find.text('Advanced export and share'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Email Failure Trace'));
      await tester.tap(find.text('Email Failure Trace'));
      await tester.pump();

      expect(copiedPayload, isNotNull);
      expect(
        copiedPayload,
        startsWith('Subject: ONYX Guard Sync Failure Trace'),
      );
      expect(copiedPayload, contains('event sync timeout'));
      expect(find.text('Failure trace mail staged'), findsOneWidget);
      expect(
        find.textContaining('mail-ready failure trace draft was copied'),
        findsOneWidget,
      );
    },
  );

  testWidgets('dashboard workspace switches modes and filters lanes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = InMemoryEventStore();
    store.append(
      IntelligenceReceived(
        eventId: 'SIG-INT-1',
        sequence: 1,
        version: 1,
        occurredAt: _dashboardWorkspaceOccurredAtUtc(0),
        intelligenceId: 'INT-WS-1',
        provider: 'newsapi.org',
        sourceType: 'news',
        externalId: 'signal-1',
        clientId: 'CLIENT-RISK',
        regionId: 'REGION-1',
        siteId: 'SITE-RISK',
        headline: 'Escalating perimeter chatter',
        summary: 'High-risk perimeter activity detected.',
        riskScore: 84,
        canonicalHash: 'hash-signal-1',
      ),
    );
    store.append(
      GuardCheckedIn(
        eventId: 'SIG-FIELD-1',
        sequence: 2,
        version: 1,
        occurredAt: _dashboardWorkspaceOccurredAtUtc(5),
        guardId: 'GUARD-1',
        clientId: 'CLIENT-STRONG',
        regionId: 'REGION-1',
        siteId: 'SITE-STRONG',
      ),
    );
    store.append(
      PatrolCompleted(
        eventId: 'SIG-PATROL-1',
        sequence: 3,
        version: 1,
        occurredAt: _dashboardWorkspaceOccurredAtUtc(8),
        guardId: 'GUARD-1',
        routeId: 'R-1',
        clientId: 'CLIENT-STRONG',
        regionId: 'REGION-1',
        siteId: 'SITE-STRONG',
        durationSeconds: 600,
      ),
    );
    store.append(
      DecisionCreated(
        eventId: 'DSP-RISK-1',
        sequence: 4,
        version: 1,
        occurredAt: _dashboardWorkspaceOccurredAtUtc(10),
        dispatchId: 'DSP-RISK',
        clientId: 'CLIENT-RISK',
        regionId: 'REGION-1',
        siteId: 'SITE-RISK',
      ),
    );
    store.append(
      ExecutionDenied(
        eventId: 'DSP-RISK-2',
        sequence: 5,
        version: 1,
        occurredAt: _dashboardWorkspaceOccurredAtUtc(14),
        dispatchId: 'DSP-RISK',
        clientId: 'CLIENT-RISK',
        regionId: 'REGION-1',
        siteId: 'SITE-RISK',
        operatorId: 'OP-1',
        reason: 'Awaiting secondary confirmation',
      ),
    );
    store.append(
      DecisionCreated(
        eventId: 'DSP-SAFE-1',
        sequence: 6,
        version: 1,
        occurredAt: _dashboardWorkspaceOccurredAtUtc(16),
        dispatchId: 'DSP-SAFE',
        clientId: 'CLIENT-STRONG',
        regionId: 'REGION-1',
        siteId: 'SITE-STRONG',
      ),
    );
    store.append(
      ExecutionCompleted(
        eventId: 'DSP-SAFE-2',
        sequence: 7,
        version: 1,
        occurredAt: _dashboardWorkspaceOccurredAtUtc(20),
        dispatchId: 'DSP-SAFE',
        clientId: 'CLIENT-STRONG',
        regionId: 'REGION-1',
        siteId: 'SITE-STRONG',
        success: true,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: DashboardPage(eventStore: store)),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('dashboard-workspace-status-banner')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dashboard-workspace-panel-signals')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('dashboard-workspace-mode-dispatch')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('dashboard-dispatch-filter-risk')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('dashboard-workspace-panel-dispatch')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dashboard-dispatch-card-DSP-RISK')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dashboard-dispatch-card-DSP-SAFE')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('dashboard-workspace-mode-sites')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('dashboard-site-filter-watch')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('dashboard-site-card-SITE-RISK')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dashboard-site-card-SITE-STRONG')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('dashboard-workspace-mode-signals')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('dashboard-signal-filter-intel')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('dashboard-workspace-panel-signals')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dashboard-signal-filter-intel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dashboard-site-filter-watch')),
      findsNothing,
    );
  });

  testWidgets('dashboard guard sync card respects alert thresholds', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          eventStore: InMemoryEventStore(),
          guardSyncBackendEnabled: true,
          guardSyncInFlight: false,
          guardSyncQueueDepth: 24,
          guardPendingEvents: 1,
          guardPendingMedia: 0,
          guardFailedEvents: 1,
          guardFailedMedia: 0,
          guardLastSuccessfulSyncAtUtc: _dashboardNowUtc().subtract(
            const Duration(minutes: 9),
          ),
          guardFailureAlertThreshold: 2,
          guardQueuePressureAlertThreshold: 25,
          guardStaleSyncAlertMinutes: 10,
        ),
      ),
    );

    expect(find.text('Guard Sync Health'), findsOneWidget);
    expect(find.text('Failures'), findsNothing);
    expect(find.text('Queue Pressure'), findsNothing);
    expect(find.text('Stale Sync'), findsNothing);
    expect(find.text('Local Only'), findsNothing);
  });

  testWidgets('dashboard shows triage posture summary', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = InMemoryEventStore();
    store.append(
      IntelligenceReceived(
        eventId: 'E-INT-1',
        sequence: 0,
        version: 1,
        occurredAt: _dashboardTriageOccurredAtUtc(0),
        intelligenceId: 'INT-1',
        provider: 'newsapi.org',
        sourceType: 'news',
        externalId: 'article-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'Armed suspects near gate B',
        summary: 'Vehicle and suspect activity near perimeter gate',
        riskScore: 84,
        canonicalHash: 'hash-1',
      ),
    );
    store.append(
      IntelligenceReceived(
        eventId: 'E-INT-2',
        sequence: 0,
        version: 1,
        occurredAt: _dashboardTriageOccurredAtUtc(2),
        intelligenceId: 'INT-2',
        provider: 'community-feed',
        sourceType: 'community',
        externalId: 'community-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'Community confirms suspects near gate B',
        summary: 'Repeat suspicious vehicle and armed suspects at perimeter',
        riskScore: 72,
        canonicalHash: 'hash-2',
      ),
    );
    store.append(
      DecisionCreated(
        eventId: 'DEC-1',
        sequence: 0,
        version: 1,
        occurredAt: _dashboardTriageOccurredAtUtc(5),
        dispatchId: 'DSP-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: DashboardPage(eventStore: store)),
    );

    expect(
      find.text('Triage posture: A 0 • W 1 • DC 1 • Esc 1'),
      findsOneWidget,
    );
    expect(find.textContaining('Top triage signals:'), findsOneWidget);
  });
}
