import 'action_status.dart';
import 'dispatch_state_machine.dart';

class DispatchAction {
  final String dispatchId;
  final ActionStatus status;

  const DispatchAction({String? dispatchId, String? id, required this.status})
    : dispatchId = dispatchId ?? id ?? '',
      assert(
        (dispatchId ?? id ?? '').length > 0,
        'DispatchAction requires dispatchId/id.',
      );

  // Backward compatibility for older engine call sites.
  String get id => dispatchId;

  DispatchAction copyWith({ActionStatus? status}) {
    return DispatchAction(
      dispatchId: dispatchId,
      status: status ?? this.status,
    );
  }

  DispatchAction transition(ActionStatus newStatus) {
    if (!DispatchStateMachine.canTransition(status, newStatus)) {
      throw StateError('Illegal transition: $status -> $newStatus');
    }
    return copyWith(status: newStatus);
  }
}
