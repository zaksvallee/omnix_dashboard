import 'onyx_agent_camera_bridge_receiver.dart';
import 'onyx_agent_camera_bridge_server_contract.dart';

OnyxAgentCameraBridgeServer createOnyxAgentCameraBridgeServer({
  required OnyxAgentCameraBridgeReceiver receiver,
  required String host,
  required int port,
  String authToken = '',
}) {
  return const UnsupportedOnyxAgentCameraBridgeServer();
}

class UnsupportedOnyxAgentCameraBridgeServer
    implements OnyxAgentCameraBridgeServer {
  const UnsupportedOnyxAgentCameraBridgeServer();

  @override
  bool get isRunning => false;

  @override
  Uri? get endpoint => null;

  @override
  Future<void> start() async {}

  @override
  Future<void> close() async {}
}
