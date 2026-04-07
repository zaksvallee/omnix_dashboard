import 'dart:convert';
import 'dart:io';

import 'hik_connect_alarm_batch.dart';

class HikConnectAlarmPayloadLoader {
  const HikConnectAlarmPayloadLoader();

  Future<HikConnectAlarmBatch> loadBatchFromFile(String path) async {
    final trimmedPath = path.trim();
    if (trimmedPath.isEmpty) {
      return const HikConnectAlarmBatch(batchId: '', messages: <HikConnectAlarmMessage>[]);
    }
    final raw = await File(trimmedPath).readAsString();
    return loadBatchFromJson(raw);
  }

  HikConnectAlarmBatch loadBatchFromJson(String rawJson) {
    final trimmed = rawJson.trim();
    if (trimmed.isEmpty) {
      return const HikConnectAlarmBatch(batchId: '', messages: <HikConnectAlarmMessage>[]);
    }
    final decoded = jsonDecode(trimmed);
    if (decoded is List) {
      return HikConnectAlarmBatch.fromApiResponse(
        <String, Object?>{
          'data': <String, Object?>{
            'batchId': '',
            'alarmMsg': decoded,
          },
        },
      );
    }
    if (decoded is Map) {
      final map = decoded.map(
        (key, value) => MapEntry(key.toString(), value as Object?),
      );
      if (map.containsKey('data')) {
        return HikConnectAlarmBatch.fromApiResponse(map);
      }
      if (map.containsKey('alarmMsg')) {
        return HikConnectAlarmBatch.fromApiResponse(
          <String, Object?>{'data': map},
        );
      }
      if (map['messages'] is List) {
        return HikConnectAlarmBatch.fromApiResponse(
          <String, Object?>{
            'data': <String, Object?>{
              'batchId': (map['batchId'] ?? '').toString(),
              'alarmMsg': map['messages'],
            },
          },
        );
      }
    }
    return const HikConnectAlarmBatch(batchId: '', messages: <HikConnectAlarmMessage>[]);
  }
}
