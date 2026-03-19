import 'package:flutter/material.dart';

import 'video_fleet_scope_health_view.dart';

enum VideoFleetWatchActionDrilldown {
  limited,
  alerts,
  repeat,
  escalated,
  filtered,
  flaggedIdentity,
  temporaryIdentity,
  allowlistedIdentity,
}

extension VideoFleetWatchActionDrilldownCopy on VideoFleetWatchActionDrilldown {
  bool get isIdentityPolicy =>
      this == VideoFleetWatchActionDrilldown.flaggedIdentity ||
      this == VideoFleetWatchActionDrilldown.temporaryIdentity ||
      this == VideoFleetWatchActionDrilldown.allowlistedIdentity;

  String get focusLabel => switch (this) {
    VideoFleetWatchActionDrilldown.limited => 'Limited watch coverage',
    VideoFleetWatchActionDrilldown.alerts => 'Alert actions',
    VideoFleetWatchActionDrilldown.repeat => 'Repeat updates',
    VideoFleetWatchActionDrilldown.escalated => 'Escalated reviews',
    VideoFleetWatchActionDrilldown.filtered => 'Filtered reviews',
    VideoFleetWatchActionDrilldown.flaggedIdentity =>
      'Flagged identity matches',
    VideoFleetWatchActionDrilldown.temporaryIdentity =>
      'Temporary identity approvals',
    VideoFleetWatchActionDrilldown.allowlistedIdentity =>
      'Allowlisted identity matches',
  };

  String get focusDetail => switch (this) {
    VideoFleetWatchActionDrilldown.limited =>
      'Showing fleet scopes where remote monitoring is active but limited.',
    VideoFleetWatchActionDrilldown.alerts =>
      'Showing fleet scopes where ONYX sent a client alert.',
    VideoFleetWatchActionDrilldown.repeat =>
      'Showing fleet scopes where ONYX stayed in monitoring with repeat updates.',
    VideoFleetWatchActionDrilldown.escalated =>
      'Showing fleet scopes where ONYX pushed the review into escalation.',
    VideoFleetWatchActionDrilldown.filtered =>
      'Showing fleet scopes where ONYX kept the review below notification threshold.',
    VideoFleetWatchActionDrilldown.flaggedIdentity =>
      'Showing fleet scopes where ONYX matched a flagged face or plate.',
    VideoFleetWatchActionDrilldown.temporaryIdentity =>
      'Showing fleet scopes where ONYX matched a one-time approved face or plate. Each scope shows the approval expiry when available.',
    VideoFleetWatchActionDrilldown.allowlistedIdentity =>
      'Showing fleet scopes where ONYX matched an allowlisted face or plate.',
  };

  String get focusBannerTitle => isIdentityPolicy
      ? 'Focused identity policy: $focusLabel'
      : 'Focused watch action: $focusLabel';

  Color get accentColor => switch (this) {
    VideoFleetWatchActionDrilldown.limited => const Color(0xFFF59E0B),
    VideoFleetWatchActionDrilldown.alerts => const Color(0xFF67E8F9),
    VideoFleetWatchActionDrilldown.repeat => const Color(0xFFFDE68A),
    VideoFleetWatchActionDrilldown.escalated => const Color(0xFFF87171),
    VideoFleetWatchActionDrilldown.filtered => const Color(0xFF9AB1CF),
    VideoFleetWatchActionDrilldown.flaggedIdentity => const Color(0xFFF87171),
    VideoFleetWatchActionDrilldown.temporaryIdentity => const Color(0xFF60A5FA),
    VideoFleetWatchActionDrilldown.allowlistedIdentity => const Color(
      0xFF86EFAC,
    ),
  };

  Color get focusBannerBackgroundColor => accentColor.withValues(alpha: 0.16);

  Color get focusBannerBorderColor => accentColor.withValues(alpha: 0.34);

  Color get focusBannerActionColor => accentColor;

  String get actionableSectionTitle => switch (this) {
    VideoFleetWatchActionDrilldown.flaggedIdentity => 'FLAGGED IDENTITY',
    VideoFleetWatchActionDrilldown.temporaryIdentity => 'TEMPORARY IDENTITY',
    VideoFleetWatchActionDrilldown.allowlistedIdentity =>
      'ALLOWLISTED IDENTITY',
    _ => 'ACTIONABLE',
  };

  String get watchOnlySectionTitle => switch (this) {
    VideoFleetWatchActionDrilldown.flaggedIdentity =>
      'WATCH-ONLY FLAGGED IDENTITY',
    VideoFleetWatchActionDrilldown.temporaryIdentity =>
      'WATCH-ONLY TEMPORARY IDENTITY',
    VideoFleetWatchActionDrilldown.allowlistedIdentity =>
      'WATCH-ONLY ALLOWLISTED IDENTITY',
    _ => 'WATCH-ONLY',
  };
}

