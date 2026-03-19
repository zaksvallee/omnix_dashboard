import 'site_activity_intelligence_service.dart';

class SiteActivityTelegramFormatter {
  const SiteActivityTelegramFormatter();

  String formatSummary({
    required SiteActivityIntelligenceSnapshot snapshot,
    String? siteLabel,
    String? reportDate,
    String? trendLabel,
    String? trendSummary,
    String? quietFallbackLine,
    String? quietFallbackDetail,
    bool includeEvidenceHandoff = false,
    String? reviewCommandHint,
    String? caseFileHint,
    List<String> historyReviewHints = const <String>[],
  }) {
    final lines = <String>[
      if ((siteLabel ?? '').trim().isNotEmpty)
        'Site activity summary: ${siteLabel!.trim()}'
      else
        'Site activity summary',
      if ((reportDate ?? '').trim().isNotEmpty) 'Window: ${reportDate!.trim()}',
    ];

    if (snapshot.totalSignals <= 0) {
      final fallbackLine = (quietFallbackLine ?? '').trim();
      if (fallbackLine.isNotEmpty) {
        lines.add(fallbackLine);
        final fallbackDetail = (quietFallbackDetail ?? '').trim();
        if (fallbackDetail.isNotEmpty) {
          lines.add(fallbackDetail);
        }
      } else {
        lines.add('No visitor or site activity signals were detected.');
      }
      if ((trendLabel ?? '').trim().isNotEmpty &&
          (trendSummary ?? '').trim().isNotEmpty) {
        lines.add('Trend: ${trendLabel!.trim()} - ${trendSummary!.trim()}');
      }
      return lines.join('\n');
    }

    final unknownSignals =
        snapshot.unknownPersonSignals + snapshot.unknownVehicleSignals;

    lines.add('Signals seen: ${snapshot.totalSignals}.');

    final movementParts = <String>[
      if (snapshot.vehicleSignals > 0) '${snapshot.vehicleSignals} vehicles',
      if (snapshot.personSignals > 0) '${snapshot.personSignals} people',
    ];
    if (movementParts.isNotEmpty) {
      lines.add('Seen: ${movementParts.join(' • ')}');
    }

    final identityParts = <String>[
      if (snapshot.knownIdentitySignals > 0)
        '${snapshot.knownIdentitySignals} known IDs',
      if (unknownSignals > 0) '$unknownSignals unknown',
      if (snapshot.flaggedIdentitySignals > 0)
        '${snapshot.flaggedIdentitySignals} flagged IDs',
    ];
    if (identityParts.isNotEmpty) {
      lines.add('Identity mix: ${identityParts.join(' • ')}');
    }

    final patternParts = <String>[
      if (snapshot.longPresenceSignals > 0)
        '${snapshot.longPresenceSignals} long stays',
      if (snapshot.guardInteractionSignals > 0)
        '${snapshot.guardInteractionSignals} guard interactions',
    ];
    if (patternParts.isNotEmpty) {
      lines.add('Patterns: ${patternParts.join(' • ')}');
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
