import 'site_activity_intelligence_service.dart';

class SiteActivityTelegramFormatter {
  const SiteActivityTelegramFormatter();

  String formatSummary({
    required SiteActivityIntelligenceSnapshot snapshot,
    String? siteLabel,
    String? reportDate,
    String? trendLabel,
    String? trendSummary,
    bool includeEvidenceHandoff = false,
    String? reviewCommandHint,
    String? caseFileHint,
    List<String> historyReviewHints = const <String>[],
  }) {
    final lines = <String>[
      if ((siteLabel ?? '').trim().isNotEmpty)
        'Site Activity Truth: ${siteLabel!.trim()}'
      else
        'Site Activity Truth',
      if ((reportDate ?? '').trim().isNotEmpty) 'Window: ${reportDate!.trim()}',
    ];

    if (snapshot.totalSignals <= 0) {
      lines.add('No visitor or site-activity signals detected.');
      if ((trendLabel ?? '').trim().isNotEmpty &&
          (trendSummary ?? '').trim().isNotEmpty) {
        lines.add('Trend: ${trendLabel!.trim()} - ${trendSummary!.trim()}');
      }
      return lines.join('\n');
    }

    final unknownSignals =
        snapshot.unknownPersonSignals + snapshot.unknownVehicleSignals;

    lines.add('${snapshot.totalSignals} site-activity signals observed.');

    final movementParts = <String>[
      if (snapshot.vehicleSignals > 0) '${snapshot.vehicleSignals} vehicles',
      if (snapshot.personSignals > 0) '${snapshot.personSignals} people',
    ];
    if (movementParts.isNotEmpty) {
      lines.add(movementParts.join(' • '));
    }

    final identityParts = <String>[
      if (snapshot.knownIdentitySignals > 0)
        '${snapshot.knownIdentitySignals} known IDs',
      if (unknownSignals > 0) '$unknownSignals unknown',
      if (snapshot.flaggedIdentitySignals > 0)
        '${snapshot.flaggedIdentitySignals} flagged IDs',
    ];
    if (identityParts.isNotEmpty) {
      lines.add(identityParts.join(' • '));
    }

    final patternParts = <String>[
      if (snapshot.longPresenceSignals > 0)
        '${snapshot.longPresenceSignals} long-presence patterns',
      if (snapshot.guardInteractionSignals > 0)
        '${snapshot.guardInteractionSignals} guard interactions',
    ];
    if (patternParts.isNotEmpty) {
      lines.add(patternParts.join(' • '));
    }

    if (snapshot.topFlaggedIdentitySummary.trim().isNotEmpty) {
      lines.add('Flagged: ${snapshot.topFlaggedIdentitySummary.trim()}');
    }
    if (snapshot.topLongPresenceSummary.trim().isNotEmpty) {
      lines.add('Long presence: ${snapshot.topLongPresenceSummary.trim()}');
    }
    if (snapshot.topGuardInteractionSummary.trim().isNotEmpty) {
      lines.add('Guard note: ${snapshot.topGuardInteractionSummary.trim()}');
    }

    if ((trendLabel ?? '').trim().isNotEmpty &&
        (trendSummary ?? '').trim().isNotEmpty) {
      lines.add('Trend: ${trendLabel!.trim()} - ${trendSummary!.trim()}');
    }

    if (includeEvidenceHandoff && snapshot.evidenceEventIds.isNotEmpty) {
      lines.add('Review: ${snapshot.evidenceEventIds.join(', ')}');
    }
    if ((reviewCommandHint ?? '').trim().isNotEmpty) {
      lines.add('Open review: ${reviewCommandHint!.trim()}');
    }
    for (final hint in historyReviewHints) {
      final trimmed = hint.trim();
      if (trimmed.isNotEmpty) {
        lines.add(trimmed);
      }
    }
    if ((caseFileHint ?? '').trim().isNotEmpty) {
      lines.add('Case file: ${caseFileHint!.trim()}');
    }

    return lines.join('\n');
  }
}
