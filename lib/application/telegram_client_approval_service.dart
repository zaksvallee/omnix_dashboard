import '../domain/events/intelligence_received.dart';
import 'intelligence_event_object_semantics.dart';
import 'monitoring_watch_scene_assessment_service.dart';

enum TelegramClientApprovalDecision { approve, review, escalate }

enum TelegramClientAllowanceDecision { allowOnce, allowAlways }

extension TelegramClientApprovalDecisionX on TelegramClientApprovalDecision {
  String get label {
    return switch (this) {
      TelegramClientApprovalDecision.approve => 'APPROVE',
      TelegramClientApprovalDecision.review => 'REVIEW',
      TelegramClientApprovalDecision.escalate => 'ESCALATE',
    };
  }
}

extension TelegramClientAllowanceDecisionX on TelegramClientAllowanceDecision {
  String get label {
    return switch (this) {
      TelegramClientAllowanceDecision.allowOnce => 'ALLOW ONCE',
      TelegramClientAllowanceDecision.allowAlways => 'ALWAYS ALLOW',
    };
  }
}

class TelegramClientApprovalService {
  static const verificationMessageKeyPrefix = 'tg-watch-verify';
  static const allowanceMessageKeyPrefix = 'tg-watch-allow';

  const TelegramClientApprovalService();

  bool requiresOutboundApproval({
    required String source,
    required String audience,
    bool controllerAuthored = false,
    bool isBulkOrBroadcast = false,
  }) {
    final normalizedSource = source.trim().toLowerCase();
    if (normalizedSource == 'ai' || normalizedSource == 'system') {
      return false;
    }
    if (isBulkOrBroadcast) {
      return true;
    }
    return controllerAuthored && audience.trim().toLowerCase() == 'client';
  }

  bool requiresClientApproval({
    required IntelligenceReceived event,
    required MonitoringWatchSceneAssessment assessment,
  }) {
    if (!assessment.shouldNotifyClient || assessment.shouldEscalate) {
      return false;
    }
    final isHumanLike = _isHumanLikeSignal(
      event: event,
      assessment: assessment,
    );
    if (!isHumanLike) {
      return false;
    }
    if (assessment.identityAllowedSignal || assessment.identityRiskSignal) {
      return false;
    }
    return true;
  }

  bool isVerificationMessageKey(String messageKey) {
    return messageKey.trim().startsWith('$verificationMessageKeyPrefix-');
  }

  bool isAllowanceMessageKey(String messageKey) {
    return messageKey.trim().startsWith('$allowanceMessageKeyPrefix-');
  }

  bool canOfferPersistentAllowance({
    required IntelligenceReceived event,
    required MonitoringWatchSceneAssessment assessment,
  }) {
    if (!requiresClientApproval(event: event, assessment: assessment)) {
      return false;
    }
    return (event.faceMatchId ?? '').trim().isNotEmpty ||
        (event.plateNumber ?? '').trim().isNotEmpty;
  }

  bool _isHumanLikeSignal({
    required IntelligenceReceived event,
    required MonitoringWatchSceneAssessment assessment,
  }) {
    final assessmentObjectLabel = assessment.objectLabel.trim().toLowerCase();
    if (assessmentObjectLabel == 'person' ||
        assessmentObjectLabel == 'human' ||
        assessmentObjectLabel == 'intruder') {
      return true;
    }
    final eventObjectLabel = resolveIdentityBackedObjectLabel(
      event: event,
      directObjectLabel: (event.objectLabel ?? '').trim(),
    ).toLowerCase();
    if (eventObjectLabel == 'person' ||
        eventObjectLabel == 'human' ||
        eventObjectLabel == 'intruder') {
      return true;
    }
    return (event.faceMatchId ?? '').trim().isNotEmpty ||
        (assessment.faceMatchId ?? '').trim().isNotEmpty;
  }

