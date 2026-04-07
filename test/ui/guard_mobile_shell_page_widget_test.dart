import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/guard/guard_ops_event.dart';
import 'package:omnix_dashboard/domain/guard/guard_mobile_ops.dart';
import 'package:omnix_dashboard/domain/guard/outcome_label_governance.dart';
import 'package:omnix_dashboard/domain/guard/guard_sync_coaching_policy.dart';
import 'package:omnix_dashboard/ui/guard_mobile_shell_page.dart';

void _mockClipboard(
  WidgetTester tester, {
  void Function(String? text)? onCopy,
}) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        final args = call.arguments as Map<dynamic, dynamic>;
        onCopy?.call(args['text'] as String?);
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
}

DateTime _guardMobileShellMarch5AtUtc(int hour, int minute, [int second = 0]) =>
    DateTime.utc(2026, 3, 5, hour, minute, second);

DateTime _guardMobileShellMarch4AtUtc(int hour, int minute, [int second = 0]) =>
    DateTime.utc(2026, 3, 4, hour, minute, second);

DateTime _guardMobileShellMarch11AtUtc(
  int hour,
  int minute, [
  int second = 0,
]) => DateTime.utc(2026, 3, 11, hour, minute, second);

DateTime _guardMobileShellNowUtc() => DateTime.now().toUtc();

