class ClientCommsDeliveryReadiness {
  final String smsFallbackLabel;
  final bool smsFallbackReady;
  final bool smsFallbackEligibleNow;
  final String voiceReadinessLabel;
  final bool hasPhoneContact;
  final String? detail;

  const ClientCommsDeliveryReadiness({
    this.smsFallbackLabel = 'SMS not ready',
    this.smsFallbackReady = false,
    this.smsFallbackEligibleNow = false,
    this.voiceReadinessLabel = 'VoIP staging',
    this.hasPhoneContact = false,
    this.detail,
  });
}

class ClientCommsDeliveryPolicyService {
  const ClientCommsDeliveryPolicyService();

  ClientCommsDeliveryReadiness evaluate({
    required bool telegramBridgeConfigured,
    required int telegramTargetCount,
    required String telegramHealthLabel,
    required bool telegramFallbackActive,
    bool telegramEndpointMappingAmbiguous = false,
    required bool smsProviderConfigured,
    required int phoneContactCount,
    required bool voipProviderConfigured,
  }) {
    final hasPhoneContact = phoneContactCount > 0;
    final normalizedTelegramHealth = telegramHealthLabel.trim().toLowerCase();
    final telegramNeedsHelp =
        telegramFallbackActive ||
        normalizedTelegramHealth == 'blocked' ||
        normalizedTelegramHealth == 'degraded' ||
        normalizedTelegramHealth == 'no-target';
    final smsFallbackReady = smsProviderConfigured && hasPhoneContact;
    final smsFallbackEligibleNow = smsFallbackReady && telegramNeedsHelp;
    final smsFallbackLabel = switch ((
      smsFallbackEligibleNow,
      smsFallbackReady,
      smsProviderConfigured,
      hasPhoneContact,
    )) {
      (true, _, _, _) => 'SMS fallback ready',
      (false, true, _, _) => 'SMS standby',
      (_, _, false, true) => 'SMS provider pending',
      (_, _, true, false) => 'SMS contact pending',
      _ => 'SMS not ready',
    };
    final voiceReadinessLabel = switch ((
      voipProviderConfigured,
      hasPhoneContact,
    )) {
      (true, true) => 'VoIP ready',
      (true, false) => 'VoIP contact pending',
      (false, true) => 'VoIP staged',
      _ => 'VoIP staging',
    };

    final detail = _detail(
      telegramBridgeConfigured: telegramBridgeConfigured,
      telegramTargetCount: telegramTargetCount,
      telegramEndpointMappingAmbiguous: telegramEndpointMappingAmbiguous,
      smsFallbackReady: smsFallbackReady,
      smsFallbackEligibleNow: smsFallbackEligibleNow,
      hasPhoneContact: hasPhoneContact,
      smsProviderConfigured: smsProviderConfigured,
      voipProviderConfigured: voipProviderConfigured,
    );

    return ClientCommsDeliveryReadiness(
      smsFallbackLabel: smsFallbackLabel,
      smsFallbackReady: smsFallbackReady,
      smsFallbackEligibleNow: smsFallbackEligibleNow,
      voiceReadinessLabel: voiceReadinessLabel,
      hasPhoneContact: hasPhoneContact,
      detail: detail,
    );
  }

  String _detail({
    required bool telegramBridgeConfigured,
    required int telegramTargetCount,
    required bool telegramEndpointMappingAmbiguous,
    required bool smsFallbackReady,
    required bool smsFallbackEligibleNow,
    required bool hasPhoneContact,
    required bool smsProviderConfigured,
    required bool voipProviderConfigured,
  }) {
    if (!telegramBridgeConfigured) {
      return 'Telegram bridge is disabled, so ONYX is limited to local desk updates.';
    }
    if (telegramEndpointMappingAmbiguous) {
      return 'Telegram target mapping is ambiguous for this scope. Resolve duplicate Telegram endpoint rows before treating this lane as ready.';
    }
    if (telegramTargetCount <= 0) {
      return 'Telegram is primary, but this scope still needs an active bridge target.';
    }
    if (smsFallbackEligibleNow) {
      return 'Telegram needs help here, and SMS fallback can take over once the adapter is switched on.';
    }
    if (smsFallbackReady) {
      return 'Telegram remains primary for this scope; SMS only steps in after confirmed Telegram trouble.';
    }
    if (hasPhoneContact && !smsProviderConfigured && !voipProviderConfigured) {
      return 'Phone contact is present, but SMS and VoIP providers still need wiring.';
    }
    if (hasPhoneContact && !smsProviderConfigured) {
      return 'Phone contact is present. Telegram stays primary until SMS fallback is wired.';
    }
    if (!hasPhoneContact) {
      return 'Telegram is primary, but this scope still needs a verified phone contact for fallback and voice.';
    }
    return 'Telegram stays primary while fallback channels stay on standby.';
  }
}
