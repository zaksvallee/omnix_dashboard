import 'package:web/web.dart' as web;

class EmailBridgeService {
  const EmailBridgeService();

  bool get supported => true;

  Future<bool> openMailDraft({
    required String subject,
    required String body,
    String? to,
  }) async {
    final recipient = (to ?? '').trim();
    final params = <String, String>{'subject': subject, 'body': body};
    final query = params.entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');
    final url = recipient.isEmpty
        ? 'mailto:?$query'
        : 'mailto:$recipient?$query';
    web.window.open(url, '_self');
    return true;
  }
}
