import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:omnix_dashboard/application/onyx_agent_camera_bridge_server_contract.dart';

enum OnyxAgentCameraBridgeReceiptState { unavailable, missing, stale, current }

const String onyxAgentCameraBridgeDefaultOperatorId = 'OPERATOR-01';

enum OnyxAgentCameraBridgeValidateAction {
  validate,
  firstValidation,
  revalidate,
  validating,
}

enum OnyxAgentCameraBridgeValidateActionLabelVariant { agent, admin }

enum OnyxAgentCameraBridgeClearActionLabelVariant { agent, admin }

enum OnyxAgentCameraBridgeCopyActionLabelVariant { agent, admin }

enum OnyxAgentCameraBridgeShellState {
  bindMismatch,
  receiptStale,
  receiptMissing,
  receiptUnavailable,
  disabled,
  ready,
  failed,
  pending,
}

enum OnyxAgentCameraBridgeShellSummaryVariant { standard, controllerCard }

enum OnyxAgentCameraBridgeChipVariant { agent, admin }

enum OnyxAgentCameraBridgeStatusTone {
  live,
  failed,
  starting,
  disabled,
  standby,
}

enum OnyxAgentCameraBridgeHealthTone { status, error, warning, success }

enum OnyxAgentCameraBridgeValidationTone { success, warning, neutral }

enum OnyxAgentCameraBridgeHealthLoadingVariant { agent, admin }

enum OnyxAgentCameraBridgeChipTone {
  status,
  info,
  success,
  warning,
  neutral,
  danger,
}

class OnyxAgentCameraBridgeChip {
  final String label;
  final OnyxAgentCameraBridgeChipTone tone;

  const OnyxAgentCameraBridgeChip({required this.label, required this.tone});
}

class OnyxAgentCameraBridgeStatusBadge {
  final String label;
  final OnyxAgentCameraBridgeStatusTone tone;

  const OnyxAgentCameraBridgeStatusBadge({
    required this.label,
    required this.tone,
  });
}

class OnyxAgentCameraBridgeHealthBadge {
  final String label;
  final OnyxAgentCameraBridgeHealthTone tone;

  const OnyxAgentCameraBridgeHealthBadge({
    required this.label,
    required this.tone,
  });
}

class OnyxAgentCameraBridgeHealthField {
  final String label;
  final String value;

  const OnyxAgentCameraBridgeHealthField({
    required this.label,
    required this.value,
  });
}

class OnyxAgentCameraBridgeRuntimeState {
  final OnyxAgentCameraBridgeReceiptState? receiptState;
  final OnyxAgentCameraBridgeShellState shellState;
  final String? validationSummary;
  final OnyxAgentCameraBridgeValidationTone? validationTone;

  const OnyxAgentCameraBridgeRuntimeState({
    required this.receiptState,
    required this.shellState,
    required this.validationSummary,
    required this.validationTone,
  });
}

class OnyxAgentCameraBridgeHealthControlState {
  final bool showHealthCard;
  final bool showClearReceiptAction;
  final bool canValidate;
  final bool canClearReceipt;

  const OnyxAgentCameraBridgeHealthControlState({
    required this.showHealthCard,
    required this.showClearReceiptAction,
    required this.canValidate,
    required this.canClearReceipt,
  });
}

class OnyxAgentCameraBridgeLocalState {
  final OnyxAgentCameraBridgeHealthSnapshot? snapshot;
  final bool validationInFlight;
  final bool resetInFlight;

  const OnyxAgentCameraBridgeLocalState({
    this.snapshot,
    this.validationInFlight = false,
    this.resetInFlight = false,
  });

  bool get hasSnapshot => snapshot != null;

  OnyxAgentCameraBridgeLocalState syncSnapshot(
    OnyxAgentCameraBridgeHealthSnapshot? nextSnapshot,
  ) {
    return OnyxAgentCameraBridgeLocalState(
      snapshot: nextSnapshot,
      validationInFlight: validationInFlight,
      resetInFlight: resetInFlight,
    );
  }

  OnyxAgentCameraBridgeLocalState beginValidation() {
    return const OnyxAgentCameraBridgeLocalState(
      snapshot: null,
      validationInFlight: true,
      resetInFlight: false,
    );
  }

  OnyxAgentCameraBridgeLocalState finishValidation(
    OnyxAgentCameraBridgeHealthSnapshot nextSnapshot,
  ) {
    return OnyxAgentCameraBridgeLocalState(
      snapshot: nextSnapshot,
      validationInFlight: false,
      resetInFlight: false,
    );
  }

  OnyxAgentCameraBridgeLocalState beginReset() {
    return const OnyxAgentCameraBridgeLocalState(
      snapshot: null,
      validationInFlight: false,
      resetInFlight: true,
    );
  }

  OnyxAgentCameraBridgeLocalState finishReset({
    required bool success,
    required OnyxAgentCameraBridgeHealthSnapshot? previousSnapshot,
  }) {
    return OnyxAgentCameraBridgeLocalState(
      snapshot: success ? null : previousSnapshot,
      validationInFlight: false,
      resetInFlight: false,
    );
  }
}

class OnyxAgentCameraBridgeValidationOutcome {
  final OnyxAgentCameraBridgeHealthSnapshot snapshot;
  final String message;

  const OnyxAgentCameraBridgeValidationOutcome({
    required this.snapshot,
    required this.message,
  });
}

class OnyxAgentCameraBridgeClearOutcome {
  final bool success;
  final String message;

  const OnyxAgentCameraBridgeClearOutcome({
    required this.success,
    required this.message,
  });
}

class OnyxAgentCameraBridgeSurfaceState {
  final OnyxAgentCameraBridgeRuntimeState runtimeState;
  final OnyxAgentCameraBridgeHealthControlState controls;
  final String shellSummary;
  final String controllerCardSummary;

  const OnyxAgentCameraBridgeSurfaceState({
    required this.runtimeState,
    required this.controls,
    required this.shellSummary,
    required this.controllerCardSummary,
  });

  OnyxAgentCameraBridgeReceiptState? get receiptState =>
      runtimeState.receiptState;

  OnyxAgentCameraBridgeShellState get shellState => runtimeState.shellState;

  String? get receiptStateLabel => runtimeState.receiptState?.label;

  String? get validationSummary => runtimeState.validationSummary;

  OnyxAgentCameraBridgeValidationTone? get validationTone =>
      runtimeState.validationTone;
}

extension OnyxAgentCameraBridgeShellStateLabel
    on OnyxAgentCameraBridgeShellState {
  String get label => switch (this) {
    OnyxAgentCameraBridgeShellState.bindMismatch => 'BIND_MISMATCH',
    OnyxAgentCameraBridgeShellState.receiptStale => 'RECEIPT_STALE',
    OnyxAgentCameraBridgeShellState.receiptMissing => 'RECEIPT_MISSING',
    OnyxAgentCameraBridgeShellState.receiptUnavailable => 'RECEIPT_UNAVAILABLE',
    OnyxAgentCameraBridgeShellState.disabled => 'DISABLED',
    OnyxAgentCameraBridgeShellState.ready => 'READY',
    OnyxAgentCameraBridgeShellState.failed => 'FAILED',
    OnyxAgentCameraBridgeShellState.pending => 'PENDING',
  };
}

