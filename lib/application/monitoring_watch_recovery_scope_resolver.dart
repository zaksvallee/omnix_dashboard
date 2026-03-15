import 'dvr_scope_config.dart';
import 'monitoring_watch_recovery_store.dart';

class MonitoringWatchRecoveryScopeResolver {
  const MonitoringWatchRecoveryScopeResolver();

  List<MonitoringWatchRecoveryScope> resolve({
    required Iterable<DvrScopeConfig> scopes,
    required String Function(String clientId, String siteId) siteLabelForScope,
  }) {
    return scopes
        .map((scope) {
          final siteLabel = siteLabelForScope(
            scope.clientId,
            scope.siteId,
          ).trim();
          return MonitoringWatchRecoveryScope(
            scopeKey: scope.scopeKey,
            siteLabel: siteLabel.isEmpty ? scope.siteId : siteLabel,
          );
        })
        .toList(growable: false);
  }
}
