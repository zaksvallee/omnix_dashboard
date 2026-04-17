import 'zara_action.dart';

enum ZaraScenarioKind {
  alarmTriage,
  dispatchOpportunity,
  guardCheck,
  intelSurface,
  clientCommsRequest,
}

enum ZaraScenarioUrgency { ambient, attention, critical }

enum ZaraScenarioLifecycleState {
  proposing,
  awaitingController,
  executing,
  complete,
  dismissed,
}

final class ZaraScenarioId {
  final String value;

  const ZaraScenarioId(this.value);

  factory ZaraScenarioId.generate([String prefix = 'zara-scenario']) {
    return ZaraScenarioId(
      '$prefix-${DateTime.now().toUtc().microsecondsSinceEpoch}',
    );
  }

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) {
    return other is ZaraScenarioId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

class ZaraScenario {
  final ZaraScenarioId id;
  final ZaraScenarioKind kind;
  final DateTime createdAt;
  final List<String> originEventIds;
  final String summary;
  final List<ZaraAction> proposedActions;
  final String relatedSiteId;
  final List<String> relatedGuardIds;
  final List<String> relatedDispatchIds;
  final ZaraScenarioUrgency urgency;
  final ZaraScenarioLifecycleState lifecycleState;
  final String clarificationRequest;
  final bool isParsingControllerInput;

  const ZaraScenario({
    required this.id,
    required this.kind,
    required this.createdAt,
    required this.originEventIds,
    required this.summary,
    required this.proposedActions,
    required this.relatedSiteId,
    this.relatedGuardIds = const <String>[],
    this.relatedDispatchIds = const <String>[],
    this.urgency = ZaraScenarioUrgency.ambient,
    this.lifecycleState = ZaraScenarioLifecycleState.proposing,
    this.clarificationRequest = '',
    this.isParsingControllerInput = false,
  });

  ZaraScenario copyWith({
    ZaraScenarioId? id,
    ZaraScenarioKind? kind,
    DateTime? createdAt,
    List<String>? originEventIds,
    String? summary,
    List<ZaraAction>? proposedActions,
    String? relatedSiteId,
    List<String>? relatedGuardIds,
    List<String>? relatedDispatchIds,
    ZaraScenarioUrgency? urgency,
    ZaraScenarioLifecycleState? lifecycleState,
    String? clarificationRequest,
    bool? isParsingControllerInput,
  }) {
    return ZaraScenario(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      createdAt: createdAt ?? this.createdAt,
      originEventIds: originEventIds ?? List<String>.from(this.originEventIds),
      summary: summary ?? this.summary,
      proposedActions:
          proposedActions ?? List<ZaraAction>.from(this.proposedActions),
      relatedSiteId: relatedSiteId ?? this.relatedSiteId,
      relatedGuardIds:
          relatedGuardIds ?? List<String>.from(this.relatedGuardIds),
      relatedDispatchIds:
          relatedDispatchIds ?? List<String>.from(this.relatedDispatchIds),
      urgency: urgency ?? this.urgency,
      lifecycleState: lifecycleState ?? this.lifecycleState,
      clarificationRequest: clarificationRequest ?? this.clarificationRequest,
      isParsingControllerInput:
          isParsingControllerInput ?? this.isParsingControllerInput,
    );
  }
}