extension VideoFleetScopeHealthViewWatchActionMatch
    on VideoFleetScopeHealthView {
  bool matchesWatchActionDrilldown(VideoFleetWatchActionDrilldown drilldown) {
    return switch (drilldown) {
      VideoFleetWatchActionDrilldown.limited => watchLabel == 'LIMITED',
      VideoFleetWatchActionDrilldown.alerts => alertCount > 0,
      VideoFleetWatchActionDrilldown.repeat => repeatCount > 0,
      VideoFleetWatchActionDrilldown.escalated => escalationCount > 0,
      VideoFleetWatchActionDrilldown.filtered => suppressedCount > 0,
      VideoFleetWatchActionDrilldown.flaggedIdentity =>
        hasFlaggedIdentityPolicy,
      VideoFleetWatchActionDrilldown.temporaryIdentity =>
        hasTemporaryIdentityPolicy,
      VideoFleetWatchActionDrilldown.allowlistedIdentity =>
        hasAllowlistedIdentityPolicy,
    };
  }
}

Color identityPolicyAccentColorForScope(
  VideoFleetScopeHealthView scope, {
  DateTime? referenceUtc,
}) {
  if (scope.hasFlaggedIdentityPolicy) {
    return VideoFleetWatchActionDrilldown.flaggedIdentity.accentColor;
  }
  if (scope.hasTemporaryIdentityPolicy) {
    return switch (scope.temporaryIdentityUrgency(referenceUtc)) {
      VideoFleetTemporaryIdentityUrgency.warning => const Color(0xFFFBBF24),
      VideoFleetTemporaryIdentityUrgency.critical ||
      VideoFleetTemporaryIdentityUrgency.expired => const Color(0xFFF87171),
      _ => VideoFleetWatchActionDrilldown.temporaryIdentity.accentColor,
    };
  }
  if (scope.hasAllowlistedIdentityPolicy) {
    return VideoFleetWatchActionDrilldown.allowlistedIdentity.accentColor;
  }
  return const Color(0xFF9AB1CF);
}

Color temporaryIdentityAccentColorForScopes(
  List<VideoFleetScopeHealthView> scopes, {
  DateTime? referenceUtc,
}) {
  var highestSeverity = 0;
  for (final scope in scopes) {
    if (!scope.hasTemporaryIdentityPolicy) {
      continue;
    }
    final urgency = scope.temporaryIdentityUrgency(referenceUtc);
    final severity = switch (urgency) {
      VideoFleetTemporaryIdentityUrgency.expired ||
      VideoFleetTemporaryIdentityUrgency.critical => 3,
      VideoFleetTemporaryIdentityUrgency.warning => 2,
      VideoFleetTemporaryIdentityUrgency.active => 1,
      null => 1,
    };
    if (severity > highestSeverity) {
      highestSeverity = severity;
    }
  }
  return switch (highestSeverity) {
    3 => const Color(0xFFF87171),
    2 => const Color(0xFFFBBF24),
    _ => VideoFleetWatchActionDrilldown.temporaryIdentity.accentColor,
  };
}

List<VideoFleetScopeHealthView> filterFleetScopesForWatchAction(
  List<VideoFleetScopeHealthView> scopes,
  VideoFleetWatchActionDrilldown? drilldown,
) {
  if (drilldown == null) {
    return scopes;
  }
  return scopes
      .where((scope) => scope.matchesWatchActionDrilldown(drilldown))
      .toList(growable: false);
}

List<VideoFleetScopeHealthView> orderFleetScopesForWatchAction(
  List<VideoFleetScopeHealthView> scopes,
  VideoFleetWatchActionDrilldown? drilldown, {
  DateTime? referenceUtc,
}) {
  if (drilldown != VideoFleetWatchActionDrilldown.temporaryIdentity) {
    return scopes;
  }
  final ordered = List<VideoFleetScopeHealthView>.from(scopes);
  ordered.sort((a, b) {
    final aRemaining = a.temporaryIdentityRemaining(referenceUtc);
    final bRemaining = b.temporaryIdentityRemaining(referenceUtc);
    if (aRemaining == null && bRemaining == null) {
      return a.siteName.compareTo(b.siteName);
    }
    if (aRemaining == null) {
      return 1;
    }
    if (bRemaining == null) {
      return -1;
    }
    final compare = aRemaining.compareTo(bRemaining);
    if (compare != 0) {
      return compare;
    }
    return a.siteName.compareTo(b.siteName);
  });
  return ordered;
}

