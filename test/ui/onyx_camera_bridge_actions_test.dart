import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/onyx_agent_camera_bridge_health_service.dart';
import 'package:omnix_dashboard/application/onyx_agent_camera_bridge_server_contract.dart';
import 'package:omnix_dashboard/ui/onyx_camera_bridge_actions.dart';
import 'package:omnix_dashboard/ui/onyx_camera_bridge_tone_resolver.dart';

final DateTime _bridgeFixtureNowUtc = DateTime.now().toUtc();

DateTime _bridgeCheckedAtUtc() =>
    _bridgeFixtureNowUtc.subtract(const Duration(minutes: 5));

DateTime _bridgePresentationNowUtc() => _bridgeFixtureNowUtc;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'camera bridge validation action updates local state and reports result',
    () async {
      final localStates = <OnyxAgentCameraBridgeLocalState>[];
      final messages = <String>[];
      OnyxAgentCameraBridgeHealthSnapshot? receivedSnapshot;
      final service = _FakeOnyxAgentCameraBridgeHealthService(
        snapshot: OnyxAgentCameraBridgeHealthSnapshot(
          requestedEndpoint: Uri.parse('http://127.0.0.1:11634'),
          healthEndpoint: Uri.parse('http://127.0.0.1:11634/health'),
          reachable: true,
          running: true,
          statusLabel: 'Healthy',
          detail: 'Bridge probe completed.',
          executePath: '/execute',
          checkedAtUtc: _bridgeCheckedAtUtc(),
        ),
      );

      await runOnyxCameraBridgeValidationAction(
        currentState: const OnyxAgentCameraBridgeLocalState(),
        status: OnyxAgentCameraBridgeStatus(
          enabled: true,
          running: true,
          endpoint: Uri.parse('http://127.0.0.1:11634'),
          statusLabel: 'Live',
        ),
        service: service,
        operatorId: 'OPS-ALPHA',
        onLocalStateChanged: localStates.add,
        isMounted: () => true,
        onSnapshotChanged: (snapshot) => receivedSnapshot = snapshot,
        onMessage: messages.add,
      );

      expect(localStates, hasLength(2));
      expect(localStates.first.validationInFlight, isTrue);
      expect(localStates.last.snapshot?.operatorId, 'OPS-ALPHA');
      expect(receivedSnapshot?.operatorId, 'OPS-ALPHA');
      expect(messages, ['Camera bridge health check complete.']);
    },
  );

  test(
    'camera bridge validation action reports missing endpoint without state churn',
    () async {
      final localStates = <OnyxAgentCameraBridgeLocalState>[];
      final messages = <String>[];

      await runOnyxCameraBridgeValidationAction(
        currentState: const OnyxAgentCameraBridgeLocalState(),
        status: const OnyxAgentCameraBridgeStatus(
          enabled: true,
          running: true,
          statusLabel: 'Live',
        ),
        service: _FakeOnyxAgentCameraBridgeHealthService(
          snapshot: OnyxAgentCameraBridgeHealthSnapshot(
            requestedEndpoint: Uri(),
            healthEndpoint: Uri(),
            reachable: true,
            running: true,
            statusLabel: 'Healthy',
            detail: 'Bridge probe completed.',
            executePath: '/execute',
            checkedAtUtc: _bridgeCheckedAtUtc(),
          ),
        ),
        operatorId: 'OPS-ALPHA',
        onLocalStateChanged: localStates.add,
        isMounted: () => true,
        onSnapshotChanged: (_) {},
        onMessage: messages.add,
      );

      expect(localStates, isEmpty);
      expect(messages, ['Camera bridge endpoint is not configured.']);
    },
  );

  test(
    'camera bridge clear action restores prior snapshot on failure',
    () async {
      final localStates = <OnyxAgentCameraBridgeLocalState>[];
      final messages = <String>[];
      final seededSnapshot = OnyxAgentCameraBridgeHealthSnapshot(
        requestedEndpoint: Uri.parse('http://127.0.0.1:11634'),
        healthEndpoint: Uri.parse('http://127.0.0.1:11634/health'),
        reachable: true,
        running: true,
        statusLabel: 'Healthy',
        detail: 'Bridge probe completed.',
        executePath: '/execute',
        checkedAtUtc: _bridgeCheckedAtUtc(),
      );

      await runOnyxCameraBridgeClearAction(
        currentState: const OnyxAgentCameraBridgeLocalState(),
        snapshot: seededSnapshot,
        onClearReceipt: () async {
          throw StateError('boom');
        },
        onLocalStateChanged: localStates.add,
        isMounted: () => true,
        onMessage: messages.add,
      );

      expect(localStates, hasLength(2));
      expect(localStates.first.resetInFlight, isTrue);
      expect(localStates.last.snapshot, same(seededSnapshot));
      expect(messages, ['Failed to clear camera bridge health receipt.']);
    },
  );

  test('camera bridge clear action noops when snapshot is absent', () async {
    final localStates = <OnyxAgentCameraBridgeLocalState>[];
    final messages = <String>[];

    await runOnyxCameraBridgeClearAction(
      currentState: const OnyxAgentCameraBridgeLocalState(),
      snapshot: null,
      onClearReceipt: () async {},
      onLocalStateChanged: localStates.add,
      isMounted: () => true,
      onMessage: messages.add,
    );

    expect(localStates, isEmpty);
    expect(messages, isEmpty);
  });

  test('camera bridge copy action copies setup and reports message', () async {
    String? clipboardText;
    final messages = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<dynamic, dynamic>;
            clipboardText = args['text'] as String?;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await runOnyxCameraBridgeCopyAction(
      status: _liveBridgeStatus(),
      presentation: _liveBridgePresentation(),
      isMounted: () => true,
      onMessage: messages.add,
    );

    expect(clipboardText, contains('Shell state: READY'));
    expect(messages, ['Camera bridge setup copied.']);
  });

  test(
    'camera bridge copy action prepends telegram seed context when provided',
    () async {
      String? clipboardText;
      final messages = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              final args = call.arguments as Map<dynamic, dynamic>;
              clipboardText = args['text'] as String?;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await runOnyxCameraBridgeCopyAction(
        status: _liveBridgeStatus(),
        presentation: _liveBridgePresentation(),
        isMounted: () => true,
        onMessage: messages.add,
        leadingText:
            'Telegram-approved camera bridge seed\nSite: SITE-ROBERTSHAM-ESTATE',
      );

      expect(
        clipboardText,
        startsWith(
          'Telegram-approved camera bridge seed\nSite: SITE-ROBERTSHAM-ESTATE\n\n',
        ),
      );
      expect(clipboardText, contains('Shell state: READY'));
      expect(messages, ['Camera bridge setup copied.']);
    },
  );

  test(
    'camera bridge copy action suppresses message when widget is unmounted',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      final messages = <String>[];

      await runOnyxCameraBridgeCopyAction(
        status: _liveBridgeStatus(),
        presentation: _liveBridgePresentation(),
        isMounted: () => false,
        onMessage: messages.add,
      );

      expect(messages, isEmpty);
    },
  );
}

