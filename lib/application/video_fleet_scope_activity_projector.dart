import '../domain/events/intelligence_received.dart';
import 'dvr_scope_config.dart';

class VideoFleetScopeActivitySnapshot {
  final int recentEvents;
  final DateTime? lastSeenAtUtc;
  final IntelligenceReceived? latestEvent;

  const VideoFleetScopeActivitySnapshot({
    required this.recentEvents,
    required this.lastSeenAtUtc,
    required this.latestEvent,
  });
}

class VideoFleetScopeActivityProjector {
  const VideoFleetScopeActivityProjector();

  Map<String, VideoFleetScopeActivitySnapshot> project({
    required Iterable<DvrScopeConfig> scopes,
    required Iterable<IntelligenceReceived> events,
    required DateTime nowUtc,
  }) {
    final windowStartUtc = nowUtc.subtract(const Duration(hours: 6));
    final recentByScope = <String, List<IntelligenceReceived>>{};
    for (final event in events) {
      if (event.sourceType != 'dvr') {
        continue;
      }
      if (event.occurredAt.toUtc().isBefore(windowStartUtc)) {
        continue;
      }
      final scopeKey = '${event.clientId}|${event.siteId}';
      recentByScope
          .putIfAbsent(scopeKey, () => <IntelligenceReceived>[])
          .add(event);
    }

    final output = <String, VideoFleetScopeActivitySnapshot>{};
    for (final scope in scopes) {
      final scopedEvents = recentByScope[scope.scopeKey];
      if (scopedEvents == null || scopedEvents.isEmpty) {
        output[scope.scopeKey] = const VideoFleetScopeActivitySnapshot(
          recentEvents: 0,
          lastSeenAtUtc: null,
          latestEvent: null,
        );
        continue;
      }
      IntelligenceReceived? latestEvent;
      for (final event in scopedEvents) {
        if (latestEvent == null ||
            event.occurredAt.isAfter(latestEvent.occurredAt)) {
          latestEvent = event;
        }
      }
      output[scope.scopeKey] = VideoFleetScopeActivitySnapshot(
        recentEvents: scopedEvents.length,
        lastSeenAtUtc: latestEvent?.occurredAt,
        latestEvent: latestEvent,
      );
    }
    return output;
  }
}
