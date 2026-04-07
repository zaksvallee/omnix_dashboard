import 'dart:convert';
import 'dart:io';

import '../../domain/incidents/incident_event.dart';
import '../../domain/crm/crm_event.dart';
import '../../domain/incidents/store/incident_state_storage.dart';
import 'event_log_rotation_guard.dart';

class LocalEventStorage implements IncidentStateStorage {
  final File incidentFile = File('incident_events.json');
  final File crmFile = File('crm_events.json');

  final EventLogRotationGuard _rotationGuard =
      const EventLogRotationGuard();

  @override
  Future<void> saveIncidents(List<IncidentEvent> events) async {
    final jsonList = events.map((e) => e.toJson()).toList();
    final content = jsonEncode(jsonList);

    await _rotationGuard.enforce(incidentFile.path);
    await incidentFile.writeAsString(content);
  }

  @override
  Future<void> saveCrm(List<CRMEvent> events) async {
    final jsonList = events.map((e) => e.toJson()).toList();
    final content = jsonEncode(jsonList);

    await _rotationGuard.enforce(crmFile.path);
    await crmFile.writeAsString(content);
  }

  @override
  Future<List<IncidentEvent>> loadIncidents() async {
    if (!await incidentFile.exists()) return [];
    final content = await incidentFile.readAsString();
    final List<dynamic> decoded = jsonDecode(content);
    return decoded.map((e) => IncidentEvent.fromJson(e)).toList();
  }

  @override
  Future<List<CRMEvent>> loadCrm() async {
    if (!await crmFile.exists()) return [];
    final content = await crmFile.readAsString();
    final List<dynamic> decoded = jsonDecode(content);
    return decoded.map((e) => CRMEvent.fromJson(e)).toList();
  }
}
