import '../llm_provider.dart';

class ZaraToolContext {
  final String? clientId;
  final String? siteId;

  const ZaraToolContext({this.clientId, this.siteId});
}

class ZaraToolExecutionResult {
  final Map<String, Object?> output;
  final bool isError;

  const ZaraToolExecutionResult({required this.output, this.isError = false});

  factory ZaraToolExecutionResult.error(String message) {
    return ZaraToolExecutionResult(
      output: <String, Object?>{'error': message},
      isError: true,
    );
  }
}

abstract class ZaraTool {
  LlmTool get definition;

  Future<ZaraToolExecutionResult> execute(
    Map<String, Object?> input,
    ZaraToolContext context,
  );
}
