import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/dvr_scope_config.dart';
import 'package:omnix_dashboard/application/video_fleet_scope_activity_projector.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';

void main() {
  group('VideoFleetScopeActivityProjector', () {
    const projector = VideoFleetScopeActivityProjector();

    test('aggregates recent DVR activity per scope and ignores old events', () {
      final output = projector.project(
        scopes: [
          _scope(clientId: 'CLIENT-A', siteId: 'SITE-A', host: '192.168.8.105'),
          _scope(clientId: 'CLIENT-B', siteId: 'SITE-B', host: '192.168.8.106'),
        ],
        events: [
          _intel(
            clientId: 'CLIENT-A',
            siteId: 'SITE-A',
            occurredAt: DateTime.utc(2026, 3, 14, 11, 55),
            headline: 'Repeat vehicle motion',
            riskScore: 84,
          ),
          _intel(
            clientId: 'CLIENT-A',
            siteId: 'SITE-A',
            occurredAt: DateTime.utc(2026, 3, 14, 10, 15),
            headline: 'Vehicle motion',
            riskScore: 72,
          ),
          _intel(
            clientId: 'CLIENT-B',
            siteId: 'SITE-B',
            occurredAt: DateTime.utc(2026, 3, 14, 2, 0),
            headline: 'Old perimeter motion',
            riskScore: 30,
          ),
        ],
        nowUtc: DateTime.utc(2026, 3, 14, 12, 0),
      );

      expect(output['CLIENT-A|SITE-A']?.recentEvents, 2);
      expect(
        output['CLIENT-A|SITE-A']?.lastSeenAtUtc,
        DateTime.utc(2026, 3, 14, 11, 55),
      );
      expect(
        output['CLIENT-A|SITE-A']?.latestEvent?.headline,
        'Repeat vehicle motion',
      );
      expect(output['CLIENT-B|SITE-B']?.recentEvents, 0);
      expect(output['CLIENT-B|SITE-B']?.lastSeenAtUtc, isNull);
      expect(output['CLIENT-B|SITE-B']?.latestEvent, isNull);
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
  required String headline,
  required int riskScore,
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
    headline: headline,
    summary: headline,
    riskScore: riskScore,
    snapshotUrl: null,
    clipUrl: null,
    canonicalHash: 'hash-${occurredAt.microsecondsSinceEpoch}',
    snapshotReferenceHash: null,
    clipReferenceHash: null,
    evidenceRecordHash: null,
  );
}
