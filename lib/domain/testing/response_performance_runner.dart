import '../events/decision_created.dart';
import '../events/response_arrived.dart';
import '../store/in_memory_event_store.dart';
import '../projection/guard_performance_projection.dart';

class ResponsePerformanceRunner {
  static void run() {
    final store = InMemoryEventStore();
    final projection = GuardPerformanceProjection();

    const clientId = 'CLIENT-1';
    const regionId = 'REGION-1';
    const siteId = 'SITE-1';
    const dispatchId = 'DSP-1';

    final decision = DecisionCreated(
      eventId: 'DEC-1',
      sequence: 0,
      version: 1,
      occurredAt: DateTime.now().toUtc(),
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      dispatchId: dispatchId,
    );

    final arrival = ResponseArrived(
      eventId: 'ARR-1',
      sequence: 0,
      version: 1,
      occurredAt: decision.occurredAt.add(const Duration(minutes: 8)),
      dispatchId: dispatchId,
      guardId: 'GUARD-1',
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
    );

    store.append(decision);
    store.append(arrival);

    for (final event in store.allEvents()) {
      projection.apply(event);
    }

    final avg = projection.averageResponseTimeMinutes(
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
    );

    if (avg < 7.9 || avg > 8.1) {
      throw StateError('Response time calculation incorrect.');
    }
  }
}
