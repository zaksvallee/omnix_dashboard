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

Refusal and gating rules:
- If the requested capability is outside the active client tier, refuse warmly and specifically.
- If the requested capability requires a data source that is not available, say exactly which data source is missing.
- Offer the next valid path: continue in-lane, request a feature sheet, or suggest a sales call when Tactical/Premium is required.
- Never pretend a gated capability is "almost done" or "coming soon".

Response rules:
- Keep responses concise unless the operator explicitly asks for depth.
- Use complete sentences. No markdown tables. Bullets only when the operator asks for a list.
- Prefer action-oriented recommendations over abstract summaries.
''';

String buildZaraSystemPrompt({
  ZaraCapabilityDefinition? capability,
  ZaraCapabilityTier activeTier = ZaraCapabilityTier.standard,
  Iterable<String> activeDataSources = const <String>[],
}) {
  final buffer = StringBuffer(zaraSystemPromptV1.trim());
  if (capability == null) {
    return buffer.toString();
  }

  final hasTierAccess = zaraTierAllowsCapability(
    activeTier: activeTier,
    capability: capability,
  );
  final hasDataSource = zaraCapabilityHasDataSource(
    capability: capability,
    activeDataSources: activeDataSources,
  );
  final availableDataSources = activeDataSources
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .join(', ');

  buffer
    ..write('\n\nCapability context:\n')
    ..write('- Active tier: ${zaraTierLabel(activeTier)}\n')
    ..write(
      '- Capability: ${capability.displayName} (${capability.capabilityKey})\n',
    )
    ..write('- Category: ${capability.category.name}\n')
    ..write('- Required tier: ${zaraTierLabel(capability.minTier)}\n')
    ..write(
      '- Required data source: ${capability.requiresDataSource ?? 'none'}\n',
    )
    ..write(
      '- Available data sources: ${availableDataSources.isEmpty ? 'none declared' : availableDataSources}\n',
    )
    ..write('\nCapability execution rules:\n');

  if (hasTierAccess && hasDataSource) {
    buffer.write(
      '- This capability is in lane. Execute it directly, keep the answer operational, and do not add upsell language.\n',
    );
  } else {
    buffer.write(
      '- This capability is out of lane. Refuse cleanly using the product language below and do not fake completion.\n',
    );
    buffer.write('- Upsell message: ${capability.upsellBlurb}\n');
    buffer.write('- Upsell CTA: ${capability.upsellCta}\n');
    if (!hasTierAccess) {
      buffer.write(
        '- State that ${zaraTierLabel(capability.minTier)} is required for this capability.\n',
      );
    }
    if (!hasDataSource) {
      buffer.write(
        '- State that the required data source is currently unavailable: ${capability.requiresDataSource}.\n',
      );
    }
    buffer.write(
      '- Offer the closest in-lane alternative if one exists, otherwise stop after the refusal.\n',
    );
  }

  return buffer.toString();
}
