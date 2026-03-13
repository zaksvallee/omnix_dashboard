import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/listener_parity_service.dart';
import 'package:omnix_dashboard/application/listener_serial_ingestor.dart';

void main() {
  test('listener parity matches serial and legacy events within skew window', () {
    const service = ListenerParityService(maxSkew: Duration(seconds: 120));
    final serial = [
      ListenerSerialEnvelope(
        provider: 'falcon_serial',
        transport: 'serial',
        externalId: 'serial-1',
        rawLine: '1130 01 004 1234 0001 2026-03-13T08:15:00Z',
        accountNumber: '1234',
        partition: '01',
        eventCode: '130',
        eventQualifier: '1',
        zone: '004',
        userCode: '0001',
        siteId: 'SITE-SANDTON',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        occurredAtUtc: DateTime.parse('2026-03-13T08:15:00Z').toUtc(),
      ),
    ];
    final legacy = [
      ListenerSerialEnvelope(
        provider: 'legacy_listener',
        transport: 'tcp',
        externalId: 'legacy-1',
        rawLine: '{"event_code":"130"}',
        accountNumber: '1234',
        partition: '01',
        eventCode: '130',
        eventQualifier: '1',
        zone: '004',
        userCode: '0001',
        siteId: 'SITE-SANDTON',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        occurredAtUtc: DateTime.parse('2026-03-13T08:15:45Z').toUtc(),
      ),
    ];

    final report = service.compare(
      serialEvents: serial,
      legacyEvents: legacy,
    );

    expect(report.matchedCount, 1);
    expect(report.unmatchedSerialCount, 0);
    expect(report.unmatchedLegacyCount, 0);
    expect(report.matches.single.skewSeconds, 45);
    expect(report.matchRatePercent, 100);
    expect(report.maxSkewSecondsObserved, 45);
    expect(report.averageSkewSeconds, 45);
    expect(report.driftReasonCounts, isEmpty);
  });

  test('listener parity leaves non-matching events unmatched', () {
    const service = ListenerParityService(maxSkew: Duration(seconds: 60));
    final serial = [
      ListenerSerialEnvelope(
        provider: 'falcon_serial',
        transport: 'serial',
        externalId: 'serial-2',
        rawLine: '1131 01 007 1234 0003 2026-03-13T10:00:00Z',
        accountNumber: '1234',
        partition: '01',
        eventCode: '131',
        eventQualifier: '1',
        zone: '007',
        userCode: '0003',
        siteId: 'SITE-SANDTON',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        occurredAtUtc: DateTime.parse('2026-03-13T10:00:00Z').toUtc(),
      ),
    ];
    final legacy = [
      ListenerSerialEnvelope(
        provider: 'legacy_listener',
        transport: 'tcp',
        externalId: 'legacy-2',
        rawLine: '{"event_code":"131"}',
        accountNumber: '1234',
        partition: '01',
        eventCode: '131',
        eventQualifier: '1',
        zone: '009',
        userCode: '0003',
        siteId: 'SITE-SANDTON',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        occurredAtUtc: DateTime.parse('2026-03-13T10:00:10Z').toUtc(),
      ),
    ];

    final report = service.compare(
      serialEvents: serial,
      legacyEvents: legacy,
    );

    expect(report.matchedCount, 0);
    expect(report.unmatchedSerialCount, 1);
    expect(report.unmatchedLegacyCount, 1);
    expect(report.summaryLabel(), contains('serial_only 1'));
    expect(report.matchRatePercent, 0);
    expect(report.maxSkewSecondsObserved, 0);
    expect(report.driftReasonCounts['zone_mismatch'], 2);
    expect(report.unmatchedSerialDrifts.single.reason, 'zone_mismatch');
    expect(report.unmatchedLegacyDrifts.single.reason, 'zone_mismatch');
  });

  test('listener parity classifies skew drift separately from identity mismatches', () {
    const service = ListenerParityService(maxSkew: Duration(seconds: 60));
    final serial = [
      ListenerSerialEnvelope(
        provider: 'falcon_serial',
        transport: 'serial',
        externalId: 'serial-3',
        rawLine: '1130 01 004 1234 0001 2026-03-13T08:15:00Z',
        accountNumber: '1234',
        partition: '01',
        eventCode: '130',
        eventQualifier: '1',
        zone: '004',
        userCode: '0001',
        siteId: 'SITE-SANDTON',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        occurredAtUtc: DateTime.parse('2026-03-13T08:15:00Z').toUtc(),
      ),
    ];
    final legacy = [
      ListenerSerialEnvelope(
        provider: 'legacy_listener',
        transport: 'tcp',
        externalId: 'legacy-3',
        rawLine: '{"event_code":"130"}',
        accountNumber: '1234',
        partition: '01',
        eventCode: '130',
        eventQualifier: '1',
        zone: '004',
        userCode: '0001',
        siteId: 'SITE-SANDTON',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        occurredAtUtc: DateTime.parse('2026-03-13T08:17:30Z').toUtc(),
      ),
    ];

    final report = service.compare(
      serialEvents: serial,
      legacyEvents: legacy,
    );

    expect(report.matchedCount, 0);
    expect(report.driftReasonCounts['skew_exceeded'], 2);
    expect(report.unmatchedSerialDrifts.single.reason, 'skew_exceeded');
    expect(report.unmatchedSerialDrifts.single.observedSkewSeconds, 150);
    expect(report.unmatchedLegacyDrifts.single.reason, 'skew_exceeded');
  });
}
