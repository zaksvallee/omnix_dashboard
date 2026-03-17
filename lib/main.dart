import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'application/client_conversation_repository.dart';
import 'application/client_messaging_bridge_repository.dart';
import 'application/cctv_bridge_service.dart';
import 'application/cctv_evidence_probe_service.dart';
import 'application/cctv_false_positive_policy.dart';
import 'application/dvr_bridge_service.dart';
import 'application/dvr_evidence_probe_service.dart';
import 'application/dvr_http_auth.dart';
import 'application/dvr_scope_config.dart';
import 'application/dispatch_persistence_service.dart';
import 'application/dispatch_snapshot_file_service.dart';
import 'application/dispatch_application_service.dart';
import 'application/guard_media_capture_service.dart';
import 'application/guard_ops_repository.dart';
import 'application/guard_sync_repository.dart';
import 'application/guard_telemetry_bridge_writer.dart';
import 'application/guard_telemetry_ingestion_adapter.dart';
import 'application/guard_telemetry_replay_fixture_service.dart';
import 'application/intake_stress_service.dart';
import 'application/listener_alarm_advisory_pipeline_service.dart';
import 'application/listener_alarm_feed_service.dart';
import 'application/listener_parity_service.dart';
import 'application/listener_alarm_partner_advisory_service.dart';
import 'application/listener_alarm_scope_mapping_service.dart';
import 'application/listener_alarm_scope_registry_repository.dart';
import 'application/listener_serial_ingestor.dart';
import 'application/morning_sovereign_report_service.dart';
import 'application/monitoring_global_posture_service.dart';
import 'application/monitoring_orchestrator_service.dart';
import 'application/monitoring_shift_notification_service.dart';
import 'application/monitoring_scene_review_store.dart';
import 'application/monitoring_watch_action_plan.dart';
import 'application/monitoring_watch_escalation_policy_service.dart';
import 'application/monitoring_identity_policy_service.dart';
import 'application/monitoring_watch_outcome_cue_store.dart';
import 'application/monitoring_watch_recovery_policy.dart';
import 'application/monitoring_watch_recovery_scope_resolver.dart';
import 'application/monitoring_watch_recovery_store.dart';
import 'application/monitoring_watch_runtime_store.dart';
import 'application/monitoring_watch_scene_assessment_service.dart';
import 'application/monitoring_temporary_identity_approval_service.dart';
import 'application/monitoring_watch_vision_review_service.dart';
import 'application/report_shell_state.dart';
import 'application/report_entry_context.dart';
import 'application/report_preview_request.dart';
import 'application/monitoring_watch_resync_plan_service.dart';
import 'application/monitoring_watch_resync_outcome_recorder.dart';
import 'application/monitoring_watch_schedule_sync_plan_service.dart';
import 'application/monitoring_shift_schedule_service.dart';
import 'application/site_identity_registry_repository.dart';
import 'application/monitoring_shift_scope_config.dart';
import 'application/offline_incident_spool_service.dart';
import 'application/ops_integration_profile.dart';
import 'application/radio_bridge_service.dart';
import 'application/runtime_config.dart';
import 'application/site_activity_intelligence_service.dart';
import 'application/site_activity_telegram_formatter.dart';
import 'application/telegram_admin_command_formatter.dart';
import 'application/telegram_ai_assistant_service.dart';
import 'application/telegram_bridge_service.dart';
import 'application/telegram_client_approval_service.dart';
import 'application/telegram_identity_intake_service.dart';
import 'application/telegram_partner_dispatch_service.dart';
import 'application/video_bridge_health_formatter.dart';
import 'application/video_fleet_scope_presentation_service.dart';
import 'application/video_fleet_scope_runtime_state_resolver.dart';
import 'application/video_bridge_runtime.dart';
import 'application/wearable_bridge_service.dart';
import 'domain/authority/operator_context.dart';
import 'domain/events/decision_created.dart';
import 'domain/events/dispatch_event.dart';
import 'domain/events/execution_completed.dart';
import 'domain/events/execution_denied.dart';
import 'domain/events/guard_checked_in.dart';
import 'domain/events/incident_closed.dart';
import 'domain/events/intelligence_received.dart';
import 'domain/events/listener_alarm_advisory_recorded.dart';
import 'domain/events/listener_alarm_feed_cycle_recorded.dart';
import 'domain/events/listener_alarm_parity_cycle_recorded.dart';
import 'domain/events/partner_dispatch_status_declared.dart';
import 'domain/events/patrol_completed.dart';
import 'domain/events/response_arrived.dart';
import 'domain/events/vehicle_visit_review_recorded.dart';
import 'domain/evidence/client_ledger_repository.dart';
import 'domain/evidence/client_ledger_service.dart';
import 'domain/evidence/evidence_provenance.dart';
import 'domain/guard/guard_ops_event.dart';
import 'domain/guard/guard_event_contract.dart';
import 'domain/guard/guard_mobile_ops.dart';
import 'domain/guard/operational_tiers.dart';
import 'domain/guard/outcome_label_governance.dart';
import 'domain/guard/guard_sync_coaching_policy.dart';
import 'domain/guard/guard_sync_selection_scope.dart';
import 'domain/intelligence/intel_ingestion.dart';
import 'domain/intelligence/risk_policy.dart';
import 'domain/store/in_memory_event_store.dart';
import 'engine/execution/execution_engine.dart';
import 'infrastructure/events/in_memory_client_ledger_repository.dart';
import 'infrastructure/events/supabase_client_ledger_repository.dart';
import 'infrastructure/intelligence/configured_live_feed_service.dart';
import 'infrastructure/intelligence/generic_feed_adapter.dart';
import 'infrastructure/intelligence/news_intelligence_service.dart';
import 'ui/app_shell.dart';
import 'ui/ai_queue_page.dart';
import 'ui/admin_page.dart';
import 'ui/client_intelligence_reports_page.dart';
import 'presentation/reports/report_preview_controller.dart';
import 'ui/client_app_page.dart';
import 'ui/clients_page.dart';
import 'ui/dispatch_page.dart';
import 'ui/events_review_page.dart';
import 'ui/governance_page.dart';
import 'ui/guards_page.dart';
import 'ui/guard_mobile_shell_page.dart';
import 'ui/live_operations_page.dart';
import 'ui/sites_command_page.dart';
import 'ui/sovereign_ledger_page.dart';
import 'ui/tactical_page.dart';
import 'ui/video_fleet_scope_health_sections.dart';
import 'ui/video_fleet_scope_health_view.dart';

enum OnyxAppMode { controller, guard, client }

class _OpsIntegrationIngestResult {
  final String source;
  final bool success;
  final bool skipped;
  final String detail;

  const _OpsIntegrationIngestResult({
    required this.source,
    required this.success,
    required this.detail,
    this.skipped = false,
  });

  String get summaryLabel {
    if (skipped) return '$source:skip';
    return '$source:${success ? 'ok' : 'fail'}';
  }
}

class _OpsIntegrationHealth {
  final int okCount;
  final int failCount;
  final int skipCount;
  final DateTime? lastRunAtUtc;
  final String lastDetail;

  const _OpsIntegrationHealth({
    this.okCount = 0,
    this.failCount = 0,
    this.skipCount = 0,
    this.lastRunAtUtc,
    this.lastDetail = '',
  });

  factory _OpsIntegrationHealth.fromJson(Map<String, Object?> json) {
    final ok = _readInt(json['ok_count']) ?? 0;
    final fail = _readInt(json['fail_count']) ?? 0;
    final skip = _readInt(json['skip_count']) ?? 0;
    final detail = _readString(json['last_detail']) ?? '';
    final runRaw = _readString(json['last_run_at_utc']);
    return _OpsIntegrationHealth(
      okCount: ok < 0 ? 0 : ok,
      failCount: fail < 0 ? 0 : fail,
      skipCount: skip < 0 ? 0 : skip,
      lastRunAtUtc: runRaw == null ? null : DateTime.tryParse(runRaw)?.toUtc(),
      lastDetail: detail,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'ok_count': okCount,
      'fail_count': failCount,
      'skip_count': skipCount,
      'last_run_at_utc': lastRunAtUtc?.toIso8601String(),
      'last_detail': lastDetail,
    };
  }

  _OpsIntegrationHealth record(
    _OpsIntegrationIngestResult result,
    DateTime runAtUtc,
  ) {
    return _OpsIntegrationHealth(
      okCount: okCount + (result.success ? 1 : 0),
      failCount: failCount + (!result.success && !result.skipped ? 1 : 0),
      skipCount: skipCount + (result.skipped ? 1 : 0),
      lastRunAtUtc: runAtUtc,
      lastDetail: result.detail.trim(),
    );
  }

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static String? _readString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _RadioPendingRetryState {
  final int attempts;
  final DateTime? nextAttemptAtUtc;
  final String? lastError;

  const _RadioPendingRetryState({
    this.attempts = 0,
    this.nextAttemptAtUtc,
    this.lastError,
  });

  factory _RadioPendingRetryState.fromJson(Map<String, Object?> json) {
    final attemptsRaw = json['attempts'];
    final attempts = switch (attemptsRaw) {
      int value => value,
      num value => value.round(),
      String value => int.tryParse(value.trim()) ?? 0,
      _ => 0,
    };
    final nextRaw = (json['next_attempt_at_utc'] ?? '').toString().trim();
    final nextAttemptAtUtc = nextRaw.isEmpty
        ? null
        : DateTime.tryParse(nextRaw)?.toUtc();
    final lastError = (json['last_error'] ?? '').toString().trim().isEmpty
        ? null
        : (json['last_error'] ?? '').toString().trim();
    return _RadioPendingRetryState(
      attempts: attempts < 0 ? 0 : attempts,
      nextAttemptAtUtc: nextAttemptAtUtc,
      lastError: lastError,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'attempts': attempts,
      'next_attempt_at_utc': nextAttemptAtUtc?.toIso8601String(),
      'last_error': lastError,
    };
  }
}

class _ListenerAlarmAdvisoryDeliveryResult {
  final int targetCount;
  final int deliveredCount;
  final int failedCount;

  const _ListenerAlarmAdvisoryDeliveryResult({
    required this.targetCount,
    required this.deliveredCount,
    required this.failedCount,
  });
}

class _ListenerAlarmCctvReviewResult {
  final ListenerAlarmAdvisoryDisposition disposition;
  final String summary;
  final String recommendation;

  const _ListenerAlarmCctvReviewResult({
    required this.disposition,
    this.summary = '',
    this.recommendation = '',
  });
}

class _TelegramBridgeTarget {
  final String chatId;
  final int? threadId;
  final String label;

  const _TelegramBridgeTarget({
    required this.chatId,
    this.threadId,
    required this.label,
  });
}

class _TelegramAdminCommandParseResult {
  final String command;
  final String arguments;

  const _TelegramAdminCommandParseResult({
    required this.command,
    this.arguments = '',
  });
}

class _TelegramDemoReadinessReport {
  final String clientId;
  final String siteId;
  final String currentChatLabel;
  final List<String> checks;
  final List<String> actions;

  const _TelegramDemoReadinessReport({
    required this.clientId,
    required this.siteId,
    required this.currentChatLabel,
    required this.checks,
    required this.actions,
  });

  bool get ready => checks.every((entry) => !entry.contains('FAIL'));
}

class _TelegramInboundClientTarget {
  final String endpointId;
  final String clientId;
  final String? siteId;
  final String displayLabel;

  const _TelegramInboundClientTarget({
    required this.endpointId,
    required this.clientId,
    this.siteId,
    required this.displayLabel,
  });
}

class _TelegramInboundPartnerTarget {
  final String clientId;
  final String? siteId;
  final String displayLabel;

  const _TelegramInboundPartnerTarget({
    required this.clientId,
    this.siteId,
    required this.displayLabel,
  });
}

class _TelegramPartnerDispatchBinding {
  final String chatId;
  final int? threadId;
  final int telegramMessageId;
  final String dispatchId;
  final String clientId;
  final String siteId;
  final DateTime sentAtUtc;

  const _TelegramPartnerDispatchBinding({
    required this.chatId,
    this.threadId,
    required this.telegramMessageId,
    required this.dispatchId,
    required this.clientId,
    required this.siteId,
    required this.sentAtUtc,
  });

  Map<String, Object?> toJson() {
    return {
      'chat_id': chatId,
      'thread_id': threadId,
      'telegram_message_id': telegramMessageId,
      'dispatch_id': dispatchId,
      'client_id': clientId,
      'site_id': siteId,
      'sent_at_utc': sentAtUtc.toIso8601String(),
    };
  }

  factory _TelegramPartnerDispatchBinding.fromJson(Map<String, Object?> json) {
    final messageRaw = json['telegram_message_id'];
    final messageId = switch (messageRaw) {
      int value => value,
      num value => value.round(),
      String value => int.tryParse(value.trim()) ?? 0,
      _ => 0,
    };
    final threadRaw = json['thread_id'];
    final threadId = switch (threadRaw) {
      int value => value,
      num value => value.round(),
      String value => int.tryParse(value.trim()),
      _ => null,
    };
    final sentRaw = (json['sent_at_utc'] ?? '').toString().trim();
    final sentAt = sentRaw.isEmpty
        ? DateTime.now().toUtc()
        : DateTime.tryParse(sentRaw)?.toUtc() ?? DateTime.now().toUtc();
    return _TelegramPartnerDispatchBinding(
      chatId: (json['chat_id'] ?? '').toString().trim(),
      threadId: threadId,
      telegramMessageId: messageId < 0 ? 0 : messageId,
      dispatchId: (json['dispatch_id'] ?? '').toString().trim(),
      clientId: (json['client_id'] ?? '').toString().trim(),
      siteId: (json['site_id'] ?? '').toString().trim(),
      sentAtUtc: sentAt,
    );
  }
}

class _MonitoringWatchTarget {
  final String clientId;
  final String siteId;
  final String cameraLabel;

  const _MonitoringWatchTarget({
    required this.clientId,
    required this.siteId,
    this.cameraLabel = 'Camera 1',
  });
}

class _TelegramAiPendingDraft {
  final int inboundUpdateId;
  final String chatId;
  final int? messageThreadId;
  final String audience;
  final String clientId;
  final String siteId;
  final String sourceText;
  final String draftText;
  final String providerLabel;
  final DateTime createdAtUtc;

  const _TelegramAiPendingDraft({
    required this.inboundUpdateId,
    required this.chatId,
    this.messageThreadId,
    required this.audience,
    required this.clientId,
    required this.siteId,
    required this.sourceText,
    required this.draftText,
    required this.providerLabel,
    required this.createdAtUtc,
  });

  Map<String, Object?> toJson() {
    return {
      'inbound_update_id': inboundUpdateId,
      'chat_id': chatId,
      'message_thread_id': messageThreadId,
      'audience': audience,
      'client_id': clientId,
      'site_id': siteId,
      'source_text': sourceText,
      'draft_text': draftText,
      'provider_label': providerLabel,
      'created_at_utc': createdAtUtc.toIso8601String(),
    };
  }

  factory _TelegramAiPendingDraft.fromJson(Map<String, Object?> json) {
    final updateRaw = json['inbound_update_id'];
    final updateId = switch (updateRaw) {
      int value => value,
      num value => value.round(),
      String value => int.tryParse(value.trim()) ?? 0,
      _ => 0,
    };
    final threadRaw = json['message_thread_id'];
    final threadId = switch (threadRaw) {
      int value => value,
      num value => value.round(),
      String value => int.tryParse(value.trim()),
      _ => null,
    };
    final createdRaw = (json['created_at_utc'] ?? '').toString().trim();
    return _TelegramAiPendingDraft(
      inboundUpdateId: updateId < 0 ? 0 : updateId,
      chatId: (json['chat_id'] ?? '').toString().trim(),
      messageThreadId: threadId,
      audience: (json['audience'] ?? '').toString().trim().isEmpty
          ? 'client'
          : (json['audience'] ?? '').toString().trim(),
      clientId: (json['client_id'] ?? '').toString().trim(),
      siteId: (json['site_id'] ?? '').toString().trim(),
      sourceText: (json['source_text'] ?? '').toString().trim(),
      draftText: (json['draft_text'] ?? '').toString().trim(),
      providerLabel: (json['provider_label'] ?? '').toString().trim(),
      createdAtUtc: createdRaw.isEmpty
          ? DateTime.now().toUtc()
          : DateTime.tryParse(createdRaw)?.toUtc() ?? DateTime.now().toUtc(),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const allowFontRuntimeFetching = bool.fromEnvironment(
    'ONYX_ALLOW_FONT_RUNTIME_FETCHING',
    defaultValue: false,
  );
  GoogleFonts.config.allowRuntimeFetching = allowFontRuntimeFetching;

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  final usableSupabaseUrl = OnyxRuntimeConfig.usableSupabaseUrl(supabaseUrl);
  final usableSupabaseAnonKey = OnyxRuntimeConfig.usableSecret(supabaseAnonKey);

  var supabaseReady = false;
  if (usableSupabaseUrl.isNotEmpty && usableSupabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: usableSupabaseUrl,
      anonKey: usableSupabaseAnonKey,
    );
    supabaseReady = true;
  } else {
    debugPrint(
      'Supabase not configured. Running with in-memory ledger repository.',
    );
  }

  runApp(OnyxApp(supabaseReady: supabaseReady));
}

class OnyxApp extends StatefulWidget {
  final bool supabaseReady;

  const OnyxApp({super.key, required this.supabaseReady});

  @override
  State<OnyxApp> createState() => _OnyxAppState();
}

class _OnyxAppState extends State<OnyxApp> with WidgetsBindingObserver {
  static const _liveFeeds = ConfiguredLiveFeedService();
  static const _monitoringShiftNotifications =
      MonitoringShiftNotificationService();
  static const _telegramClientApprovalService = TelegramClientApprovalService();
  static const _telegramIdentityIntakeService = TelegramIdentityIntakeService();
  static const _telegramPartnerDispatchService =
      TelegramPartnerDispatchService();
  static const _siteActivityIntelligenceService =
      SiteActivityIntelligenceService();
  static const _siteActivityTelegramFormatter = SiteActivityTelegramFormatter();
  static const _globalPostureService = MonitoringGlobalPostureService();
  static const _orchestratorService = MonitoringOrchestratorService();
  static const _partnerEndpointLabelPrefix = 'PARTNER';
  late final NewsIntelligenceService _newsIntel;
  static const _browserFiles = DispatchSnapshotFileService();
  static const _guardMediaCapture = FilePickerGuardMediaCaptureService();
  static const _guardMediaQualityEvaluator =
      PixelAwareGuardMediaQualityEvaluator();
  static const _guardSyncCoachingPolicy = GuardSyncCoachingPolicy();
  static const _wearableTelemetryAdapterUrl = String.fromEnvironment(
    'ONYX_WEARABLE_TELEMETRY_URL',
  );
  static const _deviceHealthTelemetryAdapterUrl = String.fromEnvironment(
    'ONYX_DEVICE_HEALTH_URL',
  );
  static const _guardTelemetryAdapterBearerToken = String.fromEnvironment(
    'ONYX_GUARD_TELEMETRY_BEARER_TOKEN',
  );
  static const _radioBearerTokenEnv = String.fromEnvironment(
    'ONYX_RADIO_BEARER_TOKEN',
  );
  static const _cctvBearerTokenEnv = String.fromEnvironment(
    'ONYX_CCTV_BEARER_TOKEN',
  );
  static const _dvrBearerTokenEnv = String.fromEnvironment(
    'ONYX_DVR_BEARER_TOKEN',
  );
  static const _dvrAuthModeEnv = String.fromEnvironment('ONYX_DVR_AUTH_MODE');
  static const _dvrUsernameEnv = String.fromEnvironment('ONYX_DVR_USERNAME');
  static const _dvrPasswordEnv = String.fromEnvironment('ONYX_DVR_PASSWORD');
  static const _clientIdEnv = String.fromEnvironment(
    'ONYX_CLIENT_ID',
    defaultValue: 'CLIENT-MS-VALLEE',
  );
  static const _regionIdEnv = String.fromEnvironment(
    'ONYX_REGION_ID',
    defaultValue: 'REGION-GAUTENG',
  );
  static const _siteIdEnv = String.fromEnvironment(
    'ONYX_SITE_ID',
    defaultValue: 'SITE-MS-VALLEE-RESIDENCE',
  );
  static const _operatorIdEnv = String.fromEnvironment(
    'ONYX_OPERATOR_ID',
    defaultValue: 'OPERATOR-01',
  );
  static const _wearableProviderEnv = String.fromEnvironment(
    'ONYX_WEARABLE_PROVIDER',
  );
  static const _wearableEventsUrlEnv = String.fromEnvironment(
    'ONYX_WEARABLE_EVENTS_URL',
  );
  static const _wearableBearerTokenEnv = String.fromEnvironment(
    'ONYX_WEARABLE_BEARER_TOKEN',
  );
  static const _radioProviderEnv = String.fromEnvironment(
    'ONYX_RADIO_PROVIDER',
  );
  static const _radioListenUrlEnv = String.fromEnvironment(
    'ONYX_RADIO_LISTEN_URL',
  );
  static const _radioRespondUrlEnv = String.fromEnvironment(
    'ONYX_RADIO_RESPOND_URL',
  );
  static const _radioChannelEnv = String.fromEnvironment(
    'ONYX_RADIO_CHANNEL',
    defaultValue: 'ops-primary',
  );
  static const _radioAiAutoAllClearEnv = bool.fromEnvironment(
    'ONYX_RADIO_AI_AUTO_ALL_CLEAR',
    defaultValue: false,
  );
  static const _cctvProviderEnv = String.fromEnvironment('ONYX_CCTV_PROVIDER');
  static const _cctvEventsUrlEnv = String.fromEnvironment(
    'ONYX_CCTV_EVENTS_URL',
  );
  static const _dvrProviderEnv = String.fromEnvironment('ONYX_DVR_PROVIDER');
  static const _dvrEventsUrlEnv = String.fromEnvironment('ONYX_DVR_EVENTS_URL');
  static const _dvrEvidenceProbeQueueDepthEnv = int.fromEnvironment(
    'ONYX_DVR_EVIDENCE_QUEUE_DEPTH',
    defaultValue: 12,
  );
  static const _dvrEvidenceProbeStaleSecondsEnv = int.fromEnvironment(
    'ONYX_DVR_STALE_FRAME_SECONDS',
    defaultValue: 1800,
  );
  static const _dvrScopeConfigsJsonEnv = String.fromEnvironment(
    'ONYX_DVR_SCOPE_CONFIGS_JSON',
  );
  static const _monitoringShiftAutoEnabledEnv = bool.fromEnvironment(
    'ONYX_MONITORING_SHIFT_AUTO_ENABLED',
    defaultValue: false,
  );
  static const _monitoringShiftStartHourEnv = int.fromEnvironment(
    'ONYX_MONITORING_SHIFT_START_HOUR',
    defaultValue: 18,
  );
  static const _monitoringShiftStartMinuteEnv = int.fromEnvironment(
    'ONYX_MONITORING_SHIFT_START_MINUTE',
    defaultValue: 0,
  );
  static const _monitoringShiftEndHourEnv = int.fromEnvironment(
    'ONYX_MONITORING_SHIFT_END_HOUR',
    defaultValue: 6,
  );
  static const _monitoringShiftEndMinuteEnv = int.fromEnvironment(
    'ONYX_MONITORING_SHIFT_END_MINUTE',
    defaultValue: 0,
  );
  static const _monitoringShiftScopesJsonEnv = String.fromEnvironment(
    'ONYX_MONITORING_SHIFT_SCOPES_JSON',
  );
  static const _monitoringIdentityRulesJsonEnv = String.fromEnvironment(
    'ONYX_MONITORING_IDENTITY_RULES_JSON',
  );
  static const _cctvLiveMonitoringEnv = bool.fromEnvironment(
    'ONYX_CCTV_LIVE_MONITORING',
    defaultValue: false,
  );
  static const _cctvFacialRecognitionEnv = bool.fromEnvironment(
    'ONYX_CCTV_FR',
    defaultValue: false,
  );
  static const _cctvLicensePlateRecognitionEnv = bool.fromEnvironment(
    'ONYX_CCTV_LPR',
    defaultValue: false,
  );
  static const _cctvEvidenceProbeQueueDepthEnv = int.fromEnvironment(
    'ONYX_CCTV_EVIDENCE_QUEUE_DEPTH',
    defaultValue: 12,
  );
  static const _cctvEvidenceProbeStaleSecondsEnv = int.fromEnvironment(
    'ONYX_CCTV_STALE_FRAME_SECONDS',
    defaultValue: 1800,
  );
  static const _cctvFalsePositiveRulesEnv = String.fromEnvironment(
    'ONYX_CCTV_FALSE_POSITIVE_RULES_JSON',
  );
  static const _guardTelemetryPreferNativeSdk = bool.fromEnvironment(
    'ONYX_GUARD_TELEMETRY_NATIVE_SDK',
    defaultValue: false,
  );
  static const _guardTelemetryNativeProviderId = String.fromEnvironment(
    'ONYX_GUARD_TELEMETRY_NATIVE_PROVIDER',
    defaultValue: 'android_native_sdk_stub',
  );
  static const _guardTelemetryNativeStubMode = bool.fromEnvironment(
    'ONYX_GUARD_TELEMETRY_NATIVE_STUB',
    defaultValue: true,
  );
  static const _guardTelemetryRequiredProviderIdEnv = String.fromEnvironment(
    'ONYX_GUARD_TELEMETRY_REQUIRED_PROVIDER',
    defaultValue: '',
  );
  static const _guardTelemetryEnforceLiveReady = bool.fromEnvironment(
    'ONYX_GUARD_TELEMETRY_ENFORCE_LIVE_READY',
    defaultValue: false,
  );
  static const _guardAppRoleEnv = String.fromEnvironment(
    'ONYX_GUARD_APP_ROLE',
    defaultValue: 'guard',
  );
  static const _appModeEnv = String.fromEnvironment(
    'ONYX_APP_MODE',
    defaultValue: 'controller',
  );
  static const _clientAppLocaleEnv = String.fromEnvironment(
    'ONYX_CLIENT_APP_LOCALE',
    defaultValue: 'en',
  );
  static const _clientPushDeliveryProviderEnv = String.fromEnvironment(
    'ONYX_CLIENT_PUSH_DELIVERY_PROVIDER',
    defaultValue: 'in_app',
  );
  static const _telegramBridgeEnabledEnv = bool.fromEnvironment(
    'ONYX_TELEGRAM_BRIDGE_ENABLED',
    defaultValue: false,
  );
  static const _telegramBotTokenEnv = String.fromEnvironment(
    'ONYX_TELEGRAM_BOT_TOKEN',
  );
  static const _telegramChatIdEnv = String.fromEnvironment(
    'ONYX_TELEGRAM_CHAT_ID',
  );
  static const _telegramMessageThreadIdEnv = String.fromEnvironment(
    'ONYX_TELEGRAM_MESSAGE_THREAD_ID',
  );
  static const _telegramPartnerChatIdEnv = String.fromEnvironment(
    'ONYX_TELEGRAM_PARTNER_CHAT_ID',
  );
  static const _telegramPartnerThreadIdEnv = String.fromEnvironment(
    'ONYX_TELEGRAM_PARTNER_THREAD_ID',
  );
  static const _telegramPartnerLabelEnv = String.fromEnvironment(
    'ONYX_TELEGRAM_PARTNER_LABEL',
    defaultValue: 'PARTNER • Response',
  );
  static const _telegramPartnerClientIdEnv = String.fromEnvironment(
    'ONYX_TELEGRAM_PARTNER_CLIENT_ID',
  );
  static const _telegramPartnerSiteIdEnv = String.fromEnvironment(
    'ONYX_TELEGRAM_PARTNER_SITE_ID',
  );
  static const _telegramAdminControlEnabledEnv = bool.fromEnvironment(
    'ONYX_TELEGRAM_ADMIN_CONTROL_ENABLED',
    defaultValue: false,
  );
  static const _telegramAdminChatIdEnv = String.fromEnvironment(
    'ONYX_TELEGRAM_ADMIN_CHAT_ID',
  );
  static const _telegramAdminThreadIdEnv = String.fromEnvironment(
    'ONYX_TELEGRAM_ADMIN_THREAD_ID',
  );
  static const _telegramAdminPollIntervalSecondsEnv = int.fromEnvironment(
    'ONYX_TELEGRAM_ADMIN_POLL_INTERVAL_SECONDS',
    defaultValue: 8,
  );
  static const _telegramAdminCriticalPushEnabledEnv = bool.fromEnvironment(
    'ONYX_TELEGRAM_ADMIN_CRITICAL_PUSH_ENABLED',
    defaultValue: true,
  );
  static const _telegramAdminCriticalReminderSecondsEnv = int.fromEnvironment(
    'ONYX_TELEGRAM_ADMIN_CRITICAL_REMINDER_SECONDS',
    defaultValue: 300,
  );
  static const _telegramAdminAllowedUserIdsEnv = String.fromEnvironment(
    'ONYX_TELEGRAM_ADMIN_ALLOWED_USER_IDS',
  );
  static const _telegramAdminExecutionEnabledEnv = bool.fromEnvironment(
    'ONYX_TELEGRAM_ADMIN_EXECUTION_ENABLED',
    defaultValue: true,
  );
  static const _telegramAiAssistantEnabledEnv = bool.fromEnvironment(
    'ONYX_TELEGRAM_AI_ASSISTANT_ENABLED',
    defaultValue: false,
  );
  static const _telegramAiApprovalRequiredEnv = bool.fromEnvironment(
    'ONYX_TELEGRAM_AI_APPROVAL_REQUIRED',
    defaultValue: false,
  );
  static const _telegramAiOpenAiApiKeyEnv = String.fromEnvironment(
    'ONYX_TELEGRAM_AI_OPENAI_API_KEY',
  );
  static const _telegramAiModelEnv = String.fromEnvironment(
    'ONYX_TELEGRAM_AI_OPENAI_MODEL',
    defaultValue: 'gpt-4.1-mini',
  );
  static const _telegramAiEndpointEnv = String.fromEnvironment(
    'ONYX_TELEGRAM_AI_OPENAI_ENDPOINT',
  );
  static const _monitoringVisionReviewEnabledEnv = bool.fromEnvironment(
    'ONYX_MONITORING_VISION_REVIEW_ENABLED',
    defaultValue: false,
  );
  static const _monitoringVisionOpenAiApiKeyEnv = String.fromEnvironment(
    'ONYX_MONITORING_VISION_OPENAI_API_KEY',
  );
  static const _monitoringVisionModelEnv = String.fromEnvironment(
    'ONYX_MONITORING_VISION_OPENAI_MODEL',
    defaultValue: 'gpt-4.1-mini',
  );
  static const _monitoringVisionEndpointEnv = String.fromEnvironment(
    'ONYX_MONITORING_VISION_OPENAI_ENDPOINT',
  );
  late final OnyxAppMode _appMode = _resolveAppMode();
  late final List<MonitoringShiftScopeConfig> _configuredMonitoringShiftScopes =
      _resolveMonitoringShiftScopes();
  late final ClientPushDeliveryProvider _clientPushDeliveryProvider =
      ClientPushDeliveryProviderParser.fromCode(_clientPushDeliveryProviderEnv);
  late final List<DvrScopeConfig> _configuredDvrScopes = _resolveDvrScopes();
  final GuardTelemetryIngestionAdapter _guardTelemetryAdapter =
      createGuardTelemetryIngestionAdapter(
        wearableHeartbeatUrl: _wearableTelemetryAdapterUrl,
        deviceHealthUrl: _deviceHealthTelemetryAdapterUrl,
        bearerToken: _guardTelemetryAdapterBearerToken,
        preferNativeSdk: _guardTelemetryPreferNativeSdk,
        nativeSdkConfig: GuardTelemetryNativeSdkConfig(
          providerId: _guardTelemetryNativeProviderId,
          stubMode: _guardTelemetryNativeStubMode,
        ),
      );
  final GuardTelemetryBridgeWriter _guardTelemetryBridgeWriter =
      createGuardTelemetryBridgeWriter(
        providerId: _guardTelemetryNativeProviderId,
        enabled: true,
      );
  final http.Client _radioBridgeHttpClient = http.Client();
  final http.Client _cctvBridgeHttpClient = http.Client();
  final http.Client _wearableBridgeHttpClient = http.Client();
  final http.Client _listenerAlarmFeedHttpClient = http.Client();
  final http.Client _listenerAlarmLegacyFeedHttpClient = http.Client();
  final http.Client _telegramBridgeHttpClient = http.Client();
  final http.Client _telegramAiHttpClient = http.Client();
  final http.Client _monitoringVisionHttpClient = http.Client();
  late final TelegramBridgeService _telegramBridge = _buildTelegramBridge();
  late final TelegramAiAssistantService _telegramAiAssistant =
      _buildTelegramAiAssistant();
  late final MonitoringWatchVisionReviewService _monitoringWatchVisionReview =
      _buildMonitoringWatchVisionReview();
  late final OnyxOpsIntegrationProfile _opsIntegrationProfile =
      OnyxOpsIntegrationProfile.fromEnvironment(
        radioProvider: _radioProviderEnv,
        radioListenUrl: _radioListenUrlEnv,
        radioRespondUrl: _radioRespondUrlEnv,
        radioChannel: _radioChannelEnv,
        radioAiAutoAllClearEnabled: _radioAiAutoAllClearEnv,
        cctvProvider: _cctvProviderEnv,
        cctvEventsUrl: _cctvEventsUrlEnv,
        cctvLiveMonitoringEnabled: _cctvLiveMonitoringEnv,
        cctvFacialRecognitionEnabled: _cctvFacialRecognitionEnv,
        cctvLicensePlateRecognitionEnabled: _cctvLicensePlateRecognitionEnv,
        dvrProvider: _dvrProviderEnv,
        dvrEventsUrl: _dvrEventsUrlEnv,
      );
  late final RadioBridgeService _radioBridgeService = createRadioBridgeService(
    provider: _opsIntegrationProfile.radio.provider,
    listenUri: _opsIntegrationProfile.radio.listenUrl,
    respondUri: _opsIntegrationProfile.radio.respondUrl,
    bearerToken: _radioBearerTokenEnv,
    client: _radioBridgeHttpClient,
  );
  late final VideoBridgeService _videoBridgeService =
      _buildVideoBridgeService();
  late final CctvFalsePositivePolicy _cctvFalsePositivePolicy =
      CctvFalsePositivePolicy.fromJsonString(_cctvFalsePositiveRulesEnv);
  late final VideoEvidenceProbeService _videoEvidenceProbeService =
      _buildVideoEvidenceProbeService();
  late final Uri? _wearableBridgeUri = Uri.tryParse(
    _wearableEventsUrlEnv.trim(),
  );
  late final WearableBridgeService _wearableBridgeService =
      createWearableBridgeService(
        provider: _wearableProviderEnv,
        eventsUri: _wearableBridgeUri,
        bearerToken: _wearableBearerTokenEnv,
        client: _wearableBridgeHttpClient,
      );
  static const _liveFeedPollUrl = String.fromEnvironment('ONYX_LIVE_FEED_URL');
  static const _liveFeedPollBearerToken = String.fromEnvironment(
    'ONYX_LIVE_FEED_BEARER_TOKEN',
  );
  static const _liveFeedPollHeadersJson = String.fromEnvironment(
    'ONYX_LIVE_FEED_HEADERS_JSON',
  );
  static const _listenerAlarmFeedUrl = String.fromEnvironment(
    'ONYX_LISTENER_ALARM_FEED_URL',
  );
  static const _listenerAlarmFeedBearerToken = String.fromEnvironment(
    'ONYX_LISTENER_ALARM_FEED_BEARER_TOKEN',
  );
  static const _listenerAlarmFeedHeadersJson = String.fromEnvironment(
    'ONYX_LISTENER_ALARM_FEED_HEADERS_JSON',
  );
  static const _listenerAlarmLegacyFeedUrl = String.fromEnvironment(
    'ONYX_LISTENER_ALARM_LEGACY_FEED_URL',
  );
  static const _listenerAlarmLegacyFeedBearerToken = String.fromEnvironment(
    'ONYX_LISTENER_ALARM_LEGACY_FEED_BEARER_TOKEN',
  );
  static const _listenerAlarmLegacyFeedHeadersJson = String.fromEnvironment(
    'ONYX_LISTENER_ALARM_LEGACY_FEED_HEADERS_JSON',
  );
  static const _guardOutcomeGovernanceJson = String.fromEnvironment(
    'ONYX_GUARD_OUTCOME_GOVERNANCE_JSON',
  );
  static const _telemetryReplayFixtures = GuardTelemetryReplayFixtureService();
  static const _guardFailureAlertThresholdEnv = int.fromEnvironment(
    'ONYX_GUARD_FAILURE_ALERT_THRESHOLD',
    defaultValue: 1,
  );
  static const _guardQueuePressureAlertThresholdEnv = int.fromEnvironment(
    'ONYX_GUARD_QUEUE_ALERT_THRESHOLD',
    defaultValue: 25,
  );
  static const _guardStaleSyncAlertMinutesEnv = int.fromEnvironment(
    'ONYX_GUARD_STALE_SYNC_ALERT_MINUTES',
    defaultValue: 10,
  );
  static const _guardFailedOpsWarnThresholdEnv = int.fromEnvironment(
    'ONYX_GUARD_FAILED_OPS_WARN_THRESHOLD',
    defaultValue: 1,
  );
  static const _guardFailedOpsCriticalThresholdEnv = int.fromEnvironment(
    'ONYX_GUARD_FAILED_OPS_CRITICAL_THRESHOLD',
    defaultValue: 5,
  );
  static const _guardOldestFailedWarnMinutesEnv = int.fromEnvironment(
    'ONYX_GUARD_OLDEST_FAILED_WARN_MINUTES',
    defaultValue: 10,
  );
  static const _guardOldestFailedCriticalMinutesEnv = int.fromEnvironment(
    'ONYX_GUARD_OLDEST_FAILED_CRITICAL_MINUTES',
    defaultValue: 30,
  );
  static const _guardFailedRetryWarnThresholdEnv = int.fromEnvironment(
    'ONYX_GUARD_FAILED_RETRY_WARN_THRESHOLD',
    defaultValue: 8,
  );
  static const _guardFailedRetryCriticalThresholdEnv = int.fromEnvironment(
    'ONYX_GUARD_FAILED_RETRY_CRITICAL_THRESHOLD',
    defaultValue: 20,
  );
  static const _maxConsecutiveLivePollFailures = 3;
  static const _guardTelemetryPayloadAlertThrottleSeconds = 300;
  static const _guardOpsBaseSyncIntervalSeconds = 45;
  static const _offlineIncidentSpoolBaseSyncIntervalSeconds = 60;
  static const _guardResumeSyncEventThrottleSecondsEnv = int.fromEnvironment(
    'ONYX_GUARD_RESUME_SYNC_EVENT_THROTTLE_SECONDS',
    defaultValue: 20,
  );
  static const _guardSyncSelectionPruneReadLimit = 500;
  static const _liveFeedPollIntervalSeconds = int.fromEnvironment(
    'ONYX_LIVE_FEED_POLL_INTERVAL_SECONDS',
    defaultValue: 30,
  );
  static const _opsIntegrationPollIntervalSeconds = int.fromEnvironment(
    'ONYX_OPS_INTEGRATION_POLL_INTERVAL_SECONDS',
    defaultValue: 45,
  );
  static const _telegramAdminMaxMessageChars = 3500;
  late final ClientAppLocale _clientAppLocale = ClientAppLocaleParser.fromCode(
    _clientAppLocaleEnv,
  );
  final store = InMemoryEventStore();
  late DispatchApplicationService service;
  late final ClientLedgerRepository _clientLedgerRepository;
  late IntakeStressService stressService;
  late final Future<DispatchPersistenceService> _persistenceServiceFuture;
  late final Future<ClientConversationRepository>
  _clientConversationRepositoryFuture;
  late final Future<GuardOpsRepository> _guardOpsRepositoryFuture;
  late final Future<GuardSyncRepository> _guardSyncRepositoryFuture;
  late final Future<GuardMobileOpsService> _guardMobileOpsServiceFuture;
  late final Future<OfflineIncidentSpoolService>
  _offlineIncidentSpoolServiceFuture;

  OnyxRoute _route = OnyxRoute.dashboard;
  String _eventsSourceFilter = '';
  String _eventsProviderFilter = '';
  String _eventsSelectedEventId = '';
  List<String> _eventsScopedEventIds = const <String>[];
  ReportShellState _reportShellState = const ReportShellState();
  String _operationsFocusIncidentReference = '';
  VideoFleetWatchActionDrilldown? _tacticalWatchActionDrilldown;
  VideoFleetWatchActionDrilldown? _dispatchWatchActionDrilldown;
  String? _dispatchSelectedDispatchId;
  AdministrationPageTab _adminPageTab = AdministrationPageTab.guards;
  VideoFleetWatchActionDrilldown? _adminWatchActionDrilldown;
  MonitoringIdentityPolicyAuditSource? _adminIdentityPolicyAuditSourceFilter;
  bool _adminIdentityPolicyAuditExpanded = true;

  late final String _selectedClient = _resolvedScopeValue(
    _clientIdEnv,
    fallback: 'CLIENT-MS-VALLEE',
  );
  late final String _selectedRegion = _resolvedScopeValue(
    _regionIdEnv,
    fallback: 'REGION-GAUTENG',
  );
  late final String _selectedSite = _resolvedScopeValue(
    _siteIdEnv,
    fallback: 'SITE-MS-VALLEE-RESIDENCE',
  );
  late final String _defaultOperatorId = _resolvedScopeValue(
    _operatorIdEnv,
    fallback: 'OPERATOR-01',
  );
  late String _operatorId = _defaultOperatorId;

  String? _lastIntakeStatus;
  String? _lastStressStatus;
  bool _stressRunning = false;
  bool _stressCancelRequested = false;
  bool _livePolling = false;
  bool _livePollRequestInFlight = false;
  int _livePollFailures = 0;
  int _livePollDelaySeconds = 0;
  int? _lastLivePollLatencyMs;
  DateTime? _lastLivePollSuccessAtUtc;
  DateTime? _lastLivePollFailureAtUtc;
  String? _lastLivePollError;
  int _runCounter = 0;
  IntakeStressProfile? _lastStressProfile;
  IntakeStressProfile _currentStressProfile = IntakeStressPreset.medium.profile;
  String _currentScenarioLabel = '';
  List<String> _currentScenarioTags = const [];
  String _currentRunNote = '';
  List<DispatchBenchmarkFilterPreset> _savedFilterPresets = const [];
  String _currentIntelligenceSourceFilter = 'all';
  String _currentIntelligenceActionFilter = 'all';
  List<String> _pinnedWatchIntelligenceIds = const [];
  List<String> _dismissedIntelligenceIds = const [];
  bool _showPinnedWatchIntelligenceOnly = false;
  bool _showDismissedIntelligenceOnly = false;
  String _selectedIntelligenceId = '';
  String _clientAppSelectedRoom = 'Residents';
  bool _clientAppShowAllRoomItems = false;
  ClientAppViewerRole _clientAppViewerRole = ClientAppViewerRole.client;
  Map<String, String> _clientAppSelectedRoomByRole = {
    ClientAppViewerRole.client.name: 'Residents',
  };
  Map<String, bool> _clientAppShowAllRoomItemsByRole = {
    ClientAppViewerRole.client.name: false,
  };
  Map<String, String> _clientAppSelectedIncidentReferenceByRole = {};
  Map<String, String> _clientAppExpandedIncidentReferenceByRole = {};
  Map<String, bool> _clientAppHasTouchedIncidentExpansionByRole = {
    ClientAppViewerRole.client.name: false,
  };
  Map<String, String> _clientAppFocusedIncidentReferenceByRole = {};
  List<ClientAppMessage> _clientAppMessages = const [];
  List<ClientAppAcknowledgement> _clientAppAcknowledgements = const [];
  List<ClientAppPushDeliveryItem> _clientAppPushQueue = const [];
  String _clientAppPushSyncStatusLabel = 'idle';
  DateTime? _clientAppPushLastSyncedAtUtc;
  String? _clientAppPushSyncFailureReason;
  int _clientAppPushSyncRetryCount = 0;
  List<ClientPushSyncAttempt> _clientAppPushSyncHistory = const [];
  bool _telegramBridgeFallbackToInApp = false;
  String _telegramBridgeHealthLabel = 'disabled';
  String? _telegramBridgeHealthDetail;
  DateTime? _telegramBridgeHealthUpdatedAtUtc;
  String? _monitoringWatchAuditSummary;
  List<String> _monitoringWatchAuditHistory = const [];
  int? _telegramAdminLastUpdateId;
  bool _telegramAdminPollInFlight = false;
  bool _telegramAdminOffsetBootstrapped = false;
  DateTime? _telegramAdminOffsetBootstrappedAtUtc;
  DateTime? _telegramAdminLastCommandAtUtc;
  String? _telegramAdminLastCommandSummary;
  List<String> _telegramAdminCommandAudit = const [];
  int? _telegramAdminPollIntervalSecondsOverride;
  int? _telegramAdminCriticalReminderSecondsOverride;
  bool? _telegramAdminExecutionEnabledOverride;
  List<int>? _telegramAdminAllowedUserIdsOverride;
  String? _telegramAdminTargetClientIdOverride;
  String? _telegramAdminTargetSiteIdOverride;
  String _telegramAdminCriticalAlertFingerprint = '';
  DateTime? _telegramAdminLastCriticalAlertAtUtc;
  String? _telegramAdminLastCriticalAlertSummary;
  DateTime? _telegramAdminLastCriticalPushAttemptAtUtc;
  bool _telegramAdminCriticalPushInFlight = false;
  DateTime? _telegramAdminCriticalSnoozedUntilUtc;
  String _telegramAdminCriticalAckFingerprint = '';
  DateTime? _telegramAdminCriticalAckAtUtc;
  bool? _telegramAiAssistantEnabledOverride;
  bool? _telegramAiApprovalRequiredOverride;
  List<_TelegramAiPendingDraft> _telegramAiPendingDrafts = const [];
  List<_TelegramPartnerDispatchBinding> _telegramPartnerDispatchBindings =
      const [];
  final ListenerAlarmScopeRegistryRepository _listenerAlarmScopeRegistry =
      ListenerAlarmScopeRegistryRepository();
  late final ListenerAlarmAdvisoryPipelineService
  _listenerAlarmAdvisoryPipeline = ListenerAlarmAdvisoryPipelineService(
    registryRepository: _listenerAlarmScopeRegistry,
  );
  final ListenerSerialIngestor _listenerAlarmSerialIngestor =
      const ListenerSerialIngestor();
  late final ListenerAlarmFeedService _listenerAlarmFeedService =
      ListenerAlarmFeedService(
        feedUri: _listenerAlarmFeedUri,
        headers: _listenerAlarmFeedHeaders,
        client: _listenerAlarmFeedHttpClient,
        serialIngestor: _listenerAlarmSerialIngestor,
      );
  late final ListenerAlarmFeedService _listenerAlarmLegacyFeedService =
      ListenerAlarmFeedService(
        feedUri: _listenerAlarmLegacyFeedUri,
        headers: _listenerAlarmLegacyFeedHeaders,
        client: _listenerAlarmLegacyFeedHttpClient,
        serialIngestor: _listenerAlarmSerialIngestor,
      );
  static const ListenerParityService _listenerParityService =
      ListenerParityService();
  DateTime? _telegramAiLastHandledAtUtc;
  String? _telegramAiLastHandledSummary;
  String _clientAppBackendProbeStatusLabel = 'idle';
  DateTime? _clientAppBackendProbeLastRunAtUtc;
  String? _clientAppBackendProbeFailureReason;
  List<ClientBackendProbeAttempt> _clientAppBackendProbeHistory = const [];
  List<NewsSourceDiagnostic> _newsSourceDiagnostics = const [];
  String _radioIntentPhrasesJsonOverride = '';
  String _monitoringIdentityRulesJsonOverride = '';
  List<MonitoringIdentityPolicyAuditRecord>
  _monitoringIdentityRuleAuditHistory =
      const <MonitoringIdentityPolicyAuditRecord>[];
  String _demoRouteCueOverridesJson = '';
  Map<String, String> _demoRouteCueOverrides = const {};
  List<String> _livePollingHistory = const [];
  List<GuardSyncOperation> _guardQueuedOperations = const [];
  GuardSyncHistoryFilter _guardSyncHistoryFilter =
      GuardSyncHistoryFilter.queued;
  GuardSyncOperationModeFilter _guardSyncOperationModeFilter =
      GuardSyncOperationModeFilter.all;
  List<String> _guardSyncAvailableFacadeIds = const [];
  String? _guardSyncSelectedFacadeId;
  int _guardOpsPendingEvents = 0;
  int _guardOpsPendingMedia = 0;
  int _guardOpsFailedEvents = 0;
  int _guardOpsFailedMedia = 0;
  String _offlineIncidentSpoolStatusLabel = 'idle';
  int _offlineIncidentSpoolPendingCount = 0;
  int _offlineIncidentSpoolRetryCount = 0;
  DateTime? _offlineIncidentSpoolLastQueuedAtUtc;
  DateTime? _offlineIncidentSpoolLastSyncedAtUtc;
  String? _offlineIncidentSpoolFailureReason;
  List<String> _offlineIncidentSpoolHistory = const [];
  Map<String, Object?> _offlineIncidentSpoolReplayAudit = const {};
  bool _offlineIncidentSpoolSyncInFlight = false;
  int _offlineIncidentSpoolSyncFailures = 0;
  int _guardOutcomePolicyDeniedCount = 0;
  String? _guardOutcomePolicyDeniedLastReason;
  List<DateTime> _guardOutcomePolicyDeniedHistoryUtc = const [];
  List<GuardOpsEvent> _guardOpsRecentEvents = const [];
  List<GuardOpsMediaUpload> _guardOpsRecentMedia = const [];
  bool _guardOpsSyncInFlight = false;
  int _guardOpsSyncFailures = 0;
  String? _guardOpsLastSyncLabel;
  DateTime? _guardOpsLastSuccessfulSyncAtUtc;
  String? _guardOpsLastFailureReason;
  String _guardOpsActiveShiftId = '';
  int _guardOpsActiveShiftSequenceWatermark = 0;
  Map<String, Object?> _guardLastCloseoutPacketAudit = const {};
  Map<String, Object?> _guardLastShiftReplayAudit = const {};
  Map<String, Object?> _guardLastSyncReportAudit = const {};
  Map<String, Object?> _guardExportAuditClearMeta = const {};
  SovereignReport? _morningSovereignReport;
  List<SovereignReport> _morningSovereignReportHistory =
      const <SovereignReport>[];
  String? _morningSovereignReportAutoRunKey;
  GovernanceSceneActionFocus? _governanceSceneActionFocus;
  String _governancePartnerScopeClientId = '';
  String _governancePartnerScopeSiteId = '';
  String _governancePartnerScopePartnerLabel = '';
  String _reportsScopeClientId = '';
  String _reportsScopeSiteId = '';
  String _reportsScopePartnerLabel = '';
  Map<String, DateTime> _guardCoachingPromptSnoozedUntilByRule = const {};
  final Set<String> _guardCoachingSnoozeExpiryEventInFlightRules = {};
  int _guardCoachingAckCount = 0;
  int _guardCoachingSnoozeCount = 0;
  int _guardCoachingSnoozeExpiryCount = 0;
  List<String> _guardCoachingRecentHistory = const [];
  int _guardSyncQueueDepth = 0;
  bool _guardSyncUsingBackend = false;
  bool _guardSyncLandingPending = false;
  bool _guardSyncHistoryFilterHydrated = false;
  bool _guardSyncOperationModeFilterHydrated = false;
  bool _guardSyncSelectedFacadeIdHydrated = false;
  bool _guardSyncSelectedOpHydrated = false;
  Map<String, String> _guardSyncSelectedOperationIdByFilter = const {};
  GuardTelemetryAdapterReadiness _guardTelemetryReadiness =
      GuardTelemetryAdapterReadiness.degraded;
  String _guardTelemetryProviderStatusLabel =
      'Telemetry provider status pending.';
  String? _guardTelemetryFacadeId;
  String? _guardTelemetryActiveProviderId;
  bool? _guardTelemetryFacadeLiveMode;
  String? _guardTelemetryFacadeToggleSource;
  String? _guardTelemetryFacadeRuntimeMode;
  String? _guardTelemetryFacadeHeartbeatSource;
  String? _guardTelemetryFacadeHeartbeatAction;
  String? _guardTelemetryVendorConnectorId;
  String? _guardTelemetryVendorConnectorSource;
  String? _guardTelemetryVendorConnectorErrorMessage;
  bool? _guardTelemetryVendorConnectorFallbackActive;
  bool? _guardTelemetryFacadeSourceActive;
  int? _guardTelemetryFacadeCallbackCount;
  DateTime? _guardTelemetryFacadeLastCallbackAtUtc;
  String? _guardTelemetryFacadeLastCallbackMessage;
  int? _guardTelemetryFacadeCallbackErrorCount;
  DateTime? _guardTelemetryFacadeLastCallbackErrorAtUtc;
  String? _guardTelemetryFacadeLastCallbackErrorMessage;
  bool _guardTelemetryVerificationChecklistPassed = false;
  String _guardTelemetryPayloadHealthLastVerdict = 'healthy';
  DateTime? _guardTelemetryPayloadHealthLastAlertAtUtc;
  IntakeTelemetry _intakeTelemetry = IntakeTelemetry.zero;
  Timer? _livePollTimer;
  Timer? _opsIntegrationPollTimer;
  Timer? _guardOpsSyncTimer;
  Timer? _offlineIncidentSpoolSyncTimer;
  Timer? _telegramAdminPollTimer;
  Timer? _monitoringWatchScheduleTimer;
  Timer? _demoAutopilotRouteTimer;
  Timer? _demoAutopilotCountdownTimer;
  Timer? _telegramDemoScriptTimer;
  bool _telegramDemoScriptRunning = false;
  int _telegramDemoScriptStep = 0;
  int _telegramDemoScriptTotal = 0;
  int _telegramDemoScriptIntervalSeconds = 20;
  String _telegramDemoScriptScopeLabel = '';
  String _telegramDemoScriptRunId = '';
  DateTime? _telegramDemoScriptStartedAtUtc;
  DateTime? _telegramDemoScriptNextStepAtUtc;
  List<ClientAppPushDeliveryItem> _telegramDemoScriptPendingItems = const [];
  final Map<String, MonitoringWatchRuntimeState> _monitoringWatchByScope = {};
  final Map<String, MonitoringWatchOutcomeCueState>
  _monitoringWatchOutcomeByScope = {};
  final Map<String, MonitoringWatchRecoveryState>
  _monitoringWatchRecoveryByScope = {};
  final Map<String, MonitoringSceneReviewRecord>
  _monitoringSceneReviewByIntelligenceId = {};
  bool _demoAutopilotRunning = false;
  bool _demoAutopilotPaused = false;
  int _demoAutopilotCurrentStep = 0;
  int _demoAutopilotTotalSteps = 0;
  String _demoAutopilotFlowLabel = '';
  int _demoAutopilotNextHopSeconds = 0;
  String _demoAutopilotNextRouteLabel = '';
  List<OnyxRoute> _demoAutopilotSequence = const [];
  int _demoAutopilotStepIntervalSeconds = 0;
  String _demoAutopilotIncidentReference = '';
  String _demoAutopilotCompletionLabel = '';
  List<RadioAutomatedResponse> _pendingRadioAutomatedResponses = const [];
  Map<String, _RadioPendingRetryState> _pendingRadioRetryByKey = const {};
  String _radioQueueLastManualActionDetail =
      'No manual radio queue action in current session.';
  String _radioQueueLastFailureSnapshot = '';
  String _radioQueueFailureAuditDetail =
      'No failure snapshot clear recorded in current session.';
  String _radioQueueLastStateChangeDetail =
      'No radio queue state change recorded in current session.';
  _OpsIntegrationHealth _radioOpsHealth = const _OpsIntegrationHealth();
  _OpsIntegrationHealth _cctvOpsHealth = const _OpsIntegrationHealth();
  _OpsIntegrationHealth _wearableOpsHealth = const _OpsIntegrationHealth();
  _OpsIntegrationHealth _listenerAlarmOpsHealth = const _OpsIntegrationHealth();
  _OpsIntegrationHealth _newsOpsHealth = const _OpsIntegrationHealth();
  VideoEvidenceProbeSnapshot _cctvEvidenceHealth =
      const VideoEvidenceProbeSnapshot();
  bool _opsIntegrationPollInFlight = false;
  DateTime? _lastGuardResumeSyncEventQueuedAtUtc;
  late final OutcomeLabelGovernancePolicy _outcomeGovernancePolicy;
  static const MonitoringWatchRecoveryPolicy _watchRecoveryPolicy =
      MonitoringWatchRecoveryPolicy();
  late MonitoringIdentityPolicyService _watchIdentityPolicyService;
  MonitoringTemporaryIdentityApprovalService
  _watchTemporaryIdentityApprovalService =
      const MonitoringTemporaryIdentityApprovalService();
  static const MonitoringWatchOutcomeCueStore _watchOutcomeCueStore =
      MonitoringWatchOutcomeCueStore();
  late MonitoringWatchSceneAssessmentService _watchSceneAssessmentService;
  static const MonitoringWatchEscalationPolicyService
  _watchEscalationPolicyService = MonitoringWatchEscalationPolicyService();
  static const MonitoringWatchRecoveryStore _watchRecoveryStore =
      MonitoringWatchRecoveryStore(policy: _watchRecoveryPolicy);
  static const MonitoringWatchRuntimeStore _watchRuntimeStore =
      MonitoringWatchRuntimeStore();
  static const MonitoringWatchRecoveryScopeResolver
  _watchRecoveryScopeResolver = MonitoringWatchRecoveryScopeResolver();
  static const MonitoringSceneReviewStore _monitoringSceneReviewStore =
      MonitoringSceneReviewStore();
  static const MonitoringWatchResyncOutcomeRecorder
  _watchResyncOutcomeRecorder = MonitoringWatchResyncOutcomeRecorder(
    outcomeCueStore: _watchOutcomeCueStore,
    recoveryStore: _watchRecoveryStore,
  );
  static const MonitoringWatchResyncPlanService _watchResyncPlanService =
      MonitoringWatchResyncPlanService();
  static const MonitoringWatchScheduleSyncPlanService
  _watchScheduleSyncPlanService = MonitoringWatchScheduleSyncPlanService();
  static const VideoFleetScopeRuntimeStateResolver _fleetRuntimeStateResolver =
      VideoFleetScopeRuntimeStateResolver(
        outcomeCueStore: _watchOutcomeCueStore,
        recoveryStore: _watchRecoveryStore,
      );
  static const VideoFleetScopePresentationService _fleetPresentationService =
      VideoFleetScopePresentationService(
        runtimeStateResolver: _fleetRuntimeStateResolver,
      );

  int get _guardResumeSyncEventThrottleSeconds {
    return _positiveThreshold(
      _guardResumeSyncEventThrottleSecondsEnv,
      fallback: 20,
    );
  }

  int _positiveThreshold(int raw, {required int fallback}) {
    return raw > 0 ? raw : fallback;
  }

  static String _resolvedScopeValue(String raw, {required String fallback}) {
    final trimmed = raw.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  int get _normalizedTelegramAdminPollIntervalSeconds {
    final raw =
        _telegramAdminPollIntervalSecondsOverride ??
        _telegramAdminPollIntervalSecondsEnv;
    if (raw < 3) {
      return 3;
    }
    if (raw > 60) {
      return 60;
    }
    return raw;
  }

  int get _normalizedTelegramAdminCriticalReminderSeconds {
    final raw =
        _telegramAdminCriticalReminderSecondsOverride ??
        _telegramAdminCriticalReminderSecondsEnv;
    if (raw < 60) {
      return 60;
    }
    if (raw > 3600) {
      return 3600;
    }
    return raw;
  }

  String _resolvedTelegramAdminChatId() {
    final explicit = _telegramAdminChatIdEnv.trim();
    if (explicit.isNotEmpty) return explicit;
    return _telegramChatIdEnv.trim();
  }

  int? _resolvedTelegramAdminThreadId() {
    final raw = _telegramAdminThreadIdEnv.trim();
    if (raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  bool get _telegramAdminControlEnabled {
    if (!_telegramAdminControlEnabledEnv) {
      return false;
    }
    if (!_telegramBridge.isConfigured) {
      return false;
    }
    return _resolvedTelegramAdminChatId().isNotEmpty;
  }

  bool get _telegramAdminCriticalPushEnabled {
    if (!_telegramAdminCriticalPushEnabledEnv) {
      return false;
    }
    return _telegramAdminControlEnabled;
  }

  bool get _telegramAdminExecutionEnabled {
    return _telegramAdminExecutionEnabledOverride ??
        _telegramAdminExecutionEnabledEnv;
  }

  bool get _telegramAiAssistantEnabled {
    final enabled =
        _telegramAiAssistantEnabledOverride ?? _telegramAiAssistantEnabledEnv;
    if (!enabled) {
      return false;
    }
    return _telegramBridge.isConfigured;
  }

  bool get _telegramAiApprovalRequired {
    return _telegramAiApprovalRequiredOverride ??
        _telegramAiApprovalRequiredEnv;
  }

  bool get _telegramInboundRouterEnabled {
    return _telegramAdminControlEnabled || _telegramAiAssistantEnabled;
  }

  bool get _keepTelegramPollingWhenBackgrounded {
    return kIsWeb || _appMode == OnyxAppMode.controller;
  }

  String get _telegramAdminTargetClientId {
    final override = (_telegramAdminTargetClientIdOverride ?? '').trim();
    if (override.isNotEmpty) {
      return override;
    }
    return _selectedClient;
  }

  String get _telegramAdminTargetSiteId {
    final override = (_telegramAdminTargetSiteIdOverride ?? '').trim();
    if (override.isNotEmpty) {
      return override;
    }
    return _selectedSite;
  }

  Set<int> get _telegramAdminAllowedUserIdsFromEnv {
    final raw = _telegramAdminAllowedUserIdsEnv.trim();
    if (raw.isEmpty) {
      return const <int>{};
    }
    return raw
        .split(',')
        .map((value) => int.tryParse(value.trim()))
        .whereType<int>()
        .where((value) => value > 0)
        .toSet();
  }

  Set<int> get _telegramAdminAllowedUserIds {
    final override = _telegramAdminAllowedUserIdsOverride;
    if (override == null) {
      return _telegramAdminAllowedUserIdsFromEnv;
    }
    return override.where((value) => value > 0).toSet();
  }

  TelegramBridgeService _buildTelegramBridge() {
    if (!_telegramBridgeEnabledEnv) {
      return const UnconfiguredTelegramBridgeService();
    }
    final botToken = _telegramBotTokenEnv.trim();
    if (botToken.isEmpty) {
      return const UnconfiguredTelegramBridgeService();
    }
    return HttpTelegramBridgeService(
      client: _telegramBridgeHttpClient,
      botToken: botToken,
    );
  }

  TelegramAiAssistantService _buildTelegramAiAssistant() {
    final apiKey = _telegramAiOpenAiApiKeyEnv.trim();
    final model = _telegramAiModelEnv.trim();
    if (apiKey.isEmpty || model.isEmpty) {
      return const UnconfiguredTelegramAiAssistantService();
    }
    final endpoint = _telegramAiEndpointEnv.trim();
    return OpenAiTelegramAiAssistantService(
      client: _telegramAiHttpClient,
      apiKey: apiKey,
      model: model,
      endpoint: endpoint.isEmpty ? null : Uri.tryParse(endpoint),
    );
  }

  MonitoringWatchVisionReviewService _buildMonitoringWatchVisionReview() {
    if (!_monitoringVisionReviewEnabledEnv) {
      return const UnconfiguredMonitoringWatchVisionReviewService();
    }
    final apiKey = _monitoringVisionOpenAiApiKeyEnv.trim().isNotEmpty
        ? _monitoringVisionOpenAiApiKeyEnv.trim()
        : _telegramAiOpenAiApiKeyEnv.trim();
    final model = _monitoringVisionModelEnv.trim().isNotEmpty
        ? _monitoringVisionModelEnv.trim()
        : _telegramAiModelEnv.trim();
    if (apiKey.isEmpty || model.isEmpty) {
      return const UnconfiguredMonitoringWatchVisionReviewService();
    }
    final endpoint = _monitoringVisionEndpointEnv.trim().isNotEmpty
        ? _monitoringVisionEndpointEnv.trim()
        : _telegramAiEndpointEnv.trim();
    return OpenAiMonitoringWatchVisionReviewService(
      client: _monitoringVisionHttpClient,
      apiKey: apiKey,
      model: model,
      endpoint: endpoint.isEmpty ? null : Uri.tryParse(endpoint),
    );
  }

  void _rebuildWatchSceneAssessmentService() {
    _watchTemporaryIdentityApprovalService =
        _watchTemporaryIdentityApprovalService.pruneExpired();
    _watchSceneAssessmentService = MonitoringWatchSceneAssessmentService(
      identityPolicyService: _watchIdentityPolicyService,
      temporaryIdentityApprovalService: _watchTemporaryIdentityApprovalService,
    );
  }

  @override
  void initState() {
    super.initState();
    _watchIdentityPolicyService = MonitoringIdentityPolicyService.parseJson(
      _monitoringIdentityRulesJsonEnv,
    );
    _rebuildWatchSceneAssessmentService();
    if (widget.supabaseReady) {
      unawaited(_hydrateTemporaryIdentityApprovalsFromSupabase());
    }
    WidgetsBinding.instance.addObserver(this);
    _telegramBridgeHealthLabel = _telegramBridge.isConfigured
        ? 'configured'
        : 'disabled';
    _telegramBridgeHealthDetail = _telegramBridge.isConfigured
        ? 'Bridge token configured. Awaiting delivery attempts.'
        : 'Telegram bridge disabled or missing bot token.';
    _outcomeGovernancePolicy = OutcomeLabelGovernancePolicy.fromJsonString(
      _guardOutcomeGovernanceJson,
      fallback: OutcomeLabelGovernancePolicy.defaultPolicy(),
    );
    _persistenceServiceFuture = DispatchPersistenceService.create();
    _clientConversationRepositoryFuture = _persistenceServiceFuture.then((
      persistence,
    ) {
      final localRepository = SharedPrefsClientConversationRepository(
        persistence,
      );
      if (!widget.supabaseReady) {
        return localRepository;
      }
      return FallbackClientConversationRepository(
        primary: SupabaseClientConversationRepository(
          client: Supabase.instance.client,
          clientId: _selectedClient,
          siteId: _selectedSite,
        ),
        fallback: localRepository,
      );
    });
    _guardSyncRepositoryFuture = _persistenceServiceFuture.then((persistence) {
      final localRepository = SharedPrefsGuardSyncRepository(persistence);
      if (!widget.supabaseReady) {
        return localRepository;
      }
      return FallbackGuardSyncRepository(
        primary: SupabaseGuardSyncRepository(
          client: Supabase.instance.client,
          clientId: _selectedClient,
          siteId: _selectedSite,
          guardId: 'GUARD-001',
        ),
        fallback: localRepository,
      );
    });
    _guardMobileOpsServiceFuture = _guardSyncRepositoryFuture.then(
      (repository) => GuardMobileOpsService(
        tierProfile: GuardOperationalTierCatalog.profile(
          GuardOperationalTier.tier1VerifiedOperations,
        ),
        syncQueue: RepositoryBackedGuardMobileSyncQueue(repository),
        operationContextBuilder: _buildGuardSyncOperationContext,
      ),
    );
    _guardOpsRepositoryFuture = _persistenceServiceFuture.then((_) {
      final remote = widget.supabaseReady
          ? SupabaseGuardOpsRemoteGateway(Supabase.instance.client)
          : const NoopGuardOpsRemoteGateway();
      return SharedPrefsGuardOpsRepository.create(remote: remote);
    });
    _clientLedgerRepository = widget.supabaseReady
        ? SupabaseClientLedgerRepository(Supabase.instance.client)
        : InMemoryClientLedgerRepository();
    _offlineIncidentSpoolServiceFuture = _persistenceServiceFuture.then((
      persistence,
    ) {
      final remote = widget.supabaseReady
          ? LedgerBackedOfflineIncidentSpoolRemoteGateway(
              ledgerService: ClientLedgerService(_clientLedgerRepository),
            )
          : const NoopOfflineIncidentSpoolRemoteGateway();
      return OfflineIncidentSpoolService(
        persistence: persistence,
        remote: remote,
      );
    });

    _rebuildDispatchServices();
    _newsIntel = NewsIntelligenceService();
    _newsSourceDiagnostics = _newsIntel.diagnostics;

    _seedDemoData();
    _hydrateTelemetry();
    _hydrateLivePollHistory();
    _hydrateLivePollSummary();
    _hydrateNewsSourceDiagnostics();
    _hydrateRadioIntentPhraseConfig();
    _hydrateOperatorIdentity();
    _hydrateMonitoringIdentityRulesConfig();
    _hydrateMonitoringIdentityRuleAuditHistory();
    _hydrateMonitoringIdentityRuleAuditUiState();
    _hydrateAdminPageTab();
    _hydrateAdminWatchActionDrilldown();
    _hydratePendingRadioAutomatedResponses();
    _hydrateOpsIntegrationHealthSnapshot();
    _hydrateStressProfile();
    _hydrateClientAppDraft();
    _hydrateTelegramAdminRuntimeState();
    _hydrateMonitoringWatchRuntimeState();
    _hydrateMonitoringWatchAuditState();
    _hydrateMonitoringWatchRecoveryState();
    _hydrateMonitoringSceneReviewState();
    _hydrateGuardSyncState();
    _hydrateGuardOpsState();
    _hydrateOfflineIncidentSpoolState();
    _hydrateOfflineIncidentSpoolReplayAudit();
    _hydrateGuardOutcomeGovernanceTelemetry();
    _hydrateGuardCoachingPromptSnoozes();
    _hydrateGuardCoachingTelemetry();
    _hydrateGuardCloseoutPacketAudit();
    _hydrateGuardShiftReplayAudit();
    _hydrateGuardSyncReportAudit();
    _hydrateGuardExportAuditClearMeta();
    _hydrateMorningSovereignReport();
    _refreshGuardTelemetryAdapterStatus();
    _startGuardOpsSyncLoop();
    _startOfflineIncidentSpoolSyncLoop();
    _startOpsIntegrationPollingLoop();
    _startTelegramAdminControlLoop();
    _startMonitoringWatchScheduleLoop();
  }

  // ignore: unused_element
  void _openGuardSyncFromDashboard() {
    setState(() {
      _route = OnyxRoute.guards;
      _guardSyncLandingPending = true;
    });
  }

  GuardMobileInitialScreen _consumeGuardInitialScreen() {
    if (_guardSyncLandingPending) {
      _guardSyncLandingPending = false;
      return GuardMobileInitialScreen.sync;
    }
    return GuardMobileInitialScreen.dispatch;
  }

  OperatorContext _currentOperatorContext() {
    return OperatorContext(
      operatorId: _operatorId.trim().isEmpty ? _defaultOperatorId : _operatorId,
      allowedRegions: {_selectedRegion},
      allowedSites: {_selectedSite},
    );
  }

  void _rebuildDispatchServices() {
    service = DispatchApplicationService(
      store: store,
      engine: ExecutionEngine(),
      policy: RiskPolicy(escalationThreshold: 70),
      ledgerService: ClientLedgerService(_clientLedgerRepository),
      operator: _currentOperatorContext(),
    );
    stressService = IntakeStressService(store: store, service: service);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _livePollTimer?.cancel();
    _opsIntegrationPollTimer?.cancel();
    _guardOpsSyncTimer?.cancel();
    _offlineIncidentSpoolSyncTimer?.cancel();
    _telegramAdminPollTimer?.cancel();
    _monitoringWatchScheduleTimer?.cancel();
    _telegramDemoScriptTimer?.cancel();
    _cancelDemoAutopilot();
    _radioBridgeHttpClient.close();
    _cctvBridgeHttpClient.close();
    _wearableBridgeHttpClient.close();
    _telegramBridgeHttpClient.close();
    _telegramAiHttpClient.close();
    _monitoringVisionHttpClient.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      if (state == AppLifecycleState.inactive ||
          state == AppLifecycleState.paused ||
          state == AppLifecycleState.detached) {
        _opsIntegrationPollTimer?.cancel();
        _opsIntegrationPollTimer = null;
        _monitoringWatchScheduleTimer?.cancel();
        _monitoringWatchScheduleTimer = null;
        if (!_keepTelegramPollingWhenBackgrounded) {
          _telegramAdminPollTimer?.cancel();
          _telegramAdminPollTimer = null;
        }
      }
      return;
    }
    _startOpsIntegrationPollingLoop();
    _startTelegramAdminControlLoop();
    _startMonitoringWatchScheduleLoop();
    unawaited(_maybeAutoGenerateMorningSovereignReport());
    if (!widget.supabaseReady || _guardOpsSyncInFlight) return;
    if (mounted) {
      setState(() {
        _guardOpsLastSyncLabel =
            'Guard sync queued after app resume (connectivity recheck).';
      });
    }
    unawaited(_queueGuardResumeSync());
  }

  Future<void> _queueGuardResumeSync() async {
    try {
      final nowUtc = DateTime.now().toUtc();
      final lastQueuedAt = _lastGuardResumeSyncEventQueuedAtUtc;
      final shouldEnqueue =
          lastQueuedAt == null ||
          nowUtc.difference(lastQueuedAt).inSeconds >=
              _guardResumeSyncEventThrottleSeconds;
      if (shouldEnqueue) {
        _lastGuardResumeSyncEventQueuedAtUtc = nowUtc;
        await _enqueueGuardOpsEvent(
          type: GuardOpsEventType.syncStatus,
          payload: {
            'sync_reason': 'app_resumed',
            'source': 'app_lifecycle',
            'connectivity_recheck': true,
            'event_throttle_seconds': _guardResumeSyncEventThrottleSeconds,
          },
        );
      }
      await _syncGuardOpsNow(background: true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _guardOpsLastSyncLabel = 'Resume sync failed: $error';
        _guardOpsLastFailureReason = error.toString();
      });
    }
  }

  Future<void> _hydrateTelemetry() async {
    final persistence = await _persistenceServiceFuture;
    final telemetry = await persistence.readTelemetry();
    if (telemetry == null || !mounted) return;
    setState(() {
      _intakeTelemetry = telemetry;
      _lastIntakeStatus =
          'Telemetry restored from local cache (${telemetry.runs} runs).';
    });
  }

  Future<void> _persistTelemetry() async {
    final persistence = await _persistenceServiceFuture;
    await persistence.saveTelemetry(_intakeTelemetry);
  }

  Future<void> _hydrateOperatorIdentity() async {
    final persistence = await _persistenceServiceFuture;
    final persisted = (await persistence.readOperatorId() ?? '').trim();
    if (persisted.isEmpty || persisted == _operatorId) {
      return;
    }
    if (mounted) {
      setState(() {
        _operatorId = persisted;
        _rebuildDispatchServices();
      });
    } else {
      _operatorId = persisted;
      _rebuildDispatchServices();
    }
  }

  Future<void> _persistOperatorIdentity() async {
    final persistence = await _persistenceServiceFuture;
    final normalized = _operatorId.trim();
    if (normalized.isEmpty || normalized == _defaultOperatorId) {
      await persistence.clearOperatorId();
    } else {
      await persistence.saveOperatorId(normalized);
    }
  }

  Future<void> _setOperatorIdentity(String operatorId) async {
    final normalized = operatorId.trim().isEmpty
        ? _defaultOperatorId
        : operatorId.trim();
    if (normalized == _operatorId) {
      return;
    }
    if (mounted) {
      setState(() {
        _operatorId = normalized;
        _rebuildDispatchServices();
      });
    } else {
      _operatorId = normalized;
      _rebuildDispatchServices();
    }
    await _persistOperatorIdentity();
  }

  Future<void> _hydrateLivePollHistory() async {
    final persistence = await _persistenceServiceFuture;
    final history = await persistence.readLivePollHistory();
    if (history.isEmpty || !mounted) return;
    setState(() {
      _livePollingHistory = history;
    });
  }

  Future<void> _persistLivePollHistory() async {
    final persistence = await _persistenceServiceFuture;
    await persistence.saveLivePollHistory(_livePollingHistory);
  }

  Future<void> _hydrateLivePollSummary() async {
    final persistence = await _persistenceServiceFuture;
    final summary = await persistence.readLivePollSummary();
    if (summary.isEmpty || !mounted) return;
    setState(() {
      _lastLivePollLatencyMs = _summaryInt(summary['latencyMs']);
      _lastLivePollSuccessAtUtc = _summaryDate(summary['successAtUtc']);
      _lastLivePollFailureAtUtc = _summaryDate(summary['failureAtUtc']);
      _lastLivePollError = _summaryString(summary['error']);
      _livePollFailures = _summaryInt(summary['failures']) ?? _livePollFailures;
      _livePollDelaySeconds =
          _summaryInt(summary['delaySeconds']) ?? _livePollDelaySeconds;
    });
  }

  Future<void> _persistLivePollSummary() async {
    final persistence = await _persistenceServiceFuture;
    await persistence.saveLivePollSummary({
      'latencyMs': _lastLivePollLatencyMs,
      'successAtUtc': _lastLivePollSuccessAtUtc?.toIso8601String(),
      'failureAtUtc': _lastLivePollFailureAtUtc?.toIso8601String(),
      'error': _lastLivePollError,
      'failures': _livePollFailures,
      'delaySeconds': _livePollDelaySeconds,
    });
  }

  Future<void> _hydrateNewsSourceDiagnostics() async {
    final persistence = await _persistenceServiceFuture;
    final saved = await persistence.readNewsSourceDiagnostics();
    if (saved.isEmpty || !mounted) return;
    final savedByProvider = {
      for (final diagnostic in saved) diagnostic.provider: diagnostic,
    };
    setState(() {
      _newsSourceDiagnostics = _newsIntel.diagnostics
          .map((baseline) {
            final cached = savedByProvider[baseline.provider];
            if (cached == null || baseline.status.startsWith('missing')) {
              return baseline;
            }
            return cached;
          })
          .toList(growable: false);
    });
  }

  Future<void> _persistNewsSourceDiagnostics() async {
    final persistence = await _persistenceServiceFuture;
    await persistence.saveNewsSourceDiagnostics(_newsSourceDiagnostics);
  }

  Future<void> _hydrateRadioIntentPhraseConfig() async {
    final persistence = await _persistenceServiceFuture;
    final raw = await persistence.readRadioIntentPhrasesJson();
    if (raw == null) return;
    final catalog = OnyxRadioIntentPhraseCatalog.tryParseJsonString(raw);
    if (catalog == null) {
      await persistence.clearRadioIntentPhrasesJson();
      return;
    }
    OnyxRadioIntentClassifier.setRuntimePhraseCatalog(catalog);
    if (!mounted) return;
    setState(() {
      _radioIntentPhrasesJsonOverride = raw;
    });
  }

  void _applyMonitoringIdentityPolicyRuntime(
    MonitoringIdentityPolicyService service,
    String rawJson,
  ) {
    _watchIdentityPolicyService = service;
    _rebuildWatchSceneAssessmentService();
    if (!mounted) return;
    setState(() {
      _monitoringIdentityRulesJsonOverride = rawJson.trim();
    });
  }

  Future<void> _hydrateMonitoringIdentityRulesConfig() async {
    final persistence = await _persistenceServiceFuture;
    final raw = await persistence.readMonitoringIdentityRulesJson();
    if (raw == null) return;
    final service = MonitoringIdentityPolicyService.parseJson(raw);
    _applyMonitoringIdentityPolicyRuntime(service, raw);
  }

  Future<void> _hydrateTemporaryIdentityApprovalsFromSupabase() async {
    if (!widget.supabaseReady) {
      return;
    }
    try {
      final repository = SupabaseSiteIdentityRegistryRepository(
        Supabase.instance.client,
      );
      final profiles = await repository.listActiveTemporaryApprovalProfiles();
      _watchTemporaryIdentityApprovalService =
          MonitoringTemporaryIdentityApprovalService.fromProfiles(profiles);
      _rebuildWatchSceneAssessmentService();
    } catch (_) {
      // Temporary approvals are an enhancement path; keep monitoring alive if sync fails.
    }
  }

  Future<void> _hydrateMonitoringIdentityRuleAuditHistory() async {
    final persistence = await _persistenceServiceFuture;
    final restored = await persistence.readMonitoringIdentityRuleAuditHistory();
    if (!mounted) {
      _monitoringIdentityRuleAuditHistory = restored;
      return;
    }
    setState(() {
      _monitoringIdentityRuleAuditHistory = restored;
    });
  }

  Future<void> _hydrateMonitoringIdentityRuleAuditUiState() async {
    final persistence = await _persistenceServiceFuture;
    final restoredSource = await persistence
        .readMonitoringIdentityRuleAuditSourceFilter();
    final restoredExpanded = await persistence
        .readMonitoringIdentityRuleAuditExpanded();
    if (!mounted) {
      _adminIdentityPolicyAuditSourceFilter = restoredSource;
      if (restoredExpanded != null) {
        _adminIdentityPolicyAuditExpanded = restoredExpanded;
      }
      return;
    }
    setState(() {
      _adminIdentityPolicyAuditSourceFilter = restoredSource;
      if (restoredExpanded != null) {
        _adminIdentityPolicyAuditExpanded = restoredExpanded;
      }
    });
  }

  Future<void> _hydrateAdminPageTab() async {
    final persistence = await _persistenceServiceFuture;
    final restored = await persistence.readAdminPageTab();
    if (restored == null) return;
    if (!mounted) {
      _adminPageTab = restored;
      return;
    }
    setState(() {
      _adminPageTab = restored;
    });
  }

  Future<void> _hydrateAdminWatchActionDrilldown() async {
    final persistence = await _persistenceServiceFuture;
    final restored = await persistence.readAdminWatchActionDrilldown();
    if (!mounted) {
      _adminWatchActionDrilldown = restored;
      if (restored != null) {
        _adminPageTab = AdministrationPageTab.system;
      }
      return;
    }
    setState(() {
      _adminWatchActionDrilldown = restored;
      if (restored != null) {
        _adminPageTab = AdministrationPageTab.system;
      }
    });
  }

  Future<void> _saveRadioIntentPhraseConfig(String rawJson) async {
    final trimmed = rawJson.trim();
    if (trimmed.isEmpty) {
      await _clearRadioIntentPhraseConfig();
      return;
    }
    final catalog = OnyxRadioIntentPhraseCatalog.tryParseJsonString(trimmed);
    if (catalog == null) {
      throw const FormatException(
        'Invalid radio intent JSON. Include at least one array for all_clear, panic, duress, or status.',
      );
    }
    final persistence = await _persistenceServiceFuture;
    await persistence.saveRadioIntentPhrasesJson(trimmed);
    OnyxRadioIntentClassifier.setRuntimePhraseCatalog(catalog);
    if (!mounted) return;
    setState(() {
      _radioIntentPhrasesJsonOverride = trimmed;
      _lastIntakeStatus = 'Radio intent phrase dictionary updated.';
    });
  }

  Future<void> _clearRadioIntentPhraseConfig() async {
    final persistence = await _persistenceServiceFuture;
    await persistence.clearRadioIntentPhrasesJson();
    OnyxRadioIntentClassifier.setRuntimePhraseCatalog(null);
    if (!mounted) return;
    setState(() {
      _radioIntentPhrasesJsonOverride = '';
      _lastIntakeStatus = 'Radio intent phrase dictionary reset to defaults.';
    });
  }

  Future<void> _saveMonitoringIdentityRulesConfig(
    MonitoringIdentityPolicyService service,
  ) async {
    final rawJson = service.toCanonicalJsonString();
    final persistence = await _persistenceServiceFuture;
    await persistence.saveMonitoringIdentityRulesJson(rawJson);
    _watchIdentityPolicyService = service;
    _rebuildWatchSceneAssessmentService();
    if (!mounted) return;
    setState(() {
      _monitoringIdentityRulesJsonOverride = rawJson;
      _lastIntakeStatus = 'Monitoring identity rules updated.';
    });
  }

  Future<void> _clearMonitoringIdentityRulesConfig() async {
    final persistence = await _persistenceServiceFuture;
    await persistence.clearMonitoringIdentityRulesJson();
    final service = MonitoringIdentityPolicyService.parseJson(
      _monitoringIdentityRulesJsonEnv,
    );
    _watchIdentityPolicyService = service;
    _rebuildWatchSceneAssessmentService();
    if (!mounted) return;
    setState(() {
      _monitoringIdentityRulesJsonOverride = '';
      _lastIntakeStatus =
          'Monitoring identity rules reset to environment defaults.';
    });
  }

  Future<void> _persistMonitoringIdentityRuleAuditHistory() async {
    final persistence = await _persistenceServiceFuture;
    await persistence.saveMonitoringIdentityRuleAuditHistory(
      _monitoringIdentityRuleAuditHistory,
    );
  }

  Future<void> _persistMonitoringIdentityRuleAuditSourceFilter() async {
    final persistence = await _persistenceServiceFuture;
    await persistence.saveMonitoringIdentityRuleAuditSourceFilter(
      _adminIdentityPolicyAuditSourceFilter,
    );
  }

  Future<void> _persistMonitoringIdentityRuleAuditExpanded() async {
    final persistence = await _persistenceServiceFuture;
    await persistence.saveMonitoringIdentityRuleAuditExpanded(
      _adminIdentityPolicyAuditExpanded,
    );
  }

  Future<void> _persistAdminWatchActionDrilldown() async {
    final persistence = await _persistenceServiceFuture;
    await persistence.saveAdminWatchActionDrilldown(_adminWatchActionDrilldown);
  }

  Future<void> _persistAdminPageTab() async {
    final persistence = await _persistenceServiceFuture;
    await persistence.saveAdminPageTab(_adminPageTab);
  }

  Future<void> _saveDemoRouteCueOverridesConfig(String rawJson) async {
    final trimmed = rawJson.trim();
    if (trimmed.isEmpty) {
      await _clearDemoRouteCueOverridesConfig();
      return;
    }
    final parsed = _parseDemoRouteCueOverridesJson(trimmed);
    if (!mounted) return;
    setState(() {
      _demoRouteCueOverridesJson = trimmed;
      _demoRouteCueOverrides = parsed;
      _lastIntakeStatus = 'Demo route narration cues updated.';
    });
  }

  Future<void> _clearDemoRouteCueOverridesConfig() async {
    if (!mounted) return;
    setState(() {
      _demoRouteCueOverridesJson = '';
      _demoRouteCueOverrides = const {};
      _lastIntakeStatus = 'Demo route narration cues reset to defaults.';
    });
  }

  Map<String, String> _parseDemoRouteCueOverridesJson(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map) {
      throw const FormatException(
        'Invalid demo cue JSON. Expected an object of route keys to cue text.',
      );
    }
    final output = <String, String>{};
    decoded.forEach((key, value) {
      final routeKey = key.toString().trim().toLowerCase();
      if (routeKey.isEmpty) return;
      final cue = value?.toString().trim() ?? '';
      if (cue.isEmpty) return;
      output[routeKey] = cue;
    });
    return output;
  }

  Future<void> _hydratePendingRadioAutomatedResponses() async {
    final persistence = await _persistenceServiceFuture;
    final restored = await persistence.readPendingRadioAutomatedResponses();
    final restoredRetryRaw = await persistence
        .readPendingRadioAutomatedResponsesRetryState();
    final restoredManualActionDetail = await persistence
        .readPendingRadioQueueManualActionDetail();
    final restoredFailureSnapshot = await persistence
        .readPendingRadioQueueFailureSnapshot();
    final restoredFailureAuditDetail = await persistence
        .readPendingRadioQueueFailureAuditDetail();
    final restoredStateChangeDetail = await persistence
        .readPendingRadioQueueStateChangeDetail();
    final trimmed = _trimPendingRadioAutomatedResponses(restored);
    final validKeys = trimmed.map(_radioAutomatedResponseKey).toSet();
    final retryByKey = <String, _RadioPendingRetryState>{};
    restoredRetryRaw.forEach((key, value) {
      if (!validKeys.contains(key)) return;
      retryByKey[key] = _RadioPendingRetryState.fromJson(value);
    });
    if (trimmed.length != restored.length) {
      if (trimmed.isEmpty) {
        await persistence.clearPendingRadioAutomatedResponses();
      } else {
        await persistence.savePendingRadioAutomatedResponses(trimmed);
      }
    }
    if (retryByKey.length != restoredRetryRaw.length) {
      if (retryByKey.isEmpty) {
        await persistence.clearPendingRadioAutomatedResponsesRetryState();
      } else {
        await persistence.savePendingRadioAutomatedResponsesRetryState(
          retryByKey.map((key, value) => MapEntry(key, value.toJson())),
        );
      }
    }
    if (!mounted) {
      _pendingRadioAutomatedResponses = trimmed;
      _pendingRadioRetryByKey = retryByKey;
      if (restoredManualActionDetail != null &&
          restoredManualActionDetail.trim().isNotEmpty) {
        _radioQueueLastManualActionDetail = restoredManualActionDetail.trim();
      }
      if (restoredFailureSnapshot != null &&
          restoredFailureSnapshot.trim().isNotEmpty) {
        _radioQueueLastFailureSnapshot = restoredFailureSnapshot.trim();
      }
      if (restoredFailureAuditDetail != null &&
          restoredFailureAuditDetail.trim().isNotEmpty) {
        _radioQueueFailureAuditDetail = restoredFailureAuditDetail.trim();
      }
      if (restoredStateChangeDetail != null &&
          restoredStateChangeDetail.trim().isNotEmpty) {
        _radioQueueLastStateChangeDetail = restoredStateChangeDetail.trim();
      }
      return;
    }
    setState(() {
      _pendingRadioAutomatedResponses = trimmed;
      _pendingRadioRetryByKey = retryByKey;
      if (restoredManualActionDetail != null &&
          restoredManualActionDetail.trim().isNotEmpty) {
        _radioQueueLastManualActionDetail = restoredManualActionDetail.trim();
      }
      if (restoredFailureSnapshot != null &&
          restoredFailureSnapshot.trim().isNotEmpty) {
        _radioQueueLastFailureSnapshot = restoredFailureSnapshot.trim();
      }
      if (restoredFailureAuditDetail != null &&
          restoredFailureAuditDetail.trim().isNotEmpty) {
        _radioQueueFailureAuditDetail = restoredFailureAuditDetail.trim();
      }
      if (restoredStateChangeDetail != null &&
          restoredStateChangeDetail.trim().isNotEmpty) {
        _radioQueueLastStateChangeDetail = restoredStateChangeDetail.trim();
      }
    });
  }

  Future<void> _persistPendingRadioAutomatedResponses() async {
    final persistence = await _persistenceServiceFuture;
    if (_pendingRadioAutomatedResponses.isEmpty) {
      await persistence.clearPendingRadioAutomatedResponses();
      await persistence.clearPendingRadioAutomatedResponsesRetryState();
    } else {
      final validKeys = _pendingRadioAutomatedResponses
          .map(_radioAutomatedResponseKey)
          .toSet();
      final retryPruned = <String, _RadioPendingRetryState>{};
      _pendingRadioRetryByKey.forEach((key, value) {
        if (validKeys.contains(key)) {
          retryPruned[key] = value;
        }
      });
      _pendingRadioRetryByKey = retryPruned;
      await persistence.savePendingRadioAutomatedResponses(
        _pendingRadioAutomatedResponses,
      );
      if (retryPruned.isEmpty) {
        await persistence.clearPendingRadioAutomatedResponsesRetryState();
      } else {
        await persistence.savePendingRadioAutomatedResponsesRetryState(
          retryPruned.map((key, value) => MapEntry(key, value.toJson())),
        );
      }
    }

    final manualActionDetail = _radioQueueLastManualActionDetail.trim();
    if (manualActionDetail.isEmpty) {
      await persistence.clearPendingRadioQueueManualActionDetail();
    } else {
      await persistence.savePendingRadioQueueManualActionDetail(
        manualActionDetail,
      );
    }
    final failureSnapshot = _radioQueueLastFailureSnapshot.trim();
    if (failureSnapshot.isEmpty) {
      await persistence.clearPendingRadioQueueFailureSnapshot();
    } else {
      await persistence.savePendingRadioQueueFailureSnapshot(failureSnapshot);
    }
    final failureAuditDetail = _radioQueueFailureAuditDetail.trim();
    if (failureAuditDetail.isEmpty) {
      await persistence.clearPendingRadioQueueFailureAuditDetail();
    } else {
      await persistence.savePendingRadioQueueFailureAuditDetail(
        failureAuditDetail,
      );
    }
    final stateChangeDetail = _radioQueueLastStateChangeDetail.trim();
    if (stateChangeDetail.isEmpty) {
      await persistence.clearPendingRadioQueueStateChangeDetail();
    } else {
      await persistence.savePendingRadioQueueStateChangeDetail(
        stateChangeDetail,
      );
    }
  }

  Future<void> _hydrateOpsIntegrationHealthSnapshot() async {
    final persistence = await _persistenceServiceFuture;
    final snapshot = await persistence.readOpsIntegrationHealthSnapshot();
    if (snapshot.isEmpty) return;
    final radioRaw = _asObjectMap(snapshot['radio']);
    final cctvRaw = _asObjectMap(snapshot['cctv']);
    final wearableRaw = _asObjectMap(snapshot['wearable']);
    final listenerAlarmRaw = _asObjectMap(snapshot['listener_alarm']);
    final newsRaw = _asObjectMap(snapshot['news']);
    final cctvEvidenceRaw = cctvRaw == null
        ? null
        : _asObjectMap(cctvRaw['evidence']);
    if (!mounted) {
      if (radioRaw != null) {
        _radioOpsHealth = _OpsIntegrationHealth.fromJson(radioRaw);
      }
      if (cctvRaw != null) {
        _cctvOpsHealth = _OpsIntegrationHealth.fromJson(cctvRaw);
      }
      if (cctvEvidenceRaw != null) {
        _cctvEvidenceHealth = VideoEvidenceProbeSnapshot.fromJson(
          cctvEvidenceRaw,
        );
      }
      if (wearableRaw != null) {
        _wearableOpsHealth = _OpsIntegrationHealth.fromJson(wearableRaw);
      }
      if (listenerAlarmRaw != null) {
        _listenerAlarmOpsHealth = _OpsIntegrationHealth.fromJson(
          listenerAlarmRaw,
        );
      }
      if (newsRaw != null) {
        _newsOpsHealth = _OpsIntegrationHealth.fromJson(newsRaw);
      }
      return;
    }
    setState(() {
      if (radioRaw != null) {
        _radioOpsHealth = _OpsIntegrationHealth.fromJson(radioRaw);
      }
      if (cctvRaw != null) {
        _cctvOpsHealth = _OpsIntegrationHealth.fromJson(cctvRaw);
      }
      if (cctvEvidenceRaw != null) {
        _cctvEvidenceHealth = VideoEvidenceProbeSnapshot.fromJson(
          cctvEvidenceRaw,
        );
      }
      if (wearableRaw != null) {
        _wearableOpsHealth = _OpsIntegrationHealth.fromJson(wearableRaw);
      }
      if (listenerAlarmRaw != null) {
        _listenerAlarmOpsHealth = _OpsIntegrationHealth.fromJson(
          listenerAlarmRaw,
        );
      }
      if (newsRaw != null) {
        _newsOpsHealth = _OpsIntegrationHealth.fromJson(newsRaw);
      }
    });
  }

  Future<void> _persistOpsIntegrationHealthSnapshot() async {
    final persistence = await _persistenceServiceFuture;
    final cctvJson = {
      ..._cctvOpsHealth.toJson(),
      'evidence': _cctvEvidenceHealth.toJson(),
    };
    await persistence.saveOpsIntegrationHealthSnapshot({
      'radio': _radioOpsHealth.toJson(),
      'cctv': cctvJson,
      'wearable': _wearableOpsHealth.toJson(),
      'listener_alarm': _listenerAlarmOpsHealth.toJson(),
      'news': _newsOpsHealth.toJson(),
    });
  }

  Future<void> _hydrateStressProfile() async {
    final persistence = await _persistenceServiceFuture;
    final draft = await persistence.readStressProfile();
    if (draft == null || !mounted) return;
    setState(() {
      _currentStressProfile = draft.profile;
      _currentScenarioLabel = draft.scenarioLabel;
      _currentScenarioTags = draft.tags;
      _currentRunNote = draft.runNote;
      _savedFilterPresets = draft.filterPresets;
      _currentIntelligenceSourceFilter = draft.intelligenceSourceFilter;
      _currentIntelligenceActionFilter = draft.intelligenceActionFilter;
      _pinnedWatchIntelligenceIds = draft.pinnedWatchIntelligenceIds;
      _dismissedIntelligenceIds = draft.dismissedIntelligenceIds;
      _showPinnedWatchIntelligenceOnly = draft.showPinnedWatchIntelligenceOnly;
      _showDismissedIntelligenceOnly = draft.showDismissedIntelligenceOnly;
      _selectedIntelligenceId = draft.selectedIntelligenceId;
      _lastStressStatus = 'Stress profile restored from local cache.';
    });
  }

  Future<void> _hydrateClientAppDraft() async {
    final persistence = await _persistenceServiceFuture;
    final conversation = await _clientConversationRepositoryFuture;
    final draft = await persistence.readClientAppDraft();
    final storedMessages = await conversation.readMessages();
    final storedAcknowledgements = await conversation.readAcknowledgements();
    final storedPushQueue = await conversation.readPushQueue();
    final storedPushSyncState = await conversation.readPushSyncState();
    if (draft == null &&
        storedMessages.isEmpty &&
        storedAcknowledgements.isEmpty &&
        storedPushQueue.isEmpty &&
        storedPushSyncState.statusLabel == 'idle' &&
        storedPushSyncState.lastSyncedAtUtc == null &&
        (storedPushSyncState.failureReason == null ||
            storedPushSyncState.failureReason!.trim().isEmpty) &&
        storedPushSyncState.retryCount <= 0 &&
        storedPushSyncState.history.isEmpty &&
        storedPushSyncState.backendProbeStatusLabel == 'idle' &&
        storedPushSyncState.backendProbeLastRunAtUtc == null &&
        (storedPushSyncState.backendProbeFailureReason == null ||
            storedPushSyncState.backendProbeFailureReason!.trim().isEmpty) &&
        storedPushSyncState.backendProbeHistory.isEmpty) {
      return;
    }
    if (!mounted) return;
    final restoredMessages = storedMessages.isNotEmpty
        ? storedMessages
        : draft?.legacyManualMessages ?? const <ClientAppMessage>[];
    final restoredAcknowledgements = storedAcknowledgements.isNotEmpty
        ? storedAcknowledgements
        : draft?.legacyAcknowledgements ?? const <ClientAppAcknowledgement>[];
    if (storedMessages.isEmpty && restoredMessages.isNotEmpty) {
      unawaited(conversation.saveMessages(restoredMessages));
    }
    if (storedAcknowledgements.isEmpty && restoredAcknowledgements.isNotEmpty) {
      unawaited(conversation.saveAcknowledgements(restoredAcknowledgements));
    }
    ClientPushSyncAttempt? latestTelegramAttempt;
    for (final attempt in storedPushSyncState.history) {
      if (attempt.status.startsWith('telegram-')) {
        latestTelegramAttempt = attempt;
        break;
      }
    }
    var restoredBridgeLabel = _telegramBridge.isConfigured
        ? 'configured'
        : 'disabled';
    String? restoredBridgeDetail = _telegramBridge.isConfigured
        ? 'Bridge token configured. Awaiting delivery attempts.'
        : 'Telegram bridge disabled or missing bot token.';
    var restoredFallbackActive = false;
    DateTime? restoredBridgeUpdatedAtUtc;
    if (latestTelegramAttempt != null) {
      restoredBridgeUpdatedAtUtc = latestTelegramAttempt.occurredAt.toUtc();
      switch (latestTelegramAttempt.status) {
        case 'telegram-ok':
          restoredBridgeLabel = 'ok';
          restoredBridgeDetail = 'Last Telegram delivery succeeded.';
          restoredFallbackActive = false;
          break;
        case 'telegram-blocked':
          restoredBridgeLabel = 'blocked';
          restoredBridgeDetail = latestTelegramAttempt.failureReason;
          restoredFallbackActive = true;
          break;
        case 'telegram-skipped':
          restoredBridgeLabel = 'no-target';
          restoredBridgeDetail = latestTelegramAttempt.failureReason;
          restoredFallbackActive = true;
          break;
        case 'telegram-failed':
          restoredBridgeLabel = 'degraded';
          restoredBridgeDetail = latestTelegramAttempt.failureReason;
          restoredFallbackActive = false;
          break;
        default:
          break;
      }
    }
    setState(() {
      if (draft != null) {
        _clientAppViewerRole = draft.viewerRole;
        _clientAppSelectedRoomByRole = Map<String, String>.from(
          draft.selectedRoomByRole,
        );
        _clientAppShowAllRoomItemsByRole = Map<String, bool>.from(
          draft.showAllRoomItemsByRole,
        );
        _clientAppSelectedRoom = draft.selectedRoomFor(
          ClientAppViewerRole.client,
        );
        _clientAppShowAllRoomItems = draft.showAllRoomItemsFor(
          ClientAppViewerRole.client,
        );
        _clientAppSelectedIncidentReferenceByRole = Map<String, String>.from(
          draft.selectedIncidentReferenceByRole,
        );
        _clientAppExpandedIncidentReferenceByRole = Map<String, String>.from(
          draft.expandedIncidentReferenceByRole,
        );
        _clientAppHasTouchedIncidentExpansionByRole = Map<String, bool>.from(
          draft.hasTouchedIncidentExpansionByRole,
        );
        _clientAppFocusedIncidentReferenceByRole = Map<String, String>.from(
          draft.focusedIncidentReferenceByRole,
        );
      }
      _clientAppMessages = restoredMessages;
      _clientAppAcknowledgements = restoredAcknowledgements;
      _clientAppPushQueue = List<ClientAppPushDeliveryItem>.from(
        storedPushQueue,
      );
      _clientAppPushSyncStatusLabel = storedPushSyncState.statusLabel;
      _clientAppPushLastSyncedAtUtc = storedPushSyncState.lastSyncedAtUtc;
      _clientAppPushSyncFailureReason = storedPushSyncState.failureReason;
      _clientAppPushSyncRetryCount = storedPushSyncState.retryCount;
      _clientAppPushSyncHistory = storedPushSyncState.history;
      _telegramBridgeFallbackToInApp = restoredFallbackActive;
      _telegramBridgeHealthLabel = restoredBridgeLabel;
      _telegramBridgeHealthDetail = restoredBridgeDetail;
      _telegramBridgeHealthUpdatedAtUtc = restoredBridgeUpdatedAtUtc;
      _clientAppBackendProbeStatusLabel =
          storedPushSyncState.backendProbeStatusLabel;
      _clientAppBackendProbeLastRunAtUtc =
          storedPushSyncState.backendProbeLastRunAtUtc;
      _clientAppBackendProbeFailureReason =
          storedPushSyncState.backendProbeFailureReason;
      _clientAppBackendProbeHistory = storedPushSyncState.backendProbeHistory;
    });
  }

  Future<void> _hydrateTelegramAdminRuntimeState() async {
    final persistence = await _persistenceServiceFuture;
    final state = await persistence.readTelegramAdminRuntimeState();
    if (state.isEmpty) {
      return;
    }
    final pollOverride = _summaryInt(state['poll_interval_override_seconds']);
    final reminderOverride = _summaryInt(
      state['critical_reminder_override_seconds'],
    );
    final executionEnabledOverride = _summaryBool(
      state['execution_enabled_override'],
    );
    final allowedUserIdsOverrideRaw = state['allowed_user_ids_override'];
    final allowedUserIdsOverride = allowedUserIdsOverrideRaw is List
        ? allowedUserIdsOverrideRaw
              .map((entry) => int.tryParse((entry ?? '').toString().trim()))
              .whereType<int>()
              .where((value) => value > 0)
              .toSet()
              .toList(growable: false)
        : null;
    final targetClientOverride = _summaryString(
      state['target_client_override'],
    );
    final targetSiteOverride = _summaryString(state['target_site_override']);
    final criticalSnoozedUntil = _summaryDate(
      state['critical_snoozed_until_utc'],
    );
    final criticalAckFingerprint =
        _summaryString(state['critical_ack_fingerprint']) ?? '';
    final criticalAckAt = _summaryDate(state['critical_ack_at_utc']);
    final criticalAlertFingerprint =
        _summaryString(state['critical_alert_fingerprint']) ?? '';
    final lastCriticalAlertAt = _summaryDate(
      state['last_critical_alert_at_utc'],
    );
    final lastCriticalAlertSummary = _summaryString(
      state['last_critical_alert_summary'],
    );
    final lastCommandAt = _summaryDate(state['last_command_at_utc']);
    final lastCommandSummary = _summaryString(state['last_command_summary']);
    final commandAuditRaw = state['command_audit'];
    final commandAudit = <String>[
      if (commandAuditRaw is List)
        for (final entry in commandAuditRaw) (entry ?? '').toString().trim(),
    ].where((entry) => entry.isNotEmpty).take(40).toList(growable: false);
    final aiAssistantEnabledOverride = _summaryBool(
      state['ai_assistant_enabled_override'],
    );
    final aiApprovalRequiredOverride = _summaryBool(
      state['ai_approval_required_override'],
    );
    final aiPendingDraftsRaw = state['ai_pending_drafts'];
    final aiPendingDrafts =
        <_TelegramAiPendingDraft>[
              if (aiPendingDraftsRaw is List)
                for (final entry in aiPendingDraftsRaw)
                  if (entry is Map)
                    _TelegramAiPendingDraft.fromJson(
                      entry.cast<Object?, Object?>().map(
                        (key, value) => MapEntry(key.toString(), value),
                      ),
                    ),
            ]
            .where(
              (entry) =>
                  entry.inboundUpdateId > 0 &&
                  entry.chatId.trim().isNotEmpty &&
                  entry.draftText.trim().isNotEmpty,
            )
            .take(100)
            .toList(growable: false);
    final partnerBindingsRaw = state['partner_dispatch_bindings'];
    final partnerBindings =
        <_TelegramPartnerDispatchBinding>[
              if (partnerBindingsRaw is List)
                for (final entry in partnerBindingsRaw)
                  if (entry is Map)
                    _TelegramPartnerDispatchBinding.fromJson(
                      entry.cast<Object?, Object?>().map(
                        (key, value) => MapEntry(key.toString(), value),
                      ),
                    ),
            ]
            .where(
              (entry) =>
                  entry.chatId.trim().isNotEmpty &&
                  entry.telegramMessageId > 0 &&
                  entry.dispatchId.trim().isNotEmpty &&
                  entry.clientId.trim().isNotEmpty &&
                  entry.siteId.trim().isNotEmpty,
            )
            .take(200)
            .toList(growable: false);
    final alarmScopeBindingsRaw = state['listener_alarm_scope_bindings'];
    final alarmScopeBindings =
        <ListenerAlarmScopeMappingEntry>[
              if (alarmScopeBindingsRaw is List)
                for (final entry in alarmScopeBindingsRaw)
                  if (entry is Map)
                    ListenerAlarmScopeMappingEntry.fromJson(
                      entry.cast<Object?, Object?>().map(
                        (key, value) => MapEntry(key.toString(), value),
                      ),
                    ),
            ]
            .where(
              (entry) =>
                  entry.accountNumber.trim().isNotEmpty &&
                  entry.clientId.trim().isNotEmpty &&
                  entry.siteId.trim().isNotEmpty,
            )
            .take(500)
            .toList(growable: false);
    if (!mounted) {
      _telegramAdminPollIntervalSecondsOverride = pollOverride;
      _telegramAdminCriticalReminderSecondsOverride = reminderOverride;
      _telegramAdminExecutionEnabledOverride = executionEnabledOverride;
      _telegramAdminAllowedUserIdsOverride = allowedUserIdsOverride;
      _telegramAdminTargetClientIdOverride = targetClientOverride;
      _telegramAdminTargetSiteIdOverride = targetSiteOverride;
      _telegramAdminCriticalSnoozedUntilUtc = criticalSnoozedUntil;
      _telegramAdminCriticalAckFingerprint = criticalAckFingerprint;
      _telegramAdminCriticalAckAtUtc = criticalAckAt;
      _telegramAdminCriticalAlertFingerprint = criticalAlertFingerprint;
      _telegramAdminLastCriticalAlertAtUtc = lastCriticalAlertAt;
      _telegramAdminLastCriticalAlertSummary = lastCriticalAlertSummary;
      _telegramAdminLastCommandAtUtc = lastCommandAt;
      _telegramAdminLastCommandSummary = lastCommandSummary;
      _telegramAdminCommandAudit = commandAudit;
      _telegramAiAssistantEnabledOverride = aiAssistantEnabledOverride;
      _telegramAiApprovalRequiredOverride = aiApprovalRequiredOverride;
      _telegramAiPendingDrafts = aiPendingDrafts;
      _telegramPartnerDispatchBindings = partnerBindings;
      _listenerAlarmScopeRegistry.replaceAll(alarmScopeBindings);
      return;
    }
    setState(() {
      _telegramAdminPollIntervalSecondsOverride = pollOverride;
      _telegramAdminCriticalReminderSecondsOverride = reminderOverride;
      _telegramAdminExecutionEnabledOverride = executionEnabledOverride;
      _telegramAdminAllowedUserIdsOverride = allowedUserIdsOverride;
      _telegramAdminTargetClientIdOverride = targetClientOverride;
      _telegramAdminTargetSiteIdOverride = targetSiteOverride;
      _telegramAdminCriticalSnoozedUntilUtc = criticalSnoozedUntil;
      _telegramAdminCriticalAckFingerprint = criticalAckFingerprint;
      _telegramAdminCriticalAckAtUtc = criticalAckAt;
      _telegramAdminCriticalAlertFingerprint = criticalAlertFingerprint;
      _telegramAdminLastCriticalAlertAtUtc = lastCriticalAlertAt;
      _telegramAdminLastCriticalAlertSummary = lastCriticalAlertSummary;
      _telegramAdminLastCommandAtUtc = lastCommandAt;
      _telegramAdminLastCommandSummary = lastCommandSummary;
      _telegramAdminCommandAudit = commandAudit;
      _telegramAiAssistantEnabledOverride = aiAssistantEnabledOverride;
      _telegramAiApprovalRequiredOverride = aiApprovalRequiredOverride;
      _telegramAiPendingDrafts = aiPendingDrafts;
      _telegramPartnerDispatchBindings = partnerBindings;
      _listenerAlarmScopeRegistry.replaceAll(alarmScopeBindings);
    });
  }

  Future<void> _hydrateMonitoringWatchRuntimeState() async {
    final persistence = await _persistenceServiceFuture;
    final raw = await persistence.readMonitoringWatchRuntimeState();
    final restored = _watchRuntimeStore.parsePersistedState(raw);
    _monitoringWatchByScope
      ..clear()
      ..addAll(restored);
    if (mounted) {
      setState(() {});
    }
    if (_monitoringShiftAutoEligible) {
      unawaited(_syncMonitoringWatchScheduleNow());
    }
  }

  Future<void> _persistMonitoringWatchRuntimeState() async {
    final persistence = await _persistenceServiceFuture;
    final prepared = _watchRuntimeStore.preparePersistedState(
      _monitoringWatchByScope,
    );
    if (prepared.shouldClear) {
      await persistence.clearMonitoringWatchRuntimeState();
      return;
    }
    await persistence.saveMonitoringWatchRuntimeState(prepared.serializedState);
  }

  Future<void> _hydrateMonitoringWatchAuditState() async {
    final persistence = await _persistenceServiceFuture;
    final restored = await persistence.readMonitoringWatchAuditHistory();
    final restoredSummary = await persistence.readMonitoringWatchAuditSummary();
    final normalized = _watchRecoveryStore.restoreAuditState(
      persistedHistory: restored,
      persistedSummary: restoredSummary,
    );
    if (!mounted) {
      _monitoringWatchAuditHistory = normalized.history;
      _monitoringWatchAuditSummary = normalized.summary;
      return;
    }
    setState(() {
      _monitoringWatchAuditHistory = normalized.history;
      _monitoringWatchAuditSummary = normalized.summary;
    });
  }

  Future<void> _persistMonitoringWatchAuditSummary() async {
    final persistence = await _persistenceServiceFuture;
    final summary = _watchRecoveryStore.normalizeAuditSummaryForPersist(
      _monitoringWatchAuditSummary,
    );
    if (summary == null) {
      await persistence.clearMonitoringWatchAuditSummary();
      return;
    }
    await persistence.saveMonitoringWatchAuditSummary(summary);
  }

  Future<void> _persistMonitoringWatchAuditHistory() async {
    final persistence = await _persistenceServiceFuture;
    final prepared = _watchRecoveryStore.prepareAuditHistoryForPersist(
      auditHistory: _monitoringWatchAuditHistory,
    );
    if (prepared.shouldClear) {
      await persistence.clearMonitoringWatchAuditHistory();
      return;
    }
    if (prepared.history.length != _monitoringWatchAuditHistory.length) {
      _monitoringWatchAuditHistory = prepared.history;
    }
    await persistence.saveMonitoringWatchAuditHistory(prepared.history);
  }

  Future<void> _hydrateMonitoringWatchRecoveryState() async {
    final persistence = await _persistenceServiceFuture;
    final raw = await persistence.readMonitoringWatchRecoveryState();
    final nowUtc = DateTime.now().toUtc();
    final restore = _watchRecoveryStore.restoreState(
      raw: raw,
      auditHistory: _monitoringWatchAuditHistory,
      scopes: _watchRecoveryScopeResolver.resolve(
        scopes: _configuredDvrScopes,
        siteLabelForScope: (clientId, siteId) => _monitoringSiteProfileFor(
          clientId: clientId,
          siteId: siteId,
        ).siteName,
      ),
      nowUtc: nowUtc,
    );
    _monitoringWatchRecoveryByScope
      ..clear()
      ..addAll(restore.stateByScope);
    if (restore.shouldPersist) {
      unawaited(_persistMonitoringWatchRecoveryState());
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _hydrateMonitoringSceneReviewState() async {
    final persistence = await _persistenceServiceFuture;
    final raw = await persistence.readMonitoringSceneReviewState();
    final restored = _monitoringSceneReviewStore.parsePersistedState(raw);
    _monitoringSceneReviewByIntelligenceId
      ..clear()
      ..addAll(restored);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _persistMonitoringSceneReviewState() async {
    final persistence = await _persistenceServiceFuture;
    final prepared = _monitoringSceneReviewStore.preparePersistedState(
      _monitoringSceneReviewByIntelligenceId,
    );
    if (prepared.shouldClear) {
      await persistence.clearMonitoringSceneReviewState();
      return;
    }
    await persistence.saveMonitoringSceneReviewState(prepared.serializedState);
  }

  Future<void> _persistMonitoringWatchRecoveryState() async {
    final persistence = await _persistenceServiceFuture;
    final prepared = _watchRecoveryStore.preparePersistedState(
      stateByScope: _monitoringWatchRecoveryByScope,
      nowUtc: DateTime.now().toUtc(),
    );
    if (prepared.freshStateByScope.length !=
        _monitoringWatchRecoveryByScope.length) {
      _monitoringWatchRecoveryByScope
        ..clear()
        ..addAll(prepared.freshStateByScope);
    }
    if (prepared.shouldClear) {
      await persistence.clearMonitoringWatchRecoveryState();
      return;
    }
    await persistence.saveMonitoringWatchRecoveryState(
      prepared.serializedState,
    );
  }

  Future<void> _persistTelegramAdminRuntimeState() async {
    final persistence = await _persistenceServiceFuture;
    final state = <String, Object?>{
      if (_telegramAdminPollIntervalSecondsOverride != null)
        'poll_interval_override_seconds':
            _telegramAdminPollIntervalSecondsOverride,
      if (_telegramAdminCriticalReminderSecondsOverride != null)
        'critical_reminder_override_seconds':
            _telegramAdminCriticalReminderSecondsOverride,
      if (_telegramAdminExecutionEnabledOverride != null)
        'execution_enabled_override': _telegramAdminExecutionEnabledOverride,
      if (_telegramAdminAllowedUserIdsOverride != null)
        'allowed_user_ids_override': _telegramAdminAllowedUserIdsOverride,
      if ((_telegramAdminTargetClientIdOverride ?? '').trim().isNotEmpty)
        'target_client_override': _telegramAdminTargetClientIdOverride!.trim(),
      if ((_telegramAdminTargetSiteIdOverride ?? '').trim().isNotEmpty)
        'target_site_override': _telegramAdminTargetSiteIdOverride!.trim(),
      if (_telegramAdminCriticalSnoozedUntilUtc != null)
        'critical_snoozed_until_utc': _telegramAdminCriticalSnoozedUntilUtc!
            .toIso8601String(),
      if (_telegramAdminCriticalAckFingerprint.trim().isNotEmpty)
        'critical_ack_fingerprint': _telegramAdminCriticalAckFingerprint.trim(),
      if (_telegramAdminCriticalAckAtUtc != null)
        'critical_ack_at_utc': _telegramAdminCriticalAckAtUtc!
            .toIso8601String(),
      if (_telegramAdminCriticalAlertFingerprint.trim().isNotEmpty)
        'critical_alert_fingerprint': _telegramAdminCriticalAlertFingerprint
            .trim(),
      if (_telegramAdminLastCriticalAlertAtUtc != null)
        'last_critical_alert_at_utc': _telegramAdminLastCriticalAlertAtUtc!
            .toIso8601String(),
      if ((_telegramAdminLastCriticalAlertSummary ?? '').trim().isNotEmpty)
        'last_critical_alert_summary': _telegramAdminLastCriticalAlertSummary!
            .trim(),
      if (_telegramAdminLastCommandAtUtc != null)
        'last_command_at_utc': _telegramAdminLastCommandAtUtc!
            .toIso8601String(),
      if ((_telegramAdminLastCommandSummary ?? '').trim().isNotEmpty)
        'last_command_summary': _telegramAdminLastCommandSummary!.trim(),
      if (_telegramAdminCommandAudit.isNotEmpty)
        'command_audit': _telegramAdminCommandAudit,
      if (_telegramAiAssistantEnabledOverride != null)
        'ai_assistant_enabled_override': _telegramAiAssistantEnabledOverride,
      if (_telegramAiApprovalRequiredOverride != null)
        'ai_approval_required_override': _telegramAiApprovalRequiredOverride,
      if (_telegramAiPendingDrafts.isNotEmpty)
        'ai_pending_drafts': _telegramAiPendingDrafts
            .map((entry) => entry.toJson())
            .toList(growable: false),
      if (_telegramPartnerDispatchBindings.isNotEmpty)
        'partner_dispatch_bindings': _telegramPartnerDispatchBindings
            .map((entry) => entry.toJson())
            .toList(growable: false),
      if (_listenerAlarmScopeRegistry.allEntries().isNotEmpty)
        'listener_alarm_scope_bindings': _listenerAlarmScopeRegistry
            .allEntries()
            .map((entry) => entry.toJson())
            .toList(growable: false),
    };
    if (state.isEmpty) {
      await persistence.clearTelegramAdminRuntimeState();
      return;
    }
    await persistence.saveTelegramAdminRuntimeState(state);
  }

  Future<void> _hydrateGuardSyncState() async {
    if (!_guardSyncHistoryFilterHydrated) {
      await _hydrateGuardSyncHistoryFilter();
    }
    if (!_guardSyncOperationModeFilterHydrated) {
      await _hydrateGuardSyncOperationModeFilter();
    }
    if (!_guardSyncSelectedFacadeIdHydrated) {
      await _hydrateGuardSyncSelectedFacadeId();
    }
    if (!_guardSyncSelectedOpHydrated) {
      await _hydrateGuardSyncSelectedOperationIds();
    }
    final repository = await _guardSyncRepositoryFuture;
    await _guardMobileOpsServiceFuture;
    final queued = await repository.readQueuedOperations();
    final statusFilter = _historyStatuses(_guardSyncHistoryFilter);
    final facadeMode = _guardSyncFacadeModeValue();
    final historyForFacadeOptions = await repository.readOperations(
      statuses: statusFilter,
      limit: 500,
      facadeMode: facadeMode,
    );
    final availableFacadeIds =
        historyForFacadeOptions
            .map(_guardSyncOperationFacadeId)
            .whereType<String>()
            .toSet()
            .toList(growable: false)
          ..sort();
    final effectiveFacadeId =
        _guardSyncSelectedFacadeId == null ||
            _guardSyncSelectedFacadeId!.isEmpty ||
            availableFacadeIds.contains(_guardSyncSelectedFacadeId)
        ? _guardSyncSelectedFacadeId
        : null;
    if (effectiveFacadeId != _guardSyncSelectedFacadeId) {
      _guardSyncSelectedFacadeId = effectiveFacadeId;
      await _persistGuardSyncSelectedFacadeId();
    }
    final history = await repository.readOperations(
      statuses: _historyStatuses(_guardSyncHistoryFilter),
      limit: 120,
      facadeMode: facadeMode,
      facadeId: effectiveFacadeId,
    );
    final knownForScopedSelections = await repository.readOperations(
      statuses: _historyStatuses(GuardSyncHistoryFilter.all),
      limit: _guardSyncSelectionPruneReadLimit,
    );
    final knownOperationIds = knownForScopedSelections
        .map((operation) => operation.operationId.trim())
        .where((operationId) => operationId.isNotEmpty)
        .toSet();
    final activeScopeKey = _guardSyncSelectionScopeKey();
    final activeScopeVisibleIds = history
        .map((operation) => operation.operationId.trim())
        .where((operationId) => operationId.isNotEmpty)
        .toSet();
    final nextScopedSelections = applyGuardSyncSelectionMaintenance(
      current: _guardSyncSelectedOperationIdByFilter,
      knownOperationIds: knownOperationIds,
      fetchedOperationCount: knownForScopedSelections.length,
      fetchLimit: _guardSyncSelectionPruneReadLimit,
      activeScopeKey: activeScopeKey,
      activeScopeVisibleOperationIds: activeScopeVisibleIds,
    );
    if (!guardSyncSelectionScopesEqual(
      nextScopedSelections,
      _guardSyncSelectedOperationIdByFilter,
    )) {
      _guardSyncSelectedOperationIdByFilter = nextScopedSelections;
      await _persistGuardSyncSelectedOperationIds();
    }
    if (!mounted) return;
    setState(() {
      _guardQueuedOperations = history;
      _guardSyncQueueDepth = queued.length;
      _guardSyncUsingBackend = widget.supabaseReady;
      _guardSyncAvailableFacadeIds = availableFacadeIds;
      _guardSyncSelectedFacadeId = effectiveFacadeId;
    });
  }

  Future<void> _hydrateGuardSyncHistoryFilter() async {
    final persistence = await _persistenceServiceFuture;
    final raw = await persistence.readGuardSyncHistoryFilter();
    GuardSyncHistoryFilter? restored;
    for (final value in GuardSyncHistoryFilter.values) {
      if (value.name == raw) {
        restored = value;
        break;
      }
    }
    _guardSyncHistoryFilterHydrated = true;
    if (restored == null || !mounted) {
      return;
    }
    setState(() {
      _guardSyncHistoryFilter = restored!;
    });
  }

  Future<void> _persistGuardSyncHistoryFilter() async {
    final persistence = await _persistenceServiceFuture;
    await persistence.saveGuardSyncHistoryFilter(_guardSyncHistoryFilter.name);
  }

  Future<void> _hydrateGuardSyncOperationModeFilter() async {
    final persistence = await _persistenceServiceFuture;
    final raw = await persistence.readGuardSyncOperationModeFilter();
    GuardSyncOperationModeFilter? restored;
    for (final value in GuardSyncOperationModeFilter.values) {
      if (value.name == raw) {
        restored = value;
        break;
      }
    }
    _guardSyncOperationModeFilterHydrated = true;
    if (restored == null || !mounted) {
      return;
    }
    setState(() {
      _guardSyncOperationModeFilter = restored!;
    });
  }

  Future<void> _persistGuardSyncOperationModeFilter() async {
    final persistence = await _persistenceServiceFuture;
    await persistence.saveGuardSyncOperationModeFilter(
      _guardSyncOperationModeFilter.name,
    );
  }

  Future<void> _hydrateGuardSyncSelectedFacadeId() async {
    final persistence = await _persistenceServiceFuture;
    final restored = await persistence.readGuardSyncSelectedFacadeId();
    final normalized = restored?.trim();
    final effective = (normalized == null || normalized.isEmpty)
        ? null
        : normalized;
    if (effective != restored) {
      await persistence.saveGuardSyncSelectedFacadeId(effective);
    }
    _guardSyncSelectedFacadeIdHydrated = true;
    if (!mounted || effective == null) return;
    setState(() {
      _guardSyncSelectedFacadeId = effective;
    });
  }

  Future<void> _persistGuardSyncSelectedFacadeId() async {
    final persistence = await _persistenceServiceFuture;
    await persistence.saveGuardSyncSelectedFacadeId(_guardSyncSelectedFacadeId);
  }

  Future<void> _hydrateGuardSyncSelectedOperationIds() async {
    final persistence = await _persistenceServiceFuture;
    final restored = await persistence.readGuardSyncSelectedOperationIds();
    final migrated = migrateLegacyGuardSyncSelectionScopes(restored);
    if (!guardSyncSelectionScopesEqual(migrated, restored)) {
      await persistence.saveGuardSyncSelectedOperationIds(migrated);
    }
    _guardSyncSelectedOpHydrated = true;
    if (!mounted || migrated.isEmpty) return;
    setState(() {
      _guardSyncSelectedOperationIdByFilter = migrated;
    });
  }

  Future<void> _persistGuardSyncSelectedOperationIds() async {
    final persistence = await _persistenceServiceFuture;
    await persistence.saveGuardSyncSelectedOperationIds(
      _guardSyncSelectedOperationIdByFilter,
    );
  }

  Set<GuardSyncOperationStatus> _historyStatuses(
    GuardSyncHistoryFilter filter,
  ) {
    switch (filter) {
      case GuardSyncHistoryFilter.queued:
        return const {GuardSyncOperationStatus.queued};
      case GuardSyncHistoryFilter.synced:
        return const {GuardSyncOperationStatus.synced};
      case GuardSyncHistoryFilter.failed:
        return const {GuardSyncOperationStatus.failed};
      case GuardSyncHistoryFilter.all:
        return const {
          GuardSyncOperationStatus.queued,
          GuardSyncOperationStatus.synced,
          GuardSyncOperationStatus.failed,
        };
    }
  }

  String? _guardSyncFacadeModeValue() {
    return switch (_guardSyncOperationModeFilter) {
      GuardSyncOperationModeFilter.live => 'live',
      GuardSyncOperationModeFilter.stub => 'stub',
      GuardSyncOperationModeFilter.unknown => 'unknown',
      GuardSyncOperationModeFilter.all => null,
    };
  }

  String? _guardSyncOperationFacadeId(GuardSyncOperation operation) {
    final raw = operation.payload['onyx_runtime_context'];
    if (raw is! Map) return null;
    final context = raw.map((key, value) => MapEntry(key.toString(), value));
    final value = context['telemetry_facade_id'];
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _setGuardHistoryFilter(GuardSyncHistoryFilter filter) async {
    if (_guardSyncHistoryFilter == filter) return;
    if (mounted) {
      setState(() {
        _guardSyncHistoryFilter = filter;
      });
    } else {
      _guardSyncHistoryFilter = filter;
    }
    await _persistGuardSyncHistoryFilter();
    await _hydrateGuardSyncState();
  }

  Future<void> _setGuardOperationModeFilter(
    GuardSyncOperationModeFilter filter,
  ) async {
    if (_guardSyncOperationModeFilter == filter) return;
    if (mounted) {
      setState(() {
        _guardSyncOperationModeFilter = filter;
      });
    } else {
      _guardSyncOperationModeFilter = filter;
    }
    await _persistGuardSyncOperationModeFilter();
    await _hydrateGuardSyncState();
  }

  Future<void> _setGuardFacadeIdFilter(String? facadeId) async {
    final next = facadeId?.trim();
    final normalized = (next == null || next.isEmpty) ? null : next;
    if (_guardSyncSelectedFacadeId == normalized) return;
    if (mounted) {
      setState(() {
        _guardSyncSelectedFacadeId = normalized;
      });
    } else {
      _guardSyncSelectedFacadeId = normalized;
    }
    await _persistGuardSyncSelectedFacadeId();
    await _hydrateGuardSyncState();
  }

  Future<void> _setGuardSelectedOperation(String? operationId) async {
    final next = setGuardSyncSelectionForScope(
      current: _guardSyncSelectedOperationIdByFilter,
      scopeKey: _guardSyncSelectionScopeKey(),
      operationId: operationId,
    );
    if (guardSyncSelectionScopesEqual(
      next,
      _guardSyncSelectedOperationIdByFilter,
    )) {
      return;
    }
    if (mounted) {
      setState(() {
        _guardSyncSelectedOperationIdByFilter = next;
      });
    } else {
      _guardSyncSelectedOperationIdByFilter = next;
    }
    await _persistGuardSyncSelectedOperationIds();
  }

  String _guardSyncSelectionScopeKey() {
    return guardSyncSelectionScopeKey(
      historyFilter: _guardSyncHistoryFilter.name,
      operationModeFilter: _guardSyncOperationModeFilter.name,
      facadeId: _guardSyncSelectedFacadeId,
    );
  }

  Future<void> _hydrateGuardOpsState() async {
    final repository = await _guardOpsRepositoryFuture;
    final activeShiftId = _activeGuardShiftId;
    final pendingEvents = await repository.pendingEvents();
    final pendingMedia = await repository.pendingMedia();
    final failedEvents = await repository.failedEvents();
    final failedMedia = await repository.failedMedia();
    final recentEvents = await repository.recentEvents(limit: 10);
    final recentMedia = await repository.recentMedia(limit: 10);
    final shiftSequenceWatermark = await repository.shiftSequenceWatermark(
      activeShiftId,
    );
    if (!mounted) return;
    setState(() {
      _guardOpsPendingEvents = pendingEvents.length;
      _guardOpsPendingMedia = pendingMedia.length;
      _guardOpsFailedEvents = failedEvents.length;
      _guardOpsFailedMedia = failedMedia.length;
      _guardOpsRecentEvents = recentEvents;
      _guardOpsRecentMedia = recentMedia;
      _guardOpsActiveShiftId = activeShiftId;
      _guardOpsActiveShiftSequenceWatermark = shiftSequenceWatermark;
    });
    await _maybeAutoGenerateMorningSovereignReport();
  }

  Future<void> _hydrateOfflineIncidentSpoolState() async {
    final persistence = await _persistenceServiceFuture;
    final state = await persistence.readOfflineIncidentSpoolSyncState();
    if (!mounted) return;
    setState(() {
      _offlineIncidentSpoolStatusLabel = state.statusLabel.trim().isEmpty
          ? 'idle'
          : state.statusLabel.trim();
      _offlineIncidentSpoolPendingCount = state.pendingCount < 0
          ? 0
          : state.pendingCount;
      _offlineIncidentSpoolRetryCount = state.retryCount < 0
          ? 0
          : state.retryCount;
      _offlineIncidentSpoolLastQueuedAtUtc = state.lastQueuedAtUtc;
      _offlineIncidentSpoolLastSyncedAtUtc = state.lastSyncedAtUtc;
      final failureReason = state.failureReason?.trim() ?? '';
      _offlineIncidentSpoolFailureReason = failureReason.isEmpty
          ? null
          : failureReason;
      _offlineIncidentSpoolHistory = state.history;
    });
  }

  Future<void> _hydrateOfflineIncidentSpoolReplayAudit() async {
    final persistence = await _persistenceServiceFuture;
    final raw = await persistence.readOfflineIncidentSpoolReplayAudit();
    if (!mounted) return;
    setState(() {
      _offlineIncidentSpoolReplayAudit = raw;
    });
  }

  String _offlineIncidentSpoolSummary() {
    final parts = <String>[
      _offlineIncidentSpoolStatusLabel.trim().isEmpty
          ? 'idle'
          : _offlineIncidentSpoolStatusLabel.trim(),
      _offlineIncidentSpoolPendingCount == 1
          ? '1 pending'
          : '$_offlineIncidentSpoolPendingCount pending',
      'retry $_offlineIncidentSpoolRetryCount',
    ];
    if (_offlineIncidentSpoolLastQueuedAtUtc != null) {
      parts.add(
        'queued ${_offlineIncidentSpoolLastQueuedAtUtc!.toIso8601String()}',
      );
    }
    if (_offlineIncidentSpoolLastSyncedAtUtc != null) {
      parts.add(
        'synced ${_offlineIncidentSpoolLastSyncedAtUtc!.toIso8601String()}',
      );
    }
    final failure = (_offlineIncidentSpoolFailureReason ?? '').trim();
    if (failure.isNotEmpty) {
      parts.add('fail $failure');
    }
    if (_offlineIncidentSpoolHistory.isNotEmpty) {
      final lastHistory = _offlineIncidentSpoolHistory.last.trim();
      if (lastHistory.isNotEmpty) {
        parts.add(lastHistory);
      }
    }
    return parts.join(' • ');
  }

  String? _offlineIncidentSpoolReplaySummary() {
    final replayedAtRaw =
        (_offlineIncidentSpoolReplayAudit['replayed_at_utc'] ?? '')
            .toString()
            .trim();
    final replayedAt = DateTime.tryParse(replayedAtRaw)?.toUtc();
    final syncedCount =
        (_offlineIncidentSpoolReplayAudit['synced_count'] as num?)?.toInt() ??
        0;
    final firstIncident =
        (_offlineIncidentSpoolReplayAudit['first_incident_reference'] ?? '')
            .toString()
            .trim();
    final lastIncident =
        (_offlineIncidentSpoolReplayAudit['last_incident_reference'] ?? '')
            .toString()
            .trim();
    final transport = (_offlineIncidentSpoolReplayAudit['transport'] ?? '')
        .toString()
        .trim();
    if (replayedAt == null && syncedCount <= 0 && lastIncident.isEmpty) {
      return null;
    }
    final parts = <String>[
      syncedCount == 1 ? '1 replayed' : '$syncedCount replayed',
      if (transport.isNotEmpty) transport,
      if (firstIncident.isNotEmpty) 'first $firstIncident',
      if (lastIncident.isNotEmpty) 'last $lastIncident',
      if (replayedAt != null) replayedAt.toIso8601String(),
    ];
    return parts.join(' • ');
  }

  Future<void> _recordOfflineIncidentSpoolReplayAudit(
    OfflineIncidentSpoolSyncResult result,
  ) async {
    if (result.syncedEntries.isEmpty) {
      return;
    }
    final ordered = [...result.syncedEntries]
      ..sort((a, b) {
        final ts = a.createdAtUtc.compareTo(b.createdAtUtc);
        if (ts != 0) return ts;
        return a.entryId.compareTo(b.entryId);
      });
    final audit = <String, Object?>{
      'replayed_at_utc': DateTime.now().toUtc().toIso8601String(),
      'transport': widget.supabaseReady ? 'client_ledger' : 'disabled',
      'synced_count': ordered.length,
      'first_incident_reference': ordered.first.incidentReference,
      'last_incident_reference': ordered.last.incidentReference,
      'site_id': ordered.last.siteId,
      'client_id': ordered.last.clientId,
      'ledger_dispatch_ids': ordered
          .map(
            (entry) =>
                LedgerBackedOfflineIncidentSpoolRemoteGateway.ledgerDispatchIdFor(
                  entry.entryId,
                ),
          )
          .toList(growable: false),
    };
    final persistence = await _persistenceServiceFuture;
    await persistence.saveOfflineIncidentSpoolReplayAudit(audit);
    if (!mounted) return;
    setState(() {
      _offlineIncidentSpoolReplayAudit = audit;
    });
  }

  void _startGuardOpsSyncLoop() {
    _guardOpsSyncTimer?.cancel();
    if (!widget.supabaseReady) return;
    _scheduleGuardOpsSync(delaySeconds: _guardOpsBaseSyncIntervalSeconds);
  }

  void _startOfflineIncidentSpoolSyncLoop() {
    _offlineIncidentSpoolSyncTimer?.cancel();
    if (!widget.supabaseReady) return;
    _scheduleOfflineIncidentSpoolSync(
      delaySeconds: _offlineIncidentSpoolBaseSyncIntervalSeconds,
    );
  }

  void _scheduleGuardOpsSync({required int delaySeconds}) {
    _guardOpsSyncTimer?.cancel();
    _guardOpsSyncTimer = Timer(Duration(seconds: delaySeconds), () async {
      await _syncGuardOpsNow(background: true);
    });
  }

  void _scheduleOfflineIncidentSpoolSync({required int delaySeconds}) {
    _offlineIncidentSpoolSyncTimer?.cancel();
    _offlineIncidentSpoolSyncTimer = Timer(
      Duration(seconds: delaySeconds),
      () async {
        await _syncOfflineIncidentSpoolNow(background: true);
      },
    );
  }

  int _guardOpsBackoffDelaySeconds(int failures) {
    final multiplier = 1 << failures;
    final delayed = _guardOpsBaseSyncIntervalSeconds * multiplier;
    if (delayed > 300) {
      return 300;
    }
    return delayed;
  }

  int _offlineIncidentSpoolBackoffDelaySeconds(int failures) {
    final multiplier = 1 << failures.clamp(0, 3);
    final delayed = _offlineIncidentSpoolBaseSyncIntervalSeconds * multiplier;
    return math.min(delayed, 300);
  }

  Future<void> _syncOfflineIncidentSpoolNow({bool background = false}) async {
    if (!widget.supabaseReady || _offlineIncidentSpoolSyncInFlight) {
      return;
    }
    _offlineIncidentSpoolSyncInFlight = true;
    try {
      final service = await _offlineIncidentSpoolServiceFuture;
      final result = await service.syncPendingEntries(batchSize: 25);
      await _recordOfflineIncidentSpoolReplayAudit(result);
      await _hydrateOfflineIncidentSpoolState();
      if (result.failureReason == null) {
        _offlineIncidentSpoolSyncFailures = 0;
      } else {
        _offlineIncidentSpoolSyncFailures += 1;
      }
    } catch (_) {
      _offlineIncidentSpoolSyncFailures += 1;
      await _hydrateOfflineIncidentSpoolState();
    } finally {
      _offlineIncidentSpoolSyncInFlight = false;
      if (widget.supabaseReady) {
        _scheduleOfflineIncidentSpoolSync(
          delaySeconds: _offlineIncidentSpoolBackoffDelaySeconds(
            _offlineIncidentSpoolSyncFailures,
          ),
        );
      }
      if (!background) {
        await _hydrateOfflineIncidentSpoolState();
      }
    }
  }

  String get _activeGuardShiftId {
    final now = DateTime.now().toUtc();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return 'SHIFT-${now.year}$month$day-GUARD-001';
  }

  Future<void> _enqueueGuardOpsEvent({
    required GuardOpsEventType type,
    required Map<String, Object?> payload,
  }) async {
    final repository = await _guardOpsRepositoryFuture;
    final mergedPayload = _withGuardActorContext(payload);
    await repository.enqueueEvent(
      guardId: 'GUARD-001',
      siteId: _selectedSite,
      shiftId: _activeGuardShiftId,
      eventType: type,
      deviceId: 'ANDROID-BV5300PRO-001',
      appVersion: 'guard-shell-v1',
      payload: mergedPayload,
      occurredAt: DateTime.now().toUtc(),
    );
    await _hydrateGuardOpsState();
  }

  Map<String, Object?> _withGuardActorContext(Map<String, Object?> payload) {
    final merged = Map<String, Object?>.from(payload);
    merged.putIfAbsent(
      GuardEventContractKeys.actorRole,
      () => _guardOperatorRole.name,
    );
    merged.putIfAbsent(GuardEventContractKeys.actorGuardId, () => 'GUARD-001');
    merged.putIfAbsent(
      GuardEventContractKeys.actorClientId,
      () => _selectedClient,
    );
    merged.putIfAbsent(GuardEventContractKeys.actorSiteId, () => _selectedSite);
    merged.putIfAbsent(
      GuardEventContractKeys.actorShiftId,
      () => _activeGuardShiftId,
    );
    return merged;
  }

  Future<void> _queueShiftStartVerification() async {
    final capture = await _guardMediaCapture.captureImage(
      purpose: 'shift_verification',
    );
    if (capture == null) {
      throw StateError(
        'Shift verification image is required before shift start.',
      );
    }
    final quality = await _guardMediaQualityEvaluator.assess(
      capture,
      purpose: 'shift_verification',
    );
    _ensureAcceptableCapture(
      quality,
      purpose: 'shift verification',
      checkpointId: null,
    );
    final repository = await _guardOpsRepositoryFuture;
    final now = DateTime.now().toUtc();
    final visualNorm = _buildVisualNormMetadata(
      capture: capture,
      purpose: 'shift_verification',
      capturedAtUtc: now,
      baselineId: 'NORM-SHIFT-SELF-V1',
    );
    final verificationEvent = await repository.enqueueEvent(
      guardId: 'GUARD-001',
      siteId: _selectedSite,
      shiftId: _activeGuardShiftId,
      eventType: GuardOpsEventType.shiftVerificationImage,
      deviceId: 'ANDROID-BV5300PRO-001',
      appVersion: 'guard-shell-v1',
      payload: _withGuardActorContext({
        'camera_mode': 'self_verification',
        'uniform_check_required': true,
        'quality_gate_required': true,
        'quality_gate': {
          'accepted': quality.accepted,
          'issues': quality.issues.map((issue) => issue.name).toList(),
          'method': quality.method,
        },
        'visual_norm': visualNorm.toJson(),
      }),
      occurredAt: now,
    );
    await repository.enqueueMedia(
      GuardOpsMediaUpload(
        mediaId: 'MEDIA-${now.millisecondsSinceEpoch}',
        eventId: verificationEvent.eventId,
        guardId: 'GUARD-001',
        siteId: _selectedSite,
        shiftId: _activeGuardShiftId,
        bucket: 'guard-shift-verification',
        path:
            'guards/GUARD-001/shift/${now.millisecondsSinceEpoch}-${capture.fileName}',
        localPath: capture.localPath,
        capturedAt: now,
        visualNorm: visualNorm,
      ),
    );
    await repository.enqueueEvent(
      guardId: 'GUARD-001',
      siteId: _selectedSite,
      shiftId: _activeGuardShiftId,
      eventType: GuardOpsEventType.shiftStart,
      deviceId: 'ANDROID-BV5300PRO-001',
      appVersion: 'guard-shell-v1',
      payload: _withGuardActorContext({
        'verification_event_id': verificationEvent.eventId,
      }),
      occurredAt: now,
    );
    await _hydrateGuardOpsState();
  }

  Future<void> _queueShiftEnd() async {
    await _enqueueGuardOpsEvent(
      type: GuardOpsEventType.shiftEnd,
      payload: {'source': 'guard_shell', 'event': 'shift_end_requested'},
    );
    await _hydrateGuardSyncState();
  }

  Future<void> _queuePatrolVerificationImage({
    required String checkpointId,
  }) async {
    final capture = await _guardMediaCapture.captureImage(
      purpose: 'patrol_verification',
      checkpointId: checkpointId,
    );
    if (capture == null) {
      throw StateError(
        'Patrol verification image is required for checkpoint $checkpointId.',
      );
    }
    final quality = await _guardMediaQualityEvaluator.assess(
      capture,
      purpose: 'patrol_verification',
      checkpointId: checkpointId,
    );
    _ensureAcceptableCapture(
      quality,
      purpose: 'patrol verification',
      checkpointId: checkpointId,
    );
    final repository = await _guardOpsRepositoryFuture;
    final now = DateTime.now().toUtc();
    final visualNorm = _buildVisualNormMetadata(
      capture: capture,
      purpose: 'patrol_verification',
      capturedAtUtc: now,
      baselineId: 'NORM-PATROL-${checkpointId.toUpperCase()}-V1',
    );
    final patrolEvent = await repository.enqueueEvent(
      guardId: 'GUARD-001',
      siteId: _selectedSite,
      shiftId: _activeGuardShiftId,
      eventType: GuardOpsEventType.patrolImageCaptured,
      deviceId: 'ANDROID-BV5300PRO-001',
      appVersion: 'guard-shell-v1',
      payload: _withGuardActorContext({
        'checkpoint_id': checkpointId,
        'verification_required': true,
        'quality_gate': {
          'accepted': quality.accepted,
          'issues': quality.issues.map((issue) => issue.name).toList(),
          'method': quality.method,
        },
        'visual_norm': visualNorm.toJson(),
      }),
      occurredAt: now,
    );
    await repository.enqueueMedia(
      GuardOpsMediaUpload(
        mediaId: 'MEDIA-${now.millisecondsSinceEpoch}',
        eventId: patrolEvent.eventId,
        guardId: 'GUARD-001',
        siteId: _selectedSite,
        shiftId: _activeGuardShiftId,
        bucket: 'guard-patrol-images',
        path:
            'guards/GUARD-001/patrol/${checkpointId.toLowerCase()}-${now.millisecondsSinceEpoch}-${capture.fileName}',
        localPath: capture.localPath,
        capturedAt: now,
        visualNorm: visualNorm,
      ),
    );
    await _hydrateGuardOpsState();
  }

  void _ensureAcceptableCapture(
    GuardMediaQualityAssessment quality, {
    required String purpose,
    required String? checkpointId,
  }) {
    if (quality.accepted) return;
    final issueNames = quality.issues.map((issue) => issue.name).join(', ');
    final scope = checkpointId == null
        ? purpose
        : '$purpose at checkpoint $checkpointId';
    throw StateError(
      'Image quality check failed for $scope: $issueNames. Retake with clear focus, better lighting, and reduced glare.',
    );
  }

  GuardVisualNormMetadata _buildVisualNormMetadata({
    required GuardMediaCaptureResult capture,
    required String purpose,
    required DateTime capturedAtUtc,
    required String baselineId,
  }) {
    final mode = _resolveVisualNormMode(
      capture: capture,
      capturedAtUtc: capturedAtUtc,
    );
    final combatWindow = _isCombatWindow(capturedAtUtc);
    final minMatchScore = switch (mode) {
      GuardVisualNormMode.day => purpose == 'shift_verification' ? 94 : 92,
      GuardVisualNormMode.night => purpose == 'shift_verification' ? 88 : 86,
      GuardVisualNormMode.ir => purpose == 'shift_verification' ? 84 : 82,
    };
    return GuardVisualNormMetadata(
      mode: mode,
      baselineId: baselineId,
      captureProfile: purpose,
      minMatchScore: minMatchScore,
      irRequired: mode == GuardVisualNormMode.ir,
      combatWindow: combatWindow,
    );
  }

  GuardVisualNormMode _resolveVisualNormMode({
    required GuardMediaCaptureResult capture,
    required DateTime capturedAtUtc,
  }) {
    final fingerprint = '${capture.fileName} ${capture.localPath}'
        .toLowerCase()
        .trim();
    final irTagged = RegExp(
      r'(^|[^a-z])(ir|infrared|thermal)([^a-z]|$)',
    ).hasMatch(fingerprint);
    if (irTagged) {
      return GuardVisualNormMode.ir;
    }
    if (_isCombatWindow(capturedAtUtc)) {
      return GuardVisualNormMode.night;
    }
    return GuardVisualNormMode.day;
  }

  bool _isCombatWindow(DateTime timestampUtc) {
    final hour = timestampUtc.toLocal().hour;
    return hour >= 22 || hour < 6;
  }

  Future<void> _syncGuardOpsNow({bool background = false}) async {
    if (_guardOpsSyncInFlight) return;
    final repository = await _guardOpsRepositoryFuture;
    if (mounted) {
      setState(() {
        _guardOpsSyncInFlight = true;
      });
    }
    try {
      final eventResult = await repository.syncPendingEvents(batchSize: 200);
      final mediaResult = await repository.uploadPendingMedia(batchSize: 40);
      await _hydrateGuardOpsState();
      final hasFailure =
          eventResult.failedCount > 0 || mediaResult.failedCount > 0;
      final label = hasFailure
          ? 'Guard sync partial failure: events failed ${eventResult.failedCount}, media failed ${mediaResult.failedCount}.'
          : 'Guard sync complete: events ${eventResult.syncedCount}, media ${mediaResult.syncedCount}.';
      if (mounted) {
        setState(() {
          _guardOpsSyncFailures = hasFailure ? _guardOpsSyncFailures + 1 : 0;
          _guardOpsLastSyncLabel = label;
          if (hasFailure) {
            _guardOpsLastFailureReason =
                eventResult.failureReason ?? mediaResult.failureReason ?? label;
          } else {
            _guardOpsLastSuccessfulSyncAtUtc = DateTime.now().toUtc();
            _guardOpsLastFailureReason = null;
          }
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _guardOpsSyncFailures += 1;
          _guardOpsLastSyncLabel = 'Guard sync failed: $error';
          _guardOpsLastFailureReason = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _guardOpsSyncInFlight = false;
        });
      }
      if (widget.supabaseReady) {
        final nextDelay = _guardOpsBackoffDelaySeconds(_guardOpsSyncFailures);
        _scheduleGuardOpsSync(delaySeconds: nextDelay);
      }
      if (!background) {
        await _hydrateGuardOpsState();
      }
    }
  }

  Future<void> _retryFailedGuardMedia() async {
    final repository = await _guardOpsRepositoryFuture;
    final retried = await repository.retryFailedMedia();
    if (mounted) {
      setState(() {
        _guardOpsLastSyncLabel = retried > 0
            ? 'Retry queued for $retried failed media upload(s).'
            : 'No failed media uploads to retry.';
      });
    }
    await _hydrateGuardOpsState();
  }

  Future<void> _retryFailedGuardEvents() async {
    final repository = await _guardOpsRepositoryFuture;
    final retried = await repository.retryFailedEvents();
    if (mounted) {
      setState(() {
        _guardOpsLastSyncLabel = retried > 0
            ? 'Retry queued for $retried failed event(s).'
            : 'No failed events to retry.';
      });
    }
    await _hydrateGuardOpsState();
  }

  GuardAssignment get _defaultGuardAssignment => GuardAssignment(
    assignmentId: 'ASSIGN-ANDROID-001',
    dispatchId: 'DISP-ANDROID-001',
    clientId: _selectedClient,
    siteId: _selectedSite,
    guardId: 'GUARD-001',
    issuedAt: DateTime.now().toUtc(),
    status: GuardDutyStatus.available,
  );

  Future<void> _queueGuardStatus(GuardDutyStatus status) async {
    final service = await _guardMobileOpsServiceFuture;
    await service.updateStatus(
      assignment: _defaultGuardAssignment,
      status: status,
      occurredAt: DateTime.now().toUtc(),
    );
    await _enqueueGuardOpsEvent(
      type: GuardOpsEventType.statusChanged,
      payload: {
        'assignment_id': _defaultGuardAssignment.assignmentId,
        'dispatch_id': _defaultGuardAssignment.dispatchId,
        'status': status.name,
      },
    );
    await _hydrateGuardSyncState();
  }

  Future<void> _queueReactionIncidentAccepted() async {
    await _queueGuardStatus(GuardDutyStatus.enRoute);
    await _enqueueGuardOpsEvent(
      type: GuardOpsEventType.reactionIncidentAccepted,
      payload: {
        'assignment_id': _defaultGuardAssignment.assignmentId,
        'dispatch_id': _defaultGuardAssignment.dispatchId,
        'status': GuardDutyStatus.enRoute.name,
        GuardEventContractKeys.actorRole: GuardMobileOperatorRole.reaction.name,
      },
    );
    await _hydrateGuardSyncState();
  }

  Future<void> _queueReactionOfficerArrived() async {
    await _queueGuardStatus(GuardDutyStatus.onSite);
    await _enqueueGuardOpsEvent(
      type: GuardOpsEventType.reactionOfficerArrived,
      payload: {
        'assignment_id': _defaultGuardAssignment.assignmentId,
        'dispatch_id': _defaultGuardAssignment.dispatchId,
        'status': GuardDutyStatus.onSite.name,
        GuardEventContractKeys.actorRole: GuardMobileOperatorRole.reaction.name,
      },
    );
    await _hydrateGuardSyncState();
  }

  Future<void> _queueReactionIncidentCleared() async {
    await _queueGuardStatus(GuardDutyStatus.clear);
    await _enqueueGuardOpsEvent(
      type: GuardOpsEventType.reactionIncidentCleared,
      payload: {
        'assignment_id': _defaultGuardAssignment.assignmentId,
        'dispatch_id': _defaultGuardAssignment.dispatchId,
        'status': GuardDutyStatus.clear.name,
        GuardEventContractKeys.actorRole: GuardMobileOperatorRole.reaction.name,
      },
    );
    await _hydrateGuardSyncState();
  }

  Future<void> _queueSupervisorStatusOverride(GuardDutyStatus status) async {
    await _queueGuardStatus(status);
    await _enqueueGuardOpsEvent(
      type: GuardOpsEventType.supervisorStatusOverride,
      payload: {
        'assignment_id': _defaultGuardAssignment.assignmentId,
        'dispatch_id': _defaultGuardAssignment.dispatchId,
        'status': status.name,
        GuardEventContractKeys.actorRole:
            GuardMobileOperatorRole.supervisor.name,
      },
    );
    await _hydrateGuardSyncState();
  }

  Future<void> _queueSupervisorCoachingAcknowledgement() async {
    await _enqueueGuardOpsEvent(
      type: GuardOpsEventType.supervisorCoachingAcknowledged,
      payload: {
        GuardEventContractKeys.actorRole:
            GuardMobileOperatorRole.supervisor.name,
        'rule_id': _effectiveGuardCoachingPrompt(
          prompt: _guardSyncCoachingPolicy.evaluate(
            syncBackendEnabled: _guardSyncUsingBackend,
            pendingEventCount: _guardOpsPendingEvents,
            pendingMediaCount: _guardOpsPendingMedia,
            failedEventCount: _guardOpsFailedEvents,
            failedMediaCount: _guardOpsFailedMedia,
            recentEvents: _guardOpsRecentEvents,
            nowUtc: DateTime.now().toUtc(),
          ),
          nowUtc: DateTime.now().toUtc(),
        ).ruleId,
        'context': 'dispatch',
      },
    );
    await _hydrateGuardSyncState();
  }

  Future<void> _queueGuardCheckpoint({
    required String checkpointId,
    required String nfcTagId,
  }) async {
    final service = await _guardMobileOpsServiceFuture;
    await service.recordCheckpointScan(
      GuardCheckpointScan(
        scanId: 'SCAN-${DateTime.now().toUtc().millisecondsSinceEpoch}',
        guardId: 'GUARD-001',
        clientId: _selectedClient,
        siteId: _selectedSite,
        checkpointId: checkpointId,
        nfcTagId: nfcTagId,
        latitude: -26.1076,
        longitude: 28.0567,
        scannedAt: DateTime.now().toUtc(),
      ),
    );
    await _enqueueGuardOpsEvent(
      type: GuardOpsEventType.checkpointScanned,
      payload: {'checkpoint_id': checkpointId, 'nfc_tag_id': nfcTagId},
    );
    await _hydrateGuardSyncState();
  }

  Future<void> _queueGuardPanicSignal() async {
    final service = await _guardMobileOpsServiceFuture;
    await service.triggerPanic(
      GuardPanicSignal(
        signalId: 'PANIC-${DateTime.now().toUtc().millisecondsSinceEpoch}',
        guardId: 'GUARD-001',
        clientId: _selectedClient,
        siteId: _selectedSite,
        latitude: -26.1076,
        longitude: 28.0567,
        triggeredAt: DateTime.now().toUtc(),
      ),
    );
    await _enqueueGuardOpsEvent(
      type: GuardOpsEventType.panicTriggered,
      payload: const {'trigger_source': 'guard_shell'},
    );
    await _hydrateGuardSyncState();
  }

  Future<void> _queueWearableHeartbeat() async {
    final sample = await _guardTelemetryAdapter.captureWearableHeartbeat();
    await _mirrorWearableHeartbeatToBridge(sample);
    await _enqueueGuardOpsEvent(
      type: GuardOpsEventType.wearableHeartbeat,
      payload: {
        'heart_rate': sample.heartRate,
        'movement_level': sample.movementLevel,
        'activity_state': sample.activityState,
        'battery_percent': sample.batteryPercent,
        'captured_at': sample.capturedAtUtc.toIso8601String(),
        'source': sample.source,
        'provider_id': sample.providerId,
        'sdk_status': sample.sdkStatus,
        'adapter': _guardTelemetryAdapter.adapterLabel,
        'adapter_stub_mode': _guardTelemetryAdapter.isStub,
      },
    );
    await _hydrateGuardSyncState();
    await _refreshGuardTelemetryAdapterStatus();
  }

  Future<void> _queueDeviceHealthTelemetry() async {
    final sample = await _guardTelemetryAdapter.captureDeviceHealth();
    await _enqueueGuardOpsEvent(
      type: GuardOpsEventType.deviceHealth,
      payload: {
        'battery_percent': sample.batteryPercent,
        'gps_accuracy_meters': sample.gpsAccuracyMeters,
        'storage_available_mb': sample.storageAvailableMb,
        'network_state': sample.networkState,
        'device_temperature_c': sample.deviceTemperatureC,
        'captured_at': sample.capturedAtUtc.toIso8601String(),
        'source': sample.source,
        'provider_id': sample.providerId,
        'sdk_status': sample.sdkStatus,
        'adapter': _guardTelemetryAdapter.adapterLabel,
        'adapter_stub_mode': _guardTelemetryAdapter.isStub,
      },
    );
    await _hydrateGuardSyncState();
    await _refreshGuardTelemetryAdapterStatus();
  }

  Future<void> _mirrorWearableHeartbeatToBridge(
    WearableTelemetrySample sample,
  ) async {
    try {
      await _guardTelemetryBridgeWriter.writeWearableHeartbeat(sample: sample);
    } catch (error) {
      debugPrint('Wearable bridge mirror failed: $error');
    }
  }

  Future<void> _seedWearableBridgeSample() async {
    if (!_guardTelemetryBridgeWriter.isAvailable) {
      throw StateError('Wearable bridge writer is unavailable.');
    }
    final nowUtc = DateTime.now().toUtc();
    await _guardTelemetryBridgeWriter.writeWearableHeartbeat(
      sample: WearableTelemetrySample(
        heartRate: 76,
        movementLevel: 0.71,
        activityState: 'patrolling',
        batteryPercent: 89,
        capturedAtUtc: nowUtc,
        source: 'onyx_guard_manual_bridge_seed',
        providerId: _guardTelemetryNativeProviderId,
        sdkStatus: 'live',
      ),
      gpsAccuracyMeters: 4.0,
    );
    await _refreshGuardTelemetryAdapterStatus();
  }

  Future<void> _emitDebugTelemetrySdkHeartbeatBroadcast() async {
    final adapter = _guardTelemetryAdapter;
    if (!kDebugMode ||
        kIsWeb ||
        adapter is! NativeGuardTelemetryIngestionAdapter) {
      throw StateError(
        'Debug SDK heartbeat broadcast is only available for native adapter debug builds.',
      );
    }
    await adapter.emitDebugSdkHeartbeatBroadcast();
    await _refreshGuardTelemetryAdapterStatus();
  }

  Future<Map<String, Object?>> _validateTelemetryPayloadReplay({
    required String fixtureId,
    required String payloadAdapter,
    Map<String, Object?>? customPayload,
  }) async {
    final fixture =
        customPayload ?? await _telemetryReplayFixtures.readFixture(fixtureId);
    final adapter = _guardTelemetryAdapter;
    if (kIsWeb || adapter is! NativeGuardTelemetryIngestionAdapter) {
      throw StateError(
        'Telemetry payload replay validation requires native adapter runtime.',
      );
    }
    final response = await adapter.validatePayloadMapping(
      payload: fixture,
      payloadAdapter: payloadAdapter,
    );
    await _refreshGuardTelemetryAdapterStatus();
    return <String, Object?>{
      'fixture_id': fixtureId,
      'payload_adapter': payloadAdapter,
      ...response,
    };
  }

  Future<void> _refreshGuardTelemetryAdapterStatus() async {
    final status = await _guardTelemetryAdapter.getStatus();
    final nowUtc = DateTime.now().toUtc();
    final callbackCount = status.facadeCallbackCount ?? 0;
    final callbackErrorCount = status.facadeCallbackErrorCount ?? 0;
    final callbackAtUtc = status.facadeLastCallbackAtUtc?.toUtc();
    final callbackAgeSeconds = callbackAtUtc == null
        ? null
        : nowUtc.difference(callbackAtUtc).inSeconds;
    final callbackFresh =
        callbackAgeSeconds != null &&
        callbackAgeSeconds >= 0 &&
        callbackAgeSeconds <= 120;
    final checklistPassed = callbackCount > 0 && callbackFresh;
    final shouldRecordChecklistPass =
        checklistPassed && !_guardTelemetryVerificationChecklistPassed;
    final currentPayloadHealthVerdict = _telemetryPayloadHealthVerdict(
      status: status,
      callbackFresh: callbackFresh,
    );
    final currentPayloadHealthReason = _telemetryPayloadHealthReason(
      status: status,
      callbackFresh: callbackFresh,
      callbackErrorCount: callbackErrorCount,
    );
    final liveReadyGateViolation = _telemetryLiveReadyGateViolation(
      status: status,
    );
    final liveReadyGateReason = _telemetryLiveReadyGateReason(status: status);
    final previousPayloadHealthVerdict =
        _guardTelemetryPayloadHealthLastVerdict;
    final shouldEmitPayloadHealthAlert = _shouldEmitTelemetryPayloadAlert(
      currentVerdict: currentPayloadHealthVerdict,
      previousVerdict: previousPayloadHealthVerdict,
      nowUtc: nowUtc,
    );
    _guardTelemetryVerificationChecklistPassed = checklistPassed;
    _guardTelemetryPayloadHealthLastVerdict = currentPayloadHealthVerdict;
    if (!mounted) return;
    setState(() {
      _guardTelemetryReadiness = status.readiness;
      _guardTelemetryProviderStatusLabel = status.message;
      _guardTelemetryFacadeId = status.facadeId;
      _guardTelemetryActiveProviderId = status.providerId;
      _guardTelemetryFacadeLiveMode = status.facadeLiveMode;
      _guardTelemetryFacadeToggleSource = status.facadeToggleSource;
      _guardTelemetryFacadeRuntimeMode = status.facadeRuntimeMode;
      _guardTelemetryFacadeHeartbeatSource = status.facadeHeartbeatSource;
      _guardTelemetryFacadeHeartbeatAction = status.facadeHeartbeatAction;
      _guardTelemetryVendorConnectorId = status.vendorConnectorId;
      _guardTelemetryVendorConnectorSource = status.vendorConnectorSource;
      _guardTelemetryVendorConnectorErrorMessage =
          status.vendorConnectorErrorMessage;
      _guardTelemetryVendorConnectorFallbackActive =
          status.vendorConnectorFallbackActive;
      _guardTelemetryFacadeSourceActive = status.facadeSourceActive;
      _guardTelemetryFacadeCallbackCount = status.facadeCallbackCount;
      _guardTelemetryFacadeLastCallbackAtUtc = status.facadeLastCallbackAtUtc;
      _guardTelemetryFacadeLastCallbackMessage =
          status.facadeLastCallbackMessage;
      _guardTelemetryFacadeCallbackErrorCount = status.facadeCallbackErrorCount;
      _guardTelemetryFacadeLastCallbackErrorAtUtc =
          status.facadeLastCallbackErrorAtUtc;
      _guardTelemetryFacadeLastCallbackErrorMessage =
          status.facadeLastCallbackErrorMessage;
    });
    if (shouldEmitPayloadHealthAlert) {
      _guardTelemetryPayloadHealthLastAlertAtUtc = nowUtc;
      try {
        await _enqueueGuardOpsEvent(
          type: GuardOpsEventType.syncStatus,
          payload: {
            'telemetry_payload_health_alert': true,
            'telemetry_payload_health_verdict': currentPayloadHealthVerdict,
            'telemetry_payload_health_previous_verdict':
                previousPayloadHealthVerdict,
            'telemetry_payload_health_reason': currentPayloadHealthReason,
            'telemetry_payload_health_trend': _telemetryPayloadHealthTrend(
              currentVerdict: currentPayloadHealthVerdict,
            ),
            'telemetry_callback_count': callbackCount,
            'telemetry_callback_fresh': callbackFresh,
            'telemetry_callback_error_count': callbackErrorCount,
            'telemetry_provider_readiness': status.readiness.name,
            'telemetry_provider_expected_id': _guardTelemetryRequiredProviderId,
            'telemetry_provider_active_id': status.providerId,
            'telemetry_live_ready_gate_enabled':
                _guardTelemetryEnforceLiveReady,
            'telemetry_live_ready_gate_violation': liveReadyGateViolation,
            'telemetry_live_ready_gate_reason': liveReadyGateReason,
            'telemetry_facade_id': status.facadeId,
            'telemetry_facade_runtime_mode': status.facadeRuntimeMode,
            'telemetry_facade_heartbeat_source': status.facadeHeartbeatSource,
            'telemetry_vendor_connector': status.vendorConnectorId,
            'telemetry_vendor_connector_source': status.vendorConnectorSource,
            'telemetry_vendor_connector_error':
                status.vendorConnectorErrorMessage,
            'telemetry_vendor_connector_fallback_active':
                status.vendorConnectorFallbackActive,
            'telemetry_facade_last_callback_at_utc': callbackAtUtc
                ?.toIso8601String(),
            'telemetry_facade_last_callback_error_at_utc': status
                .facadeLastCallbackErrorAtUtc
                ?.toIso8601String(),
            'telemetry_facade_last_callback_error_message':
                status.facadeLastCallbackErrorMessage,
          },
        );
        await _hydrateGuardSyncState();
      } catch (error) {
        if (mounted) {
          setState(() {
            _guardOpsLastSyncLabel =
                'Telemetry payload health alert emit failed: $error';
          });
        }
      }
    }
    if (shouldRecordChecklistPass) {
      try {
        await _enqueueGuardOpsEvent(
          type: GuardOpsEventType.syncStatus,
          payload: {
            'telemetry_verification_checklist_passed': true,
            'telemetry_callback_count': callbackCount,
            'telemetry_callback_fresh': callbackFresh,
            'telemetry_callback_age_seconds': callbackAgeSeconds,
            'telemetry_provider_readiness': status.readiness.name,
            'telemetry_provider_expected_id': _guardTelemetryRequiredProviderId,
            'telemetry_provider_active_id': status.providerId,
            'telemetry_live_ready_gate_enabled':
                _guardTelemetryEnforceLiveReady,
            'telemetry_live_ready_gate_violation': liveReadyGateViolation,
            'telemetry_live_ready_gate_reason': liveReadyGateReason,
            'telemetry_facade_id': status.facadeId,
            'telemetry_facade_runtime_mode': status.facadeRuntimeMode,
            'telemetry_facade_heartbeat_source': status.facadeHeartbeatSource,
            'telemetry_vendor_connector': status.vendorConnectorId,
            'telemetry_vendor_connector_source': status.vendorConnectorSource,
            'telemetry_vendor_connector_error':
                status.vendorConnectorErrorMessage,
            'telemetry_vendor_connector_fallback_active':
                status.vendorConnectorFallbackActive,
            'telemetry_facade_last_callback_at_utc': callbackAtUtc
                ?.toIso8601String(),
          },
        );
        await _hydrateGuardSyncState();
      } catch (error) {
        if (mounted) {
          setState(() {
            _guardOpsLastSyncLabel =
                'Telemetry verification audit emit failed: $error';
          });
        }
      }
    }
  }

  String _telemetryPayloadHealthVerdict({
    required GuardTelemetryAdapterStatus status,
    required bool callbackFresh,
  }) {
    if (_telemetryLiveReadyGateViolation(status: status)) {
      return 'at_risk';
    }
    if (_guardTelemetryAdapter.isStub) {
      return 'stub';
    }
    if (status.readiness == GuardTelemetryAdapterReadiness.error) {
      return 'at_risk';
    }
    final callbackErrorCount = status.facadeCallbackErrorCount ?? 0;
    if (callbackErrorCount > 0) {
      return 'at_risk';
    }
    final liveMode = status.facadeLiveMode == true;
    final callbackCount = status.facadeCallbackCount ?? 0;
    if (liveMode && callbackCount <= 0) {
      return 'degraded';
    }
    if (liveMode && !callbackFresh) {
      return 'degraded';
    }
    return 'healthy';
  }

  String _telemetryPayloadHealthReason({
    required GuardTelemetryAdapterStatus status,
    required bool callbackFresh,
    required int callbackErrorCount,
  }) {
    if (_telemetryLiveReadyGateViolation(status: status)) {
      return _telemetryLiveReadyGateReason(status: status);
    }
    if (_guardTelemetryAdapter.isStub) {
      return 'stub adapter mode active';
    }
    if (status.readiness == GuardTelemetryAdapterReadiness.error) {
      return 'provider readiness is error';
    }
    if (callbackErrorCount > 0) {
      return 'callback parse/ingest errors detected';
    }
    final liveMode = status.facadeLiveMode == true;
    final callbackCount = status.facadeCallbackCount ?? 0;
    if (liveMode && callbackCount <= 0) {
      return 'live facade has no callbacks yet';
    }
    if (liveMode && !callbackFresh) {
      return 'live callbacks are stale (>2m)';
    }
    return 'callbacks are valid and fresh';
  }

  bool _telemetryLiveReadyGateViolation({
    required GuardTelemetryAdapterStatus status,
  }) {
    if (!_guardTelemetryEnforceLiveReady) {
      return false;
    }
    if (_guardTelemetryAdapter.isStub) {
      return true;
    }
    if (status.readiness != GuardTelemetryAdapterReadiness.ready) {
      return true;
    }
    if (status.facadeLiveMode != true) {
      return true;
    }
    if (_guardTelemetryRequiredProviderId.isNotEmpty &&
        (status.providerId ?? '').trim() != _guardTelemetryRequiredProviderId) {
      return true;
    }
    return false;
  }

  String _telemetryLiveReadyGateReason({
    required GuardTelemetryAdapterStatus status,
  }) {
    if (!_guardTelemetryEnforceLiveReady) {
      return 'live-ready gate disabled';
    }
    if (_guardTelemetryAdapter.isStub) {
      return 'live-ready gate violation: adapter is stub';
    }
    if (status.readiness != GuardTelemetryAdapterReadiness.ready) {
      return 'live-ready gate violation: provider readiness is ${status.readiness.name}';
    }
    if (status.facadeLiveMode != true) {
      return 'live-ready gate violation: facade mode is not live';
    }
    if (_guardTelemetryRequiredProviderId.isNotEmpty &&
        (status.providerId ?? '').trim() != _guardTelemetryRequiredProviderId) {
      return 'live-ready gate violation: provider mismatch (${status.providerId ?? 'unknown'} != $_guardTelemetryRequiredProviderId)';
    }
    return 'live-ready gate satisfied';
  }

  String get _guardTelemetryRequiredProviderId {
    final trimmed = _guardTelemetryRequiredProviderIdEnv.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
    return _guardTelemetryNativeProviderId.trim();
  }

  GuardMobileOperatorRole get _guardOperatorRole {
    final role = _guardAppRoleEnv.trim().toLowerCase();
    switch (role) {
      case 'reaction':
      case 'reaction_officer':
        return GuardMobileOperatorRole.reaction;
      case 'supervisor':
      case 'guarding_supervisor':
        return GuardMobileOperatorRole.supervisor;
      default:
        return GuardMobileOperatorRole.guard;
    }
  }

  OnyxAppMode _resolveAppMode() {
    final mode = _appModeEnv.trim().toLowerCase();
    switch (mode) {
      case 'guard':
      case 'guard_mobile':
        return OnyxAppMode.guard;
      case 'client':
      case 'client_app':
        return OnyxAppMode.client;
      default:
        return OnyxAppMode.controller;
    }
  }

  bool _shouldEmitTelemetryPayloadAlert({
    required String currentVerdict,
    required String previousVerdict,
    required DateTime nowUtc,
  }) {
    final currentSeverity = _telemetryPayloadHealthSeverity(currentVerdict);
    final previousSeverity = _telemetryPayloadHealthSeverity(previousVerdict);
    if (currentSeverity <= 0) {
      return false;
    }
    if (currentSeverity > previousSeverity) {
      return true;
    }
    final lastAlertAtUtc = _guardTelemetryPayloadHealthLastAlertAtUtc;
    if (lastAlertAtUtc == null) {
      return true;
    }
    final elapsed = nowUtc.difference(lastAlertAtUtc.toUtc());
    return elapsed.inSeconds >= _guardTelemetryPayloadAlertThrottleSeconds;
  }

  int _telemetryPayloadHealthSeverity(String verdict) {
    switch (verdict.trim().toLowerCase()) {
      case 'at_risk':
        return 2;
      case 'degraded':
        return 1;
      default:
        return 0;
    }
  }

  String _telemetryPayloadHealthTrend({required String currentVerdict}) {
    final history =
        _guardOpsRecentEvents
            .where((event) => event.eventType == GuardOpsEventType.syncStatus)
            .where(
              (event) =>
                  event.payload['telemetry_payload_health_verdict'] != null,
            )
            .toList(growable: false)
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final previous = history
        .take(4)
        .toList(growable: false)
        .reversed
        .map(
          (event) => (event.payload['telemetry_payload_health_verdict'] ?? '')
              .toString()
              .trim()
              .toLowerCase(),
        )
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    final trend = [...previous, currentVerdict.trim().toLowerCase()];
    if (trend.isEmpty) {
      return currentVerdict;
    }
    return trend.join('->');
  }

  Map<String, Object?> _buildGuardSyncOperationContext() {
    return <String, Object?>{
      'telemetry_adapter_label': _guardTelemetryAdapter.adapterLabel,
      'telemetry_adapter_stub_mode': _guardTelemetryAdapter.isStub,
      'telemetry_provider_readiness': _guardTelemetryReadiness.name,
      'telemetry_provider_status': _guardTelemetryProviderStatusLabel,
      'telemetry_provider_expected_id': _guardTelemetryRequiredProviderId,
      'telemetry_provider_active_id': _guardTelemetryActiveProviderId,
      'telemetry_facade_id': _guardTelemetryFacadeId,
      'telemetry_facade_live_mode': _guardTelemetryFacadeLiveMode,
      'telemetry_facade_toggle_source': _guardTelemetryFacadeToggleSource,
      'telemetry_facade_runtime_mode': _guardTelemetryFacadeRuntimeMode,
      'telemetry_facade_heartbeat_source': _guardTelemetryFacadeHeartbeatSource,
      'telemetry_facade_heartbeat_action': _guardTelemetryFacadeHeartbeatAction,
      'telemetry_vendor_connector': _guardTelemetryVendorConnectorId,
      'telemetry_vendor_connector_source': _guardTelemetryVendorConnectorSource,
      'telemetry_vendor_connector_error':
          _guardTelemetryVendorConnectorErrorMessage,
      'telemetry_vendor_connector_fallback_active':
          _guardTelemetryVendorConnectorFallbackActive,
      'telemetry_facade_source_active': _guardTelemetryFacadeSourceActive,
      'telemetry_facade_callback_count': _guardTelemetryFacadeCallbackCount,
      'telemetry_facade_callback_error_count':
          _guardTelemetryFacadeCallbackErrorCount,
      'telemetry_facade_last_callback_at_utc':
          _guardTelemetryFacadeLastCallbackAtUtc?.toIso8601String(),
      'telemetry_facade_last_callback_message':
          _guardTelemetryFacadeLastCallbackMessage,
      'telemetry_facade_last_callback_error_at_utc':
          _guardTelemetryFacadeLastCallbackErrorAtUtc?.toIso8601String(),
      'telemetry_facade_last_callback_error_message':
          _guardTelemetryFacadeLastCallbackErrorMessage,
      'telemetry_live_ready_gate_enabled': _guardTelemetryEnforceLiveReady,
      'telemetry_live_ready_gate_violation':
          _guardTelemetryLiveReadyGateViolated,
      'telemetry_live_ready_gate_reason': _guardTelemetryLiveReadyGateReason,
    };
  }

  bool get _guardTelemetryLiveReadyGateViolated {
    if (!_guardTelemetryEnforceLiveReady) {
      return false;
    }
    if (_guardTelemetryAdapter.isStub) {
      return true;
    }
    if (_guardTelemetryReadiness != GuardTelemetryAdapterReadiness.ready) {
      return true;
    }
    if (_guardTelemetryFacadeLiveMode != true) {
      return true;
    }
    if (_guardTelemetryRequiredProviderId.isNotEmpty &&
        (_guardTelemetryActiveProviderId ?? '').trim() !=
            _guardTelemetryRequiredProviderId) {
      return true;
    }
    return false;
  }

  String get _guardTelemetryLiveReadyGateReason {
    if (!_guardTelemetryEnforceLiveReady) {
      return 'disabled';
    }
    if (_guardTelemetryAdapter.isStub) {
      return 'adapter is stub';
    }
    if (_guardTelemetryReadiness != GuardTelemetryAdapterReadiness.ready) {
      return 'provider readiness is ${_guardTelemetryReadiness.name}';
    }
    if (_guardTelemetryFacadeLiveMode != true) {
      return 'facade mode is not live';
    }
    if (_guardTelemetryRequiredProviderId.isNotEmpty &&
        (_guardTelemetryActiveProviderId ?? '').trim() !=
            _guardTelemetryRequiredProviderId) {
      return 'provider mismatch (${_guardTelemetryActiveProviderId ?? 'unknown'} != $_guardTelemetryRequiredProviderId)';
    }
    return 'satisfied';
  }

  Future<void> _queueIncidentOutcomeLabel({
    required String outcomeLabel,
    required String confidence,
    required String confirmedBy,
  }) async {
    final allowedConfirmers =
        _outcomeGovernancePolicy
            .allowedConfirmers(outcomeLabel)
            .toList(growable: false)
          ..sort();
    if (!_outcomeGovernancePolicy.allows(
      outcomeLabel: outcomeLabel,
      confirmedBy: confirmedBy,
    )) {
      final reason =
          'Confirmation role "$confirmedBy" is not allowed for $outcomeLabel. Allowed: ${allowedConfirmers.join(', ')}.';
      _recordGuardOutcomePolicyDenied(reason);
      throw StateError(reason);
    }
    await _enqueueGuardOpsEvent(
      type: GuardOpsEventType.incidentReported,
      payload: {
        'outcome_label': outcomeLabel,
        'label_confidence': confidence,
        'confirmed_by': confirmedBy,
        'source': 'guard_shell',
        'governance': {
          'policy_version': _outcomeGovernancePolicy.policyVersion,
          'rule_id': _outcomeGovernancePolicy.ruleIdFor(outcomeLabel),
          'allowed_confirmers': allowedConfirmers,
          'confirmed_by': confirmedBy,
        },
      },
    );
  }

  Future<void> _acknowledgeGuardCoachingPrompt({
    required String ruleId,
    required String context,
  }) async {
    await _enqueueGuardOpsEvent(
      type: GuardOpsEventType.syncStatus,
      payload: {
        'coaching_prompt_acknowledged': true,
        'rule_id': ruleId,
        'context': context,
        'acknowledged_by': 'GUARD-001',
      },
    );
    _recordGuardCoachingTelemetry(
      kind: 'ack',
      ruleId: ruleId,
      context: context,
      actorRole: 'guard',
    );
    await _hydrateGuardSyncState();
  }

  Future<void> _snoozeGuardCoachingPrompt({
    required String ruleId,
    required String context,
    required int minutes,
    required String actorRole,
  }) async {
    final untilUtc = DateTime.now().toUtc().add(Duration(minutes: minutes));
    if (mounted) {
      setState(() {
        final updated = Map<String, DateTime>.from(
          _guardCoachingPromptSnoozedUntilByRule,
        );
        updated[ruleId] = untilUtc;
        _guardCoachingPromptSnoozedUntilByRule = updated;
      });
    }
    await _enqueueGuardOpsEvent(
      type: GuardOpsEventType.syncStatus,
      payload: {
        'coaching_prompt_snoozed': true,
        'rule_id': ruleId,
        'context': context,
        'snooze_minutes': minutes,
        'snoozed_until_utc': untilUtc.toIso8601String(),
        GuardEventContractKeys.actorRole: actorRole,
      },
    );
    _recordGuardCoachingTelemetry(
      kind: 'snooze',
      ruleId: ruleId,
      context: context,
      actorRole: actorRole,
      minutes: minutes,
    );
    await _persistGuardCoachingPromptSnoozes();
    await _hydrateGuardSyncState();
  }

  GuardCoachingPrompt _effectiveGuardCoachingPrompt({
    required GuardCoachingPrompt prompt,
    required DateTime nowUtc,
  }) {
    final snoozedUntil = _guardCoachingPromptSnoozedUntilByRule[prompt.ruleId];
    if (snoozedUntil == null) {
      return prompt;
    }
    if (nowUtc.isAfter(snoozedUntil)) {
      _scheduleGuardCoachingSnoozeExpiryEvent(
        ruleId: prompt.ruleId,
        expiredAtUtc: snoozedUntil,
        nowUtc: nowUtc,
      );
      return prompt;
    }
    return GuardCoachingPrompt(
      ruleId: '${prompt.ruleId}_snoozed',
      headline: '${prompt.headline} (Snoozed)',
      message:
          'Prompt snoozed until ${snoozedUntil.toIso8601String()} by operator action.',
      priority: GuardCoachingPriority.low,
    );
  }

  void _scheduleGuardCoachingSnoozeExpiryEvent({
    required String ruleId,
    required DateTime expiredAtUtc,
    required DateTime nowUtc,
  }) {
    if (_guardCoachingSnoozeExpiryEventInFlightRules.contains(ruleId)) return;
    _guardCoachingSnoozeExpiryEventInFlightRules.add(ruleId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        _emitGuardCoachingSnoozeExpiryEvent(
          ruleId: ruleId,
          expiredAtUtc: expiredAtUtc,
          reactivatedAtUtc: nowUtc,
        ),
      );
    });
  }

  Future<void> _emitGuardCoachingSnoozeExpiryEvent({
    required String ruleId,
    required DateTime expiredAtUtc,
    required DateTime reactivatedAtUtc,
  }) async {
    try {
      if (mounted) {
        setState(() {
          final updated = Map<String, DateTime>.from(
            _guardCoachingPromptSnoozedUntilByRule,
          );
          updated.remove(ruleId);
          _guardCoachingPromptSnoozedUntilByRule = updated;
        });
      } else {
        final updated = Map<String, DateTime>.from(
          _guardCoachingPromptSnoozedUntilByRule,
        );
        updated.remove(ruleId);
        _guardCoachingPromptSnoozedUntilByRule = updated;
      }
      await _persistGuardCoachingPromptSnoozes();
      await _enqueueGuardOpsEvent(
        type: GuardOpsEventType.syncStatus,
        payload: {
          'coaching_prompt_snooze_expired': true,
          'rule_id': ruleId,
          'expired_at_utc': expiredAtUtc.toIso8601String(),
          'reactivated_at_utc': reactivatedAtUtc.toIso8601String(),
          'context': 'guards_route',
        },
      );
      _recordGuardCoachingTelemetry(
        kind: 'snooze_expired',
        ruleId: ruleId,
        context: 'guards_route',
      );
      await _hydrateGuardSyncState();
    } finally {
      _guardCoachingSnoozeExpiryEventInFlightRules.remove(ruleId);
    }
  }

  Future<void> _hydrateGuardCoachingPromptSnoozes() async {
    final persistence = await _persistenceServiceFuture;
    final raw = await persistence.readGuardCoachingPromptSnoozes();
    if (raw.isEmpty || !mounted) return;
    final parsed = raw.map((ruleId, value) {
      final timestamp = DateTime.tryParse(value?.toString() ?? '')?.toUtc();
      return MapEntry(ruleId, timestamp);
    });
    final nowUtc = DateTime.now().toUtc();
    final active = <String, DateTime>{
      for (final entry in parsed.entries)
        if (entry.value != null && entry.value!.isAfter(nowUtc))
          entry.key: entry.value!,
    };
    if (!mounted) return;
    setState(() {
      _guardCoachingPromptSnoozedUntilByRule = active;
    });
  }

  Future<void> _persistGuardCoachingPromptSnoozes() async {
    final persistence = await _persistenceServiceFuture;
    await persistence.saveGuardCoachingPromptSnoozes({
      for (final entry in _guardCoachingPromptSnoozedUntilByRule.entries)
        entry.key: entry.value.toUtc().toIso8601String(),
    });
  }

  Future<void> _hydrateGuardCoachingTelemetry() async {
    final persistence = await _persistenceServiceFuture;
    final telemetry = await persistence.readGuardCoachingTelemetry();
    if (telemetry.isEmpty || !mounted) return;
    final rawHistory = telemetry['recentHistory'];
    final history = rawHistory is List
        ? rawHistory
              .map((entry) => entry.toString().trim())
              .where((entry) => entry.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    setState(() {
      _guardCoachingAckCount = (telemetry['ackCount'] as num?)?.toInt() ?? 0;
      _guardCoachingSnoozeCount =
          (telemetry['snoozeCount'] as num?)?.toInt() ?? 0;
      _guardCoachingSnoozeExpiryCount =
          (telemetry['snoozeExpiryCount'] as num?)?.toInt() ?? 0;
      _guardCoachingRecentHistory = history;
    });
  }

  Future<void> _hydrateGuardCloseoutPacketAudit() async {
    final persistence = await _persistenceServiceFuture;
    final raw = await persistence.readGuardCloseoutPacketAudit();
    if (!mounted || raw.isEmpty) return;
    setState(() {
      _guardLastCloseoutPacketAudit = raw;
    });
  }

  Future<void> _persistGuardCloseoutPacketAudit() async {
    final persistence = await _persistenceServiceFuture;
    await persistence.saveGuardCloseoutPacketAudit(
      _guardLastCloseoutPacketAudit,
    );
  }

  Future<void> _recordGuardCloseoutPacketAudit({
    required DateTime generatedAtUtc,
    required String scopeKey,
    required String facadeMode,
    required String readinessState,
  }) async {
    final next = <String, Object?>{
      'generated_at_utc': generatedAtUtc.toUtc().toIso8601String(),
      'scope_key': scopeKey.trim(),
      'facade_mode': facadeMode.trim(),
      'readiness_state': readinessState.trim(),
    };
    if (mounted) {
      setState(() {
        _guardLastCloseoutPacketAudit = next;
      });
    } else {
      _guardLastCloseoutPacketAudit = next;
    }
    await _persistGuardCloseoutPacketAudit();
    await _recordGuardExportAuditEvent(
      exportType: 'dispatch_closeout_packet',
      payload: next,
    );
  }

  Future<void> _hydrateGuardShiftReplayAudit() async {
    final persistence = await _persistenceServiceFuture;
    final raw = await persistence.readGuardShiftReplayAudit();
    if (!mounted || raw.isEmpty) return;
    setState(() {
      _guardLastShiftReplayAudit = raw;
    });
  }

  Future<void> _persistGuardShiftReplayAudit() async {
    final persistence = await _persistenceServiceFuture;
    await persistence.saveGuardShiftReplayAudit(_guardLastShiftReplayAudit);
  }

  Future<void> _recordGuardShiftReplayAudit({
    required DateTime generatedAtUtc,
    required String shiftId,
    required int eventRows,
    required int mediaRows,
  }) async {
    final next = <String, Object?>{
      'generated_at_utc': generatedAtUtc.toUtc().toIso8601String(),
      'shift_id': shiftId.trim(),
      'event_rows': eventRows,
      'media_rows': mediaRows,
    };
    if (mounted) {
      setState(() {
        _guardLastShiftReplayAudit = next;
      });
    } else {
      _guardLastShiftReplayAudit = next;
    }
    await _persistGuardShiftReplayAudit();
    await _recordGuardExportAuditEvent(
      exportType: 'shift_replay_summary',
      payload: next,
    );
  }

  Future<void> _hydrateGuardSyncReportAudit() async {
    final persistence = await _persistenceServiceFuture;
    final raw = await persistence.readGuardSyncReportAudit();
    if (!mounted || raw.isEmpty) return;
    setState(() {
      _guardLastSyncReportAudit = raw;
    });
  }

  Future<void> _persistGuardSyncReportAudit() async {
    final persistence = await _persistenceServiceFuture;
    await persistence.saveGuardSyncReportAudit(_guardLastSyncReportAudit);
  }

  Future<void> _recordGuardSyncReportAudit({
    required DateTime generatedAtUtc,
    required String scopeKey,
    required String facadeMode,
    required String eventFilter,
    required String mediaFilter,
  }) async {
    final next = <String, Object?>{
      'generated_at_utc': generatedAtUtc.toUtc().toIso8601String(),
      'scope_key': scopeKey.trim(),
      'facade_mode': facadeMode.trim(),
      'event_filter': eventFilter.trim(),
      'media_filter': mediaFilter.trim(),
    };
    if (mounted) {
      setState(() {
        _guardLastSyncReportAudit = next;
      });
    } else {
      _guardLastSyncReportAudit = next;
    }
    await _persistGuardSyncReportAudit();
    await _recordGuardExportAuditEvent(
      exportType: 'sync_report',
      payload: next,
    );
  }

  Future<void> _recordGuardExportAuditEvent({
    required String exportType,
    required Map<String, Object?> payload,
  }) async {
    await _enqueueGuardOpsEvent(
      type: GuardOpsEventType.syncStatus,
      payload: {
        'export_audit_generated': true,
        'export_type': exportType.trim(),
        ...payload,
      },
    );
  }

  Future<void> _clearGuardExportAudits() async {
    final persistence = await _persistenceServiceFuture;
    final nowUtc = DateTime.now().toUtc();
    final scopeKey = _guardSyncSelectionScopeKey();
    final facadeMode = _guardSyncOperationModeFilter.name;
    final historyFilter = _guardSyncHistoryFilter.name;
    final clearMeta = <String, Object?>{
      'cleared_at_utc': nowUtc.toIso8601String(),
      'scope_key': scopeKey,
      'facade_mode': facadeMode,
      'history_filter': historyFilter,
    };
    if (mounted) {
      setState(() {
        _guardLastSyncReportAudit = const {};
        _guardLastShiftReplayAudit = const {};
        _guardLastCloseoutPacketAudit = const {};
        _guardExportAuditClearMeta = clearMeta;
      });
    } else {
      _guardLastSyncReportAudit = const {};
      _guardLastShiftReplayAudit = const {};
      _guardLastCloseoutPacketAudit = const {};
      _guardExportAuditClearMeta = clearMeta;
    }
    await persistence.clearGuardSyncReportAudit();
    await persistence.clearGuardShiftReplayAudit();
    await persistence.clearGuardCloseoutPacketAudit();
    await persistence.saveGuardExportAuditClearMeta(_guardExportAuditClearMeta);
    await _enqueueGuardOpsEvent(
      type: GuardOpsEventType.syncStatus,
      payload: {
        'export_audits_cleared': true,
        'scope_key': scopeKey,
        'facade_mode': facadeMode,
        'history_filter': historyFilter,
        'cleared_at_utc': nowUtc.toIso8601String(),
      },
    );
  }

  Future<void> _hydrateGuardExportAuditClearMeta() async {
    final persistence = await _persistenceServiceFuture;
    final raw = await persistence.readGuardExportAuditClearMeta();
    if (!mounted || raw.isEmpty) return;
    setState(() {
      _guardExportAuditClearMeta = raw;
    });
  }

  Future<void> _hydrateMorningSovereignReport() async {
    final persistence = await _persistenceServiceFuture;
    final rawReport = await persistence.readMorningSovereignReport();
    final rawHistory = await persistence.readMorningSovereignReportHistory();
    final autoRunKey = await persistence.readMorningSovereignReportAutoRunKey();
    SovereignReport? report;
    final history = <SovereignReport>[];
    if (rawReport.isNotEmpty) {
      try {
        report = SovereignReport.fromJson(rawReport);
      } catch (_) {
        await persistence.clearMorningSovereignReport();
      }
    }
    for (final rawEntry in rawHistory) {
      try {
        history.add(SovereignReport.fromJson(rawEntry));
      } catch (_) {}
    }
    final normalizedHistory = _normalizedMorningSovereignReportHistory(
      history,
      latest: report,
    );
    if (mounted) {
      setState(() {
        _morningSovereignReport = report;
        _morningSovereignReportHistory = normalizedHistory;
        _morningSovereignReportAutoRunKey = autoRunKey;
      });
    } else {
      _morningSovereignReport = report;
      _morningSovereignReportHistory = normalizedHistory;
      _morningSovereignReportAutoRunKey = autoRunKey;
    }
    await _maybeAutoGenerateMorningSovereignReport();
  }

  Future<void> _persistMorningSovereignReport() async {
    final persistence = await _persistenceServiceFuture;
    final report = _morningSovereignReport;
    if (report == null) {
      await persistence.clearMorningSovereignReport();
    } else {
      await persistence.saveMorningSovereignReport(report.toJson());
    }
  }

  Future<void> _persistMorningSovereignReportHistory() async {
    final persistence = await _persistenceServiceFuture;
    final history = _morningSovereignReportHistory;
    if (history.isEmpty) {
      await persistence.clearMorningSovereignReportHistory();
      return;
    }
    await persistence.saveMorningSovereignReportHistory(
      history.map((report) => report.toJson()).toList(growable: false),
    );
  }

  Future<void> _persistMorningSovereignReportAutoRunKey() async {
    final persistence = await _persistenceServiceFuture;
    final key = (_morningSovereignReportAutoRunKey ?? '').trim();
    if (key.isEmpty) {
      await persistence.clearMorningSovereignReportAutoRunKey();
    } else {
      await persistence.saveMorningSovereignReportAutoRunKey(key);
    }
  }

  void _handleMorningSovereignReportChanged(SovereignReport report) {
    final previous = _morningSovereignReport;
    _appendVehicleVisitReviewEvents(previous: previous, next: report);
    final nextHistory = _normalizedMorningSovereignReportHistory(
      _morningSovereignReportHistory,
      latest: report,
    );
    if (mounted) {
      setState(() {
        _morningSovereignReport = report;
        _morningSovereignReportHistory = nextHistory;
      });
    } else {
      _morningSovereignReport = report;
      _morningSovereignReportHistory = nextHistory;
    }
    unawaited(_persistMorningSovereignReport());
    unawaited(_persistMorningSovereignReportHistory());
  }

  List<SovereignReport> _normalizedMorningSovereignReportHistory(
    Iterable<SovereignReport> reports, {
    SovereignReport? latest,
  }) {
    final byKey = <String, SovereignReport>{};
    for (final report in reports) {
      final key = _morningSovereignReportHistoryKeyFor(report);
      if (key.isEmpty) {
        continue;
      }
      final existing = byKey[key];
      if (existing == null ||
          report.generatedAtUtc.toUtc().isAfter(
            existing.generatedAtUtc.toUtc(),
          )) {
        byKey[key] = report;
      }
    }
    if (latest != null) {
      final key = _morningSovereignReportHistoryKeyFor(latest);
      if (key.isNotEmpty) {
        byKey[key] = latest;
      }
    }
    final normalized = byKey.values.toList(growable: false)
      ..sort((a, b) {
        final generatedCompare = b.generatedAtUtc.toUtc().compareTo(
          a.generatedAtUtc.toUtc(),
        );
        if (generatedCompare != 0) {
          return generatedCompare;
        }
        return b.date.compareTo(a.date);
      });
    return normalized.take(7).toList(growable: false);
  }

  String _morningSovereignReportHistoryKeyFor(SovereignReport report) {
    final date = report.date.trim();
    if (date.isNotEmpty) {
      return date;
    }
    final generatedAt = report.generatedAtUtc.toUtc();
    if (generatedAt.year > 1970) {
      return generatedAt.toIso8601String();
    }
    return '';
  }

  void _appendVehicleVisitReviewEvents({
    required SovereignReport? previous,
    required SovereignReport next,
  }) {
    final previousByKey = <String, SovereignReportVehicleVisitException>{
      for (final exception
          in previous?.vehicleThroughput.exceptionVisits ??
              const <SovereignReportVehicleVisitException>[])
        sovereignReportVehicleVisitExceptionKey(exception): exception,
    };
    for (final exception in next.vehicleThroughput.exceptionVisits) {
      final key = sovereignReportVehicleVisitExceptionKey(exception);
      final prior = previousByKey[key];
      if (!_vehicleVisitReviewStateChanged(prior, exception)) {
        continue;
      }
      final regionId = _vehicleVisitReviewRegionIdFor(exception);
      final occurredAt = (exception.operatorReviewedAtUtc ?? DateTime.now())
          .toUtc();
      final keyHash = key.hashCode.toUnsigned(32);
      store.append(
        VehicleVisitReviewRecorded(
          eventId:
              'vehicle-review-${occurredAt.microsecondsSinceEpoch}-$keyHash',
          sequence: 0,
          version: 1,
          occurredAt: occurredAt,
          vehicleVisitKey: key,
          primaryEventId: exception.primaryEventId.trim(),
          clientId: exception.clientId.trim(),
          regionId: regionId,
          siteId: exception.siteId.trim(),
          vehicleLabel: exception.vehicleLabel.trim(),
          actorLabel: _currentGovernanceActorLabel(),
          reviewed: exception.operatorReviewed,
          statusOverride: exception.operatorStatusOverride.trim().toUpperCase(),
          effectiveStatusLabel: exception.statusLabel.trim().toUpperCase(),
          reasonLabel: exception.reasonLabel.trim(),
          workflowSummary: exception.workflowSummary.trim(),
          sourceSurface: 'governance',
        ),
      );
    }
  }

  String _currentGovernanceActorLabel() {
    final operatorId = service.operator.operatorId.trim();
    if (operatorId.isNotEmpty) {
      return operatorId;
    }
    return 'OPERATOR-UNKNOWN';
  }

  bool _vehicleVisitReviewStateChanged(
    SovereignReportVehicleVisitException? previous,
    SovereignReportVehicleVisitException next,
  ) {
    if (previous == null) {
      return next.operatorReviewed ||
          next.operatorStatusOverride.trim().isNotEmpty;
    }
    return previous.operatorReviewed != next.operatorReviewed ||
        previous.operatorStatusOverride.trim().toUpperCase() !=
            next.operatorStatusOverride.trim().toUpperCase() ||
        previous.operatorReviewedAtUtc?.toUtc() !=
            next.operatorReviewedAtUtc?.toUtc();
  }

  String _vehicleVisitReviewRegionIdFor(
    SovereignReportVehicleVisitException exception,
  ) {
    final candidateEventIds = <String>{
      exception.primaryEventId.trim(),
      ...exception.eventIds.map((id) => id.trim()),
    }..removeWhere((value) => value.isEmpty);
    if (candidateEventIds.isEmpty) {
      return '';
    }
    for (final event in store.allEvents()) {
      if (!candidateEventIds.contains(event.eventId)) {
        continue;
      }
      if (event is IntelligenceReceived) {
        return event.regionId.trim();
      }
      if (event is DecisionCreated) {
        return event.regionId.trim();
      }
      if (event is ExecutionDenied) {
        return event.regionId.trim();
      }
      if (event is ResponseArrived) {
        return event.regionId.trim();
      }
      if (event is IncidentClosed) {
        return event.regionId.trim();
      }
      if (event is PartnerDispatchStatusDeclared) {
        return event.regionId.trim();
      }
    }
    return '';
  }

  SovereignReport _mergeMorningSovereignReportVehicleReviews(
    SovereignReport report,
  ) {
    final previous = _morningSovereignReport;
    if (previous == null) {
      return report;
    }
    final previousByKey = <String, SovereignReportVehicleVisitException>{
      for (final exception in previous.vehicleThroughput.exceptionVisits)
        sovereignReportVehicleVisitExceptionKey(exception): exception,
    };
    final mergedExceptions = report.vehicleThroughput.exceptionVisits
        .map((exception) {
          final previousException =
              previousByKey[sovereignReportVehicleVisitExceptionKey(exception)];
          if (previousException == null) {
            return exception;
          }
          return exception.copyWith(
            operatorReviewed: previousException.operatorReviewed,
            operatorReviewedAtUtc: previousException.operatorReviewedAtUtc
                ?.toUtc(),
            clearOperatorReviewedAtUtc:
                !previousException.operatorReviewed &&
                previousException.operatorReviewedAtUtc == null,
            operatorStatusOverride: previousException.operatorStatusOverride
                .trim()
                .toUpperCase(),
          );
        })
        .toList(growable: false);
    return report.copyWith(
      vehicleThroughput: report.vehicleThroughput.copyWith(
        exceptionVisits: mergedExceptions,
      ),
    );
  }

  Future<void> _maybeAutoGenerateMorningSovereignReport() async {
    final nowLocal = DateTime.now();
    if (nowLocal.hour < 6) return;
    final autoRunKey = MorningSovereignReportService.autoRunKeyFor(nowLocal);
    if ((_morningSovereignReportAutoRunKey ?? '').trim() == autoRunKey) {
      return;
    }
    await _generateMorningSovereignReport(
      automated: true,
      autoRunKey: autoRunKey,
    );
  }

  Future<void> _generateMorningSovereignReport({
    bool automated = false,
    String? autoRunKey,
  }) async {
    final nowUtc = DateTime.now().toUtc();
    final service = const MorningSovereignReportService();
    final report = _mergeMorningSovereignReportVehicleReviews(
      service.generate(
        nowUtc: nowUtc,
        events: store.allEvents(),
        recentMedia: _guardOpsRecentMedia,
        guardOutcomePolicyDenied24h: _guardOutcomeDeniedInWindow(
          const Duration(hours: 24),
        ),
        sceneReviewByIntelligenceId: _monitoringSceneReviewByIntelligenceId,
      ),
    );
    final nextAutoRunKey = (autoRunKey ?? '').trim().isNotEmpty
        ? autoRunKey!.trim()
        : (DateTime.now().hour >= 6
              ? MorningSovereignReportService.autoRunKeyFor(DateTime.now())
              : (_morningSovereignReportAutoRunKey ?? '').trim());
    if (mounted) {
      setState(() {
        _morningSovereignReport = report;
        _morningSovereignReportHistory =
            _normalizedMorningSovereignReportHistory(
              _morningSovereignReportHistory,
              latest: report,
            );
        _morningSovereignReportAutoRunKey = nextAutoRunKey.isEmpty
            ? null
            : nextAutoRunKey;
      });
    } else {
      _morningSovereignReport = report;
      _morningSovereignReportHistory = _normalizedMorningSovereignReportHistory(
        _morningSovereignReportHistory,
        latest: report,
      );
      _morningSovereignReportAutoRunKey = nextAutoRunKey.isEmpty
          ? null
          : nextAutoRunKey;
    }
    await _persistMorningSovereignReport();
    await _persistMorningSovereignReportHistory();
    await _persistMorningSovereignReportAutoRunKey();
    if (automated) {
      await _autoSendMorningGovernanceDigest(report);
      await _autoSendMorningSiteActivityDigests();
    }
    await _recordGuardExportAuditEvent(
      exportType: 'morning_sovereign_report',
      payload: {
        'generated_at_utc': report.generatedAtUtc.toIso8601String(),
        'report_date': report.date,
        'window_start_utc': report.shiftWindowStartUtc.toIso8601String(),
        'window_end_utc': report.shiftWindowEndUtc.toIso8601String(),
        'auto_generated': automated,
      },
    );
  }

  Future<void> _autoSendMorningSiteActivityDigests() async {
    if (!_telegramBridge.isConfigured) {
      return;
    }
    final scopes = <ClientTelegramScopeTarget>[];
    if (widget.supabaseReady) {
      try {
        final repository = SupabaseClientMessagingBridgeRepository(
          Supabase.instance.client,
        );
        scopes.addAll(await repository.readActiveTelegramScopes());
      } catch (_) {
        // Fall back to the current target when scope enumeration is unavailable.
      }
    }
    if (scopes.isEmpty &&
        _telegramAdminTargetClientId.trim().isNotEmpty &&
        _telegramAdminTargetSiteId.trim().isNotEmpty) {
      scopes.add(
        ClientTelegramScopeTarget(
          clientId: _telegramAdminTargetClientId,
          siteId: _telegramAdminTargetSiteId,
        ),
      );
    }
    for (final scope in scopes) {
      try {
        await _deliverSiteActivityTelegramSummary(
          clientId: scope.clientId,
          siteId: scope.siteId,
          sendClient: true,
          sendPartner: true,
        );
      } catch (_) {
        // Automatic digest delivery must not block morning report generation.
      }
    }
  }

  Future<void> _autoSendMorningGovernanceDigest(SovereignReport report) async {
    if (!_telegramAdminControlEnabled || !_telegramBridge.isConfigured) {
      return;
    }
    final adminChatId = _resolvedTelegramAdminChatId();
    if (adminChatId.isEmpty) {
      return;
    }
    final adminThreadId = _resolvedTelegramAdminThreadId();
    SovereignReport? previousReport;
    for (final item in _morningSovereignReportHistory) {
      if (item.date.trim() == report.date.trim()) {
        continue;
      }
      previousReport = item;
      break;
    }
    final targetClientId = _telegramAdminTargetClientId.trim();
    final targetSiteId = _telegramAdminTargetSiteId.trim();
    final targetScope = targetClientId.isNotEmpty && targetSiteId.isNotEmpty
        ? '$targetClientId/$targetSiteId'
        : null;
    final readinessSnapshot = _globalReadinessSnapshotForReport(report);
    final readinessIntents = _globalReadinessIntentsForReport(report);
    final readinessSummary = _globalReadinessSummaryForReport(
      snapshot: readinessSnapshot,
      intents: readinessIntents,
    );
    final sceneReviewSummary = _singleLine(
      report.sceneReview.recentActionsSummary.trim().isNotEmpty
          ? report.sceneReview.recentActionsSummary
          : (report.sceneReview.actionMixSummary.trim().isNotEmpty
                ? report.sceneReview.actionMixSummary
                : (report.sceneReview.latestActionTaken.trim().isNotEmpty
                      ? report.sceneReview.latestActionTaken
                      : 'No review actions recorded.')),
      maxLength: 220,
    );
    final siteActivityHeadline = _singleLine(
      report.siteActivity.headline.trim().isNotEmpty
          ? report.siteActivity.headline
          : 'ACTIVITY STABLE',
      maxLength: 120,
    );
    final siteActivitySummary = _singleLine(
      report.siteActivity.summaryLine.trim().isNotEmpty
          ? report.siteActivity.summaryLine
          : report.siteActivity.executiveSummary,
      maxLength: 220,
    );
    final responseText = TelegramAdminCommandFormatter.morningGovernance(
      signalHeader: _telegramAdminSignalHeader(),
      reportDate: report.date,
      generatedAtUtc: report.generatedAtUtc.toIso8601String(),
      sceneReviewSummary: sceneReviewSummary,
      globalReadinessHeadline: _globalReadinessModeLabel(
        readinessSnapshot,
        readinessIntents,
      ),
      globalReadinessSummary: readinessSummary,
      globalReadinessEchoSummary: _globalReadinessEchoSummary(
        readinessIntents,
      ),
      globalReadinessTopIntentSummary: _globalReadinessTopIntentSummary(
        readinessIntents,
      ),
      currentShiftReadinessReviewCommand: '/readinessreview ${report.date}',
      currentShiftReadinessCaseFileCommand:
          '/readinesscase json ${report.date}',
      previousShiftReadinessReviewCommand: previousReport == null
          ? null
          : '/readinessreview ${previousReport.date}',
      previousShiftReadinessCaseFileCommand: previousReport == null
          ? null
          : '/readinesscase json ${previousReport.date}',
      siteActivityHeadline: siteActivityHeadline,
      siteActivitySummary: siteActivitySummary,
      currentShiftReviewCommand: '/activityreview ${report.date}',
      currentShiftCaseFileCommand: '/activitycase json ${report.date}',
      previousShiftReviewCommand: previousReport == null
          ? null
          : '/activityreview ${previousReport.date}',
      previousShiftCaseFileCommand: previousReport == null
          ? null
          : '/activitycase json ${previousReport.date}',
      targetScope: targetScope,
      targetScopeRequired: true,
      utcStamp: _telegramUtcStamp(),
    );
    try {
      await _sendTelegramMessageWithChunks(
        messageKeyPrefix: 'tg-admin-morning-governance-${report.date}',
        chatId: adminChatId,
        messageThreadId: adminThreadId,
        responseText: responseText,
        failureContext: 'Morning governance digest',
        replyMarkup: _telegramAdminQuickReplyMarkup(),
        parseMode: 'HTML',
      );
    } catch (_) {
      // Governance digests must not block the morning report cycle.
    }
  }

  SovereignReport? _morningSovereignReportForDate(String? reportDate) {
    final normalizedDate = (reportDate ?? '').trim();
    if (normalizedDate.isEmpty) {
      return _morningSovereignReport;
    }
    final current = _morningSovereignReport;
    if (current != null && current.date.trim() == normalizedDate) {
      return current;
    }
    for (final item in _morningSovereignReportHistory) {
      if (item.date.trim() == normalizedDate) {
        return item;
      }
    }
    return null;
  }

  List<DispatchEvent> _eventsScopedToWindow(
    DateTime? startUtcValue,
    DateTime? endUtcValue,
  ) {
    final startUtc = startUtcValue?.toUtc();
    final endUtc = endUtcValue?.toUtc();
    if (startUtc == null || endUtc == null) {
      return store.allEvents();
    }
    return store.allEvents()
        .where(
          (event) =>
              !event.occurredAt.toUtc().isBefore(startUtc) &&
              !event.occurredAt.toUtc().isAfter(endUtc),
        )
        .toList(growable: false);
  }

  MonitoringGlobalPostureSnapshot _globalReadinessSnapshotForReport(
    SovereignReport report,
  ) {
    final scopedEvents = _eventsScopedToWindow(
      report.shiftWindowStartUtc,
      report.shiftWindowEndUtc,
    );
    return _globalPostureService.buildSnapshot(
      events: scopedEvents,
      sceneReviewByIntelligenceId: _monitoringSceneReviewByIntelligenceId,
      generatedAtUtc: report.generatedAtUtc,
    );
  }

  List<MonitoringWatchAutonomyActionPlan> _globalReadinessIntentsForReport(
    SovereignReport report,
  ) {
    final scopedEvents = _eventsScopedToWindow(
      report.shiftWindowStartUtc,
      report.shiftWindowEndUtc,
    );
    return _orchestratorService.buildActionIntents(
      events: scopedEvents,
      sceneReviewByIntelligenceId: _monitoringSceneReviewByIntelligenceId,
    );
  }

  String _globalReadinessModeLabel(
    MonitoringGlobalPostureSnapshot snapshot,
    List<MonitoringWatchAutonomyActionPlan> intents,
  ) {
    if (snapshot.criticalSiteCount > 0) {
      return 'CRITICAL POSTURE';
    }
    if (snapshot.elevatedSiteCount > 0) {
      return 'ELEVATED WATCH';
    }
    if (intents.isNotEmpty) {
      return 'ACTIVE TENSION';
    }
    return 'STABLE POSTURE';
  }

  String _globalReadinessSummaryForReport({
    required MonitoringGlobalPostureSnapshot snapshot,
    required List<MonitoringWatchAutonomyActionPlan> intents,
  }) {
    final leadRegion = snapshot.regions.isEmpty ? null : snapshot.regions.first;
    final leadSite = snapshot.sites.isEmpty ? null : snapshot.sites.first;
    final detail = <String>[
      'Critical ${snapshot.criticalSiteCount}',
      'Elevated ${snapshot.elevatedSiteCount}',
      'Intents ${intents.length}',
      if (leadRegion != null)
        'region ${leadRegion.regionId} ${leadRegion.heatLevel.name}',
      if (leadSite != null) 'site ${leadSite.siteId}',
    ];
    return _singleLine(detail.join(' • '), maxLength: 220);
  }

  String _globalReadinessEchoSummary(
    List<MonitoringWatchAutonomyActionPlan> intents,
  ) {
    final echoes = intents
        .where((intent) => intent.actionType.trim().toUpperCase() == 'POSTURAL ECHO')
        .toList(growable: false);
    if (echoes.isEmpty) {
      return '';
    }
    final leadSites = echoes
        .map((intent) => (intent.metadata['lead_site'] ?? '').trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final targets = echoes
        .map((intent) => (intent.metadata['echo_target'] ?? intent.siteId).trim())
        .where((value) => value.isNotEmpty)
        .take(3)
        .toList(growable: false);
    final summary = <String>[
      'Echo ${echoes.length}',
      if (leadSites.isNotEmpty) 'lead ${leadSites.take(2).join(', ')}',
      if (targets.isNotEmpty) 'target ${targets.join(', ')}',
    ];
    return _singleLine(summary.join(' • '), maxLength: 220);
  }

  String _globalReadinessTopIntentSummary(
    List<MonitoringWatchAutonomyActionPlan> intents,
  ) {
    if (intents.isEmpty) {
      return '';
    }
    final top = intents.first;
    return _singleLine(
      '${top.actionType} • ${top.siteId} • ${top.description}',
      maxLength: 220,
    );
  }

  Map<String, Object?> _globalReadinessCaseFilePayload({String? reportDate}) {
    final report = _morningSovereignReportForDate(reportDate);
    if (report == null) {
      return <String, Object?>{
        'reportDate': (reportDate ?? '').trim(),
        'available': false,
        'message': 'No morning sovereign report is available for that shift.',
      };
    }
    final snapshot = _globalReadinessSnapshotForReport(report);
    final intents = _globalReadinessIntentsForReport(report);
    final posturalEchoes = intents
        .where((intent) => intent.actionType.trim().toUpperCase() == 'POSTURAL ECHO')
        .toList(growable: false);
    final leadRegion = snapshot.regions.isEmpty ? null : snapshot.regions.first;
    final leadSite = snapshot.sites.isEmpty ? null : snapshot.sites.first;
    final history = _morningSovereignReportHistory
        .where((item) => item.date.trim() != report.date.trim())
        .toList(growable: false)
      ..sort((left, right) => right.generatedAtUtc.compareTo(left.generatedAtUtc));
    return <String, Object?>{
      'reportDate': report.date,
      'generatedAtUtc': report.generatedAtUtc.toIso8601String(),
      'modeLabel': _globalReadinessModeLabel(snapshot, intents),
      'summary': _globalReadinessSummaryForReport(
        snapshot: snapshot,
        intents: intents,
      ),
      'totalSites': snapshot.totalSites,
      'criticalSiteCount': snapshot.criticalSiteCount,
      'elevatedSiteCount': snapshot.elevatedSiteCount,
      'intentCount': intents.length,
      'posturalEchoCount': posturalEchoes.length,
      'posturalEchoSummary': _globalReadinessEchoSummary(intents),
      'topIntentSummary': _globalReadinessTopIntentSummary(intents),
      'leadRegion': leadRegion == null
          ? null
          : <String, Object?>{
              'regionId': leadRegion.regionId,
              'summary': leadRegion.summary,
              'heatLevel': leadRegion.heatLevel.name,
            },
      'leadSite': leadSite == null
          ? null
          : <String, Object?>{
              'siteId': leadSite.siteId,
              'summary': leadSite.latestSummary,
              'dominantSignals': leadSite.dominantSignals,
              'heatLevel': leadSite.heatLevel.name,
            },
      'reviewCommand': '/readinessreview ${report.date}',
      'caseFileCommand': '/readinesscase json ${report.date}',
      'topIntents': intents
          .take(5)
          .map(
            (intent) => <String, Object?>{
              'actionType': intent.actionType,
              'siteId': intent.siteId,
              'priority': intent.priority.name,
              'description': intent.description,
              'countdownSeconds': intent.countdownSeconds,
              'metadata': intent.metadata,
            },
          )
          .toList(growable: false),
      'posturalEchoes': posturalEchoes
          .take(3)
          .map(
            (intent) => <String, Object?>{
              'siteId': intent.siteId,
              'priority': intent.priority.name,
              'description': intent.description,
              'leadSite': intent.metadata['lead_site'] ?? '',
              'echoTarget': intent.metadata['echo_target'] ?? intent.siteId,
              'echoHeat': intent.metadata['echo_heat'] ?? '',
              'echoSignals': intent.metadata['echo_signals'] ?? '',
            },
          )
          .toList(growable: false),
      'history': history.take(3).map((item) {
        final itemSnapshot = _globalReadinessSnapshotForReport(item);
        final itemIntents = _globalReadinessIntentsForReport(item);
        final itemEchoCount = itemIntents
            .where(
              (intent) =>
                  intent.actionType.trim().toUpperCase() == 'POSTURAL ECHO',
            )
            .length;
        return <String, Object?>{
          'reportDate': item.date,
          'modeLabel': _globalReadinessModeLabel(itemSnapshot, itemIntents),
          'summary': _globalReadinessSummaryForReport(
            snapshot: itemSnapshot,
            intents: itemIntents,
          ),
          'posturalEchoCount': itemEchoCount,
          'topIntentSummary': _globalReadinessTopIntentSummary(itemIntents),
          'reviewCommand': '/readinessreview ${item.date}',
          'caseFileCommand': '/readinesscase json ${item.date}',
        };
      }).toList(growable: false),
    };
  }

  String _globalReadinessCaseFileCsv({String? reportDate}) {
    final payload = _globalReadinessCaseFilePayload(reportDate: reportDate);
    final history = (payload['history'] as List<Object?>?) ?? const [];
    final lines = <String>[
      'metric,value',
      'report_date,${payload['reportDate'] ?? ''}',
      'available,${payload['available'] == false ? 'false' : 'true'}',
      'generated_at_utc,${payload['generatedAtUtc'] ?? ''}',
      'mode_label,"${(payload['modeLabel'] ?? '').toString().replaceAll('"', '""')}"',
      'summary,"${(payload['summary'] ?? '').toString().replaceAll('"', '""')}"',
      'total_sites,${payload['totalSites'] ?? 0}',
      'critical_site_count,${payload['criticalSiteCount'] ?? 0}',
      'elevated_site_count,${payload['elevatedSiteCount'] ?? 0}',
      'intent_count,${payload['intentCount'] ?? 0}',
      'postural_echo_count,${payload['posturalEchoCount'] ?? 0}',
      'postural_echo_summary,"${(payload['posturalEchoSummary'] ?? '').toString().replaceAll('"', '""')}"',
      'top_intent_summary,"${(payload['topIntentSummary'] ?? '').toString().replaceAll('"', '""')}"',
      'review_command,${payload['reviewCommand'] ?? ''}',
      'case_file_command,${payload['caseFileCommand'] ?? ''}',
    ];
    final topIntents = (payload['topIntents'] as List<Object?>?) ?? const [];
    for (var i = 0; i < topIntents.length; i += 1) {
      final row = topIntents[i];
      if (row is! Map) continue;
      lines.add(
        'top_intent_${i + 1},"${(row['actionType'] ?? '').toString().replaceAll('"', '""')} • ${(row['siteId'] ?? '').toString().replaceAll('"', '""')} • ${(row['description'] ?? '').toString().replaceAll('"', '""')}"',
      );
    }
    final echoes = (payload['posturalEchoes'] as List<Object?>?) ?? const [];
    for (var i = 0; i < echoes.length; i += 1) {
      final row = echoes[i];
      if (row is! Map) continue;
      lines.add(
        'postural_echo_${i + 1},"${(row['leadSite'] ?? '').toString().replaceAll('"', '""')} -> ${(row['echoTarget'] ?? '').toString().replaceAll('"', '""')} • ${(row['echoHeat'] ?? '').toString().replaceAll('"', '""')}"',
      );
    }
    for (var i = 0; i < history.length; i += 1) {
      final row = history[i];
      if (row is! Map) continue;
      lines.add(
        'history_${i + 1},"${(row['summary'] ?? '').toString().replaceAll('"', '""')}"',
      );
      lines.add(
        'history_${i + 1}_postural_echo_count,${row['posturalEchoCount'] ?? 0}',
      );
      lines.add(
        'history_${i + 1}_top_intent_summary,"${(row['topIntentSummary'] ?? '').toString().replaceAll('"', '""')}"',
      );
      lines.add('history_${i + 1}_review_command,${row['reviewCommand'] ?? ''}');
      lines.add(
        'history_${i + 1}_case_file_command,${row['caseFileCommand'] ?? ''}',
      );
    }
    return lines.join('\n');
  }

  // ignore: unused_element
  String _morningSovereignReportAutoStatusLabel() {
    final key = (_morningSovereignReportAutoRunKey ?? '').trim();
    if (key.isEmpty) {
      return 'Auto generation pending at 06:00 local.';
    }
    return 'Auto generated for shift ending $key. Next generation runs at 06:00 local.';
  }

  String? _guardSyncReportAuditLabel() {
    final generatedAtRaw = (_guardLastSyncReportAudit['generated_at_utc'] ?? '')
        .toString()
        .trim();
    final scopeKey = (_guardLastSyncReportAudit['scope_key'] ?? '')
        .toString()
        .trim();
    final facadeMode = (_guardLastSyncReportAudit['facade_mode'] ?? '')
        .toString()
        .trim();
    final eventFilter = (_guardLastSyncReportAudit['event_filter'] ?? '')
        .toString()
        .trim();
    final mediaFilter = (_guardLastSyncReportAudit['media_filter'] ?? '')
        .toString()
        .trim();
    if (generatedAtRaw.isEmpty &&
        scopeKey.isEmpty &&
        facadeMode.isEmpty &&
        eventFilter.isEmpty &&
        mediaFilter.isEmpty) {
      return null;
    }
    final generatedAt = DateTime.tryParse(generatedAtRaw)?.toUtc();
    final timestamp = generatedAt == null
        ? generatedAtRaw
        : generatedAt.toIso8601String();
    return 'at $timestamp • scope ${scopeKey.isEmpty ? 'unknown' : scopeKey} • mode ${facadeMode.isEmpty ? 'unknown' : facadeMode} • filters e:${eventFilter.isEmpty ? 'unknown' : eventFilter} m:${mediaFilter.isEmpty ? 'unknown' : mediaFilter}';
  }

  String? _guardExportAuditClearLabel() {
    final clearedAtRaw = (_guardExportAuditClearMeta['cleared_at_utc'] ?? '')
        .toString()
        .trim();
    final scopeKey = (_guardExportAuditClearMeta['scope_key'] ?? '')
        .toString()
        .trim();
    final facadeMode = (_guardExportAuditClearMeta['facade_mode'] ?? '')
        .toString()
        .trim();
    final historyFilter = (_guardExportAuditClearMeta['history_filter'] ?? '')
        .toString()
        .trim();
    if (clearedAtRaw.isEmpty &&
        scopeKey.isEmpty &&
        facadeMode.isEmpty &&
        historyFilter.isEmpty) {
      return null;
    }
    final clearedAt = DateTime.tryParse(clearedAtRaw)?.toUtc();
    final timestamp = clearedAt == null
        ? clearedAtRaw
        : clearedAt.toIso8601String();
    return 'at $timestamp • scope ${scopeKey.isEmpty ? 'unknown' : scopeKey} • mode ${facadeMode.isEmpty ? 'unknown' : facadeMode} • history ${historyFilter.isEmpty ? 'unknown' : historyFilter}';
  }

  String? _guardShiftReplayAuditLabel() {
    final generatedAtRaw =
        (_guardLastShiftReplayAudit['generated_at_utc'] ?? '')
            .toString()
            .trim();
    final shiftId = (_guardLastShiftReplayAudit['shift_id'] ?? '')
        .toString()
        .trim();
    final eventRows =
        (_guardLastShiftReplayAudit['event_rows'] as num?)?.toInt() ?? 0;
    final mediaRows =
        (_guardLastShiftReplayAudit['media_rows'] as num?)?.toInt() ?? 0;
    if (generatedAtRaw.isEmpty && shiftId.isEmpty && eventRows == 0) {
      return null;
    }
    final generatedAt = DateTime.tryParse(generatedAtRaw)?.toUtc();
    final timestamp = generatedAt == null
        ? generatedAtRaw
        : generatedAt.toIso8601String();
    return 'at $timestamp • shift ${shiftId.isEmpty ? 'unknown' : shiftId} • rows e:$eventRows m:$mediaRows';
  }

  String? _guardCloseoutPacketAuditLabel() {
    final generatedAtRaw =
        (_guardLastCloseoutPacketAudit['generated_at_utc'] ?? '')
            .toString()
            .trim();
    final scopeKey = (_guardLastCloseoutPacketAudit['scope_key'] ?? '')
        .toString()
        .trim();
    final facadeMode = (_guardLastCloseoutPacketAudit['facade_mode'] ?? '')
        .toString()
        .trim();
    final readiness = (_guardLastCloseoutPacketAudit['readiness_state'] ?? '')
        .toString()
        .trim();
    if (generatedAtRaw.isEmpty &&
        scopeKey.isEmpty &&
        facadeMode.isEmpty &&
        readiness.isEmpty) {
      return null;
    }
    final generatedAt = DateTime.tryParse(generatedAtRaw)?.toUtc();
    return 'at ${generatedAt == null ? generatedAtRaw : generatedAt.toIso8601String()} • scope ${scopeKey.isEmpty ? 'unknown' : scopeKey} • mode ${facadeMode.isEmpty ? 'unknown' : facadeMode} • readiness ${readiness.isEmpty ? 'unknown' : readiness}';
  }

  Future<void> _persistGuardCoachingTelemetry() async {
    final persistence = await _persistenceServiceFuture;
    await persistence.saveGuardCoachingTelemetry({
      'ackCount': _guardCoachingAckCount,
      'snoozeCount': _guardCoachingSnoozeCount,
      'snoozeExpiryCount': _guardCoachingSnoozeExpiryCount,
      'recentHistory': _guardCoachingRecentHistory,
    });
  }

  void _recordGuardCoachingTelemetry({
    required String kind,
    required String ruleId,
    required String context,
    String? actorRole,
    int? minutes,
  }) {
    final now = DateTime.now().toUtc();
    final detail = switch (kind) {
      'ack' => 'acknowledged',
      'snooze' => 'snoozed${minutes == null ? '' : ' ${minutes}m'}',
      'snooze_expired' => 'snooze expired',
      _ => kind,
    };
    final actor = (actorRole ?? '').trim();
    final line =
        '[${now.toIso8601String()}] $ruleId $detail @ $context'
        '${actor.isEmpty ? '' : ' by $actor'}';
    final recent = <String>[
      line,
      ..._guardCoachingRecentHistory,
    ].take(12).toList(growable: false);
    if (mounted) {
      setState(() {
        if (kind == 'ack') _guardCoachingAckCount += 1;
        if (kind == 'snooze') _guardCoachingSnoozeCount += 1;
        if (kind == 'snooze_expired') _guardCoachingSnoozeExpiryCount += 1;
        _guardCoachingRecentHistory = recent;
      });
    }
    _persistGuardCoachingTelemetry();
  }

  Future<void> _clearGuardQueue() async {
    final repository = await _guardSyncRepositoryFuture;
    await repository.saveQueuedOperations(const []);
    await _hydrateGuardSyncState();
  }

  Future<void> _retryFailedGuardSyncOperation(String operationId) async {
    final repository = await _guardSyncRepositoryFuture;
    final retried = await repository.retryFailedOperations([operationId]);
    if (retried <= 0) {
      throw StateError(
        'Operation $operationId is not currently marked failed.',
      );
    }
    await _hydrateGuardSyncState();
  }

  Future<void> _retryFailedGuardSyncOperationsBulk(
    List<String> operationIds,
  ) async {
    final trimmed = operationIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (trimmed.isEmpty) {
      throw StateError('No operation ids provided for bulk retry.');
    }
    final repository = await _guardSyncRepositoryFuture;
    final retried = await repository.retryFailedOperations(trimmed);
    if (retried <= 0) {
      throw StateError('No failed operations were eligible for retry.');
    }
    await _hydrateGuardSyncState();
  }

  Future<void> _hydrateGuardOutcomeGovernanceTelemetry() async {
    final persistence = await _persistenceServiceFuture;
    final telemetry = await persistence.readGuardOutcomeGovernanceTelemetry();
    if (telemetry.isEmpty || !mounted) return;
    final rawHistory = telemetry['deniedAtUtc'];
    final history = rawHistory is List
        ? rawHistory
              .map((entry) => DateTime.tryParse(entry.toString())?.toUtc())
              .whereType<DateTime>()
              .toList(growable: false)
        : const <DateTime>[];
    setState(() {
      _guardOutcomePolicyDeniedCount =
          (telemetry['totalDenied'] as num?)?.toInt() ?? history.length;
      _guardOutcomePolicyDeniedLastReason = telemetry['lastDeniedReason']
          ?.toString();
      _guardOutcomePolicyDeniedHistoryUtc = history;
    });
  }

  Future<void> _persistGuardOutcomeGovernanceTelemetry() async {
    final persistence = await _persistenceServiceFuture;
    await persistence.saveGuardOutcomeGovernanceTelemetry({
      'totalDenied': _guardOutcomePolicyDeniedCount,
      'lastDeniedReason': _guardOutcomePolicyDeniedLastReason,
      'deniedAtUtc': _guardOutcomePolicyDeniedHistoryUtc
          .map((entry) => entry.toIso8601String())
          .toList(growable: false),
    });
  }

  void _recordGuardOutcomePolicyDenied(String reason) {
    final now = DateTime.now().toUtc();
    final retained = <DateTime>[
      ..._guardOutcomePolicyDeniedHistoryUtc.where(
        (entry) => now.difference(entry) <= const Duration(days: 30),
      ),
      now,
    ];
    if (mounted) {
      setState(() {
        _guardOutcomePolicyDeniedCount += 1;
        _guardOutcomePolicyDeniedLastReason = reason;
        _guardOutcomePolicyDeniedHistoryUtc = retained;
      });
    }
    _persistGuardOutcomeGovernanceTelemetry();
  }

  int _guardOutcomeDeniedInWindow(Duration window) {
    final now = DateTime.now().toUtc();
    return _guardOutcomePolicyDeniedHistoryUtc
        .where((entry) => now.difference(entry) <= window)
        .length;
  }

  // ignore: unused_element
  void _clearGuardOutcomePolicyTelemetry() {
    if (mounted) {
      setState(() {
        _guardOutcomePolicyDeniedCount = 0;
        _guardOutcomePolicyDeniedLastReason = null;
        _guardOutcomePolicyDeniedHistoryUtc = const [];
      });
    }
    _persistenceServiceFuture.then((persistence) async {
      await persistence.clearGuardOutcomeGovernanceTelemetry();
    });
  }

  DispatchProfileDraft _currentProfileDraft() {
    return DispatchProfileDraft(
      profile: _currentStressProfile,
      scenarioLabel: _currentScenarioLabel,
      tags: _currentScenarioTags,
      runNote: _currentRunNote,
      filterPresets: _savedFilterPresets,
      intelligenceSourceFilter: _currentIntelligenceSourceFilter,
      intelligenceActionFilter: _currentIntelligenceActionFilter,
      pinnedWatchIntelligenceIds: _pinnedWatchIntelligenceIds,
      dismissedIntelligenceIds: _dismissedIntelligenceIds,
      showPinnedWatchIntelligenceOnly: _showPinnedWatchIntelligenceOnly,
      showDismissedIntelligenceOnly: _showDismissedIntelligenceOnly,
      selectedIntelligenceId: _selectedIntelligenceId,
    );
  }

  Future<void> _persistStressProfile(IntakeStressProfile profile) async {
    _currentStressProfile = profile;
    final persistence = await _persistenceServiceFuture;
    await persistence.saveStressProfile(_currentProfileDraft());
  }

  Future<void> _persistScenarioDraft(
    String scenarioLabel,
    List<String> tags,
  ) async {
    _currentScenarioLabel = scenarioLabel;
    _currentScenarioTags = List<String>.from(tags);
    final persistence = await _persistenceServiceFuture;
    await persistence.saveStressProfile(_currentProfileDraft());
  }

  Future<void> _persistRunNoteDraft(String runNote) async {
    _currentRunNote = runNote;
    final persistence = await _persistenceServiceFuture;
    await persistence.saveStressProfile(_currentProfileDraft());
  }

  Future<void> _persistFilterPresets(
    List<DispatchBenchmarkFilterPreset> presets,
  ) async {
    _savedFilterPresets = List<DispatchBenchmarkFilterPreset>.from(presets);
    final persistence = await _persistenceServiceFuture;
    await persistence.saveStressProfile(_currentProfileDraft());
  }

  Future<void> _persistIntelligenceFilters(
    String sourceFilter,
    String actionFilter,
  ) async {
    _currentIntelligenceSourceFilter = sourceFilter;
    _currentIntelligenceActionFilter = actionFilter;
    final persistence = await _persistenceServiceFuture;
    await persistence.saveStressProfile(_currentProfileDraft());
  }

  Future<void> _persistIntelligenceTriage(
    List<String> pinnedWatchIntelligenceIds,
    List<String> dismissedIntelligenceIds,
  ) async {
    _pinnedWatchIntelligenceIds = List<String>.from(pinnedWatchIntelligenceIds);
    _dismissedIntelligenceIds = List<String>.from(dismissedIntelligenceIds);
    final persistence = await _persistenceServiceFuture;
    await persistence.saveStressProfile(_currentProfileDraft());
  }

  Future<void> _persistIntelligenceViewModes(
    bool showPinnedWatchIntelligenceOnly,
    bool showDismissedIntelligenceOnly,
  ) async {
    _showPinnedWatchIntelligenceOnly = showPinnedWatchIntelligenceOnly;
    _showDismissedIntelligenceOnly = showDismissedIntelligenceOnly;
    final persistence = await _persistenceServiceFuture;
    await persistence.saveStressProfile(_currentProfileDraft());
  }

  Future<void> _persistSelectedIntelligence(String intelligenceId) async {
    _selectedIntelligenceId = intelligenceId;
    final persistence = await _persistenceServiceFuture;
    await persistence.saveStressProfile(_currentProfileDraft());
  }

  Future<void> _persistClientAppDraft(
    ClientAppViewerRole viewerRole,
    Map<String, String> selectedRoomByRole,
    Map<String, bool> showAllRoomItemsByRole,
    Map<String, String> selectedIncidentReferenceByRole,
    Map<String, String> expandedIncidentReferenceByRole,
    Map<String, bool> hasTouchedIncidentExpansionByRole,
    Map<String, String> focusedIncidentReferenceByRole,
    List<ClientAppMessage> messages,
    List<ClientAppAcknowledgement> acknowledgements,
  ) async {
    _clientAppViewerRole = viewerRole;
    _clientAppSelectedRoomByRole = {
      ..._clientAppSelectedRoomByRole,
      ...selectedRoomByRole,
    };
    _clientAppShowAllRoomItemsByRole = {
      ..._clientAppShowAllRoomItemsByRole,
      ...showAllRoomItemsByRole,
    };
    _clientAppSelectedRoom =
        _clientAppSelectedRoomByRole[ClientAppViewerRole.client.name] ??
        _clientAppSelectedRoom;
    _clientAppShowAllRoomItems =
        _clientAppShowAllRoomItemsByRole[ClientAppViewerRole.client.name] ??
        _clientAppShowAllRoomItems;
    _clientAppSelectedIncidentReferenceByRole = {
      ..._clientAppSelectedIncidentReferenceByRole,
      ...selectedIncidentReferenceByRole,
    };
    _clientAppExpandedIncidentReferenceByRole = {
      ..._clientAppExpandedIncidentReferenceByRole,
      ...expandedIncidentReferenceByRole,
    };
    _clientAppHasTouchedIncidentExpansionByRole = {
      ..._clientAppHasTouchedIncidentExpansionByRole,
      ...hasTouchedIncidentExpansionByRole,
    };
    _clientAppFocusedIncidentReferenceByRole = {
      ..._clientAppFocusedIncidentReferenceByRole,
      ...focusedIncidentReferenceByRole,
    };
    _clientAppMessages = List<ClientAppMessage>.from(messages);
    _clientAppAcknowledgements = List<ClientAppAcknowledgement>.from(
      acknowledgements,
    );
    final persistence = await _persistenceServiceFuture;
    final conversation = await _clientConversationRepositoryFuture;
    await Future.wait([
      persistence.saveClientAppDraft(
        ClientAppDraft(
          viewerRole: _clientAppViewerRole,
          selectedRoom: _clientAppSelectedRoom,
          selectedRoomByRole: _clientAppSelectedRoomByRole,
          showAllRoomItemsByRole: _clientAppShowAllRoomItemsByRole,
          expandedIncidentReference:
              _clientAppExpandedIncidentReferenceByRole[ClientAppViewerRole
                  .client
                  .name],
          hasTouchedIncidentExpansion:
              _clientAppHasTouchedIncidentExpansionByRole[ClientAppViewerRole
                  .client
                  .name] ==
              true,
          selectedIncidentReferenceByRole:
              _clientAppSelectedIncidentReferenceByRole,
          expandedIncidentReferenceByRole:
              _clientAppExpandedIncidentReferenceByRole,
          hasTouchedIncidentExpansionByRole:
              _clientAppHasTouchedIncidentExpansionByRole,
          focusedIncidentReferenceByRole:
              _clientAppFocusedIncidentReferenceByRole,
        ),
      ),
      conversation.saveMessages(_clientAppMessages),
      conversation.saveAcknowledgements(_clientAppAcknowledgements),
      conversation.savePushQueue(_clientAppPushQueue),
    ]);
  }

  Future<void> _persistClientAppPushQueue(
    List<ClientAppPushDeliveryItem> pushQueue, {
    bool forceTelegramResend = false,
  }) async {
    final previousQueue = List<ClientAppPushDeliveryItem>.from(
      _clientAppPushQueue,
    );
    _clientAppPushQueue = List<ClientAppPushDeliveryItem>.from(pushQueue);
    final telegramCandidates = _newTelegramBridgeCandidates(
      previousQueue: previousQueue,
      currentQueue: _clientAppPushQueue,
      forceResend: forceTelegramResend,
    );
    if (mounted) {
      setState(() {
        _clientAppPushSyncStatusLabel = 'syncing';
      });
    }
    final conversation = await _clientConversationRepositoryFuture;
    try {
      await conversation.savePushQueue(_clientAppPushQueue);
      if (!mounted) return;
      setState(() {
        _clientAppPushSyncStatusLabel = 'ok';
        _clientAppPushLastSyncedAtUtc = DateTime.now().toUtc();
        _clientAppPushSyncFailureReason = null;
        _clientAppPushSyncRetryCount = 0;
        final updatedHistory = <ClientPushSyncAttempt>[
          ClientPushSyncAttempt(
            occurredAt: DateTime.now().toUtc(),
            status: 'ok',
            queueSize: _clientAppPushQueue.length,
          ),
          ..._clientAppPushSyncHistory,
        ];
        _clientAppPushSyncHistory = updatedHistory
            .take(20)
            .toList(growable: false);
      });
      await _persistClientPushSyncState();
      unawaited(_forwardPushQueueToTelegram(telegramCandidates));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _clientAppPushSyncStatusLabel = 'failed';
        _clientAppPushSyncFailureReason = error.toString();
        _clientAppPushSyncRetryCount += 1;
        final updatedHistory = <ClientPushSyncAttempt>[
          ClientPushSyncAttempt(
            occurredAt: DateTime.now().toUtc(),
            status: 'failed',
            failureReason: error.toString(),
            queueSize: _clientAppPushQueue.length,
          ),
          ..._clientAppPushSyncHistory,
        ];
        _clientAppPushSyncHistory = updatedHistory
            .take(20)
            .toList(growable: false);
      });
      await _persistClientPushSyncState();
    }
  }

  Future<void> _persistClientPushSyncState() async {
    final conversation = await _clientConversationRepositoryFuture;
    await conversation.savePushSyncState(
      ClientPushSyncState(
        statusLabel: _clientAppPushSyncStatusLabel,
        lastSyncedAtUtc: _clientAppPushLastSyncedAtUtc,
        failureReason: _clientAppPushSyncFailureReason,
        retryCount: _clientAppPushSyncRetryCount,
        history: _clientAppPushSyncHistory,
        backendProbeStatusLabel: _clientAppBackendProbeStatusLabel,
        backendProbeLastRunAtUtc: _clientAppBackendProbeLastRunAtUtc,
        backendProbeFailureReason: _clientAppBackendProbeFailureReason,
        backendProbeHistory: _clientAppBackendProbeHistory,
      ),
    );
  }

  String _pushDeliveryBridgeKey(ClientAppPushDeliveryItem item) {
    return '${item.messageKey}:${item.deliveryProvider.code}';
  }

  List<ClientAppPushDeliveryItem> _newTelegramBridgeCandidates({
    required List<ClientAppPushDeliveryItem> previousQueue,
    required List<ClientAppPushDeliveryItem> currentQueue,
    bool forceResend = false,
  }) {
    if (!_telegramBridge.isConfigured) {
      return const [];
    }
    if (_telegramBridgeFallbackToInApp && !forceResend) {
      return const [];
    }
    final telegramQueue = currentQueue
        .where(
          (item) =>
              item.status == ClientPushDeliveryStatus.queued &&
              (item.deliveryProvider == ClientPushDeliveryProvider.telegram ||
                  item.deliveryProvider == ClientPushDeliveryProvider.inApp),
        )
        .toList(growable: false);
    if (forceResend) {
      return telegramQueue;
    }
    final previousKeys = previousQueue.map(_pushDeliveryBridgeKey).toSet();
    return telegramQueue
        .where((item) => !previousKeys.contains(_pushDeliveryBridgeKey(item)))
        .toList(growable: false);
  }

  String _telegramMessageBodyFor(ClientAppPushDeliveryItem item) {
    final targetClientId = (item.clientId ?? '').trim().isNotEmpty
        ? item.clientId!.trim()
        : _selectedClient;
    final targetSiteId = (item.siteId ?? '').trim().isNotEmpty
        ? item.siteId!.trim()
        : _selectedSite;
    final priorityLabel = item.priority ? 'PRIORITY' : 'UPDATE';
    return 'ONYX $priorityLabel\n'
        'Client: $targetClientId\n'
        'Site: $targetSiteId\n'
        'Target: ${item.targetChannel.displayLabel}\n'
        'Title: ${item.title}\n'
        '${item.body}\n'
        'Event time: ${item.occurredAt.toUtc().toIso8601String()}\n'
        'Message key: ${item.messageKey}';
  }

  Map<String, Object?>? _telegramReplyMarkupForPushItem(
    ClientAppPushDeliveryItem item,
  ) {
    if (_telegramClientApprovalService.isVerificationMessageKey(
      item.messageKey,
    )) {
      return _telegramClientApprovalService.replyKeyboardMarkup();
    }
    if (_telegramClientApprovalService.isAllowanceMessageKey(item.messageKey)) {
      return _telegramClientApprovalService.allowanceReplyKeyboardMarkup();
    }
    return null;
  }

  bool _isPartnerEndpointLabel(String label) {
    return label.trim().toUpperCase().startsWith(_partnerEndpointLabelPrefix);
  }

  String _normalizePartnerEndpointLabel(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) {
      return 'PARTNER • Response';
    }
    if (_isPartnerEndpointLabel(trimmed)) {
      return trimmed;
    }
    return 'PARTNER • $trimmed';
  }

  _TelegramBridgeTarget? _telegramFallbackTarget() {
    final fallbackChatId = _telegramChatIdEnv.trim();
    if (fallbackChatId.isEmpty) {
      return null;
    }
    final fallbackThreadRaw = _telegramMessageThreadIdEnv.trim();
    final fallbackThreadId = fallbackThreadRaw.isEmpty
        ? null
        : int.tryParse(fallbackThreadRaw);
    return _TelegramBridgeTarget(
      chatId: fallbackChatId,
      threadId: fallbackThreadId,
      label: 'env-fallback',
    );
  }

  _TelegramBridgeTarget? _telegramPartnerFallbackTarget({
    required String clientId,
    required String siteId,
  }) {
    final fallbackChatId = _telegramPartnerChatIdEnv.trim();
    if (fallbackChatId.isEmpty) {
      return null;
    }
    final fallbackClientId = _telegramPartnerClientIdEnv.trim();
    final fallbackSiteId = _telegramPartnerSiteIdEnv.trim();
    if (fallbackClientId.isNotEmpty && fallbackClientId != clientId.trim()) {
      return null;
    }
    if (fallbackSiteId.isNotEmpty && fallbackSiteId != siteId.trim()) {
      return null;
    }
    final fallbackThreadRaw = _telegramPartnerThreadIdEnv.trim();
    final fallbackThreadId = fallbackThreadRaw.isEmpty
        ? null
        : int.tryParse(fallbackThreadRaw);
    return _TelegramBridgeTarget(
      chatId: fallbackChatId,
      threadId: fallbackThreadId,
      label: _normalizePartnerEndpointLabel(_telegramPartnerLabelEnv),
    );
  }

  Future<List<_TelegramBridgeTarget>> _resolveTelegramBridgeTargets({
    String? clientId,
    String? siteId,
  }) async {
    final resolvedClientId = (clientId ?? '').trim().isNotEmpty
        ? clientId!.trim()
        : _selectedClient;
    final resolvedSiteId = (siteId ?? '').trim().isNotEmpty
        ? siteId!.trim()
        : _selectedSite;
    final fallbackTarget = _telegramFallbackTarget();
    if (!widget.supabaseReady) {
      return fallbackTarget == null
          ? const <_TelegramBridgeTarget>[]
          : <_TelegramBridgeTarget>[fallbackTarget];
    }
    try {
      final repository = SupabaseClientMessagingBridgeRepository(
        Supabase.instance.client,
      );
      final endpoints = await repository.readActiveTelegramTargets(
        clientId: resolvedClientId,
        siteId: resolvedSiteId,
      );
      final clientTargets = endpoints
          .where((endpoint) => !_isPartnerEndpointLabel(endpoint.displayLabel))
          .toList(growable: false);
      if (clientTargets.isNotEmpty) {
        return clientTargets
            .map(
              (endpoint) => _TelegramBridgeTarget(
                chatId: endpoint.chatId,
                threadId: endpoint.threadId,
                label: endpoint.displayLabel,
              ),
            )
            .toList(growable: false);
      }
    } catch (_) {
      // Fall back to environment-level target if directory lookup fails.
    }
    return fallbackTarget == null
        ? const <_TelegramBridgeTarget>[]
        : <_TelegramBridgeTarget>[fallbackTarget];
  }

  Future<List<_TelegramBridgeTarget>> _resolveTelegramPartnerTargets({
    required String clientId,
    required String siteId,
  }) async {
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId.trim();
    final fallbackTarget = _telegramPartnerFallbackTarget(
      clientId: normalizedClientId,
      siteId: normalizedSiteId,
    );
    if (!widget.supabaseReady) {
      return fallbackTarget == null
          ? const <_TelegramBridgeTarget>[]
          : <_TelegramBridgeTarget>[fallbackTarget];
    }
    try {
      final repository = SupabaseClientMessagingBridgeRepository(
        Supabase.instance.client,
      );
      final endpoints = await repository.readActiveTelegramTargets(
        clientId: normalizedClientId,
        siteId: normalizedSiteId,
      );
      final partnerTargets = endpoints
          .where((endpoint) => _isPartnerEndpointLabel(endpoint.displayLabel))
          .map(
            (endpoint) => _TelegramBridgeTarget(
              chatId: endpoint.chatId,
              threadId: endpoint.threadId,
              label: endpoint.displayLabel,
            ),
          )
          .toList(growable: false);
      if (partnerTargets.isNotEmpty) {
        return partnerTargets;
      }
    } catch (_) {
      // Fall back to environment-level target if directory lookup fails.
    }
    return fallbackTarget == null
        ? const <_TelegramBridgeTarget>[]
        : <_TelegramBridgeTarget>[fallbackTarget];
  }

  Future<void> _forwardPushQueueToTelegram(
    List<ClientAppPushDeliveryItem> candidates,
  ) async {
    if (!_telegramBridge.isConfigured) {
      if (mounted) {
        setState(() {
          _telegramBridgeHealthLabel = 'disabled';
          _telegramBridgeHealthDetail =
              'Telegram bridge disabled or missing bot token.';
          _telegramBridgeHealthUpdatedAtUtc = DateTime.now().toUtc();
        });
      }
      return;
    }
    if (candidates.isEmpty) {
      return;
    }
    final targetCache = <String, List<_TelegramBridgeTarget>>{};
    final skippedNoTargetContexts = <String>{};
    final outbound = <TelegramBridgeMessage>[];
    for (final item in candidates) {
      final targetClientId = (item.clientId ?? '').trim().isNotEmpty
          ? item.clientId!.trim()
          : _selectedClient;
      final targetSiteId = (item.siteId ?? '').trim().isNotEmpty
          ? item.siteId!.trim()
          : _selectedSite;
      final cacheKey = '$targetClientId|$targetSiteId';
      final targets = targetCache.containsKey(cacheKey)
          ? targetCache[cacheKey]!
          : await _resolveTelegramBridgeTargets(
              clientId: targetClientId,
              siteId: targetSiteId,
            );
      targetCache[cacheKey] = targets;
      if (targets.isEmpty) {
        skippedNoTargetContexts.add('$targetClientId/$targetSiteId');
        continue;
      }
      for (final target in targets) {
        outbound.add(
          TelegramBridgeMessage(
            messageKey:
                '${_pushDeliveryBridgeKey(item)}:${target.chatId}:${target.threadId ?? ''}',
            chatId: target.chatId,
            messageThreadId: target.threadId,
            text: '${_telegramMessageBodyFor(item)}\nEndpoint: ${target.label}',
            replyMarkup: _telegramReplyMarkupForPushItem(item),
          ),
        );
      }
    }
    if (outbound.isEmpty) {
      if (!mounted) return;
      final noTargetLabel = skippedNoTargetContexts.isEmpty
          ? 'No active Telegram endpoint for $_selectedClient / $_selectedSite.'
          : 'No active Telegram endpoint for ${skippedNoTargetContexts.join(', ')}.';
      setState(() {
        final now = DateTime.now().toUtc();
        _telegramBridgeFallbackToInApp = true;
        _telegramBridgeHealthLabel = 'no-target';
        _telegramBridgeHealthDetail = noTargetLabel;
        _telegramBridgeHealthUpdatedAtUtc = now;
        _clientAppPushSyncFailureReason = _telegramBridgeHealthDetail;
        _clientAppPushSyncHistory = <ClientPushSyncAttempt>[
          ClientPushSyncAttempt(
            occurredAt: now,
            status: 'telegram-skipped',
            failureReason: noTargetLabel,
            queueSize: candidates.length,
          ),
          ..._clientAppPushSyncHistory,
        ].take(20).toList(growable: false);
      });
      await _persistClientPushSyncState();
      return;
    }
    final sentAt = DateTime.now().toUtc();
    TelegramBridgeSendResult result;
    try {
      result = await _telegramBridge.sendMessages(messages: outbound);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _telegramBridgeHealthLabel = 'degraded';
        _telegramBridgeHealthDetail = error.toString();
        _telegramBridgeHealthUpdatedAtUtc = sentAt;
        _clientAppPushSyncFailureReason = error.toString();
        _clientAppPushSyncHistory = <ClientPushSyncAttempt>[
          ClientPushSyncAttempt(
            occurredAt: sentAt,
            status: 'telegram-failed',
            failureReason: error.toString(),
            queueSize: outbound.length,
          ),
          ..._clientAppPushSyncHistory,
        ].take(20).toList(growable: false);
      });
      await _persistClientPushSyncState();
      return;
    }
    if (!mounted) return;
    if (result.failedCount == 0) {
      setState(() {
        _telegramBridgeFallbackToInApp = false;
        _telegramBridgeHealthLabel = 'ok';
        _telegramBridgeHealthDetail = 'Last Telegram delivery succeeded.';
        _telegramBridgeHealthUpdatedAtUtc = sentAt;
        _clientAppPushSyncFailureReason = null;
        _clientAppPushSyncHistory = <ClientPushSyncAttempt>[
          ClientPushSyncAttempt(
            occurredAt: sentAt,
            status: 'telegram-ok',
            queueSize: outbound.length,
          ),
          ..._clientAppPushSyncHistory,
        ].take(20).toList(growable: false);
      });
      await _persistClientPushSyncState();
      return;
    }
    final reasonValues = result.failureReasonsByMessageKey.values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final blocked = reasonValues.any(_isTelegramBlockedReason);
    final reasonSuffix = reasonValues.isEmpty
        ? ''
        : ' Reasons: ${reasonValues.take(2).join(' | ')}';
    final failureLabel =
        'Telegram bridge failed for ${result.failedCount}/${outbound.length} message(s).$reasonSuffix';
    setState(() {
      _telegramBridgeFallbackToInApp = blocked;
      _telegramBridgeHealthLabel = blocked ? 'blocked' : 'degraded';
      _telegramBridgeHealthDetail = failureLabel;
      _telegramBridgeHealthUpdatedAtUtc = sentAt;
      _clientAppPushSyncFailureReason = failureLabel;
      _clientAppPushSyncHistory = <ClientPushSyncAttempt>[
        ClientPushSyncAttempt(
          occurredAt: sentAt,
          status: blocked ? 'telegram-blocked' : 'telegram-failed',
          failureReason: failureLabel,
          queueSize: outbound.length,
        ),
        ..._clientAppPushSyncHistory,
      ].take(20).toList(growable: false);
    });
    await _persistClientPushSyncState();
  }

  bool _isTelegramBlockedReason(String raw) {
    final value = raw.trim().toUpperCase();
    if (value.isEmpty) return false;
    return value.contains('FROZEN_METHOD_INVALID') ||
        value.contains('ACCOUNT IS FROZEN') ||
        value.contains('BLOCKED') ||
        value.contains('PEER_ID_INVALID');
  }

  Future<void> _retryClientAppPushSync() async {
    await _persistClientAppPushQueue(
      _clientAppPushQueue,
      forceTelegramResend: true,
    );
  }

  Future<void> _runClientAppBackendProbe() async {
    if (mounted) {
      setState(() {
        _clientAppBackendProbeStatusLabel = 'running';
        _clientAppBackendProbeFailureReason = null;
      });
    }
    final conversation = await _clientConversationRepositoryFuture;
    final originalState = await conversation.readPushSyncState();
    final probeTimestamp = DateTime.now().toUtc();
    final probeState = ClientPushSyncState(
      statusLabel: 'probe',
      lastSyncedAtUtc: probeTimestamp,
      failureReason: null,
      retryCount: 0,
      history: [
        ClientPushSyncAttempt(
          occurredAt: probeTimestamp,
          status: 'probe',
          queueSize: _clientAppPushQueue.length,
        ),
        ...originalState.history,
      ].take(20).toList(growable: false),
      backendProbeStatusLabel: originalState.backendProbeStatusLabel,
      backendProbeLastRunAtUtc: originalState.backendProbeLastRunAtUtc,
      backendProbeFailureReason: originalState.backendProbeFailureReason,
      backendProbeHistory: originalState.backendProbeHistory,
    );
    try {
      await conversation.savePushSyncState(probeState);
      final restored = await conversation.readPushSyncState();
      if (restored.statusLabel != 'probe' || restored.history.isEmpty) {
        throw StateError('Probe readback did not return the expected marker.');
      }
      await conversation.savePushSyncState(originalState);
      if (!mounted) return;
      setState(() {
        _clientAppBackendProbeStatusLabel = 'ok';
        _clientAppBackendProbeLastRunAtUtc = probeTimestamp;
        _clientAppBackendProbeFailureReason = null;
        final updatedHistory = <ClientBackendProbeAttempt>[
          ClientBackendProbeAttempt(occurredAt: probeTimestamp, status: 'ok'),
          ..._clientAppBackendProbeHistory,
        ];
        _clientAppBackendProbeHistory = updatedHistory
            .take(20)
            .toList(growable: false);
      });
      await _persistClientPushSyncState();
    } catch (error) {
      try {
        await conversation.savePushSyncState(originalState);
      } catch (_) {
        // Preserve original error and keep runtime stable.
      }
      if (!mounted) return;
      setState(() {
        _clientAppBackendProbeStatusLabel = 'failed';
        _clientAppBackendProbeLastRunAtUtc = probeTimestamp;
        _clientAppBackendProbeFailureReason = error.toString();
        final updatedHistory = <ClientBackendProbeAttempt>[
          ClientBackendProbeAttempt(
            occurredAt: probeTimestamp,
            status: 'failed',
            failureReason: error.toString(),
          ),
          ..._clientAppBackendProbeHistory,
        ];
        _clientAppBackendProbeHistory = updatedHistory
            .take(20)
            .toList(growable: false);
      });
      await _persistClientPushSyncState();
    }
  }

  Future<void> _clearClientAppBackendProbeHistory() async {
    if (!mounted) return;
    setState(() {
      _clientAppBackendProbeHistory = const [];
      _clientAppBackendProbeStatusLabel = 'idle';
      _clientAppBackendProbeLastRunAtUtc = null;
      _clientAppBackendProbeFailureReason = null;
    });
    await _persistClientPushSyncState();
  }

  Future<void> _ingestLiveFeedBatch() async {
    final runId = _nextRunId('LIVE');
    LiveFeedBatch batch;
    try {
      batch =
          _liveFeeds.loadFromEnvironment() ??
          _buildDemoLiveFeedBatch(DateTime.now().toUtc());
    } on FormatException catch (error) {
      setState(() {
        _lastIntakeStatus = 'Live feed import failed: ${error.message}';
      });
      return;
    }
    _recordLiveIngest(runId: runId, batch: batch);
  }

  Future<void> _loadLiveFeedFile() async {
    if (!_browserFiles.supported) {
      setState(() {
        _lastIntakeStatus = 'Live feed file import is only available on web.';
      });
      return;
    }

    final raw = await _browserFiles.pickJsonFile();
    if (raw == null || raw.trim().isEmpty) {
      setState(() {
        _lastIntakeStatus = 'No live feed file selected.';
      });
      return;
    }

    try {
      final batch = _liveFeeds.parseJson(raw);
      final runId = _nextRunId('FILE');
      _recordLiveIngest(
        runId: runId,
        batch: LiveFeedBatch(
          records: batch.records,
          feedDistribution: batch.feedDistribution,
          isConfigured: batch.isConfigured,
          sourceLabel: 'uploaded file',
        ),
      );
    } on FormatException catch (error) {
      setState(() {
        _lastIntakeStatus = 'Live feed file import failed: ${error.message}';
      });
    }
  }

  Future<_OpsIntegrationIngestResult> _ingestNewsSignals({
    bool updateStatus = true,
  }) async {
    if (updateStatus && mounted) {
      setState(() {
        _lastIntakeStatus = 'Fetching news intelligence...';
      });
    }
    try {
      final batch = await _newsIntel.fetchLatest(
        clientId: _selectedClient,
        regionId: _selectedRegion,
        siteId: _selectedSite,
      );
      final runId = _nextRunId('NEWS');
      final outcome = _recordLiveIngest(
        runId: runId,
        batch: LiveFeedBatch(
          records: batch.records,
          feedDistribution: batch.feedDistribution,
          isConfigured: true,
          sourceLabel: batch.sourceLabel,
        ),
        updateStatus: updateStatus,
      );
      return _recordOpsIntegrationHealth(
        _OpsIntegrationIngestResult(
          source: 'news',
          success: true,
          detail:
              '${outcome.appendedIntelligence}/${outcome.attemptedIntelligence} appended',
        ),
      );
    } on FormatException catch (error) {
      if (updateStatus && mounted) {
        setState(() {
          _lastIntakeStatus =
              'News intelligence ingest failed: ${error.message}';
        });
      }
      return _recordOpsIntegrationHealth(
        _OpsIntegrationIngestResult(
          source: 'news',
          success: false,
          detail: error.message,
        ),
      );
    } catch (error) {
      if (updateStatus && mounted) {
        setState(() {
          _lastIntakeStatus = 'News intelligence ingest failed: $error';
        });
      }
      return _recordOpsIntegrationHealth(
        _OpsIntegrationIngestResult(
          source: 'news',
          success: false,
          detail: error.toString(),
        ),
      );
    }
  }

  Future<_OpsIntegrationIngestResult> _ingestRadioOpsSignals({
    bool updateStatus = true,
  }) async {
    if (!_opsIntegrationProfile.radio.configured) {
      if (updateStatus && mounted) {
        setState(() {
          _lastIntakeStatus =
              'Radio ingest unavailable: configure ONYX_RADIO_PROVIDER and ONYX_RADIO_LISTEN_URL.';
        });
      }
      return _recordOpsIntegrationHealth(
        const _OpsIntegrationIngestResult(
          source: 'radio',
          success: false,
          skipped: true,
          detail: 'unconfigured',
        ),
      );
    }
    if (updateStatus && mounted) {
      setState(() {
        _lastIntakeStatus = 'Fetching radio ops transmissions...';
      });
    }
    try {
      final queueFingerprintBefore = _radioQueueStateFingerprint();
      final transmissions = await _radioBridgeService.fetchLatest(
        clientId: _selectedClient,
        regionId: _selectedRegion,
        siteId: _selectedSite,
      );
      final outcome = service.ingestRadioTransmissions(
        transmissions: transmissions,
        autoCloseOnAllClear: _opsIntegrationProfile.radio.aiAutoAllClearEnabled,
      );
      var radioResponsesSent = 0;
      var radioResponseAudited = 0;
      var radioResponsesDeferred = 0;
      var radioResponsesAttempted = 0;
      final queuedResponses = _mergePendingRadioAutomatedResponses(
        _pendingRadioAutomatedResponses,
        outcome.automatedResponses,
      );
      _pendingRadioAutomatedResponses = queuedResponses;
      if (_opsIntegrationProfile.radio.duplexEnabled &&
          queuedResponses.isNotEmpty) {
        final nowUtc = DateTime.now().toUtc();
        final eligibleResponses = <RadioAutomatedResponse>[];
        final deferredResponses = <RadioAutomatedResponse>[];
        for (final response in queuedResponses) {
          final key = _radioAutomatedResponseKey(response);
          final retryState = _pendingRadioRetryByKey[key];
          final nextAttemptAtUtc = retryState?.nextAttemptAtUtc;
          if (nextAttemptAtUtc != null && nextAttemptAtUtc.isAfter(nowUtc)) {
            deferredResponses.add(response);
          } else {
            eligibleResponses.add(response);
          }
        }
        radioResponsesDeferred = deferredResponses.length;
        radioResponsesAttempted = eligibleResponses.length;
        if (eligibleResponses.isEmpty) {
          _pendingRadioAutomatedResponses = _trimPendingRadioAutomatedResponses(
            deferredResponses,
          );
          _pendingRadioRetryByKey = _pruneRadioRetryStateForResponses(
            _pendingRadioAutomatedResponses,
          );
        } else {
          final sendResult = await _radioBridgeService.sendAutomatedResponses(
            responses: eligibleResponses,
          );
          final failedByKey = <String, RadioAutomatedResponse>{};
          for (final failed in sendResult.failed) {
            failedByKey[_radioAutomatedResponseKey(failed)] = failed;
          }
          final nextRetryByKey = Map<String, _RadioPendingRetryState>.from(
            _pendingRadioRetryByKey,
          );
          for (final sent in sendResult.sent) {
            nextRetryByKey.remove(_radioAutomatedResponseKey(sent));
          }
          for (final failed in sendResult.failed) {
            final key = _radioAutomatedResponseKey(failed);
            nextRetryByKey[key] = _nextRadioRetryState(
              previous: nextRetryByKey[key],
              nowUtc: nowUtc,
              error: 'send_failed',
            );
          }
          if (sendResult.failed.isNotEmpty) {
            final firstFailed = sendResult.failed.first;
            final atLabel =
                '${nowUtc.hour.toString().padLeft(2, '0')}:${nowUtc.minute.toString().padLeft(2, '0')}:${nowUtc.second.toString().padLeft(2, '0')} UTC';
            _radioQueueLastFailureSnapshot =
                '${firstFailed.transmissionId} • reason send_failed • count ${sendResult.failed.length} • at $atLabel';
          }
          _pendingRadioRetryByKey = nextRetryByKey;
          final nextPending = <RadioAutomatedResponse>[
            ...deferredResponses,
            ...failedByKey.values,
          ];
          _pendingRadioAutomatedResponses = _trimPendingRadioAutomatedResponses(
            nextPending,
          );
          _pendingRadioRetryByKey = _pruneRadioRetryStateForResponses(
            _pendingRadioAutomatedResponses,
          );
          radioResponsesSent = sendResult.sentCount;
          if (sendResult.sent.isNotEmpty) {
            radioResponseAudited = service.recordRadioAutomatedResponses(
              responses: sendResult.sent,
            );
          }
        }
      }
      if (_radioQueueStateFingerprint() != queueFingerprintBefore) {
        _markRadioQueueStateChanged('Queue updated via ingest');
      }
      unawaited(_persistPendingRadioAutomatedResponses());
      final detail =
          '${outcome.appended}/${outcome.attempted} appended • '
          'all-clear ${outcome.allClearDetected} • '
          'panic ${outcome.panicDetected} • '
          'duress ${outcome.duressDetected} • '
          'esc ${outcome.escalationDispatchesCreated} • '
          'closed ${outcome.incidentsClosed} • '
          'attempted $radioResponsesAttempted • '
          'deferred $radioResponsesDeferred • '
          'responses $radioResponsesSent • '
          'audit $radioResponseAudited'
          '${_pendingRadioAutomatedResponses.isEmpty ? '' : ' • pending ${_pendingRadioAutomatedResponses.length}'}';
      if (updateStatus && mounted) {
        setState(() {
          _lastIntakeStatus = 'Radio ops $detail.';
        });
      }
      return _recordOpsIntegrationHealth(
        _OpsIntegrationIngestResult(
          source: 'radio',
          success: true,
          detail: detail,
        ),
      );
    } on FormatException catch (error) {
      if (updateStatus && mounted) {
        setState(() {
          _lastIntakeStatus = 'Radio ingest failed: ${error.message}';
        });
      }
      return _recordOpsIntegrationHealth(
        _OpsIntegrationIngestResult(
          source: 'radio',
          success: false,
          detail: error.message,
        ),
      );
    } catch (error) {
      if (updateStatus && mounted) {
        setState(() {
          _lastIntakeStatus = 'Radio ingest failed: $error';
        });
      }
      return _recordOpsIntegrationHealth(
        _OpsIntegrationIngestResult(
          source: 'radio',
          success: false,
          detail: error.toString(),
        ),
      );
    }
  }

  Future<_OpsIntegrationIngestResult> _ingestCctvSignals({
    bool updateStatus = true,
  }) async {
    final profile = _activeVideoProfile;
    if (!profile.configured) {
      if (updateStatus && mounted) {
        setState(() {
          _lastIntakeStatus =
              'Video ingest unavailable: configure ONYX_CCTV_PROVIDER and ONYX_CCTV_EVENTS_URL, or ONYX_DVR_PROVIDER and ONYX_DVR_EVENTS_URL.';
        });
      }
      return _recordOpsIntegrationHealth(
        const _OpsIntegrationIngestResult(
          source: 'cctv',
          success: false,
          skipped: true,
          detail: 'unconfigured',
        ),
      );
    }
    if (updateStatus && mounted) {
      setState(() {
        _lastIntakeStatus =
            'Fetching ${profile.provider.trim().isEmpty ? 'video' : profile.provider} events...';
      });
    }
    try {
      late final List<NormalizedIntelRecord> records;
      late final VideoEvidenceProbeBatchResult evidenceProbe;
      if (_hasConfiguredDvrFleet) {
        final combinedRecords = <NormalizedIntelRecord>[];
        final evidenceSnapshots = <VideoEvidenceProbeSnapshot>[];
        for (final scope in _configuredDvrScopes) {
          final bridge = _videoBridgeForDvrScope(scope);
          final scopedRecords = await bridge.fetchLatest(
            clientId: scope.clientId,
            regionId: scope.regionId,
            siteId: scope.siteId,
          );
          combinedRecords.addAll(scopedRecords);
          final scopedProbe = await _videoEvidenceProbeForDvrScope(
            scope,
          ).probeBatch(scopedRecords);
          evidenceSnapshots.add(scopedProbe.snapshot);
        }
        records = combinedRecords;
        evidenceProbe = VideoEvidenceProbeBatchResult(
          snapshot: _mergeVideoEvidenceSnapshots(evidenceSnapshots),
        );
      } else {
        records = await _videoBridgeService.fetchLatest(
          clientId: _selectedClient,
          regionId: _selectedRegion,
          siteId: _selectedSite,
        );
        evidenceProbe = await _videoEvidenceProbeService.probeBatch(records);
      }
      if (mounted) {
        setState(() {
          _cctvEvidenceHealth = evidenceProbe.snapshot;
        });
      } else {
        _cctvEvidenceHealth = evidenceProbe.snapshot;
      }
      final provider = profile.provider;
      final runId = _nextRunId('CCTV');
      final outcome = _recordLiveIngest(
        runId: runId,
        batch: LiveFeedBatch(
          records: records,
          feedDistribution: _hasConfiguredDvrFleet
              ? {
                  for (final scope in _configuredDvrScopes)
                    '${scope.provider}:${scope.siteId}': records
                        .where((entry) => entry.siteId == scope.siteId)
                        .length,
                }
              : {
                  (provider.trim().isEmpty ? 'video' : provider):
                      records.length,
                },
          isConfigured: true,
          sourceLabel: 'video-${provider.trim().isEmpty ? 'events' : provider}',
        ),
        updateStatus: updateStatus,
      );
      unawaited(_processActiveMonitoringWatchEvents(outcome.appendedEvents));
      unawaited(_bufferOfflineVideoIncidents(outcome.appendedEvents));
      return _recordOpsIntegrationHealth(
        _OpsIntegrationIngestResult(
          source: 'cctv',
          success: true,
          detail: _cctvIngestDetail(
            provider: provider,
            records: records,
            attempted: outcome.attemptedIntelligence,
            appended: outcome.appendedIntelligence,
            evidence: evidenceProbe.snapshot,
          ),
        ),
      );
    } on FormatException catch (error) {
      if (updateStatus && mounted) {
        setState(() {
          _lastIntakeStatus = 'Video ingest failed: ${error.message}';
        });
      }
      return _recordOpsIntegrationHealth(
        _OpsIntegrationIngestResult(
          source: 'cctv',
          success: false,
          detail: error.message,
        ),
      );
    } catch (error) {
      if (updateStatus && mounted) {
        setState(() {
          _lastIntakeStatus = 'Video ingest failed: $error';
        });
      }
      return _recordOpsIntegrationHealth(
        _OpsIntegrationIngestResult(
          source: 'cctv',
          success: false,
          detail: error.toString(),
        ),
      );
    }
  }

  Future<_OpsIntegrationIngestResult> _ingestWearableSignals({
    bool updateStatus = true,
  }) async {
    final provider = _wearableProviderEnv.trim();
    if (provider.isEmpty || _wearableBridgeUri == null) {
      if (updateStatus && mounted) {
        setState(() {
          _lastIntakeStatus =
              'Wearable ingest unavailable: configure ONYX_WEARABLE_PROVIDER and ONYX_WEARABLE_EVENTS_URL.';
        });
      }
      return _recordOpsIntegrationHealth(
        const _OpsIntegrationIngestResult(
          source: 'wearable',
          success: false,
          skipped: true,
          detail: 'unconfigured',
        ),
      );
    }
    if (updateStatus && mounted) {
      setState(() {
        _lastIntakeStatus = 'Fetching wearable ops signals...';
      });
    }
    try {
      final records = await _wearableBridgeService.fetchLatest(
        clientId: _selectedClient,
        regionId: _selectedRegion,
        siteId: _selectedSite,
      );
      final runId = _nextRunId('WEAR');
      final outcome = _recordLiveIngest(
        runId: runId,
        batch: LiveFeedBatch(
          records: records,
          feedDistribution: {
            (provider.isEmpty ? 'wearable' : provider): records.length,
          },
          isConfigured: true,
          sourceLabel: 'wearable-${provider.isEmpty ? 'events' : provider}',
        ),
        updateStatus: updateStatus,
      );
      return _recordOpsIntegrationHealth(
        _OpsIntegrationIngestResult(
          source: 'wearable',
          success: true,
          detail:
              '${outcome.appendedIntelligence}/${outcome.attemptedIntelligence} appended',
        ),
      );
    } on FormatException catch (error) {
      if (updateStatus && mounted) {
        setState(() {
          _lastIntakeStatus = 'Wearable ingest failed: ${error.message}';
        });
      }
      return _recordOpsIntegrationHealth(
        _OpsIntegrationIngestResult(
          source: 'wearable',
          success: false,
          detail: error.message,
        ),
      );
    } catch (error) {
      if (updateStatus && mounted) {
        setState(() {
          _lastIntakeStatus = 'Wearable ingest failed: $error';
        });
      }
      return _recordOpsIntegrationHealth(
        _OpsIntegrationIngestResult(
          source: 'wearable',
          success: false,
          detail: error.toString(),
        ),
      );
    }
  }

  Future<_ListenerAlarmAdvisoryDeliveryResult> _deliverListenerAlarmAdvisory(
    ListenerAlarmAdvisoryPipelineResult pipelineResult,
  ) async {
    final resolvedClientId = pipelineResult.resolution.envelope.clientId.trim();
    final resolvedSiteId = pipelineResult.resolution.envelope.siteId.trim();
    final targets = await _resolveTelegramPartnerTargets(
      clientId: resolvedClientId,
      siteId: resolvedSiteId,
    );
    var delivered = 0;
    var failed = 0;
    for (final target in targets) {
      final sent = await _sendTelegramMessageWithChunks(
        messageKeyPrefix:
            'tg-listener-alarm-${pipelineResult.resolution.envelope.externalId}',
        chatId: target.chatId,
        messageThreadId: target.threadId,
        responseText: pipelineResult.resolution.advisoryMessage,
        failureContext: 'listener alarm advisory send',
      );
      if (sent) {
        delivered += 1;
      } else {
        failed += 1;
      }
    }
    if (delivered > 0) {
      await _appendTelegramConversationMessage(
        clientId: resolvedClientId,
        siteId: resolvedSiteId,
        author: 'ONYX Alarm Advisory',
        body: pipelineResult.resolution.advisoryMessage,
        occurredAtUtc: pipelineResult.resolution.envelope.occurredAtUtc,
        roomKey: 'Security Desk',
        viewerRole: ClientAppViewerRole.control.name,
        incidentStatusLabel: 'Alarm Advisory Sent',
        messageSource: 'telegram',
        messageProvider: 'telegram_partner_alarm',
      );
    }

    return _ListenerAlarmAdvisoryDeliveryResult(
      targetCount: targets.length,
      deliveredCount: delivered,
      failedCount: failed,
    );
  }

  void _appendListenerAlarmAdvisoryRecorded({
    required ListenerAlarmAdvisoryPipelineResult pipelineResult,
    required _ListenerAlarmAdvisoryDeliveryResult delivery,
    required _ListenerAlarmCctvReviewResult cctvReview,
  }) {
    final envelope = pipelineResult.resolution.envelope;
    final zoneLabel = pipelineResult.resolution.scope.resolvedZoneLabel;
    final occurredAt = envelope.occurredAtUtc;
    final suffix = envelope.externalId.trim().isEmpty
        ? occurredAt.microsecondsSinceEpoch.toString()
        : envelope.externalId.trim();
    store.append(
      ListenerAlarmAdvisoryRecorded(
        eventId: 'listener-alarm-advisory-$suffix',
        sequence: 0,
        version: 1,
        occurredAt: occurredAt,
        clientId: envelope.clientId.trim(),
        regionId: envelope.regionId.trim(),
        siteId: envelope.siteId.trim(),
        externalAlarmId: envelope.externalId.trim(),
        accountNumber: envelope.accountNumber.trim(),
        partition: envelope.partition.trim(),
        zone: envelope.zone.trim(),
        zoneLabel: zoneLabel,
        eventLabel: pipelineResult.resolution.eventLabel.trim(),
        dispositionLabel: cctvReview.disposition.name,
        summary: cctvReview.summary.trim(),
        recommendation: cctvReview.recommendation.trim(),
        deliveredCount: delivery.deliveredCount,
        failedCount: delivery.failedCount,
      ),
    );
  }

  void _appendListenerAlarmFeedCycleRecorded({
    required DateTime occurredAtUtc,
    required ListenerAlarmFeedBatch batch,
    required int mapped,
    required int unmapped,
    required int duplicates,
    required int normalizationSkipped,
    required int delivered,
    required int failed,
    required int clearCount,
    required int suspiciousCount,
    required int unavailableCount,
    required int pendingCount,
    required String rejectSummary,
  }) {
    store.append(
      ListenerAlarmFeedCycleRecorded(
        eventId: 'listener-alarm-cycle-${occurredAtUtc.microsecondsSinceEpoch}',
        sequence: 0,
        version: 1,
        occurredAt: occurredAtUtc,
        sourceLabel: batch.sourceLabel,
        acceptedCount: batch.acceptedCount,
        mappedCount: mapped,
        unmappedCount: unmapped,
        duplicateCount: duplicates,
        rejectedCount: batch.rejectedCount,
        normalizationSkippedCount: normalizationSkipped,
        deliveredCount: delivered,
        failedCount: failed,
        clearCount: clearCount,
        suspiciousCount: suspiciousCount,
        unavailableCount: unavailableCount,
        pendingCount: pendingCount,
        rejectSummary: rejectSummary,
      ),
    );
  }

  void _appendListenerAlarmParityCycleRecorded({
    required DateTime occurredAtUtc,
    required String sourceLabel,
    required String legacySourceLabel,
    required String statusLabel,
    required ListenerParityReport report,
    required String driftSummary,
  }) {
    store.append(
      ListenerAlarmParityCycleRecorded(
        eventId:
            'listener-alarm-parity-${occurredAtUtc.microsecondsSinceEpoch}',
        sequence: 0,
        version: 1,
        occurredAt: occurredAtUtc,
        sourceLabel: sourceLabel,
        legacySourceLabel: legacySourceLabel,
        statusLabel: statusLabel,
        serialCount: report.serialCount,
        legacyCount: report.legacyCount,
        matchedCount: report.matchedCount,
        unmatchedSerialCount: report.unmatchedSerialCount,
        unmatchedLegacyCount: report.unmatchedLegacyCount,
        maxAllowedSkewSeconds: report.maxAllowedSkewSeconds,
        maxSkewSecondsObserved: report.maxSkewSecondsObserved,
        averageSkewSeconds: report.averageSkewSeconds,
        driftSummary: driftSummary,
        driftReasonCounts: report.driftReasonCounts,
      ),
    );
  }

  String _listenerAlarmRejectSummary(Map<String, int> counts) {
    if (counts.isEmpty) {
      return '';
    }
    final entries = counts.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .take(2)
        .map((entry) => '${entry.key} ${entry.value}')
        .join(', ');
  }

  Future<_ListenerAlarmCctvReviewResult> _reviewListenerAlarmCctv(
    ListenerAlarmAdvisoryPipelineResult pipelineResult,
  ) async {
    final envelope = pipelineResult.resolution.envelope;
    final clientId = envelope.clientId.trim();
    final regionId = envelope.regionId.trim().isEmpty
        ? _selectedRegion
        : envelope.regionId.trim();
    final siteId = envelope.siteId.trim();
    if (!_activeVideoProfile.configured) {
      return const _ListenerAlarmCctvReviewResult(
        disposition: ListenerAlarmAdvisoryDisposition.unavailable,
        summary: 'CCTV review could not be started.',
      );
    }

    try {
      final records = await _fetchListenerAlarmCctvRecords(
        clientId: clientId,
        regionId: regionId,
        siteId: siteId,
      );
      if (records.isEmpty) {
        return const _ListenerAlarmCctvReviewResult(
          disposition: ListenerAlarmAdvisoryDisposition.clear,
          summary: 'No suspicious activity detected on immediate CCTV review.',
        );
      }

      service.ingestNormalizedIntelligence(
        records: records,
        autoGenerateDispatches: false,
      );
      final scopedEvents = store
          .allEvents()
          .whereType<IntelligenceReceived>()
          .where(
            (event) =>
                event.clientId == clientId &&
                event.siteId == siteId &&
                _matchesActiveVideoProviderEvent(event),
          )
          .toList(growable: false);
      final groupedEvents = _listenerAlarmScopedVideoEventsForReview(
        scopedEvents: scopedEvents,
        occurredAtUtc: envelope.occurredAtUtc,
      );
      if (groupedEvents.isEmpty) {
        return const _ListenerAlarmCctvReviewResult(
          disposition: ListenerAlarmAdvisoryDisposition.clear,
          summary: 'No suspicious activity detected on immediate CCTV review.',
        );
      }

      final latest = groupedEvents.first;
      final review = await _monitoringWatchVisionReview.review(
        event: latest,
        authConfig: _monitoringVisionAuthConfigForScope(clientId, siteId),
        groupedEventCount: groupedEvents.length,
      );
      final assessment = _watchSceneAssessmentService.assess(
        event: latest,
        review: review,
        priorReviewedEvents: 0,
        groupedEventCount: groupedEvents.length,
      );
      final decision = _watchEscalationPolicyService.decide(assessment);
      await _recordMonitoringSceneReview(
        event: latest,
        assessment: assessment,
        review: review,
        decision: decision,
      );
      return _listenerAlarmCctvReviewResultFromDecision(
        latest: latest,
        assessment: assessment,
        review: review,
        decision: decision,
        groupedEventCount: groupedEvents.length,
      );
    } catch (_) {
      return const _ListenerAlarmCctvReviewResult(
        disposition: ListenerAlarmAdvisoryDisposition.unavailable,
        summary: 'CCTV review could not be completed.',
      );
    }
  }

  Future<List<NormalizedIntelRecord>> _fetchListenerAlarmCctvRecords({
    required String clientId,
    required String regionId,
    required String siteId,
  }) async {
    if (_hasConfiguredDvrFleet) {
      final scopeKey = _monitoringScopeKey(clientId, siteId);
      final scope = _configuredDvrScopes.cast<DvrScopeConfig?>().firstWhere(
        (entry) => entry?.scopeKey == scopeKey,
        orElse: () => null,
      );
      if (scope == null) {
        throw StateError('No DVR scope configured for $clientId/$siteId.');
      }
      return _videoBridgeForDvrScope(scope).fetchLatest(
        clientId: scope.clientId,
        regionId: scope.regionId,
        siteId: scope.siteId,
      );
    }
    return _videoBridgeService.fetchLatest(
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
    );
  }

  List<IntelligenceReceived> _listenerAlarmScopedVideoEventsForReview({
    required List<IntelligenceReceived> scopedEvents,
    required DateTime occurredAtUtc,
  }) {
    const window = Duration(minutes: 15);
    final earliest = occurredAtUtc.subtract(window);
    final latest = occurredAtUtc.add(window);
    final recent =
        scopedEvents
            .where((event) {
              return !event.occurredAt.isBefore(earliest) &&
                  !event.occurredAt.isAfter(latest);
            })
            .toList(growable: false)
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return recent;
  }

  _ListenerAlarmCctvReviewResult _listenerAlarmCctvReviewResultFromDecision({
    required IntelligenceReceived latest,
    required MonitoringWatchSceneAssessment assessment,
    required MonitoringWatchVisionReviewResult review,
    required MonitoringWatchEscalationDecision decision,
    required int groupedEventCount,
  }) {
    final cameraLabel = _monitoringCameraLabel(latest.cameraId);
    final objectLabel = assessment.objectLabel.trim().isEmpty
        ? 'Activity'
        : _humanizeScopeLabel(assessment.objectLabel.trim());
    final groupedSuffix = groupedEventCount > 1
        ? ' across $groupedEventCount correlated signals'
        : '';
    final recommendedSummary = review.summary.trim();
    final summary = !review.usedFallback && recommendedSummary.isNotEmpty
        ? recommendedSummary
        : switch (decision.kind) {
            MonitoringWatchNotificationKind.suppressed =>
              '$objectLabel reviewed on $cameraLabel$groupedSuffix. Nothing suspicious to report.',
            MonitoringWatchNotificationKind.incident =>
              '$objectLabel detected on $cameraLabel$groupedSuffix. Partner attention recommended.',
            MonitoringWatchNotificationKind.repeat =>
              'Repeat $objectLabel activity detected on $cameraLabel$groupedSuffix.',
            MonitoringWatchNotificationKind.escalationCandidate =>
              '$objectLabel detected on $cameraLabel$groupedSuffix. Escalation review triggered.',
          };
    final recommendation = switch (decision.kind) {
      MonitoringWatchNotificationKind.suppressed => '',
      MonitoringWatchNotificationKind.incident =>
        'Partner attention recommended while ONYX continues observation.',
      MonitoringWatchNotificationKind.repeat =>
        'Repeat activity observed. Escalation recommended.',
      MonitoringWatchNotificationKind.escalationCandidate =>
        'Urgent escalation recommended.',
    };
    return _ListenerAlarmCctvReviewResult(
      disposition: decision.kind == MonitoringWatchNotificationKind.suppressed
          ? ListenerAlarmAdvisoryDisposition.clear
          : ListenerAlarmAdvisoryDisposition.suspicious,
      summary: summary,
      recommendation: recommendation,
    );
  }

  Future<_OpsIntegrationIngestResult> _ingestListenerAlarmSignals({
    bool updateStatus = true,
  }) async {
    if (!_listenerAlarmFeedConfigured) {
      if (updateStatus && mounted) {
        setState(() {
          _lastIntakeStatus =
              'Listener alarm ingest unavailable: configure ONYX_LISTENER_ALARM_FEED_URL.';
        });
      }
      return _recordOpsIntegrationHealth(
        const _OpsIntegrationIngestResult(
          source: 'listener',
          success: false,
          skipped: true,
          detail: 'unconfigured',
        ),
      );
    }
    if (updateStatus && mounted) {
      setState(() {
        _lastIntakeStatus = 'Fetching listener alarm signals...';
      });
    }
    try {
      final batch = await _listenerAlarmFeedService.fetchLatest(
        clientId: 'LISTENER-RAW',
        regionId: _selectedRegion,
        siteId: 'LISTENER-RAW',
      );
      ListenerParityReport? parityReport;
      String? parityDetail;
      if (_listenerAlarmLegacyFeedConfigured) {
        try {
          final legacyBatch = await _listenerAlarmLegacyFeedService.fetchLatest(
            clientId: 'LISTENER-RAW',
            regionId: _selectedRegion,
            siteId: 'LISTENER-RAW',
          );
          parityReport = _listenerParityService.compare(
            serialEvents: batch.envelopes,
            legacyEvents: legacyBatch.envelopes,
          );
          parityDetail = parityReport.summaryLabel();
          _appendListenerAlarmParityCycleRecorded(
            occurredAtUtc: DateTime.now().toUtc(),
            sourceLabel: batch.sourceLabel,
            legacySourceLabel: legacyBatch.sourceLabel,
            statusLabel: 'ok',
            report: parityReport,
            driftSummary: parityDetail,
          );
        } catch (error) {
          parityDetail = 'parity_error ${error.toString().trim()}';
          _appendListenerAlarmParityCycleRecorded(
            occurredAtUtc: DateTime.now().toUtc(),
            sourceLabel: batch.sourceLabel,
            legacySourceLabel:
                _listenerAlarmLegacyFeedUri?.host.trim().isNotEmpty == true
                ? _listenerAlarmLegacyFeedUri!.host
                : 'legacy listener feed',
            statusLabel: 'error',
            report: ListenerParityReport(
              serialCount: batch.acceptedCount,
              legacyCount: 0,
              matchedCount: 0,
              matches: const <ListenerParityMatch>[],
              unmatchedSerial: batch.envelopes,
              unmatchedLegacy: const <ListenerSerialEnvelope>[],
              unmatchedSerialDrifts: const <ListenerParityDrift>[],
              unmatchedLegacyDrifts: const <ListenerParityDrift>[],
              maxAllowedSkewSeconds: _listenerParityService.maxSkew.inSeconds,
            ),
            driftSummary: parityDetail,
          );
        }
      }
      var mapped = 0;
      var unmapped = 0;
      var appended = 0;
      var duplicates = 0;
      var normalizationSkipped = 0;
      var delivered = 0;
      var failed = 0;
      var clearCount = 0;
      var suspiciousCount = 0;
      var unavailableCount = 0;
      var pendingCount = 0;

      for (final envelope in batch.envelopes) {
        final initialPipelineResult = _listenerAlarmAdvisoryPipeline.process(
          envelope: envelope,
          disposition: ListenerAlarmAdvisoryDisposition.pending,
        );
        if (initialPipelineResult == null) {
          unmapped += 1;
          continue;
        }
        final cctvReview = await _reviewListenerAlarmCctv(
          initialPipelineResult,
        );
        switch (cctvReview.disposition) {
          case ListenerAlarmAdvisoryDisposition.clear:
            clearCount += 1;
          case ListenerAlarmAdvisoryDisposition.suspicious:
            suspiciousCount += 1;
          case ListenerAlarmAdvisoryDisposition.unavailable:
            unavailableCount += 1;
          case ListenerAlarmAdvisoryDisposition.pending:
            pendingCount += 1;
        }
        final pipelineResult = _listenerAlarmAdvisoryPipeline.process(
          envelope: envelope,
          disposition: cctvReview.disposition,
          cctvSummary: cctvReview.summary,
          recommendation: cctvReview.recommendation,
        );
        if (pipelineResult == null) {
          continue;
        }
        mapped += 1;
        final normalizedIntel = pipelineResult.normalizedIntel;
        if (normalizedIntel == null) {
          normalizationSkipped += 1;
          continue;
        }

        final outcome = service.ingestNormalizedIntelligence(
          records: <NormalizedIntelRecord>[normalizedIntel],
          autoGenerateDispatches: false,
        );
        if (outcome.appendedIntelligence <= 0) {
          duplicates += 1;
          continue;
        }
        appended += outcome.appendedIntelligence;

        final delivery = await _deliverListenerAlarmAdvisory(pipelineResult);
        delivered += delivery.deliveredCount;
        failed += delivery.failedCount;
        _appendListenerAlarmAdvisoryRecorded(
          pipelineResult: pipelineResult,
          delivery: delivery,
          cctvReview: cctvReview,
        );
      }

      final rejectLabel = _listenerAlarmRejectSummary(batch.rejectReasonCounts);
      _appendListenerAlarmFeedCycleRecorded(
        occurredAtUtc: DateTime.now().toUtc(),
        batch: batch,
        mapped: mapped,
        unmapped: unmapped,
        duplicates: duplicates,
        normalizationSkipped: normalizationSkipped,
        delivered: delivered,
        failed: failed,
        clearCount: clearCount,
        suspiciousCount: suspiciousCount,
        unavailableCount: unavailableCount,
        pendingCount: pendingCount,
        rejectSummary: rejectLabel,
      );
      final detail =
          '$appended/${batch.acceptedCount} appended • '
          'mapped $mapped • '
          'unmapped $unmapped • '
          'dup $duplicates • '
          'rejected ${batch.rejectedCount}'
          '${rejectLabel.isEmpty ? '' : ' ($rejectLabel)'} • '
          'clear $clearCount • suspicious $suspiciousCount • unavailable $unavailableCount'
          '${pendingCount == 0 ? '' : ' • pending $pendingCount'} • '
          'partner $delivered sent'
          '${failed == 0 ? '' : ' / $failed failed'}'
          '${normalizationSkipped == 0 ? '' : ' • normalization $normalizationSkipped'}'
          '${parityDetail == null || parityDetail.isEmpty ? '' : ' • parity $parityDetail'}';
      if (updateStatus && mounted) {
        setState(() {
          _lastIntakeStatus = 'Listener alarms $detail.';
        });
      }
      return _recordOpsIntegrationHealth(
        _OpsIntegrationIngestResult(
          source: 'listener',
          success: true,
          detail: detail,
        ),
      );
    } on FormatException catch (error) {
      if (updateStatus && mounted) {
        setState(() {
          _lastIntakeStatus = 'Listener alarm ingest failed: ${error.message}';
        });
      }
      return _recordOpsIntegrationHealth(
        _OpsIntegrationIngestResult(
          source: 'listener',
          success: false,
          detail: error.message,
        ),
      );
    } catch (error) {
      if (updateStatus && mounted) {
        setState(() {
          _lastIntakeStatus = 'Listener alarm ingest failed: $error';
        });
      }
      return _recordOpsIntegrationHealth(
        _OpsIntegrationIngestResult(
          source: 'listener',
          success: false,
          detail: error.toString(),
        ),
      );
    }
  }

  List<RadioAutomatedResponse> _mergePendingRadioAutomatedResponses(
    List<RadioAutomatedResponse> pending,
    List<RadioAutomatedResponse> latest,
  ) {
    final byId = <String, RadioAutomatedResponse>{};
    for (final response in [...pending, ...latest]) {
      byId[_radioAutomatedResponseKey(response)] = response;
    }
    return _trimPendingRadioAutomatedResponses(byId.values.toList());
  }

  List<RadioAutomatedResponse> _trimPendingRadioAutomatedResponses(
    List<RadioAutomatedResponse> responses,
  ) {
    const maxPendingResponses = 200;
    if (responses.length <= maxPendingResponses) {
      return responses;
    }
    return responses.sublist(responses.length - maxPendingResponses);
  }

  Map<String, _RadioPendingRetryState> _pruneRadioRetryStateForResponses(
    List<RadioAutomatedResponse> responses,
  ) {
    final keys = responses.map(_radioAutomatedResponseKey).toSet();
    final next = <String, _RadioPendingRetryState>{};
    _pendingRadioRetryByKey.forEach((key, value) {
      if (keys.contains(key)) {
        next[key] = value;
      }
    });
    return next;
  }

  _RadioPendingRetryState _nextRadioRetryState({
    required _RadioPendingRetryState? previous,
    required DateTime nowUtc,
    required String error,
  }) {
    final attempts = (previous?.attempts ?? 0) + 1;
    final waitSeconds = _radioRetryBackoffSeconds(attempts);
    return _RadioPendingRetryState(
      attempts: attempts,
      nextAttemptAtUtc: nowUtc.add(Duration(seconds: waitSeconds)),
      lastError: error.trim(),
    );
  }

  int _radioRetryBackoffSeconds(int attempts) {
    const baseSeconds = 15;
    const capSeconds = 600;
    final normalizedAttempts = attempts < 1 ? 1 : attempts;
    final exponent = normalizedAttempts - 1;
    final shifted = exponent >= 20 ? (1 << 20) : (1 << exponent);
    final computed = baseSeconds * shifted;
    if (computed > capSeconds) {
      return capSeconds;
    }
    return computed;
  }

  String _radioAutomatedResponseKey(RadioAutomatedResponse response) {
    return [
      response.transmissionId.trim(),
      response.dispatchId?.trim() ?? '',
      response.channel.trim(),
      response.message.trim(),
    ].join('|');
  }

  _OpsIntegrationIngestResult _recordOpsIntegrationHealth(
    _OpsIntegrationIngestResult result,
  ) {
    final nowUtc = DateTime.now().toUtc();
    switch (result.source) {
      case 'radio':
        _radioOpsHealth = _radioOpsHealth.record(result, nowUtc);
        break;
      case 'cctv':
        _cctvOpsHealth = _cctvOpsHealth.record(result, nowUtc);
        break;
      case 'wearable':
        _wearableOpsHealth = _wearableOpsHealth.record(result, nowUtc);
        break;
      case 'listener':
        _listenerAlarmOpsHealth = _listenerAlarmOpsHealth.record(
          result,
          nowUtc,
        );
        break;
      case 'news':
        _newsOpsHealth = _newsOpsHealth.record(result, nowUtc);
        break;
      default:
        break;
    }
    unawaited(_persistOpsIntegrationHealthSnapshot());
    return result;
  }

  String _opsHealthSummary(_OpsIntegrationHealth health) {
    final lastRun = health.lastRunAtUtc;
    final lastLabel = lastRun == null
        ? 'never'
        : '${lastRun.hour.toString().padLeft(2, '0')}:${lastRun.minute.toString().padLeft(2, '0')}:${lastRun.second.toString().padLeft(2, '0')} UTC';
    final detail = health.lastDetail.trim();
    final compactDetail = detail.length <= 84
        ? detail
        : '${detail.substring(0, 84).trimRight()}...';
    return 'ok ${health.okCount} • fail ${health.failCount} • skip ${health.skipCount} • last $lastLabel${compactDetail.isEmpty ? '' : ' • $compactDetail'}';
  }

  String _radioQueueHealthSummary() {
    final pending = _pendingRadioAutomatedResponses;
    if (pending.isEmpty) {
      return 'pending 0 • due 0 • deferred 0 • max-attempt 0';
    }
    final nowUtc = DateTime.now().toUtc();
    var dueCount = 0;
    var deferredCount = 0;
    var maxAttempts = 0;
    DateTime? nextRetryAtUtc;
    for (final response in pending) {
      final key = _radioAutomatedResponseKey(response);
      final retry = _pendingRadioRetryByKey[key];
      final attempts = retry?.attempts ?? 0;
      if (attempts > maxAttempts) {
        maxAttempts = attempts;
      }
      final nextAttemptAtUtc = retry?.nextAttemptAtUtc;
      if (nextAttemptAtUtc != null && nextAttemptAtUtc.isAfter(nowUtc)) {
        deferredCount += 1;
        if (nextRetryAtUtc == null ||
            nextAttemptAtUtc.isBefore(nextRetryAtUtc)) {
          nextRetryAtUtc = nextAttemptAtUtc;
        }
      } else {
        dueCount += 1;
      }
    }
    final nextRetryLabel = nextRetryAtUtc == null
        ? ''
        : ' • next ${nextRetryAtUtc.hour.toString().padLeft(2, '0')}:${nextRetryAtUtc.minute.toString().padLeft(2, '0')}:${nextRetryAtUtc.second.toString().padLeft(2, '0')} UTC';
    return 'pending ${pending.length} • due $dueCount • deferred $deferredCount • max-attempt $maxAttempts$nextRetryLabel';
  }

  String _radioQueueIntentMixSummary() {
    const tracked = ['all_clear', 'panic', 'duress', 'status'];
    final counts = <String, int>{
      for (final key in tracked) key: 0,
      'unknown': 0,
    };
    for (final response in _pendingRadioAutomatedResponses) {
      final normalized = response.intent.trim().toLowerCase();
      if (counts.containsKey(normalized)) {
        counts[normalized] = (counts[normalized] ?? 0) + 1;
      } else {
        counts['unknown'] = (counts['unknown'] ?? 0) + 1;
      }
    }
    return 'pending intent mix • '
        'all_clear ${counts['all_clear']} • '
        'panic ${counts['panic']} • '
        'duress ${counts['duress']} • '
        'status ${counts['status']} • '
        'unknown ${counts['unknown']}';
  }

  String _radioAckRecentSummary(List<DispatchEvent> events) {
    final nowUtc = DateTime.now().toUtc();
    final windowStartUtc = nowUtc.subtract(const Duration(hours: 6));
    final counts = <String, int>{
      'all_clear': 0,
      'panic': 0,
      'duress': 0,
      'status': 0,
    };
    var total = 0;
    for (final event in events.whereType<IntelligenceReceived>()) {
      if (event.provider != 'onyx-radio' || event.sourceType != 'system') {
        continue;
      }
      if (event.occurredAt.toUtc().isBefore(windowStartUtc)) {
        continue;
      }
      final summary = event.summary.toLowerCase();
      String key = 'all_clear';
      if (summary.contains('intent:PANIC'.toLowerCase())) {
        key = 'panic';
      } else if (summary.contains('intent:DURESS'.toLowerCase())) {
        key = 'duress';
      } else if (summary.contains('intent:STATUS'.toLowerCase())) {
        key = 'status';
      } else if (summary.contains('intent:ALL_CLEAR'.toLowerCase())) {
        key = 'all_clear';
      } else if (event.headline.toUpperCase().contains('AI_PANIC_ACK')) {
        key = 'panic';
      } else if (event.headline.toUpperCase().contains('AI_DURESS_ACK')) {
        key = 'duress';
      } else if (event.headline.toUpperCase().contains('AI_STATUS_ACK')) {
        key = 'status';
      } else if (event.headline.toUpperCase().contains('AI_ALL_CLEAR_ACK')) {
        key = 'all_clear';
      }
      counts[key] = (counts[key] ?? 0) + 1;
      total += 1;
    }
    return 'recent ack $total (6h) • '
        'all_clear ${counts['all_clear']} • '
        'panic ${counts['panic']} • '
        'duress ${counts['duress']} • '
        'status ${counts['status']}';
  }

  String _cctvCapabilitySummary() {
    if (!_activeVideoProfile.configured) {
      return 'caps none';
    }
    final caps = _activeVideoProfile.capabilityLabels;
    final labels = <String>[
      if (caps.isNotEmpty) ...caps else 'none',
      if (_hasConfiguredDvrFleet) 'FLEET ${_configuredDvrScopes.length}',
    ];
    if (labels.isEmpty) {
      return 'caps none';
    }
    return 'caps ${labels.join(' • ')}';
  }

  String _dvrFleetScopeSummary(
    List<DispatchEvent> events, {
    int maxScopes = 3,
  }) {
    if (!_hasConfiguredDvrFleet) {
      return '';
    }
    return _fleetPresentationService.formatSummary(
      scopes: _configuredDvrScopes,
      events: events.whereType<IntelligenceReceived>(),
      nowUtc: DateTime.now().toUtc(),
      siteNameForScope: (clientId, siteId) => _monitoringSiteProfileFor(
        clientId: clientId,
        siteId: siteId,
      ).siteName,
      endpointLabelForScope: _integrationEndpointLabel,
      maxScopes: maxScopes,
    );
  }

  List<VideoFleetScopeHealthView> _tacticalFleetScopeHealth(
    List<DispatchEvent> events,
  ) {
    return _fleetPresentationService.projectHealth(
      scopes: _configuredDvrScopes,
      events: events.whereType<IntelligenceReceived>(),
      nowUtc: DateTime.now().toUtc(),
      activeWatchScopeKeys: _monitoringWatchByScope.keys.toSet(),
      scheduleForScope: _monitoringScheduleForScope,
      siteNameForScope: (clientId, siteId) => _monitoringSiteProfileFor(
        clientId: clientId,
        siteId: siteId,
      ).siteName,
      endpointLabelForScope: _integrationEndpointLabel,
      cameraLabelForId: _monitoringCameraLabel,
      outcomeCueStateByScope: _monitoringWatchOutcomeByScope,
      recoveryStateByScope: _monitoringWatchRecoveryByScope,
      watchRuntimeByScope: _monitoringWatchByScope,
    );
  }

  void _recordMonitoringWatchResyncOutcome({
    required String clientId,
    required String siteId,
    required String actor,
    required String outcome,
  }) {
    final scopeKey = _monitoringScopeKey(clientId, siteId);
    final site = _monitoringSiteProfileFor(clientId: clientId, siteId: siteId);
    final siteLabel = site.siteName.trim().isEmpty
        ? siteId
        : site.siteName.trim();
    final update = _watchResyncOutcomeRecorder.record(
      cueStateByScope: _monitoringWatchOutcomeByScope,
      auditHistory: _monitoringWatchAuditHistory,
      scopeKey: scopeKey,
      siteLabel: siteLabel,
      actor: actor,
      outcome: outcome,
      nowUtc: DateTime.now().toUtc(),
    );
    _monitoringWatchOutcomeByScope
      ..clear()
      ..addAll(update.cueStateByScope);
    _monitoringWatchAuditHistory = update.auditHistory;
    _monitoringWatchAuditSummary = update.auditSummary;
    _monitoringWatchRecoveryByScope[scopeKey] = update.recoveryState;
    unawaited(_persistMonitoringWatchAuditSummary());
    unawaited(_persistMonitoringWatchAuditHistory());
    unawaited(_persistMonitoringWatchRecoveryState());
  }

  String _cctvRecentSignalSummary(List<DispatchEvent> events) {
    final nowUtc = DateTime.now().toUtc();
    final windowStartUtc = nowUtc.subtract(const Duration(hours: 6));
    final configuredProvider = _activeVideoProfile.provider
        .trim()
        .toLowerCase();
    var total = 0;
    var intrusion = 0;
    var lineCrossing = 0;
    var motion = 0;
    var fr = 0;
    var lpr = 0;

    for (final event in events.whereType<IntelligenceReceived>()) {
      if (event.sourceType != 'hardware' && event.sourceType != 'dvr') {
        continue;
      }
      if (event.occurredAt.toUtc().isBefore(windowStartUtc)) {
        continue;
      }
      if (configuredProvider.isNotEmpty &&
          event.provider.trim().toLowerCase() != configuredProvider) {
        continue;
      }
      total += 1;
      final headline = event.headline.toLowerCase();
      final summary = event.summary.toLowerCase();
      if (headline.contains('line_crossing') ||
          summary.contains('line crossing')) {
        lineCrossing += 1;
      } else if (headline.contains('intrusion') ||
          summary.contains('intrusion') ||
          summary.contains('breach')) {
        intrusion += 1;
      } else if (headline.contains('motion') || summary.contains('motion')) {
        motion += 1;
      }
      if (headline.contains('fr_match') || summary.contains('fr:')) {
        fr += 1;
      }
      if (headline.contains('lpr_alert') || summary.contains('lpr:')) {
        lpr += 1;
      }
    }

    return 'recent video intel $total (6h) • '
        'intrusion $intrusion • '
        'line_crossing $lineCrossing • '
        'motion $motion • '
        'fr $fr • '
        'lpr $lpr';
  }

  bool _matchesActiveVideoProviderEvent(IntelligenceReceived event) {
    if (event.sourceType != 'hardware' && event.sourceType != 'dvr') {
      return false;
    }
    final configuredProvider = _activeVideoProfile.provider
        .trim()
        .toLowerCase();
    if (configuredProvider.isNotEmpty &&
        event.provider.trim().toLowerCase() != configuredProvider) {
      return false;
    }
    final expectedSourceType = _activeVideoProfile.isDvr ? 'dvr' : 'hardware';
    return event.sourceType == expectedSourceType;
  }

  IntelligenceReceived? _latestActiveVideoIntelligence(
    List<DispatchEvent> events,
  ) {
    IntelligenceReceived? latest;
    for (final event in events.whereType<IntelligenceReceived>()) {
      if (!_matchesActiveVideoProviderEvent(event)) {
        continue;
      }
      if (latest == null || event.occurredAt.isAfter(latest.occurredAt)) {
        latest = event;
      }
    }
    return latest;
  }

  String? _videoIntegrityCertificateStatus(List<DispatchEvent> events) {
    final event = _latestActiveVideoIntelligence(events);
    if (event == null) {
      return null;
    }
    final certificate = EvidenceProvenanceCertificate.fromIntelligence(event);
    if (certificate.evidenceRecordHash.trim().isEmpty) {
      return 'WARN';
    }
    return 'PASS';
  }

  String? _videoIntegrityCertificateSummary(List<DispatchEvent> events) {
    final event = _latestActiveVideoIntelligence(events);
    if (event == null) {
      return null;
    }
    final certificate = EvidenceProvenanceCertificate.fromIntelligence(event);
    final snapshotState = certificate.snapshot.isPresent
        ? 'present'
        : 'missing';
    final clipState = certificate.clip.isPresent ? 'present' : 'missing';
    return 'Latest ${_activeVideoOpsLabel.toLowerCase()} evidence certificate • '
        '${certificate.intelligenceId} • '
        'record ${certificate.evidenceRecordHash.substring(0, math.min(12, certificate.evidenceRecordHash.length))} • '
        'snapshot $snapshotState • clip $clipState';
  }

  String? _videoIntegrityCertificateJsonPreview(List<DispatchEvent> events) {
    final event = _latestActiveVideoIntelligence(events);
    if (event == null) {
      return null;
    }
    final certificate = EvidenceProvenanceCertificate.fromIntelligence(event);
    final payload = <String, Object?>{
      'certificate_type': 'onyx_evidence_integrity_certificate_preview',
      'intelligence': certificate.toJson(),
      'ledger': {
        'sealed': false,
        'note':
            'Preview only. Ledger-backed export is available from the evidence export flow.',
      },
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  String? _videoIntegrityCertificateMarkdownPreview(
    List<DispatchEvent> events,
  ) {
    final event = _latestActiveVideoIntelligence(events);
    if (event == null) {
      return null;
    }
    final certificate = EvidenceProvenanceCertificate.fromIntelligence(event);
    return [
      '# ONYX Evidence Integrity Certificate',
      '',
      '- Intelligence ID: `${certificate.intelligenceId}`',
      '- Provider: `${certificate.provider}`',
      '- Source type: `${certificate.sourceType}`',
      '- External ID: `${certificate.externalId}`',
      '- Client / Site: `${certificate.clientId}` / `${certificate.siteId}`',
      '- Occurred at UTC: `${certificate.occurredAtUtc.toIso8601String()}`',
      '- Canonical hash: `${certificate.canonicalHash}`',
      '- Evidence record hash: `${certificate.evidenceRecordHash}`',
      '- Snapshot locator hash: `${certificate.snapshot.locatorHash}`',
      '- Clip locator hash: `${certificate.clip.locatorHash}`',
      '- Ledger sealed: `false`',
      '- Ledger note: `Preview only. Ledger-backed export is available from the evidence export flow.`',
    ].join('\n');
  }

  String _cctvBridgeStatusSummary() {
    final profile = _activeVideoProfile;
    final fleetSummary = _dvrFleetScopeSummary(store.allEvents(), maxScopes: 2);
    final base = VideoBridgeHealthFormatter.bridgeStatus(
      configured: profile.configured,
      provider: _hasConfiguredDvrFleet
          ? '${profile.provider} fleet'
          : profile.provider,
      endpointLabel: _hasConfiguredDvrFleet
          ? '${_configuredDvrScopes.length} scope(s)'
          : _integrationEndpointLabel(profile.eventsUrl),
      capabilitySummary: _cctvCapabilitySummary(),
      evidence: _cctvEvidenceHealth,
      pilotEdge:
          !profile.isDvr && profile.provider.toLowerCase().contains('frigate'),
    );
    if (fleetSummary.isEmpty) {
      return base;
    }
    return '$base • $fleetSummary';
  }

  String _cctvPilotContextSummary(List<DispatchEvent> events) {
    final base = VideoBridgeHealthFormatter.pilotContext(
      configured: _activeVideoProfile.configured,
      provider: _hasConfiguredDvrFleet
          ? '${_activeVideoProfile.provider} fleet'
          : _activeVideoProfile.provider,
      recentSignalSummary: _cctvRecentSignalSummary(events),
      evidence: _cctvEvidenceHealth,
    );
    final fleetSummary = _dvrFleetScopeSummary(events);
    if (fleetSummary.isEmpty) {
      return base;
    }
    return base.isEmpty ? fleetSummary : '$base • $fleetSummary';
  }

  String _cctvIngestDetail({
    required String provider,
    required List<NormalizedIntelRecord> records,
    required int attempted,
    required int appended,
    required VideoEvidenceProbeSnapshot evidence,
  }) {
    return VideoBridgeHealthFormatter.ingestDetail(
      provider: provider,
      records: records,
      attempted: attempted,
      appended: appended,
      evidence: evidence,
      compactDetail: _compactDetail,
    );
  }

  String _cctvEvidenceSummary() {
    return VideoBridgeHealthFormatter.evidenceSummary(_cctvEvidenceHealth);
  }

  String _cctvCameraHealthSummary() {
    return VideoBridgeHealthFormatter.cameraHealthSummary(_cctvEvidenceHealth);
  }

  String _cctvOpsDetailLabel() {
    final base = _activeVideoProfile.detailLabel.trim();
    final evidence = _cctvEvidenceSummary();
    final fleetSummary = _dvrFleetScopeSummary(store.allEvents(), maxScopes: 2);
    final tuning =
        !_activeVideoProfile.isDvr && _cctvFalsePositivePolicy.enabled
        ? _cctvFalsePositivePolicy.summaryLabel()
        : '';
    final extras = [
      if (tuning.isNotEmpty) tuning,
      if (evidence.isNotEmpty) evidence,
      if (fleetSummary.isNotEmpty) fleetSummary,
    ];
    if (extras.isEmpty) {
      return base;
    }
    return '$base • ${extras.join(' • ')}';
  }

  String _integrationEndpointLabel(Uri? uri) {
    if (uri == null) {
      return '';
    }
    final authority = uri.authority.trim();
    if (authority.isNotEmpty) {
      return authority;
    }
    final path = uri.path.trim();
    return path;
  }

  OnyxVideoIntegrationProfile get _activeVideoProfile =>
      _opsIntegrationProfile.activeVideo;

  String get _activeVideoOpsLabel => _activeVideoProfile.isDvr ? 'DVR' : 'CCTV';

  List<DvrScopeConfig> _resolveDvrScopes() {
    final parsed = DvrScopeConfig.parseJson(
      _dvrScopeConfigsJsonEnv,
      fallbackClientId: _selectedClient,
      fallbackRegionId: _selectedRegion,
      fallbackSiteId: _selectedSite,
      fallbackProvider: _dvrProviderEnv,
      fallbackEventsUri: Uri.tryParse(_dvrEventsUrlEnv),
      fallbackAuthMode: _dvrAuthModeEnv,
      fallbackUsername: _dvrUsernameEnv,
      fallbackPassword: _dvrPasswordEnv,
      fallbackBearerToken: _dvrBearerTokenEnv,
    );
    if (parsed.isNotEmpty) {
      return parsed;
    }
    final fallback = DvrScopeConfig(
      clientId: _selectedClient,
      regionId: _selectedRegion,
      siteId: _selectedSite,
      provider: _dvrProviderEnv,
      eventsUri: Uri.tryParse(_dvrEventsUrlEnv),
      authMode: _dvrAuthModeEnv,
      username: _dvrUsernameEnv,
      password: _dvrPasswordEnv,
      bearerToken: _dvrBearerTokenEnv,
    );
    return fallback.configured ? <DvrScopeConfig>[fallback] : const [];
  }

  bool get _hasConfiguredDvrFleet =>
      _activeVideoProfile.isDvr && _configuredDvrScopes.isNotEmpty;

  DvrBackedVideoBridgeService _videoBridgeForDvrScope(DvrScopeConfig scope) {
    return DvrBackedVideoBridgeService(
      delegate: createDvrBridgeService(
        provider: scope.provider,
        eventsUri: scope.eventsUri,
        authMode: scope.authMode,
        bearerToken: scope.bearerToken,
        username: scope.username,
        password: scope.password,
        client: _cctvBridgeHttpClient,
      ),
    );
  }

  DvrBackedVideoEvidenceProbeService _videoEvidenceProbeForDvrScope(
    DvrScopeConfig scope,
  ) {
    return DvrBackedVideoEvidenceProbeService(
      delegate: HttpDvrEvidenceProbeService(
        client: _cctvBridgeHttpClient,
        authMode: parseDvrHttpAuthMode(scope.authMode),
        bearerToken: scope.bearerToken.trim().isEmpty
            ? null
            : scope.bearerToken.trim(),
        username: scope.username.trim().isEmpty ? null : scope.username.trim(),
        password: scope.password.isEmpty ? null : scope.password,
        maxQueueDepth: _positiveThreshold(
          _dvrEvidenceProbeQueueDepthEnv,
          fallback: 12,
        ),
        staleFrameThreshold: Duration(
          seconds: _positiveThreshold(
            _dvrEvidenceProbeStaleSecondsEnv,
            fallback: 1800,
          ),
        ),
      ),
    );
  }

  DvrHttpAuthConfig _monitoringVisionAuthConfigForScope(
    String clientId,
    String siteId,
  ) {
    final scopeKey = _monitoringScopeKey(clientId, siteId);
    final scope = _configuredDvrScopes.cast<DvrScopeConfig?>().firstWhere(
      (entry) => entry?.scopeKey == scopeKey,
      orElse: () => null,
    );
    if (scope != null) {
      return DvrHttpAuthConfig(
        mode: parseDvrHttpAuthMode(scope.authMode),
        bearerToken: scope.bearerToken.trim().isEmpty
            ? null
            : scope.bearerToken.trim(),
        username: scope.username.trim().isEmpty ? null : scope.username.trim(),
        password: scope.password.isEmpty ? null : scope.password,
      );
    }
    return DvrHttpAuthConfig(
      mode: parseDvrHttpAuthMode(_dvrAuthModeEnv),
      bearerToken: _dvrBearerTokenEnv.trim().isEmpty
          ? null
          : _dvrBearerTokenEnv.trim(),
      username: _dvrUsernameEnv.trim().isEmpty ? null : _dvrUsernameEnv.trim(),
      password: _dvrPasswordEnv.isEmpty ? null : _dvrPasswordEnv,
    );
  }

  VideoEvidenceProbeSnapshot _mergeVideoEvidenceSnapshots(
    List<VideoEvidenceProbeSnapshot> snapshots,
  ) {
    if (snapshots.isEmpty) {
      return const VideoEvidenceProbeSnapshot();
    }
    DateTime? latestRunAtUtc;
    final cameras = <VideoCameraHealth>[];
    var queueDepth = 0;
    var boundedQueueLimit = 0;
    var droppedCount = 0;
    var verifiedCount = 0;
    var failureCount = 0;
    var lastAlert = '';
    for (final snapshot in snapshots) {
      queueDepth += snapshot.queueDepth;
      boundedQueueLimit += snapshot.boundedQueueLimit;
      droppedCount += snapshot.droppedCount;
      verifiedCount += snapshot.verifiedCount;
      failureCount += snapshot.failureCount;
      if ((snapshot.lastAlert).trim().isNotEmpty) {
        lastAlert = snapshot.lastAlert.trim();
      }
      if (snapshot.lastRunAtUtc != null &&
          (latestRunAtUtc == null ||
              snapshot.lastRunAtUtc!.isAfter(latestRunAtUtc))) {
        latestRunAtUtc = snapshot.lastRunAtUtc;
      }
      cameras.addAll(snapshot.cameras);
    }
    return VideoEvidenceProbeSnapshot(
      queueDepth: queueDepth,
      boundedQueueLimit: boundedQueueLimit,
      droppedCount: droppedCount,
      verifiedCount: verifiedCount,
      failureCount: failureCount,
      lastRunAtUtc: latestRunAtUtc,
      lastAlert: lastAlert,
      cameras: cameras,
    );
  }

  VideoBridgeService _buildVideoBridgeService() {
    final profile = _activeVideoProfile;
    if (profile.isDvr) {
      return DvrBackedVideoBridgeService(
        delegate: createDvrBridgeService(
          provider: profile.provider,
          eventsUri: profile.eventsUrl,
          authMode: _dvrAuthModeEnv,
          bearerToken: _dvrBearerTokenEnv,
          username: _dvrUsernameEnv,
          password: _dvrPasswordEnv,
          client: _cctvBridgeHttpClient,
        ),
      );
    }
    return CctvBackedVideoBridgeService(
      delegate: createCctvBridgeService(
        provider: profile.provider,
        eventsUri: profile.eventsUrl,
        bearerToken: _cctvBearerTokenEnv,
        liveMonitoringEnabled: profile.liveMonitoringEnabled,
        facialRecognitionEnabled: profile.facialRecognitionEnabled,
        licensePlateRecognitionEnabled: profile.licensePlateRecognitionEnabled,
        falsePositivePolicy: _cctvFalsePositivePolicy,
        client: _cctvBridgeHttpClient,
      ),
    );
  }

  VideoEvidenceProbeService _buildVideoEvidenceProbeService() {
    final profile = _activeVideoProfile;
    if (profile.isDvr) {
      return DvrBackedVideoEvidenceProbeService(
        delegate: HttpDvrEvidenceProbeService(
          client: _cctvBridgeHttpClient,
          authMode: parseDvrHttpAuthMode(_dvrAuthModeEnv),
          bearerToken: _dvrBearerTokenEnv,
          username: _dvrUsernameEnv.trim().isEmpty
              ? null
              : _dvrUsernameEnv.trim(),
          password: _dvrPasswordEnv.isEmpty ? null : _dvrPasswordEnv,
          maxQueueDepth: _positiveThreshold(
            _dvrEvidenceProbeQueueDepthEnv,
            fallback: 12,
          ),
          staleFrameThreshold: Duration(
            seconds: _positiveThreshold(
              _dvrEvidenceProbeStaleSecondsEnv,
              fallback: 1800,
            ),
          ),
        ),
      );
    }
    return CctvBackedVideoEvidenceProbeService(
      delegate: HttpCctvEvidenceProbeService(
        client: _cctvBridgeHttpClient,
        maxQueueDepth: _positiveThreshold(
          _cctvEvidenceProbeQueueDepthEnv,
          fallback: 12,
        ),
        staleFrameThreshold: Duration(
          seconds: _positiveThreshold(
            _cctvEvidenceProbeStaleSecondsEnv,
            fallback: 1800,
          ),
        ),
      ),
    );
  }

  String _compactDetail(String value, {int maxLength = 84}) {
    final trimmed = value.trim();
    if (trimmed.length <= maxLength) {
      return trimmed;
    }
    return '${trimmed.substring(0, maxLength).trimRight()}...';
  }

  String _radioQueueFailureSummary() {
    if (_pendingRadioAutomatedResponses.isEmpty) {
      final snapshot = _radioQueueLastFailureSnapshot.trim();
      if (snapshot.isNotEmpty) {
        return 'Last failure • $snapshot';
      }
      return 'No failed radio responses pending retry.';
    }
    _RadioPendingRetryState? oldestRetry;
    String? oldestKey;
    for (final response in _pendingRadioAutomatedResponses) {
      final key = _radioAutomatedResponseKey(response);
      final retry = _pendingRadioRetryByKey[key];
      if (retry == null || retry.attempts <= 0) {
        continue;
      }
      if (oldestRetry == null) {
        oldestRetry = retry;
        oldestKey = key;
        continue;
      }
      final currentNext =
          retry.nextAttemptAtUtc ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final oldestNext =
          oldestRetry.nextAttemptAtUtc ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      if (currentNext.isBefore(oldestNext)) {
        oldestRetry = retry;
        oldestKey = key;
      }
    }
    if (oldestRetry == null) {
      final snapshot = _radioQueueLastFailureSnapshot.trim();
      if (snapshot.isNotEmpty) {
        return 'Last failure • $snapshot';
      }
      return 'No failed radio responses pending retry.';
    }
    final transmissionId = oldestKey!.split('|').first.trim();
    final reason = (oldestRetry.lastError ?? 'send_failed').trim();
    final nextRetryAtUtc = oldestRetry.nextAttemptAtUtc;
    final nextLabel = nextRetryAtUtc == null
        ? 'due now'
        : '${nextRetryAtUtc.hour.toString().padLeft(2, '0')}:${nextRetryAtUtc.minute.toString().padLeft(2, '0')}:${nextRetryAtUtc.second.toString().padLeft(2, '0')} UTC';
    final shortTransmission = transmissionId.isEmpty
        ? 'unknown'
        : transmissionId;
    return '$shortTransmission • attempts ${oldestRetry.attempts} • reason $reason • next $nextLabel';
  }

  String _radioQueueManualActionSummary() {
    final detail = _radioQueueLastManualActionDetail.trim();
    if (detail.isEmpty) {
      return 'No manual radio queue action in current session.';
    }
    return detail;
  }

  String _radioQueueFailureAuditSummary() {
    final detail = _radioQueueFailureAuditDetail.trim();
    if (detail.isEmpty) {
      return 'No failure snapshot clear recorded in current session.';
    }
    return detail;
  }

  String _radioQueueStateChangeSummary() {
    final detail = _radioQueueLastStateChangeDetail.trim();
    if (detail.isEmpty) {
      return 'No radio queue state change recorded in current session.';
    }
    return detail;
  }

  String _radioQueueStateFingerprint() {
    final pending =
        _pendingRadioAutomatedResponses
            .map(_radioAutomatedResponseKey)
            .toList(growable: false)
          ..sort();
    final retry =
        _pendingRadioRetryByKey.entries
            .map((entry) {
              final next =
                  entry.value.nextAttemptAtUtc?.toIso8601String() ?? '';
              final error = entry.value.lastError?.trim() ?? '';
              return '${entry.key}|${entry.value.attempts}|$next|$error';
            })
            .toList(growable: false)
          ..sort();
    return [
      pending.join(','),
      retry.join(','),
      _radioQueueLastFailureSnapshot.trim(),
    ].join('::');
  }

  void _markRadioQueueStateChanged(String reason, {DateTime? atUtc}) {
    final whenUtc = atUtc ?? DateTime.now().toUtc();
    final atLabel =
        '${whenUtc.hour.toString().padLeft(2, '0')}:${whenUtc.minute.toString().padLeft(2, '0')}:${whenUtc.second.toString().padLeft(2, '0')} UTC';
    final detail = '$reason • $atLabel';
    if (!mounted) {
      _radioQueueLastStateChangeDetail = detail;
      return;
    }
    setState(() {
      _radioQueueLastStateChangeDetail = detail;
    });
  }

  Future<void> _retryPendingRadioQueueNow() async {
    if (_pendingRadioAutomatedResponses.isEmpty) {
      final nowUtc = DateTime.now().toUtc();
      final atLabel =
          '${nowUtc.hour.toString().padLeft(2, '0')}:${nowUtc.minute.toString().padLeft(2, '0')}:${nowUtc.second.toString().padLeft(2, '0')} UTC';
      if (!mounted) return;
      setState(() {
        _lastIntakeStatus = 'Radio queue retry skipped: no pending responses.';
        _radioQueueLastManualActionDetail =
            'Retry requested on empty queue • $atLabel';
      });
      _markRadioQueueStateChanged(
        'Retry requested on empty queue',
        atUtc: nowUtc,
      );
      return;
    }
    final nowUtc = DateTime.now().toUtc();
    final atLabel =
        '${nowUtc.hour.toString().padLeft(2, '0')}:${nowUtc.minute.toString().padLeft(2, '0')}:${nowUtc.second.toString().padLeft(2, '0')} UTC';
    final pendingKeys = _pendingRadioAutomatedResponses
        .map(_radioAutomatedResponseKey)
        .toSet();
    if (mounted) {
      setState(() {
        final nextRetryByKey = Map<String, _RadioPendingRetryState>.from(
          _pendingRadioRetryByKey,
        );
        for (final key in pendingKeys) {
          final previous = nextRetryByKey[key];
          if (previous == null) continue;
          nextRetryByKey[key] = _RadioPendingRetryState(
            attempts: previous.attempts,
            nextAttemptAtUtc: null,
            lastError: previous.lastError,
          );
        }
        _pendingRadioRetryByKey = nextRetryByKey;
        _lastIntakeStatus =
            'Manual radio retry triggered (${pendingKeys.length} pending).';
        _radioQueueLastManualActionDetail =
            'Retry requested for ${pendingKeys.length} queued • $atLabel';
      });
    }
    _markRadioQueueStateChanged(
      'Retry requested for ${pendingKeys.length} queued',
      atUtc: nowUtc,
    );
    await _persistPendingRadioAutomatedResponses();
    await _ingestRadioOpsSignals();
  }

  Future<void> _clearPendingRadioQueue() async {
    if (_pendingRadioAutomatedResponses.isEmpty) {
      final nowUtc = DateTime.now().toUtc();
      final atLabel =
          '${nowUtc.hour.toString().padLeft(2, '0')}:${nowUtc.minute.toString().padLeft(2, '0')}:${nowUtc.second.toString().padLeft(2, '0')} UTC';
      if (!mounted) return;
      setState(() {
        _lastIntakeStatus = 'Radio queue already clear.';
        _radioQueueLastManualActionDetail =
            'Clear requested on empty queue • $atLabel';
        _radioQueueFailureAuditDetail =
            'Queue clear requested on empty queue • $atLabel';
      });
      _markRadioQueueStateChanged(
        'Clear requested on empty queue',
        atUtc: nowUtc,
      );
      return;
    }
    final clearedCount = _pendingRadioAutomatedResponses.length;
    final nowUtc = DateTime.now().toUtc();
    final atLabel =
        '${nowUtc.hour.toString().padLeft(2, '0')}:${nowUtc.minute.toString().padLeft(2, '0')}:${nowUtc.second.toString().padLeft(2, '0')} UTC';
    if (mounted) {
      setState(() {
        _pendingRadioAutomatedResponses = const [];
        _pendingRadioRetryByKey = const {};
        _radioQueueLastFailureSnapshot = '';
        _lastIntakeStatus = 'Pending radio queue cleared by controller.';
        _radioQueueLastManualActionDetail =
            'Queue cleared ($clearedCount removed) • $atLabel';
        _radioQueueFailureAuditDetail =
            'Failure snapshot cleared via queue clear • $atLabel';
      });
    }
    _markRadioQueueStateChanged(
      'Queue cleared ($clearedCount removed)',
      atUtc: nowUtc,
    );
    await _persistPendingRadioAutomatedResponses();
  }

  Future<void> _clearRadioQueueFailureSnapshotOnly() async {
    final current = _radioQueueLastFailureSnapshot.trim();
    final nowUtc = DateTime.now().toUtc();
    final atLabel =
        '${nowUtc.hour.toString().padLeft(2, '0')}:${nowUtc.minute.toString().padLeft(2, '0')}:${nowUtc.second.toString().padLeft(2, '0')} UTC';
    if (current.isEmpty) {
      if (!mounted) return;
      setState(() {
        _lastIntakeStatus = 'No persisted radio failure snapshot to clear.';
        _radioQueueLastManualActionDetail =
            'Failure snapshot clear requested on empty snapshot • $atLabel';
        _radioQueueFailureAuditDetail =
            'Failure snapshot clear requested on empty snapshot • $atLabel';
      });
      _markRadioQueueStateChanged(
        'Failure snapshot clear requested on empty snapshot',
        atUtc: nowUtc,
      );
      await _persistPendingRadioAutomatedResponses();
      return;
    }
    if (mounted) {
      setState(() {
        _radioQueueLastFailureSnapshot = '';
        _lastIntakeStatus = 'Persisted radio failure snapshot cleared.';
        _radioQueueLastManualActionDetail =
            'Failure snapshot cleared • $atLabel';
        _radioQueueFailureAuditDetail = 'Failure snapshot cleared • $atLabel';
      });
    }
    _markRadioQueueStateChanged('Failure snapshot cleared', atUtc: nowUtc);
    await _persistPendingRadioAutomatedResponses();
  }

  void _startOpsIntegrationPollingLoop() {
    if (!_opsIntegrationPollingEnabled || _opsIntegrationPollTimer != null) {
      return;
    }
    _scheduleNextOpsIntegrationPoll(1);
  }

  bool get _opsIntegrationPollingEnabled {
    if (_opsIntegrationPollIntervalSeconds <= 0) {
      return false;
    }
    return _opsIntegrationPollingAvailable;
  }

  bool get _opsIntegrationPollingAvailable {
    final wearableConfigured =
        _wearableProviderEnv.trim().isNotEmpty && _wearableBridgeUri != null;
    return _opsIntegrationProfile.radio.configured ||
        _activeVideoProfile.configured ||
        wearableConfigured ||
        _listenerAlarmFeedConfigured ||
        _newsIntel.configuredProviders.isNotEmpty;
  }

  int get _normalizedOpsIntegrationPollIntervalSeconds {
    if (_opsIntegrationPollIntervalSeconds < 15) {
      return 15;
    }
    return _opsIntegrationPollIntervalSeconds;
  }

  void _scheduleNextOpsIntegrationPoll(int delaySeconds) {
    _opsIntegrationPollTimer?.cancel();
    if (!_opsIntegrationPollingEnabled) {
      _opsIntegrationPollTimer = null;
      return;
    }
    _opsIntegrationPollTimer = Timer(Duration(seconds: delaySeconds), () {
      unawaited(_pollOpsIntegrationOnce());
    });
  }

  Future<void> _pollOpsIntegrationOnce() async {
    if (!_opsIntegrationPollingEnabled || _opsIntegrationPollInFlight) {
      return;
    }
    _opsIntegrationPollInFlight = true;
    final results = <_OpsIntegrationIngestResult>[];
    try {
      if (_opsIntegrationProfile.radio.configured) {
        results.add(await _ingestRadioOpsSignals(updateStatus: false));
      }
      if (_activeVideoProfile.configured) {
        results.add(await _ingestCctvSignals(updateStatus: false));
      }
      if (_wearableProviderEnv.trim().isNotEmpty &&
          _wearableBridgeUri != null) {
        results.add(await _ingestWearableSignals(updateStatus: false));
      }
      if (_listenerAlarmFeedConfigured) {
        results.add(await _ingestListenerAlarmSignals(updateStatus: false));
      }
      if (_newsIntel.configuredProviders.isNotEmpty) {
        results.add(await _ingestNewsSignals(updateStatus: false));
      }
      if (mounted && results.isNotEmpty) {
        setState(() {
          _lastIntakeStatus = _composeOpsIntegrationPollSummary(results);
        });
      }
    } finally {
      _opsIntegrationPollInFlight = false;
      _scheduleNextOpsIntegrationPoll(
        _normalizedOpsIntegrationPollIntervalSeconds,
      );
    }
  }

  Future<void> _recordMonitoringSceneReview({
    required IntelligenceReceived event,
    required MonitoringWatchSceneAssessment assessment,
    required MonitoringWatchVisionReviewResult review,
    required MonitoringWatchEscalationDecision decision,
  }) async {
    final intelligenceId = event.intelligenceId.trim();
    if (intelligenceId.isEmpty) {
      return;
    }
    final sceneReviewSource = review.usedFallback
        ? 'metadata-only'
        : review.sourceLabel.trim();
    final sceneReviewSummary = review.summary.trim().isEmpty
        ? assessment.rationale.join(' • ')
        : review.summary.trim();
    final record = _monitoringSceneReviewStore.buildRecord(
      intelligenceId: intelligenceId,
      evidenceRecordHash: (event.evidenceRecordHash ?? '').trim(),
      sourceLabel: sceneReviewSource,
      postureLabel: assessment.postureLabel,
      decisionLabel: decision.incidentStatusLabel,
      decisionSummary: decision.decisionSummary,
      summary: sceneReviewSummary,
      reviewedAtUtc: event.occurredAt,
    );
    _monitoringSceneReviewByIntelligenceId[intelligenceId] = record;
    await _persistMonitoringSceneReviewState();
  }

  void _startTelegramAdminControlLoop() {
    if (!_telegramInboundRouterEnabled || _telegramAdminPollTimer != null) {
      return;
    }
    debugPrint(
      'ONYX Telegram admin loop start: '
      'router=${_telegramInboundRouterEnabled ? 'on' : 'off'} '
      'admin=${_telegramAdminControlEnabled ? 'on' : 'off'} '
      'ai=${_telegramAiAssistantEnabled ? 'on' : 'off'} '
      'chat=${_resolvedTelegramAdminChatId().isEmpty ? 'unset' : _resolvedTelegramAdminChatId()} '
      'bridge=${_telegramBridge.isConfigured ? 'configured' : 'disabled'}',
    );
    _scheduleNextTelegramAdminPoll(1);
  }

  void _scheduleNextTelegramAdminPoll(int delaySeconds) {
    _telegramAdminPollTimer?.cancel();
    if (!_telegramInboundRouterEnabled) {
      _telegramAdminPollTimer = null;
      return;
    }
    _telegramAdminPollTimer = Timer(Duration(seconds: delaySeconds), () {
      unawaited(_pollTelegramAdminCommandsOnce());
    });
  }

  List<String> _splitTelegramAdminResponse(String text) {
    final content = text.trim().isEmpty ? '(no output)' : text.trim();
    if (content.length <= _telegramAdminMaxMessageChars) {
      return <String>[content];
    }
    final chunks = <String>[];
    var cursor = 0;
    while (cursor < content.length) {
      final remaining = content.length - cursor;
      if (remaining <= _telegramAdminMaxMessageChars) {
        chunks.add(content.substring(cursor));
        break;
      }
      final windowEnd = cursor + _telegramAdminMaxMessageChars;
      final slice = content.substring(cursor, windowEnd);
      var cut = slice.lastIndexOf('\n');
      if (cut < _telegramAdminMaxMessageChars ~/ 2) {
        cut = slice.lastIndexOf(' ');
      }
      if (cut <= 0) {
        cut = _telegramAdminMaxMessageChars;
      }
      chunks.add(content.substring(cursor, cursor + cut).trimRight());
      cursor += cut;
      while (cursor < content.length && content[cursor] == ' ') {
        cursor += 1;
      }
    }
    return chunks
        .where((entry) => entry.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<bool> _sendTelegramMessageWithChunks({
    required String messageKeyPrefix,
    required String chatId,
    required int? messageThreadId,
    required String responseText,
    String? failureContext,
    Map<String, Object?>? replyMarkup,
    String? parseMode,
  }) async {
    final chunks = _splitTelegramAdminResponse(responseText);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final messages = <TelegramBridgeMessage>[
      for (var index = 0; index < chunks.length; index += 1)
        TelegramBridgeMessage(
          messageKey: '$messageKeyPrefix-$index-$stamp',
          chatId: chatId,
          messageThreadId: messageThreadId,
          text: chunks[index],
          replyMarkup: index == 0 ? replyMarkup : null,
          parseMode: parseMode,
        ),
    ];
    final result = await _telegramBridge.sendMessages(messages: messages);
    if (result.failedCount <= 0) {
      return true;
    }
    final reasons = result.failureReasonsByMessageKey.values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .take(2)
        .join(' | ');
    if (mounted) {
      setState(() {
        _telegramBridgeHealthLabel = 'degraded';
        _telegramBridgeHealthDetail = reasons.isEmpty
            ? '${failureContext ?? 'Telegram response'} delivery failed.'
            : '${failureContext ?? 'Telegram response'} delivery failed: $reasons';
        _telegramBridgeHealthUpdatedAtUtc = DateTime.now().toUtc();
      });
    }
    return false;
  }

  String _telegramAdminSignalHeader() {
    final events = store.allEvents();
    final activeIncidents = _activeIncidentCount(events);
    final guardsOnline = _guardsOnlineCount(events);
    final critical = _telegramAdminCriticalAlerts();
    final criticalCount = critical.length;
    final telemetryGate = _guardTelemetryLiveReadyGateViolated
        ? 'VIOLATION'
        : 'OK';
    final hasWarningSignal =
        _telegramBridgeHealthLabel.toLowerCase() == 'degraded' ||
        _telegramBridgeHealthLabel.toLowerCase() == 'blocked' ||
        _clientAppPushSyncStatusLabel.trim().toLowerCase() == 'failed' ||
        _pendingAiActionCount(events) > 0;
    final posture = criticalCount > 0
        ? 'RED'
        : (hasWarningSignal ? 'AMBER' : 'GREEN');
    return '[$posture] ONYX SIGNAL'
        ' | critical=$criticalCount'
        ' | inc=$activeIncidents'
        ' | guards=$guardsOnline'
        ' | telemetry=${_guardTelemetryReadiness.name}/$telemetryGate'
        ' | tg=${_telegramBridgeHealthLabel.toUpperCase()}'
        ' | utc=${DateTime.now().toUtc().toIso8601String()}';
  }

  Future<bool> _sendTelegramAdminResponse({
    required int updateId,
    required String chatId,
    required int? messageThreadId,
    required String responseText,
    bool includeSignalHeader = false,
    bool includeQuickActions = true,
    bool richText = false,
  }) async {
    final payload = includeSignalHeader
        ? '${_telegramAdminSignalHeader()}\n$responseText'
        : responseText;
    return _sendTelegramMessageWithChunks(
      messageKeyPrefix: 'tg-admin-$updateId',
      chatId: chatId,
      messageThreadId: messageThreadId,
      responseText: payload,
      failureContext: 'Admin response',
      replyMarkup: includeQuickActions
          ? _telegramAdminQuickReplyMarkup()
          : null,
      parseMode: richText ? 'HTML' : null,
    );
  }

  Map<String, Object?> _telegramAdminQuickReplyMarkup() {
    return const <String, Object?>{
      'keyboard': <List<Map<String, String>>>[
        <Map<String, String>>[
          <String, String>{'text': 'Brief'},
          <String, String>{'text': 'Critical risks'},
        ],
        <Map<String, String>>[
          <String, String>{'text': 'Next 5'},
          <String, String>{'text': 'Status'},
        ],
        <Map<String, String>>[
          <String, String>{'text': 'Ack critical'},
          <String, String>{'text': 'Status full'},
        ],
      ],
      'resize_keyboard': true,
      'one_time_keyboard': false,
      'is_persistent': true,
      'input_field_placeholder': 'Ask ONYX: what should I do next?',
    };
  }

  Future<void> _pollTelegramAdminCommandsOnce() async {
    if (!_telegramInboundRouterEnabled || _telegramAdminPollInFlight) {
      return;
    }
    _telegramAdminPollInFlight = true;
    try {
      if (!_telegramAdminOffsetBootstrapped) {
        await _bootstrapTelegramAdminOffset();
      }
      final updates = await _telegramBridge.fetchUpdates(
        offset: _telegramAdminLastUpdateId == null
            ? null
            : _telegramAdminLastUpdateId! + 1,
        limit: 40,
      );
      if (updates.isEmpty) {
        return;
      }
      final adminChatId = _resolvedTelegramAdminChatId();
      final adminThreadId = _resolvedTelegramAdminThreadId();
      for (final update in updates) {
        _telegramAdminLastUpdateId = update.updateId;
        if (update.fromIsBot) {
          continue;
        }
        final handledAdmin = await _handleTelegramAdminInboundUpdate(
          update,
          adminChatId: adminChatId,
          adminThreadId: adminThreadId,
        );
        var handled = handledAdmin;
        if (handledAdmin) {
          if (mounted) {
            setState(() {});
          }
          continue;
        }
        final handledPartner = await _handleTelegramPartnerInboundUpdate(
          update,
          adminChatId: adminChatId,
          adminThreadId: adminThreadId,
        );
        handled = handled || handledPartner;
        if (handledPartner) {
          if (mounted) {
            setState(() {});
          }
          continue;
        }
        final handledAi = await _handleTelegramAiInboundUpdate(
          update,
          adminChatId: adminChatId,
          adminThreadId: adminThreadId,
        );
        handled = handled || handledAi;
        if (handled && mounted) {
          setState(() {});
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _telegramBridgeHealthLabel = 'degraded';
          _telegramBridgeHealthDetail = 'Admin command poll failed: $error';
          _telegramBridgeHealthUpdatedAtUtc = DateTime.now().toUtc();
        });
      }
    } finally {
      _telegramAdminPollInFlight = false;
      unawaited(
        _maybeSendTelegramAdminCriticalDigest(source: 'admin-control-loop'),
      );
      _scheduleNextTelegramAdminPoll(
        _normalizedTelegramAdminPollIntervalSeconds,
      );
    }
  }

  Future<bool> _handleTelegramAdminInboundUpdate(
    TelegramBridgeInboundMessage update, {
    required String adminChatId,
    required int? adminThreadId,
  }) async {
    final inAdminChat =
        update.chatId.trim() == adminChatId &&
        (adminThreadId == null || update.messageThreadId == adminThreadId);
    if (!inAdminChat) {
      return false;
    }
    final parsed = _telegramAdminCommand(update.text);
    if (!_isTelegramAdminSenderAllowed(update)) {
      final senderIdLabel = update.fromUserId?.toString() ?? 'unknown';
      final aclLabel = _telegramAdminAllowedUserIds.isEmpty
          ? 'none'
          : _telegramAdminAllowedUserIds.join(',');
      if (parsed?.command == 'whoami') {
        await _sendTelegramAdminResponse(
          updateId: update.updateId,
          chatId: adminChatId,
          messageThreadId: adminThreadId,
          responseText:
              '${_telegramAdminWhoAmISnapshot(update)}\n'
              'ACL status: denied for command scope.\n'
              'Current allow list: $aclLabel\n'
              'Ask an authorized admin to run /acl add $senderIdLabel.',
          includeSignalHeader: false,
        );
      } else {
        await _sendTelegramAdminResponse(
          updateId: update.updateId,
          chatId: adminChatId,
          messageThreadId: adminThreadId,
          responseText:
              'ONYX ADMIN ACL DENY\n'
              'sender_user_id=$senderIdLabel is not allowed.\n'
              'Allowed user ids: $aclLabel\n'
              'Ask an authorized admin to run /acl add $senderIdLabel.\n'
              'Then retry your command.',
          includeSignalHeader: false,
        );
      }
      return true;
    }
    if (parsed != null) {
      final allowReadOnlyWhileControlDisabled =
          !_telegramAdminControlEnabled &&
          _telegramAdminReadOnlyCommand(parsed.command);
      if (_telegramAdminControlEnabled || allowReadOnlyWhileControlDisabled) {
        final response = await _telegramAdminResponseFor(
          parsed.command,
          update,
          arguments: parsed.arguments,
        );
        final richText = _telegramAdminUseRichTextForCommand(
          parsed.command,
          arguments: parsed.arguments,
        );
        final renderedResponse = richText
            ? _telegramAdminRenderCommandCard(parsed.command, response)
            : response;
        await _sendTelegramAdminResponse(
          updateId: update.updateId,
          chatId: adminChatId,
          messageThreadId: adminThreadId,
          responseText: renderedResponse,
          richText: richText,
        );
        _telegramAdminLastCommandAtUtc = DateTime.now().toUtc();
        final origin = update.fromUsername?.trim().isNotEmpty == true
            ? '@${update.fromUsername!.trim()}'
            : (update.fromUserId?.toString() ?? 'unknown');
        _telegramAdminLastCommandSummary = '/${parsed.command} by $origin';
        final auditEntry =
            '/${parsed.command}${parsed.arguments.isEmpty ? '' : ' ${parsed.arguments}'} by $origin (${update.chatId}${update.messageThreadId == null ? '' : '#${update.messageThreadId}'}) @ ${_telegramAdminLastCommandAtUtc!.toIso8601String()}';
        _telegramAdminCommandAudit = <String>[
          auditEntry,
          ..._telegramAdminCommandAudit,
        ].take(40).toList(growable: false);
        unawaited(_persistTelegramAdminRuntimeState());
        return true;
      }
      await _sendTelegramAdminResponse(
        updateId: update.updateId,
        chatId: adminChatId,
        messageThreadId: adminThreadId,
        responseText:
            'ONYX ADMIN CONTROL DISABLED\n'
            'Command "/${parsed.command}" is blocked by runtime config.\n'
            'Allowed while disabled: status, brief, next, critical, ops, incidents, whoami, help.\n'
            'Set ONYX_TELEGRAM_ADMIN_CONTROL_ENABLED=true to unlock full command set.',
        includeSignalHeader: false,
      );
      return true;
    }
    if (!_telegramAiAssistantEnabled) {
      return true;
    }
    final aiDraft = _telegramAiAssistant.isConfigured
        ? await _telegramAiAssistant.draftReply(
            audience: TelegramAiAudience.admin,
            messageText: update.text,
            clientId: _telegramAdminTargetClientId,
            siteId: _telegramAdminTargetSiteId,
          )
        : TelegramAiDraftReply(
            text: _telegramAdminConversationalFallback(update.text),
            usedFallback: true,
            providerLabel: 'local-router',
          );
    final delivered = await _sendTelegramAdminResponse(
      updateId: update.updateId,
      chatId: adminChatId,
      messageThreadId: adminThreadId,
      responseText: aiDraft.text,
    );
    _telegramAdminLastCommandAtUtc = DateTime.now().toUtc();
    _telegramAdminLastCommandSummary =
        'free-text by ${_telegramInboundAuthor(update)}';
    _telegramAiLastHandledAtUtc = DateTime.now().toUtc();
    _telegramAiLastHandledSummary =
        'admin/${delivered ? 'sent' : 'failed'} • ${aiDraft.providerLabel}';
    await _appendTelegramAiLedger(
      clientId: _telegramAdminTargetClientId,
      siteId: _telegramAdminTargetSiteId,
      lane: 'admin',
      action: delivered ? 'sent' : 'send_failed',
      inboundText: update.text,
      outboundText: aiDraft.text,
      providerLabel: aiDraft.providerLabel,
      update: update,
    );
    return true;
  }

  Future<bool> _handleTelegramPartnerInboundUpdate(
    TelegramBridgeInboundMessage update, {
    required String adminChatId,
    required int? adminThreadId,
  }) async {
    final target = await _resolveInboundPartnerTarget(
      chatId: update.chatId,
      messageThreadId: update.messageThreadId,
    );
    if (target == null) {
      return false;
    }
    final siteId = (target.siteId ?? '').trim().isEmpty
        ? 'default'
        : target.siteId!.trim();
    final action = _telegramPartnerDispatchService.parseActionText(update.text);
    if (action == null) {
      await _sendTelegramMessageWithChunks(
        messageKeyPrefix: 'tg-partner-help-${update.updateId}',
        chatId: update.chatId,
        messageThreadId: update.messageThreadId,
        responseText:
            'ONYX partner lane\n'
            'Reply with ACCEPT, ON SITE, ALL CLEAR, or CANCEL.\n'
            'If multiple dispatches are active, reply to the dispatch card or include the dispatch id, for example: ON SITE DSP-1001.',
        failureContext: 'Partner dispatch guidance',
        replyMarkup: _telegramPartnerDispatchService.replyKeyboardMarkup(),
      );
      return true;
    }
    final openContexts = _openPartnerDispatchContextsForScope(
      clientId: target.clientId,
      siteId: siteId,
    );
    if (openContexts.isEmpty) {
      await _sendTelegramMessageWithChunks(
        messageKeyPrefix: 'tg-partner-none-${update.updateId}',
        chatId: update.chatId,
        messageThreadId: update.messageThreadId,
        responseText:
            'ONYX found no open partner dispatches for ${target.clientId}/$siteId. Control should resend the dispatch if needed.',
        failureContext: 'Partner dispatch missing context',
      );
      return true;
    }
    final requestedDispatchId = _dispatchIdFromPartnerUpdate(
      update,
      clientId: target.clientId,
      siteId: siteId,
    );
    final matchingContexts = requestedDispatchId == null
        ? openContexts
        : openContexts
              .where(
                (context) =>
                    context.dispatchId.toUpperCase() ==
                    requestedDispatchId.toUpperCase(),
              )
              .toList(growable: false);
    if (matchingContexts.isEmpty) {
      await _sendTelegramMessageWithChunks(
        messageKeyPrefix: 'tg-partner-unknown-${update.updateId}',
        chatId: update.chatId,
        messageThreadId: update.messageThreadId,
        responseText:
            'ONYX could not match that dispatch id in ${target.clientId}/$siteId.\n'
            'Open dispatches: ${openContexts.map((context) => context.dispatchId).join(', ')}',
        failureContext: 'Partner dispatch unknown dispatch id',
      );
      return true;
    }
    if (matchingContexts.length > 1) {
      await _sendTelegramMessageWithChunks(
        messageKeyPrefix: 'tg-partner-ambiguous-${update.updateId}',
        chatId: update.chatId,
        messageThreadId: update.messageThreadId,
        responseText:
            'ONYX needs the dispatch id because multiple partner dispatches are active.\n'
            'Reply to the dispatch card or send: ${action.label} ${matchingContexts.first.dispatchId}\n'
            'Open dispatches: ${matchingContexts.map((context) => context.dispatchId).join(', ')}',
        failureContext: 'Partner dispatch ambiguous context',
      );
      return true;
    }
    final actorLabel = update.fromUsername?.trim().isNotEmpty == true
        ? '@${update.fromUsername!.trim()}'
        : _telegramInboundAuthor(update);
    final occurredAtUtc = update.sentAtUtc ?? DateTime.now().toUtc();
    final resolution = _telegramPartnerDispatchService.resolveReply(
      action: action,
      context: matchingContexts.single,
      actorLabel: actorLabel,
      occurredAtUtc: occurredAtUtc,
      events: store.allEvents(),
    );
    if (resolution == null) {
      await _sendTelegramMessageWithChunks(
        messageKeyPrefix: 'tg-partner-invalid-${update.updateId}',
        chatId: update.chatId,
        messageThreadId: update.messageThreadId,
        responseText:
            'ONYX could not apply ${action.label} for ${matchingContexts.single.dispatchId}.\n'
            'The dispatch may already be closed or that transition is not allowed.',
        failureContext: 'Partner dispatch invalid transition',
      );
      return true;
    }
    store.append(resolution.event);
    await _sendTelegramMessageWithChunks(
      messageKeyPrefix: 'tg-partner-confirm-${update.updateId}',
      chatId: update.chatId,
      messageThreadId: update.messageThreadId,
      responseText:
          '${_telegramPartnerDispatchService.partnerConfirmationText(action)}\n'
          'Dispatch: ${matchingContexts.single.dispatchId}',
      failureContext: 'Partner dispatch acknowledgement',
      replyMarkup: _telegramPartnerDispatchService.replyKeyboardMarkup(),
    );
    await _appendTelegramConversationMessage(
      clientId: target.clientId,
      siteId: siteId,
      author: matchingContexts.single.partnerLabel,
      body:
          'Partner declared ${action.label} for ${matchingContexts.single.dispatchId} via Telegram by $actorLabel.',
      occurredAtUtc: occurredAtUtc,
      roomKey: 'Security Desk',
      viewerRole: ClientAppViewerRole.control.name,
      incidentStatusLabel: resolution.clientStatusLabel,
      messageSource: 'telegram',
      messageProvider: 'partner_dispatch',
    );
    if (adminChatId.trim().isNotEmpty) {
      await _sendTelegramMessageWithChunks(
        messageKeyPrefix: 'tg-admin-partner-${update.updateId}',
        chatId: adminChatId,
        messageThreadId: adminThreadId,
        responseText: resolution.adminAuditSummary,
        failureContext: 'Admin partner dispatch relay',
      );
    }
    return true;
  }

  Future<bool> _handleTelegramAiInboundUpdate(
    TelegramBridgeInboundMessage update, {
    required String adminChatId,
    required int? adminThreadId,
  }) async {
    if (!_telegramAiAssistantEnabled) {
      return false;
    }
    final trimmed = update.text.trim();
    if (trimmed.isEmpty || trimmed.startsWith('/')) {
      return false;
    }
    final target = await _resolveInboundClientTarget(
      chatId: update.chatId,
      messageThreadId: update.messageThreadId,
    );
    if (target == null) {
      return false;
    }
    final siteId = (target.siteId ?? '').trim().isEmpty
        ? 'default'
        : target.siteId!.trim();
    await _appendTelegramConversationMessage(
      clientId: target.clientId,
      siteId: siteId,
      author: _telegramInboundAuthor(update),
      body: trimmed,
      occurredAtUtc: update.sentAtUtc ?? DateTime.now().toUtc(),
      roomKey: 'Residents',
      viewerRole: ClientAppViewerRole.client.name,
      incidentStatusLabel: 'Telegram Inbound',
      messageSource: 'telegram',
      messageProvider: 'telegram',
    );
    final canNotifyAdmin = adminChatId.trim().isNotEmpty;
    final handledClientApproval = await _handleTelegramClientApprovalReply(
      update: update,
      target: target,
      siteId: siteId,
      adminChatId: adminChatId,
      adminThreadId: adminThreadId,
    );
    if (handledClientApproval) {
      return true;
    }
    final handledClientAllowance = await _handleTelegramClientAllowanceReply(
      update: update,
      target: target,
      siteId: siteId,
      adminChatId: adminChatId,
      adminThreadId: adminThreadId,
    );
    if (handledClientAllowance) {
      return true;
    }
    final handledIdentityIntake = await _handleTelegramIdentityIntake(
      update: update,
      target: target,
      siteId: siteId,
      adminChatId: adminChatId,
      adminThreadId: adminThreadId,
    );
    if (handledIdentityIntake) {
      return true;
    }
    if (_isHighRiskTelegramMessage(trimmed)) {
      const escalationText =
          'ONYX ALERT RECEIVED: your message is marked high-priority and has been escalated to the control room.';
      await _sendTelegramMessageWithChunks(
        messageKeyPrefix: 'tg-client-escalated-${update.updateId}',
        chatId: update.chatId,
        messageThreadId: update.messageThreadId,
        responseText: escalationText,
        failureContext: 'Client escalation acknowledgement',
      );
      await _appendTelegramConversationMessage(
        clientId: target.clientId,
        siteId: siteId,
        author: 'ONYX AI',
        body: escalationText,
        occurredAtUtc: DateTime.now().toUtc(),
        roomKey: 'Residents',
        viewerRole: ClientAppViewerRole.client.name,
        incidentStatusLabel: 'Escalated',
        messageSource: 'telegram',
        messageProvider: 'ai_policy',
      );
      if (canNotifyAdmin) {
        await _sendTelegramMessageWithChunks(
          messageKeyPrefix: 'tg-admin-escalated-${update.updateId}',
          chatId: adminChatId,
          messageThreadId: adminThreadId,
          responseText:
              'ONYX AI escalation\n'
              'scope=${target.clientId}/$siteId\n'
              'chat=${update.chatId}${update.messageThreadId == null ? '' : '#${update.messageThreadId}'}\n'
              'from=${update.fromUsername?.trim().isNotEmpty == true ? '@${update.fromUsername!.trim()}' : (update.fromUserId?.toString() ?? 'unknown')}\n'
              'message=${_singleLine(trimmed)}',
          failureContext: 'Admin escalation relay',
        );
      }
      _telegramAiLastHandledAtUtc = DateTime.now().toUtc();
      _telegramAiLastHandledSummary = '${target.clientId}/$siteId • escalated';
      await _appendTelegramAiLedger(
        clientId: target.clientId,
        siteId: siteId,
        lane: 'client',
        action: 'escalated',
        inboundText: update.text,
        outboundText: escalationText,
        providerLabel: 'policy:high-risk',
        update: update,
      );
      return true;
    }
    final aiDraft = await _telegramAiAssistant.draftReply(
      audience: TelegramAiAudience.client,
      messageText: update.text,
      clientId: target.clientId,
      siteId: siteId,
    );
    if (_telegramAiApprovalRequired && canNotifyAdmin) {
      final pending = _TelegramAiPendingDraft(
        inboundUpdateId: update.updateId,
        chatId: update.chatId,
        messageThreadId: update.messageThreadId,
        audience: 'client',
        clientId: target.clientId,
        siteId: siteId,
        sourceText: update.text.trim(),
        draftText: aiDraft.text,
        providerLabel: aiDraft.providerLabel,
        createdAtUtc: DateTime.now().toUtc(),
      );
      _telegramAiPendingDrafts = <_TelegramAiPendingDraft>[
        pending,
        ..._telegramAiPendingDrafts.where(
          (entry) => entry.inboundUpdateId != pending.inboundUpdateId,
        ),
      ].take(100).toList(growable: false);
      _telegramAiLastHandledAtUtc = pending.createdAtUtc;
      _telegramAiLastHandledSummary = '${target.clientId}/$siteId • pending';
      await _appendTelegramConversationMessage(
        clientId: target.clientId,
        siteId: siteId,
        author: 'ONYX AI',
        body: 'Pending approval reply draft: ${aiDraft.text}',
        occurredAtUtc: pending.createdAtUtc,
        roomKey: 'Security Desk',
        viewerRole: ClientAppViewerRole.control.name,
        incidentStatusLabel: 'Pending Approval',
        messageSource: 'telegram',
        messageProvider: aiDraft.providerLabel,
      );
      await _sendTelegramMessageWithChunks(
        messageKeyPrefix: 'tg-admin-draft-${update.updateId}',
        chatId: adminChatId,
        messageThreadId: adminThreadId,
        responseText:
            'ONYX AI draft pending approval\n'
            'update_id=${pending.inboundUpdateId}\n'
            'scope=${pending.clientId}/${pending.siteId}\n'
            'chat=${pending.chatId}${pending.messageThreadId == null ? '' : '#${pending.messageThreadId}'}\n'
            'source=${_singleLine(pending.sourceText)}\n'
            'draft=${_singleLine(pending.draftText)}\n'
            'approve=/aiapprove ${pending.inboundUpdateId} • reject=/aireject ${pending.inboundUpdateId}',
        failureContext: 'Admin draft relay',
      );
      await _appendTelegramAiLedger(
        clientId: target.clientId,
        siteId: siteId,
        lane: 'client',
        action: 'draft_pending',
        inboundText: update.text,
        outboundText: aiDraft.text,
        providerLabel: aiDraft.providerLabel,
        update: update,
      );
      unawaited(_persistTelegramAdminRuntimeState());
      return true;
    }
    final delivered = await _sendTelegramMessageWithChunks(
      messageKeyPrefix: 'tg-client-ai-${update.updateId}',
      chatId: update.chatId,
      messageThreadId: update.messageThreadId,
      responseText: aiDraft.text,
      failureContext: 'Client AI response',
    );
    _telegramAiLastHandledAtUtc = DateTime.now().toUtc();
    _telegramAiLastHandledSummary =
        '${target.clientId}/$siteId • ${delivered ? 'sent' : 'failed'}';
    await _appendTelegramConversationMessage(
      clientId: target.clientId,
      siteId: siteId,
      author: 'ONYX AI',
      body: aiDraft.text,
      occurredAtUtc: DateTime.now().toUtc(),
      roomKey: delivered ? 'Residents' : 'Security Desk',
      viewerRole: delivered
          ? ClientAppViewerRole.client.name
          : ClientAppViewerRole.control.name,
      incidentStatusLabel: delivered ? 'Reply Sent' : 'Reply Failed',
      messageSource: 'telegram',
      messageProvider: aiDraft.providerLabel,
    );
    await _appendTelegramAiLedger(
      clientId: target.clientId,
      siteId: siteId,
      lane: 'client',
      action: delivered ? 'sent' : 'send_failed',
      inboundText: update.text,
      outboundText: aiDraft.text,
      providerLabel: aiDraft.providerLabel,
      update: update,
    );
    return true;
  }

  Future<void> _bootstrapTelegramAdminOffset() async {
    try {
      final seed = await _telegramBridge.fetchUpdates(offset: -1, limit: 1);
      if (seed.isNotEmpty) {
        _telegramAdminLastUpdateId = seed.last.updateId;
      }
      _telegramAdminOffsetBootstrapped = true;
      _telegramAdminOffsetBootstrappedAtUtc = DateTime.now().toUtc();
    } catch (_) {
      // Fall back to normal polling path if bootstrap probe fails.
      _telegramAdminOffsetBootstrapped = true;
      _telegramAdminOffsetBootstrappedAtUtc = DateTime.now().toUtc();
    }
  }

  Future<_TelegramInboundPartnerTarget?> _resolveInboundPartnerTarget({
    required String chatId,
    required int? messageThreadId,
  }) async {
    final normalizedChatId = chatId.trim();
    if (normalizedChatId.isEmpty) {
      return null;
    }
    if (widget.supabaseReady) {
      try {
        final rowsRaw = await Supabase.instance.client
            .from('client_messaging_endpoints')
            .select('client_id, site_id, display_label, telegram_thread_id')
            .eq('provider', 'telegram')
            .eq('is_active', true)
            .eq('telegram_chat_id', normalizedChatId)
            .order('verified_at', ascending: false)
            .order('created_at', ascending: false);
        final rows = List<Map<String, dynamic>>.from(rowsRaw)
            .where(
              (row) => _isPartnerEndpointLabel(
                (row['display_label'] ?? '').toString(),
              ),
            )
            .toList(growable: false);
        if (rows.isNotEmpty) {
          Map<String, dynamic>? pick;

          int? rowThread(Map<String, dynamic> row) {
            final raw = (row['telegram_thread_id'] ?? '').toString().trim();
            if (raw.isEmpty) return null;
            return int.tryParse(raw);
          }

          if (messageThreadId != null) {
            pick = rows.cast<Map<String, dynamic>?>().firstWhere(
              (row) => row != null && rowThread(row) == messageThreadId,
              orElse: () => null,
            );
          }
          pick ??= rows.cast<Map<String, dynamic>?>().firstWhere(
            (row) => row != null && rowThread(row) == null,
            orElse: () => null,
          );
          pick ??= rows.first;
          final clientId = (pick['client_id'] ?? '').toString().trim();
          if (clientId.isNotEmpty) {
            return _TelegramInboundPartnerTarget(
              clientId: clientId,
              siteId: (pick['site_id'] ?? '').toString().trim().isEmpty
                  ? null
                  : (pick['site_id'] ?? '').toString().trim(),
              displayLabel: _normalizePartnerEndpointLabel(
                (pick['display_label'] ?? '').toString(),
              ),
            );
          }
        }
      } catch (_) {
        // Fall through to environment fallback.
      }
    }
    final fallbackChatId = _telegramPartnerChatIdEnv.trim();
    if (fallbackChatId.isEmpty || fallbackChatId != normalizedChatId) {
      return null;
    }
    final fallbackThreadRaw = _telegramPartnerThreadIdEnv.trim();
    final fallbackThreadId = fallbackThreadRaw.isEmpty
        ? null
        : int.tryParse(fallbackThreadRaw);
    if (fallbackThreadId != null && fallbackThreadId != messageThreadId) {
      return null;
    }
    final clientId = _telegramPartnerClientIdEnv.trim().isEmpty
        ? _selectedClient
        : _telegramPartnerClientIdEnv.trim();
    final siteId = _telegramPartnerSiteIdEnv.trim().isEmpty
        ? _selectedSite
        : _telegramPartnerSiteIdEnv.trim();
    if (clientId.trim().isEmpty || siteId.trim().isEmpty) {
      return null;
    }
    return _TelegramInboundPartnerTarget(
      clientId: clientId,
      siteId: siteId,
      displayLabel: _normalizePartnerEndpointLabel(_telegramPartnerLabelEnv),
    );
  }

  String? _dispatchIdFromTelegramText(String text) {
    final match = RegExp(
      r'\bDSP-[A-Z0-9-]+\b',
      caseSensitive: false,
    ).firstMatch(text.toUpperCase());
    return match?.group(0)?.trim();
  }

  void _rememberPartnerDispatchBinding({
    required String chatId,
    required int? threadId,
    required int telegramMessageId,
    required TelegramPartnerDispatchContext context,
    required DateTime sentAtUtc,
  }) {
    final normalizedChatId = chatId.trim();
    if (normalizedChatId.isEmpty || telegramMessageId <= 0) {
      return;
    }
    final nowUtc = sentAtUtc.toUtc();
    final fresh = <_TelegramPartnerDispatchBinding>[
      _TelegramPartnerDispatchBinding(
        chatId: normalizedChatId,
        threadId: threadId,
        telegramMessageId: telegramMessageId,
        dispatchId: context.dispatchId,
        clientId: context.clientId,
        siteId: context.siteId,
        sentAtUtc: nowUtc,
      ),
      ..._telegramPartnerDispatchBindings.where((entry) {
        final age = nowUtc.difference(entry.sentAtUtc.toUtc());
        if (age > const Duration(days: 7)) {
          return false;
        }
        return !(entry.chatId.trim() == normalizedChatId &&
            entry.threadId == threadId &&
            entry.telegramMessageId == telegramMessageId);
      }),
    ].take(200).toList(growable: false);
    _telegramPartnerDispatchBindings = fresh;
    unawaited(_persistTelegramAdminRuntimeState());
  }

  String? _dispatchIdFromPartnerBinding(
    TelegramBridgeInboundMessage update, {
    required String clientId,
    required String siteId,
  }) {
    final replyToMessageId = update.replyToMessageId;
    if (replyToMessageId == null || replyToMessageId <= 0) {
      return null;
    }
    for (final entry in _telegramPartnerDispatchBindings) {
      if (entry.chatId.trim() != update.chatId.trim()) {
        continue;
      }
      if (entry.threadId != update.messageThreadId) {
        continue;
      }
      if (entry.telegramMessageId != replyToMessageId) {
        continue;
      }
      if (entry.clientId != clientId.trim() || entry.siteId != siteId.trim()) {
        continue;
      }
      return entry.dispatchId.trim().isEmpty ? null : entry.dispatchId.trim();
    }
    return null;
  }

  String? _dispatchIdFromPartnerUpdate(
    TelegramBridgeInboundMessage update, {
    required String clientId,
    required String siteId,
  }) {
    final direct = _dispatchIdFromTelegramText(update.text);
    if (direct != null) {
      return direct;
    }
    final bound = _dispatchIdFromPartnerBinding(
      update,
      clientId: clientId,
      siteId: siteId,
    );
    if (bound != null) {
      return bound;
    }
    final replyText = (update.replyToText ?? '').trim();
    if (replyText.isEmpty) {
      return null;
    }
    return _dispatchIdFromTelegramText(replyText);
  }

  String _partnerDispatchMessageKey(String dispatchId) {
    return '${TelegramPartnerDispatchService.dispatchMessageKeyPrefix}-${dispatchId.toLowerCase()}';
  }

  TelegramPartnerDispatchContext? _partnerDispatchContextForDecision(
    DecisionCreated decision,
  ) {
    final siteProfile = _monitoringSiteProfileFor(
      clientId: decision.clientId,
      siteId: decision.siteId,
    );
    final latestIntel =
        store
            .allEvents()
            .whereType<IntelligenceReceived>()
            .where(
              (event) =>
                  event.clientId == decision.clientId &&
                  event.siteId == decision.siteId,
            )
            .toList(growable: false)
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final incidentSummary = latestIntel.isEmpty
        ? 'Dispatch execution sent to partner. Awaiting acknowledgement.'
        : _singleLine(
            latestIntel.first.headline.trim().isEmpty
                ? latestIntel.first.summary
                : '${latestIntel.first.headline} • ${latestIntel.first.summary}',
            maxLength: 180,
          );
    return TelegramPartnerDispatchContext(
      messageKey: _partnerDispatchMessageKey(decision.dispatchId),
      dispatchId: decision.dispatchId,
      clientId: decision.clientId,
      regionId: decision.regionId,
      siteId: decision.siteId,
      siteName: siteProfile.siteName,
      incidentSummary: incidentSummary,
      partnerLabel: _normalizePartnerEndpointLabel(_telegramPartnerLabelEnv),
      occurredAtUtc: decision.occurredAt.toUtc(),
    );
  }

  List<TelegramPartnerDispatchContext> _openPartnerDispatchContextsForScope({
    required String clientId,
    required String siteId,
  }) {
    final executedIds = store
        .allEvents()
        .whereType<ExecutionCompleted>()
        .where((event) => event.success)
        .map((event) => event.dispatchId.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    final closedIds = <String>{
      ...store
          .allEvents()
          .whereType<IncidentClosed>()
          .map((event) => event.dispatchId.trim())
          .where((value) => value.isNotEmpty),
      ...store
          .allEvents()
          .whereType<ExecutionDenied>()
          .map((event) => event.dispatchId.trim())
          .where((value) => value.isNotEmpty),
    };
    final partnerDeclaredByDispatchId = <String, PartnerDispatchStatus>{};
    for (final event
        in store.allEvents().whereType<PartnerDispatchStatusDeclared>()) {
      partnerDeclaredByDispatchId[event.dispatchId.trim()] = event.status;
    }
    final decisions =
        store
            .allEvents()
            .whereType<DecisionCreated>()
            .where(
              (event) =>
                  event.clientId == clientId.trim() &&
                  event.siteId == siteId.trim(),
            )
            .toList(growable: false)
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final contexts = <TelegramPartnerDispatchContext>[];
    for (final decision in decisions) {
      final dispatchId = decision.dispatchId.trim();
      if (dispatchId.isEmpty || closedIds.contains(dispatchId)) {
        continue;
      }
      if (!executedIds.contains(dispatchId) &&
          !partnerDeclaredByDispatchId.containsKey(dispatchId)) {
        continue;
      }
      final declaredStatus = partnerDeclaredByDispatchId[dispatchId];
      if (declaredStatus == PartnerDispatchStatus.allClear ||
          declaredStatus == PartnerDispatchStatus.cancelled) {
        continue;
      }
      final context = _partnerDispatchContextForDecision(decision);
      if (context != null) {
        contexts.add(context);
      }
    }
    return contexts;
  }

  Future<bool> _sendPartnerDispatchForDispatchId(
    String dispatchId, {
    bool forceResend = false,
  }) async {
    final decision =
        store
            .allEvents()
            .whereType<DecisionCreated>()
            .where((event) => event.dispatchId == dispatchId.trim())
            .toList(growable: false)
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    if (decision.isEmpty) {
      return false;
    }
    final context = _partnerDispatchContextForDecision(decision.first);
    if (context == null) {
      return false;
    }
    final targets = await _resolveTelegramPartnerTargets(
      clientId: context.clientId,
      siteId: context.siteId,
    );
    if (targets.isEmpty) {
      return false;
    }
    var deliveredAny = false;
    final sentAtUtc = DateTime.now().toUtc();
    for (final target in targets) {
      final message = TelegramBridgeMessage(
        messageKey:
            '${context.messageKey}:${target.chatId}:${target.threadId ?? ''}',
        chatId: target.chatId,
        messageThreadId: target.threadId,
        text: _telegramPartnerDispatchService.buildDispatchMessage(context),
        replyMarkup: _telegramPartnerDispatchService.replyKeyboardMarkup(),
      );
      final result = await _telegramBridge.sendMessages(messages: [message]);
      final delivered = result.failedCount <= 0;
      if (!delivered) {
        final reasons = result.failureReasonsByMessageKey.values
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .take(2)
            .join(' | ');
        if (mounted) {
          setState(() {
            _telegramBridgeHealthLabel = 'degraded';
            _telegramBridgeHealthDetail = reasons.isEmpty
                ? 'Partner dispatch relay delivery failed.'
                : 'Partner dispatch relay delivery failed: $reasons';
            _telegramBridgeHealthUpdatedAtUtc = DateTime.now().toUtc();
          });
        }
      } else {
        final telegramMessageId =
            result.telegramMessageIdsByMessageKey[message.messageKey];
        if (telegramMessageId != null && telegramMessageId > 0) {
          _rememberPartnerDispatchBinding(
            chatId: target.chatId,
            threadId: target.threadId,
            telegramMessageId: telegramMessageId,
            context: context,
            sentAtUtc: sentAtUtc,
          );
        }
      }
      deliveredAny = deliveredAny || delivered;
    }
    if (deliveredAny || forceResend) {
      await _appendTelegramConversationMessage(
        clientId: context.clientId,
        siteId: context.siteId,
        author: 'ONYX Control',
        body:
            'Partner dispatch relayed for ${context.dispatchId} via Telegram (${targets.length} target${targets.length == 1 ? '' : 's'}).',
        occurredAtUtc: DateTime.now().toUtc(),
        roomKey: 'Security Desk',
        viewerRole: ClientAppViewerRole.control.name,
        incidentStatusLabel: 'Partner Dispatch Sent',
        messageSource: 'telegram',
        messageProvider: 'partner_dispatch',
      );
    }
    return deliveredAny;
  }

  DecisionCreated? _decisionByDispatchId(String dispatchId) {
    final matches =
        store
            .allEvents()
            .whereType<DecisionCreated>()
            .where((event) => event.dispatchId == dispatchId.trim())
            .toList(growable: false)
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return matches.isEmpty ? null : matches.first;
  }

  Future<void> _executeDispatchAndNotifyPartner(String dispatchId) async {
    final decision = _decisionByDispatchId(dispatchId);
    if (decision == null) {
      if (!mounted) return;
      setState(() {
        _lastIntakeStatus = 'Dispatch $dispatchId not found.';
      });
      return;
    }
    await service.execute(
      clientId: decision.clientId,
      regionId: decision.regionId,
      siteId: decision.siteId,
      dispatchId: dispatchId,
    );
    final delivered = await _sendPartnerDispatchForDispatchId(dispatchId);
    if (!mounted) return;
    setState(() {
      _lastIntakeStatus = delivered
          ? 'Dispatch $dispatchId executed and partner relay sent.'
          : 'Dispatch $dispatchId executed, but no partner Telegram target was available.';
    });
  }

  Future<_TelegramInboundClientTarget?> _resolveInboundClientTarget({
    required String chatId,
    required int? messageThreadId,
  }) async {
    if (!widget.supabaseReady) {
      return null;
    }
    final normalizedChatId = chatId.trim();
    if (normalizedChatId.isEmpty) {
      return null;
    }
    try {
      final rowsRaw = await Supabase.instance.client
          .from('client_messaging_endpoints')
          .select('id, client_id, site_id, display_label, telegram_thread_id')
          .eq('provider', 'telegram')
          .eq('is_active', true)
          .eq('telegram_chat_id', normalizedChatId)
          .order('verified_at', ascending: false)
          .order('created_at', ascending: false);
      final rows = List<Map<String, dynamic>>.from(rowsRaw);
      rows.removeWhere(
        (row) =>
            _isPartnerEndpointLabel((row['display_label'] ?? '').toString()),
      );
      if (rows.isEmpty) {
        return null;
      }
      Map<String, dynamic>? pick;
      int? rowThread(Map<String, dynamic> row) {
        final raw = (row['telegram_thread_id'] ?? '').toString().trim();
        if (raw.isEmpty) return null;
        return int.tryParse(raw);
      }

      if (messageThreadId != null) {
        pick = rows.cast<Map<String, dynamic>?>().firstWhere(
          (row) => row != null && rowThread(row) == messageThreadId,
          orElse: () => null,
        );
      }
      pick ??= rows.cast<Map<String, dynamic>?>().firstWhere(
        (row) => row != null && rowThread(row) == null,
        orElse: () => null,
      );
      pick ??= rows.first;
      final endpointId = (pick['id'] ?? '').toString().trim();
      final clientId = (pick['client_id'] ?? '').toString().trim();
      if (endpointId.isEmpty || clientId.isEmpty) {
        return null;
      }
      return _TelegramInboundClientTarget(
        endpointId: endpointId,
        clientId: clientId,
        siteId: (pick['site_id'] ?? '').toString().trim().isEmpty
            ? null
            : (pick['site_id'] ?? '').toString().trim(),
        displayLabel: (pick['display_label'] ?? '').toString().trim().isEmpty
            ? 'Telegram'
            : (pick['display_label'] ?? '').toString().trim(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> _handleTelegramClientApprovalReply({
    required TelegramBridgeInboundMessage update,
    required _TelegramInboundClientTarget target,
    required String siteId,
    required String adminChatId,
    required int? adminThreadId,
  }) async {
    final decision = _telegramClientApprovalService.parseDecisionText(
      update.text,
    );
    if (decision == null) {
      return false;
    }
    final pending = await _latestPendingClientVerificationForScope(
      clientId: target.clientId,
      siteId: siteId,
    );
    if (pending == null) {
      return false;
    }
    final actorLabel = update.fromUsername?.trim().isNotEmpty == true
        ? '@${update.fromUsername!.trim()}'
        : _telegramInboundAuthor(update);
    await _recordClientAcknowledgementForScope(
      clientId: target.clientId,
      siteId: siteId,
      messageKey: pending.messageKey,
      channel: ClientAppAcknowledgementChannel.client,
      acknowledgedBy:
          '${ClientAppAcknowledgementChannel.client.defaultActor} • ${decision.label} • $actorLabel',
      acknowledgedAtUtc: update.sentAtUtc ?? DateTime.now().toUtc(),
    );
    final confirmation = _telegramClientApprovalService.clientConfirmationText(
      decision,
    );
    await _sendTelegramMessageWithChunks(
      messageKeyPrefix:
          'tg-client-verify-${decision.name}-${pending.messageKey.hashCode}',
      chatId: update.chatId,
      messageThreadId: update.messageThreadId,
      responseText: confirmation,
      failureContext: 'Client verification acknowledgement',
      replyMarkup: _telegramClientApprovalService.removeKeyboardMarkup(),
    );
    final occurredAtUtc = DateTime.now().toUtc();
    await _appendTelegramConversationMessage(
      clientId: target.clientId,
      siteId: siteId,
      author: 'ONYX Control',
      body: confirmation,
      occurredAtUtc: occurredAtUtc,
      roomKey: 'Residents',
      viewerRole: ClientAppViewerRole.client.name,
      incidentStatusLabel: switch (decision) {
        TelegramClientApprovalDecision.approve => 'Client Approved',
        TelegramClientApprovalDecision.review => 'Client Review Requested',
        TelegramClientApprovalDecision.escalate => 'Client Escalated',
      },
      messageSource: 'telegram',
      messageProvider: 'onyx_monitoring',
    );
    await _appendTelegramConversationMessage(
      clientId: target.clientId,
      siteId: siteId,
      author: 'Client',
      body: 'Telegram verification decision: ${decision.label}',
      occurredAtUtc: occurredAtUtc,
      roomKey: 'Security Desk',
      viewerRole: ClientAppViewerRole.control.name,
      incidentStatusLabel: 'Client Verification Decision',
      messageSource: 'telegram',
      messageProvider: 'telegram',
    );
    final approvedEvent = decision == TelegramClientApprovalDecision.approve
        ? _intelligenceForClientPrompt(
            clientId: target.clientId,
            siteId: siteId,
            promptOccurredAtUtc: pending.occurredAt,
          )
        : null;
    if (approvedEvent != null &&
        _canOfferPersistentAllowanceForEvent(approvedEvent)) {
      final siteProfile = _monitoringSiteProfileFor(
        clientId: approvedEvent.clientId,
        siteId: approvedEvent.siteId,
      );
      final incident = MonitoringIncidentUpdate(
        occurredAt: approvedEvent.occurredAt,
        cameraLabel: _monitoringCameraLabel(approvedEvent.cameraId),
        objectLabel: (approvedEvent.objectLabel ?? '').trim().isEmpty
            ? 'person'
            : approvedEvent.objectLabel!.trim(),
        postureLabel: 'expected visitor pending memory choice',
      );
      final identityHint = _monitoringIdentityHint(approvedEvent);
      if (identityHint != null) {
        await _enqueueMonitoringClientNotification(
          clientId: approvedEvent.clientId,
          siteId: approvedEvent.siteId,
          title: 'ONYX Allowlist Option',
          body: _monitoringShiftNotifications.formatClientAllowancePrompt(
            site: siteProfile,
            incident: incident,
            identityHint: identityHint,
          ),
          occurredAtUtc: approvedEvent.occurredAt,
          messageKeyPrefix:
              TelegramClientApprovalService.allowanceMessageKeyPrefix,
          incidentStatusLabel: 'Client Allowlist Option',
        );
      }
    }
    if (adminChatId.trim().isNotEmpty) {
      await _sendTelegramMessageWithChunks(
        messageKeyPrefix:
            'tg-admin-verify-${decision.name}-${pending.messageKey.hashCode}',
        chatId: adminChatId,
        messageThreadId: adminThreadId,
        responseText: _telegramClientApprovalService.adminDecisionSummary(
          decision: decision,
          clientId: target.clientId,
          siteId: siteId,
          messageKey: pending.messageKey,
        ),
        failureContext: 'Admin verification relay',
      );
    }
    return true;
  }

  Future<bool> _handleTelegramClientAllowanceReply({
    required TelegramBridgeInboundMessage update,
    required _TelegramInboundClientTarget target,
    required String siteId,
    required String adminChatId,
    required int? adminThreadId,
  }) async {
    final decision = _telegramClientApprovalService.parseAllowanceDecisionText(
      update.text,
    );
    if (decision == null) {
      return false;
    }
    final pending = await _latestPendingClientAllowanceForScope(
      clientId: target.clientId,
      siteId: siteId,
    );
    if (pending == null) {
      return false;
    }
    final actorLabel = update.fromUsername?.trim().isNotEmpty == true
        ? '@${update.fromUsername!.trim()}'
        : _telegramInboundAuthor(update);
    await _recordClientAcknowledgementForScope(
      clientId: target.clientId,
      siteId: siteId,
      messageKey: pending.messageKey,
      channel: ClientAppAcknowledgementChannel.client,
      acknowledgedBy:
          '${ClientAppAcknowledgementChannel.client.defaultActor} • ${decision.label} • $actorLabel',
      acknowledgedAtUtc: update.sentAtUtc ?? DateTime.now().toUtc(),
    );
    final sourceEvent = _intelligenceForClientPrompt(
      clientId: target.clientId,
      siteId: siteId,
      promptOccurredAtUtc: pending.occurredAt,
    );
    if (sourceEvent != null) {
      if (decision == TelegramClientAllowanceDecision.allowAlways) {
        await _rememberAllowedIdentityFromEvent(
          event: sourceEvent,
          approvedBy: actorLabel,
          approvedAtUtc: update.sentAtUtc ?? DateTime.now().toUtc(),
        );
      } else {
        await _rememberTemporaryAllowedIdentityFromEvent(
          event: sourceEvent,
          approvedBy: actorLabel,
          approvedAtUtc: update.sentAtUtc ?? DateTime.now().toUtc(),
        );
      }
    }
    final confirmation = _telegramClientApprovalService
        .clientAllowanceConfirmationText(decision);
    await _sendTelegramMessageWithChunks(
      messageKeyPrefix:
          'tg-client-allow-${decision.name}-${pending.messageKey.hashCode}',
      chatId: update.chatId,
      messageThreadId: update.messageThreadId,
      responseText: confirmation,
      failureContext: 'Client allowlist acknowledgement',
      replyMarkup: _telegramClientApprovalService.removeKeyboardMarkup(),
    );
    final occurredAtUtc = DateTime.now().toUtc();
    await _appendTelegramConversationMessage(
      clientId: target.clientId,
      siteId: siteId,
      author: 'ONYX Control',
      body: confirmation,
      occurredAtUtc: occurredAtUtc,
      roomKey: 'Residents',
      viewerRole: ClientAppViewerRole.client.name,
      incidentStatusLabel: switch (decision) {
        TelegramClientAllowanceDecision.allowOnce => 'Client Allow Once',
        TelegramClientAllowanceDecision.allowAlways => 'Client Allowed Always',
      },
      messageSource: 'telegram',
      messageProvider: 'onyx_monitoring',
    );
    await _appendTelegramConversationMessage(
      clientId: target.clientId,
      siteId: siteId,
      author: 'Client',
      body: 'Telegram allowance decision: ${decision.label}',
      occurredAtUtc: occurredAtUtc,
      roomKey: 'Security Desk',
      viewerRole: ClientAppViewerRole.control.name,
      incidentStatusLabel: 'Client Allowlist Decision',
      messageSource: 'telegram',
      messageProvider: 'telegram',
    );
    if (adminChatId.trim().isNotEmpty) {
      await _sendTelegramMessageWithChunks(
        messageKeyPrefix:
            'tg-admin-allow-${decision.name}-${pending.messageKey.hashCode}',
        chatId: adminChatId,
        messageThreadId: adminThreadId,
        responseText: _telegramClientApprovalService
            .adminAllowanceDecisionSummary(
              decision: decision,
              clientId: target.clientId,
              siteId: siteId,
              messageKey: pending.messageKey,
            ),
        failureContext: 'Admin allowlist relay',
      );
    }
    return true;
  }

  Future<bool> _handleTelegramIdentityIntake({
    required TelegramBridgeInboundMessage update,
    required _TelegramInboundClientTarget target,
    required String siteId,
    required String adminChatId,
    required int? adminThreadId,
  }) async {
    final occurredAtUtc = update.sentAtUtc ?? DateTime.now().toUtc();
    final parsed = _telegramIdentityIntakeService.tryParse(
      clientId: target.clientId,
      siteId: siteId,
      endpointId: target.endpointId,
      rawText: update.text,
      occurredAtUtc: occurredAtUtc,
    );
    if (parsed == null) {
      return false;
    }
    if (widget.supabaseReady) {
      try {
        final repository = SupabaseSiteIdentityRegistryRepository(
          Supabase.instance.client,
        );
        await repository.insertTelegramIntake(parsed.intake);
      } catch (_) {
        // Keep the operator/client messaging path working even if persistence
        // fails temporarily.
      }
    }
    await _sendTelegramMessageWithChunks(
      messageKeyPrefix: 'tg-client-intake-${update.updateId}',
      chatId: update.chatId,
      messageThreadId: update.messageThreadId,
      responseText: parsed.clientAcknowledgementText,
      failureContext: 'Client identity intake acknowledgement',
    );
    await _appendTelegramConversationMessage(
      clientId: target.clientId,
      siteId: siteId,
      author: 'ONYX Control',
      body: parsed.clientAcknowledgementText,
      occurredAtUtc: occurredAtUtc,
      roomKey: 'Residents',
      viewerRole: ClientAppViewerRole.client.name,
      incidentStatusLabel: parsed.summaryLabel,
      messageSource: 'telegram',
      messageProvider: 'identity_intake',
    );
    await _appendTelegramConversationMessage(
      clientId: target.clientId,
      siteId: siteId,
      author: 'ONYX Intake',
      body: 'Telegram identity intake captured: ${parsed.summaryDetail}',
      occurredAtUtc: occurredAtUtc,
      roomKey: 'Security Desk',
      viewerRole: ClientAppViewerRole.control.name,
      incidentStatusLabel: parsed.summaryLabel,
      messageSource: 'telegram',
      messageProvider: 'identity_intake',
    );
    if (adminChatId.trim().isNotEmpty) {
      await _sendTelegramMessageWithChunks(
        messageKeyPrefix: 'tg-admin-intake-${update.updateId}',
        chatId: adminChatId,
        messageThreadId: adminThreadId,
        responseText: parsed.adminSummaryText,
        failureContext: 'Admin identity intake relay',
      );
    }
    return true;
  }

  Future<ClientAppPushDeliveryItem?> _latestPendingClientVerificationForScope({
    required String clientId,
    required String siteId,
  }) async {
    final repository = await _conversationRepositoryForScope(
      clientId: clientId,
      siteId: siteId,
    );
    if (repository == null) {
      return null;
    }
    final queue = await repository.readPushQueue();
    final acknowledgements = await repository.readAcknowledgements();
    final pending = queue
        .where((item) {
          if (!_telegramClientApprovalService.isVerificationMessageKey(
            item.messageKey,
          )) {
            return false;
          }
          if (item.targetChannel != ClientAppAcknowledgementChannel.client) {
            return false;
          }
          return !acknowledgements.any(
            (ack) =>
                ack.messageKey == item.messageKey &&
                ack.channel == ClientAppAcknowledgementChannel.client,
          );
        })
        .toList(growable: false);
    if (pending.isEmpty) {
      return null;
    }
    pending.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return pending.first;
  }

  Future<ClientAppPushDeliveryItem?> _latestPendingClientAllowanceForScope({
    required String clientId,
    required String siteId,
  }) async {
    final repository = await _conversationRepositoryForScope(
      clientId: clientId,
      siteId: siteId,
    );
    if (repository == null) {
      return null;
    }
    final queue = await repository.readPushQueue();
    final acknowledgements = await repository.readAcknowledgements();
    final pending = queue
        .where((item) {
          if (!_telegramClientApprovalService.isAllowanceMessageKey(
            item.messageKey,
          )) {
            return false;
          }
          if (item.targetChannel != ClientAppAcknowledgementChannel.client) {
            return false;
          }
          return !acknowledgements.any(
            (ack) =>
                ack.messageKey == item.messageKey &&
                ack.channel == ClientAppAcknowledgementChannel.client,
          );
        })
        .toList(growable: false);
    if (pending.isEmpty) {
      return null;
    }
    pending.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return pending.first;
  }

  IntelligenceReceived? _intelligenceForClientPrompt({
    required String clientId,
    required String siteId,
    required DateTime promptOccurredAtUtc,
  }) {
    final promptAtUtc = promptOccurredAtUtc.toUtc();
    final scopedEvents =
        store
            .allEvents()
            .whereType<IntelligenceReceived>()
            .where(
              (event) =>
                  event.clientId == clientId.trim() &&
                  event.siteId == siteId.trim(),
            )
            .toList(growable: false)
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    for (final event in scopedEvents) {
      if (event.occurredAt.toUtc() == promptAtUtc) {
        return event;
      }
    }
    for (final event in scopedEvents) {
      if (!event.occurredAt.toUtc().isAfter(promptAtUtc)) {
        return event;
      }
    }
    return scopedEvents.isEmpty ? null : scopedEvents.first;
  }

  bool _canOfferPersistentAllowanceForEvent(IntelligenceReceived event) {
    final objectLabel = (event.objectLabel ?? '').trim().toLowerCase();
    final isHumanLike =
        objectLabel == 'person' ||
        objectLabel == 'human' ||
        objectLabel == 'intruder' ||
        objectLabel.isEmpty;
    if (!isHumanLike) {
      return false;
    }
    final faceMatchId = (event.faceMatchId ?? '').trim();
    final plateNumber = (event.plateNumber ?? '').trim();
    if (faceMatchId.isEmpty && plateNumber.isEmpty) {
      return false;
    }
    final policy = _watchIdentityPolicyService.policyFor(
      clientId: event.clientId,
      siteId: event.siteId,
    );
    return !policy.matchesAllowedFace(faceMatchId) &&
        !policy.matchesFlaggedFace(faceMatchId) &&
        !policy.matchesAllowedPlate(plateNumber) &&
        !policy.matchesFlaggedPlate(plateNumber);
  }

  Future<void> _rememberTemporaryAllowedIdentityProfile(
    SiteIdentityProfile profile,
  ) async {
    _watchTemporaryIdentityApprovalService =
        _watchTemporaryIdentityApprovalService.upsertProfile(profile);
    _rebuildWatchSceneAssessmentService();
  }

  List<SiteIdentityProfile> _matchingTemporaryIdentityProfilesForScope(
    VideoFleetScopeHealthView scope, {
    DateTime? nowUtc,
  }) {
    final when = (nowUtc ?? DateTime.now()).toUtc();
    final normalizedFace = (scope.latestFaceMatchId ?? '').trim().toUpperCase();
    final normalizedPlate = (scope.latestPlateNumber ?? '')
        .trim()
        .toUpperCase();
    return _watchTemporaryIdentityApprovalService.profiles
        .where((profile) {
          if (profile.clientId != scope.clientId ||
              profile.siteId != scope.siteId) {
            return false;
          }
          final validUntilUtc = profile.validUntilUtc?.toUtc();
          if (validUntilUtc == null || !validUntilUtc.isAfter(when)) {
            return false;
          }
          final faceMatches =
              normalizedFace.isNotEmpty &&
              profile.faceMatchId.trim().toUpperCase() == normalizedFace;
          final plateMatches =
              normalizedPlate.isNotEmpty &&
              profile.plateNumber.trim().toUpperCase() == normalizedPlate;
          return faceMatches || plateMatches;
        })
        .toList(growable: false);
  }

  Future<void> _updateTemporaryApprovalRuntimeForScope({
    required VideoFleetScopeHealthView scope,
    required String decisionSummary,
    required String clientDecisionLabel,
    required String clientDecisionSummary,
    String? sceneReviewLabel,
  }) async {
    final scopeKey = _monitoringScopeKey(scope.clientId, scope.siteId);
    final runtime = _monitoringWatchByScope[scopeKey];
    if (runtime == null) {
      return;
    }
    _monitoringWatchByScope[scopeKey] = runtime.copyWith(
      latestSceneReviewPostureLabel:
          sceneReviewLabel ?? runtime.latestSceneReviewPostureLabel,
      latestSceneDecisionSummary: decisionSummary,
      latestClientDecisionLabel: clientDecisionLabel,
      latestClientDecisionSummary: clientDecisionSummary,
      latestClientDecisionAtUtc: DateTime.now().toUtc(),
    );
    await _persistMonitoringWatchRuntimeState();
    if (mounted) {
      setState(() {});
    }
  }

  Future<String> _extendTemporaryIdentityApprovalForScope(
    VideoFleetScopeHealthView scope,
  ) async {
    final nowUtc = DateTime.now().toUtc();
    final matches = _matchingTemporaryIdentityProfilesForScope(
      scope,
      nowUtc: nowUtc,
    );
    if (matches.isEmpty) {
      return 'No active temporary approval found for ${scope.siteName}.';
    }
    final updatedProfiles = matches
        .map((profile) {
          final baseUntil = profile.validUntilUtc?.toUtc();
          final nextUntil =
              (baseUntil != null && baseUntil.isAfter(nowUtc)
                      ? baseUntil
                      : nowUtc)
                  .add(const Duration(hours: 2));
          return profile.copyWith(
            validUntilUtc: nextUntil,
            updatedAtUtc: nowUtc,
            notes: 'Temporary approval extended by ONYX operator.',
            metadata: <String, Object?>{
              ...profile.metadata,
              'last_operator_action': 'extend_temporary_approval',
            },
          );
        })
        .toList(growable: false);

    for (final profile in updatedProfiles) {
      await _rememberTemporaryAllowedIdentityProfile(profile);
    }
    if (widget.supabaseReady) {
      try {
        final repository = SupabaseSiteIdentityRegistryRepository(
          Supabase.instance.client,
        );
        for (final profile in updatedProfiles) {
          await repository.upsertProfile(profile);
          await repository.insertApprovalDecision(
            SiteIdentityApprovalDecisionRecord(
              clientId: profile.clientId,
              siteId: profile.siteId,
              profileId: profile.profileId,
              decision: SiteIdentityDecision.approveOnce,
              source: SiteIdentityDecisionSource.admin,
              decidedBy: 'ONYX Live Ops',
              decisionSummary:
                  'Extended temporary approval for ${scope.siteName} until ${profile.validUntilUtc!.toIso8601String()}.',
              decidedAtUtc: nowUtc,
              metadata: <String, Object?>{
                'operator_action': 'extend_temporary_approval',
                'site_name': scope.siteName,
              },
            ),
          );
        }
      } catch (_) {
        // Keep the live runtime path available even if Supabase persistence fails.
      }
    }
    final nextUntil = updatedProfiles
        .map((profile) => profile.validUntilUtc!.toUtc())
        .reduce((left, right) => left.isBefore(right) ? left : right);
    final untilLabel =
        '${nextUntil.year.toString().padLeft(4, '0')}-${nextUntil.month.toString().padLeft(2, '0')}-${nextUntil.day.toString().padLeft(2, '0')} ${nextUntil.hour.toString().padLeft(2, '0')}:${nextUntil.minute.toString().padLeft(2, '0')} UTC';
    await _updateTemporaryApprovalRuntimeForScope(
      scope: scope,
      decisionSummary:
          'Suppressed because the matched identity has a one-time approval until $untilLabel and the activity remained below the client notification threshold. Operator extended the temporary pass.',
      clientDecisionLabel: 'Temporary Pass Extended',
      clientDecisionSummary:
          'ONYX live operations extended the temporary approval until $untilLabel.',
    );
    return 'Temporary approval extended until $untilLabel.';
  }

  Future<String> _expireTemporaryIdentityApprovalForScope(
    VideoFleetScopeHealthView scope,
  ) async {
    final nowUtc = DateTime.now().toUtc();
    final matches = _matchingTemporaryIdentityProfilesForScope(
      scope,
      nowUtc: nowUtc,
    );
    if (matches.isEmpty) {
      return 'No active temporary approval found for ${scope.siteName}.';
    }
    final expiredProfiles = matches
        .map(
          (profile) => profile.copyWith(
            status: SiteIdentityStatus.expired,
            validUntilUtc: nowUtc,
            updatedAtUtc: nowUtc,
            notes: 'Temporary approval expired by ONYX operator.',
            metadata: <String, Object?>{
              ...profile.metadata,
              'last_operator_action': 'expire_temporary_approval',
            },
          ),
        )
        .toList(growable: false);

    _watchTemporaryIdentityApprovalService =
        _watchTemporaryIdentityApprovalService.pruneExpired(nowUtc: nowUtc);
    _rebuildWatchSceneAssessmentService();
    if (widget.supabaseReady) {
      try {
        final repository = SupabaseSiteIdentityRegistryRepository(
          Supabase.instance.client,
        );
        for (final profile in expiredProfiles) {
          await repository.upsertProfile(profile);
          await repository.insertApprovalDecision(
            SiteIdentityApprovalDecisionRecord(
              clientId: profile.clientId,
              siteId: profile.siteId,
              profileId: profile.profileId,
              decision: SiteIdentityDecision.revoke,
              source: SiteIdentityDecisionSource.admin,
              decidedBy: 'ONYX Live Ops',
              decisionSummary:
                  'Expired temporary approval for ${scope.siteName} at ${nowUtc.toIso8601String()}.',
              decidedAtUtc: nowUtc,
              metadata: <String, Object?>{
                'operator_action': 'expire_temporary_approval',
                'site_name': scope.siteName,
              },
            ),
          );
        }
      } catch (_) {
        // Keep the live runtime path available even if Supabase persistence fails.
      }
    }
    final expiredLabel =
        '${nowUtc.year.toString().padLeft(4, '0')}-${nowUtc.month.toString().padLeft(2, '0')}-${nowUtc.day.toString().padLeft(2, '0')} ${nowUtc.hour.toString().padLeft(2, '0')}:${nowUtc.minute.toString().padLeft(2, '0')} UTC';
    await _updateTemporaryApprovalRuntimeForScope(
      scope: scope,
      sceneReviewLabel: 'review required',
      decisionSummary:
          'Temporary approval expired at $expiredLabel and future detections will require review.',
      clientDecisionLabel: 'Temporary Pass Expired',
      clientDecisionSummary:
          'ONYX live operations expired the temporary approval at $expiredLabel.',
    );
    return 'Temporary approval expired at $expiredLabel.';
  }

  Future<void> _rememberTemporaryAllowedIdentityFromEvent({
    required IntelligenceReceived event,
    required String approvedBy,
    required DateTime approvedAtUtc,
  }) async {
    final nowUtc = approvedAtUtc.toUtc();
    final validUntilUtc = nowUtc.add(const Duration(hours: 12));
    final normalizedFace = (event.faceMatchId ?? '').trim().toUpperCase();
    final normalizedPlate = (event.plateNumber ?? '').trim().toUpperCase();
    final profile = SiteIdentityProfile(
      clientId: event.clientId,
      siteId: event.siteId,
      identityType: normalizedPlate.isNotEmpty && normalizedFace.isEmpty
          ? SiteIdentityType.vehicle
          : SiteIdentityType.person,
      category: SiteIdentityCategory.visitor,
      status: SiteIdentityStatus.allowed,
      displayName:
          _monitoringIdentityHint(event) ?? 'Temporary approved visitor',
      faceMatchId: normalizedFace,
      plateNumber: normalizedPlate,
      externalReference:
          'tg-allow-once-${event.intelligenceId}-${nowUtc.microsecondsSinceEpoch}',
      notes: 'Approved once via Telegram by $approvedBy.',
      validFromUtc: nowUtc,
      validUntilUtc: validUntilUtc,
      createdAtUtc: nowUtc,
      updatedAtUtc: nowUtc,
      metadata: <String, Object?>{
        'source': 'telegram_allow_once',
        'approved_by': approvedBy,
        'intelligence_id': event.intelligenceId,
      },
    );
    await _rememberTemporaryAllowedIdentityProfile(profile);
    if (!widget.supabaseReady) {
      return;
    }
    try {
      final repository = SupabaseSiteIdentityRegistryRepository(
        Supabase.instance.client,
      );
      await repository.upsertProfile(profile);
      await repository.insertApprovalDecision(
        SiteIdentityApprovalDecisionRecord(
          clientId: event.clientId,
          siteId: event.siteId,
          decision: SiteIdentityDecision.approveOnce,
          source: SiteIdentityDecisionSource.telegram,
          decidedBy: approvedBy,
          decisionSummary:
              'Telegram allow-once approved ${_monitoringIdentityHint(event) ?? 'temporary visitor'} until ${validUntilUtc.toIso8601String()}.',
          decidedAtUtc: nowUtc,
          metadata: <String, Object?>{
            'intelligence_id': event.intelligenceId,
            'valid_until': validUntilUtc.toIso8601String(),
          },
        ),
      );
    } catch (_) {
      // Runtime temporary approval already applied; keep the live path moving.
    }
  }

  Future<void> _rememberAllowedIdentityFromEvent({
    required IntelligenceReceived event,
    required String approvedBy,
    required DateTime approvedAtUtc,
  }) async {
    final currentPolicy = _watchIdentityPolicyService.policyFor(
      clientId: event.clientId,
      siteId: event.siteId,
    );
    final nextPolicy = currentPolicy.copyWith(
      allowedFaceMatchIds: {
        ...currentPolicy.allowedFaceMatchIds,
        if ((event.faceMatchId ?? '').trim().isNotEmpty)
          event.faceMatchId!.trim().toUpperCase(),
      },
      allowedPlateNumbers: {
        ...currentPolicy.allowedPlateNumbers,
        if ((event.plateNumber ?? '').trim().isNotEmpty)
          event.plateNumber!.trim().toUpperCase(),
      },
    );
    final nextService = _watchIdentityPolicyService.updateScopePolicy(
      clientId: event.clientId,
      siteId: event.siteId,
      policy: nextPolicy,
    );
    await _saveMonitoringIdentityRulesConfig(nextService);
    final auditRecord = MonitoringIdentityPolicyAuditRecord(
      recordedAtUtc: approvedAtUtc.toUtc(),
      source: MonitoringIdentityPolicyAuditSource.manualEdit,
      message:
          'Telegram allow-always added ${_monitoringIdentityHint(event) ?? 'approved identity'} for ${event.siteId} by $approvedBy.',
    );
    final nextAuditHistory = <MonitoringIdentityPolicyAuditRecord>[
      auditRecord,
      ..._monitoringIdentityRuleAuditHistory,
    ].take(12).toList(growable: false);
    if (mounted) {
      setState(() {
        _monitoringIdentityRuleAuditHistory = nextAuditHistory;
      });
    } else {
      _monitoringIdentityRuleAuditHistory = nextAuditHistory;
    }
    await _persistMonitoringIdentityRuleAuditHistory();
    await _persistAllowedIdentityToSupabase(
      event: event,
      approvedBy: approvedBy,
      approvedAtUtc: approvedAtUtc,
    );
  }

  Future<void> _persistAllowedIdentityToSupabase({
    required IntelligenceReceived event,
    required String approvedBy,
    required DateTime approvedAtUtc,
  }) async {
    if (!widget.supabaseReady) {
      return;
    }
    final repository = SupabaseSiteIdentityRegistryRepository(
      Supabase.instance.client,
    );
    final jobs = <Future<void>>[];
    final faceMatchId = (event.faceMatchId ?? '').trim();
    final plateNumber = (event.plateNumber ?? '').trim();
    if (faceMatchId.isNotEmpty) {
      jobs.add(
        repository.upsertProfile(
          SiteIdentityProfile(
            clientId: event.clientId,
            siteId: event.siteId,
            identityType: SiteIdentityType.person,
            category: SiteIdentityCategory.visitor,
            status: SiteIdentityStatus.allowed,
            displayName: 'Visitor $faceMatchId',
            faceMatchId: faceMatchId,
            externalReference: event.intelligenceId,
            notes: 'Approved through Telegram allow-always flow.',
            createdAtUtc: approvedAtUtc.toUtc(),
            updatedAtUtc: approvedAtUtc.toUtc(),
            metadata: <String, Object?>{
              'source': 'telegram_allow_always',
              'intelligence_id': event.intelligenceId,
            },
          ),
        ),
      );
    }
    if (plateNumber.isNotEmpty) {
      jobs.add(
        repository.upsertProfile(
          SiteIdentityProfile(
            clientId: event.clientId,
            siteId: event.siteId,
            identityType: SiteIdentityType.vehicle,
            category: SiteIdentityCategory.visitor,
            status: SiteIdentityStatus.allowed,
            displayName: 'Visitor vehicle $plateNumber',
            plateNumber: plateNumber,
            externalReference: event.intelligenceId,
            notes: 'Approved through Telegram allow-always flow.',
            createdAtUtc: approvedAtUtc.toUtc(),
            updatedAtUtc: approvedAtUtc.toUtc(),
            metadata: <String, Object?>{
              'source': 'telegram_allow_always',
              'intelligence_id': event.intelligenceId,
            },
          ),
        ),
      );
    }
    jobs.add(
      repository.insertApprovalDecision(
        SiteIdentityApprovalDecisionRecord(
          clientId: event.clientId,
          siteId: event.siteId,
          intelligenceId: event.intelligenceId,
          decision: SiteIdentityDecision.approveAlways,
          source: SiteIdentityDecisionSource.telegram,
          decidedBy: approvedBy,
          decisionSummary:
              'Client chose ALWAYS ALLOW from the Telegram verification follow-up.',
          decidedAtUtc: approvedAtUtc.toUtc(),
          metadata: <String, Object?>{
            if (faceMatchId.isNotEmpty) 'face_match_id': faceMatchId,
            if (plateNumber.isNotEmpty) 'plate_number': plateNumber,
          },
        ),
      ),
    );
    try {
      await Future.wait(jobs);
    } catch (_) {
      // Local runtime policy remains authoritative even if Supabase persistence
      // is unavailable.
    }
  }

  Future<void> _recordClientAcknowledgementForScope({
    required String clientId,
    required String siteId,
    required String messageKey,
    required ClientAppAcknowledgementChannel channel,
    required String acknowledgedBy,
    required DateTime acknowledgedAtUtc,
  }) async {
    final repository = await _conversationRepositoryForScope(
      clientId: clientId,
      siteId: siteId,
    );
    if (repository == null) {
      return;
    }
    final nextAck = ClientAppAcknowledgement(
      messageKey: messageKey,
      channel: channel,
      acknowledgedBy: acknowledgedBy.trim(),
      acknowledgedAt: acknowledgedAtUtc.toUtc(),
    );
    final acknowledgements = await repository.readAcknowledgements();
    final nextAcknowledgements = <ClientAppAcknowledgement>[
      nextAck,
      ...acknowledgements.where(
        (ack) => !(ack.messageKey == messageKey && ack.channel == channel),
      ),
    ]..sort((a, b) => b.acknowledgedAt.compareTo(a.acknowledgedAt));
    final queue = await repository.readPushQueue();
    final nextQueue = queue
        .map(
          (item) => item.messageKey == messageKey
              ? ClientAppPushDeliveryItem(
                  messageKey: item.messageKey,
                  title: item.title,
                  body: item.body,
                  occurredAt: item.occurredAt,
                  clientId: item.clientId,
                  siteId: item.siteId,
                  targetChannel: item.targetChannel,
                  deliveryProvider: item.deliveryProvider,
                  priority: item.priority,
                  status: ClientPushDeliveryStatus.acknowledged,
                )
              : item,
        )
        .toList(growable: false);
    await repository.saveAcknowledgements(nextAcknowledgements);
    await repository.savePushQueue(nextQueue);
    if (clientId.trim() == _selectedClient.trim() &&
        siteId.trim() == _selectedSite.trim()) {
      _clientAppAcknowledgements = List<ClientAppAcknowledgement>.from(
        nextAcknowledgements,
      );
      _clientAppPushQueue = List<ClientAppPushDeliveryItem>.from(nextQueue);
    }
    final scopeKey = _monitoringScopeKey(clientId, siteId);
    final runtime = _monitoringWatchByScope[scopeKey];
    if (runtime != null) {
      _monitoringWatchByScope[scopeKey] = _watchRuntimeStore
          .applyClientDecision(
            runtime: runtime,
            decisionLabel: _clientDecisionRuntimeLabel(acknowledgedBy),
            decisionSummary: _clientDecisionRuntimeSummary(acknowledgedBy),
            decidedAtUtc: acknowledgedAtUtc,
          );
      await _persistMonitoringWatchRuntimeState();
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<ClientConversationRepository?> _conversationRepositoryForScope({
    required String clientId,
    required String siteId,
  }) async {
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId.trim();
    if (normalizedClientId.isEmpty || normalizedSiteId.isEmpty) {
      return null;
    }
    if (normalizedClientId == _selectedClient.trim() &&
        normalizedSiteId == _selectedSite.trim()) {
      return _clientConversationRepositoryFuture;
    }
    if (!widget.supabaseReady) {
      return null;
    }
    return SupabaseClientConversationRepository(
      client: Supabase.instance.client,
      clientId: normalizedClientId,
      siteId: normalizedSiteId,
    );
  }

  String _clientDecisionRuntimeLabel(String acknowledgedBy) {
    final normalized = acknowledgedBy.trim().toLowerCase();
    if (normalized.contains('always allow')) {
      return 'Client Allowed Always';
    }
    if (normalized.contains('allow once')) {
      return 'Client Allow Once';
    }
    if (normalized.contains('approve')) {
      return 'Client Approved';
    }
    if (normalized.contains('review')) {
      return 'Client Review Requested';
    }
    if (normalized.contains('escalate')) {
      return 'Client Escalated';
    }
    return 'Client Decision Received';
  }

  String _clientDecisionRuntimeSummary(String acknowledgedBy) {
    final normalized = acknowledgedBy.trim().toLowerCase();
    if (normalized.contains('always allow')) {
      return 'Client asked ONYX to remember this visitor for future matches.';
    }
    if (normalized.contains('allow once')) {
      return 'Client approved this visitor once and wants ONYX to ask again next time.';
    }
    if (normalized.contains('approve')) {
      return 'Client confirmed the unidentified person was expected.';
    }
    if (normalized.contains('review')) {
      return 'Client asked ONYX control to keep the event open for manual review.';
    }
    if (normalized.contains('escalate')) {
      return 'Client requested urgent control review for the unidentified person.';
    }
    return 'Client responded to the ONYX verification prompt.';
  }

  bool _isHighRiskTelegramMessage(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    const highRiskKeywords = <String>[
      'panic',
      'duress',
      'armed',
      'gun',
      'weapon',
      'intruder',
      'break in',
      'breach',
      'fire',
      'medical',
      'ambulance',
      'police',
      'hostage',
      'bomb',
    ];
    return highRiskKeywords.any(normalized.contains);
  }

  String _singleLine(String text, {int maxLength = 220}) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxLength) {
      return normalized;
    }
    return '${normalized.substring(0, maxLength - 3)}...';
  }

  String _telegramHtmlEscape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  String _telegramUtcStamp([DateTime? instant]) {
    final utc = (instant ?? DateTime.now()).toUtc();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-${two(utc.day)}T${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}Z';
  }

  bool _telegramAdminUseRichTextForCommand(
    String command, {
    String arguments = '',
  }) {
    return true;
  }

  bool _telegramLooksLikeSectionTitle(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.length > 32) {
      return false;
    }
    if (trimmed.contains(':') || trimmed.startsWith('/')) {
      return false;
    }
    return RegExp(r'^[A-Z][A-Z0-9 _/&-]+$').hasMatch(trimmed);
  }

  String _telegramRenderCardLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    if (trimmed == '---') {
      return '---';
    }
    if (trimmed.toUpperCase().startsWith('UTC:')) {
      final raw = trimmed.substring(4).trim();
      final parsed = DateTime.tryParse(raw);
      return 'UTC: ${_telegramUtcStamp(parsed ?? DateTime.now().toUtc())}';
    }
    if (_telegramLooksLikeSectionTitle(trimmed)) {
      return '<b>${_telegramHtmlEscape(trimmed)}</b>';
    }
    if (trimmed.startsWith('- ')) {
      return '• ${_telegramHtmlEscape(trimmed.substring(2).trim())}';
    }
    if (trimmed.startsWith('• ')) {
      return '• ${_telegramHtmlEscape(trimmed.substring(2).trim())}';
    }
    final colonIndex = trimmed.indexOf(':');
    if (colonIndex > 0 && colonIndex < 40) {
      final key = trimmed.substring(0, colonIndex).trim();
      final value = trimmed.substring(colonIndex + 1).trim();
      if (key.isNotEmpty && value.isNotEmpty) {
        return '• <b>${_telegramHtmlEscape(key)}:</b> ${_telegramHtmlEscape(value)}';
      }
    }
    return '• ${_telegramHtmlEscape(trimmed)}';
  }

  String _telegramNormalizeUtcLines(String text) {
    final isoRegex = RegExp(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z');

    String normalizeIsoFragments(String line) {
      return line.replaceAllMapped(isoRegex, (match) {
        final raw = match.group(0) ?? '';
        final parsed = DateTime.tryParse(raw);
        if (parsed == null) {
          return raw;
        }
        return _telegramUtcStamp(parsed);
      });
    }

    final lines = text.split('\n');
    final normalized = lines.map((line) {
      final leftPadding = line.length - line.trimLeft().length;
      final trimmed = line.trimLeft();
      if (!trimmed.toUpperCase().startsWith('UTC:')) {
        return normalizeIsoFragments(line);
      }
      final raw = trimmed.substring(4).trim();
      final parsed = DateTime.tryParse(raw);
      final utcLine =
          '${' ' * leftPadding}UTC: ${_telegramUtcStamp(parsed ?? DateTime.now().toUtc())}';
      return normalizeIsoFragments(utcLine);
    });
    return normalized.join('\n');
  }

  String _telegramAdminRenderCommandCard(String command, String responseText) {
    final raw = responseText.trim();
    if (raw.isEmpty) {
      return raw;
    }
    if (raw.contains('<b>') || raw.contains('</b>')) {
      return _telegramNormalizeUtcLines(raw);
    }
    final lines = raw
        .split('\n')
        .map((entry) => entry.trimRight())
        .where((entry) => entry.trim().isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) {
      return raw;
    }
    var title = lines.first.trim();
    var bodyLines = lines.skip(1).toList(growable: false);
    if (bodyLines.isEmpty && title.contains('•')) {
      final parts = title.split('•').map((entry) => entry.trim()).toList();
      if (parts.isNotEmpty) {
        title = parts.first;
        bodyLines = parts.skip(1).where((entry) => entry.isNotEmpty).toList();
      }
    }
    final renderedBody = bodyLines
        .map(_telegramRenderCardLine)
        .where((entry) => entry.trim().isNotEmpty)
        .join('\n');
    final normalizedTitle = title.isEmpty
        ? 'ONYX ${command.toUpperCase()}'
        : title;
    if (renderedBody.isEmpty) {
      return _telegramNormalizeUtcLines(
        '<b>${_telegramHtmlEscape(normalizedTitle)}</b>',
      );
    }
    return _telegramNormalizeUtcLines(
      '<b>${_telegramHtmlEscape(normalizedTitle)}</b>\n\n$renderedBody',
    );
  }

  String _telegramInboundAuthor(TelegramBridgeInboundMessage update) {
    final username = update.fromUsername?.trim() ?? '';
    if (username.isNotEmpty) {
      return '@$username';
    }
    final userId = update.fromUserId;
    if (userId != null) {
      return 'Telegram User $userId';
    }
    return 'Telegram Client';
  }

  Future<void> _appendTelegramConversationMessage({
    required String clientId,
    required String siteId,
    required String author,
    required String body,
    required DateTime occurredAtUtc,
    required String roomKey,
    required String viewerRole,
    required String incidentStatusLabel,
    String messageSource = 'in_app',
    String messageProvider = 'in_app',
  }) async {
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId.trim();
    final normalizedBody = body.trim();
    if (normalizedClientId.isEmpty ||
        normalizedSiteId.isEmpty ||
        normalizedBody.isEmpty) {
      return;
    }
    final message = ClientAppMessage(
      author: author.trim().isEmpty ? 'ONYX' : author.trim(),
      body: normalizedBody,
      occurredAt: occurredAtUtc.toUtc(),
      roomKey: roomKey.trim().isEmpty ? 'Residents' : roomKey.trim(),
      viewerRole: viewerRole.trim().isEmpty ? 'client' : viewerRole.trim(),
      incidentStatusLabel: incidentStatusLabel.trim().isEmpty
          ? 'Update'
          : incidentStatusLabel.trim(),
      messageSource: messageSource.trim().isEmpty
          ? 'in_app'
          : messageSource.trim(),
      messageProvider: messageProvider.trim().isEmpty
          ? 'in_app'
          : messageProvider.trim(),
    );
    final activeScope =
        normalizedClientId == _selectedClient &&
        normalizedSiteId == _selectedSite;
    if (activeScope) {
      final nextMessages = <ClientAppMessage>[message, ..._clientAppMessages]
        ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      _clientAppMessages = nextMessages;
      if (mounted) {
        setState(() {});
      }
      try {
        final conversation = await _clientConversationRepositoryFuture;
        await conversation.saveMessages(nextMessages);
      } catch (_) {
        // Best-effort only; routing must continue even if sync fails.
      }
      return;
    }
    if (!widget.supabaseReady) {
      return;
    }
    try {
      await Supabase.instance.client
          .from('client_conversation_messages')
          .insert({
            'client_id': normalizedClientId,
            'site_id': normalizedSiteId,
            'author': message.author,
            'body': message.body,
            'room_key': message.roomKey,
            'viewer_role': message.viewerRole,
            'incident_status_label': message.incidentStatusLabel,
            'message_source': message.messageSource,
            'message_provider': message.messageProvider,
            'occurred_at': message.occurredAt.toIso8601String(),
          });
    } catch (_) {
      try {
        await Supabase.instance.client
            .from('client_conversation_messages')
            .insert({
              'client_id': normalizedClientId,
              'site_id': normalizedSiteId,
              'author': message.author,
              'body': message.body,
              'room_key': message.roomKey,
              'viewer_role': message.viewerRole,
              'incident_status_label': message.incidentStatusLabel,
              'occurred_at': message.occurredAt.toIso8601String(),
            });
      } catch (_) {
        // Best-effort only; routing must continue even if sync fails.
      }
    }
  }

  String _monitoringScopeKey(String clientId, String siteId) {
    return '${clientId.trim()}|${siteId.trim()}';
  }

  String _humanizeScopeLabel(String raw) {
    final cleaned = raw
        .trim()
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .replaceAll(RegExp(r'[^A-Za-z0-9 ]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) {
      return 'Unnamed Scope';
    }
    final stopWords = <String>{'and', 'of', 'the'};
    return cleaned
        .split(' ')
        .asMap()
        .entries
        .map((entry) {
          final token = entry.value.toLowerCase();
          if (token.isEmpty) {
            return '';
          }
          if (entry.key > 0 && stopWords.contains(token)) {
            return token;
          }
          return '${token[0].toUpperCase()}${token.substring(1)}';
        })
        .join(' ');
  }

  MonitoringSiteProfile _monitoringSiteProfileFor({
    required String clientId,
    required String siteId,
  }) {
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId.trim();
    if (normalizedClientId == 'CLIENT-MS-VALLEE' &&
        normalizedSiteId == 'SITE-MS-VALLEE-RESIDENCE') {
      return const MonitoringSiteProfile(
        siteName: 'MS Vallee Residence',
        clientName: 'Muhammed Vallee',
      );
    }
    return MonitoringSiteProfile(
      siteName: _humanizeScopeLabel(normalizedSiteId),
      clientName: '',
    );
  }

  ({String label, String summary})? _siteActivityTrendSnapshotFor(
    SiteActivityIntelligenceSnapshot currentActivity,
  ) {
    final currentReport = _morningSovereignReport;
    final baselineReports =
        _morningSovereignReportHistory
            .where(
              (item) =>
                  currentReport == null ||
                  !_sameMorningSovereignReport(item, currentReport),
            )
            .toList(growable: false)
          ..sort(
            (left, right) =>
                right.generatedAtUtc.compareTo(left.generatedAtUtc),
          );
    if (baselineReports.isEmpty) {
      return null;
    }
    final baseline = baselineReports
        .take(3)
        .map((item) => item.siteActivity)
        .toList(growable: false);
    if (baseline.isEmpty) {
      return null;
    }
    final currentPressure =
        (currentActivity.flaggedIdentitySignals * 2.0) +
        (currentActivity.unknownPersonSignals +
            currentActivity.unknownVehicleSignals) +
        currentActivity.longPresenceSignals +
        (currentActivity.guardInteractionSignals * 0.5);
    final baselinePressure =
        baseline
            .map(
              (item) =>
                  (item.flaggedIdentitySignals * 2.0) +
                  item.unknownSignals +
                  item.longPresenceSignals +
                  (item.guardInteractionSignals * 0.5),
            )
            .reduce((left, right) => left + right) /
        baseline.length;
    final delta = currentPressure - baselinePressure;
    String label;
    String summary;
    if (delta >= 1.0) {
      label = 'ACTIVITY RISING';
      summary =
          'Unknown or flagged site activity increased against recent shifts.';
    } else if (delta <= -1.0) {
      label = 'ACTIVITY EASING';
      summary = 'Unknown or flagged site activity eased against recent shifts.';
    } else {
      label = 'STABLE';
      summary = 'Site activity held close to the recent shift baseline.';
    }
    return (label: label, summary: summary);
  }

  bool _sameMorningSovereignReport(
    SovereignReport left,
    SovereignReport right,
  ) {
    return left.generatedAtUtc == right.generatedAtUtc &&
        left.shiftWindowEndUtc == right.shiftWindowEndUtc &&
        left.date == right.date;
  }

  String _siteActivityTelegramSummaryForScope({
    required String clientId,
    required String siteId,
    bool includeEvidenceHandoff = false,
    bool includeReviewCommandHint = false,
    bool includeCaseFileHint = false,
  }) {
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId.trim();
    final snapshot = _siteActivityIntelligenceService.buildSnapshot(
      events: store.allEvents(),
      clientId: normalizedClientId,
      siteId: normalizedSiteId,
    );
    final siteProfile = _monitoringSiteProfileFor(
      clientId: normalizedClientId,
      siteId: normalizedSiteId,
    );
    final trend = _siteActivityTrendSnapshotFor(snapshot);
    final historyReviewHints = includeReviewCommandHint
        ? _siteActivityHistoricalReviewHintsForScope(
            clientId: normalizedClientId,
            siteId: normalizedSiteId,
          )
        : const <String>[];
    return _siteActivityTelegramFormatter.formatSummary(
      snapshot: snapshot,
      siteLabel: siteProfile.siteName,
      reportDate: _morningSovereignReport?.date,
      trendLabel: trend?.label,
      trendSummary: trend?.summary,
      includeEvidenceHandoff: includeEvidenceHandoff,
      reviewCommandHint: includeReviewCommandHint
          ? '/activityreview $normalizedClientId $normalizedSiteId'
          : null,
      historyReviewHints: historyReviewHints,
      caseFileHint: includeCaseFileHint
          ? '/activitycase $normalizedClientId $normalizedSiteId'
          : null,
    );
  }

  List<String> _siteActivityHistoricalReviewHintsForScope({
    required String clientId,
    required String siteId,
  }) {
    final history = _siteActivityHistoryPointsForScope(
      clientId: clientId,
      siteId: siteId,
    );
    if (history.isEmpty) {
      return const <String>[];
    }
    final hints = <String>[
      'Current shift: /activityreview $clientId $siteId ${history.first.reportDate}',
    ];
    if (history.length > 1) {
      hints.add(
        'Previous shift: /activityreview $clientId $siteId ${history[1].reportDate}',
      );
    }
    return hints;
  }

  bool _looksLikeSiteActivityReportDate(String value) {
    final trimmed = value.trim();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) {
      return false;
    }
    return DateTime.tryParse(trimmed) != null;
  }

  String _siteActivityReportDate(DateTime dateTime) {
    final utc = dateTime.toUtc();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-${two(utc.day)}';
  }

  int _compareDispatchEventsByOccurredAtThenSequence(
    DispatchEvent left,
    DispatchEvent right,
  ) {
    final occurredAt = left.occurredAt.compareTo(right.occurredAt);
    if (occurredAt != 0) {
      return occurredAt;
    }
    final sequence = left.sequence.compareTo(right.sequence);
    if (sequence != 0) {
      return sequence;
    }
    return left.eventId.compareTo(right.eventId);
  }

  ({String clientId, String siteId, String? reportDate})?
  _parseSiteActivityScopeRequest(String arguments) {
    final tokens = arguments
        .split(RegExp(r'\s+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) {
      return (
        clientId: _telegramAdminTargetClientId,
        siteId: _telegramAdminTargetSiteId,
        reportDate: null,
      );
    }
    if (tokens.length == 1 && _looksLikeSiteActivityReportDate(tokens.first)) {
      return (
        clientId: _telegramAdminTargetClientId,
        siteId: _telegramAdminTargetSiteId,
        reportDate: tokens.first,
      );
    }
    if (tokens.length == 2) {
      return (clientId: tokens[0], siteId: tokens[1], reportDate: null);
    }
    if (tokens.length == 3 && _looksLikeSiteActivityReportDate(tokens[2])) {
      return (clientId: tokens[0], siteId: tokens[1], reportDate: tokens[2]);
    }
    return null;
  }

  List<IntelligenceReceived> _siteActivityRowsForScope({
    required String clientId,
    required String siteId,
    String? reportDate,
  }) {
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId.trim();
    final trimmedDate = reportDate?.trim();
    return store
        .allEvents()
        .whereType<IntelligenceReceived>()
        .where(
          (event) =>
              event.clientId.trim() == normalizedClientId &&
              event.siteId.trim() == normalizedSiteId &&
              ((event.sourceType.trim().toLowerCase() == 'dvr') ||
                  (event.sourceType.trim().toLowerCase() == 'cctv')) &&
              (trimmedDate == null ||
                  trimmedDate.isEmpty ||
                  _siteActivityReportDate(event.occurredAt) == trimmedDate),
        )
        .toList(growable: false);
  }

  List<({
    String reportDate,
    SiteActivityIntelligenceSnapshot snapshot,
    List<String> eventIds,
    bool current,
  })> _siteActivityHistoryPointsForScope({
    required String clientId,
    required String siteId,
  }) {
    final scopedEvents = _siteActivityRowsForScope(
      clientId: clientId,
      siteId: siteId,
    );
    if (scopedEvents.isEmpty) {
      return const <({
        String reportDate,
        SiteActivityIntelligenceSnapshot snapshot,
        List<String> eventIds,
        bool current,
      })>[];
    }
    final grouped = <String, List<IntelligenceReceived>>{};
    for (final event in scopedEvents) {
      final reportDate = _siteActivityReportDate(event.occurredAt);
      grouped.putIfAbsent(reportDate, () => <IntelligenceReceived>[]).add(event);
    }
    final reportDates =
        grouped.keys.toList(growable: false)..sort((a, b) => b.compareTo(a));
    final latestDate = reportDates.first;
    return reportDates.map((reportDate) {
      final rows = grouped[reportDate]!.toList(growable: false)
        ..sort(_compareDispatchEventsByOccurredAtThenSequence);
      final snapshot = _siteActivityIntelligenceService.buildSnapshot(
        events: rows,
        clientId: clientId,
        siteId: siteId,
      );
      return (
        reportDate: reportDate,
        snapshot: snapshot,
        eventIds: rows.map((event) => event.eventId).toList(growable: false),
        current: reportDate == latestDate,
      );
    }).toList(growable: false);
  }

  ({
    String reportDate,
    SiteActivityIntelligenceSnapshot snapshot,
    List<String> eventIds,
    bool current,
  })? _siteActivityHistoryPointForScope({
    required String clientId,
    required String siteId,
    String? reportDate,
  }) {
    final history = _siteActivityHistoryPointsForScope(
      clientId: clientId,
      siteId: siteId,
    );
    if (history.isEmpty) {
      return null;
    }
    final trimmedDate = reportDate?.trim();
    if (trimmedDate == null || trimmedDate.isEmpty) {
      return history.first;
    }
    for (final point in history) {
      if (point.reportDate == trimmedDate) {
        return point;
      }
    }
    return null;
  }

  Map<String, Object?> _siteActivityCaseFilePayload({
    required String clientId,
    required String siteId,
    String? reportDate,
  }) {
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId.trim();
    final targetPoint = _siteActivityHistoryPointForScope(
      clientId: normalizedClientId,
      siteId: normalizedSiteId,
      reportDate: reportDate,
    );
    final snapshot =
        targetPoint?.snapshot ??
        _siteActivityIntelligenceService.buildSnapshot(
          events: _siteActivityRowsForScope(
            clientId: normalizedClientId,
            siteId: normalizedSiteId,
            reportDate: reportDate,
          ),
          clientId: normalizedClientId,
          siteId: normalizedSiteId,
        );
    final trend = _siteActivityTrendSnapshotFor(snapshot);
    final history = _siteActivityHistoryPointsForScope(
      clientId: normalizedClientId,
      siteId: normalizedSiteId,
    );
    final effectiveReportDate =
        targetPoint?.reportDate ??
        reportDate?.trim() ??
        _morningSovereignReport?.date;
    return {
      'activityCaseFile': {
        'scope': {
          'clientId': normalizedClientId,
          'siteId': normalizedSiteId,
          'reportDate': effectiveReportDate,
          'generatedAtUtc': _morningSovereignReport?.generatedAtUtc
              .toIso8601String(),
          'reviewCommand':
              '/activityreview $normalizedClientId $normalizedSiteId${effectiveReportDate == null || effectiveReportDate.isEmpty ? '' : ' $effectiveReportDate'}',
          'caseFileCommand':
              '/activitycase json $normalizedClientId $normalizedSiteId${effectiveReportDate == null || effectiveReportDate.isEmpty ? '' : ' $effectiveReportDate'}',
          'current': targetPoint?.current ?? reportDate == null,
        },
        'summaryLine': snapshot.summaryLine,
        'eventIds': targetPoint?.eventIds ?? snapshot.eventIds,
        'selectedEventId':
            targetPoint?.snapshot.selectedEventId ?? snapshot.selectedEventId,
        'reviewRefs': snapshot.evidenceEventIds,
        'topFlaggedIdentitySummary': snapshot.topFlaggedIdentitySummary,
        'topLongPresenceSummary': snapshot.topLongPresenceSummary,
        'topGuardInteractionSummary': snapshot.topGuardInteractionSummary,
        'trend': trend == null
            ? null
            : {
                'label': trend.label,
                'summary': trend.summary,
              },
        'history': history
            .take(3)
            .map(
              (point) => {
                'date': point.reportDate,
                'current': point.current,
                'totalSignals': point.snapshot.totalSignals,
                'unknownSignals':
                    point.snapshot.unknownPersonSignals +
                    point.snapshot.unknownVehicleSignals,
                'flaggedIdentitySignals': point.snapshot.flaggedIdentitySignals,
                'guardInteractionSignals':
                    point.snapshot.guardInteractionSignals,
                'summaryLine': point.snapshot.summaryLine,
                'eventIds': point.eventIds,
                'reviewCommand':
                    '/activityreview $normalizedClientId $normalizedSiteId ${point.reportDate}',
                'caseFileCommand':
                    '/activitycase json $normalizedClientId $normalizedSiteId ${point.reportDate}',
              },
            )
            .toList(growable: false),
      },
    };
  }

  String _siteActivityCaseFileCsv({
    required String clientId,
    required String siteId,
    String? reportDate,
  }) {
    final payload = _siteActivityCaseFilePayload(
      clientId: clientId,
      siteId: siteId,
      reportDate: reportDate,
    );
    final caseFile =
        payload['activityCaseFile'] as Map<String, Object?>? ??
        const <String, Object?>{};
    final scope =
        caseFile['scope'] as Map<String, Object?>? ?? const <String, Object?>{};
    final trend = caseFile['trend'] as Map<String, Object?>?;
    final history = (caseFile['history'] as List<Object?>? ?? const <Object?>[])
        .whereType<Map<String, Object?>>()
        .toList(growable: false);
    final lines = <String>[
      'metric,value',
      'client_id,${scope['clientId'] ?? ''}',
      'site_id,${scope['siteId'] ?? ''}',
      'report_date,${scope['reportDate'] ?? ''}',
      'generated_at_utc,${scope['generatedAtUtc'] ?? ''}',
      'current_scope,${scope['current'] ?? ''}',
      'review_command,${scope['reviewCommand'] ?? ''}',
      'case_file_command,${scope['caseFileCommand'] ?? ''}',
      'summary_line,"${(caseFile['summaryLine'] as String? ?? '').replaceAll('"', '""')}"',
      'selected_event_id,${caseFile['selectedEventId'] ?? ''}',
      'review_refs,"${((caseFile['reviewRefs'] as List<Object?>? ?? const <Object?>[]).join(', ')).replaceAll('"', '""')}"',
      'top_flagged_identity,"${(caseFile['topFlaggedIdentitySummary'] as String? ?? '').replaceAll('"', '""')}"',
      'top_long_presence,"${(caseFile['topLongPresenceSummary'] as String? ?? '').replaceAll('"', '""')}"',
      'top_guard_interaction,"${(caseFile['topGuardInteractionSummary'] as String? ?? '').replaceAll('"', '""')}"',
      'trend_label,${trend?['label'] ?? ''}',
      'trend_summary,"${(trend?['summary'] as String? ?? '').replaceAll('"', '""')}"',
    ];
    for (var index = 0; index < history.length; index += 1) {
      final row = index + 1;
      final point = history[index];
      lines.add('history_${row}_date,${point['date'] ?? ''}');
      lines.add('history_${row}_current,${point['current'] ?? ''}');
      lines.add(
        'history_${row}_summary,"${(point['summaryLine'] as String? ?? '').replaceAll('"', '""')}"',
      );
      lines.add('history_${row}_review_command,${point['reviewCommand'] ?? ''}');
      lines.add(
        'history_${row}_case_file_command,${point['caseFileCommand'] ?? ''}',
      );
    }
    return lines.join('\n');
  }

  Future<String> _deliverSiteActivityTelegramSummary({
    required String clientId,
    required String siteId,
    required bool sendClient,
    required bool sendPartner,
  }) async {
    if (!_telegramBridge.isConfigured) {
      return 'ONYX SENDACTIVITY\nTelegram bridge disabled or missing bot token.';
    }
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId.trim();
    if (normalizedClientId.isEmpty || normalizedSiteId.isEmpty) {
      return 'ONYX SENDACTIVITY\nUsage: /sendactivity [client|partner|both] [client_id site_id]';
    }

    final clientTargets = sendClient
        ? await _resolveTelegramBridgeTargets(
            clientId: normalizedClientId,
            siteId: normalizedSiteId,
          )
        : const <_TelegramBridgeTarget>[];
    final partnerTargets = sendPartner
        ? await _resolveTelegramPartnerTargets(
            clientId: normalizedClientId,
            siteId: normalizedSiteId,
          )
        : const <_TelegramBridgeTarget>[];
    if (clientTargets.isEmpty && partnerTargets.isEmpty) {
      return 'ONYX SENDACTIVITY\n'
          'scope=$normalizedClientId/$normalizedSiteId\n'
          'targets=0\n'
          'No active Telegram endpoints found for the selected delivery lane.';
    }
    final clientSummary = _siteActivityTelegramSummaryForScope(
      clientId: normalizedClientId,
      siteId: normalizedSiteId,
      includeEvidenceHandoff: false,
    );
    final partnerSummary = _siteActivityTelegramSummaryForScope(
      clientId: normalizedClientId,
      siteId: normalizedSiteId,
      includeEvidenceHandoff: true,
      includeReviewCommandHint: true,
      includeCaseFileHint: true,
    );
    final stamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    final dedupedMessages = <String, TelegramBridgeMessage>{};
    for (final target in clientTargets) {
      final message = TelegramBridgeMessage(
        messageKey:
            'site-activity-client-$normalizedClientId-$normalizedSiteId-${target.chatId}-${target.threadId ?? ''}-$stamp',
        chatId: target.chatId,
        messageThreadId: target.threadId,
        text: clientSummary,
      );
      dedupedMessages['${target.chatId}:${target.threadId ?? ''}:client'] =
          message;
    }
    for (final target in partnerTargets) {
      final message = TelegramBridgeMessage(
        messageKey:
            'site-activity-partner-$normalizedClientId-$normalizedSiteId-${target.chatId}-${target.threadId ?? ''}-$stamp',
        chatId: target.chatId,
        messageThreadId: target.threadId,
        text: partnerSummary,
      );
      dedupedMessages['${target.chatId}:${target.threadId ?? ''}:partner'] =
          message;
    }
    final messages = dedupedMessages.values.toList(growable: false);
    final result = await _telegramBridge.sendMessages(messages: messages);
    final sentAt = DateTime.now().toUtc();
    if (mounted) {
      setState(() {
        _telegramBridgeHealthLabel = result.failedCount == 0
            ? 'ok'
            : 'degraded';
        _telegramBridgeHealthDetail = result.failedCount == 0
            ? 'Site activity summary delivery succeeded.'
            : 'Site activity summary delivery failed for ${result.failedCount}/${messages.length} target(s).';
        _telegramBridgeHealthUpdatedAtUtc = sentAt;
      });
    }
    final reasons = result.failureReasonsByMessageKey.values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .take(2)
        .join(' | ');
    final lane = sendClient && sendPartner
        ? 'both'
        : (sendPartner ? 'partner' : 'client');
    return 'ONYX SENDACTIVITY\n'
        'scope=$normalizedClientId/$normalizedSiteId\n'
        'lane=$lane\n'
        'targets=${messages.length}\n'
        'sent=${result.sentCount}\n'
        'failed=${result.failedCount}'
        '${reasons.isEmpty ? '' : '\nreasons=$reasons'}\n'
        'UTC: ${sentAt.toIso8601String()}';
  }

  _MonitoringWatchTarget? _parseMonitoringWatchScope(
    String arguments, {
    bool includeCamera = false,
  }) {
    final tokens = arguments
        .split(RegExp(r'\s+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (!includeCamera) {
      if (tokens.isEmpty) {
        return _MonitoringWatchTarget(
          clientId: _telegramAdminTargetClientId,
          siteId: _telegramAdminTargetSiteId,
        );
      }
      if (tokens.length != 2) {
        return null;
      }
      return _MonitoringWatchTarget(clientId: tokens[0], siteId: tokens[1]);
    }
    if (tokens.isEmpty) {
      return _MonitoringWatchTarget(
        clientId: _telegramAdminTargetClientId,
        siteId: _telegramAdminTargetSiteId,
      );
    }
    if (tokens.length == 1) {
      return _MonitoringWatchTarget(
        clientId: _telegramAdminTargetClientId,
        siteId: _telegramAdminTargetSiteId,
        cameraLabel: tokens[0],
      );
    }
    if (tokens.length == 2) {
      return _MonitoringWatchTarget(clientId: tokens[0], siteId: tokens[1]);
    }
    return _MonitoringWatchTarget(
      clientId: tokens[0],
      siteId: tokens[1],
      cameraLabel: tokens.sublist(2).join(' '),
    );
  }

  Future<String> _enqueueMonitoringClientNotification({
    required String clientId,
    required String siteId,
    required String title,
    required String body,
    required DateTime occurredAtUtc,
    required String messageKeyPrefix,
    required String incidentStatusLabel,
  }) async {
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId.trim();
    final normalizedTitle = title.trim();
    final normalizedBody = body.trim();
    final messageKey =
        '$messageKeyPrefix-${normalizedClientId.toLowerCase()}-${normalizedSiteId.toLowerCase()}-${occurredAtUtc.microsecondsSinceEpoch}';
    await _appendTelegramConversationMessage(
      clientId: normalizedClientId,
      siteId: normalizedSiteId,
      author: 'ONYX Control',
      body: normalizedBody,
      occurredAtUtc: occurredAtUtc,
      roomKey: 'Residents',
      viewerRole: 'client',
      incidentStatusLabel: incidentStatusLabel,
      messageSource: 'system',
      messageProvider: 'onyx_monitoring',
    );
    await _persistClientAppPushQueue(<ClientAppPushDeliveryItem>[
      ClientAppPushDeliveryItem(
        messageKey: messageKey,
        title: normalizedTitle,
        body: normalizedBody,
        occurredAt: occurredAtUtc,
        clientId: normalizedClientId,
        siteId: normalizedSiteId,
        targetChannel: ClientAppAcknowledgementChannel.client,
        deliveryProvider: _clientPushDeliveryProvider,
        priority: true,
        status: ClientPushDeliveryStatus.queued,
      ),
      ..._clientAppPushQueue,
    ], forceTelegramResend: true);
    return messageKey;
  }

  String? _monitoringIdentityHint(IntelligenceReceived event) {
    final parts = <String>[];
    final faceMatchId = (event.faceMatchId ?? '').trim();
    final plateNumber = (event.plateNumber ?? '').trim();
    if (faceMatchId.isNotEmpty) {
      final confidence = event.faceConfidence == null
          ? ''
          : ' ${(event.faceConfidence! * 100).toStringAsFixed(1)}%';
      parts.add('Face $faceMatchId$confidence');
    }
    if (plateNumber.isNotEmpty) {
      final confidence = event.plateConfidence == null
          ? ''
          : ' ${(event.plateConfidence! * 100).toStringAsFixed(1)}%';
      parts.add('Plate $plateNumber$confidence');
    }
    if (parts.isEmpty) {
      return null;
    }
    return parts.join(' • ');
  }

  String _monitoringCameraLabel(String? cameraId) {
    final raw = (cameraId ?? '').trim();
    if (raw.isEmpty) {
      return 'Camera 1';
    }
    final match = RegExp(r'(\d+)$').firstMatch(raw);
    if (match == null) {
      return raw;
    }
    return 'Camera ${match.group(1)}';
  }

  List<MonitoringShiftScopeConfig> _resolveMonitoringShiftScopes() {
    final fallbackSchedule = _activeMonitoringShiftSchedule;
    final parsed = MonitoringShiftScopeConfig.parseJson(
      _monitoringShiftScopesJsonEnv,
      fallbackSchedule: fallbackSchedule,
      fallbackClientId: _selectedClient,
      fallbackRegionId: _selectedRegion,
      fallbackSiteId: _selectedSite,
    );
    if (parsed.isNotEmpty) {
      return parsed;
    }
    return <MonitoringShiftScopeConfig>[
      MonitoringShiftScopeConfig(
        clientId: _selectedClient,
        regionId: _selectedRegion,
        siteId: _selectedSite,
        schedule: fallbackSchedule,
      ),
    ];
  }

  MonitoringShiftSchedule get _activeMonitoringShiftSchedule =>
      const MonitoringShiftSchedule(
        enabled: _monitoringShiftAutoEnabledEnv,
        startHour: _monitoringShiftStartHourEnv,
        startMinute: _monitoringShiftStartMinuteEnv,
        endHour: _monitoringShiftEndHourEnv,
        endMinute: _monitoringShiftEndMinuteEnv,
      );

  bool get _monitoringShiftAutoEligible {
    return _activeVideoProfile.isDvr &&
        _activeVideoProfile.provider.toLowerCase().contains('monitor_only') &&
        _configuredMonitoringShiftScopes.any((entry) => entry.schedule.enabled);
  }

  MonitoringShiftSchedule _monitoringScheduleForScope(
    String clientId,
    String siteId,
  ) {
    for (final entry in _configuredMonitoringShiftScopes) {
      if (entry.clientId.trim() == clientId.trim() &&
          entry.siteId.trim() == siteId.trim()) {
        return entry.schedule;
      }
    }
    return _activeMonitoringShiftSchedule;
  }

  void _startMonitoringWatchScheduleLoop() {
    _monitoringWatchScheduleTimer?.cancel();
    if (!_monitoringShiftAutoEligible) {
      return;
    }
    unawaited(_syncMonitoringWatchScheduleNow());
  }

  void _scheduleNextMonitoringWatchSync(DateTime? nextTransitionLocal) {
    _monitoringWatchScheduleTimer?.cancel();
    if (!_monitoringShiftAutoEligible || nextTransitionLocal == null) {
      return;
    }
    final delay = nextTransitionLocal.difference(DateTime.now());
    final boundedDelay = delay.isNegative
        ? const Duration(seconds: 1)
        : delay + const Duration(seconds: 1);
    _monitoringWatchScheduleTimer = Timer(boundedDelay, () {
      unawaited(_syncMonitoringWatchScheduleNow());
    });
  }

  Future<String?> _activateMonitoringWatch({
    required String clientId,
    required String siteId,
    required DateTime startedAtUtc,
    bool notifyClient = true,
    String messageKeyPrefix = 'tg-watch-start',
  }) async {
    final scopeKey = _monitoringScopeKey(clientId, siteId);
    if (_monitoringWatchByScope.containsKey(scopeKey)) {
      return null;
    }
    final schedule = _monitoringScheduleForScope(clientId, siteId);
    String? messageKey;
    final expectedWindowEndUtc =
        schedule.endForWindowStart(startedAtUtc.toLocal())?.toUtc() ??
        startedAtUtc.add(const Duration(hours: 12));
    if (notifyClient) {
      final site = _monitoringSiteProfileFor(
        clientId: clientId,
        siteId: siteId,
      );
      final body = _monitoringShiftNotifications.formatShiftStart(
        site: site,
        window: MonitoringShiftWindow(
          startedAt: startedAtUtc,
          endsAt: expectedWindowEndUtc,
        ),
      );
      messageKey = await _enqueueMonitoringClientNotification(
        clientId: clientId,
        siteId: siteId,
        title: 'ONYX Monitoring Active',
        body: body,
        occurredAtUtc: startedAtUtc,
        messageKeyPrefix: messageKeyPrefix,
        incidentStatusLabel: 'Monitoring Active',
      );
    }
    _monitoringWatchByScope[scopeKey] = MonitoringWatchRuntimeState(
      startedAtUtc: startedAtUtc,
    );
    await _persistMonitoringWatchRuntimeState();
    if (mounted) {
      setState(() {});
    }
    return messageKey;
  }

  Future<String?> _deactivateMonitoringWatch({
    required String clientId,
    required String siteId,
    required DateTime endedAtUtc,
    bool notifyClient = true,
    String messageKeyPrefix = 'tg-watch-end',
  }) async {
    final scopeKey = _monitoringScopeKey(clientId, siteId);
    final runtime = _monitoringWatchByScope[scopeKey];
    if (runtime == null) {
      return null;
    }
    String? messageKey;
    if (notifyClient) {
      final site = _monitoringSiteProfileFor(
        clientId: clientId,
        siteId: siteId,
      );
      final summary = MonitoringShiftSummary(
        window: MonitoringShiftWindow(
          startedAt: runtime.startedAtUtc,
          endsAt: endedAtUtc,
        ),
        reviewedEvents: runtime.reviewedEvents,
        primaryActivitySource: runtime.primaryActivitySource.trim().isEmpty
            ? 'No material activity logged'
            : runtime.primaryActivitySource.trim(),
        dispatchCount: runtime.dispatchCount,
        alertCount: runtime.alertCount,
        repeatCount: runtime.repeatCount,
        escalationCount: runtime.escalationCount,
        suppressedCount: runtime.suppressedCount,
        actionHistory: runtime.actionHistory,
        suppressedHistory: runtime.suppressedHistory,
        monitoringAvailable: runtime.monitoringAvailable,
        unresolvedActionCount: runtime.unresolvedActionCount,
      );
      final body = _monitoringShiftNotifications.formatShiftSitrep(
        site: site,
        summary: summary,
      );
      messageKey = await _enqueueMonitoringClientNotification(
        clientId: clientId,
        siteId: siteId,
        title: 'ONYX Shift Sitrep',
        body: body,
        occurredAtUtc: endedAtUtc,
        messageKeyPrefix: messageKeyPrefix,
        incidentStatusLabel: 'Shift Sitrep',
      );
    }
    _monitoringWatchByScope.remove(scopeKey);
    await _persistMonitoringWatchRuntimeState();
    if (mounted) {
      setState(() {});
    }
    return messageKey;
  }

  Future<void> _syncMonitoringWatchScheduleNow() async {
    final nowLocal = DateTime.now();
    DateTime? nextTransitionLocal;
    if (!_monitoringShiftAutoEligible) {
      _scheduleNextMonitoringWatchSync(null);
      return;
    }
    for (final configuredScope in _configuredMonitoringShiftScopes) {
      final schedule = configuredScope.schedule;
      final snapshot = schedule.snapshotAt(nowLocal);
      final transition = snapshot.nextTransitionLocal;
      if (transition != null &&
          (nextTransitionLocal == null ||
              transition.isBefore(nextTransitionLocal))) {
        nextTransitionLocal = transition;
      }
      final clientId = configuredScope.clientId;
      final siteId = configuredScope.siteId;
      final scopeKey = _monitoringScopeKey(clientId, siteId);
      final runtime = _monitoringWatchByScope[scopeKey];
      final plan = _watchScheduleSyncPlanService.resolve(
        schedule: schedule,
        snapshot: snapshot,
        nowLocal: nowLocal,
        nowUtc: nowLocal.toUtc(),
        activeWatchStartedAtUtc: runtime?.startedAtUtc,
      );
      if (plan.action == MonitoringWatchScheduleSyncAction.activate &&
          plan.startedAtUtc != null) {
        await _activateMonitoringWatch(
          clientId: clientId,
          siteId: siteId,
          startedAtUtc: plan.startedAtUtc!,
          notifyClient: plan.shouldNotify,
          messageKeyPrefix: 'tg-watch-auto-start',
        );
        continue;
      }
      if (plan.action == MonitoringWatchScheduleSyncAction.deactivate &&
          plan.endedAtUtc != null) {
        await _deactivateMonitoringWatch(
          clientId: clientId,
          siteId: siteId,
          endedAtUtc: plan.endedAtUtc!,
          notifyClient: plan.shouldNotify,
          messageKeyPrefix: 'tg-watch-auto-end',
        );
      }
    }
    _scheduleNextMonitoringWatchSync(nextTransitionLocal);
  }

  Future<void> _resyncMonitoringWatchForScope({
    required String clientId,
    required String siteId,
    String actor = 'SYSTEM',
  }) async {
    final schedule = _monitoringScheduleForScope(clientId, siteId);
    final nowLocal = DateTime.now();
    final nowUtc = nowLocal.toUtc();
    final snapshot = schedule.snapshotAt(nowLocal);
    final scopeKey = _monitoringScopeKey(clientId, siteId);
    final runtime = _monitoringWatchByScope[scopeKey];
    final plan = _watchResyncPlanService.resolve(
      schedule: schedule,
      snapshot: snapshot,
      nowUtc: nowUtc,
      activeWatchStartedAtUtc: runtime?.startedAtUtc,
    );
    if (plan.action == MonitoringWatchResyncAction.activate &&
        plan.startedAtUtc != null) {
      await _activateMonitoringWatch(
        clientId: clientId,
        siteId: siteId,
        startedAtUtc: plan.startedAtUtc!,
        notifyClient: false,
        messageKeyPrefix: 'tg-watch-resync-start',
      );
    } else if (plan.action == MonitoringWatchResyncAction.deactivate &&
        plan.endedAtUtc != null) {
      await _deactivateMonitoringWatch(
        clientId: clientId,
        siteId: siteId,
        endedAtUtc: plan.endedAtUtc!,
        notifyClient: false,
        messageKeyPrefix: 'tg-watch-resync-end',
      );
    }
    _recordMonitoringWatchResyncOutcome(
      clientId: clientId,
      siteId: siteId,
      actor: actor,
      outcome: plan.outcome,
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _processActiveMonitoringWatchEvents(
    List<IntelligenceReceived> appendedEvents,
  ) async {
    if (appendedEvents.isEmpty || !_activeVideoProfile.isDvr) {
      return;
    }
    if (!_activeVideoProfile.provider.toLowerCase().contains('monitor_only')) {
      return;
    }
    final scopedEvents = <String, List<IntelligenceReceived>>{};
    for (final event in appendedEvents) {
      if (!_matchesActiveVideoProviderEvent(event)) {
        continue;
      }
      final scopeKey = _monitoringScopeKey(event.clientId, event.siteId);
      if (!_monitoringWatchByScope.containsKey(scopeKey)) {
        continue;
      }
      final bucket = scopedEvents.putIfAbsent(
        scopeKey,
        () => <IntelligenceReceived>[],
      );
      bucket.add(event);
    }
    if (scopedEvents.isEmpty) {
      return;
    }
    for (final entry in scopedEvents.entries) {
      final runtime = _monitoringWatchByScope[entry.key];
      if (runtime == null) {
        continue;
      }
      final events = entry.value.toList(growable: false)
        ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      final latest = events.first;
      final cameraLabel = _monitoringCameraLabel(latest.cameraId);
      final site = _monitoringSiteProfileFor(
        clientId: latest.clientId,
        siteId: latest.siteId,
      );
      final review = await _monitoringWatchVisionReview.review(
        event: latest,
        authConfig: _monitoringVisionAuthConfigForScope(
          latest.clientId,
          latest.siteId,
        ),
        priorReviewedEvents: runtime.reviewedEvents,
        groupedEventCount: events.length,
      );
      final assessment = _watchSceneAssessmentService.assess(
        event: latest,
        review: review,
        priorReviewedEvents: runtime.reviewedEvents,
        groupedEventCount: events.length,
      );
      final decision = _watchEscalationPolicyService.decide(assessment);
      final sceneReviewSource = review.usedFallback
          ? 'metadata-only'
          : review.sourceLabel.trim();
      final sceneReviewSummary = review.summary.trim().isEmpty
          ? assessment.rationale.join(' • ')
          : review.summary.trim();
      await _recordMonitoringSceneReview(
        event: latest,
        assessment: assessment,
        review: review,
        decision: decision,
      );
      final incident = MonitoringIncidentUpdate(
        occurredAt: latest.occurredAt,
        cameraLabel: cameraLabel,
        objectLabel: assessment.objectLabel,
        postureLabel: assessment.postureLabel,
      );
      if (decision.shouldNotifyClient) {
        final requiresClientApproval = _telegramClientApprovalService
            .requiresClientApproval(event: latest, assessment: assessment);
        final messageBody = requiresClientApproval
            ? _monitoringShiftNotifications.formatClientVerificationPrompt(
                site: site,
                incident: incident,
                identityHint: _monitoringIdentityHint(latest),
              )
            : switch (decision.kind) {
                MonitoringWatchNotificationKind.repeat =>
                  _monitoringShiftNotifications.formatRepeatActivity(
                    site: site,
                    incident: incident,
                  ),
                MonitoringWatchNotificationKind.escalationCandidate =>
                  _monitoringShiftNotifications.formatEscalationCandidate(
                    site: site,
                    incident: incident,
                  ),
                MonitoringWatchNotificationKind.incident =>
                  _monitoringShiftNotifications.formatIncident(
                    site: site,
                    incident: incident,
                  ),
                MonitoringWatchNotificationKind.suppressed => '',
              };
        await _enqueueMonitoringClientNotification(
          clientId: latest.clientId,
          siteId: latest.siteId,
          title: requiresClientApproval
              ? 'ONYX Verification Required'
              : decision.title,
          body: messageBody,
          occurredAtUtc: latest.occurredAt,
          messageKeyPrefix: requiresClientApproval
              ? TelegramClientApprovalService.verificationMessageKeyPrefix
              : decision.messageKeyPrefix,
          incidentStatusLabel: requiresClientApproval
              ? 'Client Verification Required'
              : decision.incidentStatusLabel,
        );
      }
      _monitoringWatchByScope[entry.key] = _watchRuntimeStore
          .applyReviewedActivity(
            runtime: runtime,
            reviewedEventDelta: events.length,
            activitySource: cameraLabel,
            alertDelta:
                decision.kind == MonitoringWatchNotificationKind.incident
                ? 1
                : 0,
            repeatDelta: decision.kind == MonitoringWatchNotificationKind.repeat
                ? 1
                : 0,
            escalationDelta: decision.shouldIncrementEscalation ? 1 : 0,
            suppressedDelta:
                decision.kind == MonitoringWatchNotificationKind.suppressed
                ? events.length
                : 0,
            sceneReviewSourceLabel: sceneReviewSource,
            sceneReviewPostureLabel: assessment.postureLabel,
            sceneReviewSummary: sceneReviewSummary,
            sceneDecisionLabel: decision.incidentStatusLabel,
            sceneDecisionSummary: decision.decisionSummary,
            sceneReviewRecordedAtUtc: latest.occurredAt,
          );
      await _persistMonitoringWatchRuntimeState();
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<String> _telegramAdminWatchStartCommand(String arguments) async {
    final target = _parseMonitoringWatchScope(arguments);
    if (target == null) {
      return 'ONYX WATCHSTART\nUsage: /watchstart [client_id site_id]';
    }
    final clientId = target.clientId.trim();
    final siteId = target.siteId.trim();
    if (clientId.isEmpty || siteId.isEmpty) {
      return 'ONYX WATCHSTART\nInvalid scope. Use /settarget <client_id site_id> first.';
    }
    final scopeKey = _monitoringScopeKey(clientId, siteId);
    final activeRuntime = _monitoringWatchByScope[scopeKey];
    if (activeRuntime != null) {
      return 'ONYX WATCHSTART\n'
          'scope=$clientId/$siteId\n'
          'status=already-active\n'
          'started_at=${activeRuntime.startedAtUtc.toIso8601String()}';
    }
    final nowUtc = DateTime.now().toUtc();
    final messageKey =
        await _activateMonitoringWatch(
          clientId: clientId,
          siteId: siteId,
          startedAtUtc: nowUtc,
          notifyClient: true,
          messageKeyPrefix: 'tg-watch-start',
        ) ??
        '';
    return 'ONYX WATCHSTART\n'
        'scope=$clientId/$siteId\n'
        'message_key=$messageKey\n'
        'queue_size=${_clientAppPushQueue.length}\n'
        'started_at=${nowUtc.toIso8601String()}';
  }

  Future<String> _telegramAdminWatchAlertCommand(String arguments) async {
    final target = _parseMonitoringWatchScope(arguments, includeCamera: true);
    if (target == null) {
      return 'ONYX WATCHALERT\nUsage: /watchalert [client_id site_id] [camera_label]';
    }
    final clientId = target.clientId.trim();
    final siteId = target.siteId.trim();
    if (clientId.isEmpty || siteId.isEmpty) {
      return 'ONYX WATCHALERT\nInvalid scope. Use /settarget <client_id site_id> first.';
    }
    final scopeKey = _monitoringScopeKey(clientId, siteId);
    final runtime = _monitoringWatchByScope[scopeKey];
    if (runtime == null) {
      return 'ONYX WATCHALERT\nscope=$clientId/$siteId\nNo active monitoring watch. Run /watchstart first.';
    }
    final nowUtc = DateTime.now().toUtc();
    final cameraLabel = target.cameraLabel.trim().isEmpty
        ? 'Camera 1'
        : target.cameraLabel.trim();
    final site = _monitoringSiteProfileFor(clientId: clientId, siteId: siteId);
    final body = _monitoringShiftNotifications.formatIncident(
      site: site,
      incident: MonitoringIncidentUpdate(
        occurredAt: nowUtc,
        cameraLabel: cameraLabel,
      ),
    );
    final messageKey = await _enqueueMonitoringClientNotification(
      clientId: clientId,
      siteId: siteId,
      title: 'ONYX Monitoring Alert',
      body: body,
      occurredAtUtc: nowUtc,
      messageKeyPrefix: 'tg-watch-alert',
      incidentStatusLabel: 'Monitoring Alert',
    );
    _monitoringWatchByScope[scopeKey] = _watchRuntimeStore
        .applyReviewedActivity(
          runtime: runtime,
          reviewedEventDelta: 1,
          activitySource: cameraLabel,
          alertDelta: 1,
        );
    await _persistMonitoringWatchRuntimeState();
    if (mounted) {
      setState(() {});
    }
    return 'ONYX WATCHALERT\n'
        'scope=$clientId/$siteId\n'
        'camera=$cameraLabel\n'
        'message_key=$messageKey\n'
        'reviewed_events=${_monitoringWatchByScope[scopeKey]!.reviewedEvents}\n'
        'queue_size=${_clientAppPushQueue.length}\n'
        'utc=${nowUtc.toIso8601String()}';
  }

  Future<String> _telegramAdminWatchRepeatCommand(String arguments) async {
    final target = _parseMonitoringWatchScope(arguments, includeCamera: true);
    if (target == null) {
      return 'ONYX WATCHREPEAT\nUsage: /watchrepeat [client_id site_id] [camera_label]';
    }
    final clientId = target.clientId.trim();
    final siteId = target.siteId.trim();
    if (clientId.isEmpty || siteId.isEmpty) {
      return 'ONYX WATCHREPEAT\nInvalid scope. Use /settarget <client_id site_id> first.';
    }
    final scopeKey = _monitoringScopeKey(clientId, siteId);
    final runtime = _monitoringWatchByScope[scopeKey];
    if (runtime == null) {
      return 'ONYX WATCHREPEAT\nscope=$clientId/$siteId\nNo active monitoring watch. Run /watchstart first.';
    }
    final nowUtc = DateTime.now().toUtc();
    final cameraLabel = target.cameraLabel.trim().isEmpty
        ? 'Camera 1'
        : target.cameraLabel.trim();
    final site = _monitoringSiteProfileFor(clientId: clientId, siteId: siteId);
    final body = _monitoringShiftNotifications.formatRepeatActivity(
      site: site,
      incident: MonitoringIncidentUpdate(
        occurredAt: nowUtc,
        cameraLabel: cameraLabel,
      ),
    );
    final messageKey = await _enqueueMonitoringClientNotification(
      clientId: clientId,
      siteId: siteId,
      title: 'ONYX Monitoring Update',
      body: body,
      occurredAtUtc: nowUtc,
      messageKeyPrefix: 'tg-watch-repeat',
      incidentStatusLabel: 'Repeat Activity',
    );
    _monitoringWatchByScope[scopeKey] = _watchRuntimeStore
        .applyReviewedActivity(
          runtime: runtime,
          reviewedEventDelta: 1,
          activitySource: cameraLabel,
          repeatDelta: 1,
          escalationDelta: 1,
        );
    await _persistMonitoringWatchRuntimeState();
    if (mounted) {
      setState(() {});
    }
    return 'ONYX WATCHREPEAT\n'
        'scope=$clientId/$siteId\n'
        'camera=$cameraLabel\n'
        'message_key=$messageKey\n'
        'reviewed_events=${_monitoringWatchByScope[scopeKey]!.reviewedEvents}\n'
        'escalations=${_monitoringWatchByScope[scopeKey]!.escalationCount}\n'
        'queue_size=${_clientAppPushQueue.length}\n'
        'utc=${nowUtc.toIso8601String()}';
  }

  Future<String> _telegramAdminWatchEndCommand(String arguments) async {
    final target = _parseMonitoringWatchScope(arguments);
    if (target == null) {
      return 'ONYX WATCHEND\nUsage: /watchend [client_id site_id]';
    }
    final clientId = target.clientId.trim();
    final siteId = target.siteId.trim();
    if (clientId.isEmpty || siteId.isEmpty) {
      return 'ONYX WATCHEND\nInvalid scope. Use /settarget <client_id site_id> first.';
    }
    final scopeKey = _monitoringScopeKey(clientId, siteId);
    final runtime = _monitoringWatchByScope[scopeKey];
    if (runtime == null) {
      return 'ONYX WATCHEND\nscope=$clientId/$siteId\nNo active monitoring watch. Run /watchstart first.';
    }
    final nowUtc = DateTime.now().toUtc();
    final messageKey =
        await _deactivateMonitoringWatch(
          clientId: clientId,
          siteId: siteId,
          endedAtUtc: nowUtc,
          notifyClient: true,
          messageKeyPrefix: 'tg-watch-end',
        ) ??
        '';
    return 'ONYX WATCHEND\n'
        'scope=$clientId/$siteId\n'
        'message_key=$messageKey\n'
        'reviewed_events=${runtime.reviewedEvents}\n'
        'escalations=${runtime.escalationCount}\n'
        'dispatches=${runtime.dispatchCount}\n'
        'queue_size=${_clientAppPushQueue.length}\n'
        'ended_at=${nowUtc.toIso8601String()}';
  }

  Future<void> _appendTelegramAiLedger({
    required String clientId,
    required String siteId,
    required String lane,
    required String action,
    required String inboundText,
    String? outboundText,
    String? providerLabel,
    required TelegramBridgeInboundMessage update,
  }) async {
    final normalizedClientId = clientId.trim();
    if (normalizedClientId.isEmpty) {
      return;
    }
    try {
      final canonicalJson = jsonEncode({
        'type': 'telegram_ai',
        'lane': lane.trim(),
        'action': action.trim(),
        'site_id': siteId.trim(),
        'chat_id': update.chatId.trim(),
        'message_thread_id': update.messageThreadId,
        'from_user_id': update.fromUserId,
        'from_username': update.fromUsername,
        'update_id': update.updateId,
        'inbound_text': inboundText.trim(),
        if ((outboundText ?? '').trim().isNotEmpty)
          'outbound_text': outboundText!.trim(),
        if ((providerLabel ?? '').trim().isNotEmpty)
          'provider_label': providerLabel!.trim(),
        'occurred_at_utc': DateTime.now().toUtc().toIso8601String(),
      });
      final previousHash = await _clientLedgerRepository.fetchPreviousHash(
        normalizedClientId,
      );
      final combined = previousHash == null
          ? canonicalJson
          : canonicalJson + previousHash;
      final hash = sha256.convert(utf8.encode(combined)).toString();
      await _clientLedgerRepository.insertLedgerRow(
        clientId: normalizedClientId,
        dispatchId:
            'TG-AI-${DateTime.now().toUtc().millisecondsSinceEpoch}-${update.updateId}',
        canonicalJson: canonicalJson,
        hash: hash,
        previousHash: previousHash,
      );
    } catch (_) {
      // AI chat routing must not break operations when ledger insert fails.
    }
  }

  _TelegramAdminCommandParseResult? _telegramAdminCommand(String text) {
    final trimmed = text.trim();
    if (!trimmed.startsWith('/')) {
      return _telegramAdminNaturalCommand(trimmed);
    }
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.isEmpty) {
      return null;
    }
    final token = parts.first.toLowerCase();
    final arguments = parts.length > 1 ? parts.sublist(1).join(' ').trim() : '';
    final command = token.split('@').first;
    switch (command) {
      case '/start':
      case '/help':
        return _TelegramAdminCommandParseResult(
          command: 'help',
          arguments: arguments,
        );
      case '/status':
        return _TelegramAdminCommandParseResult(
          command: 'status',
          arguments: arguments,
        );
      case '/ops':
        return _TelegramAdminCommandParseResult(
          command: 'ops',
          arguments: arguments,
        );
      case '/incidents':
        return _TelegramAdminCommandParseResult(
          command: 'incidents',
          arguments: arguments,
        );
      case '/incident':
        return _TelegramAdminCommandParseResult(
          command: 'incident',
          arguments: arguments,
        );
      case '/critical':
        return _TelegramAdminCommandParseResult(
          command: 'critical',
          arguments: arguments,
        );
      case '/syncguards':
        return _TelegramAdminCommandParseResult(
          command: 'syncguards',
          arguments: arguments,
        );
      case '/pollops':
        return _TelegramAdminCommandParseResult(
          command: 'pollops',
          arguments: arguments,
        );
      case '/history':
        return _TelegramAdminCommandParseResult(
          command: 'history',
          arguments: arguments,
        );
      case '/adminconfig':
        return _TelegramAdminCommandParseResult(
          command: 'adminconfig',
          arguments: arguments,
        );
      case '/pushcritical':
        return _TelegramAdminCommandParseResult(
          command: 'pushcritical',
          arguments: arguments,
        );
      case '/setpoll':
        return _TelegramAdminCommandParseResult(
          command: 'setpoll',
          arguments: arguments,
        );
      case '/setreminder':
        return _TelegramAdminCommandParseResult(
          command: 'setreminder',
          arguments: arguments,
        );
      case '/target':
        return _TelegramAdminCommandParseResult(
          command: 'target',
          arguments: arguments,
        );
      case '/settarget':
        return _TelegramAdminCommandParseResult(
          command: 'settarget',
          arguments: arguments,
        );
      case '/acl':
        return _TelegramAdminCommandParseResult(
          command: 'acl',
          arguments: arguments,
        );
      case '/exec':
        return _TelegramAdminCommandParseResult(
          command: 'exec',
          arguments: arguments,
        );
      case '/notifytest':
        return _TelegramAdminCommandParseResult(
          command: 'notifytest',
          arguments: arguments,
        );
      case '/watchstart':
        return _TelegramAdminCommandParseResult(
          command: 'watchstart',
          arguments: arguments,
        );
      case '/watchalert':
        return _TelegramAdminCommandParseResult(
          command: 'watchalert',
          arguments: arguments,
        );
      case '/watchrepeat':
        return _TelegramAdminCommandParseResult(
          command: 'watchrepeat',
          arguments: arguments,
        );
      case '/watchend':
        return _TelegramAdminCommandParseResult(
          command: 'watchend',
          arguments: arguments,
        );
      case '/bindchat':
        return _TelegramAdminCommandParseResult(
          command: 'bindchat',
          arguments: arguments,
        );
      case '/bindpartner':
        return _TelegramAdminCommandParseResult(
          command: 'bindpartner',
          arguments: arguments,
        );
      case '/bindalarm':
        return _TelegramAdminCommandParseResult(
          command: 'bindalarm',
          arguments: arguments,
        );
      case '/linkchat':
        return _TelegramAdminCommandParseResult(
          command: 'linkchat',
          arguments: arguments,
        );
      case '/unlinkchat':
        return _TelegramAdminCommandParseResult(
          command: 'unlinkchat',
          arguments: arguments,
        );
      case '/unlinkpartner':
        return _TelegramAdminCommandParseResult(
          command: 'unlinkpartner',
          arguments: arguments,
        );
      case '/unlinkalarm':
        return _TelegramAdminCommandParseResult(
          command: 'unlinkalarm',
          arguments: arguments,
        );
      case '/unlinkall':
        return _TelegramAdminCommandParseResult(
          command: 'unlinkall',
          arguments: arguments,
        );
      case '/chatcheck':
        return _TelegramAdminCommandParseResult(
          command: 'chatcheck',
          arguments: arguments,
        );
      case '/partnercheck':
        return _TelegramAdminCommandParseResult(
          command: 'partnercheck',
          arguments: arguments,
        );
      case '/alarmbindings':
        return _TelegramAdminCommandParseResult(
          command: 'alarmbindings',
          arguments: arguments,
        );
      case '/alarmtest':
        return _TelegramAdminCommandParseResult(
          command: 'alarmtest',
          arguments: arguments,
        );
      case '/activitytruth':
        return _TelegramAdminCommandParseResult(
          command: 'activitytruth',
          arguments: arguments,
        );
      case '/activityreview':
        return _TelegramAdminCommandParseResult(
          command: 'activityreview',
          arguments: arguments,
        );
      case '/activitycase':
        return _TelegramAdminCommandParseResult(
          command: 'activitycase',
          arguments: arguments,
        );
      case '/readinessreview':
        return _TelegramAdminCommandParseResult(
          command: 'readinessreview',
          arguments: arguments,
        );
      case '/readinesscase':
        return _TelegramAdminCommandParseResult(
          command: 'readinesscase',
          arguments: arguments,
        );
      case '/sendactivity':
        return _TelegramAdminCommandParseResult(
          command: 'sendactivity',
          arguments: arguments,
        );
      case '/demoprep':
        return _TelegramAdminCommandParseResult(
          command: 'demoprep',
          arguments: arguments,
        );
      case '/demoflow':
        return _TelegramAdminCommandParseResult(
          command: 'demoflow',
          arguments: arguments,
        );
      case '/autodemo':
        return _TelegramAdminCommandParseResult(
          command: 'autodemo',
          arguments: arguments,
        );
      case '/demoscript':
        return _TelegramAdminCommandParseResult(
          command: 'demoscript',
          arguments: arguments,
        );
      case '/democlean':
        return _TelegramAdminCommandParseResult(
          command: 'democlean',
          arguments: arguments,
        );
      case '/demolaunch':
        return _TelegramAdminCommandParseResult(
          command: 'demolaunch',
          arguments: arguments,
        );
      case '/demoplay':
        return _TelegramAdminCommandParseResult(
          command: 'demoplay',
          arguments: arguments,
        );
      case '/demoplaystop':
        return _TelegramAdminCommandParseResult(
          command: 'demoplaystop',
          arguments: arguments,
        );
      case '/demoplaystatus':
        return _TelegramAdminCommandParseResult(
          command: 'demoplaystatus',
          arguments: arguments,
        );
      case '/targets':
        return _TelegramAdminCommandParseResult(
          command: 'targets',
          arguments: arguments,
        );
      case '/demostart':
        return _TelegramAdminCommandParseResult(
          command: 'demostart',
          arguments: arguments,
        );
      case '/demofull':
        return _TelegramAdminCommandParseResult(
          command: 'demofull',
          arguments: arguments,
        );
      case '/demostop':
        return _TelegramAdminCommandParseResult(
          command: 'demostop',
          arguments: arguments,
        );
      case '/demostatus':
        return _TelegramAdminCommandParseResult(
          command: 'demostatus',
          arguments: arguments,
        );
      case '/snoozecritical':
        return _TelegramAdminCommandParseResult(
          command: 'snoozecritical',
          arguments: arguments,
        );
      case '/unsnoozecritical':
        return _TelegramAdminCommandParseResult(
          command: 'unsnoozecritical',
          arguments: arguments,
        );
      case '/ackcritical':
        return _TelegramAdminCommandParseResult(
          command: 'ackcritical',
          arguments: arguments,
        );
      case '/unackcritical':
        return _TelegramAdminCommandParseResult(
          command: 'unackcritical',
          arguments: arguments,
        );
      case '/guards':
        return _TelegramAdminCommandParseResult(
          command: 'guards',
          arguments: arguments,
        );
      case '/bridges':
        return _TelegramAdminCommandParseResult(
          command: 'bridges',
          arguments: arguments,
        );
      case '/brief':
        return _TelegramAdminCommandParseResult(
          command: 'brief',
          arguments: arguments,
        );
      case '/next':
        return _TelegramAdminCommandParseResult(
          command: 'next',
          arguments: arguments,
        );
      case '/ping':
        return _TelegramAdminCommandParseResult(
          command: 'ping',
          arguments: arguments,
        );
      case '/aiassist':
        return _TelegramAdminCommandParseResult(
          command: 'aiassist',
          arguments: arguments,
        );
      case '/aiapproval':
        return _TelegramAdminCommandParseResult(
          command: 'aiapproval',
          arguments: arguments,
        );
      case '/aidrafts':
        return _TelegramAdminCommandParseResult(
          command: 'aidrafts',
          arguments: arguments,
        );
      case '/aiapprove':
        return _TelegramAdminCommandParseResult(
          command: 'aiapprove',
          arguments: arguments,
        );
      case '/aireject':
        return _TelegramAdminCommandParseResult(
          command: 'aireject',
          arguments: arguments,
        );
      case '/aiconv':
        return _TelegramAdminCommandParseResult(
          command: 'aiconv',
          arguments: arguments,
        );
      case '/ask':
        return _TelegramAdminCommandParseResult(
          command: 'ask',
          arguments: arguments,
        );
      case '/whoami':
        return _TelegramAdminCommandParseResult(
          command: 'whoami',
          arguments: arguments,
        );
      default:
        return null;
    }
  }

  _TelegramAdminCommandParseResult? _telegramAdminNaturalCommand(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }

    final tokens = normalized
        .split(RegExp(r'\s+'))
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
    if (tokens.isNotEmpty) {
      final first = tokens.first;
      final args = tokens.length > 1 ? tokens.sublist(1).join(' ').trim() : '';
      const exactWordCommands = <String>{
        'status',
        'brief',
        'next',
        'critical',
        'pollops',
        'syncguards',
        'ops',
        'incidents',
        'incident',
        'history',
        'adminconfig',
        'pushcritical',
        'setpoll',
        'setreminder',
        'target',
        'settarget',
        'acl',
        'exec',
        'notifytest',
        'watchstart',
        'watchalert',
        'watchrepeat',
        'watchend',
        'bindchat',
        'bindpartner',
        'bindalarm',
        'linkchat',
        'unlinkchat',
        'unlinkpartner',
        'unlinkalarm',
        'unlinkall',
        'chatcheck',
        'partnercheck',
        'alarmbindings',
        'alarmtest',
        'activitytruth',
        'activityreview',
        'activitycase',
        'readinessreview',
        'readinesscase',
        'sendactivity',
        'demoprep',
        'demoflow',
        'autodemo',
        'demoscript',
        'democlean',
        'demolaunch',
        'demoplay',
        'demoplaystop',
        'demoplaystatus',
        'targets',
        'demostart',
        'demofull',
        'demostop',
        'demostatus',
        'snoozecritical',
        'unsnoozecritical',
        'ackcritical',
        'unackcritical',
        'guards',
        'bridges',
        'aiassist',
        'aiapproval',
        'aidrafts',
        'aiapprove',
        'aireject',
        'aiconv',
        'ask',
        'whoami',
        'ping',
        'help',
      };
      if (exactWordCommands.contains(first)) {
        return _TelegramAdminCommandParseResult(
          command: first,
          arguments: args,
        );
      }
    }

    bool hasAny(List<String> phrases) {
      return phrases.any(normalized.contains);
    }

    if (hasAny(const [
      'whoami',
      'who am i',
      'my user id',
      'user id',
      'my id',
    ])) {
      return const _TelegramAdminCommandParseResult(command: 'whoami');
    }
    if (hasAny(const ['help', 'commands', 'what can you do'])) {
      return const _TelegramAdminCommandParseResult(command: 'help');
    }
    if (hasAny(const [
      'what next',
      'next step',
      'next steps',
      'next 5',
      'next five',
      'what should i do',
      'what do i do',
      'do now',
      'actions now',
      'action now',
      'what now',
      'immediate actions',
    ])) {
      return const _TelegramAdminCommandParseResult(command: 'next');
    }
    if (hasAny(const [
      'ack critical',
      'acknowledge critical',
      'ack the critical',
      'acknowledge the critical',
    ])) {
      return const _TelegramAdminCommandParseResult(command: 'ackcritical');
    }
    if (hasAny(const ['critical short', 'short critical', 'critical brief'])) {
      return const _TelegramAdminCommandParseResult(
        command: 'critical',
        arguments: 'short',
      );
    }
    if (hasAny(const ['critical', 'risk', 'alert', 'urgent'])) {
      return const _TelegramAdminCommandParseResult(command: 'critical');
    }
    if (hasAny(const ['brief', 'summary', 'quick update', 'quick summary'])) {
      return const _TelegramAdminCommandParseResult(command: 'brief');
    }
    final mentionsStatus = hasAny(const ['status', 'posture', 'health']);
    final wantsFullStatus =
        hasAny(const [
          'full status',
          'status full',
          'detailed status',
          'status detailed',
          'verbose status',
          'status verbose',
        ]) ||
        (mentionsStatus &&
            hasAny(const ['full', 'detailed', 'verbose', 'long', 'detail']));
    if (wantsFullStatus) {
      return const _TelegramAdminCommandParseResult(
        command: 'status',
        arguments: 'full',
      );
    }
    if (mentionsStatus) {
      return const _TelegramAdminCommandParseResult(command: 'status');
    }
    if (hasAny(const ['ops', 'operations'])) {
      return const _TelegramAdminCommandParseResult(command: 'ops');
    }
    if (hasAny(const [
      'site activity',
      'activity truth',
      'visitor truth',
      'visitor activity',
    ])) {
      return const _TelegramAdminCommandParseResult(command: 'activitytruth');
    }
    if (hasAny(const [
      'activity review',
      'open activity review',
      'review activity',
      'open events review',
    ])) {
      return const _TelegramAdminCommandParseResult(command: 'activityreview');
    }
    if (hasAny(const ['activity case', 'case file', 'activity dossier'])) {
      return const _TelegramAdminCommandParseResult(command: 'activitycase');
    }
    if (hasAny(const [
      'readiness review',
      'global readiness review',
      'open governance readiness',
    ])) {
      return const _TelegramAdminCommandParseResult(command: 'readinessreview');
    }
    if (hasAny(const [
      'readiness case',
      'readiness dossier',
      'global readiness case',
    ])) {
      return const _TelegramAdminCommandParseResult(command: 'readinesscase');
    }
    if (hasAny(const ['incident', 'incidents'])) {
      return const _TelegramAdminCommandParseResult(command: 'incidents');
    }
    if (hasAny(const ['bridge', 'bridges'])) {
      return const _TelegramAdminCommandParseResult(command: 'bridges');
    }
    if (hasAny(const ['guard', 'guards'])) {
      return const _TelegramAdminCommandParseResult(command: 'guards');
    }
    if (hasAny(const ['target scope', 'target'])) {
      return const _TelegramAdminCommandParseResult(command: 'target');
    }

    final questionLike =
        text.contains('?') ||
        normalized.startsWith('what ') ||
        normalized.startsWith('how ') ||
        normalized.startsWith('why ') ||
        normalized.startsWith('when ') ||
        normalized.startsWith('where ') ||
        normalized.startsWith('can you ') ||
        normalized.startsWith('please ');
    if (questionLike) {
      return _TelegramAdminCommandParseResult(
        command: 'ask',
        arguments: text.trim(),
      );
    }
    return null;
  }

  bool _isTelegramAdminSenderAllowed(TelegramBridgeInboundMessage update) {
    final allowList = _telegramAdminAllowedUserIds;
    if (allowList.isEmpty) {
      return true;
    }
    final senderId = update.fromUserId;
    if (senderId == null) {
      return false;
    }
    return allowList.contains(senderId);
  }

  bool _telegramAdminRequiresExecutionMode(String command) {
    switch (command) {
      case 'syncguards':
      case 'pollops':
      case 'pushcritical':
      case 'demostart':
      case 'demofull':
      case 'demostop':
      case 'notifytest':
      case 'watchstart':
      case 'watchalert':
      case 'watchrepeat':
      case 'watchend':
      case 'bindchat':
      case 'bindpartner':
      case 'bindalarm':
      case 'linkchat':
      case 'unlinkchat':
      case 'unlinkpartner':
      case 'unlinkalarm':
      case 'unlinkall':
      case 'alarmtest':
      case 'sendactivity':
      case 'setoperator':
      case 'demoflow':
      case 'autodemo':
      case 'demoscript':
      case 'democlean':
      case 'demolaunch':
      case 'demoplay':
      case 'demoplaystop':
        return true;
      default:
        return false;
    }
  }

  bool _telegramAdminReadOnlyCommand(String command) {
    switch (command) {
      case 'help':
      case 'status':
      case 'brief':
      case 'ops':
      case 'incidents':
      case 'incident':
      case 'critical':
      case 'history':
      case 'adminconfig':
      case 'operator':
      case 'target':
      case 'guards':
      case 'bridges':
      case 'alarmbindings':
      case 'activitytruth':
      case 'activityreview':
      case 'activitycase':
      case 'readinessreview':
      case 'readinesscase':
      case 'aidrafts':
      case 'aiconv':
      case 'whoami':
      case 'ping':
      case 'next':
        return true;
      default:
        return false;
    }
  }

  Future<String> _telegramAdminResponseFor(
    String command,
    TelegramBridgeInboundMessage update, {
    String arguments = '',
  }) async {
    if (_telegramAdminRequiresExecutionMode(command) &&
        !_telegramAdminExecutionEnabled) {
      return 'ONYX EXECUTION MODE\nExecution commands are currently disabled.\nUse /exec on to enable operational actions.';
    }
    switch (command) {
      case 'status':
        return _telegramAdminStatusCommand(arguments);
      case 'ops':
        return _telegramAdminOpsSnapshot();
      case 'incidents':
        return _telegramAdminIncidentsSnapshot();
      case 'incident':
        return _telegramAdminIncidentSnapshotCommand(arguments);
      case 'critical':
        return _telegramAdminCriticalCommand(arguments);
      case 'syncguards':
        return _telegramAdminSyncGuardsCommand();
      case 'pollops':
        return _telegramAdminPollOpsCommand();
      case 'history':
        return _telegramAdminHistorySnapshot();
      case 'adminconfig':
        return _telegramAdminConfigSnapshot();
      case 'operator':
        return _telegramAdminOperatorSnapshot();
      case 'pushcritical':
        return _telegramAdminPushCriticalCommand();
      case 'setpoll':
        return _telegramAdminSetPollCommand(arguments);
      case 'setreminder':
        return _telegramAdminSetReminderCommand(arguments);
      case 'setoperator':
        return _telegramAdminSetOperatorCommand(arguments);
      case 'target':
        return _telegramAdminTargetSnapshot();
      case 'settarget':
        return _telegramAdminSetTargetCommand(arguments);
      case 'acl':
        return _telegramAdminAclCommand(arguments, update);
      case 'exec':
        return _telegramAdminExecCommand(arguments);
      case 'notifytest':
        return _telegramAdminNotifyTestCommand(arguments);
      case 'watchstart':
        return _telegramAdminWatchStartCommand(arguments);
      case 'watchalert':
        return _telegramAdminWatchAlertCommand(arguments);
      case 'watchrepeat':
        return _telegramAdminWatchRepeatCommand(arguments);
      case 'watchend':
        return _telegramAdminWatchEndCommand(arguments);
      case 'bindchat':
        return _telegramAdminBindChatCommand(arguments, update);
      case 'bindpartner':
        return _telegramAdminBindPartnerCommand(arguments, update);
      case 'bindalarm':
        return _telegramAdminBindAlarmCommand(arguments);
      case 'linkchat':
        return _telegramAdminLinkChatCommand(arguments, update);
      case 'unlinkchat':
        return _telegramAdminUnlinkChatCommand(arguments, update);
      case 'unlinkpartner':
        return _telegramAdminUnlinkPartnerCommand(arguments, update);
      case 'unlinkalarm':
        return _telegramAdminUnlinkAlarmCommand(arguments);
      case 'unlinkall':
        return _telegramAdminUnlinkAllCommand(arguments);
      case 'chatcheck':
        return _telegramAdminChatCheckCommand(arguments, update);
      case 'partnercheck':
        return _telegramAdminPartnerCheckCommand(arguments, update);
      case 'alarmbindings':
        return _telegramAdminAlarmBindingsCommand(arguments);
      case 'alarmtest':
        return _telegramAdminAlarmTestCommand(arguments);
      case 'activitytruth':
        return _telegramAdminActivityTruthCommand(arguments);
      case 'activityreview':
        return _telegramAdminActivityReviewCommand(arguments);
      case 'activitycase':
        return _telegramAdminActivityCaseCommand(arguments);
      case 'readinessreview':
        return _telegramAdminReadinessReviewCommand(arguments);
      case 'readinesscase':
        return _telegramAdminReadinessCaseCommand(arguments);
      case 'sendactivity':
        return _telegramAdminSendActivityCommand(arguments);
      case 'demoprep':
        return _telegramAdminDemoPrepCommand(arguments, update);
      case 'demoflow':
        return _telegramAdminDemoFlowCommand(arguments, update);
      case 'autodemo':
        return _telegramAdminAutoDemoCommand(arguments, update);
      case 'demoscript':
        return _telegramAdminDemoScriptCommand(arguments);
      case 'democlean':
        return _telegramAdminDemoCleanCommand(arguments);
      case 'demolaunch':
        return _telegramAdminDemoLaunchCommand(arguments, update);
      case 'demoplay':
        return _telegramAdminDemoPlayCommand(arguments);
      case 'demoplaystop':
        return _telegramAdminDemoPlayStopCommand();
      case 'demoplaystatus':
        return _telegramAdminDemoPlayStatusCommand();
      case 'targets':
        return _telegramAdminTargetsCommand(arguments);
      case 'demostart':
        return _telegramAdminDemoStartCommand(arguments, full: false);
      case 'demofull':
        return _telegramAdminDemoStartCommand(arguments, full: true);
      case 'demostop':
        return _telegramAdminDemoStopCommand();
      case 'demostatus':
        return _telegramAdminDemoStatusCommand();
      case 'snoozecritical':
        return _telegramAdminSnoozeCriticalCommand(arguments);
      case 'unsnoozecritical':
        return _telegramAdminUnsnoozeCriticalCommand();
      case 'ackcritical':
        return _telegramAdminAckCriticalCommand();
      case 'unackcritical':
        return _telegramAdminUnackCriticalCommand();
      case 'guards':
        return _telegramAdminGuardSnapshot();
      case 'bridges':
        return _telegramAdminBridgeSnapshot();
      case 'brief':
        return _telegramAdminBriefSnapshot();
      case 'next':
        return _telegramAdminNextActionsSnapshot();
      case 'aiassist':
        return _telegramAdminAiAssistCommand(arguments);
      case 'aiapproval':
        return _telegramAdminAiApprovalCommand(arguments);
      case 'aidrafts':
        return _telegramAdminAiDraftsCommand();
      case 'aiapprove':
        return _telegramAdminAiApproveCommand(arguments);
      case 'aireject':
        return _telegramAdminAiRejectCommand(arguments);
      case 'aiconv':
        return _telegramAdminAiConversationCommand(arguments);
      case 'ask':
        return _telegramAdminAskCommand(arguments);
      case 'ping':
        return 'ONYX admin bridge alive • ${DateTime.now().toUtc().toIso8601String()}';
      case 'whoami':
        return _telegramAdminWhoAmISnapshot(update);
      case 'help':
      default:
        return _telegramAdminHelpText();
    }
  }

  String _telegramAdminStatusCommand(String arguments) {
    final mode = arguments.trim().toLowerCase();
    if (mode.isEmpty ||
        mode == 'short' ||
        mode == 'compact' ||
        mode == 'exec') {
      return _telegramAdminStatusExecutiveSnapshot();
    }
    if (_telegramAdminStatusArgumentsSelectFull(mode)) {
      return _telegramAdminStatusSnapshot();
    }
    return 'ONYX STATUS\n'
        'Usage: /status [full]\n'
        'Default: executive snapshot\n'
        'Use /status full for detailed diagnostics.\n'
        'UTC: ${DateTime.now().toUtc().toIso8601String()}';
  }

  bool _telegramAdminStatusArgumentsSelectFull(String arguments) {
    final mode = arguments.trim().toLowerCase();
    return mode == 'full' ||
        mode == 'detail' ||
        mode == 'detailed' ||
        mode == 'verbose' ||
        mode == 'long';
  }

  String _telegramAdminHelpText() {
    return '🧭 <b>ONYX COMMANDS</b>\n\n'
        '<b>Core</b>\n'
        '• <code>/brief</code> - executive one-screen posture\n'
        '• <code>/status</code> - live executive card\n'
        '• <code>/status full</code> - full diagnostics\n'
        '• <code>/critical [short]</code> - active critical risks\n'
        '• <code>/next</code> - next 5-minute action ladder\n'
        '• <code>/incidents</code> | <code>/incident &lt;dispatch_id&gt;</code>\n'
        '\n---\n\n'
        '<b>Operations</b>\n'
        '• <code>/syncguards</code> - force guard sync + queue health\n'
        '• <code>/pollops</code> - poll radio/video/wearable/news now\n'
        '• <code>/guards</code> - guard telemetry and failures\n'
        '• <code>/bridges</code> - Telegram + integration bridge health\n'
        '• <code>/ops</code> - compact operations snapshot\n'
        '\n---\n\n'
        '<b>Critical Control</b>\n'
        '• <code>/ackcritical</code> | <code>/unackcritical</code>\n'
        '• <code>/snoozecritical [minutes]</code> | <code>/unsnoozecritical</code>\n'
        '• <code>/pushcritical</code> - force critical digest now\n'
        '\n---\n\n'
        '<b>AI + Messaging</b>\n'
        '• <code>/ask &lt;question&gt;</code> - contextual operational answer\n'
        '• <code>/aiassist [on|off|status|default]</code>\n'
        '• <code>/aiapproval [on|off|status|default]</code>\n'
        '• <code>/aidrafts</code> | <code>/aiapprove &lt;id&gt;</code> | <code>/aireject &lt;id&gt;</code>\n'
        '• <code>/aiconv [client_id site_id]</code>\n'
        '• <code>/watchstart [client_id site_id]</code>\n'
        '• <code>/watchalert [client_id site_id] [camera_label]</code>\n'
        '• <code>/watchrepeat [client_id site_id] [camera_label]</code>\n'
        '• <code>/watchend [client_id site_id]</code>\n'
        '• <code>/bindpartner &lt;client_id&gt; &lt;site_id&gt; [label]</code>\n'
        '• <code>/unlinkpartner [client_id site_id]</code> | <code>/partnercheck [client_id site_id]</code>\n'
        '• <code>/bindalarm &lt;account&gt; &lt;client_id&gt; &lt;site_id&gt; [partition] [zone] [zone label]</code>\n'
        '• <code>/unlinkalarm &lt;account&gt; [partition] [zone]</code> | <code>/alarmbindings [account]</code>\n'
        '• <code>/alarmtest &lt;clear|suspicious|pending|unavailable&gt; &lt;listener line&gt;</code>\n'
        '• <code>/activitytruth [client_id site_id]</code>\n'
        '• <code>/activityreview [client_id site_id] [report_date]</code>\n'
        '• <code>/activitycase [json|csv] [client_id site_id] [report_date]</code>\n'
        '• <code>/readinessreview [report_date]</code>\n'
        '• <code>/readinesscase [json|csv] [report_date]</code>\n'
        '• <code>/sendactivity [client|partner|both] [client_id site_id]</code>\n'
        '\n---\n\n'
        '<b>Admin</b>\n'
        '• <code>/exec [on|off|status|default]</code>\n'
        '• <code>/operator</code> | <code>/setoperator [&lt;operator_id&gt;|default]</code>\n'
        '• <code>/setpoll [seconds|default]</code>\n'
        '• <code>/setreminder [seconds|default]</code>\n'
        '• <code>/target</code> | <code>/settarget [client_id site_id|default]</code>\n'
        '• <code>/acl [status|list|me|add &lt;id&gt;|remove &lt;id&gt;|open|default]</code>\n'
        '• <code>/history</code> | <code>/adminconfig</code> | <code>/whoami</code> | <code>/ping</code>\n'
        '\n---\n\n'
        '<b>Natural prompts (no /)</b>\n'
        'status, brief, critical risks, what next, who am I, help, plus question-form prompts.\n'
        '\n---\n\n'
        '<b>Critical Push:</b> ${_telegramAdminCriticalPushEnabled ? 'ON' : 'OFF'} (${_normalizedTelegramAdminCriticalReminderSeconds}s reminder)\n'
        'UTC: ${_telegramUtcStamp()}';
  }

  String _telegramAdminBriefSnapshot() {
    final events = store.allEvents();
    final activeIncidents = _activeIncidentCount(events);
    final pendingActions = _pendingAiActionCount(events);
    final guardsOnline = _guardsOnlineCount(events);
    final critical = _telegramAdminCriticalAlerts();
    final criticalCount = critical.length;
    final topAlert = criticalCount > 0 ? _singleLine(critical.first) : 'none';
    final hasWarningSignal =
        _telegramBridgeHealthLabel.toLowerCase() == 'degraded' ||
        _telegramBridgeHealthLabel.toLowerCase() == 'blocked' ||
        _clientAppPushSyncStatusLabel.trim().toLowerCase() == 'failed' ||
        pendingActions > 0;
    final posture = criticalCount > 0
        ? 'RED'
        : (hasWarningSignal ? 'AMBER' : 'GREEN');
    final postureEmoji = switch (posture) {
      'RED' => '🔴',
      'AMBER' => '🟠',
      _ => '🟢',
    };
    final queueThreshold = _positiveThreshold(
      _guardQueuePressureAlertThresholdEnv,
      fallback: 25,
    );
    final slaCue = _telegramAdminSlaCue(
      criticalCount: criticalCount,
      pendingActions: pendingActions,
      queueThreshold: queueThreshold,
    );
    final actionHint = _telegramAdminPrimaryActionHint(
      criticalCount: criticalCount,
      pendingActions: pendingActions,
      queueThreshold: queueThreshold,
    );
    final nextAction = criticalCount > 0
        ? '/critical | /ackcritical | /snoozecritical 30'
        : '/ops | /incidents | /ask <question>';
    return '🚦 <b>ONYX BRIEF</b>\n\n'
        '<b>Posture:</b> $postureEmoji <b>${_telegramHtmlEscape(posture)}</b>\n'
        '<b>Active Critical Alerts:</b> <b>$criticalCount</b>\n\n'
        '---\n\n'
        '<b>Top Risk</b>\n'
        '${_telegramHtmlEscape(topAlert)}\n\n'
        '---\n\n'
        '<b>Operations Status</b>\n\n'
        '• <b>Guards Online:</b> $guardsOnline\n'
        '• <b>Incidents:</b> $activeIncidents\n'
        '• <b>Pending Replies:</b> $pendingActions\n'
        '• <b>SLA cue:</b> ${_telegramHtmlEscape(slaCue)}\n\n'
        '---\n\n'
        '<b>Recommended Action</b>\n'
        '${_telegramHtmlEscape(actionHint)}\n\n'
        '---\n\n'
        '<b>Target</b>\n\n'
        '<b>Client:</b> ${_telegramHtmlEscape(_telegramAdminTargetClientId)}\n'
        '<b>Site:</b> ${_telegramHtmlEscape(_telegramAdminTargetSiteId)}\n'
        '<b>Next:</b> ${_telegramHtmlEscape(nextAction)}\n'
        '<b>Tip:</b> /status full for diagnostics\n\n'
        'UTC: ${_telegramUtcStamp()}';
  }

  String _telegramAdminSlaCue({
    required int criticalCount,
    required int pendingActions,
    required int queueThreshold,
  }) {
    if (criticalCount > 0) {
      return 'at-risk (active critical alerts)';
    }
    if (_guardSyncQueueDepth >= queueThreshold) {
      return 'at-risk (guard sync queue pressure)';
    }
    if (_guardOpsFailedEvents > 0 || _guardOpsFailedMedia > 0) {
      return 'watch (guard ops failures present)';
    }
    if (pendingActions >= 5) {
      return 'watch (response backlog building)';
    }
    return 'on-track';
  }

  String _telegramAdminStatusExecutiveSnapshot() {
    final events = store.allEvents();
    final activeIncidents = _activeIncidentCount(events);
    final pendingActions = _pendingAiActionCount(events);
    final guardsOnline = _guardsOnlineCount(events);
    final queueThreshold = _positiveThreshold(
      _guardQueuePressureAlertThresholdEnv,
      fallback: 25,
    );
    final bridgeLabel = _telegramBridgeHealthLabel.toUpperCase();
    final critical = _telegramAdminCriticalAlerts();
    final criticalCount = critical.length;
    final topAlert = criticalCount > 0 ? _singleLine(critical.first) : 'none';
    final telemetryGate = _guardTelemetryLiveReadyGateViolated
        ? 'VIOLATION'
        : 'OK';
    final hasWarningSignal =
        _telegramBridgeHealthLabel.toLowerCase() == 'degraded' ||
        _telegramBridgeHealthLabel.toLowerCase() == 'blocked' ||
        _clientAppPushSyncStatusLabel.trim().toLowerCase() == 'failed' ||
        pendingActions > 0;
    final posture = criticalCount > 0
        ? 'RED'
        : (hasWarningSignal ? 'AMBER' : 'GREEN');
    final nextAction = criticalCount > 0
        ? '/critical | /ackcritical | /snoozecritical 30'
        : '/ops | /incidents | /ask <question>';
    final actionHint = _telegramAdminPrimaryActionHint(
      criticalCount: criticalCount,
      pendingActions: pendingActions,
      queueThreshold: queueThreshold,
    );
    final postureEmoji = switch (posture) {
      'RED' => '🔴',
      'AMBER' => '🟠',
      _ => '🟢',
    };
    return '📊 <b>ONYX STATUS</b>\n\n'
        '<b>Posture:</b> $postureEmoji <b>${_telegramHtmlEscape(posture)}</b>\n'
        '<b>Active Critical Alerts:</b> <b>$criticalCount</b>\n\n'
        '---\n\n'
        '<b>Top Risk</b>\n'
        '${_telegramHtmlEscape(topAlert)}\n\n'
        '---\n\n'
        '<b>Operations Status</b>\n\n'
        '• <b>Guards Online:</b> $guardsOnline\n'
        '• <b>Incidents:</b> $activeIncidents\n'
        '• <b>Pending Replies:</b> $pendingActions\n'
        '• <b>Guard Queue:</b> $_guardSyncQueueDepth/$queueThreshold\n'
        '• <b>Telemetry:</b> ${_telegramHtmlEscape(_guardTelemetryReadiness.name)} | gate=$telemetryGate\n'
        '• <b>Bridge:</b> telegram=${_telegramHtmlEscape(bridgeLabel)}\n\n'
        '---\n\n'
        '<b>Recommended Action</b>\n'
        '${_telegramHtmlEscape(actionHint)}\n\n'
        '---\n\n'
        '<b>Target</b>\n\n'
        '<b>Client:</b> ${_telegramHtmlEscape(_telegramAdminTargetClientId)}\n'
        '<b>Site:</b> ${_telegramHtmlEscape(_telegramAdminTargetSiteId)}\n'
        '<b>Next:</b> ${_telegramHtmlEscape(nextAction)}\n'
        '<b>Tip:</b> /status full for detailed diagnostics\n\n'
        'UTC: ${_telegramUtcStamp()}';
  }

  String _telegramAdminPrimaryActionHint({
    required int criticalCount,
    required int pendingActions,
    required int queueThreshold,
  }) {
    final bridgeState = _telegramBridgeHealthLabel.toLowerCase();
    if (criticalCount > 0) {
      if (_guardTelemetryLiveReadyGateViolated) {
        return 'run /syncguards and verify telemetry adapter readiness';
      }
      if (bridgeState == 'blocked' || bridgeState == 'degraded') {
        return 'run /bridges then /pollops to restore bridge health';
      }
      return 'open /critical and execute the top listed action';
    }
    if (_guardSyncQueueDepth >= queueThreshold) {
      return 'run /syncguards to reduce queue pressure';
    }
    if (pendingActions > 0) {
      return 'review pending replies in AI Queue and close backlog';
    }
    if (_guardOpsFailedEvents > 0 || _guardOpsFailedMedia > 0) {
      return 'check /guards and clear failed guard ops';
    }
    return 'no immediate risk; monitor with brief updates';
  }

  String _telegramAdminNextActionsSnapshot() {
    final critical = _telegramAdminCriticalAlerts();
    final criticalCount = critical.length;
    final events = store.allEvents();
    final pendingActions = _pendingAiActionCount(events);
    final activeIncidents = _activeIncidentCount(events);
    final queueThreshold = _positiveThreshold(
      _guardQueuePressureAlertThresholdEnv,
      fallback: 25,
    );
    final actions = <String>[];
    if (criticalCount > 0) {
      actions.add('Run /critical and execute the first listed action now.');
    }
    if (_guardTelemetryLiveReadyGateViolated) {
      actions.add(
        'Run /syncguards and verify guard telemetry adapter readiness.',
      );
    }
    final bridgeState = _telegramBridgeHealthLabel.toLowerCase();
    if (bridgeState == 'blocked' || bridgeState == 'degraded') {
      actions.add('Run /bridges then /pollops to verify integration health.');
    }
    if (_guardSyncQueueDepth >= queueThreshold) {
      actions.add(
        'Clear queue pressure with /syncguards (queue=$_guardSyncQueueDepth/$queueThreshold).',
      );
    }
    if (pendingActions > 0) {
      actions.add(
        'Review pending replies in AI Queue (pending=$pendingActions).',
      );
    }
    if (activeIncidents > 0) {
      actions.add('Review /incidents and confirm ownership + ETA updates.');
    }
    if (actions.isEmpty) {
      actions.add(
        'No immediate intervention required; keep monitoring with /brief.',
      );
      actions.add('Run /ops in 5 minutes to confirm posture remains stable.');
    }
    final topAlert = criticalCount > 0 ? _singleLine(critical.first) : 'none';
    final actionLines = <String>[
      for (var index = 0; index < actions.length; index += 1)
        '${index + 1}. ${actions[index]}',
    ].join('\n');
    final posture = criticalCount > 0 ? 'RED' : 'GREEN/AMBER';
    final postureEmoji = criticalCount > 0 ? '🔴' : '🟢';
    return '🧭 <b>ONYX NEXT 5 MIN</b>\n\n'
        '<b>Posture:</b> $postureEmoji <b>${_telegramHtmlEscape(posture)}</b>\n'
        '<b>Active Critical Alerts:</b> <b>$criticalCount</b>\n\n'
        '---\n\n'
        '<b>Top Risk</b>\n'
        '${_telegramHtmlEscape(topAlert)}\n\n'
        '---\n\n'
        '<b>Recommended Actions</b>\n'
        '${_telegramHtmlEscape(actionLines)}\n\n'
        '---\n\n'
        '<b>Target</b>\n\n'
        '<b>Client:</b> ${_telegramHtmlEscape(_telegramAdminTargetClientId)}\n'
        '<b>Site:</b> ${_telegramHtmlEscape(_telegramAdminTargetSiteId)}\n\n'
        'UTC: ${_telegramUtcStamp()}';
  }

  String _telegramAdminStatusSnapshot() {
    final events = store.allEvents();
    final activeIncidents = _activeIncidentCount(events);
    final pendingActions = _pendingAiActionCount(events);
    final guardsOnline = _guardsOnlineCount(events);
    final complianceIssues = _complianceIssuesCount();
    final queueThreshold = _positiveThreshold(
      _guardQueuePressureAlertThresholdEnv,
      fallback: 25,
    );
    final failedThreshold = _positiveThreshold(
      _guardFailureAlertThresholdEnv,
      fallback: 1,
    );
    final lastCommandLabel = _telegramAdminLastCommandSummary == null
        ? 'none'
        : '$_telegramAdminLastCommandSummary @ ${_telegramAdminLastCommandAtUtc?.toIso8601String() ?? 'n/a'}';
    final lastCriticalPushLabel = _telegramAdminLastCriticalAlertAtUtc == null
        ? 'none'
        : '${_telegramAdminLastCriticalAlertSummary ?? 'sent'} @ ${_telegramAdminLastCriticalAlertAtUtc!.toIso8601String()}';
    final criticalAckLabel = _telegramAdminCriticalAckAtUtc == null
        ? 'OFF'
        : 'ACKED @ ${_telegramAdminCriticalAckAtUtc!.toIso8601String()}';
    final criticalSnoozeLabel = _telegramAdminCriticalSnoozedUntilUtc == null
        ? 'OFF'
        : 'UNTIL ${_telegramAdminCriticalSnoozedUntilUtc!.toIso8601String()}';
    final offsetLabel = _telegramAdminOffsetBootstrapped
        ? (_telegramAdminOffsetBootstrappedAtUtc?.toIso8601String() ?? 'yes')
        : 'pending';
    final allowList = _telegramAdminAllowedUserIds;
    final aclSource = _telegramAdminAllowedUserIdsOverride == null
        ? 'env'
        : (_telegramAdminAllowedUserIdsOverride!.isEmpty
              ? 'override-open'
              : 'override');
    final allowListLabel = allowList.isEmpty
        ? 'chat scoped (no explicit user ACL)'
        : 'locked (${allowList.length} user id${allowList.length == 1 ? '' : 's'})';
    final executionSource = _telegramAdminExecutionEnabledOverride == null
        ? 'env'
        : 'override';
    final pollSource = _telegramAdminPollIntervalSecondsOverride == null
        ? 'env'
        : 'override';
    final reminderSource = _telegramAdminCriticalReminderSecondsOverride == null
        ? 'env'
        : 'override';
    final aiAssistSource = _telegramAiAssistantEnabledOverride == null
        ? 'env'
        : 'override';
    final aiApprovalSource = _telegramAiApprovalRequiredOverride == null
        ? 'env'
        : 'override';
    final demoPlayLabel = _telegramDemoScriptRunning
        ? 'running $_telegramDemoScriptStep/$_telegramDemoScriptTotal @ $_telegramDemoScriptScopeLabel'
        : 'idle';
    final lastAiLabel = _telegramAiLastHandledAtUtc == null
        ? 'none'
        : '${_telegramAiLastHandledSummary ?? 'handled'} @ ${_telegramAiLastHandledAtUtc!.toIso8601String()}';
    final critical = _telegramAdminCriticalAlerts();
    final criticalCount = critical.length;
    final criticalSummary = criticalCount <= 0
        ? 'none'
        : critical.take(2).join(' | ');
    return '🧾 <b>ONYX STATUS (FULL)</b>\n\n'
        '<b>CORE</b>\n'
        '• <b>Incidents:</b> active=$activeIncidents | pending replies=$pendingActions\n'
        '• <b>Guards:</b> online=$guardsOnline | queue=$_guardSyncQueueDepth/$queueThreshold | failed_ops=$_guardOpsFailedEvents/$failedThreshold\n'
        '• <b>Push:</b> ${_telegramHtmlEscape(_clientAppPushSyncStatusLabel.toUpperCase())} | queue=${_clientAppPushQueue.length}\n'
        '• <b>Telemetry:</b> ${_telegramHtmlEscape(_guardTelemetryReadiness.name)} | gate=${_guardTelemetryLiveReadyGateViolated ? 'VIOLATION' : 'OK'}\n'
        '\n---\n\n'
        '<b>BRIDGE</b>\n'
        '• <b>Telegram:</b> ${_telegramHtmlEscape(_telegramBridgeHealthLabel.toUpperCase())} | fallback=${_telegramBridgeFallbackToInApp ? 'ON' : 'OFF'}\n'
        '\n---\n\n'
        '<b>AI</b>\n'
        '• <b>Inbound:</b> ${_telegramAiAssistantEnabled ? 'ON' : 'OFF'} (${_telegramHtmlEscape(aiAssistSource)})\n'
        '• <b>Approval:</b> ${_telegramAiApprovalRequired ? 'ON' : 'OFF'} (${_telegramHtmlEscape(aiApprovalSource)}) | drafts=${_telegramAiPendingDrafts.length}\n'
        '• <b>Last AI:</b> ${_telegramHtmlEscape(lastAiLabel)}\n'
        '\n---\n\n'
        '<b>ADMIN</b>\n'
        '• <b>ACL:</b> ${_telegramHtmlEscape(allowListLabel)} (${_telegramHtmlEscape(aclSource)})\n'
        '• <b>Target:</b> ${_telegramHtmlEscape(_telegramAdminTargetClientId)}/${_telegramHtmlEscape(_telegramAdminTargetSiteId)}\n'
        '• <b>Execution:</b> ${_telegramAdminExecutionEnabled ? 'ON' : 'OFF'} (${_telegramHtmlEscape(executionSource)})\n'
        '• <b>Poll:</b> ${_normalizedTelegramAdminPollIntervalSeconds}s(${_telegramHtmlEscape(pollSource)}) | Reminder: ${_normalizedTelegramAdminCriticalReminderSeconds}s(${_telegramHtmlEscape(reminderSource)})\n'
        '• <b>Bootstrap:</b> ${_telegramHtmlEscape(offsetLabel)}\n'
        '\n---\n\n'
        '<b>CRITICAL</b>\n'
        '• <b>Active alerts:</b> $criticalCount\n'
        '• <b>Summary:</b> ${_telegramHtmlEscape(criticalSummary)}\n'
        '• <b>Snooze:</b> ${_telegramHtmlEscape(criticalSnoozeLabel)}\n'
        '• <b>Ack:</b> ${_telegramHtmlEscape(criticalAckLabel)}\n'
        '• <b>Push:</b> ${_telegramAdminCriticalPushEnabled ? 'ON' : 'OFF'} | last=${_telegramHtmlEscape(lastCriticalPushLabel)}\n'
        '\n---\n\n'
        '<b>AUDIT</b>\n'
        '• <b>Compliance issues:</b> $complianceIssues\n'
        '• <b>Demo play:</b> ${_telegramHtmlEscape(demoPlayLabel)}\n'
        '• <b>Last command:</b> ${_telegramHtmlEscape(lastCommandLabel)}\n'
        'UTC: ${_telegramUtcStamp()}';
  }

  String _telegramAdminOpsSnapshot() {
    final events = store.allEvents();
    final activeIncidents = _activeIncidentCount(events);
    final pendingActions = _pendingAiActionCount(events);
    final guardsOnline = _guardsOnlineCount(events);
    final criticalCount = _telegramAdminCriticalAlerts().length;
    final bridgeLabel = _telegramBridgeHealthLabel.toUpperCase();
    final queueThreshold = _positiveThreshold(
      _guardQueuePressureAlertThresholdEnv,
      fallback: 25,
    );
    final actionHint = _telegramAdminPrimaryActionHint(
      criticalCount: criticalCount,
      pendingActions: pendingActions,
      queueThreshold: queueThreshold,
    );
    final posture = criticalCount > 0
        ? 'RED'
        : (pendingActions > 0 ? 'AMBER' : 'GREEN');
    final postureEmoji = switch (posture) {
      'RED' => '🔴',
      'AMBER' => '🟠',
      _ => '🟢',
    };
    return '⚙️ <b>ONYX OPS</b>\n\n'
        '<b>Posture:</b> $postureEmoji <b>${_telegramHtmlEscape(posture)}</b>\n'
        '<b>Critical:</b> $criticalCount\n\n'
        '---\n\n'
        '<b>Operations Status</b>\n'
        '• <b>Incidents:</b> $activeIncidents\n'
        '• <b>Pending AI:</b> $pendingActions\n'
        '• <b>Guards Online:</b> $guardsOnline\n'
        '• <b>Guard Queue:</b> $_guardSyncQueueDepth/$queueThreshold\n'
        '• <b>Telegram Bridge:</b> ${_telegramHtmlEscape(bridgeLabel)}\n'
        '• <b>Push:</b> ${_telegramHtmlEscape(_clientAppPushSyncStatusLabel.toUpperCase())}\n'
        '• <b>Telemetry:</b> ${_telegramHtmlEscape(_guardTelemetryReadiness.name)}\n'
        '\n---\n\n'
        '<b>Recommended Action</b>\n'
        '${_telegramHtmlEscape(actionHint)}\n\n'
        'UTC: ${_telegramUtcStamp()}';
  }

  Future<String> _telegramAdminSyncGuardsCommand() async {
    if (_guardOpsSyncInFlight) {
      return '👮 <b>ONYX SYNCGUARDS</b>\n\n'
          '<b>Status:</b> sync already in progress.\n'
          'UTC: ${_telegramUtcStamp()}';
    }
    await _syncGuardOpsNow(background: true);
    final queueThreshold = _positiveThreshold(
      _guardQueuePressureAlertThresholdEnv,
      fallback: 25,
    );
    final result = (_guardOpsLastSyncLabel ?? 'completed').trim();
    final failureFlag = _guardOpsFailedEvents > 0 || _guardOpsFailedMedia > 0;
    return '👮 <b>ONYX SYNCGUARDS</b>\n\n'
        '<b>Result:</b> ${_telegramHtmlEscape(result)}\n\n'
        '---\n\n'
        '<b>Queue</b>\n'
        '• <b>Depth:</b> $_guardSyncQueueDepth/$queueThreshold\n'
        '• <b>Pending:</b> events=$_guardOpsPendingEvents | media=$_guardOpsPendingMedia\n'
        '• <b>Failed:</b> events=$_guardOpsFailedEvents | media=$_guardOpsFailedMedia\n'
        '\n---\n\n'
        '<b>Telemetry</b>\n'
        '• <b>State:</b> ${_telegramHtmlEscape(_guardTelemetryReadiness.name)}\n'
        '• <b>Gate:</b> ${_guardTelemetryLiveReadyGateViolated ? 'VIOLATION' : 'OK'}\n'
        '${failureFlag ? '• <b>Action:</b> verify adapter health, then retry <code>/syncguards</code>\n' : ''}'
        '\nUTC: ${_telegramUtcStamp()}';
  }

  Future<String> _telegramAdminPollOpsCommand() async {
    await _pollOpsIntegrationOnce();
    return TelegramAdminCommandFormatter.pollOps(
      pollResult: _telegramHtmlEscape(
        (_lastIntakeStatus ?? 'no status').trim(),
      ),
      radioHealth: _telegramHtmlEscape(_opsHealthSummary(_radioOpsHealth)),
      cctvHealth: _telegramHtmlEscape(_opsHealthSummary(_cctvOpsHealth)),
      cctvContext: _telegramHtmlEscape(
        _cctvPilotContextSummary(store.allEvents()),
      ),
      videoLabel: _activeVideoOpsLabel,
      wearableHealth: _telegramHtmlEscape(
        _opsHealthSummary(_wearableOpsHealth),
      ),
      listenerHealth: _telegramHtmlEscape(
        _opsHealthSummary(_listenerAlarmOpsHealth),
      ),
      newsHealth: _telegramHtmlEscape(_opsHealthSummary(_newsOpsHealth)),
      utcStamp: _telegramUtcStamp(),
    );
  }

  String _telegramAdminHistorySnapshot() {
    final history = _telegramAdminCommandAudit;
    if (history.isEmpty) {
      return 'ONYX ADMIN HISTORY\nNo admin command executions recorded yet.\nUTC: ${DateTime.now().toUtc().toIso8601String()}';
    }
    final rows = history.take(10).join('\n- ');
    return 'ONYX ADMIN HISTORY\n- $rows\nUTC: ${DateTime.now().toUtc().toIso8601String()}';
  }

  Future<String> _telegramAdminPushCriticalCommand() async {
    await _maybeSendTelegramAdminCriticalDigest(
      source: 'manual-command',
      force: true,
    );
    final critical = _telegramAdminCriticalAlerts();
    final summary = critical.isEmpty
        ? 'No active critical alerts.'
        : '${critical.length} active critical alert(s).';
    return 'ONYX PUSHCRITICAL\n$summary\nForced digest dispatch requested.\nUTC: ${DateTime.now().toUtc().toIso8601String()}';
  }

  String _telegramAdminConfigSnapshot() {
    final executionSource = _telegramAdminExecutionEnabledOverride == null
        ? 'env'
        : 'override';
    final pollSource = _telegramAdminPollIntervalSecondsOverride == null
        ? 'env'
        : 'override';
    final reminderSource = _telegramAdminCriticalReminderSecondsOverride == null
        ? 'env'
        : 'override';
    final aiAssistSource = _telegramAiAssistantEnabledOverride == null
        ? 'env'
        : 'override';
    final aiApprovalSource = _telegramAiApprovalRequiredOverride == null
        ? 'env'
        : 'override';
    final allowList = _telegramAdminAllowedUserIds;
    final aclSource = _telegramAdminAllowedUserIdsOverride == null
        ? 'env'
        : (_telegramAdminAllowedUserIdsOverride!.isEmpty
              ? 'override-open'
              : 'override');
    final allowListLabel = allowList.isEmpty ? 'none' : allowList.join(',');
    final targetSource =
        ((_telegramAdminTargetClientIdOverride ?? '').trim().isNotEmpty &&
            (_telegramAdminTargetSiteIdOverride ?? '').trim().isNotEmpty)
        ? 'override'
        : 'default';
    return 'ONYX ADMIN CONFIG\n'
        'execution_mode=${_telegramAdminExecutionEnabled ? 'on' : 'off'} ($executionSource)\n'
        'poll_seconds=$_normalizedTelegramAdminPollIntervalSeconds ($pollSource)\n'
        'critical_reminder_seconds=$_normalizedTelegramAdminCriticalReminderSeconds ($reminderSource)\n'
        'critical_push=${_telegramAdminCriticalPushEnabled ? 'on' : 'off'}\n'
        'ai_assist=${_telegramAiAssistantEnabled ? 'on' : 'off'} ($aiAssistSource)\n'
        'ai_client_approval_required=${_telegramAiApprovalRequired ? 'on' : 'off'} ($aiApprovalSource)\n'
        'ai_pending_drafts=${_telegramAiPendingDrafts.length}\n'
        'operator_id=${service.operator.operatorId}\n'
        'operator_source=${_operatorId.trim() == _defaultOperatorId ? 'default' : 'override'}\n'
        'target_client_id=$_telegramAdminTargetClientId\n'
        'target_site_id=$_telegramAdminTargetSiteId\n'
        'target_source=$targetSource\n'
        'allowed_user_ids_source=$aclSource\n'
        'snoozed_until=${_telegramAdminCriticalSnoozedUntilUtc?.toIso8601String() ?? 'none'}\n'
        'acked_at=${_telegramAdminCriticalAckAtUtc?.toIso8601String() ?? 'none'}\n'
        'allowed_user_ids=$allowListLabel\n'
        'UTC: ${DateTime.now().toUtc().toIso8601String()}';
  }

  String _telegramAdminOperatorSnapshot() {
    final current = service.operator.operatorId.trim();
    final source = current == _defaultOperatorId ? 'default' : 'override';
    return 'ONYX OPERATOR\n'
        'operator_id=$current\n'
        'source=$source\n'
        'allowed_regions=${service.operator.allowedRegions.join(',')}\n'
        'allowed_sites=${service.operator.allowedSites.join(',')}\n'
        'Use /setoperator <operator_id> to change runtime identity or /setoperator default to reset.\n'
        'UTC: ${DateTime.now().toUtc().toIso8601String()}';
  }

  Future<String> _telegramAdminSetOperatorCommand(String arguments) async {
    final raw = arguments.trim();
    if (raw.isEmpty) {
      return 'ONYX SETOPERATOR\n'
          'Usage: /setoperator <operator_id>\n'
          'Use /setoperator default to reset.\n'
          'Current operator: ${service.operator.operatorId}';
    }
    final normalizedLower = raw.toLowerCase();
    final nextOperatorId =
        normalizedLower == 'default' || normalizedLower == 'env'
        ? _defaultOperatorId
        : raw;
    await _setOperatorIdentity(nextOperatorId);
    final source = nextOperatorId == _defaultOperatorId
        ? 'default'
        : 'override';
    return 'ONYX SETOPERATOR\n'
        'Operator set to ${service.operator.operatorId} ($source).\n'
        'New execution and review events will use this identity.';
  }

  String _telegramAdminSetPollCommand(String arguments) {
    final raw = arguments.trim().toLowerCase();
    if (raw.isEmpty) {
      return 'ONYX SETPOLL\nUsage: /setpoll <seconds>\nRange: 3..60, or use /setpoll default';
    }
    if (raw == 'default' || raw == 'env') {
      _telegramAdminPollIntervalSecondsOverride = null;
      return 'ONYX SETPOLL\nReset to env value: ${_normalizedTelegramAdminPollIntervalSeconds}s';
    }
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed < 3 || parsed > 60) {
      return 'ONYX SETPOLL\nInvalid value "$arguments". Range is 3..60 seconds.';
    }
    _telegramAdminPollIntervalSecondsOverride = parsed;
    return 'ONYX SETPOLL\nAdmin poll interval set to ${_normalizedTelegramAdminPollIntervalSeconds}s (override).';
  }

  String _telegramAdminSetReminderCommand(String arguments) {
    final raw = arguments.trim().toLowerCase();
    if (raw.isEmpty) {
      return 'ONYX SETREMINDER\nUsage: /setreminder <seconds>\nRange: 60..3600, or use /setreminder default';
    }
    if (raw == 'default' || raw == 'env') {
      _telegramAdminCriticalReminderSecondsOverride = null;
      return 'ONYX SETREMINDER\nReset to env value: ${_normalizedTelegramAdminCriticalReminderSeconds}s';
    }
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed < 60 || parsed > 3600) {
      return 'ONYX SETREMINDER\nInvalid value "$arguments". Range is 60..3600 seconds.';
    }
    _telegramAdminCriticalReminderSecondsOverride = parsed;
    return 'ONYX SETREMINDER\nCritical reminder interval set to ${_normalizedTelegramAdminCriticalReminderSeconds}s (override).';
  }

  String _telegramAdminAiAssistCommand(String arguments) {
    final raw = arguments.trim().toLowerCase();
    if (raw.isEmpty || raw == 'status') {
      final source = _telegramAiAssistantEnabledOverride == null
          ? 'env'
          : 'override';
      final provider = _telegramAiAssistant.isConfigured
          ? 'openai'
          : 'fallback';
      return 'ONYX AI ASSIST\n'
          'enabled=${_telegramAiAssistantEnabled ? 'on' : 'off'} ($source)\n'
          'provider=$provider\n'
          'model=${_telegramAiModelEnv.trim().isEmpty ? 'unset' : _telegramAiModelEnv.trim()}';
    }
    if (raw == 'default' || raw == 'env') {
      _telegramAiAssistantEnabledOverride = null;
      return 'ONYX AI ASSIST\nReset to env value: ${_telegramAiAssistantEnabled ? 'on' : 'off'}.';
    }
    if (raw == 'on') {
      _telegramAiAssistantEnabledOverride = true;
      return 'ONYX AI ASSIST\nInbound AI assistant enabled (override).';
    }
    if (raw == 'off') {
      _telegramAiAssistantEnabledOverride = false;
      return 'ONYX AI ASSIST\nInbound AI assistant disabled (override).';
    }
    return 'ONYX AI ASSIST\nUsage: /aiassist [on|off|status|default]';
  }

  String _telegramAdminAiApprovalCommand(String arguments) {
    final raw = arguments.trim().toLowerCase();
    if (raw.isEmpty || raw == 'status') {
      final source = _telegramAiApprovalRequiredOverride == null
          ? 'env'
          : 'override';
      return 'ONYX AI APPROVAL\n'
          'required=${_telegramAiApprovalRequired ? 'on' : 'off'} ($source)\n'
          'pending_drafts=${_telegramAiPendingDrafts.length}';
    }
    if (raw == 'default' || raw == 'env') {
      _telegramAiApprovalRequiredOverride = null;
      return 'ONYX AI APPROVAL\nReset to env value: ${_telegramAiApprovalRequired ? 'on' : 'off'}.';
    }
    if (raw == 'on') {
      _telegramAiApprovalRequiredOverride = true;
      return 'ONYX AI APPROVAL\nManual approval enabled for client AI replies.';
    }
    if (raw == 'off') {
      _telegramAiApprovalRequiredOverride = false;
      return 'ONYX AI APPROVAL\nManual approval disabled (client AI auto-send enabled).';
    }
    return 'ONYX AI APPROVAL\nUsage: /aiapproval [on|off|status|default]';
  }

  String _telegramAdminAiDraftsCommand() {
    if (_telegramAiPendingDrafts.isEmpty) {
      return 'ONYX AI DRAFTS\nNo pending drafts.';
    }
    final rows = _telegramAiPendingDrafts
        .take(10)
        .map(
          (draft) =>
              '- ${draft.inboundUpdateId} • ${draft.clientId}/${draft.siteId} • ${draft.chatId}${draft.messageThreadId == null ? '' : '#${draft.messageThreadId}'} • ${draft.createdAtUtc.toIso8601String()}',
        )
        .join('\n');
    return 'ONYX AI DRAFTS (${_telegramAiPendingDrafts.length})\n$rows';
  }

  Future<String> _telegramAdminAiConversationCommand(String arguments) async {
    final raw = arguments.trim();
    final tokens = raw.isEmpty
        ? const <String>[]
        : raw
              .split(RegExp(r'\s+'))
              .where((token) => token.isNotEmpty)
              .toList(growable: false);
    if (tokens.length == 1 || tokens.length > 2) {
      return 'ONYX AI CONV\nUsage: /aiconv [client_id site_id]';
    }
    final clientId = tokens.isEmpty ? _telegramAdminTargetClientId : tokens[0];
    final siteId = tokens.isEmpty ? _telegramAdminTargetSiteId : tokens[1];
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId.trim();
    if (normalizedClientId.isEmpty || normalizedSiteId.isEmpty) {
      return 'ONYX AI CONV\nInvalid scope. Use /settarget <client_id site_id> first.';
    }
    final offScope =
        normalizedClientId != _selectedClient ||
        normalizedSiteId != _selectedSite;
    if (offScope && !widget.supabaseReady) {
      return 'ONYX AI CONV\nSupabase not available for off-scope lookup.';
    }
    final messages = await _readConversationMessagesForScope(
      clientId: normalizedClientId,
      siteId: normalizedSiteId,
      limit: 30,
    );
    if (messages.isEmpty) {
      return 'ONYX AI CONV\nscope=$normalizedClientId/$normalizedSiteId\nNo conversation rows found.';
    }
    final rows = messages
        .take(10)
        .map(
          (entry) =>
              '- ${entry.occurredAt.toIso8601String()} • ${entry.messageSource}/${entry.messageProvider} • ${entry.author}: ${_singleLine(entry.body, maxLength: 120)}',
        )
        .join('\n');
    return 'ONYX AI CONV\n'
        'scope=$normalizedClientId/$normalizedSiteId\n'
        'rows=${messages.length}\n'
        '$rows';
  }

  Future<List<ClientAppMessage>> _readConversationMessagesForScope({
    required String clientId,
    required String siteId,
    int limit = 30,
  }) async {
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId.trim();
    final safeLimit = limit.clamp(1, 100);
    if (normalizedClientId.isEmpty || normalizedSiteId.isEmpty) {
      return const <ClientAppMessage>[];
    }
    if (normalizedClientId == _selectedClient &&
        normalizedSiteId == _selectedSite) {
      final messages = List<ClientAppMessage>.from(_clientAppMessages)
        ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      return messages
          .where((entry) => entry.body.trim().isNotEmpty)
          .take(safeLimit)
          .toList(growable: false);
    }
    if (!widget.supabaseReady) {
      return const <ClientAppMessage>[];
    }
    Future<List<ClientAppMessage>> parseQueryResult(
      Future<dynamic> queryFuture,
    ) async {
      final rowsRaw = await queryFuture;
      final rows = List<Map<String, dynamic>>.from(rowsRaw);
      return rows
          .map(
            (row) => ClientAppMessage(
              author: (row['author'] ?? '').toString().trim(),
              body: (row['body'] ?? '').toString().trim(),
              roomKey: (row['room_key'] ?? '').toString().trim(),
              viewerRole: (row['viewer_role'] ?? '').toString().trim(),
              incidentStatusLabel: (row['incident_status_label'] ?? '')
                  .toString()
                  .trim(),
              messageSource: (row['message_source'] ?? '').toString().trim(),
              messageProvider: (row['message_provider'] ?? '')
                  .toString()
                  .trim(),
              occurredAt:
                  DateTime.tryParse(
                    (row['occurred_at'] ?? '').toString(),
                  )?.toUtc() ??
                  DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
            ),
          )
          .where((entry) => entry.body.isNotEmpty)
          .toList(growable: false);
    }

    try {
      return await parseQueryResult(
        Supabase.instance.client
            .from('client_conversation_messages')
            .select(
              'author, body, room_key, viewer_role, incident_status_label, message_source, message_provider, occurred_at',
            )
            .eq('client_id', normalizedClientId)
            .eq('site_id', normalizedSiteId)
            .order('occurred_at', ascending: false)
            .limit(safeLimit),
      );
    } catch (_) {
      return parseQueryResult(
        Supabase.instance.client
            .from('client_conversation_messages')
            .select(
              'author, body, room_key, viewer_role, incident_status_label, occurred_at',
            )
            .eq('client_id', normalizedClientId)
            .eq('site_id', normalizedSiteId)
            .order('occurred_at', ascending: false)
            .limit(safeLimit),
      );
    }
  }

  String _telegramConversationContextSnippet(
    List<ClientAppMessage> messages, {
    int maxRows = 6,
  }) {
    if (messages.isEmpty) {
      return 'none';
    }
    return messages
        .take(maxRows)
        .map(
          (entry) =>
              '${entry.occurredAt.toIso8601String()} • ${entry.messageSource.isEmpty ? 'unknown' : entry.messageSource}/${entry.messageProvider.isEmpty ? 'unknown' : entry.messageProvider} • ${entry.author}: ${_singleLine(entry.body, maxLength: 110)}',
        )
        .join('\n');
  }

  String _telegramAdminConversationalFallback(String messageText) {
    final normalized = messageText.trim().toLowerCase();
    if (normalized.isEmpty) {
      return 'ONYX ADMIN\nSend a request like "status", "critical risks", or "what should I do next?".';
    }
    if (normalized.contains('critical') ||
        normalized.contains('risk') ||
        normalized.contains('alert')) {
      return _telegramAdminCriticalSnapshot();
    }
    if (normalized.contains('next') ||
        normalized.contains('what now') ||
        normalized.contains('action') ||
        normalized.contains('5 min')) {
      return _telegramAdminNextActionsSnapshot();
    }
    if (normalized.contains('status') ||
        normalized.contains('posture') ||
        normalized.contains('health')) {
      return _telegramAdminStatusExecutiveSnapshot();
    }
    if (normalized.contains('incident')) {
      return _telegramAdminIncidentsSnapshot();
    }
    if (normalized.contains('bridge')) {
      return _telegramAdminBridgeSnapshot();
    }
    if (normalized.contains('guard')) {
      return _telegramAdminGuardSnapshot();
    }
    if (normalized.contains('summary') || normalized.contains('brief')) {
      return _telegramAdminBriefSnapshot();
    }
    return 'ONYX ADMIN\n'
        'I can respond directly without slash commands.\n'
        'Try: "brief", "status full", "critical risks", or "what should I do next?".';
  }

  Future<String> _telegramAdminAskCommand(String arguments) async {
    final question = arguments.trim();
    if (question.isEmpty) {
      return 'ONYX ASK\nUsage: /ask <question>';
    }
    if (!_telegramAiAssistantEnabled) {
      return 'ONYX ASK\nAI assistant is disabled.\nUse /aiassist on to enable.';
    }
    if (!_telegramAiAssistant.isConfigured) {
      return _telegramAdminConversationalFallback(question);
    }
    final critical = _telegramAdminCriticalAlerts();
    final criticalSummary = critical.isEmpty
        ? 'none'
        : critical.take(3).join(' | ');
    final contextMessages = await _readConversationMessagesForScope(
      clientId: _telegramAdminTargetClientId,
      siteId: _telegramAdminTargetSiteId,
      limit: 12,
    );
    final conversationContext = _telegramConversationContextSnippet(
      contextMessages,
      maxRows: 5,
    );
    final groundedPrompt =
        'Admin question: $question\n\n'
        'Operational context snapshot:\n'
        '${_telegramAdminOpsSnapshot()}\n'
        'Target scope: $_telegramAdminTargetClientId/$_telegramAdminTargetSiteId\n'
        'Critical alerts: $criticalSummary\n'
        'Recent target conversation context:\n'
        '$conversationContext';
    final aiDraft = await _telegramAiAssistant.draftReply(
      audience: TelegramAiAudience.admin,
      messageText: groundedPrompt,
      clientId: _telegramAdminTargetClientId,
      siteId: _telegramAdminTargetSiteId,
    );
    _telegramAiLastHandledAtUtc = DateTime.now().toUtc();
    _telegramAiLastHandledSummary = 'admin/ask • ${aiDraft.providerLabel}';
    await _appendTelegramAiLedger(
      clientId: _telegramAdminTargetClientId,
      siteId: _telegramAdminTargetSiteId,
      lane: 'admin',
      action: 'ask_reply',
      inboundText: question,
      outboundText: aiDraft.text,
      providerLabel: aiDraft.providerLabel,
      update: const TelegramBridgeInboundMessage(
        updateId: 0,
        chatId: 'admin-command',
        chatType: 'private',
        text: '/ask',
      ),
    );
    return 'ONYX ASK\n${aiDraft.text}';
  }

  Future<String> _telegramAdminAiApproveCommand(String arguments) async {
    final raw = arguments.trim();
    final updateId = int.tryParse(raw);
    if (updateId == null || updateId <= 0) {
      return 'ONYX AI APPROVE\nUsage: /aiapprove <update_id>';
    }
    final pending = _telegramAiPendingDrafts
        .cast<_TelegramAiPendingDraft?>()
        .firstWhere(
          (entry) => entry?.inboundUpdateId == updateId,
          orElse: () => null,
        );
    if (pending == null) {
      return 'ONYX AI APPROVE\nNo pending draft found for update_id=$updateId.';
    }
    final sent = await _sendTelegramMessageWithChunks(
      messageKeyPrefix: 'tg-ai-approved-$updateId',
      chatId: pending.chatId,
      messageThreadId: pending.messageThreadId,
      responseText: pending.draftText,
      failureContext: 'AI approved send',
    );
    _telegramAiPendingDrafts = _telegramAiPendingDrafts
        .where((entry) => entry.inboundUpdateId != updateId)
        .toList(growable: false);
    _telegramAiLastHandledAtUtc = DateTime.now().toUtc();
    _telegramAiLastHandledSummary =
        '${pending.clientId}/${pending.siteId} • ${sent ? 'approved' : 'approval-send-failed'}';
    await _appendTelegramConversationMessage(
      clientId: pending.clientId,
      siteId: pending.siteId,
      author: 'ONYX AI',
      body: pending.draftText,
      occurredAtUtc: DateTime.now().toUtc(),
      roomKey: sent ? 'Residents' : 'Security Desk',
      viewerRole: sent
          ? ClientAppViewerRole.client.name
          : ClientAppViewerRole.control.name,
      incidentStatusLabel: sent
          ? 'Approved Reply Sent'
          : 'Approval Send Failed',
      messageSource: 'telegram',
      messageProvider: pending.providerLabel,
    );
    await _appendTelegramAiLedger(
      clientId: pending.clientId,
      siteId: pending.siteId,
      lane: pending.audience,
      action: sent ? 'approved_sent' : 'approved_send_failed',
      inboundText: pending.sourceText,
      outboundText: pending.draftText,
      providerLabel: pending.providerLabel,
      update: TelegramBridgeInboundMessage(
        updateId: pending.inboundUpdateId,
        chatId: pending.chatId,
        chatType: 'unknown',
        messageThreadId: pending.messageThreadId,
        text: pending.sourceText,
      ),
    );
    unawaited(_persistTelegramAdminRuntimeState());
    return 'ONYX AI APPROVE\n'
        'update_id=$updateId\n'
        'scope=${pending.clientId}/${pending.siteId}\n'
        'result=${sent ? 'sent' : 'send_failed'}';
  }

  String _telegramAdminAiRejectCommand(String arguments) {
    final raw = arguments.trim();
    final updateId = int.tryParse(raw);
    if (updateId == null || updateId <= 0) {
      return 'ONYX AI REJECT\nUsage: /aireject <update_id>';
    }
    final before = _telegramAiPendingDrafts.length;
    _telegramAiPendingDrafts = _telegramAiPendingDrafts
        .where((entry) => entry.inboundUpdateId != updateId)
        .toList(growable: false);
    if (_telegramAiPendingDrafts.length == before) {
      return 'ONYX AI REJECT\nNo pending draft found for update_id=$updateId.';
    }
    unawaited(_persistTelegramAdminRuntimeState());
    return 'ONYX AI REJECT\nRejected pending draft update_id=$updateId.';
  }

  String _telegramAdminTargetSnapshot() {
    final source =
        ((_telegramAdminTargetClientIdOverride ?? '').trim().isNotEmpty &&
            (_telegramAdminTargetSiteIdOverride ?? '').trim().isNotEmpty)
        ? 'override'
        : 'default';
    return 'ONYX TARGET\n'
        'client_id=$_telegramAdminTargetClientId\n'
        'site_id=$_telegramAdminTargetSiteId\n'
        'source=$source';
  }

  String _telegramAdminSetTargetCommand(String arguments) {
    final raw = arguments.trim();
    if (raw.isEmpty) {
      return 'ONYX SETTARGET\nUsage: /settarget <client_id> <site_id>\nOr: /settarget default';
    }
    final normalized = raw.toLowerCase();
    if (normalized == 'default' || normalized == 'env') {
      _telegramAdminTargetClientIdOverride = null;
      _telegramAdminTargetSiteIdOverride = null;
      return 'ONYX SETTARGET\nReset to default target: $_telegramAdminTargetClientId/$_telegramAdminTargetSiteId';
    }
    final parts = raw
        .split(RegExp(r'\s+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (parts.length != 2) {
      return 'ONYX SETTARGET\nUsage: /settarget <client_id> <site_id>\nOr: /settarget default';
    }
    _telegramAdminTargetClientIdOverride = parts[0];
    _telegramAdminTargetSiteIdOverride = parts[1];
    return 'ONYX SETTARGET\nDefault target set to $_telegramAdminTargetClientId/$_telegramAdminTargetSiteId';
  }

  String _telegramAdminAclCommand(
    String arguments,
    TelegramBridgeInboundMessage update,
  ) {
    final tokens = arguments
        .split(RegExp(r'\s+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    final action = tokens.isEmpty ? 'status' : tokens.first.toLowerCase();
    if (action == 'status' || action == 'list') {
      final allowList = _telegramAdminAllowedUserIds.toList(growable: false)
        ..sort();
      final source = _telegramAdminAllowedUserIdsOverride == null
          ? 'env'
          : (_telegramAdminAllowedUserIdsOverride!.isEmpty
                ? 'override-open'
                : 'override');
      return 'ONYX ACL\n'
          'source=$source\n'
          'mode=${allowList.isEmpty ? 'chat-scoped' : 'locked'}\n'
          'allowed_user_ids=${allowList.isEmpty ? 'none' : allowList.join(',')}\n'
          'hint=/acl me | /acl add <id> | /acl remove <id> | /acl open | /acl default';
    }
    if (action == 'default' || action == 'env') {
      _telegramAdminAllowedUserIdsOverride = null;
      unawaited(_persistTelegramAdminRuntimeState());
      return 'ONYX ACL\nReset to env allow list.';
    }
    if (action == 'open') {
      _telegramAdminAllowedUserIdsOverride = const <int>[];
      unawaited(_persistTelegramAdminRuntimeState());
      return 'ONYX ACL\nSet to open chat-scoped mode (no explicit user IDs).';
    }
    if (action == 'me') {
      final senderId = update.fromUserId;
      if (senderId == null || senderId <= 0) {
        return 'ONYX ACL\nCannot resolve sender user ID. Use /whoami and /acl add <id>.';
      }
      _telegramAdminAllowedUserIdsOverride = <int>[senderId];
      unawaited(_persistTelegramAdminRuntimeState());
      return 'ONYX ACL\nLocked to your user ID: $senderId';
    }
    if (action == 'add' || action == 'remove') {
      if (tokens.length != 2) {
        return 'ONYX ACL\nUsage: /acl $action <user_id>';
      }
      final userId = int.tryParse(tokens[1]);
      if (userId == null || userId <= 0) {
        return 'ONYX ACL\nInvalid user_id "${tokens[1]}".';
      }
      final next = _telegramAdminAllowedUserIds.toSet();
      if (action == 'add') {
        next.add(userId);
      } else {
        next.remove(userId);
      }
      final sorted = next.toList(growable: false)..sort();
      _telegramAdminAllowedUserIdsOverride = sorted;
      unawaited(_persistTelegramAdminRuntimeState());
      return 'ONYX ACL\n'
          '${action == 'add' ? 'Added' : 'Removed'} $userId.\n'
          'allowed_user_ids=${sorted.isEmpty ? 'none' : sorted.join(',')}';
    }
    return 'ONYX ACL\nUsage: /acl [status|list|me|add <id>|remove <id>|open|default]';
  }

  String _telegramAdminExecCommand(String arguments) {
    final raw = arguments.trim().toLowerCase();
    if (raw.isEmpty || raw == 'status') {
      final source = _telegramAdminExecutionEnabledOverride == null
          ? 'env'
          : 'override';
      return 'ONYX EXECUTION MODE\n'
          'state=${_telegramAdminExecutionEnabled ? 'ON' : 'OFF'}\n'
          'source=$source';
    }
    if (raw == 'default' || raw == 'env') {
      _telegramAdminExecutionEnabledOverride = null;
      return 'ONYX EXECUTION MODE\nReset to env state: ${_telegramAdminExecutionEnabled ? 'ON' : 'OFF'}.';
    }
    if (raw == 'on') {
      _telegramAdminExecutionEnabledOverride = true;
      return 'ONYX EXECUTION MODE\nExecution commands enabled (override).';
    }
    if (raw == 'off') {
      _telegramAdminExecutionEnabledOverride = false;
      return 'ONYX EXECUTION MODE\nExecution commands disabled (override).';
    }
    return 'ONYX EXECUTION MODE\nUsage: /exec <on|off|status|default>';
  }

  Future<String> _telegramAdminNotifyTestCommand(String arguments) async {
    final tokens = arguments
        .split(RegExp(r'\s+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    var index = 0;
    var targetChannel = ClientAppAcknowledgementChannel.client;
    if (tokens.isNotEmpty) {
      final maybeChannel = tokens.first.toLowerCase();
      if (maybeChannel == 'client' || maybeChannel == 'control') {
        targetChannel = maybeChannel == 'control'
            ? ClientAppAcknowledgementChannel.control
            : ClientAppAcknowledgementChannel.client;
        index = 1;
      }
    }
    final targetTokens = tokens.sublist(index);
    if (targetTokens.isNotEmpty && targetTokens.length != 2) {
      return 'ONYX NOTIFYTEST\nUsage: /notifytest [client|control] [client_id site_id]';
    }
    final targetClientId = targetTokens.isEmpty
        ? _telegramAdminTargetClientId
        : targetTokens.first;
    final targetSiteId = targetTokens.isEmpty
        ? _telegramAdminTargetSiteId
        : targetTokens[1];
    if (targetClientId.trim().isEmpty || targetSiteId.trim().isEmpty) {
      return 'ONYX NOTIFYTEST\nUsage: /notifytest [client|control] [client_id site_id]';
    }
    final resolvedClientId = targetClientId.trim();
    final resolvedSiteId = targetSiteId.trim();
    final nowUtc = DateTime.now().toUtc();
    final messageKey = 'tg-admin-test-${nowUtc.microsecondsSinceEpoch}';
    final queue = <ClientAppPushDeliveryItem>[
      ClientAppPushDeliveryItem(
        messageKey: messageKey,
        title: 'ONYX Bridge Test',
        body:
            'Admin-triggered client notification path test from Telegram command lane.',
        occurredAt: nowUtc,
        clientId: resolvedClientId,
        siteId: resolvedSiteId,
        targetChannel: targetChannel,
        deliveryProvider: _clientPushDeliveryProvider,
        priority: true,
        status: ClientPushDeliveryStatus.queued,
      ),
      ..._clientAppPushQueue,
    ];
    await _persistClientAppPushQueue(queue, forceTelegramResend: true);
    final syncStatus = _clientAppPushSyncStatusLabel.toUpperCase();
    final failureReason = (_clientAppPushSyncFailureReason ?? '').trim();
    return 'ONYX NOTIFYTEST\n'
        'queued_message_key=$messageKey\n'
        'target_channel=${targetChannel.name}\n'
        'target_context=$resolvedClientId/$resolvedSiteId\n'
        'delivery_provider=${_clientPushDeliveryProvider.code}\n'
        'queue_size=${_clientAppPushQueue.length}\n'
        'sync_status=$syncStatus${failureReason.isEmpty ? '' : ' • $failureReason'}\n'
        'UTC: ${nowUtc.toIso8601String()}';
  }

  Future<String> _telegramAdminBindChatCommand(
    String arguments,
    TelegramBridgeInboundMessage update,
  ) async {
    final tokens = arguments
        .split(RegExp(r'\s+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (tokens.length < 2) {
      return 'ONYX BINDCHAT\nUsage: /bindchat <client_id> <site_id> [label]';
    }
    final clientId = tokens[0].trim();
    final siteId = tokens[1].trim();
    if (clientId.isEmpty || siteId.isEmpty) {
      return 'ONYX BINDCHAT\nUsage: /bindchat <client_id> <site_id> [label]';
    }
    _telegramAdminTargetClientIdOverride = clientId;
    _telegramAdminTargetSiteIdOverride = siteId;
    await _persistTelegramAdminRuntimeState();
    final label = tokens.length > 2 ? tokens.sublist(2).join(' ') : '';
    final linkArgs = label.trim().isEmpty
        ? '$clientId $siteId'
        : '$clientId $siteId $label';
    final linkResult = await _telegramAdminLinkChatCommand(linkArgs, update);
    return 'ONYX BINDCHAT\n'
        'default_target=$clientId/$siteId\n'
        '${linkResult.replaceFirst('ONYX LINKCHAT\n', '')}';
  }

  Future<String> _telegramAdminLinkChatCommand(
    String arguments,
    TelegramBridgeInboundMessage update,
  ) async {
    if (!widget.supabaseReady) {
      return 'ONYX LINKCHAT\nSupabase is required to persist messaging endpoints.';
    }
    final tokens = arguments
        .split(RegExp(r'\s+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    String clientId = _telegramAdminTargetClientId;
    String siteId = _telegramAdminTargetSiteId;
    String customLabel = '';
    if (tokens.length >= 2) {
      clientId = tokens[0].trim();
      siteId = tokens[1].trim();
      customLabel = tokens.length > 2 ? tokens.sublist(2).join(' ').trim() : '';
    } else if (tokens.length == 1) {
      customLabel = tokens.first.trim();
    }
    if (clientId.isEmpty || siteId.isEmpty) {
      return 'ONYX LINKCHAT\nUsage: /linkchat [client_id site_id] [label]';
    }
    final chatTitle = update.chatTitle?.trim() ?? '';
    final endpointLabel = customLabel.isNotEmpty
        ? customLabel
        : (chatTitle.isNotEmpty ? chatTitle : 'Telegram Bridge');
    final contactName = update.fromUsername?.trim().isNotEmpty == true
        ? '@${update.fromUsername!.trim()}'
        : (update.fromUserId == null
              ? 'Telegram Contact'
              : 'Telegram User ${update.fromUserId}');
    try {
      final repository = SupabaseClientMessagingBridgeRepository(
        Supabase.instance.client,
      );
      await repository.upsertOnboardingSetup(
        ClientMessagingOnboardingSetup(
          clientId: clientId,
          siteId: siteId,
          contactName: contactName,
          contactRole: 'sovereign_contact',
          contactConsentConfirmed: false,
          provider: 'telegram',
          endpointLabel: endpointLabel,
          telegramChatId: update.chatId,
          telegramThreadId: update.messageThreadId?.toString(),
        ),
      );
      final targets =
          (await repository.readActiveTelegramTargets(
                clientId: clientId,
                siteId: siteId,
              ))
              .where((target) => !_isPartnerEndpointLabel(target.displayLabel))
              .toList(growable: false);
      return 'ONYX LINKCHAT\n'
          'bound_chat=${update.chatId}${update.messageThreadId == null ? '' : '#${update.messageThreadId}'}\n'
          'scope=$clientId/$siteId\n'
          'label=$endpointLabel\n'
          'active_targets=${targets.length}\n'
          'UTC: ${_telegramUtcStamp()}';
    } catch (error) {
      return 'ONYX LINKCHAT\nFailed to save endpoint: $error';
    }
  }

  Future<String> _telegramAdminBindPartnerCommand(
    String arguments,
    TelegramBridgeInboundMessage update,
  ) async {
    if (!widget.supabaseReady) {
      return 'ONYX BINDPARTNER\nSupabase is required to persist partner endpoints.';
    }
    final tokens = arguments
        .split(RegExp(r'\s+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (tokens.length < 2) {
      return 'ONYX BINDPARTNER\nUsage: /bindpartner <client_id> <site_id> [label]';
    }
    final clientId = tokens[0].trim();
    final siteId = tokens[1].trim();
    if (clientId.isEmpty || siteId.isEmpty) {
      return 'ONYX BINDPARTNER\nUsage: /bindpartner <client_id> <site_id> [label]';
    }
    final customLabel = tokens.length > 2 ? tokens.sublist(2).join(' ') : '';
    final chatTitle = update.chatTitle?.trim() ?? '';
    final endpointLabel = _normalizePartnerEndpointLabel(
      customLabel.isNotEmpty
          ? customLabel
          : (chatTitle.isNotEmpty ? chatTitle : _telegramPartnerLabelEnv),
    );
    final contactName = update.fromUsername?.trim().isNotEmpty == true
        ? '@${update.fromUsername!.trim()}'
        : (update.fromUserId == null
              ? 'Partner Contact'
              : 'Telegram User ${update.fromUserId}');
    try {
      final repository = SupabaseClientMessagingBridgeRepository(
        Supabase.instance.client,
      );
      await repository.upsertOnboardingSetup(
        ClientMessagingOnboardingSetup(
          clientId: clientId,
          siteId: siteId,
          contactName: contactName,
          contactRole: 'response_partner',
          contactConsentConfirmed: false,
          provider: 'telegram',
          endpointLabel: endpointLabel,
          telegramChatId: update.chatId,
          telegramThreadId: update.messageThreadId?.toString(),
        ),
      );
      final targets =
          (await repository.readActiveTelegramTargets(
                clientId: clientId,
                siteId: siteId,
              ))
              .where((target) => _isPartnerEndpointLabel(target.displayLabel))
              .toList(growable: false);
      return 'ONYX BINDPARTNER\n'
          'bound_chat=${update.chatId}${update.messageThreadId == null ? '' : '#${update.messageThreadId}'}\n'
          'scope=$clientId/$siteId\n'
          'label=$endpointLabel\n'
          'active_partner_targets=${targets.length}\n'
          'UTC: ${_telegramUtcStamp()}';
    } catch (error) {
      return 'ONYX BINDPARTNER\nFailed to save endpoint: $error';
    }
  }

  Future<String> _telegramAdminUnlinkChatCommand(
    String arguments,
    TelegramBridgeInboundMessage update,
  ) async {
    if (!widget.supabaseReady) {
      return 'ONYX UNLINKCHAT\nSupabase is required to update messaging endpoints.';
    }
    final tokens = arguments
        .split(RegExp(r'\s+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (tokens.length == 1 || tokens.length > 2) {
      return 'ONYX UNLINKCHAT\nUsage: /unlinkchat [client_id site_id]';
    }
    final clientId = tokens.isEmpty ? _telegramAdminTargetClientId : tokens[0];
    final siteId = tokens.isEmpty ? _telegramAdminTargetSiteId : tokens[1];
    if (clientId.isEmpty || siteId.isEmpty) {
      return 'ONYX UNLINKCHAT\nUsage: /unlinkchat [client_id site_id]';
    }
    try {
      final repository = SupabaseClientMessagingBridgeRepository(
        Supabase.instance.client,
      );
      final targets =
          (await repository.readActiveTelegramTargets(
                clientId: clientId,
                siteId: siteId,
              ))
              .where(
                (target) =>
                    !_isPartnerEndpointLabel(target.displayLabel) &&
                    target.chatId.trim() == update.chatId.trim() &&
                    target.threadId == update.messageThreadId,
              )
              .toList(growable: false);
      var deactivated = 0;
      for (final target in targets) {
        await Supabase.instance.client
            .from('client_messaging_endpoints')
            .update({'is_active': false, 'last_delivery_status': 'disabled'})
            .eq('client_id', clientId)
            .eq('id', target.endpointId);
        deactivated += 1;
      }
      final remaining =
          (await repository.readActiveTelegramTargets(
                clientId: clientId,
                siteId: siteId,
              ))
              .where((target) => !_isPartnerEndpointLabel(target.displayLabel))
              .length;
      return 'ONYX UNLINKCHAT\n'
          'scope=$clientId/$siteId\n'
          'chat=${update.chatId}${update.messageThreadId == null ? '' : '#${update.messageThreadId}'}\n'
          'deactivated=$deactivated\n'
          'remaining_targets=$remaining\n'
          'UTC: ${DateTime.now().toUtc().toIso8601String()}';
    } catch (error) {
      return 'ONYX UNLINKCHAT\nFailed to disable endpoint: $error';
    }
  }

  Future<String> _telegramAdminUnlinkPartnerCommand(
    String arguments,
    TelegramBridgeInboundMessage update,
  ) async {
    if (!widget.supabaseReady) {
      return 'ONYX UNLINKPARTNER\nSupabase is required to update partner endpoints.';
    }
    final tokens = arguments
        .split(RegExp(r'\s+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (tokens.length == 1 || tokens.length > 2) {
      return 'ONYX UNLINKPARTNER\nUsage: /unlinkpartner [client_id site_id]';
    }
    final clientId = tokens.isEmpty ? _telegramAdminTargetClientId : tokens[0];
    final siteId = tokens.isEmpty ? _telegramAdminTargetSiteId : tokens[1];
    if (clientId.isEmpty || siteId.isEmpty) {
      return 'ONYX UNLINKPARTNER\nUsage: /unlinkpartner [client_id site_id]';
    }
    try {
      final repository = SupabaseClientMessagingBridgeRepository(
        Supabase.instance.client,
      );
      final targets =
          (await repository.readActiveTelegramTargets(
                clientId: clientId,
                siteId: siteId,
              ))
              .where(
                (target) =>
                    _isPartnerEndpointLabel(target.displayLabel) &&
                    target.chatId.trim() == update.chatId.trim() &&
                    target.threadId == update.messageThreadId,
              )
              .toList(growable: false);
      var deactivated = 0;
      for (final target in targets) {
        await Supabase.instance.client
            .from('client_messaging_endpoints')
            .update({
              'is_active': false,
              'last_delivery_status': 'partner_unlinked',
            })
            .eq('client_id', clientId)
            .eq('id', target.endpointId);
        deactivated += 1;
      }
      final remaining = (await repository.readActiveTelegramTargets(
        clientId: clientId,
        siteId: siteId,
      )).where((target) => _isPartnerEndpointLabel(target.displayLabel)).length;
      return 'ONYX UNLINKPARTNER\n'
          'scope=$clientId/$siteId\n'
          'chat=${update.chatId}${update.messageThreadId == null ? '' : '#${update.messageThreadId}'}\n'
          'deactivated=$deactivated\n'
          'remaining_partner_targets=$remaining\n'
          'UTC: ${DateTime.now().toUtc().toIso8601String()}';
    } catch (error) {
      return 'ONYX UNLINKPARTNER\nFailed to disable partner endpoint: $error';
    }
  }

  Future<String> _telegramAdminUnlinkAllCommand(String arguments) async {
    if (!widget.supabaseReady) {
      return 'ONYX UNLINKALL\nSupabase is required to update messaging endpoints.';
    }
    final tokens = arguments
        .split(RegExp(r'\s+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (tokens.length == 1 || tokens.length > 2) {
      return 'ONYX UNLINKALL\nUsage: /unlinkall [client_id site_id]';
    }
    final clientId = tokens.isEmpty ? _telegramAdminTargetClientId : tokens[0];
    final siteId = tokens.isEmpty ? _telegramAdminTargetSiteId : tokens[1];
    if (clientId.isEmpty || siteId.isEmpty) {
      return 'ONYX UNLINKALL\nUsage: /unlinkall [client_id site_id]';
    }
    try {
      final repository = SupabaseClientMessagingBridgeRepository(
        Supabase.instance.client,
      );
      final targets =
          (await repository.readActiveTelegramTargets(
                clientId: clientId,
                siteId: siteId,
              ))
              .where((target) => !_isPartnerEndpointLabel(target.displayLabel))
              .toList(growable: false);
      var deactivated = 0;
      for (final target in targets) {
        await Supabase.instance.client
            .from('client_messaging_endpoints')
            .update({'is_active': false, 'last_delivery_status': 'disabled'})
            .eq('client_id', clientId)
            .eq('id', target.endpointId);
        deactivated += 1;
      }
      final remaining =
          (await repository.readActiveTelegramTargets(
                clientId: clientId,
                siteId: siteId,
              ))
              .where((target) => !_isPartnerEndpointLabel(target.displayLabel))
              .length;
      return 'ONYX UNLINKALL\n'
          'scope=$clientId/$siteId\n'
          'deactivated=$deactivated\n'
          'remaining_targets=$remaining\n'
          'UTC: ${DateTime.now().toUtc().toIso8601String()}';
    } catch (error) {
      return 'ONYX UNLINKALL\nFailed to disable endpoints: $error';
    }
  }

  Future<String> _telegramAdminChatCheckCommand(
    String arguments,
    TelegramBridgeInboundMessage update,
  ) async {
    if (!widget.supabaseReady) {
      return 'ONYX CHATCHECK\nSupabase is required to verify messaging endpoints.';
    }
    final tokens = arguments
        .split(RegExp(r'\s+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (tokens.length == 1 || tokens.length > 2) {
      return 'ONYX CHATCHECK\nUsage: /chatcheck [client_id site_id]';
    }
    final clientId = tokens.isEmpty ? _telegramAdminTargetClientId : tokens[0];
    final siteId = tokens.isEmpty ? _telegramAdminTargetSiteId : tokens[1];
    if (clientId.isEmpty || siteId.isEmpty) {
      return 'ONYX CHATCHECK\nUsage: /chatcheck [client_id site_id]';
    }
    try {
      final repository = SupabaseClientMessagingBridgeRepository(
        Supabase.instance.client,
      );
      final targets =
          (await repository.readActiveTelegramTargets(
                clientId: clientId,
                siteId: siteId,
              ))
              .where((target) => !_isPartnerEndpointLabel(target.displayLabel))
              .toList(growable: false);
      final matching = targets
          .where(
            (target) =>
                target.chatId.trim() == update.chatId.trim() &&
                target.threadId == update.messageThreadId,
          )
          .toList(growable: false);
      final linked = matching.isNotEmpty;
      final rows = targets
          .take(6)
          .map((target) {
            final threadLabel = target.threadId == null
                ? 'none'
                : target.threadId.toString();
            final marker =
                target.chatId.trim() == update.chatId.trim() &&
                    target.threadId == update.messageThreadId
                ? ' [current]'
                : '';
            return '- ${target.displayLabel} | chat=${target.chatId} | thread=$threadLabel$marker';
          })
          .join('\n');
      return 'ONYX CHATCHECK\n'
          'scope=$clientId/$siteId\n'
          'current_chat=${update.chatId}${update.messageThreadId == null ? '' : '#${update.messageThreadId}'}\n'
          'linked=${linked ? 'yes' : 'no'}\n'
          'matching_endpoints=${matching.length}\n'
          'active_endpoints=${targets.length}'
          '${rows.isEmpty ? '\n(no active targets configured)' : '\n$rows'}';
    } catch (error) {
      return 'ONYX CHATCHECK\nFailed to verify endpoint: $error';
    }
  }

  Future<String> _telegramAdminPartnerCheckCommand(
    String arguments,
    TelegramBridgeInboundMessage update,
  ) async {
    if (!widget.supabaseReady) {
      return 'ONYX PARTNERCHECK\nSupabase is required to verify partner endpoints.';
    }
    final tokens = arguments
        .split(RegExp(r'\s+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (tokens.length == 1 || tokens.length > 2) {
      return 'ONYX PARTNERCHECK\nUsage: /partnercheck [client_id site_id]';
    }
    final clientId = tokens.isEmpty ? _telegramAdminTargetClientId : tokens[0];
    final siteId = tokens.isEmpty ? _telegramAdminTargetSiteId : tokens[1];
    if (clientId.isEmpty || siteId.isEmpty) {
      return 'ONYX PARTNERCHECK\nUsage: /partnercheck [client_id site_id]';
    }
    try {
      final repository = SupabaseClientMessagingBridgeRepository(
        Supabase.instance.client,
      );
      final targets =
          (await repository.readActiveTelegramTargets(
                clientId: clientId,
                siteId: siteId,
              ))
              .where((target) => _isPartnerEndpointLabel(target.displayLabel))
              .toList(growable: false);
      final matching = targets
          .where(
            (target) =>
                target.chatId.trim() == update.chatId.trim() &&
                target.threadId == update.messageThreadId,
          )
          .toList(growable: false);
      final linked = matching.isNotEmpty;
      final rows = targets
          .take(6)
          .map((target) {
            final threadLabel = target.threadId == null
                ? 'none'
                : target.threadId.toString();
            final marker =
                target.chatId.trim() == update.chatId.trim() &&
                    target.threadId == update.messageThreadId
                ? ' [current]'
                : '';
            return '- ${target.displayLabel} | chat=${target.chatId} | thread=$threadLabel$marker';
          })
          .join('\n');
      return 'ONYX PARTNERCHECK\n'
          'scope=$clientId/$siteId\n'
          'current_chat=${update.chatId}${update.messageThreadId == null ? '' : '#${update.messageThreadId}'}\n'
          'linked=${linked ? 'yes' : 'no'}\n'
          'matching_partner_endpoints=${matching.length}\n'
          'active_partner_endpoints=${targets.length}'
          '${rows.isEmpty ? '\n(no active partner targets configured)' : '\n$rows'}';
    } catch (error) {
      return 'ONYX PARTNERCHECK\nFailed to verify partner endpoint: $error';
    }
  }

  ListenerAlarmAdvisoryDisposition? _listenerAlarmDispositionFromRaw(
    String raw,
  ) {
    switch (raw.trim().toLowerCase()) {
      case 'clear':
        return ListenerAlarmAdvisoryDisposition.clear;
      case 'suspicious':
      case 'threat':
      case 'escalate':
        return ListenerAlarmAdvisoryDisposition.suspicious;
      case 'pending':
      case 'review':
      case 'reviewing':
        return ListenerAlarmAdvisoryDisposition.pending;
      case 'unavailable':
      case 'offline':
      case 'down':
        return ListenerAlarmAdvisoryDisposition.unavailable;
      default:
        return null;
    }
  }

  String _telegramAdminBindAlarmCommand(String arguments) {
    final tokens = arguments
        .split(RegExp(r'\s+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (tokens.length < 3) {
      return 'ONYX BINDALARM\n'
          'Usage: /bindalarm <account> <client_id> <site_id> [partition] [zone] [zone label]';
    }
    final accountNumber = tokens[0].trim();
    final clientId = tokens[1].trim();
    final siteId = tokens[2].trim();
    if (accountNumber.isEmpty ||
        clientId.isEmpty ||
        siteId.isEmpty ||
        !RegExp(r'^\d+$').hasMatch(accountNumber)) {
      return 'ONYX BINDALARM\n'
          'Invalid binding. account must be numeric and scope values must be present.';
    }
    final partition = tokens.length > 3 && tokens[3] != '-'
        ? tokens[3].trim()
        : '';
    final zone = tokens.length > 4 && tokens[4] != '-' ? tokens[4].trim() : '';
    if (partition.isNotEmpty && !RegExp(r'^\d+$').hasMatch(partition)) {
      return 'ONYX BINDALARM\nPartition must be numeric or "-".';
    }
    if (zone.isNotEmpty && !RegExp(r'^\d+$').hasMatch(zone)) {
      return 'ONYX BINDALARM\nZone must be numeric or "-".';
    }
    final zoneLabel = tokens.length > 5 ? tokens.sublist(5).join(' ') : '';
    final siteProfile = _monitoringSiteProfileFor(
      clientId: clientId,
      siteId: siteId,
    );
    final entry = ListenerAlarmScopeMappingEntry(
      accountNumber: accountNumber,
      partition: partition,
      zone: zone,
      zoneLabel: zoneLabel,
      siteId: siteId,
      siteName: siteProfile.siteName.trim().isEmpty
          ? _humanizeScopeLabel(siteId)
          : siteProfile.siteName.trim(),
      clientId: clientId,
      clientName: siteProfile.clientName.trim().isEmpty
          ? _humanizeScopeLabel(clientId)
          : siteProfile.clientName.trim(),
      regionId: _selectedRegion,
    );
    _listenerAlarmScopeRegistry.upsert(entry);
    unawaited(_persistTelegramAdminRuntimeState());
    final scopeSuffix = [
      if (partition.isNotEmpty) 'partition=$partition',
      if (zone.isNotEmpty) 'zone=$zone',
      if (zoneLabel.trim().isNotEmpty) 'zone_label=${zoneLabel.trim()}',
    ].join(' • ');
    return 'ONYX BINDALARM\n'
        'account=$accountNumber\n'
        'scope=$clientId/$siteId\n'
        'site=${entry.siteName}\n'
        'client=${entry.clientName}\n'
        '${scopeSuffix.isEmpty ? 'match=account_only' : scopeSuffix}\n'
        'bindings=${_listenerAlarmScopeRegistry.allEntries().length}\n'
        'UTC: ${_telegramUtcStamp()}';
  }

  String _telegramAdminUnlinkAlarmCommand(String arguments) {
    final tokens = arguments
        .split(RegExp(r'\s+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty || tokens.length > 3) {
      return 'ONYX UNLINKALARM\n'
          'Usage: /unlinkalarm <account> [partition] [zone]';
    }
    final accountNumber = tokens[0].trim();
    final partition = tokens.length > 1 && tokens[1] != '-'
        ? tokens[1].trim()
        : '';
    final zone = tokens.length > 2 && tokens[2] != '-' ? tokens[2].trim() : '';
    final removed = _listenerAlarmScopeRegistry.remove(
      accountNumber: accountNumber,
      partition: partition,
      zone: zone,
    );
    if (removed) {
      unawaited(_persistTelegramAdminRuntimeState());
    }
    return 'ONYX UNLINKALARM\n'
        'account=$accountNumber\n'
        'partition=${partition.isEmpty ? 'any' : partition}\n'
        'zone=${zone.isEmpty ? 'any' : zone}\n'
        'removed=${removed ? 'yes' : 'no'}\n'
        'bindings=${_listenerAlarmScopeRegistry.allEntries().length}\n'
        'UTC: ${_telegramUtcStamp()}';
  }

  String _telegramAdminAlarmBindingsCommand(String arguments) {
    final accountFilter = arguments.trim();
    final entries = accountFilter.isEmpty
        ? _listenerAlarmScopeRegistry.allEntries()
        : _listenerAlarmScopeRegistry.entriesForAccount(accountFilter);
    entries.sort((a, b) {
      final accountCompare = a.accountNumber.compareTo(b.accountNumber);
      if (accountCompare != 0) {
        return accountCompare;
      }
      final partitionCompare = a.partition.compareTo(b.partition);
      if (partitionCompare != 0) {
        return partitionCompare;
      }
      return a.zone.compareTo(b.zone);
    });
    final rows = entries
        .take(12)
        .map((entry) {
          final partition = entry.partition.trim().isEmpty
              ? '*'
              : entry.partition.trim();
          final zone = entry.zone.trim().isEmpty ? '*' : entry.zone.trim();
          final zoneLabel = entry.zoneLabel.trim().isEmpty
              ? ''
              : ' (${entry.zoneLabel.trim()})';
          return '- acct ${entry.accountNumber} | p=$partition | z=$zone$zoneLabel | ${entry.clientId}/${entry.siteId}';
        })
        .join('\n');
    return 'ONYX ALARMBINDINGS\n'
        'filter=${accountFilter.isEmpty ? 'all' : accountFilter}\n'
        'count=${entries.length}'
        '${rows.isEmpty ? '\n(no alarm bindings configured)' : '\n$rows'}';
  }

  Future<String> _telegramAdminAlarmTestCommand(String arguments) async {
    final raw = arguments.trim();
    if (raw.isEmpty) {
      return 'ONYX ALARMTEST\n'
          'Usage: /alarmtest <clear|suspicious|pending|unavailable> <listener line>';
    }
    final firstSpace = raw.indexOf(RegExp(r'\s'));
    if (firstSpace == -1) {
      return 'ONYX ALARMTEST\n'
          'Usage: /alarmtest <clear|suspicious|pending|unavailable> <listener line>';
    }
    final dispositionLabel = raw.substring(0, firstSpace).trim();
    final listenerLine = raw.substring(firstSpace + 1).trim();
    final disposition = _listenerAlarmDispositionFromRaw(dispositionLabel);
    if (disposition == null || listenerLine.isEmpty) {
      return 'ONYX ALARMTEST\n'
          'Unknown disposition or missing listener line.\n'
          'Usage: /alarmtest <clear|suspicious|pending|unavailable> <listener line>';
    }
    final parseAttempt = _listenerAlarmSerialIngestor.parseLineDetailed(
      line: listenerLine,
      clientId: 'LISTENER-RAW',
      regionId: _selectedRegion,
      siteId: 'LISTENER-RAW',
    );
    final envelope = parseAttempt.envelope;
    if (envelope == null) {
      return 'ONYX ALARMTEST\n'
          'parse=failed\n'
          'reason=${parseAttempt.rejectReason ?? 'unknown'}';
    }
    final pipelineResult = _listenerAlarmAdvisoryPipeline.process(
      envelope: envelope,
      disposition: disposition,
    );
    if (pipelineResult == null) {
      return 'ONYX ALARMTEST\n'
          'parse=ok\n'
          'scope=unmapped\n'
          'account=${envelope.accountNumber}\n'
          'partition=${envelope.partition.isEmpty ? 'n/a' : envelope.partition}\n'
          'zone=${envelope.zone.isEmpty ? 'n/a' : envelope.zone}\n'
          'hint=Bind the alarm account with /bindalarm before retrying.';
    }

    final normalizedIntel = pipelineResult.normalizedIntel;
    IntelligenceIngestionOutcome? outcome;
    if (normalizedIntel != null) {
      outcome = service.ingestNormalizedIntelligence(
        records: <NormalizedIntelRecord>[normalizedIntel],
        autoGenerateDispatches: false,
      );
    }

    final delivery = await _deliverListenerAlarmAdvisory(pipelineResult);
    final resolvedClientId = pipelineResult.resolution.envelope.clientId.trim();
    final resolvedSiteId = pipelineResult.resolution.envelope.siteId.trim();

    return 'ONYX ALARMTEST\n'
        'parse=ok\n'
        'scope=$resolvedClientId/$resolvedSiteId\n'
        'site=${pipelineResult.siteProfile.siteName}\n'
        'match=${pipelineResult.resolution.scope.matchMode.name}\n'
        'event=${pipelineResult.resolution.eventLabel}\n'
        'intel=${normalizedIntel == null ? 'skipped' : 'recorded'}'
        '${outcome == null ? '' : ' (${outcome.appendedIntelligence}/${outcome.attemptedIntelligence})'}\n'
        'partner_targets=${delivery.targetCount}\n'
        'partner_delivery=${delivery.deliveredCount} sent / ${delivery.failedCount} failed\n'
        'advisory=${pipelineResult.resolution.advisoryMessage}';
  }

  String _telegramAdminActivityTruthCommand(String arguments) {
    final scope = _parseMonitoringWatchScope(arguments);
    if (scope == null ||
        scope.clientId.trim().isEmpty ||
        scope.siteId.trim().isEmpty) {
      return 'ONYX ACTIVITYTRUTH\nUsage: /activitytruth [client_id site_id]';
    }
    final normalizedClientId = scope.clientId.trim();
    final normalizedSiteId = scope.siteId.trim();
    final summary = _siteActivityTelegramSummaryForScope(
      clientId: normalizedClientId,
      siteId: normalizedSiteId,
      includeEvidenceHandoff: true,
      includeReviewCommandHint: true,
      includeCaseFileHint: true,
    );
    return 'ONYX ACTIVITYTRUTH\n'
        'scope=$normalizedClientId/$normalizedSiteId\n'
        '$summary';
  }

  String _telegramAdminActivityReviewCommand(String arguments) {
    final scope = _parseSiteActivityScopeRequest(arguments);
    if (scope == null ||
        scope.clientId.trim().isEmpty ||
        scope.siteId.trim().isEmpty) {
      return 'ONYX ACTIVITYREVIEW\n'
          'Usage: /activityreview [client_id site_id] [report_date]';
    }
    final normalizedClientId = scope.clientId.trim();
    final normalizedSiteId = scope.siteId.trim();
    final point = _siteActivityHistoryPointForScope(
      clientId: normalizedClientId,
      siteId: normalizedSiteId,
      reportDate: scope.reportDate,
    );
    if (point == null || point.eventIds.isEmpty) {
      return 'ONYX ACTIVITYREVIEW\n'
          'scope=$normalizedClientId/$normalizedSiteId'
          '${(scope.reportDate ?? '').trim().isEmpty ? '' : '\nreport_date=${scope.reportDate!.trim()}'}\n'
          'No site-activity evidence is currently available for Events Review.';
    }
    _openEventsForScopedEventIds(
      point.eventIds,
      selectedEventId: point.snapshot.selectedEventId,
    );
    return 'ONYX ACTIVITYREVIEW\n'
        'scope=$normalizedClientId/$normalizedSiteId\n'
        'report_date=${point.reportDate}\n'
        'selected=${point.snapshot.selectedEventId ?? point.eventIds.first}\n'
        'events=${point.eventIds.length}\n'
        'Opening Events Review for site activity investigation.';
  }

  String _telegramAdminActivityCaseCommand(String arguments) {
    final tokens = arguments
        .split(RegExp(r'\s+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    var format = 'json';
    var index = 0;
    if (tokens.isNotEmpty) {
      final first = tokens.first.toLowerCase();
      if (first == 'json' || first == 'csv') {
        format = first;
        index = 1;
      }
    }
    final scope = _parseSiteActivityScopeRequest(tokens.sublist(index).join(' '));
    if (scope == null ||
        scope.clientId.trim().isEmpty ||
        scope.siteId.trim().isEmpty) {
      return 'ONYX ACTIVITYCASE\n'
          'Usage: /activitycase [json|csv] [client_id site_id] [report_date]';
    }
    final normalizedClientId = scope.clientId.trim();
    final normalizedSiteId = scope.siteId.trim();
    final normalizedReportDate = scope.reportDate?.trim();
    final scopeLine =
        'scope=$normalizedClientId/$normalizedSiteId${normalizedReportDate == null || normalizedReportDate.isEmpty ? '' : '\nreport_date=$normalizedReportDate'}';
    if (format == 'csv') {
      return 'ONYX ACTIVITYCASE CSV\n'
          '$scopeLine\n'
          '${_siteActivityCaseFileCsv(clientId: normalizedClientId, siteId: normalizedSiteId, reportDate: normalizedReportDate)}';
    }
    return 'ONYX ACTIVITYCASE JSON\n'
        '$scopeLine\n'
        '${const JsonEncoder.withIndent('  ').convert(_siteActivityCaseFilePayload(clientId: normalizedClientId, siteId: normalizedSiteId, reportDate: normalizedReportDate))}';
  }

  String _telegramAdminReadinessReviewCommand(String arguments) {
    final normalizedReportDate = arguments.trim();
    final report = _morningSovereignReportForDate(normalizedReportDate);
    if (report == null) {
      return 'ONYX READINESSREVIEW\n'
          'Usage: /readinessreview [report_date]\n'
          'No morning sovereign report is available for that shift.';
    }
    final snapshot = _globalReadinessSnapshotForReport(report);
    final intents = _globalReadinessIntentsForReport(report);
    _openGovernanceFromAdmin();
    return 'ONYX READINESSREVIEW\n'
        'report_date=${report.date}\n'
        'mode=${_globalReadinessModeLabel(snapshot, intents)}\n'
        'summary=${_globalReadinessSummaryForReport(snapshot: snapshot, intents: intents)}\n'
        'Opening Governance for global readiness oversight.';
  }

  String _telegramAdminReadinessCaseCommand(String arguments) {
    final tokens = arguments
        .split(RegExp(r'\s+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    var format = 'json';
    var index = 0;
    if (tokens.isNotEmpty) {
      final first = tokens.first.toLowerCase();
      if (first == 'json' || first == 'csv') {
        format = first;
        index = 1;
      }
    }
    final reportDate = tokens.length > index ? tokens.sublist(index).join(' ') : '';
    final normalizedReportDate = reportDate.trim();
    final report = _morningSovereignReportForDate(normalizedReportDate);
    if (report == null) {
      return 'ONYX READINESSCASE\n'
          'Usage: /readinesscase [json|csv] [report_date]\n'
          'No morning sovereign report is available for that shift.';
    }
    if (format == 'csv') {
      return 'ONYX READINESSCASE CSV\n'
          'report_date=${report.date}\n'
          '${_globalReadinessCaseFileCsv(reportDate: report.date)}';
    }
    return 'ONYX READINESSCASE JSON\n'
        'report_date=${report.date}\n'
        '${const JsonEncoder.withIndent('  ').convert(_globalReadinessCaseFilePayload(reportDate: report.date))}';
  }

  Future<String> _telegramAdminSendActivityCommand(String arguments) async {
    final tokens = arguments
        .split(RegExp(r'\s+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    var sendClient = true;
    var sendPartner = true;
    var index = 0;
    if (tokens.isNotEmpty) {
      final lane = tokens.first.toLowerCase();
      if (lane == 'client' || lane == 'partner' || lane == 'both') {
        sendClient = lane != 'partner';
        sendPartner = lane != 'client';
        index = 1;
      }
    }
    final targetTokens = tokens.sublist(index);
    final argumentsScope = targetTokens.join(' ');
    final scope = _parseMonitoringWatchScope(argumentsScope);
    if (scope == null ||
        scope.clientId.trim().isEmpty ||
        scope.siteId.trim().isEmpty) {
      return 'ONYX SENDACTIVITY\n'
          'Usage: /sendactivity [client|partner|both] [client_id site_id]';
    }
    return _deliverSiteActivityTelegramSummary(
      clientId: scope.clientId,
      siteId: scope.siteId,
      sendClient: sendClient,
      sendPartner: sendPartner,
    );
  }

  Future<_TelegramDemoReadinessReport> _telegramAdminBuildDemoReadinessReport({
    required String clientId,
    required String siteId,
    required TelegramBridgeInboundMessage update,
  }) async {
    final checks = <String>[];
    final actions = <String>[];
    final bridgeConfigured = _telegramBridge.isConfigured;
    checks.add('bridge_configured=${bridgeConfigured ? 'PASS' : 'FAIL'}');
    if (!bridgeConfigured) {
      actions.add('Set ONYX_TELEGRAM_BRIDGE_ENABLED=true and valid bot token.');
    }
    final executionEnabled = _telegramAdminExecutionEnabled;
    checks.add('execution_mode=${executionEnabled ? 'PASS' : 'FAIL'}');
    if (!executionEnabled) {
      actions.add('Run /exec on');
    }
    final hasTarget = clientId.trim().isNotEmpty && siteId.trim().isNotEmpty;
    checks.add(
      'target_scope=${hasTarget ? 'PASS' : 'FAIL'} ($clientId/$siteId)',
    );
    if (!hasTarget) {
      actions.add('Run /settarget <client_id> <site_id>');
    }
    if (widget.supabaseReady) {
      try {
        final repository = SupabaseClientMessagingBridgeRepository(
          Supabase.instance.client,
        );
        final targets =
            (await repository.readActiveTelegramTargets(
                  clientId: clientId,
                  siteId: siteId,
                ))
                .where(
                  (target) => !_isPartnerEndpointLabel(target.displayLabel),
                )
                .toList(growable: false);
        final linked = targets.any(
          (target) =>
              target.chatId.trim() == update.chatId.trim() &&
              target.threadId == update.messageThreadId,
        );
        checks.add(
          'chat_linked=${linked ? 'PASS' : 'FAIL'} (${targets.length} active)',
        );
        if (!linked) {
          actions.add('Run /bindchat $clientId $siteId');
        }
      } catch (error) {
        checks.add('chat_linked=UNKNOWN (lookup failed)');
        actions.add('Check Supabase connectivity: $error');
      }
    } else {
      checks.add('chat_linked=SKIPPED (supabase not ready)');
      actions.add('Enable Supabase for managed endpoint checks.');
    }
    final blockedBridge = _telegramBridgeHealthLabel.toLowerCase() == 'blocked';
    checks.add('bridge_blocked=${blockedBridge ? 'FAIL' : 'PASS'}');
    if (blockedBridge) {
      actions.add('Investigate Telegram block and rotate bot/chat if needed.');
    }
    return _TelegramDemoReadinessReport(
      clientId: clientId,
      siteId: siteId,
      currentChatLabel:
          '${update.chatId}${update.messageThreadId == null ? '' : '#${update.messageThreadId}'}',
      checks: checks,
      actions: actions,
    );
  }

  Future<String> _telegramAdminDemoPrepCommand(
    String arguments,
    TelegramBridgeInboundMessage update,
  ) async {
    final tokens = arguments
        .split(RegExp(r'\s+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (tokens.length == 1 || tokens.length > 2) {
      return 'ONYX DEMOPREP\nUsage: /demoprep [client_id site_id]';
    }
    final clientId = tokens.isEmpty ? _telegramAdminTargetClientId : tokens[0];
    final siteId = tokens.isEmpty ? _telegramAdminTargetSiteId : tokens[1];
    if (clientId.isEmpty || siteId.isEmpty) {
      return 'ONYX DEMOPREP\nUsage: /demoprep [client_id site_id]';
    }
    final report = await _telegramAdminBuildDemoReadinessReport(
      clientId: clientId,
      siteId: siteId,
      update: update,
    );
    final checksRows = report.checks.map((entry) => '- $entry').join('\n');
    final actionRows = report.actions.isEmpty
        ? '- none'
        : report.actions.map((entry) => '- $entry').join('\n');
    return 'ONYX DEMOPREP\n'
        'scope=${report.clientId}/${report.siteId}\n'
        'chat=${report.currentChatLabel}\n'
        'ready=${report.ready ? 'YES' : 'NO'}\n'
        'checks:\n$checksRows\n'
        'next_actions:\n$actionRows\n'
        'UTC: ${_telegramUtcStamp()}';
  }

  Future<String> _telegramAdminDemoFlowCommand(
    String arguments,
    TelegramBridgeInboundMessage update,
  ) async {
    final tokens = arguments
        .split(RegExp(r'\s+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (tokens.length == 1 || tokens.length > 2) {
      return 'ONYX DEMOFLOW\nUsage: /demoflow [client_id site_id]';
    }
    final clientId = tokens.isEmpty ? _telegramAdminTargetClientId : tokens[0];
    final siteId = tokens.isEmpty ? _telegramAdminTargetSiteId : tokens[1];
    if (clientId.isEmpty || siteId.isEmpty) {
      return 'ONYX DEMOFLOW\nUsage: /demoflow [client_id site_id]';
    }
    final report = await _telegramAdminBuildDemoReadinessReport(
      clientId: clientId,
      siteId: siteId,
      update: update,
    );
    if (!report.ready) {
      final actionRows = report.actions.isEmpty
          ? '- none'
          : report.actions.map((entry) => '- $entry').join('\n');
      return 'ONYX DEMOFLOW\n'
          'scope=${report.clientId}/${report.siteId}\n'
          'ready=NO\n'
          'action=aborted\n'
          'next_actions:\n$actionRows';
    }
    final notifyResult = await _telegramAdminNotifyTestCommand(
      'client ${report.clientId} ${report.siteId}',
    );
    return 'ONYX DEMOFLOW\n'
        'scope=${report.clientId}/${report.siteId}\n'
        'ready=YES\n'
        'action=notifytest(client)\n'
        '${notifyResult.replaceFirst('ONYX NOTIFYTEST\n', '')}';
  }

  Future<String> _telegramAdminAutoDemoCommand(
    String arguments,
    TelegramBridgeInboundMessage update,
  ) async {
    final tokens = arguments
        .split(RegExp(r'\s+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (tokens.length < 2) {
      return 'ONYX AUTODEMO\nUsage: /autodemo <client_id> <site_id> [label]';
    }
    final clientId = tokens[0].trim();
    final siteId = tokens[1].trim();
    if (clientId.isEmpty || siteId.isEmpty) {
      return 'ONYX AUTODEMO\nUsage: /autodemo <client_id> <site_id> [label]';
    }
    final label = tokens.length > 2 ? tokens.sublist(2).join(' ').trim() : '';
    _telegramAdminTargetClientIdOverride = clientId;
    _telegramAdminTargetSiteIdOverride = siteId;
    await _persistTelegramAdminRuntimeState();
    final linkArgs = label.isEmpty
        ? '$clientId $siteId'
        : '$clientId $siteId $label';
    final linkResult = await _telegramAdminLinkChatCommand(linkArgs, update);
    if (linkResult.startsWith('ONYX LINKCHAT\nFailed')) {
      return 'ONYX AUTODEMO\n'
          'scope=$clientId/$siteId\n'
          'target_set=YES\n'
          'link_result=FAILED\n'
          '${linkResult.replaceFirst('ONYX LINKCHAT\n', '')}';
    }
    final flowResult = await _telegramAdminDemoFlowCommand(
      '$clientId $siteId',
      update,
    );
    return 'ONYX AUTODEMO\n'
        'scope=$clientId/$siteId\n'
        'target_set=YES\n'
        '${linkResult.replaceFirst('ONYX LINKCHAT\n', 'linkchat:\n')}\n'
        '${flowResult.replaceFirst('ONYX DEMOFLOW\n', 'demoflow:\n')}';
  }

  List<ClientAppPushDeliveryItem> _buildTelegramDemoScriptItems({
    required String clientId,
    required String siteId,
    required String runId,
    required DateTime baseAtUtc,
    required int secondStepOffsetSeconds,
    required int thirdStepOffsetSeconds,
  }) {
    return <ClientAppPushDeliveryItem>[
      ClientAppPushDeliveryItem(
        messageKey: '$runId-1',
        title: 'ONYX Signal Detected',
        body:
            'Perimeter alert detected at $siteId. Controller verification in progress.',
        occurredAt: baseAtUtc,
        clientId: clientId,
        siteId: siteId,
        targetChannel: ClientAppAcknowledgementChannel.client,
        deliveryProvider: _clientPushDeliveryProvider,
        priority: true,
        status: ClientPushDeliveryStatus.queued,
      ),
      ClientAppPushDeliveryItem(
        messageKey: '$runId-2',
        title: 'ONYX Unit Dispatched',
        body:
            'Nearest response unit has been dispatched with access protocol and ETA.',
        occurredAt: baseAtUtc.add(Duration(seconds: secondStepOffsetSeconds)),
        clientId: clientId,
        siteId: siteId,
        targetChannel: ClientAppAcknowledgementChannel.client,
        deliveryProvider: _clientPushDeliveryProvider,
        priority: true,
        status: ClientPushDeliveryStatus.queued,
      ),
      ClientAppPushDeliveryItem(
        messageKey: '$runId-3',
        title: 'ONYX Site Secured',
        body:
            'Officer reported site secure. Evidence package will appear in the client ledger.',
        occurredAt: baseAtUtc.add(Duration(seconds: thirdStepOffsetSeconds)),
        clientId: clientId,
        siteId: siteId,
        targetChannel: ClientAppAcknowledgementChannel.client,
        deliveryProvider: _clientPushDeliveryProvider,
        priority: false,
        status: ClientPushDeliveryStatus.queued,
      ),
    ];
  }

  void _resetTelegramDemoScriptRun() {
    _telegramDemoScriptTimer?.cancel();
    _telegramDemoScriptTimer = null;
    _telegramDemoScriptRunning = false;
    _telegramDemoScriptStep = 0;
    _telegramDemoScriptTotal = 0;
    _telegramDemoScriptIntervalSeconds = 20;
    _telegramDemoScriptScopeLabel = '';
    _telegramDemoScriptRunId = '';
    _telegramDemoScriptStartedAtUtc = null;
    _telegramDemoScriptNextStepAtUtc = null;
    _telegramDemoScriptPendingItems = const [];
  }

  Future<void> _runTelegramDemoScriptStep() async {
    if (!_telegramDemoScriptRunning) {
      return;
    }
    final pending = _telegramDemoScriptPendingItems;
    if (pending.isEmpty) {
      _resetTelegramDemoScriptRun();
      if (mounted) {
        setState(() {});
      }
      return;
    }
    final current = pending.first;
    _telegramDemoScriptPendingItems = pending.sublist(1);
    _telegramDemoScriptStep += 1;
    _telegramDemoScriptNextStepAtUtc = null;
    if (mounted) {
      setState(() {});
    }
    await _persistClientAppPushQueue(<ClientAppPushDeliveryItem>[
      current,
      ..._clientAppPushQueue,
    ], forceTelegramResend: true);
    if (!_telegramDemoScriptRunning) {
      return;
    }
    if (_telegramDemoScriptPendingItems.isEmpty) {
      _resetTelegramDemoScriptRun();
      if (mounted) {
        setState(() {});
      }
      return;
    }
    _telegramDemoScriptTimer?.cancel();
    _telegramDemoScriptNextStepAtUtc = DateTime.now().toUtc().add(
      Duration(seconds: _telegramDemoScriptIntervalSeconds),
    );
    _telegramDemoScriptTimer = Timer(
      Duration(seconds: _telegramDemoScriptIntervalSeconds),
      () {
        unawaited(_runTelegramDemoScriptStep());
      },
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<String> _telegramAdminDemoPlayCommand(String arguments) async {
    final tokens = arguments
        .split(RegExp(r'\s+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (tokens.length == 1 || tokens.length > 3) {
      return 'ONYX DEMOPLAY\nUsage: /demoplay [client_id site_id [interval_seconds]]';
    }
    final clientId = tokens.isEmpty ? _telegramAdminTargetClientId : tokens[0];
    final siteId = tokens.isEmpty ? _telegramAdminTargetSiteId : tokens[1];
    if (clientId.isEmpty || siteId.isEmpty) {
      return 'ONYX DEMOPLAY\nUsage: /demoplay [client_id site_id [interval_seconds]]';
    }
    final intervalSeconds = tokens.length < 3
        ? 20
        : int.tryParse(tokens[2]) ?? -1;
    if (intervalSeconds < 5 || intervalSeconds > 300) {
      return 'ONYX DEMOPLAY\nInvalid interval "${tokens.length < 3 ? '' : tokens[2]}". Range is 5..300 seconds.';
    }
    if (_telegramDemoScriptRunning) {
      return _telegramAdminDemoPlayStatusCommand();
    }
    final baseAtUtc = DateTime.now().toUtc();
    final runId = 'tg-demo-live-${baseAtUtc.microsecondsSinceEpoch}';
    final items = _buildTelegramDemoScriptItems(
      clientId: clientId,
      siteId: siteId,
      runId: runId,
      baseAtUtc: baseAtUtc,
      secondStepOffsetSeconds: intervalSeconds,
      thirdStepOffsetSeconds: intervalSeconds * 2,
    );
    _telegramDemoScriptRunning = true;
    _telegramDemoScriptStep = 0;
    _telegramDemoScriptTotal = items.length;
    _telegramDemoScriptIntervalSeconds = intervalSeconds;
    _telegramDemoScriptScopeLabel = '$clientId/$siteId';
    _telegramDemoScriptRunId = runId;
    _telegramDemoScriptStartedAtUtc = baseAtUtc;
    _telegramDemoScriptNextStepAtUtc = null;
    _telegramDemoScriptPendingItems = items;
    if (mounted) {
      setState(() {});
    }
    await _runTelegramDemoScriptStep();
    return 'ONYX DEMOPLAY\n'
        'run_id=$runId\n'
        'scope=$clientId/$siteId\n'
        'interval_seconds=$intervalSeconds\n'
        'steps=${items.length}\n'
        'status=${_telegramDemoScriptRunning ? 'running' : 'completed'}';
  }

  String _telegramAdminDemoPlayStopCommand() {
    if (!_telegramDemoScriptRunning) {
      return 'ONYX DEMOPLAY\nNo active timed demo sequence.';
    }
    final scopeLabel = _telegramDemoScriptScopeLabel;
    final progress = '$_telegramDemoScriptStep/$_telegramDemoScriptTotal';
    _resetTelegramDemoScriptRun();
    if (mounted) {
      setState(() {});
    }
    return 'ONYX DEMOPLAY\nStopped timed demo sequence.\nScope: $scopeLabel\nProgress: $progress';
  }

  String _telegramAdminDemoPlayStatusCommand() {
    if (!_telegramDemoScriptRunning) {
      return 'ONYX DEMOPLAY\nStatus: idle';
    }
    final nextAt = _telegramDemoScriptNextStepAtUtc;
    final nextInSeconds = nextAt == null
        ? 0
        : nextAt.difference(DateTime.now().toUtc()).inSeconds;
    return 'ONYX DEMOPLAY\n'
        'Status: running\n'
        'Run: ${_telegramDemoScriptRunId.isEmpty ? 'n/a' : _telegramDemoScriptRunId}\n'
        'Scope: ${_telegramDemoScriptScopeLabel.isEmpty ? 'n/a' : _telegramDemoScriptScopeLabel}\n'
        'Started: ${_telegramDemoScriptStartedAtUtc?.toIso8601String() ?? 'n/a'}\n'
        'Step: $_telegramDemoScriptStep/$_telegramDemoScriptTotal\n'
        'Interval seconds: $_telegramDemoScriptIntervalSeconds\n'
        'Pending: ${_telegramDemoScriptPendingItems.length}\n'
        'Next in: ${nextInSeconds > 0 ? nextInSeconds : 0}s';
  }

  Future<String> _telegramAdminDemoScriptCommand(String arguments) async {
    final tokens = arguments
        .split(RegExp(r'\s+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (tokens.length == 1 || tokens.length > 2) {
      return 'ONYX DEMOSCRIPT\nUsage: /demoscript [client_id site_id]';
    }
    final clientId = tokens.isEmpty ? _telegramAdminTargetClientId : tokens[0];
    final siteId = tokens.isEmpty ? _telegramAdminTargetSiteId : tokens[1];
    if (clientId.isEmpty || siteId.isEmpty) {
      return 'ONYX DEMOSCRIPT\nUsage: /demoscript [client_id site_id]';
    }
    final nowUtc = DateTime.now().toUtc();
    final runId = 'tg-demo-${nowUtc.microsecondsSinceEpoch}';
    final scriptedItems = _buildTelegramDemoScriptItems(
      clientId: clientId,
      siteId: siteId,
      runId: runId,
      baseAtUtc: nowUtc,
      secondStepOffsetSeconds: 25,
      thirdStepOffsetSeconds: 90,
    );
    final queue = <ClientAppPushDeliveryItem>[
      ...scriptedItems,
      ..._clientAppPushQueue,
    ];
    await _persistClientAppPushQueue(queue, forceTelegramResend: true);
    final syncStatus = _clientAppPushSyncStatusLabel.toUpperCase();
    final failureReason = (_clientAppPushSyncFailureReason ?? '').trim();
    return 'ONYX DEMOSCRIPT\n'
        'scope=$clientId/$siteId\n'
        'queued_script_messages=${scriptedItems.length}\n'
        'delivery_provider=${_clientPushDeliveryProvider.code}\n'
        'queue_size=${_clientAppPushQueue.length}\n'
        'sync_status=$syncStatus${failureReason.isEmpty ? '' : ' • $failureReason'}\n'
        'UTC: ${nowUtc.toIso8601String()}';
  }

  Future<String> _telegramAdminDemoCleanCommand(String arguments) async {
    final tokens = arguments
        .split(RegExp(r'\s+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (tokens.length == 1 || tokens.length > 2) {
      return 'ONYX DEMOCLEAN\nUsage: /democlean [client_id site_id]';
    }
    final clientId = tokens.isEmpty ? _telegramAdminTargetClientId : tokens[0];
    final siteId = tokens.isEmpty ? _telegramAdminTargetSiteId : tokens[1];
    if (clientId.isEmpty || siteId.isEmpty) {
      return 'ONYX DEMOCLEAN\nUsage: /democlean [client_id site_id]';
    }
    bool isDemoKey(String key) {
      final normalized = key.trim().toLowerCase();
      return normalized.startsWith('tg-demo-') ||
          normalized.startsWith('tg-admin-test-');
    }

    bool matchesScope(ClientAppPushDeliveryItem item) {
      final itemClientId = (item.clientId ?? _selectedClient).trim();
      final itemSiteId = (item.siteId ?? _selectedSite).trim();
      return itemClientId == clientId && itemSiteId == siteId;
    }

    final before = _clientAppPushQueue.length;
    final filtered = _clientAppPushQueue
        .where((item) => !(matchesScope(item) && isDemoKey(item.messageKey)))
        .toList(growable: false);
    final removed = before - filtered.length;
    if (removed <= 0) {
      return 'ONYX DEMOCLEAN\nscope=$clientId/$siteId\nremoved=0\nNo queued demo/test alerts found.';
    }
    await _persistClientAppPushQueue(filtered, forceTelegramResend: false);
    final syncStatus = _clientAppPushSyncStatusLabel.toUpperCase();
    final failureReason = (_clientAppPushSyncFailureReason ?? '').trim();
    return 'ONYX DEMOCLEAN\n'
        'scope=$clientId/$siteId\n'
        'removed=$removed\n'
        'queue_size=${_clientAppPushQueue.length}\n'
        'sync_status=$syncStatus${failureReason.isEmpty ? '' : ' • $failureReason'}\n'
        'UTC: ${DateTime.now().toUtc().toIso8601String()}';
  }

  Future<String> _telegramAdminDemoLaunchCommand(
    String arguments,
    TelegramBridgeInboundMessage update,
  ) async {
    if (_telegramDemoScriptRunning) {
      _resetTelegramDemoScriptRun();
      if (mounted) {
        setState(() {});
      }
    }
    final tokens = arguments
        .split(RegExp(r'\s+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (tokens.length < 2) {
      return 'ONYX DEMOLAUNCH\nUsage: /demolaunch <client_id> <site_id> [label]';
    }
    final clientId = tokens[0].trim();
    final siteId = tokens[1].trim();
    if (clientId.isEmpty || siteId.isEmpty) {
      return 'ONYX DEMOLAUNCH\nUsage: /demolaunch <client_id> <site_id> [label]';
    }
    final label = tokens.length > 2 ? tokens.sublist(2).join(' ').trim() : '';
    _telegramAdminTargetClientIdOverride = clientId;
    _telegramAdminTargetSiteIdOverride = siteId;
    await _persistTelegramAdminRuntimeState();

    final linkArgs = label.isEmpty
        ? '$clientId $siteId'
        : '$clientId $siteId $label';
    final linkResult = await _telegramAdminLinkChatCommand(linkArgs, update);
    if (linkResult.startsWith('ONYX LINKCHAT\nFailed')) {
      return 'ONYX DEMOLAUNCH\n'
          'scope=$clientId/$siteId\n'
          'stage=linkchat\n'
          'result=FAILED\n'
          '${linkResult.replaceFirst('ONYX LINKCHAT\n', '')}';
    }

    final readiness = await _telegramAdminBuildDemoReadinessReport(
      clientId: clientId,
      siteId: siteId,
      update: update,
    );
    if (!readiness.ready) {
      final actions = readiness.actions.isEmpty
          ? '- none'
          : readiness.actions.map((entry) => '- $entry').join('\n');
      return 'ONYX DEMOLAUNCH\n'
          'scope=$clientId/$siteId\n'
          'stage=readiness\n'
          'result=BLOCKED\n'
          'next_actions:\n$actions';
    }

    final cleanResult = await _telegramAdminDemoCleanCommand(
      '$clientId $siteId',
    );
    final scriptResult = await _telegramAdminDemoScriptCommand(
      '$clientId $siteId',
    );
    return 'ONYX DEMOLAUNCH\n'
        'scope=$clientId/$siteId\n'
        'result=OK\n'
        '${linkResult.replaceFirst('ONYX LINKCHAT\n', 'linkchat:\n')}\n'
        '${cleanResult.replaceFirst('ONYX DEMOCLEAN\n', 'democlean:\n')}\n'
        '${scriptResult.replaceFirst('ONYX DEMOSCRIPT\n', 'demoscript:\n')}';
  }

  Future<String> _telegramAdminTargetsCommand(String arguments) async {
    if (!widget.supabaseReady) {
      return 'ONYX TARGETS\nSupabase is required to read messaging endpoints.';
    }
    final tokens = arguments
        .split(RegExp(r'\s+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (tokens.length == 1 || tokens.length > 2) {
      return 'ONYX TARGETS\nUsage: /targets [client_id site_id]';
    }
    final clientId = tokens.isEmpty ? _telegramAdminTargetClientId : tokens[0];
    final siteId = tokens.isEmpty ? _telegramAdminTargetSiteId : tokens[1];
    try {
      final repository = SupabaseClientMessagingBridgeRepository(
        Supabase.instance.client,
      );
      final targets = await repository.readActiveTelegramTargets(
        clientId: clientId,
        siteId: siteId,
      );
      if (targets.isEmpty) {
        return 'ONYX TARGETS\nscope=$clientId/$siteId\nNo active Telegram endpoints.';
      }
      final rows = targets
          .take(8)
          .map((target) {
            final threadLabel = target.threadId == null
                ? 'none'
                : target.threadId.toString();
            final scopeLabel = (target.siteId ?? '').trim().isEmpty
                ? 'global'
                : target.siteId!.trim();
            return '- ${target.displayLabel} | chat=${target.chatId} | thread=$threadLabel | scope=$scopeLabel';
          })
          .join('\n');
      return 'ONYX TARGETS\n'
          'scope=$clientId/$siteId\n'
          'active_endpoints=${targets.length}\n'
          '$rows';
    } catch (error) {
      return 'ONYX TARGETS\nFailed to read endpoints: $error';
    }
  }

  Future<String> _telegramAdminDemoStartCommand(
    String arguments, {
    required bool full,
  }) async {
    final requestedRef = arguments.trim();
    final incidentRef = requestedRef.isNotEmpty
        ? requestedRef
        : _firstActiveIncidentReference();
    if (incidentRef == null || incidentRef.isEmpty) {
      return 'ONYX DEMO\nNo active incident found.\nUsage: ${full ? '/demofull' : '/demostart'} <incident_ref>';
    }
    if (_demoAutopilotRunning) {
      return 'ONYX DEMO\nAutopilot already running: step $_demoAutopilotCurrentStep/$_demoAutopilotTotalSteps • $_demoAutopilotFlowLabel';
    }
    if (full) {
      _startFullDemoAutopilotFromAdminIncident(incidentRef);
    } else {
      _startDemoAutopilotFromAdminIncident(incidentRef);
    }
    return 'ONYX DEMO\nStarted ${full ? 'full' : 'quick'} autopilot for $incidentRef.\nRoute now: ${_autopilotRouteLabel(_route)}';
  }

  Future<String> _telegramAdminDemoStopCommand() async {
    if (!_demoAutopilotRunning) {
      return 'ONYX DEMO\nAutopilot is not running.';
    }
    _stopDemoAutopilotFromShell();
    return 'ONYX DEMO\nAutopilot stopped.\nUTC: ${DateTime.now().toUtc().toIso8601String()}';
  }

  Future<String> _telegramAdminDemoStatusCommand() async {
    if (!_demoAutopilotRunning) {
      return 'ONYX DEMO\nStatus: idle\nRoute: ${_autopilotRouteLabel(_route)}\nUTC: ${DateTime.now().toUtc().toIso8601String()}';
    }
    return 'ONYX DEMO\n'
        'Status: ${_demoAutopilotPaused ? 'paused' : 'running'}\n'
        'Flow: $_demoAutopilotFlowLabel\n'
        'Step: $_demoAutopilotCurrentStep/$_demoAutopilotTotalSteps\n'
        'Current route: ${_autopilotRouteLabel(_route)}\n'
        'Next route: ${_demoAutopilotNextRouteLabel.isEmpty ? 'n/a' : _demoAutopilotNextRouteLabel}\n'
        'Next hop seconds: ${_demoAutopilotNextHopSeconds > 0 ? _demoAutopilotNextHopSeconds : 0}\n'
        'Incident: ${_demoAutopilotIncidentReference.isEmpty ? 'n/a' : _demoAutopilotIncidentReference}\n'
        'UTC: ${DateTime.now().toUtc().toIso8601String()}';
  }

  String? _firstActiveIncidentReference() {
    final active = _activeIncidentDispatchesByOpenedAt();
    if (active.isEmpty) {
      return null;
    }
    return active.first.key;
  }

  String _telegramAdminSnoozeCriticalCommand(String arguments) {
    const defaultMinutes = 30;
    const maxMinutes = 240;
    var minutes = defaultMinutes;
    final raw = arguments.trim();
    if (raw.isNotEmpty) {
      final parsed = int.tryParse(raw);
      if (parsed == null || parsed < 1) {
        return 'ONYX SNOOZECRITICAL\nInvalid minutes "$raw". Use /snoozecritical 30';
      }
      minutes = parsed > maxMinutes ? maxMinutes : parsed;
    }
    final until = DateTime.now().toUtc().add(Duration(minutes: minutes));
    _telegramAdminCriticalSnoozedUntilUtc = until;
    return '<b>ONYX SNOOZECRITICAL</b>\n'
        '⏸️ <b>Critical reminders paused</b> for $minutes minute(s).\n'
        'Until: ${until.toIso8601String()}';
  }

  String _telegramAdminUnsnoozeCriticalCommand() {
    _telegramAdminCriticalSnoozedUntilUtc = null;
    return '<b>ONYX UNSNOOZECRITICAL</b>\n'
        '▶️ <b>Critical reminders resumed.</b>\n'
        'UTC: ${DateTime.now().toUtc().toIso8601String()}';
  }

  String _telegramAdminAckCriticalCommand() {
    final critical = _telegramAdminCriticalAlerts();
    if (critical.isEmpty) {
      _telegramAdminCriticalAckFingerprint = '';
      _telegramAdminCriticalAckAtUtc = null;
      return 'ONYX ACKCRITICAL\nNo active critical alerts to acknowledge.\nUTC: ${DateTime.now().toUtc().toIso8601String()}';
    }
    _telegramAdminCriticalAckFingerprint = _telegramAdminCriticalFingerprint(
      critical,
    );
    _telegramAdminCriticalAckAtUtc = DateTime.now().toUtc();
    return '<b>ONYX ACKCRITICAL</b>\n'
        '✅ <b>Current critical state acknowledged.</b>\n'
        'Auto critical pushes paused until /unackcritical (or critical clears).\n'
        'Acked at: ${_telegramAdminCriticalAckAtUtc!.toIso8601String()}';
  }

  String _telegramAdminUnackCriticalCommand() {
    _telegramAdminCriticalAckFingerprint = '';
    _telegramAdminCriticalAckAtUtc = null;
    return '<b>ONYX UNACKCRITICAL</b>\n'
        '🔔 <b>Critical acknowledgement cleared.</b>\n'
        'UTC: ${DateTime.now().toUtc().toIso8601String()}';
  }

  String _telegramAdminIncidentsSnapshot() {
    final active = _activeIncidentDispatchesByOpenedAt();
    if (active.isEmpty) {
      return 'ONYX INCIDENTS\nNo active incidents.\nUTC: ${DateTime.now().toUtc().toIso8601String()}';
    }
    final nowUtc = DateTime.now().toUtc();
    final lines = active
        .take(8)
        .map((entry) {
          final ageMinutes = nowUtc.difference(entry.value).inMinutes;
          final ageLabel = ageMinutes < 1 ? '<1m' : '${ageMinutes}m';
          return '${entry.key} • age $ageLabel';
        })
        .join('\n- ');
    final extra = active.length > 8 ? '\n... +${active.length - 8} more' : '';
    return 'ONYX INCIDENTS\n- $lines$extra\nUTC: ${nowUtc.toIso8601String()}';
  }

  String _telegramAdminIncidentSnapshotCommand(String arguments) {
    final query = arguments.trim();
    final nowUtc = DateTime.now().toUtc();
    if (query.isEmpty) {
      final active = _activeIncidentDispatchesByOpenedAt();
      final sample = active
          .take(5)
          .map((entry) => entry.key)
          .toList(growable: false);
      final sampleLabel = sample.isEmpty ? 'none' : sample.join(', ');
      return 'ONYX INCIDENT\nUsage: /incident <dispatch_id>\nActive samples: $sampleLabel';
    }
    final queryUpper = query.toUpperCase();
    bool matches(String dispatchId) {
      return dispatchId.trim().toUpperCase() == queryUpper;
    }

    String? dispatchId;
    DateTime? openedAtUtc;
    DateTime? arrivedAtUtc;
    DateTime? closedAtUtc;
    String? closeType;
    DateTime? executionCompletedAtUtc;
    DateTime? executionDeniedAtUtc;

    for (final event in store.allEvents()) {
      if (event is DecisionCreated) {
        if (!matches(event.dispatchId)) continue;
        dispatchId ??= event.dispatchId.trim();
        final occurred = event.occurredAt.toUtc();
        if (openedAtUtc == null || occurred.isBefore(openedAtUtc)) {
          openedAtUtc = occurred;
        }
      } else if (event is ResponseArrived) {
        if (!matches(event.dispatchId)) continue;
        dispatchId ??= event.dispatchId.trim();
        final occurred = event.occurredAt.toUtc();
        if (arrivedAtUtc == null || occurred.isBefore(arrivedAtUtc)) {
          arrivedAtUtc = occurred;
        }
      } else if (event is IncidentClosed) {
        if (!matches(event.dispatchId)) continue;
        dispatchId ??= event.dispatchId.trim();
        final occurred = event.occurredAt.toUtc();
        if (closedAtUtc == null || occurred.isBefore(closedAtUtc)) {
          closedAtUtc = occurred;
          closeType = event.resolutionType.trim();
        }
      } else if (event is ExecutionCompleted) {
        if (!matches(event.dispatchId)) continue;
        dispatchId ??= event.dispatchId.trim();
        final occurred = event.occurredAt.toUtc();
        if (executionCompletedAtUtc == null ||
            occurred.isAfter(executionCompletedAtUtc)) {
          executionCompletedAtUtc = occurred;
        }
      } else if (event is ExecutionDenied) {
        if (!matches(event.dispatchId)) continue;
        dispatchId ??= event.dispatchId.trim();
        final occurred = event.occurredAt.toUtc();
        if (executionDeniedAtUtc == null ||
            occurred.isAfter(executionDeniedAtUtc)) {
          executionDeniedAtUtc = occurred;
        }
      }
    }

    if (dispatchId == null) {
      return 'ONYX INCIDENT\nDispatch not found: $query';
    }

    String incidentStatus;
    if (closedAtUtc != null) {
      incidentStatus = 'closed';
    } else if (arrivedAtUtc != null) {
      incidentStatus = 'on_site';
    } else if (openedAtUtc != null) {
      incidentStatus = 'open';
    } else {
      incidentStatus = 'unknown';
    }

    String executionStatus;
    if (executionCompletedAtUtc != null) {
      executionStatus = 'completed';
    } else if (executionDeniedAtUtc != null) {
      executionStatus = 'denied';
    } else {
      executionStatus = 'pending';
    }

    final ageLabel = openedAtUtc == null
        ? 'n/a'
        : '${nowUtc.difference(openedAtUtc).inMinutes}m';
    return 'ONYX INCIDENT\n'
        'Dispatch: $dispatchId\n'
        'Status: $incidentStatus\n'
        'Execution: $executionStatus\n'
        'Age: $ageLabel\n'
        'Opened: ${openedAtUtc?.toIso8601String() ?? 'n/a'}\n'
        'Arrived: ${arrivedAtUtc?.toIso8601String() ?? 'n/a'}\n'
        'Closed: ${closedAtUtc?.toIso8601String() ?? 'n/a'}\n'
        'Resolution: ${(closeType == null || closeType.isEmpty) ? 'n/a' : closeType}\n'
        'UTC: ${nowUtc.toIso8601String()}';
  }

  List<MapEntry<String, DateTime>> _activeIncidentDispatchesByOpenedAt() {
    final events = store.allEvents();
    final decisionByDispatch = <String, DateTime>{};
    final closedDispatchIds = <String>{};
    for (final event in events) {
      if (event is DecisionCreated) {
        final dispatchId = event.dispatchId.trim();
        if (dispatchId.isEmpty) continue;
        final occurredAt = event.occurredAt.toUtc();
        final existing = decisionByDispatch[dispatchId];
        if (existing == null || occurredAt.isBefore(existing)) {
          decisionByDispatch[dispatchId] = occurredAt;
        }
      } else if (event is IncidentClosed) {
        final dispatchId = event.dispatchId.trim();
        if (dispatchId.isNotEmpty) {
          closedDispatchIds.add(dispatchId);
        }
      }
    }
    final active =
        decisionByDispatch.entries
            .where((entry) => !closedDispatchIds.contains(entry.key))
            .toList(growable: false)
          ..sort((a, b) => a.value.compareTo(b.value));
    return active;
  }

  String _telegramAdminWhoAmISnapshot(TelegramBridgeInboundMessage update) {
    final userIdLabel = update.fromUserId?.toString() ?? 'unknown';
    final usernameLabel = update.fromUsername?.trim().isNotEmpty == true
        ? '@${update.fromUsername!.trim()}'
        : 'unknown';
    final threadLabel = update.messageThreadId?.toString() ?? 'none';
    return 'ONYX WHOAMI\n'
        'user_id: $userIdLabel\n'
        'username: $usernameLabel\n'
        'chat_id: ${update.chatId}\n'
        'thread_id: $threadLabel\n'
        'Set ONYX_TELEGRAM_ADMIN_ALLOWED_USER_IDS=$userIdLabel to lock admin commands to this user.';
  }

  List<String> _telegramAdminCriticalAlerts() {
    final critical = <String>[];
    final queueThreshold = _positiveThreshold(
      _guardQueuePressureAlertThresholdEnv,
      fallback: 25,
    );
    final failedThreshold = _positiveThreshold(
      _guardFailureAlertThresholdEnv,
      fallback: 1,
    );
    if (_telegramBridgeHealthLabel.toLowerCase() == 'blocked') {
      critical.add('Telegram bridge blocked.');
    }
    if (_telegramBridgeHealthLabel.toLowerCase() == 'degraded') {
      critical.add('Telegram bridge degraded.');
    }
    if (_guardTelemetryLiveReadyGateViolated) {
      critical.add(
        'Guard telemetry live-ready gate violation: $_guardTelemetryLiveReadyGateReason.',
      );
    }
    if (_guardSyncQueueDepth >= queueThreshold) {
      critical.add(
        'Guard sync queue pressure high: $_guardSyncQueueDepth >= $queueThreshold.',
      );
    }
    if (_guardOpsFailedEvents >= failedThreshold ||
        _guardOpsFailedMedia >= failedThreshold) {
      critical.add(
        'Guard ops failures high: events=$_guardOpsFailedEvents media=$_guardOpsFailedMedia.',
      );
    }
    if (_clientAppPushSyncStatusLabel.trim().toLowerCase() == 'failed') {
      critical.add(
        'Client push sync failed: ${(_clientAppPushSyncFailureReason ?? 'unknown reason').trim()}',
      );
    }
    return critical;
  }

  String _telegramAdminCriticalSnapshot() {
    final critical = _telegramAdminCriticalAlerts();
    final events = store.allEvents();
    final activeIncidents = _activeIncidentCount(events);
    final pendingActions = _pendingAiActionCount(events);
    final guardsOnline = _guardsOnlineCount(events);
    final queueThreshold = _positiveThreshold(
      _guardQueuePressureAlertThresholdEnv,
      fallback: 25,
    );
    final bridgeWarning =
        _telegramBridgeHealthLabel.toLowerCase() == 'degraded' ||
        _telegramBridgeHealthLabel.toLowerCase() == 'blocked';
    final hasWarningSignal =
        bridgeWarning ||
        _clientAppPushSyncStatusLabel.trim().toLowerCase() == 'failed' ||
        pendingActions > 0;
    final posture = critical.isNotEmpty
        ? 'RED'
        : (hasWarningSignal ? 'AMBER' : 'GREEN');
    final postureEmoji = switch (posture) {
      'RED' => '🔴',
      'AMBER' => '🟠',
      _ => '🟢',
    };
    final actionHint = _telegramAdminPrimaryActionHint(
      criticalCount: critical.length,
      pendingActions: pendingActions,
      queueThreshold: queueThreshold,
    );
    if (critical.isEmpty) {
      return '🛡️ <b>ONYX CRITICAL</b>\n\n'
          '<b>Posture:</b> $postureEmoji <b>${_telegramHtmlEscape(posture)}</b>\n'
          '<b>Active Critical Alerts:</b> <b>0</b>\n\n'
          '---\n\n'
          '<b>Top Risk</b>\n'
          'None\n\n'
          '---\n\n'
          '<b>Operations Status</b>\n\n'
          '• <b>Guards Online:</b> $guardsOnline\n'
          '• <b>Incidents:</b> $activeIncidents\n'
          '• <b>Pending Replies:</b> $pendingActions\n\n'
          '---\n\n'
          '<b>Recommended Action</b>\n'
          'Run: <b>/ops</b>\n\n'
          '---\n\n'
          '<b>Target</b>\n\n'
          '<b>Client:</b> ${_telegramHtmlEscape(_telegramAdminTargetClientId)}\n'
          '<b>Site:</b> ${_telegramHtmlEscape(_telegramAdminTargetSiteId)}\n\n'
          'UTC: ${_telegramUtcStamp()}';
    }
    final topRisk = _telegramHtmlEscape(_singleLine(critical.first));
    return '🚨 <b>ONYX CRITICAL</b>\n\n'
        '<b>Posture:</b> $postureEmoji <b>${_telegramHtmlEscape(posture)}</b>\n'
        '<b>Active Critical Alerts:</b> <b>${critical.length}</b>\n\n'
        '---\n\n'
        '<b>Top Risk</b>\n'
        '$topRisk\n\n'
        '---\n\n'
        '<b>Operations Status</b>\n\n'
        '• <b>Guards Online:</b> $guardsOnline\n'
        '• <b>Incidents:</b> $activeIncidents\n'
        '• <b>Pending Replies:</b> $pendingActions\n\n'
        '---\n\n'
        '<b>Recommended Action</b>\n'
        'Run: <b>${_telegramHtmlEscape(_telegramAdminRecommendedCommand(actionHint))}</b>\n\n'
        '---\n\n'
        '<b>Target</b>\n\n'
        '<b>Client:</b> ${_telegramHtmlEscape(_telegramAdminTargetClientId)}\n'
        '<b>Site:</b> ${_telegramHtmlEscape(_telegramAdminTargetSiteId)}\n\n'
        'UTC: ${_telegramUtcStamp()}';
  }

  String _telegramAdminRecommendedCommand(String actionHint) {
    final lower = actionHint.toLowerCase();
    if (lower.contains('/syncguards')) return '/syncguards';
    if (lower.contains('/pollops')) return '/pollops';
    if (lower.contains('/bridges')) return '/bridges';
    if (lower.contains('/critical')) return '/critical short';
    if (lower.contains('/guards')) return '/guards';
    if (lower.contains('/ops')) return '/ops';
    return '/next';
  }

  String _telegramAdminCriticalCommand(String arguments) {
    final mode = arguments.trim().toLowerCase();
    if (mode == 'short' || mode == 'brief' || mode == 'compact') {
      return _telegramAdminCriticalShortSnapshot();
    }
    return _telegramAdminCriticalSnapshot();
  }

  String _telegramAdminCriticalShortSnapshot() {
    final critical = _telegramAdminCriticalAlerts();
    if (critical.isEmpty) {
      return '<b>ONYX CRITICAL (SHORT)</b>\n'
          '🟢 <b>Critical:</b> none\n'
          '• <b>Next:</b> monitor with brief/status.\n'
          'UTC: ${DateTime.now().toUtc().toIso8601String()}';
    }
    final top = _singleLine(critical.first, maxLength: 140);
    return '<b>ONYX CRITICAL (SHORT)</b>\n'
        '🔴 <b>Critical:</b> ${critical.length} active\n'
        '• <b>Top:</b> ${_telegramHtmlEscape(top)}\n'
        '• <b>Next:</b> /ackcritical | /snoozecritical 30 | /next\n'
        'UTC: ${DateTime.now().toUtc().toIso8601String()}';
  }

  String _telegramAdminCriticalFingerprint(List<String> critical) {
    if (critical.isEmpty) {
      return '';
    }
    String normalize(String value) {
      final normalized = value.trim().toLowerCase();
      if (normalized.startsWith('guard ops failures high:')) {
        return 'guard_ops_failures_high';
      }
      if (normalized.startsWith('guard sync queue pressure high:')) {
        return 'guard_sync_queue_pressure_high';
      }
      if (normalized.startsWith('guard telemetry live-ready gate violation:')) {
        return normalized.replaceAll(RegExp(r'\s+'), ' ');
      }
      if (normalized.startsWith('client push sync failed:')) {
        return 'client_push_sync_failed';
      }
      if (normalized == 'telegram bridge degraded.') {
        return 'telegram_bridge_degraded';
      }
      if (normalized == 'telegram bridge blocked.') {
        return 'telegram_bridge_blocked';
      }
      return normalized.replaceAll(RegExp(r'\d+'), '#');
    }

    final tokens =
        critical
            .map(normalize)
            .where((entry) => entry.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();
    return tokens.join('|');
  }

  Future<void> _maybeSendTelegramAdminCriticalDigest({
    required String source,
    bool force = false,
  }) async {
    if (!_telegramAdminCriticalPushEnabled ||
        _telegramAdminCriticalPushInFlight) {
      return;
    }
    final adminChatId = _resolvedTelegramAdminChatId();
    if (adminChatId.isEmpty) {
      return;
    }
    final now = DateTime.now().toUtc();
    const quietAfterCommandSeconds = 45;
    final lastCommandAt = _telegramAdminLastCommandAtUtc;
    if (!force &&
        lastCommandAt != null &&
        now.difference(lastCommandAt).inSeconds < quietAfterCommandSeconds) {
      return;
    }
    final lastAttemptAt = _telegramAdminLastCriticalPushAttemptAtUtc;
    if (!force &&
        lastAttemptAt != null &&
        now.difference(lastAttemptAt).inSeconds < 10) {
      return;
    }
    final critical = _telegramAdminCriticalAlerts();
    final fingerprint = _telegramAdminCriticalFingerprint(critical);
    final hasCritical = critical.isNotEmpty;
    if (!hasCritical &&
        _telegramAdminCriticalAckAtUtc != null &&
        !force &&
        _telegramAdminCriticalAckFingerprint.isNotEmpty) {
      _telegramAdminCriticalAckFingerprint = '';
      _telegramAdminCriticalAckAtUtc = null;
      unawaited(_persistTelegramAdminRuntimeState());
    }
    final criticalAckSticky =
        hasCritical && !force && _telegramAdminCriticalAckAtUtc != null;
    final criticalAcked =
        hasCritical &&
        !force &&
        _telegramAdminCriticalAckFingerprint.isNotEmpty &&
        _telegramAdminCriticalAckFingerprint == fingerprint;
    if (criticalAckSticky || criticalAcked) {
      return;
    }
    final snoozedUntil = _telegramAdminCriticalSnoozedUntilUtc;
    final reminderSnoozed =
        hasCritical &&
        !force &&
        snoozedUntil != null &&
        now.isBefore(snoozedUntil);
    if (reminderSnoozed) {
      return;
    }
    final hadCritical = _telegramAdminCriticalAlertFingerprint.isNotEmpty;
    final stateChanged = fingerprint != _telegramAdminCriticalAlertFingerprint;
    final reminderDue =
        hasCritical &&
        _telegramAdminLastCriticalAlertAtUtc != null &&
        now.difference(_telegramAdminLastCriticalAlertAtUtc!).inSeconds >=
            _normalizedTelegramAdminCriticalReminderSeconds;
    if (!force && !stateChanged && !reminderDue) {
      return;
    }
    if (!force && !hasCritical && !hadCritical) {
      return;
    }
    final summary = hasCritical
        ? 'active(${critical.length}) via $source'
        : 'cleared via $source';
    final signalHeader = _telegramAdminSignalHeader();
    final topCritical = hasCritical
        ? _singleLine(critical.first, maxLength: 140)
        : 'none';
    final moreCount = hasCritical && critical.length > 1
        ? critical.length - 1
        : 0;
    final text = hasCritical
        ? '<b>${_telegramHtmlEscape(signalHeader)}</b>\n'
              '<b>ONYX CRITICAL ALERT</b> [${_telegramHtmlEscape(source)}]\n'
              '🔴 <b>Critical:</b> ${critical.length} active\n'
              '• <b>Top:</b> ${_telegramHtmlEscape(topCritical)}\n'
              '${moreCount > 0 ? '• <b>Also:</b> +$moreCount more active critical(s)\n' : ''}'
              '• <b>Actions:</b> /critical short | Ack critical | Next 5\n'
              'UTC: ${now.toIso8601String()}'
        : '<b>${_telegramHtmlEscape(signalHeader)}</b>\n'
              '<b>ONYX CRITICAL CLEARED</b> [${_telegramHtmlEscape(source)}]\n'
              '🟢 No active critical alerts.\n'
              'UTC: ${now.toIso8601String()}';
    _telegramAdminCriticalPushInFlight = true;
    _telegramAdminLastCriticalPushAttemptAtUtc = now;
    final adminThreadId = _resolvedTelegramAdminThreadId();
    try {
      final result = await _telegramBridge.sendMessages(
        messages: <TelegramBridgeMessage>[
          TelegramBridgeMessage(
            messageKey:
                'tg-admin-critical-${now.microsecondsSinceEpoch}-${critical.length}',
            chatId: adminChatId,
            messageThreadId: adminThreadId,
            text: text,
            replyMarkup: _telegramAdminQuickReplyMarkup(),
            parseMode: 'HTML',
          ),
        ],
      );
      if (result.failedCount > 0) {
        final reason = result.failureReasonsByMessageKey.values
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .take(2)
            .join(' | ');
        final detail = reason.isEmpty
            ? 'Admin critical alert delivery failed.'
            : 'Admin critical alert delivery failed: $reason';
        if (mounted) {
          setState(() {
            _telegramBridgeHealthLabel = 'degraded';
            _telegramBridgeHealthDetail = detail;
            _telegramBridgeHealthUpdatedAtUtc = now;
          });
        }
        unawaited(_persistTelegramAdminRuntimeState());
        return;
      }
      _telegramAdminCriticalAlertFingerprint = fingerprint;
      _telegramAdminLastCriticalAlertAtUtc = now;
      _telegramAdminLastCriticalAlertSummary = summary;
      unawaited(_persistTelegramAdminRuntimeState());
    } catch (error) {
      if (mounted) {
        setState(() {
          _telegramBridgeHealthLabel = 'degraded';
          _telegramBridgeHealthDetail =
              'Admin critical alert delivery failed: $error';
          _telegramBridgeHealthUpdatedAtUtc = now;
        });
      }
      unawaited(_persistTelegramAdminRuntimeState());
    } finally {
      _telegramAdminCriticalPushInFlight = false;
    }
  }

  String _telegramAdminGuardSnapshot() {
    final events = store.allEvents();
    final guardsOnline = _guardsOnlineCount(events);
    final queueThreshold = _positiveThreshold(
      _guardQueuePressureAlertThresholdEnv,
      fallback: 25,
    );
    final failedWarn = _positiveThreshold(
      _guardFailedOpsWarnThresholdEnv,
      fallback: 1,
    );
    final syncStatus = (_guardOpsLastSyncLabel ?? 'pending').trim();
    return 'ONYX GUARDS\n'
        'Online: $guardsOnline\n'
        'Sync backend: ${_guardSyncUsingBackend ? 'supabase+fallback' : 'local-only'}\n'
        'Queue depth: $_guardSyncQueueDepth/$queueThreshold\n'
        'Pending ops: events=$_guardOpsPendingEvents media=$_guardOpsPendingMedia\n'
        'Failed ops: events=$_guardOpsFailedEvents media=$_guardOpsFailedMedia (warn=$failedWarn)\n'
        'Telemetry: ${_guardTelemetryReadiness.name} • gate=${_guardTelemetryLiveReadyGateViolated ? 'VIOLATION' : 'OK'}\n'
        'Last sync: $syncStatus\n'
        'UTC: ${DateTime.now().toUtc().toIso8601String()}';
  }

  String _telegramAdminBridgeSnapshot() {
    final radioConfigured = _opsIntegrationProfile.radio.configured;
    final wearableConfigured =
        _wearableProviderEnv.trim().isNotEmpty && _wearableBridgeUri != null;
    final pollLabel = _livePollingLabel ?? 'disabled';
    return TelegramAdminCommandFormatter.bridges(
      telegramStatus:
          _telegramBridgeHealthLabel.toUpperCase() +
          (_telegramBridgeHealthDetail == null
              ? ''
              : ' • $_telegramBridgeHealthDetail'),
      radioStatus:
          '${radioConfigured ? 'configured' : 'disabled'} • ${_radioQueueHealthSummary()}',
      cctvStatus: _cctvBridgeStatusSummary(),
      cctvHealth: _activeVideoProfile.configured
          ? _opsHealthSummary(_cctvOpsHealth)
          : null,
      cctvRecent: _activeVideoProfile.configured
          ? _cctvRecentSignalSummary(store.allEvents())
          : null,
      videoLabel: _activeVideoOpsLabel,
      wearableStatus: wearableConfigured ? 'configured' : 'disabled',
      livePollingLabel: pollLabel,
      utcStamp: DateTime.now().toUtc().toIso8601String(),
    );
  }

  String _composeOpsIntegrationPollSummary(
    List<_OpsIntegrationIngestResult> results,
  ) {
    final ok = results.where((entry) => entry.success).length;
    final failed = results.where((entry) => !entry.success && !entry.skipped);
    final skipped = results.where((entry) => entry.skipped).length;
    final labels = results
        .map((entry) => '${entry.summaryLabel}(${entry.detail})')
        .join(' • ');
    final failedLabel = failed.isEmpty ? '' : ' • fail ${failed.length}';
    final skippedLabel = skipped == 0 ? '' : ' • skip $skipped';
    return 'Ops poll • ok $ok/${results.length}$failedLabel$skippedLabel • $labels';
  }

  void _escalateIntelligence(IntelligenceReceived intel) {
    final created = service.escalateIntelligence(intel);
    setState(() {
      _lastIntakeStatus = created
          ? 'Manual dispatch created from intelligence ${intel.intelligenceId}.'
          : 'Dispatch already exists for intelligence ${intel.intelligenceId}.';
    });
  }

  Future<void> _probeNewsSource(String provider) async {
    setState(() {
      _newsSourceDiagnostics = _newsSourceDiagnostics
          .map(
            (entry) => entry.provider == provider
                ? NewsSourceDiagnostic(
                    provider: entry.provider,
                    status: 'probing...',
                    detail: 'Checking live response...',
                  )
                : entry,
          )
          .toList(growable: false);
      _lastIntakeStatus = 'Running news source probe for $provider...';
    });
    await _persistNewsSourceDiagnostics();
    final result = await _newsIntel.probeProvider(
      provider: provider,
      clientId: _selectedClient,
      regionId: _selectedRegion,
      siteId: _selectedSite,
    );
    if (!mounted) return;
    setState(() {
      _newsSourceDiagnostics = _newsSourceDiagnostics
          .map((entry) => entry.provider == provider ? result : entry)
          .toList(growable: false);
      _lastIntakeStatus = switch (result.status) {
        'probe failed' =>
          'News source probe failed for ${result.provider}: ${result.detail}',
        'reachable' =>
          'News source probe reached ${result.provider}: ${result.detail}',
        'reachable-empty' =>
          'News source probe reached ${result.provider} with no items: ${result.detail}',
        'unsupported' =>
          'News source probe is unsupported for ${result.provider}.',
        _ => 'News source probe ${result.status} for ${result.provider}.',
      };
    });
    await _persistNewsSourceDiagnostics();
  }

  Future<void> _startLiveFeedPolling() async {
    final endpoint = _liveFeedPollEndpoint;
    if (endpoint.isEmpty) {
      setState(() {
        _lastIntakeStatus =
            OnyxRuntimeConfig.hasPlaceholderLiveFeedUrl(_liveFeedPollUrl)
            ? 'Live feed polling is using the example ONYX_LIVE_FEED_URL placeholder. Replace it with a real endpoint.'
            : 'Live feed polling requires ONYX_LIVE_FEED_URL to be configured.';
      });
      return;
    }
    if (_livePolling) {
      return;
    }

    final intervalSeconds = _normalizedPollIntervalSeconds;
    setState(() {
      _livePolling = true;
      _livePollFailures = 0;
      _livePollDelaySeconds = intervalSeconds;
      _lastLivePollError = null;
      _pushLivePollingHistory(
        'Polling started • every ${intervalSeconds}s • $endpoint',
      );
      _lastIntakeStatus =
          'Live feed polling started ($intervalSeconds s) from $endpoint';
    });

    _scheduleNextLivePoll(intervalSeconds);
    await _pollLiveFeedOnce();
  }

  void _stopLiveFeedPolling({String? statusMessage}) {
    if (!_livePolling) {
      return;
    }
    _livePollTimer?.cancel();
    _livePollTimer = null;
    setState(() {
      _livePolling = false;
      _livePollRequestInFlight = false;
      _livePollDelaySeconds = 0;
      _lastLivePollError = null;
      _pushLivePollingHistory(statusMessage ?? 'Polling stopped');
      _lastIntakeStatus = statusMessage ?? 'Live feed polling stopped.';
    });
  }

  Future<void> _pollLiveFeedOnce() async {
    if (!_livePolling || _livePollRequestInFlight) {
      return;
    }

    final endpoint = _liveFeedPollEndpoint;
    if (endpoint.isEmpty) {
      _stopLiveFeedPolling();
      return;
    }

    if (mounted) {
      setState(() {
        _livePollRequestInFlight = true;
      });
    } else {
      _livePollRequestInFlight = true;
    }
    final stopwatch = Stopwatch()..start();
    try {
      final response = await http.get(
        Uri.parse(endpoint),
        headers: _liveFeedPollHeaders,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw FormatException('HTTP ${response.statusCode}');
      }

      final parsed = _liveFeeds.parseJson(response.body);
      final runId = _nextRunId('POLL');
      _recordLiveIngest(
        runId: runId,
        batch: LiveFeedBatch(
          records: parsed.records,
          feedDistribution: parsed.feedDistribution,
          isConfigured: parsed.isConfigured,
          sourceLabel: 'polled endpoint',
        ),
      );
      if (mounted) {
        setState(() {
          _livePollFailures = 0;
          _livePollDelaySeconds = _normalizedPollIntervalSeconds;
          _lastLivePollLatencyMs = stopwatch.elapsedMilliseconds;
          _lastLivePollSuccessAtUtc = DateTime.now().toUtc();
          _lastLivePollError = null;
          _pushLivePollingHistory(
            'OK • ${stopwatch.elapsedMilliseconds}ms • ${parsed.records.length} records',
          );
        });
      }
      _scheduleNextLivePoll(_normalizedPollIntervalSeconds);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final nextFailures = _livePollFailures + 1;
      if (nextFailures >= _maxConsecutiveLivePollFailures) {
        _stopLiveFeedPolling(
          statusMessage:
              'Live feed polling stopped after $_maxConsecutiveLivePollFailures consecutive failures.',
        );
        return;
      }
      final nextDelay = _backoffDelaySeconds(nextFailures);
      setState(() {
        _livePollFailures = nextFailures;
        _livePollDelaySeconds = nextDelay;
        _lastLivePollLatencyMs = stopwatch.elapsedMilliseconds;
        _lastLivePollFailureAtUtc = DateTime.now().toUtc();
        _lastLivePollError = error.toString();
        _pushLivePollingHistory(
          'FAIL • ${stopwatch.elapsedMilliseconds}ms • ${_truncatePollError(error.toString())}',
        );
        _lastIntakeStatus =
            'Live feed poll failed: $error • retrying in ${nextDelay}s';
      });
      _scheduleNextLivePoll(nextDelay);
    } finally {
      if (mounted) {
        setState(() {
          _livePollRequestInFlight = false;
        });
      } else {
        _livePollRequestInFlight = false;
      }
    }
  }

  IntelligenceIngestionOutcome _recordLiveIngest({
    required String runId,
    required LiveFeedBatch batch,
    bool updateStatus = true,
  }) {
    final outcome = service.ingestNormalizedIntelligence(
      records: batch.records,
      autoGenerateDispatches: true,
    );
    final siteDistribution = <String, int>{};
    for (final record in batch.records) {
      siteDistribution.update(
        record.siteId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    setState(() {
      if (updateStatus) {
        _lastIntakeStatus =
            'Ingested ${outcome.appendedIntelligence}/${outcome.attemptedIntelligence} intel from ${batch.feedCount} feeds (${batch.sourceLabel}) • '
            'Skipped ${outcome.skippedIntelligence} • '
            'Triage A/W/DC ${outcome.advisoryCount}/${outcome.watchCount}/${outcome.dispatchCandidateCount} • '
            'Auto-created ${outcome.createdDecisions} dispatch decisions';
      }
      _intakeTelemetry = _intakeTelemetry.add(
        label: runId,
        cancelled: false,
        sourceLabel: batch.sourceLabel,
        scenarioLabel: _currentScenarioLabel,
        tags: _currentScenarioTags,
        note: _currentRunNote,
        attempted: outcome.attemptedIntelligence,
        appended: outcome.appendedIntelligence,
        skipped: outcome.skippedIntelligence,
        decisions: outcome.createdDecisions,
        throughput: outcome.appendedIntelligence.toDouble(),
        p50Throughput: outcome.appendedIntelligence.toDouble(),
        p95Throughput: outcome.appendedIntelligence.toDouble(),
        verifyMs: 0,
        chunkSize: outcome.attemptedIntelligence,
        chunks: 1,
        avgChunkMs: 0,
        maxChunkMs: 0,
        slowChunks: 0,
        duplicatesInjected: 0,
        uniqueFeeds: batch.feedCount,
        peakPending: outcome.attemptedIntelligence,
        siteDistribution: siteDistribution,
        feedDistribution: batch.feedDistribution,
        burstSize: outcome.attemptedIntelligence,
      );
    });
    _persistTelemetry();
    return outcome;
  }

  Future<void> _bufferOfflineVideoIncidents(
    List<IntelligenceReceived> appendedEvents,
  ) async {
    if (widget.supabaseReady || appendedEvents.isEmpty) {
      return;
    }
    final service = await _offlineIncidentSpoolServiceFuture;
    var queued = 0;
    for (final event in appendedEvents) {
      if (!_matchesActiveVideoProviderEvent(event)) {
        continue;
      }
      await service.enqueue(
        incidentReference: event.intelligenceId,
        sourceType: event.sourceType,
        provider: event.provider,
        clientId: event.clientId,
        siteId: event.siteId,
        summary: event.headline,
        occurredAtUtc: event.occurredAt,
        payload: <String, Object?>{
          'external_id': event.externalId,
          'risk_score': event.riskScore,
          'canonical_hash': event.canonicalHash,
          'evidence_record_hash': event.evidenceRecordHash,
          'snapshot_reference_hash': event.snapshotReferenceHash,
          'clip_reference_hash': event.clipReferenceHash,
        },
      );
      queued += 1;
    }
    if (queued > 0) {
      await _hydrateOfflineIncidentSpoolState();
    }
  }

  LiveFeedBatch _buildDemoLiveFeedBatch(DateTime now) {
    final providerA = GenericFeedAdapter(providerName: 'watchtower');
    final providerB = GenericFeedAdapter(providerName: 'sentinelwire');

    final batchA = providerA.normalizeBatch([
      {
        'external_id': 'WT-OPS-${now.millisecondsSinceEpoch}',
        'client_id': _selectedClient,
        'region_id': _selectedRegion,
        'site_id': _selectedSite,
        'headline': 'High-risk perimeter breach signal',
        'summary': 'Thermal and access sensors indicate coordinated probe.',
        'risk_score': 88,
        'occurred_at_utc': now
            .subtract(const Duration(minutes: 4))
            .toIso8601String(),
      },
      {
        'external_id': 'WT-LOW-${now.millisecondsSinceEpoch}',
        'client_id': _selectedClient,
        'region_id': _selectedRegion,
        'site_id': _selectedSite,
        'headline': 'Routine patrol telemetry',
        'summary': 'Normal movement pattern on east corridor.',
        'risk_score': 42,
        'occurred_at_utc': now
            .subtract(const Duration(minutes: 3))
            .toIso8601String(),
      },
    ]);

    final batchB = providerB.normalizeBatch([
      {
        'external_id': 'SW-ALERT-${now.millisecondsSinceEpoch}',
        'client_id': _selectedClient,
        'region_id': _selectedRegion,
        'site_id': _selectedSite,
        'headline': 'Suspicious crowd convergence',
        'summary': 'Open-source signals flag potential escalation near gate.',
        'risk_score': 79,
        'occurred_at_utc': now
            .subtract(const Duration(minutes: 2))
            .toIso8601String(),
      },
      {
        'external_id': 'SW-MON-${now.millisecondsSinceEpoch}',
        'client_id': _selectedClient,
        'region_id': _selectedRegion,
        'site_id': _selectedSite,
        'headline': 'Transit flow update',
        'summary': 'Traffic normalization observed around sector 3.',
        'risk_score': 35,
        'occurred_at_utc': now
            .subtract(const Duration(minutes: 1))
            .toIso8601String(),
      },
    ]);

    return LiveFeedBatch(
      records: [...batchA, ...batchB],
      feedDistribution: {
        'watchtower': batchA.length,
        'sentinelwire': batchB.length,
      },
      isConfigured: false,
      sourceLabel: 'demo fallback',
    );
  }

  void _resetTelemetry() {
    setState(() {
      _intakeTelemetry = IntakeTelemetry.zero;
      _lastIntakeStatus = 'Telemetry reset.';
      _lastStressStatus = null;
    });
    _persistTelemetry();
  }

  void _clearTelemetryPersistence() {
    setState(() {
      _intakeTelemetry = IntakeTelemetry.zero;
      _livePollingHistory = const [];
      _lastLivePollLatencyMs = null;
      _lastLivePollSuccessAtUtc = null;
      _lastLivePollFailureAtUtc = null;
      _lastLivePollError = null;
      _livePollFailures = 0;
      _livePollDelaySeconds = 0;
      _lastIntakeStatus = 'Saved telemetry history cleared.';
      _lastStressStatus = null;
    });
    _persistenceServiceFuture.then((persistence) async {
      await persistence.clearTelemetry();
      await persistence.clearLivePollHistory();
      await persistence.clearLivePollSummary();
    });
  }

  void _clearLivePollHealth() {
    setState(() {
      _livePollingHistory = const [];
      _lastLivePollLatencyMs = null;
      _lastLivePollSuccessAtUtc = null;
      _lastLivePollFailureAtUtc = null;
      _lastLivePollError = null;
      _livePollFailures = 0;
      _livePollDelaySeconds = 0;
      _lastIntakeStatus = 'Saved poll health cleared.';
    });
    _persistenceServiceFuture.then((persistence) async {
      await persistence.clearLivePollHistory();
      await persistence.clearLivePollSummary();
    });
  }

  void _clearProfilePersistence() {
    setState(() {
      _currentStressProfile = IntakeStressPreset.medium.profile;
      _currentScenarioLabel = '';
      _currentScenarioTags = const [];
      _currentRunNote = '';
      _pinnedWatchIntelligenceIds = const [];
      _dismissedIntelligenceIds = const [];
      _showPinnedWatchIntelligenceOnly = false;
      _showDismissedIntelligenceOnly = false;
      _selectedIntelligenceId = '';
      _lastStressStatus = 'Saved stress draft cleared.';
    });
    _persistenceServiceFuture.then((persistence) async {
      await persistence.saveStressProfile(_currentProfileDraft());
    });
  }

  void _clearSavedViewsPersistence() {
    setState(() {
      _savedFilterPresets = const [];
      _lastStressStatus = 'Saved views cleared.';
    });
    _persistenceServiceFuture.then((persistence) async {
      await persistence.saveStressProfile(_currentProfileDraft());
    });
  }

  void _cancelStressRun() {
    if (!_stressRunning) return;
    setState(() {
      _stressCancelRequested = true;
      _lastStressStatus = 'Cancellation requested. Finishing current chunk...';
    });
  }

  Future<void> _runBenchmarkSuite() async {
    _stressCancelRequested = false;
    _lastStressStatus = 'Benchmark suite started (Light → Medium → Heavy)...';
    if (mounted) {
      setState(() {});
    }

    final suite = [
      IntakeStressPreset.light.profile,
      IntakeStressPreset.medium.profile,
      IntakeStressPreset.heavy.profile,
    ];

    for (int i = 0; i < suite.length; i++) {
      if (_stressCancelRequested) {
        if (mounted) {
          setState(() {
            _lastStressStatus = 'Benchmark suite cancelled.';
          });
        }
        break;
      }
      await _runStressIntake(suite[i]);
      if (!mounted) return;
      if ((_lastStressStatus ?? '').startsWith('Stress cancelled')) {
        setState(() {
          _lastStressStatus = 'Benchmark suite cancelled during step ${i + 1}.';
        });
        break;
      }
      setState(() {
        _lastStressStatus =
            'Benchmark step ${i + 1}/${suite.length} complete. ${_lastStressStatus ?? ''}';
      });
    }
  }

  Future<void> _runSoakIntake(IntakeStressProfile profile) async {
    final soakRuns = profile.soakRuns < 1 ? 1 : profile.soakRuns;
    final throughputSamples = <double>[];
    final verifySamples = <int>[];
    IntakeRunSummary? baseline;

    if (mounted) {
      setState(() {
        _lastStressStatus =
            'Soak started: $soakRuns repeated runs${profile.stopOnRegression ? ' • stop on regression enabled' : ''}...';
      });
    }

    for (int i = 0; i < soakRuns; i++) {
      if (_stressCancelRequested) {
        if (mounted) {
          setState(() {
            _lastStressStatus = 'Soak cancelled before run ${i + 1}.';
          });
        }
        break;
      }
      await _runStressIntake(profile.copyWith(soakRuns: 1));
      if (!mounted) return;
      final latest = _intakeTelemetry.recentRuns.isEmpty
          ? null
          : _intakeTelemetry.recentRuns.first;
      if (latest != null) {
        baseline ??= latest;
        throughputSamples.add(latest.throughput);
        verifySamples.add(latest.verifyMs);
      }
      if ((_lastStressStatus ?? '').startsWith('Stress cancelled')) {
        break;
      }
      final currentBaseline = baseline;
      if (profile.stopOnRegression &&
          currentBaseline != null &&
          latest != null &&
          shouldStopSoakOnRegression(
            baseline: currentBaseline,
            latest: latest,
            minThroughputDelta: -profile.regressionThroughputDrop.toDouble(),
            maxVerifyDeltaMs: profile.regressionVerifyIncreaseMs,
            maxPressureSeverity: profile.maxRegressionPressureSeverity,
            maxImbalanceSeverity: profile.maxRegressionImbalanceSeverity,
          )) {
        setState(() {
          _lastStressStatus =
              'Soak stopped early at run ${i + 1}/$soakRuns • regression detected '
              '(thr ${latest.throughput.toStringAsFixed(1)} vs ${currentBaseline.throughput.toStringAsFixed(1)}, '
              'verify ${latest.verifyMs} vs ${currentBaseline.verifyMs}, '
              'pressure ${latest.pressureSeverity}, imbalance ${(latest.imbalanceScore * 100).toStringAsFixed(0)}%)';
        });
        break;
      }
      setState(() {
        _lastStressStatus =
            'Soak step ${i + 1}/$soakRuns complete. ${_lastStressStatus ?? ''}';
      });
    }

    if (!mounted || throughputSamples.isEmpty) return;
    final throughputDrift = throughputSamples.length < 2
        ? 0.0
        : throughputSamples.last - throughputSamples.first;
    final verifyDrift = verifySamples.length < 2
        ? 0
        : verifySamples.last - verifySamples.first;

    setState(() {
      _intakeTelemetry = _intakeTelemetry.withSoakSummary(
        runs: throughputSamples.length,
        throughputDrift: throughputDrift,
        verifyDriftMs: verifyDrift,
      );
      _lastStressStatus =
          'Soak complete: ${throughputSamples.length}/$soakRuns runs • '
          'throughput drift ${throughputDrift >= 0 ? '+' : ''}${throughputDrift.toStringAsFixed(1)} ev/s • '
          'verify drift ${verifyDrift >= 0 ? '+' : ''}$verifyDrift ms';
    });
    _persistTelemetry();
  }

  Future<void> _runStressIntake(IntakeStressProfile profile) async {
    _lastStressProfile = profile;
    final runId = _nextRunId('STR');
    final maxAttemptedEvents = profile.maxAttemptedEvents;
    final eventsPerBurst = profile.feeds * profile.recordsPerFeed;
    final maxBursts = eventsPerBurst <= 0
        ? 1
        : (maxAttemptedEvents ~/ eventsPerBurst);
    final effectiveBursts = maxBursts < 1
        ? 1
        : (profile.bursts > maxBursts ? maxBursts : profile.bursts);

    setState(() {
      _stressRunning = true;
      _stressCancelRequested = false;
      _lastStressStatus =
          'Running $effectiveBursts/${profile.bursts} bursts x ${profile.feeds} feeds x ${profile.recordsPerFeed} records...';
    });

    try {
      final result = await stressService.run(
        profile: profile,
        runId: runId,
        clientId: _selectedClient,
        regionId: _selectedRegion,
        primarySiteId: _selectedSite,
        shouldCancel: () => _stressCancelRequested,
        onBurstProgress:
            ({
              required burstIndex,
              required effectiveBursts,
              required appendedTotal,
              required skippedTotal,
              required decisionsTotal,
              required peakPending,
              required slowChunks,
            }) async {
              if (!mounted) return;
              setState(() {
                _lastStressStatus =
                    'Burst ${burstIndex + 1}/$effectiveBursts • appended $appendedTotal • '
                    'skipped $skippedTotal • decisions $decisionsTotal • '
                    'qpeak $peakPending • slow chunks $slowChunks';
              });
            },
      );

      if (!mounted) return;
      setState(() {
        _lastStressStatus =
            '${result.cancelled ? 'Stress cancelled: ' : 'Stress complete: '}'
            'appended ${result.appendedTotal}/${result.attemptedTotal} intel, '
            'skipped ${result.skippedTotal}, created ${result.decisionsTotal} decisions, '
            '${result.throughput.toStringAsFixed(1)} events/sec '
            '(p50 ${result.p50.toStringAsFixed(1)}, p95 ${result.p95.toStringAsFixed(1)}) '
            '(avg chunk ${result.avgChunkMs.toStringAsFixed(1)} ms, max ${result.maxChunkMs} ms, '
            'slow ${result.slowChunks}, dup ${result.duplicatesInjected}, qpeak ${result.peakPending}, '
            '${profile.verifyReplay ? 'verify ${result.verifyMs} ms' : 'verify skipped'}) '
            '(${result.totalMs} ms)'
            '${effectiveBursts != profile.bursts ? ' • capped bursts to $effectiveBursts (max $maxAttemptedEvents events)' : ''}';
        _intakeTelemetry = _intakeTelemetry.add(
          label:
              '$runId F${profile.feeds}x${profile.recordsPerFeed}x${result.effectiveBursts} S${profile.siteSpread} M${profile.maxAttemptedEvents} C${profile.chunkSize} D${profile.duplicatePercent}% seed${profile.seed}${result.cancelled ? ' (cancelled)' : ''}',
          cancelled: result.cancelled,
          scenarioLabel: _currentScenarioLabel,
          tags: _currentScenarioTags,
          note: _currentRunNote,
          attempted: result.attemptedTotal,
          appended: result.appendedTotal,
          skipped: result.skippedTotal,
          decisions: result.decisionsTotal,
          throughput: result.throughput,
          p50Throughput: result.p50,
          p95Throughput: result.p95,
          verifyMs: result.verifyMs,
          chunkSize: profile.chunkSize,
          chunks: profile.chunkSize <= 0
              ? 0
              : (result.attemptedTotal / profile.chunkSize).ceil(),
          avgChunkMs: result.avgChunkMs,
          maxChunkMs: result.maxChunkMs,
          slowChunks: result.slowChunks,
          duplicatesInjected: result.duplicatesInjected,
          uniqueFeeds: profile.feeds,
          peakPending: result.peakPending,
          siteDistribution: result.siteDistribution,
          feedDistribution: result.feedDistribution,
          burstSize: result.attemptedTotal,
        );
      });
      _persistTelemetry();
    } finally {
      if (mounted) {
        setState(() {
          _stressRunning = false;
          _stressCancelRequested = false;
        });
      }
    }
  }

  Future<void> _rerunLastProfile() async {
    final profile = _lastStressProfile;
    if (profile == null) return;
    await _runStressIntake(profile);
  }

  void _seedDemoData() {
    final clientId = _selectedClient;
    final regionId = _selectedRegion;
    final siteId = _selectedSite;
    const guardId = 'GUARD-1';

    final now = DateTime.now().toUtc();

    for (int i = 0; i < 8; i++) {
      store.append(
        GuardCheckedIn(
          eventId: 'GCI-$i',
          sequence: 0,
          version: 1,
          occurredAt: now.subtract(Duration(hours: 8 - i)),
          guardId: guardId,
          clientId: clientId,
          regionId: regionId,
          siteId: siteId,
        ),
      );
    }

    for (int i = 0; i < 6; i++) {
      store.append(
        PatrolCompleted(
          eventId: 'PAT-$i',
          sequence: 0,
          version: 1,
          occurredAt: now.subtract(Duration(hours: 6 - i)),
          guardId: guardId,
          routeId: 'R1',
          clientId: clientId,
          regionId: regionId,
          siteId: siteId,
          durationSeconds: 600 + (i * 60),
        ),
      );
    }

    for (int i = 0; i < 5; i++) {
      final decisionTime = now.subtract(Duration(hours: 4 - i));
      final dispatchId = 'DSP-$i';

      store.append(
        DecisionCreated(
          eventId: 'DEC-$i',
          sequence: 0,
          version: 1,
          occurredAt: decisionTime,
          clientId: clientId,
          regionId: regionId,
          siteId: siteId,
          dispatchId: dispatchId,
        ),
      );

      final responseDelayMinutes = i.isEven ? 8 : 14;

      store.append(
        ResponseArrived(
          eventId: 'ARR-$i',
          sequence: 0,
          version: 1,
          occurredAt: decisionTime.add(Duration(minutes: responseDelayMinutes)),
          dispatchId: dispatchId,
          guardId: guardId,
          clientId: clientId,
          regionId: regionId,
          siteId: siteId,
        ),
      );

      store.append(
        IncidentClosed(
          eventId: 'CLOSE-$i',
          sequence: 0,
          version: 1,
          occurredAt: decisionTime.add(Duration(minutes: 25 + i * 3)),
          dispatchId: dispatchId,
          resolutionType: 'resolved',
          clientId: clientId,
          regionId: regionId,
          siteId: siteId,
        ),
      );
    }

    debugPrint('Seed complete. Event count: ${store.allEvents().length}');
  }

  @override
  Widget build(BuildContext context) {
    final events = store.allEvents();
    final modeHome = switch (_appMode) {
      OnyxAppMode.controller => AppShell(
        currentRoute: _route,
        onRouteChanged: (r) => setState(() {
          _cancelDemoAutopilot();
          _route = r;
          _eventsSourceFilter = '';
          _eventsProviderFilter = '';
          _eventsSelectedEventId = '';
          _eventsScopedEventIds = const <String>[];
        }),
        onIntelTickerTap: _focusEventsFromTickerItem,
        activeIncidentCount: _activeIncidentCount(events),
        aiActionCount: _pendingAiActionCount(events),
        guardsOnlineCount: _guardsOnlineCount(events),
        operatorLabel: service.operator.operatorId,
        complianceIssuesCount: _complianceIssuesCount(),
        tacticalSosAlerts: _tacticalSosAlerts(),
        intelTickerItems: _intelTickerItems(events),
        demoAutopilotStatusLabel: _demoAutopilotRunning
            ? 'Demo $_demoAutopilotCurrentStep/$_demoAutopilotTotalSteps • $_demoAutopilotFlowLabel${_demoAutopilotPaused ? ' • paused' : ''}${_demoAutopilotNextHopSeconds > 0 && _demoAutopilotNextRouteLabel.isNotEmpty && !_demoAutopilotPaused ? ' • next: $_demoAutopilotNextRouteLabel in $_demoAutopilotNextHopSeconds s' : ''}'
            : '',
        onStopDemoAutopilot: _demoAutopilotRunning
            ? _stopDemoAutopilotFromShell
            : null,
        onSkipDemoAutopilot: _demoAutopilotRunning
            ? _skipDemoAutopilotFromShell
            : null,
        onToggleDemoAutopilotPause: _demoAutopilotRunning
            ? _toggleDemoAutopilotPauseFromShell
            : null,
        demoAutopilotPaused: _demoAutopilotPaused,
        child: _buildPage(events),
      ),
      OnyxAppMode.guard => _buildGuardPage(),
      OnyxAppMode.client => _buildClientPage(events),
    };
    return MaterialApp(debugShowCheckedModeBanner: false, home: modeHome);
  }

  int _activeIncidentCount(List<DispatchEvent> events) {
    final decidedDispatchIds = events
        .whereType<DecisionCreated>()
        .map((event) => event.dispatchId.trim())
        .where((dispatchId) => dispatchId.isNotEmpty)
        .toSet();
    final closedDispatchIds = events
        .whereType<IncidentClosed>()
        .map((event) => event.dispatchId.trim())
        .where((dispatchId) => dispatchId.isNotEmpty)
        .toSet();
    return decidedDispatchIds.difference(closedDispatchIds).length;
  }

  List<OnyxIntelTickerItem> _intelTickerItems(List<DispatchEvent> events) {
    final nowUtc = DateTime.now().toUtc();
    const liveWindow = Duration(hours: 6);
    final rows = events.whereType<IntelligenceReceived>().toList(
      growable: false,
    )..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final liveRows = rows
        .where(
          (event) =>
              nowUtc.difference(event.occurredAt.toUtc()) >= Duration.zero &&
              nowUtc.difference(event.occurredAt.toUtc()) <= liveWindow,
        )
        .toList(growable: false);
    final sourceAllowList = <String>{
      'news',
      'hardware',
      'radio',
      'wearable',
      'community',
      'system',
    };
    final baseRows = liveRows.isNotEmpty ? liveRows : rows;
    final items = <OnyxIntelTickerItem>[
      ...baseRows
          .take(12)
          .where((event) => event.headline.trim().isNotEmpty)
          .map((event) {
            final sourceType = event.sourceType.trim().toLowerCase();
            return OnyxIntelTickerItem(
              id: event.intelligenceId,
              eventId: event.eventId,
              sourceType: sourceAllowList.contains(sourceType)
                  ? sourceType
                  : 'system',
              provider: event.provider,
              headline: event.headline.trim(),
              occurredAtUtc: event.occurredAt.toUtc(),
            );
          }),
    ];
    if (items.length < 8) {
      final diagnostics = _newsTickerDiagnostics();
      for (final item in diagnostics) {
        if (items.length >= 8) break;
        if (items.any((existing) => existing.id == item.id)) continue;
        items.add(item);
      }
    }
    if (items.isEmpty) {
      final intakeStatus = (_lastIntakeStatus ?? '').trim();
      final fallback = intakeStatus.isEmpty
          ? 'No live intelligence yet. Run Poll News in Administration.'
          : intakeStatus;
      items.add(
        OnyxIntelTickerItem(
          id: 'INT-SYS-FALLBACK',
          sourceType: 'system',
          provider: 'onyx',
          headline: fallback,
          occurredAtUtc: DateTime.now().toUtc(),
        ),
      );
    }
    return items.take(16).toList(growable: false);
  }

  List<OnyxIntelTickerItem> _newsTickerDiagnostics() {
    final configured = _newsIntel.configuredProviders.toSet();
    final items = <OnyxIntelTickerItem>[];
    for (final entry in _newsSourceDiagnostics) {
      final provider = entry.provider.trim();
      if (provider.isEmpty) continue;
      final status = entry.status.trim();
      if (configured.isNotEmpty &&
          !configured.contains(provider) &&
          status == 'missing') {
        continue;
      }
      final checkedAtUtc = DateTime.tryParse(entry.checkedAtUtc)?.toUtc();
      final headline = _newsDiagnosticTickerHeadline(entry);
      if (headline.isEmpty) continue;
      items.add(
        OnyxIntelTickerItem(
          id: 'INT-NEWS-DIAG-$provider',
          sourceType: 'news',
          provider: provider,
          headline: headline,
          occurredAtUtc: checkedAtUtc ?? DateTime.now().toUtc(),
        ),
      );
    }
    items.sort((a, b) => b.occurredAtUtc.compareTo(a.occurredAtUtc));
    return items;
  }

  String _newsDiagnosticTickerHeadline(NewsSourceDiagnostic diagnostic) {
    final status = diagnostic.status.trim();
    final detail = diagnostic.detail.trim();
    if (status.isEmpty && detail.isEmpty) {
      return '';
    }
    if (status.isEmpty) {
      return detail;
    }
    if (detail.isEmpty) {
      return 'Status: ${status.toUpperCase()}';
    }
    return '${status.toUpperCase()} • $detail';
  }

  void _focusEventsFromTickerItem(OnyxIntelTickerItem item) {
    _cancelDemoAutopilot();
    final source = _normalizeIntelSourceFilter(item.sourceType);
    final provider = _normalizeIntelProviderFilter(item.provider);
    final selectedEventId = _resolveTickerEventId(item);
    setState(() {
      _route = OnyxRoute.events;
      _eventsSourceFilter = source;
      _eventsProviderFilter = provider;
      _eventsSelectedEventId = selectedEventId ?? '';
      _eventsScopedEventIds = const <String>[];
    });
  }

  void _openOperationsFromAdminIncident(String incidentReference) {
    final ref = incidentReference.trim();
    if (ref.isEmpty) return;
    _cancelDemoAutopilot();
    setState(() {
      _operationsFocusIncidentReference = ref;
      _route = OnyxRoute.dashboard;
    });
  }

  void _openTacticalFromAdminIncident(String incidentReference) {
    final ref = incidentReference.trim();
    if (ref.isEmpty) return;
    _cancelDemoAutopilot();
    setState(() {
      _operationsFocusIncidentReference = ref;
      _route = OnyxRoute.tactical;
    });
  }

  void _openEventsFromAdminIncident(String incidentReference) {
    final ref = incidentReference.trim();
    if (ref.isEmpty) return;
    _cancelDemoAutopilot();
    setState(() {
      _eventsSourceFilter = '';
      _eventsProviderFilter = '';
      _eventsSelectedEventId = ref;
      _eventsScopedEventIds = const <String>[];
      _route = OnyxRoute.events;
    });
  }

  void _openEventsForEventId(String eventId) {
    final ref = eventId.trim();
    if (ref.isEmpty) return;
    _cancelDemoAutopilot();
    setState(() {
      _eventsSourceFilter = '';
      _eventsProviderFilter = '';
      _eventsSelectedEventId = ref;
      _eventsScopedEventIds = const <String>[];
      _route = OnyxRoute.events;
    });
  }

  void _openEventsForScopedEventIds(
    List<String> eventIds, {
    String? selectedEventId,
  }) {
    final scopedIds = eventIds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (scopedIds.isEmpty) return;
    final selected = (selectedEventId ?? '').trim();
    _cancelDemoAutopilot();
    setState(() {
      _eventsSourceFilter = '';
      _eventsProviderFilter = '';
      _eventsSelectedEventId =
          selected.isNotEmpty && scopedIds.contains(selected)
          ? selected
          : scopedIds.first;
      _eventsScopedEventIds = scopedIds;
      _route = OnyxRoute.events;
    });
  }

  void _openEventsForVehicleVisit(
    SovereignReportVehicleVisitException exception,
  ) {
    final primaryEventId = exception.primaryEventId.trim();
    if (primaryEventId.isEmpty) {
      return;
    }
    _cancelDemoAutopilot();
    setState(() {
      _eventsSourceFilter = '';
      _eventsProviderFilter = '';
      _eventsSelectedEventId = primaryEventId;
      _eventsScopedEventIds = exception.eventIds
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
      _route = OnyxRoute.events;
    });
  }

  void _openLedgerFromAdminIncident(String incidentReference) {
    final ref = incidentReference.trim();
    if (ref.isEmpty) return;
    _cancelDemoAutopilot();
    setState(() {
      _operationsFocusIncidentReference = ref;
      _route = OnyxRoute.ledger;
    });
  }

  void _openGovernanceFromAdmin() {
    _cancelDemoAutopilot();
    setState(() {
      _governancePartnerScopeClientId = '';
      _governancePartnerScopeSiteId = '';
      _governancePartnerScopePartnerLabel = '';
      _route = OnyxRoute.governance;
    });
  }

  void _openGovernanceForPartnerScope(
    String clientId,
    String siteId,
    String partnerLabel,
  ) {
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId.trim();
    final normalizedPartnerLabel = partnerLabel.trim();
    if (normalizedClientId.isEmpty ||
        normalizedSiteId.isEmpty ||
        normalizedPartnerLabel.isEmpty) {
      _openGovernanceFromAdmin();
      return;
    }
    _cancelDemoAutopilot();
    setState(() {
      _governancePartnerScopeClientId = normalizedClientId;
      _governancePartnerScopeSiteId = normalizedSiteId;
      _governancePartnerScopePartnerLabel = normalizedPartnerLabel;
      _route = OnyxRoute.governance;
    });
  }

  void _openDispatchesFromAdmin() {
    _cancelDemoAutopilot();
    setState(() {
      _route = OnyxRoute.dispatches;
    });
  }

  void _openDispatchesFromAdminIncident(String incidentReference) {
    final ref = incidentReference.trim();
    if (ref.isEmpty) {
      _openDispatchesFromAdmin();
      return;
    }
    _cancelDemoAutopilot();
    setState(() {
      _operationsFocusIncidentReference = ref;
      _route = OnyxRoute.dispatches;
    });
  }

  String _latestIncidentReferenceForScope(String clientId, String siteId) {
    IntelligenceReceived? latest;
    for (final event in store.allEvents().whereType<IntelligenceReceived>()) {
      if (event.clientId != clientId || event.siteId != siteId) {
        continue;
      }
      if (latest == null || event.occurredAt.isAfter(latest.occurredAt)) {
        latest = event;
      }
    }
    return latest?.intelligenceId.trim() ?? '';
  }

  void _openTacticalForFleetScope(
    String clientId,
    String siteId, [
    String? latestIncidentReference,
  ]) {
    _cancelDemoAutopilot();
    final ref = latestIncidentReference?.trim().isNotEmpty == true
        ? latestIncidentReference!.trim()
        : _latestIncidentReferenceForScope(clientId, siteId);
    setState(() {
      _operationsFocusIncidentReference = ref;
      _route = OnyxRoute.tactical;
    });
  }

  void _openDispatchesForFleetScope(
    String clientId,
    String siteId, [
    String? latestIncidentReference,
  ]) {
    _cancelDemoAutopilot();
    final ref = latestIncidentReference?.trim().isNotEmpty == true
        ? latestIncidentReference!.trim()
        : _latestIncidentReferenceForScope(clientId, siteId);
    setState(() {
      _operationsFocusIncidentReference = ref;
      _route = OnyxRoute.dispatches;
    });
  }

  void _startDemoAutopilotFromAdminIncident(String incidentReference) {
    final ref = incidentReference.trim();
    if (ref.isEmpty) return;
    _startDemoAutopilot(
      incidentReference: ref,
      sequence: const [
        OnyxRoute.dashboard,
        OnyxRoute.tactical,
        OnyxRoute.dispatches,
      ],
      stepIntervalSeconds: 6,
      flowLabel: 'Quick Tour',
      title: 'Operations -> Tactical -> Dispatches',
      completionLabel: 'Dispatches focused on',
    );
  }

  void _startFullDemoAutopilotFromAdminIncident(String incidentReference) {
    final ref = incidentReference.trim();
    if (ref.isEmpty) return;
    _startDemoAutopilot(
      incidentReference: ref,
      sequence: const [
        OnyxRoute.dashboard,
        OnyxRoute.tactical,
        OnyxRoute.dispatches,
        OnyxRoute.events,
        OnyxRoute.ledger,
        OnyxRoute.governance,
        OnyxRoute.clients,
        OnyxRoute.reports,
      ],
      stepIntervalSeconds: 5,
      flowLabel: 'Full Tour',
      title:
          'Operations -> Tactical -> Dispatches -> Events -> Ledger -> Governance -> Clients -> Reports',
      completionLabel: 'Reports reached for',
    );
  }

  void _startDemoAutopilot({
    required String incidentReference,
    required List<OnyxRoute> sequence,
    required int stepIntervalSeconds,
    required String flowLabel,
    required String title,
    required String completionLabel,
  }) {
    if (sequence.isEmpty) return;
    final ref = incidentReference.trim();
    if (ref.isEmpty) return;
    _cancelDemoAutopilot();
    final firstRoute = sequence.first;
    setState(() {
      _demoAutopilotSequence = List<OnyxRoute>.of(sequence);
      _demoAutopilotStepIntervalSeconds = stepIntervalSeconds;
      _demoAutopilotIncidentReference = ref;
      _demoAutopilotCompletionLabel = completionLabel;
      _operationsFocusIncidentReference = ref;
      _route = firstRoute;
      _eventsSourceFilter = '';
      _eventsProviderFilter = '';
      _eventsSelectedEventId = firstRoute == OnyxRoute.events ? ref : '';
      _eventsScopedEventIds = const <String>[];
      _demoAutopilotRunning = true;
      _demoAutopilotPaused = false;
      _demoAutopilotCurrentStep = 1;
      _demoAutopilotTotalSteps = sequence.length;
      _demoAutopilotFlowLabel = flowLabel;
      _demoAutopilotNextHopSeconds = sequence.length > 1
          ? stepIntervalSeconds
          : 0;
      _demoAutopilotNextRouteLabel = sequence.length > 1
          ? _autopilotRouteLabel(sequence[1])
          : '';
    });
    if (sequence.length > 1) {
      _restartDemoAutopilotCountdownTicker();
      _scheduleDemoAutopilotRouteHop(delaySeconds: stepIntervalSeconds);
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F1419),
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Demo Autopilot started: $title ($ref)',
          style: GoogleFonts.inter(
            color: const Color(0xFFEAF4FF),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  void _cancelDemoAutopilot() {
    _demoAutopilotRouteTimer?.cancel();
    _demoAutopilotRouteTimer = null;
    _demoAutopilotCountdownTimer?.cancel();
    _demoAutopilotCountdownTimer = null;
    _demoAutopilotRunning = false;
    _demoAutopilotPaused = false;
    _demoAutopilotCurrentStep = 0;
    _demoAutopilotTotalSteps = 0;
    _demoAutopilotFlowLabel = '';
    _demoAutopilotNextHopSeconds = 0;
    _demoAutopilotNextRouteLabel = '';
    _demoAutopilotSequence = const [];
    _demoAutopilotStepIntervalSeconds = 0;
    _demoAutopilotIncidentReference = '';
    _demoAutopilotCompletionLabel = '';
  }

  void _scheduleDemoAutopilotRouteHop({required int delaySeconds}) {
    _demoAutopilotRouteTimer?.cancel();
    _demoAutopilotRouteTimer = null;
    if (!_demoAutopilotRunning || _demoAutopilotPaused || delaySeconds <= 0) {
      return;
    }
    _demoAutopilotRouteTimer = Timer(Duration(seconds: delaySeconds), () {
      _demoAutopilotRouteTimer = null;
      _advanceDemoAutopilotStep();
    });
  }

  void _advanceDemoAutopilotStep({bool showStepSnack = true}) {
    if (!mounted || !_demoAutopilotRunning || _demoAutopilotPaused) return;
    final nextIndex = _demoAutopilotCurrentStep;
    if (nextIndex < 0 || nextIndex >= _demoAutopilotSequence.length) {
      return;
    }
    final nextRoute = _demoAutopilotSequence[nextIndex];
    final isLast = nextIndex == _demoAutopilotSequence.length - 1;
    setState(() {
      _route = nextRoute;
      if (nextRoute == OnyxRoute.events) {
        _eventsSourceFilter = '';
        _eventsProviderFilter = '';
        _eventsSelectedEventId = _demoAutopilotIncidentReference;
        _eventsScopedEventIds = const <String>[];
      }
      _demoAutopilotCurrentStep = nextIndex + 1;
      if (!isLast) {
        _demoAutopilotNextHopSeconds = _demoAutopilotStepIntervalSeconds;
        _demoAutopilotNextRouteLabel = _autopilotRouteLabel(
          _demoAutopilotSequence[nextIndex + 1],
        );
      }
    });
    if (!isLast && showStepSnack) {
      _showDemoAutopilotStepSnack(
        step: _demoAutopilotCurrentStep,
        total: _demoAutopilotTotalSteps,
        route: nextRoute,
      );
    }
    if (isLast) {
      final completionLabel = _demoAutopilotCompletionLabel;
      final ref = _demoAutopilotIncidentReference;
      setState(() {
        _cancelDemoAutopilot();
      });
      final doneMessenger = ScaffoldMessenger.maybeOf(context);
      doneMessenger?.hideCurrentSnackBar();
      doneMessenger?.showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0F1419),
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Demo Autopilot complete: $completionLabel $ref',
            style: GoogleFonts.inter(
              color: const Color(0xFFEAF4FF),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
      return;
    }
    _restartDemoAutopilotCountdownTicker();
    _scheduleDemoAutopilotRouteHop(
      delaySeconds: _demoAutopilotStepIntervalSeconds,
    );
  }

  void _restartDemoAutopilotCountdownTicker() {
    _demoAutopilotCountdownTimer?.cancel();
    _demoAutopilotCountdownTimer = null;
    if (_demoAutopilotPaused ||
        !_demoAutopilotRunning ||
        _demoAutopilotNextHopSeconds <= 0) {
      return;
    }
    _demoAutopilotCountdownTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
      if (!mounted || !_demoAutopilotRunning) {
        timer.cancel();
        _demoAutopilotCountdownTimer = null;
        return;
      }
      if (_demoAutopilotNextHopSeconds <= 1) {
        setState(() {
          _demoAutopilotNextHopSeconds = 0;
        });
        timer.cancel();
        _demoAutopilotCountdownTimer = null;
        return;
      }
      setState(() {
        _demoAutopilotNextHopSeconds -= 1;
      });
    });
  }

  String _autopilotRouteLabel(OnyxRoute route) {
    return switch (route) {
      OnyxRoute.dashboard => 'Operations',
      OnyxRoute.aiQueue => 'AI Queue',
      OnyxRoute.tactical => 'Tactical',
      OnyxRoute.governance => 'Governance',
      OnyxRoute.clients => 'Clients',
      OnyxRoute.sites => 'Sites',
      OnyxRoute.guards => 'Guards',
      OnyxRoute.dispatches => 'Dispatches',
      OnyxRoute.events => 'Events',
      OnyxRoute.ledger => 'Ledger',
      OnyxRoute.reports => 'Reports',
      OnyxRoute.admin => 'Admin',
    };
  }

  String _autopilotRouteKey(OnyxRoute route) {
    return route.name.toLowerCase();
  }

  String _autopilotRouteNarration(OnyxRoute route) {
    final override = _demoRouteCueOverrides[_autopilotRouteKey(route)];
    if (override != null && override.trim().isNotEmpty) {
      return override.trim();
    }
    return switch (route) {
      OnyxRoute.dashboard => 'Action ladder and decision speed.',
      OnyxRoute.aiQueue => 'AI triage and intent ordering.',
      OnyxRoute.tactical => 'Verify units, geofence, and site posture.',
      OnyxRoute.governance => 'Show compliance and readiness controls.',
      OnyxRoute.clients => 'Client-facing confidence and communication lane.',
      OnyxRoute.sites => 'Deployment footprint and zone definitions.',
      OnyxRoute.guards => 'Field force state and sync health.',
      OnyxRoute.dispatches => 'Execute with focused dispatch context.',
      OnyxRoute.events => 'Replay immutable incident timeline.',
      OnyxRoute.ledger => 'Confirm evidence chain integrity.',
      OnyxRoute.reports => 'Demonstrate export and report proof.',
      OnyxRoute.admin => 'Demo seeding and runtime controls.',
    };
  }

  void _presentReportPreview(ReportPreviewRequest request) {
    if (!mounted) {
      return;
    }
    ReportPreviewController.handleRequest(
      context: context,
      request: request,
      shellState: _reportShellState,
      onReportShellStateChanged: (value) {
        _reportShellState = value;
      },
    );
  }

  void _showDemoAutopilotStepSnack({
    required int step,
    required int total,
    required OnyxRoute route,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F1419),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        content: Text(
          'Step $step/$total • ${_autopilotRouteLabel(route)}: ${_autopilotRouteNarration(route)}',
          style: GoogleFonts.inter(
            color: const Color(0xFFEAF4FF),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  void _toggleDemoAutopilotPauseFromShell() {
    if (!_demoAutopilotRunning) return;
    setState(() {
      _demoAutopilotPaused = !_demoAutopilotPaused;
      if (_demoAutopilotPaused) {
        _demoAutopilotRouteTimer?.cancel();
        _demoAutopilotRouteTimer = null;
        _demoAutopilotCountdownTimer?.cancel();
        _demoAutopilotCountdownTimer = null;
      } else {
        if (_demoAutopilotNextHopSeconds <= 0) {
          _demoAutopilotNextHopSeconds = _demoAutopilotStepIntervalSeconds;
        }
        _restartDemoAutopilotCountdownTicker();
        _scheduleDemoAutopilotRouteHop(
          delaySeconds: _demoAutopilotNextHopSeconds,
        );
      }
    });
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F1419),
        behavior: SnackBarBehavior.floating,
        content: Text(
          _demoAutopilotPaused
              ? 'Demo Autopilot paused.'
              : 'Demo Autopilot resumed.',
          style: GoogleFonts.inter(
            color: const Color(0xFFEAF4FF),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  void _skipDemoAutopilotFromShell() {
    if (!_demoAutopilotRunning) return;
    final nextIndex = _demoAutopilotCurrentStep;
    if (nextIndex < 0 || nextIndex >= _demoAutopilotSequence.length) return;
    final targetLabel = _autopilotRouteLabel(_demoAutopilotSequence[nextIndex]);
    _demoAutopilotRouteTimer?.cancel();
    _demoAutopilotRouteTimer = null;
    _demoAutopilotCountdownTimer?.cancel();
    _demoAutopilotCountdownTimer = null;
    setState(() {
      _demoAutopilotPaused = false;
    });
    _advanceDemoAutopilotStep(showStepSnack: false);
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F1419),
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Demo Autopilot skipped ahead to $targetLabel.',
          style: GoogleFonts.inter(
            color: const Color(0xFFEAF4FF),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  void _stopDemoAutopilotFromShell() {
    if (!_demoAutopilotRunning) return;
    setState(() {
      _cancelDemoAutopilot();
    });
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F1419),
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Demo Autopilot stopped.',
          style: GoogleFonts.inter(
            color: const Color(0xFFEAF4FF),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  void _openClientViewFromAdmin() {
    _cancelDemoAutopilot();
    setState(() {
      _route = OnyxRoute.clients;
    });
  }

  void _openReportsFromAdmin() {
    _cancelDemoAutopilot();
    setState(() {
      _reportsScopeClientId = '';
      _reportsScopeSiteId = '';
      _reportsScopePartnerLabel = '';
      _reportShellState = _reportShellState.copyWith(clearEntryContext: true);
      _route = OnyxRoute.reports;
    });
  }

  void _openReportsForPartnerScope(
    String clientId,
    String siteId,
    String partnerLabel,
  ) {
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId.trim();
    final normalizedPartnerLabel = partnerLabel.trim();
    if (normalizedClientId.isEmpty ||
        normalizedSiteId.isEmpty ||
        normalizedPartnerLabel.isEmpty) {
      _openReportsFromAdmin();
      return;
    }
    _cancelDemoAutopilot();
    setState(() {
      _reportsScopeClientId = normalizedClientId;
      _reportsScopeSiteId = normalizedSiteId;
      _reportsScopePartnerLabel = normalizedPartnerLabel;
      _reportShellState = _reportShellState.copyWith(clearEntryContext: true);
      _route = OnyxRoute.reports;
    });
  }

  void _openReportsForReceiptEvent(
    String clientId,
    String siteId,
    String receiptEventId,
  ) {
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId.trim();
    final normalizedReceiptEventId = receiptEventId.trim();
    if (normalizedClientId.isEmpty ||
        normalizedSiteId.isEmpty ||
        normalizedReceiptEventId.isEmpty) {
      _openReportsFromAdmin();
      return;
    }
    _cancelDemoAutopilot();
    setState(() {
      _reportsScopeClientId = normalizedClientId;
      _reportsScopeSiteId = normalizedSiteId;
      _reportsScopePartnerLabel = '';
      _reportShellState = _reportShellState.copyWith(
        selectedReceiptEventId: normalizedReceiptEventId,
        previewReceiptEventId: normalizedReceiptEventId,
        entryContext: ReportEntryContext.governanceBrandingDrift,
        clearPartnerScopeFocus: true,
      );
      _route = OnyxRoute.reports;
    });
  }

  List<TelegramAiPendingDraftView> _telegramAiPendingDraftViews() {
    return _telegramAiPendingDrafts
        .map(
          (draft) => TelegramAiPendingDraftView(
            updateId: draft.inboundUpdateId,
            audience: draft.audience,
            clientId: draft.clientId,
            siteId: draft.siteId,
            chatId: draft.chatId,
            messageThreadId: draft.messageThreadId,
            sourceText: draft.sourceText,
            draftText: draft.draftText,
            providerLabel: draft.providerLabel,
            createdAtUtc: draft.createdAtUtc,
          ),
        )
        .toList(growable: false);
  }

  Future<void> _setTelegramAiAssistantEnabledFromAdmin(bool enabled) async {
    if (_telegramAiAssistantEnabledOverride == enabled) {
      return;
    }
    if (mounted) {
      setState(() {
        _telegramAiAssistantEnabledOverride = enabled;
      });
    } else {
      _telegramAiAssistantEnabledOverride = enabled;
    }
    await _persistTelegramAdminRuntimeState();
    _startTelegramAdminControlLoop();
  }

  Future<void> _setTelegramAiApprovalRequiredFromAdmin(bool required) async {
    if (_telegramAiApprovalRequiredOverride == required) {
      return;
    }
    if (mounted) {
      setState(() {
        _telegramAiApprovalRequiredOverride = required;
      });
    } else {
      _telegramAiApprovalRequiredOverride = required;
    }
    await _persistTelegramAdminRuntimeState();
  }

  Future<String> _approveTelegramAiDraftFromAdmin(int updateId) async {
    final result = await _telegramAdminAiApproveCommand('$updateId');
    if (mounted) {
      setState(() {});
    }
    return result;
  }

  Future<String> _rejectTelegramAiDraftFromAdmin(int updateId) async {
    final result = _telegramAdminAiRejectCommand('$updateId');
    if (mounted) {
      setState(() {});
    }
    return result;
  }

  Future<String> _runAdminSiteTelegramChatcheck({
    required String clientId,
    String? siteId,
    required String chatId,
    int? threadId,
    required String endpointLabel,
  }) async {
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId?.trim() ?? '';
    final normalizedChatId = chatId.trim();
    final normalizedLabel = endpointLabel.trim().isEmpty
        ? 'Primary Site Telegram'
        : endpointLabel.trim();
    if (normalizedClientId.isEmpty || normalizedChatId.isEmpty) {
      return 'FAIL (missing client/chat scope)';
    }
    if (!widget.supabaseReady) {
      return 'SKIP (Supabase disabled)';
    }
    if (!_telegramBridge.isConfigured) {
      return 'SKIP (Telegram bridge not configured)';
    }
    try {
      final repository = SupabaseClientMessagingBridgeRepository(
        Supabase.instance.client,
      );
      final targets = await repository.readActiveTelegramTargets(
        clientId: normalizedClientId,
        siteId: normalizedSiteId.isEmpty ? null : normalizedSiteId,
      );
      final linked = targets.any(
        (target) =>
            target.chatId.trim() == normalizedChatId &&
            target.threadId == threadId,
      );
      final matchedEndpointIds = targets
          .where(
            (target) =>
                target.chatId.trim() == normalizedChatId &&
                target.threadId == threadId,
          )
          .map((target) => target.endpointId.trim())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);

      Future<void> persistEndpointChatcheck({
        required String status,
        String? error,
      }) async {
        if (matchedEndpointIds.isEmpty) return;
        final payload = <String, Object?>{
          'last_delivery_status': status,
          'last_error': (error ?? '').trim().isEmpty ? null : error!.trim(),
          'verified_at': DateTime.now().toUtc().toIso8601String(),
        };
        for (final endpointId in matchedEndpointIds) {
          await Supabase.instance.client
              .from('client_messaging_endpoints')
              .update(payload)
              .eq('client_id', normalizedClientId)
              .eq('id', endpointId);
        }
      }

      final message = TelegramBridgeMessage(
        messageKey:
            'admin-site-chatcheck-${DateTime.now().toUtc().millisecondsSinceEpoch}',
        chatId: normalizedChatId,
        messageThreadId: threadId,
        text:
            'ONYX chatcheck PASS probe • '
            '${normalizedSiteId.isEmpty ? '$normalizedClientId/default' : '$normalizedClientId/$normalizedSiteId'}'
            ' • $normalizedLabel',
      );
      final result = await _telegramBridge.sendMessages(messages: [message]);
      final deliveryOk = result.failedCount == 0;
      final reason =
          (result.failureReasonsByMessageKey[message.messageKey] ?? '').trim();
      if (deliveryOk) {
        if (linked) {
          await persistEndpointChatcheck(status: 'chatcheck_pass');
        }
        return linked
            ? 'PASS (linked + delivered)'
            : 'FAIL (delivered but endpoint not linked in scope)';
      }
      final blocked = _isTelegramBlockedReason(reason);
      final reasonSuffix = reason.isEmpty ? '' : ' • $reason';
      if (blocked) {
        if (linked) {
          await persistEndpointChatcheck(
            status: 'chatcheck_blocked',
            error: reason,
          );
        }
        return 'FAIL (delivery blocked$reasonSuffix)';
      }
      if (linked) {
        await persistEndpointChatcheck(status: 'chatcheck_fail', error: reason);
      }
      return 'FAIL (delivery error$reasonSuffix)';
    } catch (error) {
      return 'FAIL ($error)';
    }
  }

  Future<String> _bindAdminPartnerTelegramEndpoint({
    required String clientId,
    required String siteId,
    required String endpointLabel,
    required String chatId,
    int? threadId,
  }) async {
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId.trim();
    final normalizedChatId = chatId.trim();
    final normalizedLabel = _normalizePartnerEndpointLabel(endpointLabel);
    if (normalizedClientId.isEmpty ||
        normalizedSiteId.isEmpty ||
        normalizedChatId.isEmpty) {
      return 'FAIL (missing client/site/chat scope)';
    }
    if (!widget.supabaseReady) {
      return 'SKIP (Supabase disabled)';
    }
    try {
      final repository = SupabaseClientMessagingBridgeRepository(
        Supabase.instance.client,
      );
      await repository.upsertOnboardingSetup(
        ClientMessagingOnboardingSetup(
          clientId: normalizedClientId,
          siteId: normalizedSiteId,
          contactName: 'Partner Control',
          contactRole: 'response_partner',
          contactConsentConfirmed: false,
          provider: 'telegram',
          endpointLabel: normalizedLabel,
          telegramChatId: normalizedChatId,
          telegramThreadId: threadId?.toString(),
        ),
      );
      final targets = await repository.readActiveTelegramTargets(
        clientId: normalizedClientId,
        siteId: normalizedSiteId,
      );
      final partnerTargets = targets
          .where((target) => _isPartnerEndpointLabel(target.displayLabel))
          .toList(growable: false);
      return 'PASS (partner lane bound)\n'
          'scope=$normalizedClientId/$normalizedSiteId\n'
          'chat=$normalizedChatId${threadId == null ? '' : '#$threadId'}\n'
          'label=$normalizedLabel\n'
          'active_partner_endpoints=${partnerTargets.length}';
    } catch (error) {
      return 'FAIL ($error)';
    }
  }

  Future<String> _unlinkAdminPartnerTelegramEndpoint({
    required String clientId,
    required String siteId,
    required String chatId,
    int? threadId,
  }) async {
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId.trim();
    final normalizedChatId = chatId.trim();
    if (normalizedClientId.isEmpty ||
        normalizedSiteId.isEmpty ||
        normalizedChatId.isEmpty) {
      return 'FAIL (missing client/site/chat scope)';
    }
    if (!widget.supabaseReady) {
      return 'SKIP (Supabase disabled)';
    }
    try {
      final repository = SupabaseClientMessagingBridgeRepository(
        Supabase.instance.client,
      );
      final targets = await repository.readActiveTelegramTargets(
        clientId: normalizedClientId,
        siteId: normalizedSiteId,
      );
      final matching = targets
          .where(
            (target) =>
                _isPartnerEndpointLabel(target.displayLabel) &&
                target.chatId.trim() == normalizedChatId &&
                target.threadId == threadId,
          )
          .toList(growable: false);
      var deactivated = 0;
      for (final target in matching) {
        await Supabase.instance.client
            .from('client_messaging_endpoints')
            .update({
              'is_active': false,
              'last_delivery_status': 'partner_unlinked',
            })
            .eq('client_id', normalizedClientId)
            .eq('id', target.endpointId);
        deactivated += 1;
      }
      final remaining = (await repository.readActiveTelegramTargets(
        clientId: normalizedClientId,
        siteId: normalizedSiteId,
      )).where((target) => _isPartnerEndpointLabel(target.displayLabel)).length;
      return 'PASS (partner lane updated)\n'
          'scope=$normalizedClientId/$normalizedSiteId\n'
          'chat=$normalizedChatId${threadId == null ? '' : '#$threadId'}\n'
          'deactivated=$deactivated\n'
          'remaining_partner_endpoints=$remaining';
    } catch (error) {
      return 'FAIL ($error)';
    }
  }

  Future<String> _checkAdminPartnerTelegramEndpoint({
    required String clientId,
    required String siteId,
    required String chatId,
    int? threadId,
  }) async {
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId.trim();
    final normalizedChatId = chatId.trim();
    if (normalizedClientId.isEmpty ||
        normalizedSiteId.isEmpty ||
        normalizedChatId.isEmpty) {
      return 'FAIL (missing client/site/chat scope)';
    }
    if (!widget.supabaseReady) {
      return 'SKIP (Supabase disabled)';
    }
    try {
      final repository = SupabaseClientMessagingBridgeRepository(
        Supabase.instance.client,
      );
      final targets = await repository.readActiveTelegramTargets(
        clientId: normalizedClientId,
        siteId: normalizedSiteId,
      );
      final partnerTargets = targets
          .where((target) => _isPartnerEndpointLabel(target.displayLabel))
          .toList(growable: false);
      final matching = partnerTargets
          .where(
            (target) =>
                target.chatId.trim() == normalizedChatId &&
                target.threadId == threadId,
          )
          .toList(growable: false);
      final linked = matching.isNotEmpty;
      final rows = partnerTargets
          .take(4)
          .map((target) {
            final marker =
                target.chatId.trim() == normalizedChatId &&
                    target.threadId == threadId
                ? ' [current]'
                : '';
            return '- ${target.displayLabel} | chat=${target.chatId}${target.threadId == null ? '' : '#${target.threadId}'}$marker';
          })
          .join('\n');
      return '${linked ? 'PASS' : 'FAIL'} (${linked ? 'partner lane linked' : 'partner lane missing'})\n'
          'scope=$normalizedClientId/$normalizedSiteId\n'
          'current_chat=$normalizedChatId${threadId == null ? '' : '#$threadId'}\n'
          'matching_partner_endpoints=${matching.length}\n'
          'active_partner_endpoints=${partnerTargets.length}'
          '${rows.isEmpty ? '\n(no active partner targets configured)' : '\n$rows'}';
    } catch (error) {
      return 'FAIL ($error)';
    }
  }

  String _normalizeIntelSourceFilter(String sourceType) {
    var normalized = sourceType.trim().toUpperCase();
    if (normalized.isEmpty || normalized == 'ALL') {
      return '';
    }
    if (normalized == 'CCTV') {
      normalized = 'HARDWARE';
    } else if (normalized == 'DVR') {
      normalized = 'DVR';
    }
    const allowed = <String>{
      'NEWS',
      'HARDWARE',
      'RADIO',
      'WEARABLE',
      'COMMUNITY',
    };
    if (!allowed.contains(normalized)) {
      return '';
    }
    return normalized;
  }

  String _normalizeIntelProviderFilter(String provider) {
    final normalized = provider.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'all') {
      return '';
    }
    return normalized;
  }

  String? _resolveTickerEventId(OnyxIntelTickerItem item) {
    final direct = item.eventId?.trim() ?? '';
    if (direct.isNotEmpty) {
      return direct;
    }
    final tickerId = item.id.trim();
    if (tickerId.isEmpty) {
      return null;
    }
    for (final event in store.allEvents().whereType<IntelligenceReceived>()) {
      if (event.intelligenceId.trim() == tickerId) {
        return event.eventId;
      }
    }
    return null;
  }

  int _pendingAiActionCount(List<DispatchEvent> events) {
    final decidedDispatchIds = events
        .whereType<DecisionCreated>()
        .map((event) => event.dispatchId.trim())
        .where((dispatchId) => dispatchId.isNotEmpty)
        .toSet();
    final handledDispatchIds = <String>{
      ...events
          .whereType<ExecutionCompleted>()
          .map((event) => event.dispatchId.trim())
          .where((dispatchId) => dispatchId.isNotEmpty),
      ...events
          .whereType<ExecutionDenied>()
          .map((event) => event.dispatchId.trim())
          .where((dispatchId) => dispatchId.isNotEmpty),
    };
    return decidedDispatchIds.difference(handledDispatchIds).length;
  }

  int _guardsOnlineCount(List<DispatchEvent> events) {
    final windowStartUtc = DateTime.now().toUtc().subtract(
      const Duration(hours: 12),
    );
    final guardIds = <String>{
      ...events
          .whereType<GuardCheckedIn>()
          .where((event) => event.occurredAt.toUtc().isAfter(windowStartUtc))
          .map((event) => event.guardId.trim())
          .where((guardId) => guardId.isNotEmpty),
      ...events
          .whereType<ResponseArrived>()
          .where((event) => event.occurredAt.toUtc().isAfter(windowStartUtc))
          .map((event) => event.guardId.trim())
          .where((guardId) => guardId.isNotEmpty),
      ...events
          .whereType<PatrolCompleted>()
          .where((event) => event.occurredAt.toUtc().isAfter(windowStartUtc))
          .map((event) => event.guardId.trim())
          .where((guardId) => guardId.isNotEmpty),
      ..._guardOpsRecentEvents
          .where((event) => event.occurredAt.toUtc().isAfter(windowStartUtc))
          .map((event) => event.guardId.trim())
          .where((guardId) => guardId.isNotEmpty),
    };
    if (guardIds.isEmpty && _guardOpsActiveShiftId.trim().isNotEmpty) {
      guardIds.add('GUARD-001');
    }
    return guardIds.length;
  }

  int _complianceIssuesCount() {
    final report = _morningSovereignReport;
    if (report != null) {
      final blocked = report.complianceBlockage.totalBlocked;
      final expiries =
          report.complianceBlockage.psiraExpired +
          report.complianceBlockage.pdpExpired;
      return blocked > expiries ? blocked : expiries;
    }
    return _guardOutcomeDeniedInWindow(const Duration(hours: 24));
  }

  int _tacticalSosAlerts() {
    final nowUtc = DateTime.now().toUtc();
    return _guardOpsRecentEvents
        .where(
          (event) =>
              event.eventType == GuardOpsEventType.panicTriggered &&
              nowUtc.difference(event.occurredAt.toUtc()) <=
                  const Duration(minutes: 30),
        )
        .length;
  }

  Widget _buildPage(List<DispatchEvent> events) {
    switch (_route) {
      case OnyxRoute.dashboard:
        return LiveOperationsPage(
          events: events,
          morningSovereignReportHistory: _morningSovereignReportHistory,
          focusIncidentReference: _operationsFocusIncidentReference,
          videoOpsLabel: _activeVideoOpsLabel,
          sceneReviewByIntelligenceId: _monitoringSceneReviewByIntelligenceId,
          onOpenEventsForScope: (eventIds, selectedEventId) {
            _openEventsForScopedEventIds(
              eventIds,
              selectedEventId: selectedEventId,
            );
          },
        );

      case OnyxRoute.aiQueue:
        return AIQueuePage(
          events: events,
          videoOpsLabel: _activeVideoOpsLabel,
          sceneReviewByIntelligenceId: _monitoringSceneReviewByIntelligenceId,
        );

      case OnyxRoute.tactical:
        return TacticalPage(
          events: events,
          focusIncidentReference: _operationsFocusIncidentReference,
          videoOpsLabel: _activeVideoOpsLabel,
          sceneReviewByIntelligenceId: _monitoringSceneReviewByIntelligenceId,
          cctvOpsReadiness: _activeVideoProfile.readinessLabel,
          cctvOpsDetail: _cctvOpsDetailLabel(),
          cctvProvider: _activeVideoProfile.provider,
          cctvCapabilitySummary: _cctvCapabilitySummary(),
          cctvRecentSignalSummary:
              '${_cctvRecentSignalSummary(events)}${_cctvCameraHealthSummary().isEmpty ? '' : ' • ${_cctvCameraHealthSummary()}'}',
          fleetScopeHealth: _tacticalFleetScopeHealth(events),
          initialWatchActionDrilldown: _tacticalWatchActionDrilldown,
          onWatchActionDrilldownChanged: (value) {
            setState(() {
              _tacticalWatchActionDrilldown = value;
            });
          },
          onOpenFleetTacticalScope: _openTacticalForFleetScope,
          onOpenFleetDispatchScope: _openDispatchesForFleetScope,
          onRecoverFleetWatchScope: (clientId, siteId) {
            unawaited(
              _resyncMonitoringWatchForScope(
                clientId: clientId,
                siteId: siteId,
                actor: 'TACTICAL',
              ),
            );
          },
          onExtendTemporaryIdentityApproval:
              _extendTemporaryIdentityApprovalForScope,
          onExpireTemporaryIdentityApproval:
              _expireTemporaryIdentityApprovalForScope,
        );

      case OnyxRoute.governance:
        return GovernancePage(
          events: events,
          sceneReviewByIntelligenceId: _monitoringSceneReviewByIntelligenceId,
          morningSovereignReport: _morningSovereignReport,
          morningSovereignReportHistory: _morningSovereignReportHistory,
          morningSovereignReportAutoRunKey: _morningSovereignReportAutoRunKey,
          initialPartnerScopeClientId:
              _governancePartnerScopeClientId.trim().isEmpty
              ? null
              : _governancePartnerScopeClientId,
          initialPartnerScopeSiteId:
              _governancePartnerScopeSiteId.trim().isEmpty
              ? null
              : _governancePartnerScopeSiteId,
          initialPartnerScopePartnerLabel:
              _governancePartnerScopePartnerLabel.trim().isEmpty
              ? null
              : _governancePartnerScopePartnerLabel,
          onMorningSovereignReportChanged: _handleMorningSovereignReportChanged,
          onOpenVehicleExceptionEvent: _openEventsForEventId,
          onOpenReceiptPolicyEvent: _openEventsForEventId,
          onOpenReportsForReceiptEvent: _openReportsForReceiptEvent,
          onOpenVehicleExceptionVisit: _openEventsForVehicleVisit,
          initialSceneActionFocus: _governanceSceneActionFocus,
          onSceneActionFocusChanged: (value) {
            setState(() {
              _governanceSceneActionFocus = value;
            });
          },
          onGenerateMorningSovereignReport: () async {
            await _generateMorningSovereignReport();
          },
          onOpenReportsForPartnerScope: _openReportsForPartnerScope,
        );

      case OnyxRoute.clients:
        return _appMode == OnyxAppMode.controller
            ? ClientsPage(
                clientId: _selectedClient,
                siteId: _selectedSite,
                events: events,
              )
            : _buildClientPage(events);

      case OnyxRoute.sites:
        return SitesCommandPage(events: events);

      case OnyxRoute.guards:
        return _appMode == OnyxAppMode.controller
            ? GuardsPage(events: events)
            : _buildGuardPage();

      case OnyxRoute.dispatches:
        return DispatchPage(
          clientId: _selectedClient,
          regionId: _selectedRegion,
          siteId: _selectedSite,
          focusIncidentReference: _operationsFocusIncidentReference,
          onGenerate: () {
            setState(() {
              service.processIntelligenceDemo(
                clientId: _selectedClient,
                regionId: _selectedRegion,
                siteId: _selectedSite,
              );
            });
          },
          onIngestFeeds: () {
            unawaited(_ingestLiveFeedBatch());
          },
          onIngestRadioOps: () {
            unawaited(_ingestRadioOpsSignals());
          },
          onIngestCctvEvents: () {
            unawaited(_ingestCctvSignals());
          },
          onIngestWearableOps: () {
            unawaited(_ingestWearableSignals());
          },
          onIngestNews: () {
            unawaited(_ingestNewsSignals());
          },
          onRetryRadioQueue: _pendingRadioAutomatedResponses.isEmpty
              ? null
              : () {
                  unawaited(_retryPendingRadioQueueNow());
                },
          onClearRadioQueue: _pendingRadioAutomatedResponses.isEmpty
              ? null
              : () {
                  unawaited(_clearPendingRadioQueue());
                },
          onLoadFeedFile: () {
            _loadLiveFeedFile();
          },
          onEscalateIntelligence: _escalateIntelligence,
          configuredNewsSources: _newsIntel.configuredProviders,
          newsSourceRequirementsHint: _newsIntel.configurationHint,
          newsSourceDiagnostics: _newsSourceDiagnostics,
          onProbeNewsSource: _probeNewsSource,
          onStartLivePolling: _livePollingAvailable
              ? () {
                  _startLiveFeedPolling();
                }
              : null,
          onStopLivePolling: _livePollingAvailable
              ? _stopLiveFeedPolling
              : null,
          livePolling: _livePolling,
          livePollingLabel: _livePollingLabel,
          runtimeConfigHint: _runtimeConfigHint,
          initialSelectedDispatchId: _dispatchSelectedDispatchId,
          onSelectedDispatchChanged: (value) {
            setState(() {
              _dispatchSelectedDispatchId = value;
            });
          },
          supabaseReady: widget.supabaseReady,
          guardSyncBackendEnabled: _guardSyncUsingBackend,
          telemetryProviderReadiness: _guardTelemetryReadiness.name,
          telemetryProviderActiveId: _guardTelemetryActiveProviderId,
          telemetryProviderExpectedId: _guardTelemetryRequiredProviderId,
          telemetryAdapterStubMode: _guardTelemetryAdapter.isStub,
          telemetryLiveReadyGateEnabled: _guardTelemetryEnforceLiveReady,
          telemetryLiveReadyGateViolation: _guardTelemetryLiveReadyGateViolated,
          telemetryLiveReadyGateReason: _guardTelemetryLiveReadyGateReason,
          radioOpsReadiness: _opsIntegrationProfile.radio.readinessLabel,
          radioOpsDetail: _opsIntegrationProfile.radio.detailLabel,
          radioOpsQueueHealth: _radioQueueHealthSummary(),
          radioQueueIntentMix: _radioQueueIntentMixSummary(),
          radioAckRecentSummary: _radioAckRecentSummary(events),
          radioQueueHasPending: _pendingRadioAutomatedResponses.isNotEmpty,
          radioQueueFailureDetail: _radioQueueFailureSummary(),
          radioQueueManualActionDetail: _radioQueueManualActionSummary(),
          radioAiAutoAllClearEnabled:
              _opsIntegrationProfile.radio.aiAutoAllClearEnabled,
          videoOpsLabel: _activeVideoOpsLabel,
          cctvOpsReadiness: _activeVideoProfile.readinessLabel,
          cctvOpsDetail: _cctvOpsDetailLabel(),
          cctvCapabilitySummary: _cctvCapabilitySummary(),
          cctvRecentSignalSummary:
              '${_cctvRecentSignalSummary(events)}${_cctvCameraHealthSummary().isEmpty ? '' : ' • ${_cctvCameraHealthSummary()}'}',
          fleetScopeHealth: _tacticalFleetScopeHealth(events),
          initialWatchActionDrilldown: _dispatchWatchActionDrilldown,
          onWatchActionDrilldownChanged: (value) {
            setState(() {
              _dispatchWatchActionDrilldown = value;
            });
          },
          onOpenFleetTacticalScope: _openTacticalForFleetScope,
          onOpenFleetDispatchScope: _openDispatchesForFleetScope,
          onRecoverFleetWatchScope: (clientId, siteId) {
            unawaited(
              _resyncMonitoringWatchForScope(
                clientId: clientId,
                siteId: siteId,
                actor: 'DISPATCH',
              ),
            );
          },
          onExtendTemporaryIdentityApproval:
              _extendTemporaryIdentityApprovalForScope,
          onExpireTemporaryIdentityApproval:
              _expireTemporaryIdentityApprovalForScope,
          wearableOpsReadiness:
              _wearableProviderEnv.trim().isNotEmpty &&
                  _wearableBridgeUri != null
              ? 'ACTIVE'
              : 'UNCONFIGURED',
          wearableOpsDetail:
              _wearableProviderEnv.trim().isNotEmpty &&
                  _wearableBridgeUri != null
              ? '${_wearableProviderEnv.trim()} • wearable telemetry events'
              : 'Configure ONYX_WEARABLE_PROVIDER and ONYX_WEARABLE_EVENTS_URL.',
          livePollingHistory: _livePollingHistory,
          onRunStress: _runStressIntake,
          onRunSoak: _runSoakIntake,
          onRunBenchmarkSuite: _runBenchmarkSuite,
          initialProfile: _currentStressProfile,
          initialScenarioLabel: _currentScenarioLabel,
          initialScenarioTags: _currentScenarioTags,
          initialRunNote: _currentRunNote,
          initialFilterPresets: _savedFilterPresets,
          initialIntelligenceSourceFilter: _currentIntelligenceSourceFilter,
          initialIntelligenceActionFilter: _currentIntelligenceActionFilter,
          initialPinnedWatchIntelligenceIds: _pinnedWatchIntelligenceIds,
          initialDismissedIntelligenceIds: _dismissedIntelligenceIds,
          initialShowPinnedWatchIntelligenceOnly:
              _showPinnedWatchIntelligenceOnly,
          initialShowDismissedIntelligenceOnly: _showDismissedIntelligenceOnly,
          initialSelectedIntelligenceId: _selectedIntelligenceId,
          onProfileChanged: (profile) {
            _persistStressProfile(profile);
          },
          onScenarioChanged: (scenarioLabel, tags) {
            _persistScenarioDraft(scenarioLabel, tags);
          },
          onRunNoteChanged: (runNote) {
            _persistRunNoteDraft(runNote);
          },
          onFilterPresetsChanged: (presets) {
            _persistFilterPresets(presets);
          },
          onIntelligenceFiltersChanged: (sourceFilter, actionFilter) {
            _persistIntelligenceFilters(sourceFilter, actionFilter);
          },
          onIntelligenceTriageChanged: (pinnedWatchIds, dismissedIds) {
            _persistIntelligenceTriage(pinnedWatchIds, dismissedIds);
          },
          onIntelligenceViewModesChanged: (showPinnedOnly, showDismissedOnly) {
            _persistIntelligenceViewModes(showPinnedOnly, showDismissedOnly);
          },
          onSelectedIntelligenceChanged: (intelligenceId) {
            _persistSelectedIntelligence(intelligenceId);
          },
          onTelemetryImported: (telemetry) {
            setState(() {
              _intakeTelemetry = telemetry;
              _lastIntakeStatus =
                  'Telemetry imported from clipboard (${telemetry.runs} runs).';
            });
            _persistTelemetry();
          },
          onRerunLastProfile: _lastStressProfile == null
              ? null
              : _rerunLastProfile,
          onCancelStress: _cancelStressRun,
          onResetTelemetry: _resetTelemetry,
          onClearTelemetryPersistence: _clearTelemetryPersistence,
          onClearLivePollHealth: _clearLivePollHealth,
          onClearProfilePersistence: _clearProfilePersistence,
          onClearSavedViewsPersistence: _clearSavedViewsPersistence,
          stressRunning: _stressRunning,
          intakeStatus: _lastIntakeStatus,
          stressStatus: _lastStressStatus,
          intakeTelemetry: _intakeTelemetry,
          events: events,
          morningSovereignReportHistory: _morningSovereignReportHistory,
          onExecute: (dispatchId) {
            unawaited(_executeDispatchAndNotifyPartner(dispatchId));
          },
        );

      case OnyxRoute.events:
        return EventsReviewPage(
          events: events,
          morningSovereignReportHistory: _morningSovereignReportHistory,
          sceneReviewByIntelligenceId: _monitoringSceneReviewByIntelligenceId,
          initialSourceFilter: _eventsSourceFilter.trim().isEmpty
              ? null
              : _eventsSourceFilter,
          initialProviderFilter: _eventsProviderFilter.trim().isEmpty
              ? null
              : _eventsProviderFilter,
          initialSelectedEventId: _eventsSelectedEventId.trim().isEmpty
              ? null
              : _eventsSelectedEventId,
          initialScopedEventIds: _eventsScopedEventIds,
        );

      case OnyxRoute.ledger:
        return SovereignLedgerPage(
          clientId: _selectedClient,
          events: events,
          sceneReviewByIntelligenceId: _monitoringSceneReviewByIntelligenceId,
          initialFocusReference: _operationsFocusIncidentReference,
        );

      case OnyxRoute.reports:
        return ClientIntelligenceReportsPage(
          store: store,
          selectedClient: _reportsScopeClientId.trim().isNotEmpty
              ? _reportsScopeClientId
              : _selectedClient,
          selectedSite: _reportsScopeSiteId.trim().isNotEmpty
              ? _reportsScopeSiteId
              : _selectedSite,
          sceneReviewByIntelligenceId: _monitoringSceneReviewByIntelligenceId,
          reportShellState: _reportShellState,
          morningSovereignReportHistory: _morningSovereignReportHistory,
          initialPartnerScopeClientId: _reportsScopeClientId.trim().isEmpty
              ? null
              : _reportsScopeClientId,
          initialPartnerScopeSiteId: _reportsScopeSiteId.trim().isEmpty
              ? null
              : _reportsScopeSiteId,
          initialPartnerScopePartnerLabel:
              _reportsScopePartnerLabel.trim().isEmpty
              ? null
              : _reportsScopePartnerLabel,
          onOpenGovernanceForPartnerScope: _openGovernanceForPartnerScope,
          onOpenEventsForScope: (eventIds, selectedEventId) {
            _openEventsForScopedEventIds(
              eventIds,
              selectedEventId: selectedEventId,
            );
          },
          onReportShellStateChanged: (value) {
            _reportShellState = value;
          },
          onRequestPreview: _presentReportPreview,
        );

      case OnyxRoute.admin:
        return AdministrationPage(
          events: events,
          morningSovereignReportHistory: _morningSovereignReportHistory,
          supabaseReady: widget.supabaseReady,
          sceneReviewByIntelligenceId: _monitoringSceneReviewByIntelligenceId,
          monitoringIdentityPolicyService: _watchIdentityPolicyService,
          onMonitoringIdentityPolicyServiceChanged: (value) {
            _watchIdentityPolicyService = value;
            _rebuildWatchSceneAssessmentService();
            setState(() {
              _monitoringIdentityRulesJsonOverride = value
                  .toCanonicalJsonString();
            });
          },
          onRegisterTemporaryIdentityApprovalProfile:
              _rememberTemporaryAllowedIdentityProfile,
          onExtendTemporaryIdentityApproval:
              _extendTemporaryIdentityApprovalForScope,
          onExpireTemporaryIdentityApproval:
              _expireTemporaryIdentityApprovalForScope,
          initialMonitoringIdentityRuleAuditHistory:
              _monitoringIdentityRuleAuditHistory,
          onMonitoringIdentityRuleAuditHistoryChanged: (value) {
            setState(() {
              _monitoringIdentityRuleAuditHistory = value;
            });
            unawaited(_persistMonitoringIdentityRuleAuditHistory());
          },
          initialMonitoringIdentityRuleAuditSourceFilter:
              _adminIdentityPolicyAuditSourceFilter,
          onMonitoringIdentityRuleAuditSourceFilterChanged: (value) {
            setState(() {
              _adminIdentityPolicyAuditSourceFilter = value;
            });
            unawaited(_persistMonitoringIdentityRuleAuditSourceFilter());
          },
          initialMonitoringIdentityRuleAuditExpanded:
              _adminIdentityPolicyAuditExpanded,
          onMonitoringIdentityRuleAuditExpandedChanged: (value) {
            setState(() {
              _adminIdentityPolicyAuditExpanded = value;
            });
            unawaited(_persistMonitoringIdentityRuleAuditExpanded());
          },
          initialTab: _adminPageTab,
          onTabChanged: (value) {
            setState(() {
              _adminPageTab = value;
            });
            unawaited(_persistAdminPageTab());
          },
          initialWatchActionDrilldown: _adminWatchActionDrilldown,
          onWatchActionDrilldownChanged: (value) {
            setState(() {
              _adminWatchActionDrilldown = value;
              if (value != null) {
                _adminPageTab = AdministrationPageTab.system;
              }
            });
            unawaited(_persistAdminPageTab());
            unawaited(_persistAdminWatchActionDrilldown());
          },
          onOpenOperationsForIncident: _openOperationsFromAdminIncident,
          onOpenTacticalForIncident: _openTacticalFromAdminIncident,
          onOpenEventsForIncident: _openEventsFromAdminIncident,
          onOpenEventsForScope: (eventIds, selectedEventId) {
            _openEventsForScopedEventIds(
              eventIds,
              selectedEventId: selectedEventId,
            );
          },
          onOpenLedgerForIncident: _openLedgerFromAdminIncident,
          onOpenDispatchesForIncident: _openDispatchesFromAdminIncident,
          onRunDemoAutopilotForIncident: _startDemoAutopilotFromAdminIncident,
          onRunFullDemoAutopilotForIncident:
              _startFullDemoAutopilotFromAdminIncident,
          onOpenGovernance: _openGovernanceFromAdmin,
          onOpenGovernanceForPartnerScope: _openGovernanceForPartnerScope,
          onOpenDispatches: _openDispatchesFromAdmin,
          onOpenClientView: _openClientViewFromAdmin,
          onOpenReports: _openReportsFromAdmin,
          initialRadioIntentPhrasesJson: _radioIntentPhrasesJsonOverride,
          initialDemoRouteCuesJson: _demoRouteCueOverridesJson,
          initialMonitoringIdentityRulesJson:
              _monitoringIdentityRulesJsonOverride,
          onSaveRadioIntentPhrasesJson: _saveRadioIntentPhraseConfig,
          onResetRadioIntentPhrasesJson: _clearRadioIntentPhraseConfig,
          onSaveDemoRouteCuesJson: _saveDemoRouteCueOverridesConfig,
          onResetDemoRouteCuesJson: _clearDemoRouteCueOverridesConfig,
          onSaveMonitoringIdentityPolicyService:
              _saveMonitoringIdentityRulesConfig,
          onResetMonitoringIdentityPolicyService:
              _clearMonitoringIdentityRulesConfig,
          onRunOpsIntegrationPoll: _opsIntegrationPollingAvailable
              ? _pollOpsIntegrationOnce
              : null,
          onRunRadioPoll: _opsIntegrationProfile.radio.configured
              ? () async {
                  await _ingestRadioOpsSignals();
                }
              : null,
          onRunCctvPoll: _activeVideoProfile.configured
              ? () async {
                  await _ingestCctvSignals();
                }
              : null,
          onRunWearablePoll:
              (_wearableProviderEnv.trim().isNotEmpty &&
                  _wearableBridgeUri != null)
              ? () async {
                  await _ingestWearableSignals();
                }
              : null,
          onRunNewsPoll: _newsIntel.configuredProviders.isNotEmpty
              ? () async {
                  await _ingestNewsSignals();
                }
              : null,
          onRetryRadioQueue: _pendingRadioAutomatedResponses.isEmpty
              ? null
              : _retryPendingRadioQueueNow,
          onClearRadioQueue: _pendingRadioAutomatedResponses.isEmpty
              ? null
              : _clearPendingRadioQueue,
          onClearRadioQueueFailureSnapshot:
              _radioQueueLastFailureSnapshot.trim().isEmpty
              ? null
              : _clearRadioQueueFailureSnapshotOnly,
          radioQueueHasPending: _pendingRadioAutomatedResponses.isNotEmpty,
          radioOpsPollHealth: _opsHealthSummary(_radioOpsHealth),
          radioOpsQueueHealth: _radioQueueHealthSummary(),
          radioOpsQueueIntentMix: _radioQueueIntentMixSummary(),
          radioOpsAckRecentSummary: _radioAckRecentSummary(events),
          radioOpsQueueStateDetail: _radioQueueStateChangeSummary(),
          radioOpsFailureDetail: _radioQueueLastFailureSnapshot.trim().isEmpty
              ? null
              : 'Last failure • ${_radioQueueLastFailureSnapshot.trim()}',
          radioOpsFailureAuditDetail: _radioQueueFailureAuditSummary(),
          radioOpsManualActionDetail: _radioQueueManualActionSummary(),
          videoOpsLabel: _activeVideoOpsLabel,
          cctvOpsPollHealth: _opsHealthSummary(_cctvOpsHealth),
          cctvCapabilitySummary: _cctvCapabilitySummary(),
          cctvRecentSignalSummary: _cctvRecentSignalSummary(events),
          cctvEvidenceHealthSummary: _cctvEvidenceSummary(),
          cctvCameraHealthSummary: _cctvCameraHealthSummary(),
          fleetScopeHealth: _tacticalFleetScopeHealth(events),
          onOpenFleetTacticalScope: _openTacticalForFleetScope,
          onOpenFleetDispatchScope: _openDispatchesForFleetScope,
          onRecoverFleetWatchScope: (clientId, siteId) {
            unawaited(
              _resyncMonitoringWatchForScope(
                clientId: clientId,
                siteId: siteId,
                actor: 'ADMIN',
              ),
            );
          },
          monitoringWatchAuditSummary: _monitoringWatchAuditSummary,
          monitoringWatchAuditHistory: _monitoringWatchAuditHistory,
          incidentSpoolHealthSummary: _offlineIncidentSpoolSummary(),
          incidentSpoolReplaySummary: _offlineIncidentSpoolReplaySummary(),
          videoIntegrityCertificateStatus: _videoIntegrityCertificateStatus(
            events,
          ),
          videoIntegrityCertificateSummary: _videoIntegrityCertificateSummary(
            events,
          ),
          videoIntegrityCertificateJsonPreview:
              _videoIntegrityCertificateJsonPreview(events),
          videoIntegrityCertificateMarkdownPreview:
              _videoIntegrityCertificateMarkdownPreview(events),
          wearableOpsPollHealth: _opsHealthSummary(_wearableOpsHealth),
          listenerAlarmOpsPollHealth: _opsHealthSummary(
            _listenerAlarmOpsHealth,
          ),
          newsOpsPollHealth: _opsHealthSummary(_newsOpsHealth),
          telegramBridgeHealthLabel: _telegramBridgeHealthLabel,
          telegramBridgeHealthDetail: _telegramBridgeHealthDetail,
          telegramBridgeFallbackActive: _telegramBridgeFallbackToInApp,
          telegramBridgeHealthUpdatedAtUtc: _telegramBridgeHealthUpdatedAtUtc,
          telegramAiAssistantEnabled: _telegramAiAssistantEnabled,
          telegramAiApprovalRequired: _telegramAiApprovalRequired,
          telegramAiLastHandledAtUtc: _telegramAiLastHandledAtUtc,
          telegramAiLastHandledSummary: _telegramAiLastHandledSummary,
          telegramAiPendingDrafts: _telegramAiPendingDraftViews(),
          operatorId: service.operator.operatorId,
          onSetOperatorId: _setOperatorIdentity,
          onBindPartnerTelegramEndpoint: _bindAdminPartnerTelegramEndpoint,
          onUnlinkPartnerTelegramEndpoint: _unlinkAdminPartnerTelegramEndpoint,
          onCheckPartnerTelegramEndpoint: _checkAdminPartnerTelegramEndpoint,
          onSetTelegramAiAssistantEnabled:
              _setTelegramAiAssistantEnabledFromAdmin,
          onSetTelegramAiApprovalRequired:
              _setTelegramAiApprovalRequiredFromAdmin,
          onApproveTelegramAiDraft: _approveTelegramAiDraftFromAdmin,
          onRejectTelegramAiDraft: _rejectTelegramAiDraftFromAdmin,
          onRunSiteTelegramChatcheck: _runAdminSiteTelegramChatcheck,
        );
    }
  }

  Widget _buildClientPage(List<DispatchEvent> events) {
    return ClientAppPage(
      clientId: _selectedClient,
      siteId: _selectedSite,
      locale: _clientAppLocale,
      events: events,
      backendSyncEnabled: widget.supabaseReady,
      viewerRole: _clientAppViewerRole,
      initialSelectedRoom: _clientAppSelectedRoom,
      initialSelectedRoomByRole: _clientAppSelectedRoomByRole,
      initialShowAllRoomItems: _clientAppShowAllRoomItems,
      initialShowAllRoomItemsByRole: _clientAppShowAllRoomItemsByRole,
      initialSelectedIncidentReferenceByRole:
          _clientAppSelectedIncidentReferenceByRole,
      initialExpandedIncidentReferenceByRole:
          _clientAppExpandedIncidentReferenceByRole,
      initialHasTouchedIncidentExpansionByRole:
          _clientAppHasTouchedIncidentExpansionByRole,
      initialFocusedIncidentReferenceByRole:
          _clientAppFocusedIncidentReferenceByRole,
      initialManualMessages: _clientAppMessages,
      initialAcknowledgements: _clientAppAcknowledgements,
      initialPushQueue: _clientAppPushQueue,
      pushDeliveryProvider:
          (_telegramBridge.isConfigured && !_telegramBridgeFallbackToInApp)
          ? ClientPushDeliveryProvider.telegram
          : (_clientPushDeliveryProvider == ClientPushDeliveryProvider.telegram
                ? ClientPushDeliveryProvider.inApp
                : _clientPushDeliveryProvider),
      pushSyncStatusLabel: _clientAppPushSyncStatusLabel,
      pushSyncLastSyncedAtUtc: _clientAppPushLastSyncedAtUtc,
      pushSyncFailureReason: _clientAppPushSyncFailureReason,
      pushSyncRetryCount: _clientAppPushSyncRetryCount,
      pushSyncHistory: _clientAppPushSyncHistory,
      backendProbeStatusLabel: _clientAppBackendProbeStatusLabel,
      backendProbeLastRunAtUtc: _clientAppBackendProbeLastRunAtUtc,
      backendProbeFailureReason: _clientAppBackendProbeFailureReason,
      backendProbeHistory: _clientAppBackendProbeHistory,
      onRunBackendProbe: _runClientAppBackendProbe,
      onClearBackendProbeHistory: _clearClientAppBackendProbeHistory,
      onRetryPushSync: _retryClientAppPushSync,
      onClientStateChanged: _persistClientAppDraft,
      onPushQueueChanged: _persistClientAppPushQueue,
    );
  }

  Widget _buildGuardPage() {
    final initialGuardScreen = _consumeGuardInitialScreen();
    final nowUtc = DateTime.now().toUtc();
    final guardCoachingPrompt = _guardSyncCoachingPolicy.evaluate(
      syncBackendEnabled: _guardSyncUsingBackend,
      pendingEventCount: _guardOpsPendingEvents,
      pendingMediaCount: _guardOpsPendingMedia,
      failedEventCount: _guardOpsFailedEvents,
      failedMediaCount: _guardOpsFailedMedia,
      recentEvents: _guardOpsRecentEvents,
      nowUtc: nowUtc,
    );
    final effectiveGuardCoachingPrompt = _effectiveGuardCoachingPrompt(
      prompt: guardCoachingPrompt,
      nowUtc: nowUtc,
    );
    final activeScopeKey = _guardSyncSelectionScopeKey();
    return GuardMobileShellPage(
      clientId: _selectedClient,
      siteId: _selectedSite,
      guardId: 'GUARD-001',
      guardOnlyExperience: _appMode == OnyxAppMode.guard,
      operatorRole: _guardOperatorRole,
      syncBackendEnabled: _guardSyncUsingBackend,
      queueDepth: _guardSyncQueueDepth,
      pendingEventCount: _guardOpsPendingEvents,
      pendingMediaCount: _guardOpsPendingMedia,
      failedEventCount: _guardOpsFailedEvents,
      failedMediaCount: _guardOpsFailedMedia,
      recentEvents: _guardOpsRecentEvents,
      recentMedia: _guardOpsRecentMedia,
      syncInFlight: _guardOpsSyncInFlight,
      syncStatusLabel: _guardOpsLastSyncLabel,
      activeShiftId: _guardOpsActiveShiftId,
      activeShiftSequenceWatermark: _guardOpsActiveShiftSequenceWatermark,
      lastCloseoutPacketAuditLabel: _guardCloseoutPacketAuditLabel(),
      lastShiftReplayAuditLabel: _guardShiftReplayAuditLabel(),
      lastSyncReportAuditLabel: _guardSyncReportAuditLabel(),
      lastExportAuditClearLabel: _guardExportAuditClearLabel(),
      telemetryAdapterLabel: _guardTelemetryAdapter.adapterLabel,
      telemetryAdapterStubMode: _guardTelemetryAdapter.isStub,
      telemetryProviderId: _guardTelemetryActiveProviderId,
      telemetryProviderStatusLabel: _guardTelemetryProviderStatusLabel,
      telemetryProviderReadiness: _guardTelemetryReadiness.name,
      telemetryLiveReadyGateEnabled: _guardTelemetryEnforceLiveReady,
      telemetryLiveReadyGateViolation: _guardTelemetryLiveReadyGateViolated,
      telemetryLiveReadyGateReason: _guardTelemetryLiveReadyGateReason,
      telemetryFacadeId: _guardTelemetryFacadeId,
      telemetryFacadeLiveMode: _guardTelemetryFacadeLiveMode,
      telemetryFacadeToggleSource: _guardTelemetryFacadeToggleSource,
      telemetryFacadeRuntimeMode: _guardTelemetryFacadeRuntimeMode,
      telemetryFacadeHeartbeatSource: _guardTelemetryFacadeHeartbeatSource,
      telemetryFacadeHeartbeatAction: _guardTelemetryFacadeHeartbeatAction,
      telemetryVendorConnectorId: _guardTelemetryVendorConnectorId,
      telemetryVendorConnectorSource: _guardTelemetryVendorConnectorSource,
      telemetryVendorConnectorErrorMessage:
          _guardTelemetryVendorConnectorErrorMessage,
      telemetryVendorConnectorFallbackActive:
          _guardTelemetryVendorConnectorFallbackActive,
      telemetryFacadeSourceActive: _guardTelemetryFacadeSourceActive,
      telemetryFacadeCallbackCount: _guardTelemetryFacadeCallbackCount,
      telemetryFacadeLastCallbackAtUtc: _guardTelemetryFacadeLastCallbackAtUtc,
      telemetryFacadeLastCallbackMessage:
          _guardTelemetryFacadeLastCallbackMessage,
      telemetryFacadeCallbackErrorCount:
          _guardTelemetryFacadeCallbackErrorCount,
      telemetryFacadeLastCallbackErrorAtUtc:
          _guardTelemetryFacadeLastCallbackErrorAtUtc,
      telemetryFacadeLastCallbackErrorMessage:
          _guardTelemetryFacadeLastCallbackErrorMessage,
      resumeSyncEventThrottleSeconds: _guardResumeSyncEventThrottleSeconds,
      lastSuccessfulSyncAtUtc: _guardOpsLastSuccessfulSyncAtUtc,
      lastFailureReason: _guardOpsLastFailureReason,
      coachingPrompt: effectiveGuardCoachingPrompt,
      coachingPolicy: _guardSyncCoachingPolicy,
      queuedOperations: _guardQueuedOperations,
      historyFilter: _guardSyncHistoryFilter,
      onHistoryFilterChanged: _setGuardHistoryFilter,
      operationModeFilter: _guardSyncOperationModeFilter,
      onOperationModeFilterChanged: _setGuardOperationModeFilter,
      availableFacadeIds: _guardSyncAvailableFacadeIds,
      selectedFacadeId: _guardSyncSelectedFacadeId,
      onFacadeIdFilterChanged: _setGuardFacadeIdFilter,
      scopedSelectionCount: _guardSyncSelectedOperationIdByFilter.length,
      scopedSelectionKeys: (_guardSyncSelectedOperationIdByFilter.keys.toList(
        growable: false,
      )..sort()),
      scopedSelectionsByScope: _guardSyncSelectedOperationIdByFilter,
      activeScopeKey: activeScopeKey,
      activeScopeHasSelection:
          (_guardSyncSelectedOperationIdByFilter[activeScopeKey] ?? '')
              .trim()
              .isNotEmpty,
      initialSelectedOperationId:
          _guardSyncSelectedOperationIdByFilter[activeScopeKey],
      onSelectedOperationChanged: _setGuardSelectedOperation,
      onShiftStartQueued: _queueShiftStartVerification,
      onShiftEndQueued: _queueShiftEnd,
      onStatusQueued: _queueGuardStatus,
      onReactionIncidentAcceptedQueued: _queueReactionIncidentAccepted,
      onReactionOfficerArrivedQueued: _queueReactionOfficerArrived,
      onReactionIncidentClearedQueued: _queueReactionIncidentCleared,
      onSupervisorStatusOverrideQueued: _queueSupervisorStatusOverride,
      onSupervisorCoachingAcknowledgedQueued:
          _queueSupervisorCoachingAcknowledgement,
      onCheckpointQueued: _queueGuardCheckpoint,
      onPatrolImageQueued: _queuePatrolVerificationImage,
      onPanicQueued: _queueGuardPanicSignal,
      onWearableHeartbeatQueued: _queueWearableHeartbeat,
      onDeviceHealthQueued: _queueDeviceHealthTelemetry,
      onSeedWearableBridge: _guardTelemetryBridgeWriter.isAvailable
          ? _seedWearableBridgeSample
          : null,
      onEmitTelemetryDebugHeartbeat:
          kDebugMode &&
              !kIsWeb &&
              _guardTelemetryAdapter is NativeGuardTelemetryIngestionAdapter
          ? _emitDebugTelemetrySdkHeartbeatBroadcast
          : null,
      onValidateTelemetryPayloadReplay:
          !kIsWeb &&
              _guardTelemetryAdapter is NativeGuardTelemetryIngestionAdapter
          ? _validateTelemetryPayloadReplay
          : null,
      onOutcomeLabeled: _queueIncidentOutcomeLabel,
      outcomeGovernancePolicy: _outcomeGovernancePolicy,
      onClearQueue: _clearGuardQueue,
      onSyncNow: _syncGuardOpsNow,
      onRetryFailedEvents: _retryFailedGuardEvents,
      onRetryFailedMedia: _retryFailedGuardMedia,
      onRetryFailedOperation: _retryFailedGuardSyncOperation,
      onRetryFailedOperationsBulk: _retryFailedGuardSyncOperationsBulk,
      onDispatchCloseoutPacketCopied: _recordGuardCloseoutPacketAudit,
      onShiftReplaySummaryCopied: _recordGuardShiftReplayAudit,
      onSyncReportCopied: _recordGuardSyncReportAudit,
      onClearExportAudits: _clearGuardExportAudits,
      onProbeTelemetryProvider: _refreshGuardTelemetryAdapterStatus,
      failedOpsWarnThreshold: _positiveThreshold(
        _guardFailedOpsWarnThresholdEnv,
        fallback: 1,
      ),
      failedOpsCriticalThreshold: _positiveThreshold(
        _guardFailedOpsCriticalThresholdEnv,
        fallback: 5,
      ),
      oldestFailedWarnMinutes: _positiveThreshold(
        _guardOldestFailedWarnMinutesEnv,
        fallback: 10,
      ),
      oldestFailedCriticalMinutes: _positiveThreshold(
        _guardOldestFailedCriticalMinutesEnv,
        fallback: 30,
      ),
      failedRetryWarnThreshold: _positiveThreshold(
        _guardFailedRetryWarnThresholdEnv,
        fallback: 8,
      ),
      failedRetryCriticalThreshold: _positiveThreshold(
        _guardFailedRetryCriticalThresholdEnv,
        fallback: 20,
      ),
      onAcknowledgeCoachingPrompt: _acknowledgeGuardCoachingPrompt,
      onSnoozeCoachingPrompt: _snoozeGuardCoachingPrompt,
      initialScreen: initialGuardScreen,
    );
  }

  String _nextRunId(String prefix) {
    _runCounter += 1;
    return '$prefix-${_runCounter.toString().padLeft(4, '0')}';
  }

  int get _normalizedPollIntervalSeconds {
    if (_liveFeedPollIntervalSeconds < 5) {
      return 5;
    }
    return _liveFeedPollIntervalSeconds;
  }

  String get _liveFeedPollEndpoint =>
      OnyxRuntimeConfig.usableLiveFeedUrl(_liveFeedPollUrl);

  bool get _livePollingAvailable => _liveFeedPollEndpoint.isNotEmpty;

  Uri? get _listenerAlarmFeedUri {
    final endpoint = OnyxRuntimeConfig.usableListenerAlarmFeedUrl(
      _listenerAlarmFeedUrl,
    );
    if (endpoint.isEmpty) {
      return null;
    }
    return Uri.tryParse(endpoint);
  }

  bool get _listenerAlarmFeedConfigured => _listenerAlarmFeedUri != null;

  Uri? get _listenerAlarmLegacyFeedUri {
    final endpoint = OnyxRuntimeConfig.usableListenerAlarmLegacyFeedUrl(
      _listenerAlarmLegacyFeedUrl,
    );
    if (endpoint.isEmpty) {
      return null;
    }
    return Uri.tryParse(endpoint);
  }

  bool get _listenerAlarmLegacyFeedConfigured =>
      _listenerAlarmLegacyFeedUri != null;

  Map<String, String> get _listenerAlarmFeedHeaders {
    final headers = <String, String>{};
    final bearerToken = OnyxRuntimeConfig.usableSecret(
      _listenerAlarmFeedBearerToken,
    );
    if (bearerToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $bearerToken';
    }

    final rawHeaders = _listenerAlarmFeedHeadersJson.trim();
    if (rawHeaders.isEmpty) {
      return headers;
    }

    try {
      final decoded = jsonDecode(rawHeaders);
      if (decoded is Map) {
        for (final entry in decoded.entries) {
          final key = entry.key.toString().trim();
          final value = entry.value?.toString().trim() ?? '';
          if (key.isEmpty || value.isEmpty) {
            continue;
          }
          headers[key] = value;
        }
      }
    } catch (_) {
      // Invalid header config should not crash startup; requests proceed
      // without the malformed supplemental headers.
    }

    return headers;
  }

  Map<String, String> get _listenerAlarmLegacyFeedHeaders {
    final headers = <String, String>{};
    final bearerToken = OnyxRuntimeConfig.usableSecret(
      _listenerAlarmLegacyFeedBearerToken,
    );
    if (bearerToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $bearerToken';
    }
    final rawHeaders = _listenerAlarmLegacyFeedHeadersJson.trim();
    if (rawHeaders.isEmpty) {
      return headers;
    }
    final decoded = jsonDecode(rawHeaders);
    if (decoded is! Map) {
      return headers;
    }
    decoded.forEach((key, value) {
      final headerName = key.toString().trim();
      final headerValue = value?.toString().trim() ?? '';
      if (headerName.isEmpty || headerValue.isEmpty) {
        return;
      }
      headers[headerName] = headerValue;
    });
    return headers;
  }

  Map<String, String> get _liveFeedPollHeaders {
    final headers = <String, String>{};
    final bearerToken = OnyxRuntimeConfig.usableSecret(
      _liveFeedPollBearerToken,
    );
    if (bearerToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $bearerToken';
    }

    final rawHeaders = _liveFeedPollHeadersJson.trim();
    if (rawHeaders.isEmpty) {
      return headers;
    }

    try {
      final decoded = jsonDecode(rawHeaders);
      if (decoded is Map) {
        for (final entry in decoded.entries) {
          final key = entry.key.toString().trim();
          final value = entry.value?.toString().trim() ?? '';
          if (key.isEmpty || value.isEmpty) {
            continue;
          }
          headers[key] = value;
        }
      }
    } catch (_) {
      // Invalid header config should not crash startup; requests proceed
      // without the malformed supplemental headers.
    }

    return headers;
  }

  bool get _liveFeedAuthConfigured => _liveFeedPollHeaders.isNotEmpty;

  String? get _runtimeConfigHint {
    final guardThresholdHint =
        ' Guard sync alert thresholds => failures: ${_positiveThreshold(_guardFailureAlertThresholdEnv, fallback: 1)}, queue: ${_positiveThreshold(_guardQueuePressureAlertThresholdEnv, fallback: 25)}, stale minutes: ${_positiveThreshold(_guardStaleSyncAlertMinutesEnv, fallback: 10)}.';
    final guardHistoryThresholdHint =
        ' Guard sync history thresholds => failed ops warn/critical: ${_positiveThreshold(_guardFailedOpsWarnThresholdEnv, fallback: 1)}/${_positiveThreshold(_guardFailedOpsCriticalThresholdEnv, fallback: 5)}, oldest failed minutes warn/critical: ${_positiveThreshold(_guardOldestFailedWarnMinutesEnv, fallback: 10)}/${_positiveThreshold(_guardOldestFailedCriticalMinutesEnv, fallback: 30)}, failed retry warn/critical: ${_positiveThreshold(_guardFailedRetryWarnThresholdEnv, fallback: 8)}/${_positiveThreshold(_guardFailedRetryCriticalThresholdEnv, fallback: 20)}.';
    final guardTelemetryHint =
        ' Guard telemetry adapter: ${_guardTelemetryAdapter.adapterLabel}${_guardTelemetryAdapter.isStub ? ' (stub mode)' : ' (live mode)'}; readiness: ${_guardTelemetryReadiness.name}; provider active/expected: ${_guardTelemetryActiveProviderId ?? 'unknown'}/$_guardTelemetryRequiredProviderId.';
    final guardTelemetryGateHint =
        ' Telemetry live-ready gate: ${_guardTelemetryEnforceLiveReady ? (_guardTelemetryLiveReadyGateViolated ? 'VIOLATION' : 'OK') : 'disabled'} ($_guardTelemetryLiveReadyGateReason).';
    final issues = <String>[];
    if (!widget.supabaseReady) {
      issues.add(
        OnyxRuntimeConfig.hasPlaceholderSupabaseUrl(
                  const String.fromEnvironment('SUPABASE_URL'),
                ) ||
                OnyxRuntimeConfig.hasPlaceholderSecret(
                  const String.fromEnvironment('SUPABASE_ANON_KEY'),
                )
            ? 'Supabase is running in-memory because the configured values are still placeholders. Run with local defines: ./scripts/run_onyx_chrome_local.sh'
            : 'Supabase is running in-memory because SUPABASE_URL or SUPABASE_ANON_KEY is not configured. Run with local defines: ./scripts/run_onyx_chrome_local.sh',
      );
    }
    if (OnyxRuntimeConfig.hasPlaceholderLiveFeedUrl(_liveFeedPollUrl)) {
      issues.add(
        'Live feed polling is disabled until ONYX_LIVE_FEED_URL is replaced.',
      );
    }
    if (OnyxRuntimeConfig.hasPlaceholderSecret(_liveFeedPollBearerToken)) {
      issues.add(
        'The live feed bearer token is a placeholder and will be ignored.',
      );
    }
    if (issues.isEmpty) {
      if (_guardSyncUsingBackend || _guardSyncQueueDepth > 0) {
        return _guardSyncUsingBackend
            ? 'Guard sync backend: Supabase primary with local fallback. Pending queue: $_guardSyncQueueDepth. Guard ops events: $_guardOpsPendingEvents pending, media: $_guardOpsPendingMedia pending.$guardThresholdHint$guardHistoryThresholdHint$guardTelemetryHint$guardTelemetryGateHint'
            : 'Guard sync backend: local fallback only. Pending queue: $_guardSyncQueueDepth. Guard ops events: $_guardOpsPendingEvents pending, media: $_guardOpsPendingMedia pending.$guardThresholdHint$guardHistoryThresholdHint$guardTelemetryHint$guardTelemetryGateHint';
      }
      return null;
    }
    issues.add(
      _guardSyncUsingBackend
          ? 'Guard sync backend is enabled (Supabase primary + local fallback). Pending queue: $_guardSyncQueueDepth. Guard ops events: $_guardOpsPendingEvents pending, media: $_guardOpsPendingMedia pending.$guardThresholdHint$guardHistoryThresholdHint$guardTelemetryHint$guardTelemetryGateHint'
          : 'Guard sync backend is currently local-only. Pending queue: $_guardSyncQueueDepth. Guard ops events: $_guardOpsPendingEvents pending, media: $_guardOpsPendingMedia pending.$guardThresholdHint$guardHistoryThresholdHint$guardTelemetryHint$guardTelemetryGateHint',
    );
    return issues.join(' ');
  }

  void _scheduleNextLivePoll(int delaySeconds) {
    _livePollTimer?.cancel();
    if (!_livePolling) {
      _livePollTimer = null;
      return;
    }
    _livePollTimer = Timer(Duration(seconds: delaySeconds), () {
      _pollLiveFeedOnce();
    });
  }

  int _backoffDelaySeconds(int consecutiveFailures) {
    final base = _normalizedPollIntervalSeconds;
    final multiplier = 1 << consecutiveFailures;
    final delayed = base * multiplier;
    if (delayed > 300) {
      return 300;
    }
    return delayed;
  }

  String? get _livePollingLabel {
    if (!_livePollingAvailable) {
      if (OnyxRuntimeConfig.hasPlaceholderLiveFeedUrl(_liveFeedPollUrl)) {
        return 'Polling unavailable: replace the example ONYX_LIVE_FEED_URL placeholder.';
      }
      if (_liveFeedPollUrl.trim().isEmpty) {
        return 'Polling unavailable: set ONYX_LIVE_FEED_URL to enable live feed polling.';
      }
      return null;
    }
    final endpoint = _liveFeedPollEndpoint;
    final status = _livePolling
        ? (_livePollRequestInFlight ? 'polling now' : 'active')
        : (_hasCachedLivePollSummary ? 'idle (cached)' : 'idle');
    final failureSuffix = _livePollFailures > 0
        ? ' • failures: $_livePollFailures'
        : '';
    final authSuffix = _liveFeedAuthConfigured ? ' • auth on' : '';
    final delaySuffix = _livePolling && _livePollDelaySeconds > 0
        ? ' • next in ${_livePollDelaySeconds}s'
        : '';
    final latencySuffix = _lastLivePollLatencyMs == null
        ? ''
        : ' • last latency ${_lastLivePollLatencyMs}ms';
    final lastSuccessSuffix = _lastLivePollSuccessAtUtc == null
        ? ''
        : ' • last ok ${_formatPollMoment(_lastLivePollSuccessAtUtc!)}';
    final lastFailureSuffix = _lastLivePollFailureAtUtc == null
        ? ''
        : ' • last fail ${_formatPollMoment(_lastLivePollFailureAtUtc!)}';
    final errorSuffix = _lastLivePollError == null
        ? ''
        : ' • error ${_truncatePollError(_lastLivePollError!)}';
    return 'Polling: $status • every ${_normalizedPollIntervalSeconds}s$delaySuffix • $endpoint$authSuffix$failureSuffix$latencySuffix$lastSuccessSuffix$lastFailureSuffix$errorSuffix';
  }

  String _formatPollMoment(DateTime value) {
    final utc = value.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}Z';
  }

  String _truncatePollError(String value) {
    if (value.length <= 48) {
      return value;
    }
    return '${value.substring(0, 48)}...';
  }

  bool get _hasCachedLivePollSummary {
    return _lastLivePollLatencyMs != null ||
        _lastLivePollSuccessAtUtc != null ||
        _lastLivePollFailureAtUtc != null ||
        _lastLivePollError != null ||
        _livePollFailures > 0 ||
        _livePollDelaySeconds > 0;
  }

  void _pushLivePollingHistory(String message) {
    final timestamp = _formatPollMoment(DateTime.now().toUtc());
    _livePollingHistory = [
      '$timestamp • $message',
      ..._livePollingHistory,
    ].take(6).toList(growable: false);
    _persistLivePollHistory();
    _persistLivePollSummary();
  }

  int? _summaryInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  bool? _summaryBool(Object? value) {
    if (value is bool) return value;
    if (value is num) {
      if (value == 1) return true;
      if (value == 0) return false;
      return null;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'on') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'off') {
        return false;
      }
    }
    return null;
  }

  Map<String, Object?>? _asObjectMap(Object? value) {
    if (value is! Map) return null;
    return value.map((key, entryValue) {
      return MapEntry(key.toString(), entryValue as Object?);
    });
  }

  DateTime? _summaryDate(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value)?.toUtc();
  }

  String? _summaryString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
