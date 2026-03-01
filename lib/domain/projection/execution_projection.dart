import '../logging/execution_event.dart';

class ExecutionProjection {
  final List<String> summaries;

  const ExecutionProjection({
    required this.summaries,
  });

  factory ExecutionProjection.fromEvents(
      List<ExecutionEvent> events) {
    final summaries = events.map((e) {
      switch (e.type) {
        case ExecutionEventType.intelligenceReceived:
          return 'INTEL → ${e.referenceId}';
        case ExecutionEventType.decisionCreated:
          return 'DECISION → ${e.referenceId}';
        case ExecutionEventType.executionCompleted:
          return 'EXECUTED → ${e.referenceId}';
      }
    }).toList();

    return ExecutionProjection(summaries: summaries);
  }
}
