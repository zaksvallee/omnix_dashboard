enum OnyxFrAudience { controller, client, ai }

class OnyxFrPersonRecord {
  final String siteId;
  final String personId;
  final String displayName;
  final String role;
  final bool isPrivate;
  final List<String> expectedDays;
  final String? expectedStart;
  final String? expectedEnd;
  final int photoCount;
  final String? galleryPath;
  final bool isEnrolled;
  final DateTime? enrolledAtUtc;
  final bool isActive;

  const OnyxFrPersonRecord({
    required this.siteId,
    required this.personId,
    required this.displayName,
    required this.role,
    required this.isPrivate,
    required this.expectedDays,
    required this.expectedStart,
    required this.expectedEnd,
    required this.photoCount,
    required this.galleryPath,
    required this.isEnrolled,
    required this.enrolledAtUtc,
    required this.isActive,
  });

  factory OnyxFrPersonRecord.fromRow(Map<String, dynamic> row) {
    return OnyxFrPersonRecord(
      siteId: _frString(row['site_id']),
      personId: _frString(row['person_id']).toUpperCase(),
      displayName: _frString(row['display_name']),
      role: (_frNullableString(row['role']) ?? 'resident').toLowerCase(),
      isPrivate: _frBool(row['is_private']) ?? true,
      expectedDays: _frStringList(row['expected_days']),
      expectedStart: _frNullableString(row['expected_start']),
      expectedEnd: _frNullableString(row['expected_end']),
      photoCount: _frInt(row['photo_count']) ?? 0,
      galleryPath: _frNullableString(row['gallery_path']),
      isEnrolled: _frBool(row['is_enrolled']) ?? false,
      enrolledAtUtc: _frDateTimeUtc(row['enrolled_at']),
      isActive: _frBool(row['is_active']) ?? true,
    );
  }

  bool isExpectedAt({
    required DateTime observedAtUtc,
    required String timezone,
  }) {
    if (!isActive || !isEnrolled) {
      return false;
    }
    final local = _frLocalTime(timezone, observedAtUtc.toUtc());
    if (expectedDays.isNotEmpty &&
        !expectedDays.contains(_frWeekdayLabel(local.weekday))) {
      return false;
    }
    final start = expectedStart == null ? null : _frParseClock(expectedStart!);
    final end = expectedEnd == null ? null : _frParseClock(expectedEnd!);
    if (start == null || end == null) {
      return true;
    }
    final nowMinutes = local.hour * 60 + local.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    if (startMinutes == endMinutes) {
      return true;
    }
    if (startMinutes < endMinutes) {
      return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
    }
    return nowMinutes >= startMinutes || nowMinutes <= endMinutes;
  }
}

class OnyxFrMatchContext {
  final OnyxFrPersonRecord person;
  final DateTime observedAtUtc;
  final bool isExpectedNow;

  const OnyxFrMatchContext({
    required this.person,
    required this.observedAtUtc,
    required this.isExpectedNow,
  });

  String audienceLabel(OnyxFrAudience audience) {
    return switch (audience) {
      OnyxFrAudience.client || OnyxFrAudience.ai => person.displayName,
      OnyxFrAudience.controller => isExpectedNow
          ? 'Expected person'
          : 'Recognised person',
    };
  }
}

typedef FrPersonRegistryRowsReader =
    Future<List<Map<String, dynamic>>> Function(String siteId);

class OnyxFrService {
  final FrPersonRegistryRowsReader? readRegistryRows;

  const OnyxFrService({this.readRegistryRows});

  Future<List<OnyxFrPersonRecord>> loadRegistry(String siteId) async {
    final normalizedSiteId = siteId.trim();
    if (normalizedSiteId.isEmpty) {
      return const <OnyxFrPersonRecord>[];
    }
    final rows =
        await readRegistryRows?.call(normalizedSiteId) ??
        const <Map<String, dynamic>>[];
    return rows
        .map(OnyxFrPersonRecord.fromRow)
        .where(
          (person) =>
              person.siteId == normalizedSiteId &&
              person.personId.trim().isNotEmpty &&
              person.isActive,
        )
        .toList(growable: false);
  }

  Future<OnyxFrMatchContext?> resolveMatch({
    required String siteId,
    required String personId,
    required DateTime observedAtUtc,
    String timezone = 'Africa/Johannesburg',
  }) async {
    final normalizedPersonId = personId.trim().toUpperCase();
    if (siteId.trim().isEmpty || normalizedPersonId.isEmpty) {
      return null;
    }
    final registry = await loadRegistry(siteId);
    for (final person in registry) {
      if (person.personId == normalizedPersonId) {
        return OnyxFrMatchContext(
          person: person,
          observedAtUtc: observedAtUtc.toUtc(),
          isExpectedNow: person.isExpectedAt(
            observedAtUtc: observedAtUtc.toUtc(),
            timezone: timezone,
          ),
        );
      }
    }
    return null;
  }
}

String _frString(Object? value) => (value?.toString() ?? '').trim();

String? _frNullableString(Object? value) {
  final normalized = _frString(value);
  return normalized.isEmpty ? null : normalized;
}

bool? _frBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    if (value == 1) {
      return true;
    }
    if (value == 0) {
      return false;
    }
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
  }
  return null;
}

int? _frInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

DateTime? _frDateTimeUtc(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value)?.toUtc();
}

List<String> _frStringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((entry) => entry.toString().trim().toLowerCase())
      .where((entry) => entry.isNotEmpty)
      .toList(growable: false);
}

DateTime _frLocalTime(String timezone, DateTime utc) {
  if (timezone.trim() == 'Africa/Johannesburg') {
    return utc.toUtc().add(const Duration(hours: 2));
  }
  if (timezone.trim().toUpperCase() == 'UTC') {
    return utc.toUtc();
  }
  return utc.toLocal();
}

String _frWeekdayLabel(int weekday) {
  return switch (weekday) {
    DateTime.monday => 'monday',
    DateTime.tuesday => 'tuesday',
    DateTime.wednesday => 'wednesday',
    DateTime.thursday => 'thursday',
    DateTime.friday => 'friday',
    DateTime.saturday => 'saturday',
    DateTime.sunday => 'sunday',
    _ => 'unknown',
  };
}

({int hour, int minute})? _frParseClock(String raw) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw.trim());
  if (match == null) {
    return null;
  }
  final hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  if (hour == null || minute == null) {
    return null;
  }
  return (hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
}
