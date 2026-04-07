import 'monitoring_shift_notification_service.dart';

class TelegramAiLearnedReplyExample {
  final String text;
  final String operatorTag;
  final int approvalCount;
  final DateTime? lastApprovedAtUtc;
  final DateTime? lastUsedAtUtc;

  const TelegramAiLearnedReplyExample({
    required this.text,
    this.operatorTag = '',
    this.approvalCount = 1,
    this.lastApprovedAtUtc,
    this.lastUsedAtUtc,
  });

  TelegramAiLearnedReplyExample copyWith({
    String? text,
    String? operatorTag,
    int? approvalCount,
    DateTime? lastApprovedAtUtc,
    bool clearLastApprovedAtUtc = false,
    DateTime? lastUsedAtUtc,
    bool clearLastUsedAtUtc = false,
  }) {
    return TelegramAiLearnedReplyExample(
      text: text ?? this.text,
      operatorTag: operatorTag ?? this.operatorTag,
      approvalCount: approvalCount ?? this.approvalCount,
      lastApprovedAtUtc: clearLastApprovedAtUtc
          ? null
          : (lastApprovedAtUtc ?? this.lastApprovedAtUtc),
      lastUsedAtUtc: clearLastUsedAtUtc
          ? null
          : (lastUsedAtUtc ?? this.lastUsedAtUtc),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'text': text,
      if (operatorTag.trim().isNotEmpty) 'operator_tag': operatorTag.trim(),
      'approval_count': approvalCount,
      if (lastApprovedAtUtc != null)
        'last_approved_at_utc': lastApprovedAtUtc!.toIso8601String(),
      if (lastUsedAtUtc != null)
        'last_used_at_utc': lastUsedAtUtc!.toIso8601String(),
    };
  }

  static TelegramAiLearnedReplyExample? tryParse(Object? value) {
    if (value is String) {
      final normalized = value.trim();
      if (normalized.isEmpty) {
        return null;
      }
      return TelegramAiLearnedReplyExample(text: normalized);
    }
    if (value is! Map) {
      return null;
    }
    final text = (value['text'] ?? '').toString().trim();
    if (text.isEmpty) {
      return null;
    }
    final operatorTag = (value['operator_tag'] ?? '').toString().trim();
    final approvalCountRaw = int.tryParse(
      (value['approval_count'] ?? '').toString().trim(),
    );
    final lastApprovedAtUtc = DateTime.tryParse(
      (value['last_approved_at_utc'] ?? '').toString().trim(),
    )?.toUtc();
    final lastUsedAtUtc = DateTime.tryParse(
      (value['last_used_at_utc'] ?? '').toString().trim(),
    )?.toUtc();
    return TelegramAiLearnedReplyExample(
      text: text,
      operatorTag: operatorTag,
      approvalCount: approvalCountRaw == null || approvalCountRaw <= 0
          ? 1
          : approvalCountRaw,
      lastApprovedAtUtc: lastApprovedAtUtc,
      lastUsedAtUtc: lastUsedAtUtc,
    );
  }
}

enum _TelegramAiStarterTone { standard, residential, enterprise }

enum _TelegramAiStarterIntent {
  general,
  worried,
  access,
  eta,
  movement,
  visual,
  thanks,
  status,
}

enum _TelegramAiStarterLaneStage { active, responderOnSite, closure }

enum _TelegramAiPreferredExampleSource { approved, recentApproved, starter }

class _TelegramAiPreferredExampleCandidate {
  final TelegramAiLearnedReplyExample? learnedExample;
  final String text;
  final _TelegramAiPreferredExampleSource source;
  final int index;

  const _TelegramAiPreferredExampleCandidate({
    this.learnedExample,
    required this.text,
    required this.source,
    required this.index,
  });
}

