class ClientDeliveryMessageFormatter {
  const ClientDeliveryMessageFormatter._();

  static String telegramBody({
    required String title,
    required String body,
    required String siteLabel,
    required bool priority,
  }) {
    final normalizedSite = _cleanSiteLabel(siteLabel);
    final headline = priority
        ? 'ONYX priority update for $normalizedSite'
        : 'ONYX update for $normalizedSite';
    final cleanTitle = _sentence(title, maxLength: 84);
    final cleanBody = _sentence(body, maxLength: 360);
    return '$headline\n\n$cleanTitle\n$cleanBody\n\nReply here if you need us.';
  }

  static String smsBody({
    required String title,
    required String body,
    required String siteLabel,
    required bool priority,
  }) {
    final normalizedSite = _cleanSiteLabel(siteLabel);
    final priorityLabel = priority ? 'priority update' : 'update';
    final cleanTitle = _sentence(title, maxLength: 42);
    final cleanBody = _sentence(body, maxLength: 120);
    return 'ONYX $priorityLabel for $normalizedSite: $cleanTitle $cleanBody Reply here if you need us.';
  }

  static String smsFallbackMissingPhonesSummary({required String reason}) {
    return '${_deliveryReasonLead(reason)}, but SMS fallback could not start because no active contact numbers are on file.';
  }

  static String smsFallbackOutcomeSummary({
    required String providerLabel,
    required int sentCount,
    required int totalCount,
    required String reason,
    List<String> failureReasons = const <String>[],
  }) {
    final provider = _providerDisplayLabel(providerLabel);
    final lead = sentCount <= 0
        ? '$provider could not reach any contacts after ${_deliveryReasonTail(reason)}.'
        : '$provider reached $sentCount/$totalCount contact${sentCount == 1 ? '' : 's'} after ${_deliveryReasonTail(reason)}.';
    final details = failureReasons
        .where((value) => value.trim().isNotEmpty)
        .take(2)
        .join(' | ');
    if (details.isEmpty) {
      return lead;
    }
    return '$lead $details';
  }

  static String voipStageOutcomeSummary({
    required String providerLabel,
    required bool accepted,
    required String contactName,
    String? statusLabel,
    String? detail,
  }) {
    final provider = _voiceProviderDisplayLabel(providerLabel);
    final contact = _contactLabel(contactName);
    final cleanDetail = (detail ?? '').trim();
    final normalizedStatus = (statusLabel ?? '').trim().toLowerCase();
    if (accepted) {
      return '$provider staged a call for $contact.';
    }
    if (providerLabel.trim().toLowerCase() == 'voip:unconfigured' ||
        normalizedStatus.contains('not configured')) {
      if (cleanDetail.isEmpty) {
        return 'VoIP staging is not configured for $contact yet.';
      }
      return 'VoIP staging is not configured for $contact yet. ${_sentence(cleanDetail, maxLength: 160)}';
    }
    if (cleanDetail.isEmpty) {
      return '$provider could not stage the call for $contact.';
    }
    return '$provider could not stage the call for $contact. ${_sentence(cleanDetail, maxLength: 160)}';
  }

  static String telegramBridgeFailureSummary({
    required int failedCount,
    required int totalCount,
    required String reason,
  }) {
    final normalizedReason = _sentence(reason, maxLength: 160);
    if (totalCount <= 1) {
      return 'Telegram could not deliver 1/1 client update. Bridge reported: $normalizedReason';
    }
    return 'Telegram could not deliver $failedCount/$totalCount client updates. Bridge reported: $normalizedReason';
  }

  static String humanizeScopedCommsSummary(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return value;
    }

    final telegramMatch = RegExp(
      r'^Telegram bridge failed for (\d+)\/(\d+) message\(s\)\. Reasons:\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(value);
    if (telegramMatch != null) {
      final failedCount = int.tryParse(telegramMatch.group(1) ?? '') ?? 0;
      final totalCount = int.tryParse(telegramMatch.group(2) ?? '') ?? 0;
      final reason = telegramMatch.group(3) ?? 'bridge failure';
      return telegramBridgeFailureSummary(
        failedCount: failedCount,
        totalCount: totalCount,
        reason: reason,
      );
    }

    final missingPhonesMatch = RegExp(
      r'^sms(?:-fallback)?\s+missing\s+phones\s+after\s+telegram\s+(blocked|degraded)\.?$',
      caseSensitive: false,
    ).firstMatch(value);
    if (missingPhonesMatch != null) {
      final reason =
          'telegram ${missingPhonesMatch.group(1)?.toLowerCase() ?? 'degraded'}';
      return smsFallbackMissingPhonesSummary(reason: reason);
    }

    final smsMatch = RegExp(
      r'^sms:([a-z0-9_-]+)\s+sent\s+(\d+)\/(\d+)\s+after\s+telegram\s+(blocked|degraded)\.$',
      caseSensitive: false,
    ).firstMatch(value);
    if (smsMatch != null) {
      final provider = smsMatch.group(1) ?? '';
      final sentCount = int.tryParse(smsMatch.group(2) ?? '') ?? 0;
      final totalCount = int.tryParse(smsMatch.group(3) ?? '') ?? 0;
      final reason =
          'telegram ${smsMatch.group(4)?.toLowerCase() ?? 'degraded'}';
      return smsFallbackOutcomeSummary(
        providerLabel: 'sms:$provider',
        sentCount: sentCount,
        totalCount: totalCount,
        reason: reason,
      );
    }

    final voipAcceptedMatch = RegExp(
      r'^voip:([a-z0-9_-]+)\s+staged\s+call\s+for\s+(.+)\.$',
      caseSensitive: false,
    ).firstMatch(value);
    if (voipAcceptedMatch != null) {
      final provider = voipAcceptedMatch.group(1) ?? '';
      final contactName = voipAcceptedMatch.group(2) ?? '';
      return voipStageOutcomeSummary(
        providerLabel: 'voip:$provider',
        accepted: true,
        contactName: contactName,
      );
    }

    final voipUnconfiguredMatch = RegExp(
      r'^voip:unconfigured\s+(?:not\s+configured|not\s+ready)\s+for\s+(.+?)(?:\.\s*(.+))?$',
      caseSensitive: false,
    ).firstMatch(value);
    if (voipUnconfiguredMatch != null) {
      final contactName = voipUnconfiguredMatch.group(1) ?? '';
      final detail = voipUnconfiguredMatch.group(2);
      return voipStageOutcomeSummary(
        providerLabel: 'voip:unconfigured',
        accepted: false,
        contactName: contactName,
        statusLabel: 'VoIP provider not configured',
        detail: detail,
      );
    }

    final voipFailedMatch = RegExp(
      r'^voip:([a-z0-9_-]+)\s+could\s+not\s+stage\s+call\s+for\s+(.+?)(?:\.\s*(.+))?$',
      caseSensitive: false,
    ).firstMatch(value);
    if (voipFailedMatch != null) {
      final provider = voipFailedMatch.group(1) ?? '';
      final contactName = voipFailedMatch.group(2) ?? '';
      final detail = voipFailedMatch.group(3);
      return voipStageOutcomeSummary(
        providerLabel: 'voip:$provider',
        accepted: false,
        contactName: contactName,
        detail: detail,
      );
    }

    return value;
  }

