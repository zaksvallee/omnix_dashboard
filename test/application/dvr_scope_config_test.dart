import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/dvr_scope_config.dart';

void main() {
  group('DvrScopeConfig', () {
    test('parses configured fleet DVR scopes', () {
      final configs = DvrScopeConfig.parseJson(
        '''
        [
          {
            "client_id": "CLIENT-MS-VALLEE",
            "region_id": "REGION-GAUTENG",
            "site_id": "SITE-MS-VALLEE-RESIDENCE",
            "provider": "hikvision_dvr_monitor_only",
            "events_url": "http://192.168.8.105/ISAPI/Event/notification/alertStream",
            "auth_mode": "digest",
            "username": "onyx",
            "password": "secret",
            "camera_labels": {
              "channel-13": "Front Yard",
              "channel-12": "Back Yard"
            }
          },
          {
            "client_id": "CLIENT-BETA",
            "region_id": "REGION-GAUTENG",
            "site_id": "SITE-BETA",
            "provider": "hikvision_dvr_monitor_only",
            "events_url": "http://192.168.8.106/ISAPI/Event/notification/alertStream"
          }
        ]
        ''',
        fallbackClientId: 'CLIENT-FALLBACK',
        fallbackRegionId: 'REGION-FALLBACK',
        fallbackSiteId: 'SITE-FALLBACK',
        fallbackProvider: 'hikvision_dvr_monitor_only',
        fallbackEventsUri: Uri.parse('http://192.168.8.200/events'),
        fallbackAuthMode: 'digest',
        fallbackUsername: '',
        fallbackPassword: '',
        fallbackBearerToken: '',
      );

      expect(configs, hasLength(2));
      expect(configs.first.clientId, 'CLIENT-MS-VALLEE');
      expect(configs.first.eventsUri?.host, '192.168.8.105');
      expect(configs.first.authMode, 'digest');
      expect(configs.first.username, 'onyx');
      expect(configs.first.cameraLabels['channel-13'], 'Front Yard');
      expect(configs.first.cameraLabels['channel-12'], 'Back Yard');
      expect(configs[1].siteId, 'SITE-BETA');
      expect(configs[1].eventsUri?.host, '192.168.8.106');
      expect(configs[1].authMode, 'digest');
      expect(configs[1].cameraLabels, isEmpty);
    });

    test('returns empty when config is blank', () {
      final configs = DvrScopeConfig.parseJson(
        '',
        fallbackClientId: 'CLIENT-FALLBACK',
        fallbackRegionId: 'REGION-FALLBACK',
        fallbackSiteId: 'SITE-FALLBACK',
        fallbackProvider: 'hikvision_dvr_monitor_only',
        fallbackEventsUri: Uri.parse('http://192.168.8.200/events'),
        fallbackAuthMode: 'digest',
        fallbackUsername: '',
        fallbackPassword: '',
        fallbackBearerToken: '',
      );

      expect(configs, isEmpty);
    });

    test('parses Hik-Connect OpenAPI cloud scope config', () {
      final configs = DvrScopeConfig.parseJson(
        '''
        [
          {
            "client_id": "CLIENT-MS-VALLEE",
            "region_id": "REGION-GAUTENG",
            "site_id": "SITE-MS-VALLEE-RESIDENCE",
            "provider": "hik_connect_openapi",
            "api_base_url": "https://api.hik-connect.example.com",
            "app_key": "app-key",
            "app_secret": "app-secret",
            "area_id": "-1",
            "include_sub_area": true,
            "device_serial_no": "SERIAL-001",
            "alarm_event_types": [0, 1, 100657],
            "camera_labels": {
              "camera-front": "Front Yard"
            }
          }
        ]
        ''',
        fallbackClientId: 'CLIENT-FALLBACK',
        fallbackRegionId: 'REGION-FALLBACK',
        fallbackSiteId: 'SITE-FALLBACK',
        fallbackProvider: 'hikvision_dvr_monitor_only',
        fallbackEventsUri: Uri.parse('http://192.168.8.200/events'),
        fallbackAuthMode: 'digest',
        fallbackUsername: '',
        fallbackPassword: '',
        fallbackBearerToken: '',
      );

      expect(configs, hasLength(1));
      expect(configs.first.provider, 'hik_connect_openapi');
      expect(configs.first.eventsUri, isNull);
      expect(configs.first.apiBaseUri?.host, 'api.hik-connect.example.com');
      expect(configs.first.hikConnectConfigured, isTrue);
      expect(configs.first.appKey, 'app-key');
      expect(configs.first.appSecret, 'app-secret');
      expect(configs.first.areaId, '-1');
      expect(configs.first.includeSubArea, isTrue);
      expect(configs.first.deviceSerialNo, 'SERIAL-001');
      expect(configs.first.alarmEventTypes, <int>[0, 1, 100657]);
      expect(configs.first.cameraLabels['camera-front'], 'Front Yard');
    });
  });
}
