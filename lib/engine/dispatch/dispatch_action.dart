import 'action_status.dart';
import 'dispatch_state_machine.dart';

class DispatchAction {
  final String id;
  final ActionStatus status;

  const DispatchAction({
    required this.id,
    required this.status,
  });

  DispatchAction transition(ActionStatus newStatus) {
    if (!DispatchStateMachine.canTransition(status, newStatus)) {
      throw StateError(
        'Illegal transition: $status -> $newStatus',
      );
    }

    return DispatchAction(
      id: id,
      status: newStatus,
    );
  }
}
