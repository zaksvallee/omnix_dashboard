class HikConnectLiveAddressResponse {
  final String primaryUrl;
  final Map<String, String> urlsByKey;
  final Map<String, Object?> rawData;

  const HikConnectLiveAddressResponse({
    required this.primaryUrl,
    required this.urlsByKey,
    required this.rawData,
  });

  factory HikConnectLiveAddressResponse.fromApiResponse(
    Map<String, Object?> response,
  ) {
    final data = _asObjectMap(response['data']);
    final urlsByKey = <String, String>{};
    for (final entry in data.entries) {
      final value = entry.value;
      if (value is! String) {
        continue;
      }
      final trimmed = value.trim();
      if (_looksLikeUrl(trimmed)) {
        urlsByKey[entry.key] = trimmed;
      }
    }
    final primaryUrl = _firstNonEmpty(
      urlsByKey,
      const [
        'url',
        'liveUrl',
        'wssUrl',
        'wsUrl',
        'hlsUrl',
        'flvUrl',
        'rtmpUrl',
        'rtspUrl',
      ],
    );
    return HikConnectLiveAddressResponse(
      primaryUrl: primaryUrl,
      urlsByKey: Map<String, String>.unmodifiable(urlsByKey),
      rawData: Map<String, Object?>.unmodifiable(data),
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

  static bool _looksLikeUrl(String raw) {
    final value = raw.trim().toLowerCase();
    return value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('ws://') ||
        value.startsWith('wss://') ||
        value.startsWith('rtsp://') ||
        value.startsWith('rtmp://');
  }

  static String _firstNonEmpty(
    Map<String, String> urlsByKey,
    List<String> preferredKeys,
  ) {
    for (final key in preferredKeys) {
      final value = urlsByKey[key];
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    for (final value in urlsByKey.values) {
      if (value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }
}

class HikConnectRecordElement {
  final String recordId;
  final String beginTime;
  final String endTime;
  final String playbackUrl;
  final Map<String, Object?> raw;

  const HikConnectRecordElement({
    required this.recordId,
    required this.beginTime,
    required this.endTime,
    required this.playbackUrl,
    required this.raw,
  });

  factory HikConnectRecordElement.fromJson(Map<String, Object?> raw) {
    return HikConnectRecordElement(
      recordId: _readString(raw, const [
        'recordId',
        'recordID',
        'id',
        'taskId',
      ]),
      beginTime: _readString(raw, const [
        'beginTime',
        'startTime',
        'recordBeginTime',
      ]),
      endTime: _readString(raw, const ['endTime', 'stopTime', 'recordEndTime']),
      playbackUrl: _readString(raw, const [
        'playbackUrl',
        'playUrl',
        'url',
      ]),
      raw: Map<String, Object?>.unmodifiable(raw),
    );
  }

  static String _readString(Map<String, Object?> raw, List<String> keys) {
    for (final key in keys) {
      final value = (raw[key] ?? '').toString().trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }
}

class HikConnectRecordElementSearchResult {
  final int totalCount;
  final int pageIndex;
  final int pageSize;
  final List<HikConnectRecordElement> records;
  final Map<String, Object?> rawData;

  const HikConnectRecordElementSearchResult({
    required this.totalCount,
    required this.pageIndex,
    required this.pageSize,
    required this.records,
    required this.rawData,
  });

  factory HikConnectRecordElementSearchResult.fromApiResponse(
    Map<String, Object?> response,
  ) {
    final data = _asObjectMap(response['data']);
    final list = data['recordList'] ?? data['list'] ?? data['items'];
    final rawRecords = list is List ? list : const <Object?>[];
    return HikConnectRecordElementSearchResult(
      totalCount: _asInt(data['totalCount'] ?? data['total']),
      pageIndex: _asInt(data['pageIndex']),
      pageSize: _asInt(data['pageSize']),
      records: rawRecords
          .whereType<Map>()
          .map(
            (entry) => HikConnectRecordElement.fromJson(
              entry.map(
                (key, value) => MapEntry(key.toString(), value as Object?),
              ),
            ),
          )
          .toList(growable: false),
      rawData: Map<String, Object?>.unmodifiable(data),
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

  static int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse((value ?? '').toString().trim()) ?? 0;
  }
}

class HikConnectVideoDownloadResult {
  final String downloadUrl;
  final Map<String, Object?> rawData;

  const HikConnectVideoDownloadResult({
    required this.downloadUrl,
    required this.rawData,
  });

  factory HikConnectVideoDownloadResult.fromApiResponse(
    Map<String, Object?> response,
  ) {
    final data = _asObjectMap(response['data']);
    final downloadUrl = (data['downloadUrl'] ?? data['url'] ?? '')
        .toString()
        .trim();
    return HikConnectVideoDownloadResult(
      downloadUrl: downloadUrl,
      rawData: Map<String, Object?>.unmodifiable(data),
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