List<String> telegramAiPreferredReplyExamplesForScope({
  required String clientId,
  required String siteId,
  required MonitoringSiteProfile siteProfile,
  required String messageText,
  List<String> recentConversationTurns = const <String>[],
  List<TelegramAiLearnedReplyExample> approvedRewriteExamples =
      const <TelegramAiLearnedReplyExample>[],
  List<String> recentApprovedReplyExamples = const <String>[],
}) {
  final normalizedMessage = messageText.trim().toLowerCase();
  final laneStage = _starterLaneStageFor(
    normalizedMessage: normalizedMessage,
    recentConversationTurns: recentConversationTurns,
  );
  final intent = _starterIntentFor(normalizedMessage);
  final tone = _starterToneForScope(
    clientId: clientId,
    siteId: siteId,
    siteProfile: siteProfile,
  );
  final starterExamples = telegramAiStarterReplyExamplesForScope(
    clientId: clientId,
    siteId: siteId,
    siteProfile: siteProfile,
    messageText: messageText,
    recentConversationTurns: recentConversationTurns,
  );
  final starterBudget = _starterExampleBudgetFor(
    approvedRewriteExamples.length,
  );
  final candidates = <_TelegramAiPreferredExampleCandidate>[
    ...approvedRewriteExamples.asMap().entries.map(
      (entry) => _TelegramAiPreferredExampleCandidate(
        learnedExample: entry.value,
        text: entry.value.text,
        source: _TelegramAiPreferredExampleSource.approved,
        index: entry.key,
      ),
    ),
    ...starterExamples
        .take(starterBudget)
        .toList(growable: false)
        .asMap()
        .entries
        .map(
          (entry) => _TelegramAiPreferredExampleCandidate(
            text: entry.value,
            source: _TelegramAiPreferredExampleSource.starter,
            index: entry.key,
          ),
        ),
    ...recentApprovedReplyExamples.asMap().entries.map(
      (entry) => _TelegramAiPreferredExampleCandidate(
        text: entry.value,
        source: _TelegramAiPreferredExampleSource.recentApproved,
        index: entry.key,
      ),
    ),
  ];
  final deduped = <String, _TelegramAiPreferredExampleCandidate>{};
  for (final candidate in candidates) {
    final normalized = _singleLine(candidate.text, maxLength: 140).trim();
    if (normalized.isEmpty) {
      continue;
    }
    deduped.putIfAbsent(
      normalized,
      () => _TelegramAiPreferredExampleCandidate(
        learnedExample: candidate.learnedExample,
        text: normalized,
        source: candidate.source,
        index: candidate.index,
      ),
    );
  }
  final ranked = deduped.values.toList(growable: false)
    ..sort((left, right) {
      final leftScore = _preferredExampleScore(
        candidate: left,
        laneStage: laneStage,
        intent: intent,
        tone: tone,
      );
      final rightScore = _preferredExampleScore(
        candidate: right,
        laneStage: laneStage,
        intent: intent,
        tone: tone,
      );
      if (leftScore != rightScore) {
        return rightScore.compareTo(leftScore);
      }
      final sourceRank = _preferredExampleSourceRank(
        left.source,
      ).compareTo(_preferredExampleSourceRank(right.source));
      if (sourceRank != 0) {
        return sourceRank;
      }
      return left.index.compareTo(right.index);
    });
  return ranked
      .take(4)
      .map((candidate) => candidate.text)
      .toList(growable: false);
}

List<String> telegramAiStarterReplyExamplesForScope({
  required String clientId,
  required String siteId,
  required MonitoringSiteProfile siteProfile,
  required String messageText,
  List<String> recentConversationTurns = const <String>[],
}) {
  final siteReference = _siteReferenceFor(
    siteId: siteId,
    siteProfile: siteProfile,
  );
  final tone = _starterToneForScope(
    clientId: clientId,
    siteId: siteId,
    siteProfile: siteProfile,
  );
  final normalizedMessage = messageText.trim().toLowerCase();
  final laneStage = _starterLaneStageFor(
    normalizedMessage: normalizedMessage,
    recentConversationTurns: recentConversationTurns,
  );
  final intent = _starterIntentFor(normalizedMessage);
  switch (laneStage) {
    case _TelegramAiStarterLaneStage.closure:
      return _closureExamplesFor(
        siteReference: siteReference,
        tone: tone,
        intent: intent,
      );
    case _TelegramAiStarterLaneStage.responderOnSite:
      return _onSiteExamplesFor(
        siteReference: siteReference,
        tone: tone,
        intent: intent,
      );
    case _TelegramAiStarterLaneStage.active:
      return _activeExamplesFor(
        siteReference: siteReference,
        tone: tone,
        intent: intent,
      );
  }
}

