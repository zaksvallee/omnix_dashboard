import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/client_comms_delivery_policy_service.dart';

void main() {
  const service = ClientCommsDeliveryPolicyService();

  test('keeps sms on standby while telegram is healthy', () {
    final readiness = service.evaluate(
      telegramBridgeConfigured: true,
      telegramTargetCount: 1,
      telegramHealthLabel: 'ok',
      telegramFallbackActive: false,
      smsProviderConfigured: true,
      phoneContactCount: 1,
      voipProviderConfigured: false,
    );

    expect(readiness.smsFallbackLabel, 'SMS standby');
    expect(readiness.smsFallbackReady, isTrue);
    expect(readiness.smsFallbackEligibleNow, isFalse);
    expect(readiness.voiceReadinessLabel, 'VoIP staged');
    expect(readiness.detail, contains('SMS only steps in'));
  });

  test('marks sms fallback ready only when telegram is in trouble', () {
    final readiness = service.evaluate(
      telegramBridgeConfigured: true,
      telegramTargetCount: 1,
      telegramHealthLabel: 'blocked',
      telegramFallbackActive: true,
      smsProviderConfigured: true,
      phoneContactCount: 2,
      voipProviderConfigured: true,
    );

    expect(readiness.smsFallbackLabel, 'SMS fallback ready');
    expect(readiness.smsFallbackReady, isTrue);
    expect(readiness.smsFallbackEligibleNow, isTrue);
    expect(readiness.voiceReadinessLabel, 'VoIP ready');
    expect(readiness.detail, contains('Telegram needs help'));
  });

  test('calls out missing phone contacts even when providers exist', () {
    final readiness = service.evaluate(
      telegramBridgeConfigured: true,
      telegramTargetCount: 1,
      telegramHealthLabel: 'ok',
      telegramFallbackActive: false,
      smsProviderConfigured: true,
      phoneContactCount: 0,
      voipProviderConfigured: true,
    );

    expect(readiness.smsFallbackLabel, 'SMS contact pending');
    expect(readiness.smsFallbackReady, isFalse);
    expect(readiness.voiceReadinessLabel, 'VoIP contact pending');
    expect(readiness.detail, contains('verified phone contact'));
  });

  test('calls out ambiguous telegram endpoint mappings as not ready', () {
    final readiness = service.evaluate(
      telegramBridgeConfigured: true,
      telegramTargetCount: 1,
      telegramHealthLabel: 'ok',
      telegramFallbackActive: false,
      telegramEndpointMappingAmbiguous: true,
      smsProviderConfigured: true,
      phoneContactCount: 1,
      voipProviderConfigured: true,
    );

    expect(readiness.smsFallbackLabel, 'SMS standby');
    expect(readiness.smsFallbackEligibleNow, isFalse);
    expect(readiness.detail, contains('ambiguous'));
    expect(readiness.detail, contains('duplicate Telegram endpoint rows'));
  });
}
