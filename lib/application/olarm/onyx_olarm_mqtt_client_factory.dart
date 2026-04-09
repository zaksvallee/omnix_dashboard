import 'package:mqtt_client/mqtt_client.dart';

import 'onyx_olarm_mqtt_client_factory_io.dart'
    if (dart.library.html) 'onyx_olarm_mqtt_client_factory_web.dart';

MqttClient createOnyxOlarmMqttClient({
  required String brokerUrl,
  required String clientIdentifier,
  required int port,
}) {
  return createPlatformOnyxOlarmMqttClient(
    brokerUrl: brokerUrl,
    clientIdentifier: clientIdentifier,
    port: port,
  );
}