extension OnyxAgentCameraBridgeReceiptStateLabel
    on OnyxAgentCameraBridgeReceiptState {
  String get label => switch (this) {
    OnyxAgentCameraBridgeReceiptState.unavailable => 'UNAVAILABLE',
    OnyxAgentCameraBridgeReceiptState.missing => 'MISSING',
    OnyxAgentCameraBridgeReceiptState.stale => 'STALE',
    OnyxAgentCameraBridgeReceiptState.current => 'CURRENT',
  };
}

const Duration onyxAgentCameraBridgeReceiptStaleThreshold = Duration(
  minutes: 30,
);

class OnyxAgentCameraBridgeHealthSnapshot {
  final Uri requestedEndpoint;
  final Uri healthEndpoint;
  final Uri? reportedEndpoint;
  final bool reachable;
  final bool running;
  final int? statusCode;
  final String statusLabel;
  final String detail;
  final String executePath;
  final DateTime checkedAtUtc;
  final String operatorId;

  const OnyxAgentCameraBridgeHealthSnapshot({
    required this.requestedEndpoint,
    required this.healthEndpoint,
    required this.reachable,
    required this.running,
    required this.statusLabel,
    required this.detail,
    required this.executePath,
    required this.checkedAtUtc,
    this.operatorId = '',
    this.reportedEndpoint,
    this.statusCode,
  });

  OnyxAgentCameraBridgeHealthSnapshot copyWith({
    Uri? requestedEndpoint,
    Uri? healthEndpoint,
    Uri? reportedEndpoint,
    bool? reachable,
    bool? running,
    int? statusCode,
    String? statusLabel,
    String? detail,
    String? executePath,
    DateTime? checkedAtUtc,
    String? operatorId,
  }) {
    return OnyxAgentCameraBridgeHealthSnapshot(
      requestedEndpoint: requestedEndpoint ?? this.requestedEndpoint,
      healthEndpoint: healthEndpoint ?? this.healthEndpoint,
      reportedEndpoint: reportedEndpoint ?? this.reportedEndpoint,
      reachable: reachable ?? this.reachable,
      running: running ?? this.running,
      statusCode: statusCode ?? this.statusCode,
      statusLabel: statusLabel ?? this.statusLabel,
      detail: detail ?? this.detail,
      executePath: executePath ?? this.executePath,
      checkedAtUtc: checkedAtUtc ?? this.checkedAtUtc,
      operatorId: operatorId ?? this.operatorId,
    );
  }

  factory OnyxAgentCameraBridgeHealthSnapshot.fromJson(
    Map<String, Object?> json,
  ) {
    final requestedEndpoint = Uri.tryParse(
      json['requested_endpoint']?.toString().trim() ?? '',
    );
    final healthEndpoint = Uri.tryParse(
      json['health_endpoint']?.toString().trim() ?? '',
    );
    final checkedAtUtc = DateTime.tryParse(
      json['checked_at_utc']?.toString().trim() ?? '',
    )?.toUtc();
    return OnyxAgentCameraBridgeHealthSnapshot(
      requestedEndpoint:
          requestedEndpoint ?? Uri.parse('http://127.0.0.1:11634'),
      healthEndpoint:
          healthEndpoint ??
          (requestedEndpoint ?? Uri.parse('http://127.0.0.1:11634')).replace(
            path: '/health',
          ),
      reportedEndpoint: Uri.tryParse(
        json['reported_endpoint']?.toString().trim() ?? '',
      ),
      reachable: json['reachable'] == true,
      running: json['running'] == true,
      statusCode: _readInt(json['status_code']),
      statusLabel: json['status_label']?.toString().trim().isNotEmpty == true
          ? json['status_label']!.toString().trim()
          : 'Unavailable',
      detail: json['detail']?.toString().trim() ?? '',
      executePath: json['execute_path']?.toString().trim().isNotEmpty == true
          ? json['execute_path']!.toString().trim()
          : '/execute',
      checkedAtUtc:
          checkedAtUtc ?? DateTime.fromMillisecondsSinceEpoch(0).toUtc(),
      operatorId: json['operator_id']?.toString().trim() ?? '',
    );
  }

  Uri get routeEndpoint => reportedEndpoint ?? requestedEndpoint;

  String get healthRouteLabel => 'GET ${healthEndpoint.toString()}';

  String get probedBindLabel => requestedEndpoint.toString();

  bool get hasReportedBindMismatch => reportedBindLabel != null;

  String? get reportedBindLabel {
    final reported = reportedEndpoint?.toString().trim() ?? '';
    if (reported.isEmpty) {
      return null;
    }
    if (reported == requestedEndpoint.toString()) {
      return null;
    }
    return reported;
  }

  String? get mismatchStatusLabel =>
      hasReportedBindMismatch ? 'Detected' : null;

  String get routeLabel => 'POST ${routeEndpoint.toString()}$executePath';

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'requested_endpoint': requestedEndpoint.toString(),
      'health_endpoint': healthEndpoint.toString(),
      'reported_endpoint': reportedEndpoint?.toString(),
      'reachable': reachable,
      'running': running,
      'status_code': statusCode,
      'status_label': statusLabel,
      'detail': detail,
      'execute_path': executePath,
      'checked_at_utc': checkedAtUtc.toIso8601String(),
      'operator_id': operatorId,
    };
  }
}

Duration onyxAgentCameraBridgeValidationAge(
  DateTime checkedAtUtc, {
  DateTime? nowUtc,
}) {
  final age = (nowUtc ?? DateTime.now().toUtc()).difference(
    checkedAtUtc.toUtc(),
  );
  return age.isNegative ? Duration.zero : age;
}

bool isOnyxAgentCameraBridgeReceiptStale(
  OnyxAgentCameraBridgeHealthSnapshot? snapshot, {
  DateTime? nowUtc,
  Duration threshold = onyxAgentCameraBridgeReceiptStaleThreshold,
}) {
  if (snapshot == null) {
    return false;
  }
  return onyxAgentCameraBridgeValidationAge(
        snapshot.checkedAtUtc,
        nowUtc: nowUtc,
      ) >
      threshold;
}

String onyxAgentCameraBridgeValidationRecencyLabel(
  DateTime checkedAtUtc, {
  DateTime? nowUtc,
}) {
  final age = onyxAgentCameraBridgeValidationAge(checkedAtUtc, nowUtc: nowUtc);
  if (age < const Duration(minutes: 1)) {
    return 'just now';
  }
  if (age < const Duration(hours: 1)) {
    return '${age.inMinutes}m ago';
  }
  if (age < const Duration(days: 1)) {
    return '${age.inHours}h ago';
  }
  return '${age.inDays}d ago';
}

