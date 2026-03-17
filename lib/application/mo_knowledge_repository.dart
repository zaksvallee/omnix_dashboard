import '../domain/intelligence/onyx_mo_record.dart';

abstract class MoKnowledgeRepository {
  List<OnyxMoRecord> readAll();

  List<OnyxMoRecord> readByEnvironmentType(String environmentType);

  List<OnyxMoRecord> readByValidationStatus(
    OnyxMoValidationStatus validationStatus,
  );

  void upsert(OnyxMoRecord record);

  void upsertAll(Iterable<OnyxMoRecord> records);
}

class InMemoryMoKnowledgeRepository implements MoKnowledgeRepository {
  final Map<String, OnyxMoRecord> _recordsById;

  InMemoryMoKnowledgeRepository({
    Map<String, OnyxMoRecord> seedRecords = const <String, OnyxMoRecord>{},
  }) : _recordsById = Map<String, OnyxMoRecord>.from(seedRecords);

  @override
  List<OnyxMoRecord> readAll() {
    final records = _recordsById.values.toList(growable: false)
      ..sort((left, right) => right.lastSeenUtc.compareTo(left.lastSeenUtc));
    return records;
  }

  @override
  List<OnyxMoRecord> readByEnvironmentType(String environmentType) {
    final normalized = environmentType.trim().toLowerCase();
    if (normalized.isEmpty) {
      return readAll();
    }
    return readAll()
        .where(
          (record) => record.environmentTypes.any(
            (value) => value.trim().toLowerCase() == normalized,
          ),
        )
        .toList(growable: false);
  }

  @override
  List<OnyxMoRecord> readByValidationStatus(
    OnyxMoValidationStatus validationStatus,
  ) {
    return readAll()
        .where((record) => record.validationStatus == validationStatus)
        .toList(growable: false);
  }

  @override
  void upsert(OnyxMoRecord record) {
    final id = record.moId.trim();
    if (id.isEmpty) {
      return;
    }
    _recordsById[id] = record;
  }

  @override
  void upsertAll(Iterable<OnyxMoRecord> records) {
    for (final record in records) {
      upsert(record);
    }
  }
}
