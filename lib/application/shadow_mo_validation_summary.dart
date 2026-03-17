import 'monitoring_global_posture_service.dart';

class ShadowMoValidationDriftSummary {
  final String summary;
  final String headline;
  final String historySummary;

  const ShadowMoValidationDriftSummary({
    required this.summary,
    this.headline = '',
    this.historySummary = '',
  });
}

ShadowMoValidationDriftSummary buildShadowMoValidationDriftSummary({
  required List<MonitoringGlobalSitePosture> currentSites,
  List<List<MonitoringGlobalSitePosture>> historySiteSets = const [],
}) {
  final currentCounts = _shadowValidationCounts(currentSites);
  final currentSummary = _countsSummary(currentCounts);
  if (currentSummary.isEmpty) {
    return const ShadowMoValidationDriftSummary(summary: '');
  }
  final baselines = historySiteSets
      .map(_shadowValidationCounts)
      .where((counts) => counts.isNotEmpty)
      .take(3)
      .toList(growable: false);
  if (baselines.isEmpty) {
    return ShadowMoValidationDriftSummary(summary: currentSummary);
  }

  final statuses =
      <String>{
        ...currentCounts.keys,
        for (final counts in baselines) ...counts.keys,
      }.toList(growable: false)..sort((left, right) {
        final leftIndex = _statusPriority(left);
        final rightIndex = _statusPriority(right);
        if (leftIndex != rightIndex) {
          return leftIndex.compareTo(rightIndex);
        }
        return left.compareTo(right);
      });

  final averages = <String, double>{
    for (final status in statuses)
      status:
          baselines
              .map((counts) => (counts[status] ?? 0).toDouble())
              .reduce((left, right) => left + right) /
          baselines.length,
  };
  final deltas = <String, double>{
    for (final status in statuses)
      status: (currentCounts[status] ?? 0).toDouble() - (averages[status] ?? 0),
  };
  final leadStatus = statuses.firstWhere(
    (status) => deltas[status]!.abs() >= 0.75,
    orElse: () => '',
  );
  final leadDelta = leadStatus.isEmpty ? 0.0 : deltas[leadStatus]!;
  final headline = leadStatus.isEmpty
      ? 'STABLE • ${baselines.length + 1}d'
      : '${leadDelta > 0 ? 'RISING' : 'EASING'} ${_humanizeShadowValidationStatus(leadStatus).toUpperCase()} • ${baselines.length + 1}d';
  final summary = leadStatus.isEmpty
      ? '$currentSummary • Drift stable'
      : '$currentSummary • Drift ${_humanizeShadowValidationStatus(leadStatus).toLowerCase()} ${leadDelta > 0 ? 'rising' : 'easing'}';

  final detailStatuses =
      statuses
          .where((status) => deltas[status]!.abs() >= 0.25)
          .toList(growable: false)
        ..sort((left, right) {
          final deltaCompare = deltas[right]!.abs().compareTo(
            deltas[left]!.abs(),
          );
          if (deltaCompare != 0) {
            return deltaCompare;
          }
          return _statusPriority(left).compareTo(_statusPriority(right));
        });
  final historyParts =
      (detailStatuses.isEmpty ? statuses.take(1) : detailStatuses.take(2))
          .map((status) {
            final current = currentCounts[status] ?? 0;
            final baseline = averages[status] ?? 0;
            final delta = deltas[status] ?? 0;
            final deltaLabel = delta.abs() < 0.05
                ? 'flat'
                : '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)}';
            return '${_humanizeShadowValidationStatus(status)} $current vs ${baseline.toStringAsFixed(1)} baseline ($deltaLabel)';
          })
          .toList(growable: false);

  return ShadowMoValidationDriftSummary(
    summary: summary,
    headline: headline,
    historySummary: historyParts.join(' • '),
  );
}

Map<String, int> _shadowValidationCounts(
  List<MonitoringGlobalSitePosture> sites,
) {
  final counts = <String, int>{};
  for (final site in sites) {
    for (final match in site.moShadowMatches) {
      final status = match.validationStatus.trim();
      if (status.isEmpty) {
        continue;
      }
      counts.update(status, (value) => value + 1, ifAbsent: () => 1);
    }
  }
  return counts;
}

String _countsSummary(Map<String, int> counts) {
  if (counts.isEmpty) {
    return '';
  }
  final ordered = counts.keys.toList(growable: false)
    ..sort((left, right) {
      final leftIndex = _statusPriority(left);
      final rightIndex = _statusPriority(right);
      if (leftIndex != rightIndex) {
        return leftIndex.compareTo(rightIndex);
      }
      return left.compareTo(right);
    });
  return ordered
      .map(
        (status) =>
            '${_humanizeShadowValidationStatus(status)} ${counts[status]}',
      )
      .join(' • ');
}

int _statusPriority(String status) {
  const priority = <String>[
    'production',
    'validated',
    'shadowMode',
    'candidate',
  ];
  final index = priority.indexOf(status);
  return index == -1 ? priority.length : index;
}

String _humanizeShadowValidationStatus(String status) {
  switch (status.trim()) {
    case 'shadowMode':
      return 'Shadow mode';
    case 'validated':
      return 'Validated';
    case 'production':
      return 'Production';
    case 'candidate':
      return 'Candidate';
    default:
      final trimmed = status.trim();
      if (trimmed.isEmpty) {
        return '';
      }
      return trimmed[0].toUpperCase() + trimmed.substring(1);
  }
}
