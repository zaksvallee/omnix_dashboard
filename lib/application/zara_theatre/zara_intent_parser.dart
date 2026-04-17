import 'dart:convert';

import '../ai/ollama_service.dart';
import '../onyx_agent_cloud_boost_service.dart';
import 'zara_action.dart';
import 'zara_scenario.dart';

enum ZaraActionSelectionModifier { approve, modify, reject, unclear }

class ZaraActionSelection {
  final ZaraActionId? actionId;
  final ZaraActionSelectionModifier modifier;
  final String draftEdits;
  final String clarificationRequest;

  const ZaraActionSelection({
    required this.actionId,
    required this.modifier,
    this.draftEdits = '',
    this.clarificationRequest = '',
  });

  factory ZaraActionSelection.unclear(String request) {
    return ZaraActionSelection(
      actionId: null,
      modifier: ZaraActionSelectionModifier.unclear,
      clarificationRequest: request,
    );
  }
}

class ZaraIntentParser {
  static const String _defaultLocalModel = 'mistral:7b-instruct-q5_K_M';

  final OllamaService ollamaService;
  final OnyxAgentCloudBoostService cloudBoostService;
  final String localModel;

  const ZaraIntentParser({
    this.ollamaService = const UnconfiguredOllamaService(),
    this.cloudBoostService = const UnconfiguredOnyxAgentCloudBoostService(),
    this.localModel = _defaultLocalModel,
  });

  Future<List<ZaraActionSelection>> parse(
    String controllerText,
    ZaraScenario scenario,
  ) async {
    final trimmed = controllerText.trim();
    if (trimmed.isEmpty) {
      return <ZaraActionSelection>[
        ZaraActionSelection.unclear(
          'Tell Zara which action to confirm, modify, or cancel.',
        ),
      ];
    }

    final fromOllama = await _parseWithOllama(trimmed, scenario);
    if (fromOllama.isNotEmpty) {
      return fromOllama;
    }

    final fromCloud = await _parseWithCloud(trimmed, scenario);
    if (fromCloud.isNotEmpty) {
      return fromCloud;
    }

    return _heuristicSelections(trimmed, scenario);
  }

  Future<List<ZaraActionSelection>> _parseWithOllama(
    String controllerText,
    ZaraScenario scenario,
  ) async {
    if (!ollamaService.isConfigured) {
      return const <ZaraActionSelection>[];
    }
    final decoded = await ollamaService.generateJson(
      systemPrompt: _systemPrompt,
      userPrompt: _userPrompt(controllerText, scenario),
      model: localModel,
    );
    return _selectionsFromDecoded(decoded, scenario);
  }

  Future<List<ZaraActionSelection>> _parseWithCloud(
    String controllerText,
    ZaraScenario scenario,
  ) async {
    if (!cloudBoostService.isConfigured) {
      return const <ZaraActionSelection>[];
    }
    final response = await cloudBoostService.boost(
      prompt: _userPrompt(controllerText, scenario),
      scope: OnyxAgentCloudScope(
        clientId: '',
        siteId: scenario.relatedSiteId,
        incidentReference: scenario.relatedDispatchIds.isEmpty
            ? ''
            : scenario.relatedDispatchIds.first,
        sourceRouteLabel: 'Zara Theatre',
      ),
      intent: OnyxAgentCloudIntent.dispatch,
      contextSummary: scenario.summary,
    );
    final rawText = response?.text.trim() ?? '';
    if (rawText.isEmpty) {
      return const <ZaraActionSelection>[];
    }
    final decoded = _extractJsonMap(rawText);
    return _selectionsFromDecoded(decoded, scenario);
  }

  List<ZaraActionSelection> _selectionsFromDecoded(
    Map<String, Object?>? decoded,
    ZaraScenario scenario,
  ) {
    if (decoded == null) {
      return const <ZaraActionSelection>[];
    }
    final clarification = (decoded['clarification'] ?? '').toString().trim();
    final rawSelections = decoded['selections'];
    if (rawSelections is! List) {
      if (clarification.isEmpty) {
        return const <ZaraActionSelection>[];
      }
      return <ZaraActionSelection>[ZaraActionSelection.unclear(clarification)];
    }
    if (rawSelections.isEmpty && clarification.isNotEmpty) {
      return <ZaraActionSelection>[ZaraActionSelection.unclear(clarification)];
    }
    final byId = <String, ZaraAction>{
      for (final action in scenario.proposedActions) action.id.value: action,
    };
    final selections = <ZaraActionSelection>[];
    for (final item in rawSelections) {
      if (item is! Map) {
        continue;
      }
      final rawActionId = (item['action_id'] ?? '').toString().trim();
      final modifier = _modifierFromString((item['modifier'] ?? '').toString());
      final edits = (item['draft_edits'] ?? '').toString().trim();
      final clarification = (item['clarification'] ?? '').toString().trim();
      if (modifier == ZaraActionSelectionModifier.unclear) {
        selections.add(ZaraActionSelection.unclear(clarification));
        continue;
      }
      if (rawActionId.isEmpty || !byId.containsKey(rawActionId)) {
        continue;
      }
      selections.add(
        ZaraActionSelection(
          actionId: ZaraActionId(rawActionId),
          modifier: modifier,
          draftEdits: edits,
          clarificationRequest: clarification,
        ),
      );
    }
    if (selections.isEmpty && clarification.isNotEmpty) {
      return <ZaraActionSelection>[ZaraActionSelection.unclear(clarification)];
    }
    return selections;
  }

