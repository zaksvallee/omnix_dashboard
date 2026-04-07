import 'client_delivery_message_formatter.dart';

class OnyxAgentClientDraftResult {
  final String telegramDraft;
  final String smsDraft;
  final String providerLabel;

  const OnyxAgentClientDraftResult({
    required this.telegramDraft,
    required this.smsDraft,
    this.providerLabel = 'local:formatter',
  });

  String toOperatorSummary() {
    return 'Telegram draft:\n$telegramDraft\n\nSMS draft:\n$smsDraft\n\nSource: $providerLabel';
  }
}

abstract class OnyxAgentClientDraftService {
  bool get isConfigured;

  Future<OnyxAgentClientDraftResult> draft({
    required String prompt,
    required String clientId,
    required String siteId,
    required String incidentReference,
  });
}

class LocalOnyxAgentClientDraftService implements OnyxAgentClientDraftService {
  const LocalOnyxAgentClientDraftService();

  @override
  bool get isConfigured => true;

  @override
  Future<OnyxAgentClientDraftResult> draft({
    required String prompt,
    required String clientId,
    required String siteId,
    required String incidentReference,
  }) async {
    final incidentLabel = incidentReference.trim().isEmpty
        ? 'the current operational signal'
        : incidentReference.trim();
    final siteLabel = _humanizeSiteLabel(siteId, clientId);
    final title = prompt.trim().isEmpty
        ? 'Control is actively checking $incidentLabel.'
        : 'Control update for $siteLabel.';
    final body =
        'We are verifying $incidentLabel now, including alarm context, CCTV visibility, and responder posture. '
        'I will send the next confirmed step as soon as it is verified.';
    return OnyxAgentClientDraftResult(
      telegramDraft: ClientDeliveryMessageFormatter.telegramBody(
        title: title,
        body: body,
        siteLabel: siteLabel,
        priority: _isPrioritySignal(prompt, incidentReference),
      ),
      smsDraft: ClientDeliveryMessageFormatter.smsBody(
        title: title,
        body: body,
        siteLabel: siteLabel,
        priority: _isPrioritySignal(prompt, incidentReference),
      ),
    );
  }
}

String _humanizeSiteLabel(String siteId, String clientId) {
  final site = siteId.trim();
  if (site.isNotEmpty) {
    return site;
  }
  final client = clientId.trim();
  return client.isEmpty ? 'your site' : client;
}

bool _isPrioritySignal(String prompt, String incidentReference) {
  final combined = '${prompt.trim()} ${incidentReference.trim()}'.toLowerCase();
  return combined.contains('panic') ||
      combined.contains('distress') ||
      combined.contains('intrusion') ||
      combined.contains('armed') ||
      combined.contains('priority');
}
