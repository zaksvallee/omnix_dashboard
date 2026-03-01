import 'incident_event.dart';
import 'incident_projection.dart';
import 'store/incident_event_log.dart';
import 'risk/sla_breach_evaluator.dart';
import '../integration/incident_to_crm_mapper.dart';
import '../crm/store/crm_event_log.dart';
import '../../infrastructure/persistence/local_event_storage.dart';

class IncidentService {
  final IncidentEventLog incidentLog;
  final CRMEventLog crmLog;
  final LocalEventStorage storage;

  IncidentService(this.incidentLog, this.crmLog, this.storage);

  Future<void> initialize() async {
    final savedIncidents = await storage.loadIncidents();
    final savedCrm = await storage.loadCrm();

    for (final e in savedIncidents) {
      incidentLog.append(e);
    }

    for (final e in savedCrm) {
      crmLog.append(e);
    }
  }

  Future<List<IncidentEvent>> handle(IncidentEvent incoming) async {
    final emitted = <IncidentEvent>[];

    incidentLog.append(incoming);
    emitted.add(incoming);

    final history = incidentLog.byIncident(incoming.incidentId);
    final record = IncidentProjection.rebuild(history);

    final slaEvent = SLABreachEvaluator.evaluate(
      history: history,
      record: record,
      nowUtc: DateTime.now().toUtc(),
    );

    if (slaEvent != null) {
      incidentLog.append(slaEvent);
      emitted.add(slaEvent);

      final crmEvent = IncidentToCRMMapper.map(
        incidentEvent: slaEvent,
        clientId: "client_001",
      );

      if (crmEvent != null) {
        crmLog.append(crmEvent);
      }
    }

    await storage.saveIncidents(incidentLog.all());
    await storage.saveCrm(crmLog.all());

    return emitted;
  }
}
