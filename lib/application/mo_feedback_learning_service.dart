import 'mo_runtime_matching_service.dart';
import 'mo_promotion_decision_store.dart';

class MoPromotionGuidance {
  final String moId;
  final String title;
  final String currentValidationStatus;
  final String targetValidationStatus;
  final String confidenceBias;
  final String trendBias;
  final String urgencyBias;
  final String validationDriftSummary;
  final String summary;

  const MoPromotionGuidance({
    required this.moId,
    required this.title,
    required this.currentValidationStatus,
    required this.targetValidationStatus,
    required this.confidenceBias,
    required this.trendBias,
    required this.urgencyBias,
    required this.validationDriftSummary,
    required this.summary,
  });
}

class MoFeedbackLearningService {
  final MoPromotionDecisionStore decisionStore;

  const MoFeedbackLearningService({
    this.decisionStore = const MoPromotionDecisionStore(),
  });

  MoPromotionGuidance? buildShadowPromotionGuidance({
    required List<OnyxMoShadowMatch> matches,
    required int repeatedShadowCount,
    String shadowValidationDriftSummary = '',
    int shadowPostureStrengthScore = 0,
    String shadowPostureBiasSummary = '',
  }) {
    if (matches.isEmpty) {
      return null;
    }
    final lead = matches.first;
    final currentStatus = lead.validationStatus.trim();
    final targetStatus = _targetStatusFor(currentStatus);
    if (targetStatus.isEmpty) {
      return null;
    }
    final decision = decisionStore.decisionFor(lead.moId);
    final decisionStatus = decision?.status.name ?? 'pending';
    final driftSummary = shadowValidationDriftSummary.trim();
    final driftSignal = _driftSignalFor(driftSummary);
    final postureSignal = _postureSignalFor(
      strengthScore: shadowPostureStrengthScore,
      biasSummary: shadowPostureBiasSummary,
    );
    if (repeatedShadowCount <= 0 &&
        driftSignal == _ShadowValidationDriftSignal.none &&
        postureSignal == _ShadowPostureSignal.none) {
      return null;
    }
    final baseTrendBias = repeatedShadowCount >= 2
        ? 0.25
        : repeatedShadowCount == 1
        ? 0.12
        : postureSignal == _ShadowPostureSignal.surge
        ? 0.16
        : 0.10;
    final rejectedCanReopen =
        repeatedShadowCount >= 2 || postureSignal != _ShadowPostureSignal.none;
    if (decisionStatus == 'rejected' && !rejectedCanReopen) {
      return MoPromotionGuidance(
        moId: lead.moId,
        title: lead.title,
        currentValidationStatus: currentStatus,
        targetValidationStatus: targetStatus,
        confidenceBias: 'HOLD',
        trendBias: '+0.00',
        urgencyBias: 'LOCKED',
        validationDriftSummary: driftSummary,
        summary:
            'Hold ${lead.moId} after operator rejection • ${lead.title} • x$repeatedShadowCount',
      );
    }
    if (decisionStatus == 'accepted') {
      return MoPromotionGuidance(
        moId: lead.moId,
        title: lead.title,
        currentValidationStatus: currentStatus,
        targetValidationStatus: targetStatus,
        confidenceBias: 'LOCKED',
        trendBias: '+0.00',
        urgencyBias: 'LOCKED',
        validationDriftSummary: driftSummary,
        summary:
            'Promotion accepted for ${lead.moId} toward $targetStatus review • ${lead.title}',
      );
    }
    final accelerated =
        driftSignal == _ShadowValidationDriftSignal.validatedRising ||
        postureSignal != _ShadowPostureSignal.none;
    final softened =
        driftSignal == _ShadowValidationDriftSignal.shadowModeEasing &&
        postureSignal == _ShadowPostureSignal.none;
    final confidenceBias = accelerated
        ? postureSignal == _ShadowPostureSignal.surge
              ? repeatedShadowCount >= 2
                    ? 'CRITICAL'
                    : 'HIGH'
              : repeatedShadowCount >= 2
              ? 'CRITICAL'
              : 'HIGH'
        : softened
        ? 'LOW'
        : repeatedShadowCount >= 2
        ? 'HIGH'
        : 'MEDIUM';
    final trendBias = accelerated
        ? _trendBias(
            baseTrendBias +
                (driftSignal == _ShadowValidationDriftSignal.validatedRising
                    ? repeatedShadowCount >= 2
                          ? 0.10
                          : 0.08
                    : 0.0) +
                switch (postureSignal) {
                  _ShadowPostureSignal.surge => 0.10,
                  _ShadowPostureSignal.elevated => 0.06,
                  _ShadowPostureSignal.none => 0.0,
                },
          )
        : softened
        ? _trendBias(0.04)
        : _trendBias(baseTrendBias);
    final urgencyBias = accelerated
        ? 'ACCELERATE'
        : softened
        ? 'SOFTEN'
        : decisionStatus == 'rejected'
        ? 'REOPEN'
        : 'STEADY';
    final summary = accelerated &&
            postureSignal == _ShadowPostureSignal.surge &&
            driftSignal != _ShadowValidationDriftSignal.validatedRising
        ? 'Accelerate ${lead.moId} toward $targetStatus review after shadow posture surged at the lead site • ${lead.title}${_repeatSuffix(repeatedShadowCount)}'
        : accelerated &&
                postureSignal == _ShadowPostureSignal.elevated &&
                driftSignal != _ShadowValidationDriftSignal.validatedRising
        ? 'Accelerate ${lead.moId} toward $targetStatus review after shadow posture stayed elevated at the lead site • ${lead.title}${_repeatSuffix(repeatedShadowCount)}'
        : accelerated
        ? 'Accelerate ${lead.moId} toward $targetStatus review after validated drift rose across recent shifts • ${lead.title}${_repeatSuffix(repeatedShadowCount)}'
        : softened
        ? 'Soften ${lead.moId} toward $targetStatus review while shadow-mode validation drift eases • ${lead.title} • x$repeatedShadowCount'
        : decisionStatus == 'rejected'
        ? postureSignal == _ShadowPostureSignal.surge
              ? 'Reopen ${lead.moId} toward $targetStatus review after shadow posture surged at the lead site • ${lead.title}${_repeatSuffix(repeatedShadowCount)}'
              : postureSignal == _ShadowPostureSignal.elevated
              ? 'Reopen ${lead.moId} toward $targetStatus review after shadow posture stayed elevated at the lead site • ${lead.title}${_repeatSuffix(repeatedShadowCount)}'
              : 'Reopen ${lead.moId} toward $targetStatus review after repeated shadow pressure • ${lead.title}${_repeatSuffix(repeatedShadowCount)}'
        : 'Promote ${lead.moId} toward $targetStatus review • ${lead.title}${_repeatSuffix(repeatedShadowCount)}';
    return MoPromotionGuidance(
      moId: lead.moId,
      title: lead.title,
      currentValidationStatus: currentStatus,
      targetValidationStatus: targetStatus,
      confidenceBias: confidenceBias,
      trendBias: trendBias,
      urgencyBias: urgencyBias,
      validationDriftSummary: driftSummary,
      summary: summary,
    );
  }

