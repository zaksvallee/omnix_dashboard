import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/dispatch_snapshot_file_service.dart';

void main() {
  test('DispatchSnapshotFileService uses the non-web stub in tests', () async {
    const service = DispatchSnapshotFileService();

    expect(service.supported, isFalse);
    await service.downloadJsonFile(
      filename: 'onyx_snapshot.json',
      contents: '{"version":1}',
    );
    expect(await service.pickJsonFile(), isNull);
  });
}
