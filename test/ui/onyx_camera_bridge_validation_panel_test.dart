import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/onyx_agent_camera_bridge_health_service.dart';
import 'package:omnix_dashboard/ui/onyx_camera_bridge_validation_panel.dart';
import 'package:omnix_dashboard/ui/onyx_camera_bridge_validation_summary.dart';

void main() {
  testWidgets('camera bridge validation panel renders agent variant', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OnyxCameraBridgeValidationPanel(
            runtimeState: OnyxAgentCameraBridgeRuntimeState(
              receiptState: OnyxAgentCameraBridgeReceiptState.current,
              shellState: OnyxAgentCameraBridgeShellState.ready,
              validationSummary: 'Receipt is current.',
              validationTone: OnyxAgentCameraBridgeValidationTone.success,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Receipt is current.'), findsOneWidget);

    final summary = tester.widget<OnyxCameraBridgeValidationSummary>(
      find.byType(OnyxCameraBridgeValidationSummary),
    );
    expect(summary.color, const Color(0xFF9FE6B8));
    expect(summary.topSpacing, 8);
    expect(summary.fontSize, 10.9);
  });

  testWidgets('camera bridge validation panel renders admin variant', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OnyxCameraBridgeValidationPanel(
            runtimeState: OnyxAgentCameraBridgeRuntimeState(
              receiptState: OnyxAgentCameraBridgeReceiptState.stale,
              shellState: OnyxAgentCameraBridgeShellState.receiptStale,
              validationSummary: 'Receipt is stale.',
              validationTone: OnyxAgentCameraBridgeValidationTone.warning,
            ),
            variant: OnyxCameraBridgeValidationPanelVariant.admin,
          ),
        ),
      ),
    );

    expect(find.text('Receipt is stale.'), findsOneWidget);

    final summary = tester.widget<OnyxCameraBridgeValidationSummary>(
      find.byType(OnyxCameraBridgeValidationSummary),
    );
    expect(summary.color, const Color(0xFFFDE68A));
    expect(summary.topSpacing, 10);
    expect(summary.fontSize, 11.0);
  });
}