String formatOnyxAgentCameraBridgeCheckedAtLabel(DateTime checkedAtUtc) {
  final local = checkedAtUtc.toLocal();
  const monthLabels = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final day = local.day.toString().padLeft(2, '0');
  final month = monthLabels[local.month - 1];
  final year = local.year.toString();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  final ss = local.second.toString().padLeft(2, '0');
  return '$day $month $year $hh:$mm:$ss';
}

OnyxAgentCameraBridgeReceiptState resolveOnyxAgentCameraBridgeReceiptState({
  required OnyxAgentCameraBridgeHealthSnapshot? snapshot,
  required bool missingReceipt,
  DateTime? nowUtc,
}) {
  if (snapshot == null) {
    return missingReceipt
        ? OnyxAgentCameraBridgeReceiptState.missing
        : OnyxAgentCameraBridgeReceiptState.unavailable;
  }
  return isOnyxAgentCameraBridgeReceiptStale(snapshot, nowUtc: nowUtc)
      ? OnyxAgentCameraBridgeReceiptState.stale
      : OnyxAgentCameraBridgeReceiptState.current;
}

OnyxAgentCameraBridgeReceiptState?
resolveVisibleOnyxAgentCameraBridgeReceiptState({
  required OnyxAgentCameraBridgeHealthSnapshot? snapshot,
  required bool bridgeLive,
  required bool healthProbeConfigured,
  bool validationInFlight = false,
  DateTime? nowUtc,
}) {
  if (snapshot == null && (validationInFlight || !bridgeLive)) {
    return null;
  }
  return resolveOnyxAgentCameraBridgeReceiptState(
    snapshot: snapshot,
    missingReceipt: snapshot == null && bridgeLive && healthProbeConfigured,
    nowUtc: nowUtc,
  );
}

String? visibleOnyxAgentCameraBridgeReceiptStateLabel({
  required OnyxAgentCameraBridgeHealthSnapshot? snapshot,
  required bool bridgeLive,
  required bool healthProbeConfigured,
  bool validationInFlight = false,
  DateTime? nowUtc,
}) => resolveVisibleOnyxAgentCameraBridgeReceiptState(
  snapshot: snapshot,
  bridgeLive: bridgeLive,
  healthProbeConfigured: healthProbeConfigured,
  validationInFlight: validationInFlight,
  nowUtc: nowUtc,
)?.label;

String describeOnyxAgentCameraBridgeValidation(
  OnyxAgentCameraBridgeHealthSnapshot? snapshot, {
  required bool missingReceipt,
  DateTime? nowUtc,
}) {
  if (snapshot == null) {
    return missingReceipt
        ? 'No bridge validation receipt captured yet. Run GET /health before trusting this bridge.'
        : 'Bridge validation receipt is unavailable on this ONYX runtime.';
  }
  final operatorLabel = snapshot.operatorId.trim().isEmpty
      ? ''
      : ' by ${snapshot.operatorId.trim()}';
  final recencyLabel = onyxAgentCameraBridgeValidationRecencyLabel(
    snapshot.checkedAtUtc,
    nowUtc: nowUtc,
  );
  if (isOnyxAgentCameraBridgeReceiptStale(snapshot, nowUtc: nowUtc)) {
    return 'Last validation $recencyLabel$operatorLabel. Re-run GET /health before trusting this receipt.';
  }
  return 'Last validation $recencyLabel$operatorLabel. Receipt is current.';
}

String? describeVisibleOnyxAgentCameraBridgeValidation({
  required OnyxAgentCameraBridgeHealthSnapshot? snapshot,
  required bool bridgeLive,
  required bool healthProbeConfigured,
  bool validationInFlight = false,
  DateTime? nowUtc,
}) {
  final receiptState = resolveVisibleOnyxAgentCameraBridgeReceiptState(
    snapshot: snapshot,
    bridgeLive: bridgeLive,
    healthProbeConfigured: healthProbeConfigured,
    validationInFlight: validationInFlight,
    nowUtc: nowUtc,
  );
  if (receiptState == null) {
    return null;
  }
  return describeOnyxAgentCameraBridgeValidation(
    snapshot,
    missingReceipt: receiptState == OnyxAgentCameraBridgeReceiptState.missing,
    nowUtc: nowUtc,
  );
}

OnyxAgentCameraBridgeValidationTone? resolveOnyxAgentCameraBridgeValidationTone(
  OnyxAgentCameraBridgeReceiptState? receiptState,
) {
  return switch (receiptState) {
    OnyxAgentCameraBridgeReceiptState.current =>
      OnyxAgentCameraBridgeValidationTone.success,
    OnyxAgentCameraBridgeReceiptState.stale ||
    OnyxAgentCameraBridgeReceiptState.missing =>
      OnyxAgentCameraBridgeValidationTone.warning,
    OnyxAgentCameraBridgeReceiptState.unavailable =>
      OnyxAgentCameraBridgeValidationTone.neutral,
    null => null,
  };
}

String describeOnyxAgentCameraBridgeValidateActionLabel({
  required OnyxAgentCameraBridgeValidateAction action,
  OnyxAgentCameraBridgeValidateActionLabelVariant variant =
      OnyxAgentCameraBridgeValidateActionLabelVariant.agent,
}) {
  return switch ((variant, action)) {
    (
      OnyxAgentCameraBridgeValidateActionLabelVariant.agent,
      OnyxAgentCameraBridgeValidateAction.validating,
    ) =>
      'Checking Bridge...',
    (
      OnyxAgentCameraBridgeValidateActionLabelVariant.agent,
      OnyxAgentCameraBridgeValidateAction.firstValidation,
    ) =>
      'Run First Validation',
    (
      OnyxAgentCameraBridgeValidateActionLabelVariant.agent,
      OnyxAgentCameraBridgeValidateAction.revalidate,
    ) =>
      'Re-Validate Bridge',
    (
      OnyxAgentCameraBridgeValidateActionLabelVariant.agent,
      OnyxAgentCameraBridgeValidateAction.validate,
    ) =>
      'Validate Bridge',
    (
      OnyxAgentCameraBridgeValidateActionLabelVariant.admin,
      OnyxAgentCameraBridgeValidateAction.validating,
    ) =>
      'VALIDATING BRIDGE...',
    (
      OnyxAgentCameraBridgeValidateActionLabelVariant.admin,
      OnyxAgentCameraBridgeValidateAction.firstValidation,
    ) =>
      'RUN FIRST VALIDATION',
    (
      OnyxAgentCameraBridgeValidateActionLabelVariant.admin,
      OnyxAgentCameraBridgeValidateAction.revalidate,
    ) =>
      'RE-VALIDATE BRIDGE',
    (
      OnyxAgentCameraBridgeValidateActionLabelVariant.admin,
      OnyxAgentCameraBridgeValidateAction.validate,
    ) =>
      'VALIDATE BRIDGE',
  };
}

