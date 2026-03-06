class EmailBridgeService {
  const EmailBridgeService();

  bool get supported => false;

  Future<bool> openMailDraft({
    required String subject,
    required String body,
    String? to,
  }) async {
    return false;
  }
}
