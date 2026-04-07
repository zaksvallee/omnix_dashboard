import '../domain/intelligence/intel_ingestion.dart';
import 'dvr_ingest_contract.dart';
import 'hik_connect_alarm_batch.dart';

class HikConnectAlarmSmokeResult {
  final HikConnectAlarmBatch batch;
  final List<NormalizedIntelRecord> normalizedRecords;
  final int droppedMessages;

  const HikConnectAlarmSmokeResult({
    required this.batch,
    required this.normalizedRecords,
    required this.droppedMessages,
  });

  int get totalMessages => batch.messages.length;

  String get summaryLabel =>
      '${normalizedRecords.length}/${batch.messages.length} normalized';
}

class HikConnectAlarmSmokeService {
  const HikConnectAlarmSmokeService();

  HikConnectAlarmSmokeResult evaluateBatch(
    HikConnectAlarmBatch batch, {
    required Uri baseUri,
    required String clientId,
    required String regionId,
    required String siteId,
  }) {
    final normalizer = DvrFixtureContractNormalizer(
      profile: DvrProviderProfile.hikConnectOpenApi,
      baseUri: baseUri,
    );
    final records = <NormalizedIntelRecord>[];
    for (final message in batch.messages) {
      final contract = normalizer.normalize(
        payload: message.toPayloadMap(),
        clientId: clientId,
        regionId: regionId,
        siteId: siteId,
      );
      if (contract == null) {
        continue;
      }
      records.add(contract.toNormalizedIntelRecord());
    }
    return HikConnectAlarmSmokeResult(
      batch: batch,
      normalizedRecords: List<NormalizedIntelRecord>.unmodifiable(records),
      droppedMessages: batch.messages.length - records.length,
    );
  }
}
