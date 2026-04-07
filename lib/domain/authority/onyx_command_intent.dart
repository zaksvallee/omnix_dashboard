enum OnyxCommandIntent {
  triageNextMove,
  draftClientUpdate,
  patrolReportLookup,
  guardStatusLookup,
  summarizeIncident,
  showUnresolvedIncidents,
  showSiteMostAlertsThisWeek,
  showDispatchesToday,
  showIncidentsLastNight,
}

class OnyxParsedCommand {
  final OnyxCommandIntent intent;
  final String prompt;

  const OnyxParsedCommand({required this.intent, required this.prompt});
}
