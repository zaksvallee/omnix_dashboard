import 'dart:convert';

class OutcomeLabelGovernancePolicy {
  final String policyVersion;
  final Map<String, Set<String>> allowedConfirmersByLabel;
  final Map<String, String> ruleIdByLabel;

  const OutcomeLabelGovernancePolicy({
    required this.policyVersion,
    required this.allowedConfirmersByLabel,
    required this.ruleIdByLabel,
  });

  factory OutcomeLabelGovernancePolicy.defaultPolicy() {
    return const OutcomeLabelGovernancePolicy(
      policyVersion: 'v1',
      allowedConfirmersByLabel: {
        'true_threat': {'supervisor'},
        'false_alarm': {'supervisor', 'control', 'guard'},
        'suspicious_activity': {'supervisor', 'control', 'guard'},
      },
      ruleIdByLabel: {
        'true_threat': 'outcome.true_threat.supervisor_required',
        'false_alarm': 'outcome.false_alarm.standard',
        'suspicious_activity': 'outcome.suspicious_activity.standard',
      },
    );
  }

  factory OutcomeLabelGovernancePolicy.fromJsonString(
    String raw, {
    required OutcomeLabelGovernancePolicy fallback,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return fallback;
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map) return fallback;
      final dynamicVersion = decoded['version'];
      final policyVersion = dynamicVersion == null
          ? fallback.policyVersion
          : dynamicVersion.toString().trim().isEmpty
          ? fallback.policyVersion
          : dynamicVersion.toString().trim();

      final parsedAllow = <String, Set<String>>{};
      final parsedRuleIds = <String, String>{};

      final dynamicRules = decoded['rules'];
      if (dynamicRules is Map) {
        for (final entry in dynamicRules.entries) {
          final label = entry.key.toString().trim();
          if (label.isEmpty) continue;
          final rule = entry.value;
          if (rule is Map) {
            final allowedRaw = rule['allowed_confirmers'] ?? rule['allowed'];
            if (allowedRaw is List) {
              final roles = allowedRaw
                  .map((entry) => entry.toString().trim())
                  .where((entry) => entry.isNotEmpty)
                  .toSet();
              if (roles.isNotEmpty) {
                parsedAllow[label] = roles;
              }
            }
            final ruleIdRaw = (rule['rule_id'] ?? '').toString().trim();
            if (ruleIdRaw.isNotEmpty) {
              parsedRuleIds[label] = ruleIdRaw;
            }
            continue;
          }
          if (rule is List) {
            final roles = rule
                .map((entry) => entry.toString().trim())
                .where((entry) => entry.isNotEmpty)
                .toSet();
            if (roles.isNotEmpty) {
              parsedAllow[label] = roles;
            }
          }
        }
      } else {
        for (final entry in decoded.entries) {
          final label = entry.key.toString().trim();
          if (label.isEmpty || label == 'version' || label == 'rules') {
            continue;
          }
          final value = entry.value;
          if (value is! List) {
            continue;
          }
          final roles = value
              .map((entry) => entry.toString().trim())
              .where((entry) => entry.isNotEmpty)
              .toSet();
          if (roles.isEmpty) {
            continue;
          }
          parsedAllow[label] = roles;
        }
      }

      if (parsedAllow.isEmpty) {
        return fallback;
      }
      for (final label in parsedAllow.keys) {
        parsedRuleIds[label] =
            parsedRuleIds[label] ?? _defaultRuleIdForLabel(label);
      }
      return OutcomeLabelGovernancePolicy(
        policyVersion: policyVersion,
        allowedConfirmersByLabel: parsedAllow,
        ruleIdByLabel: parsedRuleIds,
      );
    } catch (_) {
      return fallback;
    }
  }

  bool allows({required String outcomeLabel, required String confirmedBy}) {
    final allowed = allowedConfirmersByLabel[outcomeLabel.trim()];
    if (allowed == null || allowed.isEmpty) {
      return true;
    }
    return allowed.contains(confirmedBy.trim());
  }

  Set<String> allowedConfirmers(String outcomeLabel) {
    return allowedConfirmersByLabel[outcomeLabel.trim()] ?? const {};
  }

  String ruleIdFor(String outcomeLabel) {
    final label = outcomeLabel.trim();
    return ruleIdByLabel[label] ?? _defaultRuleIdForLabel(label);
  }

  Set<String> allKnownConfirmers() {
    final all = <String>{};
    for (final roles in allowedConfirmersByLabel.values) {
      all.addAll(roles);
    }
    if (all.isEmpty) {
      return const {'supervisor', 'control', 'guard'};
    }
    return all;
  }

  static String _defaultRuleIdForLabel(String label) {
    final normalized = label.trim().replaceAll(' ', '_').toLowerCase();
    if (normalized.isEmpty) {
      return 'outcome.unclassified';
    }
    return 'outcome.$normalized.standard';
  }
}
