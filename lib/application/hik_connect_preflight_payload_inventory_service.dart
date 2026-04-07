import 'dart:io';

class HikConnectPreflightPayloadInventoryService {
  const HikConnectPreflightPayloadInventoryService();

  List<Map<String, Object?>> buildInventory({
    required String cameraPayloadPath,
    required String alarmPayloadPath,
    required String liveAddressPayloadPath,
    required String playbackPayloadPath,
    required String videoDownloadPayloadPath,
  }) {
    return List<Map<String, Object?>>.unmodifiable(<Map<String, Object?>>[
      _entry('camera', cameraPayloadPath),
      _entry('alarm', alarmPayloadPath),
      _entry('live_address', liveAddressPayloadPath),
      _entry('playback', playbackPayloadPath),
      _entry('video_download', videoDownloadPayloadPath),
    ]);
  }

  Map<String, Object?> _entry(String key, String path) {
    final trimmed = path.trim();
    final configured = trimmed.isNotEmpty;
    if (!configured) {
      return <String, Object?>{
        'key': key,
        'configured': false,
        'exists': false,
        'status': 'unset',
        'path': '',
        'size_bytes': 0,
      };
    }
    final file = File(trimmed);
    final exists = file.existsSync();
    return <String, Object?>{
      'key': key,
      'configured': configured,
      'exists': exists,
      'status': configured
          ? (exists ? 'found' : 'configured_missing')
          : 'unset',
      'path': trimmed,
      'size_bytes': exists ? file.lengthSync() : 0,
    };
  }
}
