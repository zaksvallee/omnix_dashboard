import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/site_awareness/onyx_site_awareness_snapshot.dart';

void main() {
  group('OnyxSiteAwarenessSnapshot parser and projector', () {
    test(
      'parses valid EventNotificationAlert XML to the correct event type',
      () {
        final event = OnyxSiteAwarenessEvent.fromAlertXml(
          _alertXml(
            channelId: '2',
            eventType: 'linedetection',
            dateTime: DateTime.utc(2026, 4, 8, 12, 0),
          ),
        );

        expect(event.channelId, '2');
        expect(event.eventType, OnyxEventType.perimeterBreach);
      },
    );

    test('parses VMD with targetType=human as humanDetected', () {
      final event = OnyxSiteAwarenessEvent.fromAlertXml(
        _alertXml(
          channelId: '1',
          eventType: 'VMD',
          targetType: 'human',
          dateTime: DateTime.utc(2026, 4, 8, 12, 1),
        ),
      );

      expect(event.eventType, OnyxEventType.humanDetected);
    });

    test('includes zone metadata for human detections in snapshot output', () {
      final projector = OnyxSiteAwarenessProjector(
        siteId: 'SITE-1',
        clientId: 'CLIENT-1',
        cameraZones: const <String, OnyxCameraZone>{
          '1': OnyxCameraZone(
            siteId: 'SITE-1',
            channelId: '1',
            zoneName: 'Street East Gate',
            zoneType: 'perimeter',
            isPerimeter: true,
            isIndoor: false,
          ),
        },
        clock: () => DateTime.utc(2026, 4, 8, 12, 1),
      );

      final snapshot = projector.ingest(
        OnyxSiteAwarenessEvent.fromAlertXml(
          _alertXml(
            channelId: '1',
            eventType: 'VMD',
            targetType: 'human',
            dateTime: DateTime.utc(2026, 4, 8, 12, 1),
          ),
        ),
      );

      expect(snapshot.detections.humanZones, hasLength(1));
      expect(snapshot.detections.humanZones.first.zoneName, 'Street East Gate');
      expect(snapshot.detections.humanZones.first.zoneType, 'perimeter');
      expect(snapshot.detections.humanZones.first.isPerimeter, isTrue);
    });

    test(
      'maps videoloss to a faulty channel status when channel is in knownFaultChannels',
      () {
        final projector = OnyxSiteAwarenessProjector(
          siteId: 'SITE-1',
          clientId: 'CLIENT-1',
          knownFaultChannels: const <String>{'11'},
          clock: () => DateTime.utc(2026, 4, 8, 12, 2),
        );
        final event = OnyxSiteAwarenessEvent.fromAlertXml(
          _alertXml(
            channelId: '11',
            eventType: 'videoloss',
            dateTime: DateTime.utc(2026, 4, 8, 12, 2),
          ),
          knownFaultChannels: const <String>{'11'},
        );

        final snapshot = projector.ingest(event);

        expect(
          snapshot.channels['11']!.status,
          OnyxChannelStatusType.videoloss,
        );
        expect(snapshot.channels['11']!.isFault, isTrue);
        expect(snapshot.knownFaults, contains('11'));
      },
    );

    test(
      'perimeterClear stays true when only a human detection is present',
      () {
        final projector = OnyxSiteAwarenessProjector(
          siteId: 'SITE-1',
          clientId: 'CLIENT-1',
          clock: () => DateTime.utc(2026, 4, 8, 12, 3),
        );

        final snapshot = projector.ingest(
          OnyxSiteAwarenessEvent.fromAlertXml(
            _alertXml(
              channelId: '4',
              eventType: 'VMD',
              targetType: 'human',
              dateTime: DateTime.utc(2026, 4, 8, 12, 3),
            ),
          ),
        );

        expect(snapshot.perimeterClear, isTrue);
        expect(snapshot.activeAlerts, isEmpty);
      },
    );

    test('perimeterClear becomes false when a breach event is present', () {
      final projector = OnyxSiteAwarenessProjector(
        siteId: 'SITE-1',
        clientId: 'CLIENT-1',
        clock: () => DateTime.utc(2026, 4, 8, 12, 3),
      );

      final snapshot = projector.ingest(
        OnyxSiteAwarenessEvent.fromAlertXml(
          _alertXml(
            channelId: '4',
            eventType: 'linedetection',
            dateTime: DateTime.utc(2026, 4, 8, 12, 3),
          ),
        ),
      );

      expect(snapshot.perimeterClear, isFalse);
      expect(snapshot.activeAlerts, isNotEmpty);
    });

    test('detection counts increment correctly across event types', () {
      final projector = OnyxSiteAwarenessProjector(
        siteId: 'SITE-1',
        clientId: 'CLIENT-1',
        clock: () => DateTime.utc(2026, 4, 8, 12, 4),
      );

      projector.ingest(
        OnyxSiteAwarenessEvent.fromAlertXml(
          _alertXml(
            channelId: '1',
            eventType: 'VMD',
            targetType: 'human',
            dateTime: DateTime.utc(2026, 4, 8, 12, 0),
          ),
        ),
      );
      projector.ingest(
        OnyxSiteAwarenessEvent.fromAlertXml(
          _alertXml(
            channelId: '2',
            eventType: 'VMD',
            targetType: 'vehicle',
            dateTime: DateTime.utc(2026, 4, 8, 12, 1),
          ),
        ),
      );
      projector.ingest(
        OnyxSiteAwarenessEvent.fromAlertXml(
          _alertXml(
            channelId: '3',
            eventType: 'VMD',
            targetType: 'animal',
            dateTime: DateTime.utc(2026, 4, 8, 12, 2),
          ),
        ),
      );
      final snapshot = projector.ingest(
        OnyxSiteAwarenessEvent.fromAlertXml(
          _alertXml(
            channelId: '4',
            eventType: 'VMD',
            dateTime: DateTime.utc(2026, 4, 8, 12, 3),
          ),
        ),
      );

      expect(snapshot.detections.humanCount, 1);
      expect(snapshot.detections.vehicleCount, 1);
      expect(snapshot.detections.animalCount, 1);
      expect(snapshot.detections.motionCount, 1);
      expect(snapshot.detections.lastUpdated, DateTime.utc(2026, 4, 8, 12, 3));
    });

    test('rolling detections reset after five minutes', () {
      final projector = OnyxSiteAwarenessProjector(
        siteId: 'SITE-1',
        clientId: 'CLIENT-1',
        clock: () => DateTime.utc(2026, 4, 8, 12, 6, 1),
      );

      projector.ingest(
        OnyxSiteAwarenessEvent.fromAlertXml(
          _alertXml(
            channelId: '5',
            eventType: 'VMD',
            targetType: 'human',
            dateTime: DateTime.utc(2026, 4, 8, 12, 0),
          ),
        ),
      );

      final snapshot = projector.snapshot(
        at: DateTime.utc(2026, 4, 8, 12, 6, 1),
      );

      expect(snapshot.detections.humanCount, 0);
      expect(snapshot.perimeterClear, isTrue);
      expect(snapshot.activeAlerts, isEmpty);
    });
  });
}

String _alertXml({
  required String channelId,
  required String eventType,
  required DateTime dateTime,
  String? targetType,
}) {
  return '''
<?xml version="1.0" encoding="UTF-8"?>
<EventNotificationAlert version="2.0">
  <ipAddress>192.168.0.117</ipAddress>
  <portNo>80</portNo>
  <protocol>HTTP</protocol>
  <channelID>$channelId</channelID>
  <dateTime>${dateTime.toUtc().toIso8601String()}</dateTime>
  <eventType>$eventType</eventType>
  ${targetType == null ? '' : '<targetType>$targetType</targetType>'}
</EventNotificationAlert>
''';
}
