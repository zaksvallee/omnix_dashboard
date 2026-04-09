import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/telegram_command_router.dart';

void main() {
  group('OnyxTelegramCommandRouter', () {
    const router = OnyxTelegramCommandRouter();

    test('routes occupancy questions to liveStatus', () {
      expect(
        router.classify('how many people on site?'),
        OnyxTelegramCommandType.liveStatus,
      );
      expect(
        router.classify('who is on site'),
        OnyxTelegramCommandType.liveStatus,
      );
      expect(
        router.classify('anyone home'),
        OnyxTelegramCommandType.liveStatus,
      );
    });

    test('keeps explicit guard prompts on the guard route', () {
      expect(
        router.classify('guard on site'),
        OnyxTelegramCommandType.guard,
      );
      expect(
        router.classify('missed patrol'),
        OnyxTelegramCommandType.guard,
      );
    });
  });
}
