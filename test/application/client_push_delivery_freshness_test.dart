import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/client_push_delivery_freshness.dart';

void main() {
  group('ClientPushDeliveryFreshness', () {
    test('keeps fresh shift sitrep eligible for external delivery', () {
      final now = DateTime.utc(2026, 3, 18, 10, 0);

      final fresh = ClientPushDeliveryFreshness.isFreshForExternalDelivery(
        messageKey: 'tg-watch-end-client-ms-vallee-site-ms-vallee-1',
        title: 'Shift summary ready',
        occurredAtUtc: now.subtract(const Duration(minutes: 30)),
        nowUtc: now,
      );

      expect(fresh, isTrue);
    });

    test('expires stale shift sitrep for external delivery', () {
      final now = DateTime.utc(2026, 3, 18, 10, 0);

      final fresh = ClientPushDeliveryFreshness.isFreshForExternalDelivery(
        messageKey: 'tg-watch-end-client-ms-vallee-site-ms-vallee-1',
        title: 'Shift summary ready',
        occurredAtUtc: now.subtract(const Duration(hours: 8)),
        nowUtc: now,
      );

      expect(fresh, isFalse);
    });

    test('expires stale watch start for external delivery', () {
      final now = DateTime.utc(2026, 3, 18, 10, 0);

      final fresh = ClientPushDeliveryFreshness.isFreshForExternalDelivery(
        messageKey: 'tg-watch-start-client-ms-vallee-site-ms-vallee-1',
        title: 'Monitoring watch active',
        occurredAtUtc: now.subtract(const Duration(hours: 2)),
        nowUtc: now,
      );

      expect(fresh, isFalse);
    });

    test('does not expire escalation review deliveries', () {
      final now = DateTime.utc(2026, 3, 18, 10, 0);

      final fresh = ClientPushDeliveryFreshness.isFreshForExternalDelivery(
        messageKey: 'tg-client-escalated-123',
        title: 'ONYX Escalation Review',
        occurredAtUtc: now.subtract(const Duration(hours: 8)),
        nowUtc: now,
      );

      expect(fresh, isTrue);
    });
  });
}
