import 'dart:convert';
import 'dart:io';

class HikConnectVideoPayloadLoader {
  const HikConnectVideoPayloadLoader();

  Future<Map<String, Object?>> loadResponseFromFile(String path) async {
    final trimmedPath = path.trim();
    if (trimmedPath.isEmpty) {
      return const <String, Object?>{};
    }
    final raw = await File(trimmedPath).readAsString();
    return loadResponseFromJson(raw);
  }

  Map<String, Object?> loadResponseFromJson(String rawJson) {
    final trimmed = rawJson.trim();
    if (trimmed.isEmpty) {
      return const <String, Object?>{};
    }
    final decoded = jsonDecode(trimmed);
    if (decoded is Map<String, Object?>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value as Object?),
      );
    }
    return const <String, Object?>{};
  }
}
