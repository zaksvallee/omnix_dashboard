import 'dart:io';

class EventLogRotationGuard {
  final int maxBytes;

  const EventLogRotationGuard({
    this.maxBytes = 5 * 1024 * 1024, // 5MB default
  });

  Future<void> enforce(String filePath) async {
    final file = File(filePath);

    if (!await file.exists()) return;

    final size = await file.length();

    if (size <= maxBytes) return;

    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final rotatedPath = "$filePath.$timestamp.bak";

    await file.rename(rotatedPath);
    await File(filePath).writeAsString("[]");
  }
}
