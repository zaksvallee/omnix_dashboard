import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/site_activity_intelligence_service.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';

void main() {
  group('SiteActivityIntelligenceService', () {
    const service = SiteActivityIntelligenceService();

    test('summarizes people, vehicles, identities, and long presence', () {
      final events = <DispatchEvent>[
        _intel(
          id: 'veh-known-1',
          occurredAt: DateTime.utc(2026, 3, 16, 20, 0),
          objectLabel: 'vehicle',
          plateNumber: 'CA111111',
          headline: 'Known visitor vehicle entered',
          summary: 'Resident vehicle entered the gate lane.',
        ),
        _intel(
          id: 'veh-unknown-1',
          occurredAt: DateTime.utc(2026, 3, 16, 21, 0),
          objectLabel: 'car',
          headline: 'Unknown vehicle detected',
          summary: 'Unknown vehicle entered the loading zone.',
        ),
        _intel(
          id: 'person-known-1',
          occurredAt: DateTime.utc(2026, 3, 16, 21, 5),
          objectLabel: 'person',
          faceMatchId: 'BROTHER-01',
          headline: 'Known visitor detected',
          summary: 'Known family member entered the site.',
        ),
        _intel(
          id: 'person-unknown-1',
          occurredAt: DateTime.utc(2026, 3, 16, 22, 0),
          objectLabel: 'human',
          headline: 'Guard conversation observed',
          summary: 'Guard talking to unknown individual near the gate.',
        ),
        _intel(
          id: 'person-unknown-2',
          occurredAt: DateTime.utc(2026, 3, 17, 0, 30),
          objectLabel: 'human',
          headline: 'Guard conversation continues',
          summary: 'Guard conversation with unknown individual continued.',
        ),
        _intel(
          id: 'flagged-1',
          occurredAt: DateTime.utc(2026, 3, 17, 1, 0),
          objectLabel: 'person',
          headline: 'Watchlist subject detected',
          summary: 'Unauthorized person matched watchlist context.',
        ),
      ];

      final snapshot = service.buildSnapshot(events: events);

      expect(snapshot.totalSignals, 6);
      expect(snapshot.vehicleSignals, 2);
      expect(snapshot.personSignals, 4);
      expect(snapshot.knownIdentitySignals, 2);
      expect(snapshot.unknownVehicleSignals, 1);
      expect(snapshot.unknownPersonSignals, 3);
      expect(snapshot.longPresenceSignals, 1);
      expect(snapshot.guardInteractionSignals, 2);
      expect(snapshot.flaggedIdentitySignals, 1);
      expect(snapshot.summaryLine, contains('Vehicles 2'));
      expect(snapshot.summaryLine, contains('People 4'));
      expect(snapshot.summaryLine, contains('Known IDs 2'));
      expect(snapshot.summaryLine, contains('Long presence 1'));
    });
  });
}

IntelligenceReceived _intel({
  required String id,
  required DateTime occurredAt,
  required String objectLabel,
  required String headline,
  required String summary,
  String faceMatchId = '',
  String plateNumber = '',
}) {
  return IntelligenceReceived(
    eventId: 'evt-$id',
    sequence: 1,
    version: 1,
    occurredAt: occurredAt,
    intelligenceId: id,
    provider: 'hikvision_dvr_monitor_only',
    sourceType: 'dvr',
    externalId: 'ext-$id',
    clientId: 'CLIENT-VALLEE',
    regionId: 'REGION-GAUTENG',
    siteId: 'SITE-VALLEE',
    cameraId: 'cam-1',
    objectLabel: objectLabel,
    objectConfidence: 0.91,
    faceMatchId: faceMatchId.isEmpty ? null : faceMatchId,
    plateNumber: plateNumber.isEmpty ? null : plateNumber,
    headline: headline,
    summary: summary,
    riskScore: 65,
    snapshotUrl: 'https://edge.example.com/$id.jpg',
    canonicalHash: 'hash-$id',
  );
}