  static String _cleanSiteLabel(String raw) {
    final cleaned = raw
        .trim()
        .replaceFirst(
          RegExp(r'^(CLIENT|SITE|REGION)\s+', caseSensitive: false),
          '',
        )
        .replaceFirst(
          RegExp(r'^(CLIENT|SITE|REGION)-', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? 'your site' : cleaned;
  }

  static String _sentence(String raw, {required int maxLength}) {
    final normalized = raw
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[•:;,\-\s]+'), '')
        .trim();
    if (normalized.isEmpty) {
      return 'Control is on it.';
    }
    final truncated = normalized.length <= maxLength
        ? normalized
        : _truncateAtBoundary(normalized, maxLength: maxLength);
    if (RegExp(r'[.!?]$').hasMatch(truncated)) {
      return truncated;
    }
    return '$truncated.';
  }

  static String _truncateAtBoundary(String value, {required int maxLength}) {
    if (value.length <= maxLength) {
      return value;
    }
    final hardLimit = maxLength - 1;
    final candidate = value.substring(0, hardLimit).trimRight();
    final punctuationMatches = RegExp(r'[.!?](?=\s|$)').allMatches(candidate);
    if (punctuationMatches.isNotEmpty) {
      final lastBoundary = punctuationMatches.last.end;
      if (lastBoundary >= (maxLength * 0.55).round()) {
        return candidate.substring(0, lastBoundary).trimRight();
      }
    }
    final whitespaceBoundary = candidate.lastIndexOf(RegExp(r'\s'));
    if (whitespaceBoundary >= (maxLength * 0.55).round()) {
      return '${candidate.substring(0, whitespaceBoundary).trimRight()}…';
    }
    return '${candidate.trimRight()}…';
  }

  static String _providerDisplayLabel(String providerLabel) {
    final normalized = providerLabel.trim().toLowerCase();
    if (normalized == 'sms:bulksms') {
      return 'BulkSMS';
    }
    if (normalized.startsWith('sms:')) {
      final raw = normalized.substring(4).trim();
      if (raw.isEmpty) {
        return 'SMS fallback';
      }
      return '${raw[0].toUpperCase()}${raw.substring(1)} SMS';
    }
    return providerLabel.trim().isEmpty ? 'SMS fallback' : providerLabel.trim();
  }

  static String _voiceProviderDisplayLabel(String providerLabel) {
    final normalized = providerLabel.trim().toLowerCase();
    if (normalized == 'voip:asterisk') {
      return 'Asterisk';
    }
    if (normalized == 'voip:unconfigured') {
      return 'VoIP';
    }
    if (normalized.startsWith('voip:')) {
      final raw = normalized.substring(5).trim();
      if (raw.isEmpty) {
        return 'VoIP';
      }
      return '${raw[0].toUpperCase()}${raw.substring(1)}';
    }
    return providerLabel.trim().isEmpty ? 'VoIP' : providerLabel.trim();
  }

  static String _contactLabel(String contactName) {
    final normalized = contactName.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) {
      return 'this contact';
    }
    return normalized;
  }

  static String _deliveryReasonLead(String reason) {
    final normalized = reason.trim().toLowerCase();
    switch (normalized) {
      case 'telegram blocked':
        return 'Telegram was blocked for this client thread';
      case 'telegram degraded':
        return 'Telegram delivery degraded for this client thread';
      default:
        return _sentence(reason, maxLength: 80);
    }
  }

  static String _deliveryReasonTail(String reason) {
    final normalized = reason.trim().toLowerCase();
    switch (normalized) {
      case 'telegram blocked':
        return 'Telegram was blocked';
      case 'telegram degraded':
        return 'Telegram degraded';
      default:
        return _sentence(reason, maxLength: 80).replaceAll(RegExp(r'[.]$'), '');
    }
  }
}
