import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/telegram_client_router_policy.dart';

void main() {
  test(
    'prefers AI over ONYX command for gratitude plus serious-alert watch prompts',
    () {
      final result = shouldPreferTelegramAiOverOnyxCommand(
        prompt:
            'thank you for assisting. i will let you know if i need anything else. please keep me posted on any serious alerts',
        recentContextTexts: const <String>[],
      );

      expect(result, isTrue);
    },
  );

  test(
    'prefers AI over ONYX command for reassurance asks after telemetry summaries',
    () {
      final result = shouldPreferTelegramAiOverOnyxCommand(
        prompt: 'so the site is safe?',
        recentContextTexts: const <String>[
          'ONYX AI: Site activity summary: MS Vallee Residence',
          'ONYX AI: 19 guard or response-team activity signals were logged through ONYX field telemetry.',
          'ONYX AI: it is not sitting as an open incident now.',
        ],
      );

      expect(result, isTrue);
    },
  );

  test('prefers AI over ONYX command for camera reassurance prompts', () {
    final result = shouldPreferTelegramAiOverOnyxCommand(
      prompt: 'did you check cameras? is all good?',
      recentContextTexts: const <String>[
        'ONYX AI: Site activity summary: MS Vallee Residence',
      ],
    );

    expect(result, isTrue);
  });

  test(
    'prefers AI over ONYX command for conversational quick-action status asks',
    () {
      final result = shouldPreferTelegramAiOverOnyxCommand(
        prompt: "what's happening on site?",
        recentContextTexts: const <String>[],
      );

      expect(result, isTrue);
    },
  );

  test('prefers AI over ONYX command for at-site current-view asks', () {
    final result = shouldPreferTelegramAiOverOnyxCommand(
      prompt: "what's happening at site?",
      recentContextTexts: const <String>[],
    );

    expect(result, isTrue);
  });

  test('prefers AI over ONYX command for camera availability asks', () {
    final result = shouldPreferTelegramAiOverOnyxCommand(
      prompt: 'are cameras online?',
      recentContextTexts: const <String>[],
    );

    expect(result, isTrue);
  });

  test('prefers AI over ONYX command for broad status checks', () {
    final result = shouldPreferTelegramAiOverOnyxCommand(
      prompt: 'how is everything?',
      recentContextTexts: const <String>[],
    );

    expect(result, isTrue);
  });

  test('prefers AI over ONYX command for check-site-status asks', () {
    final result = shouldPreferTelegramAiOverOnyxCommand(
      prompt: 'check site status',
      recentContextTexts: const <String>[],
    );

    expect(result, isTrue);
  });

  test('prefers AI over ONYX command for site-okay reassurance asks', () {
    final result = shouldPreferTelegramAiOverOnyxCommand(
      prompt: 'is the site okay?',
      recentContextTexts: const <String>[],
    );

    expect(result, isTrue);
  });

  test('prefers AI over ONYX command for movement-status asks', () {
    final result = shouldPreferTelegramAiOverOnyxCommand(
      prompt: 'any movement?',
      recentContextTexts: const <String>[],
    );

    expect(result, isTrue);
  });

  test('prefers AI over ONYX command for current-site-view asks', () {
    final result = shouldPreferTelegramAiOverOnyxCommand(
      prompt: 'what are you seeing on site now?',
      recentContextTexts: const <String>[],
    );

    expect(result, isTrue);
  });

  test('prefers AI over ONYX command for typoed current-site-view asks', () {
    final result = shouldPreferTelegramAiOverOnyxCommand(
      prompt: 'whats happenong now?',
      recentContextTexts: const <String>[],
    );

    expect(result, isTrue);
  });

  test(
    'prefers AI over ONYX command for issue-on-site asks without prior context',
    () {
      final result = shouldPreferTelegramAiOverOnyxCommand(
        prompt: 'is there an issue on site?',
        recentContextTexts: const <String>[],
      );

      expect(result, isTrue);
    },
  );

  test(
    'prefers AI over ONYX command when the client corrects camera outage or on-site claims',
    () {
      final cameraResult = shouldPreferTelegramAiOverOnyxCommand(
        prompt: 'but my cameras are down',
        recentContextTexts: const <String>[],
      );
      final onsiteResult = shouldPreferTelegramAiOverOnyxCommand(
        prompt: 'security is NOT on site',
        recentContextTexts: const <String>[],
      );

      expect(cameraResult, isTrue);
      expect(onsiteResult, isTrue);
    },
  );

  test(
    'prefers AI over ONYX command for generic follow ups after presence verification',
    () {
      final result = shouldPreferTelegramAiOverOnyxCommand(
        prompt: 'update?',
        recentContextTexts: const <String>[
          'ONYX AI: Understood. That earlier summary refers to recorded ONYX telemetry activity, not confirmed guards physically on site now.',
          'ONYX AI: No guard is confirmed on site at MS Vallee Residence from that summary alone.',
        ],
      );

      expect(result, isTrue);
    },
  );

  test(
    'prefers AI over ONYX command for what-now follow ups after presence verification',
    () {
      final result = shouldPreferTelegramAiOverOnyxCommand(
        prompt: 'what now?',
        recentContextTexts: const <String>[
          'ONYX AI: Understood. That earlier summary refers to recorded ONYX telemetry activity, not confirmed guards physically on site now.',
          'ONYX AI: No guard is confirmed on site at MS Vallee Residence from that summary alone.',
        ],
      );

      expect(result, isTrue);
    },
  );

  test(
    'prefers AI over ONYX command for long live-update follow ups after a no-guards challenge',
    () {
      final result = shouldPreferTelegramAiOverOnyxCommand(
        prompt: 'give me an update on the site now - live update',
        recentContextTexts: const <String>[
          'Site activity summary: MS Vallee Residence',
          'there are no guards',
          'We are checking who is moving to MS Vallee Residence now. I will update you here with the next movement update.',
        ],
      );

      expect(result, isTrue);
    },
  );

  test(
    'prefers AI over ONYX command for issue-on-site asks after presence verification',
    () {
      final result = shouldPreferTelegramAiOverOnyxCommand(
        prompt: 'no response needed. is there an issue on site?',
        recentContextTexts: const <String>[
          'Understood. I do not have a confirmed guard on site at MS Vallee Residence from the scoped record I can see right now.',
          'If you want, I can verify the current response position and I will update you here with the next confirmed step.',
        ],
      );

      expect(result, isTrue);
    },
  );

  test(
    'prefers AI over ONYX command for generic follow ups after continuous visual watch updates',
    () {
      final result = shouldPreferTelegramAiOverOnyxCommand(
        prompt: 'update?',
        recentContextTexts: const <String>[
          'ONYX AI: ONYX is seeing live visual change around Front Gate through the continuous visual watch right now.',
        ],
      );

      expect(result, isTrue);
    },
  );

  test(
    'prefers AI over ONYX command for operational-picture clarification follow-ups',
    () {
      final result = shouldPreferTelegramAiOverOnyxCommand(
        prompt: 'what current operational picture?',
        recentContextTexts: const <String>[
          'ONYX: I do not have live visual confirmation at this moment, so I am grounding this on the current operational picture rather than a live camera check.',
          'ONYX: The latest confirmed activity was community reports suspicious vehicle scouting the estate entrance at 11:15.',
        ],
      );

      expect(result, isTrue);
    },
  );

  test('keeps direct read prompts on the ONYX command path', () {
    final result = shouldPreferTelegramAiOverOnyxCommand(
      prompt: 'show unresolved incidents',
      recentContextTexts: const <String>[],
    );

    expect(result, isFalse);
  });
}
