class NewsSourceDiagnostic {
  final String provider;
  final String status;
  final String detail;
  final String checkedAtUtc;

  const NewsSourceDiagnostic({
    required this.provider,
    required this.status,
    required this.detail,
    this.checkedAtUtc = '',
  });

  factory NewsSourceDiagnostic.fromJson(Map<String, Object?> json) {
    return NewsSourceDiagnostic(
      provider: (json['provider'] as String? ?? '').trim(),
      status: (json['status'] as String? ?? '').trim(),
      detail: (json['detail'] as String? ?? '').trim(),
      checkedAtUtc: (json['checkedAtUtc'] as String? ?? '').trim(),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'provider': provider,
      'status': status,
      'detail': detail,
      'checkedAtUtc': checkedAtUtc,
    };
  }
}
