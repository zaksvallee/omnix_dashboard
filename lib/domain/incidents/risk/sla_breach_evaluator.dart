import '../../crm/sla_profile.dart';
import '../incident_event.dart';
import '../incident_record.dart';
import 'sla_clock.dart';

class SLABreachEvaluator {
  static const _clockDriftTolerance = Duration(seconds: 120);

  static IncidentEvent? evaluate({
    required List<IncidentEvent> history,
    required IncidentRecord record,
    required SLAProfile profile,
    required DateTime nowUtc,
    DateTime? previousEvaluationAtUtc,
    bool retroactive = false,
    int? offlineDurationMinutes,
  }) {
    final alreadyBreached = history.any(
      (e) => e.type == IncidentEventType.incidentSlaBreached,
    );

    if (alreadyBreached) return null;

    if (previousEvaluationAtUtc != null) {
      final jump = nowUtc
          .toUtc()
          .difference(previousEvaluationAtUtc.toUtc())
          .abs();
      if (jump > _clockDriftTolerance) {
        return IncidentEvent(
          eventId: _generateId(
            prefix: 'SLA-DRIFT',
            incidentId: record.incidentId,
            nowUtc: nowUtc,
          ),
          incidentId: record.incidentId,
          type: IncidentEventType.incidentSlaClockDriftDetected,
          timestamp: nowUtc.toUtc().toIso8601String(),
          metadata: {
            'jump_seconds': jump.inSeconds,
            'severity': record.severity.name,
            'sla_state': IncidentRecord.slaStatusUnverifiableClockEvent,
          },
        );
      }
    }

    final clock = SLAClock.evaluate(
      record: record,
      profile: profile,
      nowUtc: nowUtc,
    );

    if (!clock.breached) return null;

    return IncidentEvent(
      eventId: _generateId(
        prefix: 'SLA',
        incidentId: record.incidentId,
        nowUtc: nowUtc,
      ),
      incidentId: record.incidentId,
      type: IncidentEventType.incidentSlaBreached,
      timestamp: nowUtc.toUtc().toIso8601String(),
      metadata: {
        'due_at': clock.dueAt,
        'severity': record.severity.name,
        'retroactive': retroactive,
        if (offlineDurationMinutes case final value)
          'offline_duration_minutes': value,
      },
    );
  }

  static String _generateId({
    required String prefix,
    required String incidentId,
    required DateTime nowUtc,
  }) {
    final ts = nowUtc.toUtc().millisecondsSinceEpoch;
    return '$prefix-$incidentId-$ts';
  }
}
