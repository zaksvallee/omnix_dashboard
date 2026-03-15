import '../domain/events/intelligence_received.dart';
import 'dvr_scope_config.dart';
import 'video_fleet_scope_activity_projector.dart';

class VideoFleetScopeSummaryFormatter {
  final VideoFleetScopeActivityProjector activityProjector;

  const VideoFleetScopeSummaryFormatter({
    this.activityProjector = const VideoFleetScopeActivityProjector(),
  });

  String format({
    required List<DvrScopeConfig> scopes,
    required Iterable<IntelligenceReceived> events,
    required DateTime nowUtc,
    required String Function(String clientId, String siteId) siteNameForScope,
    required String Function(Uri? eventsUri) endpointLabelForScope,
    int maxScopes = 3,
  }) {
    if (scopes.isEmpty) {
      return '';
    }
    final activityByScope = activityProjector.project(
      scopes: scopes,
      events: events,
      nowUtc: nowUtc,
    );
    final scopeRows = <String>[];
    for (final scope in scopes) {
      final activity =
          activityByScope[scope.scopeKey] ??
          const VideoFleetScopeActivitySnapshot(
            recentEvents: 0,
            lastSeenAtUtc: null,
            latestEvent: null,
          );
      final endpointLabel = endpointLabelForScope(scope.eventsUri);
      final lastLabel = activity.lastSeenAtUtc == null
          ? 'idle'
          : '${activity.lastSeenAtUtc!.toUtc().hour.toString().padLeft(2, '0')}:${activity.lastSeenAtUtc!.toUtc().minute.toString().padLeft(2, '0')}';
      scopeRows.add(
        '${siteNameForScope(scope.clientId, scope.siteId)} ${activity.recentEvents}/6h${endpointLabel.isEmpty ? '' : ' @ $endpointLabel'} • last $lastLabel',
      );
    }
    if (scopeRows.isEmpty) {
      return 'fleet ${scopes.length} scope(s)';
    }
    final visible = scopeRows.take(maxScopes).join(' • ');
    final remaining = scopeRows.length - maxScopes;
    return 'fleet ${scopes.length} scope(s) • $visible${remaining > 0 ? ' • +$remaining more' : ''}';
  }
}
