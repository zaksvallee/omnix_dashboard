class HikConnectAlarmBatch {
  final String batchId;
  final List<HikConnectAlarmMessage> messages;

  const HikConnectAlarmBatch({
    required this.batchId,
    required this.messages,
  });

  factory HikConnectAlarmBatch.fromApiResponse(Map<String, Object?> response) {
    final data = _asObjectMap(response['data']);
    final rawMessages = data['alarmMsg'];
    final messageItems = rawMessages is List ? rawMessages : const <Object?>[];
    return HikConnectAlarmBatch(
      batchId: (data['batchId'] ?? '').toString().trim(),
      messages: messageItems
          .whereType<Map>()
          .map(
            (entry) => HikConnectAlarmMessage.fromJson(
              entry.map(
                (key, value) => MapEntry(key.toString(), value as Object?),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  static Map<String, Object?> _asObjectMap(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, dynamicValue) => MapEntry(key.toString(), dynamicValue),
      );
    }
    return const <String, Object?>{};
  }
}

class HikConnectAlarmMessage {
  final String guid;
  final String systemId;
  final String msgType;
  final String alarmState;
  final String alarmSubCategory;
  final HikConnectAlarmTimeInfo timeInfo;
  final HikConnectAlarmSource eventSource;
  final HikConnectAlarmRule alarmRule;
  final HikConnectAnprInfo anprInfo;
  final HikConnectAlarmFileInfo fileInfo;

  const HikConnectAlarmMessage({
    required this.guid,
    required this.systemId,
    required this.msgType,
    required this.alarmState,
    required this.alarmSubCategory,
    required this.timeInfo,
    required this.eventSource,
    required this.alarmRule,
    required this.anprInfo,
    required this.fileInfo,
  });

  factory HikConnectAlarmMessage.fromJson(Map<String, Object?> raw) {
    return HikConnectAlarmMessage(
      guid: (raw['guid'] ?? '').toString().trim(),
      systemId: (raw['systemId'] ?? '').toString().trim(),
      msgType: (raw['msgType'] ?? '').toString().trim(),
      alarmState: (raw['alarmState'] ?? '').toString().trim(),
      alarmSubCategory: (raw['alarmSubCategory'] ?? '').toString().trim(),
      timeInfo: HikConnectAlarmTimeInfo.fromJson(_asObjectMap(raw['timeInfo'])),
      eventSource: HikConnectAlarmSource.fromJson(
        _asObjectMap(raw['eventSource']),
      ),
      alarmRule: HikConnectAlarmRule.fromJson(_asObjectMap(raw['alarmRule'])),
      anprInfo: HikConnectAnprInfo.fromJson(_asObjectMap(raw['anprInfo'])),
      fileInfo: HikConnectAlarmFileInfo.fromJson(_asObjectMap(raw['fileInfo'])),
    );
  }

  Map<String, Object?> toPayloadMap() {
    return <String, Object?>{
      if (guid.isNotEmpty) 'guid': guid,
      if (systemId.isNotEmpty) 'systemId': systemId,
      if (msgType.isNotEmpty) 'msgType': msgType,
      if (alarmState.isNotEmpty) 'alarmState': alarmState,
      if (alarmSubCategory.isNotEmpty) 'alarmSubCategory': alarmSubCategory,
      'timeInfo': timeInfo.toJson(),
      'eventSource': eventSource.toJson(),
      'alarmRule': alarmRule.toJson(),
      'anprInfo': anprInfo.toJson(),
      'fileInfo': fileInfo.toJson(),
    };
  }

  static Map<String, Object?> _asObjectMap(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, dynamicValue) => MapEntry(key.toString(), dynamicValue),
      );
    }
    return const <String, Object?>{};
  }
}

class HikConnectAlarmTimeInfo {
  final String startTime;
  final String startTimeLocal;
  final String endTime;
  final String endTimeLocal;

  const HikConnectAlarmTimeInfo({
    required this.startTime,
    required this.startTimeLocal,
    required this.endTime,
    required this.endTimeLocal,
  });

