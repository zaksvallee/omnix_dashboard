import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/telegram_bridge_delivery_memory.dart';

void main() {
  group('mergeTelegramDeliveredMessageKeys', () {
    test('prepends new keys and deduplicates', () {
      final merged = mergeTelegramDeliveredMessageKeys(
        existingKeys: const <String>['a', 'b'],
        deliveredKeys: const <String>['c', 'a'],
      );

      expect(merged, const <String>['c', 'a', 'b']);
    });

    test('ignores blanks and respects limit', () {
      final merged = mergeTelegramDeliveredMessageKeys(
        existingKeys: const <String>['old-1', 'old-2'],
        deliveredKeys: const <String>[' ', 'new-1', 'new-2'],
        limit: 3,
      );

      expect(merged, const <String>['new-1', 'new-2', 'old-1']);
    });
  });
}
