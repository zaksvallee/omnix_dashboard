enum ReportEntryContext {
  governanceBrandingDrift;

  String get storageValue => switch (this) {
    ReportEntryContext.governanceBrandingDrift => 'governance_branding_drift',
  };

  String get bannerTitle => switch (this) {
    ReportEntryContext.governanceBrandingDrift =>
      'OPENED FROM GOVERNANCE BRANDING DRIFT',
  };

  String get bannerDetail => switch (this) {
    ReportEntryContext.governanceBrandingDrift =>
      'This receipt scope was opened from Governance so operators can inspect the generated-report history behind a branding-drift shift.',
  };

  static ReportEntryContext? fromStorageValue(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    return switch (normalized) {
      'governance_branding_drift' => ReportEntryContext.governanceBrandingDrift,
      _ => null,
    };
  }
}
