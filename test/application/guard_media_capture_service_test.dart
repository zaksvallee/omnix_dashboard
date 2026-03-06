import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:omnix_dashboard/application/guard_media_capture_service.dart';

void main() {
  group('HeuristicGuardMediaQualityEvaluator', () {
    const evaluator = HeuristicGuardMediaQualityEvaluator();

    test('accepts a clean capture fingerprint', () async {
      const capture = GuardMediaCaptureResult(
        localPath: '/tmp/patrol_gate_a_001.jpg',
        fileName: 'patrol_gate_a_001.jpg',
      );
      final result = await evaluator.assess(
        capture,
        purpose: 'patrol_verification',
        checkpointId: 'GATE-A',
      );

      expect(result.accepted, isTrue);
      expect(result.issues, isEmpty);
      expect(result.method, 'heuristic_filename_v1');
    });

    test(
      'flags blur, low-light, and glare issues from capture fingerprint',
      () async {
        const capture = GuardMediaCaptureResult(
          localPath: '/tmp/dark_glare_blurry_gate.jpg',
          fileName: 'dark_glare_blurry_gate.jpg',
        );
        final result = await evaluator.assess(
          capture,
          purpose: 'patrol_verification',
          checkpointId: 'GATE-B',
        );

        expect(result.accepted, isFalse);
        expect(result.issues, contains(GuardMediaQualityIssue.blur));
        expect(result.issues, contains(GuardMediaQualityIssue.lowLight));
        expect(result.issues, contains(GuardMediaQualityIssue.glare));
      },
    );
  });

  group('PixelAwareGuardMediaQualityEvaluator', () {
    const evaluator = PixelAwareGuardMediaQualityEvaluator();

    test('flags low-light and blur for dark flat images', () async {
      final dark = img.Image(width: 64, height: 64);
      img.fill(dark, color: img.ColorRgb8(20, 20, 20));
      final bytes = img.encodeJpg(dark);
      final result = await evaluator.assess(
        GuardMediaCaptureResult(
          localPath: '/tmp/dark_flat.jpg',
          fileName: 'dark_flat.jpg',
          bytes: bytes,
        ),
        purpose: 'patrol_verification',
      );

      expect(result.accepted, isFalse);
      expect(result.issues, contains(GuardMediaQualityIssue.lowLight));
      expect(result.issues, contains(GuardMediaQualityIssue.blur));
      expect(result.method, startsWith('pixel_luma_gradient_v1'));
    });

    test('treats a well-lit checker as non-low-light input', () async {
      final checker = img.Image(width: 64, height: 64);
      for (var y = 0; y < checker.height; y++) {
        for (var x = 0; x < checker.width; x++) {
          final white = ((x ~/ 4) + (y ~/ 4)) % 2 == 0;
          checker.setPixelRgb(
            x,
            y,
            white ? 240 : 20,
            white ? 240 : 20,
            white ? 240 : 20,
          );
        }
      }
      final bytes = img.encodeJpg(checker);
      final result = await evaluator.assess(
        GuardMediaCaptureResult(
          localPath: '/tmp/checker.jpg',
          fileName: 'checker.jpg',
          bytes: bytes,
        ),
        purpose: 'shift_verification',
      );

      expect(result.issues, isNot(contains(GuardMediaQualityIssue.lowLight)));
      expect(result.method, startsWith('pixel_luma_gradient_v1'));
    });
  });
}
