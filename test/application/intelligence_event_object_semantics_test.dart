import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/intelligence_event_object_semantics.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';

void main() {
  test('preserves explicit non-generic object labels', () {
    final event = _intel(objectLabel: 'person');

    expect(
      resolveIdentityBackedObjectLabel(
        event: event,
        directObjectLabel: 'person',
      ),
      'person',
    );
  });

  test('resolves face matches to person when the direct label is generic', () {
    final event = _intel(objectLabel: '', faceMatchId: 'RESIDENT-44');

    expect(
      resolveIdentityBackedObjectLabel(
        event: event,
        directObjectLabel: 'movement',
      ),
      'person',
    );
  });

  test('resolves plate hits to vehicle when the direct label is empty', () {
    final event = _intel(objectLabel: '', plateNumber: 'CA123456');

    expect(
      resolveIdentityBackedObjectLabel(event: event, directObjectLabel: ''),
      'vehicle',
    );
  });

  test('keeps generic movement labels when no identity signal is present', () {
    final event = _intel(objectLabel: '');

    expect(
      resolveIdentityBackedObjectLabel(
        event: event,
        directObjectLabel: 'movement',
      ),
      'movement',
    );
  });
}

IntelligenceReceived _intel({
  required String objectLabel,
  String? faceMatchId,
  String? plateNumber,
}) {
  return IntelligenceReceived(
    eventId: 'evt-1',
    sequence: 1,
    version: 1,
    occurredAt: DateTime.utc(2026, 4, 5, 12),
    intelligenceId: 'intel-1',
    provider: 'hik_connect_openapi',
    sourceType: 'dvr',
    externalId: 'ext-1',
    clientId: 'CLIENT-1',
    regionId: 'REGION-1',
    siteId: 'SITE-1',
    cameraId: 'cam-1',
    objectLabel: objectLabel,
    faceMatchId: faceMatchId,
    plateNumber: plateNumber,
    headline: 'Test signal',
    summary: 'Test summary',
    riskScore: 50,
    canonicalHash: 'hash-1',
  );
}