OnyxAgentCameraBridgeStatus _liveBridgeStatus() {
  return OnyxAgentCameraBridgeStatus(
    enabled: true,
    running: true,
    endpoint: Uri.parse('http://127.0.0.1:11634'),
    statusLabel: 'Live',
    detail: 'Bridge ready.',
  );
}

OnyxCameraBridgeSurfacePresentation _liveBridgePresentation() {
  return resolveOnyxCameraBridgeSurfacePresentation(
    status: _liveBridgeStatus(),
    localSnapshot: OnyxAgentCameraBridgeHealthSnapshot(
      requestedEndpoint: Uri.parse('http://127.0.0.1:11634'),
      healthEndpoint: Uri.parse('http://127.0.0.1:11634/health'),
      reachable: true,
      running: true,
      statusLabel: 'Healthy',
      detail: 'Bridge probe completed.',
      executePath: '/execute',
      checkedAtUtc: _bridgeCheckedAtUtc(),
      operatorId: 'OPS-ALPHA',
    ),
    healthProbeConfigured: true,
    variant: OnyxCameraBridgeSurfaceToneVariant.agent,
    nowUtc: _bridgePresentationNowUtc(),
  );
}

class _FakeOnyxAgentCameraBridgeHealthService
    implements OnyxAgentCameraBridgeHealthService {
  final OnyxAgentCameraBridgeHealthSnapshot snapshot;

  const _FakeOnyxAgentCameraBridgeHealthService({required this.snapshot});

  @override
  bool get isConfigured => true;

  @override
  Future<OnyxAgentCameraBridgeHealthSnapshot> probe(Uri endpoint) async =>
      snapshot.copyWith(requestedEndpoint: endpoint);
}
