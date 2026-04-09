class OnyxOlarmDevice {
  final String deviceId;
  final String deviceName;
  final String deviceProfile;
  final List<OnyxOlarmArea> areas;
  final List<OnyxOlarmZone> zones;
  final DateTime? lastUpdated;

  const OnyxOlarmDevice({
    required this.deviceId,
    required this.deviceName,
    required this.deviceProfile,
    required this.areas,
    required this.zones,
    this.lastUpdated,
  });

  factory OnyxOlarmDevice.fromJson(
    Map<String, dynamic> json, {
    List<String> perimeterZoneIds = const <String>[],
  }) {
    final perimeterIds = perimeterZoneIds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    final deviceId = _olarmString(
          json['deviceId'],
          json['device_id'],
          json['id'],
          json['uuid'],
        ) ??
        '';
    final deviceName =
        _olarmString(
          json['deviceName'],
          json['device_name'],
          json['name'],
          json['label'],
        ) ??
        (deviceId.isEmpty ? 'Olarm device' : 'Olarm device $deviceId');
    final deviceProfile = _olarmDeviceProfileLabel(json);
    final areas = _olarmIterable(json['areas'])
        .map(
          (row) => OnyxOlarmArea.fromJson(
            row,
            fallbackNamePrefix: 'Area',
          ),
        )
        .toList(growable: false);
    final zones = _olarmIterable(json['zones'])
        .map(
          (row) => OnyxOlarmZone.fromJson(
            row,
            isPerimeterOverride: perimeterIds.contains(
              _olarmString(
                    row['zoneId'],
                    row['zone_id'],
                    row['id'],
                    row['num'],
                    row['number'],
                  ) ??
                  '',
            ),
            fallbackNamePrefix: 'Zone',
          ),
        )
        .toList(growable: false);
    return OnyxOlarmDevice(
      deviceId: deviceId,
      deviceName: deviceName,
      deviceProfile: deviceProfile,
      areas: areas,
      zones: zones,
      lastUpdated: _olarmDate(
        json['lastUpdated'],
        json['updatedAt'],
        json['updated_at'],
        json['last_seen_at'],
      ),
    );
  }

  OnyxOlarmArea? areaById(String areaId) {
    final normalizedAreaId = areaId.trim();
    if (normalizedAreaId.isEmpty) {
      return null;
    }
    for (final area in areas) {
      if (area.areaId.trim() == normalizedAreaId) {
        return area;
      }
    }
    return null;
  }

  OnyxOlarmZone? zoneById(String zoneId) {
    final normalizedZoneId = zoneId.trim();
    if (normalizedZoneId.isEmpty) {
      return null;
    }
    for (final zone in zones) {
      if (zone.zoneId.trim() == normalizedZoneId) {
        return zone;
      }
    }
    return null;
  }
}

class OnyxOlarmArea {
  final String areaId;
  final String areaName;
  final OnyxOlarmAreaStatus areaStatus;

  const OnyxOlarmArea({
    required this.areaId,
    required this.areaName,
    required this.areaStatus,
  });

  factory OnyxOlarmArea.fromJson(
    Map<String, dynamic> json, {
    String fallbackNamePrefix = 'Area',
  }) {
    final areaId =
        _olarmString(
          json['areaId'],
          json['area_id'],
          json['id'],
          json['num'],
          json['number'],
        ) ??
        '';
    return OnyxOlarmArea(
      areaId: areaId,
      areaName:
          _olarmString(
            json['areaName'],
            json['area_name'],
            json['name'],
            json['label'],
            json['description'],
          ) ??
          (areaId.isEmpty ? fallbackNamePrefix : '$fallbackNamePrefix $areaId'),
      areaStatus: OnyxOlarmAreaStatusX.fromRaw(
        json['areaStatus'],
        json['status'],
        json['state'],
        json['armStatus'],
        json['arm_status'],
        json['mode'],
      ),
    );
  }
}

class OnyxOlarmZone {
  final String zoneId;
  final String zoneName;
  final OnyxOlarmZoneStatus zoneStatus;
  final bool isPerimeter;

  const OnyxOlarmZone({
    required this.zoneId,
    required this.zoneName,
    required this.zoneStatus,
    required this.isPerimeter,
  });

  factory OnyxOlarmZone.fromJson(
    Map<String, dynamic> json, {
    bool? isPerimeterOverride,
    String fallbackNamePrefix = 'Zone',
  }) {
    final zoneId =
        _olarmString(
          json['zoneId'],
          json['zone_id'],
          json['id'],
          json['num'],
          json['number'],
        ) ??
        '';
    final zoneName =
        _olarmString(
          json['zoneName'],
          json['zone_name'],
          json['name'],
          json['label'],
          json['description'],
        ) ??
        (zoneId.isEmpty ? fallbackNamePrefix : '$fallbackNamePrefix $zoneId');
    return OnyxOlarmZone(
      zoneId: zoneId,
      zoneName: zoneName,
      zoneStatus: OnyxOlarmZoneStatusX.fromRaw(
        json['zoneStatus'],
        json['status'],
        json['state'],
        json['condition'],
      ),
      isPerimeter:
          isPerimeterOverride ?? _looksLikePerimeterZone(zoneName, json),
    );
  }
}

enum OnyxOlarmAreaStatus { disarmed, armed, stay, sleep, triggered, unknown }

