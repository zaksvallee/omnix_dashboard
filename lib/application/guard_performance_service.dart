import '../domain/projection/guard_performance_projection.dart';
import '../domain/store/event_store.dart';
import 'models/site_performance_summary.dart';

class GuardPerformanceService {
  final EventStore store;

  const GuardPerformanceService(this.store);

  SitePerformanceSummary siteSummary({
    required String clientId,
    required String regionId,
    required String siteId,
  }) {
    final projection = GuardPerformanceProjection();

    for (final event in store.allEvents()) {
      projection.apply(event);
    }

    return SitePerformanceSummary(
      avgResponseMinutes: projection.averageResponseTimeMinutes(
        clientId: clientId,
        regionId: regionId,
        siteId: siteId,
      ),
      avgResolutionMinutes: projection.averageResolutionTimeMinutes(
        clientId: clientId,
        regionId: regionId,
        siteId: siteId,
      ),
      incidentCount: projection.incidentCount(
        clientId: clientId,
        regionId: regionId,
        siteId: siteId,
      ),
      slaBreaches: projection.slaBreaches(
        clientId: clientId,
        regionId: regionId,
        siteId: siteId,
      ),
      guardCompliancePercent: projection.guardCompliancePercent(
        guardId: 'GUARD-01',
        clientId: clientId,
        regionId: regionId,
        siteId: siteId,
      ),
      slaCompliancePercent: projection.slaCompliancePercent(
        clientId: clientId,
        regionId: regionId,
        siteId: siteId,
      ),
      escalationTrendScore: projection.escalationTrendScore(
        clientId: clientId,
        regionId: regionId,
        siteId: siteId,
      ),
    );
  }
}
