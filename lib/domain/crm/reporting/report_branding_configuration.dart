class ReportBrandingConfiguration {
  final String primaryLabel;
  final String endorsementLine;

  const ReportBrandingConfiguration({
    this.primaryLabel = '',
    this.endorsementLine = '',
  });

  bool get isConfigured =>
      primaryLabel.trim().isNotEmpty || endorsementLine.trim().isNotEmpty;

  ReportBrandingConfiguration copyWith({
    String? primaryLabel,
    String? endorsementLine,
  }) {
    return ReportBrandingConfiguration(
      primaryLabel: primaryLabel ?? this.primaryLabel,
      endorsementLine: endorsementLine ?? this.endorsementLine,
    );
  }

  Map<String, Object?> toJson() {
    return {'primaryLabel': primaryLabel, 'endorsementLine': endorsementLine};
  }

  factory ReportBrandingConfiguration.fromJson(Map<String, Object?> json) {
    return ReportBrandingConfiguration(
      primaryLabel: (json['primaryLabel'] as String? ?? '').trim(),
      endorsementLine: (json['endorsementLine'] as String? ?? '').trim(),
    );
  }
}