String describeOnyxAgentCameraBridgeClearActionLabel({
  required bool resetInFlight,
  OnyxAgentCameraBridgeClearActionLabelVariant variant =
      OnyxAgentCameraBridgeClearActionLabelVariant.agent,
}) {
  return switch ((variant, resetInFlight)) {
    (OnyxAgentCameraBridgeClearActionLabelVariant.agent, true) =>
      'Clearing Receipt...',
    (OnyxAgentCameraBridgeClearActionLabelVariant.agent, false) =>
      'Clear Bridge Receipt',
    (OnyxAgentCameraBridgeClearActionLabelVariant.admin, true) =>
      'CLEARING RECEIPT...',
    (OnyxAgentCameraBridgeClearActionLabelVariant.admin, false) =>
      'CLEAR BRIDGE RECEIPT',
  };
}

String describeOnyxAgentCameraBridgeCopyActionLabel({
  OnyxAgentCameraBridgeCopyActionLabelVariant variant =
      OnyxAgentCameraBridgeCopyActionLabelVariant.agent,
}) {
  return switch (variant) {
    OnyxAgentCameraBridgeCopyActionLabelVariant.agent => 'Copy Setup',
    OnyxAgentCameraBridgeCopyActionLabelVariant.admin => 'COPY BRIDGE SETUP',
  };
}

String normalizeOnyxAgentCameraBridgeOperatorId(
  String operatorId, {
  String fallback = onyxAgentCameraBridgeDefaultOperatorId,
}) {
  final normalizedOperatorId = operatorId.trim();
  return normalizedOperatorId.isEmpty ? fallback : normalizedOperatorId;
}

String describeOnyxAgentCameraBridgeEndpointMissingMessage() {
  return 'Camera bridge endpoint is not configured.';
}

String describeOnyxAgentCameraBridgeValidationResultMessage({
  required bool reachable,
}) {
  return reachable
      ? 'Camera bridge health check complete.'
      : 'Camera bridge health check failed.';
}

String describeOnyxAgentCameraBridgeClearResultMessage({
  required bool success,
}) {
  return success
      ? 'Camera bridge health receipt cleared.'
      : 'Failed to clear camera bridge health receipt.';
}

String describeOnyxAgentCameraBridgeCopyResultMessage() {
  return 'Camera bridge setup copied.';
}

Future<bool> clearOnyxAgentCameraBridgeHealthReceipt({
  required Future<void> Function()? onClearReceipt,
}) async {
  try {
    await onClearReceipt?.call();
    return true;
  } catch (_) {
    return false;
  }
}

Future<OnyxAgentCameraBridgeHealthSnapshot>
probeOnyxAgentCameraBridgeHealthSnapshot({
  required OnyxAgentCameraBridgeHealthService service,
  required Uri endpoint,
  required String operatorId,
}) async {
  final snapshot = await () async {
    try {
      return await service.probe(endpoint);
    } catch (error, stackTrace) {
      developer.log(
        'Camera bridge health probe crashed.',
        name: 'OnyxAgentCameraBridgeHealthService',
        error: error,
        stackTrace: stackTrace,
      );
      return OnyxAgentCameraBridgeHealthSnapshot(
        requestedEndpoint: endpoint,
        healthEndpoint: endpoint.replace(path: '/health'),
        reachable: false,
        running: false,
        statusLabel: 'Probe failed',
        detail:
            'GET /health probe crashed before a bridge receipt could be captured. $error',
        executePath: '/execute',
        checkedAtUtc: DateTime.now().toUtc(),
      );
    }
  }();
  return snapshot.copyWith(
    operatorId: normalizeOnyxAgentCameraBridgeOperatorId(operatorId),
  );
}

Future<OnyxAgentCameraBridgeValidationOutcome>
completeOnyxAgentCameraBridgeValidation({
  required OnyxAgentCameraBridgeHealthService service,
  required Uri endpoint,
  required String operatorId,
}) async {
  final snapshot = await probeOnyxAgentCameraBridgeHealthSnapshot(
    service: service,
    endpoint: endpoint,
    operatorId: operatorId,
  );
  return OnyxAgentCameraBridgeValidationOutcome(
    snapshot: snapshot,
    message: describeOnyxAgentCameraBridgeValidationResultMessage(
      reachable: snapshot.reachable,
    ),
  );
}

Future<OnyxAgentCameraBridgeClearOutcome> completeOnyxAgentCameraBridgeClear({
  required Future<void> Function()? onClearReceipt,
}) async {
  final success = await clearOnyxAgentCameraBridgeHealthReceipt(
    onClearReceipt: onClearReceipt,
  );
  return OnyxAgentCameraBridgeClearOutcome(
    success: success,
    message: describeOnyxAgentCameraBridgeClearResultMessage(success: success),
  );
}

OnyxAgentCameraBridgeRuntimeState resolveOnyxAgentCameraBridgeRuntimeState({
  required OnyxAgentCameraBridgeStatus status,
  required OnyxAgentCameraBridgeHealthSnapshot? snapshot,
  required bool healthProbeConfigured,
  bool validationInFlight = false,
  DateTime? nowUtc,
}) {
  final receiptState = resolveVisibleOnyxAgentCameraBridgeReceiptState(
    snapshot: snapshot,
    bridgeLive: status.isLive,
    healthProbeConfigured: healthProbeConfigured,
    validationInFlight: validationInFlight,
    nowUtc: nowUtc,
  );
  return OnyxAgentCameraBridgeRuntimeState(
    receiptState: receiptState,
    shellState: resolveOnyxAgentCameraBridgeShellStateForStatus(
      status: status,
      snapshot: snapshot,
      receiptState: receiptState,
    ),
    validationSummary: describeVisibleOnyxAgentCameraBridgeValidation(
      snapshot: snapshot,
      bridgeLive: status.isLive,
      healthProbeConfigured: healthProbeConfigured,
      validationInFlight: validationInFlight,
      nowUtc: nowUtc,
    ),
    validationTone: resolveOnyxAgentCameraBridgeValidationTone(receiptState),
  );
}

OnyxAgentCameraBridgeHealthControlState
resolveOnyxAgentCameraBridgeHealthControlState({
  required bool validationInFlight,
  required bool resetInFlight,
  required bool healthProbeConfigured,
  required bool hasLocalSnapshot,
}) {
  return OnyxAgentCameraBridgeHealthControlState(
    showHealthCard: validationInFlight || hasLocalSnapshot,
    showClearReceiptAction: hasLocalSnapshot,
    canValidate: !validationInFlight && !resetInFlight && healthProbeConfigured,
    canClearReceipt: hasLocalSnapshot && !resetInFlight,
  );
}

