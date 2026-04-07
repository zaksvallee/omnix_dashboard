import 'dart:convert';
import 'dart:io';

import 'hik_connect_camera_catalog.dart';

class HikConnectCameraPayloadLoader {
  const HikConnectCameraPayloadLoader();

  Future<List<HikConnectCameraCatalogPage>> loadPagesFromFile(
    String path, {
    Map<String, String> cameraLabels = const <String, String>{},
  }) async {
    final trimmedPath = path.trim();
    if (trimmedPath.isEmpty) {
      return const <HikConnectCameraCatalogPage>[];
    }
    final raw = await File(trimmedPath).readAsString();
    return loadPagesFromJson(raw, cameraLabels: cameraLabels);
  }

  List<HikConnectCameraCatalogPage> loadPagesFromJson(
    String rawJson, {
    Map<String, String> cameraLabels = const <String, String>{},
  }) {
    final trimmed = rawJson.trim();
    if (trimmed.isEmpty) {
      return const <HikConnectCameraCatalogPage>[];
    }
    final decoded = jsonDecode(trimmed);
    final pagePayloads = switch (decoded) {
      List value => value,
      Map value => value['pages'] is List
          ? value['pages'] as List
          : <Object?>[value],
      _ => const <Object?>[],
    };

    final pages = <HikConnectCameraCatalogPage>[];
    for (final entry in pagePayloads.whereType<Map>()) {
      final response = entry.map(
        (key, value) => MapEntry(key.toString(), value as Object?),
      );
      pages.add(
        HikConnectCameraCatalogPage.fromApiResponse(
          response,
          cameraLabels: cameraLabels,
        ),
      );
    }
    return List<HikConnectCameraCatalogPage>.unmodifiable(pages);
  }
}
