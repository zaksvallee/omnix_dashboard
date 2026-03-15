import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/monitoring_shift_schedule_service.dart';

void main() {
  group('MonitoringShiftSchedule', () {
    test('detects active overnight window before midnight', () {
      const schedule = MonitoringShiftSchedule(
        enabled: true,
        startHour: 18,
        startMinute: 0,
        endHour: 6,
        endMinute: 0,
      );

      final snapshot = schedule.snapshotAt(DateTime(2026, 3, 13, 23, 14));

      expect(snapshot.active, isTrue);
      expect(snapshot.windowStartLocal, DateTime(2026, 3, 13, 18));
      expect(snapshot.windowEndLocal, DateTime(2026, 3, 14, 6));
      expect(snapshot.nextTransitionLocal, DateTime(2026, 3, 14, 6));
    });

    test('detects active overnight window after midnight', () {
      const schedule = MonitoringShiftSchedule(
        enabled: true,
        startHour: 18,
        startMinute: 0,
        endHour: 6,
        endMinute: 0,
      );

      final snapshot = schedule.snapshotAt(DateTime(2026, 3, 14, 5, 30));

      expect(snapshot.active, isTrue);
      expect(snapshot.windowStartLocal, DateTime(2026, 3, 13, 18));
      expect(snapshot.windowEndLocal, DateTime(2026, 3, 14, 6));
      expect(snapshot.nextTransitionLocal, DateTime(2026, 3, 14, 6));
    });

    test('returns next start when overnight window is inactive', () {
      const schedule = MonitoringShiftSchedule(
        enabled: true,
        startHour: 18,
        startMinute: 0,
        endHour: 6,
        endMinute: 0,
      );

      final snapshot = schedule.snapshotAt(DateTime(2026, 3, 14, 12, 0));

      expect(snapshot.active, isFalse);
      expect(snapshot.windowStartLocal, isNull);
      expect(snapshot.windowEndLocal, isNull);
      expect(snapshot.nextTransitionLocal, DateTime(2026, 3, 14, 18));
    });

    test('supports same-day windows', () {
      const schedule = MonitoringShiftSchedule(
        enabled: true,
        startHour: 8,
        startMinute: 0,
        endHour: 17,
        endMinute: 0,
      );

      final activeSnapshot = schedule.snapshotAt(DateTime(2026, 3, 13, 9, 0));
      final inactiveSnapshot = schedule.snapshotAt(
        DateTime(2026, 3, 13, 19, 0),
      );

      expect(activeSnapshot.active, isTrue);
      expect(activeSnapshot.windowStartLocal, DateTime(2026, 3, 13, 8));
      expect(activeSnapshot.windowEndLocal, DateTime(2026, 3, 13, 17));
      expect(
        schedule.endForWindowStart(DateTime(2026, 3, 13, 8)),
        DateTime(2026, 3, 13, 17),
      );
      expect(inactiveSnapshot.active, isFalse);
      expect(inactiveSnapshot.nextTransitionLocal, DateTime(2026, 3, 14, 8));
    });

    test('computes overnight end from stored start', () {
      const schedule = MonitoringShiftSchedule(
        enabled: true,
        startHour: 18,
        startMinute: 0,
        endHour: 6,
        endMinute: 0,
      );

      expect(
        schedule.endForWindowStart(DateTime(2026, 3, 13, 18)),
        DateTime(2026, 3, 14, 6),
      );
    });

    test('disables scheduling cleanly', () {
      const schedule = MonitoringShiftSchedule(
        enabled: false,
        startHour: 18,
        startMinute: 0,
        endHour: 6,
        endMinute: 0,
      );

      final snapshot = schedule.snapshotAt(DateTime(2026, 3, 13, 20, 0));

      expect(snapshot.active, isFalse);
      expect(snapshot.windowStartLocal, isNull);
      expect(snapshot.windowEndLocal, isNull);
      expect(snapshot.nextTransitionLocal, isNull);
    });
  });
}