OnyxAgentCameraBridgeSurfaceState resolveOnyxAgentCameraBridgeSurfaceState({
  required OnyxAgentCameraBridgeStatus status,
  required OnyxAgentCameraBridgeHealthSnapshot? snapshot,
  required bool healthProbeConfigured,
  required bool validationInFlight,
  required bool resetInFlight,
  required bool hasLocalSnapshot,
  DateTime? nowUtc,
}) {
  final runtimeState = resolveOnyxAgentCameraBridgeRuntimeState(
    status: status,
    snapshot: snapshot,
    healthProbeConfigured: healthProbeConfigured,
    validationInFlight: validationInFlight,
    nowUtc: nowUtc,
  );
  return OnyxAgentCameraBridgeSurfaceState(
    runtimeState: runtimeState,
    controls: resolveOnyxAgentCameraBridgeHealthControlState(
      validationInFlight: validationInFlight,
      resetInFlight: resetInFlight,
      healthProbeConfigured: healthProbeConfigured,
      hasLocalSnapshot: hasLocalSnapshot,
    ),
    shellSummary: describeOnyxAgentCameraBridgeShellSummary(
      shellState: runtimeState.shellState,
      snapshot: snapshot,
      endpointLabel: status.endpointLabel,
    ),
    controllerCardSummary: describeOnyxAgentCameraBridgeShellSummary(
      shellState: runtimeState.shellState,
      snapshot: snapshot,
      endpointLabel: status.endpointLabel,
      variant: OnyxAgentCameraBridgeShellSummaryVariant.controllerCard,
    ),
  );
}

OnyxAgentCameraBridgeStatusTone resolveOnyxAgentCameraBridgeStatusTone({
  required bool bridgeEnabled,
  required bool bridgeLive,
  required String statusLabel,
}) {
  if (bridgeLive) {
    return OnyxAgentCameraBridgeStatusTone.live;
  }
  final normalizedStatus = statusLabel.trim().toLowerCase();
  if (normalizedStatus == 'failed') {
    return OnyxAgentCameraBridgeStatusTone.failed;
  }
  if (normalizedStatus == 'starting') {
    return OnyxAgentCameraBridgeStatusTone.starting;
  }
  if (!bridgeEnabled) {
    return OnyxAgentCameraBridgeStatusTone.disabled;
  }
  return OnyxAgentCameraBridgeStatusTone.standby;
}

OnyxAgentCameraBridgeStatusTone resolveOnyxAgentCameraBridgeStatusToneForStatus(
  OnyxAgentCameraBridgeStatus status,
) {
  return resolveOnyxAgentCameraBridgeStatusTone(
    bridgeEnabled: status.enabled,
    bridgeLive: status.isLive,
    statusLabel: status.statusLabel,
  );
}

OnyxAgentCameraBridgeStatusBadge visibleOnyxAgentCameraBridgeStatusBadge({
  required bool bridgeEnabled,
  required bool bridgeLive,
  required String statusLabel,
}) {
  return OnyxAgentCameraBridgeStatusBadge(
    label: statusLabel.trim().toUpperCase(),
    tone: resolveOnyxAgentCameraBridgeStatusTone(
      bridgeEnabled: bridgeEnabled,
      bridgeLive: bridgeLive,
      statusLabel: statusLabel,
    ),
  );
}

OnyxAgentCameraBridgeStatusBadge
visibleOnyxAgentCameraBridgeStatusBadgeForStatus(
  OnyxAgentCameraBridgeStatus status,
) {
  return visibleOnyxAgentCameraBridgeStatusBadge(
    bridgeEnabled: status.enabled,
    bridgeLive: status.isLive,
    statusLabel: status.statusLabel,
  );
}

OnyxAgentCameraBridgeHealthTone resolveOnyxAgentCameraBridgeHealthTone(
  OnyxAgentCameraBridgeHealthSnapshot? snapshot,
) {
  if (snapshot == null) {
    return OnyxAgentCameraBridgeHealthTone.status;
  }
  if (!snapshot.reachable) {
    return OnyxAgentCameraBridgeHealthTone.error;
  }
  if (!snapshot.running) {
    return OnyxAgentCameraBridgeHealthTone.warning;
  }
  return OnyxAgentCameraBridgeHealthTone.success;
}

OnyxAgentCameraBridgeHealthBadge? visibleOnyxAgentCameraBridgeHealthBadge(
  OnyxAgentCameraBridgeHealthSnapshot? snapshot,
) {
  if (snapshot == null) {
    return null;
  }
  return OnyxAgentCameraBridgeHealthBadge(
    label: snapshot.statusLabel.toUpperCase(),
    tone: resolveOnyxAgentCameraBridgeHealthTone(snapshot),
  );
}

String describeOnyxAgentCameraBridgeHealthLoading({
  OnyxAgentCameraBridgeHealthLoadingVariant variant =
      OnyxAgentCameraBridgeHealthLoadingVariant.agent,
}) {
  return switch (variant) {
    OnyxAgentCameraBridgeHealthLoadingVariant.agent =>
      'Running GET /health against the local camera bridge...',
    OnyxAgentCameraBridgeHealthLoadingVariant.admin =>
      'Running GET /health against the configured local bridge endpoint...',
  };
}

List<OnyxAgentCameraBridgeHealthField>
visibleOnyxAgentCameraBridgeHealthFields({
  required OnyxAgentCameraBridgeHealthSnapshot snapshot,
  required String receiptStateLabel,
  required String checkedAtLabel,
}) {
  final fields = <OnyxAgentCameraBridgeHealthField>[
    OnyxAgentCameraBridgeHealthField(
      label: 'HTTP',
      value: snapshot.statusCode?.toString() ?? 'No response',
    ),
    OnyxAgentCameraBridgeHealthField(
      label: 'Receipt state',
      value: receiptStateLabel,
    ),
    OnyxAgentCameraBridgeHealthField(
      label: 'Health',
      value: snapshot.healthRouteLabel,
    ),
  ];
  if (snapshot.mismatchStatusLabel != null) {
    fields.add(
      OnyxAgentCameraBridgeHealthField(
        label: 'Endpoint mismatch',
        value: snapshot.mismatchStatusLabel!,
      ),
    );
  }
  if (snapshot.hasReportedBindMismatch) {
    fields.add(
      OnyxAgentCameraBridgeHealthField(
        label: 'Probed bind',
        value: snapshot.probedBindLabel,
      ),
    );
  }
  if (snapshot.reportedBindLabel != null) {
    fields.add(
      OnyxAgentCameraBridgeHealthField(
        label: 'Reported bind',
        value: snapshot.reportedBindLabel!,
      ),
    );
  }
  fields.add(
    OnyxAgentCameraBridgeHealthField(
      label: 'Validated at',
      value: checkedAtLabel,
    ),
  );
  if (snapshot.operatorId.trim().isNotEmpty) {
    fields.add(
      OnyxAgentCameraBridgeHealthField(
        label: 'Validated by',
        value: snapshot.operatorId.trim(),
      ),
    );
  }
  fields.add(
    OnyxAgentCameraBridgeHealthField(
      label: 'Route',
      value: snapshot.routeLabel,
    ),
  );
  return fields;
}

