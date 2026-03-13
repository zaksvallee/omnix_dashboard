import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../infrastructure/intelligence/news_intelligence_service.dart';
import '../domain/guard/guard_mobile_ops.dart';
import 'radio_bridge_service.dart';
import 'offline_incident_spool_service.dart';
import '../ui/client_app_page.dart';
import '../ui/dispatch_models.dart';

class DispatchPersistenceService {
  static const intakeTelemetryKey = 'onyx_dispatch_intake_telemetry_v1';
  static const stressProfileKey = 'onyx_dispatch_stress_profile_v1';
  static const livePollHistoryKey = 'onyx_dispatch_live_poll_history_v1';
  static const livePollSummaryKey = 'onyx_dispatch_live_poll_summary_v1';
  static const newsSourceDiagnosticsKey =
      'onyx_dispatch_news_source_diagnostics_v1';
  static const radioIntentPhrasesJsonKey = 'onyx_radio_intent_phrases_json_v1';
  static const pendingRadioAutomatedResponsesKey =
      'onyx_pending_radio_automated_responses_v1';
  static const pendingRadioAutomatedResponsesRetryStateKey =
      'onyx_pending_radio_automated_responses_retry_state_v1';
  static const pendingRadioQueueManualActionDetailKey =
      'onyx_pending_radio_queue_manual_action_detail_v1';
  static const pendingRadioQueueFailureSnapshotKey =
      'onyx_pending_radio_queue_failure_snapshot_v1';
  static const pendingRadioQueueFailureAuditDetailKey =
      'onyx_pending_radio_queue_failure_audit_detail_v1';
  static const pendingRadioQueueStateChangeDetailKey =
      'onyx_pending_radio_queue_state_change_detail_v1';
  static const opsIntegrationHealthSnapshotKey =
      'onyx_ops_integration_health_snapshot_v1';
  static const clientAppDraftKey = 'onyx_client_app_draft_v1';
  static const clientAppMessagesKey = 'onyx_client_app_messages_v1';
  static const clientAppAcknowledgementsKey = 'onyx_client_app_acks_v1';
  static const clientAppPushQueueKey = 'onyx_client_app_push_queue_v1';
  static const clientAppPushSyncStateKey = 'onyx_client_app_push_sync_state_v1';
  static const telegramAdminRuntimeStateKey =
      'onyx_telegram_admin_runtime_state_v1';
  static const offlineIncidentSpoolEntriesKey =
      'onyx_offline_incident_spool_entries_v1';
  static const offlineIncidentSpoolSyncStateKey =
      'onyx_offline_incident_spool_sync_state_v1';
  static const guardAssignmentsKey = 'onyx_guard_assignments_v1';
  static const guardSyncOperationsKey = 'onyx_guard_sync_operations_v1';
  static const guardSyncHistoryFilterKey = 'onyx_guard_sync_history_filter_v1';
  static const guardSyncOperationModeFilterKey =
      'onyx_guard_sync_operation_mode_filter_v1';
  static const guardSyncSelectedFacadeIdKey =
      'onyx_guard_sync_selected_facade_id_v1';
  static const guardSyncSelectedOperationIdsKey =
      'onyx_guard_sync_selected_operation_ids_v1';
  static const guardOutcomeGovernanceTelemetryKey =
      'onyx_guard_outcome_governance_telemetry_v1';
  static const guardCoachingPromptSnoozesKey =
      'onyx_guard_coaching_prompt_snoozes_v1';
  static const guardCoachingTelemetryKey = 'onyx_guard_coaching_telemetry_v1';
  static const guardCloseoutPacketAuditKey =
      'onyx_guard_closeout_packet_audit_v1';
  static const guardShiftReplayAuditKey = 'onyx_guard_shift_replay_audit_v1';
  static const guardSyncReportAuditKey = 'onyx_guard_sync_report_audit_v1';
  static const guardExportAuditClearMetaKey =
      'onyx_guard_export_audit_clear_meta_v1';
  static const morningSovereignReportKey = 'onyx_morning_sovereign_report_v1';
  static const morningSovereignReportAutoRunKey =
      'onyx_morning_sovereign_report_auto_run_key_v1';

