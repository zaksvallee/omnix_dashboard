import 'onyx_olarm_device.dart';

abstract class OnyxOlarmService {
  Future<List<OnyxOlarmDevice>> getDevices();
  Future<OnyxOlarmDevice> getDevice(String deviceId);
  Future<void> armArea(String deviceId, String areaId);
  Future<void> disarmArea(String deviceId, String areaId);
  Future<void> stayArea(String deviceId, String areaId);
  Stream<OnyxOlarmEvent> get events;
  Future<void> connect();
  Future<void> disconnect();
  bool get isConnected;
}

class OnyxOlarmEvent {
  final String deviceId;
  final OnyxOlarmEventType eventType;
  final String? zoneId;
  final String? areaId;
  final DateTime occurredAt;
  final Map<String, dynamic> rawPayload;

  const OnyxOlarmEvent({
    required this.deviceId,
    required this.eventType,
    this.zoneId,
    this.areaId,
    required this.occurredAt,
    required this.rawPayload,
  });
}

enum OnyxOlarmEventType {
  zoneOpen,
  zoneClosed,
  areaArmed,
  areaDisarmed,
  areaTriggered,
  tamper,
  powerFailure,
  unknown,
}
