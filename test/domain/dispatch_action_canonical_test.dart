import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/models/action_status.dart'
    as domain_status;
import 'package:omnix_dashboard/domain/models/dispatch_action.dart'
    as domain_action;
import 'package:omnix_dashboard/engine/dispatch/action_status.dart'
    as engine_status;
import 'package:omnix_dashboard/engine/dispatch/dispatch_action.dart'
    as engine_action;

void main() {
  test(
    'domain and engine action status paths resolve to same enum symbols',
    () {
      expect(domain_status.ActionStatus.decided.name, 'decided');
      expect(engine_status.ActionStatus.decided.name, 'decided');
      expect(
        domain_status.ActionStatus.values.length,
        engine_status.ActionStatus.values.length,
      );
    },
  );

  test('dispatch action supports both dispatchId and id constructor forms', () {
    final fromDomainPath = domain_action.DispatchAction(
      dispatchId: 'DSP-1',
      status: domain_status.ActionStatus.decided,
    );
    final fromEnginePath = engine_action.DispatchAction(
      id: 'DSP-2',
      status: engine_status.ActionStatus.decided,
    );

    expect(fromDomainPath.dispatchId, 'DSP-1');
    expect(fromDomainPath.id, 'DSP-1');
    expect(fromEnginePath.dispatchId, 'DSP-2');
    expect(fromEnginePath.id, 'DSP-2');
  });
}
