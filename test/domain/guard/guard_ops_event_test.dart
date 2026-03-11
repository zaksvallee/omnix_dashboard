import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/domain/guard/guard_ops_event.dart';

void main() {
  group('GuardVisualNormMetadata', () {
    test('enforces IR metadata constraint', () {
      expect(
        () => GuardVisualNormMetadata(
          mode: GuardVisualNormMode.ir,
          baselineId: 'NORM-IR-V1',
          captureProfile: 'patrol_verification',
          minMatchScore: 80,
          irRequired: false,
          combatWindow: true,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('GuardOpsMediaUpload', () {
    test('round-trips visual norm metadata through json', () {
      const visualNorm = GuardVisualNormMetadata(
        mode: GuardVisualNormMode.night,
        baselineId: 'NORM-PATROL-CP-1-V1',
        captureProfile: 'patrol_verification',
        minMatchScore: 86,
        irRequired: false,
        combatWindow: true,
      );
      final media = GuardOpsMediaUpload(
        mediaId: 'MEDIA-1',
        eventId: 'EVENT-1',
        guardId: 'GUARD-1',
        siteId: 'SITE-1',
        shiftId: 'SHIFT-1',
        bucket: 'guard-patrol-images',
        path: 'guards/GUARD-1/patrol/cp-1.jpg',
        localPath: '/tmp/cp-1.jpg',
        capturedAt: DateTime.utc(2026, 3, 9, 22, 0),
        visualNorm: visualNorm,
      );

      final decoded = GuardOpsMediaUpload.fromJson(media.toJson());

      expect(decoded.visualNorm.mode, GuardVisualNormMode.night);
      expect(decoded.visualNorm.baselineId, 'NORM-PATROL-CP-1-V1');
      expect(decoded.visualNorm.captureProfile, 'patrol_verification');
      expect(decoded.visualNorm.minMatchScore, 86);
      expect(decoded.visualNorm.combatWindow, isTrue);
    });

    test('defaults missing visual norm metadata to day profile', () {
      final decoded = GuardOpsMediaUpload.fromJson({
        'mediaId': 'MEDIA-1',
        'eventId': 'EVENT-1',
        'guardId': 'GUARD-1',
        'siteId': 'SITE-1',
        'shiftId': 'SHIFT-1',
        'bucket': 'guard-patrol-images',
        'path': 'guards/GUARD-1/patrol/cp-1.jpg',
        'localPath': '/tmp/cp-1.jpg',
        'capturedAt': DateTime.utc(2026, 3, 9, 12, 0).toIso8601String(),
      });

      expect(decoded.visualNorm.mode, GuardVisualNormMode.day);
      expect(decoded.visualNorm.baselineId, 'NORM-DAY-V1');
      expect(decoded.visualNorm.irRequired, isFalse);
      expect(decoded.visualNorm.minMatchScore, 90);
    });
  });
}
