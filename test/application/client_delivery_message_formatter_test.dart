import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/client_delivery_message_formatter.dart';

void main() {
  group('ClientDeliveryMessageFormatter', () {
    test('formats telegram body with client-facing tone', () {
      final body = ClientDeliveryMessageFormatter.telegramBody(
        title: 'Dispatch Review',
        body: 'We are checking the latest site position now',
        siteLabel: 'MS Vallee Residence',
        priority: true,
      );

      expect(body, contains('ONYX priority update for MS Vallee Residence'));
      expect(body, contains('Dispatch Review.'));
      expect(body, contains('We are checking the latest site position now.'));
      expect(body, contains('Reply here if you need us.'));
      expect(body, isNot(contains('Message key:')));
      expect(body, isNot(contains('Client:')));
    });

    test('formats sms body compactly for fallback delivery', () {
      final body = ClientDeliveryMessageFormatter.smsBody(
        title: 'Dispatch Review',
        body: 'We are checking the latest site position now',
        siteLabel: 'SITE-MS-VALLEE-RESIDENCE',
        priority: false,
      );

      expect(body, startsWith('ONYX update for MS-VALLEE-RESIDENCE:'));
      expect(body, contains('Dispatch Review.'));
      expect(body, contains('Reply here if you need us.'));
    });

    test('humanizes sms fallback summaries', () {
      final summary = ClientDeliveryMessageFormatter.smsFallbackOutcomeSummary(
        providerLabel: 'sms:bulksms',
        sentCount: 2,
        totalCount: 2,
        reason: 'telegram blocked',
      );

      expect(
        summary,
        'BulkSMS reached 2/2 contacts after Telegram was blocked.',
      );
    });

    test('humanizes missing phone fallback summary', () {
      final summary =
          ClientDeliveryMessageFormatter.smsFallbackMissingPhonesSummary(
            reason: 'telegram degraded',
          );

      expect(
        summary,
        'Telegram delivery degraded for this lane, but SMS fallback could not start because no active contact numbers are on file.',
      );
    });

    test('normalizes historical missing phone fallback summaries', () {
      final summary = ClientDeliveryMessageFormatter.humanizeScopedCommsSummary(
        'sms-fallback missing phones after telegram degraded',
      );

      expect(
        summary,
        'Telegram delivery degraded for this lane, but SMS fallback could not start because no active contact numbers are on file.',
      );
    });

    test('humanizes successful voip stage summaries', () {
      final summary = ClientDeliveryMessageFormatter.voipStageOutcomeSummary(
        providerLabel: 'voip:asterisk',
        accepted: true,
        contactName: 'Vallee command desk',
        statusLabel: 'Asterisk call staged',
      );

      expect(summary, 'Asterisk staged a call for Vallee command desk.');
    });

    test('humanizes unconfigured voip stage summaries', () {
      final summary = ClientDeliveryMessageFormatter.voipStageOutcomeSummary(
        providerLabel: 'voip:unconfigured',
        accepted: false,
        contactName: 'Thabo Mokoena',
        statusLabel: 'VoIP provider not configured',
        detail: 'SIP host pbx.vallee.local is already recorded for this guard.',
      );

      expect(
        summary,
        'VoIP staging is not configured for Thabo Mokoena yet. SIP host pbx.vallee.local is already recorded for this guard.',
      );
    });

    test('normalizes historical unconfigured voip summaries', () {
      final summary = ClientDeliveryMessageFormatter.humanizeScopedCommsSummary(
        'voip:unconfigured not configured for Thabo Mokoena. SIP host pbx.vallee.local is already recorded for this guard.',
      );

      expect(
        summary,
        'VoIP staging is not configured for Thabo Mokoena yet. SIP host pbx.vallee.local is already recorded for this guard.',
      );
    });

    test('normalizes historical failed voip summaries', () {
      final summary = ClientDeliveryMessageFormatter.humanizeScopedCommsSummary(
        'voip:asterisk could not stage call for Vallee command desk. Originate rejected by PBX.',
      );

      expect(
        summary,
        'Asterisk could not stage the call for Vallee command desk. Originate rejected by PBX.',
      );
    });

    test('normalizes telegram bridge failure summaries', () {
      final summary = ClientDeliveryMessageFormatter.humanizeScopedCommsSummary(
        'Telegram bridge failed for 1/1 message(s). Reasons: BLOCKED_BY_TEST_STUB',
      );

      expect(
        summary,
        'Telegram could not deliver 1/1 client update. Bridge reported: BLOCKED_BY_TEST_STUB.',
      );
    });
  });
}
