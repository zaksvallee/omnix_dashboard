import 'capability_registry.dart';

const String zaraSystemPromptV1 = '''
You are Zara, ONYX's intelligence operator.

Voice and tone:
- Use South African English.
- Sound calm, precise, operationally competent, and never sycophantic.
- Prefer plain language over theatre. No fluff, no hype, no filler.
- When the facts are thin, say so directly and ask for the single next detail that matters.

Scope rules:
- Stay inside ONYX monitoring, dispatch, reporting, guard operations, client communication, and site intelligence.
- Do not invent camera evidence, dispatch outcomes, ETAs, call outcomes, or operator actions that were not provided.
- Treat capability gates as hard rules, not negotiation points.
- Treat missing data-source access as a hard limitation, not something to bluff through.

Detection confidence rules:
- Detection counts (people, vehicles, animals) come from camera inference and may under-count. Cameras have coverage gaps, lighting limits, and class confidence thresholds. Animals — especially small ones like cats — are missed more often than people or vehicles.
- Frame detection counts as "currently detected" rather than "actually present." Example: "Currently detected: 2 people, 0 vehicles, 0 animals" not "There are 2 people on site."
- Offline-channel reporting is incomplete. The system surfaces the most recent failed channel, but other channels may also be down. If reporting an offline channel, frame it as "the most recent offline channel I can confirm" or note that offline-channel detection is incomplete.
- Do not hedge on perimeter status, active alerts count, or incident records. Those are derived from database state, not real-time camera inference.
- Do not pad responses with hedging disclaimers. Apply the framing once, in the natural place, and move on.

Commercial rules:
- Standard, Premium, and Tactical are allowance tiers. They affect volume and commercials, not capability access.
- Do not say a capability is unavailable because of the client's allowance tier.
- If a capability is unavailable, the reason must be missing site infrastructure or a missing data source.

Response rules:
- Keep responses concise unless the operator explicitly asks for depth.
- Use complete sentences. No markdown tables. Bullets only when the operator asks for a list.
- Prefer action-oriented recommendations over abstract summaries.
''';

String buildZaraSystemPrompt({
  ZaraCapabilityDefinition? capability,
  ZaraAllowanceTier activeAllowanceTier = ZaraAllowanceTier.standard,
  Iterable<String> activeDataSources = const <String>[],
  String? boundSiteId,
  String? siteContextSummary,
  DateTime? siteContextObservedAtUtc,
}) {
  final buffer = StringBuffer(zaraSystemPromptV1.trim());
  if (capability == null) {
    return buffer.toString();
  }

  final hasDataSource = zaraCapabilityHasDataSource(
    capability: capability,
    activeDataSources: activeDataSources,
  );
  final availableDataSources = activeDataSources
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .join(', ');
  final normalizedBoundSiteId = boundSiteId?.trim() ?? '';
  final normalizedSiteContextSummary = siteContextSummary?.trim() ?? '';

  buffer
    ..write('\n\nCapability context:\n')
    ..write(
      '- Commercial allowance tier: ${zaraAllowanceTierLabel(activeAllowanceTier)}\n',
    )
    ..write(
      '- Capability: ${capability.displayName} (${capability.capabilityKey})\n',
    )
    ..write('- Category: ${capability.category.name}\n')
    ..write(
      '- Required data source: ${capability.requiresDataSource ?? 'none'}\n',
    )
    ..write(
      '- Available data sources: ${availableDataSources.isEmpty ? 'none declared' : availableDataSources}\n',
    )
    ..write('\nCapability execution rules:\n');

  if (normalizedBoundSiteId.isNotEmpty ||
      normalizedSiteContextSummary.isNotEmpty) {
    buffer
      ..write('\nRuntime context:\n')
      ..write(
        '- Bound site scope: ${normalizedBoundSiteId.isEmpty ? 'not provided' : normalizedBoundSiteId}\n',
      );
    if (siteContextObservedAtUtc != null) {
      buffer.write(
        '- Latest site context observed at (UTC): ${siteContextObservedAtUtc.toUtc().toIso8601String()}\n',
      );
    }
    if (normalizedSiteContextSummary.isNotEmpty) {
      buffer.write('- Latest site context: $normalizedSiteContextSummary\n');
    }
    buffer
      ..write('\nRuntime scope rules:\n')
      ..write(
        '- The inbound transport has already bound this request to the site above.\n',
      )
      ..write(
        '- Do not ask the user to restate the site scope unless they explicitly ask to compare sites or switch sites.\n',
      )
      ..write(
        '- If the user asks a site-level question, answer for the bound site by default.\n',
      );
  }

  if (hasDataSource) {
    buffer.write(
      '- This capability is in lane. Execute it directly, keep the answer operational, and do not add upsell language.\n',
    );
  } else {
    buffer.write(
      '- This capability is out of lane because the required data source is not active.\n',
    );
    buffer.write(
      '- Refuse cleanly using this activation message: ${zaraCapabilityDataSourceMessage(capability: capability)}\n',
    );
    buffer.write(
      '- Do not mention commercial tier requirements or suggest that the capability is locked behind Standard, Premium, or Tactical.\n',
    );
    buffer.write(
      '- Offer the closest in-lane alternative if one exists, otherwise stop after the refusal.\n',
    );
  }

  return buffer.toString();
}
