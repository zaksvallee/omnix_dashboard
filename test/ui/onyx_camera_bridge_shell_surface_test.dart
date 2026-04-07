import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/ui/onyx_camera_bridge_shell_card.dart';
import 'package:omnix_dashboard/ui/onyx_camera_bridge_shell_surface.dart';

void main() {
  testWidgets('camera bridge shell surface renders agent variant', (
    tester,
  ) async {
    const accent = Color(0xFF34D399);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OnyxCameraBridgeShellSurface(
            accent: accent,
            child: Text('Agent shell'),
          ),
        ),
      ),
    );

    expect(find.text('Agent shell'), findsOneWidget);

    final card = tester.widget<OnyxCameraBridgeShellCard>(
      find.byType(OnyxCameraBridgeShellCard),
    );
    expect(card.backgroundColor, const Color(0xFFFBFDFF));
    expect(card.borderRadius, 12);
    expect(card.borderColor, accent.withValues(alpha: 0.28));
  });

  testWidgets('camera bridge shell surface renders admin variant', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OnyxCameraBridgeShellSurface(
            accent: Color(0xFF67E8F9),
            variant: OnyxCameraBridgeShellSurfaceVariant.admin,
            child: Text('Admin shell'),
          ),
        ),
      ),
    );

    expect(find.text('Admin shell'), findsOneWidget);

    final card = tester.widget<OnyxCameraBridgeShellCard>(
      find.byType(OnyxCameraBridgeShellCard),
    );
    expect(card.backgroundColor, const Color(0xFFFFFFFF));
    expect(card.borderRadius, 16);
    expect(card.borderColor, const Color(0xFFD4DFEA));
  });
}
