import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/telegram_client_prompt_signals.dart';

void main() {
  test('shared prompt signals recognize broad site-status checks', () {
    expect(asksForTelegramClientBroadStatusCheck('how is everything'), isTrue);
    expect(asksForTelegramClientBroadStatusCheck('hows everything'), isTrue);
    expect(asksForTelegramClientBroadStatusCheck('everything okay'), isTrue);
    expect(asksForTelegramClientBroadStatusCheck('is the site okay?'), isTrue);
    expect(asksForTelegramClientBroadStatusCheck('check site status'), isTrue);
    expect(asksForTelegramClientBroadStatusCheck('is my site secure?'), isFalse);
  });

  test('shared prompt signals recognize current site-view asks', () {
    expect(
      asksForTelegramClientCurrentSiteView('whats happening on site'),
      isTrue,
    );
    expect(
      asksForTelegramClientCurrentSiteView('whats happening at site?'),
      isTrue,
    );
    expect(
      asksForTelegramClientCurrentSiteView('what are you seeing on site now'),
      isTrue,
    );
    expect(
      asksForTelegramClientCurrentSiteView('whats happenong now?'),
      isTrue,
    );
    expect(asksForTelegramClientCurrentSiteView('how is everything'), isFalse);
  });

  test('shared prompt signals group broad status and current site-view asks', () {
    expect(
      asksForTelegramClientBroadStatusOrCurrentSiteView('how is everything'),
      isTrue,
    );
    expect(
      asksForTelegramClientBroadStatusOrCurrentSiteView('is the site okay?'),
      isTrue,
    );
    expect(
      asksForTelegramClientBroadStatusOrCurrentSiteView('check site status'),
      isTrue,
    );
    expect(
      asksForTelegramClientBroadStatusOrCurrentSiteView(
        'whats happenong now?',
      ),
      isTrue,
    );
    expect(
      asksForTelegramClientBroadStatusOrCurrentSiteView(
        'whats happening at site?',
      ),
      isTrue,
    );
    expect(
      asksForTelegramClientBroadStatusOrCurrentSiteView('any movement'),
      isFalse,
    );
  });

  test('shared prompt signals recognize movement and site-issue asks', () {
    expect(asksForTelegramClientMovementCheck('any movement'), isTrue);
    expect(
      asksForTelegramClientMovementCheck('is there any movement detected?'),
      isTrue,
    );
    expect(
      asksForTelegramClientCurrentSiteIssueCheck('is there an issue on site'),
      isTrue,
    );
    expect(
      asksForTelegramClientCurrentSiteIssueCheck('is there any problem on site?'),
      isTrue,
    );
  });

  test(
    'shared prompt signals recognize broad reassurance and generic follow-up asks',
    () {
      expect(
        asksForTelegramClientBroadReassuranceCheck('is the site safe?'),
        isTrue,
      );
      expect(
        asksForTelegramClientBroadReassuranceCheck('you sure?'),
        isTrue,
      );
      expect(asksForTelegramClientGenericStatusFollowUp('what now?'), isTrue);
      expect(
        asksForTelegramClientGenericStatusFollowUp("what's the update?"),
        isTrue,
      );
      expect(
        asksForTelegramClientGenericStatusFollowUp('check now'),
        isTrue,
      );
      expect(
        asksForTelegramClientGenericStatusFollowUp('any movement?'),
        isFalse,
      );
    },
  );
}
