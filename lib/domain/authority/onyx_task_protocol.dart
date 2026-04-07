import 'dart:convert';

enum OnyxWorkIntent { triageIncident }

enum OnyxToolTarget {
  dispatchBoard,
  tacticalTrack,
  cctvReview,
  clientComms,
  reportsWorkspace,
}

class OnyxWorkItem {
  final String id;
  final OnyxWorkIntent intent;
  final String prompt;
  final String clientId;
  final String siteId;
  final String incidentReference;
  final String sourceRouteLabel;
  final DateTime createdAt;
  final String contextSummary;
  final int totalScopedEvents;
  final int activeDispatchCount;
  final int dispatchesAwaitingResponseCount;
  final int responseCount;
  final int closedDispatchCount;
  final int patrolCount;
  final int guardCheckInCount;
  final int scopedSiteCount;
  final bool hasVisualSignal;
  final String latestIntelligenceHeadline;
  final String latestIntelligenceSourceType;
  final int? latestIntelligenceRiskScore;
  final String latestPartnerStatusLabel;
  final String latestResponderLabel;
  final String latestEventLabel;
  final DateTime? latestEventAt;
  final DateTime? latestDispatchCreatedAt;
  final DateTime? latestClosureAt;
  final String prioritySiteLabel;
  final String prioritySiteReason;
  final int? prioritySiteRiskScore;
  final List<String> rankedSiteSummaries;
  final int repeatedFalseAlarmCount;
  final bool hasHumanSafetySignal;
  final bool hasGuardWelfareRisk;
  final String guardWelfareSignalLabel;
  final String pendingFollowUpLabel;
  final String pendingFollowUpPrompt;
  final OnyxToolTarget? pendingFollowUpTarget;
  final int pendingFollowUpAgeMinutes;
  final int staleFollowUpSurfaceCount;
  final List<String> pendingConfirmations;

  const OnyxWorkItem({
    required this.id,
    required this.intent,
    required this.prompt,
    required this.clientId,
    required this.siteId,
    required this.incidentReference,
    required this.sourceRouteLabel,
    required this.createdAt,
    this.contextSummary = '',
    this.totalScopedEvents = 0,
    this.activeDispatchCount = 0,
    this.dispatchesAwaitingResponseCount = 0,
    this.responseCount = 0,
    this.closedDispatchCount = 0,
    this.patrolCount = 0,
    this.guardCheckInCount = 0,
    this.scopedSiteCount = 0,
    this.hasVisualSignal = false,
    this.latestIntelligenceHeadline = '',
    this.latestIntelligenceSourceType = '',
    this.latestIntelligenceRiskScore,
    this.latestPartnerStatusLabel = '',
    this.latestResponderLabel = '',
    this.latestEventLabel = '',
    this.latestEventAt,
    this.latestDispatchCreatedAt,
    this.latestClosureAt,
    this.prioritySiteLabel = '',
    this.prioritySiteReason = '',
    this.prioritySiteRiskScore,
    this.rankedSiteSummaries = const <String>[],
    this.repeatedFalseAlarmCount = 0,
    this.hasHumanSafetySignal = false,
    this.hasGuardWelfareRisk = false,
    this.guardWelfareSignalLabel = '',
    this.pendingFollowUpLabel = '',
    this.pendingFollowUpPrompt = '',
    this.pendingFollowUpTarget,
    this.pendingFollowUpAgeMinutes = 0,
    this.staleFollowUpSurfaceCount = 0,
    this.pendingConfirmations = const <String>[],
  });

  bool get hasPendingFollowUp {
    return pendingFollowUpLabel.trim().isNotEmpty &&
        pendingFollowUpPrompt.trim().isNotEmpty &&
        pendingFollowUpTarget != null;
  }

  bool get hasUnresolvedPendingFollowUp {
    return hasPendingFollowUp &&
        (staleFollowUpSurfaceCount >= 1 || pendingFollowUpAgeMinutes >= 8);
  }

  bool get hasOverduePendingFollowUp {
    return hasPendingFollowUp &&
        (staleFollowUpSurfaceCount >= 2 || pendingFollowUpAgeMinutes >= 20);
  }

  String get scopeLabel {
    final resolvedClientId = clientId.trim();
    final resolvedSiteId = siteId.trim();
    if (resolvedClientId.isEmpty && resolvedSiteId.isEmpty) {
      return 'Global controller scope';
    }
    if (resolvedClientId.isEmpty) {
      return resolvedSiteId;
    }
    if (resolvedSiteId.isEmpty) {
      return '$resolvedClientId • all sites';
    }
    return '$resolvedClientId • $resolvedSiteId';
  }
}

