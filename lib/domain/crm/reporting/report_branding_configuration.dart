class ReportBrandingConfiguration {
  final String primaryLabel;
  final String endorsementLine;
  final String sourceLabel;
  final bool usesOverride;

  const ReportBrandingConfiguration({
    this.primaryLabel = '',
    this.endorsementLine = '',
    this.sourceLabel = '',
    this.usesOverride = false,
  });

  bool get isConfigured =>
      primaryLabel.trim().isNotEmpty || endorsementLine.trim().isNotEmpty;

  ReportBrandingConfiguration copyWith({
    String? primaryLabel,
    String? endorsementLine,
    String? sourceLabel,
    bool? usesOverride,
  }) {
    return ReportBrandingConfiguration(
      primaryLabel: primaryLabel ?? this.primaryLabel,
      endorsementLine: endorsementLine ?? this.endorsementLine,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      usesOverride: usesOverride ?? this.usesOverride,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'primaryLabel': primaryLabel,
      'endorsementLine': endorsementLine,
      'sourceLabel': sourceLabel,
      'usesOverride': usesOverride,
    };
  }

  factory ReportBrandingConfiguration.fromJson(Map<String, Object?> json) {
    return ReportBrandingConfiguration(
      primaryLabel: (json['primaryLabel'] as String? ?? '').trim(),
      endorsementLine: (json['endorsementLine'] as String? ?? '').trim(),
      sourceLabel: (json['sourceLabel'] as String? ?? '').trim(),
      usesOverride: json['usesOverride'] == true,
    );
  }
}
