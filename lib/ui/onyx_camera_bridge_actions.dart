import '../application/onyx_agent_camera_bridge_health_service.dart';
import '../application/onyx_agent_camera_bridge_server_contract.dart';
import 'onyx_camera_bridge_clipboard.dart';
import 'onyx_camera_bridge_tone_resolver.dart';

Future<void> runOnyxCameraBridgeValidationAction({
  required OnyxAgentCameraBridgeLocalState currentState,
  required OnyxAgentCameraBridgeStatus status,
  required OnyxAgentCameraBridgeHealthService service,
  required String operatorId,
  required void Function(OnyxAgentCameraBridgeLocalState) onLocalStateChanged,
  required bool Function() isMounted,
  required void Function(OnyxAgentCameraBridgeHealthSnapshot) onSnapshotChanged,
  required void Function(String) onMessage,
}) async {
  final endpoint = status.endpoint;
  if (endpoint == null) {
    onMessage(describeOnyxAgentCameraBridgeEndpointMissingMessage());
    return;
  }
  onLocalStateChanged(currentState.beginValidation());
  final outcome = await completeOnyxAgentCameraBridgeValidation(
    service: service,
    endpoint: endpoint,
    operatorId: operatorId,
  );
  if (!isMounted()) {
    return;
  }
  onLocalStateChanged(currentState.finishValidation(outcome.snapshot));
  onSnapshotChanged(outcome.snapshot);
  onMessage(outcome.message);
}

Future<void> runOnyxCameraBridgeClearAction({
  required OnyxAgentCameraBridgeLocalState currentState,
  required OnyxAgentCameraBridgeHealthSnapshot? snapshot,
  required Future<void> Function()? onClearReceipt,
  required void Function(OnyxAgentCameraBridgeLocalState) onLocalStateChanged,
  required bool Function() isMounted,
  required void Function(String) onMessage,
}) async {
  if (snapshot == null) {
    return;
  }
  onLocalStateChanged(currentState.beginReset());
  final outcome = await completeOnyxAgentCameraBridgeClear(
    onClearReceipt: onClearReceipt,
  );
  if (!isMounted()) {
    return;
  }
  onLocalStateChanged(
    currentState.finishReset(
      success: outcome.success,
      previousSnapshot: snapshot,
    ),
  );
  onMessage(outcome.message);
}

Future<void> runOnyxCameraBridgeCopyAction({
  required OnyxAgentCameraBridgeStatus status,
  required OnyxCameraBridgeSurfacePresentation presentation,
  required bool Function() isMounted,
  required void Function(String) onMessage,
  String? leadingText,
}) async {
  final message = await copyOnyxCameraBridgeSetupToClipboard(
    status: status,
    presentation: presentation,
    leadingText: leadingText,
  );
  if (!isMounted()) {
    return;
  }
  onMessage(message);
}
