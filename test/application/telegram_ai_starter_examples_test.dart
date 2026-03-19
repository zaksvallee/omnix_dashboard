import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/monitoring_shift_notification_service.dart';
import 'package:omnix_dashboard/application/telegram_ai_starter_examples.dart';

void main() {
  const valleeProfile = MonitoringSiteProfile(
    siteName: 'MS Vallee Residence',
    clientName: 'Muhammed Vallee',
  );
  const towerProfile = MonitoringSiteProfile(
    siteName: 'Sandton Tower',
    clientName: 'Sandton Operations',
  );

  test(
    'starter examples use reassuring residential wording for worried lanes',
    () {
      final examples = telegramAiStarterReplyExamplesForScope(
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        siteProfile: valleeProfile,
        messageText: 'I am scared, what is happening?',
      );

      expect(examples, isNotEmpty);
      expect(examples.first, contains('You are not alone.'));
      expect(examples.first, contains('MS Vallee Residence'));
    },
  );

  test('starter examples use enterprise wording for access issues', () {
    final examples = telegramAiStarterReplyExamplesForScope(
      clientId: 'CLIENT-SANDTON',
      siteId: 'SITE-SANDTON-TOWER',
      siteProfile: towerProfile,
      messageText: 'The gate is not opening',
    );

    expect(examples, isNotEmpty);
    expect(examples.first, contains('checking access at Sandton Tower now'));
    expect(examples.first, contains('next confirmed step'));
    expect(examples.first, isNot(contains('You are not alone.')));
  });

  test('starter examples use camera-check wording for visual requests', () {
    final examples = telegramAiStarterReplyExamplesForScope(
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      siteProfile: valleeProfile,
      messageText: 'What do you see on camera in daylight?',
    );

    expect(examples, isNotEmpty);
    expect(examples.first, contains('checking cameras and daylight around'));
    expect(examples.first, contains('next confirmed camera check'));
  });

  test('starter examples switch to on-site wording when responder is there', () {
    final examples = telegramAiStarterReplyExamplesForScope(
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      siteProfile: valleeProfile,
      messageText: 'Any update?',
      recentConversationTurns: const [
        'Responder On Site • partner_dispatch • ONYX AI: Responder on site at MS Vallee Residence.',
      ],
    );

    expect(examples, isNotEmpty);
    expect(examples.first, contains('Security is already on site'));
    expect(examples.first, contains('next on-site step'));
  });

  test('starter examples switch to closure wording after resolution', () {
    final examples = telegramAiStarterReplyExamplesForScope(
      clientId: 'CLIENT-SANDTON',
      siteId: 'SITE-SANDTON-TOWER',
      siteProfile: towerProfile,
      messageText: 'Thanks',
      recentConversationTurns: const [
        'Incident Resolved • onyx_monitoring • ONYX AI: Incident resolved at Sandton Tower.',
      ],
    );

    expect(examples, isNotEmpty);
    expect(examples.first, contains('You are welcome.'));
    expect(examples.first, contains('Sandton Tower is secure right now.'));
    expect(examples.first, isNot(contains('next confirmed step')));
  });

  test(
    'preferred examples keep two starters when no approved rewrites exist',
    () {
      final examples = telegramAiPreferredReplyExamplesForScope(
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        siteProfile: valleeProfile,
        messageText: 'I am scared, what is happening?',
        recentApprovedReplyExamples: const [
          'We are checking MS Vallee Residence now. I will update you here with the next confirmed step.',
        ],
      );

      expect(examples, hasLength(3));
      expect(examples.first, contains('You are not alone.'));
      expect(examples[1], contains('staying close on this'));
    },
  );

  test('preferred examples keep one starter when one approved rewrite exists', () {
    final examples = telegramAiPreferredReplyExamplesForScope(
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      siteProfile: valleeProfile,
      messageText: 'I am scared, what is happening?',
      approvedRewriteExamples: const [
        TelegramAiLearnedReplyExample(
          text:
              'We are checking MS Vallee Residence now. I will share the next confirmed step here when it is confirmed.',
        ),
      ],
      recentApprovedReplyExamples: const [
        'We are checking MS Vallee Residence now. I will update you here with the next confirmed step.',
      ],
    );

    expect(examples.first, contains('I will share the next confirmed step'));
    expect(
      examples.where((entry) => entry.contains('You are not alone.')),
      hasLength(1),
    );
  });

  test('preferred examples stop using starters once two approved rewrites exist', () {
    final examples = telegramAiPreferredReplyExamplesForScope(
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      siteProfile: valleeProfile,
      messageText: 'I am scared, what is happening?',
      approvedRewriteExamples: const [
        TelegramAiLearnedReplyExample(
          text:
              'We are checking MS Vallee Residence now. I will share the next confirmed step here when it is confirmed.',
        ),
        TelegramAiLearnedReplyExample(
          text:
              'You are not alone. We are checking MS Vallee Residence now and will keep this lane updated.',
        ),
      ],
      recentApprovedReplyExamples: const [
        'We are checking MS Vallee Residence now. I will update you here with the next confirmed step.',
      ],
    );

    expect(examples, hasLength(3));
    expect(
      examples,
      isNot(
        contains(
          'We are checking MS Vallee Residence now and staying close on this. I will update you here with the next confirmed step.',
        ),
      ),
    );
    expect(
      examples,
      isNot(
        contains(
          'You are not alone. We are checking MS Vallee Residence now. I will update you here with the next confirmed step.',
        ),
      ),
    );
  });

  test('preferred examples rank worried approvals above unrelated approvals', () {
    final examples = telegramAiPreferredReplyExamplesForScope(
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      siteProfile: valleeProfile,
      messageText: 'I am scared, what is happening?',
      approvedRewriteExamples: const [
        TelegramAiLearnedReplyExample(
          text:
              'We are checking access at MS Vallee Residence now. I will update you here with the next confirmed step.',
        ),
        TelegramAiLearnedReplyExample(
          text:
              'You are not alone. We are checking MS Vallee Residence now and will keep this lane updated.',
        ),
      ],
    );

    expect(
      examples.first,
      'You are not alone. We are checking MS Vallee Residence now and will keep this lane updated.',
    );
  });

  test('preferred examples rank closure approvals above active approvals', () {
    final examples = telegramAiPreferredReplyExamplesForScope(
      clientId: 'CLIENT-SANDTON',
      siteId: 'SITE-SANDTON-TOWER',
      siteProfile: towerProfile,
      messageText: 'Thanks',
      recentConversationTurns: const [
        'Incident Resolved • onyx_monitoring • ONYX AI: Incident resolved at Sandton Tower.',
      ],
      approvedRewriteExamples: const [
        TelegramAiLearnedReplyExample(
          text:
              'We are checking Sandton Tower now. I will update you here with the next confirmed step.',
        ),
        TelegramAiLearnedReplyExample(
          text:
              'Sandton Tower is secure right now. If anything changes again, message here immediately and we will reopen the incident straight away.',
        ),
      ],
    );

    expect(
      examples.first,
      'Sandton Tower is secure right now. If anything changes again, message here immediately and we will reopen the incident straight away.',
    );
  });

  test(
    'preferred examples favor higher approval counts when tone fit is similar',
    () {
      final examples = telegramAiPreferredReplyExamplesForScope(
        clientId: 'CLIENT-SANDTON',
        siteId: 'SITE-SANDTON-TOWER',
        siteProfile: towerProfile,
        messageText: 'Any update?',
        approvedRewriteExamples: const [
          TelegramAiLearnedReplyExample(
            text:
                'We are checking Sandton Tower now. I will update you here with the next confirmed step.',
            approvalCount: 1,
          ),
          TelegramAiLearnedReplyExample(
            text:
                'We are checking Sandton Tower now and taking this seriously. I will update you here with the next confirmed step.',
            approvalCount: 4,
          ),
        ],
      );

      expect(
        examples.first,
        'We are checking Sandton Tower now and taking this seriously. I will update you here with the next confirmed step.',
      );
    },
  );

  test('preferred examples favor more recently used learned replies', () {
    final nowUtc = DateTime.now().toUtc();
    final examples = telegramAiPreferredReplyExamplesForScope(
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      siteProfile: valleeProfile,
      messageText: 'I am scared, what is happening?',
      approvedRewriteExamples: [
        TelegramAiLearnedReplyExample(
          text:
              'You are not alone. We are checking MS Vallee Residence now and will keep this lane updated.',
          approvalCount: 2,
          lastUsedAtUtc: nowUtc.subtract(const Duration(days: 20)),
        ),
        TelegramAiLearnedReplyExample(
          text:
              'You are not alone. We are checking MS Vallee Residence now. I will update you here with the next confirmed step.',
          approvalCount: 2,
          lastUsedAtUtc: nowUtc.subtract(const Duration(hours: 2)),
        ),
      ],
    );

    expect(
      examples.first,
      'You are not alone. We are checking MS Vallee Residence now. I will update you here with the next confirmed step.',
    );
  });
}
