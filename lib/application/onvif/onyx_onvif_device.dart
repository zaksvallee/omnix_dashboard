class OnyxOnvifProfile {
  final String token;
  final String name;
  final String? streamUri;
  final String? snapshotUri;

  const OnyxOnvifProfile({
    required this.token,
    required this.name,
    this.streamUri,
    this.snapshotUri,
  });

  OnyxOnvifProfile copyWith({
    String? token,
    String? name,
    String? streamUri,
    bool clearStreamUri = false,
    String? snapshotUri,
    bool clearSnapshotUri = false,
  }) {
    return OnyxOnvifProfile(
      token: token ?? this.token,
      name: name ?? this.name,
      streamUri: clearStreamUri ? null : streamUri ?? this.streamUri,
      snapshotUri: clearSnapshotUri ? null : snapshotUri ?? this.snapshotUri,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is OnyxOnvifProfile &&
        other.token == token &&
        other.name == name &&
        other.streamUri == streamUri &&
        other.snapshotUri == snapshotUri;
  }

  @override
  int get hashCode => Object.hash(token, name, streamUri, snapshotUri);
}

class OnyxOnvifDevice {
  final String id;
  final String host;
  final int port;
  final String username;
  final String password;
  final String? name;
  final String? manufacturer;
  final String? model;
  final String? firmwareVersion;
  final List<OnyxOnvifProfile> profiles;
  final bool isReachable;
  final DateTime? lastSeen;

  const OnyxOnvifDevice({
    required this.id,
    required this.host,
    this.port = 80,
    required this.username,
    required this.password,
    this.name,
    this.manufacturer,
    this.model,
    this.firmwareVersion,
    this.profiles = const <OnyxOnvifProfile>[],
    this.isReachable = false,
    this.lastSeen,
  });

  OnyxOnvifDevice copyWith({
    String? id,
    String? host,
    int? port,
    String? username,
    String? password,
    String? name,
    bool clearName = false,
    String? manufacturer,
    bool clearManufacturer = false,
    String? model,
    bool clearModel = false,
    String? firmwareVersion,
    bool clearFirmwareVersion = false,
    List<OnyxOnvifProfile>? profiles,
    bool? isReachable,
    DateTime? lastSeen,
    bool clearLastSeen = false,
  }) {
    return OnyxOnvifDevice(
      id: id ?? this.id,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      name: clearName ? null : name ?? this.name,
      manufacturer: clearManufacturer
          ? null
          : manufacturer ?? this.manufacturer,
      model: clearModel ? null : model ?? this.model,
      firmwareVersion: clearFirmwareVersion
          ? null
          : firmwareVersion ?? this.firmwareVersion,
      profiles: profiles ?? this.profiles,
      isReachable: isReachable ?? this.isReachable,
      lastSeen: clearLastSeen ? null : lastSeen ?? this.lastSeen,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is OnyxOnvifDevice &&
        other.id == id &&
        other.host == host &&
        other.port == port &&
        other.username == username &&
        other.password == password &&
        other.name == name &&
        other.manufacturer == manufacturer &&
        other.model == model &&
        other.firmwareVersion == firmwareVersion &&
        _listEquals(other.profiles, profiles) &&
        other.isReachable == isReachable &&
        other.lastSeen == lastSeen;
  }

  @override
  int get hashCode => Object.hash(
    id,
    host,
    port,
    username,
    password,
    name,
    manufacturer,
    model,
    firmwareVersion,
    Object.hashAll(profiles),
    isReachable,
    lastSeen,
  );

  static bool _listEquals(
    List<OnyxOnvifProfile> left,
    List<OnyxOnvifProfile> right,
  ) {
    if (left.length != right.length) {
      return false;
    }

    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }

    return true;
  }
}
