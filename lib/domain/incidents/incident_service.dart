import 'incident_event.dart';
import 'incident_enums.dart';
import 'incident_projection.dart';
import 'store/incident_event_log.dart';
import 'risk/sla_breach_evaluator.dart';
import '../integration/incident_to_crm_mapper.dart';
import '../crm/store/crm_event_log.dart';
import '../crm/sla_profile.dart';
import '../../infrastructure/persistence/local_event_storage.dart';

class IncidentService {
  final IncidentEventLog incidentLog;
  final CRMEventLog crmLog;
  final LocalEventStorage storage;
  final DateTime Function() _clock;
  final Map<String, DateTime> _lastSlaEvaluationAtByIncident =
      <String, DateTime>{};

  IncidentService(
    this.incidentLog,
    this.crmLog,
    this.storage, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  Future<void> initialize({required SLAProfile slaProfile}) async {
    final savedIncidents = await storage.loadIncidents();
    final savedCrm = await storage.loadCrm();

    for (final e in savedIncidents) {
      incidentLog.append(e);
    }

    for (final e in savedCrm) {
      crmLog.append(e);
    }

    final nowUtc = _clock().toUtc();
    final grouped = <String, List<IncidentEvent>>{};
    for (final event in incidentLog.all()) {
      grouped.putIfAbsent(event.incidentId, () => <IncidentEvent>[]).add(event);
    }

    var incidentMutated = false;
    var crmMutated = false;
    for (final entry in grouped.entries) {
      final history = entry.value;
      final record = IncidentProjection.rebuild(history);
      if (record.status == IncidentStatus.resolved ||
          record.status == IncidentStatus.closed) {
        continue;
      }

      final lastKnownEventAtUtc = DateTime.parse(
        history.last.timestamp,
      ).toUtc();
      final offlineDurationMinutes = nowUtc
          .difference(lastKnownEventAtUtc)
          .inMinutes;

      final retroactiveSlaEvent = SLABreachEvaluator.evaluate(
        history: history,
        record: record,
        profile: slaProfile,
        nowUtc: nowUtc,
        retroactive: true,
        offlineDurationMinutes: offlineDurationMinutes < 0
            ? 0
            : offlineDurationMinutes,
      );

      if (retroactiveSlaEvent == null) {
        continue;
      }

      incidentLog.append(retroactiveSlaEvent);
      incidentMutated = true;

      final crmEvent = IncidentToCRMMapper.map(
        incidentEvent: retroactiveSlaEvent,
        clientId: slaProfile.clientId,
        clock: _clock,
      );
      if (crmEvent != null) {
        crmLog.append(crmEvent);
        crmMutated = true;
      }
    }

    if (incidentMutated) {
      await storage.saveIncidents(incidentLog.all());
    }
    if (crmMutated) {
      await storage.saveCrm(crmLog.all());
    }
  }

  Future<List<IncidentEvent>> handle(
    IncidentEvent incoming, {
    required SLAProfile slaProfile,
  }) async {
    final emitted = <IncidentEvent>[];

    incidentLog.append(incoming);
    emitted.add(incoming);

    final history = incidentLog.byIncident(incoming.incidentId);
    final record = IncidentProjection.rebuild(history);
    final nowUtc = _clock().toUtc();

    final slaEvent = SLABreachEvaluator.evaluate(
      history: history,
      record: record,
      profile: slaProfile,
      nowUtc: nowUtc,
      previousEvaluationAtUtc:
          _lastSlaEvaluationAtByIncident[incoming.incidentId],
    );
    _lastSlaEvaluationAtByIncident[incoming.incidentId] = nowUtc;

    if (slaEvent != null) {
      incidentLog.append(slaEvent);
      emitted.add(slaEvent);

      final crmEvent = IncidentToCRMMapper.map(
        incidentEvent: slaEvent,
        clientId: slaProfile.clientId,
      );

      if (crmEvent != null) {
        crmLog.append(crmEvent);
      }
    }

    await storage.saveIncidents(incidentLog.all());
    await storage.saveCrm(crmLog.all());

    return emitted;
  }

  Future<IncidentEvent> overrideSla({
    required String incidentId,
    required String operatorId,
    required String reason,
  }) async {
    final event = IncidentEvent(
      eventId: 'SLA-OVR-${_clock().toUtc().millisecondsSinceEpoch}',
      incidentId: incidentId,
      type: IncidentEventType.incidentSlaOverrideRecorded,
      timestamp: _clock().toUtc().toIso8601String(),
      metadata: {'operator_id': operatorId, 'reason': reason},
    );

    incidentLog.append(event);
    await storage.saveIncidents(incidentLog.all());

    return event;
  }
}