  List<ZaraActionSelection> _heuristicSelections(
    String controllerText,
    ZaraScenario scenario,
  ) {
    final normalized = controllerText.toLowerCase();
    final approveAll = RegExp(
      r'\b(yes|confirm|go ahead|do it|proceed|send it|make it happen)\b',
    ).hasMatch(normalized);
    final rejectAll = RegExp(
      "\\b(no|cancel|stop|hold off|do not|don't)\\b",
    ).hasMatch(normalized);

    final selections = <ZaraActionSelection>[];
    for (final action in scenario.proposedActions) {
      final keywords = _keywordsForAction(action);
      final matched =
          keywords.any(normalized.contains) ||
          normalized.contains(action.label.toLowerCase());
      if (!matched && !approveAll && !rejectAll) {
        continue;
      }
      final modifier = _modifierForActionText(
        normalized: normalized,
        action: action,
        approveAll: approveAll,
        rejectAll: rejectAll,
      );
      if (modifier == ZaraActionSelectionModifier.unclear) {
        continue;
      }
      selections.add(
        ZaraActionSelection(
          actionId: action.id,
          modifier: modifier,
          draftEdits: modifier == ZaraActionSelectionModifier.modify
              ? controllerText.trim()
              : '',
        ),
      );
    }
    if (selections.isNotEmpty) {
      return selections;
    }
    return <ZaraActionSelection>[
      ZaraActionSelection.unclear(
        'I need a clearer instruction. For example: "send the client message and stand down dispatch."',
      ),
    ];
  }

  ZaraActionSelectionModifier _modifierForActionText({
    required String normalized,
    required ZaraAction action,
    required bool approveAll,
    required bool rejectAll,
  }) {
    final label = action.label.toLowerCase();
    final hasReject = RegExp(
      "\\b(cancel|reject|don't|do not|skip|hold)\\b",
    ).hasMatch(normalized);
    final hasModify = RegExp(
      r'\b(edit|change|update|revise|instead|say|word)\b',
    ).hasMatch(normalized);
    final actionMatched =
        _keywordsForAction(action).any(normalized.contains) ||
        normalized.contains(label);
    if ((actionMatched && hasReject) || rejectAll) {
      return ZaraActionSelectionModifier.reject;
    }
    if (action.kind == ZaraActionKind.draftClientMessage &&
        (hasModify || normalized.contains('message'))) {
      return hasModify
          ? ZaraActionSelectionModifier.modify
          : ZaraActionSelectionModifier.approve;
    }
    if (actionMatched || approveAll) {
      return ZaraActionSelectionModifier.approve;
    }
    return ZaraActionSelectionModifier.unclear;
  }

  List<String> _keywordsForAction(ZaraAction action) {
    return switch (action.kind) {
      ZaraActionKind.checkFootage => <String>[
        'footage',
        'camera',
        'cctv',
        'video',
      ],
      ZaraActionKind.checkWeather => <String>['weather', 'wind', 'storm'],
      ZaraActionKind.draftClientMessage => <String>[
        'message',
        'client',
        'notify',
        'telegram',
        'draft',
      ],
      ZaraActionKind.dispatchReaction => <String>[
        'dispatch',
        'reaction',
        'send unit',
        'send response',
      ],
      ZaraActionKind.standDownDispatch => <String>[
        'stand down',
        'cancel dispatch',
        'hold response',
        'no dispatch',
      ],
      ZaraActionKind.logOB => <String>['ob', 'occurrence book', 'log'],
      ZaraActionKind.issueGuardWarning => <String>[
        'warn guard',
        'guard warning',
      ],
      ZaraActionKind.escalateSupervisor => <String>['supervisor', 'escalate'],
      ZaraActionKind.continueMonitoring => <String>[
        'monitor',
        'watch',
        'keep watching',
        'continue',
      ],
    };
  }

  ZaraActionSelectionModifier _modifierFromString(String raw) {
    return switch (raw.trim().toLowerCase()) {
      'approve' => ZaraActionSelectionModifier.approve,
      'modify' => ZaraActionSelectionModifier.modify,
      'reject' => ZaraActionSelectionModifier.reject,
      _ => ZaraActionSelectionModifier.unclear,
    };
  }

  Map<String, Object?>? _extractJsonMap(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) {
      return null;
    }
    final snippet = raw.substring(start, end + 1);
    try {
      return _decodeJson(snippet);
    } catch (_) {
      return null;
    }
  }

  Map<String, Object?> _decodeJson(String raw) {
    final decoded = raw.trim().isEmpty
        ? const <Object?, Object?>{}
        : _jsonDecode(raw);
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  Map<Object?, Object?> _jsonDecode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<Object?, Object?>) {
      throw const FormatException('Expected a JSON object.');
    }
    return decoded;
  }

  String _userPrompt(String controllerText, ZaraScenario scenario) {
    final actions = scenario.proposedActions
        .map((action) => '- ${action.id.value}: ${action.label}')
        .join('\n');
    return 'Scenario summary:\n${scenario.summary}\n\n'
        'Proposed actions:\n$actions\n\n'
        'Controller response:\n$controllerText';
  }

  static const String _systemPrompt =
      'You extract controller intent for Zara Theatre.\n'
      'Return only JSON with this schema:\n'
      '{'
      '"selections":[{"action_id":"...", "modifier":"approve|modify|reject", "draft_edits":"...", "clarification":"..."}],'
      '"clarification":"..."'
      '}\n'
      'Rules:\n'
      '- Never return prose outside the JSON object.\n'
      '- Use action_id values exactly as provided.\n'
      '- If the instruction is unclear, return selections as an empty array and set clarification.\n'
      '- draft_edits must only be populated when modifier is modify.';
}
