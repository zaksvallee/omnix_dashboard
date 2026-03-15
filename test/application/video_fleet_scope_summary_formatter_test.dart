import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/dvr_scope_config.dart';
import 'package:omnix_dashboard/application/video_fleet_scope_summary_formatter.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';

void main() {
  group('VideoFleetScopeSummaryFormatter', () {
    const formatter = VideoFleetScopeSummaryFormatter();

    test('formats fleet summary with event counts, endpoints, and overflow', () {
      final output = formatter.format(
        scopes: [
          _scope(clientId: 'CLIENT-A', siteId: 'SITE-A', host: '192.168.8.105'),
          _scope(clientId: 'CLIENT-B', siteId: 'SITE-B', host: '192.168.8.106'),
          _scope(clientId: 'CLIENT-C', siteId: 'SITE-C', host: '192.168.8.107'),
        ],
        events: [
          _intel(
            clientId: 'CLIENT-A',
            siteId: 'SITE-A',
            occurredAt: DateTime.utc(2026, 3, 14, 11, 55),
          ),
          _intel(
            clientId: 'CLIENT-A',
            siteId: 'SITE-A',
            occurredAt: DateTime.utc(2026, 3, 14, 10, 15),
          ),
          _intel(
            clientId: 'CLIENT-B',
            siteId: 'SITE-B',
            occurredAt: DateTime.utc(2026, 3, 14, 9, 40),
          ),
          _intel(
            clientId: 'CLIENT-C',
            siteId: 'SITE-C',
            occurredAt: DateTime.utc(2026, 3, 14, 4, 30),
          ),
        ],
        nowUtc: DateTime.utc(2026, 3, 14, 12, 0),
        siteNameForScope: (clientId, siteId) => '$clientId/$siteId',
        endpointLabelForScope: (uri) => uri?.host ?? '',
        maxScopes: 2,
      );

      expect(
        output,
        'fleet 3 scope(s) • CLIENT-A/SITE-A 2/6h @ 192.168.8.105 • last 11:55 • CLIENT-B/SITE-B 1/6h @ 192.168.8.106 • last 09:40 • +1 more',
      );
    });

    test('returns idle summary when a scope has no recent DVR events', () {
      final output = formatter.format(
        scopes: [
          _scope(clientId: 'CLIENT-A', siteId: 'SITE-A', host: '192.168.8.105'),
        ],
        events: [
          _intel(
            clientId: 'CLIENT-A',
            siteId: 'SITE-A',
            occurredAt: DateTime.utc(2026, 3, 14, 2, 0),
          ),
        ],
        nowUtc: DateTime.utc(2026, 3, 14, 12, 0),
        siteNameForScope: (clientId, siteId) => '$clientId/$siteId',
        endpointLabelForScope: (uri) => '',
      );

      expect(output, 'fleet 1 scope(s) • CLIENT-A/SITE-A 0/6h • last idle');
    });
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

IntelligenceReceived _intel({
  required String clientId,
  required String siteId,
  required DateTime occurredAt,
}) {
  return IntelligenceReceived(
    eventId: 'evt-$clientId-$siteId-${occurredAt.microsecondsSinceEpoch}',
    sequence: 1,
    version: 1,
    occurredAt: occurredAt,
    intelligenceId:
        'intel-$clientId-$siteId-${occurredAt.microsecondsSinceEpoch}',
    provider: 'hikvision_dvr_monitor_only',
    sourceType: 'dvr',
    externalId: 'external-${occurredAt.microsecondsSinceEpoch}',
    clientId: clientId,
    regionId: 'REGION-GAUTENG',
    siteId: siteId,
    cameraId: 'channel-1',
    zone: null,
    objectLabel: 'vehicle',
    objectConfidence: 0.91,
    headline: 'Vehicle motion',
    summary: 'Detected',
    riskScore: 42,
    snapshotUrl: null,
    clipUrl: null,
    canonicalHash: 'hash-${occurredAt.microsecondsSinceEpoch}',
    snapshotReferenceHash: null,
    clipReferenceHash: null,
    evidenceRecordHash: null,
  );
}
