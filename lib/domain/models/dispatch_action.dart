import 'action_status.dart';

class DispatchAction {
  final String dispatchId;
  final ActionStatus status;

  const DispatchAction({
    required this.dispatchId,
    required this.status,
  });

  DispatchAction copyWith({
    ActionStatus? status,
  }) {
    return DispatchAction(
      dispatchId: dispatchId,
      status: status ?? this.status,
    );
  }
}
