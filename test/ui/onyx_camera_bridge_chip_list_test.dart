import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/onyx_agent_camera_bridge_health_service.dart';
import 'package:omnix_dashboard/ui/onyx_camera_bridge_chip_list.dart';
import 'package:omnix_dashboard/ui/onyx_camera_bridge_status_badge.dart';
import 'package:omnix_dashboard/ui/onyx_camera_bridge_tone_resolver.dart';

void main() {
  testWidgets('camera bridge chip list renders agent chips without fill', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnyxCameraBridgeChipList(
            leading: const Text('LEAD'),
            chips: const [
              OnyxAgentCameraBridgeChip(
                label: 'AUTH REQUIRED',
                tone: OnyxAgentCameraBridgeChipTone.warning,
              ),
            ],
            statusAccent: const Color(0xFF34D399),
          ),
        ),
      ),
    );

    expect(find.text('LEAD'), findsOneWidget);
    expect(find.text('AUTH REQUIRED'), findsOneWidget);

    final badge = tester.widget<OnyxCameraBridgeStatusBadge>(
      find.byType(OnyxCameraBridgeStatusBadge),
    );

    expect(badge.backgroundColor, isNull);
    expect(badge.fontSize, 9.8);
  });

  testWidgets('camera bridge chip list renders admin chips with fill', (
    tester,
  ) async {
    const statusAccent = Color(0xFF67E8F9);
    final chipColor = resolveOnyxCameraBridgeChipColorForStatusAccent(
      OnyxAgentCameraBridgeChipTone.status,
      statusAccent: statusAccent,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OnyxCameraBridgeChipList(
            chips: [
              OnyxAgentCameraBridgeChip(
                label: 'Packet ingress ready',
                tone: OnyxAgentCameraBridgeChipTone.status,
              ),
            ],
            statusAccent: statusAccent,
            variant: OnyxCameraBridgeChipListVariant.admin,
          ),
        ),
      ),
    );

    expect(find.text('Packet ingress ready'), findsOneWidget);

    final badge = tester.widget<OnyxCameraBridgeStatusBadge>(
      find.byType(OnyxCameraBridgeStatusBadge),
    );

    expect(badge.backgroundColor, chipColor.withValues(alpha: 0.12));
    expect(badge.borderColor, chipColor.withValues(alpha: 0.35));
    expect(badge.fontSize, 9);
  });
}
