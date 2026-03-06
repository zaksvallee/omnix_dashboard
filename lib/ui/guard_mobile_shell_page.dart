import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../domain/guard/guard_ops_event.dart';
import '../domain/guard/guard_mobile_ops.dart';
import '../domain/guard/outcome_label_governance.dart';
import '../domain/guard/guard_sync_coaching_policy.dart';
import 'onyx_surface.dart';

enum _GuardMobileScreen {
  shiftStart,
  dispatch,
  status,
  checkpoint,
  panic,
  sync,
}

enum GuardMobileInitialScreen { dispatch, sync }

enum GuardMobileOperatorRole { guard, reaction, supervisor }

enum _SyncRowFilter { all, failed, pending, synced }

enum _ExportAuditFilter {
  all,
  generated,
  cleared,
  verification,
  telemetryAlert,
}

enum GuardSyncOperationModeFilter { all, live, stub, unknown }

enum GuardSyncHistoryFilter { queued, synced, failed, all }

class GuardMobileShellPage extends StatefulWidget {
  final String clientId;
  final String siteId;
  final String guardId;
  final bool syncBackendEnabled;
  final int queueDepth;
  final int pendingEventCount;
  final int pendingMediaCount;
  final int failedEventCount;
  final int failedMediaCount;
  final List<GuardOpsEvent> recentEvents;
  final List<GuardOpsMediaUpload> recentMedia;
  final bool syncInFlight;
  final String? syncStatusLabel;
  final String activeShiftId;
  final int activeShiftSequenceWatermark;
  final String? lastCloseoutPacketAuditLabel;
  final String? lastShiftReplayAuditLabel;
  final String? lastSyncReportAuditLabel;
  final String? lastExportAuditClearLabel;
  final String telemetryAdapterLabel;
  final bool telemetryAdapterStubMode;
  final String? telemetryProviderId;
  final String? telemetryProviderStatusLabel;
  final String telemetryProviderReadiness;
  final bool telemetryLiveReadyGateEnabled;
  final bool telemetryLiveReadyGateViolation;
  final String? telemetryLiveReadyGateReason;
  final String? telemetryFacadeId;
  final bool? telemetryFacadeLiveMode;
  final String? telemetryFacadeToggleSource;
  final String? telemetryFacadeRuntimeMode;
  final String? telemetryFacadeHeartbeatSource;
  final String? telemetryFacadeHeartbeatAction;
  final bool? telemetryFacadeSourceActive;
  final int? telemetryFacadeCallbackCount;
  final DateTime? telemetryFacadeLastCallbackAtUtc;
  final String? telemetryFacadeLastCallbackMessage;
  final int? telemetryFacadeCallbackErrorCount;
  final DateTime? telemetryFacadeLastCallbackErrorAtUtc;
  final String? telemetryFacadeLastCallbackErrorMessage;
  final int resumeSyncEventThrottleSeconds;
  final DateTime? lastSuccessfulSyncAtUtc;
  final String? lastFailureReason;
  final GuardCoachingPrompt coachingPrompt;
  final GuardSyncCoachingPolicy coachingPolicy;
  final List<GuardSyncOperation> queuedOperations;
  final GuardSyncHistoryFilter historyFilter;
  final Future<void> Function(GuardSyncHistoryFilter filter)
  onHistoryFilterChanged;
  final GuardSyncOperationModeFilter operationModeFilter;
  final Future<void> Function(GuardSyncOperationModeFilter filter)
  onOperationModeFilterChanged;
  final List<String> availableFacadeIds;
  final String? selectedFacadeId;
  final Future<void> Function(String? facadeId) onFacadeIdFilterChanged;
  final int scopedSelectionCount;
  final List<String> scopedSelectionKeys;
  final Map<String, String> scopedSelectionsByScope;
  final String activeScopeKey;
  final bool activeScopeHasSelection;
  final String? initialSelectedOperationId;
  final Future<void> Function(String? operationId) onSelectedOperationChanged;
  final Future<void> Function() onShiftStartQueued;
  final Future<void> Function() onShiftEndQueued;
  final Future<void> Function(GuardDutyStatus status) onStatusQueued;
  final Future<void> Function()? onReactionIncidentAcceptedQueued;
  final Future<void> Function()? onReactionOfficerArrivedQueued;
  final Future<void> Function()? onReactionIncidentClearedQueued;
  final Future<void> Function(GuardDutyStatus status)?
  onSupervisorStatusOverrideQueued;
  final Future<void> Function()? onSupervisorCoachingAcknowledgedQueued;
  final Future<void> Function({
    required String checkpointId,
    required String nfcTagId,
  })
  onCheckpointQueued;
  final Future<void> Function({required String checkpointId})
  onPatrolImageQueued;
  final Future<void> Function() onPanicQueued;
  final Future<void> Function() onWearableHeartbeatQueued;
  final Future<void> Function() onDeviceHealthQueued;
  final Future<void> Function()? onSeedWearableBridge;
  final Future<void> Function()? onEmitTelemetryDebugHeartbeat;
  final Future<Map<String, Object?>> Function({
    required String fixtureId,
    required String payloadAdapter,
    Map<String, Object?>? customPayload,
  })?
  onValidateTelemetryPayloadReplay;
  final Future<void> Function({
    required String outcomeLabel,
    required String confidence,
    required String confirmedBy,
  })
  onOutcomeLabeled;
  final OutcomeLabelGovernancePolicy outcomeGovernancePolicy;
  final Future<void> Function() onClearQueue;
  final Future<void> Function() onSyncNow;
  final Future<void> Function() onRetryFailedEvents;
  final Future<void> Function() onRetryFailedMedia;
  final Future<void> Function(String operationId) onRetryFailedOperation;
  final Future<void> Function(List<String> operationIds)
  onRetryFailedOperationsBulk;
  final Future<void> Function({
    required DateTime generatedAtUtc,
    required String scopeKey,
    required String facadeMode,
    required String readinessState,
  })
  onDispatchCloseoutPacketCopied;
  final Future<void> Function({
    required DateTime generatedAtUtc,
    required String shiftId,
    required int eventRows,
    required int mediaRows,
  })?
  onShiftReplaySummaryCopied;
  final Future<void> Function({
    required DateTime generatedAtUtc,
    required String scopeKey,
    required String facadeMode,
    required String eventFilter,
    required String mediaFilter,
  })?
  onSyncReportCopied;
  final Future<void> Function()? onClearExportAudits;
  final Future<void> Function() onProbeTelemetryProvider;
  final int failedOpsWarnThreshold;
  final int failedOpsCriticalThreshold;
  final int oldestFailedWarnMinutes;
  final int oldestFailedCriticalMinutes;
  final int failedRetryWarnThreshold;
  final int failedRetryCriticalThreshold;
  final Future<void> Function({required String ruleId, required String context})
  onAcknowledgeCoachingPrompt;
  final Future<void> Function({
    required String ruleId,
    required String context,
    required int minutes,
    required String actorRole,
  })
  onSnoozeCoachingPrompt;
  final GuardMobileInitialScreen initialScreen;
  final GuardMobileOperatorRole operatorRole;

  const GuardMobileShellPage({
    super.key,
    required this.clientId,
    required this.siteId,
    required this.guardId,
    required this.syncBackendEnabled,
    required this.queueDepth,
    required this.pendingEventCount,
    required this.pendingMediaCount,
    required this.failedEventCount,
    required this.failedMediaCount,
    required this.recentEvents,
    required this.recentMedia,
    required this.syncInFlight,
    required this.syncStatusLabel,
    this.activeShiftId = '',
    this.activeShiftSequenceWatermark = 0,
    this.lastCloseoutPacketAuditLabel,
    this.lastShiftReplayAuditLabel,
    this.lastSyncReportAuditLabel,
    this.lastExportAuditClearLabel,
    this.telemetryAdapterLabel = 'unknown',
    this.telemetryAdapterStubMode = true,
    this.telemetryProviderId,
    this.telemetryProviderStatusLabel,
    this.telemetryProviderReadiness = 'degraded',
    this.telemetryLiveReadyGateEnabled = false,
    this.telemetryLiveReadyGateViolation = false,
    this.telemetryLiveReadyGateReason,
    this.telemetryFacadeId,
    this.telemetryFacadeLiveMode,
    this.telemetryFacadeToggleSource,
    this.telemetryFacadeRuntimeMode,
    this.telemetryFacadeHeartbeatSource,
    this.telemetryFacadeHeartbeatAction,
    this.telemetryFacadeSourceActive,
    this.telemetryFacadeCallbackCount,
    this.telemetryFacadeLastCallbackAtUtc,
    this.telemetryFacadeLastCallbackMessage,
    this.telemetryFacadeCallbackErrorCount,
    this.telemetryFacadeLastCallbackErrorAtUtc,
    this.telemetryFacadeLastCallbackErrorMessage,
    this.resumeSyncEventThrottleSeconds = 20,
    required this.lastSuccessfulSyncAtUtc,
    required this.lastFailureReason,
    required this.coachingPrompt,
    required this.coachingPolicy,
    required this.queuedOperations,
    required this.historyFilter,
    required this.onHistoryFilterChanged,
    this.operationModeFilter = GuardSyncOperationModeFilter.all,
    required this.onOperationModeFilterChanged,
    this.availableFacadeIds = const [],
    this.selectedFacadeId,
    required this.onFacadeIdFilterChanged,
    this.scopedSelectionCount = 0,
    this.scopedSelectionKeys = const [],
    this.scopedSelectionsByScope = const {},
    this.activeScopeKey = '',
    this.activeScopeHasSelection = false,
    this.initialSelectedOperationId,
    required this.onSelectedOperationChanged,
    required this.onShiftStartQueued,
    required this.onShiftEndQueued,
    required this.onStatusQueued,
    this.onReactionIncidentAcceptedQueued,
    this.onReactionOfficerArrivedQueued,
    this.onReactionIncidentClearedQueued,
    this.onSupervisorStatusOverrideQueued,
    this.onSupervisorCoachingAcknowledgedQueued,
    required this.onCheckpointQueued,
    required this.onPatrolImageQueued,
    required this.onPanicQueued,
    required this.onWearableHeartbeatQueued,
    required this.onDeviceHealthQueued,
    this.onSeedWearableBridge,
    this.onEmitTelemetryDebugHeartbeat,
    this.onValidateTelemetryPayloadReplay,
    required this.onOutcomeLabeled,
    required this.outcomeGovernancePolicy,
    required this.onClearQueue,
    required this.onSyncNow,
    required this.onRetryFailedEvents,
    required this.onRetryFailedMedia,
    required this.onRetryFailedOperation,
    required this.onRetryFailedOperationsBulk,
    required this.onDispatchCloseoutPacketCopied,
    this.onShiftReplaySummaryCopied,
    this.onSyncReportCopied,
    this.onClearExportAudits,
    required this.onProbeTelemetryProvider,
    this.failedOpsWarnThreshold = 1,
    this.failedOpsCriticalThreshold = 5,
    this.oldestFailedWarnMinutes = 10,
    this.oldestFailedCriticalMinutes = 30,
    this.failedRetryWarnThreshold = 8,
    this.failedRetryCriticalThreshold = 20,
    required this.onAcknowledgeCoachingPrompt,
    required this.onSnoozeCoachingPrompt,
    this.initialScreen = GuardMobileInitialScreen.dispatch,
    this.operatorRole = GuardMobileOperatorRole.guard,
  });

  @override
  State<GuardMobileShellPage> createState() => _GuardMobileShellPageState();
}

class _GuardMobileShellPageState extends State<GuardMobileShellPage> {
  static const _allFacadeFilterValue = '__all_facades__';
  static const _exportGeneratedFreshWindow = Duration(minutes: 30);
  static const _exportGeneratedStaleWindow = Duration(hours: 2);
  static const _exportRatioHealthyMax = 3.0;
  static const _exportRatioWarnMax = 6.0;
  static const int _maxHistoryOperationRows = 12;

  late _GuardMobileScreen _screen;
  bool _submitting = false;
  String _checkpointId = 'PERIMETER-NORTH';
  String _nfcTagId = 'NFC-TAG-001';
  String _outcomeConfidence = 'medium';
  String _outcomeConfirmedBy = 'supervisor';
  String? _lastActionStatus;
  bool _shiftVerified = false;
  String? _selectedEventId;
  String? _selectedMediaId;
  String? _selectedOperationId;
  _SyncRowFilter _eventFilter = _SyncRowFilter.all;
  _SyncRowFilter _mediaFilter = _SyncRowFilter.all;
  _ExportAuditFilter _exportAuditFilter = _ExportAuditFilter.all;
  bool _selectionClearNotifyQueued = false;
  String? _telemetryReplayOutput;
  String _customTelemetryPayloadJson = '';
  String _customTelemetryPayloadAdapter = 'standard';

  @override
  void initState() {
    super.initState();
    _screen = _screenFromInitial(widget.initialScreen);
    _ensureScreenAllowedForRole();
    _selectedOperationId = widget.initialSelectedOperationId;
    _ensureValidOutcomeConfirmer();
  }

