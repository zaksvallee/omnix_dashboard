import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/dvr_scope_config.dart';
import 'package:omnix_dashboard/application/monitoring_watch_recovery_scope_resolver.dart';

void main() {
  group('MonitoringWatchRecoveryScopeResolver', () {
    const resolver = MonitoringWatchRecoveryScopeResolver();

    test(
      'builds recovery scopes and falls back to site id when label is empty',
      () {
        final output = resolver.resolve(
          scopes: [
            _scope(
              clientId: 'CLIENT-A',
              siteId: 'SITE-A',
              host: '192.168.8.105',
            ),
            _scope(
              clientId: 'CLIENT-B',
              siteId: 'SITE-B',
              host: '192.168.8.106',
            ),
          ],
          siteLabelForScope: (clientId, siteId) =>
              clientId == 'CLIENT-A' ? 'MS Vallee Residence' : '   ',
        );

        expect(output, hasLength(2));
        expect(output.first.scopeKey, 'CLIENT-A|SITE-A');
        expect(output.first.siteLabel, 'MS Vallee Residence');
        expect(output.last.scopeKey, 'CLIENT-B|SITE-B');
        expect(output.last.siteLabel, 'SITE-B');
      },
    );
  });
}

DvrScopeConfig _scope({
  required String clientId,
  required String siteId,
  required String host,
}) {
  return DvrScopeConfig(
    clientId: clientId,
    regionId: 'REGION-GAUTENG',
    siteId: siteId,
    provider: 'hikvision_dvr_monitor_only',
    eventsUri: Uri.parse('http://$host/ISAPI/Event/notification/alertStream'),
    authMode: 'digest',
    username: 'onyx',
    password: 'secret',
    bearerToken: '',
  );
}
