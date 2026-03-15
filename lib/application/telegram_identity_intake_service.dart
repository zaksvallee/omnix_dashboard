import 'site_identity_registry_repository.dart';

class TelegramIdentityIntakeParseResult {
  final TelegramIdentityIntakeRecord intake;
  final String summaryLabel;
  final String summaryDetail;
  final String clientAcknowledgementText;
  final String adminSummaryText;

  const TelegramIdentityIntakeParseResult({
    required this.intake,
    required this.summaryLabel,
    required this.summaryDetail,
    required this.clientAcknowledgementText,
    required this.adminSummaryText,
  });
}

class TelegramIdentityIntakeService {
  const TelegramIdentityIntakeService();

  TelegramIdentityIntakeParseResult? tryParse({
    required String clientId,
    required String siteId,
    required String endpointId,
    required String rawText,
    required DateTime occurredAtUtc,
  }) {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final normalized = trimmed.toLowerCase();
    final category = _categoryFor(normalized);
    final hasArrivalSignal =
        normalized.contains('visitor') ||
        normalized.contains('visiting') ||
        normalized.contains('guest') ||
        normalized.contains('coming') ||
        normalized.contains('arriving') ||
        normalized.contains('arrival') ||
        normalized.contains('contractor') ||
        normalized.contains('delivery') ||
        normalized.contains('family') ||
        normalized.contains('employee') ||
        normalized.contains('resident');
    final plateNumber = _extractPlate(trimmed);
    final displayName = _extractDisplayName(trimmed);
    final validUntilUtc = _extractUntilTime(
      sourceText: normalized,
      occurredAtUtc: occurredAtUtc,
    );
    if (!hasArrivalSignal && plateNumber.isEmpty && displayName.isEmpty) {
      return null;
    }
    if (plateNumber.isEmpty && displayName.isEmpty) {
      return null;
    }
    final confidence = _confidenceFor(
      hasArrivalSignal: hasArrivalSignal,
      displayName: displayName,
      plateNumber: plateNumber,
      validUntilUtc: validUntilUtc,
    );
    final intake = TelegramIdentityIntakeRecord(
      clientId: clientId,
      siteId: siteId,
      endpointId: endpointId,
      rawText: trimmed,
      parsedDisplayName: displayName,
      parsedPlateNumber: plateNumber,
      category: category,
      validUntilUtc: validUntilUtc,
      aiConfidence: confidence,
      approvalState: 'proposed',
      createdAtUtc: occurredAtUtc.toUtc(),
      metadata: <String, Object?>{
        'parser': 'rule_based',
        'arrival_signal': hasArrivalSignal,
      },
    );
    final summaryParts = <String>[
      if (displayName.isNotEmpty) displayName,
      if (plateNumber.isNotEmpty) 'plate $plateNumber',
      if (validUntilUtc != null)
        'until ${validUntilUtc.hour.toString().padLeft(2, '0')}:${validUntilUtc.minute.toString().padLeft(2, '0')} UTC',
    ];
    final summaryDetail = summaryParts.join(' • ');
    final label = switch (category) {
      SiteIdentityCategory.employee => 'Employee intake',
      SiteIdentityCategory.family => 'Family intake',
      SiteIdentityCategory.resident => 'Resident intake',
      SiteIdentityCategory.contractor => 'Contractor intake',
      SiteIdentityCategory.delivery => 'Delivery intake',
      _ => 'Visitor intake',
    };
    return TelegramIdentityIntakeParseResult(
      intake: intake,
      summaryLabel: label,
      summaryDetail: summaryDetail,
      clientAcknowledgementText:
          summaryDetail.isEmpty
              ? 'ONYX logged your identity request for control review.'
              : 'ONYX logged this ${category.code.replaceAll('_', ' ')} for control review: $summaryDetail.',
      adminSummaryText:
          'ONYX identity intake captured\n'
          'scope=$clientId/$siteId\n'
          'category=${category.code}\n'
          'confidence=${confidence.toStringAsFixed(2)}\n'
          'name=${displayName.isEmpty ? '-' : displayName}\n'
          'plate=${plateNumber.isEmpty ? '-' : plateNumber}\n'
          'until=${validUntilUtc == null ? '-' : validUntilUtc.toIso8601String()}\n'
          'raw=$trimmed',
    );
  }