List<String> _activeExamplesFor({
  required String siteReference,
  required _TelegramAiStarterTone tone,
  required _TelegramAiStarterIntent intent,
}) {
  switch (intent) {
    case _TelegramAiStarterIntent.worried:
      return switch (tone) {
        _TelegramAiStarterTone.residential => <String>[
          'You are not alone. We are checking $siteReference now. I will update you here with the next confirmed step.',
          'We are checking $siteReference now and staying close on this. I will update you here with the next confirmed step.',
        ],
        _TelegramAiStarterTone.enterprise => <String>[
          'We are checking $siteReference now and taking this seriously. I will update you here with the next confirmed step.',
          'This is being treated seriously at $siteReference. I will update you here with the next confirmed step.',
        ],
        _ => <String>[
          'We are checking $siteReference now. I will update you here with the next confirmed step.',
          'We are actively checking $siteReference now. I will update you here with the next confirmed step.',
        ],
      };
    case _TelegramAiStarterIntent.access:
      return <String>[
        'We are checking access at $siteReference now. I will update you here with the next confirmed step.',
        'We are checking what is blocked at $siteReference now. I will update you here with the next confirmed step.',
      ];
    case _TelegramAiStarterIntent.eta:
      return <String>[
        'We are checking the ETA for $siteReference now. I will update you here when the ETA is confirmed.',
        'We are checking timing for $siteReference now. I will update you here when the ETA is confirmed.',
      ];
    case _TelegramAiStarterIntent.movement:
      return <String>[
        'We are checking who is moving to $siteReference now. I will update you here with the next movement update.',
        'We are checking movement to $siteReference now. I will update you here with the next movement update.',
      ];
    case _TelegramAiStarterIntent.visual:
      return switch (tone) {
        _TelegramAiStarterTone.residential => <String>[
          'I do not have live camera confirmation for $siteReference yet. I will update you here with the next confirmed step.',
          'We are checking the latest position at $siteReference now. I will update you here with the next confirmed step.',
        ],
        _ => <String>[
          'I do not have live camera confirmation for $siteReference right now. I will update you here with the next confirmed step.',
          'We are checking the latest position at $siteReference now. I will update you here with the next confirmed step.',
        ],
      };
    case _TelegramAiStarterIntent.thanks:
      return switch (tone) {
        _TelegramAiStarterTone.residential => <String>[
          'You are welcome. We are still checking $siteReference and I will update you here if anything changes.',
          'You are welcome. We are still watching $siteReference and I will update you here if anything changes.',
        ],
        _TelegramAiStarterTone.enterprise => <String>[
          'You are welcome. We are still checking $siteReference and will update you here if anything changes.',
          'You are welcome. We are still tracking $siteReference and will update you here if anything changes.',
        ],
        _ => <String>[
          'You are welcome. We are still checking $siteReference and will update you here if anything changes.',
          'You are welcome. We are still watching $siteReference and will update you here if anything changes.',
        ],
      };
    case _TelegramAiStarterIntent.status:
    case _TelegramAiStarterIntent.general:
      return switch (tone) {
        _TelegramAiStarterTone.residential => <String>[
          'We are checking $siteReference now and staying close on this. I will update you here with the next confirmed step.',
          'We are checking $siteReference now. I will update you here with the next confirmed step.',
        ],
        _TelegramAiStarterTone.enterprise => <String>[
          'We are checking $siteReference now and taking this seriously. I will update you here with the next confirmed step.',
          'We are checking $siteReference now. I will update you here with the next confirmed step.',
        ],
        _ => <String>[
          'We are checking $siteReference now. I will update you here with the next confirmed step.',
          'We are actively checking $siteReference now. I will update you here with the next confirmed step.',
        ],
      };
  }
}

