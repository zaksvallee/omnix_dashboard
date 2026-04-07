import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:omnix_dashboard/application/onyx_agent_camera_bridge_health_service.dart';
import 'package:omnix_dashboard/application/onyx_agent_camera_bridge_receiver.dart';
import 'package:omnix_dashboard/application/onyx_agent_camera_bridge_server_contract.dart';
import 'package:omnix_dashboard/application/onyx_agent_camera_bridge_server.dart';

String _expectedCheckedAtLabel(DateTime checkedAtUtc) {
  final local = checkedAtUtc.toLocal();
  const monthLabels = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final day = local.day.toString().padLeft(2, '0');
  final month = monthLabels[local.month - 1];
  final year = local.year.toString();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  final ss = local.second.toString().padLeft(2, '0');
  return '$day $month $year $hh:$mm:$ss';
}

void main() {
  group('camera bridge receipt helpers', () {
    test('resolve current and stale receipt states from snapshot age', () {
      final currentSnapshot = OnyxAgentCameraBridgeHealthSnapshot(
        requestedEndpoint: Uri.parse('http://127.0.0.1:11634'),
        healthEndpoint: Uri.parse('http://127.0.0.1:11634/health'),
        reachable: true,
        running: true,
        statusLabel: 'Healthy',
        detail: 'Current validation.',
        executePath: '/execute',
        checkedAtUtc: DateTime.utc(2026, 3, 27, 7, 20, 0),
        operatorId: 'OPS-ALPHA',
      );
      final staleSnapshot = currentSnapshot.copyWith(
        checkedAtUtc: DateTime.utc(2026, 3, 27, 5, 20, 0),
      );
      final nowUtc = DateTime.utc(2026, 3, 27, 7, 30, 0);

      expect(
        resolveOnyxAgentCameraBridgeReceiptState(
          snapshot: currentSnapshot,
          missingReceipt: false,
          nowUtc: nowUtc,
        ),
        OnyxAgentCameraBridgeReceiptState.current,
      );
      expect(
        resolveOnyxAgentCameraBridgeReceiptState(
          snapshot: staleSnapshot,
          missingReceipt: false,
          nowUtc: nowUtc,
        ),
        OnyxAgentCameraBridgeReceiptState.stale,
      );
      expect(
        onyxAgentCameraBridgeValidationRecencyLabel(
          currentSnapshot.checkedAtUtc,
          nowUtc: nowUtc,
        ),
        '10m ago',
      );
      expect(
        formatOnyxAgentCameraBridgeCheckedAtLabel(
          DateTime.utc(2026, 3, 27, 7, 20, 5),
        ),
        _expectedCheckedAtLabel(DateTime.utc(2026, 3, 27, 7, 20, 5)),
      );
    });

    test('resolve missing and unavailable receipt states without snapshot', () {
      expect(
        resolveOnyxAgentCameraBridgeReceiptState(
          snapshot: null,
          missingReceipt: true,
        ),
        OnyxAgentCameraBridgeReceiptState.missing,
      );
      expect(
        resolveOnyxAgentCameraBridgeReceiptState(
          snapshot: null,
          missingReceipt: false,
        ),
        OnyxAgentCameraBridgeReceiptState.unavailable,
      );
    });

    test(
      'visible receipt helper hides receipt state when bridge is not live',
      () {
        expect(
          resolveVisibleOnyxAgentCameraBridgeReceiptState(
            snapshot: null,
            bridgeLive: false,
            healthProbeConfigured: true,
          ),
          isNull,
        );
      },
    );

    test(
      'visible receipt helper hides receipt state while validation is in flight',
      () {
        expect(
          resolveVisibleOnyxAgentCameraBridgeReceiptState(
            snapshot: null,
            bridgeLive: true,
            healthProbeConfigured: true,
            validationInFlight: true,
          ),
          isNull,
        );
      },
    );

    test(
      'visible summary helper hides validation summary when bridge is not live',
      () {
        expect(
          describeVisibleOnyxAgentCameraBridgeValidation(
            snapshot: null,
            bridgeLive: false,
            healthProbeConfigured: true,
          ),
          isNull,
        );
        expect(
          visibleOnyxAgentCameraBridgeReceiptStateLabel(
            snapshot: null,
            bridgeLive: false,
            healthProbeConfigured: true,
          ),
          isNull,
        );
      },
    );

    test(
      'visible summary helper resolves missing receipt copy from shared rules',
      () {
        expect(
          describeVisibleOnyxAgentCameraBridgeValidation(
            snapshot: null,
            bridgeLive: true,
            healthProbeConfigured: true,
          ),
          'No bridge validation receipt captured yet. Run GET /health before trusting this bridge.',
        );
        expect(
          visibleOnyxAgentCameraBridgeReceiptStateLabel(
            snapshot: null,
            bridgeLive: true,
            healthProbeConfigured: true,
          ),
          'MISSING',
        );
      },
    );

    test('validation tone helper resolves from visible receipt state', () {
      expect(
        resolveOnyxAgentCameraBridgeValidationTone(
          OnyxAgentCameraBridgeReceiptState.current,
        ),
        OnyxAgentCameraBridgeValidationTone.success,
      );
      expect(
        resolveOnyxAgentCameraBridgeValidationTone(
          OnyxAgentCameraBridgeReceiptState.stale,
        ),
        OnyxAgentCameraBridgeValidationTone.warning,
      );
      expect(
        resolveOnyxAgentCameraBridgeValidationTone(
          OnyxAgentCameraBridgeReceiptState.missing,
        ),
        OnyxAgentCameraBridgeValidationTone.warning,
      );
      expect(
        resolveOnyxAgentCameraBridgeValidationTone(
          OnyxAgentCameraBridgeReceiptState.unavailable,
        ),
        OnyxAgentCameraBridgeValidationTone.neutral,
      );
      expect(resolveOnyxAgentCameraBridgeValidationTone(null), isNull);
    });

    test('validate action helper resolves from receipt state', () {
      expect(
        resolveOnyxAgentCameraBridgeValidateAction(
          receiptState: OnyxAgentCameraBridgeReceiptState.missing,
        ),
        OnyxAgentCameraBridgeValidateAction.firstValidation,
      );
      expect(
        resolveOnyxAgentCameraBridgeValidateAction(
          receiptState: OnyxAgentCameraBridgeReceiptState.current,
        ),
        OnyxAgentCameraBridgeValidateAction.revalidate,
      );
      expect(
        resolveOnyxAgentCameraBridgeValidateAction(
          receiptState: OnyxAgentCameraBridgeReceiptState.stale,
        ),
        OnyxAgentCameraBridgeValidateAction.revalidate,
      );
      expect(
        resolveOnyxAgentCameraBridgeValidateAction(
          receiptState: OnyxAgentCameraBridgeReceiptState.unavailable,
        ),
        OnyxAgentCameraBridgeValidateAction.validate,
      );
      expect(
        resolveOnyxAgentCameraBridgeValidateAction(receiptState: null),
        OnyxAgentCameraBridgeValidateAction.validate,
      );
      expect(
        resolveOnyxAgentCameraBridgeValidateAction(
          receiptState: OnyxAgentCameraBridgeReceiptState.current,
          validationInFlight: true,
        ),
        OnyxAgentCameraBridgeValidateAction.validating,
      );
      expect(
        describeOnyxAgentCameraBridgeValidateActionLabel(
          action: OnyxAgentCameraBridgeValidateAction.firstValidation,
        ),
        'Run First Validation',
      );
      expect(
        describeOnyxAgentCameraBridgeValidateActionLabel(
          action: OnyxAgentCameraBridgeValidateAction.revalidate,
          variant: OnyxAgentCameraBridgeValidateActionLabelVariant.admin,
        ),
        'RE-VALIDATE BRIDGE',
      );
    });

    test(
      'shared probe helper normalizes operator id onto probe result',
      () async {
        final service = _FakeOnyxAgentCameraBridgeHealthService(
          snapshot: OnyxAgentCameraBridgeHealthSnapshot(
            requestedEndpoint: Uri.parse('http://127.0.0.1:11634'),
            healthEndpoint: Uri.parse('http://127.0.0.1:11634/health'),
            reachable: true,
            running: true,
            statusLabel: 'Healthy',
            detail: 'Bridge probe completed.',
            executePath: '/execute',
            checkedAtUtc: DateTime.utc(2026, 3, 27, 7, 40, 0),
          ),
        );

        final result = await probeOnyxAgentCameraBridgeHealthSnapshot(
          service: service,
          endpoint: Uri.parse('http://127.0.0.1:11634'),
          operatorId: '   ',
        );

        expect(service.lastEndpoint, Uri.parse('http://127.0.0.1:11634'));
        expect(result.operatorId, onyxAgentCameraBridgeDefaultOperatorId);
        expect(result.statusLabel, 'Healthy');
      },
    );

    test(
      'shared validation outcome helper returns snapshot and result message',
      () async {
        final service = _FakeOnyxAgentCameraBridgeHealthService(
          snapshot: OnyxAgentCameraBridgeHealthSnapshot(
            requestedEndpoint: Uri.parse('http://127.0.0.1:11634'),
            healthEndpoint: Uri.parse('http://127.0.0.1:11634/health'),
            reachable: false,
            running: false,
            statusLabel: 'Unreachable',
            detail: 'Bridge probe failed.',
            executePath: '/execute',
            checkedAtUtc: DateTime.utc(2026, 3, 27, 7, 40, 0),
          ),
        );

        final outcome = await completeOnyxAgentCameraBridgeValidation(
          service: service,
          endpoint: Uri.parse('http://127.0.0.1:11634'),
          operatorId: 'CONTROL-12',
        );

        expect(service.lastEndpoint, Uri.parse('http://127.0.0.1:11634'));
        expect(outcome.snapshot.operatorId, 'CONTROL-12');
        expect(outcome.snapshot.reachable, isFalse);
        expect(outcome.message, 'Camera bridge health check failed.');
      },
    );

    test(
      'shared probe helper returns guarded failure snapshot when service throws',
      () async {
        final service = _ThrowingOnyxAgentCameraBridgeHealthService();

        final result = await probeOnyxAgentCameraBridgeHealthSnapshot(
          service: service,
          endpoint: Uri.parse('http://127.0.0.1:11634'),
          operatorId: 'OPS-77',
        );

        expect(result.reachable, isFalse);
        expect(result.running, isFalse);
        expect(result.statusLabel, 'Probe failed');
        expect(result.operatorId, 'OPS-77');
        expect(
          result.healthEndpoint,
          Uri.parse('http://127.0.0.1:11634/health'),
        );
      },
    );

    test(
      'shared clear helper reports success when callback completes',
      () async {
        var cleared = false;

        final success = await clearOnyxAgentCameraBridgeHealthReceipt(
          onClearReceipt: () async {
            cleared = true;
          },
        );

        expect(success, isTrue);
        expect(cleared, isTrue);
      },
    );

    test('shared clear helper reports failure when callback throws', () async {
      final success = await clearOnyxAgentCameraBridgeHealthReceipt(
        onClearReceipt: () async {
          throw StateError('boom');
        },
      );

      expect(success, isFalse);
    });

    test(
      'shared clear outcome helper returns message and success flag',
      () async {
        final outcome = await completeOnyxAgentCameraBridgeClear(
          onClearReceipt: () async {
            throw StateError('boom');
          },
        );

        expect(outcome.success, isFalse);
        expect(
          outcome.message,
          'Failed to clear camera bridge health receipt.',
        );
      },
    );

    test('shared local bridge state transitions validation and reset flow', () {
      final seededSnapshot = OnyxAgentCameraBridgeHealthSnapshot(
        requestedEndpoint: Uri.parse('http://127.0.0.1:11634'),
        healthEndpoint: Uri.parse('http://127.0.0.1:11634/health'),
        reachable: true,
        running: true,
        statusLabel: 'Healthy',
        detail: 'Bridge probe completed.',
        executePath: '/execute',
        checkedAtUtc: DateTime.utc(2026, 3, 27, 7, 45, 0),
      );
      const initialState = OnyxAgentCameraBridgeLocalState();
      final syncedState = initialState.syncSnapshot(seededSnapshot);
      final validatingState = syncedState.beginValidation();
      final validatedState = validatingState.finishValidation(seededSnapshot);
      final resettingState = validatedState.beginReset();
      final failedResetState = resettingState.finishReset(
        success: false,
        previousSnapshot: seededSnapshot,
      );
      final successfulResetState = resettingState.finishReset(
        success: true,
        previousSnapshot: seededSnapshot,
      );

      expect(syncedState.snapshot, same(seededSnapshot));
      expect(syncedState.hasSnapshot, isTrue);
      expect(validatingState.validationInFlight, isTrue);
      expect(validatingState.snapshot, isNull);
      expect(validatedState.validationInFlight, isFalse);
      expect(validatedState.snapshot, same(seededSnapshot));
      expect(resettingState.resetInFlight, isTrue);
      expect(resettingState.snapshot, isNull);
      expect(failedResetState.resetInFlight, isFalse);
      expect(failedResetState.snapshot, same(seededSnapshot));
      expect(successfulResetState.resetInFlight, isFalse);
      expect(successfulResetState.snapshot, isNull);
    });

    test(
      'shared runtime clipboard helper builds payload from runtime state',
      () {
        final status = OnyxAgentCameraBridgeStatus(
          enabled: true,
          running: true,
          endpoint: Uri.parse('http://127.0.0.1:11634'),
          statusLabel: 'Live',
          detail: 'Bridge ready.',
        );
        final snapshot = OnyxAgentCameraBridgeHealthSnapshot(
          requestedEndpoint: Uri.parse('http://127.0.0.1:11634'),
          healthEndpoint: Uri.parse('http://127.0.0.1:11634/health'),
          reachable: true,
          running: true,
          statusLabel: 'Healthy',
          detail: 'Bridge probe completed.',
          executePath: '/execute',
          checkedAtUtc: DateTime.utc(2026, 3, 27, 7, 45, 0),
          operatorId: 'OPS-ALPHA',
        );
        final runtimeState = resolveOnyxAgentCameraBridgeRuntimeState(
          status: status,
          snapshot: snapshot,
          healthProbeConfigured: true,
          nowUtc: DateTime.utc(2026, 3, 27, 7, 50, 0),
        );

        final payload = buildOnyxAgentCameraBridgeClipboardPayloadForRuntime(
          status: status,
          runtimeState: runtimeState,
          shellSummary: 'LAN workers can target the bridge now.',
          snapshot: snapshot,
        );

        expect(payload, contains('ONYX CAMERA BRIDGE'));
        expect(payload, contains('Shell state: READY'));
        expect(
          payload,
          contains('Shell summary: LAN workers can target the bridge now.'),
        );
        expect(payload, contains('Receipt state: CURRENT'));
        expect(payload, contains('Validated by: OPS-ALPHA'));
      },
    );

    test(
      'shared surface-state clipboard helper builds payload from packaged state',
      () {
        final status = OnyxAgentCameraBridgeStatus(
          enabled: true,
          running: true,
          endpoint: Uri.parse('http://127.0.0.1:11634'),
          statusLabel: 'Live',
          detail: 'Bridge ready.',
        );
        final snapshot = OnyxAgentCameraBridgeHealthSnapshot(
          requestedEndpoint: Uri.parse('http://127.0.0.1:11634'),
          healthEndpoint: Uri.parse('http://127.0.0.1:11634/health'),
          reachable: true,
          running: true,
          statusLabel: 'Healthy',
          detail: 'Bridge probe completed.',
          executePath: '/execute',
          checkedAtUtc: DateTime.utc(2026, 3, 27, 7, 45, 0),
          operatorId: 'OPS-ALPHA',
        );
        final surfaceState = resolveOnyxAgentCameraBridgeSurfaceState(
          status: status,
          snapshot: snapshot,
          healthProbeConfigured: true,
          validationInFlight: false,
          resetInFlight: false,
          hasLocalSnapshot: true,
          nowUtc: DateTime.utc(2026, 3, 27, 7, 50, 0),
        );

        final payload =
            buildOnyxAgentCameraBridgeClipboardPayloadForSurfaceState(
              status: status,
              surfaceState: surfaceState,
              snapshot: snapshot,
            );

        expect(payload, contains('ONYX CAMERA BRIDGE'));
        expect(payload, contains('Shell state: READY'));
        expect(payload, contains('Shell summary:'));
        expect(
          payload,
          contains(
            'LAN workers can target http://127.0.0.1:11634/execute and poll http://127.0.0.1:11634/health right now.',
          ),
        );
        expect(payload, contains('Receipt state: CURRENT'));
        expect(payload, contains('Validated by: OPS-ALPHA'));
      },
    );

    test('health control helper resolves shared local card actions', () {
      expect(
        resolveOnyxAgentCameraBridgeHealthControlState(
          validationInFlight: true,
          resetInFlight: false,
          healthProbeConfigured: true,
          hasLocalSnapshot: false,
        ).showHealthCard,
        isTrue,
      );
      expect(
        resolveOnyxAgentCameraBridgeHealthControlState(
          validationInFlight: false,
          resetInFlight: false,
          healthProbeConfigured: true,
          hasLocalSnapshot: true,
        ).showClearReceiptAction,
        isTrue,
      );
      expect(
        resolveOnyxAgentCameraBridgeHealthControlState(
          validationInFlight: false,
          resetInFlight: false,
          healthProbeConfigured: true,
          hasLocalSnapshot: true,
        ).canClearReceipt,
        isTrue,
      );
      expect(
        resolveOnyxAgentCameraBridgeHealthControlState(
          validationInFlight: false,
          resetInFlight: true,
          healthProbeConfigured: true,
          hasLocalSnapshot: true,
        ).canValidate,
        isFalse,
      );
      expect(
        resolveOnyxAgentCameraBridgeHealthControlState(
          validationInFlight: false,
          resetInFlight: false,
          healthProbeConfigured: false,
          hasLocalSnapshot: false,
        ).canValidate,
        isFalse,
      );
      expect(
        describeOnyxAgentCameraBridgeClearActionLabel(resetInFlight: false),
        'Clear Bridge Receipt',
      );
      expect(
        describeOnyxAgentCameraBridgeClearActionLabel(
          resetInFlight: true,
          variant: OnyxAgentCameraBridgeClearActionLabelVariant.admin,
        ),
        'CLEARING RECEIPT...',
      );
      expect(describeOnyxAgentCameraBridgeCopyActionLabel(), 'Copy Setup');
      expect(
        describeOnyxAgentCameraBridgeCopyActionLabel(
          variant: OnyxAgentCameraBridgeCopyActionLabelVariant.admin,
        ),
        'COPY BRIDGE SETUP',
      );
      expect(
        normalizeOnyxAgentCameraBridgeOperatorId('  '),
        onyxAgentCameraBridgeDefaultOperatorId,
      );
      expect(
        normalizeOnyxAgentCameraBridgeOperatorId(' OPS-BRAVO '),
        'OPS-BRAVO',
      );
      expect(
        describeOnyxAgentCameraBridgeEndpointMissingMessage(),
        'Camera bridge endpoint is not configured.',
      );
      expect(
        describeOnyxAgentCameraBridgeValidationResultMessage(reachable: true),
        'Camera bridge health check complete.',
      );
      expect(
        describeOnyxAgentCameraBridgeValidationResultMessage(reachable: false),
        'Camera bridge health check failed.',
      );
      expect(
        describeOnyxAgentCameraBridgeClearResultMessage(success: true),
        'Camera bridge health receipt cleared.',
      );
      expect(
        describeOnyxAgentCameraBridgeClearResultMessage(success: false),
        'Failed to clear camera bridge health receipt.',
      );
      expect(
        describeOnyxAgentCameraBridgeCopyResultMessage(),
        'Camera bridge setup copied.',
      );
    });

    test('surface state helper packages runtime and controls together', () {
      final snapshot = OnyxAgentCameraBridgeHealthSnapshot(
        requestedEndpoint: Uri.parse('http://127.0.0.1:11634'),
        healthEndpoint: Uri.parse('http://127.0.0.1:11634/health'),
        reachable: true,
        running: true,
        statusLabel: 'Healthy',
        detail: 'Current validation.',
        executePath: '/execute',
        checkedAtUtc: DateTime.utc(2026, 3, 27, 7, 20, 0),
      );

      final state = resolveOnyxAgentCameraBridgeSurfaceState(
        status: OnyxAgentCameraBridgeStatus(
          enabled: true,
          running: true,
          endpoint: Uri.parse('http://127.0.0.1:11634'),
          statusLabel: 'Live',
        ),
        snapshot: snapshot,
        healthProbeConfigured: true,
        validationInFlight: false,
        resetInFlight: false,
        hasLocalSnapshot: true,
        nowUtc: DateTime.utc(2026, 3, 27, 7, 25, 0),
      );

      expect(state.receiptState, OnyxAgentCameraBridgeReceiptState.current);
      expect(state.shellState, OnyxAgentCameraBridgeShellState.ready);
      expect(state.receiptStateLabel, 'CURRENT');
      expect(state.validationSummary, contains('Receipt is current.'));
      expect(
        state.shellSummary,
        'LAN workers can target http://127.0.0.1:11634/execute and poll http://127.0.0.1:11634/health right now.',
      );
      expect(
        state.controllerCardSummary,
        'Local camera bridge is ready for LAN worker packets.',
      );
      expect(state.controls.showHealthCard, isTrue);
      expect(state.controls.showClearReceiptAction, isTrue);
      expect(state.controls.canValidate, isTrue);
    });

    test('shell state helper resolves bridge posture from receipt and runtime', () {
      final mismatchSnapshot = OnyxAgentCameraBridgeHealthSnapshot(
        requestedEndpoint: Uri.parse('http://127.0.0.1:11634'),
        healthEndpoint: Uri.parse('http://127.0.0.1:11634/health'),
        reportedEndpoint: Uri.parse('http://10.0.0.44:11634'),
        reachable: true,
        running: true,
        statusLabel: 'Healthy',
        detail: 'Bind mismatch detected.',
        executePath: '/execute',
        checkedAtUtc: DateTime.utc(2026, 3, 27, 7, 30, 0),
      );
      expect(
        resolveOnyxAgentCameraBridgeShellState(
          receiptState: OnyxAgentCameraBridgeReceiptState.missing,
          bridgeEnabled: true,
          bridgeLive: true,
          bindMismatchDetected: false,
        ),
        OnyxAgentCameraBridgeShellState.receiptMissing,
      );
      expect(
        resolveOnyxAgentCameraBridgeShellState(
          receiptState: OnyxAgentCameraBridgeReceiptState.unavailable,
          bridgeEnabled: true,
          bridgeLive: true,
          bindMismatchDetected: false,
        ),
        OnyxAgentCameraBridgeShellState.receiptUnavailable,
      );
      expect(
        resolveOnyxAgentCameraBridgeShellState(
          receiptState: OnyxAgentCameraBridgeReceiptState.stale,
          bridgeEnabled: true,
          bridgeLive: true,
          bindMismatchDetected: false,
        ),
        OnyxAgentCameraBridgeShellState.receiptStale,
      );
      expect(
        resolveOnyxAgentCameraBridgeShellState(
          receiptState: OnyxAgentCameraBridgeReceiptState.current,
          bridgeEnabled: true,
          bridgeLive: true,
          bindMismatchDetected: false,
        ),
        OnyxAgentCameraBridgeShellState.ready,
      );
      expect(
        resolveOnyxAgentCameraBridgeShellState(
          receiptState: null,
          bridgeEnabled: false,
          bridgeLive: false,
          bindMismatchDetected: false,
        ),
        OnyxAgentCameraBridgeShellState.disabled,
      );
      expect(
        resolveOnyxAgentCameraBridgeShellState(
          receiptState: null,
          bridgeEnabled: true,
          bridgeLive: false,
          bindMismatchDetected: false,
          bridgeFailed: true,
        ),
        OnyxAgentCameraBridgeShellState.failed,
      );
      expect(
        resolveOnyxAgentCameraBridgeShellState(
          receiptState: null,
          bridgeEnabled: true,
          bridgeLive: false,
          bindMismatchDetected: false,
        ),
        OnyxAgentCameraBridgeShellState.pending,
      );
      expect(
        resolveOnyxAgentCameraBridgeShellState(
          receiptState: OnyxAgentCameraBridgeReceiptState.current,
          bridgeEnabled: true,
          bridgeLive: true,
          bindMismatchDetected: true,
        ),
        OnyxAgentCameraBridgeShellState.bindMismatch,
      );
      expect(
        OnyxAgentCameraBridgeShellState.receiptMissing.label,
        'RECEIPT_MISSING',
      );
      expect(OnyxAgentCameraBridgeShellState.ready.label, 'READY');
      expect(
        describeOnyxAgentCameraBridgeShellSummary(
          shellState: OnyxAgentCameraBridgeShellState.ready,
          endpointLabel: 'http://127.0.0.1:11634',
        ),
        'LAN workers can target http://127.0.0.1:11634/execute and poll http://127.0.0.1:11634/health right now.',
      );
      expect(
        describeOnyxAgentCameraBridgeShellSummary(
          shellState: OnyxAgentCameraBridgeShellState.disabled,
        ),
        'Enable the local camera bridge if you want LAN workers to post packets into ONYX.',
      );
      expect(
        describeOnyxAgentCameraBridgeShellSummary(
          shellState: OnyxAgentCameraBridgeShellState.bindMismatch,
          snapshot: mismatchSnapshot,
        ),
        'Latest bridge validation reported a different bind than ONYX probed. Reconcile http://127.0.0.1:11634 vs http://10.0.0.44:11634 before giving this listener to LAN workers.',
      );
      expect(
        describeOnyxAgentCameraBridgeShellSummary(
          shellState: OnyxAgentCameraBridgeShellState.disabled,
          variant: OnyxAgentCameraBridgeShellSummaryVariant.controllerCard,
        ),
        'Local camera bridge visibility stays here so camera tools never have to fall back into a hidden legacy workspace.',
      );
      expect(
        describeOnyxAgentCameraBridgeShellSummary(
          shellState: OnyxAgentCameraBridgeShellState.receiptUnavailable,
          variant: OnyxAgentCameraBridgeShellSummaryVariant.controllerCard,
        ),
        'Local camera bridge is live, but the in-app health probe is unavailable on this ONYX runtime.',
      );
    });

    test('runtime shell-state helper resolves from shared status model', () {
      const liveStatus = OnyxAgentCameraBridgeStatus(
        enabled: true,
        running: true,
        statusLabel: 'Live',
      );
      const failedStatus = OnyxAgentCameraBridgeStatus(
        enabled: true,
        running: false,
        statusLabel: 'Failed',
      );
      final mismatchSnapshot = OnyxAgentCameraBridgeHealthSnapshot(
        requestedEndpoint: Uri.parse('http://127.0.0.1:11634'),
        healthEndpoint: Uri.parse('http://127.0.0.1:11634/health'),
        reportedEndpoint: Uri.parse('http://10.0.0.44:11634'),
        reachable: true,
        running: true,
        statusLabel: 'Healthy',
        detail: 'Bind mismatch detected.',
        executePath: '/execute',
        checkedAtUtc: DateTime.utc(2026, 3, 27, 7, 30, 0),
      );

      expect(isOnyxAgentCameraBridgeStatusFailed(liveStatus), false);
      expect(isOnyxAgentCameraBridgeStatusFailed(failedStatus), true);
      expect(
        resolveOnyxAgentCameraBridgeShellStateForStatus(
          status: liveStatus,
          snapshot: mismatchSnapshot,
          receiptState: OnyxAgentCameraBridgeReceiptState.current,
        ),
        OnyxAgentCameraBridgeShellState.bindMismatch,
      );
      expect(
        resolveOnyxAgentCameraBridgeShellStateForStatus(
          status: failedStatus,
          snapshot: null,
          receiptState: null,
        ),
        OnyxAgentCameraBridgeShellState.failed,
      );
      expect(
        resolveOnyxAgentCameraBridgeRuntimeState(
          status: liveStatus,
          snapshot: mismatchSnapshot,
          healthProbeConfigured: true,
        ).shellState,
        OnyxAgentCameraBridgeShellState.bindMismatch,
      );
      expect(
        resolveOnyxAgentCameraBridgeRuntimeState(
          status: failedStatus,
          snapshot: null,
          healthProbeConfigured: true,
        ).validationSummary,
        isNull,
      );
    });

    test(
      'describe validation summary for missing unavailable and stale states',
      () {
        final snapshot = OnyxAgentCameraBridgeHealthSnapshot(
          requestedEndpoint: Uri.parse('http://127.0.0.1:11634'),
          healthEndpoint: Uri.parse('http://127.0.0.1:11634/health'),
          reachable: true,
          running: true,
          statusLabel: 'Healthy',
          detail: 'Stale validation.',
          executePath: '/execute',
          checkedAtUtc: DateTime.utc(2026, 3, 27, 4, 30, 0),
          operatorId: 'OPS-BRAVO',
        );
        final nowUtc = DateTime.utc(2026, 3, 27, 7, 30, 0);

        expect(
          describeOnyxAgentCameraBridgeValidation(
            null,
            missingReceipt: true,
            nowUtc: nowUtc,
          ),
          'No bridge validation receipt captured yet. Run GET /health before trusting this bridge.',
        );
        expect(
          describeOnyxAgentCameraBridgeValidation(
            null,
            missingReceipt: false,
            nowUtc: nowUtc,
          ),
          'Bridge validation receipt is unavailable on this ONYX runtime.',
        );
        expect(
          describeOnyxAgentCameraBridgeValidation(
            snapshot,
            missingReceipt: false,
            nowUtc: nowUtc,
          ),
          'Last validation 3h ago by OPS-BRAVO. Re-run GET /health before trusting this receipt.',
        );
      },
    );

    test('shell chip helper resolves agent and admin badge sets', () {
      expect(
        visibleOnyxAgentCameraBridgeShellChips(
          shellState: OnyxAgentCameraBridgeShellState.bindMismatch,
          receiptState: OnyxAgentCameraBridgeReceiptState.current,
        ).map((chip) => chip.label).toList(),
        <String>['BIND MISMATCH', 'RECENT RECEIPT'],
      );
      expect(
        visibleOnyxAgentCameraBridgeShellChips(
          shellState: OnyxAgentCameraBridgeShellState.receiptMissing,
          receiptState: OnyxAgentCameraBridgeReceiptState.missing,
          variant: OnyxAgentCameraBridgeChipVariant.admin,
        ).map((chip) => chip.label).toList(),
        <String>['Receipt missing'],
      );
      expect(
        visibleOnyxAgentCameraBridgeShellChips(
          shellState: OnyxAgentCameraBridgeShellState.receiptUnavailable,
          receiptState: OnyxAgentCameraBridgeReceiptState.unavailable,
          variant: OnyxAgentCameraBridgeChipVariant.admin,
        ).first.tone,
        OnyxAgentCameraBridgeChipTone.neutral,
      );
      expect(
        visibleOnyxAgentCameraBridgeShellChips(
          shellState: OnyxAgentCameraBridgeShellState.disabled,
          receiptState: null,
        ),
        isEmpty,
      );
    });

    test('runtime chip helper resolves shared auth and ingress badges', () {
      expect(
        visibleOnyxAgentCameraBridgeRuntimeChips(
          authRequired: true,
          bridgeLive: true,
        ).map((chip) => chip.label).toList(),
        <String>['AUTH REQUIRED'],
      );
      expect(
        visibleOnyxAgentCameraBridgeRuntimeChips(
          authRequired: false,
          bridgeLive: false,
          variant: OnyxAgentCameraBridgeChipVariant.admin,
        ).map((chip) => chip.label).toList(),
        <String>['Local access', 'Packet ingress pending'],
      );
      expect(
        visibleOnyxAgentCameraBridgeRuntimeChips(
          authRequired: false,
          bridgeLive: true,
          variant: OnyxAgentCameraBridgeChipVariant.admin,
        ).last.tone,
        OnyxAgentCameraBridgeChipTone.status,
      );
      expect(
        visibleOnyxAgentCameraBridgePanelChips(
          authRequired: false,
          bridgeLive: true,
          shellState: OnyxAgentCameraBridgeShellState.bindMismatch,
          receiptState: OnyxAgentCameraBridgeReceiptState.current,
        ).map((chip) => chip.label).toList(),
        <String>['LOCAL ACCESS', 'BIND MISMATCH', 'RECENT RECEIPT'],
      );
      expect(
        visibleOnyxAgentCameraBridgePanelChips(
          authRequired: false,
          bridgeLive: false,
          shellState: OnyxAgentCameraBridgeShellState.receiptMissing,
          receiptState: OnyxAgentCameraBridgeReceiptState.missing,
          variant: OnyxAgentCameraBridgeChipVariant.admin,
        ).map((chip) => chip.label).toList(),
        <String>['Local access', 'Packet ingress pending', 'Receipt missing'],
      );
    });

    test('status badge helper resolves shared label and tone', () {
      final failedStatus = OnyxAgentCameraBridgeStatus(
        enabled: true,
        running: false,
        statusLabel: 'Failed',
        detail: 'Bridge failed.',
      );
      expect(
        visibleOnyxAgentCameraBridgeStatusBadgeForStatus(
          const OnyxAgentCameraBridgeStatus(
            enabled: true,
            running: true,
            statusLabel: 'Live',
            detail: 'Bridge live.',
          ),
        ).label,
        'LIVE',
      );
      expect(
        resolveOnyxAgentCameraBridgeStatusToneForStatus(failedStatus),
        OnyxAgentCameraBridgeStatusTone.failed,
      );
      expect(
        visibleOnyxAgentCameraBridgeStatusBadgeForStatus(failedStatus).tone,
        OnyxAgentCameraBridgeStatusTone.failed,
      );
      expect(
        resolveOnyxAgentCameraBridgeStatusTone(
          bridgeEnabled: failedStatus.enabled,
          bridgeLive: failedStatus.isLive,
          statusLabel: failedStatus.statusLabel,
        ),
        OnyxAgentCameraBridgeStatusTone.failed,
      );
      expect(
        resolveOnyxAgentCameraBridgeStatusTone(
          bridgeEnabled: false,
          bridgeLive: false,
          statusLabel: 'Disabled',
        ),
        OnyxAgentCameraBridgeStatusTone.disabled,
      );
      expect(
        resolveOnyxAgentCameraBridgeStatusTone(
          bridgeEnabled: true,
          bridgeLive: false,
          statusLabel: 'Starting',
        ),
        OnyxAgentCameraBridgeStatusTone.starting,
      );
    });

    test('health badge helper resolves shared label and tone', () {
      final healthySnapshot = OnyxAgentCameraBridgeHealthSnapshot(
        requestedEndpoint: Uri.parse('http://127.0.0.1:11634'),
        healthEndpoint: Uri.parse('http://127.0.0.1:11634/health'),
        reachable: true,
        running: true,
        statusLabel: 'Healthy',
        detail: 'Bridge healthy.',
        executePath: '/execute',
        checkedAtUtc: DateTime.utc(2026, 3, 27, 7, 30, 0),
      );
      final unreachableSnapshot = healthySnapshot.copyWith(
        reachable: false,
        running: false,
        statusLabel: 'Unreachable',
      );
      final warningSnapshot = healthySnapshot.copyWith(
        running: false,
        statusLabel: 'Degraded',
      );

      expect(
        visibleOnyxAgentCameraBridgeHealthBadge(healthySnapshot)!.label,
        'HEALTHY',
      );
      expect(
        resolveOnyxAgentCameraBridgeHealthTone(unreachableSnapshot),
        OnyxAgentCameraBridgeHealthTone.error,
      );
      expect(
        resolveOnyxAgentCameraBridgeHealthTone(warningSnapshot),
        OnyxAgentCameraBridgeHealthTone.warning,
      );
      expect(
        resolveOnyxAgentCameraBridgeHealthTone(null),
        OnyxAgentCameraBridgeHealthTone.status,
      );
    });

    test('health loading helper resolves agent and admin copy', () {
      expect(
        describeOnyxAgentCameraBridgeHealthLoading(),
        'Running GET /health against the local camera bridge...',
      );
      expect(
        describeOnyxAgentCameraBridgeHealthLoading(
          variant: OnyxAgentCameraBridgeHealthLoadingVariant.admin,
        ),
        'Running GET /health against the configured local bridge endpoint...',
      );
    });

    test('health field helper preserves shared order and optional rows', () {
      final mismatchSnapshot = OnyxAgentCameraBridgeHealthSnapshot(
        requestedEndpoint: Uri.parse('http://127.0.0.1:11634'),
        healthEndpoint: Uri.parse('http://127.0.0.1:11634/health'),
        reportedEndpoint: Uri.parse('http://10.0.0.44:11634'),
        reachable: true,
        running: true,
        statusCode: 200,
        statusLabel: 'Healthy',
        detail: 'Bind mismatch detected.',
        executePath: '/execute',
        checkedAtUtc: DateTime.utc(2026, 3, 27, 7, 30, 0),
        operatorId: 'OPS-ALPHA',
      );
      final minimalSnapshot = OnyxAgentCameraBridgeHealthSnapshot(
        requestedEndpoint: Uri.parse('http://127.0.0.1:11634'),
        healthEndpoint: Uri.parse('http://127.0.0.1:11634/health'),
        reachable: true,
        running: true,
        statusLabel: 'Healthy',
        detail: 'Bridge healthy.',
        executePath: '/execute',
        checkedAtUtc: DateTime.utc(2026, 3, 27, 7, 30, 0),
      );
      final checkedAtLabel = _expectedCheckedAtLabel(
        mismatchSnapshot.checkedAtUtc,
      );

      expect(
        visibleOnyxAgentCameraBridgeHealthFields(
          snapshot: mismatchSnapshot,
          receiptStateLabel: 'CURRENT',
          checkedAtLabel: checkedAtLabel,
        ).map((field) => field.label).toList(),
        <String>[
          'HTTP',
          'Receipt state',
          'Health',
          'Endpoint mismatch',
          'Probed bind',
          'Reported bind',
          'Validated at',
          'Validated by',
          'Route',
        ],
      );
      expect(
        visibleOnyxAgentCameraBridgeHealthFields(
          snapshot: minimalSnapshot,
          receiptStateLabel: 'CURRENT',
          checkedAtLabel: checkedAtLabel,
        ).map((field) => field.label).toList(),
        <String>['HTTP', 'Receipt state', 'Health', 'Validated at', 'Route'],
      );
      expect(
        visibleOnyxAgentCameraBridgeClipboardDetailLines(
          snapshot: mismatchSnapshot,
          receiptStateLabel: 'CURRENT',
        ),
        <String>[
          'Validation: HEALTHY',
          'Health: GET http://127.0.0.1:11634/health',
          'Endpoint mismatch: DETECTED',
          'Probed bind: http://127.0.0.1:11634',
          'Reported bind: http://10.0.0.44:11634',
          'Validated at: $checkedAtLabel',
          'Receipt state: CURRENT',
          'Receipt freshness: CURRENT',
          'Validated by: OPS-ALPHA',
          'Route: POST http://10.0.0.44:11634/execute',
        ],
      );
      expect(
        visibleOnyxAgentCameraBridgeClipboardPlaceholderDetailLines(
          validationLabel: 'NOT RUN',
          receiptStateLabel: 'MISSING',
        ),
        <String>[
          'Validation: NOT RUN',
          'Receipt state: MISSING',
          'Receipt freshness: MISSING',
        ],
      );
      expect(
        visibleOnyxAgentCameraBridgeClipboardLines(
          snapshot: null,
          receiptState: OnyxAgentCameraBridgeReceiptState.missing,
        ),
        <String>[
          'Validation: NOT RUN',
          'Receipt state: MISSING',
          'Receipt freshness: MISSING',
        ],
      );
      expect(
        visibleOnyxAgentCameraBridgeClipboardLines(
          snapshot: null,
          receiptState: OnyxAgentCameraBridgeReceiptState.unavailable,
        ),
        <String>[
          'Validation: UNAVAILABLE',
          'Receipt state: UNAVAILABLE',
          'Receipt freshness: UNAVAILABLE',
        ],
      );
      expect(
        visibleOnyxAgentCameraBridgeClipboardLines(
          snapshot: mismatchSnapshot,
          receiptState: OnyxAgentCameraBridgeReceiptState.current,
        ),
        <String>[
          'Validation: HEALTHY',
          'Health: GET http://127.0.0.1:11634/health',
          'Endpoint mismatch: DETECTED',
          'Probed bind: http://127.0.0.1:11634',
          'Reported bind: http://10.0.0.44:11634',
          'Validated at: $checkedAtLabel',
          'Receipt state: CURRENT',
          'Receipt freshness: CURRENT',
          'Validated by: OPS-ALPHA',
          'Route: POST http://10.0.0.44:11634/execute',
        ],
      );
      expect(
        visibleOnyxAgentCameraBridgeClipboardLines(
          snapshot: null,
          receiptState: null,
        ),
        isEmpty,
      );
      expect(
        buildOnyxAgentCameraBridgeClipboardPayload(
          base: 'Bridge base',
          shellStateLabel: 'READY',
          shellSummary: 'Bridge ready.',
          detailLines: const <String>['Validation: HEALTHY', 'Route: POST'],
        ),
        'Bridge base\nShell state: READY\nShell summary: Bridge ready.\nValidation: HEALTHY\nRoute: POST',
      );
    });
  });

  group('HttpOnyxAgentCameraBridgeHealthService', () {
    test('serializes and restores bridge health snapshots', () {
      final snapshot = OnyxAgentCameraBridgeHealthSnapshot(
        requestedEndpoint: Uri.parse('http://127.0.0.1:11634'),
        healthEndpoint: Uri.parse('http://127.0.0.1:11634/health'),
        reportedEndpoint: Uri.parse('http://127.0.0.1:11634'),
        reachable: true,
        running: true,
        statusCode: 200,
        statusLabel: 'Healthy',
        detail:
            'GET /health succeeded and the bridge reported packet ingress ready.',
        executePath: '/execute',
        checkedAtUtc: DateTime.utc(2026, 3, 27, 7, 10, 0),
        operatorId: 'OPS-ALPHA',
      );

      final restored = OnyxAgentCameraBridgeHealthSnapshot.fromJson(
        snapshot.toJson(),
      );

      expect(restored.statusLabel, 'Healthy');
      expect(restored.reachable, true);
      expect(restored.running, true);
      expect(restored.statusCode, 200);
      expect(restored.healthRouteLabel, 'GET http://127.0.0.1:11634/health');
      expect(restored.probedBindLabel, 'http://127.0.0.1:11634');
      expect(restored.hasReportedBindMismatch, false);
      expect(restored.reportedBindLabel, isNull);
      expect(restored.mismatchStatusLabel, isNull);
      expect(restored.routeLabel, 'POST http://127.0.0.1:11634/execute');
      expect(restored.checkedAtUtc, DateTime.utc(2026, 3, 27, 7, 10, 0));
      expect(restored.operatorId, 'OPS-ALPHA');
    });

    test(
      'exposes reported bind when bridge health reports a different endpoint',
      () {
        final snapshot = OnyxAgentCameraBridgeHealthSnapshot(
          requestedEndpoint: Uri.parse('http://127.0.0.1:11634'),
          healthEndpoint: Uri.parse('http://127.0.0.1:11634/health'),
          reportedEndpoint: Uri.parse('http://10.0.0.44:11634'),
          reachable: true,
          running: true,
          statusCode: 200,
          statusLabel: 'Healthy',
          detail: 'Bridge reported a different bind target.',
          executePath: '/execute',
          checkedAtUtc: DateTime.utc(2026, 3, 27, 7, 18, 0),
        );

        expect(snapshot.probedBindLabel, 'http://127.0.0.1:11634');
        expect(snapshot.hasReportedBindMismatch, true);
        expect(snapshot.reportedBindLabel, 'http://10.0.0.44:11634');
        expect(snapshot.mismatchStatusLabel, 'Detected');
        expect(snapshot.routeLabel, 'POST http://10.0.0.44:11634/execute');
      },
    );

    test('probes the local bridge health endpoint successfully', () async {
      final server = createOnyxAgentCameraBridgeServer(
        receiver: const OnyxAgentCameraBridgeReceiver(),
        host: '127.0.0.1',
        port: 0,
      );
      addTearDown(server.close);
      await server.start();

      final client = http.Client();
      addTearDown(client.close);
      final service = HttpOnyxAgentCameraBridgeHealthService(client: client);

      final result = await service.probe(server.endpoint!);

      expect(result.reachable, true);
      expect(result.running, true);
      expect(result.statusCode, 200);
      expect(result.statusLabel, 'Healthy');
      expect(result.healthRouteLabel, 'GET ${server.endpoint}/health');
      expect(result.routeLabel, 'POST ${server.endpoint}/execute');
    });

    test(
      'returns unreachable status when the bridge cannot be reached',
      () async {
        final client = http.Client();
        addTearDown(client.close);
        final service = HttpOnyxAgentCameraBridgeHealthService(
          client: client,
          timeout: const Duration(milliseconds: 500),
        );

        final result = await service.probe(Uri.parse('http://127.0.0.1:9'));

        expect(result.reachable, false);
        expect(result.running, false);
        expect(result.statusLabel, 'Unreachable');
        expect(result.statusCode, isNull);
        expect(result.detail, contains('GET /health could not reach'));
      },
    );
  });
}

class _FakeOnyxAgentCameraBridgeHealthService
    implements OnyxAgentCameraBridgeHealthService {
  final OnyxAgentCameraBridgeHealthSnapshot snapshot;
  Uri? lastEndpoint;

  _FakeOnyxAgentCameraBridgeHealthService({required this.snapshot});

  @override
  bool get isConfigured => true;

  @override
  Future<OnyxAgentCameraBridgeHealthSnapshot> probe(Uri endpoint) async {
    lastEndpoint = endpoint;
    return snapshot;
  }
}

class _ThrowingOnyxAgentCameraBridgeHealthService
    implements OnyxAgentCameraBridgeHealthService {
  @override
  bool get isConfigured => true;

  @override
  Future<OnyxAgentCameraBridgeHealthSnapshot> probe(Uri endpoint) async {
    throw StateError('boom');
  }
}
