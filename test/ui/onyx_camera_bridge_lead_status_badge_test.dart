import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/onyx_agent_camera_bridge_server_contract.dart';
import 'package:omnix_dashboard/ui/onyx_camera_bridge_lead_status_badge.dart';
import 'package:omnix_dashboard/ui/onyx_camera_bridge_status_badge.dart';

void main() {
  testWidgets('camera bridge lead status badge renders agent variant', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OnyxCameraBridgeLeadStatusBadge(
            status: OnyxAgentCameraBridgeStatus(
              enabled: true,
              running: true,
              statusLabel: 'Live',
            ),
            accent: Color(0xFF34D399),
          ),
        ),
      ),
    );

    expect(find.text('LIVE'), findsOneWidget);

    final badge = tester.widget<OnyxCameraBridgeStatusBadge>(
      find.byType(OnyxCameraBridgeStatusBadge),
    );

    expect(badge.backgroundColor, isNull);
    expect(badge.fontSize, 9.8);
  });

  testWidgets('camera bridge lead status badge renders admin variant', (
    tester,
  ) async {
    const accent = Color(0xFF67E8F9);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OnyxCameraBridgeLeadStatusBadge(
            status: OnyxAgentCameraBridgeStatus(
              enabled: false,
              running: false,
              statusLabel: 'Disabled',
            ),
            accent: accent,
            variant: OnyxCameraBridgeLeadStatusBadgeVariant.admin,
          ),
        ),
      ),
    );

    expect(find.text('DISABLED'), findsOneWidget);

    final badge = tester.widget<OnyxCameraBridgeStatusBadge>(
      find.byType(OnyxCameraBridgeStatusBadge),
    );

    expect(badge.backgroundColor, accent.withValues(alpha: 0.15));
    expect(badge.borderColor, accent.withValues(alpha: 0.45));
    expect(badge.fontSize, 9);
  });
}