List<String> _onSiteExamplesFor({
  required String siteReference,
  required _TelegramAiStarterTone tone,
  required _TelegramAiStarterIntent intent,
}) {
  switch (intent) {
    case _TelegramAiStarterIntent.visual:
      return <String>[
        'Security is already on site at $siteReference and we are checking cameras now. I will update you here with the next confirmed camera check.',
        'Security is on site at $siteReference now. I will update you here with the next confirmed camera check.',
      ];
    case _TelegramAiStarterIntent.access:
      return <String>[
        'Security is already on site at $siteReference and checking access now. I will update you here with the next on-site step.',
        'Security is on site at $siteReference now. I will update you here with the next on-site step.',
      ];
    case _TelegramAiStarterIntent.worried:
    case _TelegramAiStarterIntent.status:
    case _TelegramAiStarterIntent.general:
    case _TelegramAiStarterIntent.eta:
    case _TelegramAiStarterIntent.movement:
    case _TelegramAiStarterIntent.thanks:
      return switch (tone) {
        _TelegramAiStarterTone.residential => <String>[
          'Security is already on site at $siteReference now. I will update you here with the next on-site step.',
          'We have security on site at $siteReference now. I will update you here with the next on-site step.',
        ],
        _ => <String>[
          'Security is already on site at $siteReference now. I will update you here with the next on-site step.',
          'Security is on site at $siteReference now. I will update you here with the next on-site step.',
        ],
      };
  }
}

List<String> _closureExamplesFor({
  required String siteReference,
  required _TelegramAiStarterTone tone,
  required _TelegramAiStarterIntent intent,
}) {
  switch (intent) {
    case _TelegramAiStarterIntent.access:
      return switch (tone) {
        _TelegramAiStarterTone.enterprise => <String>[
          '$siteReference is secure right now. If access is still affected, tell me what is blocked and we will reopen the incident straight away.',
          'Access is stable at $siteReference right now. If anything is still blocked, message here immediately and we will reopen the incident.',
        ],
        _ => <String>[
          '$siteReference is secure right now. If access is still affected, tell me what is blocked and we will reopen this straight away.',
          'Access is stable at $siteReference right now. If anything is still blocked, message here immediately and we will reopen this.',
        ],
      };
    case _TelegramAiStarterIntent.thanks:
      return switch (tone) {
        _TelegramAiStarterTone.residential => <String>[
          'You are welcome. $siteReference is secure right now. If anything changes or feels off again, message here immediately.',
          '$siteReference is secure right now. If anything changes or feels off again, message here immediately and we will reopen this straight away.',
        ],
        _TelegramAiStarterTone.enterprise => <String>[
          'You are welcome. $siteReference is secure right now. If anything changes again, message here immediately.',
          '$siteReference is secure right now. If anything changes again, message here immediately and we will reopen the incident straight away.',
        ],
        _ => <String>[
          'You are welcome. $siteReference is secure right now. If anything changes, message here immediately.',
          '$siteReference is secure right now. If anything changes, message here immediately and we will reopen this straight away.',
        ],
      };
    case _TelegramAiStarterIntent.worried:
    case _TelegramAiStarterIntent.visual:
    case _TelegramAiStarterIntent.eta:
    case _TelegramAiStarterIntent.movement:
    case _TelegramAiStarterIntent.status:
    case _TelegramAiStarterIntent.general:
      return switch (tone) {
        _TelegramAiStarterTone.residential => <String>[
          '$siteReference is secure right now. If anything changes or feels off again, message here immediately and we will reopen this straight away.',
          'The site is secure at $siteReference right now. If anything changes or feels off again, message here immediately.',
        ],
        _TelegramAiStarterTone.enterprise => <String>[
          '$siteReference is secure right now. If anything changes again, message here immediately and we will reopen the incident straight away.',
          'The site is secure at $siteReference right now. If anything changes again, message here immediately.',
        ],
        _ => <String>[
          '$siteReference is secure right now. If anything changes, message here immediately and we will reopen this straight away.',
          'The site is secure at $siteReference right now. If anything changes, message here immediately.',
        ],
      };
  }
}

