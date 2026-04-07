import '../events/dispatch_event.dart';
import '../events/decision_created.dart';
import '../events/execution_completed.dart';
import '../events/execution_denied.dart';

class SiteOverview {
  final String clientId;
  final String regionId;
  final String siteId;
  final int activeDispatches;
  final int deniedCount;
  final int failedCount;
  final String worstStatus;

  const SiteOverview({
    required this.clientId,
    required this.regionId,
    required this.siteId,
    required this.activeDispatches,
    required this.deniedCount,
    required this.failedCount,
    required this.worstStatus,
  });
}

class DashboardOverviewProjection {
  static List<SiteOverview> build(List<DispatchEvent> events) {
    final Map<String, Map<String, Map<String, List<String>>>> siteStatuses = {};

    for (final event in events) {
      if (event is DecisionCreated) {
        siteStatuses
            .putIfAbsent(event.clientId, () => {})
            .putIfAbsent(event.regionId, () => {})
            .putIfAbsent(event.siteId, () => [])
            .add('DECIDED');
      }

      if (event is ExecutionCompleted) {
        siteStatuses
            .putIfAbsent(event.clientId, () => {})
            .putIfAbsent(event.regionId, () => {})
            .putIfAbsent(event.siteId, () => [])
            .add(event.success ? 'CONFIRMED' : 'FAILED');
      }

      if (event is ExecutionDenied) {
        siteStatuses
            .putIfAbsent(event.clientId, () => {})
            .putIfAbsent(event.regionId, () => {})
            .putIfAbsent(event.siteId, () => [])
            .add('DENIED');
      }
    }

    final List<SiteOverview> results = [];

    siteStatuses.forEach((clientId, regions) {
      regions.forEach((regionId, sites) {
        sites.forEach((siteId, statuses) {
          int active = statuses.where((s) => s == 'DECIDED').length;
          int denied = statuses.where((s) => s == 'DENIED').length;
          int failed = statuses.where((s) => s == 'FAILED').length;

          String worst = 'STABLE';

          if (statuses.contains('FAILED')) {
            worst = 'FAILED';
          } else if (statuses.contains('CONFIRMED')) {
            worst = 'CONFIRMED';
          } else if (statuses.contains('DECIDED')) {
            worst = 'DECIDED';
          } else if (statuses.contains('DENIED')) {
            worst = 'DENIED';
          }

          results.add(
            SiteOverview(
              clientId: clientId,
              regionId: regionId,
              siteId: siteId,
              activeDispatches: active,
              deniedCount: denied,
              failedCount: failed,
              worstStatus: worst,
            ),
          );
        });
      });
    });

    return results;
  }
}
