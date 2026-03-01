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
    required DateTime nowUtc,
  }) {
    final start = DateTime.parse(record.detectedAt).toUtc();
    final minutes = SLAPolicy.resolveSlaMinutes(record.severity);

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
}