void main() {
  testWidgets('guard mobile shell stays stable on phone viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: GuardMobileShellPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          guardId: 'GUARD-001',
          syncBackendEnabled: true,
          queueDepth: 0,
          pendingEventCount: 0,
          pendingMediaCount: 0,
          failedEventCount: 0,
          failedMediaCount: 0,
          recentEvents: const [],
          recentMedia: const [],
          syncInFlight: false,
          syncStatusLabel: null,
          lastSuccessfulSyncAtUtc: null,
          lastFailureReason: null,
          coachingPrompt: const GuardCoachingPrompt(
            ruleId: 'phone_stability',
            headline: 'Phone Stability',
            message: 'Phone viewport render smoke test.',
            priority: GuardCoachingPriority.low,
          ),
          coachingPolicy: const GuardSyncCoachingPolicy(),
          queuedOperations: const [],
          historyFilter: GuardSyncHistoryFilter.queued,
          onHistoryFilterChanged: (_) async {},
          operationModeFilter: GuardSyncOperationModeFilter.all,
          onOperationModeFilterChanged: (_) async {},
          onFacadeIdFilterChanged: (_) async {},
          onSelectedOperationChanged: (_) async {},
          onShiftStartQueued: () async {},
          onShiftEndQueued: () async {},
          onStatusQueued: (_) async {},
          onCheckpointQueued:
              ({required checkpointId, required nfcTagId}) async {},
          onPatrolImageQueued: ({required checkpointId}) async {},
          onPanicQueued: () async {},
          onWearableHeartbeatQueued: () async {},
          onDeviceHealthQueued: () async {},
          onOutcomeLabeled:
              ({
                required outcomeLabel,
                required confidence,
                required confirmedBy,
              }) async {},
          outcomeGovernancePolicy: OutcomeLabelGovernancePolicy.defaultPolicy(),
          onClearQueue: () async {},
          onSyncNow: () async {},
          onRetryFailedEvents: () async {},
          onRetryFailedMedia: () async {},
          onRetryFailedOperation: (_) async {},
          onRetryFailedOperationsBulk: (_) async {},
          onDispatchCloseoutPacketCopied:
              ({
                required generatedAtUtc,
                required scopeKey,
                required facadeMode,
                required readinessState,
              }) async {},
          onProbeTelemetryProvider: () async {},
          onAcknowledgeCoachingPrompt:
              ({required ruleId, required context}) async {},
          onSnoozeCoachingPrompt:
              ({
                required ruleId,
                required context,
                required minutes,
                required actorRole,
              }) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Android Guard App Shell'), findsOneWidget);
    expect(find.text('Guard Screen Flow'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guard-only experience hides advanced sync workspace', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: GuardMobileShellPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          guardId: 'GUARD-001',
          guardOnlyExperience: true,
          syncBackendEnabled: true,
          queueDepth: 0,
          pendingEventCount: 0,
          pendingMediaCount: 0,
          failedEventCount: 0,
          failedMediaCount: 0,
          recentEvents: const [],
          recentMedia: const [],
          syncInFlight: false,
          syncStatusLabel: 'Sync idle',
          lastSuccessfulSyncAtUtc: null,
          lastFailureReason: null,
          coachingPrompt: const GuardCoachingPrompt(
            ruleId: 'guard_only',
            headline: 'Guard Only',
            message: 'Render a streamlined field view.',
            priority: GuardCoachingPriority.low,
          ),
          coachingPolicy: const GuardSyncCoachingPolicy(),
          queuedOperations: const [],
          historyFilter: GuardSyncHistoryFilter.queued,
          onHistoryFilterChanged: (_) async {},
          operationModeFilter: GuardSyncOperationModeFilter.all,
          onOperationModeFilterChanged: (_) async {},
          onFacadeIdFilterChanged: (_) async {},
          onSelectedOperationChanged: (_) async {},
          onShiftStartQueued: () async {},
          onShiftEndQueued: () async {},
          onStatusQueued: (_) async {},
          onCheckpointQueued:
              ({required checkpointId, required nfcTagId}) async {},
          onPatrolImageQueued: ({required checkpointId}) async {},
          onPanicQueued: () async {},
          onWearableHeartbeatQueued: () async {},
          onDeviceHealthQueued: () async {},
          onOutcomeLabeled:
              ({
                required outcomeLabel,
                required confidence,
                required confirmedBy,
              }) async {},
          outcomeGovernancePolicy: OutcomeLabelGovernancePolicy.defaultPolicy(),
          onClearQueue: () async {},
          onSyncNow: () async {},
          onRetryFailedEvents: () async {},
          onRetryFailedMedia: () async {},
          onRetryFailedOperation: (_) async {},
          onRetryFailedOperationsBulk: (_) async {},
          onDispatchCloseoutPacketCopied:
              ({
                required generatedAtUtc,
                required scopeKey,
                required facadeMode,
                required readinessState,
              }) async {},
          onProbeTelemetryProvider: () async {},
          onAcknowledgeCoachingPrompt:
              ({required ruleId, required context}) async {},
          onSnoozeCoachingPrompt:
              ({
                required ruleId,
                required context,
                required minutes,
                required actorRole,
              }) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Guard Field App'), findsOneWidget);
    expect(find.textContaining('Sync History ('), findsNothing);
    expect(find.text('Reaction Ops'), findsNothing);
    expect(find.text('Supervisor Ops'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guard mobile shell stays stable on landscape phone viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: GuardMobileShellPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          guardId: 'GUARD-001',
          syncBackendEnabled: true,
          queueDepth: 0,
          pendingEventCount: 0,
          pendingMediaCount: 0,
          failedEventCount: 0,
          failedMediaCount: 0,
          recentEvents: const [],
          recentMedia: const [],
          syncInFlight: false,
          syncStatusLabel: null,
          lastSuccessfulSyncAtUtc: null,
          lastFailureReason: null,
          coachingPrompt: const GuardCoachingPrompt(
            ruleId: 'phone_stability_landscape',
            headline: 'Phone Stability',
            message: 'Landscape phone viewport render smoke test.',
            priority: GuardCoachingPriority.low,
          ),
          coachingPolicy: const GuardSyncCoachingPolicy(),
          queuedOperations: const [],
          historyFilter: GuardSyncHistoryFilter.queued,
          onHistoryFilterChanged: (_) async {},
          operationModeFilter: GuardSyncOperationModeFilter.all,
          onOperationModeFilterChanged: (_) async {},
          onFacadeIdFilterChanged: (_) async {},
          onSelectedOperationChanged: (_) async {},
          onShiftStartQueued: () async {},
          onShiftEndQueued: () async {},
          onStatusQueued: (_) async {},
          onCheckpointQueued:
              ({required checkpointId, required nfcTagId}) async {},
          onPatrolImageQueued: ({required checkpointId}) async {},
          onPanicQueued: () async {},
          onWearableHeartbeatQueued: () async {},
          onDeviceHealthQueued: () async {},
          onOutcomeLabeled:
              ({
                required outcomeLabel,
                required confidence,
                required confirmedBy,
              }) async {},
          outcomeGovernancePolicy: OutcomeLabelGovernancePolicy.defaultPolicy(),
          onClearQueue: () async {},
          onSyncNow: () async {},
          onRetryFailedEvents: () async {},
          onRetryFailedMedia: () async {},
          onRetryFailedOperation: (_) async {},
          onRetryFailedOperationsBulk: (_) async {},
          onDispatchCloseoutPacketCopied:
              ({
                required generatedAtUtc,
                required scopeKey,
                required facadeMode,
                required readinessState,
              }) async {},
          onProbeTelemetryProvider: () async {},
          onAcknowledgeCoachingPrompt:
              ({required ruleId, required context}) async {},
          onSnoozeCoachingPrompt:
              ({
                required ruleId,
                required context,
                required minutes,
                required actorRole,
              }) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Android Guard App Shell'), findsOneWidget);
    expect(find.text('Guard Screen Flow'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guard mobile shell exposes workspace rail actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    GuardSyncHistoryFilter? lastHistoryFilter;
    String? lastSelectedOperationId;

    await tester.pumpWidget(
      MaterialApp(
        home: GuardMobileShellPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          guardId: 'GUARD-001',
          syncBackendEnabled: true,
          queueDepth: 2,
          pendingEventCount: 1,
          pendingMediaCount: 1,
          failedEventCount: 1,
          failedMediaCount: 0,
          recentEvents: const [],
          recentMedia: const [],
          syncInFlight: false,
          syncStatusLabel: 'Sync idle',
          coachingPrompt: const GuardCoachingPrompt(
            ruleId: 'workspace_shell',
            headline: 'Workspace Shell',
            message: 'Exercise the new rail and context actions.',
            priority: GuardCoachingPriority.low,
          ),
          coachingPolicy: const GuardSyncCoachingPolicy(),
          queuedOperations: [
            GuardSyncOperation(
              operationId: 'status:1',
              type: GuardSyncOperationType.statusUpdate,
              createdAt: _guardMobileShellMarch5AtUtc(10, 0),
              payload: const {
                'status': 'enRoute',
                'onyx_runtime_context': {
                  'telemetry_adapter_label': 'native_sdk:fsk_sdk',
                  'telemetry_facade_id': 'fsk_live',
                  'telemetry_facade_live_mode': true,
                  'telemetry_facade_toggle_source': 'build_config',
                },
              },
            ),
          ],
          historyFilter: GuardSyncHistoryFilter.queued,
          onHistoryFilterChanged: (filter) async {
            lastHistoryFilter = filter;
          },
          operationModeFilter: GuardSyncOperationModeFilter.all,
          onOperationModeFilterChanged: (_) async {},
          availableFacadeIds: const ['fsk_live'],
          onFacadeIdFilterChanged: (_) async {},
          onSelectedOperationChanged: (operationId) async {
            lastSelectedOperationId = operationId;
          },
          onShiftStartQueued: () async {},
          onShiftEndQueued: () async {},
          onStatusQueued: (_) async {},
          onCheckpointQueued:
              ({required checkpointId, required nfcTagId}) async {},
          onPatrolImageQueued: ({required checkpointId}) async {},
          onPanicQueued: () async {},
          onWearableHeartbeatQueued: () async {},
          onDeviceHealthQueued: () async {},
          onOutcomeLabeled:
              ({
                required outcomeLabel,
                required confidence,
                required confirmedBy,
              }) async {},
          outcomeGovernancePolicy: OutcomeLabelGovernancePolicy.defaultPolicy(),
          onClearQueue: () async {},
          onSyncNow: () async {},
          onRetryFailedEvents: () async {},
          onRetryFailedMedia: () async {},
          onRetryFailedOperation: (_) async {},
          onRetryFailedOperationsBulk: (_) async {},
          onDispatchCloseoutPacketCopied:
              ({
                required generatedAtUtc,
                required scopeKey,
                required facadeMode,
                required readinessState,
              }) async {},
          onProbeTelemetryProvider: () async {},
          onAcknowledgeCoachingPrompt:
              ({required ruleId, required context}) async {},
          onSnoozeCoachingPrompt:
              ({
                required ruleId,
                required context,
                required minutes,
                required actorRole,
              }) async {},
          lastSuccessfulSyncAtUtc: _guardMobileShellMarch5AtUtc(9, 55),
          lastFailureReason: 'network timeout',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('guard-workspace-rail')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('guard-workspace-context')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('guard-sync-operations-list')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('guard-screen-card-sync')),
    );
    await tester.tap(find.byKey(const ValueKey('guard-screen-card-sync')));
    await tester.pumpAndSettle();
    expect(find.text('Sync Status'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('guard-workspace-focus-dispatch')),
    );
    await tester.tap(
      find.byKey(const ValueKey('guard-workspace-focus-dispatch')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dispatch Inbox'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('guard-workspace-focus-failed')),
    );
    await tester.tap(
      find.byKey(const ValueKey('guard-workspace-focus-failed')),
    );
    await tester.pumpAndSettle();
    expect(lastHistoryFilter, GuardSyncHistoryFilter.failed);
    expect(find.text('Sync Status'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('guard-history-operation-status:1')),
    );
    await tester.tap(
      find.byKey(const ValueKey('guard-history-operation-status:1')),
    );
    await tester.pumpAndSettle();
    expect(lastSelectedOperationId, 'status:1');
    expect(
      find.byKey(const ValueKey('guard-sync-operation-detail')),
      findsOneWidget,
    );
  });

  testWidgets('guard mobile shell routes actions into callbacks', (
    tester,
  ) async {
    _mockClipboard(tester);

    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    GuardDutyStatus? lastStatus;
    String? lastCheckpointId;
    String? lastTagId;
    String? lastPatrolImageCheckpointId;
    var panicCount = 0;
    var clearCount = 0;
    var shiftStartCount = 0;
    var shiftEndCount = 0;
    var syncNowCount = 0;
    var retryFailedEventsCount = 0;
    var retryFailedMediaCount = 0;
    var retryFailedOperationCount = 0;
    var telemetryProbeCount = 0;
    var wearableHeartbeatCount = 0;
    var deviceHealthCount = 0;
    var wearableBridgeSeedCount = 0;
    var debugSdkHeartbeatEmitCount = 0;
    var clearExportAuditsCount = 0;
    var acknowledgedPromptCount = 0;
    var snoozedPromptCount = 0;
    String? lastOutcomeLabel;
    String? lastOutcomeConfidence;
    String? lastOutcomeConfirmedBy;
    final nowUtc = _guardMobileShellNowUtc();

    await tester.pumpWidget(
      MaterialApp(
        home: GuardMobileShellPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          guardId: 'GUARD-001',
          syncBackendEnabled: true,
          queueDepth: 1,
          pendingEventCount: 2,
          pendingMediaCount: 1,
          failedEventCount: 1,
          failedMediaCount: 1,
          recentEvents: [
            GuardOpsEvent(
              eventId: 'EVT-1',
              guardId: 'GUARD-001',
              siteId: 'SITE-SANDTON',
              shiftId: 'SHIFT-1',
              eventType: GuardOpsEventType.statusChanged,
              sequence: 1,
              occurredAt: _guardMobileShellMarch4AtUtc(18, 1),
              syncedAt: _guardMobileShellMarch4AtUtc(18, 2),
              deviceId: 'DEVICE-1',
              appVersion: '1.0.0',
              payload: const {'status': 'onSite'},
            ),
            GuardOpsEvent(
              eventId: 'EVT-2',
              guardId: 'GUARD-001',
              siteId: 'SITE-SANDTON',
              shiftId: 'SHIFT-1',
              eventType: GuardOpsEventType.panicTriggered,
              sequence: 2,
              occurredAt: _guardMobileShellMarch4AtUtc(18, 3),
              deviceId: 'DEVICE-1',
              appVersion: '1.0.0',
              payload: const {'level': 'critical', 'source': 'manual'},
              retryCount: 2,
              failureReason: 'network unavailable',
            ),
          ],
          recentMedia: [
            GuardOpsMediaUpload(
              mediaId: 'MEDIA-1',
              eventId: 'EVT-1',
              guardId: 'GUARD-001',
              siteId: 'SITE-SANDTON',
              shiftId: 'SHIFT-1',
              bucket: 'guard-patrol-images',
              path: 'guards/GUARD-001/patrol/test.jpg',
              localPath: '/tmp/test.jpg',
              capturedAt: _guardMobileShellMarch4AtUtc(18, 1),
              status: GuardMediaUploadStatus.uploaded,
            ),
            GuardOpsMediaUpload(
              mediaId: 'MEDIA-2',
              eventId: 'EVT-2',
              guardId: 'GUARD-001',
              siteId: 'SITE-SANDTON',
              shiftId: 'SHIFT-1',
              bucket: 'guard-incident-media',
              path: 'guards/GUARD-001/incident/evidence.jpg',
              localPath: '/tmp/evidence.jpg',
              capturedAt: _guardMobileShellMarch4AtUtc(18, 3),
              status: GuardMediaUploadStatus.failed,
              retryCount: 3,
              failureReason: 'upload timeout',
            ),
          ],
          syncInFlight: false,
          syncStatusLabel: 'Sync idle',
          activeShiftId: 'SHIFT-1',
          activeShiftSequenceWatermark: 27,
          telemetryAdapterLabel: 'native_sdk:fsk_sdk',
          telemetryAdapterStubMode: false,
          telemetryProviderStatusLabel: 'Native provider connected.',
          telemetryProviderReadiness: 'ready',
          telemetryFacadeId: 'fsk_sdk_facade_live',
          telemetryFacadeLiveMode: true,
          telemetryFacadeToggleSource: 'build_config',
          telemetryFacadeRuntimeMode: 'live',
          telemetryFacadeHeartbeatSource: 'android_broadcast',
          telemetryFacadeHeartbeatAction: 'com.onyx.fsk.SDK_HEARTBEAT',
          telemetryVendorConnectorId: 'broadcast_intent_connector',
          telemetryVendorConnectorSource: 'platform_default',
          telemetryVendorConnectorFallbackActive: true,
          telemetryVendorConnectorErrorMessage:
              'Failed to initialize vendor connector com.onyx.vendor.MissingConnector.',
          telemetryFacadeSourceActive: true,
          telemetryFacadeCallbackCount: 4,
          telemetryFacadeLastCallbackAtUtc: nowUtc.subtract(
            const Duration(minutes: 1),
          ),
          telemetryFacadeLastCallbackMessage:
              'Wearable heartbeat bridge payload ingested.',
          telemetryFacadeCallbackErrorCount: 1,
          telemetryFacadeLastCallbackErrorAtUtc: nowUtc.subtract(
            const Duration(minutes: 5),
          ),
          telemetryFacadeLastCallbackErrorMessage:
              'SDK callback rejected: captured_at_utc is invalid ISO-8601',
          lastSuccessfulSyncAtUtc: _guardMobileShellMarch4AtUtc(18, 0),
          lastFailureReason: 'network unavailable',
          coachingPrompt: const GuardCoachingPrompt(
            ruleId: 'high_failure_backlog',
            headline: 'Resolve Sync Failures',
            message: 'Retry failed rows and confirm network quality.',
            priority: GuardCoachingPriority.high,
          ),
          coachingPolicy: const GuardSyncCoachingPolicy(),
          queuedOperations: [
            GuardSyncOperation(
              operationId: 'status:1',
              type: GuardSyncOperationType.statusUpdate,
              createdAt: _guardMobileShellMarch4AtUtc(10, 0),
              payload: const {
                'status': 'enRoute',
                'onyx_runtime_context': {
                  'telemetry_adapter_label': 'native_sdk:fsk_sdk',
                  'telemetry_facade_id': 'fsk_sdk_facade_operation_live',
                  'telemetry_facade_live_mode': true,
                  'telemetry_facade_toggle_source': 'build_config',
                },
              },
            ),
          ],
          historyFilter: GuardSyncHistoryFilter.queued,
          onHistoryFilterChanged: (_) async {},
          operationModeFilter: GuardSyncOperationModeFilter.all,
          onOperationModeFilterChanged: (_) async {},
          availableFacadeIds: const ['fsk_sdk_facade_operation_live'],
          selectedFacadeId: null,
          onFacadeIdFilterChanged: (_) async {},
          scopedSelectionCount: 1,
          scopedSelectionKeys: const ['queued|all|all_facades'],
          scopedSelectionsByScope: const {'queued|all|all_facades': 'status:1'},
          activeScopeKey: 'queued|all|all_facades',
          activeScopeHasSelection: true,
          initialSelectedOperationId: null,
          onSelectedOperationChanged: (_) async {},
          onStatusQueued: (status) async {
            lastStatus = status;
          },
          onShiftStartQueued: () async {
            shiftStartCount += 1;
          },
          onShiftEndQueued: () async {
            shiftEndCount += 1;
          },
          onCheckpointQueued:
              ({required checkpointId, required nfcTagId}) async {
                lastCheckpointId = checkpointId;
                lastTagId = nfcTagId;
              },
          onPatrolImageQueued: ({required checkpointId}) async {
            lastPatrolImageCheckpointId = checkpointId;
          },
          onPanicQueued: () async {
            panicCount += 1;
          },
          onWearableHeartbeatQueued: () async {
            wearableHeartbeatCount += 1;
          },
          onDeviceHealthQueued: () async {
            deviceHealthCount += 1;
          },
          onSeedWearableBridge: () async {
            wearableBridgeSeedCount += 1;
          },
          onEmitTelemetryDebugHeartbeat: () async {
            debugSdkHeartbeatEmitCount += 1;
          },
          onOutcomeLabeled:
              ({
                required outcomeLabel,
                required confidence,
                required confirmedBy,
              }) async {
                lastOutcomeLabel = outcomeLabel;
                lastOutcomeConfidence = confidence;
                lastOutcomeConfirmedBy = confirmedBy;
              },
          onClearQueue: () async {
            clearCount += 1;
          },
          onSyncNow: () async {
            syncNowCount += 1;
          },
          onRetryFailedEvents: () async {
            retryFailedEventsCount += 1;
          },
          onRetryFailedMedia: () async {
            retryFailedMediaCount += 1;
          },
          onRetryFailedOperation: (_) async {
            retryFailedOperationCount += 1;
          },
          onRetryFailedOperationsBulk: (_) async {},
          onDispatchCloseoutPacketCopied:
              ({
                required generatedAtUtc,
                required scopeKey,
                required facadeMode,
                required readinessState,
              }) async {},
          onClearExportAudits: () async {
            clearExportAuditsCount += 1;
          },
          onProbeTelemetryProvider: () async {
            telemetryProbeCount += 1;
          },
          onAcknowledgeCoachingPrompt:
              ({required ruleId, required context}) async {
                acknowledgedPromptCount += 1;
              },
          onSnoozeCoachingPrompt:
              ({
                required ruleId,
                required context,
                required minutes,
                required actorRole,
              }) async {
                snoozedPromptCount += 1;
              },
          outcomeGovernancePolicy: OutcomeLabelGovernancePolicy.defaultPolicy(),
        ),
      ),
    );

    expect(find.text('Android Guard App Shell'), findsOneWidget);
    expect(find.text('statusUpdate'), findsOneWidget);
    expect(find.text('Sync idle'), findsOneWidget);
    expect(find.text('Coaching Prompt • DISPATCH'), findsOneWidget);
    expect(find.text('Resolve Sync Failures'), findsOneWidget);
    expect(find.text('Guard Snooze Blocked'), findsOneWidget);
    expect(find.text('Supervisor Override Snooze'), findsOneWidget);
    await tester.tap(find.text('Acknowledge Prompt').first);
    await tester.pumpAndSettle();
    expect(acknowledgedPromptCount, 1);
    await tester.tap(find.text('Supervisor Override Snooze').first);
    await tester.pumpAndSettle();
    expect(snoozedPromptCount, 1);

    final shiftStartChip = find.widgetWithText(ChoiceChip, 'Shift Start').first;
    await tester.ensureVisible(shiftStartChip);
    await tester.tap(shiftStartChip);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Capture + Start Shift'));
    await tester.pumpAndSettle();
    expect(shiftStartCount, 1);

    final statusChip = find.widgetWithText(ChoiceChip, 'Status').first;
    await tester.ensureVisible(statusChip);
    await tester.tap(statusChip);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('On Site'));
    await tester.tap(find.text('On Site'));
    await tester.pumpAndSettle();
    expect(lastStatus, GuardDutyStatus.onSite);

    final checkpointChip = find.widgetWithText(ChoiceChip, 'Checkpoint').first;
    await tester.ensureVisible(checkpointChip);
    await tester.tap(checkpointChip, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Coaching Prompt • CHECKPOINT'), findsOneWidget);
    await tester.ensureVisible(find.byType(TextFormField).first);
    await tester.enterText(find.byType(TextFormField).at(0), 'GATE-3');
    await tester.enterText(find.byType(TextFormField).at(1), 'NFC-99');
    await tester.ensureVisible(find.text('Queue Checkpoint Scan'));
    await tester.tap(find.text('Queue Checkpoint Scan'));
    await tester.pumpAndSettle();
    expect(lastCheckpointId, 'GATE-3');
    expect(lastTagId, 'NFC-99');
    await tester.tap(find.text('Queue Patrol Image'));
    await tester.pumpAndSettle();
    expect(lastPatrolImageCheckpointId, 'GATE-3');

    final panicChip = find.widgetWithText(ChoiceChip, 'Panic').first;
    await tester.ensureVisible(panicChip);
    await tester.tap(panicChip);
    await tester.pumpAndSettle();
    await tester.tap(find.text('High'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Control'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trigger Panic'));
    await tester.pumpAndSettle();
    expect(panicCount, 1);
    await tester.tap(find.text('Label: False Alarm'));
    await tester.pumpAndSettle();
    expect(lastOutcomeLabel, 'false_alarm');
    expect(lastOutcomeConfidence, 'high');
    expect(lastOutcomeConfirmedBy, 'control');
    await tester.tap(find.text('Label: True Threat'));
    await tester.pumpAndSettle();
    expect(lastOutcomeLabel, 'false_alarm');
    expect(
      find.textContaining('Guard action failed: Bad state:'),
      findsOneWidget,
    );

    await tester.ensureVisible(shiftStartChip);
    await tester.tap(shiftStartChip);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Queue Shift End'));
    await tester.pumpAndSettle();
    expect(shiftEndCount, 1);

    await tester.ensureVisible(find.text('Clear Queue'));
    await tester.tap(find.text('Clear Queue'));
    await tester.pumpAndSettle();
    expect(clearCount, 1);

    final syncChip = find.widgetWithText(ChoiceChip, 'Sync').first;
    await tester.ensureVisible(syncChip);
    await tester.tap(syncChip);
    await tester.pumpAndSettle();
    expect(
      find.text('Telemetry adapter: native_sdk:fsk_sdk (live)'),
      findsOneWidget,
    );
    expect(
      find.text('Provider readiness: ready • Native provider connected.'),
      findsOneWidget,
    );
    expect(find.text('Active Shift: SHIFT-1'), findsOneWidget);
    expect(find.text('Shift Seq Watermark: 27'), findsOneWidget);
    expect(find.text('Shift Events: 2'), findsOneWidget);
    expect(find.text('Shift Media: 2'), findsOneWidget);
    expect(find.text('Shift Pending: 0'), findsOneWidget);
    expect(find.text('Shift Failed: 2'), findsOneWidget);
    expect(find.text('Shift Closed: no'), findsOneWidget);
    expect(find.text('Closeout Ready: blocked'), findsOneWidget);
    expect(find.text('Shift Lifecycle: no shift activity'), findsOneWidget);
    expect(find.text('Open Shift Age: none'), findsOneWidget);
    expect(find.text('Last Export Audit Reset: none'), findsOneWidget);
    expect(find.text('Export Audit Resets: 0'), findsOneWidget);
    expect(find.text('Last Export Audit Generated: none'), findsOneWidget);
    expect(find.text('Export Gen/Clear Ratio: 0.00'), findsOneWidget);
    expect(find.text('Export Health Verdict: Healthy'), findsOneWidget);
    expect(
      find.text('Export health reason: no export activity yet'),
      findsOneWidget,
    );
    expect(find.textContaining('Export health thresholds:'), findsOneWidget);
    expect(find.text('Sync Report Exports: 0'), findsOneWidget);
    expect(find.text('Replay Exports: 0'), findsOneWidget);
    expect(find.text('Closeout Exports: 0'), findsOneWidget);
    expect(find.text('Export Audit Timeline'), findsOneWidget);
    expect(find.text('Copy Export Audit Timeline'), findsOneWidget);
    expect(find.text('Copy Telemetry Alerts Only'), findsOneWidget);
    expect(find.text('Generated: 0'), findsOneWidget);
    expect(find.text('Cleared: 0'), findsOneWidget);
    expect(find.text('Verification: 0'), findsOneWidget);
    expect(find.text('none yet'), findsOneWidget);
    expect(find.text('Facade: fsk_sdk_facade_live'), findsOneWidget);
    expect(find.text('Mode: live'), findsOneWidget);
    expect(find.text('Toggle: build_config'), findsOneWidget);
    expect(find.text('Runtime: live'), findsOneWidget);
    expect(find.text('Heartbeat Source: android_broadcast'), findsOneWidget);
    expect(find.text('Connector: broadcast_intent_connector'), findsOneWidget);
    expect(find.text('Connector Source: platform_default'), findsOneWidget);
    expect(find.text('Connector Fallback: active'), findsOneWidget);
    expect(find.text('Source Active: yes'), findsOneWidget);
    expect(find.text('SDK Callbacks: 4'), findsOneWidget);
    expect(find.textContaining('Callback Age:'), findsOneWidget);
    expect(
      find.text('Heartbeat action: com.onyx.fsk.SDK_HEARTBEAT'),
      findsOneWidget,
    );
    expect(
      find.text('Facade message: Wearable heartbeat bridge payload ingested.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Vendor connector error: Failed to initialize vendor connector com.onyx.vendor.MissingConnector.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Last SDK callback:'), findsOneWidget);
    expect(find.text('Telemetry Verification Checklist'), findsOneWidget);
    expect(find.text('Callback seen: pass'), findsOneWidget);
    expect(find.text('Callback fresh (<=2m): pass'), findsOneWidget);
    expect(
      find.text('Op Facade: fsk_sdk_facade_operation_live'),
      findsOneWidget,
    );
    expect(find.text('Live Ops: 1'), findsOneWidget);
    expect(find.text('Stub Ops: 0'), findsOneWidget);
    expect(find.text('Unknown Ops: 0'), findsOneWidget);
    expect(
      find.textContaining('Operational Coaching • high_failure_backlog'),
      findsOneWidget,
    );
    expect(find.text('Resolve Sync Failures'), findsOneWidget);
    await tester.ensureVisible(find.text('Acknowledge Prompt').first);
    await tester.tap(find.text('Acknowledge Prompt').first);
    await tester.pumpAndSettle();
    expect(acknowledgedPromptCount, 2);
    await tester.ensureVisible(find.text('Supervisor Override Snooze').first);
    await tester.tap(find.text('Supervisor Override Snooze').first);
    await tester.pumpAndSettle();
    expect(snoozedPromptCount, 2);
    await tester.ensureVisible(find.text('Sync Now'));
    await tester.tap(find.text('Sync Now'));
    await tester.pumpAndSettle();
    expect(syncNowCount, 1);
    await tester.ensureVisible(find.text('Retry Failed Events'));
    await tester.tap(find.text('Retry Failed Events'));
    await tester.pumpAndSettle();
    expect(retryFailedEventsCount, 1);
    await tester.ensureVisible(find.text('Retry Failed Media'));
    await tester.tap(find.text('Retry Failed Media'));
    await tester.pumpAndSettle();
    expect(retryFailedMediaCount, 1);
    await tester.ensureVisible(find.text('Probe Telemetry Provider'));
    await tester.tap(find.text('Probe Telemetry Provider'));
    await tester.pumpAndSettle();
    expect(telemetryProbeCount, 1);
    await tester.ensureVisible(find.text('Queue Wearable Heartbeat'));
    await tester.tap(find.text('Queue Wearable Heartbeat'));
    await tester.pumpAndSettle();
    expect(wearableHeartbeatCount, 1);
    await tester.ensureVisible(find.text('Queue Device Health'));
    await tester.tap(find.text('Queue Device Health'));
    await tester.pumpAndSettle();
    expect(deviceHealthCount, 1);
    await tester.ensureVisible(find.text('Seed Wearable Bridge'));
    await tester.tap(find.text('Seed Wearable Bridge'));
    await tester.pumpAndSettle();
    expect(wearableBridgeSeedCount, 1);
    await tester.ensureVisible(find.text('Emit Debug SDK Heartbeat'));
    await tester.tap(find.text('Emit Debug SDK Heartbeat'));
    await tester.pumpAndSettle();
    expect(debugSdkHeartbeatEmitCount, 1);
    final copySyncReportButton = find.widgetWithText(
      FilledButton,
      'Copy Sync Report',
    );
    await tester.ensureVisible(copySyncReportButton);
    await tester.tap(copySyncReportButton);
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Copy Export Audit Timeline'), findsOneWidget);
    await tester.ensureVisible(find.text('Copy Export Audit Timeline'));
    await tester.tap(find.text('Copy Export Audit Timeline'));
    await tester.pumpAndSettle();
    expect(find.text('Copy Shift Replay Summary'), findsOneWidget);
    await tester.ensureVisible(find.text('Copy Shift Replay Summary'));
    await tester.tap(find.text('Copy Shift Replay Summary'));
    await tester.pumpAndSettle();
    expect(find.text('Dispatch Closeout Packet'), findsOneWidget);
    await tester.ensureVisible(find.text('Dispatch Closeout Packet'));
    await tester.tap(find.text('Dispatch Closeout Packet'));
    await tester.pumpAndSettle();
    expect(find.text('Clear Export Audits'), findsOneWidget);
    await tester.ensureVisible(find.text('Clear Export Audits'));
    await tester.tap(find.text('Clear Export Audits'));
    await tester.pumpAndSettle();
    expect(clearExportAuditsCount, 1);
    expect(find.text('Copy Filtered Event Rows'), findsOneWidget);
    expect(find.text('Copy Filtered Media Rows'), findsOneWidget);
    expect(find.text('Copy Sync Report'), findsOneWidget);
    await tester.ensureVisible(find.text('Copy Scoped Keys'));
    await tester.tap(find.text('Copy Scoped Keys'));
    await tester.pumpAndSettle();
    expect(find.text('Sync health: At Risk'), findsOneWidget);
    expect(find.textContaining('Payload Health:'), findsOneWidget);
    expect(find.textContaining('Payload Health Trend:'), findsOneWidget);
    expect(find.textContaining('Telemetry Payload Alerts:'), findsOneWidget);
    expect(find.textContaining('Last Payload Alert:'), findsOneWidget);
    expect(find.textContaining('Payload health reason:'), findsOneWidget);
    expect(find.textContaining('Payload health trend: none'), findsOneWidget);
    expect(
      find.textContaining('recent callback parse/ingest errors detected'),
      findsOneWidget,
    );

    expect(find.text('All: 2'), findsNWidgets(2));
    final failedFilterFirst = find.text('Failed: 1').first;
    await tester.ensureVisible(failedFilterFirst);
    await tester.tap(failedFilterFirst, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.textContaining('panicTriggered • seq 2'), findsOneWidget);
    expect(find.textContaining('statusChanged • seq 1'), findsNothing);

    final panicRow = find.textContaining('panicTriggered • seq 2');
    await tester.ensureVisible(panicRow);
    await tester.tap(panicRow, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Event panicTriggered'), findsOneWidget);
    expect(
      find.textContaining('Failure Trace: network unavailable'),
      findsOneWidget,
    );
    expect(find.textContaining('"source": "manual"'), findsOneWidget);
    expect(find.text('Copy Selected Detail'), findsOneWidget);

    final syncedFilterFirst = find.text('Synced: 1').first;
    await tester.ensureVisible(syncedFilterFirst);
    await tester.tap(syncedFilterFirst, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Event panicTriggered'), findsNothing);
    expect(
      find.textContaining(
        'Select a recent row to inspect payload, retries, and failure trace.',
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(failedFilterFirst);
    await tester.tap(failedFilterFirst, warnIfMissed: false);
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('guard-incident-media • failed'));
    await tester.pumpAndSettle();
    expect(find.text('Media failed'), findsOneWidget);
    expect(
      find.textContaining('Failure Trace: upload timeout'),
      findsOneWidget,
    );
    expect(find.textContaining('Retry Count: 3'), findsOneWidget);
    expect(find.text('Copy Selected Detail'), findsOneWidget);

    final syncedFilterLast = find.text('Synced: 1').last;
    await tester.ensureVisible(syncedFilterLast);
    await tester.tap(syncedFilterLast, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.textContaining('guard-incident-media • failed'), findsNothing);
    expect(
      find.textContaining('guard-patrol-images • uploaded'),
      findsOneWidget,
    );
    expect(retryFailedOperationCount, 0);
  });

  testWidgets('guard mobile shell pins sync copy feedback in-page', (
    tester,
  ) async {
    String? copiedSyncReport;
    _mockClipboard(tester, onCopy: (text) => copiedSyncReport = text);

    await tester.binding.setSurfaceSize(const Size(1600, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: GuardMobileShellPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          guardId: 'GUARD-001',
          syncBackendEnabled: true,
          queueDepth: 0,
          pendingEventCount: 0,
          pendingMediaCount: 0,
          failedEventCount: 0,
          failedMediaCount: 0,
          recentEvents: const [],
          recentMedia: const [],
          syncInFlight: false,
          syncStatusLabel: 'Sync idle',
          lastSuccessfulSyncAtUtc: null,
          lastFailureReason: null,
          coachingPrompt: const GuardCoachingPrompt(
            ruleId: 'sync_copy_feedback',
            headline: 'Sync Copy',
            message: 'Verify in-page copy feedback.',
            priority: GuardCoachingPriority.low,
          ),
          coachingPolicy: const GuardSyncCoachingPolicy(),
          queuedOperations: const [],
          historyFilter: GuardSyncHistoryFilter.queued,
          onHistoryFilterChanged: (_) async {},
          operationModeFilter: GuardSyncOperationModeFilter.all,
          onOperationModeFilterChanged: (_) async {},
          onFacadeIdFilterChanged: (_) async {},
          onSelectedOperationChanged: (_) async {},
          initialScreen: GuardMobileInitialScreen.sync,
          onShiftStartQueued: () async {},
          onShiftEndQueued: () async {},
          onStatusQueued: (_) async {},
          onCheckpointQueued:
              ({required checkpointId, required nfcTagId}) async {},
          onPatrolImageQueued: ({required checkpointId}) async {},
          onPanicQueued: () async {},
          onWearableHeartbeatQueued: () async {},
          onDeviceHealthQueued: () async {},
          onOutcomeLabeled:
              ({
                required outcomeLabel,
                required confidence,
                required confirmedBy,
              }) async {},
          outcomeGovernancePolicy: OutcomeLabelGovernancePolicy.defaultPolicy(),
          onClearQueue: () async {},
          onSyncNow: () async {},
          onRetryFailedEvents: () async {},
          onRetryFailedMedia: () async {},
          onRetryFailedOperation: (_) async {},
          onRetryFailedOperationsBulk: (_) async {},
          onDispatchCloseoutPacketCopied:
              ({
                required generatedAtUtc,
                required scopeKey,
                required facadeMode,
                required readinessState,
              }) async {},
          onProbeTelemetryProvider: () async {},
          onAcknowledgeCoachingPrompt:
              ({required ruleId, required context}) async {},
          onSnoozeCoachingPrompt:
              ({
                required ruleId,
                required context,
                required minutes,
                required actorRole,
              }) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final copySyncReportButton = find.widgetWithText(
      FilledButton,
      'Copy Sync Report',
    );
    await tester.ensureVisible(copySyncReportButton);
    await tester.tap(copySyncReportButton);
    await tester.pumpAndSettle();

    expect(copiedSyncReport, isNotNull);
    expect(find.textContaining('Sync report copied'), findsWidgets);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('guard app role modes gate screen flow chips', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Future<void> pumpRole(GuardMobileOperatorRole role) {
      return tester.pumpWidget(
        MaterialApp(
          home: GuardMobileShellPage(
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            guardId: 'GUARD-001',
            operatorRole: role,
            syncBackendEnabled: true,
            queueDepth: 0,
            pendingEventCount: 0,
            pendingMediaCount: 0,
            failedEventCount: 0,
            failedMediaCount: 0,
            recentEvents: const [],
            recentMedia: const [],
            syncInFlight: false,
            syncStatusLabel: null,
            lastSuccessfulSyncAtUtc: null,
            lastFailureReason: null,
            coachingPrompt: const GuardCoachingPrompt(
              ruleId: 'test_prompt',
              headline: 'Test Prompt',
              message: 'Role gating validation.',
              priority: GuardCoachingPriority.low,
            ),
            coachingPolicy: const GuardSyncCoachingPolicy(),
            queuedOperations: const [],
            historyFilter: GuardSyncHistoryFilter.queued,
            onHistoryFilterChanged: (_) async {},
            operationModeFilter: GuardSyncOperationModeFilter.all,
            onOperationModeFilterChanged: (_) async {},
            onFacadeIdFilterChanged: (_) async {},
            onSelectedOperationChanged: (_) async {},
            onShiftStartQueued: () async {},
            onShiftEndQueued: () async {},
            onStatusQueued: (_) async {},
            onCheckpointQueued:
                ({required checkpointId, required nfcTagId}) async {},
            onPatrolImageQueued: ({required checkpointId}) async {},
            onPanicQueued: () async {},
            onWearableHeartbeatQueued: () async {},
            onDeviceHealthQueued: () async {},
            onOutcomeLabeled:
                ({
                  required outcomeLabel,
                  required confidence,
                  required confirmedBy,
                }) async {},
            outcomeGovernancePolicy:
                OutcomeLabelGovernancePolicy.defaultPolicy(),
            onClearQueue: () async {},
            onSyncNow: () async {},
            onRetryFailedEvents: () async {},
            onRetryFailedMedia: () async {},
            onRetryFailedOperation: (_) async {},
            onRetryFailedOperationsBulk: (_) async {},
            onDispatchCloseoutPacketCopied:
                ({
                  required generatedAtUtc,
                  required scopeKey,
                  required facadeMode,
                  required readinessState,
                }) async {},
            onProbeTelemetryProvider: () async {},
            onAcknowledgeCoachingPrompt:
                ({required ruleId, required context}) async {},
            onSnoozeCoachingPrompt:
                ({
                  required ruleId,
                  required context,
                  required minutes,
                  required actorRole,
                }) async {},
          ),
        ),
      );
    }

    await pumpRole(GuardMobileOperatorRole.reaction);
    await tester.pumpAndSettle();
    expect(find.text('Role: Reaction'), findsOneWidget);
    expect(find.text('Dispatch'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Panic'), findsOneWidget);
    expect(find.text('Sync'), findsOneWidget);
    expect(find.text('Shift Start'), findsNothing);
    expect(find.text('Checkpoint'), findsNothing);

    await pumpRole(GuardMobileOperatorRole.supervisor);
    await tester.pumpAndSettle();
    expect(find.text('Role: Supervisor'), findsOneWidget);
    expect(find.text('Dispatch'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Sync'), findsOneWidget);
    expect(find.text('Panic'), findsNothing);
    expect(find.text('Shift Start'), findsNothing);
    expect(find.text('Checkpoint'), findsNothing);
  });

  testWidgets(
    'reaction and supervisor roles show role-specific dispatch panels',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var reactionAcceptedCount = 0;
      var reactionArrivedCount = 0;
      var reactionClearedCount = 0;
      var supervisorOverrideCount = 0;
      var supervisorCoachingAckCount = 0;

      Future<void> pumpRole(GuardMobileOperatorRole role) {
        return tester.pumpWidget(
          MaterialApp(
            home: GuardMobileShellPage(
              clientId: 'CLIENT-001',
              siteId: 'SITE-SANDTON',
              guardId: 'GUARD-001',
              operatorRole: role,
              syncBackendEnabled: true,
              queueDepth: 0,
              pendingEventCount: 0,
              pendingMediaCount: 0,
              failedEventCount: 0,
              failedMediaCount: 0,
              recentEvents: const [],
              recentMedia: const [],
              syncInFlight: false,
              syncStatusLabel: null,
              lastSuccessfulSyncAtUtc: null,
              lastFailureReason: null,
              coachingPrompt: const GuardCoachingPrompt(
                ruleId: 'test_prompt',
                headline: 'Test Prompt',
                message: 'Role dispatch panel validation.',
                priority: GuardCoachingPriority.low,
              ),
              coachingPolicy: const GuardSyncCoachingPolicy(),
              queuedOperations: const [],
              historyFilter: GuardSyncHistoryFilter.queued,
              onHistoryFilterChanged: (_) async {},
              operationModeFilter: GuardSyncOperationModeFilter.all,
              onOperationModeFilterChanged: (_) async {},
              onFacadeIdFilterChanged: (_) async {},
              onSelectedOperationChanged: (_) async {},
              onShiftStartQueued: () async {},
              onShiftEndQueued: () async {},
              onStatusQueued: (_) async {},
              onReactionIncidentAcceptedQueued: () async {
                reactionAcceptedCount += 1;
              },
              onReactionOfficerArrivedQueued: () async {
                reactionArrivedCount += 1;
              },
              onReactionIncidentClearedQueued: () async {
                reactionClearedCount += 1;
              },
              onSupervisorStatusOverrideQueued: (_) async {
                supervisorOverrideCount += 1;
              },
              onSupervisorCoachingAcknowledgedQueued: () async {
                supervisorCoachingAckCount += 1;
              },
              onCheckpointQueued:
                  ({required checkpointId, required nfcTagId}) async {},
              onPatrolImageQueued: ({required checkpointId}) async {},
              onPanicQueued: () async {},
              onWearableHeartbeatQueued: () async {},
              onDeviceHealthQueued: () async {},
              onOutcomeLabeled:
                  ({
                    required outcomeLabel,
                    required confidence,
                    required confirmedBy,
                  }) async {},
              outcomeGovernancePolicy:
                  OutcomeLabelGovernancePolicy.defaultPolicy(),
              onClearQueue: () async {},
              onSyncNow: () async {},
              onRetryFailedEvents: () async {},
              onRetryFailedMedia: () async {},
              onRetryFailedOperation: (_) async {},
              onRetryFailedOperationsBulk: (_) async {},
              onDispatchCloseoutPacketCopied:
                  ({
                    required generatedAtUtc,
                    required scopeKey,
                    required facadeMode,
                    required readinessState,
                  }) async {},
              onProbeTelemetryProvider: () async {},
              onAcknowledgeCoachingPrompt:
                  ({required ruleId, required context}) async {},
              onSnoozeCoachingPrompt:
                  ({
                    required ruleId,
                    required context,
                    required minutes,
                    required actorRole,
                  }) async {},
            ),
          ),
        );
      }

      await pumpRole(GuardMobileOperatorRole.reaction);
      await tester.pumpAndSettle();
      expect(find.text('Reaction Incident Queue'), findsOneWidget);
      expect(find.text('Accept Incident'), findsOneWidget);
      expect(find.text('Mark Arrived'), findsOneWidget);
      expect(find.text('Incident Clear'), findsWidgets);
      await tester.tap(find.text('Accept Incident'));
      await tester.pump();
      await tester.tap(find.text('Mark Arrived'));
      await tester.pump();
      await tester.tap(find.text('Incident Clear').first);
      await tester.pump();
      expect(reactionAcceptedCount, 1);
      expect(reactionArrivedCount, 1);
      expect(reactionClearedCount, 1);

      await pumpRole(GuardMobileOperatorRole.supervisor);
      await tester.pumpAndSettle();
      expect(find.text('Supervisor Dispatch Console'), findsOneWidget);
      expect(find.text('Override: En Route'), findsOneWidget);
      expect(find.text('Override: On Site'), findsOneWidget);
      expect(find.text('Acknowledge Coaching'), findsOneWidget);
      await tester.tap(find.text('Override: En Route'));
      await tester.pump();
      await tester.tap(find.text('Override: On Site'));
      await tester.pump();
      await tester.tap(find.text('Acknowledge Coaching'));
      await tester.pump();
      expect(supervisorOverrideCount, 2);
      expect(supervisorCoachingAckCount, 1);
    },
  );

  testWidgets('guard mobile shell can open directly on sync screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: GuardMobileShellPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          guardId: 'GUARD-001',
          syncBackendEnabled: true,
          queueDepth: 0,
          pendingEventCount: 0,
          pendingMediaCount: 0,
          failedEventCount: 0,
          failedMediaCount: 0,
          recentEvents: const [],
          recentMedia: const [],
          syncInFlight: false,
          syncStatusLabel: 'Sync idle',
          activeShiftId: '',
          activeShiftSequenceWatermark: 0,
          lastCloseoutPacketAuditLabel:
              'at 2026-03-05T10:00:00.000Z • scope queued|all|all_facades • mode all • readiness ready',
          lastShiftReplayAuditLabel:
              'at 2026-03-05T10:05:00.000Z • shift SHIFT-20260305-GUARD-001 • rows e:12 m:4',
          lastSyncReportAuditLabel:
              'at 2026-03-05T10:07:00.000Z • scope queued|all|all_facades • mode all • filters e:all m:all',
          lastExportAuditClearLabel:
              'at 2026-03-05T10:08:00.000Z • scope queued|all|all_facades • mode all • history queued',
          telemetryAdapterLabel: 'demo_fallback',
          telemetryAdapterStubMode: true,
          telemetryProviderStatusLabel:
              'Demo telemetry adapter active (stub mode).',
          telemetryProviderReadiness: 'degraded',
          lastSuccessfulSyncAtUtc: null,
          lastFailureReason: null,
          coachingPrompt: const GuardCoachingPrompt(
            ruleId: 'steady_state',
            headline: 'Sync Steady',
            message: 'Sync lane is healthy.',
            priority: GuardCoachingPriority.low,
          ),
          coachingPolicy: const GuardSyncCoachingPolicy(),
          queuedOperations: const [],
          historyFilter: GuardSyncHistoryFilter.queued,
          onHistoryFilterChanged: (_) async {},
          operationModeFilter: GuardSyncOperationModeFilter.all,
          onOperationModeFilterChanged: (_) async {},
          availableFacadeIds: const [],
          selectedFacadeId: null,
          onFacadeIdFilterChanged: (_) async {},
          initialSelectedOperationId: null,
          onSelectedOperationChanged: (_) async {},
          initialScreen: GuardMobileInitialScreen.sync,
          onStatusQueued: (_) async {},
          onShiftStartQueued: () async {},
          onShiftEndQueued: () async {},
          onCheckpointQueued:
              ({required checkpointId, required nfcTagId}) async {},
          onPatrolImageQueued: ({required checkpointId}) async {},
          onPanicQueued: () async {},
          onWearableHeartbeatQueued: () async {},
          onDeviceHealthQueued: () async {},
          onOutcomeLabeled:
              ({
                required outcomeLabel,
                required confidence,
                required confirmedBy,
              }) async {},
          onClearQueue: () async {},
          onSyncNow: () async {},
          onRetryFailedEvents: () async {},
          onRetryFailedMedia: () async {},
          onRetryFailedOperation: (_) async {},
          onRetryFailedOperationsBulk: (_) async {},
          onDispatchCloseoutPacketCopied:
              ({
                required generatedAtUtc,
                required scopeKey,
                required facadeMode,
                required readinessState,
              }) async {},
          onProbeTelemetryProvider: () async {},
          onAcknowledgeCoachingPrompt:
              ({required ruleId, required context}) async {},
          onSnoozeCoachingPrompt:
              ({
                required ruleId,
                required context,
                required minutes,
                required actorRole,
              }) async {},
          outcomeGovernancePolicy: OutcomeLabelGovernancePolicy.defaultPolicy(),
        ),
      ),
    );

    expect(find.text('Sync Status'), findsOneWidget);
    expect(find.text('Dispatch Inbox'), findsNothing);
    expect(find.text('Sync health: Healthy'), findsOneWidget);
    expect(find.textContaining('Last closeout packet:'), findsOneWidget);
    expect(find.textContaining('Last replay summary:'), findsOneWidget);
    expect(find.textContaining('Last sync report:'), findsOneWidget);
    expect(find.textContaining('Last export audit reset:'), findsOneWidget);
    expect(
      find.text('Telemetry adapter: demo_fallback (stub)'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Provider readiness: degraded • Demo telemetry adapter active (stub mode).',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('PTT lockscreen capture: no recent samples'),
      findsOneWidget,
    );
    expect(find.text('Resume sync event throttle: 20s'), findsOneWidget);
    expect(find.text('Shift Events: 0'), findsOneWidget);
    expect(find.text('Shift Media: 0'), findsOneWidget);
    expect(find.text('Shift Pending: 0'), findsOneWidget);
    expect(find.text('Shift Failed: 0'), findsOneWidget);
    expect(find.text('Shift Closed: no'), findsOneWidget);
    expect(find.text('Closeout Ready: ready'), findsOneWidget);
    expect(find.text('Shift Lifecycle: no shift activity'), findsOneWidget);
    expect(find.text('Open Shift Age: none'), findsOneWidget);
    expect(find.text('Last Resume Sync Trigger: none'), findsOneWidget);
    expect(find.text('Resume Sync Triggers: 0'), findsOneWidget);
    expect(find.text('Last Export Audit Reset: none'), findsOneWidget);
    expect(find.text('Export Audit Resets: 0'), findsOneWidget);
    expect(find.text('Last Export Audit Generated: none'), findsOneWidget);
    expect(find.text('Export Gen/Clear Ratio: 0.00'), findsOneWidget);
    expect(find.text('Export Health Verdict: Healthy'), findsOneWidget);
    expect(
      find.text('Export health reason: no export activity yet'),
      findsOneWidget,
    );
    expect(find.textContaining('Export health thresholds:'), findsOneWidget);
    expect(find.text('Sync Report Exports: 0'), findsOneWidget);
    expect(find.text('Replay Exports: 0'), findsOneWidget);
    expect(find.text('Closeout Exports: 0'), findsOneWidget);
    expect(find.text('Export Audit Timeline'), findsOneWidget);
    expect(find.text('Copy Export Audit Timeline'), findsOneWidget);
    expect(find.text('Generated: 0'), findsOneWidget);
    expect(find.text('Cleared: 0'), findsOneWidget);
    expect(find.text('none yet'), findsOneWidget);
    expect(find.text('Sync Steady'), findsOneWidget);
    expect(find.textContaining('Coaching Prompt •'), findsNothing);
  });

  testWidgets('sync screen flags unlocked-only PTT lockscreen capture', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: GuardMobileShellPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          guardId: 'GUARD-001',
          syncBackendEnabled: true,
          queueDepth: 0,
          pendingEventCount: 0,
          pendingMediaCount: 0,
          failedEventCount: 0,
          failedMediaCount: 0,
          recentEvents: [
            GuardOpsEvent(
              eventId: 'EVT-PTT-1',
              guardId: 'GUARD-001',
              siteId: 'SITE-SANDTON',
              shiftId: 'SHIFT-PTT',
              eventType: GuardOpsEventType.deviceHealth,
              sequence: 1,
              occurredAt: _guardMobileShellMarch11AtUtc(17, 41, 12),
              deviceId: 'DEVICE-1',
              appVersion: '1.0.0',
              payload: const {
                'ptt_action': 'com.zello.ptt.down',
                'ptt_state': 'ptt_down',
                'device_locked': false,
              },
            ),
          ],
          recentMedia: const [],
          syncInFlight: false,
          syncStatusLabel: 'Sync idle',
          initialScreen: GuardMobileInitialScreen.sync,
          lastSuccessfulSyncAtUtc: null,
          lastFailureReason: null,
          coachingPrompt: const GuardCoachingPrompt(
            ruleId: 'ptt_lockscreen_visibility',
            headline: 'PTT Lockscreen Visibility',
            message: 'Show lockscreen telemetry state in sync status.',
            priority: GuardCoachingPriority.low,
          ),
          coachingPolicy: const GuardSyncCoachingPolicy(),
          queuedOperations: const [],
          historyFilter: GuardSyncHistoryFilter.queued,
          onHistoryFilterChanged: (_) async {},
          operationModeFilter: GuardSyncOperationModeFilter.all,
          onOperationModeFilterChanged: (_) async {},
          onFacadeIdFilterChanged: (_) async {},
          onSelectedOperationChanged: (_) async {},
          onShiftStartQueued: () async {},
          onShiftEndQueued: () async {},
          onStatusQueued: (_) async {},
          onCheckpointQueued:
              ({required checkpointId, required nfcTagId}) async {},
          onPatrolImageQueued: ({required checkpointId}) async {},
          onPanicQueued: () async {},
          onWearableHeartbeatQueued: () async {},
          onDeviceHealthQueued: () async {},
          onOutcomeLabeled:
              ({
                required outcomeLabel,
                required confidence,
                required confirmedBy,
              }) async {},
          outcomeGovernancePolicy: OutcomeLabelGovernancePolicy.defaultPolicy(),
          onClearQueue: () async {},
          onSyncNow: () async {},
          onRetryFailedEvents: () async {},
          onRetryFailedMedia: () async {},
          onRetryFailedOperation: (_) async {},
          onRetryFailedOperationsBulk: (_) async {},
          onDispatchCloseoutPacketCopied:
              ({
                required generatedAtUtc,
                required scopeKey,
                required facadeMode,
                required readinessState,
              }) async {},
          onProbeTelemetryProvider: () async {},
          onAcknowledgeCoachingPrompt:
              ({required ruleId, required context}) async {},
          onSnoozeCoachingPrompt:
              ({
                required ruleId,
                required context,
                required minutes,
                required actorRole,
              }) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sync Status'), findsOneWidget);
    expect(
      find.textContaining('PTT lockscreen capture: unlocked only'),
      findsOneWidget,
    );
    expect(
      find.textContaining('locked 0/1 samples (keyguard path blocked)'),
      findsOneWidget,
    );
  });

  testWidgets('sync screen shows last app-resume sync trigger timestamp', (
    tester,
  ) async {
    final lastResumeSyncTriggerAtUtc = _guardMobileShellMarch5AtUtc(9, 30);

    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: GuardMobileShellPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          guardId: 'GUARD-001',
          syncBackendEnabled: true,
          queueDepth: 0,
          pendingEventCount: 0,
          pendingMediaCount: 0,
          failedEventCount: 0,
          failedMediaCount: 0,
          recentEvents: [
            GuardOpsEvent(
              eventId: 'EVT-RESUME',
              guardId: 'GUARD-001',
              siteId: 'SITE-SANDTON',
              shiftId: 'SHIFT-1',
              eventType: GuardOpsEventType.syncStatus,
              sequence: 6,
              occurredAt: lastResumeSyncTriggerAtUtc,
              deviceId: 'DEVICE-1',
              appVersion: '1.0.0',
              payload: const {
                'sync_reason': 'app_resumed',
                'source': 'app_lifecycle',
              },
            ),
          ],
          recentMedia: const [],
          syncInFlight: false,
          syncStatusLabel: 'Sync idle',
          activeShiftId: 'SHIFT-1',
          activeShiftSequenceWatermark: 6,
          telemetryAdapterLabel: 'demo_fallback',
          telemetryAdapterStubMode: true,
          telemetryProviderStatusLabel: 'Demo telemetry adapter active.',
          telemetryProviderReadiness: 'degraded',
          lastSuccessfulSyncAtUtc: null,
          lastFailureReason: null,
          coachingPrompt: const GuardCoachingPrompt(
            ruleId: 'steady_state',
            headline: 'Sync Steady',
            message: 'Sync lane is healthy.',
            priority: GuardCoachingPriority.low,
          ),
          coachingPolicy: const GuardSyncCoachingPolicy(),
          queuedOperations: const [],
          historyFilter: GuardSyncHistoryFilter.queued,
          onHistoryFilterChanged: (_) async {},
          operationModeFilter: GuardSyncOperationModeFilter.all,
          onOperationModeFilterChanged: (_) async {},
          availableFacadeIds: const [],
          selectedFacadeId: null,
          onFacadeIdFilterChanged: (_) async {},
          initialSelectedOperationId: null,
          onSelectedOperationChanged: (_) async {},
          initialScreen: GuardMobileInitialScreen.sync,
          onStatusQueued: (_) async {},
          onShiftStartQueued: () async {},
          onShiftEndQueued: () async {},
          onCheckpointQueued:
              ({required checkpointId, required nfcTagId}) async {},
          onPatrolImageQueued: ({required checkpointId}) async {},
          onPanicQueued: () async {},
          onWearableHeartbeatQueued: () async {},
          onDeviceHealthQueued: () async {},
          onOutcomeLabeled:
              ({
                required outcomeLabel,
                required confidence,
                required confirmedBy,
              }) async {},
          onClearQueue: () async {},
          onSyncNow: () async {},
          onRetryFailedEvents: () async {},
          onRetryFailedMedia: () async {},
          onRetryFailedOperation: (_) async {},
          onRetryFailedOperationsBulk: (_) async {},
          onDispatchCloseoutPacketCopied:
              ({
                required generatedAtUtc,
                required scopeKey,
                required facadeMode,
                required readinessState,
              }) async {},
          onProbeTelemetryProvider: () async {},
          onAcknowledgeCoachingPrompt:
              ({required ruleId, required context}) async {},
          onSnoozeCoachingPrompt:
              ({
                required ruleId,
                required context,
                required minutes,
                required actorRole,
              }) async {},
          outcomeGovernancePolicy: OutcomeLabelGovernancePolicy.defaultPolicy(),
        ),
      ),
    );

    expect(
      find.text(
        'Last Resume Sync Trigger: ${lastResumeSyncTriggerAtUtc.toIso8601String()}',
      ),
      findsOneWidget,
    );
    expect(find.text('Resume Sync Triggers: 1'), findsOneWidget);
    expect(find.text('Last Export Audit Reset: none'), findsOneWidget);
    expect(find.text('Export Audit Resets: 0'), findsOneWidget);
    expect(find.text('Last Export Audit Generated: none'), findsOneWidget);
    expect(find.text('Export Gen/Clear Ratio: 0.00'), findsOneWidget);
    expect(find.text('Export Health Verdict: Healthy'), findsOneWidget);
    expect(
      find.text('Export health reason: no export activity yet'),
      findsOneWidget,
    );
    expect(find.textContaining('Export health thresholds:'), findsOneWidget);
    expect(find.text('Sync Report Exports: 0'), findsOneWidget);
    expect(find.text('Replay Exports: 0'), findsOneWidget);
    expect(find.text('Closeout Exports: 0'), findsOneWidget);
    expect(find.text('Export Audit Timeline'), findsOneWidget);
    expect(find.text('Copy Export Audit Timeline'), findsOneWidget);
    expect(find.text('Generated: 0'), findsOneWidget);
    expect(find.text('Cleared: 0'), findsOneWidget);
    expect(find.text('none yet'), findsOneWidget);
  });

  testWidgets('export audit timeline supports verification filter rows', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: GuardMobileShellPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          guardId: 'GUARD-001',
          syncBackendEnabled: true,
          queueDepth: 0,
          pendingEventCount: 0,
          pendingMediaCount: 0,
          failedEventCount: 0,
          failedMediaCount: 0,
          recentEvents: [
            GuardOpsEvent(
              eventId: 'SYNC-GEN',
              guardId: 'GUARD-001',
              siteId: 'SITE-SANDTON',
              shiftId: 'SHIFT-1',
              eventType: GuardOpsEventType.syncStatus,
              sequence: 1,
              occurredAt: _guardMobileShellMarch5AtUtc(10, 0),
              syncedAt: _guardMobileShellMarch5AtUtc(10, 0, 2),
              deviceId: 'DEVICE-1',
              appVersion: '1.0.0',
              payload: const {
                'export_audit_generated': true,
                'export_type': 'sync_report',
                'scope_key': 'queued|all|all_facades',
              },
            ),
            GuardOpsEvent(
              eventId: 'SYNC-CLEAR',
              guardId: 'GUARD-001',
              siteId: 'SITE-SANDTON',
              shiftId: 'SHIFT-1',
              eventType: GuardOpsEventType.syncStatus,
              sequence: 2,
              occurredAt: _guardMobileShellMarch5AtUtc(10, 1),
              syncedAt: _guardMobileShellMarch5AtUtc(10, 1, 2),
              deviceId: 'DEVICE-1',
              appVersion: '1.0.0',
              payload: const {
                'export_audits_cleared': true,
                'scope_key': 'queued|all|all_facades',
              },
            ),
            GuardOpsEvent(
              eventId: 'SYNC-VERIFY',
              guardId: 'GUARD-001',
              siteId: 'SITE-SANDTON',
              shiftId: 'SHIFT-1',
              eventType: GuardOpsEventType.syncStatus,
              sequence: 3,
              occurredAt: _guardMobileShellMarch5AtUtc(10, 2),
              syncedAt: _guardMobileShellMarch5AtUtc(10, 2, 2),
              deviceId: 'DEVICE-1',
              appVersion: '1.0.0',
              payload: const {
                'telemetry_verification_checklist_passed': true,
                'scope_key': 'queued|all|all_facades',
              },
            ),
            GuardOpsEvent(
              eventId: 'SYNC-TELEMETRY-ALERT',
              guardId: 'GUARD-001',
              siteId: 'SITE-SANDTON',
              shiftId: 'SHIFT-1',
              eventType: GuardOpsEventType.syncStatus,
              sequence: 4,
              occurredAt: _guardMobileShellMarch5AtUtc(10, 3),
              syncedAt: _guardMobileShellMarch5AtUtc(10, 3, 2),
              deviceId: 'DEVICE-1',
              appVersion: '1.0.0',
              payload: const {
                'telemetry_payload_health_alert': true,
                'telemetry_payload_health_verdict': 'at_risk',
                'scope_key': 'queued|all|all_facades',
              },
            ),
          ],
          recentMedia: const [],
          syncInFlight: false,
          syncStatusLabel: 'Sync idle',
          activeShiftId: 'SHIFT-1',
          activeShiftSequenceWatermark: 3,
          telemetryAdapterLabel: 'native_sdk:fsk_sdk',
          telemetryAdapterStubMode: false,
          telemetryProviderStatusLabel: 'ready',
          telemetryProviderReadiness: 'ready',
          telemetryFacadeId: 'fsk_live',
          telemetryFacadeLiveMode: true,
          telemetryFacadeToggleSource: 'build_config',
          lastSuccessfulSyncAtUtc: _guardMobileShellMarch5AtUtc(10, 2),
          lastFailureReason: null,
          coachingPrompt: const GuardCoachingPrompt(
            ruleId: 'steady_state',
            headline: 'Sync Steady',
            message: 'Sync lane is healthy.',
            priority: GuardCoachingPriority.low,
          ),
          coachingPolicy: const GuardSyncCoachingPolicy(),
          queuedOperations: const [],
          historyFilter: GuardSyncHistoryFilter.all,
          onHistoryFilterChanged: (_) async {},
          operationModeFilter: GuardSyncOperationModeFilter.all,
          onOperationModeFilterChanged: (_) async {},
          availableFacadeIds: const ['fsk_live'],
          selectedFacadeId: 'fsk_live',
          onFacadeIdFilterChanged: (_) async {},
          scopedSelectionCount: 0,
          scopedSelectionKeys: const [],
          scopedSelectionsByScope: const {},
          activeScopeKey: 'all|all|fsk_live',
          activeScopeHasSelection: false,
          initialSelectedOperationId: null,
          onSelectedOperationChanged: (_) async {},
          initialScreen: GuardMobileInitialScreen.sync,
          onStatusQueued: (_) async {},
          onShiftStartQueued: () async {},
          onShiftEndQueued: () async {},
          onCheckpointQueued:
              ({required checkpointId, required nfcTagId}) async {},
          onPatrolImageQueued: ({required checkpointId}) async {},
          onPanicQueued: () async {},
          onWearableHeartbeatQueued: () async {},
          onDeviceHealthQueued: () async {},
          onOutcomeLabeled:
              ({
                required outcomeLabel,
                required confidence,
                required confirmedBy,
              }) async {},
          onClearQueue: () async {},
          onSyncNow: () async {},
          onRetryFailedEvents: () async {},
          onRetryFailedMedia: () async {},
          onRetryFailedOperation: (_) async {},
          onRetryFailedOperationsBulk: (_) async {},
          onDispatchCloseoutPacketCopied:
              ({
                required generatedAtUtc,
                required scopeKey,
                required facadeMode,
                required readinessState,
              }) async {},
          onProbeTelemetryProvider: () async {},
          onAcknowledgeCoachingPrompt:
              ({required ruleId, required context}) async {},
          onSnoozeCoachingPrompt:
              ({
                required ruleId,
                required context,
                required minutes,
                required actorRole,
              }) async {},
          outcomeGovernancePolicy: OutcomeLabelGovernancePolicy.defaultPolicy(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Export Audit Timeline'), findsOneWidget);
    expect(find.text('All: 4'), findsWidgets);
    expect(find.text('Generated: 1'), findsWidgets);
    expect(find.text('Cleared: 1'), findsWidgets);
    expect(find.text('Verification: 1'), findsWidgets);
    expect(find.text('Telemetry Alerts: 1'), findsWidgets);

    await tester.ensureVisible(find.text('Verification: 1').first);
    await tester.tap(find.text('Verification: 1').first);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('verification • telemetry_checklist'),
      findsOneWidget,
    );
    expect(find.textContaining('generated • sync_report'), findsNothing);
    expect(find.textContaining('cleared • n/a'), findsNothing);

    await tester.ensureVisible(find.text('Copy Telemetry Alerts Only'));
    await tester.tap(find.text('Copy Telemetry Alerts Only'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Telemetry Alerts: 1').first);
    await tester.tap(find.text('Telemetry Alerts: 1').first);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('telemetry_alert • payload_health'),
      findsOneWidget,
    );
    expect(
      find.textContaining('verification • telemetry_checklist'),
      findsNothing,
    );
  });

  testWidgets('sync selection follows scoped initial selection on rebuild', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final operations = [
      GuardSyncOperation(
        operationId: 'op-live-1',
        type: GuardSyncOperationType.statusUpdate,
        createdAt: _guardMobileShellMarch5AtUtc(10, 0),
        payload: const {
          'status': 'onSite',
          'onyx_runtime_context': {
            'telemetry_facade_id': 'fsk_live',
            'telemetry_facade_live_mode': true,
          },
        },
      ),
      GuardSyncOperation(
        operationId: 'op-stub-1',
        type: GuardSyncOperationType.panicSignal,
        createdAt: _guardMobileShellMarch5AtUtc(10, 1),
        payload: const {
          'level': 'high',
          'onyx_runtime_context': {
            'telemetry_facade_id': 'fsk_stub',
            'telemetry_facade_live_mode': false,
          },
        },
      ),
    ];

    Future<void> pumpShell({
      required GuardSyncOperationModeFilter mode,
      required String? facadeId,
      required String? initialSelectedOperationId,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: GuardMobileShellPage(
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            guardId: 'GUARD-001',
            syncBackendEnabled: true,
            queueDepth: operations.length,
            pendingEventCount: 0,
            pendingMediaCount: 0,
            failedEventCount: 0,
            failedMediaCount: 0,
            recentEvents: const [],
            recentMedia: const [],
            syncInFlight: false,
            syncStatusLabel: 'Sync idle',
            activeShiftId: '',
            activeShiftSequenceWatermark: 0,
            telemetryAdapterLabel: 'native_sdk:fsk_sdk',
            telemetryAdapterStubMode: false,
            telemetryProviderStatusLabel: 'ready',
            telemetryProviderReadiness: 'ready',
            telemetryFacadeId: facadeId,
            telemetryFacadeLiveMode: mode == GuardSyncOperationModeFilter.live,
            telemetryFacadeToggleSource: 'build_config',
            lastSuccessfulSyncAtUtc: _guardMobileShellMarch5AtUtc(10, 2),
            lastFailureReason: null,
            coachingPrompt: const GuardCoachingPrompt(
              ruleId: 'steady_state',
              headline: 'Sync Steady',
              message: 'Sync lane is healthy.',
              priority: GuardCoachingPriority.low,
            ),
            coachingPolicy: const GuardSyncCoachingPolicy(),
            queuedOperations: operations,
            historyFilter: GuardSyncHistoryFilter.all,
            onHistoryFilterChanged: (_) async {},
            operationModeFilter: mode,
            onOperationModeFilterChanged: (_) async {},
            availableFacadeIds: const ['fsk_live', 'fsk_stub'],
            selectedFacadeId: facadeId,
            onFacadeIdFilterChanged: (_) async {},
            scopedSelectionCount: 2,
            scopedSelectionKeys: const [
              'all|live|fsk_live',
              'all|stub|fsk_stub',
            ],
            scopedSelectionsByScope: const {
              'all|live|fsk_live': 'op-live-1',
              'all|stub|fsk_stub': 'op-stub-1',
            },
            activeScopeKey:
                'all|${mode == GuardSyncOperationModeFilter.live ? 'live' : 'stub'}|${facadeId ?? 'all_facades'}',
            activeScopeHasSelection: true,
            initialSelectedOperationId: initialSelectedOperationId,
            onSelectedOperationChanged: (_) async {},
            initialScreen: GuardMobileInitialScreen.sync,
            onStatusQueued: (_) async {},
            onShiftStartQueued: () async {},
            onShiftEndQueued: () async {},
            onCheckpointQueued:
                ({required checkpointId, required nfcTagId}) async {},
            onPatrolImageQueued: ({required checkpointId}) async {},
            onPanicQueued: () async {},
            onWearableHeartbeatQueued: () async {},
            onDeviceHealthQueued: () async {},
            onOutcomeLabeled:
                ({
                  required outcomeLabel,
                  required confidence,
                  required confirmedBy,
                }) async {},
            onClearQueue: () async {},
            onSyncNow: () async {},
            onRetryFailedEvents: () async {},
            onRetryFailedMedia: () async {},
            onRetryFailedOperation: (_) async {},
            onRetryFailedOperationsBulk: (_) async {},
            onDispatchCloseoutPacketCopied:
                ({
                  required generatedAtUtc,
                  required scopeKey,
                  required facadeMode,
                  required readinessState,
                }) async {},
            onProbeTelemetryProvider: () async {},
            onAcknowledgeCoachingPrompt:
                ({required ruleId, required context}) async {},
            onSnoozeCoachingPrompt:
                ({
                  required ruleId,
                  required context,
                  required minutes,
                  required actorRole,
                }) async {},
            outcomeGovernancePolicy:
                OutcomeLabelGovernancePolicy.defaultPolicy(),
          ),
        ),
      );
    }

    await pumpShell(
      mode: GuardSyncOperationModeFilter.live,
      facadeId: 'fsk_live',
      initialSelectedOperationId: 'op-live-1',
    );
    await tester.pumpAndSettle();
    expect(find.text('Scope Selection: selected'), findsOneWidget);
    expect(find.text('Selected Operation Detail'), findsOneWidget);
    expect(find.textContaining('ID: op-live-1'), findsOneWidget);
    expect(find.textContaining('ID: op-stub-1'), findsNothing);

    await pumpShell(
      mode: GuardSyncOperationModeFilter.stub,
      facadeId: 'fsk_stub',
      initialSelectedOperationId: 'op-stub-1',
    );
    await tester.pumpAndSettle();
    expect(find.text('Scope Selection: selected'), findsOneWidget);
    expect(find.textContaining('ID: op-stub-1'), findsOneWidget);
    expect(find.textContaining('ID: op-live-1'), findsNothing);
  });

  testWidgets('invalid selected operation is cleared and propagated upstream', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final selectionUpdates = <String?>[];
    final operations = [
      GuardSyncOperation(
        operationId: 'op-live-1',
        type: GuardSyncOperationType.statusUpdate,
        createdAt: _guardMobileShellMarch5AtUtc(10, 0),
        payload: const {
          'status': 'onSite',
          'onyx_runtime_context': {
            'telemetry_facade_id': 'fsk_live',
            'telemetry_facade_live_mode': true,
          },
        },
      ),
    ];

    Future<void> pumpShell(GuardSyncOperationModeFilter mode) {
      return tester.pumpWidget(
        MaterialApp(
          home: GuardMobileShellPage(
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            guardId: 'GUARD-001',
            syncBackendEnabled: true,
            queueDepth: operations.length,
            pendingEventCount: 0,
            pendingMediaCount: 0,
            failedEventCount: 0,
            failedMediaCount: 0,
            recentEvents: const [],
            recentMedia: const [],
            syncInFlight: false,
            syncStatusLabel: 'Sync idle',
            activeShiftId: '',
            activeShiftSequenceWatermark: 0,
            telemetryAdapterLabel: 'native_sdk:fsk_sdk',
            telemetryAdapterStubMode: false,
            telemetryProviderStatusLabel: 'ready',
            telemetryProviderReadiness: 'ready',
            telemetryFacadeId: 'fsk_live',
            telemetryFacadeLiveMode: true,
            telemetryFacadeToggleSource: 'build_config',
            lastSuccessfulSyncAtUtc: _guardMobileShellMarch5AtUtc(10, 2),
            lastFailureReason: null,
            coachingPrompt: const GuardCoachingPrompt(
              ruleId: 'steady_state',
              headline: 'Sync Steady',
              message: 'Sync lane is healthy.',
              priority: GuardCoachingPriority.low,
            ),
            coachingPolicy: const GuardSyncCoachingPolicy(),
            queuedOperations: operations,
            historyFilter: GuardSyncHistoryFilter.all,
            onHistoryFilterChanged: (_) async {},
            operationModeFilter: mode,
            onOperationModeFilterChanged: (_) async {},
            availableFacadeIds: const ['fsk_live'],
            selectedFacadeId: 'fsk_live',
            onFacadeIdFilterChanged: (_) async {},
            scopedSelectionCount: 1,
            scopedSelectionKeys: const ['all|live|fsk_live'],
            scopedSelectionsByScope: const {'all|live|fsk_live': 'op-live-1'},
            activeScopeKey:
                'all|${mode == GuardSyncOperationModeFilter.live ? 'live' : 'stub'}|fsk_live',
            activeScopeHasSelection: mode == GuardSyncOperationModeFilter.live,
            initialSelectedOperationId: 'op-live-1',
            onSelectedOperationChanged: (operationId) async {
              selectionUpdates.add(operationId);
            },
            initialScreen: GuardMobileInitialScreen.sync,
            onStatusQueued: (_) async {},
            onShiftStartQueued: () async {},
            onShiftEndQueued: () async {},
            onCheckpointQueued:
                ({required checkpointId, required nfcTagId}) async {},
            onPatrolImageQueued: ({required checkpointId}) async {},
            onPanicQueued: () async {},
            onWearableHeartbeatQueued: () async {},
            onDeviceHealthQueued: () async {},
            onOutcomeLabeled:
                ({
                  required outcomeLabel,
                  required confidence,
                  required confirmedBy,
                }) async {},
            onClearQueue: () async {},
            onSyncNow: () async {},
            onRetryFailedEvents: () async {},
            onRetryFailedMedia: () async {},
            onRetryFailedOperation: (_) async {},
            onRetryFailedOperationsBulk: (_) async {},
            onDispatchCloseoutPacketCopied:
                ({
                  required generatedAtUtc,
                  required scopeKey,
                  required facadeMode,
                  required readinessState,
                }) async {},
            onProbeTelemetryProvider: () async {},
            onAcknowledgeCoachingPrompt:
                ({required ruleId, required context}) async {},
            onSnoozeCoachingPrompt:
                ({
                  required ruleId,
                  required context,
                  required minutes,
                  required actorRole,
                }) async {},
            outcomeGovernancePolicy:
                OutcomeLabelGovernancePolicy.defaultPolicy(),
          ),
        ),
      );
    }

    await pumpShell(GuardSyncOperationModeFilter.live);
    await tester.pumpAndSettle();
    expect(find.textContaining('ID: op-live-1'), findsOneWidget);
    expect(selectionUpdates, isEmpty);

    await pumpShell(GuardSyncOperationModeFilter.stub);
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('ID: op-live-1'), findsNothing);
    expect(selectionUpdates, contains(null));
  });

  testWidgets(
    'scope selection chip shows none when active scope is unselected',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: GuardMobileShellPage(
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            guardId: 'GUARD-001',
            syncBackendEnabled: true,
            queueDepth: 1,
            pendingEventCount: 0,
            pendingMediaCount: 0,
            failedEventCount: 0,
            failedMediaCount: 0,
            recentEvents: const [],
            recentMedia: const [],
            syncInFlight: false,
            syncStatusLabel: 'Sync idle',
            activeShiftId: '',
            activeShiftSequenceWatermark: 0,
            telemetryAdapterLabel: 'native_sdk:fsk_sdk',
            telemetryAdapterStubMode: false,
            telemetryProviderStatusLabel: 'ready',
            telemetryProviderReadiness: 'ready',
            lastSuccessfulSyncAtUtc: _guardMobileShellMarch5AtUtc(10, 2),
            lastFailureReason: null,
            coachingPrompt: const GuardCoachingPrompt(
              ruleId: 'steady_state',
              headline: 'Sync Steady',
              message: 'Sync lane is healthy.',
              priority: GuardCoachingPriority.low,
            ),
            coachingPolicy: const GuardSyncCoachingPolicy(),
            queuedOperations: const [],
            historyFilter: GuardSyncHistoryFilter.queued,
            onHistoryFilterChanged: (_) async {},
            operationModeFilter: GuardSyncOperationModeFilter.all,
            onOperationModeFilterChanged: (_) async {},
            availableFacadeIds: const ['fsk_live'],
            selectedFacadeId: null,
            onFacadeIdFilterChanged: (_) async {},
            scopedSelectionCount: 0,
            scopedSelectionKeys: const [],
            activeScopeKey: 'queued|all|all_facades',
            activeScopeHasSelection: false,
            initialSelectedOperationId: null,
            onSelectedOperationChanged: (_) async {},
            initialScreen: GuardMobileInitialScreen.sync,
            onStatusQueued: (_) async {},
            onShiftStartQueued: () async {},
            onShiftEndQueued: () async {},
            onCheckpointQueued:
                ({required checkpointId, required nfcTagId}) async {},
            onPatrolImageQueued: ({required checkpointId}) async {},
            onPanicQueued: () async {},
            onWearableHeartbeatQueued: () async {},
            onDeviceHealthQueued: () async {},
            onOutcomeLabeled:
                ({
                  required outcomeLabel,
                  required confidence,
                  required confirmedBy,
                }) async {},
            onClearQueue: () async {},
            onSyncNow: () async {},
            onRetryFailedEvents: () async {},
            onRetryFailedMedia: () async {},
            onRetryFailedOperation: (_) async {},
            onRetryFailedOperationsBulk: (_) async {},
            onDispatchCloseoutPacketCopied:
                ({
                  required generatedAtUtc,
                  required scopeKey,
                  required facadeMode,
                  required readinessState,
                }) async {},
            onProbeTelemetryProvider: () async {},
            onAcknowledgeCoachingPrompt:
                ({required ruleId, required context}) async {},
            onSnoozeCoachingPrompt:
                ({
                  required ruleId,
                  required context,
                  required minutes,
                  required actorRole,
                }) async {},
            outcomeGovernancePolicy:
                OutcomeLabelGovernancePolicy.defaultPolicy(),
          ),
        ),
      );

      expect(find.text('Scope Selection: none'), findsOneWidget);
    },
  );

  testWidgets('sync screen runs telemetry payload replay and renders output', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var replayCalls = 0;
    String? lastFixtureId;
    String? lastAdapter;

    await tester.pumpWidget(
      MaterialApp(
        home: GuardMobileShellPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          guardId: 'GUARD-001',
          syncBackendEnabled: true,
          queueDepth: 0,
          pendingEventCount: 0,
          pendingMediaCount: 0,
          failedEventCount: 0,
          failedMediaCount: 0,
          recentEvents: const [],
          recentMedia: const [],
          syncInFlight: false,
          syncStatusLabel: 'Sync idle',
          activeShiftId: '',
          activeShiftSequenceWatermark: 0,
          telemetryAdapterLabel: 'native_sdk:fsk_sdk',
          telemetryAdapterStubMode: false,
          telemetryProviderStatusLabel: 'ready',
          telemetryProviderReadiness: 'ready',
          lastSuccessfulSyncAtUtc: _guardMobileShellMarch5AtUtc(10, 2),
          lastFailureReason: null,
          coachingPrompt: const GuardCoachingPrompt(
            ruleId: 'steady_state',
            headline: 'Sync Steady',
            message: 'Sync lane is healthy.',
            priority: GuardCoachingPriority.low,
          ),
          coachingPolicy: const GuardSyncCoachingPolicy(),
          queuedOperations: const [],
          historyFilter: GuardSyncHistoryFilter.queued,
          onHistoryFilterChanged: (_) async {},
          operationModeFilter: GuardSyncOperationModeFilter.all,
          onOperationModeFilterChanged: (_) async {},
          availableFacadeIds: const ['fsk_live'],
          selectedFacadeId: null,
          onFacadeIdFilterChanged: (_) async {},
          scopedSelectionCount: 0,
          scopedSelectionKeys: const [],
          activeScopeKey: 'queued|all|all_facades',
          activeScopeHasSelection: false,
          initialSelectedOperationId: null,
          onSelectedOperationChanged: (_) async {},
          initialScreen: GuardMobileInitialScreen.sync,
          onStatusQueued: (_) async {},
          onShiftStartQueued: () async {},
          onShiftEndQueued: () async {},
          onCheckpointQueued:
              ({required checkpointId, required nfcTagId}) async {},
          onPatrolImageQueued: ({required checkpointId}) async {},
          onPanicQueued: () async {},
          onWearableHeartbeatQueued: () async {},
          onDeviceHealthQueued: () async {},
          onValidateTelemetryPayloadReplay:
              ({
                required fixtureId,
                required payloadAdapter,
                customPayload,
              }) async {
                replayCalls += 1;
                lastFixtureId = fixtureId;
                lastAdapter = payloadAdapter;
                return <String, Object?>{
                  'accepted': true,
                  'fixture_id': fixtureId,
                  'payload_adapter': payloadAdapter,
                  'normalized_payload': <String, Object?>{
                    'heart_rate': 81,
                    'movement_level': 0.57,
                  },
                };
              },
          onOutcomeLabeled:
              ({
                required outcomeLabel,
                required confidence,
                required confirmedBy,
              }) async {},
          onClearQueue: () async {},
          onSyncNow: () async {},
          onRetryFailedEvents: () async {},
          onRetryFailedMedia: () async {},
          onRetryFailedOperation: (_) async {},
          onRetryFailedOperationsBulk: (_) async {},
          onDispatchCloseoutPacketCopied:
              ({
                required generatedAtUtc,
                required scopeKey,
                required facadeMode,
                required readinessState,
              }) async {},
          onProbeTelemetryProvider: () async {},
          onAcknowledgeCoachingPrompt:
              ({required ruleId, required context}) async {},
          onSnoozeCoachingPrompt:
              ({
                required ruleId,
                required context,
                required minutes,
                required actorRole,
              }) async {},
          outcomeGovernancePolicy: OutcomeLabelGovernancePolicy.defaultPolicy(),
        ),
      ),
    );

    final replayButton = find.text('Replay Payload (Legacy)').first;
    await tester.ensureVisible(replayButton);
    await tester.tap(replayButton);
    await tester.pumpAndSettle();

    expect(replayCalls, 1);
    expect(lastFixtureId, 'legacy_ptt_sample');
    expect(lastAdapter, 'legacy_ptt');
    expect(find.text('Telemetry Payload Replay Output'), findsOneWidget);
    expect(find.textContaining('"accepted": true'), findsOneWidget);
    expect(find.textContaining('"heart_rate": 81'), findsOneWidget);

    final hikvisionReplayButton = find.text('Replay Payload (Hikvision)').first;
    await tester.ensureVisible(hikvisionReplayButton);
    await tester.tap(hikvisionReplayButton);
    await tester.pumpAndSettle();

    expect(replayCalls, 2);
    expect(lastFixtureId, 'hikvision_guardlink_sample');
    expect(lastAdapter, 'hikvision_guardlink');
  });

  testWidgets('sync screen shows role operation KPI counts for active shift', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: GuardMobileShellPage(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          guardId: 'GUARD-001',
          syncBackendEnabled: true,
          queueDepth: 0,
          pendingEventCount: 0,
          pendingMediaCount: 0,
          failedEventCount: 0,
          failedMediaCount: 0,
          recentEvents: [
            GuardOpsEvent(
              eventId: 'EVT-RA',
              guardId: 'GUARD-001',
              siteId: 'SITE-SANDTON',
              shiftId: 'SHIFT-1',
              eventType: GuardOpsEventType.reactionIncidentAccepted,
              sequence: 1,
              occurredAt: _guardMobileShellMarch5AtUtc(11, 0),
              deviceId: 'DEVICE-1',
              appVersion: '1.0.0',
              payload: const {},
            ),
            GuardOpsEvent(
              eventId: 'EVT-RR',
              guardId: 'GUARD-001',
              siteId: 'SITE-SANDTON',
              shiftId: 'SHIFT-1',
              eventType: GuardOpsEventType.reactionOfficerArrived,
              sequence: 2,
              occurredAt: _guardMobileShellMarch5AtUtc(11, 2),
              deviceId: 'DEVICE-1',
              appVersion: '1.0.0',
              payload: const {},
            ),
            GuardOpsEvent(
              eventId: 'EVT-RC',
              guardId: 'GUARD-001',
              siteId: 'SITE-SANDTON',
              shiftId: 'SHIFT-1',
              eventType: GuardOpsEventType.reactionIncidentCleared,
              sequence: 3,
              occurredAt: _guardMobileShellMarch5AtUtc(11, 4),
              deviceId: 'DEVICE-1',
              appVersion: '1.0.0',
              payload: const {},
            ),
            GuardOpsEvent(
              eventId: 'EVT-SO',
              guardId: 'GUARD-001',
              siteId: 'SITE-SANDTON',
              shiftId: 'SHIFT-1',
              eventType: GuardOpsEventType.supervisorStatusOverride,
              sequence: 4,
              occurredAt: _guardMobileShellMarch5AtUtc(11, 6),
              deviceId: 'DEVICE-1',
              appVersion: '1.0.0',
              payload: const {},
            ),
            GuardOpsEvent(
              eventId: 'EVT-SA',
              guardId: 'GUARD-001',
              siteId: 'SITE-SANDTON',
              shiftId: 'SHIFT-1',
              eventType: GuardOpsEventType.supervisorCoachingAcknowledged,
              sequence: 5,
              occurredAt: _guardMobileShellMarch5AtUtc(11, 8),
              deviceId: 'DEVICE-1',
              appVersion: '1.0.0',
              payload: const {},
            ),
          ],
          recentMedia: const [],
          syncInFlight: false,
          syncStatusLabel: 'Sync idle',
          activeShiftId: 'SHIFT-1',
          activeShiftSequenceWatermark: 5,
          lastSuccessfulSyncAtUtc: null,
          lastFailureReason: null,
          coachingPrompt: const GuardCoachingPrompt(
            ruleId: 'steady_state',
            headline: 'Sync Steady',
            message: 'Sync lane is healthy.',
            priority: GuardCoachingPriority.low,
          ),
          coachingPolicy: const GuardSyncCoachingPolicy(),
          queuedOperations: const [],
          historyFilter: GuardSyncHistoryFilter.queued,
          onHistoryFilterChanged: (_) async {},
          operationModeFilter: GuardSyncOperationModeFilter.all,
          onOperationModeFilterChanged: (_) async {},
          availableFacadeIds: const [],
          selectedFacadeId: null,
          onFacadeIdFilterChanged: (_) async {},
          initialSelectedOperationId: null,
          onSelectedOperationChanged: (_) async {},
          initialScreen: GuardMobileInitialScreen.sync,
          onStatusQueued: (_) async {},
          onShiftStartQueued: () async {},
          onShiftEndQueued: () async {},
          onCheckpointQueued:
              ({required checkpointId, required nfcTagId}) async {},
          onPatrolImageQueued: ({required checkpointId}) async {},
          onPanicQueued: () async {},
          onWearableHeartbeatQueued: () async {},
          onDeviceHealthQueued: () async {},
          onOutcomeLabeled:
              ({
                required outcomeLabel,
                required confidence,
                required confirmedBy,
              }) async {},
          onClearQueue: () async {},
          onSyncNow: () async {},
          onRetryFailedEvents: () async {},
          onRetryFailedMedia: () async {},
          onRetryFailedOperation: (_) async {},
          onRetryFailedOperationsBulk: (_) async {},
          onDispatchCloseoutPacketCopied:
              ({
                required generatedAtUtc,
                required scopeKey,
                required facadeMode,
                required readinessState,
              }) async {},
          onProbeTelemetryProvider: () async {},
          onAcknowledgeCoachingPrompt:
              ({required ruleId, required context}) async {},
          onSnoozeCoachingPrompt:
              ({
                required ruleId,
                required context,
                required minutes,
                required actorRole,
              }) async {},
          outcomeGovernancePolicy: OutcomeLabelGovernancePolicy.defaultPolicy(),
        ),
      ),
    );

    expect(
      find.textContaining(
        'Role ops (shift) • reaction A/Ar/C: 1/1/1 • supervisor O/Ack: 1/1',
      ),
      findsOneWidget,
    );
  });
}
