import '../events/guard_checked_in.dart';
import '../store/in_memory_event_store.dart';
import '../projection/guard_performance_projection.dart';
import '../testing/replay_consistency_verifier.dart';

class GuardPerformanceRunner {
  static void run() {
    final store = InMemoryEventStore();
    final projection = GuardPerformanceProjection();

    const clientId = 'CLIENT-1';
    const regionId = 'REGION-1';
    const siteId = 'SITE-1';
    const guardId = 'GUARD-1';

    final checkIn1 = GuardCheckedIn(
      eventId: 'GCI-1',
      sequence: 0,
      version: 1,
      occurredAt: DateTime.now().toUtc(),
      guardId: guardId,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
    );

    final checkIn2 = GuardCheckedIn(
      eventId: 'GCI-2',
      sequence: 0,
      version: 1,
      occurredAt: DateTime.now().toUtc(),
      guardId: guardId,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
    );

    store.append(checkIn1);
    store.append(checkIn2);

    for (final event in store.allEvents()) {
      projection.apply(event);
    }

    final total = projection.guardCheckIns(
      guardId: guardId,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
    );

    if (total != 2) {
      throw StateError('Guard check-in projection mismatch.');
    }

    ReplayConsistencyVerifier.verify(store.allEvents());
  }
}
