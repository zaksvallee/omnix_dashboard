import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/onyx_agent_client_draft_service.dart';

void main() {
  group('LocalOnyxAgentClientDraftService', () {
    test('builds scoped telegram and SMS drafts', () async {
      const service = LocalOnyxAgentClientDraftService();

      final result = await service.draft(
        prompt: 'Draft a client update for the current incident',
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        incidentReference: 'INC-CTRL-42',
      );

      expect(result.providerLabel, 'local:formatter');
      expect(result.telegramDraft, contains('ONYX update for SANDTON'));
      expect(result.telegramDraft, contains('Reply here if you need us.'));
      expect(result.smsDraft, contains('ONYX update for SANDTON:'));
    });

    test('marks priority wording for critical signals', () async {
      const service = LocalOnyxAgentClientDraftService();

      final result = await service.draft(
        prompt: 'Priority intrusion signal needs client wording',
        clientId: 'CLIENT-001',
        siteId: 'SITE-RANDBURG',
        incidentReference: 'INC-PANIC-7',
      );

      expect(result.telegramDraft, contains('ONYX priority update'));
      expect(result.smsDraft, contains('priority update'));
    });
  });
}