class OnyxRecommendation {
  final String workItemId;
  final OnyxToolTarget target;
  final String nextMoveLabel;
  final String headline;
  final String detail;
  final String summary;
  final String evidenceHeadline;
  final String evidenceDetail;
  final String advisory;
  final double confidence;
  final List<String> missingInfo;
  final List<String> contextHighlights;
  final String followUpLabel;
  final String followUpPrompt;
  final bool allowRouteExecution;

  const OnyxRecommendation({
    required this.workItemId,
    required this.target,
    required this.nextMoveLabel,
    required this.headline,
    required this.detail,
    required this.summary,
    required this.evidenceHeadline,
    required this.evidenceDetail,
    this.advisory = '',
    this.confidence = 0.72,
    this.missingInfo = const <String>[],
    this.contextHighlights = const <String>[],
    this.followUpLabel = '',
    this.followUpPrompt = '',
    this.allowRouteExecution = true,
  });

  Map<String, String> toToolActionArguments() {
    return <String, String>{
      'workItemId': workItemId,
      'target': target.name,
      'nextMoveLabel': nextMoveLabel,
      'headline': headline,
      'detail': detail,
      'summary': summary,
      'evidenceHeadline': evidenceHeadline,
      'evidenceDetail': evidenceDetail,
      if (advisory.trim().isNotEmpty) 'advisory': advisory,
      'confidence': confidence.toString(),
      if (missingInfo.isNotEmpty) 'missingInfo': jsonEncode(missingInfo),
      if (contextHighlights.isNotEmpty)
        'contextHighlights': jsonEncode(contextHighlights),
      if (followUpLabel.trim().isNotEmpty) 'followUpLabel': followUpLabel,
      if (followUpPrompt.trim().isNotEmpty) 'followUpPrompt': followUpPrompt,
      'allowRouteExecution': allowRouteExecution ? 'true' : 'false',
    };
  }

  factory OnyxRecommendation.fromToolActionArguments(
    Map<String, String> arguments,
  ) {
    final targetName = arguments['target']?.trim() ?? '';
    final target = OnyxToolTarget.values.firstWhere(
      (value) => value.name == targetName,
      orElse: () => OnyxToolTarget.dispatchBoard,
    );
    final parsedConfidence = double.tryParse(
      arguments['confidence']?.trim() ?? '',
    );
    final missingInfo = _decodeStringList(arguments['missingInfo']);
    final contextHighlights = _decodeStringList(arguments['contextHighlights']);
    return OnyxRecommendation(
      workItemId: arguments['workItemId']?.trim() ?? 'interactive',
      target: target,
      nextMoveLabel:
          arguments['nextMoveLabel']?.trim() ?? 'OPEN DISPATCH BOARD',
      headline:
          arguments['headline']?.trim() ?? 'Dispatch Board is the next move',
      detail:
          arguments['detail']?.trim() ??
          'Work the next controller move from Dispatch Board.',
      summary:
          arguments['summary']?.trim() ??
          'One next move is staged from typed triage.',
      evidenceHeadline:
          arguments['evidenceHeadline']?.trim() ??
          'Dispatch Board handoff sealed.',
      evidenceDetail:
          arguments['evidenceDetail']?.trim() ??
          'ONYX recorded the typed triage handoff for the next controller move.',
      advisory: arguments['advisory']?.trim() ?? '',
      confidence: parsedConfidence ?? 0.72,
      missingInfo: missingInfo,
      contextHighlights: contextHighlights,
      followUpLabel: arguments['followUpLabel']?.trim() ?? '',
      followUpPrompt: arguments['followUpPrompt']?.trim() ?? '',
      allowRouteExecution:
          (arguments['allowRouteExecution']?.trim().toLowerCase() ?? 'true') !=
          'false',
    );
  }
}

List<String> _decodeStringList(String? raw) {
  final normalized = raw?.trim() ?? '';
  if (normalized.isEmpty) {
    return const <String>[];
  }
  try {
    final decoded = jsonDecode(normalized);
    if (decoded is! List) {
      return const <String>[];
    }
    return decoded
        .map((entry) => entry?.toString().trim() ?? '')
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  } catch (_) {
    return normalized
        .split('||')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }
}

class OnyxEvidenceReceipt {
  final String label;
  final String headline;
  final String detail;

  const OnyxEvidenceReceipt({
    required this.label,
    required this.headline,
    required this.detail,
  });
}

class OnyxToolResult {
  final bool executed;
  final OnyxToolTarget target;
  final String headline;
  final String detail;
  final String summary;
  final OnyxEvidenceReceipt receipt;

  const OnyxToolResult({
    required this.executed,
    required this.target,
    required this.headline,
    required this.detail,
    required this.summary,
    required this.receipt,
  });
}