_TelegramAiStarterIntent _starterIntentFor(String normalizedMessage) {
  if (_containsAny(normalizedMessage, const [
    'thank you',
    'thanks',
    'appreciate it',
  ])) {
    return _TelegramAiStarterIntent.thanks;
  }
  if (_containsAny(normalizedMessage, const [
    'scared',
    'worried',
    'afraid',
    'unsafe',
    'panic',
    'help',
  ])) {
    return _TelegramAiStarterIntent.worried;
  }
  if (_containsAny(normalizedMessage, const [
    'gate',
    'door',
    'boom',
    'barrier',
    'access',
    'entry',
    'exit',
    'open',
    'locked',
    'unlock',
  ])) {
    return _TelegramAiStarterIntent.access;
  }
  if (_containsAny(normalizedMessage, const [
    'camera',
    'cameras',
    'cctv',
    'see',
    'visual',
    'footage',
    'daylight',
  ])) {
    return _TelegramAiStarterIntent.visual;
  }
  if (_containsAny(normalizedMessage, const [
    'eta',
    'how long',
    'how soon',
    'when will',
    'when is',
  ])) {
    return _TelegramAiStarterIntent.eta;
  }
  if (_containsAny(normalizedMessage, const [
    'moving',
    'coming',
    'on the way',
    'arriving',
    'arrive',
  ])) {
    return _TelegramAiStarterIntent.movement;
  }
  if (_containsAny(normalizedMessage, const [
    'status',
    'update',
    'what is happening',
    'what is going on',
    'what happened',
    'any update',
  ])) {
    return _TelegramAiStarterIntent.status;
  }
  return _TelegramAiStarterIntent.general;
}

_TelegramAiStarterLaneStage _starterLaneStageFor({
  required String normalizedMessage,
  required List<String> recentConversationTurns,
}) {
  final combined = <String>[
    normalizedMessage,
    ...recentConversationTurns.map((value) => value.trim().toLowerCase()),
  ].where((value) => value.isNotEmpty).join('\n');
  if (_containsAny(combined, const [
    'incident resolved',
    'secure right now',
    'all clear',
    'resolved',
  ])) {
    return _TelegramAiStarterLaneStage.closure;
  }
  if (_containsAny(combined, const [
    'responder on site',
    'security is on site',
    'already on site',
    'on site at',
  ])) {
    return _TelegramAiStarterLaneStage.responderOnSite;
  }
  return _TelegramAiStarterLaneStage.active;
}

_TelegramAiStarterTone _starterToneForScope({
  required String clientId,
  required String siteId,
  required MonitoringSiteProfile siteProfile,
}) {
  final joined =
      '${clientId.trim()} ${siteId.trim()} ${siteProfile.clientName} ${siteProfile.siteName}'
          .toLowerCase();
  if (_containsAny(joined, const [
    'residence',
    'residential',
    'estate',
    'villa',
    'home',
    'community',
    'vallee',
  ])) {
    return _TelegramAiStarterTone.residential;
  }
  if (_containsAny(joined, const [
    'tower',
    'campus',
    'office',
    'industrial',
    'business',
    'corporate',
    'enterprise',
    'park',
    'centre',
    'center',
  ])) {
    return _TelegramAiStarterTone.enterprise;
  }
  return _TelegramAiStarterTone.standard;
}

String _siteReferenceFor({
  required String siteId,
  required MonitoringSiteProfile siteProfile,
}) {
  final siteName = siteProfile.siteName.trim();
  if (siteName.isNotEmpty) {
    return siteName;
  }
  return _humanizeScopeLabel(siteId);
}

String _humanizeScopeLabel(String raw) {
  final cleaned = raw
      .trim()
      .replaceFirst(RegExp(r'^(CLIENT|SITE|REGION)-'), '')
      .replaceAll(RegExp(r'[_\\-]+'), ' ')
      .replaceAll(RegExp(r'[^A-Za-z0-9 ]+'), ' ')
      .replaceAll(RegExp(r'\\s+'), ' ')
      .trim();
  if (cleaned.isEmpty) {
    return 'Unnamed Scope';
  }
  final stopWords = <String>{'and', 'of', 'the'};
  return cleaned
      .split(' ')
      .where((token) => token.trim().isNotEmpty)
      .toList(growable: false)
      .asMap()
      .entries
      .map((entry) {
        final token = entry.value.toLowerCase();
        if (entry.key > 0 && stopWords.contains(token)) {
          return token;
        }
        return '${token[0].toUpperCase()}${token.substring(1)}';
      })
      .join(' ');
}

bool _containsAny(String text, List<String> needles) {
  for (final needle in needles) {
    if (text.contains(needle)) {
      return true;
    }
  }
  return false;
}

int _starterExampleBudgetFor(int approvedRewriteCount) {
  if (approvedRewriteCount >= 2) {
    return 0;
  }
  if (approvedRewriteCount == 1) {
    return 1;
  }
  return 2;
}

