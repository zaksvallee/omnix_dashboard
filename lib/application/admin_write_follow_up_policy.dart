class AdminWriteFollowUpOutcome {
  final bool treatAsSuccess;
  final String message;
  final String detail;

  const AdminWriteFollowUpOutcome({
    required this.treatAsSuccess,
    required this.message,
    required this.detail,
  });
}

AdminWriteFollowUpOutcome resolveAdminWriteFollowUpOutcome({
  required bool primaryWriteCompleted,
  required String failureMessage,
  required String successWarningMessage,
  required String successWarningDetail,
  required String failureDetailPrefix,
  required Object error,
}) {
  if (primaryWriteCompleted) {
    return AdminWriteFollowUpOutcome(
      treatAsSuccess: true,
      message: successWarningMessage,
      detail: '$successWarningDetail: $error',
    );
  }
  return AdminWriteFollowUpOutcome(
    treatAsSuccess: false,
    message: failureMessage,
    detail: '$failureDetailPrefix: $error',
  );
}