VideoFleetScopeHealthView? primaryFleetScopeForWatchAction(
  VideoFleetScopeHealthSections sections,
  VideoFleetWatchActionDrilldown? drilldown,
) {
  if (drilldown == null) {
    return null;
  }
  if (sections.actionableScopes.isNotEmpty) {
    return sections.actionableScopes.first;
  }
  if (sections.watchOnlyScopes.isNotEmpty) {
    return sections.watchOnlyScopes.first;
  }
  return null;
}

String focusDetailForWatchAction(
  List<VideoFleetScopeHealthView> scopes,
  VideoFleetWatchActionDrilldown drilldown, {
  DateTime? referenceUtc,
}) {
  if (drilldown != VideoFleetWatchActionDrilldown.temporaryIdentity) {
    return drilldown.focusDetail;
  }
  final matchingScopes = filterFleetScopesForWatchAction(scopes, drilldown);
  VideoFleetScopeHealthView? soonestScope;
  Duration? soonestRemaining;
  for (final scope in matchingScopes) {
    final remaining = scope.temporaryIdentityRemaining(referenceUtc);
    if (remaining == null) {
      continue;
    }
    if (soonestRemaining == null || remaining < soonestRemaining) {
      soonestRemaining = remaining;
      soonestScope = scope;
    }
  }
  if (soonestScope == null || soonestRemaining == null) {
    return drilldown.focusDetail;
  }
  final countdown = soonestScope.temporaryIdentityCountdownText(referenceUtc);
  final until = soonestScope.temporaryIdentityValidUntilText;
  if (countdown == null || until == null) {
    return drilldown.focusDetail;
  }
  return '${drilldown.focusDetail} Soonest expiry: ${soonestScope.siteName} $countdown ($until).';
}

String? prominentLatestTextForWatchAction(
  VideoFleetScopeHealthView scope,
  VideoFleetWatchActionDrilldown? drilldown,
) {
  if (drilldown == null) {
    return scope.prominentLatestText;
  }
  final focusedSummary = _focusedRecentWatchActionSummary(scope, drilldown);
  return focusedSummary ?? scope.prominentLatestText;
}

String? _focusedRecentWatchActionSummary(
  VideoFleetScopeHealthView scope,
  VideoFleetWatchActionDrilldown drilldown,
) {
  if (drilldown == VideoFleetWatchActionDrilldown.limited) {
    final detail = scope.limitedWatchStatusDetailText;
    if (detail == null || detail.trim().isEmpty) {
      return null;
    }
    return 'Limited watch: ${detail.trim()}';
  }
  if (drilldown == VideoFleetWatchActionDrilldown.flaggedIdentity ||
      drilldown == VideoFleetWatchActionDrilldown.temporaryIdentity ||
      drilldown == VideoFleetWatchActionDrilldown.allowlistedIdentity) {
    final prefix = switch (drilldown) {
      VideoFleetWatchActionDrilldown.flaggedIdentity => 'Flagged identity',
      VideoFleetWatchActionDrilldown.temporaryIdentity => 'Temporary identity',
      VideoFleetWatchActionDrilldown.allowlistedIdentity =>
        'Allowlisted identity',
      _ => '',
    };
    final identityMatch = scope.identityMatchText;
    final identityPolicy = scope.identityPolicyText;
    final detail = identityMatch ?? identityPolicy;
    if (detail == null) {
      return null;
    }
    final until = drilldown == VideoFleetWatchActionDrilldown.temporaryIdentity
        ? scope.temporaryIdentityValidUntilText
        : null;
    final header = until == null ? prefix : '$prefix until $until';
    return '$header: ${detail.replaceFirst('Identity match: ', '').replaceFirst('Identity policy: ', '')}';
  }
  final entries = switch (drilldown) {
    VideoFleetWatchActionDrilldown.filtered =>
      scope.suppressedHistory
          .map((entry) => entry.trim())
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false),
    _ =>
      scope.actionHistory
          .map((entry) => entry.trim())
          .where((entry) => _matchesActionHistoryDrilldown(entry, drilldown))
          .toList(growable: false),
  };
  if (entries.isEmpty) {
    return null;
  }
  final latest = entries.first;
  final remaining = entries.length - 1;
  final prefix = switch (drilldown) {
    VideoFleetWatchActionDrilldown.limited => 'Limited watch',
    VideoFleetWatchActionDrilldown.alerts => 'Recent alert actions',
    VideoFleetWatchActionDrilldown.repeat => 'Recent repeat updates',
    VideoFleetWatchActionDrilldown.escalated => 'Recent escalations',
    VideoFleetWatchActionDrilldown.filtered => 'Recent filtered reviews',
    _ => '',
  };
  if (remaining <= 0) {
    return '$prefix: $latest';
  }
  return '$prefix: $latest (+$remaining more)';
}

