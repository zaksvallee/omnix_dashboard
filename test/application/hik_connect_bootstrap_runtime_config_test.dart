import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/hik_connect_bootstrap_runtime_config.dart';

void main() {
  group('HikConnectBootstrapRuntimeConfig', () {
    test('parses runtime env with sane defaults', () {
      final config = HikConnectBootstrapRuntimeConfig.fromEnvironment(
        <String, String>{
          'ONYX_DVR_CLIENT_ID': 'CLIENT-MS-VALLEE',
          'ONYX_DVR_REGION_ID': 'REGION-GAUTENG',
          'ONYX_DVR_SITE_ID': 'SITE-MS-VALLEE-RESIDENCE',
          'ONYX_DVR_API_BASE_URL': 'https://api.hik-connect.example.com',
          'ONYX_DVR_APP_KEY': 'app-key',
          'ONYX_DVR_APP_SECRET': 'app-secret',
          'ONYX_DVR_INCLUDE_SUB_AREA': 'false',
          'ONYX_DVR_DEVICE_SERIAL_NO': 'SERIAL-001',
          'ONYX_DVR_ALARM_EVENT_TYPES': '0, 1 100657',
          'ONYX_DVR_PAGE_SIZE': '50',
          'ONYX_DVR_MAX_PAGES': '4',
        },
      );

      expect(config.configured, isTrue);
      expect(config.provider, 'hik_connect_openapi');
      expect(config.apiBaseUri?.host, 'api.hik-connect.example.com');
      expect(config.includeSubArea, isFalse);
      expect(config.deviceSerialNo, 'SERIAL-001');
      expect(config.alarmEventTypes, <int>[0, 1, 100657]);
      expect(config.pageSize, 50);
      expect(config.maxPages, 4);
      expect(config.cameraPayloadPath, isEmpty);

      final apiConfig = config.toApiConfig();
      expect(apiConfig.clientId, 'CLIENT-MS-VALLEE');
      expect(apiConfig.siteId, 'SITE-MS-VALLEE-RESIDENCE');
      expect(apiConfig.alarmEventTypes, <int>[0, 1, 100657]);
    });

    test('reports validation errors for missing required env', () {
      final config = HikConnectBootstrapRuntimeConfig.fromEnvironment(
        <String, String>{
          'ONYX_DVR_PROVIDER': 'hikvision_dvr',
          'ONYX_DVR_API_BASE_URL': 'not-a-url',
        },
      );

      expect(config.configured, isFalse);
      expect(
        config.validationErrors,
        contains('Missing ONYX_DVR_CLIENT_ID.'),
      );
      expect(
        config.validationErrors,
        contains('Missing ONYX_DVR_REGION_ID.'),
      );
      expect(config.validationErrors, contains('Missing ONYX_DVR_SITE_ID.'));
      expect(
        config.validationErrors,
        contains(
          'Missing or invalid ONYX_DVR_API_BASE_URL. Use a full HTTPS base URL.',
        ),
      );
      expect(config.validationErrors, contains('Missing ONYX_DVR_APP_KEY.'));
      expect(config.validationErrors, contains('Missing ONYX_DVR_APP_SECRET.'));
      expect(
        config.validationErrors,
        contains(
          'ONYX_DVR_PROVIDER must target Hik-Connect OpenAPI for this bootstrap tool.',
        ),
      );
    });

    test('allows offline payload bootstrap without live credentials', () {
      final config = HikConnectBootstrapRuntimeConfig.fromEnvironment(
        <String, String>{
          'ONYX_DVR_CLIENT_ID': 'CLIENT-MS-VALLEE',
          'ONYX_DVR_REGION_ID': 'REGION-GAUTENG',
          'ONYX_DVR_SITE_ID': 'SITE-MS-VALLEE-RESIDENCE',
          'ONYX_DVR_API_BASE_URL': 'https://api.hik-connect.example.com',
          'ONYX_DVR_CAMERA_PAYLOAD_PATH': '/tmp/vallee-camera-pages.json',
        },
      );

      expect(config.usesSavedCameraPayload, isTrue);
      expect(config.configured, isTrue);
      expect(config.appKey, isEmpty);
      expect(config.appSecret, isEmpty);
    });
  });
}
