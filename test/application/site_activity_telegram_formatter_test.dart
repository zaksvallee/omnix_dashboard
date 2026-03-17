import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/site_activity_intelligence_service.dart';
import 'package:omnix_dashboard/application/site_activity_telegram_formatter.dart';

void main() {
  test('formats site activity telegram summary with truth and trend', () {
    const formatter = SiteActivityTelegramFormatter();
    const snapshot = SiteActivityIntelligenceSnapshot(
      totalSignals: 15,
      personSignals: 9,
      vehicleSignals: 6,
      knownIdentitySignals: 3,
      flaggedIdentitySignals: 1,
      unknownPersonSignals: 5,
      unknownVehicleSignals: 2,
      longPresenceSignals: 1,
      guardInteractionSignals: 1,
      topFlaggedIdentitySummary: 'PERSON-44 flagged near gate-cam',
      topLongPresenceSummary:
          'Unknown person remained near driveway-cam for 3h 10m',
      topGuardInteractionSummary:
          'Guard interaction observed near gate-cam',
      evidenceEventIds: <String>['ACTIVITY-7', 'ACTIVITY-11'],
      summaryLine:
          'Signals 15 • Vehicles 6 • People 9 • Known IDs 3 • Unknown 7 • Long presence 1 • Guard interactions 1 • Flagged IDs 1',
    );

    final message = formatter.formatSummary(
      snapshot: snapshot,
      siteLabel: 'Vallee Residence',
      reportDate: '2026-03-17',
      trendLabel: 'ACTIVITY RISING',
      trendSummary: 'Unknown or flagged site activity increased against recent shifts.',
    );

    expect(message, contains('Site Activity Truth: Vallee Residence'));
    expect(message, contains('Window: 2026-03-17'));
    expect(message, contains('15 site-activity signals observed.'));
    expect(message, contains('6 vehicles • 9 people'));
    expect(message, contains('3 known IDs • 7 unknown • 1 flagged IDs'));
    expect(message, contains('1 long-presence patterns • 1 guard interactions'));
    expect(message, contains('Flagged: PERSON-44 flagged near gate-cam'));
    expect(
      message,
      contains(
        'Long presence: Unknown person remained near driveway-cam for 3h 10m',
      ),
    );
    expect(message, contains('Guard note: Guard interaction observed near gate-cam'));
    expect(
      message,
      contains(
        'Trend: ACTIVITY RISING - Unknown or flagged site activity increased against recent shifts.',
      ),
    );
    expect(message, isNot(contains('Review:')));

    final operatorMessage = formatter.formatSummary(
      snapshot: snapshot,
      siteLabel: 'Vallee Residence',
      includeEvidenceHandoff: true,
    );
    expect(operatorMessage, contains('Review: ACTIVITY-7, ACTIVITY-11'));
  });

  test('formats quiet site activity telegram summary', () {
    const formatter = SiteActivityTelegramFormatter();
    const snapshot = SiteActivityIntelligenceSnapshot(
      totalSignals: 0,
      personSignals: 0,
      vehicleSignals: 0,
      knownIdentitySignals: 0,
      flaggedIdentitySignals: 0,
      unknownPersonSignals: 0,
      unknownVehicleSignals: 0,
      longPresenceSignals: 0,
      guardInteractionSignals: 0,
      topFlaggedIdentitySummary: '',
      topLongPresenceSummary: '',
      topGuardInteractionSummary: '',
      evidenceEventIds: <String>[],
      summaryLine: 'No visitor or site-activity signals detected.',
    );

    final message = formatter.formatSummary(snapshot: snapshot);

    expect(message, contains('Site Activity Truth'));
    expect(message, contains('No visitor or site-activity signals detected.'));
  });
}