bool _matchesActionHistoryDrilldown(
  String entry,
  VideoFleetWatchActionDrilldown drilldown,
) {
  final normalized = entry.trim().toLowerCase();
  if (normalized.isEmpty) {
    return false;
  }
  return switch (drilldown) {
    VideoFleetWatchActionDrilldown.limited => normalized.contains('limited'),
    VideoFleetWatchActionDrilldown.alerts =>
      normalized.contains('alert') || normalized.contains('incident'),
    VideoFleetWatchActionDrilldown.repeat => normalized.contains('repeat'),
    VideoFleetWatchActionDrilldown.escalated => normalized.contains('escalat'),
    VideoFleetWatchActionDrilldown.filtered => normalized.contains('suppress'),
    VideoFleetWatchActionDrilldown.flaggedIdentity =>
      normalized.contains('flagged') || normalized.contains('watchlist'),
    VideoFleetWatchActionDrilldown.temporaryIdentity =>
      normalized.contains('temporary approval') ||
          normalized.contains('one-time approval') ||
          normalized.contains('one time approval'),
    VideoFleetWatchActionDrilldown.allowlistedIdentity =>
      normalized.contains('allowlisted') ||
          normalized.contains('known allowed'),
  };
}

class VideoFleetScopeHealthSections {
  final List<VideoFleetScopeHealthView> actionableScopes;
  final List<VideoFleetScopeHealthView> watchOnlyScopes;
  final int activeCount;
  final int limitedCount;
  final int gapCount;
  final int highRiskCount;
  final int recoveredCount;
  final int suppressedCount;
  final int alertActionCount;
  final int repeatActionCount;
  final int escalationActionCount;
  final int suppressedActionCount;
  final int flaggedIdentityCount;
  final int temporaryIdentityCount;
  final int allowlistedIdentityCount;
  final int staleCount;
  final int noIncidentCount;

  const VideoFleetScopeHealthSections({
    required this.actionableScopes,
    required this.watchOnlyScopes,
    required this.activeCount,
    required this.limitedCount,
    required this.gapCount,
    required this.highRiskCount,
    required this.recoveredCount,
    required this.suppressedCount,
    required this.alertActionCount,
    required this.repeatActionCount,
    required this.escalationActionCount,
    required this.suppressedActionCount,
    required this.flaggedIdentityCount,
    required this.temporaryIdentityCount,
    required this.allowlistedIdentityCount,
    required this.staleCount,
    required this.noIncidentCount,
  });

  factory VideoFleetScopeHealthSections.fromScopes(
    List<VideoFleetScopeHealthView> scopes,
  ) {
    final actionableScopes = scopes
        .where((scope) => scope.hasIncidentContext)
        .toList(growable: false);
    final watchOnlyScopes = scopes
        .where((scope) => !scope.hasIncidentContext)
        .toList(growable: false);
    return VideoFleetScopeHealthSections(
      actionableScopes: actionableScopes,
      watchOnlyScopes: watchOnlyScopes,
      activeCount: scopes
          .where(
            (scope) =>
                scope.watchLabel == 'ACTIVE' || scope.watchLabel == 'LIMITED',
          )
          .length,
      limitedCount: scopes
          .where((scope) => scope.watchLabel == 'LIMITED')
          .length,
      gapCount: scopes.where((scope) => scope.hasWatchActivationGap).length,
      highRiskCount: scopes
          .where((scope) => (scope.latestRiskScore ?? 0) >= 70)
          .length,
      recoveredCount: scopes.where((scope) => scope.hasRecentRecovery).length,
      suppressedCount: scopes
          .where((scope) => scope.hasSuppressedSceneAction)
          .length,
      alertActionCount: scopes.fold(
        0,
        (total, scope) => total + scope.alertCount,
      ),
      repeatActionCount: scopes.fold(
        0,
        (total, scope) => total + scope.repeatCount,
      ),
      escalationActionCount: scopes.fold(
        0,
        (total, scope) => total + scope.escalationCount,
      ),
      suppressedActionCount: scopes.fold(
        0,
        (total, scope) => total + scope.suppressedCount,
      ),
      flaggedIdentityCount: scopes
          .where((scope) => scope.hasFlaggedIdentityPolicy)
          .length,
      temporaryIdentityCount: scopes
          .where((scope) => scope.hasTemporaryIdentityPolicy)
          .length,
      allowlistedIdentityCount: scopes
          .where((scope) => scope.hasAllowlistedIdentityPolicy)
          .length,
      staleCount: scopes.where((scope) => scope.isStale).length,
      noIncidentCount: watchOnlyScopes.length,
    );
  }

