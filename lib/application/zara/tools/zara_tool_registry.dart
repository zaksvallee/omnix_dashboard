import '../llm_provider.dart';
import 'zara_tool.dart';

class ZaraToolRegistry {
  final Map<String, ZaraTool> _toolsByName;
  final Map<String, List<String>> _capabilityToToolNames;

  const ZaraToolRegistry({
    required Map<String, ZaraTool> toolsByName,
    required Map<String, List<String>> capabilityToToolNames,
  }) : _toolsByName = toolsByName,
       _capabilityToToolNames = capabilityToToolNames;

  List<LlmTool> definitionsForCapability(String capabilityKey) {
    final names = _capabilityToToolNames[capabilityKey] ?? const <String>[];
    return names
        .map((name) => _toolsByName[name]?.definition)
        .whereType<LlmTool>()
        .toList(growable: false);
  }

  ZaraTool? toolByName(String name) => _toolsByName[name];

  bool capabilityHasTools(String capabilityKey) {
    final names = _capabilityToToolNames[capabilityKey];
    return names != null && names.isNotEmpty;
  }
}

const ZaraToolRegistry emptyZaraToolRegistry = ZaraToolRegistry(
  toolsByName: <String, ZaraTool>{},
  capabilityToToolNames: <String, List<String>>{},
);
