enum ZaraActionKind {
  checkFootage,
  checkWeather,
  draftClientMessage,
  dispatchReaction,
  standDownDispatch,
  logOB,
  issueGuardWarning,
  escalateSupervisor,
  continueMonitoring,
}

enum ZaraActionState {
  proposed,
  awaitingConfirmation,
  autoExecuting,
  executing,
  completed,
  failed,
  rejected,
}

final class ZaraActionId {
  final String value;

  const ZaraActionId(this.value);

  factory ZaraActionId.generate([String prefix = 'zara-action']) {
    return ZaraActionId(
      '$prefix-${DateTime.now().toUtc().microsecondsSinceEpoch}',
    );
  }

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) {
    return other is ZaraActionId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

abstract class ZaraActionPayload {
  const ZaraActionPayload();

  Map<String, Object?> toJson();
}

class ZaraEmptyPayload extends ZaraActionPayload {
  const ZaraEmptyPayload();

  @override
  Map<String, Object?> toJson() => const <String, Object?>{};
}

class ZaraClientMessagePayload extends ZaraActionPayload {
  final String clientId;
  final String siteId;
  final String room;
  final String incidentReference;
  final String draftText;
  final String originalDraftText;

  const ZaraClientMessagePayload({
    required this.clientId,
    required this.siteId,
    required this.room,
    required this.incidentReference,
    required this.draftText,
    required this.originalDraftText,
  });

  ZaraClientMessagePayload copyWith({
    String? clientId,
    String? siteId,
    String? room,
    String? incidentReference,
    String? draftText,
    String? originalDraftText,
  }) {
    return ZaraClientMessagePayload(
      clientId: clientId ?? this.clientId,
      siteId: siteId ?? this.siteId,
      room: room ?? this.room,
      incidentReference: incidentReference ?? this.incidentReference,
      draftText: draftText ?? this.draftText,
      originalDraftText: originalDraftText ?? this.originalDraftText,
    );
  }

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'client_id': clientId,
      'site_id': siteId,
      'room': room,
      'incident_reference': incidentReference,
      'draft_text': draftText,
      'original_draft_text': originalDraftText,
    };
  }
}

class ZaraDispatchPayload extends ZaraActionPayload {
  final String clientId;
  final String regionId;
  final String siteId;
  final String dispatchId;
  final String note;

  const ZaraDispatchPayload({
    required this.clientId,
    required this.regionId,
    required this.siteId,
    required this.dispatchId,
    this.note = '',
  });

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'client_id': clientId,
      'region_id': regionId,
      'site_id': siteId,
      'dispatch_id': dispatchId,
      'note': note,
    };
  }
}

class ZaraMonitoringPayload extends ZaraActionPayload {
  final String siteId;
  final String detail;

  const ZaraMonitoringPayload({required this.siteId, required this.detail});

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{'site_id': siteId, 'detail': detail};
  }
}

class ZaraAction {
  final ZaraActionId id;
  final ZaraActionKind kind;
  final String label;
  final bool reversible;
  final bool confirmRequired;
  final ZaraActionPayload payload;
  final ZaraActionState state;
  final String resolutionSummary;
  final String pendingDraftEdits;

  const ZaraAction({
    required this.id,
    required this.kind,
    required this.label,
    required this.reversible,
    required this.confirmRequired,
    required this.payload,
    this.state = ZaraActionState.proposed,
    this.resolutionSummary = '',
    this.pendingDraftEdits = '',
  });

  bool get isAutoExecutable => reversible && !confirmRequired;

  ZaraAction copyWith({
    ZaraActionId? id,
    ZaraActionKind? kind,
    String? label,
    bool? reversible,
    bool? confirmRequired,
    ZaraActionPayload? payload,
    ZaraActionState? state,
    String? resolutionSummary,
    String? pendingDraftEdits,
  }) {
    return ZaraAction(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      label: label ?? this.label,
      reversible: reversible ?? this.reversible,
      confirmRequired: confirmRequired ?? this.confirmRequired,
      payload: payload ?? this.payload,
      state: state ?? this.state,
      resolutionSummary: resolutionSummary ?? this.resolutionSummary,
      pendingDraftEdits: pendingDraftEdits ?? this.pendingDraftEdits,
    );
  }
}