  String get actionableLabel => actionableScopes.isNotEmpty
      ? 'Incident-backed fleet scopes'
      : 'No incident-backed fleet scopes right now';

  String get watchOnlyLabel => watchOnlyScopes.isNotEmpty
      ? 'Watch scopes awaiting incident context'
      : 'No watch-only scopes awaiting incident context';

  String actionableLabelFor(VideoFleetWatchActionDrilldown? drilldown) {
    if (drilldown == null) {
      return actionableLabel;
    }
    final hasMatchingActionable = actionableScopes.any(
      (scope) => scope.matchesWatchActionDrilldown(drilldown),
    );
    return switch (drilldown) {
      VideoFleetWatchActionDrilldown.limited =>
        hasMatchingActionable
            ? 'Incident-backed limited-watch scopes'
            : 'No incident-backed limited-watch scopes right now',
      VideoFleetWatchActionDrilldown.alerts =>
        hasMatchingActionable
            ? 'Incident-backed alert scopes'
            : 'No incident-backed alert scopes right now',
      VideoFleetWatchActionDrilldown.repeat =>
        hasMatchingActionable
            ? 'Incident-backed repeat-update scopes'
            : 'No incident-backed repeat-update scopes right now',
      VideoFleetWatchActionDrilldown.escalated =>
        hasMatchingActionable
            ? 'Incident-backed escalated scopes'
            : 'No incident-backed escalated scopes right now',
      VideoFleetWatchActionDrilldown.filtered =>
        hasMatchingActionable
            ? 'Incident-backed filtered scopes'
            : 'No incident-backed filtered scopes right now',
      VideoFleetWatchActionDrilldown.flaggedIdentity =>
        hasMatchingActionable
            ? 'Incident-backed flagged-identity scopes'
            : 'No incident-backed flagged-identity scopes right now',
      VideoFleetWatchActionDrilldown.temporaryIdentity =>
        hasMatchingActionable
            ? 'Incident-backed temporary-identity scopes'
            : 'No incident-backed temporary-identity scopes right now',
      VideoFleetWatchActionDrilldown.allowlistedIdentity =>
        hasMatchingActionable
            ? 'Incident-backed allowlisted-identity scopes'
            : 'No incident-backed allowlisted-identity scopes right now',
    };
  }

  String watchOnlyLabelFor(VideoFleetWatchActionDrilldown? drilldown) {
    if (drilldown == null) {
      return watchOnlyLabel;
    }
    final hasMatchingWatchOnly = watchOnlyScopes.any(
      (scope) => scope.matchesWatchActionDrilldown(drilldown),
    );
    return switch (drilldown) {
      VideoFleetWatchActionDrilldown.limited =>
        hasMatchingWatchOnly
            ? 'Watch scopes with limited remote coverage'
            : 'No watch-only limited-watch scopes awaiting incident context',
      VideoFleetWatchActionDrilldown.alerts =>
        hasMatchingWatchOnly
            ? 'Watch scopes with client alert actions'
            : 'No watch-only alert scopes awaiting incident context',
      VideoFleetWatchActionDrilldown.repeat =>
        hasMatchingWatchOnly
            ? 'Watch scopes with repeat-update actions'
            : 'No watch-only repeat-update scopes awaiting incident context',
      VideoFleetWatchActionDrilldown.escalated =>
        hasMatchingWatchOnly
            ? 'Watch scopes with escalated reviews'
            : 'No watch-only escalated scopes awaiting incident context',
      VideoFleetWatchActionDrilldown.filtered =>
        hasMatchingWatchOnly
            ? 'Watch scopes with filtered reviews'
            : 'No watch-only filtered scopes awaiting incident context',
      VideoFleetWatchActionDrilldown.flaggedIdentity =>
        hasMatchingWatchOnly
            ? 'Watch scopes with flagged identity matches'
            : 'No watch-only flagged identity scopes awaiting incident context',
      VideoFleetWatchActionDrilldown.temporaryIdentity =>
        hasMatchingWatchOnly
            ? 'Watch scopes with temporary identity approvals'
            : 'No watch-only temporary identity scopes awaiting incident context',
      VideoFleetWatchActionDrilldown.allowlistedIdentity =>
        hasMatchingWatchOnly
            ? 'Watch scopes with allowlisted identity matches'
            : 'No watch-only allowlisted identity scopes awaiting incident context',
    };
  }
}
