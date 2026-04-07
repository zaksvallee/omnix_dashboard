import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/engine/dispatch/action_status.dart';
import 'package:omnix_dashboard/engine/dispatch/dispatch_state_machine.dart';

void main() {
  test('dispatch state machine legal and illegal transitions match the approved matrix', () {
    const expected = <ActionStatus, Set<ActionStatus>>{
      ActionStatus.decided: <ActionStatus>{
        ActionStatus.committing,
        ActionStatus.executed,
        ActionStatus.aborted,
        ActionStatus.overridden,
      },
      ActionStatus.committing: <ActionStatus>{
        ActionStatus.executed,
        ActionStatus.failed,
        ActionStatus.overridden,
      },
      ActionStatus.executed: <ActionStatus>{
        ActionStatus.confirmed,
        ActionStatus.failed,
      },
      ActionStatus.confirmed: <ActionStatus>{},
      ActionStatus.aborted: <ActionStatus>{},
      ActionStatus.overridden: <ActionStatus>{},
      ActionStatus.failed: <ActionStatus>{},
    };

    for (final from in ActionStatus.values) {
      for (final to in ActionStatus.values) {
        final actual = DispatchStateMachine.canTransition(from, to);
        final isExpected = expected[from]!.contains(to);
        expect(
          actual,
          isExpected,
          reason: 'Unexpected transition result for $from -> $to',
        );
      }
    }
  });
}
