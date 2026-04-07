import 'hik_connect_camera_bootstrap_service.dart';

class HikConnectEnvSeedFormatter {
  const HikConnectEnvSeedFormatter();

  String formatEnvBlock({
    required HikConnectCameraBootstrapSnapshot snapshot,
    required String apiBaseUrl,
    String appKey = 'replace-me',
    String appSecret = 'replace-me',
    String areaId = '-1',
    bool includeSubArea = true,
    List<int> alarmEventTypes = const <int>[0, 1, 100657],
    String provider = 'hik_connect_openapi',
  }) {
    final lines = <String>[
      'ONYX_DVR_PROVIDER=${_shellEscape(provider.trim())}',
      'ONYX_DVR_API_BASE_URL=${_shellEscape(apiBaseUrl.trim())}',
      'ONYX_DVR_APP_KEY=${_shellEscape(appKey.trim())}',
      'ONYX_DVR_APP_SECRET=${_shellEscape(appSecret.trim())}',
      'ONYX_DVR_AREA_ID=${_shellEscape(areaId.trim())}',
      'ONYX_DVR_INCLUDE_SUB_AREA=${includeSubArea ? 'true' : 'false'}',
      'ONYX_DVR_ALARM_EVENT_TYPES=${_shellEscape(alarmEventTypes.join(','))}',
    ];

    final preferredSerial = snapshot.preferredDeviceSerialNo.trim();
    if (preferredSerial.isNotEmpty) {
      lines.add('ONYX_DVR_DEVICE_SERIAL_NO=${_shellEscape(preferredSerial)}');
    } else if (snapshot.deviceSerials.isNotEmpty) {
      lines.add(
        '# ONYX_DVR_DEVICE_SERIAL_NO=choose-one-of:${snapshot.deviceSerials.join('|')}',
      );
    }

    return lines.map((line) => 'export $line').join('\n');
  }

  String _shellEscape(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return "''";
    }
    final escaped = value.replaceAll("'", "'\"'\"'");
    return "'$escaped'";
  }
}
