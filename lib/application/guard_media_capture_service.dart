import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;

class GuardMediaCaptureResult {
  final String localPath;
  final String fileName;
  final List<int>? bytes;

  const GuardMediaCaptureResult({
    required this.localPath,
    required this.fileName,
    this.bytes,
  });
}

enum GuardMediaQualityIssue { blur, lowLight, glare }

class GuardMediaQualityAssessment {
  final bool accepted;
  final List<GuardMediaQualityIssue> issues;
  final String method;

  const GuardMediaQualityAssessment({
    required this.accepted,
    required this.issues,
    required this.method,
  });
}

abstract class GuardMediaQualityEvaluator {
  Future<GuardMediaQualityAssessment> assess(
    GuardMediaCaptureResult capture, {
    required String purpose,
    String? checkpointId,
  });
}

class HeuristicGuardMediaQualityEvaluator
    implements GuardMediaQualityEvaluator {
  const HeuristicGuardMediaQualityEvaluator();

  static const _blurTokens = <String>[
    'blur',
    'blurry',
    'outoffocus',
    'out-of-focus',
  ];
  static const _lowLightTokens = <String>[
    'lowlight',
    'low-light',
    'dark',
    'underexposed',
  ];
  static const _glareTokens = <String>['glare', 'reflection', 'overexposed'];

  @override
  Future<GuardMediaQualityAssessment> assess(
    GuardMediaCaptureResult capture, {
    required String purpose,
    String? checkpointId,
  }) async {
    final fingerprint =
        '${capture.fileName.toLowerCase()} ${capture.localPath.toLowerCase()}';
    final issues = <GuardMediaQualityIssue>[];
    if (_blurTokens.any(fingerprint.contains)) {
      issues.add(GuardMediaQualityIssue.blur);
    }
    if (_lowLightTokens.any(fingerprint.contains)) {
      issues.add(GuardMediaQualityIssue.lowLight);
    }
    if (_glareTokens.any(fingerprint.contains)) {
      issues.add(GuardMediaQualityIssue.glare);
    }
    return GuardMediaQualityAssessment(
      accepted: issues.isEmpty,
      issues: issues,
      method: 'heuristic_filename_v1',
    );
  }
}

class PixelAwareGuardMediaQualityEvaluator
    implements GuardMediaQualityEvaluator {
  final GuardMediaQualityEvaluator fallback;

  const PixelAwareGuardMediaQualityEvaluator({
    this.fallback = const HeuristicGuardMediaQualityEvaluator(),
  });

  @override
  Future<GuardMediaQualityAssessment> assess(
    GuardMediaCaptureResult capture, {
    required String purpose,
    String? checkpointId,
  }) async {
    final fallbackResult = await fallback.assess(
      capture,
      purpose: purpose,
      checkpointId: checkpointId,
    );
    final bytes = capture.bytes;
    if (bytes == null || bytes.isEmpty) {
      return fallbackResult;
    }
    final decoded = img.decodeImage(Uint8List.fromList(bytes));
    if (decoded == null) {
      return fallbackResult;
    }

    final pixelIssues = _analyzePixels(decoded);
    final merged = <GuardMediaQualityIssue>{
      ...fallbackResult.issues,
      ...pixelIssues,
    };
    return GuardMediaQualityAssessment(
      accepted: merged.isEmpty,
      issues: merged.toList(growable: false),
      method: 'pixel_luma_gradient_v1+${fallbackResult.method}',
    );
  }

  List<GuardMediaQualityIssue> _analyzePixels(img.Image image) {
    final luminanceStats = _luminanceStats(image);
    final avgGradient = _averageGradient(image);
    final issues = <GuardMediaQualityIssue>[];
    if (luminanceStats.mean < 70) {
      issues.add(GuardMediaQualityIssue.lowLight);
    }
    if (luminanceStats.brightRatio > 0.18 && luminanceStats.mean > 200) {
      issues.add(GuardMediaQualityIssue.glare);
    }
    if (avgGradient < 2) {
      issues.add(GuardMediaQualityIssue.blur);
    }
    return issues;
  }

  _LuminanceStats _luminanceStats(img.Image image) {
    final width = image.width;
    final height = image.height;
    final pixelCount = width * height;
    if (pixelCount <= 0) {
      return const _LuminanceStats(mean: 0, brightRatio: 0);
    }
    final step = _sampleStep(pixelCount);
    var sum = 0.0;
    var bright = 0;
    var count = 0;
    for (var y = 0; y < height; y += step) {
      for (var x = 0; x < width; x += step) {
        final pixel = image.getPixelSafe(x, y);
        final luma = _luma(pixel.r, pixel.g, pixel.b);
        sum += luma;
        if (luma >= 240) {
          bright += 1;
        }
        count += 1;
      }
    }
    if (count == 0) {
      return const _LuminanceStats(mean: 0, brightRatio: 0);
    }
    return _LuminanceStats(mean: sum / count, brightRatio: bright / count);
  }

  double _averageGradient(img.Image image) {
    final width = image.width;
    final height = image.height;
    if (width < 2 || height < 2) return 0;
    final step = _sampleStep(width * height);
    var gradientSum = 0.0;
    var count = 0;
    for (var y = 0; y < height - 1; y += step) {
      for (var x = 0; x < width - 1; x += step) {
        final a = image.getPixelSafe(x, y);
        final b = image.getPixelSafe(x + 1, y);
        final c = image.getPixelSafe(x, y + 1);
        final lumaA = _luma(a.r, a.g, a.b);
        final lumaB = _luma(b.r, b.g, b.b);
        final lumaC = _luma(c.r, c.g, c.b);
        gradientSum += (lumaA - lumaB).abs() + (lumaA - lumaC).abs();
        count += 1;
      }
    }
    if (count == 0) return 0;
    return gradientSum / count;
  }

  int _sampleStep(int pixelCount) {
    if (pixelCount > 1_200_000) return 8;
    if (pixelCount > 600_000) return 6;
    if (pixelCount > 200_000) return 4;
    return 2;
  }

  double _luma(num r, num g, num b) {
    return (0.299 * r) + (0.587 * g) + (0.114 * b);
  }
}

class _LuminanceStats {
  final double mean;
  final double brightRatio;

  const _LuminanceStats({required this.mean, required this.brightRatio});
}

abstract class GuardMediaCaptureService {
  Future<GuardMediaCaptureResult?> captureImage({
    required String purpose,
    String? checkpointId,
  });
}

class FilePickerGuardMediaCaptureService implements GuardMediaCaptureService {
  const FilePickerGuardMediaCaptureService();

  @override
  Future<GuardMediaCaptureResult?> captureImage({
    required String purpose,
    String? checkpointId,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final file = result.files.first;
    final path = (file.path ?? '').trim();
    if (path.isNotEmpty) {
      return GuardMediaCaptureResult(
        localPath: path,
        fileName: file.name,
        bytes: file.bytes,
      );
    }
    if (file.name.trim().isNotEmpty) {
      // Web and some providers do not expose absolute file paths.
      return GuardMediaCaptureResult(
        localPath: 'picked://${file.name.trim()}',
        fileName: file.name.trim(),
        bytes: file.bytes,
      );
    }
    return null;
  }
}