  final SharedPreferences prefs;

  const DispatchPersistenceService(this.prefs);

  static Future<DispatchPersistenceService> create() async {
    return DispatchPersistenceService(await SharedPreferences.getInstance());
  }

  Future<IntakeTelemetry?> readTelemetry() async {
    final raw = prefs.getString(intakeTelemetryKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return IntakeTelemetry.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value as Object?)),
      );
    } catch (_) {
      await clearTelemetry();
      return null;
    }
  }

  Future<void> saveTelemetry(IntakeTelemetry telemetry) async {
    await prefs.setString(intakeTelemetryKey, jsonEncode(telemetry.toJson()));
  }

  Future<void> clearTelemetry() async {
    await prefs.remove(intakeTelemetryKey);
  }

  Future<List<String>> readLivePollHistory() async {
    final raw = prefs.getString(livePollHistoryKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map((item) => item?.toString() ?? '')
          .where((item) => item.trim().isNotEmpty)
          .map((item) => item.trim())
          .toList(growable: false);
    } catch (_) {
      await clearLivePollHistory();
      return const [];
    }
  }

  Future<void> saveLivePollHistory(List<String> entries) async {
    await prefs.setString(livePollHistoryKey, jsonEncode(entries));
  }

  Future<void> clearLivePollHistory() async {
    await prefs.remove(livePollHistoryKey);
  }

  Future<Map<String, Object?>> readLivePollSummary() async {
    final raw = prefs.getString(livePollSummaryKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value as Object?),
      );
    } catch (_) {
      await clearLivePollSummary();
      return const {};
    }
  }

  Future<void> saveLivePollSummary(Map<String, Object?> summary) async {
    await prefs.setString(livePollSummaryKey, jsonEncode(summary));
  }

  Future<void> clearLivePollSummary() async {
    await prefs.remove(livePollSummaryKey);
  }

  Future<List<NewsSourceDiagnostic>> readNewsSourceDiagnostics() async {
    final raw = prefs.getString(newsSourceDiagnosticsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => NewsSourceDiagnostic.fromJson(
              item.map(
                (key, value) => MapEntry(key.toString(), value as Object?),
              ),
            ),
          )
          .where((item) => item.provider.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      await clearNewsSourceDiagnostics();
      return const [];
    }
  }

  Future<void> saveNewsSourceDiagnostics(
    List<NewsSourceDiagnostic> diagnostics,
  ) async {
    await prefs.setString(
      newsSourceDiagnosticsKey,
      jsonEncode(diagnostics.map((entry) => entry.toJson()).toList()),
    );
  }

  Future<void> clearNewsSourceDiagnostics() async {
    await prefs.remove(newsSourceDiagnosticsKey);
  }

  Future<String?> readRadioIntentPhrasesJson() async {
    final raw = prefs.getString(radioIntentPhrasesJsonKey);
    if (raw == null || raw.trim().isEmpty) return null;
    return raw.trim();
  }

  Future<void> saveRadioIntentPhrasesJson(String rawJson) async {
    await prefs.setString(radioIntentPhrasesJsonKey, rawJson.trim());
  }

  Future<void> clearRadioIntentPhrasesJson() async {
    await prefs.remove(radioIntentPhrasesJsonKey);
  }

  Future<List<RadioAutomatedResponse>>
  readPendingRadioAutomatedResponses() async {
    final raw = prefs.getString(pendingRadioAutomatedResponsesKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (entry) => RadioAutomatedResponse.fromJson(
              entry.map(
                (key, value) => MapEntry(key.toString(), value as Object?),
              ),
            ),
          )
          .where(
            (entry) =>
                entry.transmissionId.trim().isNotEmpty &&
                entry.message.trim().isNotEmpty,
          )
          .toList(growable: false);
    } catch (_) {
      await clearPendingRadioAutomatedResponses();
      return const [];
    }
  }

  Future<void> savePendingRadioAutomatedResponses(
    List<RadioAutomatedResponse> responses,
  ) async {
    await prefs.setString(
      pendingRadioAutomatedResponsesKey,
      jsonEncode(responses.map((entry) => entry.toJson()).toList()),
    );
  }

  Future<void> clearPendingRadioAutomatedResponses() async {
    await prefs.remove(pendingRadioAutomatedResponsesKey);
  }

  Future<Map<String, Map<String, Object?>>>
  readPendingRadioAutomatedResponsesRetryState() async {
    final raw = prefs.getString(pendingRadioAutomatedResponsesRetryStateKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      final parsed = <String, Map<String, Object?>>{};
      decoded.forEach((key, value) {
        if (value is! Map) return;
        parsed[key.toString()] = value.map(
          (entryKey, entryValue) =>
              MapEntry(entryKey.toString(), entryValue as Object?),
        );
      });
      return parsed;
    } catch (_) {
      await clearPendingRadioAutomatedResponsesRetryState();
      return const {};
    }
  }

  Future<void> savePendingRadioAutomatedResponsesRetryState(
    Map<String, Map<String, Object?>> retryStateByResponseKey,
  ) async {
    await prefs.setString(
      pendingRadioAutomatedResponsesRetryStateKey,
      jsonEncode(retryStateByResponseKey),
    );
  }

  Future<void> clearPendingRadioAutomatedResponsesRetryState() async {
    await prefs.remove(pendingRadioAutomatedResponsesRetryStateKey);
  }

  Future<String?> readPendingRadioQueueManualActionDetail() async {
    final raw = prefs.getString(pendingRadioQueueManualActionDetailKey);
    if (raw == null || raw.trim().isEmpty) return null;
    return raw.trim();
  }

  Future<void> savePendingRadioQueueManualActionDetail(String detail) async {
    final normalized = detail.trim();
    if (normalized.isEmpty) {
      await clearPendingRadioQueueManualActionDetail();
      return;
    }
    await prefs.setString(pendingRadioQueueManualActionDetailKey, normalized);
  }

  Future<void> clearPendingRadioQueueManualActionDetail() async {
    await prefs.remove(pendingRadioQueueManualActionDetailKey);
  }

  Future<String?> readPendingRadioQueueFailureSnapshot() async {
    final raw = prefs.getString(pendingRadioQueueFailureSnapshotKey);
    if (raw == null || raw.trim().isEmpty) return null;
    return raw.trim();
  }

  Future<void> savePendingRadioQueueFailureSnapshot(String detail) async {
    final normalized = detail.trim();
    if (normalized.isEmpty) {
      await clearPendingRadioQueueFailureSnapshot();
      return;
    }
    await prefs.setString(pendingRadioQueueFailureSnapshotKey, normalized);
  }

  Future<void> clearPendingRadioQueueFailureSnapshot() async {
    await prefs.remove(pendingRadioQueueFailureSnapshotKey);
  }

  Future<String?> readPendingRadioQueueFailureAuditDetail() async {
    final raw = prefs.getString(pendingRadioQueueFailureAuditDetailKey);
    if (raw == null || raw.trim().isEmpty) return null;
    return raw.trim();
  }

  Future<void> savePendingRadioQueueFailureAuditDetail(String detail) async {
    final normalized = detail.trim();
    if (normalized.isEmpty) {
      await clearPendingRadioQueueFailureAuditDetail();
      return;
    }
    await prefs.setString(pendingRadioQueueFailureAuditDetailKey, normalized);
  }

  Future<void> clearPendingRadioQueueFailureAuditDetail() async {
    await prefs.remove(pendingRadioQueueFailureAuditDetailKey);
  }

  Future<String?> readPendingRadioQueueStateChangeDetail() async {
    final raw = prefs.getString(pendingRadioQueueStateChangeDetailKey);
    if (raw == null || raw.trim().isEmpty) return null;
    return raw.trim();
  }

  Future<void> savePendingRadioQueueStateChangeDetail(String detail) async {
    final normalized = detail.trim();
    if (normalized.isEmpty) {
      await clearPendingRadioQueueStateChangeDetail();
      return;
    }
    await prefs.setString(pendingRadioQueueStateChangeDetailKey, normalized);
  }

  Future<void> clearPendingRadioQueueStateChangeDetail() async {
    await prefs.remove(pendingRadioQueueStateChangeDetailKey);
  }

  Future<Map<String, Object?>> readOpsIntegrationHealthSnapshot() async {
    final raw = prefs.getString(opsIntegrationHealthSnapshotKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value as Object?),
      );
    } catch (_) {
      await clearOpsIntegrationHealthSnapshot();
      return const {};
    }
  }

  Future<void> saveOpsIntegrationHealthSnapshot(
    Map<String, Object?> snapshot,
  ) async {
    await prefs.setString(
      opsIntegrationHealthSnapshotKey,
      jsonEncode(snapshot),
    );
  }

  Future<void> clearOpsIntegrationHealthSnapshot() async {
    await prefs.remove(opsIntegrationHealthSnapshotKey);
  }

  Future<ClientAppDraft?> readClientAppDraft() async {
    final raw = prefs.getString(clientAppDraftKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return ClientAppDraft.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value as Object?)),
      );
    } catch (_) {
      await clearClientAppDraft();
      return null;
    }
  }

  Future<void> saveClientAppDraft(ClientAppDraft draft) async {
    await prefs.setString(clientAppDraftKey, jsonEncode(draft.toJson()));
  }

  Future<void> clearClientAppDraft() async {
    await prefs.remove(clientAppDraftKey);
  }

  Future<List<ClientAppMessage>> readClientAppMessages() async {
    final raw = prefs.getString(clientAppMessagesKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => ClientAppMessage.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .where((message) => message.body.trim().isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      await clearClientAppMessages();
      return const [];
    }
  }

  Future<void> saveClientAppMessages(List<ClientAppMessage> messages) async {
    await prefs.setString(
      clientAppMessagesKey,
      jsonEncode(messages.map((message) => message.toJson()).toList()),
    );
  }

  Future<void> clearClientAppMessages() async {
    await prefs.remove(clientAppMessagesKey);
  }

  Future<List<ClientAppAcknowledgement>> readClientAppAcknowledgements() async {
    final raw = prefs.getString(clientAppAcknowledgementsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => ClientAppAcknowledgement.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .where((item) => item.messageKey.trim().isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      await clearClientAppAcknowledgements();
      return const [];
    }
  }

  Future<void> saveClientAppAcknowledgements(
    List<ClientAppAcknowledgement> acknowledgements,
  ) async {
    await prefs.setString(
      clientAppAcknowledgementsKey,
      jsonEncode(
        acknowledgements
            .map((acknowledgement) => acknowledgement.toJson())
            .toList(),
      ),
    );
  }

  Future<void> clearClientAppAcknowledgements() async {
    await prefs.remove(clientAppAcknowledgementsKey);
  }

  Future<List<ClientAppPushDeliveryItem>> readClientAppPushQueue() async {
    final raw = prefs.getString(clientAppPushQueueKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => ClientAppPushDeliveryItem.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .where((item) => item.messageKey.trim().isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      await clearClientAppPushQueue();
      return const [];
    }
  }

  Future<void> saveClientAppPushQueue(
    List<ClientAppPushDeliveryItem> pushQueue,
  ) async {
    await prefs.setString(
      clientAppPushQueueKey,
      jsonEncode(pushQueue.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> clearClientAppPushQueue() async {
    await prefs.remove(clientAppPushQueueKey);
  }

  Future<ClientPushSyncState> readClientAppPushSyncState() async {
    final raw = prefs.getString(clientAppPushSyncStateKey);
    if (raw == null || raw.isEmpty) return const ClientPushSyncState.idle();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const ClientPushSyncState.idle();
      return ClientPushSyncState.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value as Object?)),
      );
    } catch (_) {
      await clearClientAppPushSyncState();
      return const ClientPushSyncState.idle();
    }
  }

  Future<void> saveClientAppPushSyncState(ClientPushSyncState state) async {
    await prefs.setString(
      clientAppPushSyncStateKey,
      jsonEncode(state.toJson()),
    );
  }

  Future<void> clearClientAppPushSyncState() async {
    await prefs.remove(clientAppPushSyncStateKey);
  }

  Future<Map<String, Object?>> readTelegramAdminRuntimeState() async {
    final raw = prefs.getString(telegramAdminRuntimeStateKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value as Object?),
      );
    } catch (_) {
      await clearTelegramAdminRuntimeState();
      return const {};
    }
  }

  Future<void> saveTelegramAdminRuntimeState(
    Map<String, Object?> state,
  ) async {
    await prefs.setString(telegramAdminRuntimeStateKey, jsonEncode(state));
  }

  Future<void> clearTelegramAdminRuntimeState() async {
    await prefs.remove(telegramAdminRuntimeStateKey);
  }

  Future<List<OfflineIncidentSpoolEntry>> readOfflineIncidentSpoolEntries() async {
    final raw = prefs.getString(offlineIncidentSpoolEntriesKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => OfflineIncidentSpoolEntry.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .where(
            (entry) =>
                entry.entryId.isNotEmpty &&
                entry.incidentReference.isNotEmpty &&
                entry.siteId.isNotEmpty,
          )
          .toList(growable: false);
    } catch (_) {
      await clearOfflineIncidentSpoolEntries();
      return const [];
    }
  }

  Future<void> saveOfflineIncidentSpoolEntries(
    List<OfflineIncidentSpoolEntry> entries,
  ) async {
    await prefs.setString(
      offlineIncidentSpoolEntriesKey,
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }

  Future<void> clearOfflineIncidentSpoolEntries() async {
    await prefs.remove(offlineIncidentSpoolEntriesKey);
  }

  Future<OfflineIncidentSpoolSyncState> readOfflineIncidentSpoolSyncState() async {
    final raw = prefs.getString(offlineIncidentSpoolSyncStateKey);
    if (raw == null || raw.isEmpty) {
      return const OfflineIncidentSpoolSyncState();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const OfflineIncidentSpoolSyncState();
      }
      return OfflineIncidentSpoolSyncState.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value as Object?)),
      );
    } catch (_) {
      await clearOfflineIncidentSpoolSyncState();
      return const OfflineIncidentSpoolSyncState();
    }
  }

  Future<void> saveOfflineIncidentSpoolSyncState(
    OfflineIncidentSpoolSyncState state,
  ) async {
    await prefs.setString(
      offlineIncidentSpoolSyncStateKey,
      jsonEncode(state.toJson()),
    );
  }

  Future<void> clearOfflineIncidentSpoolSyncState() async {
    await prefs.remove(offlineIncidentSpoolSyncStateKey);
  }

  Future<List<GuardAssignment>> readGuardAssignments() async {
    final raw = prefs.getString(guardAssignmentsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => GuardAssignment.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .where(
            (assignment) =>
                assignment.assignmentId.isNotEmpty &&
                assignment.dispatchId.isNotEmpty,
          )
          .toList(growable: false);
    } catch (_) {
      await clearGuardAssignments();
      return const [];
    }
  }

  Future<void> saveGuardAssignments(List<GuardAssignment> assignments) async {
    await prefs.setString(
      guardAssignmentsKey,
      jsonEncode(assignments.map((entry) => entry.toJson()).toList()),
    );
  }

  Future<void> clearGuardAssignments() async {
    await prefs.remove(guardAssignmentsKey);
  }

  Future<List<GuardSyncOperation>> readGuardSyncOperations() async {
    final raw = prefs.getString(guardSyncOperationsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => GuardSyncOperation.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .where((operation) => operation.operationId.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      await clearGuardSyncOperations();
      return const [];
    }
  }

  Future<void> saveGuardSyncOperations(
    List<GuardSyncOperation> operations,
  ) async {
    await prefs.setString(
      guardSyncOperationsKey,
      jsonEncode(operations.map((entry) => entry.toJson()).toList()),
    );
  }

  Future<void> clearGuardSyncOperations() async {
    await prefs.remove(guardSyncOperationsKey);
  }

  Future<String?> readGuardSyncHistoryFilter() async {
    final raw = prefs.getString(guardSyncHistoryFilterKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return raw.trim();
  }

  Future<void> saveGuardSyncHistoryFilter(String filter) async {
    await prefs.setString(guardSyncHistoryFilterKey, filter.trim());
  }

  Future<void> clearGuardSyncHistoryFilter() async {
    await prefs.remove(guardSyncHistoryFilterKey);
  }

  Future<String?> readGuardSyncOperationModeFilter() async {
    final raw = prefs.getString(guardSyncOperationModeFilterKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return raw.trim();
  }

  Future<void> saveGuardSyncOperationModeFilter(String filter) async {
    final normalized = filter.trim();
    if (normalized.isEmpty) {
      await clearGuardSyncOperationModeFilter();
      return;
    }
    await prefs.setString(guardSyncOperationModeFilterKey, normalized);
  }

  Future<void> clearGuardSyncOperationModeFilter() async {
    await prefs.remove(guardSyncOperationModeFilterKey);
  }

  Future<String?> readGuardSyncSelectedFacadeId() async {
    final raw = prefs.getString(guardSyncSelectedFacadeIdKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return raw.trim();
  }

  Future<void> saveGuardSyncSelectedFacadeId(String? facadeId) async {
    final normalized = facadeId?.trim() ?? '';
    if (normalized.isEmpty) {
      await clearGuardSyncSelectedFacadeId();
      return;
    }
    await prefs.setString(guardSyncSelectedFacadeIdKey, normalized);
  }

  Future<void> clearGuardSyncSelectedFacadeId() async {
    await prefs.remove(guardSyncSelectedFacadeIdKey);
  }

  Future<Map<String, String>> readGuardSyncSelectedOperationIds() async {
    final raw = prefs.getString(guardSyncSelectedOperationIdsKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      final mapped = <String, String>{};
      decoded.forEach((key, value) {
        final filter = key.toString().trim();
        final operationId = value?.toString().trim() ?? '';
        if (filter.isEmpty || operationId.isEmpty) {
          return;
        }
        mapped[filter] = operationId;
      });
      return mapped;
    } catch (_) {
      await clearGuardSyncSelectedOperationIds();
      return const {};
    }
  }

  Future<void> saveGuardSyncSelectedOperationIds(
    Map<String, String> selectionByFilter,
  ) async {
    await prefs.setString(
      guardSyncSelectedOperationIdsKey,
      jsonEncode(selectionByFilter),
    );
  }

  Future<void> clearGuardSyncSelectedOperationIds() async {
    await prefs.remove(guardSyncSelectedOperationIdsKey);
  }

  Future<Map<String, Object?>> readGuardOutcomeGovernanceTelemetry() async {
    final raw = prefs.getString(guardOutcomeGovernanceTelemetryKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value as Object?),
      );
    } catch (_) {
      await clearGuardOutcomeGovernanceTelemetry();
      return const {};
    }
  }

  Future<void> saveGuardOutcomeGovernanceTelemetry(
    Map<String, Object?> telemetry,
  ) async {
    await prefs.setString(
      guardOutcomeGovernanceTelemetryKey,
      jsonEncode(telemetry),
    );
  }

  Future<void> clearGuardOutcomeGovernanceTelemetry() async {
    await prefs.remove(guardOutcomeGovernanceTelemetryKey);
  }

  Future<Map<String, Object?>> readGuardCoachingPromptSnoozes() async {
    final raw = prefs.getString(guardCoachingPromptSnoozesKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value as Object?),
      );
    } catch (_) {
      await clearGuardCoachingPromptSnoozes();
      return const {};
    }
  }

  Future<void> saveGuardCoachingPromptSnoozes(
    Map<String, Object?> snoozes,
  ) async {
    await prefs.setString(guardCoachingPromptSnoozesKey, jsonEncode(snoozes));
  }

  Future<void> clearGuardCoachingPromptSnoozes() async {
    await prefs.remove(guardCoachingPromptSnoozesKey);
  }

  Future<Map<String, Object?>> readGuardCoachingTelemetry() async {
    final raw = prefs.getString(guardCoachingTelemetryKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value as Object?),
      );
    } catch (_) {
      await clearGuardCoachingTelemetry();
      return const {};
    }
  }

  Future<void> saveGuardCoachingTelemetry(
    Map<String, Object?> telemetry,
  ) async {
    await prefs.setString(guardCoachingTelemetryKey, jsonEncode(telemetry));
  }

  Future<void> clearGuardCoachingTelemetry() async {
    await prefs.remove(guardCoachingTelemetryKey);
  }

  Future<Map<String, Object?>> readGuardCloseoutPacketAudit() async {
    final raw = prefs.getString(guardCloseoutPacketAuditKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value as Object?),
      );
    } catch (_) {
      await clearGuardCloseoutPacketAudit();
      return const {};
    }
  }

  Future<void> saveGuardCloseoutPacketAudit(Map<String, Object?> audit) async {
    await prefs.setString(guardCloseoutPacketAuditKey, jsonEncode(audit));
  }

  Future<void> clearGuardCloseoutPacketAudit() async {
    await prefs.remove(guardCloseoutPacketAuditKey);
  }

  Future<Map<String, Object?>> readGuardShiftReplayAudit() async {
    final raw = prefs.getString(guardShiftReplayAuditKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value as Object?),
      );
    } catch (_) {
      await clearGuardShiftReplayAudit();
      return const {};
    }
  }

  Future<void> saveGuardShiftReplayAudit(Map<String, Object?> audit) async {
    await prefs.setString(guardShiftReplayAuditKey, jsonEncode(audit));
  }

  Future<void> clearGuardShiftReplayAudit() async {
    await prefs.remove(guardShiftReplayAuditKey);
  }

  Future<Map<String, Object?>> readGuardSyncReportAudit() async {
    final raw = prefs.getString(guardSyncReportAuditKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value as Object?),
      );
    } catch (_) {
      await clearGuardSyncReportAudit();
      return const {};
    }
  }

  Future<void> saveGuardSyncReportAudit(Map<String, Object?> audit) async {
    await prefs.setString(guardSyncReportAuditKey, jsonEncode(audit));
  }

  Future<void> clearGuardSyncReportAudit() async {
    await prefs.remove(guardSyncReportAuditKey);
  }

  Future<Map<String, Object?>> readGuardExportAuditClearMeta() async {
    final raw = prefs.getString(guardExportAuditClearMetaKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value as Object?),
      );
    } catch (_) {
      await clearGuardExportAuditClearMeta();
      return const {};
    }
  }

  Future<void> saveGuardExportAuditClearMeta(Map<String, Object?> meta) async {
    await prefs.setString(guardExportAuditClearMetaKey, jsonEncode(meta));
  }

  Future<void> clearGuardExportAuditClearMeta() async {
    await prefs.remove(guardExportAuditClearMetaKey);
  }

  Future<Map<String, Object?>> readMorningSovereignReport() async {
    final raw = prefs.getString(morningSovereignReportKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value as Object?),
      );
    } catch (_) {
      await clearMorningSovereignReport();
      return const {};
    }
  }

  Future<void> saveMorningSovereignReport(Map<String, Object?> report) async {
    await prefs.setString(morningSovereignReportKey, jsonEncode(report));
  }

  Future<void> clearMorningSovereignReport() async {
    await prefs.remove(morningSovereignReportKey);
  }

  Future<String?> readMorningSovereignReportAutoRunKey() async {
    final raw = prefs.getString(morningSovereignReportAutoRunKey);
    if (raw == null || raw.trim().isEmpty) return null;
    return raw.trim();
  }

  Future<void> saveMorningSovereignReportAutoRunKey(String key) async {
    await prefs.setString(morningSovereignReportAutoRunKey, key.trim());
  }

  Future<void> clearMorningSovereignReportAutoRunKey() async {
    await prefs.remove(morningSovereignReportAutoRunKey);
  }

  Future<DispatchProfileDraft?> readStressProfile() async {
    final raw = prefs.getString(stressProfileKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return DispatchProfileDraft.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value as Object?)),
      );
    } catch (_) {
      await clearStressProfile();
      return null;
    }
  }

  Future<void> saveStressProfile(DispatchProfileDraft draft) async {
    await prefs.setString(stressProfileKey, jsonEncode(draft.toJson()));
  }

  Future<void> clearStressProfile() async {
    await prefs.remove(stressProfileKey);
  }
}