  SiteIdentityCategory _categoryFor(String normalized) {
    if (normalized.contains('employee')) {
      return SiteIdentityCategory.employee;
    }
    if (normalized.contains('family')) {
      return SiteIdentityCategory.family;
    }
    if (normalized.contains('resident')) {
      return SiteIdentityCategory.resident;
    }
    if (normalized.contains('contractor')) {
      return SiteIdentityCategory.contractor;
    }
    if (normalized.contains('delivery')) {
      return SiteIdentityCategory.delivery;
    }
    return SiteIdentityCategory.visitor;
  }

  String _extractPlate(String sourceText) {
    final match = RegExp(r'\b([A-Z]{2,3}\s?\d{3,6}[A-Z]{0,2})\b')
        .firstMatch(sourceText.toUpperCase());
    if (match == null) {
      return '';
    }
    return match.group(1)!.replaceAll(RegExp(r'\s+'), '');
  }

  String _extractDisplayName(String sourceText) {
    final leadingMatch = RegExp(
      r'^([A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,2})\s+(?:is|will be|arriving|coming|visiting)\b',
    ).firstMatch(sourceText);
    if (leadingMatch != null) {
      return _cleanDisplayName(leadingMatch.group(1)!);
    }
    final namedMatch = RegExp(
      r'\b(?:visitor|guest|contractor|delivery|employee|resident)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,2})\b',
    ).firstMatch(sourceText);
    if (namedMatch != null) {
      return _cleanDisplayName(namedMatch.group(1)!);
    }
    return '';
  }

  String _cleanDisplayName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final bannedQuestionWords = <String>{
      'what',
      'who',
      'when',
      'where',
      'why',
      'how',
      'status',
    };
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.isEmpty) {
      return '';
    }
    if (bannedQuestionWords.contains(parts.first.toLowerCase())) {
      return '';
    }
    final roleWords = <String>{
      'visitor',
      'guest',
      'contractor',
      'delivery',
      'employee',
      'resident',
      'family',
    };
    if (parts.length > 1 && roleWords.contains(parts.first.toLowerCase())) {
      return parts.sublist(1).join(' ').trim();
    }
    return trimmed;
  }

  DateTime? _extractUntilTime({
    required String sourceText,
    required DateTime occurredAtUtc,
  }) {
    final match = RegExp(r'\buntil\s+(\d{1,2}):(\d{2})\b').firstMatch(sourceText);
    if (match == null) {
      return null;
    }
    final hour = int.tryParse(match.group(1)!) ?? -1;
    final minute = int.tryParse(match.group(2)!) ?? -1;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }
    var result = DateTime.utc(
      occurredAtUtc.year,
      occurredAtUtc.month,
      occurredAtUtc.day,
      hour,
      minute,
    );
    if (result.isBefore(occurredAtUtc.toUtc())) {
      result = result.add(const Duration(days: 1));
    }
    return result;
  }

  double _confidenceFor({
    required bool hasArrivalSignal,
    required String displayName,
    required String plateNumber,
    required DateTime? validUntilUtc,
  }) {
    var confidence = hasArrivalSignal ? 0.58 : 0.45;
    if (displayName.isNotEmpty) {
      confidence += 0.17;
    }
    if (plateNumber.isNotEmpty) {
      confidence += 0.17;
    }
    if (validUntilUtc != null) {
      confidence += 0.08;
    }
    if (confidence > 0.96) {
      return 0.96;
    }
    return confidence;
  }
}
