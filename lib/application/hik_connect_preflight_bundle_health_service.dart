import 'hik_connect_alarm_smoke_service.dart';
import 'hik_connect_bootstrap_orchestrator_service.dart';
import 'hik_connect_video_smoke_service.dart';

class HikConnectPreflightBundleHealthService {
  const HikConnectPreflightBundleHealthService();

  List<String> buildNotes({
    required String cameraPayloadPath,
    required String alarmPayloadPath,
    required String liveAddressPayloadPath,
    required String playbackPayloadPath,
    required String videoDownloadPayloadPath,
    HikConnectBootstrapRunResult? bootstrap,
    HikConnectAlarmSmokeResult? alarm,
    HikConnectVideoSmokeResult? video,
  }) {
    final notes = <String>[];

    if (cameraPayloadPath.trim().isNotEmpty &&
        bootstrap != null &&
        bootstrap.snapshot.cameraCount == 0) {
      notes.add(
        'Camera payload was present but resolved to zero cameras.',
      );
    }

    if (alarmPayloadPath.trim().isNotEmpty &&
        alarm != null &&
        alarm.totalMessages == 0) {
      notes.add(
        'Alarm payload was present but resolved to zero messages.',
      );
    }

    if (liveAddressPayloadPath.trim().isNotEmpty) {
      final primaryUrl = video?.liveAddress?.primaryUrl.trim() ?? '';
      if (primaryUrl.isEmpty) {
        notes.add(
          'Live-address payload was present but did not expose a usable stream URL.',
        );
      }
    }

    if (playbackPayloadPath.trim().isNotEmpty) {
      final playbackCount = video?.playbackCatalog?.records.length ?? 0;
      if (playbackCount == 0) {
        notes.add(
          'Playback payload was present but did not expose any record windows.',
        );
      }
    }

    if (videoDownloadPayloadPath.trim().isNotEmpty) {
      final downloadUrl = video?.downloadResult?.downloadUrl.trim() ?? '';
      if (downloadUrl.isEmpty) {
        notes.add(
          'Video-download payload was present but did not expose a download URL.',
        );
      }
    }

    return List<String>.unmodifiable(notes);
  }
}