  Map<String, Object?> replyKeyboardMarkup() {
    return const <String, Object?>{
      'keyboard': <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': 'APPROVE'},
          <String, String>{'text': 'REVIEW'},
          <String, String>{'text': 'ESCALATE'},
        ],
      ],
      'resize_keyboard': true,
      'one_time_keyboard': true,
      'is_persistent': false,
      'input_field_placeholder': 'Reply APPROVE, REVIEW, or ESCALATE',
    };
  }

  Map<String, Object?> removeKeyboardMarkup() {
    return const <String, Object?>{'remove_keyboard': true};
  }

  Map<String, Object?> allowanceReplyKeyboardMarkup() {
    return const <String, Object?>{
      'keyboard': <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': 'ALLOW ONCE'},
          <String, String>{'text': 'ALWAYS ALLOW'},
        ],
      ],
      'resize_keyboard': true,
      'one_time_keyboard': true,
      'is_persistent': false,
      'input_field_placeholder': 'Reply ALLOW ONCE or ALWAYS ALLOW',
    };
  }

  TelegramClientApprovalDecision? parseDecisionText(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized == 'approve' ||
        normalized == 'approved' ||
        normalized == 'yes approve' ||
        normalized == 'expected' ||
        normalized == 'authorised' ||
        normalized == 'authorized' ||
        normalized == 'known visitor') {
      return TelegramClientApprovalDecision.approve;
    }
    if (normalized == 'review' ||
        normalized == 'flag for review' ||
        normalized == 'flag review' ||
        normalized == 'manual review' ||
        normalized == 'unsure' ||
        normalized == 'not sure') {
      return TelegramClientApprovalDecision.review;
    }
    if (normalized == 'escalate' ||
        normalized == 'unapprove' ||
        normalized == 'not approved' ||
        normalized == 'not approve' ||
        normalized == 'intruder' ||
        normalized == 'suspicious' ||
        normalized == 'deny') {
      return TelegramClientApprovalDecision.escalate;
    }
    return null;
  }

  TelegramClientAllowanceDecision? parseAllowanceDecisionText(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized == 'allow once' ||
        normalized == 'once' ||
        normalized == 'allow this once' ||
        normalized == 'one time') {
      return TelegramClientAllowanceDecision.allowOnce;
    }
    if (normalized == 'always allow' ||
        normalized == 'allow always' ||
        normalized == 'always' ||
        normalized == 'remember visitor') {
      return TelegramClientAllowanceDecision.allowAlways;
    }
    return null;
  }

  String clientConfirmationText(TelegramClientApprovalDecision decision) {
    return switch (decision) {
      TelegramClientApprovalDecision.approve =>
        'ONYX received your approval. Control has logged this person as expected and will continue monitoring.',
      TelegramClientApprovalDecision.review =>
        'ONYX received your review request. Control will keep the event open for manual review.',
      TelegramClientApprovalDecision.escalate =>
        'ONYX received your escalation request. Control has been notified for urgent review.',
    };
  }

  String clientAllowanceConfirmationText(
    TelegramClientAllowanceDecision decision,
  ) {
    return switch (decision) {
      TelegramClientAllowanceDecision.allowOnce =>
        'ONYX logged this as a one-time approved visitor. We will ask again if the same person appears later.',
      TelegramClientAllowanceDecision.allowAlways =>
        'ONYX saved this visitor to the site allowlist and will treat future matches as expected.',
    };
  }

  String adminDecisionSummary({
    required TelegramClientApprovalDecision decision,
    required String clientId,
    required String siteId,
    required String messageKey,
  }) {
    final action = switch (decision) {
      TelegramClientApprovalDecision.approve => 'approved',
      TelegramClientApprovalDecision.review => 'flagged for review',
      TelegramClientApprovalDecision.escalate => 'escalated',
    };
    return 'ONYX client verification update\n'
        'scope=$clientId/$siteId\n'
        'message_key=$messageKey\n'
        'decision=$action';
  }

  String adminAllowanceDecisionSummary({
    required TelegramClientAllowanceDecision decision,
    required String clientId,
    required String siteId,
    required String messageKey,
  }) {
    final action = switch (decision) {
      TelegramClientAllowanceDecision.allowOnce => 'allow_once',
      TelegramClientAllowanceDecision.allowAlways => 'allow_always',
    };
    return 'ONYX client identity memory update\n'
        'scope=$clientId/$siteId\n'
        'message_key=$messageKey\n'
        'decision=$action';
  }
}
