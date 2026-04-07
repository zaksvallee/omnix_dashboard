import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/onyx_agent_camera_bridge_health_service.dart';
import 'package:omnix_dashboard/application/onyx_agent_camera_bridge_server_contract.dart';
import 'package:omnix_dashboard/ui/onyx_camera_bridge_clipboard.dart';
import 'package:omnix_dashboard/ui/onyx_camera_bridge_tone_resolver.dart';

final DateTime _bridgeFixtureNowUtc = DateTime.now().toUtc();

DateTime _bridgeCheckedAtUtc() =>
    _bridgeFixtureNowUtc.subtract(const Duration(minutes: 5));

DateTime _bridgePresentationNowUtc() => _bridgeFixtureNowUtc;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'camera bridge clipboard helper copies shared presentation payload',
    () async {
      String? clipboardText;
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
        checkedAtUtc: _bridgeCheckedAtUtc(),
        operatorId: 'OPS-ALPHA',
      );
      final presentation = resolveOnyxCameraBridgeSurfacePresentation(
        status: status,
        localSnapshot: snapshot,
        healthProbeConfigured: true,
        variant: OnyxCameraBridgeSurfaceToneVariant.agent,
        nowUtc: _bridgePresentationNowUtc(),
      );

      final message = await copyOnyxCameraBridgeSetupToClipboard(
        status: status,
        presentation: presentation,
      );

      expect(message, 'Camera bridge setup copied.');
      expect(clipboardText, isNotNull);
      expect(clipboardText, contains('ONYX CAMERA BRIDGE'));
      expect(clipboardText, contains('Shell state: READY'));
      expect(clipboardText, contains('Receipt state: CURRENT'));
      expect(clipboardText, contains('Validated by: OPS-ALPHA'));
    },
  );
}
