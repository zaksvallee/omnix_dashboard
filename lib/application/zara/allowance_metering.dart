import 'dart:math' as math;

import 'capability_registry.dart';

const int _zaraAllowanceApproachingPercent = 80;

class ZaraAllowancePlan {
  final ZaraAllowanceTier tier;
  final int monthlyIncludedUnits;
  final bool softOverageEnabled;
  final bool emergencyContinuityEnabled;
  final String sourceLabel;

  const ZaraAllowancePlan({
    required this.tier,
    required this.monthlyIncludedUnits,
    this.softOverageEnabled = true,
    this.emergencyContinuityEnabled = true,
    this.sourceLabel = 'tier-default',
  });
}

class ZaraMonthlyUsageSnapshot {
  final DateTime periodMonthUtc;
  final ZaraAllowancePlan plan;
  final int usedUnits;

  const ZaraMonthlyUsageSnapshot({
    required this.periodMonthUtc,
    required this.plan,
    required this.usedUnits,
  });

  int get includedUnits => plan.monthlyIncludedUnits;

  bool get hasAllowanceLimit => includedUnits > 0;

  int get warningThresholdUnits {
    if (!hasAllowanceLimit) {
      return 0;
    }
    return math.max(
      1,
      ((includedUnits * _zaraAllowanceApproachingPercent) / 100).ceil(),
    );
  }

  int get remainingIncludedUnits => math.max(includedUnits - usedUnits, 0);

  int get overageUnits => math.max(usedUnits - includedUnits, 0);

  bool get isAtOrAboveWarningThreshold =>
      hasAllowanceLimit && usedUnits >= warningThresholdUnits;

  bool get isAtOrAboveAllowanceLimit =>
      hasAllowanceLimit && usedUnits >= includedUnits;
}

class ZaraAllowanceContext {
  final ZaraAllowancePlan plan;
  final ZaraMonthlyUsageSnapshot usage;

  const ZaraAllowanceContext({required this.plan, required this.usage});
}

class ZaraUsageLedgerEntry {
  final String clientId;
  final String? siteId;
  final String audienceLabel;
  final String deliveryModeLabel;
  final ZaraAllowanceTier allowanceTier;
  final String? capabilityKey;
  final String decisionLabel;
  final String providerLabel;
  final bool usedFallback;
  final bool isEmergency;
  final int billableUnits;
  final DateTime createdAtUtc;
  final Map<String, Object?> metadata;

  const ZaraUsageLedgerEntry({
    required this.clientId,
    this.siteId,
    required this.audienceLabel,
    required this.deliveryModeLabel,
    required this.allowanceTier,
    this.capabilityKey,
    required this.decisionLabel,
    required this.providerLabel,
    required this.usedFallback,
    required this.isEmergency,
    required this.billableUnits,
    required this.createdAtUtc,
    this.metadata = const <String, Object?>{},
  });

  DateTime get periodMonthUtc => zaraUsagePeriodMonthUtc(createdAtUtc);

  Map<String, Object?> toInsertRow() {
    final normalizedMetadata = <String, Object?>{};
    metadata.forEach((key, value) {
      if (value != null) {
        normalizedMetadata[key] = value;
      }
    });
    return <String, Object?>{
      'client_id': clientId.trim(),
      'site_id': _normalizedOrNull(siteId),
      'audience': _toSnakeCase(audienceLabel),
      'delivery_mode': _toSnakeCase(deliveryModeLabel),
      'allowance_tier': allowanceTier.name,
      'capability_key': _normalizedOrNull(capabilityKey),
      'decision': _toSnakeCase(decisionLabel),
      'provider_label': providerLabel.trim(),
      'used_fallback': usedFallback,
      'is_emergency': isEmergency,
      'billable_units': math.max(billableUnits, 0),
      'period_month': _dateValue(periodMonthUtc),
      'created_at': createdAtUtc.toUtc().toIso8601String(),
      'metadata': normalizedMetadata,
    };
  }
}

enum ZaraAllowanceWarningEvent { none, warning80, warning100 }

ZaraAllowancePlan resolveZaraAllowancePlan({
  required ZaraAllowanceTier tier,
  Map<String, dynamic>? clientMetadata,
}) {
  final metadata = clientMetadata ?? const <String, dynamic>{};
  final overrideUnits =
      parsePositiveInt(metadata['zara_monthly_allowance_queries']) ??
      parsePositiveInt(metadata['zara_monthly_query_allowance']) ??
      parsePositiveInt(metadata['zara_monthly_allowance_units']);
  if (overrideUnits != null) {
    return ZaraAllowancePlan(
      tier: tier,
      monthlyIncludedUnits: overrideUnits,
      sourceLabel: 'client-metadata',
    );
  }

  return ZaraAllowancePlan(
    tier: tier,
    monthlyIncludedUnits: defaultMonthlyIncludedUnitsForTier(tier),
  );
}