  _ShadowValidationDriftSignal _driftSignalFor(String summary) {
    final normalized = summary.trim().toLowerCase();
    if (normalized.contains('drift validated rising') ||
        normalized.contains('drift production rising')) {
      return _ShadowValidationDriftSignal.validatedRising;
    }
    if (normalized.contains('drift shadow mode easing') ||
        normalized.contains('drift candidate easing')) {
      return _ShadowValidationDriftSignal.shadowModeEasing;
    }
    return _ShadowValidationDriftSignal.none;
  }

  String _trendBias(double value) {
    final fixed = value.toStringAsFixed(2);
    return value >= 0 ? '+$fixed' : fixed;
  }

  String _targetStatusFor(String currentStatus) {
    return switch (currentStatus.trim()) {
      'candidate' => 'shadowMode',
      'canonicalized' => 'shadowMode',
      'shadowMode' => 'validated',
      'validated' => 'validated',
      _ => '',
    };
  }

  _ShadowPostureSignal _postureSignalFor({
    required int strengthScore,
    required String biasSummary,
  }) {
    final normalized = biasSummary.trim().toUpperCase();
    if (strengthScore >= 75 || normalized.contains('POSTURE SURGE')) {
      return _ShadowPostureSignal.surge;
    }
    if (strengthScore >= 65 || normalized.contains('POSTURE ELEVATED')) {
      return _ShadowPostureSignal.elevated;
    }
    return _ShadowPostureSignal.none;
  }

  String _repeatSuffix(int repeatedShadowCount) {
    return repeatedShadowCount > 0 ? ' • x$repeatedShadowCount' : '';
  }
}

enum _ShadowValidationDriftSignal { none, validatedRising, shadowModeEasing }

enum _ShadowPostureSignal { none, elevated, surge }
