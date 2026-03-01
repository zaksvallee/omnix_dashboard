import 'domain/events/decision_created.dart';
import 'domain/events/execution_completed.dart';
import 'domain/projection/dispatch_projection.dart';

void runVerticalSlice() {
  final projection = DispatchProjection();

  final decisionEvent = DecisionCreated(
    eventId: 'evt-1',
    sequence: 0,
    version: 1,
    occurredAt: DateTime.now().toUtc(),
    dispatchId: 'DSP-001',
    clientId: 'CLIENT-TEST',
    regionId: 'REGION-TEST',
    siteId: 'SITE-TEST',
  );

  projection.apply(decisionEvent);

  final executionEvent = ExecutionCompleted(
    eventId: 'evt-2',
    sequence: 1,
    version: 1,
    occurredAt: DateTime.now().toUtc(),
    dispatchId: 'DSP-001',
    clientId: 'CLIENT-TEST',
    regionId: 'REGION-TEST',
    siteId: 'SITE-TEST',
    success: true,
  );

  projection.apply(executionEvent);
}