String _singleLine(String value, {required int maxLength}) {
  final collapsed = value
      .replaceAll(RegExp(r'\r\n?'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (collapsed.length <= maxLength) {
    return collapsed;
  }
  return '${collapsed.substring(0, maxLength - 1).trimRight()}…';
}

int _preferredExampleScore({
  required _TelegramAiPreferredExampleCandidate candidate,
  required _TelegramAiStarterLaneStage laneStage,
  required _TelegramAiStarterIntent intent,
  required _TelegramAiStarterTone tone,
}) {
  final text = candidate.text.toLowerCase();
  final learned = candidate.learnedExample;
  var score = switch (candidate.source) {
    _TelegramAiPreferredExampleSource.approved => 300,
    _TelegramAiPreferredExampleSource.recentApproved => 180,
    _TelegramAiPreferredExampleSource.starter => 90,
  };
  score -= candidate.index * 4;
  if (learned != null) {
    final normalizedApprovalCount = learned.approvalCount <= 0
        ? 1
        : learned.approvalCount;
    score += normalizedApprovalCount * 24;
    score += _recencyScoreFor(learned.lastUsedAtUtc, freshBonus: 42);
    score += _recencyScoreFor(learned.lastApprovedAtUtc, freshBonus: 28);
  }
  if (candidate.text.length <= 110) {
    score += 8;
  }
  switch (laneStage) {
    case _TelegramAiStarterLaneStage.closure:
      if (_containsAny(text, const ['secure right now', 'reopen'])) {
        score += 80;
      }
    case _TelegramAiStarterLaneStage.responderOnSite:
      if (_containsAny(text, const ['on site', 'next on-site step'])) {
        score += 80;
      }
    case _TelegramAiStarterLaneStage.active:
      if (_containsAny(text, const ['checking', 'next confirmed step'])) {
        score += 25;
      }
  }
  switch (intent) {
    case _TelegramAiStarterIntent.worried:
      if (_containsAny(text, const [
        'you are not alone',
        'taking this seriously',
        'staying close on this',
      ])) {
        score += 70;
      }
    case _TelegramAiStarterIntent.access:
      if (_containsAny(text, const ['access', 'blocked', 'gate'])) {
        score += 70;
      }
    case _TelegramAiStarterIntent.eta:
      if (_containsAny(text, const ['eta', 'timing'])) {
        score += 70;
      }
    case _TelegramAiStarterIntent.movement:
      if (_containsAny(text, const ['moving', 'movement', 'on the way'])) {
        score += 70;
      }
    case _TelegramAiStarterIntent.visual:
      if (_containsAny(text, const [
        'camera',
        'cameras',
        'daylight',
        'camera check',
      ])) {
        score += 70;
      }
    case _TelegramAiStarterIntent.thanks:
      if (_containsAny(text, const [
        'you are welcome',
        'if anything changes',
      ])) {
        score += 70;
      }
    case _TelegramAiStarterIntent.status:
    case _TelegramAiStarterIntent.general:
      if (_containsAny(text, const ['checking', 'next confirmed step'])) {
        score += 40;
      }
  }
  switch (tone) {
    case _TelegramAiStarterTone.residential:
      if (_containsAny(text, const [
        'you are not alone',
        'staying close on this',
        'feels off again',
      ])) {
        score += 35;
      }
    case _TelegramAiStarterTone.enterprise:
      if (_containsAny(text, const [
        'taking this seriously',
        'incident',
        'access',
      ])) {
        score += 35;
      }
    case _TelegramAiStarterTone.standard:
      break;
  }
  return score;
}

int _preferredExampleSourceRank(_TelegramAiPreferredExampleSource source) {
  return switch (source) {
    _TelegramAiPreferredExampleSource.approved => 0,
    _TelegramAiPreferredExampleSource.recentApproved => 1,
    _TelegramAiPreferredExampleSource.starter => 2,
  };
}

int _recencyScoreFor(DateTime? timestamp, {required int freshBonus}) {
  if (timestamp == null) {
    return 0;
  }
  final age = DateTime.now().toUtc().difference(timestamp.toUtc());
  if (age.inDays <= 1) {
    return freshBonus;
  }
  if (age.inDays <= 7) {
    return (freshBonus * 0.65).round();
  }
  if (age.inDays <= 30) {
    return (freshBonus * 0.35).round();
  }
  return 0;
}