List<String> visibleOnyxAgentCameraBridgeClipboardDetailLines({
  required OnyxAgentCameraBridgeHealthSnapshot snapshot,
  required String receiptStateLabel,
}) {
  final lines = <String>[
    'Validation: ${snapshot.statusLabel.toUpperCase()}',
    'Health: ${snapshot.healthRouteLabel}',
  ];
  if (snapshot.mismatchStatusLabel != null) {
    lines.add(
      'Endpoint mismatch: ${snapshot.mismatchStatusLabel!.toUpperCase()}',
    );
  }
  if (snapshot.hasReportedBindMismatch) {
    lines.add('Probed bind: ${snapshot.probedBindLabel}');
  }
  if (snapshot.reportedBindLabel != null) {
    lines.add('Reported bind: ${snapshot.reportedBindLabel!}');
  }
  lines.add(
    'Validated at: ${formatOnyxAgentCameraBridgeCheckedAtLabel(snapshot.checkedAtUtc)}',
  );
  lines.add('Receipt state: $receiptStateLabel');
  lines.add('Receipt freshness: $receiptStateLabel');
  if (snapshot.operatorId.trim().isNotEmpty) {
    lines.add('Validated by: ${snapshot.operatorId.trim()}');
  }
  lines.add('Route: ${snapshot.routeLabel}');
  return lines;
}

List<String> visibleOnyxAgentCameraBridgeClipboardPlaceholderDetailLines({
  required String validationLabel,
  required String receiptStateLabel,
}) {
  return <String>[
    'Validation: $validationLabel',
    'Receipt state: $receiptStateLabel',
    'Receipt freshness: $receiptStateLabel',
  ];
}

List<String> visibleOnyxAgentCameraBridgeClipboardLines({
  required OnyxAgentCameraBridgeHealthSnapshot? snapshot,
  required OnyxAgentCameraBridgeReceiptState? receiptState,
}) {
  if (snapshot != null && receiptState != null) {
    return visibleOnyxAgentCameraBridgeClipboardDetailLines(
      snapshot: snapshot,
      receiptStateLabel: receiptState.label,
    );
  }
  return switch (receiptState) {
    OnyxAgentCameraBridgeReceiptState.missing =>
      visibleOnyxAgentCameraBridgeClipboardPlaceholderDetailLines(
        validationLabel: 'NOT RUN',
        receiptStateLabel: OnyxAgentCameraBridgeReceiptState.missing.label,
      ),
    OnyxAgentCameraBridgeReceiptState.unavailable =>
      visibleOnyxAgentCameraBridgeClipboardPlaceholderDetailLines(
        validationLabel: 'UNAVAILABLE',
        receiptStateLabel: OnyxAgentCameraBridgeReceiptState.unavailable.label,
      ),
    OnyxAgentCameraBridgeReceiptState.current ||
    OnyxAgentCameraBridgeReceiptState.stale ||
    null => const <String>[],
  };
}

String buildOnyxAgentCameraBridgeClipboardPayload({
  required String base,
  required String shellStateLabel,
  required String shellSummary,
  Iterable<String> detailLines = const <String>[],
}) {
  final buffer = StringBuffer(base)
    ..write('\nShell state: $shellStateLabel')
    ..write('\nShell summary: $shellSummary');
  for (final line in detailLines) {
    buffer.write('\n$line');
  }
  return buffer.toString();
}

String buildOnyxAgentCameraBridgeClipboardPayloadForRuntime({
  required OnyxAgentCameraBridgeStatus status,
  required OnyxAgentCameraBridgeRuntimeState runtimeState,
  required String shellSummary,
  required OnyxAgentCameraBridgeHealthSnapshot? snapshot,
}) {
  return buildOnyxAgentCameraBridgeClipboardPayload(
    base: status.toClipboardPayload(),
    shellStateLabel: runtimeState.shellState.label,
    shellSummary: shellSummary,
    detailLines: visibleOnyxAgentCameraBridgeClipboardLines(
      snapshot: snapshot,
      receiptState: runtimeState.receiptState,
    ),
  );
}

String buildOnyxAgentCameraBridgeClipboardPayloadForSurfaceState({
  required OnyxAgentCameraBridgeStatus status,
  required OnyxAgentCameraBridgeSurfaceState surfaceState,
  required OnyxAgentCameraBridgeHealthSnapshot? snapshot,
}) {
  return buildOnyxAgentCameraBridgeClipboardPayloadForRuntime(
    status: status,
    runtimeState: surfaceState.runtimeState,
    shellSummary: surfaceState.shellSummary,
    snapshot: snapshot,
  );
}

List<OnyxAgentCameraBridgeChip> visibleOnyxAgentCameraBridgeRuntimeChips({
  required bool authRequired,
  required bool bridgeLive,
  OnyxAgentCameraBridgeChipVariant variant =
      OnyxAgentCameraBridgeChipVariant.agent,
}) {
  final chips = <OnyxAgentCameraBridgeChip>[
    OnyxAgentCameraBridgeChip(
      label: switch (variant) {
        OnyxAgentCameraBridgeChipVariant.agent =>
          authRequired ? 'AUTH REQUIRED' : 'LOCAL ACCESS',
        OnyxAgentCameraBridgeChipVariant.admin =>
          authRequired ? 'Auth required' : 'Local access',
      },
      tone: authRequired
          ? OnyxAgentCameraBridgeChipTone.warning
          : OnyxAgentCameraBridgeChipTone.info,
    ),
  ];
  if (variant == OnyxAgentCameraBridgeChipVariant.admin) {
    chips.add(
      OnyxAgentCameraBridgeChip(
        label: bridgeLive ? 'Packet ingress ready' : 'Packet ingress pending',
        tone: OnyxAgentCameraBridgeChipTone.status,
      ),
    );
  }
  return chips;
}

List<OnyxAgentCameraBridgeChip> visibleOnyxAgentCameraBridgeShellChips({
  required OnyxAgentCameraBridgeShellState shellState,
  required OnyxAgentCameraBridgeReceiptState? receiptState,
  OnyxAgentCameraBridgeChipVariant variant =
      OnyxAgentCameraBridgeChipVariant.agent,
}) {
  final chips = <OnyxAgentCameraBridgeChip>[];
  if (shellState == OnyxAgentCameraBridgeShellState.bindMismatch) {
    chips.add(
      OnyxAgentCameraBridgeChip(
        label: switch (variant) {
          OnyxAgentCameraBridgeChipVariant.agent => 'BIND MISMATCH',
          OnyxAgentCameraBridgeChipVariant.admin => 'Bind mismatch',
        },
        tone: OnyxAgentCameraBridgeChipTone.danger,
      ),
    );
  }
  switch (receiptState) {
    case OnyxAgentCameraBridgeReceiptState.current:
      chips.add(
        OnyxAgentCameraBridgeChip(
          label: switch (variant) {
            OnyxAgentCameraBridgeChipVariant.agent => 'RECENT RECEIPT',
            OnyxAgentCameraBridgeChipVariant.admin => 'Receipt recent',
          },
          tone: OnyxAgentCameraBridgeChipTone.success,
        ),
      );
    case OnyxAgentCameraBridgeReceiptState.stale:
      chips.add(
        OnyxAgentCameraBridgeChip(
          label: switch (variant) {
            OnyxAgentCameraBridgeChipVariant.agent => 'STALE RECEIPT',
            OnyxAgentCameraBridgeChipVariant.admin => 'Receipt stale',
          },
          tone: OnyxAgentCameraBridgeChipTone.warning,
        ),
      );
    case OnyxAgentCameraBridgeReceiptState.missing:
      chips.add(
        OnyxAgentCameraBridgeChip(
          label: switch (variant) {
            OnyxAgentCameraBridgeChipVariant.agent => 'UNVALIDATED',
            OnyxAgentCameraBridgeChipVariant.admin => 'Receipt missing',
          },
          tone: OnyxAgentCameraBridgeChipTone.warning,
        ),
      );
    case OnyxAgentCameraBridgeReceiptState.unavailable:
      chips.add(
        OnyxAgentCameraBridgeChip(
          label: switch (variant) {
            OnyxAgentCameraBridgeChipVariant.agent => 'RECEIPT UNAVAILABLE',
            OnyxAgentCameraBridgeChipVariant.admin => 'Receipt unavailable',
          },
          tone: OnyxAgentCameraBridgeChipTone.neutral,
        ),
      );
    case null:
      break;
  }
  return chips;
}

