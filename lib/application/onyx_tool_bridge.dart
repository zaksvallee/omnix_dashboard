import '../domain/authority/onyx_task_protocol.dart';

class OnyxToolBridge {
  final String scopeLabel;
  final String incidentReference;
  final bool Function()? openDispatchBoard;
  final bool Function()? openTacticalTrack;
  final bool Function()? openCctvReview;
  final bool Function()? openClientComms;
  final bool Function()? openReportsWorkspace;

  const OnyxToolBridge({
    required this.scopeLabel,
    required this.incidentReference,
    this.openDispatchBoard,
    this.openTacticalTrack,
    this.openCctvReview,
    this.openClientComms,
    this.openReportsWorkspace,
  });

  OnyxToolResult executeRecommendation(OnyxRecommendation recommendation) {
    final callback = _callbackForTarget(recommendation.target);
    final didOpen = callback?.call() ?? false;
    final routeLabel = _routeLabelForRecommendation(recommendation);
    final incident = incidentReference.trim().isEmpty
        ? 'the active incident'
        : incidentReference.trim();
    return OnyxToolResult(
      executed: didOpen,
      target: recommendation.target,
      headline: didOpen
          ? '$routeLabel opened from typed triage.'
          : '$routeLabel is not available from this ONYX surface.',
      detail: didOpen
          ? recommendation.detail
          : 'ONYX kept the typed next move pinned for $incident in $scopeLabel, but this surface could not open $routeLabel directly.',
      summary: recommendation.summary,
      receipt: didOpen
          ? OnyxEvidenceReceipt(
              label: 'EVIDENCE RECEIPT',
              headline: recommendation.evidenceHeadline,
              detail: recommendation.evidenceDetail,
            )
          : OnyxEvidenceReceipt(
              label: 'EVIDENCE READY',
              headline: 'Typed next move held for review.',
              detail:
                  'ONYX staged the typed triage note for $incident in $scopeLabel even though $routeLabel could not open from this surface.',
            ),
    );
  }

  bool Function()? _callbackForTarget(OnyxToolTarget target) {
    return switch (target) {
      OnyxToolTarget.dispatchBoard => openDispatchBoard,
      OnyxToolTarget.tacticalTrack => openTacticalTrack,
      OnyxToolTarget.cctvReview => openCctvReview,
      OnyxToolTarget.clientComms => openClientComms,
      OnyxToolTarget.reportsWorkspace => openReportsWorkspace,
    };
  }

  String _routeLabelForRecommendation(OnyxRecommendation recommendation) {
    return switch (recommendation.target) {
      OnyxToolTarget.dispatchBoard => 'Dispatch Board',
      OnyxToolTarget.tacticalTrack => 'Tactical Track',
      OnyxToolTarget.cctvReview => 'CCTV Review',
      OnyxToolTarget.clientComms => 'Client Comms',
      OnyxToolTarget.reportsWorkspace => 'Reports Workspace',
    };
  }
}
