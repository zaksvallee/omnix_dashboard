import '../domain/events/decision_created.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/execution_denied.dart';
import '../domain/events/incident_closed.dart';
import '../domain/events/partner_dispatch_status_declared.dart';
import '../domain/events/response_arrived.dart';

enum TelegramPartnerDispatchAction { accept, onSite, allClear, cancel }

extension TelegramPartnerDispatchActionX on TelegramPartnerDispatchAction {
  String get label {
    return switch (this) {
      TelegramPartnerDispatchAction.accept => 'ACCEPT',
      TelegramPartnerDispatchAction.onSite => 'ON SITE',
      TelegramPartnerDispatchAction.allClear => 'ALL CLEAR',
      TelegramPartnerDispatchAction.cancel => 'CANCEL',
    };
  }

  PartnerDispatchStatus get declaredStatus {
    return switch (this) {
      TelegramPartnerDispatchAction.accept => PartnerDispatchStatus.accepted,
      TelegramPartnerDispatchAction.onSite => PartnerDispatchStatus.onSite,
      TelegramPartnerDispatchAction.allClear => PartnerDispatchStatus.allClear,
      TelegramPartnerDispatchAction.cancel => PartnerDispatchStatus.cancelled,
    };
  }
}

class TelegramPartnerDispatchContext {
  final String messageKey;
  final String dispatchId;
  final String clientId;
  final String regionId;
  final String siteId;
  final String siteName;
  final String incidentSummary;
  final String dispatchDirective;
  final String welfareDirective;
  final String partnerLabel;
  final DateTime occurredAtUtc;

  const TelegramPartnerDispatchContext({
    required this.messageKey,
    required this.dispatchId,
    required this.clientId,
    required this.regionId,
    required this.siteId,
    required this.siteName,
    required this.incidentSummary,
    this.dispatchDirective = '',
    this.welfareDirective = '',
    required this.partnerLabel,
    required this.occurredAtUtc,
  });
}

class TelegramPartnerDispatchResolution {
  final TelegramPartnerDispatchAction action;
  final PartnerDispatchStatusDeclared event;
  final String clientStatusLabel;
  final String adminAuditSummary;

  const TelegramPartnerDispatchResolution({
    required this.action,
    required this.event,
    required this.clientStatusLabel,
    required this.adminAuditSummary,
  });
}

class TelegramPartnerDispatchService {
  static const dispatchMessageKeyPrefix = 'tg-partner-dispatch';

  const TelegramPartnerDispatchService();

  bool isDispatchMessageKey(String messageKey) {
    return messageKey.trim().startsWith('$dispatchMessageKeyPrefix-');
  }