List<OnyxAgentCameraBridgeChip> visibleOnyxAgentCameraBridgePanelChips({
  required bool authRequired,
  required bool bridgeLive,
  required OnyxAgentCameraBridgeShellState shellState,
  required OnyxAgentCameraBridgeReceiptState? receiptState,
  OnyxAgentCameraBridgeChipVariant variant =
      OnyxAgentCameraBridgeChipVariant.agent,
}) {
  return <OnyxAgentCameraBridgeChip>[
    ...visibleOnyxAgentCameraBridgeRuntimeChips(
      authRequired: authRequired,
      bridgeLive: bridgeLive,
      variant: variant,
    ),
    ...visibleOnyxAgentCameraBridgeShellChips(
      shellState: shellState,
      receiptState: receiptState,
      variant: variant,
    ),
  ];
}

OnyxAgentCameraBridgeValidateAction resolveOnyxAgentCameraBridgeValidateAction({
  required OnyxAgentCameraBridgeReceiptState? receiptState,
  bool validationInFlight = false,
}) {
  if (validationInFlight) {
    return OnyxAgentCameraBridgeValidateAction.validating;
  }
  return switch (receiptState) {
    OnyxAgentCameraBridgeReceiptState.missing =>
      OnyxAgentCameraBridgeValidateAction.firstValidation,
    OnyxAgentCameraBridgeReceiptState.current ||
    OnyxAgentCameraBridgeReceiptState.stale =>
      OnyxAgentCameraBridgeValidateAction.revalidate,
    OnyxAgentCameraBridgeReceiptState.unavailable ||
    null => OnyxAgentCameraBridgeValidateAction.validate,
  };
}

OnyxAgentCameraBridgeShellState resolveOnyxAgentCameraBridgeShellState({
  required OnyxAgentCameraBridgeReceiptState? receiptState,
  required bool bridgeEnabled,
  required bool bridgeLive,
  required bool bindMismatchDetected,
  bool bridgeFailed = false,
}) {
  if (bindMismatchDetected) {
    return OnyxAgentCameraBridgeShellState.bindMismatch;
  }
  return switch (receiptState) {
    OnyxAgentCameraBridgeReceiptState.stale =>
      OnyxAgentCameraBridgeShellState.receiptStale,
    OnyxAgentCameraBridgeReceiptState.missing =>
      OnyxAgentCameraBridgeShellState.receiptMissing,
    OnyxAgentCameraBridgeReceiptState.unavailable =>
      OnyxAgentCameraBridgeShellState.receiptUnavailable,
    OnyxAgentCameraBridgeReceiptState.current =>
      OnyxAgentCameraBridgeShellState.ready,
    null =>
      !bridgeEnabled
          ? OnyxAgentCameraBridgeShellState.disabled
          : bridgeLive
          ? OnyxAgentCameraBridgeShellState.ready
          : bridgeFailed
          ? OnyxAgentCameraBridgeShellState.failed
          : OnyxAgentCameraBridgeShellState.pending,
  };
}

bool isOnyxAgentCameraBridgeStatusFailed(OnyxAgentCameraBridgeStatus status) {
  return status.statusLabel.trim().toLowerCase() == 'failed';
}

OnyxAgentCameraBridgeShellState
resolveOnyxAgentCameraBridgeShellStateForStatus({
  required OnyxAgentCameraBridgeStatus status,
  required OnyxAgentCameraBridgeHealthSnapshot? snapshot,
  required OnyxAgentCameraBridgeReceiptState? receiptState,
}) {
  return resolveOnyxAgentCameraBridgeShellState(
    receiptState: receiptState,
    bridgeEnabled: status.enabled,
    bridgeLive: status.isLive,
    bindMismatchDetected: snapshot?.hasReportedBindMismatch == true,
    bridgeFailed: isOnyxAgentCameraBridgeStatusFailed(status),
  );
}

