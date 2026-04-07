import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/onyx_agent_camera_bridge_server_contract.dart';
import 'package:omnix_dashboard/ui/onyx_camera_bridge_status_metadata_block.dart';
import 'package:omnix_dashboard/ui/onyx_camera_bridge_status_metadata_panel.dart';

void main() {
  final status = OnyxAgentCameraBridgeStatus(
    enabled: true,
    running: true,
    authRequired: true,
    endpoint: Uri(scheme: 'http', host: '127.0.0.1', port: 11634),
    statusLabel: 'Live',
    detail: 'Embedded LAN listener is active.',
  );

  testWidgets('camera bridge status metadata panel renders agent variant', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnyxCameraBridgeStatusMetadataPanel(status: status),
        ),
      ),
    );

    expect(find.text('Embedded LAN listener is active.'), findsOneWidget);

    final block = tester.widget<OnyxCameraBridgeStatusMetadataBlock>(
      find.byType(OnyxCameraBridgeStatusMetadataBlock),
    );
    expect(block.fields.first.label, 'Bind');
    expect(block.valueColor, const Color(0xFFDCE8F7));
    expect(block.fieldBottomPadding, 6);
    expect(block.detailTopSpacing, 8);
  });

  testWidgets('camera bridge status metadata panel renders admin variant', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnyxCameraBridgeStatusMetadataPanel(
            status: status,
            variant: OnyxCameraBridgeStatusMetadataPanelVariant.admin,
          ),
        ),
      ),
    );

    expect(find.text('Embedded LAN listener is active.'), findsOneWidget);

    final block = tester.widget<OnyxCameraBridgeStatusMetadataBlock>(
      find.byType(OnyxCameraBridgeStatusMetadataBlock),
    );
    expect(block.fields.first.label, 'Bind address');
    expect(block.valueColor, const Color(0xFFEAF4FF));
    expect(block.fieldBottomPadding, 8);
    expect(block.detailTopSpacing, 10);
  });
}
