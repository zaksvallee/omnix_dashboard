import '../events/decision_created.dart';
import '../events/incident_closed.dart';
import '../store/in_memory_event_store.dart';
import '../projection/guard_performance_projection.dart';

class IncidentPerformanceRunner {
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

    final closed = IncidentClosed(
      eventId: 'CLOSE-1',
      sequence: 0,
      version: 1,
      occurredAt: decision.occurredAt.add(const Duration(minutes: 25)),
      dispatchId: dispatchId,
      resolutionType: 'resolved',
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
    );

    store.append(decision);
    store.append(closed);

    for (final event in store.allEvents()) {
      projection.apply(event);
    }

    final count = projection.incidentCount(
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
    );

    final avg = projection.averageResolutionTimeMinutes(
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
    );

    if (count != 1) {
      throw StateError('Incident count incorrect.');
    }

    if (avg < 24.9 || avg > 25.1) {
      throw StateError('Resolution time calculation incorrect.');
    }
  }
}
