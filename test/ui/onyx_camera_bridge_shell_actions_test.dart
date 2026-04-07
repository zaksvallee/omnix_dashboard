import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/onyx_agent_camera_bridge_health_service.dart';
import 'package:omnix_dashboard/ui/onyx_camera_bridge_shell_actions.dart';

void main() {
  testWidgets('camera bridge shell actions render agent labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OnyxCameraBridgeShellActions(
            validateButtonKey: ValueKey('validate'),
            onValidate: null,
            validateBusy: false,
            receiptState: OnyxAgentCameraBridgeReceiptState.missing,
            clearButtonKey: ValueKey('clear'),
            showClearAction: true,
            onClear: null,
            clearBusy: false,
            copyButtonKey: ValueKey('copy'),
            onCopy: null,
            accent: Color(0xFF34D399),
          ),
        ),
      ),
    );

    expect(find.text('Run First Validation'), findsOneWidget);
    expect(find.text('Clear Bridge Receipt'), findsOneWidget);
    expect(find.text('Copy Setup'), findsOneWidget);
  });

  testWidgets('camera bridge shell actions render admin labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OnyxCameraBridgeShellActions(
            validateButtonKey: ValueKey('validate'),
            onValidate: null,
            validateBusy: false,
            receiptState: OnyxAgentCameraBridgeReceiptState.current,
            clearButtonKey: ValueKey('clear'),
            showClearAction: true,
            onClear: null,
            clearBusy: false,
            copyButtonKey: ValueKey('copy'),
            onCopy: null,
            accent: Color(0xFF67E8F9),
            variant: OnyxCameraBridgeShellActionsVariant.admin,
          ),
        ),
      ),
    );

    expect(find.text('RE-VALIDATE BRIDGE'), findsOneWidget);
    expect(find.text('CLEAR BRIDGE RECEIPT'), findsOneWidget);
    expect(find.text('COPY BRIDGE SETUP'), findsOneWidget);
  });
}
