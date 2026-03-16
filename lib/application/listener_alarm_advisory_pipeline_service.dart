import '../domain/intelligence/intel_ingestion.dart';
import 'listener_alarm_advisory_resolution_service.dart';
import 'listener_alarm_partner_advisory_service.dart';
import 'listener_alarm_scope_registry_repository.dart';
import 'listener_serial_ingestor.dart';
import 'monitoring_shift_notification_service.dart';

class ListenerAlarmAdvisoryPipelineResult {
  final ListenerAlarmAdvisoryResolution resolution;
  final MonitoringSiteProfile siteProfile;
  final NormalizedIntelRecord? normalizedIntel;

  const ListenerAlarmAdvisoryPipelineResult({
    required this.resolution,
    required this.siteProfile,
    required this.normalizedIntel,
  });
}

class ListenerAlarmAdvisoryPipelineService {
  final ListenerAlarmScopeRegistryRepository registryRepository;
  final ListenerAlarmAdvisoryResolutionService advisoryResolutionService;
  final ListenerSerialIngestor serialIngestor;

  const ListenerAlarmAdvisoryPipelineService({
    required this.registryRepository,
    this.advisoryResolutionService = const ListenerAlarmAdvisoryResolutionService(),
    this.serialIngestor = const ListenerSerialIngestor(),
  });

  ListenerAlarmAdvisoryPipelineResult? process({
    required ListenerSerialEnvelope envelope,
    required ListenerAlarmAdvisoryDisposition disposition,
    String cctvSummary = '',
    String recommendation = '',
  }) {
    final resolution = advisoryResolutionService.resolvePartnerAdvisory(
      envelope: envelope,
      scopeEntries: registryRepository.allEntries(),
      disposition: disposition,
      cctvSummary: cctvSummary,
      recommendation: recommendation,
    );
    if (resolution == null) {
      return null;
    }

    return ListenerAlarmAdvisoryPipelineResult(
      resolution: resolution,
      siteProfile: resolution.scope.siteProfile,
      normalizedIntel: serialIngestor.normalizeEnvelope(resolution.envelope),
    );
  }
}