  Map<String, Object?> replyKeyboardMarkup() {
    return const <String, Object?>{
      'keyboard': <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': 'ACCEPT'},
          <String, String>{'text': 'ON SITE'},
        ],
        <Map<String, String>>[
          <String, String>{'text': 'ALL CLEAR'},
          <String, String>{'text': 'CANCEL'},
        ],
      ],
      'resize_keyboard': true,
      'one_time_keyboard': false,
      'is_persistent': true,
      'input_field_placeholder': 'Reply ACCEPT, ON SITE, ALL CLEAR, or CANCEL',
    };
  }

  Map<String, Object?> removeKeyboardMarkup() {
    return const <String, Object?>{'remove_keyboard': true};
  }

  TelegramPartnerDispatchAction? parseActionText(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized == 'accept' ||
        normalized == 'accepted' ||
        normalized == 'ack' ||
        normalized == 'acknowledged' ||
        normalized == 'en route') {
      return TelegramPartnerDispatchAction.accept;
    }
    if (normalized == 'on site' ||
        normalized == 'onsite' ||
        normalized == 'arrived' ||
        normalized == 'on scene') {
      return TelegramPartnerDispatchAction.onSite;
    }
    if (normalized == 'all clear' ||
        normalized == 'clear' ||
        normalized == 'site clear' ||
        normalized == 'client safe') {
      return TelegramPartnerDispatchAction.allClear;
    }
    if (normalized == 'cancel' ||
        normalized == 'cancelled' ||
        normalized == 'canceled' ||
        normalized == 'abort') {
      return TelegramPartnerDispatchAction.cancel;
    }
    return null;
  }

  String buildDispatchMessage(TelegramPartnerDispatchContext context) {
    final incidentSummary = context.incidentSummary.trim().isEmpty
        ? 'Monitoring escalation awaiting partner acknowledgement.'
        : context.incidentSummary.trim();
    final dispatchDirective = context.dispatchDirective.trim();
    final welfareDirective = context.welfareDirective.trim();
    return 'ONYX PARTNER DISPATCH\n'
        'incident=${context.dispatchId}\n'
        'site=${context.siteName}\n'
        'scope=${context.clientId}/${context.siteId}\n'
        'partner=${context.partnerLabel}\n'
        'message_key=${context.messageKey}\n'
        'occurred_at=${context.occurredAtUtc.toIso8601String()}\n'
        'summary=$incidentSummary\n'
        '${dispatchDirective.isEmpty ? '' : 'dispatch_directive=$dispatchDirective\n'}'
        '${welfareDirective.isEmpty ? '' : 'welfare_directive=$welfareDirective\n'}'
        'Reply with: ACCEPT, ON SITE, ALL CLEAR, or CANCEL.';
  }

  String partnerConfirmationText(TelegramPartnerDispatchAction action) {
    return switch (action) {
      TelegramPartnerDispatchAction.accept =>
        'ONYX logged your ACCEPT update. The incident remains open and is marked partner acknowledged.',
      TelegramPartnerDispatchAction.onSite =>
        'ONYX logged your ON SITE update. The incident is marked partner declared on site.',
      TelegramPartnerDispatchAction.allClear =>
        'ONYX logged your ALL CLEAR update. The incident can now move toward closeout.',
      TelegramPartnerDispatchAction.cancel =>
        'ONYX logged your CANCEL update. Control should review the incident immediately.',
    };
  }

  TelegramPartnerDispatchResolution? resolveReply({
    required TelegramPartnerDispatchAction action,
    required TelegramPartnerDispatchContext context,
    required String actorLabel,
    required DateTime occurredAtUtc,
    required List<DispatchEvent> events,
  }) {
    if (!_dispatchExists(context.dispatchId, events)) {
      return null;
    }
    if (_dispatchClosed(context.dispatchId, events)) {
      return null;
    }
    if (!_transitionAllowed(action, context.dispatchId, events)) {
      return null;
    }
    final event = PartnerDispatchStatusDeclared(
      eventId:
          'PARTNER-${action.name.toUpperCase()}-${context.dispatchId}-${occurredAtUtc.microsecondsSinceEpoch}',
      sequence: 0,
      version: 1,
      occurredAt: occurredAtUtc.toUtc(),
      dispatchId: context.dispatchId,
      clientId: context.clientId,
      regionId: context.regionId,
      siteId: context.siteId,
      partnerLabel: context.partnerLabel,
      actorLabel: actorLabel.trim(),
      status: action.declaredStatus,
      sourceChannel: 'telegram',
      sourceMessageKey: context.messageKey,
    );
    return TelegramPartnerDispatchResolution(
      action: action,
      event: event,
      clientStatusLabel: _clientStatusLabelFor(action),
      adminAuditSummary: _adminAuditSummary(
        action: action,
        context: context,
        actorLabel: actorLabel,
        occurredAtUtc: occurredAtUtc,
      ),
    );
  }

  bool _dispatchExists(String dispatchId, List<DispatchEvent> events) {
    return events.whereType<DecisionCreated>().any(
      (event) => event.dispatchId == dispatchId,
    );
  }

  bool _dispatchClosed(String dispatchId, List<DispatchEvent> events) {
    for (final event in events) {
      if (event is IncidentClosed && event.dispatchId == dispatchId) {
        return true;
      }
      if (event is ExecutionDenied && event.dispatchId == dispatchId) {
        return true;
      }
    }
    return false;
  }

  bool _transitionAllowed(
    TelegramPartnerDispatchAction action,
    String dispatchId,
    List<DispatchEvent> events,
  ) {
    final declaredStatuses = events
        .whereType<PartnerDispatchStatusDeclared>()
        .where((event) => event.dispatchId == dispatchId)
        .map((event) => event.status)
        .toSet();
    final alreadyAccepted = declaredStatuses.contains(
      PartnerDispatchStatus.accepted,
    );
    final alreadyOnSite = declaredStatuses.contains(
      PartnerDispatchStatus.onSite,
    );
    final alreadyAllClear = declaredStatuses.contains(
      PartnerDispatchStatus.allClear,
    );
    final alreadyCancelled = declaredStatuses.contains(
      PartnerDispatchStatus.cancelled,
    );
    final hasVerifiedArrival = events.whereType<ResponseArrived>().any(
      (event) => event.dispatchId == dispatchId,
    );

    if (alreadyAllClear || alreadyCancelled) {
      return false;
    }

    return switch (action) {
      TelegramPartnerDispatchAction.accept => !alreadyAccepted,
      TelegramPartnerDispatchAction.onSite =>
        !alreadyOnSite && (alreadyAccepted || hasVerifiedArrival),
      TelegramPartnerDispatchAction.allClear =>
        alreadyOnSite || hasVerifiedArrival,
      TelegramPartnerDispatchAction.cancel => !alreadyCancelled,
    };
  }

  String _clientStatusLabelFor(TelegramPartnerDispatchAction action) {
    return switch (action) {
      TelegramPartnerDispatchAction.accept => 'Partner Accepted',
      TelegramPartnerDispatchAction.onSite => 'Partner On Site',
      TelegramPartnerDispatchAction.allClear => 'Partner All Clear',
      TelegramPartnerDispatchAction.cancel => 'Partner Cancelled',
    };
  }

  String _adminAuditSummary({
    required TelegramPartnerDispatchAction action,
    required TelegramPartnerDispatchContext context,
    required String actorLabel,
    required DateTime occurredAtUtc,
  }) {
    return 'ONYX partner dispatch update\n'
        'incident=${context.dispatchId}\n'
        'scope=${context.clientId}/${context.siteId}\n'
        'partner=${context.partnerLabel}\n'
        'message_key=${context.messageKey}\n'
        'action=${action.label}\n'
        'actor=${actorLabel.trim()}\n'
        'occurred_at=${occurredAtUtc.toUtc().toIso8601String()}';
  }
}
