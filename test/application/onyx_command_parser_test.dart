import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/onyx_command_parser.dart';
import 'package:omnix_dashboard/domain/authority/onyx_command_intent.dart';

void main() {
  const parser = OnyxCommandParser();

  group('OnyxCommandParser supported prompt matrix', () {
    const promptExpectations = <({String prompt, OnyxCommandIntent intent})>[
      (
        prompt: 'Draft a client update for this site',
        intent: OnyxCommandIntent.draftClientUpdate,
      ),
      (
        prompt: 'Write the client a quick update',
        intent: OnyxCommandIntent.draftClientUpdate,
      ),
      (
        prompt: 'Prepare a resident message',
        intent: OnyxCommandIntent.draftClientUpdate,
      ),
      (
        prompt: 'Show last patrol report for Guard001',
        intent: OnyxCommandIntent.patrolReportLookup,
      ),
      (
        prompt: 'Provide the latest patrol proof for Guard001',
        intent: OnyxCommandIntent.patrolReportLookup,
      ),
      (
        prompt: 'Check status of Guard001',
        intent: OnyxCommandIntent.guardStatusLookup,
      ),
      (
        prompt: 'Check stauts of Guard001',
        intent: OnyxCommandIntent.guardStatusLookup,
      ),
      (
        prompt: 'Check guards',
        intent: OnyxCommandIntent.guardStatusLookup,
      ),
      (
        prompt: 'Where is Guard001 right now',
        intent: OnyxCommandIntent.guardStatusLookup,
      ),
      (
        prompt: 'Check the patrol route for Guard001',
        intent: OnyxCommandIntent.guardStatusLookup,
      ),
      (
        prompt: 'Which site has most alerts this week',
        intent: OnyxCommandIntent.showSiteMostAlertsThisWeek,
      ),
      (
        prompt: 'What site has highest alerts weekly',
        intent: OnyxCommandIntent.showSiteMostAlertsThisWeek,
      ),
      (
        prompt: 'Which site has most alerts across all sites this week?',
        intent: OnyxCommandIntent.showSiteMostAlertsThisWeek,
      ),
      (
        prompt: 'Top site across all properties this week?',
        intent: OnyxCommandIntent.showSiteMostAlertsThisWeek,
      ),
      (
        prompt: 'Show incidents last night',
        intent: OnyxCommandIntent.showIncidentsLastNight,
      ),
      (
        prompt: 'Show incidents overnight',
        intent: OnyxCommandIntent.showIncidentsLastNight,
      ),
      (
        prompt: 'Any breaches tonight',
        intent: OnyxCommandIntent.showIncidentsLastNight,
      ),
      (
        prompt: 'What changed tonight',
        intent: OnyxCommandIntent.showIncidentsLastNight,
      ),
      (
        prompt: 'What changed across all sites tonight?',
        intent: OnyxCommandIntent.showIncidentsLastNight,
      ),
      (
        prompt: 'What happened overnight',
        intent: OnyxCommandIntent.showIncidentsLastNight,
      ),
      (
        prompt: 'Check tonights breaches',
        intent: OnyxCommandIntent.showIncidentsLastNight,
      ),
      (
        prompt: 'Check tonight\'s breaches',
        intent: OnyxCommandIntent.showIncidentsLastNight,
      ),
      (
        prompt: 'Check breaches',
        intent: OnyxCommandIntent.showUnresolvedIncidents,
      ),
      (
        prompt: 'Show breaches',
        intent: OnyxCommandIntent.showUnresolvedIncidents,
      ),
      (
        prompt: 'Any breaches',
        intent: OnyxCommandIntent.showUnresolvedIncidents,
      ),
      (
        prompt: 'Breach status',
        intent: OnyxCommandIntent.showUnresolvedIncidents,
      ),
      (
        prompt: 'Fire status',
        intent: OnyxCommandIntent.showUnresolvedIncidents,
      ),
      (
        prompt: 'Medical status',
        intent: OnyxCommandIntent.showUnresolvedIncidents,
      ),
      (
        prompt: 'Police status',
        intent: OnyxCommandIntent.showUnresolvedIncidents,
      ),
      (
        prompt: 'Ambulance status',
        intent: OnyxCommandIntent.showUnresolvedIncidents,
      ),
      (
        prompt: 'Fire update',
        intent: OnyxCommandIntent.showUnresolvedIncidents,
      ),
      (
        prompt: 'Medical?',
        intent: OnyxCommandIntent.showUnresolvedIncidents,
      ),
      (
        prompt: 'Police here',
        intent: OnyxCommandIntent.showUnresolvedIncidents,
      ),
      (
        prompt: 'Ambulnce status',
        intent: OnyxCommandIntent.showUnresolvedIncidents,
      ),
      (
        prompt: 'Ambulnce stauts?',
        intent: OnyxCommandIntent.showUnresolvedIncidents,
      ),
      (
        prompt: 'Is there a fire?',
        intent: OnyxCommandIntent.showUnresolvedIncidents,
      ),
      (
        prompt: 'Do we have any breaches?',
        intent: OnyxCommandIntent.showUnresolvedIncidents,
      ),
      (
        prompt: 'Any fire issues tonight',
        intent: OnyxCommandIntent.showIncidentsLastNight,
      ),
      (
        prompt: 'Do we have police activity tonight?',
        intent: OnyxCommandIntent.showIncidentsLastNight,
      ),
      (
        prompt: 'Police activity at MS Vallee tonight?',
        intent: OnyxCommandIntent.showIncidentsLastNight,
      ),
      (
        prompt: 'Police activity across Vallee sites tonight?',
        intent: OnyxCommandIntent.showIncidentsLastNight,
      ),
      (
        prompt: 'Any medical incidents here',
        intent: OnyxCommandIntent.showUnresolvedIncidents,
      ),
      (
        prompt: 'Do we have police activity',
        intent: OnyxCommandIntent.showUnresolvedIncidents,
      ),
      (
        prompt: 'Breaches at the site?',
        intent: OnyxCommandIntent.showUnresolvedIncidents,
      ),
      (
        prompt: 'Breaches across all sites?',
        intent: OnyxCommandIntent.showUnresolvedIncidents,
      ),
      (
        prompt: 'Show dispatches today',
        intent: OnyxCommandIntent.showDispatchesToday,
      ),
      (
        prompt: 'Dispatches across all sites today?',
        intent: OnyxCommandIntent.showDispatchesToday,
      ),
      (
        prompt: 'Which dispatches happened today',
        intent: OnyxCommandIntent.showDispatchesToday,
      ),
      (
        prompt: 'Todays dispatches',
        intent: OnyxCommandIntent.showDispatchesToday,
      ),
      (
        prompt: 'Show unresolved incidents',
        intent: OnyxCommandIntent.showUnresolvedIncidents,
      ),
      (
        prompt: 'What active incidents are still open',
        intent: OnyxCommandIntent.showUnresolvedIncidents,
      ),
      (
        prompt: 'Any open incidents',
        intent: OnyxCommandIntent.showUnresolvedIncidents,
      ),
      (
        prompt: 'Give me an incident summary',
        intent: OnyxCommandIntent.summarizeIncident,
      ),
      (
        prompt: 'What happened with the alarm',
        intent: OnyxCommandIntent.summarizeIncident,
      ),
      (
        prompt: 'One next move',
        intent: OnyxCommandIntent.triageNextMove,
      ),
      (
        prompt: 'Open dispatch board',
        intent: OnyxCommandIntent.triageNextMove,
      ),
    ];

    for (final expectation in promptExpectations) {
      test('"${expectation.prompt}" -> ${expectation.intent.name}', () {
        final parsed = parser.parse(expectation.prompt);
        expect(parsed.intent, expectation.intent);
      });
    }
  });
}
