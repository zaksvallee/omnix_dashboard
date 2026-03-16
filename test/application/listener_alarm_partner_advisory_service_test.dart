import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/listener_alarm_partner_advisory_service.dart';
import 'package:omnix_dashboard/application/monitoring_shift_notification_service.dart';

void main() {
  const service = ListenerAlarmPartnerAdvisoryService();
  const site = MonitoringSiteProfile(
    siteName: 'Vallee Residence',
    clientName: 'Vision Tactical',
  );

  test('formats clear partner alarm advisory', () {
    final message = service.formatPartnerAdvisory(
      ListenerAlarmPartnerAdvisoryContext(
        site: site,
        eventLabel: 'BURGLARY_ALARM',
        occurredAtUtc: DateTime.utc(2026, 3, 16, 7, 30),
        disposition: ListenerAlarmAdvisoryDisposition.clear,
        cctvSummary: 'Nothing suspicious to report',
      ),
    );

    expect(
      message,
      'Signal received from Vallee Residence for burglary alarm. CCTV checked immediately. Nothing suspicious to report.',
    );
  });

  test('formats suspicious advisory with zone label and escalation fallback', () {
    final message = service.formatPartnerAdvisory(
      ListenerAlarmPartnerAdvisoryContext(
        site: site,
        eventLabel: 'PERIMETER_ALARM',
        occurredAtUtc: DateTime.utc(2026, 3, 16, 7, 31),
        disposition: ListenerAlarmAdvisoryDisposition.suspicious,
        zoneLabel: 'Front Gate',
        cctvSummary: 'Human movement confirmed near front gate',
      ),
    );

    expect(
      message,
      'Signal received from Vallee Residence (Front Gate) for perimeter alarm. CCTV checked immediately. Human movement confirmed near front gate. Escalation recommended.',
    );
  });

  test('formats unavailable advisory with manual verification guidance', () {
    final message = service.formatPartnerAdvisory(
      ListenerAlarmPartnerAdvisoryContext(
        site: site,
        eventLabel: 'GENERAL_ALARM',
        occurredAtUtc: DateTime.utc(2026, 3, 16, 7, 32),
        disposition: ListenerAlarmAdvisoryDisposition.unavailable,
      ),
    );

    expect(
      message,
      'Signal received from Vallee Residence for general alarm. Alarm signal received. CCTV review is currently unavailable. Manual verification recommended while CCTV access is restored.',
    );
  });

  test('formats pending advisory with follow-up guidance', () {
    final message = service.formatPartnerAdvisory(
      ListenerAlarmPartnerAdvisoryContext(
        site: site,
        eventLabel: 'LISTENER_EVENT',
        occurredAtUtc: DateTime.utc(2026, 3, 16, 7, 33),
        disposition: ListenerAlarmAdvisoryDisposition.pending,
      ),
    );

    expect(
      message,
      'Signal received from Vallee Residence for alarm signal. CCTV review is underway. Further update to follow.',
    );
  });
}