  @override
  void didUpdateWidget(covariant GuardMobileShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialScreen != widget.initialScreen) {
      _screen = _screenFromInitial(widget.initialScreen);
    }
    if (oldWidget.operatorRole != widget.operatorRole) {
      _ensureScreenAllowedForRole();
    }
    if (oldWidget.initialSelectedOperationId !=
            widget.initialSelectedOperationId &&
        widget.initialSelectedOperationId != _selectedOperationId) {
      _selectedOperationId = widget.initialSelectedOperationId;
    }
    _ensureValidOutcomeConfirmer();
  }

  void _ensureValidOutcomeConfirmer() {
    final available = _availableConfirmationRoles();
    if (available.isEmpty) {
      return;
    }
    if (!available.contains(_outcomeConfirmedBy)) {
      _outcomeConfirmedBy = available.first;
    }
  }

  _GuardMobileScreen _screenFromInitial(GuardMobileInitialScreen screen) {
    return switch (screen) {
      GuardMobileInitialScreen.dispatch => _GuardMobileScreen.dispatch,
      GuardMobileInitialScreen.sync => _GuardMobileScreen.sync,
    };
  }

  List<_GuardMobileScreen> _screensForRole(GuardMobileOperatorRole role) {
    switch (role) {
      case GuardMobileOperatorRole.guard:
        return const [
          _GuardMobileScreen.shiftStart,
          _GuardMobileScreen.dispatch,
          _GuardMobileScreen.status,
          _GuardMobileScreen.checkpoint,
          _GuardMobileScreen.panic,
          _GuardMobileScreen.sync,
        ];
      case GuardMobileOperatorRole.reaction:
        return const [
          _GuardMobileScreen.dispatch,
          _GuardMobileScreen.status,
          _GuardMobileScreen.panic,
          _GuardMobileScreen.sync,
        ];
      case GuardMobileOperatorRole.supervisor:
        return const [
          _GuardMobileScreen.dispatch,
          _GuardMobileScreen.status,
          _GuardMobileScreen.sync,
        ];
    }
  }

  void _ensureScreenAllowedForRole() {
    final allowedScreens = _screensForRole(widget.operatorRole);
    if (allowedScreens.contains(_screen)) {
      return;
    }
    _screen = allowedScreens.first;
  }

  String _operatorRoleLabel(GuardMobileOperatorRole role) {
    switch (role) {
      case GuardMobileOperatorRole.guard:
        return 'Guard';
      case GuardMobileOperatorRole.reaction:
        return 'Reaction';
      case GuardMobileOperatorRole.supervisor:
        return 'Supervisor';
    }
  }

  String _headerSubtitleForRole(GuardMobileOperatorRole role) {
    switch (role) {
      case GuardMobileOperatorRole.guard:
        return 'Dispatch, status, checkpoint, and panic flow wired into the queued guard sync pipeline.';
      case GuardMobileOperatorRole.reaction:
        return 'Reaction mode for incident acceptance, response updates, and emergency escalation.';
      case GuardMobileOperatorRole.supervisor:
        return 'Supervisor mode for dispatch oversight, status overrides, and coaching governance.';
    }
  }

  String _formatUtc(DateTime value) {
    return value.toUtc().toIso8601String();
  }

  String _prettyJson(Map<String, Object?> value) {
    if (value.isEmpty) {
      return '{}';
    }
    return const JsonEncoder.withIndent('  ').convert(value);
  }

  Future<void> _runTelemetryReplayValidation({
    required String fixtureId,
    required String payloadAdapter,
    Map<String, Object?>? customPayload,
  }) async {
    final callback = widget.onValidateTelemetryPayloadReplay;
    if (callback == null) {
      throw StateError('Telemetry replay validation is not available.');
    }
    final result = await callback(
      fixtureId: fixtureId,
      payloadAdapter: payloadAdapter,
      customPayload: customPayload,
    );
    if (!mounted) return;
    setState(() {
      _telemetryReplayOutput = _prettyJson(result);
    });
  }

  Map<String, Object?> _decodeCustomTelemetryPayloadJson() {
    final raw = _customTelemetryPayloadJson.trim();
    if (raw.isEmpty) {
      throw StateError('Custom telemetry payload JSON is empty.');
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw StateError('Custom telemetry payload must be a JSON object.');
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  String _eventDetailText(GuardOpsEvent event) {
    return 'Event ${event.eventType.name}\n'
        'ID: ${event.eventId}\n'
        'Guard: ${event.guardId}\n'
        'Site: ${event.siteId}\n'
        'Shift: ${event.shiftId} seq ${event.sequence}\n'
        'Occurred: ${_formatUtc(event.occurredAt)}\n'
        'Synced: ${event.syncedAt == null ? 'pending' : _formatUtc(event.syncedAt!)}\n'
        'Retry Count: ${event.retryCount}\n'
        'Failure Trace: ${event.failureReason ?? 'none'}\n'
        'Payload:\n${_prettyJson(event.payload)}';
  }

  String _mediaDetailText(GuardOpsMediaUpload media) {
    return 'Media ${media.status.name}\n'
        'ID: ${media.mediaId}\n'
        'Event ID: ${media.eventId}\n'
        'Guard: ${media.guardId}\n'
        'Site: ${media.siteId}\n'
        'Shift: ${media.shiftId}\n'
        'Bucket: ${media.bucket}\n'
        'Path: ${media.path}\n'
        'Local Path: ${media.localPath}\n'
        'Captured: ${_formatUtc(media.capturedAt)}\n'
        'Uploaded: ${media.uploadedAt == null ? 'pending' : _formatUtc(media.uploadedAt!)}\n'
        'Retry Count: ${media.retryCount}\n'
        'Failure Trace: ${media.failureReason ?? 'none'}\n'
        'SHA256: ${media.sha256 ?? 'n/a'}';
  }

  String _filterLabel(_SyncRowFilter filter) {
    return switch (filter) {
      _SyncRowFilter.all => 'All',
      _SyncRowFilter.failed => 'Failed',
      _SyncRowFilter.pending => 'Pending',
      _SyncRowFilter.synced => 'Synced',
    };
  }

  String _exportAuditFilterLabel(_ExportAuditFilter filter) {
    return switch (filter) {
      _ExportAuditFilter.all => 'All',
      _ExportAuditFilter.generated => 'Generated',
      _ExportAuditFilter.cleared => 'Cleared',
      _ExportAuditFilter.verification => 'Verification',
      _ExportAuditFilter.telemetryAlert => 'Telemetry Alerts',
    };
  }

  bool _eventMatchesFilter(GuardOpsEvent event, _SyncRowFilter filter) {
    switch (filter) {
      case _SyncRowFilter.all:
        return true;
      case _SyncRowFilter.failed:
        return (event.failureReason ?? '').trim().isNotEmpty;
      case _SyncRowFilter.pending:
        return event.isPending && (event.failureReason ?? '').trim().isEmpty;
      case _SyncRowFilter.synced:
        return event.syncedAt != null &&
            (event.failureReason ?? '').trim().isEmpty;
    }
  }

  bool _mediaMatchesFilter(GuardOpsMediaUpload media, _SyncRowFilter filter) {
    switch (filter) {
      case _SyncRowFilter.all:
        return true;
      case _SyncRowFilter.failed:
        return media.status == GuardMediaUploadStatus.failed;
      case _SyncRowFilter.pending:
        return media.status == GuardMediaUploadStatus.queued;
      case _SyncRowFilter.synced:
        return media.status == GuardMediaUploadStatus.uploaded;
    }
  }

  String _eventRowSummary(GuardOpsEvent event) {
    final state = event.isPending
        ? 'pending'
        : (event.failureReason ?? '').trim().isNotEmpty
        ? 'failed'
        : 'synced';
    return '${event.eventType.name} • seq ${event.sequence} • $state • ${_formatUtc(event.occurredAt)}'
        '${(event.failureReason ?? '').trim().isEmpty ? '' : ' • ${event.failureReason}'}';
  }

  String _mediaRowSummary(GuardOpsMediaUpload media) {
    return '${media.bucket} • ${media.status.name} • ${_formatUtc(media.capturedAt)}'
        '${(media.failureReason ?? '').trim().isEmpty ? '' : ' • ${media.failureReason}'}';
  }

  String _operationDetailText(GuardSyncOperation operation) {
    return 'Operation ${operation.type.name}\n'
        'ID: ${operation.operationId}\n'
        'Status: ${operation.status.name}\n'
        'Created: ${_formatUtc(operation.createdAt)}\n'
        'Retry Count: ${operation.retryCount}\n'
        'Failure Reason: ${operation.failureReason ?? 'none'}\n'
        'Payload:\n${_prettyJson(operation.payload)}';
  }

  String _durationCompact(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes < 1) return '<1m';
    if (minutes < 60) return '${minutes}m';
    final hours = duration.inHours;
    if (hours < 24) return '${hours}h ${minutes % 60}m';
    final days = duration.inDays;
    return '${days}d ${hours % 24}h';
  }

  DateTime? _latestEventAt(GuardOpsEventType type) {
    return widget.recentEvents
        .where((event) => event.eventType == type)
        .map((event) => event.occurredAt.toUtc())
        .fold<DateTime?>(
          null,
          (latest, current) =>
              latest == null || current.isAfter(latest) ? current : latest,
        );
  }

  bool _hasOpenShift(DateTime nowUtc) {
    final latestStart = _latestEventAt(GuardOpsEventType.shiftStart);
    final latestEnd = _latestEventAt(GuardOpsEventType.shiftEnd);
    if (latestStart == null) {
      return false;
    }
    if (latestEnd == null) {
      return true;
    }
    return latestStart.isAfter(latestEnd);
  }

  String _shiftLifecycleLabel(DateTime nowUtc) {
    final latestStart = _latestEventAt(GuardOpsEventType.shiftStart);
    if (latestStart == null) {
      return 'no shift activity';
    }
    return _hasOpenShift(nowUtc) ? 'active' : 'closed';
  }

  String _openShiftAgeLabel(DateTime nowUtc) {
    if (!_hasOpenShift(nowUtc)) {
      return 'none';
    }
    final latestStart = _latestEventAt(GuardOpsEventType.shiftStart);
    if (latestStart == null) {
      return 'none';
    }
    return _durationCompact(nowUtc.difference(latestStart));
  }

  DateTime? _latestResumeSyncTriggerAt() {
    return widget.recentEvents
        .where((event) => event.eventType == GuardOpsEventType.syncStatus)
        .where((event) {
          final reason = (event.payload['sync_reason'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          return reason == 'app_resumed';
        })
        .map((event) => event.occurredAt.toUtc())
        .fold<DateTime?>(
          null,
          (latest, current) =>
              latest == null || current.isAfter(latest) ? current : latest,
        );
  }

  DateTime? _latestExportAuditResetEventAt() {
    return widget.recentEvents
        .where((event) => event.eventType == GuardOpsEventType.syncStatus)
        .where((event) {
          final cleared = event.payload['export_audits_cleared'];
          return cleared == true;
        })
        .map((event) => event.occurredAt.toUtc())
        .fold<DateTime?>(
          null,
          (latest, current) =>
              latest == null || current.isAfter(latest) ? current : latest,
        );
  }

  DateTime? _latestExportAuditGeneratedEventAt() {
    return widget.recentEvents
        .where((event) => event.eventType == GuardOpsEventType.syncStatus)
        .where((event) => event.payload['export_audit_generated'] == true)
        .map((event) => event.occurredAt.toUtc())
        .fold<DateTime?>(
          null,
          (latest, current) =>
              latest == null || current.isAfter(latest) ? current : latest,
        );
  }

  int _resumeSyncTriggerCount(String shiftId) {
    final key = shiftId.trim();
    if (key.isEmpty) return 0;
    return widget.recentEvents.where((event) {
      if (event.shiftId != key) return false;
      if (event.eventType != GuardOpsEventType.syncStatus) return false;
      final reason = (event.payload['sync_reason'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      return reason == 'app_resumed';
    }).length;
  }

  DateTime? _latestTelemetryPayloadHealthAlertAt() {
    return widget.recentEvents
        .where((event) => event.eventType == GuardOpsEventType.syncStatus)
        .where(
          (event) => event.payload['telemetry_payload_health_alert'] == true,
        )
        .map((event) => event.occurredAt.toUtc())
        .fold<DateTime?>(
          null,
          (latest, current) =>
              latest == null || current.isAfter(latest) ? current : latest,
        );
  }

  int _telemetryPayloadHealthAlertCount(String shiftId) {
    final key = shiftId.trim();
    if (key.isEmpty) return 0;
    return widget.recentEvents.where((event) {
      if (event.shiftId != key) return false;
      if (event.eventType != GuardOpsEventType.syncStatus) return false;
      return event.payload['telemetry_payload_health_alert'] == true;
    }).length;
  }

  int _exportAuditResetEventCount(String shiftId) {
    final key = shiftId.trim();
    if (key.isEmpty) return 0;
    return widget.recentEvents.where((event) {
      if (event.shiftId != key) return false;
      if (event.eventType != GuardOpsEventType.syncStatus) return false;
      return event.payload['export_audits_cleared'] == true;
    }).length;
  }

  int _exportAuditGeneratedEventCount(String shiftId, {String? exportType}) {
    final key = shiftId.trim();
    if (key.isEmpty) return 0;
    final normalizedType = exportType?.trim().toLowerCase();
    return widget.recentEvents.where((event) {
      if (event.shiftId != key) return false;
      if (event.eventType != GuardOpsEventType.syncStatus) return false;
      if (event.payload['export_audit_generated'] != true) return false;
      if (normalizedType == null || normalizedType.isEmpty) return true;
      final currentType = (event.payload['export_type'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      return currentType == normalizedType;
    }).length;
  }

  String _exportAuditGeneratedToClearedRatioLabel(String shiftId) {
    final generated = _exportAuditGeneratedEventCount(shiftId);
    final cleared = _exportAuditResetEventCount(shiftId);
    if (cleared == 0) {
      return generated == 0 ? '0.00' : 'n/a';
    }
    return (generated / cleared).toStringAsFixed(2);
  }

  String _exportAuditHealthThresholdsLabel() {
    final freshMinutes = _exportGeneratedFreshWindow.inMinutes;
    final staleWindow = _exportGeneratedStaleWindow;
    final staleLabel = staleWindow.inMinutes < 60
        ? '${staleWindow.inMinutes}m'
        : '${staleWindow.inHours}h';
    return 'generated freshness <=${freshMinutes}m (fresh), <=$staleLabel (warn), >$staleLabel (critical); ratio <=${_exportRatioHealthyMax.toStringAsFixed(0)} (healthy), <=${_exportRatioWarnMax.toStringAsFixed(0)} (warn), >${_exportRatioWarnMax.toStringAsFixed(0)} (critical)';
  }

  int _exportGeneratedHealthSeverity(
    DateTime? lastGeneratedAtUtc,
    DateTime nowUtc,
  ) {
    if (lastGeneratedAtUtc == null) return 0;
    final age = nowUtc.difference(lastGeneratedAtUtc.toUtc());
    if (age <= _exportGeneratedFreshWindow) return 0;
    if (age <= _exportGeneratedStaleWindow) return 1;
    return 2;
  }

  int _exportRatioHealthSeverity(String shiftId) {
    final generated = _exportAuditGeneratedEventCount(shiftId);
    final cleared = _exportAuditResetEventCount(shiftId);
    if (generated == 0 && cleared == 0) return 0;
    if (cleared == 0) return 1;
    final ratio = generated / cleared;
    if (ratio <= _exportRatioHealthyMax) return 0;
    if (ratio <= _exportRatioWarnMax) return 1;
    return 2;
  }

  String _exportHealthVerdict(String shiftId, DateTime nowUtc) {
    final generatedSeverity = _exportGeneratedHealthSeverity(
      _latestExportAuditGeneratedEventAt(),
      nowUtc,
    );
    final ratioSeverity = _exportRatioHealthSeverity(shiftId);
    final severity = generatedSeverity > ratioSeverity
        ? generatedSeverity
        : ratioSeverity;
    return switch (severity) {
      0 => 'Healthy',
      1 => 'Warn',
      _ => 'Critical',
    };
  }

  String _exportHealthReason(String shiftId, DateTime nowUtc) {
    final generatedAt = _latestExportAuditGeneratedEventAt();
    final generatedSeverity = _exportGeneratedHealthSeverity(
      generatedAt,
      nowUtc,
    );
    final ratioSeverity = _exportRatioHealthSeverity(shiftId);
    final generated = _exportAuditGeneratedEventCount(shiftId);
    final cleared = _exportAuditResetEventCount(shiftId);
    if (generated == 0 && cleared == 0) {
      return 'no export activity yet';
    }
    if (generatedSeverity >= ratioSeverity) {
      return switch (generatedSeverity) {
        0 => 'generated timestamp is within threshold',
        1 => 'generated timestamp is aging',
        _ => 'generated timestamp is stale',
      };
    }
    if (cleared == 0) {
      return 'generated exports without clears';
    }
    final ratio = generated / cleared;
    if (ratioSeverity == 1) {
      return 'gen/clear ratio elevated (${ratio.toStringAsFixed(2)})';
    }
    return 'gen/clear ratio high (${ratio.toStringAsFixed(2)})';
  }

  Color _exportAuditGeneratedHealthColor(
    DateTime? lastGeneratedAtUtc,
    DateTime nowUtc,
  ) {
    return switch (_exportGeneratedHealthSeverity(lastGeneratedAtUtc, nowUtc)) {
      0 when lastGeneratedAtUtc == null => const Color(0xFFB6C6DD),
      0 => const Color(0xFF8FD1FF),
      1 => const Color(0xFFF1B872),
      _ => const Color(0xFFFF8D9A),
    };
  }

  Color _exportAuditRatioHealthColor(String shiftId) {
    final generated = _exportAuditGeneratedEventCount(shiftId);
    final cleared = _exportAuditResetEventCount(shiftId);
    return switch (_exportRatioHealthSeverity(shiftId)) {
      0 when generated == 0 && cleared == 0 => const Color(0xFFB6C6DD),
      0 => const Color(0xFF8FD1FF),
      1 => const Color(0xFFF1B872),
      _ => const Color(0xFFFF8D9A),
    };
  }

  bool _matchesExportAuditFilter(
    GuardOpsEvent event,
    _ExportAuditFilter filter,
  ) {
    final generated = event.payload['export_audit_generated'] == true;
    final cleared = event.payload['export_audits_cleared'] == true;
    final verification =
        event.payload['telemetry_verification_checklist_passed'] == true;
    final telemetryAlert =
        event.payload['telemetry_payload_health_alert'] == true;
    return switch (filter) {
      _ExportAuditFilter.all =>
        generated || cleared || verification || telemetryAlert,
      _ExportAuditFilter.generated => generated,
      _ExportAuditFilter.cleared => cleared,
      _ExportAuditFilter.verification => verification,
      _ExportAuditFilter.telemetryAlert => telemetryAlert,
    };
  }

  List<GuardOpsEvent> _recentExportAuditEvents({
    int limit = 8,
    _ExportAuditFilter filter = _ExportAuditFilter.all,
  }) {
    final rows =
        widget.recentEvents
            .where((event) => event.eventType == GuardOpsEventType.syncStatus)
            .where((event) => _matchesExportAuditFilter(event, filter))
            .toList(growable: false)
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    if (rows.length <= limit) return rows;
    return rows.take(limit).toList(growable: false);
  }

  String _exportAuditTimelineRowSummary(GuardOpsEvent event) {
    final payload = event.payload;
    final action = switch (true) {
      _ when payload['export_audits_cleared'] == true => 'cleared',
      _ when payload['telemetry_payload_health_alert'] == true =>
        'telemetry_alert',
      _ when payload['telemetry_verification_checklist_passed'] == true =>
        'verification',
      _ => 'generated',
    };
    final exportType = (payload['export_type'] ?? '').toString().trim();
    final typeLabel = switch (action) {
      'verification' => 'telemetry_checklist',
      'telemetry_alert' => 'payload_health',
      _ => (exportType.isEmpty ? 'n/a' : exportType),
    };
    final scopeKey = (payload['scope_key'] ?? '').toString().trim();
    final shiftId = (payload['shift_id'] ?? event.shiftId).toString().trim();
    final context = scopeKey.isNotEmpty
        ? 'scope=$scopeKey'
        : (shiftId.isNotEmpty ? 'shift=$shiftId' : 'scope=n/a');
    return '${_formatUtc(event.occurredAt)} • $action • $typeLabel • $context';
  }

  int _shiftEventCount(String shiftId) {
    final key = shiftId.trim();
    if (key.isEmpty) return 0;
    return widget.recentEvents.where((event) => event.shiftId == key).length;
  }

  int _shiftEventFailedCount(String shiftId) {
    final key = shiftId.trim();
    if (key.isEmpty) return 0;
    return widget.recentEvents
        .where(
          (event) =>
              event.shiftId == key &&
              (event.failureReason ?? '').trim().isNotEmpty,
        )
        .length;
  }

  int _shiftEventPendingCount(String shiftId) {
    final key = shiftId.trim();
    if (key.isEmpty) return 0;
    return widget.recentEvents
        .where(
          (event) =>
              event.shiftId == key &&
              event.isPending &&
              (event.failureReason ?? '').trim().isEmpty,
        )
        .length;
  }

  int _shiftMediaCount(String shiftId) {
    final key = shiftId.trim();
    if (key.isEmpty) return 0;
    return widget.recentMedia.where((media) => media.shiftId == key).length;
  }

  int _shiftMediaFailedCount(String shiftId) {
    final key = shiftId.trim();
    if (key.isEmpty) return 0;
    return widget.recentMedia
        .where(
          (media) =>
              media.shiftId == key &&
              media.status == GuardMediaUploadStatus.failed,
        )
        .length;
  }

  int _shiftMediaPendingCount(String shiftId) {
    final key = shiftId.trim();
    if (key.isEmpty) return 0;
    return widget.recentMedia
        .where(
          (media) =>
              media.shiftId == key &&
              media.status == GuardMediaUploadStatus.queued,
        )
        .length;
  }

  int _eventTypeCount(GuardOpsEventType type, {String? shiftId}) {
    final key = shiftId?.trim() ?? '';
    return widget.recentEvents
        .where((event) => event.eventType == type)
        .where((event) => key.isEmpty || event.shiftId == key)
        .length;
  }

  int _reactionAcceptedCount({String? shiftId}) {
    return _eventTypeCount(
      GuardOpsEventType.reactionIncidentAccepted,
      shiftId: shiftId,
    );
  }

  int _reactionArrivedCount({String? shiftId}) {
    return _eventTypeCount(
      GuardOpsEventType.reactionOfficerArrived,
      shiftId: shiftId,
    );
  }

  int _reactionClearedCount({String? shiftId}) {
    return _eventTypeCount(
      GuardOpsEventType.reactionIncidentCleared,
      shiftId: shiftId,
    );
  }

  int _supervisorOverrideCount({String? shiftId}) {
    return _eventTypeCount(
      GuardOpsEventType.supervisorStatusOverride,
      shiftId: shiftId,
    );
  }

  int _supervisorCoachingAckCount({String? shiftId}) {
    return _eventTypeCount(
      GuardOpsEventType.supervisorCoachingAcknowledged,
      shiftId: shiftId,
    );
  }

  bool _shiftHasEndEvent(String shiftId) {
    final key = shiftId.trim();
    if (key.isEmpty) return false;
    return widget.recentEvents.any(
      (event) =>
          event.shiftId == key && event.eventType == GuardOpsEventType.shiftEnd,
    );
  }

  String _shiftCloseoutReadinessLabel(String shiftId) {
    final pending =
        _shiftEventPendingCount(shiftId) + _shiftMediaPendingCount(shiftId);
    final failed =
        _shiftEventFailedCount(shiftId) + _shiftMediaFailedCount(shiftId);
    if (pending == 0 && failed == 0) {
      return 'ready';
    }
    if (failed > 0) {
      return 'blocked';
    }
    return 'pending';
  }

  Color _shiftCloseoutReadinessColor(String shiftId) {
    switch (_shiftCloseoutReadinessLabel(shiftId)) {
      case 'ready':
        return const Color(0xFF7FD8A5);
      case 'blocked':
        return const Color(0xFFFF8D9A);
      case 'pending':
      default:
        return const Color(0xFFF1B872);
    }
  }

  Widget _failedOpsMetricsStrip(List<GuardSyncOperation> operations) {
    final failed = operations
        .where(
          (operation) => operation.status == GuardSyncOperationStatus.failed,
        )
        .toList(growable: false);
    final failedCount = failed.length;
    final retryTotal = failed.fold<int>(
      0,
      (sum, operation) => sum + operation.retryCount,
    );
    String oldestAge = 'n/a';
    Color failedCountColor = const Color(0xFF7FD8A5);
    Color oldestAgeColor = const Color(0xFF7FD8A5);
    Color retryTotalColor = const Color(0xFF8FD1FF);
    final failedWarn = widget.failedOpsWarnThreshold > 0
        ? widget.failedOpsWarnThreshold
        : 1;
    final failedCritical = widget.failedOpsCriticalThreshold >= failedWarn
        ? widget.failedOpsCriticalThreshold
        : failedWarn;
    final oldestWarnMinutes = widget.oldestFailedWarnMinutes > 0
        ? widget.oldestFailedWarnMinutes
        : 10;
    final oldestCriticalMinutes =
        widget.oldestFailedCriticalMinutes >= oldestWarnMinutes
        ? widget.oldestFailedCriticalMinutes
        : oldestWarnMinutes;
    final retryWarn = widget.failedRetryWarnThreshold > 0
        ? widget.failedRetryWarnThreshold
        : 8;
    final retryCritical = widget.failedRetryCriticalThreshold >= retryWarn
        ? widget.failedRetryCriticalThreshold
        : retryWarn;
    if (failedCount >= failedCritical) {
      failedCountColor = const Color(0xFFFF8D9A);
    } else if (failedCount >= failedWarn) {
      failedCountColor = const Color(0xFFF1B872);
    }
    if (failed.isNotEmpty) {
      final oldest = failed
          .map((operation) => operation.createdAt)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      final age = DateTime.now().toUtc().difference(oldest);
      oldestAge = _durationCompact(age);
      if (age >= Duration(minutes: oldestCriticalMinutes)) {
        oldestAgeColor = const Color(0xFFFF8D9A);
      } else if (age >= Duration(minutes: oldestWarnMinutes)) {
        oldestAgeColor = const Color(0xFFF1B872);
      }
    }
    if (retryTotal >= retryCritical) {
      retryTotalColor = const Color(0xFFFF8D9A);
    } else if (retryTotal >= retryWarn) {
      retryTotalColor = const Color(0xFFF1B872);
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _chip('Failed Ops', '$failedCount', failedCountColor),
        _chip('Oldest Failed Age', oldestAge, oldestAgeColor),
        _chip('Failed Retry Total', '$retryTotal', retryTotalColor),
      ],
    );
  }

  Future<bool> _confirmRetryAllFailedOps(int failedCount) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Retry Failed Operations',
            style: GoogleFonts.rajdhani(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'Requeue $failedCount failed operation(s) in the current history view?',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Retry All',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  String _operationModeLabel(GuardSyncOperationModeFilter filter) {
    return switch (filter) {
      GuardSyncOperationModeFilter.all => 'All Ops',
      GuardSyncOperationModeFilter.live => 'Live Ops',
      GuardSyncOperationModeFilter.stub => 'Stub Ops',
      GuardSyncOperationModeFilter.unknown => 'Unknown Ops',
    };
  }

  GuardSyncOperationModeFilter _operationModeFor(GuardSyncOperation operation) {
    final context = _operationRuntimeContext(operation);
    if (context == null) {
      return GuardSyncOperationModeFilter.unknown;
    }
    final mode = _runtimeBoolLabel(context['telemetry_facade_live_mode']);
    return switch (mode) {
      'live' => GuardSyncOperationModeFilter.live,
      'stub' => GuardSyncOperationModeFilter.stub,
      _ => GuardSyncOperationModeFilter.unknown,
    };
  }

  List<GuardSyncOperation> _visibleOperationsByMode() {
    if (widget.operationModeFilter == GuardSyncOperationModeFilter.all) {
      return widget.queuedOperations;
    }
    return widget.queuedOperations
        .where(
          (operation) =>
              _operationModeFor(operation) == widget.operationModeFilter,
        )
        .toList(growable: false);
  }

  GuardSyncOperation? _selectedOperation(List<GuardSyncOperation> operations) {
    if (operations.isEmpty) {
      return null;
    }
    final selected = operations.where(
      (operation) => operation.operationId == _selectedOperationId,
    );
    if (selected.isNotEmpty) {
      return selected.first;
    }
    return operations.first;
  }

  bool _requiresSupervisorConfirmation(String outcomeLabel) {
    final allowed = widget.outcomeGovernancePolicy.allowedConfirmers(
      outcomeLabel,
    );
    return allowed.length == 1 && allowed.contains('supervisor');
  }

  void _enforceOutcomeGovernance(
    String outcomeLabel, {
    required String confirmedBy,
  }) {
    if (!widget.outcomeGovernancePolicy.allows(
      outcomeLabel: outcomeLabel,
      confirmedBy: confirmedBy,
    )) {
      final allowed = widget.outcomeGovernancePolicy.allowedConfirmers(
        outcomeLabel,
      );
      throw StateError(
        'Confirmation role "$confirmedBy" is not allowed for $outcomeLabel. Allowed: ${allowed.join(', ')}.',
      );
    }
  }

  List<String> _availableConfirmationRoles() {
    final preferredOrder = <String>['supervisor', 'control', 'guard'];
    final known = widget.outcomeGovernancePolicy.allKnownConfirmers();
    final ordered = <String>[];
    for (final role in preferredOrder) {
      if (known.contains(role)) {
        ordered.add(role);
      }
    }
    for (final role in known) {
      if (!ordered.contains(role)) {
        ordered.add(role);
      }
    }
    return ordered;
  }

  String _roleLabel(String role) {
    if (role.isEmpty) return role;
    return '${role[0].toUpperCase()}${role.substring(1)}';
  }

  String _syncHealthLabel() {
    if (!widget.syncBackendEnabled) {
      return 'Local Only';
    }
    if (widget.failedEventCount > 0 || widget.failedMediaCount > 0) {
      return 'At Risk';
    }
    if (widget.pendingEventCount > 0 ||
        widget.pendingMediaCount > 0 ||
        widget.queueDepth > 0) {
      return 'Degraded';
    }
    return 'Healthy';
  }

  Color _syncHealthColor() {
    final label = _syncHealthLabel();
    switch (label) {
      case 'At Risk':
        return const Color(0xFFFF8D9A);
      case 'Degraded':
        return const Color(0xFFF1B872);
      case 'Local Only':
        return const Color(0xFFB6C6DD);
      case 'Healthy':
        return const Color(0xFF7FD8A5);
      default:
        return const Color(0xFFB6C6DD);
    }
  }

  Color _telemetryProviderReadinessColor() {
    switch (widget.telemetryProviderReadiness) {
      case 'ready':
        return const Color(0xFF7FD8A5);
      case 'error':
        return const Color(0xFFFF8D9A);
      default:
        return const Color(0xFFF1B872);
    }
  }

  String _telemetryCallbackAgeLabel(DateTime nowUtc) {
    final callbackAtUtc = widget.telemetryFacadeLastCallbackAtUtc;
    if (callbackAtUtc == null) return 'none';
    final age = nowUtc.difference(callbackAtUtc.toUtc());
    if (age.isNegative) return '<1m';
    return _durationCompact(age);
  }

  Color _telemetryCallbackAgeColor(DateTime nowUtc) {
    final callbackAtUtc = widget.telemetryFacadeLastCallbackAtUtc;
    if (callbackAtUtc == null) {
      return const Color(0xFFB6C6DD);
    }
    final age = nowUtc.difference(callbackAtUtc.toUtc());
    if (age <= const Duration(minutes: 2)) {
      return const Color(0xFF7FD8A5);
    }
    if (age <= const Duration(minutes: 10)) {
      return const Color(0xFFF1B872);
    }
    return const Color(0xFFFF8D9A);
  }

  Duration? _telemetryLastCallbackErrorAge(DateTime nowUtc) {
    final errorAtUtc = widget.telemetryFacadeLastCallbackErrorAtUtc;
    if (errorAtUtc == null) return null;
    return nowUtc.difference(errorAtUtc.toUtc());
  }

  String _telemetryPayloadHealthVerdict(DateTime nowUtc) {
    if (widget.telemetryAdapterStubMode) {
      return 'Stub';
    }
    if (widget.telemetryProviderReadiness == 'error') {
      return 'At Risk';
    }
    final errorCount = widget.telemetryFacadeCallbackErrorCount ?? 0;
    if (errorCount > 0) {
      final age = _telemetryLastCallbackErrorAge(nowUtc);
      if (age != null &&
          !age.isNegative &&
          age <= const Duration(minutes: 30)) {
        return 'At Risk';
      }
      return 'Degraded';
    }
    if (widget.telemetryFacadeLiveMode == true) {
      if (!_telemetryCallbackSeen()) {
        return 'Degraded';
      }
      if (!_telemetryCallbackFresh(nowUtc)) {
        return 'Degraded';
      }
    }
    return 'Healthy';
  }

  String _telemetryPayloadHealthReason(DateTime nowUtc) {
    if (widget.telemetryAdapterStubMode) {
      return 'stub adapter mode active';
    }
    if (widget.telemetryProviderReadiness == 'error') {
      return 'provider readiness is error';
    }
    final errorCount = widget.telemetryFacadeCallbackErrorCount ?? 0;
    if (errorCount > 0) {
      final age = _telemetryLastCallbackErrorAge(nowUtc);
      if (age == null) {
        return 'callback errors detected without timestamp';
      }
      if (age.isNegative) {
        return 'callback errors detected with future timestamp';
      }
      if (age <= const Duration(minutes: 30)) {
        return 'recent callback parse/ingest errors detected';
      }
      return 'historical callback errors detected';
    }
    if (widget.telemetryFacadeLiveMode == true && !_telemetryCallbackSeen()) {
      return 'live facade has no callbacks yet';
    }
    if (widget.telemetryFacadeLiveMode == true &&
        !_telemetryCallbackFresh(nowUtc)) {
      return 'live callbacks are stale (>2m)';
    }
    return 'callbacks are valid and fresh';
  }

  Color _telemetryPayloadHealthColor(DateTime nowUtc) {
    return switch (_telemetryPayloadHealthVerdict(nowUtc)) {
      'Healthy' => const Color(0xFF7FD8A5),
      'Stub' => const Color(0xFFB6C6DD),
      'Degraded' => const Color(0xFFF1B872),
      _ => const Color(0xFFFF8D9A),
    };
  }

  String _telemetryPayloadHealthTrendLabel() {
    final rows = _telemetryPayloadHealthTrendRows();
    if (rows.isEmpty) {
      return 'n/a';
    }
    return rows
        .map((row) => _telemetryPayloadHealthAbbrev(row.verdict))
        .join('->');
  }

  String _telemetryPayloadHealthTrendDetails() {
    final rows = _telemetryPayloadHealthTrendRows();
    if (rows.isEmpty) {
      return 'none';
    }
    return rows
        .map(
          (row) =>
              '${_formatUtc(row.atUtc)} ${row.verdict} (${row.callbackErrorCount} errors)',
        )
        .join(' | ');
  }

  List<({DateTime atUtc, String verdict, int callbackErrorCount})>
  _telemetryPayloadHealthTrendRows() {
    final rows =
        widget.recentEvents
            .where((event) => event.eventType == GuardOpsEventType.syncStatus)
            .where(
              (event) =>
                  event.payload.containsKey('telemetry_provider_readiness') ||
                  event.payload.containsKey(
                    'telemetry_facade_callback_error_count',
                  ),
            )
            .toList(growable: false)
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return rows
        .take(5)
        .toList(growable: false)
        .reversed
        .map(
          (event) => (
            atUtc: event.occurredAt.toUtc(),
            verdict: _telemetryPayloadHealthVerdictFromPayload(event.payload),
            callbackErrorCount: _telemetryPayloadCallbackErrorsFromPayload(
              event.payload,
            ),
          ),
        )
        .toList(growable: false);
  }

  String _telemetryPayloadHealthVerdictFromPayload(
    Map<String, Object?> payload,
  ) {
    if (_payloadBool(payload, 'telemetry_adapter_stub_mode') == true) {
      return 'Stub';
    }
    final readiness = (payload['telemetry_provider_readiness'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (readiness == 'error') {
      return 'At Risk';
    }
    final callbackErrors = _telemetryPayloadCallbackErrorsFromPayload(payload);
    if (callbackErrors > 0) {
      return 'At Risk';
    }
    final liveMode = _payloadBool(payload, 'telemetry_facade_live_mode');
    final callbackCount = _payloadInt(
      payload,
      'telemetry_facade_callback_count',
    );
    if (liveMode == true && callbackCount <= 0) {
      return 'Degraded';
    }
    final callbackAtUtc = _payloadDateTime(
      payload,
      'telemetry_facade_last_callback_at_utc',
    );
    if (liveMode == true && callbackAtUtc != null) {
      final age = DateTime.now().toUtc().difference(callbackAtUtc);
      if (!age.isNegative && age > const Duration(minutes: 2)) {
        return 'Degraded';
      }
    }
    return 'Healthy';
  }

  int _telemetryPayloadCallbackErrorsFromPayload(Map<String, Object?> payload) {
    return _payloadInt(payload, 'telemetry_facade_callback_error_count');
  }

  String _telemetryPayloadHealthAbbrev(String verdict) {
    return switch (verdict) {
      'Healthy' => 'H',
      'Degraded' => 'D',
      'At Risk' => 'R',
      'Stub' => 'S',
      _ => '?',
    };
  }

  int _payloadInt(Map<String, Object?> payload, String key) {
    final value = payload[key];
    return switch (value) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v.trim()) ?? 0,
      _ => 0,
    };
  }

  bool? _payloadBool(Map<String, Object?> payload, String key) {
    final value = payload[key];
    return switch (value) {
      bool v => v,
      String v => v.trim().toLowerCase() == 'true',
      _ => null,
    };
  }

  DateTime? _payloadDateTime(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is! String) {
      return null;
    }
    final parsed = DateTime.tryParse(value.trim());
    return parsed?.toUtc();
  }

  bool _telemetryCallbackSeen() {
    return (widget.telemetryFacadeCallbackCount ?? 0) > 0;
  }

  bool _telemetryCallbackFresh(DateTime nowUtc) {
    final callbackAtUtc = widget.telemetryFacadeLastCallbackAtUtc;
    if (callbackAtUtc == null) return false;
    final age = nowUtc.difference(callbackAtUtc.toUtc());
    return !age.isNegative && age <= const Duration(minutes: 2);
  }

  Color _checklistColor(bool pass) {
    return pass ? const Color(0xFF7FD8A5) : const Color(0xFFF1B872);
  }

  String _buildSyncReport({
    required List<GuardOpsEvent> filteredEvents,
    required List<GuardOpsMediaUpload> filteredMedia,
  }) {
    final nowUtc = DateTime.now().toUtc();
    final lastResumeSyncTrigger = _latestResumeSyncTriggerAt();
    final lastTelemetryPayloadAlert = _latestTelemetryPayloadHealthAlertAt();
    final lastExportAuditReset = _latestExportAuditResetEventAt();
    final lastExportAuditGenerated = _latestExportAuditGeneratedEventAt();
    final telemetryContextLines = _syncTelemetryContextLines();
    final buffer = StringBuffer()
      ..writeln('Guard Sync Report')
      ..writeln('Guard: ${widget.guardId}')
      ..writeln('Site: ${widget.siteId}')
      ..writeln(
        'Backend: ${widget.syncBackendEnabled ? 'Supabase+fallback' : 'Local only'}',
      )
      ..writeln('Health: ${_syncHealthLabel()}')
      ..writeln('Queue depth: ${widget.queueDepth}')
      ..writeln(
        'Pending events/media: ${widget.pendingEventCount}/${widget.pendingMediaCount}',
      )
      ..writeln(
        'Failed events/media: ${widget.failedEventCount}/${widget.failedMediaCount}',
      )
      ..writeln(
        'Reaction ops (accepted/arrived/cleared): ${_reactionAcceptedCount(shiftId: widget.activeShiftId)}/${_reactionArrivedCount(shiftId: widget.activeShiftId)}/${_reactionClearedCount(shiftId: widget.activeShiftId)}',
      )
      ..writeln(
        'Supervisor ops (overrides/coaching_ack): ${_supervisorOverrideCount(shiftId: widget.activeShiftId)}/${_supervisorCoachingAckCount(shiftId: widget.activeShiftId)}',
      )
      ..writeln(telemetryContextLines.join('\n'))
      ..writeln(
        'Last success: ${widget.lastSuccessfulSyncAtUtc == null ? 'none' : _formatUtc(widget.lastSuccessfulSyncAtUtc!)}',
      )
      ..writeln(
        'Last resume sync trigger: ${lastResumeSyncTrigger == null ? 'none' : _formatUtc(lastResumeSyncTrigger)}',
      )
      ..writeln(
        'Resume sync triggers (shift): ${_resumeSyncTriggerCount(widget.activeShiftId)}',
      )
      ..writeln(
        'Last telemetry payload alert: ${lastTelemetryPayloadAlert == null ? 'none' : _formatUtc(lastTelemetryPayloadAlert)}',
      )
      ..writeln(
        'Telemetry payload alerts (shift): ${_telemetryPayloadHealthAlertCount(widget.activeShiftId)}',
      )
      ..writeln(
        'Last export audit reset trigger: ${lastExportAuditReset == null ? 'none' : _formatUtc(lastExportAuditReset)}',
      )
      ..writeln(
        'Export audit resets (shift): ${_exportAuditResetEventCount(widget.activeShiftId)}',
      )
      ..writeln(
        'Last export audit generated trigger: ${lastExportAuditGenerated == null ? 'none' : _formatUtc(lastExportAuditGenerated)}',
      )
      ..writeln(
        'Export health thresholds: ${_exportAuditHealthThresholdsLabel()}',
      )
      ..writeln(
        'Export health verdict: ${_exportHealthVerdict(widget.activeShiftId, nowUtc)}',
      )
      ..writeln(
        'Export health reason: ${_exportHealthReason(widget.activeShiftId, nowUtc)}',
      )
      ..writeln(
        'Export gen/clear ratio (shift): ${_exportAuditGeneratedToClearedRatioLabel(widget.activeShiftId)}',
      )
      ..writeln(
        'Sync report exports (shift): ${_exportAuditGeneratedEventCount(widget.activeShiftId, exportType: 'sync_report')}',
      )
      ..writeln(
        'Shift replay exports (shift): ${_exportAuditGeneratedEventCount(widget.activeShiftId, exportType: 'shift_replay_summary')}',
      )
      ..writeln(
        'Closeout packet exports (shift): ${_exportAuditGeneratedEventCount(widget.activeShiftId, exportType: 'dispatch_closeout_packet')}',
      )
      ..writeln(
        'Last sync report audit: ${(widget.lastSyncReportAuditLabel ?? '').trim().isEmpty ? 'none' : widget.lastSyncReportAuditLabel!.trim()}',
      )
      ..writeln(
        'Last replay summary audit: ${(widget.lastShiftReplayAuditLabel ?? '').trim().isEmpty ? 'none' : widget.lastShiftReplayAuditLabel!.trim()}',
      )
      ..writeln(
        'Last closeout packet audit: ${(widget.lastCloseoutPacketAuditLabel ?? '').trim().isEmpty ? 'none' : widget.lastCloseoutPacketAuditLabel!.trim()}',
      )
      ..writeln(
        'Last export audit reset: ${(widget.lastExportAuditClearLabel ?? '').trim().isEmpty ? 'none' : widget.lastExportAuditClearLabel!.trim()}',
      )
      ..writeln('Last failure: ${widget.lastFailureReason ?? 'none'}')
      ..writeln('Event filter: ${_filterLabel(_eventFilter)}')
      ..writeln('Media filter: ${_filterLabel(_mediaFilter)}')
      ..writeln('Event rows:')
      ..writeln(
        filteredEvents.isEmpty
            ? 'none'
            : filteredEvents.map(_eventRowSummary).join('\n'),
      )
      ..writeln('Media rows:')
      ..write(
        filteredMedia.isEmpty
            ? 'none'
            : filteredMedia.map(_mediaRowSummary).join('\n'),
      );
    return buffer.toString();
  }

  List<String> _syncTelemetryContextLines() {
    final nowUtc = DateTime.now().toUtc();
    return [
      'Telemetry adapter: ${widget.telemetryAdapterLabel} (${widget.telemetryAdapterStubMode ? 'stub' : 'live'})',
      'Provider readiness: ${widget.telemetryProviderReadiness}${widget.telemetryProviderStatusLabel == null ? '' : ' • ${widget.telemetryProviderStatusLabel}'}',
      'Provider ID: ${widget.telemetryProviderId ?? 'n/a'}',
      'Live-ready gate: ${widget.telemetryLiveReadyGateEnabled ? (widget.telemetryLiveReadyGateViolation ? 'VIOLATION' : 'OK') : 'disabled'} (${widget.telemetryLiveReadyGateReason ?? 'n/a'})',
      'Resume sync event throttle: ${widget.resumeSyncEventThrottleSeconds}s',
      'Facade id: ${widget.telemetryFacadeId ?? 'n/a'}',
      'Facade mode: ${widget.telemetryFacadeLiveMode == null ? 'n/a' : (widget.telemetryFacadeLiveMode! ? 'live' : 'stub')}',
      'Facade toggle source: ${widget.telemetryFacadeToggleSource ?? 'n/a'}',
      'Facade heartbeat source: ${widget.telemetryFacadeHeartbeatSource ?? 'n/a'}',
      'Facade callback count: ${widget.telemetryFacadeCallbackCount ?? 0}',
      'Facade callback errors: ${widget.telemetryFacadeCallbackErrorCount ?? 0}',
      'Facade last callback age: ${_telemetryCallbackAgeLabel(nowUtc)}',
      'Telemetry payload health verdict: ${_telemetryPayloadHealthVerdict(nowUtc)}',
      'Telemetry payload health reason: ${_telemetryPayloadHealthReason(nowUtc)}',
      'Telemetry payload health trend: ${_telemetryPayloadHealthTrendLabel()}',
      'Telemetry payload health trend rows: ${_telemetryPayloadHealthTrendDetails()}',
    ];
  }

  String _buildFilteredEventRowsExport(List<GuardOpsEvent> filteredEvents) {
    return [
      'Guard Sync Event Rows',
      'Guard: ${widget.guardId}',
      'Site: ${widget.siteId}',
      ..._syncTelemetryContextLines(),
      'Event filter: ${_filterLabel(_eventFilter)}',
      'Rows:',
      if (filteredEvents.isEmpty)
        'none'
      else
        filteredEvents.map(_eventRowSummary).join('\n'),
    ].join('\n');
  }

  String _buildFilteredMediaRowsExport(
    List<GuardOpsMediaUpload> filteredMedia,
  ) {
    return [
      'Guard Sync Media Rows',
      'Guard: ${widget.guardId}',
      'Site: ${widget.siteId}',
      ..._syncTelemetryContextLines(),
      'Media filter: ${_filterLabel(_mediaFilter)}',
      'Rows:',
      if (filteredMedia.isEmpty)
        'none'
      else
        filteredMedia.map(_mediaRowSummary).join('\n'),
    ].join('\n');
  }

  String _buildExportAuditTimelineExport(List<GuardOpsEvent> timelineEvents) {
    return [
      'Guard Export Audit Timeline',
      'Guard: ${widget.guardId}',
      'Site: ${widget.siteId}',
      ..._syncTelemetryContextLines(),
      'Rows:',
      if (timelineEvents.isEmpty)
        'none'
      else
        timelineEvents.map(_exportAuditTimelineRowSummary).join('\n'),
    ].join('\n');
  }

  String _buildShiftReplaySummary() {
    final nowUtc = DateTime.now().toUtc();
    final activeShiftId = widget.activeShiftId.trim();
    final shiftId = activeShiftId.isEmpty ? 'unassigned' : activeShiftId;
    final latestShiftStart = _latestEventAt(GuardOpsEventType.shiftStart);
    final latestShiftEnd = _latestEventAt(GuardOpsEventType.shiftEnd);
    final latestResumeSyncTrigger = _latestResumeSyncTriggerAt();
    final latestTelemetryPayloadAlert = _latestTelemetryPayloadHealthAlertAt();
    final latestExportAuditReset = _latestExportAuditResetEventAt();
    final latestExportAuditGenerated = _latestExportAuditGeneratedEventAt();
    return [
      'Guard Shift Replay Summary',
      'Guard: ${widget.guardId}',
      'Site: ${widget.siteId}',
      'Shift: $shiftId',
      'Sequence watermark: ${widget.activeShiftSequenceWatermark}',
      'Lifecycle: ${_shiftLifecycleLabel(nowUtc)}',
      'Shift closed: ${_shiftHasEndEvent(activeShiftId) ? 'yes' : 'no'}',
      'Last shift start: ${latestShiftStart == null ? 'none' : _formatUtc(latestShiftStart)}',
      'Last shift end: ${latestShiftEnd == null ? 'none' : _formatUtc(latestShiftEnd)}',
      'Last resume sync trigger: ${latestResumeSyncTrigger == null ? 'none' : _formatUtc(latestResumeSyncTrigger)}',
      'Resume sync triggers (shift): ${_resumeSyncTriggerCount(activeShiftId)}',
      'Last telemetry payload alert: ${latestTelemetryPayloadAlert == null ? 'none' : _formatUtc(latestTelemetryPayloadAlert)}',
      'Telemetry payload alerts (shift): ${_telemetryPayloadHealthAlertCount(activeShiftId)}',
      'Last export audit reset trigger: ${latestExportAuditReset == null ? 'none' : _formatUtc(latestExportAuditReset)}',
      'Export audit resets (shift): ${_exportAuditResetEventCount(activeShiftId)}',
      'Last export audit generated trigger: ${latestExportAuditGenerated == null ? 'none' : _formatUtc(latestExportAuditGenerated)}',
      'Export health thresholds: ${_exportAuditHealthThresholdsLabel()}',
      'Export health verdict: ${_exportHealthVerdict(activeShiftId, nowUtc)}',
      'Export health reason: ${_exportHealthReason(activeShiftId, nowUtc)}',
      'Export gen/clear ratio (shift): ${_exportAuditGeneratedToClearedRatioLabel(activeShiftId)}',
      'Sync report exports (shift): ${_exportAuditGeneratedEventCount(activeShiftId, exportType: 'sync_report')}',
      'Shift replay exports (shift): ${_exportAuditGeneratedEventCount(activeShiftId, exportType: 'shift_replay_summary')}',
      'Closeout packet exports (shift): ${_exportAuditGeneratedEventCount(activeShiftId, exportType: 'dispatch_closeout_packet')}',
      'Open shift age: ${_openShiftAgeLabel(nowUtc)}',
      'Shift events: ${_shiftEventCount(activeShiftId)}',
      'Shift media: ${_shiftMediaCount(activeShiftId)}',
      'Shift pending: ${_shiftEventPendingCount(activeShiftId) + _shiftMediaPendingCount(activeShiftId)}',
      'Shift failed: ${_shiftEventFailedCount(activeShiftId) + _shiftMediaFailedCount(activeShiftId)}',
      'Reaction ops (shift accepted/arrived/cleared): ${_reactionAcceptedCount(shiftId: activeShiftId)}/${_reactionArrivedCount(shiftId: activeShiftId)}/${_reactionClearedCount(shiftId: activeShiftId)}',
      'Supervisor ops (shift overrides/coaching_ack): ${_supervisorOverrideCount(shiftId: activeShiftId)}/${_supervisorCoachingAckCount(shiftId: activeShiftId)}',
      'Shift event rows:',
      if (_shiftEventCount(activeShiftId) == 0)
        'none'
      else
        widget.recentEvents
            .where((event) => event.shiftId == activeShiftId)
            .map(_eventRowSummary)
            .join('\n'),
      'Shift media rows:',
      if (_shiftMediaCount(activeShiftId) == 0)
        'none'
      else
        widget.recentMedia
            .where((media) => media.shiftId == activeShiftId)
            .map(_mediaRowSummary)
            .join('\n'),
    ].join('\n');
  }

  String _buildDispatchCloseoutPacket({
    required List<GuardOpsEvent> filteredEvents,
    required List<GuardOpsMediaUpload> filteredMedia,
  }) {
    final nowUtc = DateTime.now().toUtc();
    final activeShiftId = widget.activeShiftId.trim();
    final operations = _visibleOperationsByMode();
    final selectedOperation = _selectedOperation(operations);
    final dispatchTimelineRows =
        widget.recentEvents
            .where(
              (event) =>
                  event.eventType == GuardOpsEventType.dispatchReceived ||
                  event.eventType == GuardOpsEventType.dispatchAcknowledged ||
                  event.eventType == GuardOpsEventType.statusChanged ||
                  event.eventType ==
                      GuardOpsEventType.reactionIncidentAccepted ||
                  event.eventType == GuardOpsEventType.reactionOfficerArrived ||
                  event.eventType ==
                      GuardOpsEventType.reactionIncidentCleared ||
                  event.eventType ==
                      GuardOpsEventType.supervisorStatusOverride ||
                  event.eventType ==
                      GuardOpsEventType.supervisorCoachingAcknowledged ||
                  event.eventType == GuardOpsEventType.panicTriggered ||
                  event.eventType == GuardOpsEventType.panicCleared ||
                  event.eventType == GuardOpsEventType.incidentReported,
            )
            .toList(growable: false)
          ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return [
      'Dispatch Closeout Packet',
      'Generated At: ${_formatUtc(DateTime.now().toUtc())}',
      'Reviewed Sync Context:',
      'Scope key: ${widget.activeScopeKey.trim().isEmpty ? 'unknown' : widget.activeScopeKey.trim()}',
      'Facade mode filter: ${widget.operationModeFilter.name}',
      'Facade id filter: ${(widget.selectedFacadeId ?? '').trim().isEmpty ? 'all_facades' : widget.selectedFacadeId!.trim()}',
      'History filter: ${widget.historyFilter.name}',
      'Last sync report audit: ${(widget.lastSyncReportAuditLabel ?? '').trim().isEmpty ? 'none' : widget.lastSyncReportAuditLabel!.trim()}',
      'Last export audit reset: ${(widget.lastExportAuditClearLabel ?? '').trim().isEmpty ? 'none' : widget.lastExportAuditClearLabel!.trim()}',
      'Export health thresholds: ${_exportAuditHealthThresholdsLabel()}',
      'Export health verdict: ${_exportHealthVerdict(activeShiftId, nowUtc)}',
      'Export health reason: ${_exportHealthReason(activeShiftId, nowUtc)}',
      '---',
      _buildShiftReplaySummary(),
      '---',
      'Dispatch Timeline:',
      if (dispatchTimelineRows.isEmpty)
        'none'
      else
        dispatchTimelineRows.map(_eventRowSummary).join('\n'),
      '---',
      'Selected Operation Detail:',
      if (selectedOperation == null)
        'none'
      else
        _operationDetailText(selectedOperation),
      '---',
      'Filtered Event Snapshot:',
      if (filteredEvents.isEmpty)
        'none'
      else
        filteredEvents.map(_eventRowSummary).join('\n'),
      '---',
      'Filtered Media Snapshot:',
      if (filteredMedia.isEmpty)
        'none'
      else
        filteredMedia.map(_mediaRowSummary).join('\n'),
      '---',
      'Sync Report:',
      _buildSyncReport(
        filteredEvents: filteredEvents,
        filteredMedia: filteredMedia,
      ),
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final visibleHistoryOperations = _visibleOperationsByMode();
    final visibleHistoryOperationRows = visibleHistoryOperations
        .take(_maxHistoryOperationRows)
        .toList(growable: false);
    final hiddenHistoryOperationRows =
        visibleHistoryOperations.length - visibleHistoryOperationRows.length;
    final activeShiftId = widget.activeShiftId.trim();
    final facadeIdOptions = {
      ...widget.availableFacadeIds.where((value) => value.trim().isNotEmpty),
      if ((widget.selectedFacadeId ?? '').trim().isNotEmpty)
        widget.selectedFacadeId!.trim(),
    }.toList(growable: false)..sort();
    if (_selectedOperationId != null &&
        !visibleHistoryOperations.any(
          (operation) => operation.operationId == _selectedOperationId,
        )) {
      _selectedOperationId = null;
      if (!_selectionClearNotifyQueued) {
        _selectionClearNotifyQueued = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _selectionClearNotifyQueued = false;
          unawaited(widget.onSelectedOperationChanged(null));
        });
      }
    }
    return OnyxPageScaffold(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1540),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OnyxPageHeader(
                  title: 'Android Guard App Shell',
                  subtitle: _headerSubtitleForRole(widget.operatorRole),
                  actions: [
                    _chip(
                      'Role',
                      _operatorRoleLabel(widget.operatorRole),
                      const Color(0xFFB2A5FF),
                    ),
                    _chip('Guard', widget.guardId, const Color(0xFF69C3FF)),
                    _chip('Site', widget.siteId, const Color(0xFF63D79C)),
                    _chip(
                      'Sync',
                      widget.syncBackendEnabled
                          ? 'Supabase + fallback'
                          : 'Local only',
                      widget.syncBackendEnabled
                          ? const Color(0xFF67D39A)
                          : const Color(0xFFF5C26E),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OnyxSummaryStat(
                        label: 'Pending Events',
                        value: widget.pendingEventCount.toString(),
                        accent: const Color(0xFF6BC6FF),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OnyxSummaryStat(
                        label: 'Pending Media',
                        value: widget.pendingMediaCount.toString(),
                        accent: const Color(0xFF7FB1FF),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OnyxSummaryStat(
                        label: 'Sync Queue',
                        value: widget.queueDepth.toString(),
                        accent: const Color(0xFF73D8A0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip(
                      'Reaction Ops',
                      'A:${_reactionAcceptedCount(shiftId: activeShiftId)} Ar:${_reactionArrivedCount(shiftId: activeShiftId)} C:${_reactionClearedCount(shiftId: activeShiftId)}',
                      const Color(0xFF90D2FF),
                    ),
                    _chip(
                      'Supervisor Ops',
                      'O:${_supervisorOverrideCount(shiftId: activeShiftId)} Ack:${_supervisorCoachingAckCount(shiftId: activeShiftId)}',
                      const Color(0xFFC2B2FF),
                    ),
                  ],
                ),
                if (widget.syncStatusLabel != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.syncStatusLabel!,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF9AB3D4),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (_lastActionStatus != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _lastActionStatus!,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF9AB3D4),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: OnyxSectionCard(
                          title: 'Guard Screen Flow',
                          subtitle:
                              'This shell maps Android screens to actual queued sync operations.',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _screensForRole(widget.operatorRole)
                                    .map(
                                      (screen) => switch (screen) {
                                        _GuardMobileScreen.shiftStart =>
                                          _screenChip(
                                            'Shift Start',
                                            _GuardMobileScreen.shiftStart,
                                          ),
                                        _GuardMobileScreen.dispatch =>
                                          _screenChip(
                                            'Dispatch',
                                            _GuardMobileScreen.dispatch,
                                          ),
                                        _GuardMobileScreen.status =>
                                          _screenChip(
                                            'Status',
                                            _GuardMobileScreen.status,
                                          ),
                                        _GuardMobileScreen.checkpoint =>
                                          _screenChip(
                                            'Checkpoint',
                                            _GuardMobileScreen.checkpoint,
                                          ),
                                        _GuardMobileScreen.panic => _screenChip(
                                          'Panic',
                                          _GuardMobileScreen.panic,
                                        ),
                                        _GuardMobileScreen.sync => _screenChip(
                                          'Sync',
                                          _GuardMobileScreen.sync,
                                        ),
                                      },
                                    )
                                    .toList(growable: false),
                              ),
                              const SizedBox(height: 14),
                              _buildScreenPanel(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 5,
                        child: OnyxSectionCard(
                          title:
                              'Sync History (${widget.historyFilter.name.toUpperCase()})',
                          subtitle:
                              'Recent operations from repository-backed sync history.',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _historyChip(
                                    label: 'Queued',
                                    filter: GuardSyncHistoryFilter.queued,
                                  ),
                                  _historyChip(
                                    label: 'Synced',
                                    filter: GuardSyncHistoryFilter.synced,
                                  ),
                                  _historyChip(
                                    label: 'Failed',
                                    filter: GuardSyncHistoryFilter.failed,
                                  ),
                                  _historyChip(
                                    label: 'All',
                                    filter: GuardSyncHistoryFilter.all,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: GuardSyncOperationModeFilter.values
                                    .map((mode) {
                                      final count =
                                          mode ==
                                              GuardSyncOperationModeFilter.all
                                          ? widget.queuedOperations.length
                                          : widget.queuedOperations
                                                .where(
                                                  (operation) =>
                                                      _operationModeFor(
                                                        operation,
                                                      ) ==
                                                      mode,
                                                )
                                                .length;
                                      return _syncFilterChip(
                                        label:
                                            '${_operationModeLabel(mode)}: $count',
                                        selected:
                                            widget.operationModeFilter == mode,
                                        onTap: () {
                                          unawaited(
                                            widget.onOperationModeFilterChanged(
                                              mode,
                                            ),
                                          );
                                        },
                                      );
                                    })
                                    .toList(growable: false),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    'Facade Filter:',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF8EA4C2),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value:
                                            widget.selectedFacadeId == null ||
                                                widget.selectedFacadeId!.isEmpty
                                            ? _allFacadeFilterValue
                                            : widget.selectedFacadeId!,
                                        dropdownColor: const Color(0xFF0A1529),
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFFDCE9FF),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        items: [
                                          const DropdownMenuItem<String>(
                                            value: _allFacadeFilterValue,
                                            child: Text('All Facades'),
                                          ),
                                          ...facadeIdOptions.map(
                                            (facadeId) =>
                                                DropdownMenuItem<String>(
                                                  value: facadeId,
                                                  child: Text(facadeId),
                                                ),
                                          ),
                                        ],
                                        onChanged: (value) {
                                          final next =
                                              value == null ||
                                                  value == _allFacadeFilterValue
                                              ? null
                                              : value;
                                          unawaited(
                                            widget.onFacadeIdFilterChanged(
                                              next,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _chip(
                                    'Scoped Selections',
                                    widget.scopedSelectionCount.toString(),
                                    const Color(0xFF8FD1FF),
                                  ),
                                  _chip(
                                    'Active Scope',
                                    widget.activeScopeKey.trim().isEmpty
                                        ? 'unknown'
                                        : widget.activeScopeKey.trim(),
                                    const Color(0xFFB6C6DD),
                                  ),
                                  _chip(
                                    'Scope Selection',
                                    widget.activeScopeHasSelection
                                        ? 'selected'
                                        : 'none',
                                    widget.activeScopeHasSelection
                                        ? const Color(0xFF7FD8A5)
                                        : const Color(0xFFF1B872),
                                  ),
                                ],
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _submitting
                                      ? null
                                      : () async {
                                          await _withSubmit(
                                            'Scoped selection keys copied.',
                                            _copyScopedSelectionKeys,
                                          );
                                        },
                                  child: Text(
                                    'Copy Scoped Keys',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF89D7FF),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              _failedOpsMetricsStrip(visibleHistoryOperations),
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _submitting
                                      ? null
                                      : () async {
                                          await _withSubmit(
                                            'Queue cleared.',
                                            () {
                                              return widget.onClearQueue();
                                            },
                                          );
                                          if (!mounted) return;
                                          setState(() {
                                            _selectedOperationId = null;
                                          });
                                          await widget
                                              .onSelectedOperationChanged(null);
                                        },
                                  child: Text(
                                    'Clear Queue',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF89D7FF),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: 380,
                                child: visibleHistoryOperations.isEmpty
                                    ? Center(
                                        child: Text(
                                          'No operations in this history filter.',
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF8EA4C2),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      )
                                    : ListView.separated(
                                        itemCount:
                                            visibleHistoryOperationRows.length,
                                        separatorBuilder: (_, _) =>
                                            const SizedBox(height: 8),
                                        itemBuilder: (context, index) {
                                          final operation =
                                              visibleHistoryOperationRows[index];
                                          return _operationRow(
                                            operation,
                                            selected:
                                                _selectedOperationId ==
                                                operation.operationId,
                                            onTap: () {
                                              setState(() {
                                                _selectedOperationId =
                                                    operation.operationId;
                                              });
                                              unawaited(
                                                widget
                                                    .onSelectedOperationChanged(
                                                      operation.operationId,
                                                    ),
                                              );
                                            },
                                          );
                                        },
                                      ),
                              ),
                              if (hiddenHistoryOperationRows > 0) ...[
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: OnyxTruncationHint(
                                    visibleCount:
                                        visibleHistoryOperationRows.length,
                                    totalCount: visibleHistoryOperations.length,
                                    subject: 'operations',
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              _operationDetailPanel(visibleHistoryOperations),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScreenPanel() {
    switch (_screen) {
      case _GuardMobileScreen.shiftStart:
        return _panel(
          title: 'Shift Start Verification',
          body:
              'Capture mandatory identity/uniform verification before active patrol.',
          actions: [
            _actionButton(
              label: _shiftVerified ? 'Verified' : 'Capture + Start Shift',
              onPressed: _shiftVerified
                  ? null
                  : () async {
                      await _withSubmit(
                        'Shift verification and start queued.',
                        () {
                          return widget.onShiftStartQueued();
                        },
                      );
                      if (!mounted) return;
                      setState(() {
                        _shiftVerified = true;
                      });
                    },
            ),
            _actionButton(
              label: _shiftVerified ? 'Queue Shift End' : 'Shift Not Active',
              onPressed: !_shiftVerified
                  ? null
                  : () async {
                      await _withSubmit('Shift end queued.', () {
                        return widget.onShiftEndQueued();
                      });
                      if (!mounted) return;
                      setState(() {
                        _shiftVerified = false;
                      });
                    },
            ),
          ],
        );
      case _GuardMobileScreen.dispatch:
        final dispatchCoaching =
            _shouldSurfaceContextCoaching(widget.coachingPrompt)
            ? _contextCoachingBanner(widget.coachingPrompt, context: 'dispatch')
            : null;
        if (widget.operatorRole == GuardMobileOperatorRole.reaction) {
          return _panel(
            title: 'Reaction Incident Queue',
            body:
                'Incident DISP-ANDROID-001 is active for ${widget.siteId}. Accept and drive response milestones.',
            bodyWidget: dispatchCoaching,
            actions: [
              _actionButton(
                label: 'Accept Incident',
                onPressed: () async {
                  await _withSubmit(
                    'Incident accepted and EN ROUTE queued.',
                    () =>
                        widget.onReactionIncidentAcceptedQueued?.call() ??
                        widget.onStatusQueued(GuardDutyStatus.enRoute),
                  );
                },
              ),
              _actionButton(
                label: 'Mark Arrived',
                onPressed: () async {
                  await _withSubmit(
                    'ARRIVED / ON SITE queued.',
                    () =>
                        widget.onReactionOfficerArrivedQueued?.call() ??
                        widget.onStatusQueued(GuardDutyStatus.onSite),
                  );
                },
              ),
              _actionButton(
                label: 'Incident Clear',
                onPressed: () async {
                  await _withSubmit(
                    'INCIDENT CLEAR queued.',
                    () =>
                        widget.onReactionIncidentClearedQueued?.call() ??
                        widget.onStatusQueued(GuardDutyStatus.clear),
                  );
                },
              ),
            ],
          );
        }
        if (widget.operatorRole == GuardMobileOperatorRole.supervisor) {
          return _panel(
            title: 'Supervisor Dispatch Console',
            body:
                'Supervise field response progression and apply dispatch overrides.',
            bodyWidget: dispatchCoaching,
            actions: [
              _actionButton(
                label: 'Override: En Route',
                onPressed: () async {
                  await _withSubmit(
                    'Supervisor override queued: EN ROUTE.',
                    () =>
                        widget.onSupervisorStatusOverrideQueued?.call(
                          GuardDutyStatus.enRoute,
                        ) ??
                        widget.onStatusQueued(GuardDutyStatus.enRoute),
                  );
                },
              ),
              _actionButton(
                label: 'Override: On Site',
                onPressed: () async {
                  await _withSubmit(
                    'Supervisor override queued: ON SITE.',
                    () =>
                        widget.onSupervisorStatusOverrideQueued?.call(
                          GuardDutyStatus.onSite,
                        ) ??
                        widget.onStatusQueued(GuardDutyStatus.onSite),
                  );
                },
              ),
              _actionButton(
                label: 'Acknowledge Coaching',
                onPressed: () async {
                  await _withSubmit(
                    'Supervisor coaching acknowledgement queued.',
                    () =>
                        widget.onSupervisorCoachingAcknowledgedQueued?.call() ??
                        widget.onAcknowledgeCoachingPrompt(
                          ruleId: widget.coachingPrompt.ruleId,
                          context: 'dispatch',
                        ),
                  );
                },
              ),
            ],
          );
        }
        return _panel(
          title: 'Dispatch Inbox',
          body:
              'Dispatch DISP-ANDROID-001 awaiting acknowledgement for ${widget.siteId}.',
          bodyWidget: dispatchCoaching,
          actions: [
            _actionButton(
              label: 'Acknowledge',
              onPressed: () async {
                await _withSubmit(
                  'Dispatch acknowledged and EN ROUTE queued.',
                  () {
                    return widget.onStatusQueued(GuardDutyStatus.enRoute);
                  },
                );
              },
            ),
            _actionButton(
              label: 'Mark On Site',
              onPressed: () async {
                await _withSubmit('ON SITE status queued.', () {
                  return widget.onStatusQueued(GuardDutyStatus.onSite);
                });
              },
            ),
          ],
        );
      case _GuardMobileScreen.status:
        if (widget.operatorRole == GuardMobileOperatorRole.reaction) {
          return _panel(
            title: 'Reaction Status Update',
            body: 'Push live incident response milestones to command.',
            actions: [
              _actionButton(
                label: 'En Route',
                onPressed: () => _withSubmit(
                  'REACTION EN ROUTE queued.',
                  () => widget.onStatusQueued(GuardDutyStatus.enRoute),
                ),
              ),
              _actionButton(
                label: 'On Scene',
                onPressed: () => _withSubmit(
                  'REACTION ON SCENE queued.',
                  () => widget.onStatusQueued(GuardDutyStatus.onSite),
                ),
              ),
              _actionButton(
                label: 'Incident Clear',
                onPressed: () => _withSubmit(
                  'REACTION INCIDENT CLEAR queued.',
                  () => widget.onStatusQueued(GuardDutyStatus.clear),
                ),
              ),
              _actionButton(
                label: 'Radio Offline',
                onPressed: () => _withSubmit(
                  'REACTION OFFLINE queued.',
                  () => widget.onStatusQueued(GuardDutyStatus.offline),
                ),
              ),
            ],
          );
        }
        if (widget.operatorRole == GuardMobileOperatorRole.supervisor) {
          return _panel(
            title: 'Supervisor Status Override',
            body:
                'Apply supervised duty-state corrections for active field units.',
            actions: [
              _actionButton(
                label: 'Override En Route',
                onPressed: () => _withSubmit(
                  'Supervisor override queued: EN ROUTE.',
                  () =>
                      widget.onSupervisorStatusOverrideQueued?.call(
                        GuardDutyStatus.enRoute,
                      ) ??
                      widget.onStatusQueued(GuardDutyStatus.enRoute),
                ),
              ),
              _actionButton(
                label: 'Override On Site',
                onPressed: () => _withSubmit(
                  'Supervisor override queued: ON SITE.',
                  () =>
                      widget.onSupervisorStatusOverrideQueued?.call(
                        GuardDutyStatus.onSite,
                      ) ??
                      widget.onStatusQueued(GuardDutyStatus.onSite),
                ),
              ),
              _actionButton(
                label: 'Override Clear',
                onPressed: () => _withSubmit(
                  'Supervisor override queued: CLEAR.',
                  () =>
                      widget.onSupervisorStatusOverrideQueued?.call(
                        GuardDutyStatus.clear,
                      ) ??
                      widget.onStatusQueued(GuardDutyStatus.clear),
                ),
              ),
            ],
          );
        }
        return _panel(
          title: 'Status Update',
          body: 'Push duty-state transitions to the sync queue.',
          actions: [
            _actionButton(
              label: 'En Route',
              onPressed: () => _withSubmit(
                'EN ROUTE status queued.',
                () => widget.onStatusQueued(GuardDutyStatus.enRoute),
              ),
            ),
            _actionButton(
              label: 'On Site',
              onPressed: () => _withSubmit(
                'ON SITE status queued.',
                () => widget.onStatusQueued(GuardDutyStatus.onSite),
              ),
            ),
            _actionButton(
              label: 'Clear',
              onPressed: () => _withSubmit(
                'CLEAR status queued.',
                () => widget.onStatusQueued(GuardDutyStatus.clear),
              ),
            ),
            _actionButton(
              label: 'Offline',
              onPressed: () => _withSubmit(
                'OFFLINE status queued.',
                () => widget.onStatusQueued(GuardDutyStatus.offline),
              ),
            ),
          ],
        );
      case _GuardMobileScreen.checkpoint:
        final checkpointBanner =
            _shouldSurfaceContextCoaching(widget.coachingPrompt)
            ? _contextCoachingBanner(
                widget.coachingPrompt,
                context: 'checkpoint',
              )
            : null;
        return _panel(
          title: 'NFC Checkpoint',
          body:
              'Capture patrol verification against site checkpoints. Patrol image is enforced.',
          bodyWidget: Column(
            children: [
              if (checkpointBanner != null) ...[
                checkpointBanner,
                const SizedBox(height: 10),
              ],
              _field(
                label: 'Checkpoint ID',
                value: _checkpointId,
                onChanged: (value) => _checkpointId = value.trim(),
              ),
              const SizedBox(height: 10),
              _field(
                label: 'NFC Tag ID',
                value: _nfcTagId,
                onChanged: (value) => _nfcTagId = value.trim(),
              ),
            ],
          ),
          actions: [
            _actionButton(
              label: 'Queue Checkpoint Scan',
              onPressed: () async {
                await _withSubmit('Checkpoint scan queued.', () {
                  return widget.onCheckpointQueued(
                    checkpointId: _checkpointId.isEmpty
                        ? 'PERIMETER-NORTH'
                        : _checkpointId,
                    nfcTagId: _nfcTagId.isEmpty ? 'NFC-TAG-001' : _nfcTagId,
                  );
                });
              },
            ),
            _actionButton(
              label: _shiftVerified
                  ? 'Queue Patrol Image'
                  : 'Shift Start Required',
              onPressed: !_shiftVerified
                  ? null
                  : () async {
                      await _withSubmit(
                        'Patrol verification image queued.',
                        () {
                          return widget.onPatrolImageQueued(
                            checkpointId: _checkpointId.isEmpty
                                ? 'PERIMETER-NORTH'
                                : _checkpointId,
                          );
                        },
                      );
                    },
            ),
          ],
        );
      case _GuardMobileScreen.panic:
        final panicBody =
            widget.operatorRole == GuardMobileOperatorRole.reaction
            ? 'Escalate active reaction incident immediately to control room and nearby units.'
            : 'Send immediate panic signal and location to control room.';
        return _panel(
          title: 'Emergency Trigger',
          body: panicBody,
          bodyWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Outcome Confidence',
                style: GoogleFonts.inter(
                  color: const Color(0xFF9CC0E2),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _syncFilterChip(
                    label: 'Low',
                    selected: _outcomeConfidence == 'low',
                    onTap: () {
                      setState(() {
                        _outcomeConfidence = 'low';
                      });
                    },
                  ),
                  _syncFilterChip(
                    label: 'Medium',
                    selected: _outcomeConfidence == 'medium',
                    onTap: () {
                      setState(() {
                        _outcomeConfidence = 'medium';
                      });
                    },
                  ),
                  _syncFilterChip(
                    label: 'High',
                    selected: _outcomeConfidence == 'high',
                    onTap: () {
                      setState(() {
                        _outcomeConfidence = 'high';
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Confirmation Source',
                style: GoogleFonts.inter(
                  color: const Color(0xFF9CC0E2),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _availableConfirmationRoles()
                    .map((role) {
                      return _syncFilterChip(
                        label: _roleLabel(role),
                        selected: _outcomeConfirmedBy == role,
                        onTap: () {
                          setState(() {
                            _outcomeConfirmedBy = role;
                          });
                        },
                      );
                    })
                    .toList(growable: false),
              ),
              if (_requiresSupervisorConfirmation('true_threat') &&
                  _outcomeConfirmedBy != 'supervisor') ...[
                const SizedBox(height: 6),
                Text(
                  'Policy: true_threat requires supervisor confirmation.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFF1B872),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            _actionButton(
              label: 'Trigger Panic',
              danger: true,
              onPressed: () async {
                await _withSubmit('Panic signal queued.', () {
                  return widget.onPanicQueued();
                });
              },
            ),
            _actionButton(
              label: 'Label: True Threat',
              onPressed: () async {
                await _withSubmit('Incident labeled true_threat.', () {
                  _enforceOutcomeGovernance(
                    'true_threat',
                    confirmedBy: _outcomeConfirmedBy,
                  );
                  return widget.onOutcomeLabeled(
                    outcomeLabel: 'true_threat',
                    confidence: _outcomeConfidence,
                    confirmedBy: _outcomeConfirmedBy,
                  );
                });
              },
            ),
            _actionButton(
              label: 'Label: False Alarm',
              onPressed: () async {
                await _withSubmit('Incident labeled false_alarm.', () {
                  _enforceOutcomeGovernance(
                    'false_alarm',
                    confirmedBy: _outcomeConfirmedBy,
                  );
                  return widget.onOutcomeLabeled(
                    outcomeLabel: 'false_alarm',
                    confidence: _outcomeConfidence,
                    confirmedBy: _outcomeConfirmedBy,
                  );
                });
              },
            ),
            _actionButton(
              label: 'Label: Suspicious Activity',
              onPressed: () async {
                await _withSubmit('Incident labeled suspicious_activity.', () {
                  _enforceOutcomeGovernance(
                    'suspicious_activity',
                    confirmedBy: _outcomeConfirmedBy,
                  );
                  return widget.onOutcomeLabeled(
                    outcomeLabel: 'suspicious_activity',
                    confidence: _outcomeConfidence,
                    confirmedBy: _outcomeConfirmedBy,
                  );
                });
              },
            ),
          ],
        );
      case _GuardMobileScreen.sync:
        final nowUtc = DateTime.now().toUtc();
        final latestShiftStart = _latestEventAt(GuardOpsEventType.shiftStart);
        final latestShiftEnd = _latestEventAt(GuardOpsEventType.shiftEnd);
        final latestResumeSyncTrigger = _latestResumeSyncTriggerAt();
        final latestTelemetryPayloadAlert =
            _latestTelemetryPayloadHealthAlertAt();
        final latestExportAuditReset = _latestExportAuditResetEventAt();
        final latestExportAuditGenerated = _latestExportAuditGeneratedEventAt();
        final activeShiftId = widget.activeShiftId.trim();
        final filteredEvents = widget.recentEvents
            .where((event) => _eventMatchesFilter(event, _eventFilter))
            .take(4)
            .toList(growable: false);
        final filteredMedia = widget.recentMedia
            .where((media) => _mediaMatchesFilter(media, _mediaFilter))
            .take(4)
            .toList(growable: false);
        if (_selectedEventId != null &&
            !filteredEvents.any((event) => event.eventId == _selectedEventId)) {
          _selectedEventId = null;
        }
        if (_selectedMediaId != null &&
            !filteredMedia.any((media) => media.mediaId == _selectedMediaId)) {
          _selectedMediaId = null;
        }
        return _panel(
          title: 'Sync Status',
          body:
              'Manual sync trigger for pending event and media queues. Automatic sync runs in background.',
          bodyWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pending events: ${widget.pendingEventCount} | pending media: ${widget.pendingMediaCount}',
                style: GoogleFonts.inter(
                  color: const Color(0xFFB4C8E5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Sync health: ${_syncHealthLabel()}',
                style: GoogleFonts.inter(
                  color: _syncHealthColor(),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Role ops (shift) • reaction A/Ar/C: ${_reactionAcceptedCount(shiftId: activeShiftId)}/${_reactionArrivedCount(shiftId: activeShiftId)}/${_reactionClearedCount(shiftId: activeShiftId)} • supervisor O/Ack: ${_supervisorOverrideCount(shiftId: activeShiftId)}/${_supervisorCoachingAckCount(shiftId: activeShiftId)}',
                style: GoogleFonts.inter(
                  color: const Color(0xFFB4C8E5),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Telemetry adapter: ${widget.telemetryAdapterLabel} (${widget.telemetryAdapterStubMode ? 'stub' : 'live'})',
                style: GoogleFonts.inter(
                  color: widget.telemetryAdapterStubMode
                      ? const Color(0xFFF1B872)
                      : const Color(0xFF7FD8A5),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (widget.telemetryProviderStatusLabel != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Provider readiness: ${widget.telemetryProviderReadiness} • ${widget.telemetryProviderStatusLabel}',
                  style: GoogleFonts.inter(
                    color: _telemetryProviderReadinessColor(),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 2),
              Text(
                'Live-ready gate: ${widget.telemetryLiveReadyGateEnabled ? (widget.telemetryLiveReadyGateViolation ? 'VIOLATION' : 'OK') : 'disabled'}${widget.telemetryLiveReadyGateReason == null || widget.telemetryLiveReadyGateReason!.trim().isEmpty ? '' : ' • ${widget.telemetryLiveReadyGateReason}'}',
                style: GoogleFonts.inter(
                  color: widget.telemetryLiveReadyGateViolation
                      ? const Color(0xFFFF9A8B)
                      : (widget.telemetryLiveReadyGateEnabled
                            ? const Color(0xFF7FD8A5)
                            : const Color(0xFFB6C6DD)),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (widget.telemetryProviderId != null &&
                  widget.telemetryProviderId!.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Provider ID: ${widget.telemetryProviderId}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8DA4C5),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (_telemetryReplayOutput != null &&
                  _telemetryReplayOutput!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Telemetry Payload Replay Output',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF92D0FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  _telemetryReplayOutput!,
                  style: GoogleFonts.robotoMono(
                    color: const Color(0xFFB8CBE7),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Custom Telemetry Replay Payload',
                style: GoogleFonts.inter(
                  color: const Color(0xFF92D0FF),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                minLines: 3,
                maxLines: 6,
                onChanged: (value) => _customTelemetryPayloadJson = value,
                style: GoogleFonts.robotoMono(
                  color: const Color(0xFFB8CBE7),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText:
                      '{"heart_rate":81,"movement_level":0.57,"activity_state":"patrolling","captured_at_utc":"2026-03-05T14:05:00Z"}',
                  hintStyle: GoogleFonts.robotoMono(
                    color: const Color(0xFF6E84A3),
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF0A1324),
                  contentPadding: const EdgeInsets.all(10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF1C3454)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF1C3454)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF61C7FF)),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _syncFilterChip(
                    label: 'Standard',
                    selected: _customTelemetryPayloadAdapter == 'standard',
                    onTap: () {
                      setState(() {
                        _customTelemetryPayloadAdapter = 'standard';
                      });
                    },
                  ),
                  _syncFilterChip(
                    label: 'Legacy PTT',
                    selected: _customTelemetryPayloadAdapter == 'legacy_ptt',
                    onTap: () {
                      setState(() {
                        _customTelemetryPayloadAdapter = 'legacy_ptt';
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Resume sync event throttle: ${widget.resumeSyncEventThrottleSeconds}s',
                style: GoogleFonts.inter(
                  color: const Color(0xFFB6C6DD),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (widget.telemetryFacadeId != null ||
                  widget.telemetryFacadeLiveMode != null ||
                  widget.telemetryFacadeToggleSource != null ||
                  widget.telemetryFacadeRuntimeMode != null ||
                  widget.telemetryFacadeHeartbeatSource != null ||
                  widget.telemetryFacadeSourceActive != null ||
                  widget.telemetryFacadeCallbackCount != null) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _chip(
                      'Facade',
                      widget.telemetryFacadeId ?? 'unknown',
                      const Color(0xFF8FD1FF),
                    ),
                    _chip(
                      'Mode',
                      widget.telemetryFacadeLiveMode == null
                          ? 'unknown'
                          : (widget.telemetryFacadeLiveMode! ? 'live' : 'stub'),
                      widget.telemetryFacadeLiveMode == null
                          ? const Color(0xFFB6C6DD)
                          : (widget.telemetryFacadeLiveMode!
                                ? const Color(0xFF7FD8A5)
                                : const Color(0xFFF1B872)),
                    ),
                    _chip(
                      'Toggle',
                      widget.telemetryFacadeToggleSource ?? 'unknown',
                      const Color(0xFFB6C6DD),
                    ),
                    if (widget.telemetryFacadeRuntimeMode != null)
                      _chip(
                        'Runtime',
                        widget.telemetryFacadeRuntimeMode!,
                        const Color(0xFF8FD1FF),
                      ),
                    if (widget.telemetryFacadeHeartbeatSource != null)
                      _chip(
                        'Heartbeat Source',
                        widget.telemetryFacadeHeartbeatSource!,
                        const Color(0xFFB6C6DD),
                      ),
                    if (widget.telemetryFacadeSourceActive != null)
                      _chip(
                        'Source Active',
                        widget.telemetryFacadeSourceActive! ? 'yes' : 'no',
                        widget.telemetryFacadeSourceActive!
                            ? const Color(0xFF7FD8A5)
                            : const Color(0xFFF1B872),
                      ),
                    if (widget.telemetryFacadeCallbackCount != null)
                      _chip(
                        'SDK Callbacks',
                        widget.telemetryFacadeCallbackCount.toString(),
                        const Color(0xFF8FD1FF),
                      ),
                    if (widget.telemetryFacadeCallbackErrorCount != null)
                      _chip(
                        'Callback Errors',
                        widget.telemetryFacadeCallbackErrorCount.toString(),
                        (widget.telemetryFacadeCallbackErrorCount ?? 0) > 0
                            ? const Color(0xFFFF9A8B)
                            : const Color(0xFF7FD8A5),
                      ),
                    if (widget.telemetryFacadeLastCallbackAtUtc != null)
                      _chip(
                        'Callback Age',
                        _telemetryCallbackAgeLabel(nowUtc),
                        _telemetryCallbackAgeColor(nowUtc),
                      ),
                    _chip(
                      'Payload Health',
                      _telemetryPayloadHealthVerdict(nowUtc),
                      _telemetryPayloadHealthColor(nowUtc),
                    ),
                    _chip(
                      'Payload Health Trend',
                      _telemetryPayloadHealthTrendLabel(),
                      const Color(0xFFB6C6DD),
                    ),
                  ],
                ),
                if (widget.telemetryFacadeHeartbeatAction != null &&
                    widget.telemetryFacadeHeartbeatAction!
                        .trim()
                        .isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Heartbeat action: ${widget.telemetryFacadeHeartbeatAction}',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF8DA4C5),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (widget.telemetryFacadeLastCallbackAtUtc != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Last SDK callback: ${_formatUtc(widget.telemetryFacadeLastCallbackAtUtc!)}',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF8FD1FF),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (widget.telemetryFacadeLastCallbackMessage != null &&
                    widget.telemetryFacadeLastCallbackMessage!
                        .trim()
                        .isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Facade message: ${widget.telemetryFacadeLastCallbackMessage}',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFB6C6DD),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  'Payload health reason: ${_telemetryPayloadHealthReason(nowUtc)}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFB6C6DD),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Payload health trend: ${_telemetryPayloadHealthTrendDetails()}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8DA4C5),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.telemetryFacadeLastCallbackErrorAtUtc != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Last callback error at: ${_formatUtc(widget.telemetryFacadeLastCallbackErrorAtUtc!)}',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFFF9A8B),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (widget.telemetryFacadeLastCallbackErrorMessage != null &&
                    widget.telemetryFacadeLastCallbackErrorMessage!
                        .trim()
                        .isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Callback error: ${widget.telemetryFacadeLastCallbackErrorMessage}',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFFF9A8B),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'Telemetry Verification Checklist',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF92D0FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Callback seen: ${_telemetryCallbackSeen() ? 'pass' : 'pending'}',
                  style: GoogleFonts.inter(
                    color: _checklistColor(_telemetryCallbackSeen()),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Callback fresh (<=2m): ${_telemetryCallbackFresh(nowUtc) ? 'pass' : 'pending'}',
                  style: GoogleFonts.inter(
                    color: _checklistColor(_telemetryCallbackFresh(nowUtc)),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                'Failed events: ${widget.failedEventCount} | failed media: ${widget.failedMediaCount}',
                style: GoogleFonts.inter(
                  color: const Color(0xFFF1B872),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _chip(
                    'Active Shift',
                    widget.activeShiftId.trim().isEmpty
                        ? 'unassigned'
                        : widget.activeShiftId.trim(),
                    const Color(0xFF8FD1FF),
                  ),
                  _chip(
                    'Shift Seq Watermark',
                    widget.activeShiftSequenceWatermark.toString(),
                    const Color(0xFFB6C6DD),
                  ),
                  _chip(
                    'Shift Events',
                    _shiftEventCount(activeShiftId).toString(),
                    const Color(0xFF8FD1FF),
                  ),
                  _chip(
                    'Shift Media',
                    _shiftMediaCount(activeShiftId).toString(),
                    const Color(0xFF8FD1FF),
                  ),
                  _chip(
                    'Shift Pending',
                    '${_shiftEventPendingCount(activeShiftId) + _shiftMediaPendingCount(activeShiftId)}',
                    const Color(0xFFF1B872),
                  ),
                  _chip(
                    'Shift Failed',
                    '${_shiftEventFailedCount(activeShiftId) + _shiftMediaFailedCount(activeShiftId)}',
                    const Color(0xFFFF8D9A),
                  ),
                  _chip(
                    'Shift Closed',
                    _shiftHasEndEvent(activeShiftId) ? 'yes' : 'no',
                    _shiftHasEndEvent(activeShiftId)
                        ? const Color(0xFF7FD8A5)
                        : const Color(0xFFF1B872),
                  ),
                  _chip(
                    'Closeout Ready',
                    _shiftCloseoutReadinessLabel(activeShiftId),
                    _shiftCloseoutReadinessColor(activeShiftId),
                  ),
                  _chip(
                    'Shift Lifecycle',
                    _shiftLifecycleLabel(nowUtc),
                    _hasOpenShift(nowUtc)
                        ? const Color(0xFFF1B872)
                        : const Color(0xFF7FD8A5),
                  ),
                  _chip(
                    'Last Shift Start',
                    latestShiftStart == null
                        ? 'none'
                        : _formatUtc(latestShiftStart),
                    const Color(0xFF8FD1FF),
                  ),
                  _chip(
                    'Last Shift End',
                    latestShiftEnd == null
                        ? 'none'
                        : _formatUtc(latestShiftEnd),
                    const Color(0xFFB6C6DD),
                  ),
                  _chip(
                    'Open Shift Age',
                    _openShiftAgeLabel(nowUtc),
                    _hasOpenShift(nowUtc)
                        ? const Color(0xFFF1B872)
                        : const Color(0xFF7FD8A5),
                  ),
                  _chip(
                    'Last Resume Sync Trigger',
                    latestResumeSyncTrigger == null
                        ? 'none'
                        : _formatUtc(latestResumeSyncTrigger),
                    latestResumeSyncTrigger == null
                        ? const Color(0xFFB6C6DD)
                        : const Color(0xFF8FD1FF),
                  ),
                  _chip(
                    'Resume Sync Triggers',
                    _resumeSyncTriggerCount(activeShiftId).toString(),
                    const Color(0xFF8FD1FF),
                  ),
                  _chip(
                    'Telemetry Payload Alerts',
                    _telemetryPayloadHealthAlertCount(activeShiftId).toString(),
                    _telemetryPayloadHealthAlertCount(activeShiftId) > 0
                        ? const Color(0xFFFF8D9A)
                        : const Color(0xFF7FD8A5),
                  ),
                  _chip(
                    'Last Payload Alert',
                    latestTelemetryPayloadAlert == null
                        ? 'none'
                        : _formatUtc(latestTelemetryPayloadAlert),
                    latestTelemetryPayloadAlert == null
                        ? const Color(0xFFB6C6DD)
                        : const Color(0xFFFF8D9A),
                  ),
                  _chip(
                    'Last Export Audit Reset',
                    latestExportAuditReset == null
                        ? 'none'
                        : _formatUtc(latestExportAuditReset),
                    latestExportAuditReset == null
                        ? const Color(0xFFB6C6DD)
                        : const Color(0xFF8FD1FF),
                  ),
                  _chip(
                    'Export Audit Resets',
                    _exportAuditResetEventCount(activeShiftId).toString(),
                    const Color(0xFFB6C6DD),
                  ),
                  _chip(
                    'Last Export Audit Generated',
                    latestExportAuditGenerated == null
                        ? 'none'
                        : _formatUtc(latestExportAuditGenerated),
                    _exportAuditGeneratedHealthColor(
                      latestExportAuditGenerated,
                      nowUtc,
                    ),
                  ),
                  _chip(
                    'Export Gen/Clear Ratio',
                    _exportAuditGeneratedToClearedRatioLabel(activeShiftId),
                    _exportAuditRatioHealthColor(activeShiftId),
                  ),
                  _chip(
                    'Export Health Verdict',
                    _exportHealthVerdict(activeShiftId, nowUtc),
                    switch (_exportHealthVerdict(activeShiftId, nowUtc)) {
                      'Healthy' => const Color(0xFF7FD8A5),
                      'Warn' => const Color(0xFFF1B872),
                      _ => const Color(0xFFFF8D9A),
                    },
                  ),
                  _chip(
                    'Sync Report Exports',
                    _exportAuditGeneratedEventCount(
                      activeShiftId,
                      exportType: 'sync_report',
                    ).toString(),
                    const Color(0xFF8FD1FF),
                  ),
                  _chip(
                    'Replay Exports',
                    _exportAuditGeneratedEventCount(
                      activeShiftId,
                      exportType: 'shift_replay_summary',
                    ).toString(),
                    const Color(0xFF8FD1FF),
                  ),
                  _chip(
                    'Closeout Exports',
                    _exportAuditGeneratedEventCount(
                      activeShiftId,
                      exportType: 'dispatch_closeout_packet',
                    ).toString(),
                    const Color(0xFF8FD1FF),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Export health reason: ${_exportHealthReason(activeShiftId, nowUtc)}',
                style: GoogleFonts.inter(
                  color: const Color(0xFFB6C6DD),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Export health thresholds: ${_exportAuditHealthThresholdsLabel()}',
                style: GoogleFonts.inter(
                  color: const Color(0xFF8DA4C5),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (widget.lastSuccessfulSyncAtUtc != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Last successful sync: ${widget.lastSuccessfulSyncAtUtc!.toIso8601String()}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF7FD8A5),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (widget.lastFailureReason != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Last failure: ${widget.lastFailureReason}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFFF8D9A),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (widget.lastCloseoutPacketAuditLabel != null &&
                  widget.lastCloseoutPacketAuditLabel!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Last closeout packet: ${widget.lastCloseoutPacketAuditLabel}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8FD1FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (widget.lastShiftReplayAuditLabel != null &&
                  widget.lastShiftReplayAuditLabel!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Last replay summary: ${widget.lastShiftReplayAuditLabel}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8FD1FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (widget.lastSyncReportAuditLabel != null &&
                  widget.lastSyncReportAuditLabel!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Last sync report: ${widget.lastSyncReportAuditLabel}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8FD1FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (widget.lastExportAuditClearLabel != null &&
                  widget.lastExportAuditClearLabel!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Last export audit reset: ${widget.lastExportAuditClearLabel}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFB6C6DD),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                'Export Audit Timeline',
                style: GoogleFonts.inter(
                  color: const Color(0xFF92D0FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _ExportAuditFilter.values
                    .map((filter) {
                      final count = _recentExportAuditEvents(
                        limit: widget.recentEvents.length,
                        filter: filter,
                      ).length;
                      return _syncFilterChip(
                        label: '${_exportAuditFilterLabel(filter)}: $count',
                        selected: _exportAuditFilter == filter,
                        onTap: () {
                          setState(() {
                            _exportAuditFilter = filter;
                          });
                        },
                      );
                    })
                    .toList(growable: false),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () async {
                  final timeline = _recentExportAuditEvents(
                    filter: _exportAuditFilter,
                  );
                  await Clipboard.setData(
                    ClipboardData(
                      text: _buildExportAuditTimelineExport(timeline),
                    ),
                  );
                  if (!mounted) return;
                  _showSnack('Export audit timeline copied');
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Copy Export Audit Timeline',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8FD1FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () async {
                  final telemetryAlertTimeline = _recentExportAuditEvents(
                    limit: widget.recentEvents.length,
                    filter: _ExportAuditFilter.telemetryAlert,
                  );
                  await Clipboard.setData(
                    ClipboardData(
                      text: _buildExportAuditTimelineExport(
                        telemetryAlertTimeline,
                      ),
                    ),
                  );
                  if (!mounted) return;
                  _showSnack('Telemetry alerts timeline copied');
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Copy Telemetry Alerts Only',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8FD1FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              ...(() {
                final timeline = _recentExportAuditEvents(
                  filter: _exportAuditFilter,
                );
                if (timeline.isEmpty) {
                  return <Widget>[
                    Text(
                      'none yet',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF6F89AC),
                        fontSize: 11,
                      ),
                    ),
                  ];
                }
                return timeline
                    .map(
                      (event) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          _exportAuditTimelineRowSummary(event),
                          style: GoogleFonts.inter(
                            color: const Color(0xFFB6C6DD),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false);
              })(),
              const SizedBox(height: 8),
              _coachingPromptCard(widget.coachingPrompt),
              const SizedBox(height: 10),
              Text(
                'Recent Event Sync',
                style: GoogleFonts.inter(
                  color: const Color(0xFF92D0FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _SyncRowFilter.values
                    .map((filter) {
                      final count = widget.recentEvents
                          .where((event) => _eventMatchesFilter(event, filter))
                          .length;
                      return _syncFilterChip(
                        label: '${_filterLabel(filter)}: $count',
                        selected: _eventFilter == filter,
                        onTap: () {
                          setState(() {
                            _eventFilter = filter;
                          });
                        },
                      );
                    })
                    .toList(growable: false),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: filteredEvents.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(
                          ClipboardData(
                            text: _buildFilteredEventRowsExport(filteredEvents),
                          ),
                        );
                        if (!mounted) return;
                        _showSnack('Filtered event rows copied');
                      },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Copy Filtered Event Rows',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8FD1FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              ...filteredEvents.map((event) {
                final state = event.isPending
                    ? 'pending'
                    : event.failureReason != null
                    ? 'failed'
                    : 'synced';
                final selected = _selectedEventId == event.eventId;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedEventId = event.eventId;
                      _selectedMediaId = null;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF16304E)
                          : const Color(0xFF0A1324),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF61C7FF)
                            : const Color(0xFF1C3454),
                      ),
                    ),
                    child: Text(
                      '${event.eventType.name} • seq ${event.sequence} • $state • ${_formatUtc(event.occurredAt)}',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFB8CBE7),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }),
              if (filteredEvents.isEmpty)
                Text(
                  'No event history in this filter.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8097B8),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                'Recent Media Sync',
                style: GoogleFonts.inter(
                  color: const Color(0xFF92D0FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _SyncRowFilter.values
                    .map((filter) {
                      final count = widget.recentMedia
                          .where((media) => _mediaMatchesFilter(media, filter))
                          .length;
                      return _syncFilterChip(
                        label: '${_filterLabel(filter)}: $count',
                        selected: _mediaFilter == filter,
                        onTap: () {
                          setState(() {
                            _mediaFilter = filter;
                          });
                        },
                      );
                    })
                    .toList(growable: false),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: filteredMedia.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(
                          ClipboardData(
                            text: _buildFilteredMediaRowsExport(filteredMedia),
                          ),
                        );
                        if (!mounted) return;
                        _showSnack('Filtered media rows copied');
                      },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Copy Filtered Media Rows',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8FD1FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              ...filteredMedia.map((media) {
                final selected = _selectedMediaId == media.mediaId;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedMediaId = media.mediaId;
                      _selectedEventId = null;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF16304E)
                          : const Color(0xFF0A1324),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF61C7FF)
                            : const Color(0xFF1C3454),
                      ),
                    ),
                    child: Text(
                      '${media.bucket} • ${media.status.name} • ${_formatUtc(media.capturedAt)}',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFB8CBE7),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }),
              if (filteredMedia.isEmpty)
                Text(
                  'No media history in this filter.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8097B8),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 10),
              _syncDetailPanel(
                filteredEvents: filteredEvents,
                filteredMedia: filteredMedia,
              ),
            ],
          ),
          actions: [
            _actionButton(
              label: widget.syncInFlight ? 'Syncing...' : 'Sync Now',
              onPressed: widget.syncInFlight
                  ? null
                  : () async {
                      await _withSubmit('Manual sync completed.', () {
                        return widget.onSyncNow();
                      });
                    },
            ),
            _actionButton(
              label: 'Retry Failed Events',
              onPressed: () async {
                await _withSubmit('Failed events requeued for retry.', () {
                  return widget.onRetryFailedEvents();
                });
              },
            ),
            _actionButton(
              label: 'Retry Failed Media',
              onPressed: () async {
                await _withSubmit('Failed media requeued for retry.', () {
                  return widget.onRetryFailedMedia();
                });
              },
            ),
            _actionButton(
              label: 'Probe Telemetry Provider',
              onPressed: () async {
                await _withSubmit('Telemetry provider probe completed.', () {
                  return widget.onProbeTelemetryProvider();
                });
              },
            ),
            _actionButton(
              label: 'Queue Wearable Heartbeat',
              onPressed: () async {
                await _withSubmit('Wearable heartbeat queued.', () {
                  return widget.onWearableHeartbeatQueued();
                });
              },
            ),
            _actionButton(
              label: 'Queue Device Health',
              onPressed: () async {
                await _withSubmit('Device health telemetry queued.', () {
                  return widget.onDeviceHealthQueued();
                });
              },
            ),
            _actionButton(
              label: 'Seed Wearable Bridge',
              onPressed: widget.onSeedWearableBridge == null
                  ? null
                  : () async {
                      await _withSubmit('Wearable bridge sample ingested.', () {
                        return widget.onSeedWearableBridge!();
                      });
                    },
            ),
            if (widget.onEmitTelemetryDebugHeartbeat != null)
              _actionButton(
                label: 'Emit Debug SDK Heartbeat',
                onPressed: () async {
                  await _withSubmit(
                    'Debug SDK heartbeat broadcast emitted.',
                    () {
                      return widget.onEmitTelemetryDebugHeartbeat!();
                    },
                  );
                },
              ),
            if (widget.onValidateTelemetryPayloadReplay != null)
              _actionButton(
                label: 'Replay Payload (Standard)',
                onPressed: () async {
                  await _withSubmit(
                    'Telemetry payload replay validation completed (standard).',
                    () {
                      return _runTelemetryReplayValidation(
                        fixtureId: 'standard_sample',
                        payloadAdapter: 'standard',
                      );
                    },
                  );
                },
              ),
            if (widget.onValidateTelemetryPayloadReplay != null)
              _actionButton(
                label: 'Replay Payload (Legacy)',
                onPressed: () async {
                  await _withSubmit(
                    'Telemetry payload replay validation completed (legacy_ptt).',
                    () {
                      return _runTelemetryReplayValidation(
                        fixtureId: 'legacy_ptt_sample',
                        payloadAdapter: 'legacy_ptt',
                      );
                    },
                  );
                },
              ),
            if (widget.onValidateTelemetryPayloadReplay != null)
              _actionButton(
                label: 'Replay Payload (Custom JSON)',
                onPressed: () async {
                  await _withSubmit(
                    'Telemetry payload replay validation completed (custom).',
                    () {
                      return _runTelemetryReplayValidation(
                        fixtureId: 'custom_payload',
                        payloadAdapter: _customTelemetryPayloadAdapter,
                        customPayload: _decodeCustomTelemetryPayloadJson(),
                      );
                    },
                  );
                },
              ),
            _actionButton(
              label: 'Copy Sync Report',
              onPressed: () async {
                final generatedAtUtc = DateTime.now().toUtc();
                await Clipboard.setData(
                  ClipboardData(
                    text: _buildSyncReport(
                      filteredEvents: filteredEvents,
                      filteredMedia: filteredMedia,
                    ),
                  ),
                );
                if (widget.onSyncReportCopied != null) {
                  await widget.onSyncReportCopied!(
                    generatedAtUtc: generatedAtUtc,
                    scopeKey: widget.activeScopeKey,
                    facadeMode: widget.operationModeFilter.name,
                    eventFilter: _filterLabel(_eventFilter).toLowerCase(),
                    mediaFilter: _filterLabel(_mediaFilter).toLowerCase(),
                  );
                }
                if (!mounted) return;
                _showSnack('Sync report copied');
              },
            ),
            _actionButton(
              label: 'Copy Shift Replay Summary',
              onPressed: () async {
                final generatedAtUtc = DateTime.now().toUtc();
                final replayText = _buildShiftReplaySummary();
                await Clipboard.setData(ClipboardData(text: replayText));
                if (widget.onShiftReplaySummaryCopied != null) {
                  await widget.onShiftReplaySummaryCopied!(
                    generatedAtUtc: generatedAtUtc,
                    shiftId: activeShiftId,
                    eventRows: filteredEvents.length,
                    mediaRows: filteredMedia.length,
                  );
                }
                if (!mounted) return;
                _showSnack('Shift replay summary copied');
              },
            ),
            _actionButton(
              label: 'Dispatch Closeout Packet',
              onPressed: () async {
                final generatedAtUtc = DateTime.now().toUtc();
                await Clipboard.setData(
                  ClipboardData(
                    text: _buildDispatchCloseoutPacket(
                      filteredEvents: filteredEvents,
                      filteredMedia: filteredMedia,
                    ),
                  ),
                );
                await widget.onDispatchCloseoutPacketCopied(
                  generatedAtUtc: generatedAtUtc,
                  scopeKey: widget.activeScopeKey,
                  facadeMode: widget.operationModeFilter.name,
                  readinessState: _shiftCloseoutReadinessLabel(activeShiftId),
                );
                if (!mounted) return;
                _showSnack('Dispatch closeout packet copied');
              },
            ),
            _actionButton(
              label: 'Clear Export Audits',
              onPressed: widget.onClearExportAudits == null
                  ? null
                  : () async {
                      await _withSubmit('Export audits cleared.', () {
                        return widget.onClearExportAudits!();
                      });
                    },
            ),
            _actionButton(
              label: 'Copy Selected Operation Detail',
              onPressed: () async {
                final operation = _selectedOperation(
                  _visibleOperationsByMode(),
                );
                if (operation == null) {
                  _showSnack('No operation rows available in this filter.');
                  return;
                }
                await Clipboard.setData(
                  ClipboardData(text: _operationDetailText(operation)),
                );
                if (!mounted) return;
                _showSnack('Selected operation detail copied');
              },
            ),
            _actionButton(
              label: 'Retry Selected Failed Op',
              onPressed: () async {
                await _withSubmit(
                  'Retry queued for selected operation.',
                  () async {
                    final operation = _selectedOperation(
                      _visibleOperationsByMode(),
                    );
                    if (operation == null) {
                      throw StateError('No operation rows available to retry.');
                    }
                    if (operation.status != GuardSyncOperationStatus.failed) {
                      throw StateError(
                        'Select a failed operation in history before retrying.',
                      );
                    }
                    await widget.onRetryFailedOperation(operation.operationId);
                  },
                );
              },
            ),
            _actionButton(
              label: 'Retry All Failed Ops',
              onPressed: () async {
                final failedIds = _visibleOperationsByMode()
                    .where(
                      (operation) =>
                          operation.status == GuardSyncOperationStatus.failed,
                    )
                    .map((operation) => operation.operationId)
                    .where((id) => id.trim().isNotEmpty)
                    .toList(growable: false);
                if (failedIds.isEmpty) {
                  _showSnack(
                    'No failed operations in the current history filter.',
                  );
                  return;
                }
                final confirmed = await _confirmRetryAllFailedOps(
                  failedIds.length,
                );
                if (!confirmed) return;
                await _withSubmit(
                  'Retry queued for ${failedIds.length} failed operation(s).',
                  () => widget.onRetryFailedOperationsBulk(failedIds),
                );
              },
            ),
          ],
        );
    }
  }

  Widget _coachingPromptCard(GuardCoachingPrompt prompt) {
    final accent = switch (prompt.priority) {
      GuardCoachingPriority.low => const Color(0xFF7FD8A5),
      GuardCoachingPriority.medium => const Color(0xFFF1B872),
      GuardCoachingPriority.high => const Color(0xFFFF9EA7),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1325),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Operational Coaching • ${prompt.ruleId}',
            style: GoogleFonts.inter(
              color: accent,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            prompt.headline,
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFE8F1FF),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            prompt.message,
            style: GoogleFonts.inter(
              color: const Color(0xFFB8CBE7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () async {
              await _withSubmit(
                'Coaching prompt acknowledged.',
                () => widget.onAcknowledgeCoachingPrompt(
                  ruleId: prompt.ruleId,
                  context: 'sync',
                ),
              );
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Acknowledge Prompt',
              style: GoogleFonts.inter(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton(
                onPressed:
                    widget.coachingPolicy.canSnooze(
                      prompt: prompt,
                      actorRole: GuardCoachingActorRole.guard,
                    )
                    ? () async {
                        final minutes = widget.coachingPolicy
                            .defaultSnoozeWindow(prompt)
                            .inMinutes;
                        await _withSubmit(
                          'Coaching prompt snoozed for $minutes minutes.',
                          () => widget.onSnoozeCoachingPrompt(
                            ruleId: prompt.ruleId,
                            context: 'sync',
                            minutes: minutes,
                            actorRole: GuardCoachingActorRole.guard.name,
                          ),
                        );
                      }
                    : null,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  widget.coachingPolicy.canSnooze(
                        prompt: prompt,
                        actorRole: GuardCoachingActorRole.guard,
                      )
                      ? 'Snooze Prompt'
                      : 'Guard Snooze Blocked',
                  style: GoogleFonts.inter(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!widget.coachingPolicy.canSnooze(
                prompt: prompt,
                actorRole: GuardCoachingActorRole.guard,
              ))
                TextButton(
                  onPressed: () async {
                    final minutes = widget.coachingPolicy
                        .defaultSnoozeWindow(prompt)
                        .inMinutes;
                    await _withSubmit(
                      'Supervisor override snooze applied for $minutes minutes.',
                      () => widget.onSnoozeCoachingPrompt(
                        ruleId: prompt.ruleId,
                        context: 'sync',
                        minutes: minutes,
                        actorRole: GuardCoachingActorRole.supervisor.name,
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Supervisor Override Snooze',
                    style: GoogleFonts.inter(
                      color: accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  bool _shouldSurfaceContextCoaching(GuardCoachingPrompt prompt) {
    return prompt.priority != GuardCoachingPriority.low;
  }

  Widget _contextCoachingBanner(
    GuardCoachingPrompt prompt, {
    required String context,
  }) {
    final accent = switch (prompt.priority) {
      GuardCoachingPriority.low => const Color(0xFF7FD8A5),
      GuardCoachingPriority.medium => const Color(0xFFF1B872),
      GuardCoachingPriority.high => const Color(0xFFFF9EA7),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF091427),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Coaching Prompt • ${context.toUpperCase()}',
            style: GoogleFonts.inter(
              color: accent,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            prompt.headline,
            style: GoogleFonts.inter(
              color: const Color(0xFFE8F1FF),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () async {
              await _withSubmit(
                'Coaching prompt acknowledged.',
                () => widget.onAcknowledgeCoachingPrompt(
                  ruleId: prompt.ruleId,
                  context: context,
                ),
              );
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Acknowledge Prompt',
              style: GoogleFonts.inter(
                color: accent,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 2),
          TextButton(
            onPressed:
                widget.coachingPolicy.canSnooze(
                  prompt: prompt,
                  actorRole: GuardCoachingActorRole.guard,
                )
                ? () async {
                    final minutes = widget.coachingPolicy
                        .defaultSnoozeWindow(prompt)
                        .inMinutes;
                    await _withSubmit(
                      'Coaching prompt snoozed for $minutes minutes.',
                      () => widget.onSnoozeCoachingPrompt(
                        ruleId: prompt.ruleId,
                        context: context,
                        minutes: minutes,
                        actorRole: GuardCoachingActorRole.guard.name,
                      ),
                    );
                  }
                : null,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              widget.coachingPolicy.canSnooze(
                    prompt: prompt,
                    actorRole: GuardCoachingActorRole.guard,
                  )
                  ? 'Snooze Prompt'
                  : 'Guard Snooze Blocked',
              style: GoogleFonts.inter(
                color: accent,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (!widget.coachingPolicy.canSnooze(
            prompt: prompt,
            actorRole: GuardCoachingActorRole.guard,
          ))
            TextButton(
              onPressed: () async {
                final minutes = widget.coachingPolicy
                    .defaultSnoozeWindow(prompt)
                    .inMinutes;
                await _withSubmit(
                  'Supervisor override snooze applied for $minutes minutes.',
                  () => widget.onSnoozeCoachingPrompt(
                    ruleId: prompt.ruleId,
                    context: context,
                    minutes: minutes,
                    actorRole: GuardCoachingActorRole.supervisor.name,
                  ),
                );
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Supervisor Override Snooze',
                style: GoogleFonts.inter(
                  color: accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _syncDetailPanel({
    required List<GuardOpsEvent> filteredEvents,
    required List<GuardOpsMediaUpload> filteredMedia,
  }) {
    final selectedEvent = filteredEvents
        .where((entry) => entry.eventId == _selectedEventId)
        .firstOrNull;
    final selectedMedia = filteredMedia
        .where((entry) => entry.mediaId == _selectedMediaId)
        .firstOrNull;
    if (selectedEvent == null && selectedMedia == null) {
      return Text(
        'Select a recent row to inspect payload, retries, and failure trace.',
        style: GoogleFonts.inter(
          color: const Color(0xFF7F98BA),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    if (selectedEvent != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1325),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2A4A74)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Event ${selectedEvent.eventType.name}',
              style: GoogleFonts.inter(
                color: const Color(0xFFD3E3FA),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              _eventDetailText(selectedEvent).split('\n').skip(1).join('\n'),
              style: GoogleFonts.inter(
                color: const Color(0xFFC7D8F1),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: _eventDetailText(selectedEvent)),
                );
                if (!mounted) return;
                _showSnack('Sync detail copied');
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Copy Selected Detail',
                style: GoogleFonts.inter(
                  color: const Color(0xFF8FD1FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }
    final media = selectedMedia!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1325),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A4A74)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Media ${media.status.name}',
            style: GoogleFonts.inter(
              color: const Color(0xFFD3E3FA),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            _mediaDetailText(media).split('\n').skip(1).join('\n'),
            style: GoogleFonts.inter(
              color: const Color(0xFFC7D8F1),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: _mediaDetailText(media)),
              );
              if (!mounted) return;
              _showSnack('Sync detail copied');
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Copy Selected Detail',
              style: GoogleFonts.inter(
                color: const Color(0xFF8FD1FF),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel({
    required String title,
    required String body,
    required List<Widget> actions,
    Widget? bodyWidget,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1930), Color(0xFF0A1428)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFF1E3A62)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFE7F1FF),
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1D2),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (bodyWidget != null) ...[const SizedBox(height: 12), bodyWidget],
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ),
    );
  }

  Widget _field({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return TextFormField(
      initialValue: value,
      onChanged: onChanged,
      style: GoogleFonts.inter(
        color: const Color(0xFFE7F1FF),
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
          color: const Color(0xFF86A0C6),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: const Color(0xFF0B162C),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1F3D65)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1F3D65)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF4BAFFF)),
        ),
      ),
    );
  }

  Widget _screenChip(String label, _GuardMobileScreen screen) {
    final selected = _screen == screen;
    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.inter(
          color: selected ? const Color(0xFFDAE8FF) : const Color(0xFF8EA5C6),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _screen = screen;
        });
      },
      backgroundColor: const Color(0xFF0A1428),
      selectedColor: const Color(0xFF18355A),
      side: BorderSide(
        color: selected ? const Color(0xFF3E7EC0) : const Color(0xFF224066),
      ),
    );
  }

  Widget _syncFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: selected
            ? const Color(0xFF09192F)
            : const Color(0xFF9FB6D5),
        backgroundColor: selected
            ? const Color(0xFF8FD1FF)
            : const Color(0x142A5E97),
        side: BorderSide(
          color: selected ? const Color(0xFF8FD1FF) : const Color(0xFF2A5E97),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required Future<void> Function()? onPressed,
    bool danger = false,
  }) {
    final color = danger ? const Color(0xFFFF6C7A) : const Color(0xFF66C5FF);
    return FilledButton(
      onPressed: _submitting || onPressed == null ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: danger
            ? const Color(0xFF3A1420)
            : const Color(0xFF132E4E),
        side: BorderSide(color: color.withValues(alpha: 0.75)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _operationRow(
    GuardSyncOperation operation, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    final statusColor = switch (operation.status) {
      GuardSyncOperationStatus.queued => const Color(0xFFF1B872),
      GuardSyncOperationStatus.synced => const Color(0xFF7FD8A5),
      GuardSyncOperationStatus.failed => const Color(0xFFFF8D9A),
    };
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: selected ? const Color(0xFF143155) : const Color(0xFF0A1529),
          border: Border.all(
            color: selected ? const Color(0xFF69C3FF) : const Color(0xFF1F3D64),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              operation.type.name,
              style: GoogleFonts.inter(
                color: const Color(0xFF8FD3FF),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Status: ${operation.status.name}',
              style: GoogleFonts.inter(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            if ((operation.failureReason ?? '').trim().isNotEmpty)
              Text(
                'Failure: ${operation.failureReason}',
                style: GoogleFonts.inter(
                  color: const Color(0xFFFF9EA7),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            if ((operation.failureReason ?? '').trim().isNotEmpty)
              const SizedBox(height: 4),
            Text(
              operation.operationId,
              style: GoogleFonts.inter(
                color: const Color(0xFFDCE9FF),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'At ${operation.createdAt.toUtc().toIso8601String()}',
              style: GoogleFonts.inter(
                color: const Color(0xFF8EA5C6),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _operationDetailPanel(List<GuardSyncOperation> operations) {
    final operation = _selectedOperation(operations);
    if (operation == null) {
      return const SizedBox.shrink();
    }
    final operationContext = _operationRuntimeContext(operation);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF091224),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1F3D64)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selected Operation Detail',
            style: GoogleFonts.inter(
              color: const Color(0xFF8FD1FF),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (operationContext != null) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _chip(
                  'Op Adapter',
                  operationContext['telemetry_adapter_label']?.toString() ??
                      'unknown',
                  const Color(0xFF8FD1FF),
                ),
                _chip(
                  'Op Facade',
                  operationContext['telemetry_facade_id']?.toString() ??
                      'unknown',
                  const Color(0xFFB6C6DD),
                ),
                _chip(
                  'Op Mode',
                  _runtimeBoolLabel(
                    operationContext['telemetry_facade_live_mode'],
                  ),
                  const Color(0xFF7FD8A5),
                ),
                _chip(
                  'Op Toggle',
                  operationContext['telemetry_facade_toggle_source']
                          ?.toString() ??
                      'unknown',
                  const Color(0xFFF1B872),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          SelectableText(
            _operationDetailText(operation),
            style: GoogleFonts.jetBrainsMono(
              color: const Color(0xFFB8CBE7),
              fontSize: 10,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, Object?>? _operationRuntimeContext(GuardSyncOperation operation) {
    final raw = operation.payload['onyx_runtime_context'];
    if (raw is! Map) return null;
    final mapped = raw.map((key, value) => MapEntry(key.toString(), value));
    return mapped;
  }

  String _runtimeBoolLabel(Object? raw) {
    if (raw is bool) return raw ? 'live' : 'stub';
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      if (normalized == 'true') return 'live';
      if (normalized == 'false') return 'stub';
    }
    return 'unknown';
  }

  Widget _historyChip({
    required String label,
    required GuardSyncHistoryFilter filter,
  }) {
    final selected = widget.historyFilter == filter;
    return TextButton(
      onPressed: _submitting || selected
          ? null
          : () async {
              await _withSubmit(
                'History filter switched to ${filter.name}.',
                () => widget.onHistoryFilterChanged(filter),
              );
            },
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: selected
            ? const Color(0xFF09192F)
            : const Color(0xFF9FB6D5),
        backgroundColor: selected
            ? const Color(0xFF8FD1FF)
            : const Color(0x142A5E97),
        side: BorderSide(
          color: selected ? const Color(0xFF8FD1FF) : const Color(0xFF2A5E97),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _chip(String label, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$label: $value',
        style: GoogleFonts.inter(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _copyScopedSelectionKeys() async {
    final rows =
        widget.scopedSelectionsByScope.entries
            .map(
              (entry) =>
                  (scope: entry.key.trim(), operationId: entry.value.trim()),
            )
            .where(
              (entry) => entry.scope.isNotEmpty && entry.operationId.isNotEmpty,
            )
            .toList(growable: false)
          ..sort((a, b) => a.scope.compareTo(b.scope));
    final text = rows.isEmpty
        ? 'none'
        : rows
              .map((entry) => '${entry.scope} => ${entry.operationId}')
              .join('\n');
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _withSubmit(
    String successMessage,
    Future<void> Function() action,
  ) async {
    setState(() {
      _submitting = true;
    });
    try {
      await action();
      if (!mounted) return;
      setState(() {
        _lastActionStatus = successMessage;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _lastActionStatus = 'Guard action failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(
            color: const Color(0xFFE7F1FF),
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: const Color(0xFF0E203A),
      ),
    );
  }
}
