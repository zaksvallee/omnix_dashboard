import 'hik_connect_alarm_smoke_service.dart';
import 'hik_connect_bootstrap_orchestrator_service.dart';
import 'hik_connect_video_smoke_service.dart';

class HikConnectPreflightNextStepService {
  const HikConnectPreflightNextStepService();

  List<String> buildSteps({
    required List<Map<String, Object?>> payloadInventory,
    HikConnectBootstrapRunResult? bootstrap,
    HikConnectAlarmSmokeResult? alarm,
    HikConnectVideoSmokeResult? video,
  }) {
    final steps = <String>[];

    for (final entry in payloadInventory) {
      final key = (entry['key'] ?? '').toString().trim();
      final status = (entry['status'] ?? '').toString().trim();
      final path = (entry['path'] ?? '').toString().trim();
      if (status == 'unset') {
        final step = _missingPayloadStep(key);
        if (step != null) {
          steps.add(step);
        }
      } else if (status == 'configured_missing') {
        final label = _labelForKey(key);
        if (path.isNotEmpty) {
          steps.add(
            'Provide the $label payload at $path or update the bundle path.',
          );
        } else {
          steps.add('Provide the $label payload or update the bundle path.');
        }
      }
    }

    if (bootstrap != null) {
      if (!bootstrap.readyForPilot) {
        if (bootstrap.snapshot.deviceSerials.length > 1) {
          steps.add(
            'Choose the preferred Hik-Connect device serial for the first pilot scope seed.',
          );
        }
        for (final warning in bootstrap.warnings) {
          final trimmed = warning.trim();
          if (trimmed.isNotEmpty) {
            steps.add('Review camera bootstrap warning: $trimmed');
          }
        }
      }
    }

    if (alarm != null &&
        alarm.totalMessages > 0 &&
        alarm.normalizedRecords.isEmpty) {
      steps.add(
        'Review the Hik-Connect alarm sample and event-type mapping because none of the messages normalized into ONYX intel yet.',
      );
    }

    if (video != null) {
      final hasLive = video.liveAddress != null &&
          video.liveAddress!.primaryUrl.trim().isNotEmpty;
      final hasPlayback = video.playbackCatalog != null &&
          video.playbackCatalog!.records.isNotEmpty;
      final hasDownload = video.downloadResult != null &&
          video.downloadResult!.downloadUrl.trim().isNotEmpty;
      if (!hasLive) {
        steps.add(
          'Capture a live-address response with a usable stream URL for a representative camera.',
        );
      }
      if (!hasPlayback) {
        steps.add(
          'Capture a playback-search response with at least one record window for a representative camera.',
        );
      }
      if (!hasDownload) {
        steps.add(
          'Capture a video-download response with a usable download URL for evidence export.',
        );
      }
    }

    if (steps.isEmpty) {
      return const <String>[
        'Bundle looks ready for the first Hik-Connect pilot run.',
      ];
    }

    return List<String>.unmodifiable(_dedupe(steps));
  }

  String? _missingPayloadStep(String key) {
    switch (key) {
      case 'camera':
        return 'Capture or export a Hik-Connect camera inventory payload from areas/cameras/get.';
      case 'alarm':
        return 'Capture or export a Hik-Connect alarm queue payload from mq/messages.';
      case 'live_address':
        return 'Capture or export a Hik-Connect live-address payload for a representative camera.';
      case 'playback':
        return 'Capture or export a Hik-Connect playback-search payload for a representative camera and time window.';
      case 'video_download':
        return 'Capture or export a Hik-Connect video-download payload for a representative clip.';
      default:
        return null;
    }
  }

  String _labelForKey(String key) {
    switch (key) {
      case 'camera':
        return 'camera inventory';
      case 'alarm':
        return 'alarm queue';
      case 'live_address':
        return 'live-address';
      case 'playback':
        return 'playback-search';
      case 'video_download':
        return 'video-download';
      default:
        return key;
    }
  }

  List<String> _dedupe(List<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      if (seen.add(value)) {
        result.add(value);
      }
    }
    return result;
  }
}
