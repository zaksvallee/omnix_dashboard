import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/onyx_agent_camera_bridge_health_service.dart';
import 'package:omnix_dashboard/application/onyx_agent_camera_bridge_server_contract.dart';
import 'package:omnix_dashboard/ui/onyx_camera_bridge_shell_body.dart';

void main() {
  testWidgets('camera bridge shell body renders agent variant', (
    tester,
  ) async {
    final surfaceState = OnyxAgentCameraBridgeSurfaceState(
      runtimeState: const OnyxAgentCameraBridgeRuntimeState(
        receiptState: OnyxAgentCameraBridgeReceiptState.current,
        shellState: OnyxAgentCameraBridgeShellState.ready,
        validationSummary: 'Receipt is current.',
        validationTone: OnyxAgentCameraBridgeValidationTone.success,
      ),
      controls: const OnyxAgentCameraBridgeHealthControlState(
        showHealthCard: true,
        showClearReceiptAction: true,
        canValidate: true,
        canClearReceipt: true,
      ),
      shellSummary:
          'LAN workers can target http://127.0.0.1:11634/execute and poll http://127.0.0.1:11634/health right now.',
      controllerCardSummary:
          'Local camera bridge is ready for LAN worker packets.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnyxCameraBridgeShellBody(
            status: OnyxAgentCameraBridgeStatus(
              enabled: true,
              running: true,
              authRequired: true,
              endpoint: Uri.parse('http://127.0.0.1:11634'),
              statusLabel: 'Live',
              detail: 'Agent bridge detail.',
            ),
            surfaceState: surfaceState,
            snapshot: null,
            accent: const Color(0xFF67E8F9),
            healthAccent: const Color(0xFF34D399),
            healthCardKey: const ValueKey('agent-health'),
            validateButtonKey: const ValueKey('agent-validate'),
            onValidate: null,
            validateBusy: false,
            clearButtonKey: const ValueKey('agent-clear'),
            onClear: null,
            clearBusy: false,
            copyButtonKey: const ValueKey('agent-copy'),
            onCopy: null,
            chipLeading: const Icon(Icons.memory_rounded),
          ),
        ),
      ),
    );

    expect(
      find.text('Local camera bridge is ready for LAN worker packets.'),
      findsOneWidget,
    );
    expect(find.text('Receipt is current.'), findsOneWidget);
    expect(find.text('Agent bridge detail.'), findsOneWidget);
    expect(
      find.text('Running GET /health against the local camera bridge...'),
      findsOneWidget,
    );
    expect(find.text('Re-Validate Bridge'), findsOneWidget);
    expect(find.text('Clear Bridge Receipt'), findsOneWidget);
    expect(find.text('Copy Setup'), findsOneWidget);
  });

  testWidgets('camera bridge shell body renders admin variant', (
    tester,
  ) async {
    final surfaceState = OnyxAgentCameraBridgeSurfaceState(
      runtimeState: const OnyxAgentCameraBridgeRuntimeState(
        receiptState: OnyxAgentCameraBridgeReceiptState.stale,
        shellState: OnyxAgentCameraBridgeShellState.receiptStale,
        validationSummary: 'Receipt is stale.',
        validationTone: OnyxAgentCameraBridgeValidationTone.warning,
      ),
      controls: const OnyxAgentCameraBridgeHealthControlState(
        showHealthCard: false,
        showClearReceiptAction: false,
        canValidate: true,
        canClearReceipt: false,
      ),
      shellSummary:
          'Bridge validation receipt is stale. Re-run GET /health before trusting http://127.0.0.1:11634 for LAN worker setup.',
      controllerCardSummary:
          'Local camera bridge is ready for LAN worker packets.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnyxCameraBridgeShellBody(
            status: OnyxAgentCameraBridgeStatus(
              enabled: true,
              running: true,
              endpoint: Uri.parse('http://127.0.0.1:11634'),
              statusLabel: 'Live',
              detail: 'Admin bridge detail.',
            ),
            surfaceState: surfaceState,
            snapshot: null,
            accent: const Color(0xFF67E8F9),
            healthAccent: const Color(0xFFFDE68A),
            summaryPanelKey: const ValueKey('admin-summary'),
            validateButtonKey: const ValueKey('admin-validate'),
            onValidate: null,
            validateBusy: false,
            clearButtonKey: const ValueKey('admin-clear'),
            onClear: null,
            clearBusy: false,
            copyButtonKey: const ValueKey('admin-copy'),
            onCopy: null,
            variant: OnyxCameraBridgeShellBodyVariant.admin,
          ),
        ),
      ),
    );

    expect(
      find.text(
        'Bridge validation receipt is stale. Re-run GET /health before trusting http://127.0.0.1:11634 for LAN worker setup.',
      ),
      findsOneWidget,
    );
    expect(find.text('Receipt is stale.'), findsOneWidget);
    expect(find.text('Admin bridge detail.'), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-summary')), findsOneWidget);
    expect(
      find.text(
        'Running GET /health against the configured local bridge endpoint...',
      ),
      findsNothing,
    );
    expect(find.text('RE-VALIDATE BRIDGE'), findsOneWidget);
    expect(find.text('COPY BRIDGE SETUP'), findsOneWidget);
  });
}
