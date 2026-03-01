enum ExecutionEventType {
  intelligenceReceived,
  decisionCreated,
  executionCompleted,
}

class ExecutionEvent {
  final ExecutionEventType type;
  final String referenceId;
  final String message;
  final DateTime timestamp;

  const ExecutionEvent({
    required this.type,
    required this.referenceId,
    required this.message,
    required this.timestamp,
  });
}
