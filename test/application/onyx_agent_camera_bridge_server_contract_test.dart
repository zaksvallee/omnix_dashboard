import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/onyx_agent_camera_bridge_server_contract.dart';

void main() {
  group('camera bridge server contract', () {
    test('builds shared agent and admin detail fields from bridge status', () {
      final status = OnyxAgentCameraBridgeStatus(
        enabled: true,
        running: true,
        authRequired: true,
        endpoint: Uri.parse('http://127.0.0.1:11634'),
        statusLabel: 'Live',
        detail: 'Ready for LAN workers.',
      );

      expect(status.visibleDetailFields(), [
        isA<OnyxAgentCameraBridgeStatusDetail>()
            .having((field) => field.label, 'label', 'Bind')
            .having((field) => field.value, 'value', 'http://127.0.0.1:11634'),
        isA<OnyxAgentCameraBridgeStatusDetail>()
            .having((field) => field.label, 'label', 'Routes')
            .having(
              (field) => field.value,
              'value',
              'POST /execute • GET /health',
            ),
        isA<OnyxAgentCameraBridgeStatusDetail>()
            .having((field) => field.label, 'label', 'Access')
            .having(
              (field) => field.value,
              'value',
              'Bearer token required for remote posts',
            ),
      ]);
      expect(
        status.visibleDetailFields(
          variant: OnyxAgentCameraBridgeStatusDetailVariant.admin,
        ),
        [
          isA<OnyxAgentCameraBridgeStatusDetail>()
              .having((field) => field.label, 'label', 'Bind address')
              .having(
                (field) => field.value,
                'value',
                'http://127.0.0.1:11634',
              ),
          isA<OnyxAgentCameraBridgeStatusDetail>()
              .having((field) => field.label, 'label', 'Routes')
              .having(
                (field) => field.value,
                'value',
                'POST /execute • GET /health',
              ),
          isA<OnyxAgentCameraBridgeStatusDetail>()
              .having((field) => field.label, 'label', 'Access')
              .having(
                (field) => field.value,
                'value',
                'Bearer token required for remote packet posts',
              ),
        ],
      );
    });

    test('clipboard payload uses absolute routes and shared auth copy', () {
      final status = OnyxAgentCameraBridgeStatus(
        enabled: true,
        running: true,
        authRequired: false,
        endpoint: Uri.parse('http://127.0.0.1:11634'),
        statusLabel: 'Live',
        detail: 'Ready for LAN workers.',
      );

      expect(
        status.toClipboardPayload(),
        contains(
          'Routes: POST http://127.0.0.1:11634/execute • GET http://127.0.0.1:11634/health',
        ),
      );
      expect(status.toClipboardPayload(), contains('Auth: Local access open'));
    });
  });
}