extension OnyxOlarmAreaStatusX on OnyxOlarmAreaStatus {
  static OnyxOlarmAreaStatus fromRaw(Object? raw, [Object? raw2, Object? raw3, Object? raw4, Object? raw5, Object? raw6]) {
    final normalized = _olarmJoined(
      raw,
      raw2,
      raw3,
      raw4,
      raw5,
      raw6,
    );
    if (normalized.contains('trigger') || normalized.contains('alarm')) {
      return OnyxOlarmAreaStatus.triggered;
    }
    if (normalized.contains('sleep') || normalized.contains('night')) {
      return OnyxOlarmAreaStatus.sleep;
    }
    if (normalized.contains('stay')) {
      return OnyxOlarmAreaStatus.stay;
    }
    if (normalized.contains('disarm') ||
        normalized.contains('unset') ||
        normalized.contains('off')) {
      return OnyxOlarmAreaStatus.disarmed;
    }
    if (normalized.contains('arm') ||
        normalized.contains('away') ||
        normalized.contains('full')) {
      return OnyxOlarmAreaStatus.armed;
    }
    return OnyxOlarmAreaStatus.unknown;
  }
}

enum OnyxOlarmZoneStatus { closed, open, bypassed, tamper, unknown }

extension OnyxOlarmZoneStatusX on OnyxOlarmZoneStatus {
  static OnyxOlarmZoneStatus fromRaw(
    Object? raw, [
    Object? raw2,
    Object? raw3,
    Object? raw4,
  ]) {
    final normalized = _olarmJoined(raw, raw2, raw3, raw4);
    if (normalized.contains('tamper')) {
      return OnyxOlarmZoneStatus.tamper;
    }
    if (normalized.contains('bypass')) {
      return OnyxOlarmZoneStatus.bypassed;
    }
    if (normalized.contains('closed') ||
        normalized.contains('close') ||
        normalized.contains('normal') ||
        normalized.contains('secure') ||
        normalized.contains('restore')) {
      return OnyxOlarmZoneStatus.closed;
    }
    if (normalized.contains('open') ||
        normalized.contains('violat') ||
        normalized.contains('alarm') ||
        normalized.contains('active') ||
        normalized.contains('trigger')) {
      return OnyxOlarmZoneStatus.open;
    }
    return OnyxOlarmZoneStatus.unknown;
  }
}

List<Map<String, dynamic>> _olarmIterable(Object? raw) {
  if (raw is List) {
    return raw
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
  }
  if (raw is Map) {
    return raw.values
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
  }
  return const <Map<String, dynamic>>[];
}

String? _olarmString(
  Object? raw1, [
  Object? raw2,
  Object? raw3,
  Object? raw4,
  Object? raw5,
  Object? raw6,
]) {
  for (final raw in <Object?>[raw1, raw2, raw3, raw4, raw5, raw6]) {
    if (raw == null) {
      continue;
    }
    final value = raw.toString().trim();
    if (value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

String _olarmJoined(
  Object? raw1, [
  Object? raw2,
  Object? raw3,
  Object? raw4,
  Object? raw5,
  Object? raw6,
]) {
  return <Object?>[raw1, raw2, raw3, raw4, raw5, raw6]
      .where((value) => value != null)
      .map((value) => value.toString().trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .join(' ');
}

DateTime? _olarmDate(
  Object? raw1, [
  Object? raw2,
  Object? raw3,
  Object? raw4,
]) {
  for (final raw in <Object?>[raw1, raw2, raw3, raw4]) {
    if (raw == null) {
      continue;
    }
    if (raw is int) {
      final milliseconds = raw > 9999999999 ? raw : raw * 1000;
      return DateTime.fromMillisecondsSinceEpoch(
        milliseconds,
        isUtc: true,
      );
    }
    final parsed = DateTime.tryParse(raw.toString().trim());
    if (parsed != null) {
      return parsed.toUtc();
    }
  }
  return null;
}

String _olarmDeviceProfileLabel(Map<String, dynamic> json) {
  final rawProfile = json['deviceProfile'];
  if (rawProfile is String && rawProfile.trim().isNotEmpty) {
    return rawProfile.trim();
  }
  if (rawProfile is Map) {
    final map = Map<String, dynamic>.from(rawProfile);
    final direct =
        _olarmString(
          map['name'],
          map['panelModel'],
          map['panel_model'],
          map['panelType'],
          map['panel_type'],
          map['description'],
        ) ??
        '';
    if (direct.isNotEmpty) {
      return direct;
    }
  }
  return _olarmString(
        json['panelModel'],
        json['panel_model'],
        json['panelType'],
        json['panel_type'],
        json['deviceType'],
        json['device_type'],
      ) ??
      'unknown';
}

bool _looksLikePerimeterZone(String zoneName, Map<String, dynamic> json) {
  final normalizedName = zoneName.trim().toLowerCase();
  final typeCode = int.tryParse(
    _olarmString(
          json['zoneType'],
          json['zone_type'],
          json['type'],
          json['sensorType'],
          json['sensor_type'],
        ) ??
        '',
  );
  if (typeCode == 10 || typeCode == 11 || typeCode == 21) {
    return true;
  }
  return normalizedName.contains('perimeter') ||
      normalizedName.contains('front door') ||
      normalizedName.contains('back door') ||
      normalizedName.contains('door') ||
      normalizedName.contains('window') ||
      normalizedName.contains('gate') ||
      normalizedName.contains('garage') ||
      normalizedName.contains('entry') ||
      normalizedName.contains('outside') ||
      normalizedName.contains('exterior');
}
