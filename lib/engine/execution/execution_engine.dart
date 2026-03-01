import '../../domain/authority/authority_token.dart';

class ExecutionEngine {
  final Set<String> _executedDispatchIds = {};

  ExecutionEngine();

  bool execute(
    String dispatchId, {
    required AuthorityToken authority,
  }) {
    if (dispatchId.isEmpty) {
      throw ArgumentError('dispatchId cannot be empty.');
    }

    if (authority.authorizedBy.isEmpty) {
      throw StateError('Execution requires valid authority.');
    }

    if (_executedDispatchIds.contains(dispatchId)) {
      throw StateError(
        'Duplicate execution attempt detected for dispatchId: $dispatchId',
      );
    }

    _executedDispatchIds.add(dispatchId);

    // Simulated success for vertical slice
    return true;
  }
}
