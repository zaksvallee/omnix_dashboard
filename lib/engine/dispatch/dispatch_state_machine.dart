import 'action_status.dart';

class DispatchStateMachine {
  static bool canTransition(
    ActionStatus from,
    ActionStatus to,
  ) {
    switch (from) {
      case ActionStatus.decided:
        return to == ActionStatus.committing ||
            to == ActionStatus.executed ||
            to == ActionStatus.overridden;

      case ActionStatus.committing:
        return to == ActionStatus.executed ||
            to == ActionStatus.aborted ||
            to == ActionStatus.overridden;

      case ActionStatus.executed:
        return to == ActionStatus.failed;

      case ActionStatus.aborted:
      case ActionStatus.overridden:
      case ActionStatus.failed:
        return false;
    }
  }
}