int defaultMonthlyIncludedUnitsForTier(ZaraAllowanceTier tier) {
  return switch (tier) {
    ZaraAllowanceTier.standard => 250,
    ZaraAllowanceTier.premium => 1000,
    ZaraAllowanceTier.tactical => 5000,
  };
}

DateTime zaraUsagePeriodMonthUtc(DateTime timestampUtc) {
  final normalized = timestampUtc.toUtc();
  return DateTime.utc(normalized.year, normalized.month);
}

ZaraAllowanceWarningEvent zaraAllowanceWarningEventForTransition({
  required ZaraMonthlyUsageSnapshot beforeUsage,
  required ZaraMonthlyUsageSnapshot afterUsage,
}) {
  if (!afterUsage.hasAllowanceLimit) {
    return ZaraAllowanceWarningEvent.none;
  }

  final limit = afterUsage.includedUnits;
  if (beforeUsage.usedUnits < limit && afterUsage.usedUnits >= limit) {
    return ZaraAllowanceWarningEvent.warning100;
  }

  final warningThreshold = afterUsage.warningThresholdUnits;
  if (beforeUsage.usedUnits < warningThreshold &&
      afterUsage.usedUnits >= warningThreshold) {
    return ZaraAllowanceWarningEvent.warning80;
  }

  return ZaraAllowanceWarningEvent.none;
}

String? buildZaraAllowanceWarningText({
  required ZaraAllowanceWarningEvent event,
  required ZaraMonthlyUsageSnapshot usage,
  required bool isEmergency,
}) {
  if (event == ZaraAllowanceWarningEvent.none || !usage.hasAllowanceLimit) {
    return null;
  }

  final usageLabel = '${usage.usedUnits}/${usage.includedUnits}';
  switch (event) {
    case ZaraAllowanceWarningEvent.none:
      return null;
    case ZaraAllowanceWarningEvent.warning80:
      return 'Allowance notice: $usageLabel Zara queries used this month. '
          'Zara stays live, and we can flag your account manager before the '
          'included volume runs out.';
    case ZaraAllowanceWarningEvent.warning100:
      if (isEmergency && usage.plan.emergencyContinuityEnabled) {
        return 'Allowance notice: $usageLabel Zara queries used this month. '
            'Zara stays live under soft overage, and there is no hard cutoff '
            'during a live emergency.';
      }
      return 'Allowance notice: $usageLabel Zara queries used this month. '
          'Zara stays live under soft overage, and your account manager can '
          'help with included-volume planning.';
  }
}

bool zaraMessageLooksEmergency(String messageText) {
  final normalized = messageText.trim().toLowerCase();
  if (normalized.isEmpty) {
    return false;
  }

  const urgentSignals = <String>[
    'emergency',
    'urgent',
    'immediate danger',
    'panic',
    'fire',
    'smoke',
    'flood',
    'leak',
    'break-in',
    'intruder',
    'weapon',
    'gun',
    'ambulance',
    'police',
    'saps',
    '112',
    'help now',
    'attack',
  ];
  return urgentSignals.any(normalized.contains);
}

int zaraBillableUnitsForTurn({
  required String decisionLabel,
  required bool usedFallback,
  String? capabilityKey,
}) {
  final normalizedDecision = decisionLabel.trim().toLowerCase();
  if (normalizedDecision == 'delegated') {
    return 1;
  }
  if (normalizedDecision == 'fallback' &&
      (capabilityKey?.trim().isNotEmpty ?? false) &&
      !usedFallback) {
    return 1;
  }
  return 0;
}

int? parsePositiveInt(Object? rawValue) {
  if (rawValue is int) {
    return rawValue > 0 ? rawValue : null;
  }
  if (rawValue is num) {
    final value = rawValue.toInt();
    return value > 0 ? value : null;
  }
  final normalized = rawValue?.toString().trim() ?? '';
  if (normalized.isEmpty) {
    return null;
  }
  final parsed = int.tryParse(normalized);
  if (parsed == null || parsed <= 0) {
    return null;
  }
  return parsed;
}

String? _normalizedOrNull(String? rawValue) {
  final normalized = rawValue?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

String _toSnakeCase(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return '';
  }
  final buffer = StringBuffer();
  for (var index = 0; index < normalized.length; index++) {
    final char = normalized[index];
    final isUpper = char.toUpperCase() == char && char.toLowerCase() != char;
    if (isUpper && index > 0) {
      buffer.write('_');
    }
    buffer.write(char.toLowerCase());
  }
  return buffer.toString();
}

String _dateValue(DateTime value) {
  final utc = value.toUtc();
  final month = utc.month.toString().padLeft(2, '0');
  final day = utc.day.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}-$month-$day';
}
