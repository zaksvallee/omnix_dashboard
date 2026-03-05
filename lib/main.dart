import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'application/client_conversation_repository.dart';
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
import 'application/runtime_config.dart';
import 'domain/authority/operator_context.dart';
import 'domain/events/decision_created.dart';
import 'domain/events/guard_checked_in.dart';
import 'domain/events/incident_closed.dart';
import 'domain/events/intelligence_received.dart';
import 'domain/events/patrol_completed.dart';
import 'domain/events/response_arrived.dart';
import 'domain/evidence/client_ledger_repository.dart';
import 'domain/evidence/client_ledger_service.dart';
import 'domain/guard/guard_ops_event.dart';
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
import 'presentation/reports/report_test_harness.dart';
import 'ui/app_shell.dart';
import 'ui/client_app_page.dart';
import 'ui/dashboard_page.dart';
import 'ui/dispatch_page.dart';
import 'ui/events_page.dart';
import 'ui/guard_mobile_shell_page.dart';
import 'ui/ledger_page.dart';
import 'ui/sites_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

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
  static const _clientAppLocaleEnv = String.fromEnvironment(
    'ONYX_CLIENT_APP_LOCALE',
    defaultValue: 'en',
  );
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
  Timer? _guardOpsSyncTimer;
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
    _refreshGuardTelemetryAdapterStatus();
    _startGuardOpsSyncLoop();
  }

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
    _guardOpsSyncTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
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
    await repository.enqueueEvent(
      guardId: 'GUARD-001',
      siteId: _selectedSite,
      shiftId: _activeGuardShiftId,
      eventType: type,
      deviceId: 'ANDROID-BV5300PRO-001',
      appVersion: 'guard-shell-v1',
      payload: payload,
      occurredAt: DateTime.now().toUtc(),
    );
    await _hydrateGuardOpsState();
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
    final verificationEvent = await repository.enqueueEvent(
      guardId: 'GUARD-001',
      siteId: _selectedSite,
      shiftId: _activeGuardShiftId,
      eventType: GuardOpsEventType.shiftVerificationImage,
      deviceId: 'ANDROID-BV5300PRO-001',
      appVersion: 'guard-shell-v1',
      payload: {
        'camera_mode': 'self_verification',
        'uniform_check_required': true,
        'quality_gate_required': true,
        'quality_gate': {
          'accepted': quality.accepted,
          'issues': quality.issues.map((issue) => issue.name).toList(),
          'method': quality.method,
        },
      },
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
      ),
    );
    await repository.enqueueEvent(
      guardId: 'GUARD-001',
      siteId: _selectedSite,
      shiftId: _activeGuardShiftId,
      eventType: GuardOpsEventType.shiftStart,
      deviceId: 'ANDROID-BV5300PRO-001',
      appVersion: 'guard-shell-v1',
      payload: {'verification_event_id': verificationEvent.eventId},
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
    final patrolEvent = await repository.enqueueEvent(
      guardId: 'GUARD-001',
      siteId: _selectedSite,
      shiftId: _activeGuardShiftId,
      eventType: GuardOpsEventType.patrolImageCaptured,
      deviceId: 'ANDROID-BV5300PRO-001',
      appVersion: 'guard-shell-v1',
      payload: {
        'checkpoint_id': checkpointId,
        'verification_required': true,
        'quality_gate': {
          'accepted': quality.accepted,
          'issues': quality.issues.map((issue) => issue.name).toList(),
          'method': quality.method,
        },
      },
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
        'actor_role': GuardMobileOperatorRole.reaction.name,
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
        'actor_role': GuardMobileOperatorRole.reaction.name,
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
        'actor_role': GuardMobileOperatorRole.reaction.name,
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
        'actor_role': GuardMobileOperatorRole.supervisor.name,
      },
    );
    await _hydrateGuardSyncState();
  }

  Future<void> _queueSupervisorCoachingAcknowledgement() async {
    await _enqueueGuardOpsEvent(
      type: GuardOpsEventType.supervisorCoachingAcknowledged,
      payload: {
        'actor_role': GuardMobileOperatorRole.supervisor.name,
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

  Future<void> _emitDebugFskSdkHeartbeatBroadcast() async {
    final adapter = _guardTelemetryAdapter;
    if (!kDebugMode ||
        kIsWeb ||
        adapter is! NativeGuardTelemetryIngestionAdapter) {
      throw StateError(
        'Debug SDK heartbeat broadcast is only available for native adapter debug builds.',
      );
    }
    await adapter.emitDebugFskSdkHeartbeatBroadcast();
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
    final response = await adapter.validateFskPayloadMapping(
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
        'actor_role': actorRole,
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

  Future<void> _ingestNewsSignals() async {
    setState(() {
      _lastIntakeStatus = 'Fetching news intelligence...';
    });
    try {
      final batch = await _newsIntel.fetchLatest(
        clientId: _selectedClient,
        regionId: _selectedRegion,
        siteId: _selectedSite,
      );
      final runId = _nextRunId('NEWS');
      _recordLiveIngest(
        runId: runId,
        batch: LiveFeedBatch(
          records: batch.records,
          feedDistribution: batch.feedDistribution,
          isConfigured: true,
          sourceLabel: batch.sourceLabel,
        ),
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        _lastIntakeStatus = 'News intelligence ingest failed: ${error.message}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _lastIntakeStatus = 'News intelligence ingest failed: $error';
      });
    }
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

  void _recordLiveIngest({
    required String runId,
    required LiveFeedBatch batch,
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
      _lastIntakeStatus =
          'Ingested ${outcome.appendedIntelligence}/${outcome.attemptedIntelligence} intel from ${batch.feedCount} feeds (${batch.sourceLabel}) • '
          'Skipped ${outcome.skippedIntelligence} • '
          'Triage A/W/DC ${outcome.advisoryCount}/${outcome.watchCount}/${outcome.dispatchCandidateCount} • '
          'Auto-created ${outcome.createdDecisions} dispatch decisions';
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AppShell(
        currentRoute: _route,
        onRouteChanged: (r) => setState(() => _route = r),
        child: _buildPage(),
      ),
    );
  }

  Widget _buildPage() {
    switch (_route) {
      case OnyxRoute.dashboard:
        return DashboardPage(
          eventStore: store,
          guardSyncBackendEnabled: _guardSyncUsingBackend,
          guardSyncInFlight: _guardOpsSyncInFlight,
          guardSyncQueueDepth: _guardSyncQueueDepth,
          guardPendingEvents: _guardOpsPendingEvents,
          guardPendingMedia: _guardOpsPendingMedia,
          guardFailedEvents: _guardOpsFailedEvents,
          guardFailedMedia: _guardOpsFailedMedia,
          guardOutcomePolicyDeniedCount: _guardOutcomePolicyDeniedCount,
          guardOutcomePolicyDeniedLastReason:
              _guardOutcomePolicyDeniedLastReason,
          guardOutcomePolicyDenied24h: _guardOutcomeDeniedInWindow(
            const Duration(hours: 24),
          ),
          guardOutcomePolicyDenied7d: _guardOutcomeDeniedInWindow(
            const Duration(days: 7),
          ),
          guardOutcomePolicyDeniedHistoryUtc:
              _guardOutcomePolicyDeniedHistoryUtc,
          guardCoachingAckCount: _guardCoachingAckCount,
          guardCoachingSnoozeCount: _guardCoachingSnoozeCount,
          guardCoachingSnoozeExpiryCount: _guardCoachingSnoozeExpiryCount,
          guardCoachingRecentHistory: _guardCoachingRecentHistory,
          guardSyncStatusLabel: _guardOpsLastSyncLabel,
          guardLastSuccessfulSyncAtUtc: _guardOpsLastSuccessfulSyncAtUtc,
          guardLastFailureReason: _guardOpsLastFailureReason,
          onOpenGuardSync: _openGuardSyncFromDashboard,
          onClearGuardOutcomePolicyTelemetry: _clearGuardOutcomePolicyTelemetry,
          guardFailureAlertThreshold: _positiveThreshold(
            _guardFailureAlertThresholdEnv,
            fallback: 1,
          ),
          guardQueuePressureAlertThreshold: _positiveThreshold(
            _guardQueuePressureAlertThresholdEnv,
            fallback: 25,
          ),
          guardStaleSyncAlertMinutes: _positiveThreshold(
            _guardStaleSyncAlertMinutesEnv,
            fallback: 10,
          ),
          guardRecentEvents: _guardOpsRecentEvents,
          guardRecentMedia: _guardOpsRecentMedia,
        );

      case OnyxRoute.clients:
        return ClientAppPage(
          clientId: _selectedClient,
          siteId: _selectedSite,
          locale: _clientAppLocale,
          events: store.allEvents(),
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

      case OnyxRoute.sites:
        return SitesPage(events: store.allEvents());

      case OnyxRoute.guards:
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
          telemetryFacadeSourceActive: _guardTelemetryFacadeSourceActive,
          telemetryFacadeCallbackCount: _guardTelemetryFacadeCallbackCount,
          telemetryFacadeLastCallbackAtUtc:
              _guardTelemetryFacadeLastCallbackAtUtc,
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
          scopedSelectionKeys:
              (_guardSyncSelectedOperationIdByFilter.keys.toList(
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
              ? _emitDebugFskSdkHeartbeatBroadcast
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
            _ingestLiveFeedBatch();
          },
          onIngestNews: () {
            _ingestNewsSignals();
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
          events: store.allEvents(),
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
        return EventsPage(events: store.allEvents());

      case OnyxRoute.ledger:
        return LedgerPage(
          clientId: _selectedClient,
          supabaseEnabled: widget.supabaseReady,
          events: store.allEvents(),
        );

      case OnyxRoute.reports:
        return ReportTestHarnessPage(
          store: store,
          selectedClient: _selectedClient,
          selectedSite: _selectedSite,
        );
    }
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
