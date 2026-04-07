import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/ui/onyx_camera_bridge_health_panel.dart';
import 'package:omnix_dashboard/ui/onyx_camera_bridge_health_card.dart';

void main() {
  testWidgets('camera bridge health panel renders agent loading copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OnyxCameraBridgeHealthPanel(
            snapshot: null,
            accent: Color(0xFF34D399),
            receiptStateLabel: null,
          ),
        ),
      ),
    );

    expect(
      find.text('Running GET /health against the local camera bridge...'),
      findsOneWidget,
    );

    final card = tester.widget<OnyxCameraBridgeHealthCard>(
      find.byType(OnyxCameraBridgeHealthCard),
    );
    expect(card.backgroundColor, Colors.white);
  });

  testWidgets('camera bridge health panel renders admin loading copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OnyxCameraBridgeHealthPanel(
            snapshot: null,
            accent: Color(0xFF67E8F9),
            receiptStateLabel: null,
            variant: OnyxCameraBridgeHealthPanelVariant.admin,
          ),
        ),
      ),
    );

    expect(
      find.text(
        'Running GET /health against the configured local bridge endpoint...',
      ),
      findsOneWidget,
    );

    final card = tester.widget<OnyxCameraBridgeHealthCard>(
      find.byType(OnyxCameraBridgeHealthCard),
    );
    expect(card.backgroundColor, const Color(0xFFF7FAFD));
  });
}
