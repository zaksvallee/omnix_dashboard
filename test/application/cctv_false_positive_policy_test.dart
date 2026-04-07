import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/cctv_false_positive_policy.dart';

void main() {
  group('CctvFalsePositivePolicy', () {
    test('missing hour fields keep parsed rules inactive', () {
      final policy = CctvFalsePositivePolicy.fromJsonString('''
[
  {
    "zone": "garden",
    "object_label": "cat",
    "min_confidence_percent": 80
  }
]
''');

      expect(policy.enabled, isFalse);
      expect(
        policy.shouldSuppress(
          zone: 'garden',
          objectLabel: 'cat',
          objectConfidencePercent: 40,
          occurredAtUtc: _utcAtLocalHour(1),
        ),
        isFalse,
      );
    });

    test('same-hour rules are treated as invalid and skipped', () {
      final policy = CctvFalsePositivePolicy.fromJsonString('''
[
  {
    "zone": "garden",
    "object_label": "cat",
    "start_hour_local": 6,
    "end_hour_local": 6,
    "min_confidence_percent": 80
  }
]
''');

      expect(policy.enabled, isFalse);
      expect(
        policy.shouldSuppress(
          zone: 'garden',
          objectLabel: 'cat',
          objectConfidencePercent: 40,
          occurredAtUtc: _utcAtLocalHour(6),
        ),
        isFalse,
      );
    });

    test('suppresses low-confidence detections inside a standard window', () {
      const rule = CctvFalsePositiveRule(
        zone: 'garden',
        objectLabel: 'cat',
        startHourLocal: 0,
        endHourLocal: 6,
        minConfidencePercent: 80,
      );

      expect(
        rule.matches(
          zoneValue: 'garden',
          objectLabelValue: 'cat',
          objectConfidencePercent: 40,
          occurredAtUtc: _utcAtLocalHour(1),
        ),
        isTrue,
      );
      expect(
        rule.matches(
          zoneValue: 'garden',
          objectLabelValue: 'cat',
          objectConfidencePercent: 80,
          occurredAtUtc: _utcAtLocalHour(1),
        ),
        isFalse,
      );
      expect(
        rule.matches(
          zoneValue: 'garden',
          objectLabelValue: 'cat',
          objectConfidencePercent: 91,
          occurredAtUtc: _utcAtLocalHour(1),
        ),
        isFalse,
      );
    });

    test('honors standard window boundaries with exclusive end hour', () {
      const rule = CctvFalsePositiveRule(
        zone: 'garden',
        objectLabel: 'cat',
        startHourLocal: 0,
        endHourLocal: 6,
        minConfidencePercent: 80,
      );

      expect(
        rule.matches(
          zoneValue: 'garden',
          objectLabelValue: 'cat',
          objectConfidencePercent: 40,
          occurredAtUtc: _utcAtLocalHour(2),
        ),
        isTrue,
      );
      expect(
        rule.matches(
          zoneValue: 'garden',
          objectLabelValue: 'cat',
          objectConfidencePercent: 40,
          occurredAtUtc: _utcAtLocalHour(6),
        ),
        isFalse,
      );
    });

    test('honors midnight-crossing windows correctly', () {
      const rule = CctvFalsePositiveRule(
        zone: 'driveway',
        objectLabel: 'car',
        startHourLocal: 22,
        endHourLocal: 5,
        minConfidencePercent: 60,
      );

      expect(
        rule.matches(
          zoneValue: 'driveway',
          objectLabelValue: 'car',
          objectConfidencePercent: 40,
          occurredAtUtc: _utcAtLocalHour(23),
        ),
        isTrue,
      );
      expect(
        rule.matches(
          zoneValue: 'driveway',
          objectLabelValue: 'car',
          objectConfidencePercent: 40,
          occurredAtUtc: _utcAtLocalHour(1),
        ),
        isTrue,
      );
      expect(
        rule.matches(
          zoneValue: 'driveway',
          objectLabelValue: 'car',
          objectConfidencePercent: 40,
          occurredAtUtc: _utcAtLocalHour(12),
        ),
        isFalse,
      );
    });
  });
}

DateTime _utcAtLocalHour(int hour) {
  return DateTime(2026, 4, 7, hour).toUtc();
}
