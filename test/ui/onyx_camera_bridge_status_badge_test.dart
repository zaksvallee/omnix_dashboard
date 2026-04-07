import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/ui/onyx_camera_bridge_status_badge.dart';

void main() {
  testWidgets('camera bridge status badge renders configured colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OnyxCameraBridgeStatusBadge(
            label: 'LIVE',
            foregroundColor: Color(0xFF34D399),
            backgroundColor: Color(0x2200FF00),
            borderColor: Color(0xFF22C55E),
            fontSize: 9.4,
          ),
        ),
      ),
    );

    expect(find.text('LIVE'), findsOneWidget);

    final container = tester.widget<Container>(find.byType(Container).first);
    final decoration = container.decoration! as BoxDecoration;

    expect(decoration.color, const Color(0x2200FF00));
    expect((decoration.border! as Border).top.color, const Color(0xFF22C55E));
  });

  testWidgets('camera bridge status badge supports transparent background', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OnyxCameraBridgeStatusBadge(
            label: 'DISABLED',
            foregroundColor: Color(0xFFCBD5E1),
            borderColor: Color(0xFF94A3B8),
          ),
        ),
      ),
    );

    final container = tester.widget<Container>(find.byType(Container).first);
    final decoration = container.decoration! as BoxDecoration;

    expect(decoration.color, isNull);
    expect(find.text('DISABLED'), findsOneWidget);
  });
}
