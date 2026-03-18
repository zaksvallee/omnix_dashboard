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
  });
}
