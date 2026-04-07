import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/dvr_http_auth.dart';
import 'package:omnix_dashboard/application/dvr_scope_config.dart';
import 'package:omnix_dashboard/application/local_hikvision_dvr_proxy_runtime_config.dart';

void main() {
  const resolver = LocalHikvisionDvrProxyRuntimeConfigResolver();

  test('resolves loopback-scoped local Hikvision proxy runtime config', () {
    final config = resolver.resolve(
      scopes: <DvrScopeConfig>[
        DvrScopeConfig(
          clientId: 'CLIENT-MS-VALLEE',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          provider: 'hikvision_dvr_monitor_only',
          eventsUri: Uri(
            scheme: 'http',
            host: '127.0.0.1',
            port: 11635,
            path: '/ISAPI/Event/notification/alertStream',
          ),
          authMode: 'none',
          username: '',
          password: '',
          bearerToken: '',
        ),
      ],
      upstreamAlertStreamUri: Uri.parse(
        'http://192.168.0.117/ISAPI/Event/notification/alertStream',
      ),
      upstreamAuthMode: 'digest',
      upstreamUsername: 'admin',
      upstreamPassword: 'secret',
    );

    expect(config, isNotNull);
    expect(config!.bindHost, '127.0.0.1');
    expect(config.bindPort, 11635);
    expect(
      config.upstreamAlertStreamUri.toString(),
      'http://192.168.0.117/ISAPI/Event/notification/alertStream',
    );
    expect(config.upstreamAuth.mode, DvrHttpAuthMode.digest);
    expect(config.upstreamAuth.username, 'admin');
    expect(config.upstreamAuth.password, 'secret');
  });

  test('returns null without a loopback events scope', () {
    final config = resolver.resolve(
      scopes: <DvrScopeConfig>[
        DvrScopeConfig(
          clientId: 'CLIENT-MS-VALLEE',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          provider: 'hikvision_dvr_monitor_only',
          eventsUri: Uri(
            scheme: 'http',
            host: '192.168.0.117',
            port: 80,
            path: '/ISAPI/Event/notification/alertStream',
          ),
          authMode: 'digest',
          username: 'admin',
          password: 'secret',
          bearerToken: '',
        ),
      ],
      upstreamAlertStreamUri: Uri.parse(
        'http://192.168.0.117/ISAPI/Event/notification/alertStream',
      ),
      upstreamAuthMode: 'digest',
      upstreamUsername: 'admin',
      upstreamPassword: 'secret',
    );

    expect(config, isNull);
  });

  test('returns null when upstream is missing or loops back to itself', () {
    expect(
      resolver.resolve(
        scopes: <DvrScopeConfig>[
          DvrScopeConfig(
            clientId: 'CLIENT-MS-VALLEE',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-MS-VALLEE-RESIDENCE',
            provider: 'hikvision_dvr_monitor_only',
            eventsUri: Uri(
              scheme: 'http',
              host: 'localhost',
              port: 11635,
              path: '/ISAPI/Event/notification/alertStream',
            ),
            authMode: 'none',
            username: '',
            password: '',
            bearerToken: '',
          ),
        ],
        upstreamAlertStreamUri: null,
        upstreamAuthMode: 'none',
      ),
      isNull,
    );

    expect(
      resolver.resolve(
        scopes: <DvrScopeConfig>[
          DvrScopeConfig(
            clientId: 'CLIENT-MS-VALLEE',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-MS-VALLEE-RESIDENCE',
            provider: 'hikvision_dvr_monitor_only',
            eventsUri: Uri(
              scheme: 'http',
              host: '127.0.0.1',
              port: 11635,
              path: '/ISAPI/Event/notification/alertStream',
            ),
            authMode: 'none',
            username: '',
            password: '',
            bearerToken: '',
          ),
        ],
        upstreamAlertStreamUri: Uri.parse(
          'http://127.0.0.1:11635/ISAPI/Event/notification/alertStream',
        ),
        upstreamAuthMode: 'none',
      ),
      isNull,
    );
  });
}
