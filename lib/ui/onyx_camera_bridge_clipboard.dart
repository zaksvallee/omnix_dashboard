import 'package:flutter/services.dart';

import '../application/onyx_agent_camera_bridge_health_service.dart';
import '../application/onyx_agent_camera_bridge_server_contract.dart';
import 'onyx_camera_bridge_tone_resolver.dart';

String buildOnyxCameraBridgeClipboardPayloadForPresentation({
  required OnyxAgentCameraBridgeStatus status,
  required OnyxCameraBridgeSurfacePresentation presentation,
  String? leadingText,
}) {
  final payload = buildOnyxAgentCameraBridgeClipboardPayloadForSurfaceState(
    status: status,
    surfaceState: presentation.surfaceState,
    snapshot: presentation.effectiveSnapshot,
  );
  final seedText = (leadingText ?? '').trim();
  if (seedText.isEmpty) {
    return payload;
  }
  return '$seedText\n\n$payload';
}

Future<String> copyOnyxCameraBridgeSetupToClipboard({
  required OnyxAgentCameraBridgeStatus status,
  required OnyxCameraBridgeSurfacePresentation presentation,
  String? leadingText,
}) async {
  await Clipboard.setData(
    ClipboardData(
      text: buildOnyxCameraBridgeClipboardPayloadForPresentation(
        status: status,
        presentation: presentation,
        leadingText: leadingText,
      ),
    ),
  );
  return describeOnyxAgentCameraBridgeCopyResultMessage();
}