String describeOnyxAgentCameraBridgeShellSummary({
  required OnyxAgentCameraBridgeShellState shellState,
  OnyxAgentCameraBridgeHealthSnapshot? snapshot,
  String? endpointLabel,
  OnyxAgentCameraBridgeShellSummaryVariant variant =
      OnyxAgentCameraBridgeShellSummaryVariant.standard,
}) {
  final normalizedEndpointLabel = endpointLabel?.trim() ?? '';
  if (variant == OnyxAgentCameraBridgeShellSummaryVariant.controllerCard) {
    return switch (shellState) {
      OnyxAgentCameraBridgeShellState.bindMismatch =>
        'Latest validation reported a different bind than ONYX probed. Compare the probed and reported endpoints before handing this bridge to LAN workers.',
      OnyxAgentCameraBridgeShellState.receiptMissing =>
        'Local camera bridge is live, but no validation receipt has been captured yet. Run GET /health before handing this bridge to LAN workers.',
      OnyxAgentCameraBridgeShellState.receiptUnavailable =>
        'Local camera bridge is live, but the in-app health probe is unavailable on this ONYX runtime.',
      OnyxAgentCameraBridgeShellState.receiptStale ||
      OnyxAgentCameraBridgeShellState.ready =>
        'Local camera bridge is ready for LAN worker packets.',
      OnyxAgentCameraBridgeShellState.disabled ||
      OnyxAgentCameraBridgeShellState.failed ||
      OnyxAgentCameraBridgeShellState.pending =>
        'Local camera bridge visibility stays here so camera tools never have to fall back into a hidden legacy workspace.',
    };
  }
  return switch (shellState) {
    OnyxAgentCameraBridgeShellState.bindMismatch =>
      snapshot?.reportedBindLabel != null
          ? 'Latest bridge validation reported a different bind than ONYX probed. Reconcile ${snapshot!.probedBindLabel} vs ${snapshot.reportedBindLabel!} before giving this listener to LAN workers.'
          : 'Latest bridge validation reported a different bind than ONYX probed. Compare the probed and reported endpoints before handing this bridge to LAN workers.',
    OnyxAgentCameraBridgeShellState.receiptStale =>
      normalizedEndpointLabel.isNotEmpty
          ? 'Bridge validation receipt is stale. Re-run GET /health before trusting $normalizedEndpointLabel for LAN worker setup.'
          : 'Local camera bridge is live, but the last validation receipt is stale. Re-run GET /health before handing this bridge to LAN workers.',
    OnyxAgentCameraBridgeShellState.receiptMissing =>
      normalizedEndpointLabel.isNotEmpty
          ? 'No bridge validation receipt has been captured yet. Run GET /health before trusting $normalizedEndpointLabel for LAN worker setup.'
          : 'Local camera bridge is live, but no validation receipt has been captured yet. Run GET /health before handing this bridge to LAN workers.',
    OnyxAgentCameraBridgeShellState.receiptUnavailable =>
      normalizedEndpointLabel.isNotEmpty
          ? 'Bridge validation receipt is unavailable on this ONYX runtime. Configure the in-app health probe before trusting $normalizedEndpointLabel for LAN worker setup.'
          : 'Local camera bridge is live, but the in-app health probe is unavailable on this ONYX runtime.',
    OnyxAgentCameraBridgeShellState.disabled =>
      'Enable the local camera bridge if you want LAN workers to post packets into ONYX.',
    OnyxAgentCameraBridgeShellState.ready =>
      normalizedEndpointLabel.isNotEmpty
          ? 'LAN workers can target $normalizedEndpointLabel/execute and poll $normalizedEndpointLabel/health right now.'
          : 'Local camera bridge is ready for LAN worker packets.',
    OnyxAgentCameraBridgeShellState.failed =>
      'Repair the host, port, or socket permission issue before retrying the local bridge bind.',
    OnyxAgentCameraBridgeShellState.pending =>
      'Keep the configured bind address ready while the bridge finishes binding on this ONYX host.',
  };
}

int? _readInt(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString().trim() ?? '');
}

abstract class OnyxAgentCameraBridgeHealthService {
  bool get isConfigured;

  Future<OnyxAgentCameraBridgeHealthSnapshot> probe(Uri endpoint);
}

class UnconfiguredOnyxAgentCameraBridgeHealthService
    implements OnyxAgentCameraBridgeHealthService {
  const UnconfiguredOnyxAgentCameraBridgeHealthService();

  @override
  bool get isConfigured => false;

  @override
  Future<OnyxAgentCameraBridgeHealthSnapshot> probe(Uri endpoint) async {
    final healthEndpoint = endpoint.replace(path: '/health');
    return OnyxAgentCameraBridgeHealthSnapshot(
      requestedEndpoint: endpoint,
      healthEndpoint: healthEndpoint,
      reachable: false,
      running: false,
      statusLabel: 'Unavailable',
      detail:
          'The in-app bridge health probe is not configured on this ONYX runtime.',
      executePath: '/execute',
      checkedAtUtc: DateTime.now().toUtc(),
    );
  }
}

class HttpOnyxAgentCameraBridgeHealthService
    implements OnyxAgentCameraBridgeHealthService {
  final http.Client client;
  final Duration timeout;

  const HttpOnyxAgentCameraBridgeHealthService({
    required this.client,
    this.timeout = const Duration(seconds: 3),
  });

  @override
  bool get isConfigured => true;

  @override
  Future<OnyxAgentCameraBridgeHealthSnapshot> probe(Uri endpoint) async {
    final healthEndpoint = endpoint.replace(path: '/health');
    final checkedAtUtc = DateTime.now().toUtc();
    try {
      final response = await client.get(healthEndpoint).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return OnyxAgentCameraBridgeHealthSnapshot(
          requestedEndpoint: endpoint,
          healthEndpoint: healthEndpoint,
          reachable: true,
          running: false,
          statusCode: response.statusCode,
          statusLabel: 'Degraded',
          detail:
              'GET /health responded with HTTP ${response.statusCode}. The bridge is reachable but did not report a clean runtime state.',
          executePath: '/execute',
          checkedAtUtc: checkedAtUtc,
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return OnyxAgentCameraBridgeHealthSnapshot(
          requestedEndpoint: endpoint,
          healthEndpoint: healthEndpoint,
          reachable: true,
          running: false,
          statusCode: response.statusCode,
          statusLabel: 'Unexpected response',
          detail:
              'GET /health responded with HTTP ${response.statusCode}, but the payload did not match the camera bridge contract.',
          executePath: '/execute',
          checkedAtUtc: checkedAtUtc,
        );
      }

      final payload = decoded.map(
        (key, value) => MapEntry(key.toString(), value as Object?),
      );
      final running = payload['running'] == true;
      final reportedEndpoint = Uri.tryParse(
        payload['endpoint']?.toString().trim() ?? '',
      );
      final executePath = payload['execute_path']?.toString().trim() ?? '';
      final status = payload['status']?.toString().trim().toLowerCase() ?? '';
      final mismatchDetail =
          reportedEndpoint != null &&
              reportedEndpoint.toString() != endpoint.toString()
          ? ' Bridge reported bind ${reportedEndpoint.toString()} while ONYX probed ${endpoint.toString()}.'
          : '';
      return OnyxAgentCameraBridgeHealthSnapshot(
        requestedEndpoint: endpoint,
        healthEndpoint: healthEndpoint,
        reportedEndpoint: reportedEndpoint,
        reachable: true,
        running: running,
        statusCode: response.statusCode,
        statusLabel: running && status == 'ok' ? 'Healthy' : 'Reachable',
        detail: running
            ? 'GET /health succeeded and the bridge reported packet ingress ready.$mismatchDetail'
            : 'GET /health succeeded, but the bridge did not report an active packet ingress state.$mismatchDetail',
        executePath: executePath.isEmpty ? '/execute' : executePath,
        checkedAtUtc: checkedAtUtc,
      );
    } on TimeoutException {
      return OnyxAgentCameraBridgeHealthSnapshot(
        requestedEndpoint: endpoint,
        healthEndpoint: healthEndpoint,
        reachable: false,
        running: false,
        statusLabel: 'Timed out',
        detail:
            'GET /health did not answer within ${timeout.inSeconds} seconds. Check the local listener and host firewall before retrying.',
        executePath: '/execute',
        checkedAtUtc: checkedAtUtc,
      );
    } catch (error) {
      return OnyxAgentCameraBridgeHealthSnapshot(
        requestedEndpoint: endpoint,
        healthEndpoint: healthEndpoint,
        reachable: false,
        running: false,
        statusLabel: 'Unreachable',
        detail:
            'GET /health could not reach the local camera bridge endpoint. $error',
        executePath: '/execute',
        checkedAtUtc: checkedAtUtc,
      );
    }
  }
}
