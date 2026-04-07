import 'dart:io';

Future<bool> onyxAgentCanConnect(
  String host,
  int port,
  Duration timeout,
) async {
  try {
    final socket = await Socket.connect(host, port, timeout: timeout);
    await socket.close();
    return true;
  } catch (_) {
    return false;
  }
}
