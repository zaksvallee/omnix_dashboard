import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/telegram_admin_command_formatter.dart';

void main() {
  test('/pollops formatter includes CCTV pilot context', () {
    final response = TelegramAdminCommandFormatter.pollOps(
      pollResult: 'Ops poll • ok 4/4',
      radioHealth: 'ok 2 • fail 0 • skip 0 • last 10:05:00 UTC',
      cctvHealth:
          'ok 3 • fail 0 • skip 0 • last 10:05:01 UTC • 1/1 appended • frigate • CCTV person detected in north_gate',
      cctvContext:
          'provider frigate • recent hardware intel 5 (6h) • intrusion 2 • line_crossing 1 • motion 1 • fr 0 • lpr 0',
      wearableHealth: 'ok 1 • fail 0 • skip 0 • last 10:05:02 UTC',
      newsHealth: 'ok 4 • fail 0 • skip 0 • last 10:05:03 UTC',
      utcStamp: '2026-03-13T10:05:10Z',
    );

    expect(response, contains('<b>CCTV:</b> ok 3 • fail 0 • skip 0'));
    expect(
      response,
      contains(
        '<b>CCTV Context:</b> provider frigate • recent hardware intel 5 (6h)',
      ),
    );
    expect(response, contains('run <code>/bridges</code>'));
  });

  test('/pollops formatter supports DVR video label', () {
    final response = TelegramAdminCommandFormatter.pollOps(
      pollResult: 'Ops poll • ok 4/4',
      radioHealth: 'ok 2 • fail 0 • skip 0 • last 10:05:00 UTC',
      cctvHealth:
          'ok 3 • fail 0 • skip 0 • last 10:05:01 UTC • 1/1 appended • hikvision-dvr • DVR vehicle detected in bay_2',
      cctvContext:
          'provider hikvision-dvr • recent video intel 5 (6h) • intrusion 2 • line_crossing 1 • motion 1 • fr 0 • lpr 1',
      wearableHealth: 'ok 1 • fail 0 • skip 0 • last 10:05:02 UTC',
      newsHealth: 'ok 4 • fail 0 • skip 0 • last 10:05:03 UTC',
      utcStamp: '2026-03-13T10:05:10Z',
      videoLabel: 'DVR',
    );

    expect(response, contains('<b>DVR:</b> ok 3 • fail 0 • skip 0'));
    expect(
      response,
      contains(
        '<b>DVR Context:</b> provider hikvision-dvr • recent video intel 5 (6h)',
      ),
    );
  });

  test('/bridges formatter includes CCTV health and recent signal summaries', () {
    final response = TelegramAdminCommandFormatter.bridges(
      telegramStatus: 'READY • admin chat bound',
      radioStatus:
          'configured • pending 0 • due 0 • deferred 0 • max-attempt 0',
      cctvStatus:
          'configured • pilot edge • provider frigate • edge edge.example.com • caps LIVE AI MONITORING',
      cctvHealth:
          'ok 2 • fail 0 • skip 0 • last 10:05:01 UTC • 1/1 appended • frigate • CCTV person detected in north_gate',
      cctvRecent:
          'recent hardware intel 5 (6h) • intrusion 2 • line_crossing 1 • motion 1 • fr 0 • lpr 0',
      wearableStatus: 'configured',
      livePollingLabel: 'enabled',
      utcStamp: '2026-03-13T10:05:10Z',
    );

    expect(
      response,
      contains(
        'CCTV: configured • pilot edge • provider frigate • edge edge.example.com',
      ),
    );
    expect(response, contains('CCTV Health: ok 2 • fail 0 • skip 0'));
    expect(
      response,
      contains(
        'CCTV Recent: recent hardware intel 5 (6h) • intrusion 2 • line_crossing 1',
      ),
    );
  });

  test('/bridges formatter supports DVR health and recent signal labels', () {
    final response = TelegramAdminCommandFormatter.bridges(
      telegramStatus: 'READY • admin chat bound',
      radioStatus:
          'configured • pending 0 • due 0 • deferred 0 • max-attempt 0',
      cctvStatus:
          'configured • pilot dvr • provider hikvision-dvr • edge dvr.example.com • caps LIVE AI MONITORING',
      cctvHealth:
          'ok 2 • fail 0 • skip 0 • last 10:05:01 UTC • 1/1 appended • hikvision-dvr • DVR vehicle detected in bay_2',
      cctvRecent:
          'recent video intel 5 (6h) • intrusion 2 • line_crossing 1 • motion 1 • fr 0 • lpr 1',
      wearableStatus: 'configured',
      livePollingLabel: 'enabled',
      utcStamp: '2026-03-13T10:05:10Z',
      videoLabel: 'DVR',
    );

    expect(
      response,
      contains(
        'DVR: configured • pilot dvr • provider hikvision-dvr • edge dvr.example.com',
      ),
    );
    expect(response, contains('DVR Health: ok 2 • fail 0 • skip 0'));
    expect(
      response,
      contains(
        'DVR Recent: recent video intel 5 (6h) • intrusion 2 • line_crossing 1',
      ),
    );
  });
}
