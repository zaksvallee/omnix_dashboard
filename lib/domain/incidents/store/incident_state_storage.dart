import '../../crm/crm_event.dart';
import '../incident_event.dart';

abstract class IncidentStateStorage {
  Future<void> saveIncidents(List<IncidentEvent> events);

  Future<void> saveCrm(List<CRMEvent> events);

  Future<List<IncidentEvent>> loadIncidents();

  Future<List<CRMEvent>> loadCrm();
}