  factory HikConnectAlarmTimeInfo.fromJson(Map<String, Object?> raw) {
    return HikConnectAlarmTimeInfo(
      startTime: (raw['startTime'] ?? '').toString().trim(),
      startTimeLocal: (raw['startTimeLocal'] ?? '').toString().trim(),
      endTime: (raw['endTime'] ?? '').toString().trim(),
      endTimeLocal: (raw['endTimeLocal'] ?? '').toString().trim(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    if (startTime.isNotEmpty) 'startTime': startTime,
    if (startTimeLocal.isNotEmpty) 'startTimeLocal': startTimeLocal,
    if (endTime.isNotEmpty) 'endTime': endTime,
    if (endTimeLocal.isNotEmpty) 'endTimeLocal': endTimeLocal,
  };
}

class HikConnectAlarmSource {
  final String sourceId;
  final String sourceName;
  final String areaName;
  final String eventType;
  final String deviceName;

  const HikConnectAlarmSource({
    required this.sourceId,
    required this.sourceName,
    required this.areaName,
    required this.eventType,
    required this.deviceName,
  });

  factory HikConnectAlarmSource.fromJson(Map<String, Object?> raw) {
    final deviceInfo = raw['deviceInfo'];
    final deviceMap = deviceInfo is Map
        ? deviceInfo.map(
            (key, value) => MapEntry(key.toString(), value as Object?),
          )
        : const <String, Object?>{};
    return HikConnectAlarmSource(
      sourceId: (raw['sourceID'] ?? '').toString().trim(),
      sourceName: (raw['sourceName'] ?? '').toString().trim(),
      areaName: (raw['areaName'] ?? '').toString().trim(),
      eventType: (raw['eventType'] ?? '').toString().trim(),
      deviceName: (deviceMap['devName'] ?? '').toString().trim(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    if (sourceId.isNotEmpty) 'sourceID': sourceId,
    if (sourceName.isNotEmpty) 'sourceName': sourceName,
    if (areaName.isNotEmpty) 'areaName': areaName,
    if (eventType.isNotEmpty) 'eventType': eventType,
    if (deviceName.isNotEmpty)
      'deviceInfo': <String, Object?>{'devName': deviceName},
  };
}

class HikConnectAlarmRule {
  final String name;

  const HikConnectAlarmRule({required this.name});

  factory HikConnectAlarmRule.fromJson(Map<String, Object?> raw) {
    return HikConnectAlarmRule(name: (raw['name'] ?? '').toString().trim());
  }

  Map<String, Object?> toJson() =>
      name.isEmpty ? const <String, Object?>{} : <String, Object?>{'name': name};
}

class HikConnectAnprInfo {
  final String licensePlate;

  const HikConnectAnprInfo({required this.licensePlate});

  factory HikConnectAnprInfo.fromJson(Map<String, Object?> raw) {
    return HikConnectAnprInfo(
      licensePlate: (raw['licensePlate'] ?? '').toString().trim(),
    );
  }

  Map<String, Object?> toJson() => licensePlate.isEmpty
      ? const <String, Object?>{}
      : <String, Object?>{'licensePlate': licensePlate};
}

class HikConnectAlarmFile {
  final String type;
  final String fileUrl;

  const HikConnectAlarmFile({
    required this.type,
    required this.fileUrl,
  });

  factory HikConnectAlarmFile.fromJson(Map<String, Object?> raw) {
    return HikConnectAlarmFile(
      type: (raw['type'] ?? '').toString().trim(),
      fileUrl: ((raw['fileUrl'] ?? raw['URL']) ?? '').toString().trim(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    if (type.isNotEmpty) 'type': type,
    if (fileUrl.isNotEmpty) 'URL': fileUrl,
  };
}

class HikConnectAlarmFileInfo {
  final List<HikConnectAlarmFile> files;

  const HikConnectAlarmFileInfo({required this.files});

  factory HikConnectAlarmFileInfo.fromJson(Map<String, Object?> raw) {
    final fileEntries = raw['file'];
    final rawFiles = fileEntries is List ? fileEntries : const <Object?>[];
    return HikConnectAlarmFileInfo(
      files: rawFiles
          .whereType<Map>()
          .map(
            (entry) => HikConnectAlarmFile.fromJson(
              entry.map(
                (key, value) => MapEntry(key.toString(), value as Object?),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    if (files.isNotEmpty) 'file': files.map((entry) => entry.toJson()).toList(),
  };
}
