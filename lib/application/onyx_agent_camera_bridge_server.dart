import 'onyx_agent_camera_bridge_receiver.dart';
import 'onyx_agent_camera_bridge_server_contract.dart';
import 'onyx_agent_camera_bridge_server_stub.dart'
    if (dart.library.io) 'onyx_agent_camera_bridge_server_io.dart'
    as bridge_server;

OnyxAgentCameraBridgeServer createOnyxAgentCameraBridgeServer({
  required OnyxAgentCameraBridgeReceiver receiver,
  required String host,
  required int port,
  String authToken = '',
}) {
  return bridge_server.createOnyxAgentCameraBridgeServer(
    receiver: receiver,
    host: host,
    port: port,
    authToken: authToken,
  );
}
