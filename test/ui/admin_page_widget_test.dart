import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/morning_sovereign_report_service.dart';
import 'package:omnix_dashboard/application/monitoring_identity_policy_service.dart';
import 'package:omnix_dashboard/application/monitoring_scene_review_store.dart';
import 'package:omnix_dashboard/application/site_identity_registry_repository.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/listener_alarm_advisory_recorded.dart';
import 'package:omnix_dashboard/domain/events/listener_alarm_feed_cycle_recorded.dart';
import 'package:omnix_dashboard/domain/events/listener_alarm_parity_cycle_recorded.dart';
import 'package:omnix_dashboard/domain/events/partner_dispatch_status_declared.dart';
import 'package:omnix_dashboard/ui/admin_page.dart';
import 'package:omnix_dashboard/ui/video_fleet_scope_health_sections.dart';
import 'package:omnix_dashboard/ui/video_fleet_scope_health_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('administration page stays stable on phone viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[],
          supabaseReady: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('System Administration'), findsOneWidget);
    expect(find.text('Administration Console'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('administration page stays stable on landscape viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[],
          supabaseReady: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('System Administration'), findsOneWidget);
    expect(find.text('Employees'), findsOneWidget);
    expect(find.text('Sites'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('administration page switches tabs and shows system cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[],
          supabaseReady: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Thabo Mokoena'), findsOneWidget);

    await tester.tap(find.text('System').first);
    await tester.pumpAndSettle();

    expect(find.text('SLA Tiers'), findsOneWidget);
    expect(find.text('Risk Policies'), findsOneWidget);
    expect(find.text('System Information'), findsOneWidget);
  });

  testWidgets('administration page can start on system tab from parent state', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[],
          supabaseReady: false,
          initialTab: AdministrationPageTab.system,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('System Information'), findsOneWidget);
    expect(find.text('SLA Tiers'), findsOneWidget);
    expect(find.textContaining('Thabo Mokoena'), findsNothing);
  });

  testWidgets('system tab can update operator runtime in app', (tester) async {
    String operatorId = 'OPS-ALPHA';
    final savedOperatorIds = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return AdministrationPage(
              events: const <DispatchEvent>[],
              supabaseReady: false,
              initialTab: AdministrationPageTab.system,
              operatorId: operatorId,
              onSetOperatorId: (value) async {
                savedOperatorIds.add(value);
                setState(() {
                  operatorId = value.trim().isEmpty
                      ? 'OPERATOR-01'
                      : value.trim();
                });
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Operator Runtime'), findsOneWidget);
    expect(find.text('Active operator: OPS-ALPHA'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('admin-operator-runtime-field')),
      'OPS-BETA',
    );
    await tester.ensureVisible(find.text('Save Operator'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Operator'));
    await tester.pumpAndSettle();

    expect(savedOperatorIds, <String>['OPS-BETA']);
    expect(find.text('Active operator: OPS-BETA'), findsOneWidget);
    expect(find.text('Operator runtime set to OPS-BETA.'), findsOneWidget);

    await tester.ensureVisible(find.text('Reset Default'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset Default'));
    await tester.pumpAndSettle();

    expect(savedOperatorIds, <String>['OPS-BETA', '']);
    expect(find.text('Active operator: OPERATOR-01'), findsOneWidget);
  });

  testWidgets('system tab can manage partner dispatch runtime lane', (
    tester,
  ) async {
    late Map<String, Object?> boundPayload;
    late Map<String, Object?> checkedPayload;
    late Map<String, Object?> unlinkedPayload;

    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: const <DispatchEvent>[],
          supabaseReady: false,
          initialTab: AdministrationPageTab.system,
          onBindPartnerTelegramEndpoint:
              ({
                required clientId,
                required siteId,
                required endpointLabel,
                required chatId,
                int? threadId,
              }) async {
                boundPayload = <String, Object?>{
                  'clientId': clientId,
                  'siteId': siteId,
                  'endpointLabel': endpointLabel,
                  'chatId': chatId,
                  'threadId': threadId,
                };
                return 'PASS (partner lane bound)\nscope=$clientId/$siteId';
              },
          onCheckPartnerTelegramEndpoint:
              ({
                required clientId,
                required siteId,
                required chatId,
                int? threadId,
              }) async {
                checkedPayload = <String, Object?>{
                  'clientId': clientId,
                  'siteId': siteId,
                  'chatId': chatId,
                  'threadId': threadId,
                };
                return 'PASS (partner lane linked)\nscope=$clientId/$siteId';
              },
          onUnlinkPartnerTelegramEndpoint:
              ({
                required clientId,
                required siteId,
                required chatId,
                int? threadId,
              }) async {
                unlinkedPayload = <String, Object?>{
                  'clientId': clientId,
                  'siteId': siteId,
                  'chatId': chatId,
                  'threadId': threadId,
                };
                return 'PASS (partner lane updated)\nscope=$clientId/$siteId';
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Partner Dispatch Runtime'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('admin-partner-runtime-label-field')),
      'Field Response',
    );
    await tester.enterText(
      find.byKey(const ValueKey('admin-partner-runtime-chat-field')),
      '-1001234567890',
    );
    await tester.enterText(
      find.byKey(const ValueKey('admin-partner-runtime-thread-field')),
      '77',
    );
    await tester.ensureVisible(find.text('Bind Partner Lane'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bind Partner Lane'));
    await tester.pumpAndSettle();

    expect(boundPayload['clientId'], 'CLT-001');
    expect(boundPayload['siteId'], 'WTF-MAIN');
    expect(boundPayload['endpointLabel'], 'Field Response');
    expect(boundPayload['chatId'], '-1001234567890');
    expect(boundPayload['threadId'], 77);
    expect(find.textContaining('PASS (partner lane bound)'), findsOneWidget);

    await tester.ensureVisible(find.text('Check Lane'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check Lane'));
    await tester.pumpAndSettle();

    expect(checkedPayload['clientId'], 'CLT-001');
    expect(checkedPayload['siteId'], 'WTF-MAIN');
    expect(checkedPayload['chatId'], '-1001234567890');
    expect(checkedPayload['threadId'], 77);
    expect(find.textContaining('PASS (partner lane linked)'), findsOneWidget);

    await tester.ensureVisible(find.text('Unlink Lane'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unlink Lane'));
    await tester.pumpAndSettle();

    expect(unlinkedPayload['clientId'], 'CLT-001');
    expect(unlinkedPayload['siteId'], 'WTF-MAIN');
    expect(unlinkedPayload['chatId'], '-1001234567890');
    expect(unlinkedPayload['threadId'], 77);
    expect(find.textContaining('PASS (partner lane updated)'), findsOneWidget);
  });

  testWidgets('system tab shows partner scorecard summary and opens scope drill-in', (
    tester,
  ) async {
    String? copiedPayload;
    var openedGovernance = 0;
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

    final priorReport = SovereignReport(
      date: '2026-03-14',
      generatedAtUtc: DateTime.utc(2026, 3, 14, 6, 0),
      shiftWindowStartUtc: DateTime.utc(2026, 3, 13, 22, 0),
      shiftWindowEndUtc: DateTime.utc(2026, 3, 14, 6, 0),
      ledgerIntegrity: const SovereignReportLedgerIntegrity(
        totalEvents: 10,
        hashVerified: true,
        integrityScore: 99,
      ),
      aiHumanDelta: const SovereignReportAiHumanDelta(
        aiDecisions: 1,
        humanOverrides: 0,
        overrideReasons: <String, int>{},
      ),
      normDrift: const SovereignReportNormDrift(
        sitesMonitored: 1,
        driftDetected: 0,
        avgMatchScore: 100,
      ),
      complianceBlockage: const SovereignReportComplianceBlockage(
        psiraExpired: 0,
        pdpExpired: 0,
        totalBlocked: 0,
      ),
      partnerProgression: SovereignReportPartnerProgression(
        dispatchCount: 1,
        declarationCount: 1,
        acceptedCount: 1,
        onSiteCount: 0,
        allClearCount: 0,
        cancelledCount: 1,
        summaryLine: '',
        scoreboardRows: [
          SovereignReportPartnerScoreboardRow(
            clientId: 'CLT-001',
            siteId: 'WTF-MAIN',
            partnerLabel: 'PARTNER • Alpha',
            dispatchCount: 1,
            strongCount: 0,
            onTrackCount: 0,
            watchCount: 0,
            criticalCount: 1,
            averageAcceptedDelayMinutes: 12.0,
            averageOnSiteDelayMinutes: 22.0,
            summaryLine:
                'Dispatches 1 • Strong 0 • On track 0 • Watch 0 • Critical 1 • Avg accept 12.0m • Avg on site 22.0m',
          ),
        ],
      ),
    );
    final currentReport = SovereignReport(
      date: '2026-03-15',
      generatedAtUtc: DateTime.utc(2026, 3, 15, 6, 0),
      shiftWindowStartUtc: DateTime.utc(2026, 3, 14, 22, 0),
      shiftWindowEndUtc: DateTime.utc(2026, 3, 15, 6, 0),
      ledgerIntegrity: const SovereignReportLedgerIntegrity(
        totalEvents: 12,
        hashVerified: true,
        integrityScore: 99,
      ),
      aiHumanDelta: const SovereignReportAiHumanDelta(
        aiDecisions: 1,
        humanOverrides: 0,
        overrideReasons: <String, int>{},
      ),
      normDrift: const SovereignReportNormDrift(
        sitesMonitored: 1,
        driftDetected: 0,
        avgMatchScore: 100,
      ),
      complianceBlockage: const SovereignReportComplianceBlockage(
        psiraExpired: 0,
        pdpExpired: 0,
        totalBlocked: 0,
      ),
      partnerProgression: SovereignReportPartnerProgression(
        dispatchCount: 1,
        declarationCount: 3,
        acceptedCount: 1,
        onSiteCount: 1,
        allClearCount: 1,
        cancelledCount: 0,
        summaryLine: '',
        scoreboardRows: [
          SovereignReportPartnerScoreboardRow(
            clientId: 'CLT-001',
            siteId: 'WTF-MAIN',
            partnerLabel: 'PARTNER • Alpha',
            dispatchCount: 1,
            strongCount: 1,
            onTrackCount: 0,
            watchCount: 0,
            criticalCount: 0,
            averageAcceptedDelayMinutes: 4.0,
            averageOnSiteDelayMinutes: 10.0,
            summaryLine:
                'Dispatches 1 • Strong 1 • On track 0 • Watch 0 • Critical 0 • Avg accept 4.0m • Avg on site 10.0m',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: const <DispatchEvent>[],
          supabaseReady: false,
          initialTab: AdministrationPageTab.system,
          morningSovereignReportHistory: [priorReport, currentReport],
          onOpenGovernance: () {
            openedGovernance += 1;
          },
          initialSitePartnerLaneDetails: const <String, List<String>>{
            'CLT-001::WTF-MAIN': <String>[
              'PARTNER • Alpha • chat=-1001234567890 • thread=77',
            ],
          },
          initialSitePartnerChatcheckStatus: const <String, String>{
            'CLT-001::WTF-MAIN': 'PASS (partner lane linked)',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Partner Scorecard'), findsOneWidget);
    expect(find.text('Slipping: 0'), findsOneWidget);
    expect(find.text('Critical: 0'), findsOneWidget);
    expect(find.text('Improving: 1'), findsOneWidget);
    expect(find.text('Open Governance'), findsOneWidget);
    expect(find.text('Copy Scorecard JSON'), findsOneWidget);
    expect(find.text('Copy Scorecard CSV'), findsOneWidget);

    await tester.ensureVisible(find.text('Open Governance'));
    await tester.tap(find.text('Open Governance'));
    await tester.pumpAndSettle();

    expect(openedGovernance, 1);
    expect(find.text('Opening Governance readiness board'), findsOneWidget);

    await tester.tap(find.text('Copy Scorecard JSON'));
    await tester.pumpAndSettle();

    expect(copiedPayload, isNotNull);
    expect(copiedPayload, contains('"scorecardRows"'));
    expect(copiedPayload, contains('"clientId": "CLT-001"'));
    expect(copiedPayload, contains('"siteId": "WTF-MAIN"'));
    expect(copiedPayload, contains('"partnerLabel": "PARTNER • Alpha"'));
    expect(copiedPayload, contains('"trendLabel": "IMPROVING"'));

    await tester.ensureVisible(find.text('Copy Scorecard CSV'));
    await tester.tap(find.text('Copy Scorecard CSV'));
    await tester.pumpAndSettle();

    expect(copiedPayload, isNotNull);
    expect(
      copiedPayload,
      contains(
        'client_id,site_id,partner_label,report_days,dispatch_count,strong_count',
      ),
    );
    expect(copiedPayload, contains('"CLT-001","WTF-MAIN","PARTNER • Alpha"'));
    expect(copiedPayload, contains('"IMPROVING"'));

    final scorecardFinder = find.byKey(
      const ValueKey(
        'admin-partner-scorecard-CLT-001-WTF-MAIN-PARTNER • Alpha',
      ),
    );
    await tester.ensureVisible(scorecardFinder);
    await tester.tap(scorecardFinder);
    await tester.pumpAndSettle();

    expect(find.textContaining('Partner Dispatch Detail'), findsOneWidget);
    expect(find.text('7-day trend'), findsOneWidget);
    expect(
      find.text('Acceptance timing improved against the prior 7-day average.'),
      findsWidgets,
    );
    expect(
      find.text('PARTNER • Alpha • chat=-1001234567890 • thread=77'),
      findsOneWidget,
    );
  });

  testWidgets('admin tables surface partner lane health summaries', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[],
          supabaseReady: false,
          initialTab: AdministrationPageTab.clients,
          initialClientPartnerEndpointCounts: <String, int>{'CLT-001': 2},
          initialClientPartnerLanePreview: <String, String>{
            'CLT-001': 'PARTNER • Alpha • PARTNER • Bravo',
          },
          initialClientPartnerChatcheckStatus: <String, String>{
            'CLT-001': 'PASS (partner lane linked)',
          },
          initialSitePartnerEndpointCounts: <String, int>{
            'CLT-001::WTF-MAIN': 1,
          },
          initialSitePartnerChatcheckStatus: <String, String>{
            'CLT-001::WTF-MAIN': 'FAIL (partner lane missing)',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Partner Lanes: 2'), findsOneWidget);
    expect(
      find.text('Partner Labels: PARTNER • Alpha • PARTNER • Bravo'),
      findsOneWidget,
    );
    expect(
      find.text('Partner Dispatch: PASS (partner lane linked)'),
      findsOneWidget,
    );
    expect(find.text('PARTNER PASS'), findsOneWidget);

    await tester.tap(find.text('Sites').first);
    await tester.pumpAndSettle();

    expect(find.text('Partner lanes: 1'), findsOneWidget);
    expect(
      find.text('Partner dispatch: FAIL (partner lane missing)'),
      findsOneWidget,
    );
    expect(find.text('PARTNER FAIL'), findsOneWidget);
  });

  testWidgets('site partner health row opens drill-in with lane details', (
    tester,
  ) async {
    late Map<String, Object?> checkedPayload;
    String? openedDispatchClientId;
    String? openedDispatchSiteId;
    String? openedDispatchReference;
    List<String>? openedEventIds;
    String? openedSelectedEventId;
    Map<String, String>? openedGovernanceScope;

    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[
            PartnerDispatchStatusDeclared(
              eventId: 'evt-partner-0',
              sequence: 3,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 15, 21, 11),
              dispatchId: 'DSP-8821',
              clientId: 'CLT-001',
              regionId: 'GAUTENG',
              siteId: 'WTF-MAIN',
              partnerLabel: 'PARTNER • Alpha',
              actorLabel: '@partner.alpha',
              status: PartnerDispatchStatus.accepted,
              sourceChannel: 'telegram',
              sourceMessageKey: 'tg-partner-0',
            ),
            PartnerDispatchStatusDeclared(
              eventId: 'evt-partner-1',
              sequence: 2,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 15, 21, 14),
              dispatchId: 'DSP-8821',
              clientId: 'CLT-001',
              regionId: 'GAUTENG',
              siteId: 'WTF-MAIN',
              partnerLabel: 'PARTNER • Alpha',
              actorLabel: '@partner.alpha',
              status: PartnerDispatchStatus.onSite,
              sourceChannel: 'telegram',
              sourceMessageKey: 'tg-partner-1',
            ),
            PartnerDispatchStatusDeclared(
              eventId: 'evt-partner-2',
              sequence: 1,
              version: 1,
              occurredAt: DateTime.utc(2026, 3, 15, 21, 19),
              dispatchId: 'DSP-8821',
              clientId: 'CLT-001',
              regionId: 'GAUTENG',
              siteId: 'WTF-MAIN',
              partnerLabel: 'PARTNER • Alpha',
              actorLabel: '@partner.alpha',
              status: PartnerDispatchStatus.allClear,
              sourceChannel: 'telegram',
              sourceMessageKey: 'tg-partner-2',
            ),
          ],
          morningSovereignReportHistory: <SovereignReport>[
            SovereignReport(
              date: '2026-03-14',
              generatedAtUtc: DateTime.utc(2026, 3, 14, 6, 0),
              shiftWindowStartUtc: DateTime.utc(2026, 3, 13, 22, 0),
              shiftWindowEndUtc: DateTime.utc(2026, 3, 14, 6, 0),
              ledgerIntegrity: const SovereignReportLedgerIntegrity(
                totalEvents: 10,
                hashVerified: true,
                integrityScore: 99,
              ),
              aiHumanDelta: const SovereignReportAiHumanDelta(
                aiDecisions: 1,
                humanOverrides: 0,
                overrideReasons: <String, int>{},
              ),
              normDrift: const SovereignReportNormDrift(
                sitesMonitored: 1,
                driftDetected: 0,
                avgMatchScore: 100,
              ),
              complianceBlockage: const SovereignReportComplianceBlockage(
                psiraExpired: 0,
                pdpExpired: 0,
                totalBlocked: 0,
              ),
              partnerProgression: SovereignReportPartnerProgression(
                dispatchCount: 1,
                declarationCount: 1,
                acceptedCount: 1,
                onSiteCount: 0,
                allClearCount: 0,
                cancelledCount: 1,
                summaryLine: '',
                scoreboardRows: [
                  SovereignReportPartnerScoreboardRow(
                    clientId: 'CLT-001',
                    siteId: 'WTF-MAIN',
                    partnerLabel: 'PARTNER • Alpha',
                    dispatchCount: 1,
                    strongCount: 0,
                    onTrackCount: 0,
                    watchCount: 0,
                    criticalCount: 1,
                    averageAcceptedDelayMinutes: 12.0,
                    averageOnSiteDelayMinutes: 22.0,
                    summaryLine:
                        'Dispatches 1 • Strong 0 • On track 0 • Watch 0 • Critical 1 • Avg accept 12.0m • Avg on site 22.0m',
                  ),
                ],
              ),
            ),
            SovereignReport(
              date: '2026-03-15',
              generatedAtUtc: DateTime.utc(2026, 3, 15, 6, 0),
              shiftWindowStartUtc: DateTime.utc(2026, 3, 14, 22, 0),
              shiftWindowEndUtc: DateTime.utc(2026, 3, 15, 6, 0),
              ledgerIntegrity: const SovereignReportLedgerIntegrity(
                totalEvents: 10,
                hashVerified: true,
                integrityScore: 99,
              ),
              aiHumanDelta: const SovereignReportAiHumanDelta(
                aiDecisions: 1,
                humanOverrides: 0,
                overrideReasons: <String, int>{},
              ),
              normDrift: const SovereignReportNormDrift(
                sitesMonitored: 1,
                driftDetected: 0,
                avgMatchScore: 100,
              ),
              complianceBlockage: const SovereignReportComplianceBlockage(
                psiraExpired: 0,
                pdpExpired: 0,
                totalBlocked: 0,
              ),
              partnerProgression: SovereignReportPartnerProgression(
                dispatchCount: 1,
                declarationCount: 3,
                acceptedCount: 1,
                onSiteCount: 1,
                allClearCount: 1,
                cancelledCount: 0,
                summaryLine: '',
                scoreboardRows: [
                  SovereignReportPartnerScoreboardRow(
                    clientId: 'CLT-001',
                    siteId: 'WTF-MAIN',
                    partnerLabel: 'PARTNER • Alpha',
                    dispatchCount: 1,
                    strongCount: 1,
                    onTrackCount: 0,
                    watchCount: 0,
                    criticalCount: 0,
                    averageAcceptedDelayMinutes: 4.0,
                    averageOnSiteDelayMinutes: 10.0,
                    summaryLine:
                        'Dispatches 1 • Strong 1 • On track 0 • Watch 0 • Critical 0 • Avg accept 4.0m • Avg on site 10.0m',
                  ),
                ],
              ),
            ),
          ],
          supabaseReady: false,
          initialTab: AdministrationPageTab.sites,
          initialSitePartnerEndpointCounts: <String, int>{
            'CLT-001::WTF-MAIN': 1,
          },
          initialSitePartnerChatcheckStatus: <String, String>{
            'CLT-001::WTF-MAIN': 'PASS (partner lane linked)',
          },
          initialSitePartnerLaneDetails: <String, List<String>>{
            'CLT-001::WTF-MAIN': <String>[
              'PARTNER • Alpha • chat=-1001234567890 • thread=77',
            ],
          },
          onCheckPartnerTelegramEndpoint:
              ({
                required clientId,
                required siteId,
                required chatId,
                int? threadId,
              }) async {
                checkedPayload = <String, Object?>{
                  'clientId': clientId,
                  'siteId': siteId,
                  'chatId': chatId,
                  'threadId': threadId,
                };
                return 'PASS (partner lane linked)';
              },
          onOpenFleetDispatchScope: (clientId, siteId, incidentReference) {
            openedDispatchClientId = clientId;
            openedDispatchSiteId = siteId;
            openedDispatchReference = incidentReference;
          },
          onOpenEventsForScope: (eventIds, selectedEventId) {
            openedEventIds = eventIds;
            openedSelectedEventId = selectedEventId;
          },
          onOpenGovernanceForPartnerScope: (clientId, siteId, partnerLabel) {
            openedGovernanceScope = <String, String>{
              'clientId': clientId,
              'siteId': siteId,
              'partnerLabel': partnerLabel,
            };
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Waterfall Estate Main (WTF-MAIN)'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Partner Dispatch Detail'), findsOneWidget);
    expect(
      find.text('PARTNER • Alpha • chat=-1001234567890 • thread=77'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        '2026-03-15 21:14 UTC • PARTNER • Alpha • ON SITE • @partner.alpha • dispatch=DSP-8821',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-partner-dispatch-progression-card')),
      findsOneWidget,
    );
    expect(find.text('Dispatch progression'), findsOneWidget);
    expect(find.text('7-day trend'), findsOneWidget);
    expect(find.text('DSP-8821'), findsWidgets);
    expect(
      find.textContaining('PARTNER • Alpha • Latest ALL CLEAR'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-partner-progress-accepted')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-partner-progress-onSite')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-partner-progress-allClear')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-partner-progress-cancelled')),
      findsOneWidget,
    );
    expect(find.text('IMPROVING'), findsOneWidget);
    expect(
      find.text('Acceptance timing improved against the prior 7-day average.'),
      findsOneWidget,
    );
    expect(find.text('Open Governance Scope'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);

    await tester.tap(find.text('Check lane'));
    await tester.pumpAndSettle();

    expect(checkedPayload['clientId'], 'CLT-001');
    expect(checkedPayload['siteId'], 'WTF-MAIN');
    expect(checkedPayload['chatId'], '-1001234567890');
    expect(checkedPayload['threadId'], 77);
    expect(
      find.text('Current health: PASS (partner lane linked)'),
      findsOneWidget,
    );

    await tester.tap(find.text('Open Dispatch Scope'));
    await tester.pumpAndSettle();

    expect(openedDispatchClientId, 'CLT-001');
    expect(openedDispatchSiteId, 'WTF-MAIN');
    expect(openedDispatchReference, isNull);

    await tester.tap(find.text('Waterfall Estate Main (WTF-MAIN)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Governance Scope'));
    await tester.pumpAndSettle();

    expect(openedGovernanceScope, <String, String>{
      'clientId': 'CLT-001',
      'siteId': 'WTF-MAIN',
      'partnerLabel': 'PARTNER • Alpha',
    });
    expect(
      find.textContaining('Opening Governance for WTF-MAIN'),
      findsOneWidget,
    );

    await tester.tap(find.text('Waterfall Estate Main (WTF-MAIN)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Events Review'));
    await tester.pumpAndSettle();

    expect(openedEventIds, <String>[
      'evt-partner-2',
      'evt-partner-1',
      'evt-partner-0',
    ]);
    expect(openedSelectedEventId, 'evt-partner-2');
  });

  testWidgets('administration page reports tab changes to parent state', (
    tester,
  ) async {
    AdministrationPageTab selectedTab = AdministrationPageTab.guards;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return AdministrationPage(
              events: const <DispatchEvent>[],
              supabaseReady: false,
              initialTab: selectedTab,
              onTabChanged: (value) {
                setState(() {
                  selectedTab = value;
                });
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(selectedTab, AdministrationPageTab.guards);
    expect(find.textContaining('Thabo Mokoena'), findsOneWidget);

    await tester.tap(find.text('System').first);
    await tester.pumpAndSettle();

    expect(selectedTab, AdministrationPageTab.system);
    expect(find.text('System Information'), findsOneWidget);
    expect(find.textContaining('Thabo Mokoena'), findsNothing);
  });

  testWidgets(
    'administration page persists selected tab through parent-owned remounts',
    (tester) async {
      AdministrationPageTab selectedTab = AdministrationPageTab.system;
      var showAdmin = true;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        showAdmin = !showAdmin;
                      });
                    },
                    child: const Text('Toggle admin'),
                  ),
                  Expanded(
                    child: showAdmin
                        ? AdministrationPage(
                            events: const <DispatchEvent>[],
                            supabaseReady: false,
                            initialTab: selectedTab,
                            onTabChanged: (value) {
                              setState(() {
                                selectedTab = value;
                              });
                            },
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('System Information'), findsOneWidget);
      expect(find.textContaining('Thabo Mokoena'), findsNothing);

      await tester.tap(find.text('Toggle admin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toggle admin'));
      await tester.pumpAndSettle();

      expect(selectedTab, AdministrationPageTab.system);
      expect(find.text('System Information'), findsOneWidget);
      expect(find.textContaining('Thabo Mokoena'), findsNothing);
    },
  );

  testWidgets('administration page filters guards by search query', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[],
          supabaseReady: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Nomsa');
    await tester.pumpAndSettle();

    expect(find.textContaining('Nomsa Khumalo'), findsOneWidget);
    expect(find.textContaining('Thabo Mokoena'), findsNothing);
  });

  testWidgets('system tab shows ops poll health rows when provided', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[],
          supabaseReady: false,
          radioOpsPollHealth: 'ok 3 • fail 1 • skip 0 • last 10:05:00 UTC',
          radioOpsQueueHealth:
              'pending 4 • due 1 • deferred 3 • max-attempt 2 • next 10:05:30 UTC',
          radioOpsQueueIntentMix:
              'pending intent mix • all_clear 2 • panic 1 • duress 1 • status 0 • unknown 0',
          radioOpsAckRecentSummary:
              'recent ack 5 (6h) • all_clear 2 • panic 1 • duress 1 • status 1',
          radioOpsQueueStateDetail: 'Queue updated via ingest • 10:06:20 UTC',
          radioOpsFailureDetail:
              'Last failure • ZEL-9001 • reason send_failed • count 2 • at 10:05:30 UTC',
          radioOpsFailureAuditDetail: 'Failure snapshot cleared • 10:06:00 UTC',
          radioOpsManualActionDetail:
              'Retry requested for 4 queued • 10:05:15 UTC',
          cctvOpsPollHealth: 'ok 2 • fail 0 • skip 0 • last 10:05:01 UTC',
          cctvCapabilitySummary: 'caps LIVE AI MONITORING • FR • LPR',
          cctvRecentSignalSummary:
              'recent video intel 5 (6h) • intrusion 2 • line_crossing 1 • motion 1 • fr 1 • lpr 2',
          cctvEvidenceHealthSummary:
              'verified 2 • fail 0 • dropped 0 • queue 2/12 • last 10:05:01 UTC',
          cctvCameraHealthSummary:
              'front-gate:healthy • zone north_gate • stale 1m | yard:stale • zone driveway • stale 42m',
          incidentSpoolHealthSummary:
              'buffering • 3 pending • retry 1 • queued 2026-03-13T10:05:30.000Z',
          incidentSpoolReplaySummary:
              '2 replayed • client_ledger • last INC-002 • 2026-03-13T10:07:00.000Z',
          monitoringWatchAuditSummary:
              'Resync • ADMIN • MS Vallee Residence • Resynced • 2026-03-13T10:08:00.000Z',
          monitoringWatchAuditHistory: <String>[
            'Resync • ADMIN • MS Vallee Residence • Resynced • 2026-03-13T10:08:00.000Z',
            'Resync • DISPATCH • MS Vallee Residence • Already aligned • 2026-03-13T09:58:00.000Z',
          ],
          wearableOpsPollHealth: 'ok 1 • fail 0 • skip 0 • last 10:05:02 UTC',
          newsOpsPollHealth: 'ok 4 • fail 0 • skip 0 • last 10:05:03 UTC',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('System').first);
    await tester.pumpAndSettle();

    expect(find.text('Ops Integration Poll Health'), findsOneWidget);
    expect(find.textContaining('ok 3 • fail 1'), findsOneWidget);
    expect(
      find.textContaining('pending 4 • due 1 • deferred 3'),
      findsOneWidget,
    );
    expect(
      find.textContaining('pending intent mix • all_clear 2 • panic 1'),
      findsOneWidget,
    );
    expect(
      find.textContaining('recent ack 5 (6h) • all_clear 2 • panic 1'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Queue updated via ingest • 10:06:20 UTC'),
      findsOneWidget,
    );
    expect(find.textContaining('Last failure • ZEL-9001'), findsOneWidget);
    expect(
      find.textContaining('Failure snapshot cleared • 10:06:00 UTC'),
      findsOneWidget,
    );
    expect(find.textContaining('Retry requested for 4 queued'), findsOneWidget);
    expect(find.textContaining('ok 2 • fail 0'), findsOneWidget);
    expect(
      find.textContaining('LIVE AI MONITORING • FR • LPR'),
      findsOneWidget,
    );
    expect(
      find.textContaining('recent video intel 5 (6h) • intrusion 2'),
      findsOneWidget,
    );
    expect(
      find.textContaining('verified 2 • fail 0 • dropped 0 • queue 2/12'),
      findsOneWidget,
    );
    expect(
      find.textContaining('front-gate:healthy • zone north_gate'),
      findsOneWidget,
    );
    expect(
      find.textContaining('buffering • 3 pending • retry 1'),
      findsOneWidget,
    );
    expect(find.textContaining('2 replayed • client_ledger'), findsOneWidget);
    expect(find.text('Watch Recovery Trail'), findsOneWidget);
    expect(
      find.text(
        'Resync • ADMIN • MS Vallee Residence • Resynced • 2026-03-13T10:08:00.000Z',
      ),
      findsOneWidget,
    );
    expect(find.text('MS Vallee Residence'), findsWidgets);
    expect(find.text('Actor ADMIN'), findsOneWidget);
    expect(find.text('Actor DISPATCH'), findsOneWidget);
    expect(find.text('Outcome Resynced'), findsOneWidget);
    expect(find.text('Outcome Already aligned'), findsOneWidget);
    expect(find.text('At 2026-03-13 10:08 UTC'), findsOneWidget);
    expect(find.text('At 2026-03-13 09:58 UTC'), findsOneWidget);
    expect(find.textContaining('ok 1 • fail 0'), findsOneWidget);
    expect(find.textContaining('ok 4 • fail 0'), findsOneWidget);
  });

  testWidgets(
    'system tab shows listener alarm summary card from audit events',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdministrationPage(
            supabaseReady: false,
            events: <DispatchEvent>[
              ListenerAlarmFeedCycleRecorded(
                eventId: 'alarm-cycle-1',
                sequence: 1,
                version: 1,
                occurredAt: DateTime.utc(2026, 3, 16, 8, 0),
                sourceLabel: 'listener-http',
                acceptedCount: 5,
                mappedCount: 4,
                unmappedCount: 1,
                duplicateCount: 0,
                rejectedCount: 0,
                normalizationSkippedCount: 0,
                deliveredCount: 4,
                failedCount: 0,
                clearCount: 3,
                suspiciousCount: 1,
                unavailableCount: 0,
                pendingCount: 0,
                rejectSummary: '',
              ),
              ListenerAlarmAdvisoryRecorded(
                eventId: 'alarm-advisory-1',
                sequence: 2,
                version: 1,
                occurredAt: DateTime.utc(2026, 3, 16, 8, 1),
                clientId: 'CLIENT-1',
                regionId: 'REGION-1',
                siteId: 'VALLEE',
                externalAlarmId: 'EXT-1',
                accountNumber: '1234',
                partition: '1',
                zone: '004',
                zoneLabel: 'Front gate',
                eventLabel: 'Burglary',
                dispositionLabel: 'suspicious',
                summary: 'Person detected near the front gate camera.',
                recommendation: 'Escalation recommended.',
                deliveredCount: 1,
                failedCount: 0,
              ),
              ListenerAlarmParityCycleRecorded(
                eventId: 'alarm-parity-1',
                sequence: 3,
                version: 1,
                occurredAt: DateTime.utc(2026, 3, 16, 8, 2),
                sourceLabel: 'listener-http',
                legacySourceLabel: 'oryx-http',
                statusLabel: 'ok',
                serialCount: 5,
                legacyCount: 5,
                matchedCount: 4,
                unmatchedSerialCount: 1,
                unmatchedLegacyCount: 1,
                maxAllowedSkewSeconds: 90,
                maxSkewSecondsObserved: 22,
                averageSkewSeconds: 8.4,
                driftSummary: 'serial 5 • legacy 5 • matched 4',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('System').first);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Listener Alarm'));
      await tester.pumpAndSettle();

      expect(find.text('Listener Alarm'), findsOneWidget);
      expect(find.textContaining('Cycles'), findsOneWidget);
      expect(find.textContaining('Advisories'), findsOneWidget);
      expect(
        find.textContaining('Latest cycle • mapped 4/5 • missed 1'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Latest advisory • VALLEE • Burglary'),
        findsOneWidget,
      );
      expect(
        find.textContaining('OK • matched 4/5 • serial-only 1 • legacy-only 1'),
        findsOneWidget,
      );
    },
  );

  testWidgets('system tab shows video integrity certificate preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[],
          supabaseReady: false,
          videoOpsLabel: 'DVR',
          videoIntegrityCertificateStatus: 'PASS',
          videoIntegrityCertificateSummary:
              'Bundle hash sealed for dvr validation_report.json.',
          videoIntegrityCertificateJsonPreview:
              '{\n  "status": "PASS",\n  "bundle_hash": "abc123"\n}',
          videoIntegrityCertificateMarkdownPreview:
              '# Integrity Certificate\n\n- Status: `PASS`\n- Bundle hash: `abc123`',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('System').first);
    await tester.pumpAndSettle();

    expect(find.text('DVR Integrity Certificate'), findsOneWidget);
    expect(
      find.textContaining('Bundle hash sealed for dvr validation_report.json.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('View Certificate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View Certificate'));
    await tester.pumpAndSettle();

    expect(find.text('DVR Integrity Certificate'), findsAtLeastNWidgets(1));
    expect(find.text('JSON'), findsOneWidget);
    expect(find.text('Markdown'), findsOneWidget);
    expect(find.textContaining('"bundle_hash": "abc123"'), findsOneWidget);
    expect(find.text('Copy JSON'), findsOneWidget);
    expect(find.text('Copy Markdown'), findsOneWidget);
  });

  testWidgets('system tab validates and saves radio intent dictionary', (
    tester,
  ) async {
    String? savedRaw;
    var resetCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: const <DispatchEvent>[],
          supabaseReady: false,
          initialRadioIntentPhrasesJson:
              '{"all_clear":["all clear"],"panic":["panic"],"duress":["silent duress"],"status":["status update"]}',
          onSaveRadioIntentPhrasesJson: (rawJson) async {
            savedRaw = rawJson;
          },
          onResetRadioIntentPhrasesJson: () async {
            resetCalls += 1;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('System').first);
    await tester.pumpAndSettle();

    expect(find.text('Radio Intent Dictionary'), findsOneWidget);
    final radioEditor = find.byWidgetPredicate((widget) {
      if (widget is! TextField) return false;
      final hint = widget.decoration?.hintText ?? '';
      return hint.contains('"panic button"');
    });
    final radioValidateButton = find.text('Validate').first;
    final radioSaveButton = find.text('Save Runtime').first;
    final radioResetButton = find.text('Reset To Defaults').first;
    expect(radioEditor, findsOneWidget);
    expect(radioValidateButton, findsOneWidget);
    expect(radioSaveButton, findsOneWidget);
    expect(radioResetButton, findsOneWidget);

    await tester.enterText(radioEditor, '{not-json');
    await tester.ensureVisible(radioValidateButton);
    await tester.pumpAndSettle();
    await tester.tap(radioValidateButton);
    await tester.pumpAndSettle();
    expect(savedRaw, isNull);

    await tester.enterText(
      radioEditor,
      '{"all_clear":["all clear"],"panic":["panic button"],"duress":["duress"],"status":["status check"]}',
    );
    await tester.ensureVisible(radioSaveButton);
    await tester.pumpAndSettle();
    await tester.tap(radioSaveButton);
    await tester.pumpAndSettle();

    expect(savedRaw, contains('"panic button"'));

    await tester.ensureVisible(radioResetButton);
    await tester.pumpAndSettle();
    await tester.tap(radioResetButton);
    await tester.pumpAndSettle();
    expect(resetCalls, 1);
  });

  testWidgets('system tab invokes radio queue action callbacks', (
    tester,
  ) async {
    var runOpsPollCalls = 0;
    var runRadioPollCalls = 0;
    var runCctvPollCalls = 0;
    var runWearablePollCalls = 0;
    var runNewsPollCalls = 0;
    var retryCalls = 0;
    var clearCalls = 0;
    var clearFailureSnapshotCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: const <DispatchEvent>[],
          supabaseReady: false,
          videoOpsLabel: 'DVR',
          radioOpsPollHealth: 'ok 1 • fail 0 • skip 0 • last 10:05:00 UTC',
          radioOpsQueueHealth: 'pending 2 • due 1 • deferred 1 • max-attempt 2',
          radioOpsFailureDetail:
              'Last failure • ZEL-9001 • reason send_failed • count 2 • at 10:05:30 UTC',
          radioQueueHasPending: true,
          onRunOpsIntegrationPoll: () async {
            runOpsPollCalls += 1;
          },
          onRunRadioPoll: () async {
            runRadioPollCalls += 1;
          },
          onRunCctvPoll: () async {
            runCctvPollCalls += 1;
          },
          onRunWearablePoll: () async {
            runWearablePollCalls += 1;
          },
          onRunNewsPoll: () async {
            runNewsPollCalls += 1;
          },
          onRetryRadioQueue: () async {
            retryCalls += 1;
          },
          onClearRadioQueue: () async {
            clearCalls += 1;
          },
          onClearRadioQueueFailureSnapshot: () async {
            clearFailureSnapshotCalls += 1;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('System').first);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Run Ops Poll Now').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Run Ops Poll Now').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Poll Radio').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Poll Radio').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Poll DVR').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Poll DVR').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Poll Wearable').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Poll Wearable').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Poll News').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Poll News').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Retry Radio Queue').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry Radio Queue').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Clear Radio Queue').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear Radio Queue').first);
    await tester.pumpAndSettle();
    expect(find.text('Clear Radio Queue?'), findsOneWidget);
    await tester.tap(find.text('Confirm Clear').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Clear Last Failure').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear Last Failure').first);
    await tester.pumpAndSettle();
    expect(find.text('Clear Last Failure Snapshot?'), findsOneWidget);
    await tester.tap(find.text('Confirm Clear').first);
    await tester.pumpAndSettle();

    expect(runOpsPollCalls, 1);
    expect(runRadioPollCalls, 1);
    expect(runCctvPollCalls, 1);
    expect(runWearablePollCalls, 1);
    expect(runNewsPollCalls, 1);
    expect(retryCalls, 1);
    expect(clearCalls, 1);
    expect(clearFailureSnapshotCalls, 1);
  });

  testWidgets('system tab clear radio queue cancel does not invoke callback', (
    tester,
  ) async {
    var clearCalls = 0;
    var clearFailureSnapshotCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: const <DispatchEvent>[],
          supabaseReady: false,
          radioOpsPollHealth: 'ok 1 • fail 0 • skip 0 • last 10:05:00 UTC',
          radioOpsQueueHealth: 'pending 1 • due 1 • deferred 0 • max-attempt 1',
          radioOpsFailureDetail:
              'Last failure • ZEL-9001 • reason send_failed • count 1 • at 10:05:30 UTC',
          radioQueueHasPending: true,
          onClearRadioQueue: () async {
            clearCalls += 1;
          },
          onClearRadioQueueFailureSnapshot: () async {
            clearFailureSnapshotCalls += 1;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('System').first);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Clear Radio Queue').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear Radio Queue').first);
    await tester.pumpAndSettle();
    expect(find.text('Clear Radio Queue?'), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Clear Last Failure').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear Last Failure').first);
    await tester.pumpAndSettle();
    expect(find.text('Clear Last Failure Snapshot?'), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();

    expect(clearCalls, 0);
    expect(clearFailureSnapshotCalls, 0);
  });

  testWidgets('system tab groups fleet scopes into actionable and watch-only', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdministrationPage(
          events: <DispatchEvent>[],
          supabaseReady: false,
          cctvOpsPollHealth: 'ok 1 • fail 0 • skip 0 • last 10:05:01 UTC',
          fleetScopeHealth: <VideoFleetScopeHealthView>[
            VideoFleetScopeHealthView(
              clientId: 'CLIENT-A',
              siteId: 'SITE-A',
              siteName: 'MS Vallee Residence',
              endpointLabel: '192.168.8.105',
              statusLabel: 'LIVE',
              watchLabel: 'ACTIVE',
              recentEvents: 2,
              lastSeenLabel: '21:14 UTC',
              freshnessLabel: 'Fresh',
              isStale: false,
              watchWindowLabel: '18:00-06:00',
              watchWindowStateLabel: 'IN WINDOW',
              alertCount: 1,
              escalationCount: 1,
              actionHistory: [
                '21:13 UTC • Camera 2 • Monitoring Alert • Client alert sent because vehicle activity was detected and confidence remained medium.',
              ],
              latestEventLabel: 'Vehicle motion',
              latestIncidentReference: 'INT-VALLEE-1',
              latestEventTimeLabel: '21:14 UTC',
              latestCameraLabel: 'Camera 1',
              latestRiskScore: 84,
              latestFaceMatchId: 'PERSON-44',
              latestFaceConfidence: 91.2,
              latestPlateNumber: 'CA123456',
              latestPlateConfidence: 96.4,
              latestSceneReviewLabel:
                  'openai:gpt-4.1-mini • identity match concern • 21:14 UTC',
              latestSceneDecisionSummary:
                  'Escalated for urgent review because face match PERSON-44 was flagged and the event metadata suggested an unauthorized or watchlist context.',
            ),
            VideoFleetScopeHealthView(
              clientId: 'CLIENT-B',
              siteId: 'SITE-B',
              siteName: 'Beta Watch',
              endpointLabel: '192.168.8.106',
              statusLabel: 'WATCH READY',
              watchLabel: 'SCHEDULED',
              recentEvents: 0,
              lastSeenLabel: 'idle',
              freshnessLabel: 'Idle',
              isStale: false,
              watchWindowLabel: '18:00-06:00',
              watchWindowStateLabel: 'IN WINDOW',
              repeatCount: 2,
              suppressedCount: 3,
              lastRecoveryLabel: 'ADMIN • Resynced • 21:08 UTC',
              latestSceneDecisionLabel: 'Suppressed',
              latestSceneDecisionSummary:
                  'Suppressed because the activity remained below the client notification threshold.',
              watchActivationGapLabel: 'MISSED START',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('System').first);
    await tester.pumpAndSettle();

    expect(
      find.text('ACTIONABLE (1) • Incident-backed fleet scopes'),
      findsOneWidget,
    );
    expect(
      find.text('WATCH-ONLY (1) • Watch scopes awaiting incident context'),
      findsOneWidget,
    );
    expect(find.text('Gap 1'), findsOneWidget);
    expect(find.text('Recovered 6h 1'), findsOneWidget);
    expect(find.text('Suppressed 1'), findsOneWidget);
    expect(
      find.textContaining('Identity policy: Flagged match'),
      findsOneWidget,
    );
    expect(find.text('Identity Flagged'), findsOneWidget);
    expect(
      find.textContaining(
        'Identity match: Face PERSON-44 91.2% • Plate CA123456 96.4%',
      ),
      findsOneWidget,
    );
    expect(find.text('Alerts 1'), findsOneWidget);
    expect(find.text('Repeat 2'), findsOneWidget);
    expect(find.text('Escalated 1'), findsOneWidget);
    expect(find.text('Filtered 3'), findsOneWidget);
    expect(find.text('Flagged ID 1'), findsOneWidget);
    expect(find.text('Allowed ID 0'), findsOneWidget);
    expect(find.text('Recovery ADMIN • Resynced • 21:08 UTC'), findsOneWidget);
    expect(find.text('Window 18:00-06:00'), findsNWidgets(2));
    expect(find.text('Phase IN WINDOW'), findsNWidgets(2));
    expect(find.text('Gap MISSED START'), findsOneWidget);

    await tester.ensureVisible(find.text('Alerts 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alerts 1'));
    await tester.pumpAndSettle();
    expect(find.text('Focused watch action: Alert actions'), findsOneWidget);
    expect(
      find.text('Showing fleet scopes where ONYX sent a client alert.'),
      findsOneWidget,
    );
    expect(
      find.text('ACTIONABLE (1) • Incident-backed alert scopes'),
      findsOneWidget,
    );
    expect(
      find.text(
        'WATCH-ONLY (0) • No watch-only alert scopes awaiting incident context',
      ),
      findsOneWidget,
    );
    expect(find.text('Beta Watch'), findsNothing);

    await tester.ensureVisible(find.text('Escalated 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escalated 1'));
    await tester.pumpAndSettle();
    expect(
      find.text('Focused watch action: Escalated reviews'),
      findsOneWidget,
    );
    final textWidgets = tester.widgetList<Text>(find.byType(Text)).toList();
    expect(
      textWidgets.indexWhere((widget) => widget.data == 'CCTV Fleet Health'),
      lessThan(
        textWidgets.indexWhere((widget) => widget.data == 'Total Guards'),
      ),
    );
    expect(find.text('Beta Watch'), findsNothing);
    expect(find.text('MS Vallee Residence'), findsOneWidget);
    expect(
      find.textContaining(
        'Recent action: 21:13 UTC • Camera 2 • Monitoring Alert',
      ),
      findsOneWidget,
    );
    expect(find.text('Latest: 21:14 UTC • Vehicle motion'), findsNothing);
  });

  testWidgets('system tab shows configured identity rules panel', (
    tester,
  ) async {
    final identityPolicyService = MonitoringIdentityPolicyService.parseJson(
      '[{"client_id":"CLIENT-MS-VALLEE","site_id":"SITE-MS-VALLEE-RESIDENCE","allowed_face_match_ids":["RESIDENT-01"],"flagged_face_match_ids":["PERSON-44"],"allowed_plate_numbers":["CA111111"],"flagged_plate_numbers":["CA123456"]}]',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: const <DispatchEvent>[],
          supabaseReady: false,
          monitoringIdentityPolicyService: identityPolicyService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('System').first);
    await tester.pumpAndSettle();

    expect(find.text('Identity Rules'), findsOneWidget);
    expect(find.text('1 sites'), findsOneWidget);
    expect(find.text('SITE-MS-VALLEE-RESIDENCE'), findsOneWidget);
    expect(find.text('CLIENT-MS-VALLEE'), findsOneWidget);
    expect(find.text('Flagged faces 1'), findsOneWidget);
    expect(find.text('Flagged plates 1'), findsOneWidget);
    expect(find.text('Allowed faces 1'), findsOneWidget);
    expect(find.text('Allowed plates 1'), findsOneWidget);
    expect(find.text('PERSON-44'), findsOneWidget);
    expect(find.text('CA123456'), findsOneWidget);
    expect(find.text('RESIDENT-01'), findsOneWidget);
    expect(find.text('CA111111'), findsOneWidget);
  });

  testWidgets(
    'system tab persists watch action drilldown through parent-owned remounts',
    (tester) async {
      VideoFleetWatchActionDrilldown? selectedDrilldown =
          VideoFleetWatchActionDrilldown.filtered;
      var showAdmin = true;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        showAdmin = !showAdmin;
                      });
                    },
                    child: const Text('Toggle admin'),
                  ),
                  Expanded(
                    child: showAdmin
                        ? AdministrationPage(
                            events: const <DispatchEvent>[],
                            supabaseReady: false,
                            initialTab: AdministrationPageTab.system,
                            initialWatchActionDrilldown: selectedDrilldown,
                            onWatchActionDrilldownChanged: (value) {
                              setState(() {
                                selectedDrilldown = value;
                              });
                            },
                            cctvOpsPollHealth:
                                'ok 1 • fail 0 • skip 0 • last 10:05:01 UTC',
                            fleetScopeHealth: const <VideoFleetScopeHealthView>[
                              VideoFleetScopeHealthView(
                                clientId: 'CLIENT-B',
                                siteId: 'SITE-B',
                                siteName: 'Beta Watch',
                                endpointLabel: '192.168.8.106',
                                statusLabel: 'WATCH READY',
                                watchLabel: 'SCHEDULED',
                                recentEvents: 1,
                                lastSeenLabel: '21:14 UTC',
                                freshnessLabel: 'Recent',
                                isStale: false,
                                suppressedCount: 1,
                                suppressedHistory: [
                                  '21:10 UTC • Camera 2 • Suppressed because the activity remained below the client notification threshold.',
                                ],
                                latestIncidentReference: 'INT-BETA-1',
                                latestCameraLabel: 'Camera 2',
                                latestSceneDecisionLabel: 'Suppressed',
                                latestSceneDecisionSummary:
                                    'Suppressed because the activity remained below the client notification threshold.',
                              ),
                            ],
                            sceneReviewByIntelligenceId:
                                <String, MonitoringSceneReviewRecord>{
                                  'INT-BETA-1': MonitoringSceneReviewRecord(
                                    intelligenceId: 'INT-BETA-1',
                                    sourceLabel: 'openai:gpt-4.1-mini',
                                    postureLabel: 'reviewed',
                                    decisionLabel: 'Suppressed',
                                    decisionSummary:
                                        'Suppressed because the activity remained below the client notification threshold.',
                                    summary:
                                        'Vehicle remained below escalation threshold.',
                                    reviewedAtUtc: DateTime.utc(
                                      2026,
                                      3,
                                      13,
                                      21,
                                      14,
                                    ),
                                  ),
                                },
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Focused watch action: Filtered reviews'),
        findsOneWidget,
      );
      expect(find.text('Suppressed Scene Reviews'), findsOneWidget);

      await tester.tap(find.text('Toggle admin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toggle admin'));
      await tester.pumpAndSettle();

      expect(
        find.text('Focused watch action: Filtered reviews'),
        findsOneWidget,
      );
      expect(find.text('Suppressed Scene Reviews'), findsOneWidget);
    },
  );

  testWidgets('system tab can add and remove identity rule values', (
    tester,
  ) async {
    MonitoringIdentityPolicyService
    changedService = MonitoringIdentityPolicyService.parseJson(
      '[{"client_id":"CLIENT-MS-VALLEE","site_id":"SITE-MS-VALLEE-RESIDENCE","allowed_face_match_ids":["RESIDENT-01"],"flagged_face_match_ids":["PERSON-44"],"allowed_plate_numbers":["CA111111"],"flagged_plate_numbers":["CA123456"]}]',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return AdministrationPage(
              events: const <DispatchEvent>[],
              supabaseReady: false,
              monitoringIdentityPolicyService: changedService,
              onMonitoringIdentityPolicyServiceChanged: (value) {
                setState(() {
                  changedService = value;
                });
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('System').first);
    await tester.pumpAndSettle();

    final addRuleButton = find.byKey(
      const ValueKey('identity-rule-add-flaggedFaces-SITE-MS-VALLEE-RESIDENCE'),
    );
    await tester.ensureVisible(addRuleButton);
    await tester.tap(addRuleButton);
    await tester.pumpAndSettle();

    final dialogField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogField, 'person-77');
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Add')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Flagged faces 2'), findsOneWidget);
    expect(find.text('PERSON-77'), findsOneWidget);
    expect(
      changedService
          .policyFor(
            clientId: 'CLIENT-MS-VALLEE',
            siteId: 'SITE-MS-VALLEE-RESIDENCE',
          )
          .flaggedFaceMatchIds,
      contains('PERSON-77'),
    );

    await tester.tap(find.byTooltip('Remove PERSON-44'));
    await tester.pumpAndSettle();

    expect(find.text('Flagged faces 1'), findsOneWidget);
    expect(find.text('PERSON-44'), findsNothing);
    expect(
      changedService
          .policyFor(
            clientId: 'CLIENT-MS-VALLEE',
            siteId: 'SITE-MS-VALLEE-RESIDENCE',
          )
          .flaggedFaceMatchIds,
      isNot(contains('PERSON-44')),
    );
  });

  testWidgets('system tab shows recent identity rule changes', (tester) async {
    MonitoringIdentityPolicyService
    currentService = MonitoringIdentityPolicyService.parseJson(
      '[{"client_id":"CLIENT-MS-VALLEE","site_id":"SITE-MS-VALLEE-RESIDENCE","allowed_face_match_ids":["RESIDENT-01"],"flagged_face_match_ids":["PERSON-44"],"allowed_plate_numbers":["CA111111"],"flagged_plate_numbers":["CA123456"]}]',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return AdministrationPage(
              events: const <DispatchEvent>[],
              supabaseReady: false,
              monitoringIdentityPolicyService: currentService,
              onMonitoringIdentityPolicyServiceChanged: (value) {
                setState(() {
                  currentService = value;
                });
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('System').first);
    await tester.pumpAndSettle();

    final addRuleButton = find.byKey(
      const ValueKey('identity-rule-add-flaggedFaces-SITE-MS-VALLEE-RESIDENCE'),
    );
    await tester.ensureVisible(addRuleButton);
    await tester.tap(addRuleButton);
    await tester.pumpAndSettle();

    final dialogField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogField, 'person-77');
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Add')),
    );
    await tester.pump();

    expect(find.text('Recent Rule Changes'), findsOneWidget);
    expect(find.text('1 recent'), findsOneWidget);
    expect(find.text('Manual edit'), findsWidgets);
    expect(
      find.textContaining(
        'Added PERSON-77 to flagged faces for SITE-MS-VALLEE-RESIDENCE.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('system tab can start with persisted identity rule history', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: const <DispatchEvent>[],
          supabaseReady: false,
          monitoringIdentityPolicyService:
              const MonitoringIdentityPolicyService(
                policiesByScope: {
                  'CLIENT-MS-VALLEE|SITE-MS-VALLEE-RESIDENCE':
                      MonitoringIdentityScopePolicy(
                        flaggedFaceMatchIds: {'PERSON-44'},
                      ),
                },
              ),
          initialMonitoringIdentityRuleAuditHistory:
              <MonitoringIdentityPolicyAuditRecord>[
                MonitoringIdentityPolicyAuditRecord(
                  recordedAtUtc: DateTime.utc(2026, 3, 15, 7, 14),
                  source: MonitoringIdentityPolicyAuditSource.manualEdit,
                  message:
                      'Added PERSON-44 to flagged faces for SITE-MS-VALLEE-RESIDENCE.',
                ),
              ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('System').first);
    await tester.pumpAndSettle();

    expect(find.text('Recent Rule Changes'), findsOneWidget);
    expect(find.text('1 recent'), findsOneWidget);
    expect(find.text('Manual edit'), findsWidgets);
    expect(find.text('2026-03-15 07:14 UTC'), findsOneWidget);
    expect(
      find.textContaining(
        'Added PERSON-44 to flagged faces for SITE-MS-VALLEE-RESIDENCE.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('system tab can filter identity rule history by source', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: const <DispatchEvent>[],
          supabaseReady: false,
          monitoringIdentityPolicyService:
              const MonitoringIdentityPolicyService(
                policiesByScope: {
                  'CLIENT-MS-VALLEE|SITE-MS-VALLEE-RESIDENCE':
                      MonitoringIdentityScopePolicy(
                        flaggedFaceMatchIds: {'PERSON-44'},
                      ),
                },
              ),
          initialMonitoringIdentityRuleAuditHistory:
              <MonitoringIdentityPolicyAuditRecord>[
                MonitoringIdentityPolicyAuditRecord(
                  recordedAtUtc: DateTime.utc(2026, 3, 15, 7, 14),
                  source: MonitoringIdentityPolicyAuditSource.manualEdit,
                  message:
                      'Added PERSON-44 to flagged faces for SITE-MS-VALLEE-RESIDENCE.',
                ),
                MonitoringIdentityPolicyAuditRecord(
                  recordedAtUtc: DateTime.utc(2026, 3, 15, 7, 10),
                  source: MonitoringIdentityPolicyAuditSource.saveRuntime,
                  message: 'Saved runtime identity rules (1 sites).',
                ),
              ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('System').first);
    await tester.pumpAndSettle();

    expect(find.text('2 recent'), findsOneWidget);
    expect(find.text('Manual edit'), findsWidgets);
    expect(find.text('Runtime save'), findsWidgets);

    final manualEditFilter = find.byKey(
      const ValueKey('identity-audit-filter-manual_edit'),
    );
    await tester.ensureVisible(manualEditFilter);
    await tester.tap(manualEditFilter);
    await tester.pumpAndSettle();

    expect(find.text('1 recent'), findsOneWidget);
    expect(
      find.textContaining(
        'Added PERSON-44 to flagged faces for SITE-MS-VALLEE-RESIDENCE.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Saved runtime identity rules (1 sites).'),
      findsNothing,
    );
  });

  testWidgets(
    'system tab persists identity rule history filter through parent-owned remounts',
    (tester) async {
      MonitoringIdentityPolicyAuditSource? selectedSource =
          MonitoringIdentityPolicyAuditSource.manualEdit;
      var showAdmin = true;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        showAdmin = !showAdmin;
                      });
                    },
                    child: const Text('Toggle admin'),
                  ),
                  Expanded(
                    child: showAdmin
                        ? AdministrationPage(
                            events: const <DispatchEvent>[],
                            supabaseReady: false,
                            initialTab: AdministrationPageTab.system,
                            monitoringIdentityPolicyService:
                                const MonitoringIdentityPolicyService(
                                  policiesByScope: {
                                    'CLIENT-MS-VALLEE|SITE-MS-VALLEE-RESIDENCE':
                                        MonitoringIdentityScopePolicy(
                                          flaggedFaceMatchIds: {'PERSON-44'},
                                        ),
                                  },
                                ),
                            initialMonitoringIdentityRuleAuditHistory:
                                <MonitoringIdentityPolicyAuditRecord>[
                                  MonitoringIdentityPolicyAuditRecord(
                                    recordedAtUtc: DateTime.utc(
                                      2026,
                                      3,
                                      15,
                                      7,
                                      14,
                                    ),
                                    source: MonitoringIdentityPolicyAuditSource
                                        .manualEdit,
                                    message:
                                        'Added PERSON-44 to flagged faces for SITE-MS-VALLEE-RESIDENCE.',
                                  ),
                                  MonitoringIdentityPolicyAuditRecord(
                                    recordedAtUtc: DateTime.utc(
                                      2026,
                                      3,
                                      15,
                                      7,
                                      10,
                                    ),
                                    source: MonitoringIdentityPolicyAuditSource
                                        .saveRuntime,
                                    message:
                                        'Saved runtime identity rules (1 sites).',
                                  ),
                                ],
                            initialMonitoringIdentityRuleAuditSourceFilter:
                                selectedSource,
                            onMonitoringIdentityRuleAuditSourceFilterChanged:
                                (value) {
                                  setState(() {
                                    selectedSource = value;
                                  });
                                },
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 recent'), findsOneWidget);
      expect(
        find.textContaining(
          'Added PERSON-44 to flagged faces for SITE-MS-VALLEE-RESIDENCE.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Saved runtime identity rules (1 sites).'),
        findsNothing,
      );

      await tester.tap(find.text('Toggle admin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toggle admin'));
      await tester.pumpAndSettle();

      expect(find.text('Recent Rule Changes'), findsOneWidget);
      expect(find.text('1 recent'), findsOneWidget);
      expect(
        find.textContaining(
          'Added PERSON-44 to flagged faces for SITE-MS-VALLEE-RESIDENCE.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Saved runtime identity rules (1 sites).'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'system tab persists identity rule history expansion through parent-owned remounts',
    (tester) async {
      var auditExpanded = true;
      var showAdmin = true;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        showAdmin = !showAdmin;
                      });
                    },
                    child: const Text('Toggle admin'),
                  ),
                  Expanded(
                    child: showAdmin
                        ? AdministrationPage(
                            events: const <DispatchEvent>[],
                            supabaseReady: false,
                            initialTab: AdministrationPageTab.system,
                            monitoringIdentityPolicyService:
                                const MonitoringIdentityPolicyService(
                                  policiesByScope: {
                                    'CLIENT-MS-VALLEE|SITE-MS-VALLEE-RESIDENCE':
                                        MonitoringIdentityScopePolicy(
                                          flaggedFaceMatchIds: {'PERSON-44'},
                                        ),
                                  },
                                ),
                            initialMonitoringIdentityRuleAuditHistory:
                                <MonitoringIdentityPolicyAuditRecord>[
                                  MonitoringIdentityPolicyAuditRecord(
                                    recordedAtUtc: DateTime.utc(
                                      2026,
                                      3,
                                      15,
                                      7,
                                      14,
                                    ),
                                    source: MonitoringIdentityPolicyAuditSource
                                        .manualEdit,
                                    message:
                                        'Added PERSON-44 to flagged faces for SITE-MS-VALLEE-RESIDENCE.',
                                  ),
                                ],
                            initialMonitoringIdentityRuleAuditExpanded:
                                auditExpanded,
                            onMonitoringIdentityRuleAuditExpandedChanged:
                                (value) {
                                  setState(() {
                                    auditExpanded = value;
                                  });
                                },
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Collapse'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(
        find.textContaining(
          'Added PERSON-44 to flagged faces for SITE-MS-VALLEE-RESIDENCE.',
        ),
        findsOneWidget,
      );

      final auditToggle = find.byKey(const ValueKey('identity-audit-toggle'));
      await tester.ensureVisible(auditToggle);
      await tester.tap(auditToggle);
      await tester.pumpAndSettle();

      expect(auditExpanded, isFalse);
      expect(find.text('Expand'), findsOneWidget);
      expect(find.text('All'), findsNothing);
      expect(
        find.textContaining(
          'Added PERSON-44 to flagged faces for SITE-MS-VALLEE-RESIDENCE.',
        ),
        findsNothing,
      );

      await tester.tap(find.text('Toggle admin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toggle admin'));
      await tester.pumpAndSettle();

      expect(find.text('Recent Rule Changes'), findsOneWidget);
      expect(find.text('Expand'), findsOneWidget);
      expect(find.text('All'), findsNothing);
      expect(
        find.textContaining(
          'Added PERSON-44 to flagged faces for SITE-MS-VALLEE-RESIDENCE.',
        ),
        findsNothing,
      );
    },
  );

  testWidgets('system tab can copy, save, and reset identity rules runtime', (
    tester,
  ) async {
    MonitoringIdentityPolicyService
    currentService = MonitoringIdentityPolicyService.parseJson(
      '[{"client_id":"CLIENT-MS-VALLEE","site_id":"SITE-MS-VALLEE-RESIDENCE","allowed_face_match_ids":["RESIDENT-01"],"flagged_face_match_ids":["PERSON-44"],"allowed_plate_numbers":["CA111111"],"flagged_plate_numbers":["CA123456"]}]',
    );
    MonitoringIdentityPolicyService? savedService;
    var resetCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return AdministrationPage(
              events: const <DispatchEvent>[],
              supabaseReady: false,
              monitoringIdentityPolicyService: currentService,
              initialMonitoringIdentityRulesJson: currentService
                  .toCanonicalJsonString(),
              onMonitoringIdentityPolicyServiceChanged: (value) {
                setState(() {
                  currentService = value;
                });
              },
              onSaveMonitoringIdentityPolicyService: (value) async {
                savedService = value;
              },
              onResetMonitoringIdentityPolicyService: () async {
                resetCount += 1;
                setState(() {
                  currentService = const MonitoringIdentityPolicyService();
                });
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('System').first);
    await tester.pumpAndSettle();

    final copyJsonButton = find.byKey(
      const ValueKey('identity-rules-copy-json'),
    );
    await tester.ensureVisible(copyJsonButton);
    await tester.tap(copyJsonButton);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('identity-rules-save-runtime')));
    await tester.pump();

    expect(savedService, isNotNull);
    expect(
      savedService!
          .policyFor(
            clientId: 'CLIENT-MS-VALLEE',
            siteId: 'SITE-MS-VALLEE-RESIDENCE',
          )
          .flaggedFaceMatchIds,
      contains('PERSON-44'),
    );

    await tester.tap(
      find.byKey(const ValueKey('identity-rules-reset-runtime')),
    );
    await tester.pump();

    expect(resetCount, 1);
    expect(find.text('1 sites'), findsNothing);
  });

  testWidgets('system tab can import identity rules json into runtime', (
    tester,
  ) async {
    MonitoringIdentityPolicyService
    currentService = MonitoringIdentityPolicyService.parseJson(
      '[{"client_id":"CLIENT-MS-VALLEE","site_id":"SITE-MS-VALLEE-RESIDENCE","allowed_face_match_ids":["RESIDENT-01"],"flagged_face_match_ids":["PERSON-44"],"allowed_plate_numbers":["CA111111"],"flagged_plate_numbers":["CA123456"]}]',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return AdministrationPage(
              events: const <DispatchEvent>[],
              supabaseReady: false,
              monitoringIdentityPolicyService: currentService,
              onMonitoringIdentityPolicyServiceChanged: (value) {
                setState(() {
                  currentService = value;
                });
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('System').first);
    await tester.pumpAndSettle();

    final importJsonButton = find.byKey(
      const ValueKey('identity-rules-import-json'),
    );
    await tester.ensureVisible(importJsonButton);
    await tester.tap(importJsonButton);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('identity-rules-import-text-field')),
      '[{"client_id":"CLIENT-BETA","site_id":"SITE-BETA","flagged_face_match_ids":["PERSON-99"],"allowed_plate_numbers":["ZX12345"]}]',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Import'),
      ),
    );
    await tester.pump();

    expect(find.text('2 sites'), findsNothing);
    expect(find.text('1 sites'), findsOneWidget);
    expect(find.text('SITE-BETA'), findsOneWidget);
    expect(find.text('CLIENT-BETA'), findsOneWidget);
    expect(find.text('PERSON-99'), findsOneWidget);
    expect(find.text('ZX12345'), findsOneWidget);
  });

  testWidgets('system tab can import one site policy without replacing others', (
    tester,
  ) async {
    MonitoringIdentityPolicyService
    currentService = MonitoringIdentityPolicyService.parseJson(
      '[{"client_id":"CLIENT-MS-VALLEE","site_id":"SITE-MS-VALLEE-RESIDENCE","allowed_face_match_ids":["RESIDENT-01"],"flagged_face_match_ids":["PERSON-44"],"allowed_plate_numbers":["CA111111"],"flagged_plate_numbers":["CA123456"]},{"client_id":"CLIENT-BETA","site_id":"SITE-BETA","flagged_face_match_ids":["PERSON-99"]}]',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return AdministrationPage(
              events: const <DispatchEvent>[],
              supabaseReady: false,
              monitoringIdentityPolicyService: currentService,
              onMonitoringIdentityPolicyServiceChanged: (value) {
                setState(() {
                  currentService = value;
                });
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('System').first);
    await tester.pumpAndSettle();

    final importSiteButton = find.byKey(
      const ValueKey('identity-rules-import-site-SITE-MS-VALLEE-RESIDENCE'),
    );
    await tester.ensureVisible(importSiteButton);
    await tester.tap(importSiteButton);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(
        const ValueKey('identity-rules-site-import-SITE-MS-VALLEE-RESIDENCE'),
      ),
      '[{"client_id":"CLIENT-MS-VALLEE","site_id":"SITE-MS-VALLEE-RESIDENCE","flagged_face_match_ids":["PERSON-77"],"allowed_plate_numbers":["CA777777"]}]',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Import'),
      ),
    );
    await tester.pump();

    expect(find.text('2 sites'), findsOneWidget);
    expect(find.text('SITE-BETA'), findsOneWidget);
    expect(find.text('PERSON-99'), findsOneWidget);
    expect(find.text('PERSON-77'), findsOneWidget);
    expect(find.text('CA777777'), findsOneWidget);
    expect(find.text('PERSON-44'), findsNothing);
    expect(
      currentService
          .policyFor(clientId: 'CLIENT-BETA', siteId: 'SITE-BETA')
          .flaggedFaceMatchIds,
      contains('PERSON-99'),
    );
  });

  testWidgets('system tab can clear one site policy without replacing others', (
    tester,
  ) async {
    MonitoringIdentityPolicyService
    currentService = MonitoringIdentityPolicyService.parseJson(
      '[{"client_id":"CLIENT-MS-VALLEE","site_id":"SITE-MS-VALLEE-RESIDENCE","allowed_face_match_ids":["RESIDENT-01"],"flagged_face_match_ids":["PERSON-44"],"allowed_plate_numbers":["CA111111"],"flagged_plate_numbers":["CA123456"]},{"client_id":"CLIENT-BETA","site_id":"SITE-BETA","flagged_face_match_ids":["PERSON-99"]}]',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return AdministrationPage(
              events: const <DispatchEvent>[],
              supabaseReady: false,
              monitoringIdentityPolicyService: currentService,
              onMonitoringIdentityPolicyServiceChanged: (value) {
                setState(() {
                  currentService = value;
                });
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('System').first);
    await tester.pumpAndSettle();

    final clearSiteButton = find.byKey(
      const ValueKey('identity-rules-clear-site-SITE-MS-VALLEE-RESIDENCE'),
    );
    await tester.ensureVisible(clearSiteButton);
    await tester.tap(clearSiteButton);
    await tester.pumpAndSettle();

    expect(find.text('Clear Site Identity Rules?'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Clear'),
      ),
    );
    await tester.pump();

    expect(find.text('1 sites'), findsOneWidget);
    expect(find.text('SITE-MS-VALLEE-RESIDENCE'), findsNothing);
    expect(find.text('SITE-BETA'), findsOneWidget);
    expect(find.text('PERSON-99'), findsOneWidget);
    expect(
      currentService
          .policyFor(clientId: 'CLIENT-BETA', siteId: 'SITE-BETA')
          .flaggedFaceMatchIds,
      contains('PERSON-99'),
    );
    expect(
      currentService
          .policyFor(
            clientId: 'CLIENT-MS-VALLEE',
            siteId: 'SITE-MS-VALLEE-RESIDENCE',
          )
          .isEmpty,
      isTrue,
    );
  });

  testWidgets('system tab shows suppressed scene review drill-in entries', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? openedEventsIncidentRef;
    String? openedLedgerIncidentRef;
    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: const <DispatchEvent>[],
          supabaseReady: false,
          cctvOpsPollHealth: 'ok 1 • fail 0 • skip 0 • last 10:05:01 UTC',
          fleetScopeHealth: const <VideoFleetScopeHealthView>[
            VideoFleetScopeHealthView(
              clientId: 'CLIENT-B',
              siteId: 'SITE-B',
              siteName: 'Beta Watch',
              endpointLabel: '192.168.8.106',
              statusLabel: 'WATCH READY',
              watchLabel: 'SCHEDULED',
              recentEvents: 1,
              lastSeenLabel: '21:14 UTC',
              freshnessLabel: 'Recent',
              isStale: false,
              suppressedCount: 1,
              suppressedHistory: [
                '21:10 UTC • Camera 2 • Suppressed because the activity remained below the client notification threshold.',
                '21:08 UTC • Camera 5 • Suppressed because the vehicle path stayed outside the secure boundary.',
              ],
              latestIncidentReference: 'INT-BETA-1',
              latestCameraLabel: 'Camera 2',
              latestSceneDecisionLabel: 'Suppressed',
              latestSceneDecisionSummary:
                  'Suppressed because the activity remained below the client notification threshold.',
            ),
          ],
          sceneReviewByIntelligenceId: <String, MonitoringSceneReviewRecord>{
            'INT-BETA-1': MonitoringSceneReviewRecord(
              intelligenceId: 'INT-BETA-1',
              sourceLabel: 'openai:gpt-4.1-mini',
              postureLabel: 'reviewed',
              decisionLabel: 'Suppressed',
              decisionSummary:
                  'Suppressed because the activity remained below the client notification threshold.',
              summary: 'Vehicle remained below escalation threshold.',
              reviewedAtUtc: DateTime.utc(2026, 3, 13, 21, 14),
            ),
          },
          onOpenEventsForIncident: (incidentRef) {
            openedEventsIncidentRef = incidentRef;
          },
          onOpenLedgerForIncident: (incidentRef) {
            openedLedgerIncidentRef = incidentRef;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('System').first);
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Filtered 1'));
    await tester.pumpAndSettle();
    final beforeTapOffset = scrollable.position.pixels;
    await tester.tap(find.text('Filtered 1'));
    await tester.pumpAndSettle();

    expect(scrollable.position.pixels, greaterThan(beforeTapOffset));
    expect(find.text('Focused watch action: Filtered reviews'), findsOneWidget);
    final textWidgets = tester.widgetList<Text>(find.byType(Text)).toList();
    expect(
      textWidgets.indexWhere(
        (widget) => widget.data == 'Suppressed Scene Reviews',
      ),
      lessThan(
        textWidgets.indexWhere((widget) => widget.data == 'CCTV Fleet Health'),
      ),
    );
    expect(find.text('Suppressed Scene Reviews'), findsOneWidget);
    expect(find.text('1 internal'), findsOneWidget);
    expect(find.text('Beta Watch'), findsWidgets);
    expect(find.text('Action Suppressed'), findsOneWidget);
    expect(find.text('Camera Camera 2'), findsWidgets);
    expect(find.text('Source openai:gpt-4.1-mini'), findsOneWidget);
    expect(find.text('Posture reviewed'), findsOneWidget);
    expect(
      find.textContaining(
        'Recent filtered reviews: 21:10 UTC • Camera 2 • Suppressed because the activity remained below the client notification threshold.',
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.textContaining(
        'Recent filtered reviews: 21:10 UTC • Camera 2 • Suppressed because the activity remained below the client notification threshold.',
      ),
    );
    await tester.pumpAndSettle();
    final beforeSummaryTapOffset = scrollable.position.pixels;
    await tester.tap(
      find.textContaining(
        'Recent filtered reviews: 21:10 UTC • Camera 2 • Suppressed because the activity remained below the client notification threshold.',
      ),
    );
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, lessThan(beforeSummaryTapOffset));
    expect(
      find.textContaining(
        'Suppressed because the activity remained below the client notification threshold.',
      ),
      findsWidgets,
    );
    expect(
      find.text('Scene review: Vehicle remained below escalation threshold.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Events'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Events'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ledger'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ledger'));
    await tester.pumpAndSettle();

    expect(openedEventsIncidentRef, 'INT-BETA-1');
    expect(openedLedgerIncidentRef, 'INT-BETA-1');
  });

  testWidgets(
    'system tab fleet actions pass incident reference and ignore watch-only scopes',
    (tester) async {
      String? tappedTacticalClientId;
      String? tappedTacticalSiteId;
      String? tappedTacticalReference;
      String? tappedDispatchClientId;
      String? tappedDispatchSiteId;
      String? tappedDispatchReference;
      String? recoveredClientId;
      String? recoveredSiteId;

      await tester.pumpWidget(
        MaterialApp(
          home: AdministrationPage(
            events: const <DispatchEvent>[],
            supabaseReady: false,
            cctvOpsPollHealth: 'ok 1 • fail 0 • skip 0 • last 10:05:01 UTC',
            fleetScopeHealth: const <VideoFleetScopeHealthView>[
              VideoFleetScopeHealthView(
                clientId: 'CLIENT-A',
                siteId: 'SITE-A',
                siteName: 'MS Vallee Residence',
                endpointLabel: '192.168.8.105',
                statusLabel: 'LIVE',
                watchLabel: 'ACTIVE',
                recentEvents: 2,
                lastSeenLabel: '21:14 UTC',
                freshnessLabel: 'Fresh',
                isStale: false,
                latestEventLabel: 'Vehicle motion',
                latestIncidentReference: 'INT-VALLEE-1',
                latestEventTimeLabel: '21:14 UTC',
                latestCameraLabel: 'Camera 1',
                latestRiskScore: 84,
                latestFaceMatchId: 'PERSON-44',
                latestFaceConfidence: 91.2,
                latestPlateNumber: 'CA123456',
                latestPlateConfidence: 96.4,
                latestSceneReviewLabel:
                    'openai:gpt-4.1-mini • identity match concern • 21:14 UTC',
                latestSceneDecisionSummary:
                    'Escalated for urgent review because face match PERSON-44 was flagged and the event metadata suggested an unauthorized or watchlist context.',
              ),
              VideoFleetScopeHealthView(
                clientId: 'CLIENT-B',
                siteId: 'SITE-B',
                siteName: 'Beta Watch',
                endpointLabel: '192.168.8.106',
                statusLabel: 'WATCH READY',
                watchLabel: 'SCHEDULED',
                recentEvents: 0,
                lastSeenLabel: 'idle',
                freshnessLabel: 'Idle',
                isStale: false,
                watchWindowLabel: '18:00-06:00',
                watchWindowStateLabel: 'IN WINDOW',
                watchActivationGapLabel: 'MISSED START',
              ),
            ],
            onOpenFleetTacticalScope: (clientId, siteId, incidentReference) {
              tappedTacticalClientId = clientId;
              tappedTacticalSiteId = siteId;
              tappedTacticalReference = incidentReference;
            },
            onOpenFleetDispatchScope: (clientId, siteId, incidentReference) {
              tappedDispatchClientId = clientId;
              tappedDispatchSiteId = siteId;
              tappedDispatchReference = incidentReference;
            },
            onRecoverFleetWatchScope: (clientId, siteId) {
              recoveredClientId = clientId;
              recoveredSiteId = siteId;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('System').first);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('MS Vallee Residence').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('MS Vallee Residence').first);
      await tester.pumpAndSettle();
      expect(tappedTacticalClientId, 'CLIENT-A');
      expect(tappedTacticalSiteId, 'SITE-A');
      expect(tappedTacticalReference, 'INT-VALLEE-1');

      await tester.ensureVisible(find.text('Dispatch').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dispatch').first);
      await tester.pumpAndSettle();
      expect(tappedDispatchClientId, 'CLIENT-A');
      expect(tappedDispatchSiteId, 'SITE-A');
      expect(tappedDispatchReference, 'INT-VALLEE-1');

      tappedTacticalClientId = null;
      tappedTacticalSiteId = null;
      tappedTacticalReference = null;
      await tester.ensureVisible(find.text('Flagged ID 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flagged ID 1'));
      await tester.pumpAndSettle();
      expect(
        find.text('Focused identity policy: Flagged identity matches'),
        findsOneWidget,
      );
      await tester.tap(
        find.textContaining(
          'Flagged identity: Face PERSON-44 91.2% • Plate CA123456 96.4%',
        ),
      );
      await tester.pumpAndSettle();
      expect(tappedTacticalClientId, 'CLIENT-A');
      expect(tappedTacticalSiteId, 'SITE-A');
      expect(tappedTacticalReference, 'INT-VALLEE-1');
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Resync').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resync').first);
      await tester.pumpAndSettle();
      expect(recoveredClientId, 'CLIENT-B');
      expect(recoveredSiteId, 'SITE-B');

      tappedTacticalClientId = null;
      tappedTacticalSiteId = null;
      tappedTacticalReference = null;
      await tester.ensureVisible(find.text('Beta Watch').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beta Watch').first);
      await tester.pumpAndSettle();
      expect(tappedTacticalClientId, isNull);
      expect(tappedTacticalSiteId, isNull);
      expect(tappedTacticalReference, isNull);
    },
  );

  testWidgets('system tab renders telegram visitor proposal queue', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdministrationPage(
          events: const <DispatchEvent>[],
          supabaseReady: false,
          initialTab: AdministrationPageTab.system,
          initialTelegramIdentityIntakes: <TelegramIdentityIntakeRecord>[
            TelegramIdentityIntakeRecord(
              intakeId: 'intake-1',
              clientId: 'CLIENT-MS-VALLEE',
              siteId: 'SITE-MS-VALLEE-RESIDENCE',
              rawText:
                  'John Smith is visiting in a white Hilux CA123456 until 18:00',
              parsedDisplayName: 'John Smith',
              parsedFaceMatchId: 'PERSON-44',
              parsedPlateNumber: 'CA123456',
              category: SiteIdentityCategory.visitor,
              aiConfidence: 0.92,
              approvalState: 'proposed',
              createdAtUtc: DateTime.utc(2026, 3, 15, 10, 45),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Telegram Visitor Proposals'), findsOneWidget);
    expect(find.text('1 pending'), findsOneWidget);
    expect(find.text('John Smith'), findsOneWidget);
    expect(
      find.text('John Smith is visiting in a white Hilux CA123456 until 18:00'),
      findsOneWidget,
    );
    expect(find.text('Allow Once'), findsOneWidget);
    expect(find.text('Always Allow'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
  });

  testWidgets(
    'system tab temporary identity summary opens incident-backed scope detail',
    (tester) async {
      String? tappedTacticalClientId;
      String? tappedTacticalSiteId;
      String? tappedTacticalReference;
      String? extendedSite;
      String? expiredSite;

      await tester.pumpWidget(
        MaterialApp(
          home: AdministrationPage(
            events: const <DispatchEvent>[],
            supabaseReady: false,
            initialTab: AdministrationPageTab.system,
            fleetScopeHealth: const <VideoFleetScopeHealthView>[
              VideoFleetScopeHealthView(
                clientId: 'CLIENT-A',
                siteId: 'SITE-A',
                siteName: 'MS Vallee Residence',
                endpointLabel: '192.168.8.105',
                statusLabel: 'LIVE',
                watchLabel: 'ACTIVE',
                recentEvents: 1,
                lastSeenLabel: '21:14 UTC',
                freshnessLabel: 'Fresh',
                isStale: false,
                latestIncidentReference: 'INT-VALLEE-1',
                latestEventTimeLabel: '21:14 UTC',
                latestCameraLabel: 'Camera 1',
                latestFaceMatchId: 'VISITOR-01',
                latestFaceConfidence: 93.1,
                latestPlateNumber: 'CA777777',
                latestPlateConfidence: 97.4,
                latestSceneReviewLabel:
                    'openai:gpt-4.1-mini • known allowed identity • 21:14 UTC',
                latestSceneDecisionSummary:
                    'Suppressed because the matched identity has a one-time approval until 2026-03-15 18:00 UTC and the activity remained below the client notification threshold.',
              ),
            ],
            onOpenFleetTacticalScope: (clientId, siteId, incidentReference) {
              tappedTacticalClientId = clientId;
              tappedTacticalSiteId = siteId;
              tappedTacticalReference = incidentReference;
            },
            onExtendTemporaryIdentityApproval: (scope) async {
              extendedSite = scope.siteName;
              return 'Extended ${scope.siteName}.';
            },
            onExpireTemporaryIdentityApproval: (scope) async {
              expiredSite = scope.siteName;
              return 'Expired ${scope.siteName}.';
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Temporary ID 1'), findsOneWidget);
      expect(
        find.textContaining(
          'Identity policy: Temporary approval until 2026-03-15 18:00 UTC',
        ),
        findsOneWidget,
      );
      expect(find.text('Identity Temporary'), findsOneWidget);
      await tester.ensureVisible(find.text('Temporary ID 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Temporary ID 1'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.text('Focused identity policy: Temporary identity approvals'),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Extend 2h'));
      await tester.pumpAndSettle();
      expect(
        find.text('Focused identity policy: Temporary identity approvals'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Showing fleet scopes where ONYX matched a one-time approved face or plate.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Soonest expiry: MS Vallee Residence'),
        findsOneWidget,
      );
      expect(find.text('Extend 2h'), findsOneWidget);
      expect(find.text('Expire now'), findsOneWidget);
      await tester.tap(find.text('Extend 2h'));
      await tester.pumpAndSettle();
      expect(extendedSite, 'MS Vallee Residence');
      await tester.tap(find.text('Expire now'));
      await tester.pumpAndSettle();
      expect(find.text('Expire Temporary Approval?'), findsOneWidget);
      expect(
        find.textContaining(
          'This immediately removes the temporary identity approval for MS Vallee Residence.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Expire now'));
      await tester.pumpAndSettle();
      expect(expiredSite, 'MS Vallee Residence');
      await tester.ensureVisible(
        find.textContaining(
          'Temporary identity until 2026-03-15 18:00 UTC: Face VISITOR-01 93.1% • Plate CA777777 97.4%',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.textContaining(
          'Temporary identity until 2026-03-15 18:00 UTC: Face VISITOR-01 93.1% • Plate CA777777 97.4%',
        ),
      );
      await tester.pumpAndSettle();
      expect(tappedTacticalClientId, 'CLIENT-A');
      expect(tappedTacticalSiteId, 'SITE-A');
      expect(tappedTacticalReference, 'INT-VALLEE-1');
    },
  );

  testWidgets(
    'system tab allowlisted identity summary opens incident-backed scope detail',
    (tester) async {
      String? tappedTacticalClientId;
      String? tappedTacticalSiteId;
      String? tappedTacticalReference;

      await tester.pumpWidget(
        MaterialApp(
          home: AdministrationPage(
            events: const <DispatchEvent>[],
            supabaseReady: false,
            initialTab: AdministrationPageTab.system,
            fleetScopeHealth: const <VideoFleetScopeHealthView>[
              VideoFleetScopeHealthView(
                clientId: 'CLIENT-A',
                siteId: 'SITE-A',
                siteName: 'MS Vallee Residence',
                endpointLabel: '192.168.8.105',
                statusLabel: 'LIVE',
                watchLabel: 'ACTIVE',
                recentEvents: 1,
                lastSeenLabel: '21:14 UTC',
                freshnessLabel: 'Fresh',
                isStale: false,
                latestIncidentReference: 'INT-VALLEE-1',
                latestEventTimeLabel: '21:14 UTC',
                latestCameraLabel: 'Camera 1',
                latestFaceMatchId: 'RESIDENT-01',
                latestFaceConfidence: 94.1,
                latestPlateNumber: 'CA111111',
                latestPlateConfidence: 98.0,
                latestSceneReviewLabel:
                    'openai:gpt-4.1-mini • known allowed identity • 21:14 UTC',
                latestSceneDecisionSummary:
                    'Suppressed because RESIDENT-01 and plate CA111111 are allowlisted for this site.',
              ),
            ],
            onOpenFleetTacticalScope: (clientId, siteId, incidentReference) {
              tappedTacticalClientId = clientId;
              tappedTacticalSiteId = siteId;
              tappedTacticalReference = incidentReference;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Allowed ID 1'), findsOneWidget);
      expect(find.text('Identity Allowlisted'), findsOneWidget);
      await tester.ensureVisible(find.text('Allowed ID 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allowed ID 1'));
      await tester.pumpAndSettle();
      expect(
        find.text('Focused identity policy: Allowlisted identity matches'),
        findsOneWidget,
      );
      await tester.tap(
        find.textContaining(
          'Allowlisted identity: Face RESIDENT-01 94.1% • Plate CA111111 98.0%',
        ),
      );
      await tester.pumpAndSettle();
      expect(tappedTacticalClientId, 'CLIENT-A');
      expect(tappedTacticalSiteId, 'SITE-A');
      expect(tappedTacticalReference, 'INT-VALLEE-1');
    },
  );
}
