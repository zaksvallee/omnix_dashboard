import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';

MqttClient createPlatformOnyxOlarmMqttClient({
  required String brokerUrl,
  required String clientIdentifier,
  required int port,
}) {
  final client = MqttBrowserClient(brokerUrl, clientIdentifier)
    ..port = port
    ..websocketProtocols = MqttClientConstants.protocolsSingleDefault;
  return client;
}
