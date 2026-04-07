import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/ui/onyx_camera_bridge_summary_panel.dart';

void main() {
  testWidgets('camera bridge summary panel renders agent variant', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OnyxCameraBridgeSummaryPanel(summary: 'Agent summary'),
        ),
      ),
    );

    expect(find.text('Agent summary'), findsOneWidget);
    expect(find.byType(Container), findsNothing);
  });

  testWidgets('camera bridge summary panel renders admin variant', (
    tester,
  ) async {
    const accent = Color(0xFF67E8F9);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OnyxCameraBridgeSummaryPanel(
            panelKey: ValueKey('summary'),
            summary: 'Admin summary',
            accent: accent,
            variant: OnyxCameraBridgeSummaryPanelVariant.admin,
          ),
        ),
      ),
    );

    expect(find.text('Admin summary'), findsOneWidget);

    final container = tester.widget<Container>(
      find.byKey(const ValueKey('summary')),
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFFFFFFFF));
    expect(
      (decoration.border! as Border).top.color,
      accent.withValues(alpha: 0.28),
    );
  });
}
