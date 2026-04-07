import '../../crm/sla_profile.dart';
import '../incident_record.dart';
import '../incident_enums.dart';
import 'sla_policy.dart';

class SLAClock {
  final String startedAt;
  final String dueAt;
  final bool breached;

  const SLAClock({
    required this.startedAt,
    required this.dueAt,
    required this.breached,
  });

  static SLAClock evaluate({
    required IncidentRecord record,
    required SLAProfile profile,
    required DateTime nowUtc,
  }) {
    final start = parseDetectedAtUtc(record.detectedAt);

    final minutes = SLAPolicy.resolveSlaMinutes(
      severity: record.severity,
      profile: profile,
    );

    final due = start.add(Duration(minutes: minutes));

    final isTerminal =
        record.status == IncidentStatus.resolved ||
        record.status == IncidentStatus.closed;

    final breached = !isTerminal && nowUtc.isAfter(due);

    return SLAClock(
      startedAt: start.toIso8601String(),
      dueAt: due.toIso8601String(),
      breached: breached,
    );
  }

  static DateTime parseDetectedAtUtc(String detectedAt) {
    final normalized = detectedAt.trim();
    if (!normalized.endsWith('Z')) {
      throw ArgumentError.value(
        detectedAt,
        'detectedAt',
        'SLA detectedAt timestamps must be UTC and end with Z.',
      );
    }
    return DateTime.parse(normalized).toUtc();
  }
}
