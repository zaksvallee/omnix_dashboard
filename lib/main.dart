import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'application/client_conversation_repository.dart';
import 'application/cctv_bridge_service.dart';
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
import 'application/morning_sovereign_report_service.dart';
import 'application/ops_integration_profile.dart';
import 'application/radio_bridge_service.dart';
import 'application/runtime_config.dart';
import 'application/wearable_bridge_service.dart';
import 'domain/authority/operator_context.dart';
import 'domain/events/decision_created.dart';
import 'domain/events/dispatch_event.dart';
import 'domain/events/execution_completed.dart';
import 'domain/events/execution_denied.dart';
import 'domain/events/guard_checked_in.dart';
import 'domain/events/incident_closed.dart';
import 'domain/events/intelligence_received.dart';
import 'domain/events/patrol_completed.dart';
import 'domain/events/response_arrived.dart';
import 'domain/evidence/client_ledger_repository.dart';
import 'domain/evidence/client_ledger_service.dart';
import 'domain/guard/guard_ops_event.dart';
import 'domain/guard/guard_event_contract.dart';
import 'domain/guard/guard_mobile_ops.dart';
import 'domain/guard/operational_tiers.dart';
import 'domain/guard/outcome_label_governance.dart';
import 'domain/guard/guard_sync_coaching_policy.dart';
import 'domain/guard/guard_sync_selection_scope.dart';
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
  late final OnyxAppMode _appMode = _resolveAppMode();
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
      );
  late final RadioBridgeService _radioBridgeService = createRadioBridgeService(
    provider: _opsIntegrationProfile.radio.provider,
    listenUri: _opsIntegrationProfile.radio.listenUrl,
    respondUri: _opsIntegrationProfile.radio.respondUrl,
    bearerToken: _radioBearerTokenEnv,
    client: _radioBridgeHttpClient,
  );
  late final CctvBridgeService _cctvBridgeService = createCctvBridgeService(
    provider: _opsIntegrationProfile.cctv.provider,
    eventsUri: _opsIntegrationProfile.cctv.eventsUrl,
    bearerToken: _cctvBearerTokenEnv,
    liveMonitoringEnabled: _opsIntegrationProfile.cctv.liveMonitoringEnabled,
    facialRecognitionEnabled:
        _opsIntegrationProfile.cctv.facialRecognitionEnabled,
    licensePlateRecognitionEnabled:
        _opsIntegrationProfile.cctv.licensePlateRecognitionEnabled,
    client: _cctvBridgeHttpClient,
  );
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
  late final ClientAppLocale _clientAppLocale = ClientAppLocaleParser.fromCode(
    _clientAppLocaleEnv,
  );
  final store = InMemoryEventStore();
  late final DispatchApplicationService service;
  late final IntakeStressService stressService;
  late final Future<DispatchPersistenceService> _persistenceServiceFuture;
  late final Future<ClientConversationRepository>
  _clientConversationRepositoryFuture;
  late final Future<GuardOpsRepository> _guardOpsRepositoryFuture;
  late final Future<GuardSyncRepository> _guardSyncRepositoryFuture;
  late final Future<GuardMobileOpsService> _guardMobileOpsServiceFuture;

  OnyxRoute _route = OnyxRoute.dashboard;
  String _eventsSourceFilter = '';
  String _eventsProviderFilter = '';
  String _eventsSelectedEventId = '';

  final String _selectedClient = 'CLIENT-001';
  final String _selectedRegion = 'REGION-GAUTENG';
  final String _selectedSite = 'SITE-SANDTON';

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
  String _clientAppBackendProbeStatusLabel = 'idle';
  DateTime? _clientAppBackendProbeLastRunAtUtc;
  String? _clientAppBackendProbeFailureReason;
  List<ClientBackendProbeAttempt> _clientAppBackendProbeHistory = const [];
  List<NewsSourceDiagnostic> _newsSourceDiagnostics = const [];
  String _radioIntentPhrasesJsonOverride = '';
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
  String? _morningSovereignReportAutoRunKey;
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
  _OpsIntegrationHealth _newsOpsHealth = const _OpsIntegrationHealth();
  bool _opsIntegrationPollInFlight = false;
  DateTime? _lastGuardResumeSyncEventQueuedAtUtc;
  late final OutcomeLabelGovernancePolicy _outcomeGovernancePolicy;

  int get _guardResumeSyncEventThrottleSeconds {
    return _positiveThreshold(
      _guardResumeSyncEventThrottleSecondsEnv,
      fallback: 20,
    );
  }

  int _positiveThreshold(int raw, {required int fallback}) {
    return raw > 0 ? raw : fallback;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

    final ClientLedgerRepository repository = widget.supabaseReady
        ? SupabaseClientLedgerRepository(Supabase.instance.client)
        : InMemoryClientLedgerRepository();

    final operator = OperatorContext(
      operatorId: 'OPERATOR-01',
      allowedRegions: {'REGION-GAUTENG'},
      allowedSites: {'SITE-SANDTON'},
    );

    service = DispatchApplicationService(
      store: store,
      engine: ExecutionEngine(),
      policy: RiskPolicy(escalationThreshold: 70),
      ledgerService: ClientLedgerService(repository),
      operator: operator,
    );
    stressService = IntakeStressService(store: store, service: service);
    _newsIntel = NewsIntelligenceService();
    _newsSourceDiagnostics = _newsIntel.diagnostics;

    _seedDemoData();
    _hydrateTelemetry();
    _hydrateLivePollHistory();
    _hydrateLivePollSummary();
    _hydrateNewsSourceDiagnostics();
    _hydrateRadioIntentPhraseConfig();
    _hydratePendingRadioAutomatedResponses();
    _hydrateOpsIntegrationHealthSnapshot();
    _hydrateStressProfile();
    _hydrateClientAppDraft();
    _hydrateGuardSyncState();
    _hydrateGuardOpsState();
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
    _startOpsIntegrationPollingLoop();
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _livePollTimer?.cancel();
    _opsIntegrationPollTimer?.cancel();
    _guardOpsSyncTimer?.cancel();
    _radioBridgeHttpClient.close();
    _cctvBridgeHttpClient.close();
    _wearableBridgeHttpClient.close();
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
      }
      return;
    }
    _startOpsIntegrationPollingLoop();
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
    final newsRaw = _asObjectMap(snapshot['news']);
    if (!mounted) {
      if (radioRaw != null) {
        _radioOpsHealth = _OpsIntegrationHealth.fromJson(radioRaw);
      }
      if (cctvRaw != null) {
        _cctvOpsHealth = _OpsIntegrationHealth.fromJson(cctvRaw);
      }
      if (wearableRaw != null) {
        _wearableOpsHealth = _OpsIntegrationHealth.fromJson(wearableRaw);
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
      if (wearableRaw != null) {
        _wearableOpsHealth = _OpsIntegrationHealth.fromJson(wearableRaw);
      }
      if (newsRaw != null) {
        _newsOpsHealth = _OpsIntegrationHealth.fromJson(newsRaw);
      }
    });
  }

  Future<void> _persistOpsIntegrationHealthSnapshot() async {
    final persistence = await _persistenceServiceFuture;
    await persistence.saveOpsIntegrationHealthSnapshot({
      'radio': _radioOpsHealth.toJson(),
      'cctv': _cctvOpsHealth.toJson(),
      'wearable': _wearableOpsHealth.toJson(),
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
      _clientAppBackendProbeStatusLabel =
          storedPushSyncState.backendProbeStatusLabel;
      _clientAppBackendProbeLastRunAtUtc =
          storedPushSyncState.backendProbeLastRunAtUtc;
      _clientAppBackendProbeFailureReason =
          storedPushSyncState.backendProbeFailureReason;
      _clientAppBackendProbeHistory = storedPushSyncState.backendProbeHistory;
    });
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

  void _startGuardOpsSyncLoop() {
    _guardOpsSyncTimer?.cancel();
    if (!widget.supabaseReady) return;
    _scheduleGuardOpsSync(delaySeconds: _guardOpsBaseSyncIntervalSeconds);
  }

  void _scheduleGuardOpsSync({required int delaySeconds}) {
    _guardOpsSyncTimer?.cancel();
    _guardOpsSyncTimer = Timer(Duration(seconds: delaySeconds), () async {
      await _syncGuardOpsNow(background: true);
    });
  }

  int _guardOpsBackoffDelaySeconds(int failures) {
    final multiplier = 1 << failures;
    final delayed = _guardOpsBaseSyncIntervalSeconds * multiplier;
    if (delayed > 300) {
      return 300;
    }
    return delayed;
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
    final autoRunKey = await persistence.readMorningSovereignReportAutoRunKey();
    SovereignReport? report;
    if (rawReport.isNotEmpty) {
      try {
        report = SovereignReport.fromJson(rawReport);
      } catch (_) {
        await persistence.clearMorningSovereignReport();
      }
    }
    if (mounted) {
      setState(() {
        _morningSovereignReport = report;
        _morningSovereignReportAutoRunKey = autoRunKey;
      });
    } else {
      _morningSovereignReport = report;
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

  Future<void> _persistMorningSovereignReportAutoRunKey() async {
    final persistence = await _persistenceServiceFuture;
    final key = (_morningSovereignReportAutoRunKey ?? '').trim();
    if (key.isEmpty) {
      await persistence.clearMorningSovereignReportAutoRunKey();
    } else {
      await persistence.saveMorningSovereignReportAutoRunKey(key);
    }
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
    final report = service.generate(
      nowUtc: nowUtc,
      events: store.allEvents(),
      recentMedia: _guardOpsRecentMedia,
      guardOutcomePolicyDenied24h: _guardOutcomeDeniedInWindow(
        const Duration(hours: 24),
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
        _morningSovereignReportAutoRunKey = nextAutoRunKey.isEmpty
            ? null
            : nextAutoRunKey;
      });
    } else {
      _morningSovereignReport = report;
      _morningSovereignReportAutoRunKey = nextAutoRunKey.isEmpty
          ? null
          : nextAutoRunKey;
    }
    await _persistMorningSovereignReport();
    await _persistMorningSovereignReportAutoRunKey();
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
    List<ClientAppPushDeliveryItem> pushQueue,
  ) async {
    _clientAppPushQueue = List<ClientAppPushDeliveryItem>.from(pushQueue);
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

  Future<void> _retryClientAppPushSync() async {
    await _persistClientAppPushQueue(_clientAppPushQueue);
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
    if (!_opsIntegrationProfile.cctv.configured) {
      if (updateStatus && mounted) {
        setState(() {
          _lastIntakeStatus =
              'CCTV ingest unavailable: configure ONYX_CCTV_PROVIDER and ONYX_CCTV_EVENTS_URL.';
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
        _lastIntakeStatus = 'Fetching CCTV AI events...';
      });
    }
    try {
      final records = await _cctvBridgeService.fetchLatest(
        clientId: _selectedClient,
        regionId: _selectedRegion,
        siteId: _selectedSite,
      );
      final provider = _opsIntegrationProfile.cctv.provider;
      final runId = _nextRunId('CCTV');
      final outcome = _recordLiveIngest(
        runId: runId,
        batch: LiveFeedBatch(
          records: records,
          feedDistribution: {
            (provider.trim().isEmpty ? 'cctv' : provider): records.length,
          },
          isConfigured: true,
          sourceLabel: 'cctv-${provider.trim().isEmpty ? 'events' : provider}',
        ),
        updateStatus: updateStatus,
      );
      return _recordOpsIntegrationHealth(
        _OpsIntegrationIngestResult(
          source: 'cctv',
          success: true,
          detail:
              '${outcome.appendedIntelligence}/${outcome.attemptedIntelligence} appended',
        ),
      );
    } on FormatException catch (error) {
      if (updateStatus && mounted) {
        setState(() {
          _lastIntakeStatus = 'CCTV ingest failed: ${error.message}';
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
          _lastIntakeStatus = 'CCTV ingest failed: $error';
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
    final compactDetail = detail.length <= 56
        ? detail
        : '${detail.substring(0, 56).trimRight()}...';
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
    if (!_opsIntegrationProfile.cctv.configured) {
      return 'caps none';
    }
    final caps = _opsIntegrationProfile.cctv.capabilityLabels;
    if (caps.isEmpty) {
      return 'caps none';
    }
    return 'caps ${caps.join(' • ')}';
  }

  String _cctvRecentSignalSummary(List<DispatchEvent> events) {
    final nowUtc = DateTime.now().toUtc();
    final windowStartUtc = nowUtc.subtract(const Duration(hours: 6));
    final configuredProvider = _opsIntegrationProfile.cctv.provider
        .trim()
        .toLowerCase();
    var total = 0;
    var intrusion = 0;
    var lineCrossing = 0;
    var motion = 0;
    var fr = 0;
    var lpr = 0;

    for (final event in events.whereType<IntelligenceReceived>()) {
      if (event.sourceType != 'hardware') {
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

    return 'recent hardware intel $total (6h) • '
        'intrusion $intrusion • '
        'line_crossing $lineCrossing • '
        'motion $motion • '
        'fr $fr • '
        'lpr $lpr';
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
        _opsIntegrationProfile.cctv.configured ||
        wearableConfigured ||
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
      if (_opsIntegrationProfile.cctv.configured) {
        results.add(await _ingestCctvSignals(updateStatus: false));
      }
      if (_wearableProviderEnv.trim().isNotEmpty &&
          _wearableBridgeUri != null) {
        results.add(await _ingestWearableSignals(updateStatus: false));
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
    const clientId = 'CLIENT-001';
    const regionId = 'REGION-GAUTENG';
    const siteId = 'SITE-SANDTON';
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
          _route = r;
          _eventsSourceFilter = '';
          _eventsProviderFilter = '';
          _eventsSelectedEventId = '';
        }),
        onIntelTickerTap: _focusEventsFromTickerItem,
        activeIncidentCount: _activeIncidentCount(events),
        aiActionCount: _pendingAiActionCount(events),
        guardsOnlineCount: _guardsOnlineCount(events),
        complianceIssuesCount: _complianceIssuesCount(),
        tacticalSosAlerts: _tacticalSosAlerts(),
        intelTickerItems: _intelTickerItems(events),
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
    final source = _normalizeIntelSourceFilter(item.sourceType);
    final provider = _normalizeIntelProviderFilter(item.provider);
    final selectedEventId = _resolveTickerEventId(item);
    setState(() {
      _route = OnyxRoute.events;
      _eventsSourceFilter = source;
      _eventsProviderFilter = provider;
      _eventsSelectedEventId = selectedEventId ?? '';
    });
  }

  String _normalizeIntelSourceFilter(String sourceType) {
    var normalized = sourceType.trim().toUpperCase();
    if (normalized.isEmpty || normalized == 'ALL') {
      return '';
    }
    if (normalized == 'CCTV') {
      normalized = 'HARDWARE';
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
        return LiveOperationsPage(events: events);

      case OnyxRoute.aiQueue:
        return AIQueuePage(events: events);

      case OnyxRoute.tactical:
        return TacticalPage(
          events: events,
          cctvOpsReadiness: _opsIntegrationProfile.cctv.readinessLabel,
          cctvOpsDetail: _opsIntegrationProfile.cctv.detailLabel,
          cctvProvider: _opsIntegrationProfile.cctv.provider,
          cctvCapabilitySummary: _cctvCapabilitySummary(),
          cctvRecentSignalSummary: _cctvRecentSignalSummary(events),
        );

      case OnyxRoute.governance:
        return GovernancePage(
          events: events,
          morningSovereignReport: _morningSovereignReport,
          morningSovereignReportAutoRunKey: _morningSovereignReportAutoRunKey,
          onGenerateMorningSovereignReport: () async {
            await _generateMorningSovereignReport();
          },
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
          cctvOpsReadiness: _opsIntegrationProfile.cctv.readinessLabel,
          cctvOpsDetail: _opsIntegrationProfile.cctv.detailLabel,
          cctvCapabilitySummary: _cctvCapabilitySummary(),
          cctvRecentSignalSummary: _cctvRecentSignalSummary(events),
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
          onExecute: (dispatchId) {
            setState(() {
              service.execute(
                clientId: _selectedClient,
                regionId: _selectedRegion,
                siteId: _selectedSite,
                dispatchId: dispatchId,
              );
            });
          },
        );

      case OnyxRoute.events:
        return EventsReviewPage(
          events: events,
          initialSourceFilter: _eventsSourceFilter.trim().isEmpty
              ? null
              : _eventsSourceFilter,
          initialProviderFilter: _eventsProviderFilter.trim().isEmpty
              ? null
              : _eventsProviderFilter,
          initialSelectedEventId: _eventsSelectedEventId.trim().isEmpty
              ? null
              : _eventsSelectedEventId,
        );

      case OnyxRoute.ledger:
        return SovereignLedgerPage(clientId: _selectedClient, events: events);

      case OnyxRoute.reports:
        return ClientIntelligenceReportsPage(
          store: store,
          selectedClient: _selectedClient,
          selectedSite: _selectedSite,
        );

      case OnyxRoute.admin:
        return AdministrationPage(
          events: events,
          initialRadioIntentPhrasesJson: _radioIntentPhrasesJsonOverride,
          onSaveRadioIntentPhrasesJson: _saveRadioIntentPhraseConfig,
          onResetRadioIntentPhrasesJson: _clearRadioIntentPhraseConfig,
          onRunOpsIntegrationPoll: _opsIntegrationPollingAvailable
              ? _pollOpsIntegrationOnce
              : null,
          onRunRadioPoll: _opsIntegrationProfile.radio.configured
              ? () async {
                  await _ingestRadioOpsSignals();
                }
              : null,
          onRunCctvPoll: _opsIntegrationProfile.cctv.configured
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
          cctvOpsPollHealth: _opsHealthSummary(_cctvOpsHealth),
          cctvCapabilitySummary: _cctvCapabilitySummary(),
          cctvRecentSignalSummary: _cctvRecentSignalSummary(events),
          wearableOpsPollHealth: _opsHealthSummary(_wearableOpsHealth),
          newsOpsPollHealth: _opsHealthSummary(_newsOpsHealth),
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
