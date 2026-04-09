import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

MqttClient createPlatformOnyxOlarmMqttClient({
  required String brokerUrl,
  required String clientIdentifier,
  required int port,
}) {
  final client = MqttServerClient(brokerUrl, clientIdentifier)
    ..port = port
    ..useWebSocket = true
    ..websocketProtocols = MqttClientConstants.protocolsSingleDefault;
  return client;
}
