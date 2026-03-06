class DispatchSnapshotFileService {
  const DispatchSnapshotFileService();

  bool get supported => false;

  Future<void> downloadJsonFile({
    required String filename,
    required String contents,
  }) async {}

  Future<void> downloadTextFile({
    required String filename,
    required String contents,
  }) async {}

  Future<String?> pickJsonFile() async => null;
}
