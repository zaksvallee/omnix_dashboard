import '../events/patrol_completed.dart';
import '../store/in_memory_event_store.dart';
import '../projection/guard_performance_projection.dart';

class PatrolPerformanceRunner {
  static void run() {
    final store = InMemoryEventStore();
    final projection = GuardPerformanceProjection();

    const clientId = 'CLIENT-1';
    const regionId = 'REGION-1';
    const siteId = 'SITE-1';
    const guardId = 'GUARD-1';

    final patrol1 = PatrolCompleted(
      eventId: 'PAT-1',
      sequence: 0,
      version: 1,
      occurredAt: DateTime.now().toUtc(),
      guardId: guardId,
      routeId: 'R1',
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      durationSeconds: 600,
    );

    final patrol2 = PatrolCompleted(
      eventId: 'PAT-2',
      sequence: 0,
      version: 1,
      occurredAt: DateTime.now().toUtc(),
      guardId: guardId,
      routeId: 'R1',
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      durationSeconds: 900,
    );

    store.append(patrol1);
    store.append(patrol2);

    for (final event in store.allEvents()) {
      projection.apply(event);
    }

    final count = projection.patrolCompletions(
      guardId: guardId,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
    );

    final avg = projection.averagePatrolDurationMinutes(
      guardId: guardId,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
    );

    if (count != 2) {
      throw StateError('Patrol completion count incorrect.');
    }

    if (avg < 11.9 || avg > 12.1) {
      throw StateError('Patrol duration average incorrect.');
    }
  }
}
