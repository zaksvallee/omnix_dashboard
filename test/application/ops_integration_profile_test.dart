import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/dvr_scope_config.dart';
import 'package:omnix_dashboard/application/ops_integration_profile.dart';

void main() {
  test('radio profile resolves duplex readiness and details', () {
    final profile = OnyxOpsIntegrationProfile.fromEnvironment(
      radioProvider: 'zello',
      radioListenUrl: 'https://radio.example.com/listen',
      radioRespondUrl: 'https://radio.example.com/respond',
      radioChannel: 'client-ops',
      radioAiAutoAllClearEnabled: true,
      cctvProvider: '',
      cctvEventsUrl: '',
      cctvLiveMonitoringEnabled: false,
      cctvFacialRecognitionEnabled: false,
      cctvLicensePlateRecognitionEnabled: false,
      dvrProvider: '',
      dvrEventsUrl: '',
    );

    expect(profile.radio.readinessLabel, 'LISTEN + RESPOND');
    expect(profile.radio.duplexEnabled, isTrue);
    expect(profile.radio.detailLabel, contains('zello'));
    expect(profile.radio.detailLabel, contains('AI all-clear enabled'));
  });

  test('cctv profile advertises live monitoring, FR, and LPR', () {
    final profile = OnyxOpsIntegrationProfile.fromEnvironment(
      radioProvider: '',
      radioListenUrl: '',
      radioRespondUrl: '',
      radioChannel: '',
      radioAiAutoAllClearEnabled: false,
      cctvProvider: 'hikvision',
      cctvEventsUrl: 'https://cctv.example.com/events',
      cctvLiveMonitoringEnabled: true,
      cctvFacialRecognitionEnabled: true,
      cctvLicensePlateRecognitionEnabled: true,
      dvrProvider: '',
      dvrEventsUrl: '',
    );

    expect(profile.cctv.readinessLabel, 'ACTIVE');
    expect(
      profile.cctv.capabilityLabels,
      containsAll(<String>['LIVE AI MONITORING', 'FR', 'LPR']),
    );
  });

  test(
    'monitor-only dvr profile becomes active video path when cctv is unconfigured',
    () {
      final profile = OnyxOpsIntegrationProfile.fromEnvironment(
        radioProvider: '',
        radioListenUrl: '',
        radioRespondUrl: '',
        radioChannel: '',
        radioAiAutoAllClearEnabled: false,
        cctvProvider: '',
        cctvEventsUrl: '',
        cctvLiveMonitoringEnabled: false,
        cctvFacialRecognitionEnabled: false,
        cctvLicensePlateRecognitionEnabled: false,
        dvrProvider: 'hikvision_dvr_monitor_only',
        dvrEventsUrl:
            'https://dvr.example.com/ISAPI/Event/notification/alertStream',
      );

      expect(profile.dvr.configured, isTrue);
      expect(profile.activeVideo.isDvr, isTrue);
      expect(profile.activeVideo.provider, 'hikvision_dvr_monitor_only');
      expect(profile.activeVideo.capabilityLabels, <String>[
        'LIVE AI MONITORING',
      ]);
    },
  );

  test('cctv retains precedence when both cctv and dvr are configured', () {
    final profile = OnyxOpsIntegrationProfile.fromEnvironment(
      radioProvider: '',
      radioListenUrl: '',
      radioRespondUrl: '',
      radioChannel: '',
      radioAiAutoAllClearEnabled: false,
      cctvProvider: 'frigate',
      cctvEventsUrl: 'https://edge.example.com/api/events',
      cctvLiveMonitoringEnabled: true,
      cctvFacialRecognitionEnabled: false,
      cctvLicensePlateRecognitionEnabled: false,
      dvrProvider: 'hikvision_dvr',
      dvrEventsUrl:
          'https://dvr.example.com/ISAPI/Event/notification/alertStream',
    );

    expect(profile.activeVideo.isDvr, isFalse);
    expect(profile.activeVideo.provider, 'frigate');
  });

  test('dvr scope configs can supply the active video path when env is blank', () {
    final profile = OnyxOpsIntegrationProfile.activeVideoFromDvrScopes(
      <DvrScopeConfig>[
        DvrScopeConfig(
          clientId: 'CLIENT-MS-VALLEE',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          provider: 'hikvision_dvr',
          eventsUri: Uri(
            scheme: 'https',
            host: 'dvr.example.com',
            path: '/ISAPI/Event/notification/alertStream',
          ),
          authMode: 'digest',
          username: 'admin',
          password: 'secret',
          bearerToken: '',
        ),
      ],
      preferredClientId: 'CLIENT-MS-VALLEE',
      preferredSiteId: 'SITE-MS-VALLEE-RESIDENCE',
    );

    expect(profile.configured, isTrue);
    expect(profile.isDvr, isTrue);
    expect(profile.provider, 'hikvision_dvr');
    expect(profile.supportsMonitoringWatch, isTrue);
    expect(profile.capabilityLabels, <String>['LIVE AI MONITORING']);
  });

  test('hik-connect cloud scope can supply the active video path when env is blank', () {
    final profile = OnyxOpsIntegrationProfile.activeVideoFromDvrScopes(
      <DvrScopeConfig>[
        DvrScopeConfig(
          clientId: 'CLIENT-MS-VALLEE',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          provider: 'hik_connect_openapi',
          eventsUri: null,
          apiBaseUri: Uri(
            scheme: 'https',
            host: 'api.hik-connect.example.com',
          ),
          authMode: '',
          username: '',
          password: '',
          bearerToken: '',
          appKey: 'app-key',
          appSecret: 'app-secret',
          alarmEventTypes: <int>[0, 1, 100657],
        ),
      ],
      preferredClientId: 'CLIENT-MS-VALLEE',
      preferredSiteId: 'SITE-MS-VALLEE-RESIDENCE',
    );

    expect(profile.configured, isTrue);
    expect(profile.isDvr, isTrue);
    expect(profile.provider, 'hik_connect_openapi');
    expect(profile.supportsMonitoringWatch, isTrue);
    expect(profile.capabilityLabels, contains('LIVE AI MONITORING'));
    expect(profile.capabilityLabels, contains('LPR'));
  });

  test('radio all-clear classifier detects safe confirmations', () {
    expect(
      OnyxRadioAllClearClassifier.indicatesAllClear(
        'Control, all clear at gate two. Client safe.',
      ),
      isTrue,
    );
    expect(
      OnyxRadioAllClearClassifier.indicatesAllClear(
        'Officer on site, investigating breach alarm now.',
      ),
      isFalse,
    );
  });

  test(
    'radio intent classifier detects panic, duress, status, and unknown',
    () {
      expect(
        OnyxRadioIntentClassifier.detect(
          'Panic button pressed. Need backup now at north gate.',
        ),
        OnyxRadioIntent.panic,
      );
      expect(
        OnyxRadioIntentClassifier.detect(
          'Control, silent duress triggered. Unsafe code confirmed.',
        ),
        OnyxRadioIntent.duress,
      );
      expect(
        OnyxRadioIntentClassifier.detect(
          'Status update: officer en route and checkpoint complete.',
        ),
        OnyxRadioIntent.status,
      );
      expect(OnyxRadioIntentClassifier.detect('...'), OnyxRadioIntent.unknown);
    },
  );

  test('radio intent catalog supports JSON phrase overrides', () {
    final catalog = OnyxRadioIntentPhraseCatalog.fromJsonString('''
{
  "all_clear": ["secure now"],
  "panic": ["code red now"],
  "duress": ["silent alarm"],
  "status": ["progress update"]
}
''', fallback: OnyxRadioIntentPhraseCatalog.defaults());

    expect(
      OnyxRadioIntentClassifier.detectWithCatalog(
        'Control confirms secure now at gate one.',
        catalog,
      ),
      OnyxRadioIntent.allClear,
    );
    expect(
      OnyxRadioIntentClassifier.detectWithCatalog(
        'Code red now, backup needed.',
        catalog,
      ),
      OnyxRadioIntent.panic,
    );
    expect(
      OnyxRadioIntentClassifier.detectWithCatalog(
        'Trigger silent alarm without escalation wording.',
        catalog,
      ),
      OnyxRadioIntent.duress,
    );
    expect(
      OnyxRadioIntentClassifier.detectWithCatalog(
        'Progress update from Echo-3.',
        catalog,
      ),
      OnyxRadioIntent.status,
    );
  });

  test('radio intent catalog falls back safely on invalid JSON', () {
    final fallback = OnyxRadioIntentPhraseCatalog.defaults();
    final catalog = OnyxRadioIntentPhraseCatalog.fromJsonString(
      '{not-json',
      fallback: fallback,
    );

    expect(catalog.allClearPhrases, fallback.allClearPhrases);
    expect(catalog.panicPhrases, fallback.panicPhrases);
    expect(catalog.duressPhrases, fallback.duressPhrases);
    expect(catalog.statusPhrases, fallback.statusPhrases);
  });
}
