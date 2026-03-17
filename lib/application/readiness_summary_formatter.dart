import 'monitoring_watch_action_plan.dart';

String buildGlobalReadinessPosturalEchoSummary({
  required List<MonitoringWatchAutonomyActionPlan> intents,
  bool includeLeadSites = true,
}) {
  final echoes = intents
      .where((intent) => intent.actionType.trim().toUpperCase() == 'POSTURAL ECHO')
      .toList(growable: false);
  if (echoes.isEmpty) {
    return '';
  }
  final leadSites = echoes
      .map((intent) => (intent.metadata['lead_site'] ?? '').trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList(growable: false);
  final targets = echoes
      .map((intent) => (intent.metadata['echo_target'] ?? intent.siteId).trim())
      .where((value) => value.isNotEmpty)
      .take(3)
      .toList(growable: false);
  final parts = <String>[
    'Echo ${echoes.length}',
    if (includeLeadSites && leadSites.isNotEmpty)
      'lead ${leadSites.take(2).join(', ')}',
    if (targets.isNotEmpty) 'target ${targets.join(', ')}',
  ];
  return parts.join(' • ');
}

String buildGlobalReadinessTopIntentSummary({
  required List<MonitoringWatchAutonomyActionPlan> intents,
  bool includeSiteId = true,
}) {
  if (intents.isEmpty) {
    return '';
  }
  final top = intents.first;
  final parts = <String>[
    top.actionType,
    if (includeSiteId && top.siteId.trim().isNotEmpty) top.siteId,
    if (top.description.trim().isNotEmpty) top.description,
  ];
  return parts.join(' • ');
}
