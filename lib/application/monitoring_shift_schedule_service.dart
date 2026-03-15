class MonitoringShiftSchedule {
  final bool enabled;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  const MonitoringShiftSchedule({
    required this.enabled,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  MonitoringShiftScheduleSnapshot snapshotAt(DateTime nowLocal) {
    final normalizedNow = DateTime(
      nowLocal.year,
      nowLocal.month,
      nowLocal.day,
      nowLocal.hour,
      nowLocal.minute,
      nowLocal.second,
      nowLocal.millisecond,
      nowLocal.microsecond,
    );
    if (!enabled) {
      return MonitoringShiftScheduleSnapshot(
        active: false,
        windowStartLocal: null,
        windowEndLocal: null,
        nextTransitionLocal: null,
      );
    }
    final startTotalMinutes = _normalizedMinuteOfDay(startHour, startMinute);
    final endTotalMinutes = _normalizedMinuteOfDay(endHour, endMinute);
    final nowTotalMinutes = normalizedNow.hour * 60 + normalizedNow.minute;
    final allDay = startTotalMinutes == endTotalMinutes;
    if (allDay) {
      final start = _anchor(normalizedNow, startHour, startMinute);
      final windowStart = normalizedNow.isBefore(start)
          ? start.subtract(const Duration(days: 1))
          : start;
      return MonitoringShiftScheduleSnapshot(
        active: true,
        windowStartLocal: windowStart,
        windowEndLocal: windowStart.add(const Duration(days: 1)),
        nextTransitionLocal: windowStart.add(const Duration(days: 1)),
      );
    }
    final overnight = startTotalMinutes > endTotalMinutes;
    if (overnight) {
      final startsToday = nowTotalMinutes >= startTotalMinutes;
      final endsToday = nowTotalMinutes < endTotalMinutes;
      if (startsToday || endsToday) {
        final startAnchor = startsToday
            ? _anchor(normalizedNow, startHour, startMinute)
            : _anchor(
                normalizedNow.subtract(const Duration(days: 1)),
                startHour,
                startMinute,
              );
        final endAnchor = startsToday
            ? _anchor(
                normalizedNow.add(const Duration(days: 1)),
                endHour,
                endMinute,
              )
            : _anchor(normalizedNow, endHour, endMinute);
        return MonitoringShiftScheduleSnapshot(
          active: true,
          windowStartLocal: startAnchor,
          windowEndLocal: endAnchor,
          nextTransitionLocal: endAnchor,
        );
      }
      final nextStart = _anchor(normalizedNow, startHour, startMinute);
      return MonitoringShiftScheduleSnapshot(
        active: false,
        windowStartLocal: null,
        windowEndLocal: null,
        nextTransitionLocal: nextStart,
      );
    }
    final startToday = _anchor(normalizedNow, startHour, startMinute);
    final endToday = _anchor(normalizedNow, endHour, endMinute);
    if (nowTotalMinutes >= startTotalMinutes &&
        nowTotalMinutes < endTotalMinutes) {
      return MonitoringShiftScheduleSnapshot(
        active: true,
        windowStartLocal: startToday,
        windowEndLocal: endToday,
        nextTransitionLocal: endToday,
      );
    }
    final nextStart = normalizedNow.isBefore(startToday)
        ? startToday
        : startToday.add(const Duration(days: 1));
    return MonitoringShiftScheduleSnapshot(
      active: false,
      windowStartLocal: null,
      windowEndLocal: null,
      nextTransitionLocal: nextStart,
    );
  }

  DateTime? endForWindowStart(DateTime windowStartLocal) {
    if (!enabled) {
      return null;
    }
    final startAnchor = DateTime(
      windowStartLocal.year,
      windowStartLocal.month,
      windowStartLocal.day,
      startHour.clamp(0, 23),
      startMinute.clamp(0, 59),
    );
    final endAnchor = DateTime(
      windowStartLocal.year,
      windowStartLocal.month,
      windowStartLocal.day,
      endHour.clamp(0, 23),
      endMinute.clamp(0, 59),
    );
    final startTotalMinutes = _normalizedMinuteOfDay(startHour, startMinute);
    final endTotalMinutes = _normalizedMinuteOfDay(endHour, endMinute);
    if (startTotalMinutes == endTotalMinutes) {
      return startAnchor.add(const Duration(days: 1));
    }
    if (startTotalMinutes > endTotalMinutes) {
      return endAnchor.add(const Duration(days: 1));
    }
    return endAnchor;
  }

  int _normalizedMinuteOfDay(int hour, int minute) {
    final normalizedHour = hour.clamp(0, 23);
    final normalizedMinute = minute.clamp(0, 59);
    return normalizedHour * 60 + normalizedMinute;
  }

  DateTime _anchor(DateTime value, int hour, int minute) {
    return DateTime(
      value.year,
      value.month,
      value.day,
      hour.clamp(0, 23),
      minute.clamp(0, 59),
    );
  }
}

class MonitoringShiftScheduleSnapshot {
  final bool active;
  final DateTime? windowStartLocal;
  final DateTime? windowEndLocal;
  final DateTime? nextTransitionLocal;

  const MonitoringShiftScheduleSnapshot({
    required this.active,
    required this.windowStartLocal,
    required this.windowEndLocal,
    required this.nextTransitionLocal,
  });
}
