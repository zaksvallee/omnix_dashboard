import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../application/morning_sovereign_report_service.dart';
import '../application/client_messaging_bridge_repository.dart';
import '../application/monitoring_global_posture_service.dart';
import '../application/monitoring_identity_policy_service.dart';
import '../application/monitoring_orchestrator_service.dart';
import '../application/monitoring_scene_review_store.dart';
import '../application/monitoring_synthetic_war_room_service.dart';
import '../application/monitoring_watch_recovery_policy.dart';
import '../application/monitoring_watch_recovery_store.dart';
import '../application/ops_integration_profile.dart';
import '../application/site_identity_registry_repository.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/listener_alarm_advisory_recorded.dart';
import '../domain/events/listener_alarm_feed_cycle_recorded.dart';
import '../domain/events/listener_alarm_parity_cycle_recorded.dart';
import '../domain/events/partner_dispatch_status_declared.dart';
import 'onyx_surface.dart';
import 'video_fleet_scope_health_card.dart';
import 'video_fleet_scope_health_panel.dart';
import 'video_fleet_scope_health_sections.dart';
import 'video_fleet_scope_health_view.dart';

enum AdministrationPageTab { guards, sites, clients, system }

enum _AdminTab { guards, sites, clients, system }

enum _IdentityRuleBucket {
  flaggedFaces,
  flaggedPlates,
  allowedFaces,
  allowedPlates,
}

enum _AdminStatus { active, inactive, suspended }

class _GuardAdminRow {
  final String id;
  final String name;
  final String role;
  final String employeeId;
  final String phone;
  final String email;
  final String psiraNumber;
  final String? psiraExpiry;
  final List<String> certifications;
  final String assignedSite;
  final String shiftPattern;
  final String emergencyContact;
  final _AdminStatus status;

  const _GuardAdminRow({
    required this.id,
    required this.name,
    required this.role,
    required this.employeeId,
    required this.phone,
    required this.email,
    required this.psiraNumber,
    this.psiraExpiry,
    required this.certifications,
    required this.assignedSite,
    required this.shiftPattern,
    required this.emergencyContact,
    required this.status,
  });
}

class _SiteAdminRow {
  final String id;
  final String name;
  final String code;
  final String clientId;
  final String address;
  final double lat;
  final double lng;
  final String contactPerson;
  final String contactPhone;
  final String? fskNumber;
  final int geofenceRadiusMeters;
  final _AdminStatus status;

  const _SiteAdminRow({
    required this.id,
    required this.name,
    required this.code,
    required this.clientId,
    required this.address,
    required this.lat,
    required this.lng,
    required this.contactPerson,
    required this.contactPhone,
    this.fskNumber,
    required this.geofenceRadiusMeters,
    required this.status,
  });
}

class _ClientAdminRow {
  final String id;
  final String name;
  final String code;
  final String contactPerson;
  final String contactEmail;
  final String contactPhone;
  final String slaTier;
  final String contractStart;
  final String contractEnd;
  final int sites;
  final _AdminStatus status;

  const _ClientAdminRow({
    required this.id,
    required this.name,
    required this.code,
    required this.contactPerson,
    required this.contactEmail,
    required this.contactPhone,
    required this.slaTier,
    required this.contractStart,
    required this.contractEnd,
    required this.sites,
    required this.status,
  });
}

class _DemoScenarioOption {
  final String value;
  final String label;
  final String detail;

  const _DemoScenarioOption({
    required this.value,
    required this.label,
    required this.detail,
  });
}

class _PreviewGate {
  final String label;
  final bool ready;
  final int step;

  const _PreviewGate({
    required this.label,
    required this.ready,
    required this.step,
  });
}

class _DemoCoachCue {
  final String stage;
  final String narration;
  final String proofPoint;

  const _DemoCoachCue({
    required this.stage,
    required this.narration,
    required this.proofPoint,
  });
}

class _DemoOperationsSeedResult {
  final String? vehicleCallsign;
  final String? incidentEventUid;
  final List<String> warnings;

  const _DemoOperationsSeedResult({
    this.vehicleCallsign,
    this.incidentEventUid,
    this.warnings = const <String>[],
  });
}

class _AdminPartnerTrendRow {
  final String clientId;
  final String siteId;
  final String partnerLabel;
  final int reportDays;
  final int dispatchCount;
  final int strongCount;
  final int onTrackCount;
  final int watchCount;
  final int criticalCount;
  final double averageAcceptedDelayMinutes;
  final double averageOnSiteDelayMinutes;
  final String currentScoreLabel;
  final String trendLabel;
  final String trendReason;

  const _AdminPartnerTrendRow({
    required this.clientId,
    required this.siteId,
    required this.partnerLabel,
    required this.reportDays,
    required this.dispatchCount,
    required this.strongCount,
    required this.onTrackCount,
    required this.watchCount,
    required this.criticalCount,
    required this.averageAcceptedDelayMinutes,
    required this.averageOnSiteDelayMinutes,
    required this.currentScoreLabel,
    required this.trendLabel,
    required this.trendReason,
  });
}

class _AdminPartnerTrendAggregate {
  final String clientId;
  final String siteId;
  final String partnerLabel;
  final Set<String> reportDates = <String>{};
  int dispatchCount = 0;
  int strongCount = 0;
  int onTrackCount = 0;
  int watchCount = 0;
  int criticalCount = 0;
  double acceptedDelayWeightedSum = 0;
  double acceptedDelayWeight = 0;
  double onSiteDelayWeightedSum = 0;
  double onSiteDelayWeight = 0;
  final List<double> priorSeverityScores = <double>[];
  final List<double> priorAcceptedDelayMinutes = <double>[];
  final List<double> priorOnSiteDelayMinutes = <double>[];
  SovereignReportPartnerScoreboardRow? currentRow;

  _AdminPartnerTrendAggregate({
    required this.clientId,
    required this.siteId,
    required this.partnerLabel,
  });
}

class _SuppressedSceneReviewEntry {
  final VideoFleetScopeHealthView scope;
  final MonitoringSceneReviewRecord review;

  const _SuppressedSceneReviewEntry({
    required this.scope,
    required this.review,
  });
}

class _SuccessDialogQuickAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color foregroundColor;
  final Color borderColor;

  const _SuccessDialogQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.foregroundColor,
    required this.borderColor,
  });
}

enum _SuccessDialogOutcome { dismissed, continued, quickAction }

class _ClientOnboardingDraft {
  final String clientId;
  final String legalName;
  final String clientType;
  final String billingAddress;
  final String vatNumber;
  final String sovereignContact;
  final String contactName;
  final String contactEmail;
  final String contactPhone;
  final DateTime? contractStart;
  final String slaTier;
  final String messagingProvider;
  final String messagingEndpointLabel;
  final String telegramChatId;
  final String telegramThreadId;
  final String incidentRoutingPolicy;
  final bool contactConsentConfirmed;

  const _ClientOnboardingDraft({
    required this.clientId,
    required this.legalName,
    required this.clientType,
    required this.billingAddress,
    required this.vatNumber,
    required this.sovereignContact,
    required this.contactName,
    required this.contactEmail,
    required this.contactPhone,
    required this.contractStart,
    required this.slaTier,
    required this.messagingProvider,
    required this.messagingEndpointLabel,
    required this.telegramChatId,
    required this.telegramThreadId,
    required this.incidentRoutingPolicy,
    required this.contactConsentConfirmed,
  });
}

class _ClientMessagingBridgeDraft {
  final String clientId;
  final String? siteId;
  final bool applyToAllClientSites;
  final String contactName;
  final String contactRole;
  final String contactEmail;
  final String contactPhone;
  final String provider;
  final String endpointLabel;
  final String telegramChatId;
  final String telegramThreadId;
  final String incidentRoutingPolicy;
  final bool contactConsentConfirmed;

  const _ClientMessagingBridgeDraft({
    required this.clientId,
    required this.siteId,
    required this.applyToAllClientSites,
    required this.contactName,
    required this.contactRole,
    required this.contactEmail,
    required this.contactPhone,
    required this.provider,
    required this.endpointLabel,
    required this.telegramChatId,
    required this.telegramThreadId,
    required this.incidentRoutingPolicy,
    required this.contactConsentConfirmed,
  });
}

class _SiteOnboardingDraft {
  final String siteId;
  final String clientId;
  final String siteName;
  final String siteCode;
  final String address;
  final double? latitude;
  final double? longitude;
  final int geofenceRadiusMeters;
  final String entryProtocol;
  final String siteLayoutMapUrl;
  final String riskProfile;
  final int guardNudgeFrequencyMinutes;
  final int escalationTriggerMinutes;
  final bool enableTelegramBridge;
  final String messagingEndpointLabel;
  final String telegramChatId;
  final String telegramThreadId;

  const _SiteOnboardingDraft({
    required this.siteId,
    required this.clientId,
    required this.siteName,
    required this.siteCode,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.geofenceRadiusMeters,
    required this.entryProtocol,
    required this.siteLayoutMapUrl,
    required this.riskProfile,
    required this.guardNudgeFrequencyMinutes,
    required this.escalationTriggerMinutes,
    required this.enableTelegramBridge,
    required this.messagingEndpointLabel,
    required this.telegramChatId,
    required this.telegramThreadId,
  });
}

class _EmployeeOnboardingDraft {
  final String clientId;
  final String employeeCode;
  final String role;
  final String fullName;
  final String surname;
  final String idNumber;
  final DateTime? dateOfBirth;
  final String psiraNumber;
  final String psiraGrade;
  final DateTime? psiraExpiry;
  final bool hasDriverLicense;
  final String driverLicenseCode;
  final DateTime? driverLicenseExpiry;
  final bool hasPdp;
  final DateTime? pdpExpiry;
  final String deviceUid;
  final String contactPhone;
  final String contactEmail;
  final String assignedSiteId;

  const _EmployeeOnboardingDraft({
    required this.clientId,
    required this.employeeCode,
    required this.role,
    required this.fullName,
    required this.surname,
    required this.idNumber,
    required this.dateOfBirth,
    required this.psiraNumber,
    required this.psiraGrade,
    required this.psiraExpiry,
    required this.hasDriverLicense,
    required this.driverLicenseCode,
    required this.driverLicenseExpiry,
    required this.hasPdp,
    required this.pdpExpiry,
    required this.deviceUid,
    required this.contactPhone,
    required this.contactEmail,
    required this.assignedSiteId,
  });
}

class TelegramAiPendingDraftView {
  final int updateId;
  final String audience;
  final String clientId;
  final String siteId;
  final String chatId;
  final int? messageThreadId;
  final String sourceText;
  final String draftText;
  final String providerLabel;
  final DateTime createdAtUtc;

  const TelegramAiPendingDraftView({
    required this.updateId,
    required this.audience,
    required this.clientId,
    required this.siteId,
    required this.chatId,
    this.messageThreadId,
    required this.sourceText,
    required this.draftText,
    required this.providerLabel,
    required this.createdAtUtc,
  });
}

class AdministrationPage extends StatefulWidget {
  final List<DispatchEvent> events;
  final List<SovereignReport> morningSovereignReportHistory;
  final bool supabaseReady;
  final ValueChanged<String>? onOpenOperationsForIncident;
  final ValueChanged<String>? onOpenTacticalForIncident;
  final ValueChanged<String>? onOpenEventsForIncident;
  final void Function(List<String> eventIds, String? selectedEventId)?
  onOpenEventsForScope;
  final ValueChanged<String>? onOpenLedgerForIncident;
  final ValueChanged<String>? onOpenDispatchesForIncident;
  final ValueChanged<String>? onRunDemoAutopilotForIncident;
  final ValueChanged<String>? onRunFullDemoAutopilotForIncident;
  final VoidCallback? onOpenGovernance;
  final void Function(String clientId, String siteId, String partnerLabel)?
  onOpenGovernanceForPartnerScope;
  final VoidCallback? onOpenDispatches;
  final VoidCallback? onOpenClientView;
  final VoidCallback? onOpenReports;
  final String initialRadioIntentPhrasesJson;
  final String initialDemoRouteCuesJson;
  final Future<void> Function(String rawJson)? onSaveRadioIntentPhrasesJson;
  final Future<void> Function()? onResetRadioIntentPhrasesJson;
  final Future<void> Function(String rawJson)? onSaveDemoRouteCuesJson;
  final Future<void> Function()? onResetDemoRouteCuesJson;
  final Future<void> Function()? onRetryRadioQueue;
  final Future<void> Function()? onRunOpsIntegrationPoll;
  final Future<void> Function()? onRunRadioPoll;
  final Future<void> Function()? onRunCctvPoll;
  final Future<void> Function()? onRunWearablePoll;
  final Future<void> Function()? onRunNewsPoll;
  final Future<void> Function()? onClearRadioQueue;
  final Future<void> Function()? onClearRadioQueueFailureSnapshot;
  final bool radioQueueHasPending;
  final String? radioOpsPollHealth;
  final String? radioOpsQueueHealth;
  final String? radioOpsQueueIntentMix;
  final String? radioOpsAckRecentSummary;
  final String? radioOpsQueueStateDetail;
  final String? radioOpsFailureDetail;
  final String? radioOpsFailureAuditDetail;
  final String? radioOpsManualActionDetail;
  final String videoOpsLabel;
  final String? cctvOpsPollHealth;
  final String? cctvCapabilitySummary;
  final String? cctvRecentSignalSummary;
  final String? cctvEvidenceHealthSummary;
  final String? cctvCameraHealthSummary;
  final List<VideoFleetScopeHealthView> fleetScopeHealth;
  final Map<String, MonitoringSceneReviewRecord> sceneReviewByIntelligenceId;
  final MonitoringIdentityPolicyService monitoringIdentityPolicyService;
  final ValueChanged<MonitoringIdentityPolicyService>?
  onMonitoringIdentityPolicyServiceChanged;
  final String initialMonitoringIdentityRulesJson;
  final Future<void> Function(MonitoringIdentityPolicyService service)?
  onSaveMonitoringIdentityPolicyService;
  final Future<void> Function()? onResetMonitoringIdentityPolicyService;
  final Future<void> Function(SiteIdentityProfile profile)?
  onRegisterTemporaryIdentityApprovalProfile;
  final Future<String> Function(VideoFleetScopeHealthView scope)?
  onExtendTemporaryIdentityApproval;
  final Future<String> Function(VideoFleetScopeHealthView scope)?
  onExpireTemporaryIdentityApproval;
  final List<MonitoringIdentityPolicyAuditRecord>
  initialMonitoringIdentityRuleAuditHistory;
  final ValueChanged<List<MonitoringIdentityPolicyAuditRecord>>?
  onMonitoringIdentityRuleAuditHistoryChanged;
  final MonitoringIdentityPolicyAuditSource?
  initialMonitoringIdentityRuleAuditSourceFilter;
  final ValueChanged<MonitoringIdentityPolicyAuditSource?>?
  onMonitoringIdentityRuleAuditSourceFilterChanged;
  final bool initialMonitoringIdentityRuleAuditExpanded;
  final ValueChanged<bool>? onMonitoringIdentityRuleAuditExpandedChanged;
  final List<TelegramIdentityIntakeRecord> initialTelegramIdentityIntakes;
  final AdministrationPageTab initialTab;
  final ValueChanged<AdministrationPageTab>? onTabChanged;
  final VideoFleetWatchActionDrilldown? initialWatchActionDrilldown;
  final ValueChanged<VideoFleetWatchActionDrilldown?>?
  onWatchActionDrilldownChanged;
  final void Function(
    String clientId,
    String siteId,
    String? incidentReference,
  )?
  onOpenFleetTacticalScope;
  final void Function(
    String clientId,
    String siteId,
    String? incidentReference,
  )?
  onOpenFleetDispatchScope;
  final void Function(String clientId, String siteId)? onRecoverFleetWatchScope;
  final String? monitoringWatchAuditSummary;
  final List<String> monitoringWatchAuditHistory;
  final String? incidentSpoolHealthSummary;
  final String? incidentSpoolReplaySummary;
  final String? videoIntegrityCertificateStatus;
  final String? videoIntegrityCertificateSummary;
  final String? videoIntegrityCertificateJsonPreview;
  final String? videoIntegrityCertificateMarkdownPreview;
  final String? wearableOpsPollHealth;
  final String? listenerAlarmOpsPollHealth;
  final String? newsOpsPollHealth;
  final String telegramBridgeHealthLabel;
  final String? telegramBridgeHealthDetail;
  final bool telegramBridgeFallbackActive;
  final DateTime? telegramBridgeHealthUpdatedAtUtc;
  final Map<String, int> initialClientPartnerEndpointCounts;
  final Map<String, String> initialClientPartnerLanePreview;
  final Map<String, String> initialClientPartnerChatcheckStatus;
  final Map<String, List<String>> initialClientPartnerLaneDetails;
  final Map<String, int> initialSitePartnerEndpointCounts;
  final Map<String, String> initialSitePartnerChatcheckStatus;
  final Map<String, List<String>> initialSitePartnerLaneDetails;
  final bool telegramAiAssistantEnabled;
  final bool telegramAiApprovalRequired;
  final DateTime? telegramAiLastHandledAtUtc;
  final String? telegramAiLastHandledSummary;
  final List<TelegramAiPendingDraftView> telegramAiPendingDrafts;
  final String operatorId;
  final Future<void> Function(String operatorId)? onSetOperatorId;
  final Future<String> Function({
    required String clientId,
    required String siteId,
    required String endpointLabel,
    required String chatId,
    int? threadId,
  })?
  onBindPartnerTelegramEndpoint;
  final Future<String> Function({
    required String clientId,
    required String siteId,
    required String chatId,
    int? threadId,
  })?
  onUnlinkPartnerTelegramEndpoint;
  final Future<String> Function({
    required String clientId,
    required String siteId,
    required String chatId,
    int? threadId,
  })?
  onCheckPartnerTelegramEndpoint;
  final Future<void> Function(bool enabled)? onSetTelegramAiAssistantEnabled;
  final Future<void> Function(bool required)? onSetTelegramAiApprovalRequired;
  final Future<String> Function(int updateId)? onApproveTelegramAiDraft;
  final Future<String> Function(int updateId)? onRejectTelegramAiDraft;
  final Future<String> Function({
    required String clientId,
    String? siteId,
    required String chatId,
    int? threadId,
    required String endpointLabel,
  })?
  onRunSiteTelegramChatcheck;

  const AdministrationPage({
    super.key,
    required this.events,
    this.morningSovereignReportHistory = const <SovereignReport>[],
    required this.supabaseReady,
    this.onOpenOperationsForIncident,
    this.onOpenTacticalForIncident,
    this.onOpenEventsForIncident,
    this.onOpenEventsForScope,
    this.onOpenLedgerForIncident,
    this.onOpenDispatchesForIncident,
    this.onRunDemoAutopilotForIncident,
    this.onRunFullDemoAutopilotForIncident,
    this.onOpenGovernance,
    this.onOpenGovernanceForPartnerScope,
    this.onOpenDispatches,
    this.onOpenClientView,
    this.onOpenReports,
    this.initialRadioIntentPhrasesJson = '',
    this.initialDemoRouteCuesJson = '',
    this.onSaveRadioIntentPhrasesJson,
    this.onResetRadioIntentPhrasesJson,
    this.onSaveDemoRouteCuesJson,
    this.onResetDemoRouteCuesJson,
    this.onRetryRadioQueue,
    this.onRunOpsIntegrationPoll,
    this.onRunRadioPoll,
    this.onRunCctvPoll,
    this.onRunWearablePoll,
    this.onRunNewsPoll,
    this.onClearRadioQueue,
    this.onClearRadioQueueFailureSnapshot,
    this.radioQueueHasPending = false,
    this.radioOpsPollHealth,
    this.radioOpsQueueHealth,
    this.radioOpsQueueIntentMix,
    this.radioOpsAckRecentSummary,
    this.radioOpsQueueStateDetail,
    this.radioOpsFailureDetail,
    this.radioOpsFailureAuditDetail,
    this.radioOpsManualActionDetail,
    this.videoOpsLabel = 'CCTV',
    this.cctvOpsPollHealth,
    this.cctvCapabilitySummary,
    this.cctvRecentSignalSummary,
    this.cctvEvidenceHealthSummary,
    this.cctvCameraHealthSummary,
    this.fleetScopeHealth = const <VideoFleetScopeHealthView>[],
    this.sceneReviewByIntelligenceId =
        const <String, MonitoringSceneReviewRecord>{},
    this.monitoringIdentityPolicyService =
        const MonitoringIdentityPolicyService(),
    this.onMonitoringIdentityPolicyServiceChanged,
    this.initialMonitoringIdentityRulesJson = '',
    this.onSaveMonitoringIdentityPolicyService,
    this.onResetMonitoringIdentityPolicyService,
    this.onRegisterTemporaryIdentityApprovalProfile,
    this.onExtendTemporaryIdentityApproval,
    this.onExpireTemporaryIdentityApproval,
    this.initialMonitoringIdentityRuleAuditHistory =
        const <MonitoringIdentityPolicyAuditRecord>[],
    this.onMonitoringIdentityRuleAuditHistoryChanged,
    this.initialMonitoringIdentityRuleAuditSourceFilter,
    this.onMonitoringIdentityRuleAuditSourceFilterChanged,
    this.initialMonitoringIdentityRuleAuditExpanded = true,
    this.onMonitoringIdentityRuleAuditExpandedChanged,
    this.initialTelegramIdentityIntakes =
        const <TelegramIdentityIntakeRecord>[],
    this.initialTab = AdministrationPageTab.guards,
    this.onTabChanged,
    this.initialWatchActionDrilldown,
    this.onWatchActionDrilldownChanged,
    this.onOpenFleetTacticalScope,
    this.onOpenFleetDispatchScope,
    this.onRecoverFleetWatchScope,
    this.monitoringWatchAuditSummary,
    this.monitoringWatchAuditHistory = const <String>[],
    this.incidentSpoolHealthSummary,
    this.incidentSpoolReplaySummary,
    this.videoIntegrityCertificateStatus,
    this.videoIntegrityCertificateSummary,
    this.videoIntegrityCertificateJsonPreview,
    this.videoIntegrityCertificateMarkdownPreview,
    this.wearableOpsPollHealth,
    this.listenerAlarmOpsPollHealth,
    this.newsOpsPollHealth,
    this.telegramBridgeHealthLabel = 'disabled',
    this.telegramBridgeHealthDetail,
    this.telegramBridgeFallbackActive = false,
    this.telegramBridgeHealthUpdatedAtUtc,
    this.initialClientPartnerEndpointCounts = const <String, int>{},
    this.initialClientPartnerLanePreview = const <String, String>{},
    this.initialClientPartnerChatcheckStatus = const <String, String>{},
    this.initialClientPartnerLaneDetails = const <String, List<String>>{},
    this.initialSitePartnerEndpointCounts = const <String, int>{},
    this.initialSitePartnerChatcheckStatus = const <String, String>{},
    this.initialSitePartnerLaneDetails = const <String, List<String>>{},
    this.telegramAiAssistantEnabled = false,
    this.telegramAiApprovalRequired = false,
    this.telegramAiLastHandledAtUtc,
    this.telegramAiLastHandledSummary,
    this.telegramAiPendingDrafts = const <TelegramAiPendingDraftView>[],
    this.operatorId = 'OPERATOR-01',
    this.onSetOperatorId,
    this.onBindPartnerTelegramEndpoint,
    this.onUnlinkPartnerTelegramEndpoint,
    this.onCheckPartnerTelegramEndpoint,
    this.onSetTelegramAiAssistantEnabled,
    this.onSetTelegramAiApprovalRequired,
    this.onApproveTelegramAiDraft,
    this.onRejectTelegramAiDraft,
    this.onRunSiteTelegramChatcheck,
  });

  @override
  State<AdministrationPage> createState() => _AdministrationPageState();
}

class _AdministrationPageState extends State<AdministrationPage> {
  static const _partnerEndpointLabelPrefix = 'PARTNER';
  static const MonitoringWatchRecoveryStore _watchRecoveryStore =
      MonitoringWatchRecoveryStore(policy: MonitoringWatchRecoveryPolicy());
  static const _globalPostureService = MonitoringGlobalPostureService();
  static const _orchestratorService = MonitoringOrchestratorService();
  static const _syntheticWarRoomService = MonitoringSyntheticWarRoomService();

  final TextEditingController _searchController = TextEditingController();
  late final TextEditingController _radioIntentPhrasesController =
      TextEditingController(text: _resolvedInitialRadioIntentPhrasesJson());
  late final TextEditingController _demoRouteCuesController =
      TextEditingController(text: _resolvedInitialDemoRouteCuesJson());
  late final TextEditingController _operatorIdController;
  late final TextEditingController _partnerEndpointLabelController;
  late final TextEditingController _partnerChatIdController;
  late final TextEditingController _partnerThreadIdController;

  _AdminTab _activeTab = _AdminTab.guards;
  String _query = '';
  bool _directoryLoading = false;
  bool _directorySaving = false;
  bool _demoScriptRunning = false;
  bool _demoCleanupRunning = false;
  bool _directoryLoadedFromSupabase = false;
  bool _demoMode = false;
  String _demoStackProfile = 'industrial';
  String? _demoStoryClientId;
  String? _demoStorySiteId;
  String? _demoStoryEmployeeCode;
  String? _demoStoryVehicleCallsign;
  String? _demoStoryIncidentEventUid;
  DateTime? _demoStoryUpdatedAt;
  String? _directorySyncMessage;
  bool _radioIntentPhrasesSaving = false;
  bool _identityPolicySaving = false;
  String? _radioIntentPhraseValidation;
  bool _radioIntentPhraseValidationError = false;
  bool _demoRouteCuesSaving = false;
  String? _demoRouteCueValidation;
  bool _demoRouteCueValidationError = false;
  bool _operatorIdSaving = false;
  bool _partnerRuntimeBusy = false;
  String? _partnerRuntimeClientId;
  String? _partnerRuntimeSiteId;
  String? _partnerRuntimeStatus;
  bool _telegramAiSettingsBusy = false;
  Set<int> _telegramAiDraftActionBusyIds = const <int>{};
  VideoFleetWatchActionDrilldown? _activeWatchActionDrilldown;

  List<_GuardAdminRow> _guards = const [
    _GuardAdminRow(
      id: 'GRD-001',
      name: 'Thabo Mokoena',
      role: 'guard',
      employeeId: 'EMP-441',
      phone: '+27 82 555 0441',
      email: 'thabo.m@onyx-security.co.za',
      psiraNumber: 'PSI-441-2024',
      psiraExpiry: '2026-10-31',
      certifications: ['PSIRA', 'Armed Response', 'First Aid'],
      assignedSite: 'WTF-MAIN',
      shiftPattern: 'Night (18:00-06:00)',
      emergencyContact: '+27 82 555 0442',
      status: _AdminStatus.active,
    ),
    _GuardAdminRow(
      id: 'GRD-002',
      name: 'Sipho Ndlovu',
      role: 'reaction_officer',
      employeeId: 'EMP-442',
      phone: '+27 83 444 0442',
      email: 'sipho.n@onyx-security.co.za',
      psiraNumber: 'PSI-442-2024',
      psiraExpiry: '2026-08-15',
      certifications: ['PSIRA', 'Armed Response', 'Fire Safety'],
      assignedSite: 'BLR-MAIN',
      shiftPattern: 'Night (18:00-06:00)',
      emergencyContact: '+27 83 444 0443',
      status: _AdminStatus.active,
    ),
    _GuardAdminRow(
      id: 'GRD-003',
      name: 'Nomsa Khumalo',
      role: 'supervisor',
      employeeId: 'EMP-443',
      phone: '+27 84 333 0443',
      email: 'nomsa.k@onyx-security.co.za',
      psiraNumber: 'PSI-443-2024',
      psiraExpiry: '2027-01-20',
      certifications: ['PSIRA', 'First Aid', 'CPR'],
      assignedSite: 'SDN-NORTH',
      shiftPattern: 'Day (06:00-18:00)',
      emergencyContact: '+27 84 333 0444',
      status: _AdminStatus.active,
    ),
  ];

  List<_SiteAdminRow> _sites = const [
    _SiteAdminRow(
      id: 'WTF-MAIN',
      name: 'Waterfall Estate Main',
      code: 'WTF-MAIN',
      clientId: 'CLT-001',
      address: '123 Waterfall Drive, Midrand, 1686',
      lat: -26.0285,
      lng: 28.1122,
      contactPerson: 'John Smith',
      contactPhone: '+27 11 555 0001',
      fskNumber: 'FSK-WTF-001',
      geofenceRadiusMeters: 500,
      status: _AdminStatus.active,
    ),
    _SiteAdminRow(
      id: 'BLR-MAIN',
      name: 'Blue Ridge Security',
      code: 'BLR-MAIN',
      clientId: 'CLT-002',
      address: '45 Ridge Road, Johannesburg, 2001',
      lat: -26.1234,
      lng: 28.0567,
      contactPerson: 'Sarah Johnson',
      contactPhone: '+27 11 555 0002',
      fskNumber: 'FSK-BLR-001',
      geofenceRadiusMeters: 300,
      status: _AdminStatus.active,
    ),
    _SiteAdminRow(
      id: 'SITE-MS-VALLEE-RESIDENCE',
      name: 'MS Vallee Residence',
      code: 'SITE-MS-VALLEE-RESIDENCE',
      clientId: 'CLIENT-MS-VALLEE',
      address: '11 Eastwood Street, Reuven, Johannesburg, 2091',
      lat: -26.2041,
      lng: 28.0473,
      contactPerson: 'Muhammed Vallee',
      contactPhone: '0824787276',
      fskNumber: 'DVR-HIK-MS-VALLEE',
      geofenceRadiusMeters: 150,
      status: _AdminStatus.active,
    ),
    _SiteAdminRow(
      id: 'SDN-NORTH',
      name: 'Sandton Estate North',
      code: 'SDN-NORTH',
      clientId: 'CLT-001',
      address: '78 North Avenue, Sandton, 2196',
      lat: -26.0789,
      lng: 28.0456,
      contactPerson: 'Michael Brown',
      contactPhone: '+27 11 555 0003',
      fskNumber: 'FSK-SDN-001',
      geofenceRadiusMeters: 400,
      status: _AdminStatus.active,
    ),
  ];

  List<_ClientAdminRow> _clients = const [
    _ClientAdminRow(
      id: 'CLT-001',
      name: 'Waterfall Estates Group',
      code: 'WTF-GRP',
      contactPerson: 'David Wilson',
      contactEmail: 'david.wilson@waterfall.co.za',
      contactPhone: '+27 11 888 0001',
      slaTier: 'platinum',
      contractStart: '2024-01-01',
      contractEnd: '2026-12-31',
      sites: 2,
      status: _AdminStatus.active,
    ),
    _ClientAdminRow(
      id: 'CLT-002',
      name: 'Blue Ridge Properties',
      code: 'BLR-PROP',
      contactPerson: 'Lisa Anderson',
      contactEmail: 'lisa.a@blueridge.co.za',
      contactPhone: '+27 11 888 0002',
      slaTier: 'gold',
      contractStart: '2024-03-01',
      contractEnd: '2025-02-28',
      sites: 1,
      status: _AdminStatus.active,
    ),
    _ClientAdminRow(
      id: 'CLIENT-MS-VALLEE',
      name: 'MS Vallee Residence',
      code: 'MS-VALLEE',
      contactPerson: 'Muhammed Vallee',
      contactEmail: '-',
      contactPhone: '0824787276',
      slaTier: 'monitor_only',
      contractStart: '2026-03-13',
      contractEnd: '-',
      sites: 1,
      status: _AdminStatus.active,
    ),
    _ClientAdminRow(
      id: 'CLT-003',
      name: 'Centurion Business Park',
      code: 'CNT-BIZ',
      contactPerson: 'Robert Taylor',
      contactEmail: 'robert.t@centurion.co.za',
      contactPhone: '+27 11 888 0003',
      slaTier: 'silver',
      contractStart: '2024-06-01',
      contractEnd: '2025-05-31',
      sites: 1,
      status: _AdminStatus.active,
    ),
  ];
  Map<String, int> _clientMessagingEndpointCounts = const {};
  Map<String, int> _clientTelegramEndpointCounts = const {};
  Map<String, int> _clientMessagingContactCounts = const {};
  Map<String, String> _clientMessagingLanePreview = const {};
  Map<String, String> _clientTelegramChatcheckStatus = const {};
  Map<String, String> _siteTelegramChatcheckStatus = const {};
  Map<String, int> _clientPartnerEndpointCounts = const {};
  Map<String, String> _clientPartnerLanePreview = const {};
  Map<String, String> _clientPartnerChatcheckStatus = const {};
  Map<String, List<String>> _clientPartnerLaneDetails = const {};
  Map<String, int> _sitePartnerEndpointCounts = const {};
  Map<String, String> _sitePartnerChatcheckStatus = const {};
  Map<String, List<String>> _sitePartnerLaneDetails = const {};
  late MonitoringIdentityPolicyService _monitoringIdentityPolicyService;
  List<MonitoringIdentityPolicyAuditRecord> _identityPolicyAuditHistory =
      const <MonitoringIdentityPolicyAuditRecord>[];
  MonitoringIdentityPolicyAuditSource? _activeIdentityPolicyAuditSource;
  bool _identityPolicyAuditExpanded = true;
  List<TelegramIdentityIntakeRecord> _telegramIdentityIntakes =
      const <TelegramIdentityIntakeRecord>[];
  bool _telegramIdentityIntakesLoading = false;
  Set<String> _telegramIdentityIntakeBusyIds = const <String>{};

  _AdminTab _adminTabFromPublic(AdministrationPageTab tab) {
    return switch (tab) {
      AdministrationPageTab.guards => _AdminTab.guards,
      AdministrationPageTab.sites => _AdminTab.sites,
      AdministrationPageTab.clients => _AdminTab.clients,
      AdministrationPageTab.system => _AdminTab.system,
    };
  }

  AdministrationPageTab _adminTabToPublic(_AdminTab tab) {
    return switch (tab) {
      _AdminTab.guards => AdministrationPageTab.guards,
      _AdminTab.sites => AdministrationPageTab.sites,
      _AdminTab.clients => AdministrationPageTab.clients,
      _AdminTab.system => AdministrationPageTab.system,
    };
  }

  @override
  void didUpdateWidget(covariant AdministrationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialRadioIntentPhrasesJson !=
        widget.initialRadioIntentPhrasesJson) {
      _radioIntentPhrasesController.text =
          _resolvedInitialRadioIntentPhrasesJson();
    }
    if (oldWidget.initialDemoRouteCuesJson != widget.initialDemoRouteCuesJson) {
      _demoRouteCuesController.text = _resolvedInitialDemoRouteCuesJson();
    }
    if (oldWidget.operatorId != widget.operatorId) {
      _operatorIdController.text = widget.operatorId;
    }
    if (!oldWidget.supabaseReady && widget.supabaseReady) {
      _loadDirectoryFromSupabase();
      _loadTelegramIdentityIntakesFromSupabase();
    }
    if (oldWidget.initialTab != widget.initialTab &&
        _activeTab != _adminTabFromPublic(widget.initialTab)) {
      _activeTab = _adminTabFromPublic(widget.initialTab);
    }
    if (oldWidget.initialWatchActionDrilldown !=
            widget.initialWatchActionDrilldown &&
        _activeWatchActionDrilldown != widget.initialWatchActionDrilldown) {
      _activeWatchActionDrilldown = widget.initialWatchActionDrilldown;
    }
    if (oldWidget.monitoringIdentityPolicyService !=
        widget.monitoringIdentityPolicyService) {
      _monitoringIdentityPolicyService = widget.monitoringIdentityPolicyService;
    }
    if (oldWidget.initialMonitoringIdentityRuleAuditHistory !=
        widget.initialMonitoringIdentityRuleAuditHistory) {
      _identityPolicyAuditHistory =
          widget.initialMonitoringIdentityRuleAuditHistory;
    }
    if (oldWidget.initialMonitoringIdentityRuleAuditSourceFilter !=
            widget.initialMonitoringIdentityRuleAuditSourceFilter &&
        _activeIdentityPolicyAuditSource !=
            widget.initialMonitoringIdentityRuleAuditSourceFilter) {
      _activeIdentityPolicyAuditSource =
          widget.initialMonitoringIdentityRuleAuditSourceFilter;
    }
    if (oldWidget.initialMonitoringIdentityRuleAuditExpanded !=
            widget.initialMonitoringIdentityRuleAuditExpanded &&
        _identityPolicyAuditExpanded !=
            widget.initialMonitoringIdentityRuleAuditExpanded) {
      _identityPolicyAuditExpanded =
          widget.initialMonitoringIdentityRuleAuditExpanded;
    }
    if (oldWidget.initialTelegramIdentityIntakes !=
        widget.initialTelegramIdentityIntakes) {
      _telegramIdentityIntakes = widget.initialTelegramIdentityIntakes;
    }
    if (oldWidget.initialClientPartnerEndpointCounts !=
        widget.initialClientPartnerEndpointCounts) {
      _clientPartnerEndpointCounts = widget.initialClientPartnerEndpointCounts;
    }
    if (oldWidget.initialClientPartnerLanePreview !=
        widget.initialClientPartnerLanePreview) {
      _clientPartnerLanePreview = widget.initialClientPartnerLanePreview;
    }
    if (oldWidget.initialClientPartnerChatcheckStatus !=
        widget.initialClientPartnerChatcheckStatus) {
      _clientPartnerChatcheckStatus =
          widget.initialClientPartnerChatcheckStatus;
    }
    if (oldWidget.initialClientPartnerLaneDetails !=
        widget.initialClientPartnerLaneDetails) {
      _clientPartnerLaneDetails = widget.initialClientPartnerLaneDetails;
    }
    if (oldWidget.initialSitePartnerEndpointCounts !=
        widget.initialSitePartnerEndpointCounts) {
      _sitePartnerEndpointCounts = widget.initialSitePartnerEndpointCounts;
    }
    if (oldWidget.initialSitePartnerChatcheckStatus !=
        widget.initialSitePartnerChatcheckStatus) {
      _sitePartnerChatcheckStatus = widget.initialSitePartnerChatcheckStatus;
    }
    if (oldWidget.initialSitePartnerLaneDetails !=
        widget.initialSitePartnerLaneDetails) {
      _sitePartnerLaneDetails = widget.initialSitePartnerLaneDetails;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _radioIntentPhrasesController.dispose();
    _demoRouteCuesController.dispose();
    _operatorIdController.dispose();
    _partnerEndpointLabelController.dispose();
    _partnerChatIdController.dispose();
    _partnerThreadIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OnyxPageScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OnyxPageHeader(
                  title: 'System Administration',
                  subtitle:
                      'Manage guards, sites, clients, and system configuration',
                  actions: [
                    OutlinedButton.icon(
                      onPressed: () => _snack('Export started'),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF8FD1FF),
                        side: const BorderSide(color: Color(0xFF35506F)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      label: Text(
                        'Export Data',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _snack('CSV import staged'),
                      icon: const Icon(Icons.upload_rounded, size: 16),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2B5E93),
                        foregroundColor: const Color(0xFFEAF4FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      label: Text(
                        'Import CSV',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _tabBar(),
                const SizedBox(height: 12),
                OnyxSectionCard(
                  title: 'Administration Console',
                  subtitle:
                      'Search, inspect, and maintain operational configuration records.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _toolbar(),
                      if (_demoMode) ...[
                        const SizedBox(height: 10),
                        _demoStoryboardPanel(),
                      ],
                      if ((_directorySyncMessage ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _directorySyncMessage!.trim(),
                          style: GoogleFonts.inter(
                            color: const Color(0xFF8EA4C2),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _activeTabBody(),
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

  @override
  void initState() {
    super.initState();
    _operatorIdController = TextEditingController(text: widget.operatorId);
    _partnerEndpointLabelController = TextEditingController(
      text: 'PARTNER • Response',
    );
    _partnerChatIdController = TextEditingController();
    _partnerThreadIdController = TextEditingController();
    _activeTab = _adminTabFromPublic(widget.initialTab);
    _activeWatchActionDrilldown = widget.initialWatchActionDrilldown;
    _monitoringIdentityPolicyService = widget.monitoringIdentityPolicyService;
    _identityPolicyAuditHistory =
        widget.initialMonitoringIdentityRuleAuditHistory;
    _activeIdentityPolicyAuditSource =
        widget.initialMonitoringIdentityRuleAuditSourceFilter;
    _identityPolicyAuditExpanded =
        widget.initialMonitoringIdentityRuleAuditExpanded;
    _telegramIdentityIntakes = widget.initialTelegramIdentityIntakes;
    _clientPartnerEndpointCounts = widget.initialClientPartnerEndpointCounts;
    _clientPartnerLanePreview = widget.initialClientPartnerLanePreview;
    _clientPartnerChatcheckStatus = widget.initialClientPartnerChatcheckStatus;
    _clientPartnerLaneDetails = widget.initialClientPartnerLaneDetails;
    _sitePartnerEndpointCounts = widget.initialSitePartnerEndpointCounts;
    _sitePartnerChatcheckStatus = widget.initialSitePartnerChatcheckStatus;
    _sitePartnerLaneDetails = widget.initialSitePartnerLaneDetails;
    final partnerScope = _resolvePartnerRuntimeScope(
      clients: _clients,
      sites: _sites,
    );
    _partnerRuntimeClientId = partnerScope.clientId;
    _partnerRuntimeSiteId = partnerScope.siteId;
    if (widget.supabaseReady) {
      _loadDirectoryFromSupabase();
      _loadTelegramIdentityIntakesFromSupabase();
    } else {
      _directorySyncMessage = 'Supabase offline. Using local seed data.';
    }
  }

  void _setActiveWatchActionDrilldown(
    VideoFleetWatchActionDrilldown? value, {
    bool notify = true,
  }) {
    if (_activeWatchActionDrilldown == value) {
      return;
    }
    setState(() {
      _activeWatchActionDrilldown = value;
    });
    if (notify) {
      widget.onWatchActionDrilldownChanged?.call(value);
    }
  }

  void _setActiveTab(_AdminTab value, {bool notify = true}) {
    if (_activeTab == value) {
      return;
    }
    setState(() {
      _activeTab = value;
    });
    if (notify) {
      widget.onTabChanged?.call(_adminTabToPublic(value));
    }
  }

  String _normalizeIdentityRuleValue(String raw) {
    return raw.trim().toUpperCase();
  }

  Set<String> _identityRuleValues(
    MonitoringIdentityScopePolicy policy,
    _IdentityRuleBucket bucket,
  ) {
    return switch (bucket) {
      _IdentityRuleBucket.flaggedFaces => policy.flaggedFaceMatchIds,
      _IdentityRuleBucket.flaggedPlates => policy.flaggedPlateNumbers,
      _IdentityRuleBucket.allowedFaces => policy.allowedFaceMatchIds,
      _IdentityRuleBucket.allowedPlates => policy.allowedPlateNumbers,
    };
  }

  MonitoringIdentityScopePolicy _identityRulePolicyWithValues(
    MonitoringIdentityScopePolicy policy,
    _IdentityRuleBucket bucket,
    Set<String> values,
  ) {
    return switch (bucket) {
      _IdentityRuleBucket.flaggedFaces => policy.copyWith(
        flaggedFaceMatchIds: values,
      ),
      _IdentityRuleBucket.flaggedPlates => policy.copyWith(
        flaggedPlateNumbers: values,
      ),
      _IdentityRuleBucket.allowedFaces => policy.copyWith(
        allowedFaceMatchIds: values,
      ),
      _IdentityRuleBucket.allowedPlates => policy.copyWith(
        allowedPlateNumbers: values,
      ),
    };
  }

  String _identityRuleLabel(_IdentityRuleBucket bucket) {
    return switch (bucket) {
      _IdentityRuleBucket.flaggedFaces => 'Flagged faces',
      _IdentityRuleBucket.flaggedPlates => 'Flagged plates',
      _IdentityRuleBucket.allowedFaces => 'Allowed faces',
      _IdentityRuleBucket.allowedPlates => 'Allowed plates',
    };
  }

  String _identityRuleSingularLabel(_IdentityRuleBucket bucket) {
    return switch (bucket) {
      _IdentityRuleBucket.flaggedFaces => 'flagged face',
      _IdentityRuleBucket.flaggedPlates => 'flagged plate',
      _IdentityRuleBucket.allowedFaces => 'allowed face',
      _IdentityRuleBucket.allowedPlates => 'allowed plate',
    };
  }

  Color _identityRuleBucketColor(_IdentityRuleBucket bucket) {
    return switch (bucket) {
      _IdentityRuleBucket.flaggedFaces => const Color(0xFFFF7A7A),
      _IdentityRuleBucket.flaggedPlates => const Color(0xFFFFB36B),
      _IdentityRuleBucket.allowedFaces => const Color(0xFF58D68D),
      _IdentityRuleBucket.allowedPlates => const Color(0xFF4FD1C5),
    };
  }

  void _commitMonitoringIdentityPolicyService(
    MonitoringIdentityPolicyService nextService,
  ) {
    setState(() {
      _monitoringIdentityPolicyService = nextService;
    });
    widget.onMonitoringIdentityPolicyServiceChanged?.call(nextService);
  }

  void _recordIdentityPolicyAudit(
    String message, {
    required MonitoringIdentityPolicyAuditSource source,
  }) {
    final nextHistory = <MonitoringIdentityPolicyAuditRecord>[
      MonitoringIdentityPolicyAuditRecord(
        recordedAtUtc: DateTime.now().toUtc(),
        source: source,
        message: message,
      ),
      ..._identityPolicyAuditHistory,
    ].take(8).toList(growable: false);
    setState(() {
      _identityPolicyAuditHistory = nextHistory;
    });
    widget.onMonitoringIdentityRuleAuditHistoryChanged?.call(nextHistory);
  }

  void _setActiveIdentityPolicyAuditSource(
    MonitoringIdentityPolicyAuditSource? source,
  ) {
    if (_activeIdentityPolicyAuditSource == source) {
      return;
    }
    setState(() {
      _activeIdentityPolicyAuditSource = source;
    });
    widget.onMonitoringIdentityRuleAuditSourceFilterChanged?.call(source);
  }

  void _setIdentityPolicyAuditExpanded(bool value) {
    if (_identityPolicyAuditExpanded == value) {
      return;
    }
    setState(() {
      _identityPolicyAuditExpanded = value;
    });
    widget.onMonitoringIdentityRuleAuditExpandedChanged?.call(value);
  }

  Future<void> _loadTelegramIdentityIntakesFromSupabase() async {
    if (!widget.supabaseReady) {
      return;
    }
    setState(() {
      _telegramIdentityIntakesLoading = true;
    });
    try {
      final repository = SupabaseSiteIdentityRegistryRepository(
        Supabase.instance.client,
      );
      final records = await repository.listPendingTelegramIntakes();
      if (!mounted) {
        return;
      }
      setState(() {
        _telegramIdentityIntakes = records;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _snack('Failed to load Telegram visitor proposals: $error');
    } finally {
      if (mounted) {
        setState(() {
          _telegramIdentityIntakesLoading = false;
        });
      }
    }
  }

  void _setTelegramIdentityIntakeBusy(String intakeId, bool busy) {
    final normalized = intakeId.trim();
    if (normalized.isEmpty) {
      return;
    }
    final next = {..._telegramIdentityIntakeBusyIds};
    if (busy) {
      next.add(normalized);
    } else {
      next.remove(normalized);
    }
    setState(() {
      _telegramIdentityIntakeBusyIds = next;
    });
  }

  String _telegramIntakeDisplayName(TelegramIdentityIntakeRecord intake) {
    if (intake.parsedDisplayName.trim().isNotEmpty) {
      return intake.parsedDisplayName.trim();
    }
    if (intake.parsedFaceMatchId.trim().isNotEmpty) {
      return 'Face ${intake.parsedFaceMatchId.trim()}';
    }
    if (intake.parsedPlateNumber.trim().isNotEmpty) {
      return 'Plate ${intake.parsedPlateNumber.trim()}';
    }
    return 'Unnamed visitor';
  }

  String _telegramIntakeSummary(TelegramIdentityIntakeRecord intake) {
    final details = <String>[
      intake.category.code.toUpperCase(),
      if (intake.parsedFaceMatchId.trim().isNotEmpty)
        'Face ${intake.parsedFaceMatchId.trim()}',
      if (intake.parsedPlateNumber.trim().isNotEmpty)
        'Plate ${intake.parsedPlateNumber.trim()}',
      if (intake.validUntilUtc != null)
        'Until ${intake.validUntilUtc!.toUtc().hour.toString().padLeft(2, '0')}:${intake.validUntilUtc!.toUtc().minute.toString().padLeft(2, '0')} UTC',
    ];
    return details.join(' • ');
  }

  DateTime _telegramIntakeApprovalExpiry(TelegramIdentityIntakeRecord intake) {
    final fromUtc = intake.validFromUtc?.toUtc() ?? intake.createdAtUtc.toUtc();
    final untilUtc = intake.validUntilUtc?.toUtc();
    if (untilUtc != null && untilUtc.isAfter(fromUtc)) {
      return untilUtc;
    }
    return DateTime.now().toUtc().add(const Duration(hours: 12));
  }

  String _telegramIntakeExpiryLabel(DateTime utc) {
    final year = utc.year.toString().padLeft(4, '0');
    final month = utc.month.toString().padLeft(2, '0');
    final day = utc.day.toString().padLeft(2, '0');
    final hour = utc.hour.toString().padLeft(2, '0');
    final minute = utc.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute UTC';
  }

  Future<void> _approveTelegramIdentityIntakeOnce(
    TelegramIdentityIntakeRecord intake,
  ) async {
    if (!widget.supabaseReady) {
      _snack('Supabase required to action Telegram visitor proposals.');
      return;
    }
    _setTelegramIdentityIntakeBusy(intake.intakeId, true);
    try {
      final repository = SupabaseSiteIdentityRegistryRepository(
        Supabase.instance.client,
      );
      final nowUtc = DateTime.now().toUtc();
      final validUntilUtc = _telegramIntakeApprovalExpiry(intake);
      final displayName = _telegramIntakeDisplayName(intake);
      final faceId = intake.parsedFaceMatchId.trim().toUpperCase();
      final plate = intake.parsedPlateNumber.trim().toUpperCase();
      final summary =
          'Admin approved one-time Telegram visitor proposal for '
          '${displayName.isEmpty ? intake.siteId : displayName} until '
          '${_telegramIntakeExpiryLabel(validUntilUtc)}.';

      final profileType = plate.isNotEmpty && faceId.isEmpty
          ? SiteIdentityType.vehicle
          : SiteIdentityType.person;
      final profile = SiteIdentityProfile(
        clientId: intake.clientId,
        siteId: intake.siteId,
        identityType: profileType,
        category: intake.category,
        status: SiteIdentityStatus.allowed,
        displayName: displayName,
        faceMatchId: faceId,
        plateNumber: plate,
        externalReference: intake.intakeId,
        notes: 'Approved once from Telegram visitor proposal.',
        validFromUtc: intake.validFromUtc?.toUtc() ?? nowUtc,
        validUntilUtc: validUntilUtc,
        createdAtUtc: nowUtc,
        updatedAtUtc: nowUtc,
        metadata: <String, Object?>{
          'source': 'telegram_identity_intake',
          'intake_id': intake.intakeId,
          'temporary_approval': true,
        },
      );
      await repository.upsertProfile(profile);
      await repository.insertApprovalDecision(
        SiteIdentityApprovalDecisionRecord(
          clientId: intake.clientId,
          siteId: intake.siteId,
          decision: SiteIdentityDecision.approveOnce,
          source: SiteIdentityDecisionSource.admin,
          decidedBy: 'ONYX Admin',
          decisionSummary: summary,
          decidedAtUtc: nowUtc,
          metadata: <String, Object?>{
            'intake_id': intake.intakeId,
            'raw_text': intake.rawText,
            'valid_until': validUntilUtc.toIso8601String(),
          },
        ),
      );
      await repository.updateTelegramIntakeApprovalState(
        intakeId: intake.intakeId,
        approvalState: 'approved_once',
      );
      if (widget.onRegisterTemporaryIdentityApprovalProfile != null) {
        await widget.onRegisterTemporaryIdentityApprovalProfile!(profile);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _telegramIdentityIntakes = _telegramIdentityIntakes
            .where((record) => record.intakeId != intake.intakeId)
            .toList(growable: false);
      });
      _snack(
        'Telegram visitor proposal approved once until ${_telegramIntakeExpiryLabel(validUntilUtc)}.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _snack('Failed to approve one-time Telegram visitor proposal: $error');
    } finally {
      if (mounted) {
        _setTelegramIdentityIntakeBusy(intake.intakeId, false);
      }
    }
  }

  Future<void> _approveTelegramIdentityIntakeAlways(
    TelegramIdentityIntakeRecord intake,
  ) async {
    if (!widget.supabaseReady) {
      _snack('Supabase required to action Telegram visitor proposals.');
      return;
    }
    _setTelegramIdentityIntakeBusy(intake.intakeId, true);
    try {
      final repository = SupabaseSiteIdentityRegistryRepository(
        Supabase.instance.client,
      );
      final nowUtc = DateTime.now().toUtc();
      final faceId = intake.parsedFaceMatchId.trim().toUpperCase();
      final plate = intake.parsedPlateNumber.trim().toUpperCase();
      final displayName = _telegramIntakeDisplayName(intake);
      final summary =
          'Admin approved Telegram visitor proposal for '
          '${displayName.isEmpty ? intake.siteId : displayName}.';

      if (faceId.isNotEmpty) {
        await repository.upsertProfile(
          SiteIdentityProfile(
            clientId: intake.clientId,
            siteId: intake.siteId,
            identityType: SiteIdentityType.person,
            category: intake.category,
            status: SiteIdentityStatus.allowed,
            displayName: displayName,
            faceMatchId: faceId,
            externalReference: intake.intakeId,
            notes: 'Approved from Telegram visitor proposal.',
            validFromUtc: intake.validFromUtc ?? nowUtc,
            createdAtUtc: nowUtc,
            updatedAtUtc: nowUtc,
            metadata: <String, Object?>{
              'source': 'telegram_identity_intake',
              'intake_id': intake.intakeId,
            },
          ),
        );
      }
      if (plate.isNotEmpty) {
        await repository.upsertProfile(
          SiteIdentityProfile(
            clientId: intake.clientId,
            siteId: intake.siteId,
            identityType: SiteIdentityType.vehicle,
            category: intake.category,
            status: SiteIdentityStatus.allowed,
            displayName: plate,
            plateNumber: plate,
            externalReference: intake.intakeId,
            notes: 'Approved from Telegram visitor proposal.',
            validFromUtc: intake.validFromUtc ?? nowUtc,
            createdAtUtc: nowUtc,
            updatedAtUtc: nowUtc,
            metadata: <String, Object?>{
              'source': 'telegram_identity_intake',
              'intake_id': intake.intakeId,
            },
          ),
        );
      }

      await repository.insertApprovalDecision(
        SiteIdentityApprovalDecisionRecord(
          clientId: intake.clientId,
          siteId: intake.siteId,
          decision: SiteIdentityDecision.approveAlways,
          source: SiteIdentityDecisionSource.admin,
          decidedBy: 'ONYX Admin',
          decisionSummary: summary,
          decidedAtUtc: nowUtc,
          metadata: <String, Object?>{
            'intake_id': intake.intakeId,
            'raw_text': intake.rawText,
          },
        ),
      );
      await repository.updateTelegramIntakeApprovalState(
        intakeId: intake.intakeId,
        approvalState: 'approved',
      );

      if (faceId.isNotEmpty || plate.isNotEmpty) {
        final current = _monitoringIdentityPolicyService.policyFor(
          clientId: intake.clientId,
          siteId: intake.siteId,
        );
        _commitMonitoringIdentityPolicyService(
          _monitoringIdentityPolicyService.updateScopePolicy(
            clientId: intake.clientId,
            siteId: intake.siteId,
            policy: current.copyWith(
              allowedFaceMatchIds: faceId.isEmpty
                  ? current.allowedFaceMatchIds
                  : <String>{...current.allowedFaceMatchIds, faceId},
              allowedPlateNumbers: plate.isEmpty
                  ? current.allowedPlateNumbers
                  : <String>{...current.allowedPlateNumbers, plate},
            ),
          ),
        );
        _recordIdentityPolicyAudit(
          'Approved Telegram visitor proposal for ${intake.siteId} (${_telegramIntakeSummary(intake)}).',
          source: MonitoringIdentityPolicyAuditSource.manualEdit,
        );
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _telegramIdentityIntakes = _telegramIdentityIntakes
            .where((record) => record.intakeId != intake.intakeId)
            .toList(growable: false);
      });
      _snack(
        faceId.isEmpty && plate.isEmpty
            ? 'Proposal approved into the registry. Add a stable face or plate later for automatic matching.'
            : 'Telegram visitor proposal allowlisted.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _snack('Failed to approve Telegram visitor proposal: $error');
    } finally {
      if (mounted) {
        _setTelegramIdentityIntakeBusy(intake.intakeId, false);
      }
    }
  }

  Future<void> _rejectTelegramIdentityIntake(
    TelegramIdentityIntakeRecord intake,
  ) async {
    if (!widget.supabaseReady) {
      _snack('Supabase required to action Telegram visitor proposals.');
      return;
    }
    _setTelegramIdentityIntakeBusy(intake.intakeId, true);
    try {
      final repository = SupabaseSiteIdentityRegistryRepository(
        Supabase.instance.client,
      );
      await repository.insertApprovalDecision(
        SiteIdentityApprovalDecisionRecord(
          clientId: intake.clientId,
          siteId: intake.siteId,
          decision: SiteIdentityDecision.review,
          source: SiteIdentityDecisionSource.admin,
          decidedBy: 'ONYX Admin',
          decisionSummary:
              'Admin rejected Telegram visitor proposal and left it out of the allowlist.',
          decidedAtUtc: DateTime.now().toUtc(),
          metadata: <String, Object?>{
            'intake_id': intake.intakeId,
            'raw_text': intake.rawText,
          },
        ),
      );
      await repository.updateTelegramIntakeApprovalState(
        intakeId: intake.intakeId,
        approvalState: 'rejected',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _telegramIdentityIntakes = _telegramIdentityIntakes
            .where((record) => record.intakeId != intake.intakeId)
            .toList(growable: false);
      });
      _snack('Telegram visitor proposal rejected.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _snack('Failed to reject Telegram visitor proposal: $error');
    } finally {
      if (mounted) {
        _setTelegramIdentityIntakeBusy(intake.intakeId, false);
      }
    }
  }

  Future<void> _copyMonitoringIdentityRulesJson() async {
    final rawJson = _monitoringIdentityPolicyService.toCanonicalJsonString();
    await Clipboard.setData(ClipboardData(text: rawJson));
    _snack('Identity rules JSON copied.');
  }

  Future<void> _importMonitoringIdentityRulesJson() async {
    final controller = TextEditingController(
      text: _monitoringIdentityPolicyService.toCanonicalJsonString(),
    );
    final rawJson = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0C1117),
          title: Text(
            'Import Identity Rules JSON',
            style: GoogleFonts.inter(
              color: const Color(0xFFEAF4FF),
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SizedBox(
            width: 520,
            child: TextField(
              key: const ValueKey('identity-rules-import-text-field'),
              controller: controller,
              minLines: 8,
              maxLines: 14,
              style: GoogleFonts.robotoMono(
                color: const Color(0xFFEAF4FF),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText:
                    '[{"client_id":"CLIENT-MS-VALLEE","site_id":"SITE-MS-VALLEE-RESIDENCE","flagged_face_match_ids":["PERSON-44"]}]',
                hintStyle: GoogleFonts.robotoMono(
                  color: const Color(0xFF6A829F),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                filled: true,
                fillColor: const Color(0xFF0A0F15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0x332B425F)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0x332B425F)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0x6655A4FF)),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Import'),
            ),
          ],
        );
      },
    );
    final trimmed = (rawJson ?? '').trim();
    if (trimmed.isEmpty) {
      return;
    }
    try {
      final importedService = MonitoringIdentityPolicyService.parseJson(
        trimmed,
      );
      _commitMonitoringIdentityPolicyService(importedService);
      _recordIdentityPolicyAudit(
        'Imported full identity rule set with ${importedService.entries.length} site entries.',
        source: MonitoringIdentityPolicyAuditSource.importAll,
      );
      _snack('Identity rules imported into runtime.');
    } catch (error) {
      _snack('Failed to import identity rules: $error');
    }
  }

  String _identityPolicyEntryJson(MonitoringIdentityScopePolicyEntry entry) {
    final service = MonitoringIdentityPolicyService(
      policiesByScope: {'${entry.clientId}|${entry.siteId}': entry.policy},
    );
    return service.toCanonicalJsonString();
  }

  Future<void> _copyMonitoringIdentitySiteRulesJson(
    MonitoringIdentityScopePolicyEntry entry,
  ) async {
    await Clipboard.setData(
      ClipboardData(text: _identityPolicyEntryJson(entry)),
    );
    _snack('Site identity rules JSON copied.');
  }

  Future<void> _importMonitoringIdentitySiteRulesJson(
    MonitoringIdentityScopePolicyEntry entry,
  ) async {
    final controller = TextEditingController(
      text: _identityPolicyEntryJson(entry),
    );
    final rawJson = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0C1117),
          title: Text(
            'Import Site Identity Rules JSON',
            style: GoogleFonts.inter(
              color: const Color(0xFFEAF4FF),
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SizedBox(
            width: 520,
            child: TextField(
              key: ValueKey('identity-rules-site-import-${entry.siteId}'),
              controller: controller,
              minLines: 8,
              maxLines: 14,
              style: GoogleFonts.robotoMono(
                color: const Color(0xFFEAF4FF),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText:
                    '[{"client_id":"${entry.clientId}","site_id":"${entry.siteId}","flagged_face_match_ids":["PERSON-44"]}]',
                hintStyle: GoogleFonts.robotoMono(
                  color: const Color(0xFF6A829F),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                filled: true,
                fillColor: const Color(0xFF0A0F15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0x332B425F)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0x332B425F)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0x6655A4FF)),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Import'),
            ),
          ],
        );
      },
    );
    final trimmed = (rawJson ?? '').trim();
    if (trimmed.isEmpty) {
      return;
    }
    try {
      final importedService = MonitoringIdentityPolicyService.parseJson(
        trimmed,
      );
      final importedEntries = importedService.entries;
      if (importedEntries.length != 1) {
        throw const FormatException(
          'Import exactly one site policy in the JSON payload.',
        );
      }
      final importedEntry = importedEntries.single;
      if (importedEntry.clientId != entry.clientId ||
          importedEntry.siteId != entry.siteId) {
        throw FormatException(
          'Imported policy targets ${importedEntry.clientId}/${importedEntry.siteId}, expected ${entry.clientId}/${entry.siteId}.',
        );
      }
      final merged = _monitoringIdentityPolicyService.updateScopePolicy(
        clientId: entry.clientId,
        siteId: entry.siteId,
        policy: importedEntry.policy,
      );
      _commitMonitoringIdentityPolicyService(merged);
      _recordIdentityPolicyAudit(
        'Imported site rules for ${entry.siteId}.',
        source: MonitoringIdentityPolicyAuditSource.importSite,
      );
      _snack('Imported site identity rules for ${entry.siteId}.');
    } catch (error) {
      _snack('Failed to import site identity rules: $error');
    }
  }

  Future<void> _clearMonitoringIdentitySiteRules(
    MonitoringIdentityScopePolicyEntry entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0C1117),
          title: Text(
            'Clear Site Identity Rules?',
            style: GoogleFonts.inter(
              color: const Color(0xFFEAF4FF),
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'This will remove all flagged and allowlisted identity rules for ${entry.siteId}.',
            style: GoogleFonts.inter(
              color: const Color(0xFFBFD7F2),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: const Color(0xFFEAF4FF),
              ),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    final cleared = _monitoringIdentityPolicyService.updateScopePolicy(
      clientId: entry.clientId,
      siteId: entry.siteId,
      policy: const MonitoringIdentityScopePolicy(),
    );
    _commitMonitoringIdentityPolicyService(cleared);
    _recordIdentityPolicyAudit(
      'Cleared all site rules for ${entry.siteId}.',
      source: MonitoringIdentityPolicyAuditSource.clearSite,
    );
    _snack('Cleared site identity rules for ${entry.siteId}.');
  }

  Future<void> _saveMonitoringIdentityRules() async {
    if (widget.onSaveMonitoringIdentityPolicyService == null) {
      _snack('Identity rules runtime save unavailable.');
      return;
    }
    setState(() {
      _identityPolicySaving = true;
    });
    try {
      await widget.onSaveMonitoringIdentityPolicyService!(
        _monitoringIdentityPolicyService,
      );
      if (!mounted) return;
      _recordIdentityPolicyAudit(
        'Saved runtime identity rules (${_monitoringIdentityPolicyService.entries.length} sites).',
        source: MonitoringIdentityPolicyAuditSource.saveRuntime,
      );
      _snack('Identity rules runtime saved.');
    } catch (error) {
      if (!mounted) return;
      _snack('Failed to save identity rules: $error');
    } finally {
      if (mounted) {
        setState(() {
          _identityPolicySaving = false;
        });
      }
    }
  }

  Future<void> _resetMonitoringIdentityRules() async {
    if (widget.onResetMonitoringIdentityPolicyService == null) {
      _snack('Identity rules reset unavailable.');
      return;
    }
    setState(() {
      _identityPolicySaving = true;
    });
    try {
      await widget.onResetMonitoringIdentityPolicyService!();
      if (!mounted) return;
      _recordIdentityPolicyAudit(
        'Reset identity rules to defaults.',
        source: MonitoringIdentityPolicyAuditSource.resetRuntime,
      );
      _snack('Identity rules reset to defaults.');
    } catch (error) {
      if (!mounted) return;
      _snack('Failed to reset identity rules: $error');
    } finally {
      if (mounted) {
        setState(() {
          _identityPolicySaving = false;
        });
      }
    }
  }

  Future<void> _promptAddIdentityRuleValue({
    required String clientId,
    required String siteId,
    required MonitoringIdentityScopePolicy policy,
    required _IdentityRuleBucket bucket,
  }) async {
    final controller = TextEditingController();
    final label = _identityRuleSingularLabel(bucket);
    final rawValue = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0C1117),
          title: Text(
            'Add $label',
            style: GoogleFonts.inter(
              color: const Color(0xFFEAF4FF),
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: GoogleFonts.inter(color: const Color(0xFFEAF4FF)),
            decoration: InputDecoration(
              hintText: 'Enter ${label.replaceAll(' ', ' ID / ')}',
              hintStyle: GoogleFonts.inter(color: const Color(0xFF8EA4C2)),
            ),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    final normalized = _normalizeIdentityRuleValue(rawValue ?? '');
    if (normalized.isEmpty) {
      return;
    }
    final currentValues = _identityRuleValues(policy, bucket);
    if (currentValues.contains(normalized)) {
      _snack('${_identityRuleLabel(bucket)} already contains $normalized');
      return;
    }
    final nextValues = {...currentValues, normalized};
    final nextPolicy = _identityRulePolicyWithValues(
      policy,
      bucket,
      nextValues,
    );
    _commitMonitoringIdentityPolicyService(
      _monitoringIdentityPolicyService.updateScopePolicy(
        clientId: clientId,
        siteId: siteId,
        policy: nextPolicy,
      ),
    );
    _recordIdentityPolicyAudit(
      'Added $normalized to ${_identityRuleLabel(bucket).toLowerCase()} for $siteId.',
      source: MonitoringIdentityPolicyAuditSource.manualEdit,
    );
    _snack('Added $normalized to ${_identityRuleLabel(bucket).toLowerCase()}');
  }

  void _removeIdentityRuleValue({
    required String clientId,
    required String siteId,
    required MonitoringIdentityScopePolicy policy,
    required _IdentityRuleBucket bucket,
    required String value,
  }) {
    final normalized = _normalizeIdentityRuleValue(value);
    final nextValues = {..._identityRuleValues(policy, bucket)}
      ..remove(normalized);
    final nextPolicy = _identityRulePolicyWithValues(
      policy,
      bucket,
      nextValues,
    );
    _commitMonitoringIdentityPolicyService(
      _monitoringIdentityPolicyService.updateScopePolicy(
        clientId: clientId,
        siteId: siteId,
        policy: nextPolicy,
      ),
    );
    _recordIdentityPolicyAudit(
      'Removed $normalized from ${_identityRuleLabel(bucket).toLowerCase()} for $siteId.',
      source: MonitoringIdentityPolicyAuditSource.manualEdit,
    );
    _snack(
      'Removed $normalized from ${_identityRuleLabel(bucket).toLowerCase()}',
    );
  }

  Widget _tabBar() {
    final tabs = [
      (_AdminTab.guards, 'Employees', Icons.shield_rounded, _guards.length),
      (_AdminTab.sites, 'Sites', Icons.apartment_rounded, _sites.length),
      (
        _AdminTab.clients,
        'Clients',
        Icons.business_center_rounded,
        _clients.length,
      ),
      (_AdminTab.system, 'System', Icons.settings_rounded, null),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x33223344))),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: tabs
            .map((tab) {
              final active = _activeTab == tab.$1;
              return InkWell(
                onTap: () => _setActiveTab(tab.$1),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0x1A22D3EE)
                        : const Color(0xFF0E1A2B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: active
                          ? const Color(0x6622D3EE)
                          : const Color(0x332B425F),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tab.$3,
                        size: 16,
                        color: active
                            ? const Color(0xFF22D3EE)
                            : const Color(0xFF9AB1CF),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tab.$2,
                        style: GoogleFonts.inter(
                          color: active
                              ? const Color(0xFFEAF4FF)
                              : const Color(0xB3FFFFFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (tab.$4 != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x22000000),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: const Color(0x332B425F)),
                          ),
                          child: Text(
                            '${tab.$4}',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF8EA4C2),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }

  String _demoStackProfileLabel(String value) {
    switch (value) {
      case 'estate':
        return 'Estate';
      case 'retail':
        return 'Retail';
      case 'industrial':
      default:
        return 'Industrial';
    }
  }

  String _demoStackProfileDetail(String value) {
    switch (value) {
      case 'estate':
        return 'Residential patrol posture';
      case 'retail':
        return 'Hybrid mall posture';
      case 'industrial':
      default:
        return 'High-risk response posture';
    }
  }

  (String, Color, Color, Color) _telegramBridgeTone() {
    final normalized = widget.telegramBridgeHealthLabel.trim().toLowerCase();
    final fallback = widget.telegramBridgeFallbackActive;
    return switch (normalized) {
      'ok' || 'configured' => (
        fallback ? 'Bridge: Fallback (In-App)' : 'Bridge: Ready',
        fallback ? const Color(0xFFF59E0B) : const Color(0xFF34D399),
        fallback ? const Color(0x1AF59E0B) : const Color(0x1A34D399),
        fallback ? const Color(0x66F59E0B) : const Color(0x6634D399),
      ),
      'blocked' => (
        'Bridge: Blocked',
        const Color(0xFFF87171),
        const Color(0x1AF87171),
        const Color(0x66F87171),
      ),
      'no-target' => (
        'Bridge: No Target',
        const Color(0xFFF59E0B),
        const Color(0x1AF59E0B),
        const Color(0x66F59E0B),
      ),
      'degraded' => (
        'Bridge: Degraded',
        const Color(0xFFF59E0B),
        const Color(0x1AF59E0B),
        const Color(0x66F59E0B),
      ),
      'disabled' => (
        'Bridge: Disabled',
        const Color(0xFF94A3B8),
        const Color(0x1A94A3B8),
        const Color(0x6694A3B8),
      ),
      _ => (
        'Bridge: ${widget.telegramBridgeHealthLabel.trim().isEmpty ? 'Unknown' : widget.telegramBridgeHealthLabel.trim()}',
        const Color(0xFF8FD1FF),
        const Color(0x1A8FD1FF),
        const Color(0x668FD1FF),
      ),
    };
  }

  String _telegramBridgeUpdatedAtLabel() {
    final at = widget.telegramBridgeHealthUpdatedAtUtc?.toLocal();
    if (at == null) return 'No recent bridge activity.';
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    return 'Updated $hh:$mm';
  }

  Widget _toolbar() {
    final label = switch (_activeTab) {
      _AdminTab.guards => 'Employee',
      _AdminTab.sites => 'Site',
      _AdminTab.clients => 'Client',
      _AdminTab.system => 'Item',
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final search = TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _query = value.trim()),
          style: GoogleFonts.inter(
            color: const Color(0xFFEAF4FF),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 18,
              color: Color(0xFF8EA4C2),
            ),
            hintText: 'Search ${_activeTab.name}...',
            hintStyle: GoogleFonts.inter(
              color: const Color(0x668EA4C2),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            filled: true,
            fillColor: const Color(0xFF0C1117),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0x332B425F)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0x332B425F)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0x8022D3EE)),
            ),
          ),
        );

        final addButton = FilledButton.icon(
          onPressed: _directorySaving ? null : _openCreateFlow,
          icon: const Icon(Icons.add_rounded, size: 16),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2B5E93),
            foregroundColor: const Color(0xFFEAF4FF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          label: Text(
            'Add $label',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        );
        final addChatLaneButton = OutlinedButton.icon(
          onPressed:
              (_directorySaving ||
                  !widget.supabaseReady ||
                  _activeTab != _AdminTab.clients)
              ? null
              : _openClientMessagingBridgeFlow,
          icon: const Icon(Icons.forum_rounded, size: 16),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF8FD1FF),
            side: const BorderSide(color: Color(0xFF35506F)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          label: Text(
            'Add Chat Lane',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        );

        final demoScriptButton = FilledButton.icon(
          onPressed:
              (_directorySaving || _demoScriptRunning || _demoCleanupRunning)
              ? null
              : _buildDemoStackAndLaunchOperations,
          icon: _demoScriptRunning
              ? const SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.layers_rounded, size: 16),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1D4ED8),
            foregroundColor: const Color(0xFFEAF4FF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          label: Text(
            _demoScriptRunning ? 'Building...' : 'Build Demo Stack',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        );

        final demoProfilePicker = PopupMenuButton<String>(
          onSelected: (value) {
            setState(() => _demoStackProfile = value);
            _snack(
              'Demo stack profile set to ${_demoStackProfileLabel(value)}.',
            );
          },
          color: const Color(0xFF101923),
          itemBuilder: (context) {
            const options = ['industrial', 'estate', 'retail'];
            return options
                .map((value) {
                  final selected = value == _demoStackProfile;
                  return PopupMenuItem<String>(
                    value: value,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          child: selected
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  size: 14,
                                  color: Color(0xFF34D399),
                                )
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _demoStackProfileLabel(value),
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFEAF4FF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _demoStackProfileDetail(value),
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF9AB1CF),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                })
                .toList(growable: false);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1B2A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF35506F)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.tune_rounded,
                  size: 16,
                  color: Color(0xFF8FD1FF),
                ),
                const SizedBox(width: 6),
                Text(
                  'Stack: ${_demoStackProfileLabel(_demoStackProfile)}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEAF4FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.expand_more_rounded,
                  size: 16,
                  color: Color(0xFF8FD1FF),
                ),
              ],
            ),
          ),
        );

        final demoResetButton = OutlinedButton.icon(
          onPressed:
              (_directorySaving || _demoScriptRunning || _demoCleanupRunning)
              ? null
              : _clearDemoData,
          icon: _demoCleanupRunning
              ? const SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_sweep_rounded, size: 16),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFFDA4AF),
            side: const BorderSide(color: Color(0xFF5B242C)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          label: Text(
            _demoCleanupRunning ? 'Clearing...' : 'Reset Demo Data',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        );

        final statusChip = Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF0C1117),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x332B425F)),
          ),
          child: Text(
            _directoryLoading
                ? 'Directory: Syncing…'
                : _directoryLoadedFromSupabase
                ? 'Directory: Supabase'
                : 'Directory: Local',
            style: GoogleFonts.inter(
              color: _directoryLoadedFromSupabase
                  ? const Color(0xFF67E8F9)
                  : const Color(0xFF9AB1CF),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
        final bridgeTone = _telegramBridgeTone();
        final bridgeChip = Tooltip(
          message:
              '${widget.telegramBridgeHealthDetail ?? 'No bridge detail available.'}\n${_telegramBridgeUpdatedAtLabel()}',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: bridgeTone.$3,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: bridgeTone.$4),
            ),
            child: Text(
              bridgeTone.$1,
              style: GoogleFonts.inter(
                color: bridgeTone.$2,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );

        final demoChip = FilterChip(
          selected: _demoMode,
          onSelected: (value) => setState(() => _demoMode = value),
          showCheckmark: false,
          backgroundColor: const Color(0xFF0C1117),
          selectedColor: const Color(0x3322D3EE),
          side: BorderSide(
            color: _demoMode
                ? const Color(0xFF3C79BB)
                : const Color(0x332B425F),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          avatar: Icon(
            Icons.auto_awesome_rounded,
            size: 16,
            color: _demoMode
                ? const Color(0xFF67E8F9)
                : const Color(0xFF8EA4C2),
          ),
          label: Text(
            _demoMode ? 'Demo Mode: ON' : 'Demo Mode',
            style: GoogleFonts.inter(
              color: _demoMode
                  ? const Color(0xFFEAF4FF)
                  : const Color(0xFF9AB1CF),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  statusChip,
                  bridgeChip,
                  demoChip,
                  if (_demoMode) demoProfilePicker,
                  if (_demoMode) demoScriptButton,
                  if (_demoMode) demoResetButton,
                  if (_activeTab == _AdminTab.clients) addChatLaneButton,
                  addButton,
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: search),
            const SizedBox(width: 10),
            statusChip,
            const SizedBox(width: 10),
            bridgeChip,
            const SizedBox(width: 10),
            demoChip,
            const SizedBox(width: 10),
            if (_demoMode) ...[
              demoProfilePicker,
              const SizedBox(width: 10),
              demoScriptButton,
              const SizedBox(width: 10),
              demoResetButton,
              const SizedBox(width: 10),
            ],
            if (_activeTab == _AdminTab.clients) ...[
              addChatLaneButton,
              const SizedBox(width: 10),
            ],
            addButton,
          ],
        );
      },
    );
  }

  Widget _activeTabBody() {
    return switch (_activeTab) {
      _AdminTab.guards => _guardsTable(),
      _AdminTab.sites => _sitesTable(),
      _AdminTab.clients => _clientsTable(),
      _AdminTab.system => _systemTab(),
    };
  }

  Widget _demoStoryboardPanel() {
    final clientReady = (_demoStoryClientId ?? '').isNotEmpty;
    final siteReady = (_demoStorySiteId ?? '').isNotEmpty;
    final employeeReady = (_demoStoryEmployeeCode ?? '').isNotEmpty;
    final vehicleReady = (_demoStoryVehicleCallsign ?? '').isNotEmpty;
    final incidentReady = (_demoStoryIncidentEventUid ?? '').isNotEmpty;
    final stackReady = clientReady && siteReady && employeeReady;
    final opsReady = stackReady && vehicleReady && incidentReady;
    final stackProfileLabel = _demoStackProfileLabel(_demoStackProfile);
    final runbookText =
        'ONYX Client Demo Runbook\n'
        'Date: ${DateTime.now().toLocal()}\n'
        'Profile: $stackProfileLabel\n'
        'Status: ${opsReady ? 'Ops-ready' : (stackReady ? 'Core-ready' : 'Setup in progress')}\n\n'
        'Demo IDs\n'
        '- Client: ${_demoStoryClientId ?? 'Pending'}\n'
        '- Site: ${_demoStorySiteId ?? 'Pending'}\n'
        '- Employee: ${_demoStoryEmployeeCode ?? 'Pending'}\n'
        '- Vehicle: ${_demoStoryVehicleCallsign ?? 'Pending'}\n'
        '- Incident Ref: ${_demoStoryIncidentEventUid ?? 'Pending'}\n\n'
        'Live Route Flow\n'
        '1. Admin: confirm Storyboard readiness and mention compliance fields.\n'
        '2. Trigger Run Demo Autopilot for a fast combat-window walkthrough.\n'
        '3. Trigger Run Full Demo Tour for end-to-end executive replay.\n'
        '4. Events Timeline: replay immutable incident timeline evidence.\n'
        '5. Sovereign Ledger: confirm immutable chain entry focus.\n'
        '6. Governance: show readiness/compliance dashboard and handover discipline.\n'
        '7. Client View: show client-facing context and confidence lane.\n'
        '8. Reports: show sovereign reporting/export readiness.\n\n'
        'Close\n'
        '- Reconfirm focused incident ref and promised response workflow.\n'
        '- Optionally run Reset Demo Data before next client.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1419),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF35506F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: Color(0xFF67E8F9),
              ),
              const SizedBox(width: 8),
              Text(
                'Demo Storyboard',
                style: GoogleFonts.inter(
                  color: const Color(0xFFEAF4FF),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (_demoStoryUpdatedAt != null)
                Text(
                  'Updated ${_demoStamp(_demoStoryUpdatedAt!)}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8EA4C2),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x223C79BB),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0x665FAAFF)),
                ),
                child: Text(
                  'Stack Profile: $stackProfileLabel',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEAF4FF),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                _demoStackProfileDetail(_demoStackProfile),
                style: GoogleFonts.inter(
                  color: const Color(0xFF9AB1CF),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _demoStoryRow(
            step: '1. Client Setup',
            done: clientReady,
            detail: clientReady
                ? 'Created $_demoStoryClientId with sovereign contact and SLA.'
                : 'Talk track: onboard a legal client profile in under one minute.',
          ),
          const SizedBox(height: 6),
          _demoStoryRow(
            step: '2. Site Deployment',
            done: siteReady,
            detail: siteReady
                ? 'Created $_demoStorySiteId with risk profile + geofence defaults.'
                : 'Talk track: define location intelligence, entry protocol, and risk posture.',
          ),
          const SizedBox(height: 6),
          _demoStoryRow(
            step: '3. Response Readiness',
            done: employeeReady,
            detail: employeeReady
                ? 'Created $_demoStoryEmployeeCode and linked assignment.'
                : 'Talk track: add PSIRA/licensing metadata and assign the nearest unit.',
          ),
          const SizedBox(height: 6),
          _demoStoryRow(
            step: '4. Fleet Asset',
            done: vehicleReady,
            detail: vehicleReady
                ? 'Seeded vehicle $_demoStoryVehicleCallsign for reaction dispatch.'
                : 'Talk track: attach a reaction unit vehicle for live deployment.',
          ),
          const SizedBox(height: 6),
          _demoStoryRow(
            step: '5. Incident Timeline',
            done: incidentReady,
            detail: incidentReady
                ? 'Seeded incident $_demoStoryIncidentEventUid for Operations playback.'
                : 'Talk track: create a sample breach event to replay the action ladder.',
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: opsReady
                  ? const Color(0x2234D399)
                  : (stackReady
                        ? const Color(0x223C79BB)
                        : const Color(0x221F3A5A)),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: opsReady
                    ? const Color(0x6634D399)
                    : (stackReady
                          ? const Color(0x665FAAFF)
                          : const Color(0x5535506F)),
              ),
            ),
            child: Text(
              opsReady
                  ? 'Narrative ready: switch to Operations/Tactical and replay the seeded incident chain.'
                  : (stackReady
                        ? 'Core stack ready. Seed fleet + incident data for a full client demo.'
                        : 'Next action: build Demo Stack or complete the next onboarding step.'),
              style: GoogleFonts.inter(
                color: const Color(0xFFEAF4FF),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (!opsReady) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed:
                  (_directorySaving ||
                      _demoScriptRunning ||
                      _demoCleanupRunning)
                  ? null
                  : _buildDemoStackAndLaunchOperations,
              icon: _demoScriptRunning
                  ? const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.layers_rounded, size: 16),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                foregroundColor: const Color(0xFFEAF4FF),
              ),
              label: Text(
                _demoScriptRunning
                    ? 'Building Demo Stack...'
                    : 'Build Demo Stack',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: runbookText));
                if (!mounted) return;
                _snack('Demo runbook copied.');
              },
              icon: const Icon(Icons.summarize_rounded, size: 16),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF8FD1FF),
              ),
              label: Text(
                'Copy Demo Runbook',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (incidentReady) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final incidentRef = _demoStoryIncidentEventUid ?? '';
                    if (incidentRef.trim().isEmpty) return;
                    await Clipboard.setData(ClipboardData(text: incidentRef));
                    if (!mounted) return;
                    _snack('Incident reference copied: $incidentRef');
                  },
                  icon: const Icon(Icons.content_copy_rounded, size: 16),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8FD1FF),
                    side: const BorderSide(color: Color(0xFF35506F)),
                  ),
                  label: Text(
                    'Copy Incident Ref',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
                FilledButton.icon(
                  onPressed: widget.onRunDemoAutopilotForIncident == null
                      ? null
                      : () {
                          final incidentRef = _demoStoryIncidentEventUid ?? '';
                          if (incidentRef.trim().isEmpty) return;
                          widget.onRunDemoAutopilotForIncident!.call(
                            incidentRef,
                          );
                          _snack(
                            'Demo Autopilot started for incident: $incidentRef',
                          );
                        },
                  icon: const Icon(Icons.auto_mode_rounded, size: 16),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: const Color(0xFFEAF4FF),
                  ),
                  label: Text(
                    'Run Demo Autopilot',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: widget.onRunFullDemoAutopilotForIncident == null
                      ? null
                      : () {
                          final incidentRef = _demoStoryIncidentEventUid ?? '';
                          if (incidentRef.trim().isEmpty) return;
                          widget.onRunFullDemoAutopilotForIncident!.call(
                            incidentRef,
                          );
                          _snack(
                            'Full Demo Tour started for incident: $incidentRef',
                          );
                        },
                  icon: const Icon(Icons.route_rounded, size: 16),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF93C5FD),
                    side: const BorderSide(color: Color(0xFF35506F)),
                  ),
                  label: Text(
                    'Run Full Demo Tour',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
                FilledButton.icon(
                  onPressed: widget.onOpenOperationsForIncident == null
                      ? null
                      : () {
                          final incidentRef = _demoStoryIncidentEventUid ?? '';
                          if (incidentRef.trim().isEmpty) return;
                          widget.onOpenOperationsForIncident!.call(incidentRef);
                          _snack('Opening Operations with focus: $incidentRef');
                        },
                  icon: const Icon(Icons.rocket_launch_rounded, size: 16),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2B5E93),
                    foregroundColor: const Color(0xFFEAF4FF),
                  ),
                  label: Text(
                    'Open Operations',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: widget.onOpenTacticalForIncident == null
                      ? null
                      : () {
                          final incidentRef = _demoStoryIncidentEventUid ?? '';
                          if (incidentRef.trim().isEmpty) return;
                          widget.onOpenTacticalForIncident!.call(incidentRef);
                          _snack('Opening Tactical view from: $incidentRef');
                        },
                  icon: const Icon(Icons.map_rounded, size: 16),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF67E8F9),
                    side: const BorderSide(color: Color(0xFF2B5E93)),
                  ),
                  label: Text(
                    'Open Tactical',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: widget.onOpenEventsForIncident == null
                      ? null
                      : () {
                          final incidentRef = _demoStoryIncidentEventUid ?? '';
                          if (incidentRef.trim().isEmpty) return;
                          widget.onOpenEventsForIncident!.call(incidentRef);
                          _snack('Opening Events timeline for: $incidentRef');
                        },
                  icon: const Icon(Icons.timeline_rounded, size: 16),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFBFD7F2),
                    side: const BorderSide(color: Color(0xFF35506F)),
                  ),
                  label: Text(
                    'Open Events Timeline',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: widget.onOpenLedgerForIncident == null
                      ? null
                      : () {
                          final incidentRef = _demoStoryIncidentEventUid ?? '';
                          if (incidentRef.trim().isEmpty) return;
                          widget.onOpenLedgerForIncident!.call(incidentRef);
                          _snack('Opening Ledger for: $incidentRef');
                        },
                  icon: const Icon(Icons.receipt_long_rounded, size: 16),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFDE68A),
                    side: const BorderSide(color: Color(0xFF5B3A16)),
                  ),
                  label: Text(
                    'Open Ledger',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: widget.onOpenGovernance == null
                      ? null
                      : () {
                          widget.onOpenGovernance!.call();
                          _snack('Opening Governance readiness board');
                        },
                  icon: const Icon(Icons.fact_check_rounded, size: 16),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF86EFAC),
                    side: const BorderSide(color: Color(0xFF2F5949)),
                  ),
                  label: Text(
                    'Open Governance',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed:
                      widget.onOpenDispatchesForIncident == null &&
                          widget.onOpenDispatches == null
                      ? null
                      : () {
                          final incidentRef = _demoStoryIncidentEventUid ?? '';
                          if (incidentRef.trim().isNotEmpty &&
                              widget.onOpenDispatchesForIncident != null) {
                            widget.onOpenDispatchesForIncident!.call(
                              incidentRef,
                            );
                            _snack(
                              'Opening Dispatches with focus: $incidentRef',
                            );
                            return;
                          }
                          widget.onOpenDispatches?.call();
                          _snack('Opening Dispatches');
                        },
                  icon: const Icon(Icons.hub_rounded, size: 16),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF93C5FD),
                    side: const BorderSide(color: Color(0xFF35506F)),
                  ),
                  label: Text(
                    'Open Dispatches',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: widget.onOpenClientView == null
                      ? null
                      : () {
                          widget.onOpenClientView!.call();
                          _snack('Opening Client view');
                        },
                  icon: const Icon(Icons.person_outline_rounded, size: 16),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFBFD7F2),
                    side: const BorderSide(color: Color(0xFF35506F)),
                  ),
                  label: Text(
                    'Open Client View',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: widget.onOpenReports == null
                      ? null
                      : () {
                          widget.onOpenReports!.call();
                          _snack('Opening Reports');
                        },
                  icon: const Icon(Icons.assessment_rounded, size: 16),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFFDDAA),
                    side: const BorderSide(color: Color(0xFF5B3A16)),
                  ),
                  label: Text(
                    'Open Reports',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _demoStoryRow({
    required String step,
    required bool done,
    required String detail,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1117),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: done ? const Color(0x6634D399) : const Color(0x332B425F),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 16,
            color: done ? const Color(0xFF34D399) : const Color(0xFF8EA4C2),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEAF4FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9AB1CF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _recordDemoStoryboard({
    String? clientId,
    String? siteId,
    String? employeeCode,
    String? vehicleCallsign,
    String? incidentEventUid,
  }) {
    final hasAny =
        (clientId ?? '').isNotEmpty ||
        (siteId ?? '').isNotEmpty ||
        (employeeCode ?? '').isNotEmpty ||
        (vehicleCallsign ?? '').isNotEmpty ||
        (incidentEventUid ?? '').isNotEmpty;
    if (!hasAny || !mounted) return;
    setState(() {
      if ((clientId ?? '').isNotEmpty) _demoStoryClientId = clientId;
      if ((siteId ?? '').isNotEmpty) _demoStorySiteId = siteId;
      if ((employeeCode ?? '').isNotEmpty) {
        _demoStoryEmployeeCode = employeeCode;
      }
      if ((vehicleCallsign ?? '').isNotEmpty) {
        _demoStoryVehicleCallsign = vehicleCallsign;
      }
      if ((incidentEventUid ?? '').isNotEmpty) {
        _demoStoryIncidentEventUid = incidentEventUid;
      }
      _demoStoryUpdatedAt = DateTime.now();
    });
  }

  String _demoStamp(DateTime value) {
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _siteScopeKey(String clientId, String siteId) {
    return '${clientId.trim()}::${siteId.trim()}';
  }

  void _cacheChatcheckResult({
    required String clientId,
    String? siteId,
    required String result,
  }) {
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId?.trim() ?? '';
    final normalizedResult = result.trim();
    if (normalizedClientId.isEmpty || normalizedResult.isEmpty) {
      return;
    }
    final nextClient = Map<String, String>.from(_clientTelegramChatcheckStatus);
    final nextSite = Map<String, String>.from(_siteTelegramChatcheckStatus);
    nextClient[normalizedClientId] = normalizedResult;
    if (normalizedSiteId.isNotEmpty) {
      nextSite[_siteScopeKey(normalizedClientId, normalizedSiteId)] =
          normalizedResult;
    }
    _clientTelegramChatcheckStatus = nextClient;
    _siteTelegramChatcheckStatus = nextSite;
  }

  void _cachePartnerChatcheckResult({
    required String clientId,
    String? siteId,
    required String result,
  }) {
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId?.trim() ?? '';
    final normalizedResult = result.trim();
    if (normalizedClientId.isEmpty || normalizedResult.isEmpty) {
      return;
    }
    final nextClient = Map<String, String>.from(_clientPartnerChatcheckStatus);
    final nextSite = Map<String, String>.from(_sitePartnerChatcheckStatus);
    nextClient[normalizedClientId] = normalizedResult;
    if (normalizedSiteId.isNotEmpty) {
      nextSite[_siteScopeKey(normalizedClientId, normalizedSiteId)] =
          normalizedResult;
    }
    _clientPartnerChatcheckStatus = nextClient;
    _sitePartnerChatcheckStatus = nextSite;
  }

  void _recordChatcheckResult({
    required String clientId,
    String? siteId,
    required String result,
  }) {
    if (!mounted) {
      _cacheChatcheckResult(clientId: clientId, siteId: siteId, result: result);
      return;
    }
    setState(() {
      _cacheChatcheckResult(clientId: clientId, siteId: siteId, result: result);
    });
  }

  Widget _chatcheckBadge(String status) {
    final normalized = status.trim();
    final uppercase = normalized.toUpperCase();
    late final String label;
    late final Color fg;
    late final Color bg;
    late final Color border;
    if (uppercase.startsWith('PASS')) {
      label = 'CHATCHECK PASS';
      fg = const Color(0xFF86EFAC);
      bg = const Color(0x1A15803D);
      border = const Color(0x664ADE80);
    } else if (uppercase.startsWith('FAIL')) {
      label = 'CHATCHECK FAIL';
      fg = const Color(0xFFFCA5A5);
      bg = const Color(0x1A7F1D1D);
      border = const Color(0x66F87171);
    } else if (uppercase.startsWith('SKIP')) {
      label = 'CHATCHECK SKIP';
      fg = const Color(0xFFFDE68A);
      bg = const Color(0x1A7C4A03);
      border = const Color(0x66F59E0B);
    } else {
      label = 'CHATCHECK';
      fg = const Color(0xFFE2E8F0);
      bg = const Color(0x1A334155);
      border = const Color(0x665A738F);
    }
    return Tooltip(
      message: normalized,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: fg,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  int _chatcheckSeverity(String status) {
    final uppercase = status.trim().toUpperCase();
    if (uppercase.startsWith('FAIL')) return 3;
    if (uppercase.startsWith('SKIP')) return 2;
    if (uppercase.startsWith('PASS')) return 1;
    return 0;
  }

  String _preferredChatcheckStatus(String current, String candidate) {
    final currentNormalized = current.trim();
    final candidateNormalized = candidate.trim();
    if (candidateNormalized.isEmpty) return currentNormalized;
    if (currentNormalized.isEmpty) return candidateNormalized;
    final currentRank = _chatcheckSeverity(currentNormalized);
    final candidateRank = _chatcheckSeverity(candidateNormalized);
    if (candidateRank > currentRank) {
      return candidateNormalized;
    }
    return currentNormalized;
  }

  String _chatcheckStatusFromEndpointRow(Map<String, dynamic> row) {
    final status = (row['last_delivery_status'] ?? '').toString().trim();
    if (status.isEmpty) return '';
    final normalized = status.toLowerCase();
    final error = (row['last_error'] ?? '').toString().trim();
    final detailSuffix = error.isEmpty ? '' : ' • $error';
    return switch (normalized) {
      'chatcheck_pass' => 'PASS (linked + delivered)',
      'chatcheck_blocked' => 'FAIL (delivery blocked$detailSuffix)',
      'chatcheck_fail' => 'FAIL (delivery error$detailSuffix)',
      'chatcheck_unlinked' => 'FAIL (endpoint not linked in scope)',
      'chatcheck_skip' => 'SKIP${error.isEmpty ? '' : ' ($error)'}',
      _ => '',
    };
  }

  bool _isPartnerEndpointLabel(String label) {
    return label.trim().toUpperCase().startsWith(_partnerEndpointLabelPrefix);
  }

  Widget _partnerDispatchBadge(String status) {
    final normalized = status.trim();
    final uppercase = normalized.toUpperCase();
    late final String label;
    late final Color fg;
    late final Color bg;
    late final Color border;
    if (uppercase.startsWith('PASS')) {
      label = 'PARTNER PASS';
      fg = const Color(0xFF86EFAC);
      bg = const Color(0x1A15803D);
      border = const Color(0x664ADE80);
    } else if (uppercase.startsWith('FAIL')) {
      label = 'PARTNER FAIL';
      fg = const Color(0xFFFCA5A5);
      bg = const Color(0x1A7F1D1D);
      border = const Color(0x66F87171);
    } else if (uppercase.startsWith('SKIP')) {
      label = 'PARTNER SKIP';
      fg = const Color(0xFFFDE68A);
      bg = const Color(0x1A7C4A03);
      border = const Color(0x66F59E0B);
    } else {
      label = 'PARTNER';
      fg = const Color(0xFFE2E8F0);
      bg = const Color(0x1A334155);
      border = const Color(0x665A738F);
    }
    return Tooltip(
      message: normalized,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: fg,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  ({String label, String chatId, int? threadId})? _primaryPartnerLaneForScope(
    String clientId, {
    String? siteId,
  }) {
    final details = _partnerLaneDetailsForScope(clientId, siteId: siteId);
    if (details.isEmpty) {
      return null;
    }
    final segments = details.first
        .split(' • ')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (segments.length < 2) {
      return null;
    }
    final label = segments.first;
    var chatId = '';
    int? threadId;
    for (final segment in segments.skip(1)) {
      if (segment.startsWith('chat=')) {
        chatId = segment.substring('chat='.length).trim();
      } else if (segment.startsWith('thread=')) {
        threadId = int.tryParse(segment.substring('thread='.length).trim());
      }
    }
    if (chatId.isEmpty || chatId == 'pending') {
      return null;
    }
    return (label: label, chatId: chatId, threadId: threadId);
  }

  Widget _miniStatBlock(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(0xFF8EA4C2),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            color: const Color(0xFFEAF4FF),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  String _partnerDispatchStatusLabel(PartnerDispatchStatus status) {
    return switch (status) {
      PartnerDispatchStatus.accepted => 'ACCEPT',
      PartnerDispatchStatus.onSite => 'ON SITE',
      PartnerDispatchStatus.allClear => 'ALL CLEAR',
      PartnerDispatchStatus.cancelled => 'CANCEL',
    };
  }

  Widget _partnerProgressBadge({
    required PartnerDispatchStatus status,
    required DateTime? timestamp,
  }) {
    final reached = timestamp != null;
    final tone = _partnerProgressTone(status);
    return Container(
      key: ValueKey<String>('admin-partner-progress-${status.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: reached ? tone.$2 : const Color(0xFF111822),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: reached ? tone.$3 : const Color(0xFF2A374A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _partnerDispatchStatusLabel(status),
            style: GoogleFonts.inter(
              color: reached ? tone.$1 : const Color(0xFF94A3B8),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            reached ? _partnerEventTimeLabel(timestamp) : 'Pending',
            style: GoogleFonts.inter(
              color: reached
                  ? const Color(0xFFEAF4FF)
                  : const Color(0xFF8EA4C2),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _adminPartnerTrendCard(_AdminPartnerTrendRow row) {
    final trendColor = _adminPartnerTrendColor(row.trendLabel);
    final currentScoreColor = _adminPartnerScoreColor(row.currentScoreLabel);
    return SizedBox(
      width: 320,
      child: Container(
        key: ValueKey<String>(
          'admin-partner-trend-${row.clientId}-${row.siteId}-${row.partnerLabel}',
        ),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1722),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF223244)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${row.siteId} • ${row.partnerLabel}',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFEAF4FF),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (row.currentScoreLabel.trim().isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: currentScoreColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: currentScoreColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      row.currentScoreLabel,
                      style: GoogleFonts.inter(
                        color: currentScoreColor,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: trendColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: trendColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    row.trendLabel,
                    style: GoogleFonts.inter(
                      color: trendColor,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Days ${row.reportDays} • Dispatches ${row.dispatchCount} • Strong ${row.strongCount} • On track ${row.onTrackCount} • Watch ${row.watchCount} • Critical ${row.criticalCount}',
              style: GoogleFonts.inter(
                color: const Color(0xFFB9CCE5),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Avg accept ${row.averageAcceptedDelayMinutes.toStringAsFixed(1)}m • Avg on site ${row.averageOnSiteDelayMinutes.toStringAsFixed(1)}m',
              style: GoogleFonts.inter(
                color: const Color(0xFF8EA4C2),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              row.trendReason,
              style: GoogleFonts.inter(
                color: trendColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  (Color, Color, Color) _partnerProgressTone(PartnerDispatchStatus status) {
    return switch (status) {
      PartnerDispatchStatus.accepted => (
        const Color(0xFF38BDF8),
        const Color(0x1A38BDF8),
        const Color(0x6638BDF8),
      ),
      PartnerDispatchStatus.onSite => (
        const Color(0xFFF59E0B),
        const Color(0x1AF59E0B),
        const Color(0x66F59E0B),
      ),
      PartnerDispatchStatus.allClear => (
        const Color(0xFF34D399),
        const Color(0x1A34D399),
        const Color(0x6634D399),
      ),
      PartnerDispatchStatus.cancelled => (
        const Color(0xFFF87171),
        const Color(0x1AF87171),
        const Color(0x66F87171),
      ),
    };
  }

  Color _adminPartnerScoreColor(String scoreLabel) {
    return switch (scoreLabel.trim().toUpperCase()) {
      'STRONG' => const Color(0xFF34D399),
      'ON TRACK' => const Color(0xFF38BDF8),
      'WATCH' => const Color(0xFFF59E0B),
      'CRITICAL' => const Color(0xFFF87171),
      _ => const Color(0xFF9CB4D0),
    };
  }

  Color _adminPartnerTrendColor(String trendLabel) {
    return switch (trendLabel.trim().toUpperCase()) {
      'IMPROVING' => const Color(0xFF34D399),
      'STABLE' => const Color(0xFF38BDF8),
      'SLIPPING' => const Color(0xFFF97316),
      'NEW' => const Color(0xFFFDE68A),
      _ => const Color(0xFF9CB4D0),
    };
  }

  String _partnerEventTimeLabel(DateTime occurredAt) {
    final value = occurredAt.toUtc();
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute UTC';
  }

  List<String> _partnerLaneDetailsForScope(String clientId, {String? siteId}) {
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId?.trim() ?? '';
    if (normalizedSiteId.isNotEmpty) {
      final scoped =
          _sitePartnerLaneDetails[_siteScopeKey(
            normalizedClientId,
            normalizedSiteId,
          )];
      if (scoped != null && scoped.isNotEmpty) {
        return scoped;
      }
    }
    return _clientPartnerLaneDetails[normalizedClientId] ?? const <String>[];
  }

  List<PartnerDispatchStatusDeclared> _recentPartnerActionsForScope(
    String clientId, {
    String? siteId,
  }) {
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId?.trim() ?? '';
    final matching = widget.events
        .whereType<PartnerDispatchStatusDeclared>()
        .where(
          (event) =>
              event.clientId.trim() == normalizedClientId &&
              (normalizedSiteId.isEmpty ||
                  event.siteId.trim() == normalizedSiteId),
        )
        .toList(growable: false);
    matching.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return matching.take(6).toList(growable: false);
  }

  _PartnerActionSummary? _partnerActionSummaryForScope(
    List<PartnerDispatchStatusDeclared> recentActions,
  ) {
    if (recentActions.isEmpty) {
      return null;
    }
    final ordered = [...recentActions]
      ..sort((a, b) {
        final occurredAtCompare = a.occurredAt.compareTo(b.occurredAt);
        if (occurredAtCompare != 0) {
          return occurredAtCompare;
        }
        return a.sequence.compareTo(b.sequence);
      });
    final first = ordered.first;
    final latest = ordered.last;
    final firstOccurrenceByStatus = <PartnerDispatchStatus, DateTime>{};
    for (final event in ordered) {
      firstOccurrenceByStatus.putIfAbsent(event.status, () => event.occurredAt);
    }
    return _PartnerActionSummary(
      dispatchId: first.dispatchId,
      partnerLabel: first.partnerLabel,
      latestStatus: latest.status,
      latestOccurredAt: latest.occurredAt,
      actionCount: ordered.length,
      firstOccurrenceByStatus: firstOccurrenceByStatus,
    );
  }

  List<_AdminPartnerTrendRow> _partnerTrendRowsForScope(
    String clientId, {
    String? siteId,
  }) {
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId?.trim() ?? '';
    if (normalizedClientId.isEmpty ||
        widget.morningSovereignReportHistory.isEmpty) {
      return const <_AdminPartnerTrendRow>[];
    }
    final reports = [...widget.morningSovereignReportHistory]
      ..sort(
        (a, b) => b.generatedAtUtc.toUtc().compareTo(a.generatedAtUtc.toUtc()),
      );
    final latestDate = reports.isEmpty ? '' : reports.first.date.trim();
    final aggregates = <String, _AdminPartnerTrendAggregate>{};
    for (final report in reports) {
      final reportDate = report.date.trim();
      if (reportDate.isEmpty) {
        continue;
      }
      final isCurrent = reportDate == latestDate;
      for (final row in report.partnerProgression.scoreboardRows) {
        if (row.clientId.trim() != normalizedClientId) {
          continue;
        }
        if (normalizedSiteId.isNotEmpty &&
            row.siteId.trim() != normalizedSiteId) {
          continue;
        }
        final key = _adminPartnerTrendKey(
          row.clientId,
          row.siteId,
          row.partnerLabel,
        );
        final aggregate = aggregates.putIfAbsent(
          key,
          () => _AdminPartnerTrendAggregate(
            clientId: row.clientId,
            siteId: row.siteId,
            partnerLabel: row.partnerLabel,
          ),
        );
        aggregate.reportDates.add(reportDate);
        aggregate.dispatchCount += row.dispatchCount;
        aggregate.strongCount += row.strongCount;
        aggregate.onTrackCount += row.onTrackCount;
        aggregate.watchCount += row.watchCount;
        aggregate.criticalCount += row.criticalCount;
        if (row.averageAcceptedDelayMinutes > 0) {
          aggregate.acceptedDelayWeightedSum +=
              row.averageAcceptedDelayMinutes * row.dispatchCount;
          aggregate.acceptedDelayWeight += row.dispatchCount;
        }
        if (row.averageOnSiteDelayMinutes > 0) {
          aggregate.onSiteDelayWeightedSum +=
              row.averageOnSiteDelayMinutes * row.dispatchCount;
          aggregate.onSiteDelayWeight += row.dispatchCount;
        }
        if (isCurrent) {
          aggregate.currentRow = row;
        } else {
          aggregate.priorSeverityScores.add(_adminPartnerSeverityScore(row));
          if (row.averageAcceptedDelayMinutes > 0) {
            aggregate.priorAcceptedDelayMinutes.add(
              row.averageAcceptedDelayMinutes,
            );
          }
          if (row.averageOnSiteDelayMinutes > 0) {
            aggregate.priorOnSiteDelayMinutes.add(
              row.averageOnSiteDelayMinutes,
            );
          }
        }
      }
    }
    final rows = <_AdminPartnerTrendRow>[];
    for (final aggregate in aggregates.values) {
      final currentRow = aggregate.currentRow;
      if (currentRow == null) {
        continue;
      }
      final acceptedAverage = aggregate.acceptedDelayWeight == 0
          ? 0.0
          : aggregate.acceptedDelayWeightedSum / aggregate.acceptedDelayWeight;
      final onSiteAverage = aggregate.onSiteDelayWeight == 0
          ? 0.0
          : aggregate.onSiteDelayWeightedSum / aggregate.onSiteDelayWeight;
      rows.add(
        _AdminPartnerTrendRow(
          clientId: aggregate.clientId,
          siteId: aggregate.siteId,
          partnerLabel: aggregate.partnerLabel,
          reportDays: aggregate.reportDates.length,
          dispatchCount: aggregate.dispatchCount,
          strongCount: aggregate.strongCount,
          onTrackCount: aggregate.onTrackCount,
          watchCount: aggregate.watchCount,
          criticalCount: aggregate.criticalCount,
          averageAcceptedDelayMinutes: double.parse(
            acceptedAverage.toStringAsFixed(1),
          ),
          averageOnSiteDelayMinutes: double.parse(
            onSiteAverage.toStringAsFixed(1),
          ),
          currentScoreLabel: _adminPartnerDominantScoreLabel(currentRow),
          trendLabel: _adminPartnerTrendLabel(
            currentRow,
            aggregate.priorSeverityScores,
          ),
          trendReason: _adminPartnerTrendReason(
            currentRow: currentRow,
            priorSeverityScores: aggregate.priorSeverityScores,
            priorAcceptedDelayMinutes: aggregate.priorAcceptedDelayMinutes,
            priorOnSiteDelayMinutes: aggregate.priorOnSiteDelayMinutes,
          ),
        ),
      );
    }
    rows.sort((a, b) {
      final priorityCompare = _adminPartnerTrendPriority(
        b.trendLabel,
      ).compareTo(_adminPartnerTrendPriority(a.trendLabel));
      if (priorityCompare != 0) {
        return priorityCompare;
      }
      final criticalCompare = b.criticalCount.compareTo(a.criticalCount);
      if (criticalCompare != 0) {
        return criticalCompare;
      }
      return a.partnerLabel.compareTo(b.partnerLabel);
    });
    return rows;
  }

  List<_AdminPartnerTrendRow> _partnerTrendRowsGlobal() {
    if (widget.morningSovereignReportHistory.isEmpty) {
      return const <_AdminPartnerTrendRow>[];
    }
    final scopeKeys = <String>{
      for (final report in widget.morningSovereignReportHistory)
        for (final row in report.partnerProgression.scoreboardRows)
          _adminPartnerTrendKey(row.clientId, row.siteId, row.partnerLabel),
    };
    final rows = <_AdminPartnerTrendRow>[];
    for (final scopeKey in scopeKeys) {
      final split = scopeKey.split('::');
      if (split.length != 3) {
        continue;
      }
      final scopedRows = _partnerTrendRowsForScope(split[0], siteId: split[1]);
      final match = scopedRows.where(
        (row) =>
            row.clientId.trim() == split[0].trim() &&
            row.siteId.trim() == split[1].trim() &&
            row.partnerLabel.trim().toUpperCase() == split[2].trim(),
      );
      rows.addAll(match);
    }
    rows.sort((a, b) {
      final priorityCompare = _adminPartnerTrendPriority(
        b.trendLabel,
      ).compareTo(_adminPartnerTrendPriority(a.trendLabel));
      if (priorityCompare != 0) {
        return priorityCompare;
      }
      final criticalCompare = b.criticalCount.compareTo(a.criticalCount);
      if (criticalCompare != 0) {
        return criticalCompare;
      }
      final dispatchCompare = b.dispatchCount.compareTo(a.dispatchCount);
      if (dispatchCompare != 0) {
        return dispatchCompare;
      }
      return a.partnerLabel.compareTo(b.partnerLabel);
    });
    return rows;
  }

  String _adminPartnerTrendKey(
    String clientId,
    String siteId,
    String partnerLabel,
  ) {
    return '${clientId.trim()}::${siteId.trim()}::${partnerLabel.trim().toUpperCase()}';
  }

  double _adminPartnerSeverityScore(SovereignReportPartnerScoreboardRow row) {
    final dispatchCount = row.dispatchCount <= 0 ? 1 : row.dispatchCount;
    final rawScore = (row.criticalCount * 3) + row.watchCount - row.strongCount;
    return rawScore / dispatchCount;
  }

  String _adminPartnerDominantScoreLabel(
    SovereignReportPartnerScoreboardRow row,
  ) {
    if (row.criticalCount > 0) {
      return 'CRITICAL';
    }
    if (row.watchCount > 0) {
      return 'WATCH';
    }
    if (row.onTrackCount > 0) {
      return 'ON TRACK';
    }
    if (row.strongCount > 0) {
      return 'STRONG';
    }
    return '';
  }

  String _adminPartnerTrendLabel(
    SovereignReportPartnerScoreboardRow currentRow,
    List<double> priorSeverityScores,
  ) {
    if (priorSeverityScores.isEmpty) {
      return 'NEW';
    }
    final priorAverage =
        priorSeverityScores.reduce((left, right) => left + right) /
        priorSeverityScores.length;
    final currentScore = _adminPartnerSeverityScore(currentRow);
    if (currentScore <= priorAverage - 0.35) {
      return 'IMPROVING';
    }
    if (currentScore >= priorAverage + 0.35) {
      return 'SLIPPING';
    }
    return 'STABLE';
  }

  String _adminPartnerTrendReason({
    required SovereignReportPartnerScoreboardRow currentRow,
    required List<double> priorSeverityScores,
    required List<double> priorAcceptedDelayMinutes,
    required List<double> priorOnSiteDelayMinutes,
  }) {
    if (priorSeverityScores.isEmpty) {
      return 'First recorded shift in the 7-day partner window.';
    }
    final trendLabel = _adminPartnerTrendLabel(currentRow, priorSeverityScores);
    final priorAcceptedAverage = priorAcceptedDelayMinutes.isEmpty
        ? null
        : priorAcceptedDelayMinutes.reduce((left, right) => left + right) /
              priorAcceptedDelayMinutes.length;
    final priorOnSiteAverage = priorOnSiteDelayMinutes.isEmpty
        ? null
        : priorOnSiteDelayMinutes.reduce((left, right) => left + right) /
              priorOnSiteDelayMinutes.length;
    switch (trendLabel) {
      case 'IMPROVING':
        if (priorAcceptedAverage != null &&
            currentRow.averageAcceptedDelayMinutes > 0 &&
            currentRow.averageAcceptedDelayMinutes <=
                priorAcceptedAverage - 2.0) {
          return 'Acceptance timing improved against the prior 7-day average.';
        }
        if (priorOnSiteAverage != null &&
            currentRow.averageOnSiteDelayMinutes > 0 &&
            currentRow.averageOnSiteDelayMinutes <= priorOnSiteAverage - 2.0) {
          return 'On-site timing improved against the prior 7-day average.';
        }
        return 'Current shift severity improved against the prior 7-day average.';
      case 'SLIPPING':
        if (priorAcceptedAverage != null &&
            currentRow.averageAcceptedDelayMinutes >=
                priorAcceptedAverage + 2.0) {
          return 'Acceptance timing slipped beyond the prior 7-day average.';
        }
        if (priorOnSiteAverage != null &&
            currentRow.averageOnSiteDelayMinutes >= priorOnSiteAverage + 2.0) {
          return 'On-site timing slipped beyond the prior 7-day average.';
        }
        return 'Current shift severity slipped against the prior 7-day average.';
      case 'STABLE':
      case 'NEW':
        return 'Current shift is holding close to the prior 7-day performance.';
    }
    return '';
  }

  int _adminPartnerTrendPriority(String label) {
    switch (label.trim().toUpperCase()) {
      case 'SLIPPING':
        return 4;
      case 'NEW':
        return 3;
      case 'STABLE':
        return 2;
      case 'IMPROVING':
        return 1;
      default:
        return 0;
    }
  }

  Future<void> _showPartnerDispatchDetailDialog({
    required String clientId,
    String? siteId,
  }) async {
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId?.trim() ?? '';
    final laneDetails = _partnerLaneDetailsForScope(
      normalizedClientId,
      siteId: normalizedSiteId,
    );
    final partnerStatus = normalizedSiteId.isEmpty
        ? (_clientPartnerChatcheckStatus[normalizedClientId] ?? '').trim()
        : (_sitePartnerChatcheckStatus[_siteScopeKey(
                    normalizedClientId,
                    normalizedSiteId,
                  )] ??
                  '')
              .trim();
    final recentActions = _recentPartnerActionsForScope(
      normalizedClientId,
      siteId: normalizedSiteId,
    );
    final trendRows = _partnerTrendRowsForScope(
      normalizedClientId,
      siteId: normalizedSiteId,
    );
    final partnerActionSummary = _partnerActionSummaryForScope(recentActions);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var detailStatus = partnerStatus;
        var checking = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0C1117),
              title: Text(
                normalizedSiteId.isEmpty
                    ? 'Partner Dispatch Detail'
                    : 'Partner Dispatch Detail • ${_siteName(normalizedSiteId)}',
                style: GoogleFonts.inter(
                  color: const Color(0xFFEAF4FF),
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: SizedBox(
                width: _responsiveDialogWidth(context, maxWidth: 720),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scope: ${_clientName(normalizedClientId)}${normalizedSiteId.isEmpty ? '' : ' • ${_siteName(normalizedSiteId)}'}',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF9AB1CF),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (detailStatus.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Current health: $detailStatus',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFEAF4FF),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        'Bound lane details',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFEAF4FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (laneDetails.isEmpty)
                        Text(
                          'No bound partner lane details are cached for this scope yet.',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF8EA4C2),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        ...laneDetails.map(
                          (detail) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              detail,
                              style: GoogleFonts.robotoMono(
                                color: const Color(0xFFB9CCE5),
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      if (trendRows.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          '7-day trend',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFEAF4FF),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final row in trendRows)
                              _adminPartnerTrendCard(row),
                          ],
                        ),
                        if (widget.onOpenGovernanceForPartnerScope != null &&
                            trendRows.length == 1) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () {
                              widget.onOpenGovernanceForPartnerScope!(
                                normalizedClientId,
                                trendRows.first.siteId,
                                trendRows.first.partnerLabel,
                              );
                              Navigator.of(dialogContext).pop();
                              _snack(
                                'Opening Governance for ${trendRows.first.siteId} • ${trendRows.first.partnerLabel}',
                              );
                            },
                            icon: const Icon(
                              Icons.verified_user_rounded,
                              size: 16,
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF8FD1FF),
                              side: const BorderSide(color: Color(0xFF35506F)),
                            ),
                            label: Text(
                              'Open Governance Scope',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                      if (partnerActionSummary != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Dispatch progression',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFEAF4FF),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          key: const ValueKey(
                            'admin-partner-dispatch-progression-card',
                          ),
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F1722),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF223244)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _miniStatBlock(
                                      'Dispatch',
                                      partnerActionSummary.dispatchId,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _miniStatBlock(
                                      'Declarations',
                                      '${partnerActionSummary.actionCount}',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${partnerActionSummary.partnerLabel} • Latest ${_partnerDispatchStatusLabel(partnerActionSummary.latestStatus)} • ${_partnerEventTimeLabel(partnerActionSummary.latestOccurredAt)}',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFEAF4FF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final status
                                      in PartnerDispatchStatus.values)
                                    _partnerProgressBadge(
                                      status: status,
                                      timestamp: partnerActionSummary
                                          .firstOccurrenceByStatus[status],
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        'Recent declared actions',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFEAF4FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (recentActions.isEmpty)
                        Text(
                          'No partner-declared actions recorded for this scope yet.',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF8EA4C2),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        ...recentActions.map(
                          (event) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '${_partnerEventTimeLabel(event.occurredAt)} • ${event.partnerLabel} • ${_partnerDispatchStatusLabel(event.status)} • ${event.actorLabel} • dispatch=${event.dispatchId}',
                              style: GoogleFonts.robotoMono(
                                color: const Color(0xFFB9CCE5),
                                fontSize: 11,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (widget.onCheckPartnerTelegramEndpoint != null)
                  TextButton(
                    onPressed: checking
                        ? null
                        : () async {
                            final lane = _primaryPartnerLaneForScope(
                              normalizedClientId,
                              siteId: normalizedSiteId,
                            );
                            if (lane == null) {
                              _snack(
                                'No partner lane with a usable chat/thread target is available for check.',
                              );
                              return;
                            }
                            setDialogState(() => checking = true);
                            try {
                              final result =
                                  await widget.onCheckPartnerTelegramEndpoint!(
                                    clientId: normalizedClientId,
                                    siteId: normalizedSiteId,
                                    chatId: lane.chatId,
                                    threadId: lane.threadId,
                                  );
                              if (!mounted) return;
                              setState(() {
                                _cachePartnerChatcheckResult(
                                  clientId: normalizedClientId,
                                  siteId: normalizedSiteId,
                                  result: result,
                                );
                              });
                              setDialogState(() {
                                detailStatus = result;
                                checking = false;
                              });
                            } catch (_) {
                              if (!mounted) return;
                              setDialogState(() => checking = false);
                              _snack('Failed to verify partner dispatch lane.');
                            }
                          },
                    child: Text(
                      checking ? 'Checking...' : 'Check lane',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFEAF4FF),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (recentActions.isNotEmpty &&
                    widget.onOpenEventsForScope != null)
                  TextButton(
                    onPressed: () {
                      final eventIds = recentActions
                          .map((event) => event.eventId.trim())
                          .where((id) => id.isNotEmpty)
                          .toList(growable: false);
                      if (eventIds.isEmpty) {
                        return;
                      }
                      Navigator.of(dialogContext).pop();
                      widget.onOpenEventsForScope!.call(
                        eventIds,
                        eventIds.first,
                      );
                    },
                    child: Text(
                      'Open Events Review',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8FD1FF),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (normalizedSiteId.isNotEmpty &&
                    widget.onOpenFleetDispatchScope != null)
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      widget.onOpenFleetDispatchScope!.call(
                        normalizedClientId,
                        normalizedSiteId,
                        null,
                      );
                    },
                    child: Text(
                      'Open Dispatch Scope',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8FD1FF),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else if (widget.onOpenDispatches != null)
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      widget.onOpenDispatches!.call();
                    },
                    child: Text(
                      'Open Dispatches',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8FD1FF),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Close',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFEAF4FF),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _guardsTable() {
    final filtered = _guards
        .where((row) {
          final q = _query.toLowerCase();
          return q.isEmpty ||
              row.name.toLowerCase().contains(q) ||
              row.employeeId.toLowerCase().contains(q);
        })
        .toList(growable: false);

    return Column(
      children: filtered
          .map((row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _dataCard(
                title: '${row.name} (${row.id})',
                lines: [
                  'Employee: ${row.employeeId} • Role: ${row.role}',
                  'PSIRA: ${row.psiraNumber.isEmpty ? '-' : row.psiraNumber}${row.psiraExpiry == null ? '' : ' • Exp ${row.psiraExpiry}'}',
                  'Contact: ${row.phone} • ${row.email}',
                  'Assigned Site: ${_siteName(row.assignedSite)} • ${row.shiftPattern}',
                  'Emergency: ${row.emergencyContact}',
                  'Certifications: ${row.certifications.join(', ')}',
                ],
                status: row.status,
                isDemo:
                    _isDemoIdentifier(row.id) ||
                    _isDemoIdentifier(row.employeeId),
                onEdit: () => _showEditStub('Guard'),
                onDelete: () => _deleteGuard(row.id),
              ),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _sitesTable() {
    final filtered = _sites
        .where((row) {
          final q = _query.toLowerCase();
          return q.isEmpty ||
              row.name.toLowerCase().contains(q) ||
              row.code.toLowerCase().contains(q);
        })
        .toList(growable: false);

    return Column(
      children: filtered
          .map((row) {
            final siteChatcheck =
                _siteTelegramChatcheckStatus[_siteScopeKey(
                      row.clientId,
                      row.id,
                    )]
                    ?.trim() ??
                '';
            final sitePartnerChatcheck =
                _sitePartnerChatcheckStatus[_siteScopeKey(row.clientId, row.id)]
                    ?.trim() ??
                '';
            final sitePartnerLaneCount =
                _sitePartnerEndpointCounts[_siteScopeKey(
                  row.clientId,
                  row.id,
                )] ??
                0;
            final hasPartnerDrillIn =
                sitePartnerLaneCount > 0 ||
                sitePartnerChatcheck.isNotEmpty ||
                _recentPartnerActionsForScope(
                  row.clientId,
                  siteId: row.id,
                ).isNotEmpty;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _dataCard(
                title: '${row.name} (${row.code})',
                lines: [
                  'Client: ${_clientName(row.clientId)}',
                  'Address: ${row.address}',
                  'Coordinates: ${row.lat.toStringAsFixed(4)}, ${row.lng.toStringAsFixed(4)}',
                  'Contact: ${row.contactPerson} • ${row.contactPhone}',
                  'FSK: ${row.fskNumber ?? '-'} • Geofence: ${row.geofenceRadiusMeters}m',
                  if (siteChatcheck.isNotEmpty) 'Chatcheck: $siteChatcheck',
                  if (sitePartnerLaneCount > 0)
                    'Partner lanes: $sitePartnerLaneCount',
                  if (sitePartnerChatcheck.isNotEmpty)
                    'Partner dispatch: $sitePartnerChatcheck',
                ],
                status: row.status,
                isDemo:
                    _isDemoIdentifier(row.id) || _isDemoIdentifier(row.code),
                headerBadges: [
                  if (siteChatcheck.isNotEmpty) _chatcheckBadge(siteChatcheck),
                  if (sitePartnerChatcheck.isNotEmpty)
                    _partnerDispatchBadge(sitePartnerChatcheck),
                ],
                onTap: !hasPartnerDrillIn
                    ? null
                    : () => _showPartnerDispatchDetailDialog(
                        clientId: row.clientId,
                        siteId: row.id,
                      ),
                onEdit: () => _showEditStub('Site'),
                onDelete: () => _deleteSite(row.id),
              ),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _clientsTable() {
    final filtered = _clients
        .where((row) {
          final q = _query.toLowerCase();
          return q.isEmpty ||
              row.name.toLowerCase().contains(q) ||
              row.code.toLowerCase().contains(q);
        })
        .toList(growable: false);

    return Column(
      children: filtered
          .map((row) {
            final laneCount = _clientMessagingEndpointCounts[row.id] ?? 0;
            final telegramCount = _clientTelegramEndpointCounts[row.id] ?? 0;
            final contactCount = _clientMessagingContactCounts[row.id] ?? 0;
            final lanePreview =
                _clientMessagingLanePreview[row.id]?.trim() ?? '';
            final clientChatcheck =
                _clientTelegramChatcheckStatus[row.id]?.trim() ?? '';
            final partnerLaneCount = _clientPartnerEndpointCounts[row.id] ?? 0;
            final partnerLanePreview =
                _clientPartnerLanePreview[row.id]?.trim() ?? '';
            final partnerChatcheck =
                _clientPartnerChatcheckStatus[row.id]?.trim() ?? '';
            final hasPartnerDrillIn =
                partnerLaneCount > 0 ||
                partnerChatcheck.isNotEmpty ||
                _recentPartnerActionsForScope(row.id).isNotEmpty;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _dataCard(
                title: '${row.name} (${row.code})',
                lines: [
                  'Contact: ${row.contactPerson} • ${row.contactPhone}',
                  'Email: ${row.contactEmail}',
                  'SLA Tier: ${row.slaTier.toUpperCase()} • Sites: ${row.sites}',
                  'Contract: ${row.contractStart} to ${row.contractEnd}',
                  'Chat Lanes: $laneCount • Telegram: $telegramCount • Contacts: $contactCount',
                  if (lanePreview.isNotEmpty) 'Lane Labels: $lanePreview',
                  if (clientChatcheck.isNotEmpty) 'Chatcheck: $clientChatcheck',
                  if (partnerLaneCount > 0) 'Partner Lanes: $partnerLaneCount',
                  if (partnerLanePreview.isNotEmpty)
                    'Partner Labels: $partnerLanePreview',
                  if (partnerChatcheck.isNotEmpty)
                    'Partner Dispatch: $partnerChatcheck',
                ],
                status: row.status,
                isDemo:
                    _isDemoIdentifier(row.id) || _isDemoIdentifier(row.code),
                headerBadges: [
                  if (clientChatcheck.isNotEmpty)
                    _chatcheckBadge(clientChatcheck),
                  if (partnerChatcheck.isNotEmpty)
                    _partnerDispatchBadge(partnerChatcheck),
                ],
                onTap: !hasPartnerDrillIn
                    ? null
                    : () => _showPartnerDispatchDetailDialog(clientId: row.id),
                onEdit: () =>
                    _openClientMessagingBridgeFlow(initialClientId: row.id),
                editTooltip: 'Add chat lane',
                editIcon: Icons.forum_rounded,
                onDelete: () => _deleteClient(row.id),
              ),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _systemTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 980;
            final children = [
              Expanded(child: _slaCard()),
              const SizedBox(width: 10, height: 10),
              Expanded(child: _policyCard()),
            ];
            if (compact) {
              return Column(
                children: [
                  _slaCard(),
                  const SizedBox(height: 10),
                  _policyCard(),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            );
          },
        ),
        const SizedBox(height: 10),
        _radioIntentPhraseCard(),
        const SizedBox(height: 10),
        _demoRouteCueCard(),
        const SizedBox(height: 10),
        _partnerScorecardSummaryCard(),
        const SizedBox(height: 10),
        _globalReadinessSummaryCard(),
        const SizedBox(height: 10),
        _listenerAlarmSummaryCard(),
        const SizedBox(height: 10),
        _systemInfoCard(),
      ],
    );
  }

  Widget _partnerScorecardSummaryCard() {
    final rows = _partnerTrendRowsGlobal().take(6).toList(growable: false);
    final slippingCount = rows
        .where((row) => row.trendLabel == 'SLIPPING')
        .length;
    final criticalCount = rows
        .where((row) => row.currentScoreLabel == 'CRITICAL')
        .length;
    final improvingCount = rows
        .where((row) => row.trendLabel == 'IMPROVING')
        .length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subTitle('Partner Scorecard'),
          const SizedBox(height: 8),
          Text(
            '7-day partner performance across active client/site scopes.',
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _partnerScorecardChip(
                label: 'Slipping',
                value: '$slippingCount',
                color: const Color(0xFFF97316),
              ),
              _partnerScorecardChip(
                label: 'Critical',
                value: '$criticalCount',
                color: const Color(0xFFEF4444),
              ),
              _partnerScorecardChip(
                label: 'Improving',
                value: '$improvingCount',
                color: const Color(0xFF34D399),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (widget.onOpenGovernance != null)
                OutlinedButton.icon(
                  onPressed: () {
                    widget.onOpenGovernance!.call();
                    _snack('Opening Governance readiness board');
                  },
                  icon: const Icon(Icons.verified_user_rounded, size: 16),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8FD1FF),
                    side: const BorderSide(color: Color(0xFF35506F)),
                  ),
                  label: Text(
                    'Open Governance',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
              FilledButton.icon(
                onPressed: rows.isEmpty ? null : _copyPartnerScorecardJson,
                icon: const Icon(Icons.copy_all_rounded, size: 16),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: const Color(0xFFEAF4FF),
                ),
                label: Text(
                  'Copy Scorecard JSON',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton.icon(
                onPressed: rows.isEmpty ? null : _copyPartnerScorecardCsv,
                icon: const Icon(Icons.table_rows_rounded, size: 16),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF9AB1CF),
                  side: const BorderSide(color: Color(0xFF35506F)),
                ),
                label: Text(
                  'Copy Scorecard CSV',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            Text(
              'No partner scorecard history is available yet.',
              style: GoogleFonts.inter(
                color: const Color(0xFF8EA4C2),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final row in rows)
                  InkWell(
                    key: ValueKey<String>(
                      'admin-partner-scorecard-${row.clientId}-${row.siteId}-${row.partnerLabel}',
                    ),
                    onTap: () => _showPartnerDispatchDetailDialog(
                      clientId: row.clientId,
                      siteId: row.siteId,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    child: _adminPartnerTrendCard(row),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _listenerAlarmSummaryCard() {
    final cycles = [
      ...widget.events.whereType<ListenerAlarmFeedCycleRecorded>(),
    ]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final advisories = [
      ...widget.events.whereType<ListenerAlarmAdvisoryRecorded>(),
    ]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final latestCycle = cycles.isEmpty ? null : cycles.first;
    final parities = [
      ...widget.events.whereType<ListenerAlarmParityCycleRecorded>(),
    ]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final latestParity = parities.isEmpty ? null : parities.first;
    final clearCount = advisories
        .where((event) => event.dispositionLabel == 'clear')
        .length;
    final suspiciousCount = advisories
        .where((event) => event.dispositionLabel == 'suspicious')
        .length;
    final unavailableCount = advisories
        .where((event) => event.dispositionLabel == 'unavailable')
        .length;
    final latestAdvisory = advisories.isEmpty ? null : advisories.first;
    final latestCycleSummary = latestCycle == null
        ? 'No listener alarm feed cycles have been recorded yet.'
        : 'Latest cycle • mapped ${latestCycle.mappedCount}/${latestCycle.acceptedCount} • '
              'missed ${latestCycle.unmappedCount + latestCycle.rejectedCount + latestCycle.failedCount} • '
              'clear ${latestCycle.clearCount} • suspicious ${latestCycle.suspiciousCount}';
    final latestAdvisorySummary = latestAdvisory == null
        ? 'No listener alarm advisories have been delivered yet.'
        : 'Latest advisory • ${latestAdvisory.siteId} • ${latestAdvisory.eventLabel} • '
              '${latestAdvisory.summary}';
    final latestParitySummary = latestParity == null
        ? 'No listener parity comparison has been recorded yet.'
        : '${latestParity.statusLabel.toUpperCase()} • matched ${latestParity.matchedCount}/${latestParity.legacyCount} • '
              'serial-only ${latestParity.unmatchedSerialCount} • legacy-only ${latestParity.unmatchedLegacyCount} • '
              'max skew ${latestParity.maxSkewSecondsObserved}s';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subTitle('Listener Alarm'),
          const SizedBox(height: 8),
          Text(
            'Parallel alarm intake health, verdict mix, and the latest partner advisory outcome.',
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _partnerScorecardChip(
                label: 'Cycles',
                value: '${cycles.length}',
                color: const Color(0xFF8FD1FF),
              ),
              _partnerScorecardChip(
                label: 'Advisories',
                value: '${advisories.length}',
                color: const Color(0xFF22D3EE),
              ),
              _partnerScorecardChip(
                label: 'Clear',
                value: '$clearCount',
                color: const Color(0xFF34D399),
              ),
              _partnerScorecardChip(
                label: 'Suspicious',
                value: '$suspiciousCount',
                color: const Color(0xFFF59E0B),
              ),
              _partnerScorecardChip(
                label: 'Unavailable',
                value: '$unavailableCount',
                color: const Color(0xFFEF4444),
              ),
              _partnerScorecardChip(
                label: 'Parity',
                value: '${parities.length}',
                color: const Color(0xFFFDE68A),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _listenerAlarmSummaryRow(label: 'Feed', value: latestCycleSummary),
          const SizedBox(height: 8),
          _listenerAlarmSummaryRow(
            label: 'Partner',
            value: latestAdvisorySummary,
          ),
          const SizedBox(height: 8),
          _listenerAlarmSummaryRow(label: 'Parity', value: latestParitySummary),
        ],
      ),
    );
  }

  Widget _globalReadinessSummaryCard() {
    final snapshot = _globalPostureService.buildSnapshot(
      events: widget.events,
      sceneReviewByIntelligenceId: widget.sceneReviewByIntelligenceId,
    );
    final intents = _orchestratorService.buildActionIntents(
      events: widget.events,
      sceneReviewByIntelligenceId: widget.sceneReviewByIntelligenceId,
      videoOpsLabel: widget.videoOpsLabel,
    );
    final warRoomPlans = _syntheticWarRoomService.buildSimulationPlans(
      events: widget.events,
      sceneReviewByIntelligenceId: widget.sceneReviewByIntelligenceId,
      videoOpsLabel: widget.videoOpsLabel,
    );
    final leadRegion = snapshot.regions.isEmpty ? null : snapshot.regions.first;
    final leadSite = snapshot.sites.isEmpty ? null : snapshot.sites.first;
    final summary = snapshot.totalSites <= 0
        ? 'No cross-site posture signals are active yet.'
        : 'Sites ${snapshot.totalSites} • elevated ${snapshot.elevatedSiteCount} • critical ${snapshot.criticalSiteCount} • intents ${intents.length}'
            '${leadRegion == null ? '' : ' • region ${leadRegion.regionId} ${leadRegion.heatLevel.name.toUpperCase()}'}'
            '${leadSite == null ? '' : ' • lead ${leadSite.siteId}'}';
    return Container(
      key: const ValueKey('admin-global-readiness-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subTitle('Global Readiness'),
          const SizedBox(height: 8),
          Text(
            'Cross-site posture and orchestrator interventions across the active video monitoring estate.',
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _partnerScorecardChip(
                label: 'Sites',
                value: '${snapshot.totalSites}',
                color: const Color(0xFF8FD1FF),
              ),
              _partnerScorecardChip(
                label: 'Elevated',
                value: '${snapshot.elevatedSiteCount}',
                color: const Color(0xFFF59E0B),
              ),
              _partnerScorecardChip(
                label: 'Critical',
                value: '${snapshot.criticalSiteCount}',
                color: const Color(0xFFEF4444),
              ),
              _partnerScorecardChip(
                label: 'Intents',
                value: '${intents.length}',
                color: const Color(0xFF22D3EE),
              ),
              _partnerScorecardChip(
                label: 'Sim',
                value: '${warRoomPlans.length}',
                color: warRoomPlans.any(
                      (plan) => plan.actionType == 'POLICY RECOMMENDATION',
                    )
                    ? const Color(0xFF8B5CF6)
                    : const Color(0xFF8FD1FF),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            summary,
            style: GoogleFonts.inter(
              color: const Color(0xFFEAF4FF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (leadSite != null) ...[
            const SizedBox(height: 8),
            Text(
              'Lead posture • ${leadSite.siteId} • ${leadSite.heatLevel.name.toUpperCase()} • ${leadSite.latestSummary}',
              style: GoogleFonts.inter(
                color: const Color(0xFF8EA4C2),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (intents.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Latest intent • ${intents.first.actionType} • ${intents.first.description}',
              style: GoogleFonts.inter(
                color: const Color(0xFFFDE68A),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (warRoomPlans.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Simulation • ${warRoomPlans.first.actionType} • ${warRoomPlans.first.description}',
              style: GoogleFonts.inter(
                color: const Color(0xFFC4B5FD),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _listenerAlarmSummaryRow({
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1117),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0x332B425F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              color: const Color(0xFF9CB2D1),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyPartnerScorecardJson() async {
    final text = _partnerScorecardJson();
    await Clipboard.setData(ClipboardData(text: text));
    _snack('Partner scorecard JSON copied.');
  }

  Future<void> _copyPartnerScorecardCsv() async {
    final text = _partnerScorecardCsv();
    await Clipboard.setData(ClipboardData(text: text));
    _snack('Partner scorecard CSV copied.');
  }

  String _partnerScorecardJson() {
    final rows = _partnerTrendRowsGlobal();
    final latestGeneratedAtUtc = widget.morningSovereignReportHistory.isEmpty
        ? null
        : ([...widget.morningSovereignReportHistory]..sort(
                (a, b) => b.generatedAtUtc.toUtc().compareTo(
                  a.generatedAtUtc.toUtc(),
                ),
              ))
              .first
              .generatedAtUtc
              .toIso8601String();
    final payload = <String, Object?>{
      'generatedAtUtc': latestGeneratedAtUtc,
      'scorecardRows': rows
          .map(
            (row) => <String, Object?>{
              'clientId': row.clientId,
              'siteId': row.siteId,
              'partnerLabel': row.partnerLabel,
              'reportDays': row.reportDays,
              'dispatchCount': row.dispatchCount,
              'strongCount': row.strongCount,
              'onTrackCount': row.onTrackCount,
              'watchCount': row.watchCount,
              'criticalCount': row.criticalCount,
              'averageAcceptedDelayMinutes': row.averageAcceptedDelayMinutes,
              'averageOnSiteDelayMinutes': row.averageOnSiteDelayMinutes,
              'currentScoreLabel': row.currentScoreLabel,
              'trendLabel': row.trendLabel,
              'trendReason': row.trendReason,
            },
          )
          .toList(growable: false),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  String _partnerScorecardCsv() {
    final rows = _partnerTrendRowsGlobal();
    final lines = <String>[
      'client_id,site_id,partner_label,report_days,dispatch_count,strong_count,on_track_count,watch_count,critical_count,avg_accept_minutes,avg_on_site_minutes,current_score,trend_label,trend_reason',
      for (final row in rows)
        '"${row.clientId.replaceAll('"', '""')}","${row.siteId.replaceAll('"', '""')}","${row.partnerLabel.replaceAll('"', '""')}",${row.reportDays},${row.dispatchCount},${row.strongCount},${row.onTrackCount},${row.watchCount},${row.criticalCount},${row.averageAcceptedDelayMinutes.toStringAsFixed(1)},${row.averageOnSiteDelayMinutes.toStringAsFixed(1)},"${row.currentScoreLabel.replaceAll('"', '""')}","${row.trendLabel.replaceAll('"', '""')}","${row.trendReason.replaceAll('"', '""')}"',
    ];
    return lines.join('\n');
  }

  Widget _partnerScorecardChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$label: $value',
        style: GoogleFonts.inter(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _radioIntentPhraseCard() {
    final hasOverride = widget.initialRadioIntentPhrasesJson.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subTitle('Radio Intent Dictionary'),
          const SizedBox(height: 8),
          Text(
            'Tune panic/duress/all-clear/status phrase detection at runtime.',
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _radioIntentPhrasesController,
            maxLines: 10,
            minLines: 8,
            style: GoogleFonts.robotoMono(
              color: const Color(0xFFEAF4FF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText:
                  '{\n  "all_clear": ["all clear"],\n  "panic": ["panic button"],\n  "duress": ["silent duress"],\n  "status": ["status update"]\n}',
              hintStyle: GoogleFonts.robotoMono(
                color: const Color(0xFF6A829F),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              filled: true,
              fillColor: const Color(0xFF0C1117),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0x332B425F)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0x332B425F)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0x6655A4FF)),
              ),
            ),
          ),
          if (_radioIntentPhraseValidation != null) ...[
            const SizedBox(height: 8),
            Text(
              _radioIntentPhraseValidation!,
              style: GoogleFonts.inter(
                color: _radioIntentPhraseValidationError
                    ? const Color(0xFFF87171)
                    : const Color(0xFF67E8F9),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _radioIntentPhrasesSaving
                    ? null
                    : _validateRadioIntentJson,
                icon: const Icon(Icons.rule_rounded, size: 16),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2B5E93),
                  foregroundColor: const Color(0xFFEAF4FF),
                ),
                label: Text(
                  'Validate',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.icon(
                onPressed: _radioIntentPhrasesSaving
                    ? null
                    : _saveRadioIntentJson,
                icon: const Icon(Icons.save_rounded, size: 16),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: const Color(0xFFEAF4FF),
                ),
                label: Text(
                  'Save Runtime',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _radioIntentPhrasesSaving
                    ? null
                    : _resetRadioIntentJson,
                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF9AB1CF),
                  side: const BorderSide(color: Color(0xFF35506F)),
                ),
                label: Text(
                  hasOverride ? 'Reset To Defaults' : 'Defaults Active',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _demoRouteCueCard() {
    final hasOverride = widget.initialDemoRouteCuesJson.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subTitle('Demo Route Cues'),
          const SizedBox(height: 8),
          Text(
            'Customize autoplay presenter narration per route at runtime.',
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _demoRouteCuesController,
            maxLines: 12,
            minLines: 8,
            style: GoogleFonts.robotoMono(
              color: const Color(0xFFEAF4FF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText:
                  '{\n  "dashboard": "Action ladder and decision speed.",\n  "tactical": "Verify units and site posture.",\n  "dispatches": "Execute dispatch from focused queue."\n}',
              hintStyle: GoogleFonts.robotoMono(
                color: const Color(0xFF6A829F),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              filled: true,
              fillColor: const Color(0xFF0C1117),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0x332B425F)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0x332B425F)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0x6655A4FF)),
              ),
            ),
          ),
          if (_demoRouteCueValidation != null) ...[
            const SizedBox(height: 8),
            Text(
              _demoRouteCueValidation!,
              style: GoogleFonts.inter(
                color: _demoRouteCueValidationError
                    ? const Color(0xFFF87171)
                    : const Color(0xFF67E8F9),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _demoRouteCuesSaving
                    ? null
                    : _validateDemoRouteCueJson,
                icon: const Icon(Icons.rule_rounded, size: 16),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2B5E93),
                  foregroundColor: const Color(0xFFEAF4FF),
                ),
                label: Text(
                  'Validate',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.icon(
                onPressed: _demoRouteCuesSaving ? null : _saveDemoRouteCueJson,
                icon: const Icon(Icons.save_rounded, size: 16),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: const Color(0xFFEAF4FF),
                ),
                label: Text(
                  'Save Runtime',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _demoRouteCuesSaving ? null : _resetDemoRouteCueJson,
                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF9AB1CF),
                  side: const BorderSide(color: Color(0xFF35506F)),
                ),
                label: Text(
                  hasOverride ? 'Reset To Defaults' : 'Defaults Active',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _slaCard() {
    final tiers = [
      ('Platinum', '< 5 min', const Color(0xFF22D3EE)),
      ('Gold', '< 10 min', const Color(0xFFF59E0B)),
      ('Silver', '< 15 min', const Color(0xFF94A3B8)),
      ('Bronze', '< 20 min', const Color(0xFFFB923C)),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subTitle('SLA Tiers'),
          const SizedBox(height: 8),
          ...tiers.map((tier) {
            return Container(
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0C1117),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0x332B425F)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: tier.$3,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tier.$1,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFEAF4FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    tier.$2,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF9AB1CF),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _policyCard() {
    final policies = [
      ('Auto-escalate after', '30 seconds'),
      ('Critical incident timeout', '5 minutes'),
      ('Guard heartbeat interval', '60 seconds'),
      ('Geofence breach alert', 'Enabled'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subTitle('Risk Policies'),
          const SizedBox(height: 8),
          ...policies.map((policy) {
            return Container(
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0C1117),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0x332B425F)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      policy.$1,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF9AB1CF),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    policy.$2,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFEAF4FF),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _systemInfoCard() {
    final fleetPanelKey = GlobalKey();
    final suppressedPanelKey = GlobalKey();
    final suppressedEntries = _suppressedSceneReviewEntries();
    final showSuppressedPrimary =
        _activeWatchActionDrilldown ==
            VideoFleetWatchActionDrilldown.filtered &&
        suppressedEntries.isNotEmpty;
    final showEscalatedPrimary =
        _activeWatchActionDrilldown == VideoFleetWatchActionDrilldown.escalated;
    void openWatchActionDrilldown(VideoFleetWatchActionDrilldown drilldown) {
      if (_activeWatchActionDrilldown == drilldown) {
        _setActiveWatchActionDrilldown(null);
        return;
      }
      _setActiveWatchActionDrilldown(drilldown);
      final targetContext =
          drilldown == VideoFleetWatchActionDrilldown.filtered &&
              suppressedEntries.isNotEmpty
          ? suppressedPanelKey.currentContext
          : fleetPanelKey.currentContext;
      if (targetContext == null) {
        return;
      }
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }

    void openLatestWatchActionDetail(VideoFleetScopeHealthView scope) {
      if (_activeWatchActionDrilldown ==
              VideoFleetWatchActionDrilldown.filtered &&
          suppressedEntries.isNotEmpty) {
        final targetContext = suppressedPanelKey.currentContext;
        if (targetContext != null) {
          Scrollable.ensureVisible(
            targetContext,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
        }
        return;
      }
      final primaryOpenFleetScope = scope.hasIncidentContext
          ? (widget.onOpenFleetTacticalScope ?? widget.onOpenFleetDispatchScope)
          : null;
      if (primaryOpenFleetScope == null) {
        return;
      }
      primaryOpenFleetScope.call(
        scope.clientId,
        scope.siteId,
        scope.latestIncidentReference,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subTitle('System Information'),
          if (showEscalatedPrimary && widget.fleetScopeHealth.isNotEmpty) ...[
            const SizedBox(height: 8),
            KeyedSubtree(
              key: fleetPanelKey,
              child: _fleetScopeHealthPanel(
                onOpenWatchActionDrilldown: openWatchActionDrilldown,
                onOpenLatestWatchActionDetail: openLatestWatchActionDetail,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _sysInfoMini('Total Guards', _guards.length.toString()),
              _sysInfoMini('Total Sites', _sites.length.toString()),
              _sysInfoMini('Total Clients', _clients.length.toString()),
            ],
          ),
          const SizedBox(height: 12),
          _telegramBridgeStatusPanel(),
          const SizedBox(height: 12),
          _operatorRuntimePanel(),
          const SizedBox(height: 12),
          _partnerDispatchRuntimePanel(),
          const SizedBox(height: 12),
          _telegramAiAssistantPanel(),
          if (_hasVideoIntegrityCertificatePreview()) ...[
            const SizedBox(height: 12),
            _videoIntegrityCertificatePanel(),
          ],
          if (_opsPollHealthRows().isNotEmpty) ...[
            const SizedBox(height: 12),
            _subTitle('Ops Integration Poll Health'),
            const SizedBox(height: 8),
            ..._opsPollHealthRows(),
            if (widget.monitoringWatchAuditHistory.isNotEmpty) ...[
              const SizedBox(height: 8),
              _monitoringWatchAuditTrailPanel(),
            ],
          ],
          if (showSuppressedPrimary) ...[
            const SizedBox(height: 8),
            KeyedSubtree(
              key: suppressedPanelKey,
              child: _suppressedSceneReviewPanel(suppressedEntries),
            ),
          ],
          if (!showEscalatedPrimary && widget.fleetScopeHealth.isNotEmpty) ...[
            const SizedBox(height: 8),
            KeyedSubtree(
              key: fleetPanelKey,
              child: _fleetScopeHealthPanel(
                onOpenWatchActionDrilldown: openWatchActionDrilldown,
                onOpenLatestWatchActionDetail: openLatestWatchActionDetail,
              ),
            ),
          ],
          if (!showSuppressedPrimary && suppressedEntries.isNotEmpty) ...[
            const SizedBox(height: 8),
            KeyedSubtree(
              key: suppressedPanelKey,
              child: _suppressedSceneReviewPanel(suppressedEntries),
            ),
          ],
          if (_monitoringIdentityPolicyService.entries.isNotEmpty) ...[
            const SizedBox(height: 8),
            _identityPolicyPanel(),
          ],
          if (widget.supabaseReady || _telegramIdentityIntakes.isNotEmpty) ...[
            const SizedBox(height: 8),
            _telegramIdentityIntakePanel(),
          ],
          const SizedBox(height: 8),
          _opsQueueActionButtons(),
        ],
      ),
    );
  }

  bool _hasVideoIntegrityCertificatePreview() {
    return (widget.videoIntegrityCertificateStatus ?? '').trim().isNotEmpty ||
        (widget.videoIntegrityCertificateSummary ?? '').trim().isNotEmpty ||
        (widget.videoIntegrityCertificateJsonPreview ?? '').trim().isNotEmpty ||
        (widget.videoIntegrityCertificateMarkdownPreview ?? '')
            .trim()
            .isNotEmpty;
  }

  Widget _videoIntegrityCertificatePanel() {
    final status = (widget.videoIntegrityCertificateStatus ?? '').trim();
    final summary = (widget.videoIntegrityCertificateSummary ?? '').trim();
    final hasPreview =
        (widget.videoIntegrityCertificateJsonPreview ?? '').trim().isNotEmpty ||
        (widget.videoIntegrityCertificateMarkdownPreview ?? '')
            .trim()
            .isNotEmpty;
    final statusUpper = status.toUpperCase();
    final accent = statusUpper == 'PASS'
        ? const Color(0xFF34D399)
        : statusUpper == 'WARN' || statusUpper == 'HOLD'
        ? const Color(0xFFF59E0B)
        : const Color(0xFF67E8F9);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1117),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0x332B425F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_rounded, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(
                '${widget.videoOpsLabel} Integrity Certificate',
                style: GoogleFonts.inter(
                  color: const Color(0xFFEAF4FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (status.isNotEmpty)
                Text(
                  statusUpper,
                  style: GoogleFonts.inter(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            summary.isEmpty
                ? 'No active ${widget.videoOpsLabel} integrity summary available.'
                : summary,
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (hasPreview) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _showVideoIntegrityCertificatePreview,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEAF4FF),
                side: const BorderSide(color: Color(0xFF35506F)),
              ),
              icon: const Icon(Icons.description_rounded, size: 16),
              label: Text(
                'View Certificate',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showVideoIntegrityCertificatePreview() {
    final jsonPreview =
        (widget.videoIntegrityCertificateJsonPreview ?? '').trim().isEmpty
        ? '{\n  "note": "No runtime JSON preview provided."\n}'
        : widget.videoIntegrityCertificateJsonPreview!.trim();
    final markdownPreview =
        (widget.videoIntegrityCertificateMarkdownPreview ?? '').trim().isEmpty
        ? '# Integrity Certificate\n\nNo runtime markdown preview provided.'
        : widget.videoIntegrityCertificateMarkdownPreview!.trim();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF0E1A2B),
          child: DefaultTabController(
            length: 2,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760, maxHeight: 640),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.videoOpsLabel} Integrity Certificate',
                      style: GoogleFonts.rajdhani(
                        color: const Color(0xFFE8F1FF),
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Preview the latest ${widget.videoOpsLabel} integrity certificate derived from runtime video intelligence evidence.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8EA5C6),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const TabBar(
                      tabs: [
                        Tab(text: 'JSON'),
                        Tab(text: 'Markdown'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _adminCertificatePane(jsonPreview),
                          _adminCertificatePane(markdownPreview),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: jsonPreview),
                            );
                          },
                          icon: const Icon(
                            Icons.content_copy_rounded,
                            size: 16,
                          ),
                          label: Text(
                            'Copy JSON',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFEAF4FF),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: markdownPreview),
                            );
                          },
                          icon: const Icon(
                            Icons.content_copy_rounded,
                            size: 16,
                          ),
                          label: Text(
                            'Copy Markdown',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFEAF4FF),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: Text(
                            'Close',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFEAF4FF),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _adminCertificatePane(String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF091221),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1A355A)),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          content,
          style: GoogleFonts.robotoMono(
            color: const Color(0xFFE6F0FF),
            fontSize: 12,
            height: 1.45,
          ),
        ),
      ),
    );
  }

  Widget _telegramBridgeStatusPanel() {
    final tone = _telegramBridgeTone();
    final detail = (widget.telegramBridgeHealthDetail ?? '').trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tone.$3,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: tone.$4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tone.$1,
            style: GoogleFonts.inter(
              color: tone.$2,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail.isEmpty ? 'No bridge detail available.' : detail,
            style: GoogleFonts.inter(
              color: const Color(0xFFEAF4FF),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _telegramBridgeUpdatedAtLabel(),
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _telegramAiLastHandledLabel() {
    final at = widget.telegramAiLastHandledAtUtc?.toLocal();
    if (at == null) {
      return 'No AI message handled yet.';
    }
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    final summary = (widget.telegramAiLastHandledSummary ?? '').trim();
    if (summary.isEmpty) {
      return 'Last handled at $hh:$mm';
    }
    return 'Last: $summary • $hh:$mm';
  }

  String _compactSingleLine(String text, {int max = 180}) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= max) return normalized;
    return '${normalized.substring(0, max - 3)}...';
  }

  Future<void> _setTelegramAiAssistantEnabled(bool enabled) async {
    if (_telegramAiSettingsBusy ||
        widget.onSetTelegramAiAssistantEnabled == null) {
      return;
    }
    setState(() => _telegramAiSettingsBusy = true);
    try {
      await widget.onSetTelegramAiAssistantEnabled!.call(enabled);
      _snack('Telegram AI assistant ${enabled ? 'enabled' : 'disabled'}.');
    } catch (error) {
      _snack('Failed to update AI assistant setting.');
    } finally {
      if (mounted) {
        setState(() => _telegramAiSettingsBusy = false);
      }
    }
  }

  Future<void> _setTelegramAiApprovalRequired(bool required) async {
    if (_telegramAiSettingsBusy ||
        widget.onSetTelegramAiApprovalRequired == null) {
      return;
    }
    setState(() => _telegramAiSettingsBusy = true);
    try {
      await widget.onSetTelegramAiApprovalRequired!.call(required);
      _snack(
        'Client AI approval ${required ? 'enabled (manual)' : 'disabled (auto-send)'}.',
      );
    } catch (error) {
      _snack('Failed to update AI approval setting.');
    } finally {
      if (mounted) {
        setState(() => _telegramAiSettingsBusy = false);
      }
    }
  }

  Future<void> _saveOperatorId() async {
    if (_operatorIdSaving || widget.onSetOperatorId == null) {
      return;
    }
    final nextOperatorId = _operatorIdController.text.trim();
    setState(() => _operatorIdSaving = true);
    try {
      await widget.onSetOperatorId!.call(nextOperatorId);
      final resolved = nextOperatorId.isEmpty
          ? 'default operator'
          : nextOperatorId;
      _snack('Operator runtime set to $resolved.');
    } catch (_) {
      _snack('Failed to update operator runtime.');
    } finally {
      if (mounted) {
        setState(() => _operatorIdSaving = false);
      }
    }
  }

  ({String clientId, String siteId}) _resolvePartnerRuntimeScope({
    required List<_ClientAdminRow> clients,
    required List<_SiteAdminRow> sites,
    String? preferredClientId,
    String? preferredSiteId,
  }) {
    final sitePreferred = preferredSiteId?.trim() ?? '';
    final clientPreferred = preferredClientId?.trim() ?? '';

    if (sitePreferred.isNotEmpty) {
      for (final site in sites) {
        if (site.id == sitePreferred) {
          return (clientId: site.clientId, siteId: site.id);
        }
      }
    }

    if (clientPreferred.isNotEmpty) {
      final siteForClient = sites.where(
        (site) => site.clientId == clientPreferred,
      );
      if (siteForClient.isNotEmpty) {
        return (clientId: clientPreferred, siteId: siteForClient.first.id);
      }
      final clientExists = clients.any(
        (client) => client.id == clientPreferred,
      );
      if (clientExists) {
        return (clientId: clientPreferred, siteId: '');
      }
    }

    if (sites.isNotEmpty) {
      return (clientId: sites.first.clientId, siteId: sites.first.id);
    }
    if (clients.isNotEmpty) {
      return (clientId: clients.first.id, siteId: '');
    }
    return (clientId: '', siteId: '');
  }

  List<_SiteAdminRow> _partnerRuntimeSitesForClient(String clientId) {
    final normalizedClientId = clientId.trim();
    if (normalizedClientId.isEmpty) {
      return _sites;
    }
    return _sites
        .where((site) => site.clientId == normalizedClientId)
        .toList(growable: false);
  }

  Future<void> _runPartnerRuntimeBind() async {
    if (_partnerRuntimeBusy || widget.onBindPartnerTelegramEndpoint == null) {
      return;
    }
    final clientId = (_partnerRuntimeClientId ?? '').trim();
    final siteId = (_partnerRuntimeSiteId ?? '').trim();
    final endpointLabel = _partnerEndpointLabelController.text.trim();
    final chatId = _partnerChatIdController.text.trim();
    final threadId = int.tryParse(_partnerThreadIdController.text.trim());
    if (clientId.isEmpty || siteId.isEmpty) {
      _snack('Select a client/site scope before binding a partner lane.');
      return;
    }
    if (chatId.isEmpty) {
      _snack('Partner chat ID is required.');
      return;
    }
    setState(() => _partnerRuntimeBusy = true);
    try {
      final result = await widget.onBindPartnerTelegramEndpoint!.call(
        clientId: clientId,
        siteId: siteId,
        endpointLabel: endpointLabel,
        chatId: chatId,
        threadId: threadId,
      );
      if (!mounted) return;
      setState(() => _partnerRuntimeStatus = result);
      _snack('Partner dispatch lane saved.');
    } catch (error) {
      _snack('Failed to save partner dispatch lane.');
    } finally {
      if (mounted) {
        setState(() => _partnerRuntimeBusy = false);
      }
    }
  }

  Future<void> _runPartnerRuntimeCheck() async {
    if (_partnerRuntimeBusy || widget.onCheckPartnerTelegramEndpoint == null) {
      return;
    }
    final clientId = (_partnerRuntimeClientId ?? '').trim();
    final siteId = (_partnerRuntimeSiteId ?? '').trim();
    final chatId = _partnerChatIdController.text.trim();
    final threadId = int.tryParse(_partnerThreadIdController.text.trim());
    if (clientId.isEmpty || siteId.isEmpty) {
      _snack('Select a client/site scope before checking a partner lane.');
      return;
    }
    if (chatId.isEmpty) {
      _snack('Partner chat ID is required for check.');
      return;
    }
    setState(() => _partnerRuntimeBusy = true);
    try {
      final result = await widget.onCheckPartnerTelegramEndpoint!.call(
        clientId: clientId,
        siteId: siteId,
        chatId: chatId,
        threadId: threadId,
      );
      if (!mounted) return;
      setState(() => _partnerRuntimeStatus = result);
    } catch (error) {
      _snack('Failed to verify partner dispatch lane.');
    } finally {
      if (mounted) {
        setState(() => _partnerRuntimeBusy = false);
      }
    }
  }

  Future<void> _runPartnerRuntimeUnlink() async {
    if (_partnerRuntimeBusy || widget.onUnlinkPartnerTelegramEndpoint == null) {
      return;
    }
    final clientId = (_partnerRuntimeClientId ?? '').trim();
    final siteId = (_partnerRuntimeSiteId ?? '').trim();
    final chatId = _partnerChatIdController.text.trim();
    final threadId = int.tryParse(_partnerThreadIdController.text.trim());
    if (clientId.isEmpty || siteId.isEmpty) {
      _snack('Select a client/site scope before unlinking a partner lane.');
      return;
    }
    if (chatId.isEmpty) {
      _snack('Partner chat ID is required for unlink.');
      return;
    }
    setState(() => _partnerRuntimeBusy = true);
    try {
      final result = await widget.onUnlinkPartnerTelegramEndpoint!.call(
        clientId: clientId,
        siteId: siteId,
        chatId: chatId,
        threadId: threadId,
      );
      if (!mounted) return;
      setState(() => _partnerRuntimeStatus = result);
      _snack('Partner dispatch lane updated.');
    } catch (error) {
      _snack('Failed to unlink partner dispatch lane.');
    } finally {
      if (mounted) {
        setState(() => _partnerRuntimeBusy = false);
      }
    }
  }

  Future<void> _resetOperatorId() async {
    if (_operatorIdSaving || widget.onSetOperatorId == null) {
      return;
    }
    _operatorIdController.clear();
    await _saveOperatorId();
  }

  Future<void> _approveTelegramAiDraft(TelegramAiPendingDraftView draft) async {
    if (widget.onApproveTelegramAiDraft == null ||
        _telegramAiDraftActionBusyIds.contains(draft.updateId)) {
      return;
    }
    setState(() {
      _telegramAiDraftActionBusyIds = {
        ..._telegramAiDraftActionBusyIds,
        draft.updateId,
      };
    });
    try {
      final message = await widget.onApproveTelegramAiDraft!.call(
        draft.updateId,
      );
      _snack(message.trim().isEmpty ? 'Draft approved.' : message);
    } catch (_) {
      _snack('Failed to approve AI draft ${draft.updateId}.');
    } finally {
      if (mounted) {
        setState(() {
          _telegramAiDraftActionBusyIds = _telegramAiDraftActionBusyIds
              .where((entry) => entry != draft.updateId)
              .toSet();
        });
      }
    }
  }

  Future<void> _rejectTelegramAiDraft(TelegramAiPendingDraftView draft) async {
    if (widget.onRejectTelegramAiDraft == null ||
        _telegramAiDraftActionBusyIds.contains(draft.updateId)) {
      return;
    }
    setState(() {
      _telegramAiDraftActionBusyIds = {
        ..._telegramAiDraftActionBusyIds,
        draft.updateId,
      };
    });
    try {
      final message = await widget.onRejectTelegramAiDraft!.call(
        draft.updateId,
      );
      _snack(message.trim().isEmpty ? 'Draft rejected.' : message);
    } catch (_) {
      _snack('Failed to reject AI draft ${draft.updateId}.');
    } finally {
      if (mounted) {
        setState(() {
          _telegramAiDraftActionBusyIds = _telegramAiDraftActionBusyIds
              .where((entry) => entry != draft.updateId)
              .toSet();
        });
      }
    }
  }

  Widget _telegramAiAssistantPanel() {
    final drafts = widget.telegramAiPendingDrafts;
    final canToggleAssist = widget.onSetTelegramAiAssistantEnabled != null;
    final canToggleApproval = widget.onSetTelegramAiApprovalRequired != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1117),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0x332B425F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.smart_toy_rounded,
                size: 16,
                color: widget.telegramAiAssistantEnabled
                    ? const Color(0xFF22D3EE)
                    : const Color(0xFF8EA4C2),
              ),
              const SizedBox(width: 6),
              Text(
                'Telegram AI Assistant',
                style: GoogleFonts.inter(
                  color: const Color(0xFFEAF4FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                'Drafts: ${drafts.length}',
                style: GoogleFonts.inter(
                  color: const Color(0xFF9AB1CF),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _telegramAiLastHandledLabel(),
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: (!canToggleAssist || _telegramAiSettingsBusy)
                    ? null
                    : () => _setTelegramAiAssistantEnabled(
                        !widget.telegramAiAssistantEnabled,
                      ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: widget.telegramAiAssistantEnabled
                      ? const Color(0xFF34D399)
                      : const Color(0xFF8EA4C2),
                  side: BorderSide(
                    color: widget.telegramAiAssistantEnabled
                        ? const Color(0xFF2F5949)
                        : const Color(0xFF35506F),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: Icon(
                  widget.telegramAiAssistantEnabled
                      ? Icons.toggle_on_rounded
                      : Icons.toggle_off_rounded,
                  size: 16,
                ),
                label: Text(
                  'AI Assist ${widget.telegramAiAssistantEnabled ? 'ON' : 'OFF'}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: (!canToggleApproval || _telegramAiSettingsBusy)
                    ? null
                    : () => _setTelegramAiApprovalRequired(
                        !widget.telegramAiApprovalRequired,
                      ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: widget.telegramAiApprovalRequired
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF9AB1CF),
                  side: BorderSide(
                    color: widget.telegramAiApprovalRequired
                        ? const Color(0xFF5B3A16)
                        : const Color(0xFF35506F),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: Icon(
                  widget.telegramAiApprovalRequired
                      ? Icons.verified_user_rounded
                      : Icons.auto_awesome_rounded,
                  size: 16,
                ),
                label: Text(
                  widget.telegramAiApprovalRequired
                      ? 'Client Reply Approval ON'
                      : 'Client Reply Approval OFF',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (drafts.isEmpty)
            Text(
              'No pending AI drafts.',
              style: GoogleFonts.inter(
                color: const Color(0xFF8EA4C2),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            ...drafts.take(4).map((draft) {
              final busy = _telegramAiDraftActionBusyIds.contains(
                draft.updateId,
              );
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF121A24),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x332B425F)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${draft.updateId} • ${draft.clientId}/${draft.siteId} • ${draft.chatId}${draft.messageThreadId == null ? '' : '#${draft.messageThreadId}'}',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFEAF4FF),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Provider: ${draft.providerLabel} • ${draft.createdAtUtc.toLocal().toIso8601String()}',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8EA4C2),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Client: ${_compactSingleLine(draft.sourceText, max: 150)}',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF9AB1CF),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Draft: ${_compactSingleLine(draft.draftText, max: 150)}',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF67E8F9),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed:
                              (widget.onApproveTelegramAiDraft == null || busy)
                              ? null
                              : () => _approveTelegramAiDraft(draft),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D5B),
                            foregroundColor: const Color(0xFFEAF4FF),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                          icon: const Icon(Icons.check_rounded, size: 14),
                          label: Text(
                            'Approve',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              (widget.onRejectTelegramAiDraft == null || busy)
                              ? null
                              : () => _rejectTelegramAiDraft(draft),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFF87171),
                            side: const BorderSide(color: Color(0xFF5B242C)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                          icon: const Icon(Icons.close_rounded, size: 14),
                          label: Text(
                            'Reject',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _operatorRuntimePanel() {
    final canSave = widget.onSetOperatorId != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1117),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0x332B425F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.badge_rounded,
                size: 16,
                color: Color(0xFF67E8F9),
              ),
              const SizedBox(width: 6),
              Text(
                'Operator Runtime',
                style: GoogleFonts.inter(
                  color: const Color(0xFFEAF4FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Active operator: ${widget.operatorId}',
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('admin-operator-runtime-field'),
            controller: _operatorIdController,
            enabled: canSave && !_operatorIdSaving,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saveOperatorId(),
            style: GoogleFonts.robotoMono(
              color: const Color(0xFFEAF4FF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              labelText: 'Operator ID',
              hintText: 'OPERATOR-01',
              hintStyle: GoogleFonts.robotoMono(
                color: const Color(0xFF6A829F),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              labelStyle: GoogleFonts.inter(
                color: const Color(0xFF9AB1CF),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              filled: true,
              fillColor: const Color(0xFF0A0F15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0x332B425F)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0x332B425F)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF4E7498)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Affects new execution and review events. Leave blank to revert to the default runtime operator.',
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: (!canSave || _operatorIdSaving)
                    ? null
                    : _saveOperatorId,
                icon: _operatorIdSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded, size: 16),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2B5E93),
                  foregroundColor: const Color(0xFFEAF4FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                label: Text(
                  _operatorIdSaving ? 'Saving...' : 'Save Operator',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: (!canSave || _operatorIdSaving)
                    ? null
                    : _resetOperatorId,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEAF4FF),
                  side: const BorderSide(color: Color(0xFF35506F)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                label: Text(
                  'Reset Default',
                  style: GoogleFonts.inter(
                    fontSize: 11,
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

  Widget _partnerDispatchRuntimePanel() {
    final clientScope = (_partnerRuntimeClientId ?? '').trim();
    final siteScope = (_partnerRuntimeSiteId ?? '').trim();
    final sitesForClient = _partnerRuntimeSitesForClient(clientScope);
    final canMutate = widget.onBindPartnerTelegramEndpoint != null;
    final canCheck = widget.onCheckPartnerTelegramEndpoint != null;
    final canUnlink = widget.onUnlinkPartnerTelegramEndpoint != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1117),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0x332B425F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_shipping_rounded,
                size: 16,
                color: Color(0xFFF59E0B),
              ),
              const SizedBox(width: 6),
              Text(
                'Partner Dispatch Runtime',
                style: GoogleFonts.inter(
                  color: const Color(0xFFEAF4FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Bind, verify, or unlink the Telegram lane used for partner ACCEPT / ON SITE / ALL CLEAR updates.',
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (_clients.isEmpty || _sites.isEmpty)
            Text(
              'Client/site directory is required before partner runtime lanes can be managed.',
              style: GoogleFonts.inter(
                color: const Color(0xFF8EA4C2),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(
                      'admin-partner-runtime-client-dropdown-$clientScope',
                    ),
                    isExpanded: true,
                    initialValue: clientScope.isEmpty ? null : clientScope,
                    items: _clients
                        .map(
                          (client) => DropdownMenuItem<String>(
                            value: client.id,
                            child: Text(
                              client.name,
                              style: GoogleFonts.inter(fontSize: 12),
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _partnerRuntimeBusy
                        ? null
                        : (value) {
                            final resolved = _resolvePartnerRuntimeScope(
                              clients: _clients,
                              sites: _sites,
                              preferredClientId: value,
                            );
                            setState(() {
                              _partnerRuntimeClientId = resolved.clientId;
                              _partnerRuntimeSiteId = resolved.siteId;
                            });
                          },
                    decoration: const InputDecoration(
                      labelText: 'Client Scope',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(
                      'admin-partner-runtime-site-dropdown-$siteScope',
                    ),
                    isExpanded: true,
                    initialValue: siteScope.isEmpty ? null : siteScope,
                    items: sitesForClient
                        .map(
                          (site) => DropdownMenuItem<String>(
                            value: site.id,
                            child: Text(
                              site.name,
                              style: GoogleFonts.inter(fontSize: 12),
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _partnerRuntimeBusy
                        ? null
                        : (value) {
                            setState(() {
                              _partnerRuntimeSiteId = value?.trim() ?? '';
                            });
                          },
                    decoration: const InputDecoration(labelText: 'Site Scope'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('admin-partner-runtime-label-field'),
              controller: _partnerEndpointLabelController,
              enabled: !_partnerRuntimeBusy,
              style: GoogleFonts.robotoMono(
                color: const Color(0xFFEAF4FF),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                labelText: 'Partner Endpoint Label',
                hintText: 'PARTNER • Response',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('admin-partner-runtime-chat-field'),
                    controller: _partnerChatIdController,
                    enabled: !_partnerRuntimeBusy,
                    style: GoogleFonts.robotoMono(
                      color: const Color(0xFFEAF4FF),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Partner Chat ID',
                      hintText: '-1000000009999',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 160,
                  child: TextField(
                    key: const ValueKey('admin-partner-runtime-thread-field'),
                    controller: _partnerThreadIdController,
                    enabled: !_partnerRuntimeBusy,
                    style: GoogleFonts.robotoMono(
                      color: const Color(0xFFEAF4FF),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Thread ID',
                      hintText: 'optional',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: (!canMutate || _partnerRuntimeBusy)
                      ? null
                      : _runPartnerRuntimeBind,
                  icon: _partnerRuntimeBusy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link_rounded, size: 16),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2B5E93),
                    foregroundColor: const Color(0xFFEAF4FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  label: Text(
                    _partnerRuntimeBusy ? 'Working...' : 'Bind Partner Lane',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: (!canCheck || _partnerRuntimeBusy)
                      ? null
                      : _runPartnerRuntimeCheck,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEAF4FF),
                    side: const BorderSide(color: Color(0xFF35506F)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.verified_user_rounded, size: 16),
                  label: Text(
                    'Check Lane',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: (!canUnlink || _partnerRuntimeBusy)
                      ? null
                      : _runPartnerRuntimeUnlink,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFCA5A5),
                    side: const BorderSide(color: Color(0xFF7F1D1D)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.link_off_rounded, size: 16),
                  label: Text(
                    'Unlink Lane',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if ((_partnerRuntimeStatus ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              SelectableText(
                _partnerRuntimeStatus!.trim(),
                style: GoogleFonts.robotoMono(
                  color: const Color(0xFF9AB1CF),
                  fontSize: 11,
                  height: 1.45,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _opsQueueActionButtons() {
    final hasPending = widget.radioQueueHasPending;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: widget.onRunOpsIntegrationPoll != null
              ? () async {
                  await widget.onRunOpsIntegrationPoll!.call();
                }
              : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF7DD3FC),
            side: const BorderSide(color: Color(0xFF35506F)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.sync_rounded, size: 16),
          label: Text(
            'Run Ops Poll Now',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        OutlinedButton.icon(
          onPressed: widget.onRunRadioPoll != null
              ? () async {
                  await widget.onRunRadioPoll!.call();
                }
              : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF67E8F9),
            side: const BorderSide(color: Color(0xFF35506F)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.sensors_rounded, size: 16),
          label: Text(
            'Poll Radio',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        OutlinedButton.icon(
          onPressed: widget.onRunCctvPoll != null
              ? () async {
                  await widget.onRunCctvPoll!.call();
                }
              : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF93C5FD),
            side: const BorderSide(color: Color(0xFF35506F)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.videocam_rounded, size: 16),
          label: Text(
            'Poll ${widget.videoOpsLabel}',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        OutlinedButton.icon(
          onPressed: widget.onRunWearablePoll != null
              ? () async {
                  await widget.onRunWearablePoll!.call();
                }
              : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF34D399),
            side: const BorderSide(color: Color(0xFF2F5949)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.watch_rounded, size: 16),
          label: Text(
            'Poll Wearable',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        OutlinedButton.icon(
          onPressed: widget.onRunNewsPoll != null
              ? () async {
                  await widget.onRunNewsPoll!.call();
                }
              : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFF59E0B),
            side: const BorderSide(color: Color(0xFF5B3A16)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.newspaper_rounded, size: 16),
          label: Text(
            'Poll News',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        OutlinedButton.icon(
          onPressed: hasPending && widget.onRetryRadioQueue != null
              ? () async {
                  await widget.onRetryRadioQueue!.call();
                }
              : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF67E8F9),
            side: const BorderSide(color: Color(0xFF35506F)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: Text(
            'Retry Radio Queue',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        OutlinedButton.icon(
          onPressed: hasPending && widget.onClearRadioQueue != null
              ? () async {
                  await _confirmClearRadioQueue();
                }
              : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFF87171),
            side: const BorderSide(color: Color(0xFF5B242C)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.clear_all_rounded, size: 16),
          label: Text(
            'Clear Radio Queue',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        OutlinedButton.icon(
          onPressed: widget.onClearRadioQueueFailureSnapshot != null
              ? () async {
                  await _confirmClearRadioFailureSnapshot();
                }
              : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFF59E0B),
            side: const BorderSide(color: Color(0xFF5B3A16)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.history_toggle_off_rounded, size: 16),
          label: Text(
            'Clear Last Failure',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmClearRadioQueue() async {
    if (!widget.radioQueueHasPending || widget.onClearRadioQueue == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF30363D)),
          ),
          title: Text(
            'Clear Radio Queue?',
            style: GoogleFonts.inter(
              color: const Color(0xFFEAF4FF),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'This removes all pending automated radio responses from the queue.',
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: const Color(0xFF9AB1CF),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB91C1C),
                foregroundColor: const Color(0xFFEAF4FF),
              ),
              child: Text(
                'Confirm Clear',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await widget.onClearRadioQueue!.call();
    }
  }

  Future<void> _confirmClearRadioFailureSnapshot() async {
    if (widget.onClearRadioQueueFailureSnapshot == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF30363D)),
          ),
          title: Text(
            'Clear Last Failure Snapshot?',
            style: GoogleFonts.inter(
              color: const Color(0xFFEAF4FF),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'This clears the persisted last radio failure snapshot from system diagnostics.',
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: const Color(0xFF9AB1CF),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB45309),
                foregroundColor: const Color(0xFFEAF4FF),
              ),
              child: Text(
                'Confirm Clear',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await widget.onClearRadioQueueFailureSnapshot!.call();
    }
  }

  List<Widget> _opsPollHealthRows() {
    final rows = <(String, String)>[];
    if ((widget.radioOpsPollHealth ?? '').trim().isNotEmpty) {
      rows.add(('Radio', widget.radioOpsPollHealth!.trim()));
    }
    if ((widget.radioOpsQueueHealth ?? '').trim().isNotEmpty) {
      rows.add(('Radio Queue', widget.radioOpsQueueHealth!.trim()));
    }
    if ((widget.radioOpsQueueIntentMix ?? '').trim().isNotEmpty) {
      rows.add(('Radio Queue Mix', widget.radioOpsQueueIntentMix!.trim()));
    }
    if ((widget.radioOpsAckRecentSummary ?? '').trim().isNotEmpty) {
      rows.add(('Radio ACK Recent', widget.radioOpsAckRecentSummary!.trim()));
    }
    if ((widget.radioOpsQueueStateDetail ?? '').trim().isNotEmpty) {
      rows.add(('Radio Queue State', widget.radioOpsQueueStateDetail!.trim()));
    }
    if ((widget.radioOpsFailureDetail ?? '').trim().isNotEmpty) {
      rows.add(('Radio Failure', widget.radioOpsFailureDetail!.trim()));
    }
    if ((widget.radioOpsFailureAuditDetail ?? '').trim().isNotEmpty) {
      rows.add((
        'Radio Failure Audit',
        widget.radioOpsFailureAuditDetail!.trim(),
      ));
    }
    if ((widget.radioOpsManualActionDetail ?? '').trim().isNotEmpty) {
      rows.add(('Radio Action', widget.radioOpsManualActionDetail!.trim()));
    }
    if ((widget.cctvOpsPollHealth ?? '').trim().isNotEmpty) {
      rows.add((widget.videoOpsLabel, widget.cctvOpsPollHealth!.trim()));
    }
    if ((widget.cctvCapabilitySummary ?? '').trim().isNotEmpty) {
      rows.add((
        '${widget.videoOpsLabel} Caps',
        widget.cctvCapabilitySummary!.trim(),
      ));
    }
    if ((widget.cctvRecentSignalSummary ?? '').trim().isNotEmpty) {
      rows.add((
        '${widget.videoOpsLabel} Recent',
        widget.cctvRecentSignalSummary!.trim(),
      ));
    }
    if ((widget.cctvEvidenceHealthSummary ?? '').trim().isNotEmpty) {
      rows.add((
        '${widget.videoOpsLabel} Evidence',
        widget.cctvEvidenceHealthSummary!.trim(),
      ));
    }
    if ((widget.cctvCameraHealthSummary ?? '').trim().isNotEmpty) {
      rows.add((
        '${widget.videoOpsLabel} Cameras',
        widget.cctvCameraHealthSummary!.trim(),
      ));
    }
    if ((widget.incidentSpoolHealthSummary ?? '').trim().isNotEmpty) {
      rows.add(('Incident Spool', widget.incidentSpoolHealthSummary!.trim()));
    }
    if ((widget.incidentSpoolReplaySummary ?? '').trim().isNotEmpty) {
      rows.add(('Spool Replay', widget.incidentSpoolReplaySummary!.trim()));
    }
    if ((widget.monitoringWatchAuditSummary ?? '').trim().isNotEmpty) {
      rows.add(('Watch Audit', widget.monitoringWatchAuditSummary!.trim()));
    }
    if ((widget.wearableOpsPollHealth ?? '').trim().isNotEmpty) {
      rows.add(('Wearable', widget.wearableOpsPollHealth!.trim()));
    }
    if ((widget.listenerAlarmOpsPollHealth ?? '').trim().isNotEmpty) {
      rows.add(('Listener Alarm', widget.listenerAlarmOpsPollHealth!.trim()));
    }
    if ((widget.newsOpsPollHealth ?? '').trim().isNotEmpty) {
      rows.add(('News', widget.newsOpsPollHealth!.trim()));
    }
    return rows
        .map(
          (row) => Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF0C1117),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0x332B425F)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 74,
                  child: Text(
                    row.$1.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: const Color(0xFF8EA4C2),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    row.$2,
                    style: GoogleFonts.robotoMono(
                      color: const Color(0xFF67E8F9),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList(growable: false);
  }

  Widget _monitoringWatchAuditTrailPanel() {
    final history = widget.monitoringWatchAuditHistory
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .map(
          (entry) =>
              (raw: entry, record: _watchRecoveryStore.parseAuditRecord(entry)),
        )
        .toList(growable: false);
    if (history.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1117),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0x332B425F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Watch Recovery Trail',
                style: GoogleFonts.inter(
                  color: const Color(0xFFEAF4FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x1422D3EE),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0x3322D3EE)),
                ),
                child: Text(
                  '${history.length} entries',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF67E8F9),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...history.asMap().entries.map((entry) {
            final index = entry.key;
            final audit = entry.value;
            final isLatest = index == 0;
            final record = audit.record;
            final isStructured = record?.isValid ?? false;
            return Container(
              width: double.infinity,
              margin: EdgeInsets.only(
                bottom: index == history.length - 1 ? 0 : 8,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: isLatest
                    ? const Color(0x1410B981)
                    : const Color(0xFF11161D),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isLatest
                      ? const Color(0x334AD2A0)
                      : const Color(0x332B425F),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 46,
                    child: Text(
                      isLatest ? 'LATEST' : '#${index + 1}',
                      style: GoogleFonts.inter(
                        color: isLatest
                            ? const Color(0xFF86EFAC)
                            : const Color(0xFF8EA4C2),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: isStructured
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                record!.siteLabel,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFEAF4FF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _watchAuditChip(
                                    'Actor',
                                    record.actor,
                                    color: const Color(0xFF67E8F9),
                                  ),
                                  _watchAuditChip(
                                    'Outcome',
                                    record.outcome,
                                    color: isLatest
                                        ? const Color(0xFF86EFAC)
                                        : const Color(0xFFFDE68A),
                                  ),
                                  _watchAuditChip(
                                    'At',
                                    _watchAuditRecordedAtLabel(record),
                                    color: const Color(0xFFBFD7F2),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                record.action,
                                style: GoogleFonts.robotoMono(
                                  color: const Color(0xFF67E8F9),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            audit.raw,
                            style: GoogleFonts.robotoMono(
                              color: const Color(0xFF67E8F9),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _watchAuditChip(String label, String value, {required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1117),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x332B425F)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: GoogleFonts.inter(
                color: const Color(0xFF8EA4C2),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _watchAuditRecordedAtLabel(MonitoringWatchAuditRecord audit) {
    final recordedAtUtc = audit.recordedAtUtc;
    if (recordedAtUtc == null) {
      return 'Unknown';
    }
    final year = recordedAtUtc.year.toString().padLeft(4, '0');
    final month = recordedAtUtc.month.toString().padLeft(2, '0');
    final day = recordedAtUtc.day.toString().padLeft(2, '0');
    final hour = recordedAtUtc.hour.toString().padLeft(2, '0');
    final minute = recordedAtUtc.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute UTC';
  }

  Widget _fleetScopeHealthPanel({
    required void Function(VideoFleetWatchActionDrilldown drilldown)
    onOpenWatchActionDrilldown,
    required void Function(VideoFleetScopeHealthView scope)
    onOpenLatestWatchActionDetail,
  }) {
    final sections = VideoFleetScopeHealthSections.fromScopes(
      widget.fleetScopeHealth,
    );
    final filteredSections = VideoFleetScopeHealthSections.fromScopes(
      orderFleetScopesForWatchAction(
        filterFleetScopesForWatchAction(
          widget.fleetScopeHealth,
          _activeWatchActionDrilldown,
        ),
        _activeWatchActionDrilldown,
      ),
    );
    final primaryFocusedScope = primaryFleetScopeForWatchAction(
      filteredSections,
      _activeWatchActionDrilldown,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_activeWatchActionDrilldown != null) ...[
          _watchActionFocusBanner(primaryFocusedScope),
          const SizedBox(height: 8),
        ],
        VideoFleetScopeHealthPanel(
          title: '${widget.videoOpsLabel} Fleet Health',
          titleStyle: GoogleFonts.inter(
            color: const Color(0xFFEAF4FF),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          sectionLabelStyle: GoogleFonts.inter(
            color: const Color(0xFF8EA4C2),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.9,
          ),
          sections: filteredSections,
          activeWatchActionDrilldown: _activeWatchActionDrilldown,
          summaryChildren: _fleetSummaryChips(
            sections: sections,
            onOpenWatchActionDrilldown: onOpenWatchActionDrilldown,
          ),
          actionableChildren: filteredSections.actionableScopes
              .map(
                (scope) => _fleetScopeHealthCard(
                  scope,
                  onOpenLatestWatchActionDetail: onOpenLatestWatchActionDetail,
                ),
              )
              .toList(growable: false),
          watchOnlyChildren: filteredSections.watchOnlyScopes
              .map(
                (scope) => _fleetScopeHealthCard(
                  scope,
                  onOpenLatestWatchActionDetail: onOpenLatestWatchActionDetail,
                ),
              )
              .toList(growable: false),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF0C1117),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0x332B425F)),
          ),
        ),
      ],
    );
  }

  List<_SuppressedSceneReviewEntry> _suppressedSceneReviewEntries() {
    final output = <_SuppressedSceneReviewEntry>[];
    for (final scope in widget.fleetScopeHealth) {
      if (!scope.hasSuppressedSceneAction) {
        continue;
      }
      final intelligenceId = (scope.latestIncidentReference ?? '').trim();
      if (intelligenceId.isEmpty) {
        continue;
      }
      final review = widget.sceneReviewByIntelligenceId[intelligenceId];
      if (review == null) {
        continue;
      }
      output.add(_SuppressedSceneReviewEntry(scope: scope, review: review));
    }
    output.sort(
      (a, b) => b.review.reviewedAtUtc.compareTo(a.review.reviewedAtUtc),
    );
    return output;
  }

  Widget _suppressedSceneReviewPanel(
    List<_SuppressedSceneReviewEntry> entries,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1117),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0x332B425F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Suppressed Scene Reviews',
                style: GoogleFonts.inter(
                  color: const Color(0xFFEAF4FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x149AB1CF),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0x339AB1CF)),
                ),
                child: Text(
                  '${entries.length} internal',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFBFD7F2),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Recent ${widget.videoOpsLabel} reviews ONYX kept internal during the active watch window.',
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ...entries.take(6).toList(growable: false).asMap().entries.map((
            entry,
          ) {
            final item = entry.value;
            final scope = item.scope;
            final review = item.review;
            final incidentRef = (scope.latestIncidentReference ?? '').trim();
            final decisionSummary = review.decisionSummary.trim();
            final reviewSummary = review.summary.trim();
            return Container(
              width: double.infinity,
              margin: EdgeInsets.only(
                bottom: entry.key == math.min(entries.length, 6) - 1 ? 0 : 8,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFF11161D),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x332B425F)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          scope.siteName,
                          style: GoogleFonts.inter(
                            color: const Color(0xFFEAF4FF),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _suppressedReviewedAtLabel(review.reviewedAtUtc),
                        style: GoogleFonts.robotoMono(
                          color: const Color(0xFF8EA4C2),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _watchAuditChip(
                        'Action',
                        review.decisionLabel.trim().isEmpty
                            ? 'Suppressed'
                            : review.decisionLabel,
                        color: const Color(0xFFBFD7F2),
                      ),
                      if ((scope.latestCameraLabel ?? '').trim().isNotEmpty)
                        _watchAuditChip(
                          'Camera',
                          scope.latestCameraLabel!,
                          color: const Color(0xFF67E8F9),
                        ),
                      _watchAuditChip(
                        'Source',
                        review.sourceLabel,
                        color: const Color(0xFFFDE68A),
                      ),
                      _watchAuditChip(
                        'Posture',
                        review.postureLabel,
                        color: const Color(0xFF86EFAC),
                      ),
                    ],
                  ),
                  if (decisionSummary.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      decisionSummary,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFEAF4FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (reviewSummary.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Scene review: $reviewSummary',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF9AB1CF),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (incidentRef.isNotEmpty &&
                      (widget.onOpenEventsForIncident != null ||
                          widget.onOpenLedgerForIncident != null)) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (widget.onOpenEventsForIncident != null)
                          _fleetActionButton(
                            label: 'Events',
                            color: const Color(0xFF67E8F9),
                            onPressed: () => widget.onOpenEventsForIncident!
                                .call(incidentRef),
                          ),
                        if (widget.onOpenLedgerForIncident != null)
                          _fleetActionButton(
                            label: 'Ledger',
                            color: const Color(0xFFFBBF24),
                            onPressed: () => widget.onOpenLedgerForIncident!
                                .call(incidentRef),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _identityPolicyPanel() {
    final entries = _monitoringIdentityPolicyService.entries;
    final hasOverride = widget.initialMonitoringIdentityRulesJson
        .trim()
        .isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1117),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0x332B425F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Identity Rules',
                style: GoogleFonts.inter(
                  color: const Color(0xFFEAF4FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x149AB1CF),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0x339AB1CF)),
                ),
                child: Text(
                  '${entries.length} sites',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFBFD7F2),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Configured allowlisted and flagged face and plate rules currently shaping ONYX watch decisions.',
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const ValueKey('identity-rules-copy-json'),
                onPressed: _identityPolicySaving
                    ? null
                    : _copyMonitoringIdentityRulesJson,
                icon: const Icon(Icons.copy_all_rounded, size: 16),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2B5E93),
                  foregroundColor: const Color(0xFFEAF4FF),
                ),
                label: Text(
                  'Copy JSON',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.icon(
                key: const ValueKey('identity-rules-import-json'),
                onPressed: _identityPolicySaving
                    ? null
                    : _importMonitoringIdentityRulesJson,
                icon: const Icon(Icons.upload_file_rounded, size: 16),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: const Color(0xFFEAF4FF),
                ),
                label: Text(
                  'Import JSON',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.icon(
                key: const ValueKey('identity-rules-save-runtime'),
                onPressed:
                    _identityPolicySaving ||
                        widget.onSaveMonitoringIdentityPolicyService == null
                    ? null
                    : _saveMonitoringIdentityRules,
                icon: const Icon(Icons.save_rounded, size: 16),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: const Color(0xFFEAF4FF),
                ),
                label: Text(
                  'Save Runtime',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton.icon(
                key: const ValueKey('identity-rules-reset-runtime'),
                onPressed:
                    _identityPolicySaving ||
                        widget.onResetMonitoringIdentityPolicyService == null
                    ? null
                    : _resetMonitoringIdentityRules,
                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF9AB1CF),
                  side: const BorderSide(color: Color(0xFF35506F)),
                ),
                label: Text(
                  hasOverride ? 'Reset To Defaults' : 'Defaults Active',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...entries.take(6).toList(growable: false).asMap().entries.map((
            entry,
          ) {
            final item = entry.value;
            final policy = item.policy;
            return Container(
              width: double.infinity,
              margin: EdgeInsets.only(
                bottom: entry.key == math.min(entries.length, 6) - 1 ? 0 : 8,
              ),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0F15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x332B425F)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.siteId,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFEAF4FF),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.clientId,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF9AB1CF),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton.icon(
                        key: ValueKey(
                          'identity-rules-copy-site-${item.siteId}',
                        ),
                        onPressed: _identityPolicySaving
                            ? null
                            : () => _copyMonitoringIdentitySiteRulesJson(item),
                        icon: const Icon(Icons.copy_all_rounded, size: 14),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF67E8F9),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        label: Text(
                          'Copy Site JSON',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                      TextButton.icon(
                        key: ValueKey(
                          'identity-rules-import-site-${item.siteId}',
                        ),
                        onPressed: _identityPolicySaving
                            ? null
                            : () =>
                                  _importMonitoringIdentitySiteRulesJson(item),
                        icon: const Icon(Icons.upload_file_rounded, size: 14),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF93C5FD),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        label: Text(
                          'Import Site JSON',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                      TextButton.icon(
                        key: ValueKey(
                          'identity-rules-clear-site-${item.siteId}',
                        ),
                        onPressed: _identityPolicySaving
                            ? null
                            : () => _clearMonitoringIdentitySiteRules(item),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 14,
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFFCA5A5),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        label: Text(
                          'Clear Site Rules',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _identityRuleChip(
                        'Flagged faces ${policy.flaggedFaceMatchIds.length}',
                        const Color(0xFFFF7A7A),
                      ),
                      _identityRuleChip(
                        'Flagged plates ${policy.flaggedPlateNumbers.length}',
                        const Color(0xFFFFB36B),
                      ),
                      _identityRuleChip(
                        'Allowed faces ${policy.allowedFaceMatchIds.length}',
                        const Color(0xFF58D68D),
                      ),
                      _identityRuleChip(
                        'Allowed plates ${policy.allowedPlateNumbers.length}',
                        const Color(0xFF4FD1C5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _identityRuleLine(
                    clientId: item.clientId,
                    siteId: item.siteId,
                    policy: policy,
                    bucket: _IdentityRuleBucket.flaggedFaces,
                  ),
                  _identityRuleLine(
                    clientId: item.clientId,
                    siteId: item.siteId,
                    policy: policy,
                    bucket: _IdentityRuleBucket.flaggedPlates,
                  ),
                  _identityRuleLine(
                    clientId: item.clientId,
                    siteId: item.siteId,
                    policy: policy,
                    bucket: _IdentityRuleBucket.allowedFaces,
                  ),
                  _identityRuleLine(
                    clientId: item.clientId,
                    siteId: item.siteId,
                    policy: policy,
                    bucket: _IdentityRuleBucket.allowedPlates,
                  ),
                ],
              ),
            );
          }),
          if (_identityPolicyAuditHistory.isNotEmpty) ...[
            const SizedBox(height: 10),
            Builder(
              builder: (context) {
                final filteredHistory = _activeIdentityPolicyAuditSource == null
                    ? _identityPolicyAuditHistory
                    : _identityPolicyAuditHistory
                          .where(
                            (record) =>
                                record.source ==
                                _activeIdentityPolicyAuditSource,
                          )
                          .toList(growable: false);
                final availableSources = _identityPolicyAuditHistory
                    .map((record) => record.source)
                    .toSet()
                    .toList(growable: false);
                availableSources.sort((a, b) => a.label.compareTo(b.label));
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0F15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x332B425F)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Recent Rule Changes',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFEAF4FF),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x149AB1CF),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0x339AB1CF),
                              ),
                            ),
                            child: Text(
                              '${filteredHistory.length} recent',
                              style: GoogleFonts.inter(
                                color: const Color(0xFFBFD7F2),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            key: const ValueKey('identity-audit-toggle'),
                            onPressed: () => _setIdentityPolicyAuditExpanded(
                              !_identityPolicyAuditExpanded,
                            ),
                            icon: Icon(
                              _identityPolicyAuditExpanded
                                  ? Icons.unfold_less_rounded
                                  : Icons.unfold_more_rounded,
                              size: 16,
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFBFD7F2),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              textStyle: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            label: Text(
                              _identityPolicyAuditExpanded
                                  ? 'Collapse'
                                  : 'Expand',
                            ),
                          ),
                        ],
                      ),
                      if (_identityPolicyAuditExpanded) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            FilterChip(
                              key: const ValueKey('identity-audit-filter-all'),
                              label: const Text('All'),
                              selected:
                                  _activeIdentityPolicyAuditSource == null,
                              onSelected: (_) =>
                                  _setActiveIdentityPolicyAuditSource(null),
                              selectedColor: const Color(0x339AB1CF),
                              checkmarkColor: const Color(0xFFBFD7F2),
                              labelStyle: GoogleFonts.inter(
                                color: const Color(0xFFBFD7F2),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                              side: const BorderSide(color: Color(0x339AB1CF)),
                            ),
                            ...availableSources.map((source) {
                              return FilterChip(
                                key: ValueKey(
                                  'identity-audit-filter-${source.persistenceKey}',
                                ),
                                label: Text(source.label),
                                selected:
                                    _activeIdentityPolicyAuditSource == source,
                                onSelected: (_) =>
                                    _setActiveIdentityPolicyAuditSource(source),
                                selectedColor: const Color(0x339AB1CF),
                                checkmarkColor: const Color(0xFFBFD7F2),
                                labelStyle: GoogleFonts.inter(
                                  color: const Color(0xFFBFD7F2),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                                side: const BorderSide(
                                  color: Color(0x339AB1CF),
                                ),
                              );
                            }),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...filteredHistory.asMap().entries.map((entry) {
                          final record = entry.value;
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: entry.key == filteredHistory.length - 1
                                  ? 0
                                  : 6,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0x149AB1CF),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(
                                          color: const Color(0x339AB1CF),
                                        ),
                                      ),
                                      child: Text(
                                        record.source.label,
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFFBFD7F2),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      record.recordedAtLabel,
                                      style: GoogleFonts.robotoMono(
                                        color: const Color(0xFF8EA4C2),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  record.message,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFFBFD7F2),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _telegramIdentityIntakePanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1117),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0x332B425F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Telegram Visitor Proposals',
                style: GoogleFonts.inter(
                  color: const Color(0xFFEAF4FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x149AB1CF),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0x339AB1CF)),
                ),
                child: Text(
                  '${_telegramIdentityIntakes.length} pending',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFBFD7F2),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              if (widget.supabaseReady)
                TextButton.icon(
                  key: const ValueKey('telegram-identity-intake-refresh'),
                  onPressed: _telegramIdentityIntakesLoading
                      ? null
                      : _loadTelegramIdentityIntakesFromSupabase,
                  icon: _telegramIdentityIntakesLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 14),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF93C5FD),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                  label: Text(
                    'Refresh',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Client Telegram messages parsed into visitor proposals that control can review into the site allowlist.',
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          if (_telegramIdentityIntakes.isEmpty)
            Text(
              widget.supabaseReady
                  ? 'No pending Telegram visitor proposals.'
                  : 'Supabase offline. Pending Telegram visitor proposals are unavailable in this session.',
              style: GoogleFonts.inter(
                color: const Color(0xFFD9E7FA),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            ..._telegramIdentityIntakes.map((intake) {
              final busy = _telegramIdentityIntakeBusyIds.contains(
                intake.intakeId.trim(),
              );
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0F15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x332B425F)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _telegramIntakeDisplayName(intake),
                            style: GoogleFonts.inter(
                              color: const Color(0xFFEAF4FF),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${intake.createdAtUtc.toUtc().toIso8601String().replaceFirst('T', ' ').substring(0, 16)} UTC',
                          style: GoogleFonts.robotoMono(
                            color: const Color(0xFF8EA4C2),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${intake.siteId} • ${intake.clientId}',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF9AB1CF),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _identityRuleChip(
                          intake.category.code.toUpperCase(),
                          const Color(0xFF67E8F9),
                        ),
                        if (intake.parsedFaceMatchId.trim().isNotEmpty)
                          _identityRuleChip(
                            'Face ${intake.parsedFaceMatchId.trim()}',
                            const Color(0xFF58D68D),
                          ),
                        if (intake.parsedPlateNumber.trim().isNotEmpty)
                          _identityRuleChip(
                            'Plate ${intake.parsedPlateNumber.trim()}',
                            const Color(0xFFFBBF24),
                          ),
                        _identityRuleChip(
                          '${(intake.aiConfidence * 100).toStringAsFixed(0)}% parse',
                          const Color(0xFFBFD7F2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      intake.rawText,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFBFD7F2),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_telegramIntakeSummary(intake).isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        _telegramIntakeSummary(intake),
                        style: GoogleFonts.inter(
                          color: const Color(0xFF8EA4C2),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          key: ValueKey(
                            'telegram-identity-allow-once-${intake.intakeId}',
                          ),
                          onPressed: busy
                              ? null
                              : () =>
                                    _approveTelegramIdentityIntakeOnce(intake),
                          icon: busy
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.schedule_rounded, size: 16),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2B5E93),
                            foregroundColor: const Color(0xFFEAF4FF),
                          ),
                          label: Text(
                            'Allow Once',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        FilledButton.icon(
                          key: ValueKey(
                            'telegram-identity-allow-${intake.intakeId}',
                          ),
                          onPressed: busy
                              ? null
                              : () => _approveTelegramIdentityIntakeAlways(
                                  intake,
                                ),
                          icon: busy
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.verified_user_rounded,
                                  size: 16,
                                ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: const Color(0xFFEAF4FF),
                          ),
                          label: Text(
                            'Always Allow',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          key: ValueKey(
                            'telegram-identity-reject-${intake.intakeId}',
                          ),
                          onPressed: busy
                              ? null
                              : () => _rejectTelegramIdentityIntake(intake),
                          icon: const Icon(Icons.close_rounded, size: 16),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFCA5A5),
                            side: const BorderSide(color: Color(0xFF7F1D1D)),
                          ),
                          label: Text(
                            'Reject',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _identityRuleChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _identityRuleLine({
    required String clientId,
    required String siteId,
    required MonitoringIdentityScopePolicy policy,
    required _IdentityRuleBucket bucket,
  }) {
    final values = _identityRuleValues(policy, bucket).toList(growable: false)
      ..sort();
    final label = _identityRuleLabel(bucket);
    final color = _identityRuleBucketColor(bucket);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8EA4C2),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                key: ValueKey('identity-rule-add-${bucket.name}-$siteId'),
                onPressed: () => _promptAddIdentityRuleValue(
                  clientId: clientId,
                  siteId: siteId,
                  policy: policy,
                  bucket: bucket,
                ),
                style: TextButton.styleFrom(
                  foregroundColor: color,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (values.isEmpty)
            Text(
              'None configured',
              style: GoogleFonts.inter(
                color: const Color(0xFFD9E7FA),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: values
                  .map(
                    (value) => InputChip(
                      key: ValueKey(
                        'identity-rule-chip-${bucket.name}-$siteId-$value',
                      ),
                      label: Text(value),
                      deleteIconColor: color,
                      deleteButtonTooltipMessage: 'Remove $value',
                      onDeleted: () => _removeIdentityRuleValue(
                        clientId: clientId,
                        siteId: siteId,
                        policy: policy,
                        bucket: bucket,
                        value: value,
                      ),
                      backgroundColor: color.withValues(alpha: 0.12),
                      side: BorderSide(color: color.withValues(alpha: 0.35)),
                      labelStyle: GoogleFonts.inter(
                        color: const Color(0xFFD9E7FA),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }

  String _suppressedReviewedAtLabel(DateTime reviewedAtUtc) {
    final value = reviewedAtUtc.toUtc();
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute UTC';
  }

  Widget _fleetScopeHealthCard(
    VideoFleetScopeHealthView scope, {
    required void Function(VideoFleetScopeHealthView scope)
    onOpenLatestWatchActionDetail,
  }) {
    final statusColor = switch (scope.statusLabel.toUpperCase()) {
      'LIVE' => const Color(0xFF10B981),
      'ACTIVE WATCH' => const Color(0xFF22D3EE),
      'WATCH READY' => const Color(0xFFF59E0B),
      _ => const Color(0xFF8EA4C2),
    };
    final primaryOpenFleetScope = scope.hasIncidentContext
        ? (widget.onOpenFleetTacticalScope ?? widget.onOpenFleetDispatchScope)
        : null;
    return VideoFleetScopeHealthCard(
      title: scope.siteName,
      endpointLabel: scope.endpointLabel,
      lastSeenLabel: scope.lastSeenLabel,
      titleStyle: GoogleFonts.inter(
        color: const Color(0xFFEAF4FF),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      endpointStyle: GoogleFonts.robotoMono(
        color: const Color(0xFF8EA4C2),
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
      lastSeenStyle: GoogleFonts.inter(
        color: const Color(0xFF9AB1CF),
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      noteStyle: GoogleFonts.inter(
        color: const Color(0xFF9AB1CF),
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
      latestStyle: GoogleFonts.inter(
        color: const Color(0xFFEAF4FF),
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      primaryChips: [
        if ((scope.operatorOutcomeLabel ?? '').trim().isNotEmpty)
          _fleetBadge(
            'Cue',
            scope.operatorOutcomeLabel!,
            const Color(0xFF67E8F9),
          ),
        if ((scope.operatorOutcomeLabel ?? '').trim().isEmpty &&
            (scope.lastRecoveryLabel ?? '').trim().isNotEmpty)
          _fleetBadge(
            'Recovery',
            scope.lastRecoveryLabel!,
            const Color(0xFF86EFAC),
          ),
        if (scope.hasWatchActivationGap)
          _fleetBadge(
            'Gap',
            scope.watchActivationGapLabel!,
            const Color(0xFFF87171),
          ),
        if (!scope.hasIncidentContext)
          _fleetBadge('Context', 'Pending', const Color(0xFFFBBF24)),
        if (scope.identityPolicyChipValue != null)
          _fleetBadge(
            'Identity',
            scope.identityPolicyChipValue!,
            identityPolicyAccentColorForScope(scope),
          ),
        if (scope.clientDecisionChipValue != null)
          _fleetBadge(
            'Client',
            scope.clientDecisionChipValue!,
            scope.clientDecisionChipValue == 'Approved'
                ? const Color(0xFF86EFAC)
                : scope.clientDecisionChipValue == 'Review'
                ? const Color(0xFFFDE68A)
                : const Color(0xFFFCA5A5),
          ),
        _fleetBadge('Status', scope.statusLabel, statusColor),
        _fleetBadge('Watch', scope.watchLabel, const Color(0xFF67E8F9)),
        _fleetBadge(
          'Freshness',
          scope.freshnessLabel,
          _fleetFreshnessColor(scope),
        ),
        _fleetBadge('6h', '${scope.recentEvents}', const Color(0xFF9AB1CF)),
      ],
      secondaryChips: [
        if (scope.watchWindowLabel != null)
          _fleetBadge(
            'Window',
            scope.watchWindowLabel!,
            const Color(0xFF86EFAC),
          ),
        if (scope.watchWindowStateLabel != null)
          _fleetBadge(
            'Phase',
            scope.watchWindowStateLabel!,
            scope.watchWindowStateLabel == 'IN WINDOW'
                ? const Color(0xFF86EFAC)
                : const Color(0xFFFBBF24),
          ),
        if (scope.latestRiskScore != null)
          _fleetBadge(
            'Risk',
            _fleetRiskLabel(scope.latestRiskScore!),
            _fleetRiskColor(scope.latestRiskScore!),
          ),
        if (scope.latestCameraLabel != null)
          _fleetBadge(
            'Camera',
            scope.latestCameraLabel!,
            const Color(0xFF9AB1CF),
          ),
      ],
      actionChildren: [
        if (widget.onRecoverFleetWatchScope != null &&
            scope.hasWatchActivationGap)
          _fleetActionButton(
            label: 'Resync',
            color: const Color(0xFFF87171),
            onPressed: () => widget.onRecoverFleetWatchScope!.call(
              scope.clientId,
              scope.siteId,
            ),
          ),
        if (widget.onOpenFleetTacticalScope != null && scope.hasIncidentContext)
          _fleetActionButton(
            label: 'Tactical',
            color: const Color(0xFF67E8F9),
            onPressed: () => widget.onOpenFleetTacticalScope!.call(
              scope.clientId,
              scope.siteId,
              scope.latestIncidentReference,
            ),
          ),
        if (widget.onOpenFleetDispatchScope != null && scope.hasIncidentContext)
          _fleetActionButton(
            label: 'Dispatch',
            color: const Color(0xFFFBBF24),
            onPressed: () => widget.onOpenFleetDispatchScope!.call(
              scope.clientId,
              scope.siteId,
              scope.latestIncidentReference,
            ),
          ),
      ],
      noteText: scope.noteText,
      latestText: prominentLatestTextForWatchAction(
        scope,
        _activeWatchActionDrilldown,
      ),
      onLatestTap: () => onOpenLatestWatchActionDetail(scope),
      onTap: primaryOpenFleetScope == null
          ? null
          : () => primaryOpenFleetScope.call(
              scope.clientId,
              scope.siteId,
              scope.latestIncidentReference,
            ),
      decoration: BoxDecoration(
        color: const Color(0xFF101722),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x333A546E)),
      ),
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
    );
  }

  List<Widget> _fleetSummaryChips({
    required VideoFleetScopeHealthSections sections,
    required void Function(VideoFleetWatchActionDrilldown drilldown)
    onOpenWatchActionDrilldown,
  }) {
    return [
      _fleetBadge('Active', '${sections.activeCount}', const Color(0xFF67E8F9)),
      _fleetBadge('Gap', '${sections.gapCount}', const Color(0xFFF87171)),
      _fleetBadge(
        'High Risk',
        '${sections.highRiskCount}',
        const Color(0xFFF87171),
      ),
      _fleetBadge(
        'Recovered 6h',
        '${sections.recoveredCount}',
        const Color(0xFF86EFAC),
      ),
      _fleetBadge(
        'Suppressed',
        '${sections.suppressedCount}',
        const Color(0xFF9AB1CF),
      ),
      _fleetBadge(
        'Alerts',
        '${sections.alertActionCount}',
        const Color(0xFF67E8F9),
        isActive:
            _activeWatchActionDrilldown ==
            VideoFleetWatchActionDrilldown.alerts,
        onTap: sections.alertActionCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.alerts,
              )
            : null,
      ),
      _fleetBadge(
        'Repeat',
        '${sections.repeatActionCount}',
        const Color(0xFFFDE68A),
        isActive:
            _activeWatchActionDrilldown ==
            VideoFleetWatchActionDrilldown.repeat,
        onTap: sections.repeatActionCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.repeat,
              )
            : null,
      ),
      _fleetBadge(
        'Escalated',
        '${sections.escalationActionCount}',
        const Color(0xFFF87171),
        isActive:
            _activeWatchActionDrilldown ==
            VideoFleetWatchActionDrilldown.escalated,
        onTap: sections.escalationActionCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.escalated,
              )
            : null,
      ),
      _fleetBadge(
        'Filtered',
        '${sections.suppressedActionCount}',
        const Color(0xFF9AB1CF),
        isActive:
            _activeWatchActionDrilldown ==
            VideoFleetWatchActionDrilldown.filtered,
        onTap: sections.suppressedActionCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.filtered,
              )
            : null,
      ),
      _fleetBadge(
        'Flagged ID',
        '${sections.flaggedIdentityCount}',
        VideoFleetWatchActionDrilldown.flaggedIdentity.accentColor,
        isActive:
            _activeWatchActionDrilldown ==
            VideoFleetWatchActionDrilldown.flaggedIdentity,
        onTap: sections.flaggedIdentityCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.flaggedIdentity,
              )
            : null,
      ),
      _fleetBadge(
        'Temporary ID',
        '${sections.temporaryIdentityCount}',
        temporaryIdentityAccentColorForScopes(widget.fleetScopeHealth),
        isActive:
            _activeWatchActionDrilldown ==
            VideoFleetWatchActionDrilldown.temporaryIdentity,
        onTap: sections.temporaryIdentityCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.temporaryIdentity,
              )
            : null,
      ),
      _fleetBadge(
        'Allowed ID',
        '${sections.allowlistedIdentityCount}',
        VideoFleetWatchActionDrilldown.allowlistedIdentity.accentColor,
        isActive:
            _activeWatchActionDrilldown ==
            VideoFleetWatchActionDrilldown.allowlistedIdentity,
        onTap: sections.allowlistedIdentityCount > 0
            ? () => onOpenWatchActionDrilldown(
                VideoFleetWatchActionDrilldown.allowlistedIdentity,
              )
            : null,
      ),
      _fleetBadge('Stale', '${sections.staleCount}', const Color(0xFFFBBF24)),
      _fleetBadge(
        'No Incident',
        '${sections.noIncidentCount}',
        const Color(0xFF9AB1CF),
      ),
    ];
  }

  Widget _fleetActionButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.45)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    );
  }

  Color _fleetRiskColor(int score) {
    if (score >= 85) {
      return const Color(0xFFF87171);
    }
    if (score >= 70) {
      return const Color(0xFFFBBF24);
    }
    if (score >= 40) {
      return const Color(0xFF67E8F9);
    }
    return const Color(0xFF9AB1CF);
  }

  String _fleetRiskLabel(int score) {
    if (score >= 85) {
      return 'Critical';
    }
    if (score >= 70) {
      return 'High';
    }
    if (score >= 40) {
      return 'Watch';
    }
    return 'Routine';
  }

  Color _fleetFreshnessColor(VideoFleetScopeHealthView scope) {
    return switch (scope.freshnessLabel) {
      'Fresh' => const Color(0xFF10B981),
      'Recent' => const Color(0xFF67E8F9),
      'Stale' => const Color(0xFFF87171),
      'Quiet' => const Color(0xFFFBBF24),
      _ => const Color(0xFF9AB1CF),
    };
  }

  Widget _fleetBadge(
    String label,
    String value,
    Color color, {
    VoidCallback? onTap,
    bool isActive = false,
  }) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isActive ? 0.28 : 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: isActive ? 0.95 : 0.5),
        ),
      ),
      child: Text(
        '$label $value',
        style: GoogleFonts.inter(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    if (onTap == null) {
      return badge;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: badge,
    );
  }

  Widget _watchActionFocusBanner(VideoFleetScopeHealthView? focusedScope) {
    final active = _activeWatchActionDrilldown;
    if (active == null) {
      return const SizedBox.shrink();
    }
    final canMutateTemporaryApproval =
        active == VideoFleetWatchActionDrilldown.temporaryIdentity &&
        focusedScope != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: active.focusBannerBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: active.focusBannerBorderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active.focusBannerTitle,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEAF4FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  focusDetailForWatchAction(widget.fleetScopeHealth, active),
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9AB1CF),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (canMutateTemporaryApproval &&
                  widget.onExtendTemporaryIdentityApproval != null)
                TextButton(
                  onPressed: () async {
                    final message = await widget
                        .onExtendTemporaryIdentityApproval!(focusedScope);
                    if (!mounted) {
                      return;
                    }
                    _snack(message);
                  },
                  child: Text(
                    'Extend 2h',
                    style: GoogleFonts.inter(
                      color: active.focusBannerActionColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (canMutateTemporaryApproval &&
                  widget.onExpireTemporaryIdentityApproval != null)
                TextButton(
                  onPressed: () async {
                    final confirmed =
                        await _confirmExpireTemporaryIdentityApproval(
                          focusedScope,
                        );
                    if (!confirmed) {
                      return;
                    }
                    final message = await widget
                        .onExpireTemporaryIdentityApproval!(focusedScope);
                    if (!mounted) {
                      return;
                    }
                    _snack(message);
                  },
                  child: Text(
                    'Expire now',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFFCA5A5),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              TextButton(
                onPressed: () => _setActiveWatchActionDrilldown(null),
                child: Text(
                  'Clear',
                  style: GoogleFonts.inter(
                    color: active.focusBannerActionColor,
                    fontSize: 11,
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

  Future<bool> _confirmExpireTemporaryIdentityApproval(
    VideoFleetScopeHealthView scope,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0C1117),
          title: Text(
            'Expire Temporary Approval?',
            style: GoogleFonts.inter(
              color: const Color(0xFFEAF4FF),
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'This immediately removes the temporary identity approval for ${scope.siteName}. Future matches will no longer be treated as approved.',
            style: GoogleFonts.inter(
              color: const Color(0xFFBFD7F2),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: const Color(0xFFEAF4FF),
              ),
              child: const Text('Expire now'),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  Widget _sysInfoMini(String label, String value) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1117),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0x332B425F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFEAF4FF),
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataCard({
    required String title,
    required List<String> lines,
    required _AdminStatus status,
    bool isDemo = false,
    List<Widget> headerBadges = const [],
    VoidCallback? onTap,
    required VoidCallback onEdit,
    String editTooltip = 'Edit',
    IconData editIcon = Icons.edit_rounded,
    Color editIconColor = const Color(0xFF60A5FA),
    required VoidCallback onDelete,
  }) {
    final body = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDemo ? const Color(0xFF3C79BB) : const Color(0xFF30363D),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEAF4FF),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isDemo) ...[
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x223C79BB),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0x663C79BB)),
                  ),
                  child: Text(
                    'DEMO',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF8FD1FF),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
              ...headerBadges,
              _statusChip(status),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onEdit,
                tooltip: editTooltip,
                icon: Icon(editIcon, size: 16, color: editIconColor),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: onDelete,
                tooltip: 'Delete',
                icon: const Icon(
                  Icons.delete_rounded,
                  size: 16,
                  color: Color(0xFFF87171),
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                line,
                style: GoogleFonts.inter(
                  color: const Color(0xFF9AB1CF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) {
      return body;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: body,
      ),
    );
  }

  Widget _statusChip(_AdminStatus status) {
    final (label, fg, bg, border) = switch (status) {
      _AdminStatus.active => (
        'ACTIVE',
        const Color(0xFF10B981),
        const Color(0x1A10B981),
        const Color(0x6610B981),
      ),
      _AdminStatus.inactive => (
        'INACTIVE',
        const Color(0xFF94A3B8),
        const Color(0x1A94A3B8),
        const Color(0x6694A3B8),
      ),
      _AdminStatus.suspended => (
        'SUSPENDED',
        const Color(0xFFEF4444),
        const Color(0x1AEF4444),
        const Color(0x66EF4444),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: const Color(0xFF161B22),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF30363D)),
    );
  }

  Widget _subTitle(String title) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 3,
          decoration: BoxDecoration(
            color: const Color(0xFF3C79BB),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            color: const Color(0xFFEAF4FF),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  String _siteName(String id) {
    for (final site in _sites) {
      if (site.id == id) return site.name;
    }
    return 'Unassigned';
  }

  String _clientName(String id) {
    for (final client in _clients) {
      if (client.id == id) return client.name;
    }
    return 'Unknown Client';
  }

  Future<void> _openCreateFlow() async {
    switch (_activeTab) {
      case _AdminTab.clients:
        final draft = await showDialog<_ClientOnboardingDraft>(
          context: context,
          builder: (dialogContext) => _ClientOnboardingDialog(
            demoMode: _demoMode,
            onOpenTacticalForIncident: widget.onOpenTacticalForIncident,
            onOpenOperationsForIncident: widget.onOpenOperationsForIncident,
          ),
        );
        if (draft == null) return;
        await _createClientRecord(draft);
        return;
      case _AdminTab.sites:
        if (_clients.isEmpty) {
          _snack('Create a client before adding a site.');
          return;
        }
        final draft = await showDialog<_SiteOnboardingDraft>(
          context: context,
          builder: (dialogContext) => _SiteOnboardingDialog(
            clients: _clients,
            demoMode: _demoMode,
            onOpenTacticalForIncident: widget.onOpenTacticalForIncident,
            onOpenOperationsForIncident: widget.onOpenOperationsForIncident,
          ),
        );
        if (draft == null) return;
        await _createSiteRecord(draft);
        return;
      case _AdminTab.guards:
        if (_clients.isEmpty) {
          _snack('Create a client before adding an employee.');
          return;
        }
        final draft = await showDialog<_EmployeeOnboardingDraft>(
          context: context,
          builder: (dialogContext) => _EmployeeOnboardingDialog(
            clients: _clients,
            sites: _sites,
            demoMode: _demoMode,
            onOpenTacticalForIncident: widget.onOpenTacticalForIncident,
            onOpenOperationsForIncident: widget.onOpenOperationsForIncident,
          ),
        );
        if (draft == null) return;
        await _createEmployeeRecord(draft);
        return;
      case _AdminTab.system:
        _snack('System items cannot be created from this action.');
        return;
    }
  }

  Future<void> _openClientMessagingBridgeFlow({String? initialClientId}) async {
    if (_clients.isEmpty) {
      _snack('Create a client before linking chat lanes.');
      return;
    }
    final draft = await showDialog<_ClientMessagingBridgeDraft>(
      context: context,
      builder: (dialogContext) => _ClientMessagingBridgeDialog(
        clients: _clients,
        sites: _sites,
        initialClientId: initialClientId,
      ),
    );
    if (draft == null) return;
    await _createClientMessagingBridgeRecord(draft);
  }

  Future<void> _createClientMessagingBridgeRecord(
    _ClientMessagingBridgeDraft draft,
  ) async {
    if (!widget.supabaseReady) {
      _snack('Supabase required to save messaging bridge records.');
      return;
    }
    setState(() => _directorySaving = true);
    try {
      final supabase = Supabase.instance.client;
      final repository = SupabaseClientMessagingBridgeRepository(supabase);
      final normalizedClientId = draft.clientId.trim();
      final threadId = int.tryParse(draft.telegramThreadId.trim());
      final priorities = _incidentPrioritiesForPolicy(
        draft.incidentRoutingPolicy,
      );
      final targetSiteIds = <String?>[];
      if (draft.applyToAllClientSites) {
        final uniqueSiteIds = _sites
            .where((site) => site.clientId == normalizedClientId)
            .map((site) => site.id.trim())
            .where((siteId) => siteId.isNotEmpty)
            .toSet()
            .toList(growable: false);
        uniqueSiteIds.sort();
        if (uniqueSiteIds.isEmpty) {
          targetSiteIds.add(null);
        } else {
          targetSiteIds.addAll(uniqueSiteIds);
        }
      } else {
        final requestedSiteId = draft.siteId?.trim() ?? '';
        targetSiteIds.add(requestedSiteId.isEmpty ? null : requestedSiteId);
      }

      for (final siteId in targetSiteIds) {
        await repository.upsertOnboardingSetup(
          ClientMessagingOnboardingSetup(
            clientId: normalizedClientId,
            siteId: siteId,
            contactName: draft.contactName,
            contactRole: draft.contactRole,
            contactPhone: draft.contactPhone,
            contactEmail: draft.contactEmail,
            contactConsentConfirmed: draft.contactConsentConfirmed,
            provider: draft.provider,
            endpointLabel: draft.endpointLabel,
            telegramChatId: draft.telegramChatId,
            telegramThreadId: draft.telegramThreadId,
            incidentPriorities: priorities,
            incidentTypes: const <String>[],
          ),
        );
      }
      final checkOutcomes = <String>[];
      if (draft.provider.trim().toLowerCase() == 'telegram' &&
          draft.telegramChatId.trim().isNotEmpty) {
        final runChatcheck = widget.onRunSiteTelegramChatcheck;
        if (runChatcheck != null) {
          for (final siteId in targetSiteIds) {
            final check = await runChatcheck(
              clientId: normalizedClientId,
              siteId: siteId,
              chatId: draft.telegramChatId.trim(),
              threadId: threadId,
              endpointLabel: draft.endpointLabel.trim().isEmpty
                  ? 'Primary Telegram Bridge'
                  : draft.endpointLabel.trim(),
            );
            final scopeLabel = (siteId ?? '').trim().isEmpty
                ? 'client-default'
                : siteId!;
            checkOutcomes.add('$scopeLabel=$check');
            _recordChatcheckResult(
              clientId: normalizedClientId,
              siteId: siteId,
              result: check,
            );
          }
        } else {
          checkOutcomes.add('chatcheck=SKIP(runtime hook missing)');
          for (final siteId in targetSiteIds) {
            _recordChatcheckResult(
              clientId: normalizedClientId,
              siteId: siteId,
              result: 'SKIP (runtime hook missing)',
            );
          }
        }
      } else if (draft.provider.trim().toLowerCase() == 'telegram') {
        checkOutcomes.add('chatcheck=SKIP(chat id missing)');
        for (final siteId in targetSiteIds) {
          _recordChatcheckResult(
            clientId: normalizedClientId,
            siteId: siteId,
            result: 'SKIP (chat ID missing)',
          );
        }
      }
      await _loadDirectoryFromSupabase();
      final scopeLabel = draft.applyToAllClientSites
          ? (targetSiteIds.length == 1 && targetSiteIds.first == null
                ? 'client-wide (no sites yet)'
                : 'all ${targetSiteIds.length} site(s)')
          : ((draft.siteId ?? '').trim().isEmpty
                ? 'client-wide'
                : draft.siteId!.trim());
      _snack(
        'Chat lane saved for ${draft.clientId} (${draft.provider}) • $scopeLabel'
        '${checkOutcomes.isEmpty ? '.' : ' • ${checkOutcomes.join(' | ')}'}',
      );
    } catch (error) {
      _snack('Failed to save chat lane.');
      setState(() {
        _directorySyncMessage = 'Messaging bridge save failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _directorySaving = false);
      }
    }
  }

  Future<void> _buildDemoStackAndLaunchOperations() async {
    return _runDemoScript(autoOpenOperations: true);
  }

  Future<void> _runDemoScript({bool autoOpenOperations = false}) async {
    if (_demoScriptRunning || _directorySaving) return;
    final suffix = (DateTime.now().millisecondsSinceEpoch % 100000).toString();
    final profile = _demoStackProfile;
    final profileLabel = _demoStackProfileLabel(profile);
    final profileCode = switch (profile) {
      'estate' => 'E',
      'retail' => 'R',
      _ => 'I',
    };
    final clientId = 'DEMO-CLT-$profileCode-$suffix';
    final siteId = 'DEMO-SITE-$profileCode-$suffix';
    final employeeCode = 'DEMO-EMP-$profileCode-$suffix';

    String clientLegalName = 'Atlas Industrial Campus (Pty) Ltd';
    String clientType = 'armed_response';
    String billingAddress = '7 Foundry Road, Wadeville, Germiston, 1422';
    String vatNumber = '4080112234';
    String sovereignContact = 'Mandla Dube';
    String contactName = 'Mandla Dube';
    String contactEmail = 'operations@atlascampus.co.za';
    String contactPhone = '+27 82 900 4431';
    String slaTier = 'platinum';

    String siteName = 'North Gate Tactical Perimeter';
    String siteCodePrefix = 'NGATE';
    String siteAddress = '11 Granite Drive, North Riding, Johannesburg, 2162';
    double siteLat = -26.0601;
    double siteLng = 27.9717;
    int geofenceRadiusMeters = 450;
    String entryProtocol =
        'Gate intercom to control room. Pin + radio call after 22:00.';
    String siteMapUrl =
        'https://cdn.onyx.local/site-layouts/demo-north-gate.pdf';
    String riskProfile = 'industrial';
    int nudgeMinutes = 10;
    int escalationMinutes = 1;

    String employeeRole = 'reaction_officer';
    String employeeFullName = 'Kagiso';
    String employeeSurname = 'Molefe';
    String employeeIdNumber = '8808085501081';
    DateTime employeeDob = DateTime(1988, 8, 8);
    String psiraGrade = 'B';
    int psiraExpiryDays = 540;
    bool hasDriverLicense = true;
    String driverLicenseCode = 'Code 10';
    bool hasPdp = true;
    String deviceUidPrefix = 'BV5300P-DEMO-I';
    String employeePhone = '+27 82 711 2233';
    String employeeEmail = 'kagiso.demo@onyx-security.co.za';

    switch (profile) {
      case 'estate':
        clientLegalName = 'Sovereign Ridge Estate HOA';
        clientType = 'hybrid';
        billingAddress = '21 Sovereign Lane, Sandton, Johannesburg, 2196';
        vatNumber = '4499912345';
        sovereignContact = 'Alicia van der Merwe';
        contactName = 'Alicia van der Merwe';
        contactEmail = 'alicia@sovereignridge.co.za';
        contactPhone = '+27 82 700 1122';
        slaTier = 'gold';

        siteName = 'Blue Ridge Estate Perimeter';
        siteCodePrefix = 'ESTATE';
        siteAddress = '4 Willow Crescent, Fourways, Johannesburg, 2191';
        siteLat = -26.0214;
        siteLng = 28.0064;
        geofenceRadiusMeters = 300;
        entryProtocol =
            'Main gate intercom to estate control. Visitor lane after ID verification.';
        siteMapUrl =
            'https://cdn.onyx.local/site-layouts/demo-estate-perimeter.pdf';
        riskProfile = 'residential';
        nudgeMinutes = 15;
        escalationMinutes = 2;

        employeeRole = 'guard';
        employeeFullName = 'Lerato';
        employeeSurname = 'Nkosi';
        employeeIdNumber = '9205150890084';
        employeeDob = DateTime(1992, 5, 15);
        psiraGrade = 'C';
        psiraExpiryDays = 460;
        hasDriverLicense = false;
        driverLicenseCode = '';
        hasPdp = false;
        deviceUidPrefix = 'BV5300P-GRD-E';
        employeePhone = '+27 84 611 3301';
        employeeEmail = 'lerato.guard@onyx-security.co.za';
        break;
      case 'retail':
        clientLegalName = 'Harbor Point Retail Centre';
        clientType = 'hybrid';
        billingAddress = '55 Marine Drive, Umhlanga, KwaZulu-Natal, 4319';
        vatNumber = '4527700987';
        sovereignContact = 'Naomi Peters';
        contactName = 'Centre Management Desk';
        contactEmail = 'ops@harborpointmall.co.za';
        contactPhone = '+27 83 455 8891';
        slaTier = 'gold';

        siteName = 'Harbor Point Retail Complex';
        siteCodePrefix = 'MALL';
        siteAddress = '55 Marine Drive, Umhlanga, KwaZulu-Natal, 4319';
        siteLat = -29.7265;
        siteLng = 31.0849;
        geofenceRadiusMeters = 380;
        entryProtocol =
            'Service gate code via supervisor. Parking deck patrol route every 20 minutes.';
        siteMapUrl =
            'https://cdn.onyx.local/site-layouts/demo-retail-complex.pdf';
        riskProfile = 'commercial';
        nudgeMinutes = 12;
        escalationMinutes = 2;

        employeeRole = 'reaction_officer';
        employeeFullName = 'Anele';
        employeeSurname = 'Jacobs';
        employeeIdNumber = '9003031234080';
        employeeDob = DateTime(1990, 3, 3);
        psiraGrade = 'B';
        psiraExpiryDays = 520;
        hasDriverLicense = true;
        driverLicenseCode = 'Code 10';
        hasPdp = true;
        deviceUidPrefix = 'BV5300P-RSP-R';
        employeePhone = '+27 83 740 1144';
        employeeEmail = 'anele.response@onyx-security.co.za';
        break;
      case 'industrial':
      default:
        break;
    }

    final psiraNumber = 'PSI-DEMO-$profileCode-$suffix';
    final employeePsiraExpiry = DateTime.now().add(
      Duration(days: psiraExpiryDays),
    );
    final driverLicenseExpiry = hasDriverLicense
        ? DateTime.now().add(const Duration(days: 900))
        : null;
    final pdpExpiry = hasPdp
        ? DateTime.now().add(const Duration(days: 700))
        : null;
    setState(() {
      _demoScriptRunning = true;
      _demoStoryClientId = null;
      _demoStorySiteId = null;
      _demoStoryEmployeeCode = null;
      _demoStoryVehicleCallsign = null;
      _demoStoryIncidentEventUid = null;
      _demoStoryUpdatedAt = null;
    });
    try {
      final clientOk = await _createClientRecord(
        _ClientOnboardingDraft(
          clientId: clientId,
          legalName: clientLegalName,
          clientType: clientType,
          billingAddress: billingAddress,
          vatNumber: vatNumber,
          sovereignContact: sovereignContact,
          contactName: contactName,
          contactEmail: contactEmail,
          contactPhone: contactPhone,
          contractStart: DateTime.now(),
          slaTier: slaTier,
          messagingProvider: 'in_app',
          messagingEndpointLabel: 'Primary Client In-App Lane',
          telegramChatId: '',
          telegramThreadId: '',
          incidentRoutingPolicy: 'all',
          contactConsentConfirmed: true,
        ),
        showFeedback: false,
      );
      if (!clientOk) {
        if (mounted) {
          _snack('Demo stack ($profileLabel) stopped at client stage.');
        }
        return;
      }

      final siteOk = await _createSiteRecord(
        _SiteOnboardingDraft(
          siteId: siteId,
          clientId: clientId,
          siteName: siteName,
          siteCode: '$siteCodePrefix-$suffix',
          address: siteAddress,
          latitude: siteLat,
          longitude: siteLng,
          geofenceRadiusMeters: geofenceRadiusMeters,
          entryProtocol: entryProtocol,
          siteLayoutMapUrl: siteMapUrl,
          riskProfile: riskProfile,
          guardNudgeFrequencyMinutes: nudgeMinutes,
          escalationTriggerMinutes: escalationMinutes,
          enableTelegramBridge: false,
          messagingEndpointLabel: 'Primary Site Telegram',
          telegramChatId: '',
          telegramThreadId: '',
        ),
        showFeedback: false,
      );
      if (!siteOk) {
        if (mounted) {
          _snack('Demo stack ($profileLabel) stopped at site stage.');
        }
        return;
      }

      final employeeOk = await _createEmployeeRecord(
        _EmployeeOnboardingDraft(
          clientId: clientId,
          employeeCode: employeeCode,
          role: employeeRole,
          fullName: employeeFullName,
          surname: employeeSurname,
          idNumber: employeeIdNumber,
          dateOfBirth: employeeDob,
          psiraNumber: psiraNumber,
          psiraGrade: psiraGrade,
          psiraExpiry: employeePsiraExpiry,
          hasDriverLicense: hasDriverLicense,
          driverLicenseCode: driverLicenseCode,
          driverLicenseExpiry: driverLicenseExpiry,
          hasPdp: hasPdp,
          pdpExpiry: pdpExpiry,
          deviceUid: '$deviceUidPrefix-$suffix',
          contactPhone: employeePhone,
          contactEmail: employeeEmail,
          assignedSiteId: siteId,
        ),
        showFeedback: false,
      );
      if (!employeeOk) {
        if (mounted) {
          _snack('Demo stack ($profileLabel) stopped at employee stage.');
        }
        return;
      }

      final opsSeed = await _seedDemoOperationsData(
        suffix: suffix,
        clientId: clientId,
        siteId: siteId,
        employeeCode: employeeCode,
      );
      if ((opsSeed.vehicleCallsign ?? '').isNotEmpty ||
          (opsSeed.incidentEventUid ?? '').isNotEmpty) {
        _recordDemoStoryboard(
          vehicleCallsign: opsSeed.vehicleCallsign,
          incidentEventUid: opsSeed.incidentEventUid,
        );
      }
      if (opsSeed.warnings.isNotEmpty && mounted) {
        setState(() {
          _directorySyncMessage = opsSeed.warnings.join(' | ');
        });
      }

      if (!mounted) return;
      final seededIncidentRef = opsSeed.incidentEventUid;
      final quickActions = <_SuccessDialogQuickAction>[
        if (seededIncidentRef != null &&
            seededIncidentRef.trim().isNotEmpty &&
            widget.onRunDemoAutopilotForIncident != null)
          _SuccessDialogQuickAction(
            icon: Icons.auto_mode_rounded,
            label: 'Run Autopilot',
            onTap: () =>
                widget.onRunDemoAutopilotForIncident!.call(seededIncidentRef),
            foregroundColor: const Color(0xFF93C5FD),
            borderColor: const Color(0xFF2B5E93),
          ),
        if (seededIncidentRef != null &&
            seededIncidentRef.trim().isNotEmpty &&
            widget.onRunFullDemoAutopilotForIncident != null)
          _SuccessDialogQuickAction(
            icon: Icons.route_rounded,
            label: 'Run Full Tour',
            onTap: () => widget.onRunFullDemoAutopilotForIncident!.call(
              seededIncidentRef,
            ),
            foregroundColor: const Color(0xFFBFD7F2),
            borderColor: const Color(0xFF35506F),
          ),
        if (seededIncidentRef != null &&
            seededIncidentRef.trim().isNotEmpty &&
            widget.onOpenDispatchesForIncident != null)
          _SuccessDialogQuickAction(
            icon: Icons.hub_rounded,
            label: 'Open Dispatches',
            onTap: () =>
                widget.onOpenDispatchesForIncident!.call(seededIncidentRef),
            foregroundColor: const Color(0xFF93C5FD),
            borderColor: const Color(0xFF35506F),
          )
        else if (widget.onOpenDispatches != null)
          _SuccessDialogQuickAction(
            icon: Icons.hub_rounded,
            label: 'Open Dispatches',
            onTap: widget.onOpenDispatches!,
            foregroundColor: const Color(0xFF93C5FD),
            borderColor: const Color(0xFF35506F),
          ),
        if (seededIncidentRef != null &&
            seededIncidentRef.trim().isNotEmpty &&
            widget.onOpenTacticalForIncident != null)
          _SuccessDialogQuickAction(
            icon: Icons.map_rounded,
            label: 'Open Tactical',
            onTap: () =>
                widget.onOpenTacticalForIncident!.call(seededIncidentRef),
            foregroundColor: const Color(0xFF67E8F9),
            borderColor: const Color(0xFF2B5E93),
          ),
        if (seededIncidentRef != null &&
            seededIncidentRef.trim().isNotEmpty &&
            widget.onOpenEventsForIncident != null)
          _SuccessDialogQuickAction(
            icon: Icons.timeline_rounded,
            label: 'Open Events',
            onTap: () =>
                widget.onOpenEventsForIncident!.call(seededIncidentRef),
            foregroundColor: const Color(0xFFBFD7F2),
            borderColor: const Color(0xFF35506F),
          ),
        if (seededIncidentRef != null &&
            seededIncidentRef.trim().isNotEmpty &&
            widget.onOpenLedgerForIncident != null)
          _SuccessDialogQuickAction(
            icon: Icons.receipt_long_rounded,
            label: 'Open Ledger',
            onTap: () =>
                widget.onOpenLedgerForIncident!.call(seededIncidentRef),
            foregroundColor: const Color(0xFFFDE68A),
            borderColor: const Color(0xFF5B3A16),
          ),
        if (widget.onOpenGovernance != null)
          _SuccessDialogQuickAction(
            icon: Icons.fact_check_rounded,
            label: 'Open Governance',
            onTap: widget.onOpenGovernance!,
            foregroundColor: const Color(0xFF86EFAC),
            borderColor: const Color(0xFF2F5949),
          ),
        if (widget.onOpenClientView != null)
          _SuccessDialogQuickAction(
            icon: Icons.person_outline_rounded,
            label: 'Open Client View',
            onTap: widget.onOpenClientView!,
            foregroundColor: const Color(0xFFBFD7F2),
            borderColor: const Color(0xFF35506F),
          ),
        if (widget.onOpenReports != null)
          _SuccessDialogQuickAction(
            icon: Icons.assessment_rounded,
            label: 'Open Reports',
            onTap: widget.onOpenReports!,
            foregroundColor: const Color(0xFFFFDDAA),
            borderColor: const Color(0xFF5B3A16),
          ),
      ];
      final continueLaunchesOperations =
          seededIncidentRef != null &&
          seededIncidentRef.trim().isNotEmpty &&
          widget.onOpenOperationsForIncident != null;
      if (autoOpenOperations && continueLaunchesOperations) {
        widget.onOpenOperationsForIncident!.call(seededIncidentRef);
        _snack(
          'Demo stack ($profileLabel) ready. Opening Operations: $seededIncidentRef',
        );
        return;
      }
      final dialogOutcome = await _showCreateSuccessDialog(
        title: 'Demo Stack Ready',
        subtitle:
            '$profileLabel profile seeded for client, site, employee, and operations.',
        highlights: [
          'Profile: $profileLabel',
          'Client: $clientId',
          'Site: $siteId',
          'Employee: $employeeCode',
          if ((opsSeed.vehicleCallsign ?? '').isNotEmpty)
            'Vehicle: ${opsSeed.vehicleCallsign}',
          if ((opsSeed.incidentEventUid ?? '').isNotEmpty)
            'Incident: ${opsSeed.incidentEventUid}',
          if (opsSeed.warnings.isNotEmpty)
            'Ops seed warnings captured in sync status.',
        ],
        onContinueDemo: continueLaunchesOperations
            ? () => widget.onOpenOperationsForIncident!.call(seededIncidentRef)
            : null,
        continueLabel: continueLaunchesOperations
            ? 'Continue to Operations'
            : 'Continue Demo',
        focusReference: (seededIncidentRef ?? siteId).trim(),
        quickActions: quickActions,
      );
      if (opsSeed.warnings.isEmpty) {
        _snack('Demo stack ($profileLabel) completed.');
      } else {
        _snack('Demo stack ($profileLabel) completed with ops-seed warnings.');
      }
      final launchedRouteFromDialog =
          dialogOutcome == _SuccessDialogOutcome.quickAction ||
          (dialogOutcome == _SuccessDialogOutcome.continued &&
              continueLaunchesOperations);
      if (!launchedRouteFromDialog && mounted) {
        setState(() {
          _activeTab = _AdminTab.sites;
          _query = siteId;
        });
        widget.onTabChanged?.call(AdministrationPageTab.sites);
        _searchController.text = siteId;
      }
    } finally {
      if (mounted) {
        setState(() => _demoScriptRunning = false);
      }
    }
  }

  Future<_DemoOperationsSeedResult> _seedDemoOperationsData({
    required String suffix,
    required String clientId,
    required String siteId,
    required String employeeCode,
  }) async {
    if (!widget.supabaseReady) {
      return const _DemoOperationsSeedResult(
        warnings: <String>[
          'Ops seed skipped: Supabase is not connected in this session.',
        ],
      );
    }

    final warnings = <String>[];
    final supabase = Supabase.instance.client;
    String? employeeId;
    String? vehicleCallsign;
    String? incidentEventUid;

    try {
      final employeeRowsRaw = await supabase
          .from('employees')
          .select('id')
          .eq('client_id', clientId)
          .eq('employee_code', employeeCode)
          .limit(1);
      final employeeRows = List<Map<String, dynamic>>.from(employeeRowsRaw);
      if (employeeRows.isNotEmpty) {
        final value = (employeeRows.first['id'] ?? '').toString();
        employeeId = value.isEmpty ? null : value;
      }
    } catch (error) {
      warnings.add('Unable to resolve seeded employee UUID for ops links.');
    }

    try {
      vehicleCallsign = 'DEMO-ECHO-$suffix';
      final plateSuffix = suffix.padLeft(5, '0');
      await supabase.from('vehicles').upsert({
        'client_id': clientId,
        'site_id': siteId,
        'vehicle_callsign': vehicleCallsign,
        'license_plate': 'DEMO-$plateSuffix',
        'vehicle_type': 'armed_response_vehicle',
        'maintenance_status': 'ok',
        'service_due_date': DateTime.now()
            .add(const Duration(days: 120))
            .toIso8601String(),
        'roadworthy_expiry': DateTime.now()
            .add(const Duration(days: 300))
            .toIso8601String(),
        'odometer_km': 48210,
        'fuel_percent': 76.5,
        'assigned_employee_id': employeeId,
        'metadata': {
          'demo_seed': true,
          'seed_source': 'admin_demo_script',
          'unit_label': 'Delta-1',
        },
        'is_active': true,
      }, onConflict: 'client_id,vehicle_callsign');
    } catch (error) {
      vehicleCallsign = null;
      warnings.add('Vehicle demo seed failed.');
    }

    try {
      final signal = DateTime.now().toUtc();
      incidentEventUid = 'DEMO-EVT-$suffix';
      await supabase.from('incidents').upsert({
        'event_uid': incidentEventUid,
        'client_id': clientId,
        'site_id': siteId,
        'incident_type': 'breach',
        'priority': 'p2',
        'status': 'dispatched',
        'signal_received_at': signal.toIso8601String(),
        'triage_time': signal
            .add(const Duration(seconds: 22))
            .toIso8601String(),
        'dispatch_time': signal
            .add(const Duration(minutes: 1))
            .toIso8601String(),
        'controller_notes':
            'Demo breach detected at North Gate perimeter. Delta-1 pre-alert issued.',
        'field_report': 'Demo unit acknowledged dispatch. ETA under 3 minutes.',
        'media_attachments': <String>[],
        'evidence_hash': 'demo-evidence-$suffix',
        'linked_employee_id': employeeId,
        'linked_guard_ops_event_id': 'DEMO-GOPS-$suffix',
        'metadata': {
          'demo_seed': true,
          'seed_source': 'admin_demo_script',
          'incident_cluster': 'demo-cluster-a',
        },
      }, onConflict: 'event_uid');
    } catch (error) {
      incidentEventUid = null;
      warnings.add('Incident demo seed failed.');
    }

    return _DemoOperationsSeedResult(
      vehicleCallsign: vehicleCallsign,
      incidentEventUid: incidentEventUid,
      warnings: warnings,
    );
  }

  bool _isDemoIdentifier(String value) {
    return value.trim().toUpperCase().startsWith('DEMO-');
  }

  Future<void> _clearDemoData() async {
    if (_directorySaving || _demoScriptRunning || _demoCleanupRunning) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF5B242C)),
          ),
          title: Text(
            'Reset Demo Data?',
            style: GoogleFonts.inter(
              color: const Color(0xFFEAF4FF),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'This removes all records where IDs start with DEMO- (clients, sites, employees, assignments, seeded vehicles, and incidents).',
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: const Color(0xFF9AB1CF),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.delete_sweep_rounded, size: 16),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB91C1C),
                foregroundColor: const Color(0xFFEAF4FF),
              ),
              label: Text(
                'Clear Demo Data',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    setState(() => _demoCleanupRunning = true);
    var clearedClients = 0;
    var clearedSites = 0;
    var clearedEmployees = 0;
    try {
      if (widget.supabaseReady) {
        final supabase = Supabase.instance.client;
        final demoClientsRaw = await supabase
            .from('clients')
            .select('client_id')
            .ilike('client_id', 'DEMO-%');
        final demoClientIds = List<Map<String, dynamic>>.from(demoClientsRaw)
            .map((row) => (row['client_id'] ?? '').toString())
            .where((id) {
              return id.isNotEmpty;
            })
            .toList(growable: false);

        final demoEmployeesRaw = await supabase
            .from('employees')
            .select('id, employee_code')
            .ilike('employee_code', 'DEMO-%');
        final demoEmployeeIds =
            List<Map<String, dynamic>>.from(demoEmployeesRaw)
                .map((row) => (row['id'] ?? '').toString())
                .where((id) {
                  return id.isNotEmpty;
                })
                .toList(growable: false);

        final demoSitesRaw = await supabase
            .from('sites')
            .select('site_id')
            .ilike('site_id', 'DEMO-%');
        final demoSiteIds = List<Map<String, dynamic>>.from(demoSitesRaw)
            .map((row) => (row['site_id'] ?? '').toString())
            .where((id) {
              return id.isNotEmpty;
            })
            .toList(growable: false);
        clearedClients = demoClientIds.length;
        clearedSites = demoSiteIds.length;
        clearedEmployees = demoEmployeeIds.length;

        Future<void> tryDeleteByFilter({
          required String table,
          required String column,
          required List<String> values,
        }) async {
          if (values.isEmpty) return;
          try {
            await supabase.from(table).delete().inFilter(column, values);
          } catch (_) {
            // Best-effort cleanup for optional legacy/expanded tables.
          }
        }

        await tryDeleteByFilter(
          table: 'employee_site_assignments',
          column: 'employee_id',
          values: demoEmployeeIds,
        );
        await tryDeleteByFilter(
          table: 'guards',
          column: 'source_employee_id',
          values: demoEmployeeIds,
        );
        await tryDeleteByFilter(
          table: 'controllers',
          column: 'source_employee_id',
          values: demoEmployeeIds,
        );
        await tryDeleteByFilter(
          table: 'staff',
          column: 'source_employee_id',
          values: demoEmployeeIds,
        );
        await tryDeleteByFilter(
          table: 'guards',
          column: 'client_id',
          values: demoClientIds,
        );
        await tryDeleteByFilter(
          table: 'controllers',
          column: 'client_id',
          values: demoClientIds,
        );
        await tryDeleteByFilter(
          table: 'staff',
          column: 'client_id',
          values: demoClientIds,
        );
        await tryDeleteByFilter(
          table: 'incidents',
          column: 'site_id',
          values: demoSiteIds,
        );
        await tryDeleteByFilter(
          table: 'vehicles',
          column: 'site_id',
          values: demoSiteIds,
        );
        await tryDeleteByFilter(
          table: 'vehicles',
          column: 'client_id',
          values: demoClientIds,
        );

        if (demoEmployeeIds.isNotEmpty) {
          await supabase
              .from('employees')
              .delete()
              .inFilter('id', demoEmployeeIds);
        }
        if (demoSiteIds.isNotEmpty) {
          await supabase
              .from('sites')
              .delete()
              .inFilter('site_id', demoSiteIds);
        }
        if (demoClientIds.isNotEmpty) {
          await supabase
              .from('clients')
              .delete()
              .inFilter('client_id', demoClientIds);
        }
        await _loadDirectoryFromSupabase();
      } else {
        final beforeClients = _clients.length;
        final beforeSites = _sites.length;
        final beforeEmployees = _guards.length;
        setState(() {
          _clients = _clients
              .where((row) => !_isDemoIdentifier(row.id))
              .toList(growable: false);
          _sites = _sites
              .where((row) => !_isDemoIdentifier(row.id))
              .toList(growable: false);
          _guards = _guards
              .where(
                (row) =>
                    !_isDemoIdentifier(row.id) &&
                    !_isDemoIdentifier(row.employeeId),
              )
              .toList(growable: false);
          _directorySyncMessage = 'Demo records cleared from local directory.';
        });
        clearedClients = beforeClients - _clients.length;
        clearedSites = beforeSites - _sites.length;
        clearedEmployees = beforeEmployees - _guards.length;
      }
      if (!mounted) return;
      setState(() {
        _query = '';
        _searchController.clear();
        _demoStoryClientId = null;
        _demoStorySiteId = null;
        _demoStoryEmployeeCode = null;
        _demoStoryVehicleCallsign = null;
        _demoStoryIncidentEventUid = null;
        _demoStoryUpdatedAt = null;
      });
      _snack(
        'Demo data cleared: $clearedClients client(s), $clearedSites site(s), $clearedEmployees employee(s).',
      );
    } catch (error) {
      if (!mounted) return;
      _snack('Failed to clear demo data.');
      setState(() {
        _directorySyncMessage = 'Demo cleanup failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _demoCleanupRunning = false);
      }
    }
  }

  Future<bool> _createClientRecord(
    _ClientOnboardingDraft draft, {
    bool showFeedback = true,
  }) async {
    setState(() => _directorySaving = true);
    var chatcheckSummary = 'Telegram lane disabled or in-app only.';
    String? chatcheckResult;
    try {
      if (widget.supabaseReady) {
        final supabase = Supabase.instance.client;
        await supabase.from('clients').upsert({
          'client_id': draft.clientId,
          'display_name': draft.legalName,
          'legal_name': draft.legalName,
          'client_type': draft.clientType,
          'billing_address': draft.billingAddress.isEmpty
              ? null
              : draft.billingAddress,
          'vat_number': draft.vatNumber.isEmpty ? null : draft.vatNumber,
          'sovereign_contact': draft.sovereignContact.isEmpty
              ? null
              : draft.sovereignContact,
          'contact_name': draft.contactName.isEmpty ? null : draft.contactName,
          'contact_email': draft.contactEmail.isEmpty
              ? null
              : draft.contactEmail,
          'contact_phone': draft.contactPhone.isEmpty
              ? null
              : draft.contactPhone,
          'contract_start': draft.contractStart?.toIso8601String(),
          'metadata': {'sla_tier': draft.slaTier, 'code': draft.clientId},
          'is_active': true,
        }, onConflict: 'client_id');
        final messagingRepository = SupabaseClientMessagingBridgeRepository(
          supabase,
        );
        await messagingRepository.upsertOnboardingSetup(
          ClientMessagingOnboardingSetup(
            clientId: draft.clientId,
            contactName: _resolvedClientContactName(draft),
            contactRole: 'sovereign_contact',
            contactPhone: draft.contactPhone,
            contactEmail: draft.contactEmail,
            contactConsentConfirmed: draft.contactConsentConfirmed,
            provider: draft.messagingProvider,
            endpointLabel: draft.messagingEndpointLabel,
            telegramChatId: draft.telegramChatId,
            telegramThreadId: draft.telegramThreadId,
            incidentPriorities: _incidentPrioritiesForPolicy(
              draft.incidentRoutingPolicy,
            ),
            incidentTypes: const <String>[],
          ),
        );
        if (draft.messagingProvider == 'telegram' &&
            draft.telegramChatId.trim().isNotEmpty) {
          final runChatcheck = widget.onRunSiteTelegramChatcheck;
          if (runChatcheck != null) {
            final threadId = int.tryParse(draft.telegramThreadId.trim());
            try {
              final check = await runChatcheck(
                clientId: draft.clientId,
                siteId: null,
                chatId: draft.telegramChatId.trim(),
                threadId: threadId,
                endpointLabel: draft.messagingEndpointLabel.trim().isEmpty
                    ? 'Primary Client Telegram'
                    : draft.messagingEndpointLabel.trim(),
              );
              chatcheckResult = check;
              chatcheckSummary = 'Telegram chatcheck: $check';
            } catch (error) {
              chatcheckResult = 'FAIL ($error)';
              chatcheckSummary = 'Telegram chatcheck: FAIL ($error)';
            }
          } else {
            chatcheckResult = 'SKIP (runtime hook missing)';
            chatcheckSummary =
                'Telegram chatcheck: SKIP (runtime hook missing)';
          }
        } else if (draft.messagingProvider == 'telegram') {
          chatcheckResult = 'SKIP (chat ID missing)';
          chatcheckSummary = 'Telegram chatcheck: SKIP (chat ID missing)';
        }
        await _loadDirectoryFromSupabase();
      } else {
        final row = _ClientAdminRow(
          id: draft.clientId,
          name: draft.legalName,
          code: draft.clientId,
          contactPerson: draft.contactName.isEmpty
              ? draft.sovereignContact
              : draft.contactName,
          contactEmail: draft.contactEmail,
          contactPhone: draft.contactPhone,
          slaTier: draft.slaTier,
          contractStart: _dateLabel(draft.contractStart),
          contractEnd: '-',
          sites: 0,
          status: _AdminStatus.active,
        );
        setState(() {
          _clients = [..._clients, row];
          _directorySyncMessage = 'Client ${draft.clientId} saved locally.';
        });
        if (draft.messagingProvider == 'telegram') {
          chatcheckResult = 'SKIP (Supabase/runtime bridge required)';
          chatcheckSummary =
              'Telegram chatcheck: SKIP (Supabase/runtime bridge required)';
        }
      }
      if (chatcheckResult != null) {
        _recordChatcheckResult(
          clientId: draft.clientId,
          siteId: null,
          result: chatcheckResult,
        );
      }
      if (_demoMode) {
        _recordDemoStoryboard(clientId: draft.clientId);
      }
      if (showFeedback && _demoMode && mounted) {
        final quickActions = _buildDirectoryCreateQuickActions(
          focusReference: draft.clientId.trim(),
          includeClientView: true,
          includeReports: true,
        );
        await _showCreateSuccessDialog(
          title: 'Client Demo Ready',
          subtitle: '${draft.legalName} has been onboarded.',
          highlights: [
            'Client ID: ${draft.clientId}',
            'Service: ${draft.clientType.replaceAll('_', ' ')}',
            'SLA Tier: ${draft.slaTier.toUpperCase()}',
            'Messaging: ${draft.messagingProvider}${draft.messagingProvider == 'telegram' && draft.telegramChatId.trim().isNotEmpty ? ' (${draft.telegramChatId.trim()})' : ''}',
            chatcheckSummary,
          ],
          focusReference: draft.clientId.trim(),
          quickActions: quickActions,
        );
      }
      if (showFeedback) {
        _snack('Client ${draft.clientId} saved.');
      }
      return true;
    } catch (error) {
      if (showFeedback) {
        _snack('Failed to save client.');
      }
      setState(() {
        _directorySyncMessage = 'Client save failed: $error';
      });
      return false;
    } finally {
      if (mounted) {
        setState(() => _directorySaving = false);
      }
    }
  }

  String _resolvedClientContactName(_ClientOnboardingDraft draft) {
    final primary = draft.contactName.trim();
    if (primary.isNotEmpty) return primary;
    final sovereign = draft.sovereignContact.trim();
    if (sovereign.isNotEmpty) return sovereign;
    return '${draft.legalName.trim()} Contact';
  }

  List<String> _incidentPrioritiesForPolicy(String policy) {
    return switch (policy.trim().toLowerCase()) {
      'p1_only' => const <String>['p1'],
      'p1_p2' => const <String>['p1', 'p2'],
      _ => const <String>['p1', 'p2', 'p3', 'p4'],
    };
  }

  Future<bool> _createSiteRecord(
    _SiteOnboardingDraft draft, {
    bool showFeedback = true,
  }) async {
    setState(() => _directorySaving = true);
    var chatcheckSummary = 'Telegram lane inherits client default.';
    String? chatcheckResult;
    try {
      if (widget.supabaseReady) {
        final supabase = Supabase.instance.client;
        await supabase.from('sites').upsert({
          'site_id': draft.siteId,
          'client_id': draft.clientId,
          'site_name': draft.siteName,
          'site_code': draft.siteCode.isEmpty ? null : draft.siteCode,
          'timezone': 'Africa/Johannesburg',
          'physical_address': draft.address,
          'latitude': draft.latitude,
          'longitude': draft.longitude,
          'geofence_radius_meters': draft.geofenceRadiusMeters.toDouble(),
          'entry_protocol': draft.entryProtocol.isEmpty
              ? null
              : draft.entryProtocol,
          'site_layout_map_url': draft.siteLayoutMapUrl.isEmpty
              ? null
              : draft.siteLayoutMapUrl,
          'risk_profile': draft.riskProfile,
          'risk_rating': _riskRatingFromProfile(draft.riskProfile),
          'guard_nudge_frequency_minutes': draft.guardNudgeFrequencyMinutes,
          'escalation_trigger_minutes': draft.escalationTriggerMinutes,
          'metadata': {
            'onboarding_source': 'admin_stepper',
            'risk_profile': draft.riskProfile,
          },
          'is_active': true,
        }, onConflict: 'site_id');
        if (draft.enableTelegramBridge &&
            draft.telegramChatId.trim().isNotEmpty) {
          final messagingRepository = SupabaseClientMessagingBridgeRepository(
            supabase,
          );
          await messagingRepository.upsertOnboardingSetup(
            ClientMessagingOnboardingSetup(
              clientId: draft.clientId,
              siteId: draft.siteId,
              contactName: '${draft.siteName} Site Desk',
              contactRole: 'site_control',
              contactConsentConfirmed: true,
              provider: 'telegram',
              endpointLabel: draft.messagingEndpointLabel,
              telegramChatId: draft.telegramChatId,
              telegramThreadId: draft.telegramThreadId,
              incidentPriorities: const <String>['p1', 'p2', 'p3', 'p4'],
              incidentTypes: const <String>[],
            ),
          );
          final runChatcheck = widget.onRunSiteTelegramChatcheck;
          if (runChatcheck != null) {
            final threadId = int.tryParse(draft.telegramThreadId.trim());
            try {
              final check = await runChatcheck(
                clientId: draft.clientId,
                siteId: draft.siteId,
                chatId: draft.telegramChatId.trim(),
                threadId: threadId,
                endpointLabel: draft.messagingEndpointLabel.trim().isEmpty
                    ? 'Primary Site Telegram'
                    : draft.messagingEndpointLabel.trim(),
              );
              chatcheckResult = check;
              chatcheckSummary = 'Telegram chatcheck: $check';
            } catch (error) {
              chatcheckResult = 'FAIL ($error)';
              chatcheckSummary = 'Telegram chatcheck: FAIL ($error)';
            }
          } else {
            chatcheckResult = 'SKIP (runtime hook missing)';
            chatcheckSummary =
                'Telegram chatcheck: SKIP (runtime hook missing)';
          }
        } else if (draft.enableTelegramBridge) {
          chatcheckResult = 'SKIP (chat ID missing)';
          chatcheckSummary = 'Telegram chatcheck: SKIP (chat ID missing)';
        }
        await _loadDirectoryFromSupabase();
      } else {
        final row = _SiteAdminRow(
          id: draft.siteId,
          name: draft.siteName,
          code: draft.siteCode.isEmpty ? draft.siteId : draft.siteCode,
          clientId: draft.clientId,
          address: draft.address,
          lat: draft.latitude ?? 0,
          lng: draft.longitude ?? 0,
          contactPerson: '-',
          contactPhone: '-',
          geofenceRadiusMeters: draft.geofenceRadiusMeters,
          status: _AdminStatus.active,
        );
        setState(() {
          _sites = [..._sites, row];
          _clients = _clients
              .map(
                (client) => client.id == draft.clientId
                    ? _ClientAdminRow(
                        id: client.id,
                        name: client.name,
                        code: client.code,
                        contactPerson: client.contactPerson,
                        contactEmail: client.contactEmail,
                        contactPhone: client.contactPhone,
                        slaTier: client.slaTier,
                        contractStart: client.contractStart,
                        contractEnd: client.contractEnd,
                        sites: client.sites + 1,
                        status: client.status,
                      )
                    : client,
              )
              .toList(growable: false);
          _directorySyncMessage = 'Site ${draft.siteId} saved locally.';
        });
        if (draft.enableTelegramBridge) {
          chatcheckResult = 'SKIP (Supabase/runtime bridge required)';
          chatcheckSummary =
              'Telegram chatcheck: SKIP (Supabase/runtime bridge required)';
        }
      }
      if (chatcheckResult != null) {
        _recordChatcheckResult(
          clientId: draft.clientId,
          siteId: draft.siteId,
          result: chatcheckResult,
        );
      }
      if (_demoMode) {
        _recordDemoStoryboard(siteId: draft.siteId);
      }
      if (showFeedback && _demoMode && mounted) {
        final quickActions = _buildDirectoryCreateQuickActions(
          focusReference: draft.siteId.trim(),
        );
        await _showCreateSuccessDialog(
          title: 'Site Demo Ready',
          subtitle: '${draft.siteName} is now deployable.',
          highlights: [
            'Site ID: ${draft.siteId}',
            'Risk Profile: ${draft.riskProfile.replaceAll('_', ' ')}',
            'Nudge/Escalation: ${draft.guardNudgeFrequencyMinutes}/${draft.escalationTriggerMinutes} min',
            'Messaging: ${draft.enableTelegramBridge ? 'telegram (${draft.telegramChatId.trim().isEmpty ? 'pending chat id' : draft.telegramChatId.trim()})' : 'inherit client lane'}',
            chatcheckSummary,
          ],
          focusReference: draft.siteId.trim(),
          quickActions: quickActions,
        );
      }
      if (showFeedback) {
        _snack('Site ${draft.siteId} saved.');
      }
      return true;
    } catch (error) {
      if (showFeedback) {
        _snack('Failed to save site.');
      }
      setState(() {
        _directorySyncMessage = 'Site save failed: $error';
      });
      return false;
    } finally {
      if (mounted) {
        setState(() => _directorySaving = false);
      }
    }
  }

  Future<bool> _createEmployeeRecord(
    _EmployeeOnboardingDraft draft, {
    bool showFeedback = true,
  }) async {
    setState(() => _directorySaving = true);
    try {
      if (widget.supabaseReady) {
        final employee = await Supabase.instance.client
            .from('employees')
            .upsert({
              'client_id': draft.clientId,
              'employee_code': draft.employeeCode,
              'full_name': draft.fullName,
              'surname': draft.surname,
              'id_number': draft.idNumber,
              'date_of_birth': draft.dateOfBirth?.toIso8601String(),
              'primary_role': draft.role,
              'psira_number': draft.psiraNumber.isEmpty
                  ? null
                  : draft.psiraNumber,
              'psira_grade': draft.psiraGrade.isEmpty ? null : draft.psiraGrade,
              'psira_expiry': draft.psiraExpiry?.toIso8601String(),
              'has_driver_license': draft.hasDriverLicense,
              'driver_license_code': draft.hasDriverLicense
                  ? draft.driverLicenseCode
                  : null,
              'driver_license_expiry': draft.driverLicenseExpiry
                  ?.toIso8601String(),
              'has_pdp': draft.hasPdp,
              'pdp_expiry': draft.pdpExpiry?.toIso8601String(),
              'device_uid': draft.deviceUid.isEmpty ? null : draft.deviceUid,
              'contact_phone': draft.contactPhone.isEmpty
                  ? null
                  : draft.contactPhone,
              'contact_email': draft.contactEmail.isEmpty
                  ? null
                  : draft.contactEmail,
              'employment_status': 'active',
              'metadata': {
                'onboarding_source': 'admin_stepper',
                'biometric_hash_captured': false,
              },
              'firearm_competency': {},
              'issued_firearm_serials': <String>[],
            }, onConflict: 'client_id,employee_code')
            .select('id')
            .single();

        if (draft.assignedSiteId.isNotEmpty) {
          await Supabase.instance.client
              .from('employee_site_assignments')
              .upsert({
                'client_id': draft.clientId,
                'employee_id': employee['id'],
                'site_id': draft.assignedSiteId,
                'is_primary': true,
                'assignment_status': 'active',
              }, onConflict: 'employee_id,site_id');
        }
        await _loadDirectoryFromSupabase();
      } else {
        final row = _GuardAdminRow(
          id: draft.employeeCode,
          name: '${draft.fullName} ${draft.surname}'.trim(),
          role: draft.role,
          employeeId: draft.employeeCode,
          phone: draft.contactPhone,
          email: draft.contactEmail,
          psiraNumber: draft.psiraNumber,
          psiraExpiry: _dateLabel(draft.psiraExpiry),
          certifications: [
            if (draft.psiraGrade.isNotEmpty) 'PSIRA ${draft.psiraGrade}',
            if (draft.hasDriverLicense)
              'Driver License ${draft.driverLicenseCode}',
            if (draft.hasPdp) 'PDP',
          ],
          assignedSite: draft.assignedSiteId,
          shiftPattern: 'Unassigned',
          emergencyContact: '-',
          status: _AdminStatus.active,
        );
        setState(() {
          _guards = [..._guards, row];
          _directorySyncMessage =
              'Employee ${draft.employeeCode} saved locally.';
        });
      }
      if (_demoMode) {
        _recordDemoStoryboard(employeeCode: draft.employeeCode);
      }
      if (showFeedback && _demoMode && mounted) {
        final focusReference = draft.assignedSiteId.trim().isEmpty
            ? draft.employeeCode.trim()
            : draft.assignedSiteId.trim();
        final quickActions = _buildDirectoryCreateQuickActions(
          focusReference: focusReference,
        );
        await _showCreateSuccessDialog(
          title: 'Employee Demo Ready',
          subtitle: '${draft.fullName} ${draft.surname} added to registry.',
          highlights: [
            'Employee Code: ${draft.employeeCode}',
            'Role: ${draft.role.replaceAll('_', ' ')}',
            'Assignment: ${draft.assignedSiteId.isEmpty ? 'Unassigned' : draft.assignedSiteId}',
          ],
          focusReference: focusReference,
          quickActions: quickActions,
        );
      }
      if (showFeedback) {
        _snack('Employee ${draft.employeeCode} saved.');
      }
      return true;
    } catch (error) {
      if (showFeedback) {
        _snack('Failed to save employee.');
      }
      setState(() {
        _directorySyncMessage = 'Employee save failed: $error';
      });
      return false;
    } finally {
      if (mounted) {
        setState(() => _directorySaving = false);
      }
    }
  }

  Future<void> _loadDirectoryFromSupabase() async {
    if (!widget.supabaseReady) return;
    setState(() {
      _directoryLoading = true;
      _directorySyncMessage = 'Syncing directory from Supabase…';
    });
    try {
      final supabase = Supabase.instance.client;
      final clientsRaw = await supabase
          .from('clients')
          .select()
          .order('display_name');
      final sitesRaw = await supabase.from('sites').select().order('site_name');
      final employeesRaw = await supabase
          .from('employees')
          .select()
          .order('full_name');
      final assignmentsRaw = await supabase
          .from('employee_site_assignments')
          .select()
          .eq('assignment_status', 'active');
      List<Map<String, dynamic>> endpointRows = const [];
      List<Map<String, dynamic>> contactRows = const [];
      try {
        final endpointsRaw = await supabase
            .from('client_messaging_endpoints')
            .select(
              'client_id, site_id, provider, is_active, display_label, telegram_chat_id, telegram_thread_id, last_delivery_status, last_error',
            );
        endpointRows = List<Map<String, dynamic>>.from(endpointsRaw);
      } catch (_) {
        endpointRows = const [];
      }
      try {
        final contactsRaw = await supabase
            .from('client_contacts')
            .select('client_id, is_active');
        contactRows = List<Map<String, dynamic>>.from(contactsRaw);
      } catch (_) {
        contactRows = const [];
      }

      final clientsRows = List<Map<String, dynamic>>.from(clientsRaw);
      final sitesRows = List<Map<String, dynamic>>.from(sitesRaw);
      final employeesRows = List<Map<String, dynamic>>.from(employeesRaw);
      final assignmentsRows = List<Map<String, dynamic>>.from(assignmentsRaw);

      final siteCounts = <String, int>{};
      for (final site in sitesRows) {
        final clientId = (site['client_id'] ?? '').toString();
        if (clientId.isEmpty) continue;
        siteCounts.update(clientId, (value) => value + 1, ifAbsent: () => 1);
      }
      final endpointCounts = <String, int>{};
      final telegramCounts = <String, int>{};
      final partnerEndpointCounts = <String, int>{};
      final lanePreviewByClient = <String, List<String>>{};
      final partnerLanePreviewByClient = <String, List<String>>{};
      final partnerLaneDetailsByClient = <String, List<String>>{};
      final chatcheckByClient = <String, String>{};
      final chatcheckBySite = <String, String>{};
      final partnerChatcheckByClient = <String, String>{};
      final partnerChatcheckBySite = <String, String>{};
      final partnerEndpointCountsBySite = <String, int>{};
      final partnerLaneDetailsBySite = <String, List<String>>{};
      for (final row in endpointRows) {
        if (row['is_active'] == false) continue;
        final clientId = (row['client_id'] ?? '').toString().trim();
        if (clientId.isEmpty) continue;
        endpointCounts.update(
          clientId,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
        final provider = (row['provider'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final label = (row['display_label'] ?? '').toString().trim();
        final isPartner = _isPartnerEndpointLabel(label);
        final chatId = (row['telegram_chat_id'] ?? '').toString().trim();
        final threadRaw = (row['telegram_thread_id'] ?? '').toString().trim();
        if (provider == 'telegram') {
          if (isPartner) {
            partnerEndpointCounts.update(
              clientId,
              (value) => value + 1,
              ifAbsent: () => 1,
            );
            final siteId = (row['site_id'] ?? '').toString().trim();
            if (siteId.isNotEmpty) {
              final scopeKey = _siteScopeKey(clientId, siteId);
              partnerEndpointCountsBySite.update(
                scopeKey,
                (value) => value + 1,
                ifAbsent: () => 1,
              );
              final detailLine =
                  '$label • chat=${chatId.isEmpty ? 'pending' : chatId}'
                  '${threadRaw.isEmpty ? '' : ' • thread=$threadRaw'}';
              final siteDetails = partnerLaneDetailsBySite.putIfAbsent(
                scopeKey,
                () => <String>[],
              );
              if (!siteDetails.contains(detailLine)) {
                siteDetails.add(detailLine);
              }
            }
            final detailLine =
                '$label • chat=${chatId.isEmpty ? 'pending' : chatId}'
                '${threadRaw.isEmpty ? '' : ' • thread=$threadRaw'}';
            final clientDetails = partnerLaneDetailsByClient.putIfAbsent(
              clientId,
              () => <String>[],
            );
            if (!clientDetails.contains(detailLine)) {
              clientDetails.add(detailLine);
            }
          } else {
            telegramCounts.update(
              clientId,
              (value) => value + 1,
              ifAbsent: () => 1,
            );
          }
          final chatcheckStatus = _chatcheckStatusFromEndpointRow(row);
          if (chatcheckStatus.isNotEmpty) {
            if (isPartner) {
              final currentClientStatus =
                  partnerChatcheckByClient[clientId] ?? '';
              partnerChatcheckByClient[clientId] = _preferredChatcheckStatus(
                currentClientStatus,
                chatcheckStatus,
              );
            } else {
              final currentClientStatus = chatcheckByClient[clientId] ?? '';
              chatcheckByClient[clientId] = _preferredChatcheckStatus(
                currentClientStatus,
                chatcheckStatus,
              );
            }
            final siteId = (row['site_id'] ?? '').toString().trim();
            if (siteId.isNotEmpty) {
              final key = _siteScopeKey(clientId, siteId);
              if (isPartner) {
                final currentSiteStatus = partnerChatcheckBySite[key] ?? '';
                partnerChatcheckBySite[key] = _preferredChatcheckStatus(
                  currentSiteStatus,
                  chatcheckStatus,
                );
              } else {
                final currentSiteStatus = chatcheckBySite[key] ?? '';
                chatcheckBySite[key] = _preferredChatcheckStatus(
                  currentSiteStatus,
                  chatcheckStatus,
                );
              }
            }
          }
        }
        if (label.isNotEmpty) {
          final preview =
              (isPartner ? partnerLanePreviewByClient : lanePreviewByClient)
                  .putIfAbsent(clientId, () => <String>[]);
          if (!preview.contains(label) && preview.length < 2) {
            preview.add(label);
          }
        }
      }
      final contactCounts = <String, int>{};
      for (final row in contactRows) {
        if (row['is_active'] == false) continue;
        final clientId = (row['client_id'] ?? '').toString().trim();
        if (clientId.isEmpty) continue;
        contactCounts.update(clientId, (value) => value + 1, ifAbsent: () => 1);
      }

      final primarySiteByEmployeeId = <String, String>{};
      for (final assignment in assignmentsRows) {
        final employeeId = (assignment['employee_id'] ?? '').toString();
        final siteId = (assignment['site_id'] ?? '').toString();
        if (employeeId.isEmpty || siteId.isEmpty) continue;
        final isPrimary = assignment['is_primary'] == true;
        if (isPrimary || !primarySiteByEmployeeId.containsKey(employeeId)) {
          primarySiteByEmployeeId[employeeId] = siteId;
        }
      }

      final nextClients = clientsRows
          .map((row) {
            final metadata =
                (row['metadata'] as Map?)?.cast<String, dynamic>() ??
                const <String, dynamic>{};
            final id = (row['client_id'] ?? '').toString();
            return _ClientAdminRow(
              id: id,
              name: (row['display_name'] ?? row['legal_name'] ?? id).toString(),
              code: (metadata['code'] ?? id).toString(),
              contactPerson:
                  (row['contact_name'] ?? row['sovereign_contact'] ?? '-')
                      .toString(),
              contactEmail: (row['contact_email'] ?? '-').toString(),
              contactPhone: (row['contact_phone'] ?? '-').toString(),
              slaTier: (metadata['sla_tier'] ?? 'standard').toString(),
              contractStart: _dateFromDynamic(row['contract_start']),
              contractEnd: (metadata['contract_end'] ?? '-').toString(),
              sites: siteCounts[id] ?? 0,
              status: (row['is_active'] == false)
                  ? _AdminStatus.inactive
                  : _AdminStatus.active,
            );
          })
          .toList(growable: false);

      final nextSites = sitesRows
          .map((row) {
            final hardwareIds =
                (row['hardware_ids'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                const <String>[];
            final firstFsk = hardwareIds.cast<String?>().firstWhere(
              (entry) => (entry ?? '').toUpperCase().contains('FSK'),
              orElse: () => null,
            );
            return _SiteAdminRow(
              id: (row['site_id'] ?? '').toString(),
              name: (row['site_name'] ?? '-').toString(),
              code: (row['site_code'] ?? row['site_id'] ?? '-').toString(),
              clientId: (row['client_id'] ?? '').toString(),
              address:
                  (row['physical_address'] ??
                          row['address_line_1'] ??
                          row['address'] ??
                          '-')
                      .toString(),
              lat: _doubleFromDynamic(row['latitude']),
              lng: _doubleFromDynamic(row['longitude']),
              contactPerson: '-',
              contactPhone: '-',
              fskNumber: firstFsk,
              geofenceRadiusMeters: _intFromDynamic(
                row['geofence_radius_meters'],
              ),
              status: (row['is_active'] == false)
                  ? _AdminStatus.inactive
                  : _AdminStatus.active,
            );
          })
          .toList(growable: false);

      final nextEmployees = employeesRows
          .map((row) {
            final metadata =
                (row['metadata'] as Map?)?.cast<String, dynamic>() ??
                const <String, dynamic>{};
            final employeeUuid = (row['id'] ?? '').toString();
            final fullName = (row['full_name'] ?? '').toString();
            final surname = (row['surname'] ?? '').toString();
            final displayName = '$fullName $surname'.trim();
            final employment = (row['employment_status'] ?? 'active')
                .toString();
            return _GuardAdminRow(
              id: (row['employee_code'] ?? '').toString(),
              name: displayName.isEmpty
                  ? (row['employee_code'] ?? '-').toString()
                  : displayName,
              role: (row['primary_role'] ?? 'guard').toString(),
              employeeId: (row['employee_code'] ?? '-').toString(),
              phone: (row['contact_phone'] ?? '-').toString(),
              email: (row['contact_email'] ?? '-').toString(),
              psiraNumber: (row['psira_number'] ?? '').toString(),
              psiraExpiry: _dateFromDynamic(row['psira_expiry']),
              certifications: _employeeCertifications(row),
              assignedSite: primarySiteByEmployeeId[employeeUuid] ?? '',
              shiftPattern: (metadata['shift_pattern'] ?? 'Unassigned')
                  .toString(),
              emergencyContact: (metadata['emergency_contact_phone'] ?? '-')
                  .toString(),
              status: switch (employment) {
                'suspended' => _AdminStatus.suspended,
                'terminated' => _AdminStatus.inactive,
                _ => _AdminStatus.active,
              },
            );
          })
          .toList(growable: false);

      if (!mounted) return;
      final partnerScope = _resolvePartnerRuntimeScope(
        clients: nextClients,
        sites: nextSites,
        preferredClientId: _partnerRuntimeClientId,
        preferredSiteId: _partnerRuntimeSiteId,
      );
      setState(() {
        _clients = nextClients;
        _sites = nextSites;
        _guards = nextEmployees;
        _partnerRuntimeClientId = partnerScope.clientId;
        _partnerRuntimeSiteId = partnerScope.siteId;
        _clientMessagingEndpointCounts = endpointCounts;
        _clientTelegramEndpointCounts = telegramCounts;
        _clientMessagingContactCounts = contactCounts;
        _clientPartnerEndpointCounts = partnerEndpointCounts;
        _clientMessagingLanePreview = {
          for (final entry in lanePreviewByClient.entries)
            entry.key: entry.value.join(' • '),
        };
        _clientPartnerLanePreview = {
          for (final entry in partnerLanePreviewByClient.entries)
            entry.key: entry.value.join(' • '),
        };
        _clientPartnerLaneDetails = {
          for (final entry in partnerLaneDetailsByClient.entries)
            entry.key: List<String>.unmodifiable(entry.value),
        };
        _clientTelegramChatcheckStatus = chatcheckByClient;
        _siteTelegramChatcheckStatus = chatcheckBySite;
        _clientPartnerChatcheckStatus = partnerChatcheckByClient;
        _sitePartnerEndpointCounts = partnerEndpointCountsBySite;
        _sitePartnerChatcheckStatus = partnerChatcheckBySite;
        _sitePartnerLaneDetails = {
          for (final entry in partnerLaneDetailsBySite.entries)
            entry.key: List<String>.unmodifiable(entry.value),
        };
        _directoryLoadedFromSupabase = true;
        _directorySyncMessage =
            'Directory synced: ${nextClients.length} clients, ${nextSites.length} sites, ${nextEmployees.length} employees.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _directoryLoadedFromSupabase = false;
        _clientMessagingEndpointCounts = const {};
        _clientTelegramEndpointCounts = const {};
        _clientMessagingContactCounts = const {};
        _clientPartnerEndpointCounts = const {};
        _clientMessagingLanePreview = const {};
        _clientPartnerLanePreview = const {};
        _clientPartnerLaneDetails = const {};
        _clientTelegramChatcheckStatus = const {};
        _siteTelegramChatcheckStatus = const {};
        _clientPartnerChatcheckStatus = const {};
        _sitePartnerEndpointCounts = const {};
        _sitePartnerChatcheckStatus = const {};
        _sitePartnerLaneDetails = const {};
        _directorySyncMessage = 'Directory sync failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _directoryLoading = false;
        });
      }
    }
  }

  List<String> _employeeCertifications(Map<String, dynamic> row) {
    final certs = <String>[];
    final psiraGrade = (row['psira_grade'] ?? '').toString();
    if (psiraGrade.isNotEmpty) {
      certs.add('PSIRA $psiraGrade');
    }
    if (row['has_driver_license'] == true) {
      final code = (row['driver_license_code'] ?? '').toString();
      certs.add(code.isEmpty ? 'Driver License' : 'Driver License $code');
    }
    if (row['has_pdp'] == true) {
      certs.add('PDP');
    }
    final competency =
        (row['firearm_competency'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    for (final entry in competency.entries) {
      if (entry.value == true) {
        certs.add('Firearm ${entry.key}');
      }
    }
    if (certs.isEmpty) {
      certs.add('General');
    }
    return certs;
  }

  int _riskRatingFromProfile(String profile) {
    return switch (profile) {
      'industrial' => 5,
      'commercial' => 4,
      'mixed_use' => 4,
      _ => 3,
    };
  }

  List<_SuccessDialogQuickAction> _buildDirectoryCreateQuickActions({
    required String focusReference,
    bool includeClientView = false,
    bool includeReports = false,
    bool includeTours = true,
    int maxActions = 4,
  }) {
    final ref = focusReference.trim();
    final actions = <_SuccessDialogQuickAction>[];

    _SuccessDialogQuickAction? runAutopilotAction() {
      if (!includeTours ||
          ref.isEmpty ||
          widget.onRunDemoAutopilotForIncident == null) {
        return null;
      }
      return _SuccessDialogQuickAction(
        icon: Icons.auto_mode_rounded,
        label: 'Run Autopilot',
        onTap: () => widget.onRunDemoAutopilotForIncident!.call(ref),
        foregroundColor: const Color(0xFF93C5FD),
        borderColor: const Color(0xFF2B5E93),
      );
    }

    _SuccessDialogQuickAction? runFullTourAction() {
      if (!includeTours ||
          ref.isEmpty ||
          widget.onRunFullDemoAutopilotForIncident == null) {
        return null;
      }
      return _SuccessDialogQuickAction(
        icon: Icons.route_rounded,
        label: 'Run Full Tour',
        onTap: () => widget.onRunFullDemoAutopilotForIncident!.call(ref),
        foregroundColor: const Color(0xFFBFD7F2),
        borderColor: const Color(0xFF35506F),
      );
    }

    _SuccessDialogQuickAction? openOperationsAction() {
      if (ref.isEmpty || widget.onOpenOperationsForIncident == null) {
        return null;
      }
      return _SuccessDialogQuickAction(
        icon: Icons.space_dashboard_rounded,
        label: 'Open Operations',
        onTap: () => widget.onOpenOperationsForIncident!.call(ref),
        foregroundColor: const Color(0xFFBFD7F2),
        borderColor: const Color(0xFF35506F),
      );
    }

    _SuccessDialogQuickAction? openTacticalAction() {
      if (ref.isEmpty || widget.onOpenTacticalForIncident == null) return null;
      return _SuccessDialogQuickAction(
        icon: Icons.map_rounded,
        label: 'Open Tactical',
        onTap: () => widget.onOpenTacticalForIncident!.call(ref),
        foregroundColor: const Color(0xFF9FE8FF),
        borderColor: const Color(0xFF2B5E93),
      );
    }

    _SuccessDialogQuickAction? openDispatchesAction() {
      if (ref.isNotEmpty && widget.onOpenDispatchesForIncident != null) {
        return _SuccessDialogQuickAction(
          icon: Icons.hub_rounded,
          label: 'Open Dispatches',
          onTap: () => widget.onOpenDispatchesForIncident!.call(ref),
          foregroundColor: const Color(0xFF93C5FD),
          borderColor: const Color(0xFF35506F),
        );
      }
      if (widget.onOpenDispatches != null) {
        return _SuccessDialogQuickAction(
          icon: Icons.hub_rounded,
          label: 'Open Dispatches',
          onTap: widget.onOpenDispatches!,
          foregroundColor: const Color(0xFF93C5FD),
          borderColor: const Color(0xFF35506F),
        );
      }
      return null;
    }

    _SuccessDialogQuickAction? openClientViewAction() {
      if (!includeClientView || widget.onOpenClientView == null) return null;
      return _SuccessDialogQuickAction(
        icon: Icons.person_outline_rounded,
        label: 'Open Client View',
        onTap: widget.onOpenClientView!,
        foregroundColor: const Color(0xFFBFD7F2),
        borderColor: const Color(0xFF35506F),
      );
    }

    _SuccessDialogQuickAction? openReportsAction() {
      if (!includeReports || widget.onOpenReports == null) return null;
      return _SuccessDialogQuickAction(
        icon: Icons.assessment_rounded,
        label: 'Open Reports',
        onTap: widget.onOpenReports!,
        foregroundColor: const Color(0xFFFFDDAA),
        borderColor: const Color(0xFF5B3A16),
      );
    }

    final isClientEntity = includeClientView || includeReports;
    if (isClientEntity) {
      final prioritizedClient = <_SuccessDialogQuickAction?>[
        runFullTourAction(),
        openClientViewAction(),
        openOperationsAction(),
        openReportsAction(),
        runAutopilotAction(),
        openTacticalAction(),
        openDispatchesAction(),
      ];
      for (final action in prioritizedClient) {
        if (action != null) actions.add(action);
      }
    } else {
      final prioritizedOps = <_SuccessDialogQuickAction?>[
        runAutopilotAction(),
        runFullTourAction(),
        openOperationsAction(),
        openTacticalAction(),
        openDispatchesAction(),
      ];
      for (final action in prioritizedOps) {
        if (action != null) actions.add(action);
      }
    }

    if (actions.length <= maxActions) return actions;
    return actions.take(maxActions).toList(growable: false);
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return '-';
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _dateFromDynamic(Object? value) {
    if (value == null) return '-';
    final parsed = DateTime.tryParse(value.toString());
    return _dateLabel(parsed);
  }

  double _doubleFromDynamic(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  int _intFromDynamic(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  void _deleteGuard(String id) {
    setState(() {
      _guards = _guards
          .where((guard) => guard.id != id)
          .toList(growable: false);
    });
    _snack('Guard $id deleted');
  }

  void _deleteSite(String id) {
    setState(() {
      _sites = _sites.where((site) => site.id != id).toList(growable: false);
    });
    _snack('Site $id deleted');
  }

  void _deleteClient(String id) {
    setState(() {
      _clients = _clients
          .where((client) => client.id != id)
          .toList(growable: false);
    });
    _snack('Client $id deleted');
  }

  Future<void> _showEditStub(String label) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF161B22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF30363D)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add $label',
                  style: GoogleFonts.rajdhani(
                    color: const Color(0xFFEAF4FF),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Form implementation ready for Supabase integration.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9AB1CF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF9AB1CF),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        _snack('$label saved');
                      },
                      icon: const Icon(Icons.save_rounded, size: 16),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2B5E93),
                        foregroundColor: const Color(0xFFEAF4FF),
                      ),
                      label: Text(
                        'Save',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<_SuccessDialogOutcome> _showCreateSuccessDialog({
    required String title,
    required String subtitle,
    required List<String> highlights,
    VoidCallback? onContinueDemo,
    String continueLabel = 'Continue Demo',
    String? focusReference,
    List<_SuccessDialogQuickAction> quickActions = const [],
  }) async {
    final resolvedFocusReference = (focusReference ?? '').trim();
    final hasFocusReference = resolvedFocusReference.isNotEmpty;
    final hasContinueAction = onContinueDemo != null;
    final primaryLabel = hasContinueAction ? continueLabel : 'Close';
    final primaryIcon = hasContinueAction
        ? Icons.play_arrow_rounded
        : Icons.close_rounded;
    final result = await showDialog<_SuccessDialogOutcome>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF161B22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF35506F)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0x223C79BB),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF67E8F9),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.rajdhani(
                          color: const Color(0xFFEAF4FF),
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFB7CCE6),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (hasFocusReference) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1A28),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF35506F)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.radio_button_checked_rounded,
                          size: 14,
                          color: Color(0xFF8FD1FF),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'Focus: $resolvedFocusReference',
                            style: GoogleFonts.robotoMono(
                              color: const Color(0xFFEAF4FF),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: resolvedFocusReference),
                            );
                            if (!mounted) return;
                            _snack('Focus reference copied.');
                          },
                          icon: const Icon(Icons.copy_rounded, size: 14),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFBFD7F2),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                          ),
                          label: Text(
                            'Copy',
                            style: GoogleFonts.inter(
                              fontSize: 10.8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                for (final line in highlights) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 5),
                        child: Icon(
                          Icons.fiber_manual_record_rounded,
                          size: 8,
                          color: Color(0xFF8FD1FF),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          line,
                          style: GoogleFonts.inter(
                            color: const Color(0xFFEAF4FF),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final action in quickActions)
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(
                              dialogContext,
                            ).pop(_SuccessDialogOutcome.quickAction);
                            action.onTap();
                          },
                          icon: Icon(action.icon, size: 16),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: action.foregroundColor,
                            side: BorderSide(color: action.borderColor),
                          ),
                          label: Text(
                            action.label,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      FilledButton.icon(
                        onPressed: () {
                          if (hasContinueAction) {
                            Navigator.of(
                              dialogContext,
                            ).pop(_SuccessDialogOutcome.continued);
                            onContinueDemo.call();
                            return;
                          }
                          Navigator.of(
                            dialogContext,
                          ).pop(_SuccessDialogOutcome.dismissed);
                        },
                        icon: Icon(primaryIcon, size: 16),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2B5E93),
                          foregroundColor: const Color(0xFFEAF4FF),
                        ),
                        label: Text(
                          primaryLabel,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    return result ?? _SuccessDialogOutcome.dismissed;
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F1419),
        behavior: SnackBarBehavior.floating,
        content: Text(
          message,
          style: GoogleFonts.inter(
            color: const Color(0xFFEAF4FF),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  String _resolvedInitialRadioIntentPhrasesJson() {
    final raw = widget.initialRadioIntentPhrasesJson.trim();
    if (raw.isNotEmpty) {
      return raw;
    }
    return '';
  }

  String _resolvedInitialDemoRouteCuesJson() {
    final raw = widget.initialDemoRouteCuesJson.trim();
    if (raw.isNotEmpty) {
      return raw;
    }
    return '';
  }

  Future<void> _validateRadioIntentJson() async {
    final raw = _radioIntentPhrasesController.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _radioIntentPhraseValidation =
            'Valid: empty config uses default phrases.';
        _radioIntentPhraseValidationError = false;
      });
      return;
    }
    final parsed = OnyxRadioIntentPhraseCatalog.tryParseJsonString(raw);
    if (parsed == null) {
      setState(() {
        _radioIntentPhraseValidation =
            'Invalid JSON or missing phrase arrays for all_clear/panic/duress/status.';
        _radioIntentPhraseValidationError = true;
      });
      return;
    }
    setState(() {
      _radioIntentPhraseValidation =
          'Valid: all_clear=${parsed.allClearPhrases.length}, panic=${parsed.panicPhrases.length}, duress=${parsed.duressPhrases.length}, status=${parsed.statusPhrases.length}.';
      _radioIntentPhraseValidationError = false;
    });
  }

  Future<void> _saveRadioIntentJson() async {
    await _validateRadioIntentJson();
    if (_radioIntentPhraseValidationError) {
      return;
    }
    if (widget.onSaveRadioIntentPhrasesJson == null) {
      _snack('Runtime save is not wired.');
      return;
    }
    setState(() {
      _radioIntentPhrasesSaving = true;
    });
    try {
      await widget.onSaveRadioIntentPhrasesJson!(
        _radioIntentPhrasesController.text,
      );
      if (!mounted) return;
      _snack('Radio intent dictionary saved.');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _radioIntentPhraseValidation = error.toString();
        _radioIntentPhraseValidationError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _radioIntentPhrasesSaving = false;
        });
      }
    }
  }

  Future<void> _resetRadioIntentJson() async {
    _radioIntentPhrasesController.clear();
    if (widget.onResetRadioIntentPhrasesJson != null) {
      await widget.onResetRadioIntentPhrasesJson!();
    }
    if (!mounted) return;
    setState(() {
      _radioIntentPhraseValidation = 'Default phrase dictionary restored.';
      _radioIntentPhraseValidationError = false;
    });
    _snack('Radio intent dictionary reset.');
  }

  Future<void> _validateDemoRouteCueJson() async {
    final raw = _demoRouteCuesController.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _demoRouteCueValidation = 'Valid: empty config uses default cues.';
        _demoRouteCueValidationError = false;
      });
      return;
    }
    final parsed = _parseDemoRouteCueMap(raw);
    if (parsed == null) {
      setState(() {
        _demoRouteCueValidation =
            'Invalid JSON. Expected object entries like {"dashboard":"..."} with non-empty string values.';
        _demoRouteCueValidationError = true;
      });
      return;
    }
    setState(() {
      _demoRouteCueValidation =
          'Valid: ${parsed.length} cue override${parsed.length == 1 ? '' : 's'} loaded.';
      _demoRouteCueValidationError = false;
    });
  }

  Map<String, String>? _parseDemoRouteCueMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final output = <String, String>{};
      decoded.forEach((key, value) {
        final routeKey = key.toString().trim().toLowerCase();
        final cue = value?.toString().trim() ?? '';
        if (routeKey.isEmpty || cue.isEmpty) {
          return;
        }
        output[routeKey] = cue;
      });
      return output;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveDemoRouteCueJson() async {
    await _validateDemoRouteCueJson();
    if (_demoRouteCueValidationError) {
      return;
    }
    if (widget.onSaveDemoRouteCuesJson == null) {
      _snack('Runtime save is not wired.');
      return;
    }
    setState(() {
      _demoRouteCuesSaving = true;
    });
    try {
      await widget.onSaveDemoRouteCuesJson!(_demoRouteCuesController.text);
      if (!mounted) return;
      _snack('Demo route cues saved.');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _demoRouteCueValidation = error.toString();
        _demoRouteCueValidationError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _demoRouteCuesSaving = false;
        });
      }
    }
  }

  Future<void> _resetDemoRouteCueJson() async {
    _demoRouteCuesController.clear();
    if (widget.onResetDemoRouteCuesJson != null) {
      await widget.onResetDemoRouteCuesJson!();
    }
    if (!mounted) return;
    setState(() {
      _demoRouteCueValidation = 'Default route cues restored.';
      _demoRouteCueValidationError = false;
    });
    _snack('Demo route cues reset.');
  }
}

class _ClientOnboardingDialog extends StatefulWidget {
  final bool demoMode;
  final ValueChanged<String>? onOpenTacticalForIncident;
  final ValueChanged<String>? onOpenOperationsForIncident;

  const _ClientOnboardingDialog({
    required this.demoMode,
    this.onOpenTacticalForIncident,
    this.onOpenOperationsForIncident,
  });

  @override
  State<_ClientOnboardingDialog> createState() =>
      _ClientOnboardingDialogState();
}

class _ClientOnboardingDialogState extends State<_ClientOnboardingDialog> {
  int _step = 0;
  String? _error;
  bool _showCreatePulse = false;
  DateTime _sessionStartedAt = DateTime.now();
  final _clientIdController = TextEditingController();
  final _legalNameController = TextEditingController();
  final _billingAddressController = TextEditingController();
  final _vatNumberController = TextEditingController();
  final _sovereignContactController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _telegramChatIdController = TextEditingController();
  final _telegramThreadIdController = TextEditingController();
  final _endpointLabelController = TextEditingController(
    text: 'Primary Client Telegram',
  );
  String _clientType = 'guarding';
  String _slaTier = 'gold';
  String _incidentRoutingPolicy = 'all';
  bool _enableTelegramBridge = true;
  bool _contactConsentConfirmed = true;
  String _selectedClientScenario = 'estate_hoa';
  String _appliedClientScenario = '';
  DateTime? _contractStart;

  @override
  void dispose() {
    _clientIdController.dispose();
    _legalNameController.dispose();
    _billingAddressController.dispose();
    _vatNumberController.dispose();
    _sovereignContactController.dispose();
    _contactNameController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    _telegramChatIdController.dispose();
    _telegramThreadIdController.dispose();
    _endpointLabelController.dispose();
    super.dispose();
  }

  void _resetDemoPace() {
    setState(() => _sessionStartedAt = DateTime.now());
  }

  int _startFreshDemo() {
    var resetCount = 0;
    setState(() {
      if (_step != 0) {
        _step = 0;
        resetCount++;
      }
      if (_error != null) {
        _error = null;
        resetCount++;
      }
      if (_showCreatePulse) {
        _showCreatePulse = false;
        resetCount++;
      }
      _sessionStartedAt = DateTime.now();
      if (_clientIdController.text.trim().isNotEmpty) {
        _clientIdController.clear();
        resetCount++;
      }
      if (_legalNameController.text.trim().isNotEmpty) {
        _legalNameController.clear();
        resetCount++;
      }
      if (_billingAddressController.text.trim().isNotEmpty) {
        _billingAddressController.clear();
        resetCount++;
      }
      if (_vatNumberController.text.trim().isNotEmpty) {
        _vatNumberController.clear();
        resetCount++;
      }
      if (_sovereignContactController.text.trim().isNotEmpty) {
        _sovereignContactController.clear();
        resetCount++;
      }
      if (_contactNameController.text.trim().isNotEmpty) {
        _contactNameController.clear();
        resetCount++;
      }
      if (_contactEmailController.text.trim().isNotEmpty) {
        _contactEmailController.clear();
        resetCount++;
      }
      if (_contactPhoneController.text.trim().isNotEmpty) {
        _contactPhoneController.clear();
        resetCount++;
      }
      if (_telegramChatIdController.text.trim().isNotEmpty) {
        _telegramChatIdController.clear();
        resetCount++;
      }
      if (_telegramThreadIdController.text.trim().isNotEmpty) {
        _telegramThreadIdController.clear();
        resetCount++;
      }
      if (_endpointLabelController.text.trim() != 'Primary Client Telegram') {
        _endpointLabelController.text = 'Primary Client Telegram';
        resetCount++;
      }
      if (_clientType != 'guarding') {
        _clientType = 'guarding';
        resetCount++;
      }
      if (_slaTier != 'gold') {
        _slaTier = 'gold';
        resetCount++;
      }
      if (_incidentRoutingPolicy != 'all') {
        _incidentRoutingPolicy = 'all';
        resetCount++;
      }
      if (!_enableTelegramBridge) {
        _enableTelegramBridge = true;
        resetCount++;
      }
      if (!_contactConsentConfirmed) {
        _contactConsentConfirmed = true;
        resetCount++;
      }
      if (_contractStart != null) {
        _contractStart = null;
        resetCount++;
      }
      if (_appliedClientScenario.isNotEmpty) {
        _appliedClientScenario = '';
        resetCount++;
      }
    });
    return resetCount;
  }

  double get _completionScore {
    var score = 0;
    const total = 8;
    if (_clientIdController.text.trim().isNotEmpty) score++;
    if (_legalNameController.text.trim().isNotEmpty) score++;
    if (_sovereignContactController.text.trim().isNotEmpty) score++;
    if (_contactPhoneController.text.trim().isNotEmpty) score++;
    if (_endpointLabelController.text.trim().isNotEmpty) score++;
    if (!_enableTelegramBridge ||
        _telegramChatIdController.text.trim().isNotEmpty) {
      score++;
    }
    if (_slaTier.trim().isNotEmpty) score++;
    if (_contractStart != null) score++;
    return score / total;
  }

  List<String> get _previewLines {
    final id = _clientIdController.text.trim().isEmpty
        ? 'Pending'
        : _clientIdController.text.trim().toUpperCase();
    final name = _legalNameController.text.trim().isEmpty
        ? 'Pending legal entity'
        : _legalNameController.text.trim();
    final contact = _sovereignContactController.text.trim().isEmpty
        ? 'Pending sovereign contact'
        : _sovereignContactController.text.trim();
    final start = _contractStart == null
        ? 'Pending'
        : _dateOnly(_contractStart!);
    final provider = _enableTelegramBridge ? 'telegram' : 'in_app';
    final bridgeValue = _enableTelegramBridge
        ? (_telegramChatIdController.text.trim().isEmpty
              ? 'Pending chat id'
              : _telegramChatIdController.text.trim())
        : 'In-app only';
    return [
      'Client: $id • $name',
      'Type/SLA: ${_clientType.replaceAll('_', ' ')} / ${_slaTier.toUpperCase()}',
      'Sovereign Contact: $contact',
      'Bridge: $provider • $bridgeValue',
      'Contract Start: $start',
    ];
  }

  List<_PreviewGate> get _previewGates {
    final hasIdentity =
        _clientIdController.text.trim().isNotEmpty &&
        _legalNameController.text.trim().isNotEmpty;
    final hasSovereign = _sovereignContactController.text.trim().isNotEmpty;
    final hasComms =
        _contactPhoneController.text.trim().isNotEmpty ||
        _contactEmailController.text.trim().isNotEmpty;
    final hasBridge =
        !_enableTelegramBridge ||
        _telegramChatIdController.text.trim().isNotEmpty;
    final hasConsent = _contactConsentConfirmed;
    final hasContractStart = _contractStart != null;
    final hasSla = _slaTier.trim().isNotEmpty;
    return [
      _PreviewGate(label: 'Identity', ready: hasIdentity, step: 0),
      _PreviewGate(label: 'Sovereign Contact', ready: hasSovereign, step: 1),
      _PreviewGate(label: 'Comms Lane', ready: hasComms, step: 1),
      _PreviewGate(label: 'Contract Date', ready: hasContractStart, step: 2),
      _PreviewGate(label: 'SLA Tier', ready: hasSla, step: 2),
      _PreviewGate(label: 'Messaging Bridge', ready: hasBridge, step: 3),
      _PreviewGate(label: 'Consent', ready: hasConsent, step: 3),
    ];
  }

  bool get _allGatesReady => _previewGates.every((gate) => gate.ready);

  int? get _nextIncompleteStep {
    for (final gate in _previewGates) {
      if (!gate.ready) return gate.step;
    }
    return null;
  }

  Map<String, dynamic> get _payloadPreview {
    return {
      'client_id': _clientIdController.text.trim().toUpperCase(),
      'legal_name': _legalNameController.text.trim(),
      'client_type': _clientType,
      'sla_tier': _slaTier,
      'sovereign_contact': _sovereignContactController.text.trim(),
      'billing_address': _billingAddressController.text.trim(),
      'vat_number': _vatNumberController.text.trim(),
      'contact_name': _contactNameController.text.trim(),
      'contact_email': _contactEmailController.text.trim(),
      'contact_phone': _contactPhoneController.text.trim(),
      'contract_start': _contractStart?.toIso8601String(),
      'messaging_provider': _enableTelegramBridge ? 'telegram' : 'in_app',
      'messaging_endpoint_label': _endpointLabelController.text.trim(),
      'telegram_chat_id': _telegramChatIdController.text.trim(),
      'telegram_thread_id': _telegramThreadIdController.text.trim(),
      'incident_routing_policy': _incidentRoutingPolicy,
      'contact_consent_confirmed': _contactConsentConfirmed,
    };
  }

  bool _validateStep() {
    setState(() => _error = null);
    if (_step == 0) {
      if (_clientIdController.text.trim().isEmpty) {
        setState(() => _error = 'Client ID is required.');
        return false;
      }
      if (_legalNameController.text.trim().isEmpty) {
        setState(() => _error = 'Legal name is required.');
        return false;
      }
    }
    if (_step == 1) {
      final email = _contactEmailController.text.trim();
      if (email.isNotEmpty && !email.contains('@')) {
        setState(() => _error = 'Contact email is invalid.');
        return false;
      }
    }
    if (_step == 3) {
      if (_endpointLabelController.text.trim().isEmpty) {
        setState(() => _error = 'Messaging endpoint label is required.');
        return false;
      }
      if (_enableTelegramBridge &&
          _telegramChatIdController.text.trim().isEmpty) {
        setState(() => _error = 'Telegram chat ID is required.');
        return false;
      }
    }
    return true;
  }

  Future<void> _pickContractStart() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _contractStart ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) {
      setState(() => _contractStart = picked);
    }
  }

  void _next() async {
    if (!_validateStep()) return;
    if (_showCreatePulse) {
      setState(() => _showCreatePulse = false);
    }
    if (_step < 3) {
      setState(() => _step += 1);
      return;
    }
    if (!_allGatesReady) {
      final proceed = await _confirmIncompleteReadiness(
        context,
        entityLabel: 'Client',
        gates: _previewGates,
        accent: const Color(0xFF2A6CC6),
      );
      if (!proceed) {
        final target = _nextIncompleteStep;
        if (target != null && mounted) {
          setState(() => _step = target);
        }
        return;
      }
    }
    await _playCreatePulse();
    if (!mounted) return;
    Navigator.of(context).pop(
      _ClientOnboardingDraft(
        clientId: _clientIdController.text.trim().toUpperCase(),
        legalName: _legalNameController.text.trim(),
        clientType: _clientType,
        billingAddress: _billingAddressController.text.trim(),
        vatNumber: _vatNumberController.text.trim(),
        sovereignContact: _sovereignContactController.text.trim(),
        contactName: _contactNameController.text.trim(),
        contactEmail: _contactEmailController.text.trim(),
        contactPhone: _contactPhoneController.text.trim(),
        contractStart: _contractStart,
        slaTier: _slaTier,
        messagingProvider: _enableTelegramBridge ? 'telegram' : 'in_app',
        messagingEndpointLabel: _endpointLabelController.text.trim(),
        telegramChatId: _telegramChatIdController.text.trim(),
        telegramThreadId: _telegramThreadIdController.text.trim(),
        incidentRoutingPolicy: _incidentRoutingPolicy,
        contactConsentConfirmed: _contactConsentConfirmed,
      ),
    );
  }

  Future<void> _playCreatePulse() async {
    if (!mounted) return;
    setState(() => _showCreatePulse = true);
    await Future<void>.delayed(const Duration(milliseconds: 520));
  }

  void _applyDemoTemplate() {
    _applyClientScenario(_selectedClientScenario);
  }

  String _launchDemoFlow() {
    _applyDemoTemplate();
    return '${_clientScenarioLabel(_selectedClientScenario)} demo loaded. ${_recoverDemoPace()}';
  }

  String _clientScenarioLabel(String scenario) {
    switch (scenario) {
      case 'industrial_campus':
        return 'Industrial';
      case 'retail_centre':
        return 'Retail';
      case 'estate_hoa':
      default:
        return 'Estate';
    }
  }

  int _autoFillMissingForDemo() {
    final stamp = DateTime.now().millisecondsSinceEpoch % 10000;
    final scenario = _selectedClientScenario;
    String defaultIdPrefix = 'DEMO-CLT';
    String defaultLegalName = 'Sovereign Ridge Estate HOA';
    String defaultBilling = '21 Sovereign Lane, Sandton, Johannesburg, 2196';
    String defaultVat = '4499912345';
    String defaultSovereign = 'Alicia van der Merwe';
    String defaultContactName = 'Alicia van der Merwe';
    String defaultEmail = 'alicia@sovereignridge.co.za';
    String defaultPhone = '+27 82 700 1122';
    String defaultTelegramChatId = '-1000000000000';
    String defaultTelegramThreadId = '';
    switch (scenario) {
      case 'industrial_campus':
        defaultIdPrefix = 'DEMO-CLT-I';
        defaultLegalName = 'Atlas Industrial Campus (Pty) Ltd';
        defaultBilling = '7 Foundry Road, Wadeville, Germiston, 1422';
        defaultVat = '4080112234';
        defaultSovereign = 'Mandla Dube';
        defaultContactName = 'Mandla Dube';
        defaultEmail = 'operations@atlascampus.co.za';
        defaultPhone = '+27 82 900 4431';
        defaultTelegramChatId = '-1000000001001';
        break;
      case 'retail_centre':
        defaultIdPrefix = 'DEMO-CLT-R';
        defaultLegalName = 'Harbor Point Retail Centre';
        defaultBilling = '55 Marine Drive, Umhlanga, KwaZulu-Natal, 4319';
        defaultVat = '4527700987';
        defaultSovereign = 'Naomi Peters';
        defaultContactName = 'Centre Management Desk';
        defaultEmail = 'ops@harborpointmall.co.za';
        defaultPhone = '+27 83 455 8891';
        defaultTelegramChatId = '-1000000002002';
        break;
      case 'estate_hoa':
      default:
        break;
    }
    var filledCount = 0;
    setState(() {
      if (_clientIdController.text.trim().isEmpty) {
        _clientIdController.text = '$defaultIdPrefix$stamp';
        filledCount++;
      }
      if (_legalNameController.text.trim().isEmpty) {
        _legalNameController.text = defaultLegalName;
        filledCount++;
      }
      if (_billingAddressController.text.trim().isEmpty) {
        _billingAddressController.text = defaultBilling;
        filledCount++;
      }
      if (_vatNumberController.text.trim().isEmpty) {
        _vatNumberController.text = defaultVat;
        filledCount++;
      }
      if (_sovereignContactController.text.trim().isEmpty) {
        _sovereignContactController.text = defaultSovereign;
        filledCount++;
      }
      if (_contactNameController.text.trim().isEmpty) {
        _contactNameController.text = defaultContactName;
        filledCount++;
      }
      if (_contactEmailController.text.trim().isEmpty) {
        _contactEmailController.text = defaultEmail;
        filledCount++;
      }
      if (_contactPhoneController.text.trim().isEmpty) {
        _contactPhoneController.text = defaultPhone;
        filledCount++;
      }
      if (_endpointLabelController.text.trim().isEmpty) {
        _endpointLabelController.text = 'Primary Client Telegram';
        filledCount++;
      }
      if (_telegramChatIdController.text.trim().isEmpty) {
        _telegramChatIdController.text = defaultTelegramChatId;
        filledCount++;
      }
      if (_telegramThreadIdController.text.trim().isEmpty &&
          defaultTelegramThreadId.isNotEmpty) {
        _telegramThreadIdController.text = defaultTelegramThreadId;
        filledCount++;
      }
      if (!_enableTelegramBridge) {
        _enableTelegramBridge = true;
        filledCount++;
      }
      if (_incidentRoutingPolicy != 'all') {
        _incidentRoutingPolicy = 'all';
        filledCount++;
      }
      if (!_contactConsentConfirmed) {
        _contactConsentConfirmed = true;
        filledCount++;
      }
      if (_contractStart == null) {
        _contractStart = DateTime.now();
        filledCount++;
      }
    });
    return filledCount;
  }

  String _clientPitchText() {
    final legal = _legalNameController.text.trim().isEmpty
        ? 'this client'
        : _legalNameController.text.trim();
    final contact = _sovereignContactController.text.trim().isEmpty
        ? 'the sovereign contact'
        : _sovereignContactController.text.trim();
    final typeLabel = _clientType.replaceAll('_', ' ');
    final tier = _slaTier.toUpperCase();
    final provider = _enableTelegramBridge ? 'Telegram bridge' : 'in-app lane';
    return 'ONYX has onboarded $legal as a $typeLabel account with $tier SLA. '
        'Sovereign advisory lane is anchored to $contact via $provider, so escalations and incident updates flow instantly without manual lookup.';
  }

  String _runDemoReady() {
    final filledCount = _autoFillMissingForDemo();
    final target = _nextIncompleteStep;
    if (target != null) {
      setState(() => _step = target);
      return filledCount <= 0
          ? 'Complete Step ${target + 1} to finish readiness.'
          : '$filledCount fields auto-filled. Continue on Step ${target + 1}.';
    }
    setState(() => _step = 3);
    return filledCount <= 0
        ? 'Already demo-ready for client onboarding.'
        : 'Client onboarding demo-ready with $filledCount fields auto-filled.';
  }

  String _recoverDemoPace() {
    setState(() => _sessionStartedAt = DateTime.now());
    final readiness = _runDemoReady();
    return 'Demo pace reset. $readiness';
  }

  String _resolvedClientPreviewReference() {
    final clientId = _clientIdController.text.trim().toUpperCase();
    if (clientId.isNotEmpty) return clientId;
    final legalToken = _legalNameController.text
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    if (legalToken.isNotEmpty) return 'CLIENT-$legalToken';
    return '';
  }

  void _openClientOperationsPreview() {
    final openOperations = widget.onOpenOperationsForIncident;
    if (openOperations == null) {
      _showOnboardingSnackBar(
        context,
        'Operations view navigation unavailable.',
      );
      return;
    }
    final focusReference = _resolvedClientPreviewReference();
    if (focusReference.isEmpty) {
      _showOnboardingSnackBar(
        context,
        'Set client ID or legal name before opening Operations.',
      );
      return;
    }
    Navigator.of(context).pop();
    openOperations.call(focusReference);
  }

  void _openClientTacticalPreview() {
    final openTactical = widget.onOpenTacticalForIncident;
    if (openTactical == null) {
      _showOnboardingSnackBar(context, 'Tactical view navigation unavailable.');
      return;
    }
    final focusReference = _resolvedClientPreviewReference();
    if (focusReference.isEmpty) {
      _showOnboardingSnackBar(
        context,
        'Set client ID or legal name before opening Tactical.',
      );
      return;
    }
    Navigator.of(context).pop();
    openTactical.call(focusReference);
  }

  String get _demoReadyButtonLabel {
    final readyCount = _previewGates.where((gate) => gate.ready).length;
    final total = _previewGates.length;
    if (total > 0 && readyCount == total) {
      return 'Demo Ready ✓';
    }
    return 'Demo Ready $readyCount/$total';
  }

  IconData get _demoReadyButtonIcon =>
      _allGatesReady ? Icons.task_alt_rounded : Icons.bolt_rounded;

  Color get _demoReadyButtonColor =>
      _allGatesReady ? const Color(0xFF0F766E) : const Color(0xFF1E5AA9);

  bool get _clientTemplatePending =>
      _selectedClientScenario != _appliedClientScenario;

  String _clientSnapshotText() {
    final readyCount = _previewGates.where((gate) => gate.ready).length;
    final gateTotal = _previewGates.length;
    final completionPct = (_completionScore.clamp(0.0, 1.0) * 100).round();
    final nextGap = _nextIncompleteStep;
    return 'Client Demo Snapshot\n'
        'Scenario: ${_clientScenarioLabel(_selectedClientScenario)}\n'
        'Template: ${_clientTemplatePending ? 'Pending apply' : 'Applied'}\n'
        'Progress: Step ${_step + 1}/4\n'
        'Readiness: $readyCount/$gateTotal\n'
        'Completion: $completionPct%\n'
        'Next Gap: ${nextGap == null ? 'None' : 'Step ${nextGap + 1}'}\n'
        '${_previewLines.join('\n')}';
  }

  void _applyClientScenario(String scenario) {
    final stamp = DateTime.now().millisecondsSinceEpoch % 10000;
    setState(() {
      _selectedClientScenario = scenario;
      _appliedClientScenario = scenario;
      switch (scenario) {
        case 'industrial_campus':
          _clientIdController.text = 'DEMO-CLT-I$stamp';
          _legalNameController.text = 'Atlas Industrial Campus (Pty) Ltd';
          _billingAddressController.text =
              '7 Foundry Road, Wadeville, Germiston, 1422';
          _vatNumberController.text = '4080112234';
          _sovereignContactController.text = 'Mandla Dube';
          _contactNameController.text = 'Mandla Dube';
          _contactEmailController.text = 'operations@atlascampus.co.za';
          _contactPhoneController.text = '+27 82 900 4431';
          _telegramChatIdController.text = '-1000000001001';
          _telegramThreadIdController.text = '';
          _endpointLabelController.text = 'Primary Client Telegram';
          _incidentRoutingPolicy = 'all';
          _enableTelegramBridge = true;
          _contactConsentConfirmed = true;
          _clientType = 'armed_response';
          _slaTier = 'platinum';
          break;
        case 'retail_centre':
          _clientIdController.text = 'DEMO-CLT-R$stamp';
          _legalNameController.text = 'Harbor Point Retail Centre';
          _billingAddressController.text =
              '55 Marine Drive, Umhlanga, KwaZulu-Natal, 4319';
          _vatNumberController.text = '4527700987';
          _sovereignContactController.text = 'Naomi Peters';
          _contactNameController.text = 'Centre Management Desk';
          _contactEmailController.text = 'ops@harborpointmall.co.za';
          _contactPhoneController.text = '+27 83 455 8891';
          _telegramChatIdController.text = '-1000000002002';
          _telegramThreadIdController.text = '';
          _endpointLabelController.text = 'Primary Client Telegram';
          _incidentRoutingPolicy = 'all';
          _enableTelegramBridge = true;
          _contactConsentConfirmed = true;
          _clientType = 'hybrid';
          _slaTier = 'gold';
          break;
        case 'estate_hoa':
        default:
          _clientIdController.text = 'DEMO-CLT-$stamp';
          _legalNameController.text = 'Sovereign Ridge Estate HOA';
          _billingAddressController.text =
              '21 Sovereign Lane, Sandton, Johannesburg, 2196';
          _vatNumberController.text = '4499912345';
          _sovereignContactController.text = 'Alicia van der Merwe';
          _contactNameController.text = 'Alicia van der Merwe';
          _contactEmailController.text = 'alicia@sovereignridge.co.za';
          _contactPhoneController.text = '+27 82 700 1122';
          _telegramChatIdController.text = '-1000000003003';
          _telegramThreadIdController.text = '';
          _endpointLabelController.text = 'Primary Client Telegram';
          _incidentRoutingPolicy = 'all';
          _enableTelegramBridge = true;
          _contactConsentConfirmed = true;
          _clientType = 'hybrid';
          _slaTier = 'gold';
          break;
      }
      _contractStart = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    return Dialog(
      backgroundColor: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF30363D)),
      ),
      child: SizedBox(
        width: _responsiveDialogWidth(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _onboardingHero(
                  context: context,
                  title: 'New Client Onboarding',
                  subtitle:
                      'Register contract, billing, and sovereign contacts in a clean guided flow.',
                  accent: const Color(0xFF2A6CC6),
                  responseTarget: 'Client onboarding under 60s',
                  confidenceLabel: 'Contract readiness 99.2%',
                  talkTrackTitle: 'Client Demo Talk Track',
                  talkTrackLines: const [
                    'We start by registering the legal entity and sovereign contact.',
                    'ONYX binds SLA tiering upfront so response expectations are explicit.',
                    'Billing and compliance fields are captured once for all connected sites.',
                    'This turns onboarding into a one-minute operational handoff.',
                  ],
                  compact: compact,
                  chips: const [
                    'Legal Entity',
                    'SLA Tier',
                    'Sovereign Contact',
                  ],
                ),
                if (widget.demoMode) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () {
                          _applyDemoTemplate();
                          _showOnboardingSnackBar(
                            context,
                            '${_clientScenarioLabel(_selectedClientScenario)} template applied.',
                          );
                        },
                        icon: Icon(
                          _clientTemplatePending
                              ? Icons.hourglass_top_rounded
                              : Icons.auto_awesome_rounded,
                          size: 16,
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _clientTemplatePending
                              ? const Color(0xFF9A4D08)
                              : const Color(0xFF1F3A5A),
                          foregroundColor: const Color(0xFFEAF4FF),
                        ),
                        label: Text(
                          _clientTemplatePending
                              ? 'Apply ${_clientScenarioLabel(_selectedClientScenario)} Template'
                              : '${_clientScenarioLabel(_selectedClientScenario)} Template Applied',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () async {
                          final launchMessage = _launchDemoFlow();
                          await Clipboard.setData(
                            ClipboardData(text: _clientPitchText()),
                          );
                          if (!context.mounted) return;
                          _showOnboardingSnackBar(
                            context,
                            '$launchMessage Pitch copied.',
                          );
                        },
                        icon: const Icon(Icons.rocket_launch_rounded, size: 16),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: const Color(0xFFEAF4FF),
                        ),
                        label: Text(
                          'Launch Demo',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () =>
                            _showOnboardingSnackBar(context, _runDemoReady()),
                        icon: Icon(_demoReadyButtonIcon, size: 16),
                        style: FilledButton.styleFrom(
                          backgroundColor: _demoReadyButtonColor,
                          foregroundColor: const Color(0xFFEAF4FF),
                        ),
                        label: Text(
                          _demoReadyButtonLabel,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                      _demoScenarioPicker(
                        label: 'Client Scenario',
                        selectedValue: _selectedClientScenario,
                        isApplied: !_clientTemplatePending,
                        onSelected: (scenario) {
                          setState(() => _selectedClientScenario = scenario);
                          final pending =
                              _selectedClientScenario != _appliedClientScenario;
                          _showOnboardingSnackBar(
                            context,
                            pending
                                ? '${_clientScenarioLabel(scenario)} scenario selected. Tap Apply to populate fields.'
                                : '${_clientScenarioLabel(scenario)} scenario already applied.',
                          );
                        },
                        options: const [
                          _DemoScenarioOption(
                            value: 'estate_hoa',
                            label: 'Estate HOA',
                            detail: 'Residential command stack.',
                          ),
                          _DemoScenarioOption(
                            value: 'industrial_campus',
                            label: 'Industrial Campus',
                            detail: 'High-risk armed response profile.',
                          ),
                          _DemoScenarioOption(
                            value: 'retail_centre',
                            label: 'Retail Centre',
                            detail: 'Hybrid guarding + remote watch.',
                          ),
                        ],
                      ),
                      OutlinedButton.icon(
                        onPressed: _resetDemoPace,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8FD1FF),
                          side: const BorderSide(color: Color(0xFF35506F)),
                        ),
                        label: Text(
                          'Reset Pace',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          final resetCount = _startFreshDemo();
                          final message = resetCount <= 0
                              ? 'Already fresh and ready for next demo.'
                              : resetCount == 1
                              ? '1 item reset for a fresh demo.'
                              : '$resetCount items reset for a fresh demo.';
                          _showOnboardingSnackBar(context, message);
                        },
                        icon: const Icon(
                          Icons.cleaning_services_rounded,
                          size: 16,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF9FD6FF),
                          side: const BorderSide(color: Color(0xFF35506F)),
                        ),
                        label: Text(
                          'Start Fresh',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          final target = _nextIncompleteStep;
                          if (target == null) {
                            _showOnboardingSnackBar(
                              context,
                              'All readiness gates are already complete.',
                            );
                            return;
                          }
                          setState(() => _step = target);
                          _showOnboardingSnackBar(
                            context,
                            'Jumped to Step ${target + 1} for missing inputs.',
                          );
                        },
                        icon: const Icon(Icons.track_changes_rounded, size: 16),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFFE1B8),
                          side: const BorderSide(color: Color(0xFFB3742C)),
                        ),
                        label: Text(
                          'Next Gap',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.onOpenOperationsForIncident == null
                            ? null
                            : _openClientOperationsPreview,
                        icon: const Icon(
                          Icons.space_dashboard_rounded,
                          size: 16,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFBFD7F2),
                          side: const BorderSide(color: Color(0xFF35506F)),
                        ),
                        label: Text(
                          'Open Operations',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.onOpenTacticalForIncident == null
                            ? null
                            : _openClientTacticalPreview,
                        icon: const Icon(Icons.map_rounded, size: 16),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF9FE8FF),
                          side: const BorderSide(color: Color(0xFF35506F)),
                        ),
                        label: Text(
                          'Open Tactical',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: _clientPitchText()),
                          );
                          if (!context.mounted) return;
                          _showOnboardingSnackBar(
                            context,
                            'Client pitch copied.',
                          );
                        },
                        icon: const Icon(Icons.mic_rounded, size: 16),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFBFE6FF),
                          side: const BorderSide(color: Color(0xFF35506F)),
                        ),
                        label: Text(
                          'Copy Pitch',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: _clientSnapshotText()),
                          );
                          if (!context.mounted) return;
                          _showOnboardingSnackBar(
                            context,
                            'Client snapshot copied.',
                          );
                        },
                        icon: const Icon(Icons.receipt_long_rounded, size: 16),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFD5EBFF),
                          side: const BorderSide(color: Color(0xFF35506F)),
                        ),
                        label: Text(
                          'Copy Snapshot',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
                if ((_error ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFF87171),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                _creationPulseBanner(
                  visible: _showCreatePulse,
                  accent: const Color(0xFF2A6CC6),
                  label: 'Client profile locked and ready for deployment.',
                ),
                const SizedBox(height: 8),
                _stepSummary(
                  currentStep: _step,
                  labels: const [
                    'Identity',
                    'Contact',
                    'Contract',
                    'Messaging',
                  ],
                  onStepTap: (step) => setState(() => _step = step),
                  readinessGates: _previewGates,
                ),
                const SizedBox(height: 8),
                _demoPaceMeter(
                  startedAt: _sessionStartedAt,
                  targetSeconds: 60,
                  accent: const Color(0xFF2A6CC6),
                  compact: compact,
                  onRecover: widget.demoMode
                      ? () =>
                            _showOnboardingSnackBar(context, _recoverDemoPace())
                      : null,
                  recoverLabel: 'Recover Client Pace',
                ),
                const SizedBox(height: 8),
                _demoCoachCard(
                  context: context,
                  accent: const Color(0xFF2A6CC6),
                  currentStep: _step,
                  compact: compact,
                  cues: const [
                    _DemoCoachCue(
                      stage: 'Identity',
                      narration:
                          'We register the legal entity once and anchor every downstream site and incident to this contract owner.',
                      proofPoint:
                          'PSIRA/billing alignment begins at onboarding, not after incidents.',
                    ),
                    _DemoCoachCue(
                      stage: 'Contact',
                      narration:
                          'Sovereign and emergency contacts are captured here so advisory flows are pre-mapped before first alarm.',
                      proofPoint:
                          'Cuts dispatch friction by avoiding manual contact lookup in crisis.',
                    ),
                    _DemoCoachCue(
                      stage: 'Contract',
                      narration:
                          'SLA tiering sets response expectations now, so the command center can enforce objective timelines.',
                      proofPoint:
                          'Prevents ambiguity in post-incident client reporting.',
                    ),
                    _DemoCoachCue(
                      stage: 'Messaging',
                      narration:
                          'Client contact is linked to Telegram or in-app routing at onboarding, so alerts land instantly in the agreed lane.',
                      proofPoint:
                          'Removes manual channel switching during live incidents.',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _onboardingLivePreview(
                  context: context,
                  title: 'Live Payload Preview',
                  accent: const Color(0xFF2A6CC6),
                  lines: _previewLines,
                  gates: _previewGates,
                  completion: _completionScore,
                  compact: compact,
                  payload: _payloadPreview,
                  sqlTable: 'clients',
                  sqlConflictColumns: const ['client_id'],
                  onAutoFillMissing: widget.demoMode
                      ? _autoFillMissingForDemo
                      : null,
                  autoFillLabel:
                      'Auto-Fill ${_clientScenarioLabel(_selectedClientScenario)} Demo',
                  onJumpToStep: (step) => setState(() => _step = step),
                ),
                const SizedBox(height: 8),
                Theme(
                  data: _onboardingStepperTheme(context),
                  child: Stepper(
                    currentStep: _step,
                    onStepTapped: (value) => setState(() => _step = value),
                    controlsBuilder: (context, details) {
                      final isFinalStep = _step == 3;
                      final readyForCreate = _allGatesReady;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _next,
                            icon: Icon(
                              isFinalStep
                                  ? (readyForCreate
                                        ? Icons.check_circle_rounded
                                        : Icons.error_outline_rounded)
                                  : Icons.arrow_forward_rounded,
                              size: 16,
                            ),
                            style: _onboardingPrimaryActionStyle(
                              accent: const Color(0xFF2A6CC6),
                              isFinalStep: isFinalStep,
                              readyForCreate: readyForCreate,
                            ),
                            label: Text(
                              isFinalStep
                                  ? (readyForCreate
                                        ? 'Create Client (Ready)'
                                        : 'Create Client (Needs Inputs)')
                                  : 'Next',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: _step == 0
                                ? () => Navigator.of(context).pop()
                                : () => setState(() => _step -= 1),
                            icon: Icon(
                              _step == 0
                                  ? Icons.close_rounded
                                  : Icons.arrow_back_rounded,
                              size: 16,
                            ),
                            style: _onboardingSecondaryActionStyle(),
                            label: Text(
                              _step == 0 ? 'Cancel' : 'Back',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (isFinalStep && !readyForCreate)
                            OutlinedButton.icon(
                              onPressed: () {
                                final target = _nextIncompleteStep;
                                if (target == null) return;
                                setState(() => _step = target);
                              },
                              icon: const Icon(
                                Icons.track_changes_rounded,
                                size: 16,
                              ),
                              style: _onboardingMissingStepActionStyle(),
                              label: Text(
                                'Go To Missing Step',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                    steps: [
                      Step(
                        state: _stepStateFor(stepIndex: 0, currentStep: _step),
                        isActive: true,
                        title: _stepTitle(
                          'Identity',
                          stepIndex: 0,
                          currentStep: _step,
                        ),
                        content: _stepPanel(
                          children: [
                            _textField(
                              _clientIdController,
                              'Client ID (e.g. CLIENT-001)',
                            ),
                            const SizedBox(height: 8),
                            _textField(
                              _legalNameController,
                              'Legal Entity Name',
                            ),
                            const SizedBox(height: 8),
                            _dropdownField(
                              label: 'Client Type',
                              value: _clientType,
                              items: const [
                                'guarding',
                                'armed_response',
                                'remote_watch',
                                'hybrid',
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _clientType = value);
                              },
                            ),
                          ],
                        ),
                      ),
                      Step(
                        state: _stepStateFor(stepIndex: 1, currentStep: _step),
                        isActive: true,
                        title: _stepTitle(
                          'Contact & Compliance',
                          stepIndex: 1,
                          currentStep: _step,
                        ),
                        content: _stepPanel(
                          children: [
                            _textField(
                              _billingAddressController,
                              'Billing Address',
                            ),
                            const SizedBox(height: 8),
                            _textField(_vatNumberController, 'VAT Number'),
                            const SizedBox(height: 8),
                            _textField(
                              _sovereignContactController,
                              'Sovereign Contact',
                            ),
                            const SizedBox(height: 8),
                            _textField(
                              _contactNameController,
                              'Primary Contact Name',
                            ),
                            const SizedBox(height: 8),
                            _textField(
                              _contactEmailController,
                              'Primary Contact Email',
                            ),
                            const SizedBox(height: 8),
                            _textField(
                              _contactPhoneController,
                              'Primary Contact Phone',
                            ),
                          ],
                        ),
                      ),
                      Step(
                        state: _stepStateFor(stepIndex: 2, currentStep: _step),
                        isActive: true,
                        title: _stepTitle(
                          'Contract',
                          stepIndex: 2,
                          currentStep: _step,
                        ),
                        content: _stepPanel(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _dropdownField(
                              label: 'SLA Tier',
                              value: _slaTier,
                              items: const [
                                'platinum',
                                'gold',
                                'silver',
                                'bronze',
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _slaTier = value);
                              },
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _pickContractStart,
                              icon: const Icon(Icons.event_rounded, size: 16),
                              label: Text(
                                _contractStart == null
                                    ? 'Set Contract Start Date'
                                    : 'Contract Start: ${_dateOnly(_contractStart!)}',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Step(
                        state: _stepStateFor(stepIndex: 3, currentStep: _step),
                        isActive: true,
                        title: _stepTitle(
                          'Messaging Bridge',
                          stepIndex: 3,
                          currentStep: _step,
                        ),
                        content: _stepPanel(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              value: _enableTelegramBridge,
                              onChanged: (value) {
                                setState(() => _enableTelegramBridge = value);
                              },
                              title: Text(
                                'Enable Telegram Bridge',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFEAF4FF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                _enableTelegramBridge
                                    ? 'Alerts route to client Telegram chat/topic.'
                                    : 'Use ONYX in-app messaging only.',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF9AB1CF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _textField(
                              _endpointLabelController,
                              'Endpoint Label (e.g. Primary Client Telegram)',
                            ),
                            if (_enableTelegramBridge) ...[
                              const SizedBox(height: 8),
                              _textField(
                                _telegramChatIdController,
                                'Telegram Chat ID (e.g. -1001234567890)',
                              ),
                              const SizedBox(height: 8),
                              _textField(
                                _telegramThreadIdController,
                                'Telegram Thread ID (optional)',
                              ),
                            ],
                            const SizedBox(height: 8),
                            _dropdownField(
                              label: 'Incident Routing Policy',
                              value: _incidentRoutingPolicy,
                              items: const ['all', 'p1_p2', 'p1_only'],
                              labels: const {
                                'all': 'All priorities (P1-P4)',
                                'p1_p2': 'Critical + High (P1-P2)',
                                'p1_only': 'Critical only (P1)',
                              },
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _incidentRoutingPolicy = value);
                              },
                            ),
                            const SizedBox(height: 8),
                            CheckboxListTile(
                              value: _contactConsentConfirmed,
                              onChanged: (value) {
                                setState(
                                  () =>
                                      _contactConsentConfirmed = value == true,
                                );
                              },
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                'Contact consent captured for alert delivery',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFEAF4FF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                'Store consent timestamp for POPIA-aligned messaging records.',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF9AB1CF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
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
}

class _ClientMessagingBridgeDialog extends StatefulWidget {
  final List<_ClientAdminRow> clients;
  final List<_SiteAdminRow> sites;
  final String? initialClientId;

  const _ClientMessagingBridgeDialog({
    required this.clients,
    required this.sites,
    this.initialClientId,
  });

  @override
  State<_ClientMessagingBridgeDialog> createState() =>
      _ClientMessagingBridgeDialogState();
}

class _ClientMessagingBridgeDialogState
    extends State<_ClientMessagingBridgeDialog> {
  late String _clientId;
  String _siteId = '';
  bool _applyToAllClientSites = true;
  String _provider = 'telegram';
  String _incidentRoutingPolicy = 'all';
  bool _contactConsentConfirmed = true;
  String? _error;

  final _contactNameController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _endpointLabelController = TextEditingController(
    text: 'Primary Client Telegram',
  );
  final _telegramChatIdController = TextEditingController();
  final _telegramThreadIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final requestedClientId = widget.initialClientId?.trim() ?? '';
    final requestedExists = widget.clients.any(
      (client) => client.id == requestedClientId,
    );
    _clientId = requestedExists ? requestedClientId : widget.clients.first.id;
    _applyClientDefaults();
  }

  @override
  void dispose() {
    _contactNameController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    _endpointLabelController.dispose();
    _telegramChatIdController.dispose();
    _telegramThreadIdController.dispose();
    super.dispose();
  }

  void _applyClientDefaults() {
    final client = _selectedClientRow;
    if (client == null) return;
    if (_contactNameController.text.trim().isEmpty &&
        client.contactPerson.trim().isNotEmpty) {
      _contactNameController.text = client.contactPerson.trim();
    }
    if (_contactEmailController.text.trim().isEmpty &&
        client.contactEmail.trim().isNotEmpty &&
        client.contactEmail.trim() != '-') {
      _contactEmailController.text = client.contactEmail.trim();
    }
    if (_contactPhoneController.text.trim().isEmpty &&
        client.contactPhone.trim().isNotEmpty &&
        client.contactPhone.trim() != '-') {
      _contactPhoneController.text = client.contactPhone.trim();
    }
  }

  _ClientAdminRow? get _selectedClientRow {
    for (final client in widget.clients) {
      if (client.id == _clientId) return client;
    }
    return null;
  }

  List<_SiteAdminRow> get _filteredSites {
    return widget.sites
        .where((site) => site.clientId == _clientId)
        .toList(growable: false);
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(
        color: const Color(0xFF8EA4C2),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: const Color(0xFF0C1117),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0x332B425F)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0x332B425F)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0x8022D3EE)),
      ),
    );
  }

  bool _validate() {
    setState(() => _error = null);
    if (_contactNameController.text.trim().isEmpty) {
      setState(() => _error = 'Contact name is required.');
      return false;
    }
    if (_endpointLabelController.text.trim().isEmpty) {
      setState(() => _error = 'Endpoint label is required.');
      return false;
    }
    if (_provider == 'telegram' &&
        _telegramChatIdController.text.trim().isEmpty) {
      setState(() => _error = 'Telegram chat ID is required.');
      return false;
    }
    if (!_contactConsentConfirmed) {
      setState(() => _error = 'Consent confirmation is required.');
      return false;
    }
    return true;
  }

  void _save() {
    if (!_validate()) return;
    Navigator.of(context).pop(
      _ClientMessagingBridgeDraft(
        clientId: _clientId,
        siteId: _siteId.trim().isEmpty ? null : _siteId.trim(),
        applyToAllClientSites: _applyToAllClientSites,
        contactName: _contactNameController.text.trim(),
        contactRole: 'client_contact',
        contactEmail: _contactEmailController.text.trim(),
        contactPhone: _contactPhoneController.text.trim(),
        provider: _provider,
        endpointLabel: _endpointLabelController.text.trim(),
        telegramChatId: _telegramChatIdController.text.trim(),
        telegramThreadId: _telegramThreadIdController.text.trim(),
        incidentRoutingPolicy: _incidentRoutingPolicy,
        contactConsentConfirmed: _contactConsentConfirmed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clientItems = widget.clients
        .map(
          (client) => DropdownMenuItem<String>(
            value: client.id,
            child: Text(
              '${client.name} (${client.id})',
              style: GoogleFonts.inter(
                color: const Color(0xFFEAF4FF),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        )
        .toList(growable: false);
    final filteredSites = _filteredSites;

    return AlertDialog(
      backgroundColor: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF30363D)),
      ),
      title: Text(
        'Add Client Chat Lane',
        style: GoogleFonts.inter(
          color: const Color(0xFFEAF4FF),
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _clientId,
                isExpanded: true,
                dropdownColor: const Color(0xFF101923),
                style: GoogleFonts.inter(
                  color: const Color(0xFFEAF4FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                decoration: _inputDecoration('Client'),
                items: clientItems,
                onChanged: (value) {
                  if (value == null || value == _clientId) return;
                  setState(() {
                    _clientId = value;
                    _siteId = '';
                  });
                  _applyClientDefaults();
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey<String>('site-scope-$_clientId-$_siteId'),
                initialValue: _siteId,
                isExpanded: true,
                dropdownColor: const Color(0xFF101923),
                style: GoogleFonts.inter(
                  color: const Color(0xFFEAF4FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                decoration: _inputDecoration('Site Scope'),
                items: [
                  DropdownMenuItem<String>(
                    value: '',
                    child: Text(
                      'Client-wide (all sites)',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFEAF4FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ...filteredSites.map(
                    (site) => DropdownMenuItem<String>(
                      value: site.id,
                      child: Text(
                        '${site.name} (${site.id})',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFEAF4FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
                onChanged: _applyToAllClientSites
                    ? null
                    : (value) => setState(() => _siteId = value ?? ''),
              ),
              const SizedBox(height: 6),
              CheckboxListTile(
                value: _applyToAllClientSites,
                onChanged: (value) {
                  setState(() {
                    _applyToAllClientSites = value == true;
                    if (_applyToAllClientSites) {
                      _siteId = '';
                    }
                  });
                },
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  'Apply to all current client sites',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEAF4FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  _filteredSites.isEmpty
                      ? 'No sites yet. Setup will be saved as client-wide and reused when sites are added.'
                      : 'Provision this lane for all ${_filteredSites.length} site(s) in one action.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9AB1CF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _contactNameController,
                style: GoogleFonts.inter(
                  color: const Color(0xFFEAF4FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                decoration: _inputDecoration('Contact Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _contactEmailController,
                style: GoogleFonts.inter(
                  color: const Color(0xFFEAF4FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                decoration: _inputDecoration('Contact Email'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _contactPhoneController,
                style: GoogleFonts.inter(
                  color: const Color(0xFFEAF4FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                decoration: _inputDecoration('Contact Phone'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _provider,
                isExpanded: true,
                dropdownColor: const Color(0xFF101923),
                style: GoogleFonts.inter(
                  color: const Color(0xFFEAF4FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                decoration: _inputDecoration('Provider'),
                items: const [
                  DropdownMenuItem<String>(
                    value: 'telegram',
                    child: Text('Telegram'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'in_app',
                    child: Text('In-App'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _provider = value);
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _endpointLabelController,
                style: GoogleFonts.inter(
                  color: const Color(0xFFEAF4FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                decoration: _inputDecoration('Endpoint Label'),
              ),
              if (_provider == 'telegram') ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _telegramChatIdController,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEAF4FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: _inputDecoration('Telegram Chat ID'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _telegramThreadIdController,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEAF4FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: _inputDecoration('Telegram Thread ID (optional)'),
                ),
              ],
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _incidentRoutingPolicy,
                isExpanded: true,
                dropdownColor: const Color(0xFF101923),
                style: GoogleFonts.inter(
                  color: const Color(0xFFEAF4FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                decoration: _inputDecoration('Routing Policy'),
                items: const [
                  DropdownMenuItem<String>(
                    value: 'all',
                    child: Text('All priorities (P1-P4)'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'p1_p2',
                    child: Text('Critical + High (P1-P2)'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'p1_only',
                    child: Text('Critical only (P1)'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _incidentRoutingPolicy = value);
                },
              ),
              const SizedBox(height: 6),
              CheckboxListTile(
                value: _contactConsentConfirmed,
                onChanged: (value) {
                  setState(() => _contactConsentConfirmed = value == true);
                },
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  'Consent confirmed for messaging',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEAF4FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'POPIA-aligned consent timestamp will be stored.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9AB1CF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if ((_error ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _error!,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFF87171),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: Icon(
            _applyToAllClientSites
                ? Icons.alt_route_rounded
                : Icons.save_rounded,
            size: 16,
          ),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: const Color(0xFFEAF4FF),
          ),
          label: Text(
            _applyToAllClientSites ? 'Save All Site Lanes' : 'Save Chat Lane',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _SiteOnboardingDialog extends StatefulWidget {
  final List<_ClientAdminRow> clients;
  final bool demoMode;
  final ValueChanged<String>? onOpenTacticalForIncident;
  final ValueChanged<String>? onOpenOperationsForIncident;

  const _SiteOnboardingDialog({
    required this.clients,
    required this.demoMode,
    this.onOpenTacticalForIncident,
    this.onOpenOperationsForIncident,
  });

  @override
  State<_SiteOnboardingDialog> createState() => _SiteOnboardingDialogState();
}

class _SiteOnboardingDialogState extends State<_SiteOnboardingDialog> {
  int _step = 0;
  String? _error;
  bool _showCreatePulse = false;
  bool _normalizingSiteIdentity = false;
  String? _lastAutoSiteId;
  String? _lastAutoSiteCode;
  DateTime _sessionStartedAt = DateTime.now();
  late String _clientId = widget.clients.first.id;
  String _riskProfile = 'residential';
  String _selectedSiteScenario = 'industrial_yard';
  String _appliedSiteScenario = '';
  final _siteIdController = TextEditingController();
  final _siteNameController = TextEditingController();
  final _siteCodeController = TextEditingController();
  final _addressController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _geofenceController = TextEditingController(text: '300');
  final _entryProtocolController = TextEditingController();
  final _mapUrlController = TextEditingController();
  final _nudgeController = TextEditingController(text: '15');
  final _escalationController = TextEditingController(text: '2');
  bool _enableSiteTelegramBridge = false;
  final _siteTelegramChatIdController = TextEditingController();
  final _siteTelegramThreadIdController = TextEditingController();
  final _siteEndpointLabelController = TextEditingController(
    text: 'Primary Site Telegram',
  );
  late final List<TextEditingController> _livePreviewControllers;

  @override
  void initState() {
    super.initState();
    _livePreviewControllers = [
      _addressController,
      _latController,
      _lngController,
      _geofenceController,
      _entryProtocolController,
      _mapUrlController,
      _nudgeController,
      _escalationController,
      _siteEndpointLabelController,
      _siteTelegramChatIdController,
      _siteTelegramThreadIdController,
    ];
    for (final controller in _livePreviewControllers) {
      controller.addListener(_handleLivePreviewInputChanged);
    }
    _siteNameController.addListener(_handleSiteNameInputChanged);
    _siteIdController.addListener(_handleSiteIdentityInputChanged);
    _siteCodeController.addListener(_handleSiteIdentityInputChanged);
  }

  void _handleLivePreviewInputChanged() {
    if (!mounted || _normalizingSiteIdentity) return;
    setState(() {});
  }

  void _handleSiteNameInputChanged() {
    if (!mounted) return;
    _syncIdentityFromName();
    setState(() {});
  }

  void _handleSiteIdentityInputChanged() {
    if (_normalizingSiteIdentity) return;
    final normalizedId = _normalizeIdentityToken(_siteIdController.text);
    final normalizedCode = _normalizeIdentityToken(_siteCodeController.text);
    final idChanged = normalizedId != _siteIdController.text;
    final codeChanged = normalizedCode != _siteCodeController.text;
    if (!idChanged && !codeChanged) return;
    _normalizingSiteIdentity = true;
    try {
      if (idChanged) {
        _siteIdController.value = TextEditingValue(
          text: normalizedId,
          selection: TextSelection.collapsed(offset: normalizedId.length),
        );
      }
      if (codeChanged) {
        _siteCodeController.value = TextEditingValue(
          text: normalizedCode,
          selection: TextSelection.collapsed(offset: normalizedCode.length),
        );
      }
    } finally {
      _normalizingSiteIdentity = false;
    }
  }

  String _normalizeIdentityToken(String raw) {
    return raw
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  void _syncIdentityFromName({
    bool force = false,
    bool includeId = true,
    bool includeCode = true,
  }) {
    final suggestedId = includeId
        ? _generateSiteIdFromName(_siteNameController.text)
        : '';
    final suggestedCode = includeCode
        ? _generateSiteCodeFromName(_siteNameController.text)
        : '';
    final currentId = _siteIdController.text.trim();
    final currentCode = _siteCodeController.text.trim();
    final shouldSetId =
        includeId &&
        suggestedId.isNotEmpty &&
        (force || currentId.isEmpty || currentId == (_lastAutoSiteId ?? ''));
    final shouldSetCode =
        includeCode &&
        suggestedCode.isNotEmpty &&
        (force ||
            currentCode.isEmpty ||
            currentCode == (_lastAutoSiteCode ?? ''));
    if (!shouldSetId && !shouldSetCode) return;
    _normalizingSiteIdentity = true;
    try {
      if (shouldSetId) {
        _siteIdController.value = TextEditingValue(
          text: suggestedId,
          selection: TextSelection.collapsed(offset: suggestedId.length),
        );
        _lastAutoSiteId = suggestedId;
      }
      if (shouldSetCode) {
        _siteCodeController.value = TextEditingValue(
          text: suggestedCode,
          selection: TextSelection.collapsed(offset: suggestedCode.length),
        );
        _lastAutoSiteCode = suggestedCode;
      }
    } finally {
      _normalizingSiteIdentity = false;
    }
  }

  @override
  void dispose() {
    for (final controller in _livePreviewControllers) {
      controller.removeListener(_handleLivePreviewInputChanged);
    }
    _siteNameController.removeListener(_handleSiteNameInputChanged);
    _siteIdController.removeListener(_handleSiteIdentityInputChanged);
    _siteCodeController.removeListener(_handleSiteIdentityInputChanged);
    _siteIdController.dispose();
    _siteNameController.dispose();
    _siteCodeController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _geofenceController.dispose();
    _entryProtocolController.dispose();
    _mapUrlController.dispose();
    _nudgeController.dispose();
    _escalationController.dispose();
    _siteEndpointLabelController.dispose();
    _siteTelegramChatIdController.dispose();
    _siteTelegramThreadIdController.dispose();
    super.dispose();
  }

  void _resetDemoPace() {
    setState(() => _sessionStartedAt = DateTime.now());
  }

  int _startFreshDemo() {
    var resetCount = 0;
    setState(() {
      if (_step != 0) {
        _step = 0;
        resetCount++;
      }
      if (_error != null) {
        _error = null;
        resetCount++;
      }
      if (_showCreatePulse) {
        _showCreatePulse = false;
        resetCount++;
      }
      _sessionStartedAt = DateTime.now();
      if (_siteIdController.text.trim().isNotEmpty) {
        _siteIdController.clear();
        resetCount++;
      }
      if (_siteNameController.text.trim().isNotEmpty) {
        _siteNameController.clear();
        resetCount++;
      }
      if (_siteCodeController.text.trim().isNotEmpty) {
        _siteCodeController.clear();
        resetCount++;
      }
      if (_addressController.text.trim().isNotEmpty) {
        _addressController.clear();
        resetCount++;
      }
      if (_latController.text.trim().isNotEmpty) {
        _latController.clear();
        resetCount++;
      }
      if (_lngController.text.trim().isNotEmpty) {
        _lngController.clear();
        resetCount++;
      }
      if (_entryProtocolController.text.trim().isNotEmpty) {
        _entryProtocolController.clear();
        resetCount++;
      }
      if (_mapUrlController.text.trim().isNotEmpty) {
        _mapUrlController.clear();
        resetCount++;
      }
      if (_geofenceController.text != '300') {
        _geofenceController.text = '300';
        resetCount++;
      }
      if (_riskProfile != 'residential') {
        _riskProfile = 'residential';
        resetCount++;
      }
      if (_nudgeController.text != '15') {
        _nudgeController.text = '15';
        resetCount++;
      }
      if (_escalationController.text != '2') {
        _escalationController.text = '2';
        resetCount++;
      }
      if (_enableSiteTelegramBridge) {
        _enableSiteTelegramBridge = false;
        resetCount++;
      }
      if (_siteEndpointLabelController.text.trim() != 'Primary Site Telegram') {
        _siteEndpointLabelController.text = 'Primary Site Telegram';
        resetCount++;
      }
      if (_siteTelegramChatIdController.text.trim().isNotEmpty) {
        _siteTelegramChatIdController.clear();
        resetCount++;
      }
      if (_siteTelegramThreadIdController.text.trim().isNotEmpty) {
        _siteTelegramThreadIdController.clear();
        resetCount++;
      }
      if (_lastAutoSiteId != null) {
        _lastAutoSiteId = null;
        resetCount++;
      }
      if (_lastAutoSiteCode != null) {
        _lastAutoSiteCode = null;
        resetCount++;
      }
      if (_appliedSiteScenario.isNotEmpty) {
        _appliedSiteScenario = '';
        resetCount++;
      }
    });
    return resetCount;
  }

  double get _completionScore {
    var score = 0;
    const total = 8;
    if (_clientId.trim().isNotEmpty) score++;
    if (_siteIdController.text.trim().isNotEmpty) score++;
    if (_siteNameController.text.trim().isNotEmpty) score++;
    if (_addressController.text.trim().isNotEmpty) score++;
    if (_riskProfile.trim().isNotEmpty) score++;
    final nudge = int.tryParse(_nudgeController.text.trim()) ?? 0;
    if (nudge > 0) score++;
    final escalation = int.tryParse(_escalationController.text.trim()) ?? 0;
    if (escalation > 0) score++;
    if (!_enableSiteTelegramBridge ||
        _siteTelegramChatIdController.text.trim().isNotEmpty) {
      score++;
    }
    return score / total;
  }

  List<String> get _previewLines {
    final siteId = _siteIdController.text.trim().isEmpty
        ? 'Pending'
        : _siteIdController.text.trim().toUpperCase();
    final siteName = _siteNameController.text.trim().isEmpty
        ? 'Pending site name'
        : _siteNameController.text.trim();
    final location = _addressController.text.trim().isEmpty
        ? 'Pending address'
        : _addressController.text.trim();
    final messaging = _enableSiteTelegramBridge
        ? (_siteTelegramChatIdController.text.trim().isEmpty
              ? 'Telegram lane pending chat ID'
              : 'Telegram lane ${_siteTelegramChatIdController.text.trim()}')
        : 'Use client default messaging lane';
    return [
      'Site: $siteId • $siteName',
      'Client Link: $_clientId',
      'Risk Profile: ${_riskProfile.replaceAll('_', ' ')}',
      'Location: $location',
      'Messaging: $messaging',
    ];
  }

  List<_PreviewGate> get _previewGates {
    final hasIdentity =
        _siteIdController.text.trim().isNotEmpty &&
        _siteNameController.text.trim().isNotEmpty;
    final hasAddress = _addressController.text.trim().isNotEmpty;
    final hasCoordinates =
        double.tryParse(_latController.text.trim()) != null &&
        double.tryParse(_lngController.text.trim()) != null;
    final hasRiskProfile = _riskProfile.trim().isNotEmpty;
    final hasAutomationValues =
        (int.tryParse(_nudgeController.text.trim()) ?? 0) > 0 &&
        (int.tryParse(_escalationController.text.trim()) ?? 0) > 0;
    final hasMessagingLane =
        !_enableSiteTelegramBridge ||
        _siteTelegramChatIdController.text.trim().isNotEmpty;
    return [
      _PreviewGate(label: 'Site Identity', ready: hasIdentity, step: 0),
      _PreviewGate(label: 'Address', ready: hasAddress, step: 1),
      _PreviewGate(label: 'Geo Pins', ready: hasCoordinates, step: 1),
      _PreviewGate(label: 'Risk Profile', ready: hasRiskProfile, step: 2),
      _PreviewGate(
        label: 'Automation Timers',
        ready: hasAutomationValues,
        step: 2,
      ),
      _PreviewGate(label: 'Messaging Lane', ready: hasMessagingLane, step: 2),
    ];
  }

  bool get _allGatesReady => _previewGates.every((gate) => gate.ready);

  int? get _nextIncompleteStep {
    for (final gate in _previewGates) {
      if (!gate.ready) return gate.step;
    }
    return null;
  }

  Map<String, dynamic> get _payloadPreview {
    return {
      'site_id': _siteIdController.text.trim().toUpperCase(),
      'client_id': _clientId,
      'site_name': _siteNameController.text.trim(),
      'site_code': _siteCodeController.text.trim().toUpperCase(),
      'physical_address': _addressController.text.trim(),
      'latitude': double.tryParse(_latController.text.trim()),
      'longitude': double.tryParse(_lngController.text.trim()),
      'geofence_radius_meters': int.tryParse(_geofenceController.text.trim()),
      'entry_protocol': _entryProtocolController.text.trim(),
      'site_layout_map_url': _mapUrlController.text.trim(),
      'risk_profile': _riskProfile,
      'guard_nudge_frequency_minutes': int.tryParse(
        _nudgeController.text.trim(),
      ),
      'escalation_trigger_minutes': int.tryParse(
        _escalationController.text.trim(),
      ),
    };
  }

  void _applyRiskDefaults(String profile) {
    _nudgeController.text = _recommendedNudgeMinutesForProfile(
      profile,
    ).toString();
    _escalationController.text = _recommendedEscalationMinutesForProfile(
      profile,
    ).toString();
  }

  int _recommendedNudgeMinutesForProfile(String profile) {
    switch (profile) {
      case 'industrial':
        return 10;
      case 'residential':
        return 15;
      case 'commercial':
      case 'mixed_use':
      default:
        return 12;
    }
  }

  int _recommendedEscalationMinutesForProfile(String profile) {
    switch (profile) {
      case 'industrial':
        return 1;
      case 'residential':
      case 'commercial':
      case 'mixed_use':
      default:
        return 2;
    }
  }

  bool _validateStep() {
    setState(() => _error = null);
    if (_step == 0) {
      if (_siteIdController.text.trim().isEmpty) {
        setState(() => _error = 'Site ID is required.');
        return false;
      }
      if (_siteNameController.text.trim().isEmpty) {
        setState(() => _error = 'Site name is required.');
        return false;
      }
    }
    if (_step == 1) {
      if (_addressController.text.trim().isEmpty) {
        setState(() => _error = 'Site address is required.');
        return false;
      }
    }
    if (_step == 2) {
      final nudge = int.tryParse(_nudgeController.text.trim());
      final escalation = int.tryParse(_escalationController.text.trim());
      if (nudge == null ||
          nudge <= 0 ||
          escalation == null ||
          escalation <= 0) {
        setState(
          () => _error = 'Nudge and escalation values must be positive.',
        );
        return false;
      }
      if (_enableSiteTelegramBridge &&
          _siteTelegramChatIdController.text.trim().isEmpty) {
        setState(() => _error = 'Telegram chat ID is required for site lane.');
        return false;
      }
      if (_enableSiteTelegramBridge &&
          _siteEndpointLabelController.text.trim().isEmpty) {
        setState(
          () => _error = 'Messaging endpoint label is required for site lane.',
        );
        return false;
      }
      final threadRaw = _siteTelegramThreadIdController.text.trim();
      if (_enableSiteTelegramBridge &&
          threadRaw.isNotEmpty &&
          int.tryParse(threadRaw) == null) {
        setState(
          () => _error = 'Telegram thread ID must be numeric when provided.',
        );
        return false;
      }
    }
    return true;
  }

  void _next() async {
    if (!_validateStep()) return;
    if (_showCreatePulse) {
      setState(() => _showCreatePulse = false);
    }
    if (_step < 2) {
      setState(() => _step += 1);
      return;
    }
    if (!_allGatesReady) {
      final proceed = await _confirmIncompleteReadiness(
        context,
        entityLabel: 'Site',
        gates: _previewGates,
        accent: const Color(0xFF0E8B8F),
      );
      if (!proceed) {
        final target = _nextIncompleteStep;
        if (target != null && mounted) {
          setState(() => _step = target);
        }
        return;
      }
    }
    await _playCreatePulse();
    if (!mounted) return;
    Navigator.of(context).pop(
      _SiteOnboardingDraft(
        siteId: _siteIdController.text.trim().toUpperCase(),
        clientId: _clientId,
        siteName: _siteNameController.text.trim(),
        siteCode: _siteCodeController.text.trim().toUpperCase(),
        address: _addressController.text.trim(),
        latitude: double.tryParse(_latController.text.trim()),
        longitude: double.tryParse(_lngController.text.trim()),
        geofenceRadiusMeters:
            int.tryParse(_geofenceController.text.trim()) ?? 300,
        entryProtocol: _entryProtocolController.text.trim(),
        siteLayoutMapUrl: _mapUrlController.text.trim(),
        riskProfile: _riskProfile,
        guardNudgeFrequencyMinutes:
            int.tryParse(_nudgeController.text.trim()) ?? 12,
        escalationTriggerMinutes:
            int.tryParse(_escalationController.text.trim()) ?? 2,
        enableTelegramBridge: _enableSiteTelegramBridge,
        messagingEndpointLabel: _siteEndpointLabelController.text.trim(),
        telegramChatId: _siteTelegramChatIdController.text.trim(),
        telegramThreadId: _siteTelegramThreadIdController.text.trim(),
      ),
    );
  }

  Future<void> _playCreatePulse() async {
    if (!mounted) return;
    setState(() => _showCreatePulse = true);
    await Future<void>.delayed(const Duration(milliseconds: 520));
  }

  void _applyDemoTemplate() {
    _applySiteScenario(_selectedSiteScenario);
  }

  String _launchDemoFlow() {
    _applyDemoTemplate();
    return '${_siteScenarioLabel(_selectedSiteScenario)} demo loaded. ${_recoverDemoPace()}';
  }

  String _siteScenarioLabel(String scenario) {
    switch (scenario) {
      case 'residential_estate':
        return 'Estate';
      case 'retail_centre':
        return 'Retail';
      case 'industrial_yard':
      default:
        return 'Industrial';
    }
  }

  int _autoFillMissingForDemo() {
    final stamp = DateTime.now().millisecondsSinceEpoch % 10000;
    final scenario = _selectedSiteScenario;
    String defaultSiteName = 'North Gate Tactical Perimeter';
    String defaultSiteCode = 'NGATE-$stamp';
    String defaultAddress =
        '11 Granite Drive, North Riding, Johannesburg, 2162';
    String defaultLat = '-26.0601';
    String defaultLng = '27.9717';
    String defaultMapUrl =
        'https://cdn.onyx.local/site-layouts/demo-north-gate.pdf';
    String preferredRisk = 'industrial';
    switch (scenario) {
      case 'residential_estate':
        defaultSiteName = 'Blue Ridge Estate Perimeter';
        defaultSiteCode = 'ESTATE-$stamp';
        defaultAddress = '4 Willow Crescent, Fourways, Johannesburg, 2191';
        defaultLat = '-26.0214';
        defaultLng = '28.0064';
        defaultMapUrl =
            'https://cdn.onyx.local/site-layouts/demo-estate-perimeter.pdf';
        preferredRisk = 'residential';
        break;
      case 'retail_centre':
        defaultSiteName = 'Harbor Point Retail Complex';
        defaultSiteCode = 'MALL-$stamp';
        defaultAddress = '55 Marine Drive, Umhlanga, KwaZulu-Natal, 4319';
        defaultLat = '-29.7265';
        defaultLng = '31.0849';
        defaultMapUrl =
            'https://cdn.onyx.local/site-layouts/demo-retail-complex.pdf';
        preferredRisk = 'commercial';
        break;
      case 'industrial_yard':
      default:
        break;
    }
    final recommendedGeofence = _recommendedGeofenceMetersForProfile(
      preferredRisk,
    );
    final recommendedNudge = _recommendedNudgeMinutesForProfile(preferredRisk);
    final recommendedEscalation = _recommendedEscalationMinutesForProfile(
      preferredRisk,
    );
    final protocolTemplate = _recommendedProtocolForProfile(preferredRisk);
    var filledCount = 0;
    setState(() {
      if (_siteNameController.text.trim().isEmpty) {
        _siteNameController.text = defaultSiteName;
        filledCount++;
      }
      if (_siteIdController.text.trim().isEmpty) {
        final generated = _generateSiteIdFromName(_siteNameController.text);
        _siteIdController.text = generated.isEmpty
            ? 'DEMO-SITE-$stamp'
            : generated;
        filledCount++;
      }
      if (_siteCodeController.text.trim().isEmpty) {
        final generated = _generateSiteCodeFromName(defaultSiteName);
        _siteCodeController.text = generated.isEmpty
            ? defaultSiteCode
            : generated;
        filledCount++;
      }
      if (_addressController.text.trim().isEmpty) {
        _addressController.text = defaultAddress;
        filledCount++;
      }
      if (_latController.text.trim().isEmpty) {
        _latController.text = defaultLat;
        filledCount++;
      }
      if (_lngController.text.trim().isEmpty) {
        _lngController.text = defaultLng;
        filledCount++;
      }
      if (_riskProfile == 'residential' && preferredRisk != 'residential') {
        _riskProfile = preferredRisk;
        filledCount++;
      }
      if (_geofenceController.text.trim().isEmpty ||
          (int.tryParse(_geofenceController.text.trim()) ?? 0) <= 0) {
        _geofenceController.text = recommendedGeofence.toString();
        filledCount++;
      }
      if (_entryProtocolController.text.trim().isEmpty) {
        _entryProtocolController.text = protocolTemplate;
        filledCount++;
      }
      if (_mapUrlController.text.trim().isEmpty) {
        _mapUrlController.text = defaultMapUrl;
        filledCount++;
      }
      if ((int.tryParse(_nudgeController.text.trim()) ?? 0) <= 0) {
        _nudgeController.text = recommendedNudge.toString();
        filledCount++;
      }
      if ((int.tryParse(_escalationController.text.trim()) ?? 0) <= 0) {
        _escalationController.text = recommendedEscalation.toString();
        filledCount++;
      }
    });
    return filledCount;
  }

  String _sitePitchText() {
    final siteName = _siteNameController.text.trim().isEmpty
        ? 'this site'
        : _siteNameController.text.trim();
    final geofence =
        int.tryParse(_geofenceController.text.trim()) ??
        _recommendedGeofenceMetersForProfile(_riskProfile);
    final nudge =
        int.tryParse(_nudgeController.text.trim()) ??
        _recommendedNudgeMinutesForProfile(_riskProfile);
    final escalation =
        int.tryParse(_escalationController.text.trim()) ??
        _recommendedEscalationMinutesForProfile(_riskProfile);
    final profileLabel = _riskProfile.replaceAll('_', ' ');
    return 'ONYX has configured $siteName with a $profileLabel risk posture. '
        'The live footprint is locked to a ${geofence}m geofence, with guard nudge cadence at $nudge minutes and escalation at $escalation minutes for deterministic response discipline.';
  }

  String _runDemoReady() {
    final filledCount = _autoFillMissingForDemo();
    final target = _nextIncompleteStep;
    if (target != null) {
      setState(() => _step = target);
      return filledCount <= 0
          ? 'Complete Step ${target + 1} to finish site readiness.'
          : '$filledCount fields auto-filled. Continue on Step ${target + 1}.';
    }
    setState(() => _step = 2);
    return filledCount <= 0
        ? 'Already demo-ready for site onboarding.'
        : 'Site onboarding demo-ready with $filledCount fields auto-filled.';
  }

  String _recoverDemoPace() {
    setState(() => _sessionStartedAt = DateTime.now());
    final readiness = _runDemoReady();
    return 'Demo pace reset. $readiness';
  }

  String get _demoReadyButtonLabel {
    final readyCount = _previewGates.where((gate) => gate.ready).length;
    final total = _previewGates.length;
    if (total > 0 && readyCount == total) {
      return 'Demo Ready ✓';
    }
    return 'Demo Ready $readyCount/$total';
  }

  IconData get _demoReadyButtonIcon =>
      _allGatesReady ? Icons.task_alt_rounded : Icons.bolt_rounded;

  Color get _demoReadyButtonColor =>
      _allGatesReady ? const Color(0xFF0F766E) : const Color(0xFF0E8B8F);

  bool get _siteTemplatePending =>
      _selectedSiteScenario != _appliedSiteScenario;

  String _siteSnapshotText() {
    final readyCount = _previewGates.where((gate) => gate.ready).length;
    final gateTotal = _previewGates.length;
    final completionPct = (_completionScore.clamp(0.0, 1.0) * 100).round();
    final nextGap = _nextIncompleteStep;
    return 'Site Demo Snapshot\n'
        'Scenario: ${_siteScenarioLabel(_selectedSiteScenario)}\n'
        'Template: ${_siteTemplatePending ? 'Pending apply' : 'Applied'}\n'
        'Progress: Step ${_step + 1}/3\n'
        'Readiness: $readyCount/$gateTotal\n'
        'Completion: $completionPct%\n'
        'Next Gap: ${nextGap == null ? 'None' : 'Step ${nextGap + 1}'}\n'
        '${_previewLines.join('\n')}';
  }

  void _applySiteScenario(String scenario) {
    final stamp = DateTime.now().millisecondsSinceEpoch % 10000;
    setState(() {
      _selectedSiteScenario = scenario;
      _appliedSiteScenario = scenario;
      switch (scenario) {
        case 'residential_estate':
          _siteIdController.text = 'DEMO-SITE-R$stamp';
          _siteNameController.text = 'Blue Ridge Estate Perimeter';
          _siteCodeController.text = 'ESTATE-$stamp';
          _addressController.text =
              '4 Willow Crescent, Fourways, Johannesburg, 2191';
          _latController.text = '-26.0214';
          _lngController.text = '28.0064';
          _geofenceController.text = '300';
          _entryProtocolController.text =
              'Main gate intercom to estate control. Visitor lane after ID verification.';
          _mapUrlController.text =
              'https://cdn.onyx.local/site-layouts/demo-estate-perimeter.pdf';
          _riskProfile = 'residential';
          break;
        case 'retail_centre':
          _siteIdController.text = 'DEMO-SITE-M$stamp';
          _siteNameController.text = 'Harbor Point Retail Complex';
          _siteCodeController.text = 'MALL-$stamp';
          _addressController.text =
              '55 Marine Drive, Umhlanga, KwaZulu-Natal, 4319';
          _latController.text = '-29.7265';
          _lngController.text = '31.0849';
          _geofenceController.text = '380';
          _entryProtocolController.text =
              'Service gate code via supervisor. Parking deck patrol route every 20 minutes.';
          _mapUrlController.text =
              'https://cdn.onyx.local/site-layouts/demo-retail-complex.pdf';
          _riskProfile = 'commercial';
          break;
        case 'industrial_yard':
        default:
          _siteIdController.text = 'DEMO-SITE-$stamp';
          _siteNameController.text = 'North Gate Tactical Perimeter';
          _siteCodeController.text = 'NGATE-$stamp';
          _addressController.text =
              '11 Granite Drive, North Riding, Johannesburg, 2162';
          _latController.text = '-26.0601';
          _lngController.text = '27.9717';
          _geofenceController.text = '450';
          _entryProtocolController.text =
              'Gate intercom to control room. Pin + radio call after 22:00.';
          _mapUrlController.text =
              'https://cdn.onyx.local/site-layouts/demo-north-gate.pdf';
          _riskProfile = 'industrial';
          break;
      }
      _applyRiskDefaults(_riskProfile);
    });
  }

  String _generateSiteIdFromName(String rawName) {
    final normalized = rawName
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    if (normalized.isEmpty) return '';
    return 'SITE-$normalized';
  }

  String _generateSiteCodeFromName(String rawName) {
    final tokens = rawName
        .trim()
        .toUpperCase()
        .split(RegExp(r'[^A-Z0-9]+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) return '';
    final compact = tokens
        .take(3)
        .map((token) => token.length <= 4 ? token : token.substring(0, 4))
        .join('-');
    return compact;
  }

  String _resolvedPreviewReference() {
    final siteId = _siteIdController.text.trim().toUpperCase();
    if (siteId.isNotEmpty) return siteId;
    final suggestedSiteId = _generateSiteIdFromName(_siteNameController.text);
    if (suggestedSiteId.isNotEmpty) return suggestedSiteId;
    final siteCode = _siteCodeController.text.trim().toUpperCase();
    if (siteCode.isNotEmpty) return 'SITE-$siteCode';
    final hasCoords =
        double.tryParse(_latController.text.trim()) != null &&
        double.tryParse(_lngController.text.trim()) != null;
    if (hasCoords) return 'SITE-TACTICAL-PREVIEW';
    return '';
  }

  void _openTacticalPreview() {
    final openTactical = widget.onOpenTacticalForIncident;
    if (openTactical == null) {
      _showOnboardingSnackBar(context, 'Tactical view navigation unavailable.');
      return;
    }
    final focusReference = _resolvedPreviewReference();
    if (focusReference.isEmpty) {
      _showOnboardingSnackBar(
        context,
        'Add site identity or coordinates before opening Tactical.',
      );
      return;
    }
    Navigator.of(context).pop();
    openTactical.call(focusReference);
  }

  void _openOperationsPreview() {
    final openOperations = widget.onOpenOperationsForIncident;
    if (openOperations == null) {
      _showOnboardingSnackBar(
        context,
        'Operations view navigation unavailable.',
      );
      return;
    }
    final focusReference = _resolvedPreviewReference();
    if (focusReference.isEmpty) {
      _showOnboardingSnackBar(
        context,
        'Add site identity or coordinates before opening Operations.',
      );
      return;
    }
    Navigator.of(context).pop();
    openOperations.call(focusReference);
  }

  Widget _siteIdentitySuggestionStrip() {
    final suggestedId = _generateSiteIdFromName(_siteNameController.text);
    final suggestedCode = _generateSiteCodeFromName(_siteNameController.text);
    final idReady = suggestedId.isNotEmpty;
    final codeReady = suggestedCode.isNotEmpty;
    final idAlreadyApplied =
        idReady && _siteIdController.text.trim() == suggestedId;
    final codeAlreadyApplied =
        codeReady && _siteCodeController.text.trim() == suggestedCode;
    final canApplyAny =
        (idReady && !idAlreadyApplied) || (codeReady && !codeAlreadyApplied);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: (idReady || codeReady) ? 1 : 0.55,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: const Color(0xFF101A25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF36506D)),
        ),
        child: Wrap(
          spacing: 7,
          runSpacing: 7,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _identitySuggestionChip(
              label: 'Suggested ID',
              value: idReady ? suggestedId : 'Type Site Name',
              ready: idReady,
            ),
            _identitySuggestionChip(
              label: 'Suggested Code',
              value: codeReady ? suggestedCode : 'Type Site Name',
              ready: codeReady,
            ),
            OutlinedButton.icon(
              onPressed: canApplyAny
                  ? () => setState(() => _syncIdentityFromName(force: true))
                  : null,
              icon: const Icon(Icons.auto_fix_high_rounded, size: 14),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFBFE6FF),
                side: const BorderSide(color: Color(0xFF4C6683)),
                backgroundColor: const Color(0xFF111A24),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                minimumSize: const Size(0, 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              label: Text(
                'Apply Suggestions',
                style: GoogleFonts.inter(
                  fontSize: 10.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _identitySuggestionChip({
    required String label,
    required String value,
    required bool ready,
  }) {
    final accent = ready ? const Color(0xFF38BDF8) : const Color(0xFF6B7F96);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.65)),
      ),
      child: Text(
        '$label: $value',
        style: GoogleFonts.inter(
          color: const Color(0xFFEAF4FF),
          fontSize: 10.4,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _riskProfileOptionTile({
    required String keyValue,
    required String label,
    required String detail,
    required String timerHint,
  }) {
    final selected = _riskProfile == keyValue;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        setState(() {
          _riskProfile = keyValue;
          _applyRiskDefaults(keyValue);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: 222,
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0x3322D3EE), Color(0x2234D399)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : const Color(0xFF111A24),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF67C5FF) : const Color(0xFF4C6683),
            width: selected ? 1.3 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  selected ? Icons.task_alt_rounded : Icons.radio_button_off,
                  size: 14,
                  color: selected
                      ? const Color(0xFF7EF2C3)
                      : const Color(0xFF9AB1CF),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFEAF4FF),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              style: GoogleFonts.inter(
                color: const Color(0xFFBFD7F2),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              timerHint,
              style: GoogleFonts.inter(
                color: const Color(0xFF9FD6FF),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coordinatePresetStrip() {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        _coordinatePresetChip(label: 'Sandton', lat: -26.1076, lng: 28.0567),
        _coordinatePresetChip(label: 'Midrand', lat: -26.0010, lng: 28.1262),
        _coordinatePresetChip(
          label: 'North Riding',
          lat: -26.0557,
          lng: 27.9504,
        ),
        _coordinatePresetChip(label: 'Umhlanga', lat: -29.7265, lng: 31.0849),
      ],
    );
  }

  Widget _coordinatePresetChip({
    required String label,
    required double lat,
    required double lng,
  }) {
    final currentLat = double.tryParse(_latController.text.trim());
    final currentLng = double.tryParse(_lngController.text.trim());
    final selected =
        currentLat != null &&
        currentLng != null &&
        (currentLat - lat).abs() < 0.0002 &&
        (currentLng - lng).abs() < 0.0002;
    return ChoiceChip(
      selected: selected,
      label: Text(
        label,
        style: GoogleFonts.inter(
          color: const Color(0xFFEAF4FF),
          fontSize: 10.6,
          fontWeight: FontWeight.w700,
        ),
      ),
      selectedColor: const Color(0x3338BDF8),
      backgroundColor: const Color(0xFF111A24),
      side: BorderSide(
        color: selected ? const Color(0xFF38BDF8) : const Color(0xFF4C6683),
      ),
      onSelected: (_) => setState(() {
        _latController.text = lat.toStringAsFixed(4);
        _lngController.text = lng.toStringAsFixed(4);
      }),
    );
  }

  Widget _geofencePresetStrip() {
    final current = int.tryParse(_geofenceController.text.trim());
    final recommended = _recommendedGeofenceMetersForProfile(_riskProfile);
    const presets = <int>[200, 300, 450, 600];
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final preset in presets)
          ChoiceChip(
            selected: current == preset,
            label: Text(
              '${preset}m',
              style: GoogleFonts.inter(
                color: const Color(0xFFEAF4FF),
                fontSize: 10.6,
                fontWeight: FontWeight.w700,
              ),
            ),
            selectedColor: const Color(0x3334D399),
            backgroundColor: const Color(0xFF111A24),
            side: BorderSide(
              color: current == preset
                  ? const Color(0xFF34D399)
                  : const Color(0xFF4C6683),
            ),
            onSelected: (_) =>
                setState(() => _geofenceController.text = preset.toString()),
          ),
        OutlinedButton.icon(
          onPressed: () =>
              setState(() => _geofenceController.text = recommended.toString()),
          icon: const Icon(Icons.tune_rounded, size: 14),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFBFE6FF),
            side: const BorderSide(color: Color(0xFF4C6683)),
            backgroundColor: const Color(0xFF111A24),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            minimumSize: const Size(0, 32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          label: Text(
            'Risk Default (${recommended}m)',
            style: GoogleFonts.inter(
              fontSize: 10.6,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  int _recommendedGeofenceMetersForProfile(String profile) {
    switch (profile) {
      case 'industrial':
        return 450;
      case 'commercial':
        return 380;
      case 'mixed_use':
        return 400;
      case 'residential':
      default:
        return 300;
    }
  }

  String _recommendedProtocolForProfile(String profile) {
    switch (profile) {
      case 'industrial':
        return 'Gate intercom to control room. Pin + radio call after 22:00.';
      case 'commercial':
        return 'Service gate code via supervisor. Parking deck patrol route every 20 minutes.';
      case 'mixed_use':
        return 'Main gate intercom to control room. Visitor lane after ID verification.';
      case 'residential':
      default:
        return 'Main gate intercom to control room. Visitor lane after ID verification.';
    }
  }

  void _applyRiskOpsPack() {
    final recommendedGeofence = _recommendedGeofenceMetersForProfile(
      _riskProfile,
    );
    final protocolTemplate = _recommendedProtocolForProfile(_riskProfile);
    setState(() {
      _geofenceController.text = recommendedGeofence.toString();
      _entryProtocolController.text = protocolTemplate;
      if (_mapUrlController.text.trim().isEmpty) {
        _mapUrlController.text = _suggestedLayoutMapUrl();
      }
    });
  }

  Widget _entryProtocolTemplateStrip() {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        _protocolTemplateChip(
          label: 'Estate Gate',
          template:
              'Main gate intercom to control room. Visitor lane after ID verification.',
        ),
        _protocolTemplateChip(
          label: 'Industrial Night',
          template:
              'Gate intercom to control room. Pin + radio call after 22:00.',
        ),
        _protocolTemplateChip(
          label: 'Retail Service',
          template:
              'Service gate code via supervisor. Parking deck patrol route every 20 minutes.',
        ),
      ],
    );
  }

  Widget _protocolTemplateChip({
    required String label,
    required String template,
  }) {
    final selected = _entryProtocolController.text.trim() == template;
    return ChoiceChip(
      selected: selected,
      label: Text(
        label,
        style: GoogleFonts.inter(
          color: const Color(0xFFEAF4FF),
          fontSize: 10.6,
          fontWeight: FontWeight.w700,
        ),
      ),
      selectedColor: const Color(0x3334D399),
      backgroundColor: const Color(0xFF111A24),
      side: BorderSide(
        color: selected ? const Color(0xFF34D399) : const Color(0xFF4C6683),
      ),
      onSelected: (_) =>
          setState(() => _entryProtocolController.text = template),
    );
  }

  String _suggestedLayoutMapUrl() {
    final rawSiteId = _siteIdController.text.trim().toLowerCase();
    final normalized = rawSiteId.isEmpty
        ? 'site-layout'
        : rawSiteId.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final clean = normalized
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final slug = clean.isEmpty ? 'site-layout' : clean;
    return 'https://cdn.onyx.local/site-layouts/$slug.pdf';
  }

  String _locationIntegrityNarrative({
    required int readyCount,
    required int? geofence,
    required int recommended,
    required bool geofenceInRange,
    required bool geofenceAligned,
    required bool entryProtocolReady,
    required bool mapReady,
  }) {
    if (readyCount >= 5) {
      return 'Location pack is deployment-ready. Geofence aligns with risk baseline and map evidence link is valid.';
    }
    if (!geofenceInRange) {
      return 'Set geofence between 150m and 1000m to keep dispatch boundaries stable.';
    }
    if (!geofenceAligned) {
      return 'Current geofence (${geofence ?? 'unset'}m) drifts from risk baseline (${recommended}m). Apply Risk Default unless SLA requires override.';
    }
    if (!entryProtocolReady) {
      return 'Entry protocol needs more detail (gate flow, auth method, after-hours fallback).';
    }
    if (!mapReady) {
      return 'Layout map should be a valid http/https URL so field teams can open baseline plans instantly.';
    }
    return 'Complete remaining location fields to lock geospatial integrity for incident verification.';
  }

  Widget _locationIntegrityCard() {
    final hasAddress = _addressController.text.trim().isNotEmpty;
    final hasCoords =
        double.tryParse(_latController.text.trim()) != null &&
        double.tryParse(_lngController.text.trim()) != null;
    final recommended = _recommendedGeofenceMetersForProfile(_riskProfile);
    final geofence = int.tryParse(_geofenceController.text.trim());
    final geofenceInRange =
        geofence != null && geofence >= 150 && geofence <= 1000;
    final geofenceAligned =
        geofence != null && (geofence - recommended).abs() <= 200;
    final geofenceHealthy = geofenceInRange && geofenceAligned;
    final entryProtocolText = _entryProtocolController.text.trim();
    final hasEntryProtocol = entryProtocolText.length >= 16;
    final mapUrlRaw = _mapUrlController.text.trim();
    final parsedMapUrl = Uri.tryParse(mapUrlRaw);
    final hasMap =
        parsedMapUrl != null &&
        (parsedMapUrl.scheme == 'http' || parsedMapUrl.scheme == 'https') &&
        parsedMapUrl.host.isNotEmpty;
    final readyCount = [
      hasAddress,
      hasCoords,
      geofenceHealthy,
      hasEntryProtocol,
      hasMap,
    ].where((value) => value).length;
    final accent = readyCount >= 4
        ? const Color(0xFF22C55E)
        : (readyCount >= 2 ? const Color(0xFF38BDF8) : const Color(0xFFF97316));
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1621),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.place_rounded, size: 15, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Location Integrity',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEAF4FF),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$readyCount/5 ready',
                style: GoogleFonts.inter(
                  color: const Color(0xFFCEE4FA),
                  fontSize: 10.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _integrityPill(label: 'Address', ready: hasAddress),
              _integrityPill(label: 'Geo Pins', ready: hasCoords),
              _integrityPill(
                label: 'Geofence',
                ready: geofenceHealthy,
                value: geofence == null ? null : '${geofence}m',
              ),
              _integrityPill(label: 'Entry Protocol', ready: hasEntryProtocol),
              _integrityPill(label: 'Layout Map', ready: hasMap),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            _locationIntegrityNarrative(
              readyCount: readyCount,
              geofence: geofence,
              recommended: recommended,
              geofenceInRange: geofenceInRange,
              geofenceAligned: geofenceAligned,
              entryProtocolReady: hasEntryProtocol,
              mapReady: hasMap,
            ),
            style: GoogleFonts.inter(
              color: const Color(0xFFCEE4FA),
              fontSize: 10.6,
              fontWeight: FontWeight.w600,
              height: 1.28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tacticalFootprintCard() {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    final hasCoords = lat != null && lng != null;
    final geofenceMeters =
        int.tryParse(_geofenceController.text.trim()) ??
        _recommendedGeofenceMetersForProfile(_riskProfile);
    final accent = _riskProfileAccent(_riskProfile);
    const minLat = -35.0;
    const maxLat = -22.0;
    const minLng = 16.0;
    const maxLng = 33.0;
    final resolvedLat = lat ?? ((minLat + maxLat) / 2);
    final resolvedLng = lng ?? ((minLng + maxLng) / 2);
    final normalizedLng = hasCoords
        ? ((resolvedLng - minLng) / (maxLng - minLng)).clamp(0.0, 1.0)
        : 0.5;
    final normalizedLat = hasCoords
        ? ((resolvedLat - minLat) / (maxLat - minLat)).clamp(0.0, 1.0)
        : 0.5;
    final markerAlignment = Alignment(
      ((normalizedLng * 2) - 1).clamp(-0.72, 0.72),
      (((1 - normalizedLat) * 2) - 1).clamp(-0.72, 0.72),
    );
    final ringRadius = (26 * (geofenceMeters / 450)).clamp(16.0, 54.0);
    final latLabel = hasCoords ? resolvedLat.toStringAsFixed(4) : 'Pending';
    final lngLabel = hasCoords ? resolvedLng.toStringAsFixed(4) : 'Pending';
    final statusLabel = hasCoords ? 'GPS locked' : 'Awaiting coordinates';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1722),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.78)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.map_rounded, size: 15, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Tactical Footprint',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEAF4FF),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withValues(alpha: 0.7)),
                ),
                child: Text(
                  _riskProfile.replaceAll('_', ' ').toUpperCase(),
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEAF4FF),
                    fontSize: 10.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          AspectRatio(
            aspectRatio: 1.9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF071019), Color(0xFF102235)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _TacticalMapGridPainter(accent: accent),
                    ),
                  ),
                  Align(
                    alignment: markerAlignment,
                    child: Container(
                      width: ringRadius * 2,
                      height: ringRadius * 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: 0.11),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.85),
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: markerAlignment,
                    child: Container(
                      width: math.max(10.0, ringRadius * 0.36),
                      height: math.max(10.0, ringRadius * 0.36),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF7EF2C3),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x5522D3EE),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _integrityPill(label: 'Lat', ready: hasCoords, value: latLabel),
              _integrityPill(label: 'Lng', ready: hasCoords, value: lngLabel),
              _integrityPill(
                label: 'Geofence',
                ready: geofenceMeters > 0,
                value: '${geofenceMeters}m',
              ),
              _integrityPill(
                label: 'Status',
                ready: hasCoords,
                value: statusLabel,
              ),
            ],
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              OutlinedButton.icon(
                onPressed: widget.onOpenTacticalForIncident == null
                    ? null
                    : _openTacticalPreview,
                icon: const Icon(Icons.map_rounded, size: 14),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF9FE8FF),
                  side: BorderSide(color: accent.withValues(alpha: 0.75)),
                  backgroundColor: const Color(0xFF111A24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                label: Text(
                  'Open Tactical',
                  style: GoogleFonts.inter(
                    fontSize: 10.6,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: widget.onOpenOperationsForIncident == null
                    ? null
                    : _openOperationsPreview,
                icon: const Icon(Icons.space_dashboard_rounded, size: 14),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFBFD7F2),
                  side: const BorderSide(color: Color(0xFF35506F)),
                  backgroundColor: const Color(0xFF111A24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                label: Text(
                  'Open Operations',
                  style: GoogleFonts.inter(
                    fontSize: 10.6,
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

  Widget _integrityPill({
    required String label,
    required bool ready,
    String? value,
  }) {
    final accent = ready ? const Color(0xFF34D399) : const Color(0xFFF97316);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.65)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ready ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            size: 12.5,
            color: ready ? const Color(0xFF7EF2C3) : const Color(0xFFFFD29A),
          ),
          const SizedBox(width: 5),
          Text(
            value == null ? label : '$label: $value',
            style: GoogleFonts.inter(
              color: const Color(0xFFEAF4FF),
              fontSize: 10.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _riskOutcomePreviewCard() {
    final accent = _riskProfileAccent(_riskProfile);
    final nudge = int.tryParse(_nudgeController.text.trim());
    final escalation = int.tryParse(_escalationController.text.trim());
    final nudgeLabel = nudge == null || nudge <= 0 ? 'Unset' : '$nudge min';
    final escalationLabel = escalation == null || escalation <= 0
        ? 'Unset'
        : '$escalation min';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.28), const Color(0xFF0F1722)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.radar_rounded, size: 15, color: accent),
              const SizedBox(width: 6),
              Text(
                'Operational Outcome',
                style: GoogleFonts.inter(
                  color: const Color(0xFFEAF4FF),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            _riskProfileNarrative(_riskProfile),
            style: GoogleFonts.inter(
              color: const Color(0xFFCEE4FA),
              fontSize: 10.8,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _riskMetricChip(
                icon: Icons.shield_rounded,
                label: 'Profile',
                value: _riskProfile.replaceAll('_', ' ').toUpperCase(),
                accent: accent,
              ),
              _riskMetricChip(
                icon: Icons.notifications_active_rounded,
                label: 'Nudge',
                value: nudgeLabel,
                accent: accent,
              ),
              _riskMetricChip(
                icon: Icons.warning_amber_rounded,
                label: 'Escalation',
                value: escalationLabel,
                accent: accent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _riskResponseSimulatorCard() {
    final nudge = int.tryParse(_nudgeController.text.trim());
    final escalation = int.tryParse(_escalationController.text.trim());
    final valid = (nudge ?? 0) > 0 && (escalation ?? 0) > 0;
    final cadenceTier = _riskCadenceTierLabel(
      nudge: nudge,
      escalation: escalation,
    );
    final cadenceColor = _riskCadenceTierColor(cadenceTier);
    final firstNudge = valid ? '$nudge min' : 'Pending';
    final escalationWindow = valid ? '$escalation min' : 'Pending';
    final driftCheck = valid
        ? '${math.max(2, ((nudge ?? 0) / 3).round())} min interval'
        : 'Pending';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1621),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cadenceColor.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline_rounded, size: 15, color: cadenceColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Response Simulator',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEAF4FF),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cadenceColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: cadenceColor.withValues(alpha: 0.7),
                  ),
                ),
                child: Text(
                  cadenceTier,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEAF4FF),
                    fontSize: 10.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _riskMetricChip(
                icon: Icons.timelapse_rounded,
                label: 'First Nudge',
                value: firstNudge,
                accent: cadenceColor,
              ),
              _riskMetricChip(
                icon: Icons.campaign_rounded,
                label: 'Escalation',
                value: escalationWindow,
                accent: cadenceColor,
              ),
              _riskMetricChip(
                icon: Icons.my_location_rounded,
                label: 'GPS Drift',
                value: driftCheck,
                accent: cadenceColor,
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            _riskControllerCue(
              nudge: nudge,
              escalation: escalation,
              valid: valid,
            ),
            style: GoogleFonts.inter(
              color: const Color(0xFFCEE4FA),
              fontSize: 10.6,
              fontWeight: FontWeight.w600,
              height: 1.28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _riskMetricChip({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0x1411161D),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: const Color(0xFFEAF4FF)),
          const SizedBox(width: 5),
          Text(
            '$label: $value',
            style: GoogleFonts.inter(
              color: const Color(0xFFEAF4FF),
              fontSize: 10.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Color _riskProfileAccent(String profile) {
    switch (profile) {
      case 'industrial':
        return const Color(0xFFF97316);
      case 'residential':
        return const Color(0xFF22C55E);
      case 'commercial':
        return const Color(0xFF38BDF8);
      case 'mixed_use':
      default:
        return const Color(0xFFA78BFA);
    }
  }

  String _riskCadenceTierLabel({
    required int? nudge,
    required int? escalation,
  }) {
    if ((nudge ?? 0) <= 0 || (escalation ?? 0) <= 0) {
      return 'Cadence Pending';
    }
    if ((escalation ?? 0) <= 1 && (nudge ?? 0) <= 10) {
      return 'Aggressive';
    }
    if ((escalation ?? 0) <= 2 && (nudge ?? 0) <= 15) {
      return 'Balanced';
    }
    return 'Conservative';
  }

  Color _riskCadenceTierColor(String tier) {
    switch (tier) {
      case 'Aggressive':
        return const Color(0xFFF97316);
      case 'Balanced':
        return const Color(0xFF22C55E);
      case 'Conservative':
        return const Color(0xFF38BDF8);
      case 'Cadence Pending':
      default:
        return const Color(0xFFA78BFA);
    }
  }

  String _riskControllerCue({
    required int? nudge,
    required int? escalation,
    required bool valid,
  }) {
    if (!valid) {
      return 'Set positive timer values to simulate escalation behavior and guard check rhythm.';
    }
    if ((escalation ?? 0) <= 1) {
      return 'Controller cue: pre-stage nearest response unit and keep client advisory lane hot.';
    }
    if ((nudge ?? 0) <= 12) {
      return 'Controller cue: maintain frequent guard acknowledgements and monitor checkpoint drift.';
    }
    return 'Controller cue: standard patrol rhythm active; monitor for delay accumulation during peak load.';
  }

  String _riskProfileNarrative(String profile) {
    switch (profile) {
      case 'industrial':
        return 'High-alert posture with faster escalation and tighter patrol verification cycles.';
      case 'residential':
        return 'Balanced vigilance model optimized for perimeter confidence and resident flow.';
      case 'commercial':
        return 'Traffic-aware monitoring with structured cadence for entrances and loading zones.';
      case 'mixed_use':
      default:
        return 'Hybrid policy blending residential discipline with commercial response tempo.';
    }
  }

  int _riskFirstActionSeconds(String profile) {
    switch (profile) {
      case 'industrial':
        return 18;
      case 'commercial':
        return 24;
      case 'mixed_use':
        return 26;
      case 'residential':
      default:
        return 30;
    }
  }

  int _riskBaseArrivalSeconds(String profile) {
    switch (profile) {
      case 'industrial':
        return 160;
      case 'commercial':
        return 190;
      case 'mixed_use':
        return 205;
      case 'residential':
      default:
        return 225;
    }
  }

  int _resolveGeofenceForSla() {
    return int.tryParse(_geofenceController.text.trim()) ??
        _recommendedGeofenceMetersForProfile(_riskProfile);
  }

  int _resolveNudgeForSla() {
    return int.tryParse(_nudgeController.text.trim()) ??
        _recommendedNudgeMinutesForProfile(_riskProfile);
  }

  int _resolveEscalationForSla() {
    return int.tryParse(_escalationController.text.trim()) ??
        _recommendedEscalationMinutesForProfile(_riskProfile);
  }

  String _durationLabel(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _clientPromiseNarrative({
    required int firstActionSeconds,
    required int dispatchSeconds,
    required int advisorySeconds,
    required int arrivalSeconds,
    required int geofenceMeters,
    required int escalationMinutes,
  }) {
    return 'Controller action in ${_durationLabel(firstActionSeconds)}, dispatch in ${_durationLabel(dispatchSeconds)}, client advisory by ${_durationLabel(advisorySeconds)}, and expected arrival around ${_durationLabel(arrivalSeconds)} for a ${geofenceMeters}m perimeter. Escalation lock triggers at $escalationMinutes minute${escalationMinutes == 1 ? '' : 's'}.';
  }

  String _clientPromiseScript({
    required int firstActionSeconds,
    required int dispatchSeconds,
    required int advisorySeconds,
    required int arrivalSeconds,
    required int geofenceMeters,
    required int nudgeMinutes,
    required int escalationMinutes,
  }) {
    final siteName = _siteNameController.text.trim().isEmpty
        ? 'this site'
        : _siteNameController.text.trim();
    return 'On $siteName, ONYX commits to first controller action in ${_durationLabel(firstActionSeconds)} and dispatch in ${_durationLabel(dispatchSeconds)}. '
        'Client advisory is issued by ${_durationLabel(advisorySeconds)}, with expected unit arrival around ${_durationLabel(arrivalSeconds)} across a ${geofenceMeters}m perimeter. '
        'Guard vigilance runs every $nudgeMinutes minute${nudgeMinutes == 1 ? '' : 's'} with escalation at $escalationMinutes minute${escalationMinutes == 1 ? '' : 's'} if acknowledgement is missing.';
  }

  Future<void> _copyClientPromiseScript(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Client demo script copied.',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _slaPromisePreviewCard() {
    final accent = _riskProfileAccent(_riskProfile);
    final geofenceMeters = _resolveGeofenceForSla();
    final nudgeMinutes = _resolveNudgeForSla();
    final escalationMinutes = _resolveEscalationForSla();
    final firstActionSeconds = _riskFirstActionSeconds(_riskProfile);
    final dispatchSeconds = firstActionSeconds + 22;
    final advisorySeconds = dispatchSeconds + 25;
    final geofenceAdjustment = ((geofenceMeters - 300) / 14).round();
    final arrivalSeconds =
        (_riskBaseArrivalSeconds(_riskProfile) + geofenceAdjustment).clamp(
          130,
          460,
        );
    final script = _clientPromiseScript(
      firstActionSeconds: firstActionSeconds,
      dispatchSeconds: dispatchSeconds,
      advisorySeconds: advisorySeconds,
      arrivalSeconds: arrivalSeconds,
      geofenceMeters: geofenceMeters,
      nudgeMinutes: nudgeMinutes,
      escalationMinutes: escalationMinutes,
    );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.26), const Color(0xFF0D1621)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_rounded, size: 15, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'SLA Promise Preview',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEAF4FF),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _copyClientPromiseScript(script),
                icon: const Icon(Icons.content_copy_rounded, size: 14),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEAF4FF),
                  side: BorderSide(color: accent.withValues(alpha: 0.72)),
                  backgroundColor: const Color(0x20111A24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  minimumSize: const Size(0, 30),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                label: Text(
                  'Copy Demo Script',
                  style: GoogleFonts.inter(
                    fontSize: 10.3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _riskMetricChip(
                icon: Icons.flash_on_rounded,
                label: 'First Action',
                value: _durationLabel(firstActionSeconds),
                accent: accent,
              ),
              _riskMetricChip(
                icon: Icons.send_rounded,
                label: 'Dispatch',
                value: _durationLabel(dispatchSeconds),
                accent: accent,
              ),
              _riskMetricChip(
                icon: Icons.sms_rounded,
                label: 'Client Advisory',
                value: _durationLabel(advisorySeconds),
                accent: accent,
              ),
              _riskMetricChip(
                icon: Icons.directions_car_filled_rounded,
                label: 'Arrival',
                value: _durationLabel(arrivalSeconds),
                accent: accent,
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            _clientPromiseNarrative(
              firstActionSeconds: firstActionSeconds,
              dispatchSeconds: dispatchSeconds,
              advisorySeconds: advisorySeconds,
              arrivalSeconds: arrivalSeconds,
              geofenceMeters: geofenceMeters,
              escalationMinutes: escalationMinutes,
            ),
            style: GoogleFonts.inter(
              color: const Color(0xFFCEE4FA),
              fontSize: 10.6,
              fontWeight: FontWeight.w600,
              height: 1.28,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    return Dialog(
      backgroundColor: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF30363D)),
      ),
      child: SizedBox(
        width: _responsiveDialogWidth(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _onboardingHero(
                  context: context,
                  title: 'New Site Onboarding',
                  subtitle:
                      'Configure location intelligence, entry protocols, and risk-driven automation defaults.',
                  accent: const Color(0xFF0E8B8F),
                  responseTarget: 'Risk profile + geofence under 75s',
                  confidenceLabel: 'Geo validation confidence 97.8%',
                  talkTrackTitle: 'Site Demo Talk Track',
                  talkTrackLines: const [
                    'Here we define the physical deployment footprint for dispatch logic.',
                    'Risk profile auto-tunes nudge and escalation timers for this site.',
                    'Entry protocol and map metadata remove guesswork during live incidents.',
                    'The result is faster, safer response execution from first signal.',
                  ],
                  compact: compact,
                  chips: const [
                    'Location',
                    'Risk Profiler',
                    'Geofence & Protocol',
                  ],
                ),
                if (widget.demoMode) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () {
                          _applyDemoTemplate();
                          _showOnboardingSnackBar(
                            context,
                            '${_siteScenarioLabel(_selectedSiteScenario)} template applied.',
                          );
                        },
                        icon: Icon(
                          _siteTemplatePending
                              ? Icons.hourglass_top_rounded
                              : Icons.auto_awesome_rounded,
                          size: 16,
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _siteTemplatePending
                              ? const Color(0xFF9A4D08)
                              : const Color(0xFF1F3A5A),
                          foregroundColor: const Color(0xFFEAF4FF),
                        ),
                        label: Text(
                          _siteTemplatePending
                              ? 'Apply ${_siteScenarioLabel(_selectedSiteScenario)} Template'
                              : '${_siteScenarioLabel(_selectedSiteScenario)} Template Applied',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () async {
                          final launchMessage = _launchDemoFlow();
                          await Clipboard.setData(
                            ClipboardData(text: _sitePitchText()),
                          );
                          if (!context.mounted) return;
                          _showOnboardingSnackBar(
                            context,
                            '$launchMessage Pitch copied.',
                          );
                        },
                        icon: const Icon(Icons.rocket_launch_rounded, size: 16),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: const Color(0xFFEAF4FF),
                        ),
                        label: Text(
                          'Launch Demo',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () =>
                            _showOnboardingSnackBar(context, _runDemoReady()),
                        icon: Icon(_demoReadyButtonIcon, size: 16),
                        style: FilledButton.styleFrom(
                          backgroundColor: _demoReadyButtonColor,
                          foregroundColor: const Color(0xFFEAF4FF),
                        ),
                        label: Text(
                          _demoReadyButtonLabel,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                      _demoScenarioPicker(
                        label: 'Site Scenario',
                        selectedValue: _selectedSiteScenario,
                        isApplied: !_siteTemplatePending,
                        onSelected: (scenario) {
                          setState(() => _selectedSiteScenario = scenario);
                          final pending =
                              _selectedSiteScenario != _appliedSiteScenario;
                          _showOnboardingSnackBar(
                            context,
                            pending
                                ? '${_siteScenarioLabel(scenario)} scenario selected. Tap Apply to populate fields.'
                                : '${_siteScenarioLabel(scenario)} scenario already applied.',
                          );
                        },
                        options: const [
                          _DemoScenarioOption(
                            value: 'industrial_yard',
                            label: 'Industrial Yard',
                            detail: 'High-risk perimeter posture.',
                          ),
                          _DemoScenarioOption(
                            value: 'residential_estate',
                            label: 'Residential Estate',
                            detail: 'Standard estate guarding workflow.',
                          ),
                          _DemoScenarioOption(
                            value: 'retail_centre',
                            label: 'Retail Centre',
                            detail: 'Commercial mixed-footfall profile.',
                          ),
                        ],
                      ),
                      OutlinedButton.icon(
                        onPressed: _resetDemoPace,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8FD1FF),
                          side: const BorderSide(color: Color(0xFF35506F)),
                        ),
                        label: Text(
                          'Reset Pace',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          final resetCount = _startFreshDemo();
                          final message = resetCount <= 0
                              ? 'Already fresh and ready for next demo.'
                              : resetCount == 1
                              ? '1 item reset for a fresh demo.'
                              : '$resetCount items reset for a fresh demo.';
                          _showOnboardingSnackBar(context, message);
                        },
                        icon: const Icon(
                          Icons.cleaning_services_rounded,
                          size: 16,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF9FD6FF),
                          side: const BorderSide(color: Color(0xFF35506F)),
                        ),
                        label: Text(
                          'Start Fresh',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          final target = _nextIncompleteStep;
                          if (target == null) {
                            _showOnboardingSnackBar(
                              context,
                              'All readiness gates are already complete.',
                            );
                            return;
                          }
                          setState(() => _step = target);
                          _showOnboardingSnackBar(
                            context,
                            'Jumped to Step ${target + 1} for missing inputs.',
                          );
                        },
                        icon: const Icon(Icons.track_changes_rounded, size: 16),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFFE1B8),
                          side: const BorderSide(color: Color(0xFFB3742C)),
                        ),
                        label: Text(
                          'Next Gap',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: _sitePitchText()),
                          );
                          if (!context.mounted) return;
                          _showOnboardingSnackBar(
                            context,
                            'Site pitch copied.',
                          );
                        },
                        icon: const Icon(Icons.mic_rounded, size: 16),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFBFE6FF),
                          side: const BorderSide(color: Color(0xFF35506F)),
                        ),
                        label: Text(
                          'Copy Pitch',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: _siteSnapshotText()),
                          );
                          if (!context.mounted) return;
                          _showOnboardingSnackBar(
                            context,
                            'Site snapshot copied.',
                          );
                        },
                        icon: const Icon(Icons.receipt_long_rounded, size: 16),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFD5EBFF),
                          side: const BorderSide(color: Color(0xFF35506F)),
                        ),
                        label: Text(
                          'Copy Snapshot',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
                if ((_error ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFF87171),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                _creationPulseBanner(
                  visible: _showCreatePulse,
                  accent: const Color(0xFF0E8B8F),
                  label:
                      'Site footprint committed with risk automation defaults.',
                ),
                const SizedBox(height: 8),
                _stepSummary(
                  currentStep: _step,
                  labels: const ['Identity', 'Location', 'Risk'],
                  onStepTap: (step) => setState(() => _step = step),
                  readinessGates: _previewGates,
                ),
                const SizedBox(height: 8),
                _demoPaceMeter(
                  startedAt: _sessionStartedAt,
                  targetSeconds: 75,
                  accent: const Color(0xFF0E8B8F),
                  compact: compact,
                  onRecover: widget.demoMode
                      ? () =>
                            _showOnboardingSnackBar(context, _recoverDemoPace())
                      : null,
                  recoverLabel: 'Recover Site Pace',
                ),
                const SizedBox(height: 8),
                _demoCoachCard(
                  context: context,
                  accent: const Color(0xFF0E8B8F),
                  currentStep: _step,
                  compact: compact,
                  cues: const [
                    _DemoCoachCue(
                      stage: 'Identity',
                      narration:
                          'This locks site identity to the right client so dispatch and ledger chains never cross tenants.',
                      proofPoint:
                          'Client/site linking is deterministic from day one.',
                    ),
                    _DemoCoachCue(
                      stage: 'Location',
                      narration:
                          'We capture physical address and geo pins so patrol, ETA, and incident arrival checks are GPS-verifiable.',
                      proofPoint:
                          'Supports anti-ghost verification during incidents.',
                    ),
                    _DemoCoachCue(
                      stage: 'Risk',
                      narration:
                          'Risk profile auto-tunes nudge and escalation timing to match operational reality at this site.',
                      proofPoint:
                          'Standardizes response behavior without manual tuning.',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _slaPromisePreviewCard(),
                const SizedBox(height: 8),
                _onboardingLivePreview(
                  context: context,
                  title: 'Deployment Preview',
                  accent: const Color(0xFF0E8B8F),
                  lines: _previewLines,
                  gates: _previewGates,
                  completion: _completionScore,
                  compact: compact,
                  payload: _payloadPreview,
                  sqlTable: 'sites',
                  sqlConflictColumns: const ['site_id'],
                  onAutoFillMissing: widget.demoMode
                      ? _autoFillMissingForDemo
                      : null,
                  autoFillLabel:
                      'Auto-Fill ${_siteScenarioLabel(_selectedSiteScenario)} Demo',
                  onJumpToStep: (step) => setState(() => _step = step),
                ),
                const SizedBox(height: 8),
                Theme(
                  data: _onboardingStepperTheme(context),
                  child: Stepper(
                    currentStep: _step,
                    onStepTapped: (value) => setState(() => _step = value),
                    controlsBuilder: (context, details) {
                      final isFinalStep = _step == 2;
                      final readyForCreate = _allGatesReady;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _next,
                            icon: Icon(
                              isFinalStep
                                  ? (readyForCreate
                                        ? Icons.check_circle_rounded
                                        : Icons.error_outline_rounded)
                                  : Icons.arrow_forward_rounded,
                              size: 16,
                            ),
                            style: _onboardingPrimaryActionStyle(
                              accent: const Color(0xFF0E8B8F),
                              isFinalStep: isFinalStep,
                              readyForCreate: readyForCreate,
                            ),
                            label: Text(
                              isFinalStep
                                  ? (readyForCreate
                                        ? 'Create Site (Ready)'
                                        : 'Create Site (Needs Inputs)')
                                  : 'Next',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: _step == 0
                                ? () => Navigator.of(context).pop()
                                : () => setState(() => _step -= 1),
                            icon: Icon(
                              _step == 0
                                  ? Icons.close_rounded
                                  : Icons.arrow_back_rounded,
                              size: 16,
                            ),
                            style: _onboardingSecondaryActionStyle(),
                            label: Text(
                              _step == 0 ? 'Cancel' : 'Back',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (isFinalStep && !readyForCreate)
                            OutlinedButton.icon(
                              onPressed: () {
                                final target = _nextIncompleteStep;
                                if (target == null) return;
                                setState(() => _step = target);
                              },
                              icon: const Icon(
                                Icons.track_changes_rounded,
                                size: 16,
                              ),
                              style: _onboardingMissingStepActionStyle(),
                              label: Text(
                                'Go To Missing Step',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                    steps: [
                      Step(
                        state: _stepStateFor(stepIndex: 0, currentStep: _step),
                        isActive: true,
                        title: _stepTitle(
                          'Identity',
                          stepIndex: 0,
                          currentStep: _step,
                        ),
                        content: _stepPanel(
                          children: [
                            _dropdownField(
                              label: 'Client',
                              value: _clientId,
                              items: widget.clients
                                  .map((client) => client.id)
                                  .toList(),
                              labels: {
                                for (final client in widget.clients)
                                  client.id: '${client.name} (${client.id})',
                              },
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _clientId = value);
                              },
                            ),
                            const SizedBox(height: 8),
                            _textField(
                              _siteIdController,
                              'Site ID (e.g. SITE-SANDTON)',
                            ),
                            const SizedBox(height: 8),
                            _textField(_siteNameController, 'Site Name'),
                            const SizedBox(height: 8),
                            _textField(_siteCodeController, 'Site Code'),
                            const SizedBox(height: 7),
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => setState(
                                    () => _syncIdentityFromName(
                                      force: true,
                                      includeId: true,
                                      includeCode: false,
                                    ),
                                  ),
                                  icon: const Icon(Icons.tag_rounded, size: 14),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFBFE6FF),
                                    side: const BorderSide(
                                      color: Color(0xFF4C6683),
                                    ),
                                    backgroundColor: const Color(0xFF111A24),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 6,
                                    ),
                                    minimumSize: const Size(0, 32),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  label: Text(
                                    'Generate Site ID',
                                    style: GoogleFonts.inter(
                                      fontSize: 10.6,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => setState(
                                    () => _syncIdentityFromName(
                                      force: true,
                                      includeId: false,
                                      includeCode: true,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.qr_code_2_rounded,
                                    size: 14,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFBFE6FF),
                                    side: const BorderSide(
                                      color: Color(0xFF4C6683),
                                    ),
                                    backgroundColor: const Color(0xFF111A24),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 6,
                                    ),
                                    minimumSize: const Size(0, 32),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  label: Text(
                                    'Generate Site Code',
                                    style: GoogleFonts.inter(
                                      fontSize: 10.6,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            _siteIdentitySuggestionStrip(),
                          ],
                        ),
                      ),
                      Step(
                        state: _stepStateFor(stepIndex: 1, currentStep: _step),
                        isActive: true,
                        title: _stepTitle(
                          'Location',
                          stepIndex: 1,
                          currentStep: _step,
                        ),
                        content: _stepPanel(
                          children: [
                            _textField(_addressController, 'Physical Address'),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _textField(_latController, 'Latitude'),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _textField(
                                    _lngController,
                                    'Longitude',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            _coordinatePresetStrip(),
                            const SizedBox(height: 8),
                            _textField(
                              _geofenceController,
                              'Geofence Radius (meters)',
                            ),
                            const SizedBox(height: 7),
                            _geofencePresetStrip(),
                            const SizedBox(height: 8),
                            _tacticalFootprintCard(),
                            const SizedBox(height: 8),
                            _textField(
                              _entryProtocolController,
                              'Entry Protocol',
                            ),
                            const SizedBox(height: 7),
                            _entryProtocolTemplateStrip(),
                            const SizedBox(height: 8),
                            _textField(
                              _mapUrlController,
                              'Site Layout Map URL',
                            ),
                            const SizedBox(height: 7),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: () => setState(
                                  () => _mapUrlController.text =
                                      _suggestedLayoutMapUrl(),
                                ),
                                icon: const Icon(
                                  Icons.auto_fix_high_rounded,
                                  size: 14,
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFBFE6FF),
                                  side: const BorderSide(
                                    color: Color(0xFF4C6683),
                                  ),
                                  backgroundColor: const Color(0xFF111A24),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 6,
                                  ),
                                  minimumSize: const Size(0, 32),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                label: Text(
                                  'Use Suggested URL',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.6,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _locationIntegrityCard(),
                          ],
                        ),
                      ),
                      Step(
                        state: _stepStateFor(stepIndex: 2, currentStep: _step),
                        isActive: true,
                        title: _stepTitle(
                          'Risk Profiler',
                          stepIndex: 2,
                          currentStep: _step,
                        ),
                        content: _stepPanel(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Is this site High-Risk (Industrial) or Residential?',
                              style: GoogleFonts.inter(
                                color: const Color(0xFFEAF4FF),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _riskProfileOptionTile(
                                  keyValue: 'residential',
                                  label: 'Residential',
                                  detail:
                                      'Estates and compounds. Balanced patrol cadence.',
                                  timerHint: '15m nudge • 2m escalation',
                                ),
                                _riskProfileOptionTile(
                                  keyValue: 'industrial',
                                  label: 'Industrial',
                                  detail:
                                      'Yards and plants. Aggressive vigilance posture.',
                                  timerHint: '10m nudge • 1m escalation',
                                ),
                                _riskProfileOptionTile(
                                  keyValue: 'commercial',
                                  label: 'Commercial',
                                  detail:
                                      'Retail and offices with mixed traffic.',
                                  timerHint: '12m nudge • 2m escalation',
                                ),
                                _riskProfileOptionTile(
                                  keyValue: 'mixed_use',
                                  label: 'Mixed Use',
                                  detail:
                                      'Hybrid zones spanning residential + business.',
                                  timerHint: '12m nudge • 2m escalation',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Timer Overrides',
                              style: GoogleFonts.inter(
                                color: const Color(0xFFD7EAFE),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: _textField(
                                    _nudgeController,
                                    'Guard Nudge Frequency (min)',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _textField(
                                    _escalationController,
                                    'Escalation Trigger (min)',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: FilledButton.icon(
                                onPressed: _applyRiskOpsPack,
                                icon: const Icon(
                                  Icons.auto_fix_high_rounded,
                                  size: 14,
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF0E8B8F),
                                  foregroundColor: const Color(0xFFEAF4FF),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 7,
                                  ),
                                  minimumSize: const Size(0, 32),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                label: Text(
                                  'Apply Risk Ops Pack',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.6,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Defaults are auto-loaded from the selected risk profile. Override only when client SLA needs custom cadence.',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF9AB1CF),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _riskOutcomePreviewCard(),
                            const SizedBox(height: 8),
                            _riskResponseSimulatorCard(),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0B121A),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF36506B),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Dedicated Site Telegram Lane',
                                              style: GoogleFonts.inter(
                                                color: const Color(0xFFEAF4FF),
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Optional override. Leave off to inherit the client-level lane.',
                                              style: GoogleFonts.inter(
                                                color: const Color(0xFF9AB1CF),
                                                fontSize: 10.8,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Switch(
                                        value: _enableSiteTelegramBridge,
                                        onChanged: (value) {
                                          setState(() {
                                            _enableSiteTelegramBridge = value;
                                            if (!value) {
                                              _siteTelegramChatIdController
                                                  .clear();
                                              _siteTelegramThreadIdController
                                                  .clear();
                                            }
                                          });
                                        },
                                        activeThumbColor: const Color(
                                          0xFF22C55E,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_enableSiteTelegramBridge) ...[
                                    const SizedBox(height: 8),
                                    _textField(
                                      _siteEndpointLabelController,
                                      'Messaging Endpoint Label',
                                    ),
                                    const SizedBox(height: 8),
                                    _textField(
                                      _siteTelegramChatIdController,
                                      'Telegram Chat ID',
                                    ),
                                    const SizedBox(height: 8),
                                    _textField(
                                      _siteTelegramThreadIdController,
                                      'Telegram Thread ID (optional)',
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Tip: use /whoami in the admin Telegram group to capture chat_id/thread_id values quickly.',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF9AB1CF),
                                        fontSize: 10.8,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
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
}

class _EmployeeOnboardingDialog extends StatefulWidget {
  final List<_ClientAdminRow> clients;
  final List<_SiteAdminRow> sites;
  final bool demoMode;
  final ValueChanged<String>? onOpenTacticalForIncident;
  final ValueChanged<String>? onOpenOperationsForIncident;

  const _EmployeeOnboardingDialog({
    required this.clients,
    required this.sites,
    required this.demoMode,
    this.onOpenTacticalForIncident,
    this.onOpenOperationsForIncident,
  });

  @override
  State<_EmployeeOnboardingDialog> createState() =>
      _EmployeeOnboardingDialogState();
}

class _EmployeeOnboardingDialogState extends State<_EmployeeOnboardingDialog> {
  int _step = 0;
  String? _error;
  bool _showCreatePulse = false;
  DateTime _sessionStartedAt = DateTime.now();
  late String _clientId = widget.clients.first.id;
  String _role = 'guard';
  String _selectedEmployeeScenario = 'reaction_officer';
  String _appliedEmployeeScenario = '';
  String _psiraGrade = 'C';
  String _assignedSiteId = '';
  bool _hasDriverLicense = false;
  bool _hasPdp = false;
  DateTime? _dob;
  DateTime? _psiraExpiry;
  DateTime? _licenseExpiry;
  DateTime? _pdpExpiry;
  final _employeeCodeController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _psiraNumberController = TextEditingController();
  final _driverCodeController = TextEditingController();
  final _deviceUidController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _employeeCodeController.dispose();
    _fullNameController.dispose();
    _surnameController.dispose();
    _idNumberController.dispose();
    _psiraNumberController.dispose();
    _driverCodeController.dispose();
    _deviceUidController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _resetDemoPace() {
    setState(() => _sessionStartedAt = DateTime.now());
  }

  int _startFreshDemo() {
    var resetCount = 0;
    setState(() {
      if (_step != 0) {
        _step = 0;
        resetCount++;
      }
      if (_error != null) {
        _error = null;
        resetCount++;
      }
      if (_showCreatePulse) {
        _showCreatePulse = false;
        resetCount++;
      }
      _sessionStartedAt = DateTime.now();
      if (_employeeCodeController.text.trim().isNotEmpty) {
        _employeeCodeController.clear();
        resetCount++;
      }
      if (_fullNameController.text.trim().isNotEmpty) {
        _fullNameController.clear();
        resetCount++;
      }
      if (_surnameController.text.trim().isNotEmpty) {
        _surnameController.clear();
        resetCount++;
      }
      if (_idNumberController.text.trim().isNotEmpty) {
        _idNumberController.clear();
        resetCount++;
      }
      if (_psiraNumberController.text.trim().isNotEmpty) {
        _psiraNumberController.clear();
        resetCount++;
      }
      if (_driverCodeController.text.trim().isNotEmpty) {
        _driverCodeController.clear();
        resetCount++;
      }
      if (_deviceUidController.text.trim().isNotEmpty) {
        _deviceUidController.clear();
        resetCount++;
      }
      if (_phoneController.text.trim().isNotEmpty) {
        _phoneController.clear();
        resetCount++;
      }
      if (_emailController.text.trim().isNotEmpty) {
        _emailController.clear();
        resetCount++;
      }
      if (_role != 'guard') {
        _role = 'guard';
        resetCount++;
      }
      if (_psiraGrade != 'C') {
        _psiraGrade = 'C';
        resetCount++;
      }
      if (_assignedSiteId.trim().isNotEmpty) {
        _assignedSiteId = '';
        resetCount++;
      }
      if (_hasDriverLicense) {
        _hasDriverLicense = false;
        resetCount++;
      }
      if (_hasPdp) {
        _hasPdp = false;
        resetCount++;
      }
      if (_dob != null) {
        _dob = null;
        resetCount++;
      }
      if (_psiraExpiry != null) {
        _psiraExpiry = null;
        resetCount++;
      }
      if (_licenseExpiry != null) {
        _licenseExpiry = null;
        resetCount++;
      }
      if (_pdpExpiry != null) {
        _pdpExpiry = null;
        resetCount++;
      }
      if (_appliedEmployeeScenario.isNotEmpty) {
        _appliedEmployeeScenario = '';
        resetCount++;
      }
    });
    return resetCount;
  }

  List<_SiteAdminRow> get _siteOptions => widget.sites
      .where((site) => site.clientId == _clientId)
      .toList(growable: false);

  bool get _roleRequiresPsira =>
      _role == 'guard' || _role == 'reaction_officer';

  double get _completionScore {
    var score = 0;
    const total = 8;
    if (_employeeCodeController.text.trim().isNotEmpty) score++;
    if (_fullNameController.text.trim().isNotEmpty &&
        _surnameController.text.trim().isNotEmpty) {
      score++;
    }
    if (_idNumberController.text.trim().isNotEmpty) score++;
    if (_role.trim().isNotEmpty) score++;
    if (!_roleRequiresPsira || _psiraNumberController.text.trim().isNotEmpty) {
      score++;
    }
    if (!_hasDriverLicense || _driverCodeController.text.trim().isNotEmpty) {
      score++;
    }
    if (_phoneController.text.trim().isNotEmpty) score++;
    if (_assignedSiteId.trim().isNotEmpty) score++;
    return score / total;
  }

  List<String> get _previewLines {
    final employeeCode = _employeeCodeController.text.trim().isEmpty
        ? 'Pending'
        : _employeeCodeController.text.trim().toUpperCase();
    final fullName =
        '${_fullNameController.text.trim()} ${_surnameController.text.trim()}'
            .trim();
    final displayName = fullName.isEmpty ? 'Pending employee name' : fullName;
    final psira = _psiraNumberController.text.trim().isEmpty
        ? (_roleRequiresPsira ? 'Pending PSIRA' : 'Not required')
        : _psiraNumberController.text.trim();
    final assignment = _assignedSiteId.trim().isEmpty
        ? 'Unassigned'
        : _assignedSiteId.trim();
    return [
      'Employee: $employeeCode • $displayName',
      'Role: ${_role.replaceAll('_', ' ')}',
      'Compliance: PSIRA $psira',
      'Primary Assignment: $assignment',
    ];
  }

  List<_PreviewGate> get _previewGates {
    final hasIdentity =
        _employeeCodeController.text.trim().isNotEmpty &&
        _fullNameController.text.trim().isNotEmpty &&
        _surnameController.text.trim().isNotEmpty &&
        _idNumberController.text.trim().isNotEmpty;
    final psiraReady =
        !_roleRequiresPsira || _psiraNumberController.text.trim().isNotEmpty;
    final drivingReady =
        !_hasDriverLicense || _driverCodeController.text.trim().isNotEmpty;
    final pdpReady = !_hasPdp || _pdpExpiry != null;
    final hasContact = _phoneController.text.trim().isNotEmpty;
    final assignmentReady =
        _role == 'controller' || _assignedSiteId.trim().isNotEmpty;
    return [
      _PreviewGate(label: 'Identity', ready: hasIdentity, step: 0),
      _PreviewGate(label: 'PSIRA Ready', ready: psiraReady, step: 1),
      _PreviewGate(label: 'Driving', ready: drivingReady, step: 2),
      _PreviewGate(label: 'PDP', ready: pdpReady, step: 2),
      _PreviewGate(label: 'Contact', ready: hasContact, step: 2),
      _PreviewGate(label: 'Assignment', ready: assignmentReady, step: 2),
    ];
  }

  bool get _allGatesReady => _previewGates.every((gate) => gate.ready);

  int? get _nextIncompleteStep {
    for (final gate in _previewGates) {
      if (!gate.ready) return gate.step;
    }
    return null;
  }

  Map<String, dynamic> get _payloadPreview {
    return {
      'client_id': _clientId,
      'employee_code': _employeeCodeController.text.trim().toUpperCase(),
      'role': _role,
      'full_name': _fullNameController.text.trim(),
      'surname': _surnameController.text.trim(),
      'id_number': _idNumberController.text.trim(),
      'date_of_birth': _dob?.toIso8601String(),
      'psira_number': _psiraNumberController.text.trim(),
      'psira_grade': _psiraGrade,
      'psira_expiry': _psiraExpiry?.toIso8601String(),
      'has_driver_license': _hasDriverLicense,
      'driver_license_code': _driverCodeController.text.trim(),
      'driver_license_expiry': _licenseExpiry?.toIso8601String(),
      'has_pdp': _hasPdp,
      'pdp_expiry': _pdpExpiry?.toIso8601String(),
      'device_uid': _deviceUidController.text.trim(),
      'contact_phone': _phoneController.text.trim(),
      'contact_email': _emailController.text.trim(),
      'assigned_site_id': _assignedSiteId,
    };
  }

  String get _assignmentSqlPreview {
    return _buildEmployeeAssignmentUpsertSql(
      clientId: _clientId.trim(),
      employeeCode: _employeeCodeController.text.trim().toUpperCase(),
      siteId: _assignedSiteId.trim(),
    );
  }

  bool _validateStep() {
    setState(() => _error = null);
    if (_step == 0) {
      if (_employeeCodeController.text.trim().isEmpty) {
        setState(() => _error = 'Employee code is required.');
        return false;
      }
      if (_fullNameController.text.trim().isEmpty ||
          _surnameController.text.trim().isEmpty) {
        setState(() => _error = 'Full name and surname are required.');
        return false;
      }
      if (_idNumberController.text.trim().isEmpty) {
        setState(() => _error = 'ID or passport number is required.');
        return false;
      }
    }
    if (_step == 1) {
      final complianceRole = _role == 'guard' || _role == 'reaction_officer';
      if (complianceRole && _psiraNumberController.text.trim().isEmpty) {
        setState(
          () => _error = 'PSIRA number is required for guard/reaction roles.',
        );
        return false;
      }
    }
    if (_step == 2) {
      if (_hasDriverLicense && _driverCodeController.text.trim().isEmpty) {
        setState(() => _error = 'Driver license code is required.');
        return false;
      }
      final email = _emailController.text.trim();
      if (email.isNotEmpty && !email.contains('@')) {
        setState(() => _error = 'Contact email is invalid.');
        return false;
      }
      if (_hasPdp && !_hasDriverLicense) {
        setState(() => _error = 'PDP requires an active driver license.');
        return false;
      }
    }
    return true;
  }

  Future<void> _pickDate({
    required DateTime? current,
    required ValueChanged<DateTime> onSelected,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 70),
      lastDate: DateTime(now.year + 15),
    );
    if (picked != null) {
      onSelected(picked);
    }
  }

  void _next() async {
    if (!_validateStep()) return;
    if (_showCreatePulse) {
      setState(() => _showCreatePulse = false);
    }
    if (_step < 2) {
      setState(() => _step += 1);
      return;
    }
    if (!_allGatesReady) {
      final proceed = await _confirmIncompleteReadiness(
        context,
        entityLabel: 'Employee',
        gates: _previewGates,
        accent: const Color(0xFF5C66D6),
      );
      if (!proceed) {
        final target = _nextIncompleteStep;
        if (target != null && mounted) {
          setState(() => _step = target);
        }
        return;
      }
    }
    await _playCreatePulse();
    if (!mounted) return;
    Navigator.of(context).pop(
      _EmployeeOnboardingDraft(
        clientId: _clientId,
        employeeCode: _employeeCodeController.text.trim().toUpperCase(),
        role: _role,
        fullName: _fullNameController.text.trim(),
        surname: _surnameController.text.trim(),
        idNumber: _idNumberController.text.trim(),
        dateOfBirth: _dob,
        psiraNumber: _psiraNumberController.text.trim(),
        psiraGrade: _psiraGrade,
        psiraExpiry: _psiraExpiry,
        hasDriverLicense: _hasDriverLicense,
        driverLicenseCode: _driverCodeController.text.trim(),
        driverLicenseExpiry: _licenseExpiry,
        hasPdp: _hasPdp,
        pdpExpiry: _pdpExpiry,
        deviceUid: _deviceUidController.text.trim(),
        contactPhone: _phoneController.text.trim(),
        contactEmail: _emailController.text.trim(),
        assignedSiteId: _assignedSiteId,
      ),
    );
  }

  Future<void> _playCreatePulse() async {
    if (!mounted) return;
    setState(() => _showCreatePulse = true);
    await Future<void>.delayed(const Duration(milliseconds: 520));
  }

  void _applyDemoTemplate() {
    _applyEmployeeScenario(_selectedEmployeeScenario);
  }

  String _launchDemoFlow() {
    _applyDemoTemplate();
    return '${_employeeScenarioLabel(_selectedEmployeeScenario)} demo loaded. ${_recoverDemoPace()}';
  }

  String _employeeScenarioLabel(String scenario) {
    switch (scenario) {
      case 'controller':
        return 'Controller';
      case 'static_guard':
        return 'Guard';
      case 'reaction_officer':
      default:
        return 'Reaction';
    }
  }

  int _autoFillMissingForDemo() {
    final stamp = DateTime.now().millisecondsSinceEpoch % 10000;
    final firstSite = _siteOptions.isEmpty ? '' : _siteOptions.first.id;
    final scenario = _selectedEmployeeScenario;
    String defaultRole = 'reaction_officer';
    String defaultCode = 'DEMO-EMP-$stamp';
    String defaultFullName = 'Kagiso';
    String defaultSurname = 'Molefe';
    String defaultId = '8808085501081';
    DateTime defaultDob = DateTime(1988, 8, 8);
    String defaultPsira = 'PSI-DEMO-$stamp';
    String defaultGrade = 'B';
    DateTime defaultPsiraExpiry = DateTime.now().add(const Duration(days: 540));
    bool defaultHasDriverLicense = true;
    bool defaultHasPdp = true;
    String defaultDriverCode = 'Code 10';
    DateTime defaultLicenseExpiry = DateTime.now().add(
      const Duration(days: 900),
    );
    DateTime defaultPdpExpiry = DateTime.now().add(const Duration(days: 700));
    String defaultDeviceUid = 'BV5300P-DEMO-$stamp';
    String defaultPhone = '+27 82 711 2233';
    String defaultEmail = 'kagiso.demo@onyx-security.co.za';
    String defaultAssignedSite = firstSite;
    switch (scenario) {
      case 'static_guard':
        defaultRole = 'guard';
        defaultCode = 'DEMO-EMP-G$stamp';
        defaultFullName = 'Lerato';
        defaultSurname = 'Nkosi';
        defaultId = '9205150890084';
        defaultDob = DateTime(1992, 5, 15);
        defaultPsira = 'PSI-DEMO-G$stamp';
        defaultGrade = 'C';
        defaultPsiraExpiry = DateTime.now().add(const Duration(days: 460));
        defaultHasDriverLicense = false;
        defaultHasPdp = false;
        defaultDriverCode = '';
        defaultDeviceUid = 'BV5300P-GRD-$stamp';
        defaultPhone = '+27 84 611 3301';
        defaultEmail = 'lerato.guard@onyx-security.co.za';
        defaultAssignedSite = firstSite;
        break;
      case 'controller':
        defaultRole = 'controller';
        defaultCode = 'DEMO-EMP-C$stamp';
        defaultFullName = 'Anele';
        defaultSurname = 'Jacobs';
        defaultId = '9003031234080';
        defaultDob = DateTime(1990, 3, 3);
        defaultPsira = '';
        defaultGrade = 'C';
        defaultHasDriverLicense = false;
        defaultHasPdp = false;
        defaultDriverCode = '';
        defaultDeviceUid = 'ONYX-CONSOLE-$stamp';
        defaultPhone = '+27 83 740 1144';
        defaultEmail = 'anele.controller@onyx-security.co.za';
        defaultAssignedSite = '';
        break;
      case 'reaction_officer':
      default:
        break;
    }
    final needsPsira =
        defaultRole == 'guard' || defaultRole == 'reaction_officer';
    var filledCount = 0;
    setState(() {
      if (_role == 'guard' && defaultRole != 'guard') {
        _role = defaultRole;
        filledCount++;
      }
      if (_employeeCodeController.text.trim().isEmpty) {
        _employeeCodeController.text = defaultCode;
        filledCount++;
      }
      if (_fullNameController.text.trim().isEmpty) {
        _fullNameController.text = defaultFullName;
        filledCount++;
      }
      if (_surnameController.text.trim().isEmpty) {
        _surnameController.text = defaultSurname;
        filledCount++;
      }
      if (_idNumberController.text.trim().isEmpty) {
        _idNumberController.text = defaultId;
        filledCount++;
      }
      if (_dob == null) {
        _dob = defaultDob;
        filledCount++;
      }
      if (_psiraGrade == 'C' && defaultGrade != 'C') {
        _psiraGrade = defaultGrade;
        filledCount++;
      }
      if (needsPsira && _psiraNumberController.text.trim().isEmpty) {
        _psiraNumberController.text = defaultPsira;
        filledCount++;
      }
      if (needsPsira && _psiraExpiry == null) {
        _psiraExpiry = defaultPsiraExpiry;
        filledCount++;
      }
      if (defaultHasDriverLicense && !_hasDriverLicense) {
        _hasDriverLicense = true;
        filledCount++;
      }
      if (_hasDriverLicense && _driverCodeController.text.trim().isEmpty) {
        _driverCodeController.text = defaultDriverCode;
        filledCount++;
      }
      if (_hasDriverLicense && _licenseExpiry == null) {
        _licenseExpiry = defaultLicenseExpiry;
        filledCount++;
      }
      if (defaultHasPdp && !_hasPdp) {
        _hasPdp = true;
        filledCount++;
      }
      if (_hasPdp && _pdpExpiry == null) {
        _pdpExpiry = defaultPdpExpiry;
        filledCount++;
      }
      if (_deviceUidController.text.trim().isEmpty) {
        _deviceUidController.text = defaultDeviceUid;
        filledCount++;
      }
      if (_phoneController.text.trim().isEmpty) {
        _phoneController.text = defaultPhone;
        filledCount++;
      }
      if (_emailController.text.trim().isEmpty) {
        _emailController.text = defaultEmail;
        filledCount++;
      }
      if (_role != 'controller' &&
          _assignedSiteId.trim().isEmpty &&
          defaultAssignedSite.isNotEmpty) {
        _assignedSiteId = defaultAssignedSite;
        filledCount++;
      }
    });
    return filledCount;
  }

  String _employeePitchText() {
    final fullName =
        '${_fullNameController.text.trim()} ${_surnameController.text.trim()}'
            .trim();
    final name = fullName.isEmpty ? 'this resource' : fullName;
    final roleLabel = _role.replaceAll('_', ' ');
    final psira = _psiraNumberController.text.trim();
    final assignment = _assignedSiteId.trim().isEmpty
        ? 'unassigned (standby)'
        : _assignedSiteId.trim();
    final complianceLine = psira.isEmpty
        ? 'Role compliance is tracked in the registry.'
        : 'PSIRA reference $psira is linked for audit-ready dispatching.';
    return 'ONYX has onboarded $name as $roleLabel with deployment assignment $assignment. '
        '$complianceLine This profile can be activated in operations immediately.';
  }

  String _runDemoReady() {
    final filledCount = _autoFillMissingForDemo();
    final target = _nextIncompleteStep;
    if (target != null) {
      setState(() => _step = target);
      return filledCount <= 0
          ? 'Complete Step ${target + 1} to finish employee readiness.'
          : '$filledCount fields auto-filled. Continue on Step ${target + 1}.';
    }
    setState(() => _step = 2);
    return filledCount <= 0
        ? 'Already demo-ready for employee onboarding.'
        : 'Employee onboarding demo-ready with $filledCount fields auto-filled.';
  }

  String _recoverDemoPace() {
    setState(() => _sessionStartedAt = DateTime.now());
    final readiness = _runDemoReady();
    return 'Demo pace reset. $readiness';
  }

  String _resolvedEmployeePreviewReference() {
    final assignedSiteId = _assignedSiteId.trim().toUpperCase();
    if (assignedSiteId.isNotEmpty) return assignedSiteId;
    final employeeCode = _employeeCodeController.text.trim().toUpperCase();
    if (employeeCode.isNotEmpty) return employeeCode;
    final fullNameToken =
        '${_fullNameController.text.trim()} ${_surnameController.text.trim()}'
            .trim()
            .toUpperCase()
            .replaceAll(RegExp(r'[^A-Z0-9]+'), '-')
            .replaceAll(RegExp(r'-+'), '-')
            .replaceAll(RegExp(r'^-|-$'), '');
    if (fullNameToken.isNotEmpty) return 'EMP-$fullNameToken';
    return '';
  }

  void _openEmployeeOperationsPreview() {
    final openOperations = widget.onOpenOperationsForIncident;
    if (openOperations == null) {
      _showOnboardingSnackBar(
        context,
        'Operations view navigation unavailable.',
      );
      return;
    }
    final focusReference = _resolvedEmployeePreviewReference();
    if (focusReference.isEmpty) {
      _showOnboardingSnackBar(
        context,
        'Set employee identity or assignment before opening Operations.',
      );
      return;
    }
    Navigator.of(context).pop();
    openOperations.call(focusReference);
  }

  void _openEmployeeTacticalPreview() {
    final openTactical = widget.onOpenTacticalForIncident;
    if (openTactical == null) {
      _showOnboardingSnackBar(context, 'Tactical view navigation unavailable.');
      return;
    }
    final focusReference = _resolvedEmployeePreviewReference();
    if (focusReference.isEmpty) {
      _showOnboardingSnackBar(
        context,
        'Set employee identity or assignment before opening Tactical.',
      );
      return;
    }
    Navigator.of(context).pop();
    openTactical.call(focusReference);
  }

  String get _demoReadyButtonLabel {
    final readyCount = _previewGates.where((gate) => gate.ready).length;
    final total = _previewGates.length;
    if (total > 0 && readyCount == total) {
      return 'Demo Ready ✓';
    }
    return 'Demo Ready $readyCount/$total';
  }

  IconData get _demoReadyButtonIcon =>
      _allGatesReady ? Icons.task_alt_rounded : Icons.bolt_rounded;

  Color get _demoReadyButtonColor =>
      _allGatesReady ? const Color(0xFF0F766E) : const Color(0xFF5C66D6);

  bool get _employeeTemplatePending =>
      _selectedEmployeeScenario != _appliedEmployeeScenario;

  String _employeeSnapshotText() {
    final readyCount = _previewGates.where((gate) => gate.ready).length;
    final gateTotal = _previewGates.length;
    final completionPct = (_completionScore.clamp(0.0, 1.0) * 100).round();
    final nextGap = _nextIncompleteStep;
    return 'Employee Demo Snapshot\n'
        'Scenario: ${_employeeScenarioLabel(_selectedEmployeeScenario)}\n'
        'Template: ${_employeeTemplatePending ? 'Pending apply' : 'Applied'}\n'
        'Progress: Step ${_step + 1}/3\n'
        'Readiness: $readyCount/$gateTotal\n'
        'Completion: $completionPct%\n'
        'Next Gap: ${nextGap == null ? 'None' : 'Step ${nextGap + 1}'}\n'
        '${_previewLines.join('\n')}';
  }

  void _applyEmployeeScenario(String scenario) {
    final stamp = DateTime.now().millisecondsSinceEpoch % 10000;
    final firstSite = _siteOptions.isEmpty ? '' : _siteOptions.first.id;
    setState(() {
      _selectedEmployeeScenario = scenario;
      _appliedEmployeeScenario = scenario;
      switch (scenario) {
        case 'static_guard':
          _employeeCodeController.text = 'DEMO-EMP-G$stamp';
          _fullNameController.text = 'Lerato';
          _surnameController.text = 'Nkosi';
          _idNumberController.text = '9205150890084';
          _role = 'guard';
          _dob = DateTime(1992, 5, 15);
          _psiraNumberController.text = 'PSI-DEMO-G$stamp';
          _psiraGrade = 'C';
          _psiraExpiry = DateTime.now().add(const Duration(days: 460));
          _hasDriverLicense = false;
          _driverCodeController.clear();
          _licenseExpiry = null;
          _hasPdp = false;
          _pdpExpiry = null;
          _deviceUidController.text = 'BV5300P-GRD-$stamp';
          _phoneController.text = '+27 84 611 3301';
          _emailController.text = 'lerato.guard@onyx-security.co.za';
          _assignedSiteId = firstSite;
          break;
        case 'controller':
          _employeeCodeController.text = 'DEMO-EMP-C$stamp';
          _fullNameController.text = 'Anele';
          _surnameController.text = 'Jacobs';
          _idNumberController.text = '9003031234080';
          _role = 'controller';
          _dob = DateTime(1990, 3, 3);
          _psiraNumberController.text = '';
          _psiraGrade = 'C';
          _psiraExpiry = null;
          _hasDriverLicense = false;
          _driverCodeController.clear();
          _licenseExpiry = null;
          _hasPdp = false;
          _pdpExpiry = null;
          _deviceUidController.text = 'ONYX-CONSOLE-$stamp';
          _phoneController.text = '+27 83 740 1144';
          _emailController.text = 'anele.controller@onyx-security.co.za';
          _assignedSiteId = '';
          break;
        case 'reaction_officer':
        default:
          _employeeCodeController.text = 'DEMO-EMP-$stamp';
          _fullNameController.text = 'Kagiso';
          _surnameController.text = 'Molefe';
          _idNumberController.text = '8808085501081';
          _role = 'reaction_officer';
          _dob = DateTime(1988, 8, 8);
          _psiraNumberController.text = 'PSI-DEMO-$stamp';
          _psiraGrade = 'B';
          _psiraExpiry = DateTime.now().add(const Duration(days: 540));
          _hasDriverLicense = true;
          _driverCodeController.text = 'Code 10';
          _licenseExpiry = DateTime.now().add(const Duration(days: 900));
          _hasPdp = true;
          _pdpExpiry = DateTime.now().add(const Duration(days: 700));
          _deviceUidController.text = 'BV5300P-DEMO-$stamp';
          _phoneController.text = '+27 82 711 2233';
          _emailController.text = 'kagiso.demo@onyx-security.co.za';
          _assignedSiteId = firstSite;
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    return Dialog(
      backgroundColor: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF30363D)),
      ),
      child: SizedBox(
        width: _responsiveDialogWidth(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _onboardingHero(
                  context: context,
                  title: 'New Employee Onboarding',
                  subtitle:
                      'Capture PSIRA, licensing, and assignment data with operational readiness checks.',
                  accent: const Color(0xFF5C66D6),
                  responseTarget: 'Registry + assignment under 90s',
                  confidenceLabel: 'Compliance confidence 98.6%',
                  talkTrackTitle: 'Employee Demo Talk Track',
                  talkTrackLines: const [
                    'All personnel are centralized in one registry with role-based metadata.',
                    'PSIRA and licensing checks are captured at entry to reduce compliance drift.',
                    'Assignment links each employee to active site operations immediately.',
                    'This keeps dispatch readiness and auditability aligned by design.',
                  ],
                  compact: compact,
                  chips: const ['Role & Identity', 'Compliance', 'Deployment'],
                ),
                if (widget.demoMode) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () {
                          _applyDemoTemplate();
                          _showOnboardingSnackBar(
                            context,
                            '${_employeeScenarioLabel(_selectedEmployeeScenario)} template applied.',
                          );
                        },
                        icon: Icon(
                          _employeeTemplatePending
                              ? Icons.hourglass_top_rounded
                              : Icons.auto_awesome_rounded,
                          size: 16,
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _employeeTemplatePending
                              ? const Color(0xFF9A4D08)
                              : const Color(0xFF1F3A5A),
                          foregroundColor: const Color(0xFFEAF4FF),
                        ),
                        label: Text(
                          _employeeTemplatePending
                              ? 'Apply ${_employeeScenarioLabel(_selectedEmployeeScenario)} Template'
                              : '${_employeeScenarioLabel(_selectedEmployeeScenario)} Template Applied',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () async {
                          final launchMessage = _launchDemoFlow();
                          await Clipboard.setData(
                            ClipboardData(text: _employeePitchText()),
                          );
                          if (!context.mounted) return;
                          _showOnboardingSnackBar(
                            context,
                            '$launchMessage Pitch copied.',
                          );
                        },
                        icon: const Icon(Icons.rocket_launch_rounded, size: 16),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: const Color(0xFFEAF4FF),
                        ),
                        label: Text(
                          'Launch Demo',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () =>
                            _showOnboardingSnackBar(context, _runDemoReady()),
                        icon: Icon(_demoReadyButtonIcon, size: 16),
                        style: FilledButton.styleFrom(
                          backgroundColor: _demoReadyButtonColor,
                          foregroundColor: const Color(0xFFEAF4FF),
                        ),
                        label: Text(
                          _demoReadyButtonLabel,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                      _demoScenarioPicker(
                        label: 'Employee Scenario',
                        selectedValue: _selectedEmployeeScenario,
                        isApplied: !_employeeTemplatePending,
                        onSelected: (scenario) {
                          setState(() => _selectedEmployeeScenario = scenario);
                          final pending =
                              _selectedEmployeeScenario !=
                              _appliedEmployeeScenario;
                          _showOnboardingSnackBar(
                            context,
                            pending
                                ? '${_employeeScenarioLabel(scenario)} scenario selected. Tap Apply to populate fields.'
                                : '${_employeeScenarioLabel(scenario)} scenario already applied.',
                          );
                        },
                        options: const [
                          _DemoScenarioOption(
                            value: 'reaction_officer',
                            label: 'Reaction Officer',
                            detail: 'Licensed rapid response profile.',
                          ),
                          _DemoScenarioOption(
                            value: 'static_guard',
                            label: 'Static Guard',
                            detail: 'Checkpoint and patrol profile.',
                          ),
                          _DemoScenarioOption(
                            value: 'controller',
                            label: 'Control Room Operator',
                            detail: 'Operations desk governance profile.',
                          ),
                        ],
                      ),
                      OutlinedButton.icon(
                        onPressed: _resetDemoPace,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8FD1FF),
                          side: const BorderSide(color: Color(0xFF35506F)),
                        ),
                        label: Text(
                          'Reset Pace',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          final resetCount = _startFreshDemo();
                          final message = resetCount <= 0
                              ? 'Already fresh and ready for next demo.'
                              : resetCount == 1
                              ? '1 item reset for a fresh demo.'
                              : '$resetCount items reset for a fresh demo.';
                          _showOnboardingSnackBar(context, message);
                        },
                        icon: const Icon(
                          Icons.cleaning_services_rounded,
                          size: 16,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF9FD6FF),
                          side: const BorderSide(color: Color(0xFF35506F)),
                        ),
                        label: Text(
                          'Start Fresh',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          final target = _nextIncompleteStep;
                          if (target == null) {
                            _showOnboardingSnackBar(
                              context,
                              'All readiness gates are already complete.',
                            );
                            return;
                          }
                          setState(() => _step = target);
                          _showOnboardingSnackBar(
                            context,
                            'Jumped to Step ${target + 1} for missing inputs.',
                          );
                        },
                        icon: const Icon(Icons.track_changes_rounded, size: 16),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFFE1B8),
                          side: const BorderSide(color: Color(0xFFB3742C)),
                        ),
                        label: Text(
                          'Next Gap',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.onOpenOperationsForIncident == null
                            ? null
                            : _openEmployeeOperationsPreview,
                        icon: const Icon(
                          Icons.space_dashboard_rounded,
                          size: 16,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFBFD7F2),
                          side: const BorderSide(color: Color(0xFF35506F)),
                        ),
                        label: Text(
                          'Open Operations',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.onOpenTacticalForIncident == null
                            ? null
                            : _openEmployeeTacticalPreview,
                        icon: const Icon(Icons.map_rounded, size: 16),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF9FE8FF),
                          side: const BorderSide(color: Color(0xFF35506F)),
                        ),
                        label: Text(
                          'Open Tactical',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: _employeePitchText()),
                          );
                          if (!context.mounted) return;
                          _showOnboardingSnackBar(
                            context,
                            'Employee pitch copied.',
                          );
                        },
                        icon: const Icon(Icons.mic_rounded, size: 16),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFBFE6FF),
                          side: const BorderSide(color: Color(0xFF35506F)),
                        ),
                        label: Text(
                          'Copy Pitch',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: _employeeSnapshotText()),
                          );
                          if (!context.mounted) return;
                          _showOnboardingSnackBar(
                            context,
                            'Employee snapshot copied.',
                          );
                        },
                        icon: const Icon(Icons.receipt_long_rounded, size: 16),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFD5EBFF),
                          side: const BorderSide(color: Color(0xFF35506F)),
                        ),
                        label: Text(
                          'Copy Snapshot',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
                if ((_error ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFF87171),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                _creationPulseBanner(
                  visible: _showCreatePulse,
                  accent: const Color(0xFF5C66D6),
                  label: 'Employee readiness profile is live and assignable.',
                ),
                const SizedBox(height: 8),
                _stepSummary(
                  currentStep: _step,
                  labels: const ['Identity', 'Compliance', 'Assignment'],
                  onStepTap: (step) => setState(() => _step = step),
                  readinessGates: _previewGates,
                ),
                const SizedBox(height: 8),
                _demoPaceMeter(
                  startedAt: _sessionStartedAt,
                  targetSeconds: 90,
                  accent: const Color(0xFF5C66D6),
                  compact: compact,
                  onRecover: widget.demoMode
                      ? () =>
                            _showOnboardingSnackBar(context, _recoverDemoPace())
                      : null,
                  recoverLabel: 'Recover Employee Pace',
                ),
                const SizedBox(height: 8),
                _demoCoachCard(
                  context: context,
                  accent: const Color(0xFF5C66D6),
                  currentStep: _step,
                  compact: compact,
                  cues: const [
                    _DemoCoachCue(
                      stage: 'Identity',
                      narration:
                          'All staff types live in one registry with role metadata, so permissions and dispatch context stay coherent.',
                      proofPoint:
                          'Controller, guard, and reaction teams share one source of truth.',
                    ),
                    _DemoCoachCue(
                      stage: 'Compliance',
                      narration:
                          'PSIRA and license fields are captured as operational prerequisites, not optional notes.',
                      proofPoint:
                          'Readiness checks can block ineligible assignments automatically.',
                    ),
                    _DemoCoachCue(
                      stage: 'Assignment',
                      narration:
                          'Primary site assignment makes this profile deployable immediately once saved.',
                      proofPoint:
                          'Cuts setup-to-response time during client onboarding demos.',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _onboardingLivePreview(
                  context: context,
                  title: 'Readiness Preview',
                  accent: const Color(0xFF5C66D6),
                  lines: _previewLines,
                  gates: _previewGates,
                  completion: _completionScore,
                  compact: compact,
                  payload: _payloadPreview,
                  sqlTable: 'employees',
                  sqlConflictColumns: const ['client_id', 'employee_code'],
                  sqlExtraStatements: [_assignmentSqlPreview],
                  onAutoFillMissing: widget.demoMode
                      ? _autoFillMissingForDemo
                      : null,
                  autoFillLabel:
                      'Auto-Fill ${_employeeScenarioLabel(_selectedEmployeeScenario)} Demo',
                  onJumpToStep: (step) => setState(() => _step = step),
                ),
                const SizedBox(height: 8),
                Theme(
                  data: _onboardingStepperTheme(context),
                  child: Stepper(
                    currentStep: _step,
                    onStepTapped: (value) => setState(() => _step = value),
                    controlsBuilder: (context, details) {
                      final isFinalStep = _step == 2;
                      final readyForCreate = _allGatesReady;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _next,
                            icon: Icon(
                              isFinalStep
                                  ? (readyForCreate
                                        ? Icons.check_circle_rounded
                                        : Icons.error_outline_rounded)
                                  : Icons.arrow_forward_rounded,
                              size: 16,
                            ),
                            style: _onboardingPrimaryActionStyle(
                              accent: const Color(0xFF5C66D6),
                              isFinalStep: isFinalStep,
                              readyForCreate: readyForCreate,
                            ),
                            label: Text(
                              isFinalStep
                                  ? (readyForCreate
                                        ? 'Create Employee (Ready)'
                                        : 'Create Employee (Needs Inputs)')
                                  : 'Next',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: _step == 0
                                ? () => Navigator.of(context).pop()
                                : () => setState(() => _step -= 1),
                            icon: Icon(
                              _step == 0
                                  ? Icons.close_rounded
                                  : Icons.arrow_back_rounded,
                              size: 16,
                            ),
                            style: _onboardingSecondaryActionStyle(),
                            label: Text(
                              _step == 0 ? 'Cancel' : 'Back',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (isFinalStep && !readyForCreate)
                            OutlinedButton.icon(
                              onPressed: () {
                                final target = _nextIncompleteStep;
                                if (target == null) return;
                                setState(() => _step = target);
                              },
                              icon: const Icon(
                                Icons.track_changes_rounded,
                                size: 16,
                              ),
                              style: _onboardingMissingStepActionStyle(),
                              label: Text(
                                'Go To Missing Step',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                    steps: [
                      Step(
                        state: _stepStateFor(stepIndex: 0, currentStep: _step),
                        isActive: true,
                        title: _stepTitle(
                          'Identity',
                          stepIndex: 0,
                          currentStep: _step,
                        ),
                        content: _stepPanel(
                          children: [
                            _dropdownField(
                              label: 'Client',
                              value: _clientId,
                              items: widget.clients
                                  .map((client) => client.id)
                                  .toList(),
                              labels: {
                                for (final client in widget.clients)
                                  client.id: '${client.name} (${client.id})',
                              },
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _clientId = value;
                                  _assignedSiteId = '';
                                });
                              },
                            ),
                            const SizedBox(height: 8),
                            _textField(
                              _employeeCodeController,
                              'Employee Code',
                            ),
                            const SizedBox(height: 8),
                            _dropdownField(
                              label: 'Primary Role',
                              value: _role,
                              items: const [
                                'controller',
                                'supervisor',
                                'guard',
                                'reaction_officer',
                                'manager',
                                'admin',
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _role = value);
                              },
                            ),
                            const SizedBox(height: 8),
                            _textField(_fullNameController, 'Full Name'),
                            const SizedBox(height: 8),
                            _textField(_surnameController, 'Surname'),
                            const SizedBox(height: 8),
                            _textField(
                              _idNumberController,
                              'ID / Passport Number',
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => _pickDate(
                                current: _dob,
                                onSelected: (date) =>
                                    setState(() => _dob = date),
                              ),
                              icon: const Icon(Icons.cake_rounded, size: 16),
                              label: Text(
                                _dob == null
                                    ? 'Set Date of Birth'
                                    : 'DOB: ${_dateOnly(_dob!)}',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Step(
                        state: _stepStateFor(stepIndex: 1, currentStep: _step),
                        isActive: true,
                        title: _stepTitle(
                          'PSIRA & Compliance',
                          stepIndex: 1,
                          currentStep: _step,
                        ),
                        content: _stepPanel(
                          children: [
                            _textField(_psiraNumberController, 'PSIRA Number'),
                            const SizedBox(height: 8),
                            _dropdownField(
                              label: 'PSIRA Grade',
                              value: _psiraGrade,
                              items: const ['A', 'B', 'C', 'D', 'E'],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _psiraGrade = value);
                              },
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => _pickDate(
                                current: _psiraExpiry,
                                onSelected: (date) =>
                                    setState(() => _psiraExpiry = date),
                              ),
                              icon: const Icon(Icons.badge_rounded, size: 16),
                              label: Text(
                                _psiraExpiry == null
                                    ? 'Set PSIRA Expiry'
                                    : 'PSIRA Expiry: ${_dateOnly(_psiraExpiry!)}',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Step(
                        state: _stepStateFor(stepIndex: 2, currentStep: _step),
                        isActive: true,
                        title: _stepTitle(
                          'Licensing & Assignment',
                          stepIndex: 2,
                          currentStep: _step,
                        ),
                        content: _stepPanel(
                          children: [
                            SwitchListTile(
                              value: _hasDriverLicense,
                              onChanged: (value) =>
                                  setState(() => _hasDriverLicense = value),
                              title: Text(
                                'Has Driver License',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFEAF4FF),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (_hasDriverLicense) ...[
                              _textField(_driverCodeController, 'License Code'),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () => _pickDate(
                                  current: _licenseExpiry,
                                  onSelected: (date) =>
                                      setState(() => _licenseExpiry = date),
                                ),
                                icon: const Icon(Icons.event_rounded, size: 16),
                                label: Text(
                                  _licenseExpiry == null
                                      ? 'Set License Expiry'
                                      : 'License Expiry: ${_dateOnly(_licenseExpiry!)}',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            SwitchListTile(
                              value: _hasPdp,
                              onChanged: (value) =>
                                  setState(() => _hasPdp = value),
                              title: Text(
                                'Has PDP',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFEAF4FF),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (_hasPdp) ...[
                              OutlinedButton.icon(
                                onPressed: () => _pickDate(
                                  current: _pdpExpiry,
                                  onSelected: (date) =>
                                      setState(() => _pdpExpiry = date),
                                ),
                                icon: const Icon(Icons.event_rounded, size: 16),
                                label: Text(
                                  _pdpExpiry == null
                                      ? 'Set PDP Expiry'
                                      : 'PDP Expiry: ${_dateOnly(_pdpExpiry!)}',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            _textField(_deviceUidController, 'Device UID'),
                            const SizedBox(height: 8),
                            _textField(_phoneController, 'Contact Phone'),
                            const SizedBox(height: 8),
                            _textField(_emailController, 'Contact Email'),
                            const SizedBox(height: 8),
                            _dropdownField(
                              label: 'Primary Site Assignment',
                              value: _assignedSiteId,
                              items: [
                                '',
                                ..._siteOptions.map((site) => site.id),
                              ],
                              labels: {
                                '': 'Unassigned',
                                for (final site in _siteOptions)
                                  site.id: '${site.name} (${site.id})',
                              },
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _assignedSiteId = value);
                              },
                            ),
                          ],
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
}

void _showOnboardingSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: const Color(0xFF0F1419),
      behavior: SnackBarBehavior.floating,
      content: Text(
        message,
        style: GoogleFonts.inter(
          color: const Color(0xFFEAF4FF),
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

Widget _onboardingHero({
  required BuildContext context,
  required String title,
  required String subtitle,
  required Color accent,
  required List<String> chips,
  required String responseTarget,
  required String confidenceLabel,
  required String talkTrackTitle,
  required List<String> talkTrackLines,
  bool compact = false,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [accent.withValues(alpha: 0.35), const Color(0xFF0E1520)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: accent.withValues(alpha: 0.55)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.rajdhani(
                  color: const Color(0xFFEAF4FF),
                  fontSize: compact ? 22 : 27,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () => _showTalkTrackDialog(
                context,
                title: talkTrackTitle,
                lines: talkTrackLines,
                accent: accent,
              ),
              icon: const Icon(Icons.record_voice_over_rounded, size: 16),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEAF4FF),
                side: BorderSide(color: accent.withValues(alpha: 0.85)),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 8 : 10,
                  vertical: 8,
                ),
              ),
              label: Text(
                compact ? 'Track' : 'Demo Talk Track',
                style: GoogleFonts.inter(
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            color: const Color(0xFFCCE4FF),
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: chips
              .map((chip) => _onboardingTag(label: chip, accent: accent))
              .toList(growable: false),
        ),
        const SizedBox(height: 10),
        _heroSignalStrip(
          accent: accent,
          responseTarget: responseTarget,
          confidenceLabel: confidenceLabel,
          compact: compact,
        ),
      ],
    ),
  );
}

Widget _onboardingTag({required String label, required Color accent}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: accent.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: accent.withValues(alpha: 0.7)),
    ),
    child: Text(
      label,
      style: GoogleFonts.inter(
        color: const Color(0xFFEAF4FF),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

Widget _heroSignalStrip({
  required Color accent,
  required String responseTarget,
  required String confidenceLabel,
  required bool compact,
}) {
  return StreamBuilder<int>(
    stream: Stream.periodic(const Duration(seconds: 1), (tick) => tick),
    initialData: 0,
    builder: (context, snapshot) {
      final now = DateTime.now();
      final pulseOn = ((snapshot.data ?? 0) % 2 == 0);
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0x22182736),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xAA496580)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: pulseOn ? 1 : 0.45,
                  child: Icon(
                    Icons.circle,
                    size: 8,
                    color: accent.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Live ${_timeStamp(now)} SAST',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEAF4FF),
                    fontSize: compact ? 10 : 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0x22182736),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xAA496580)),
            ),
            child: Text(
              responseTarget,
              style: GoogleFonts.inter(
                color: const Color(0xFFCCE4FF),
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: accent.withValues(alpha: 0.75)),
            ),
            child: Text(
              confidenceLabel,
              style: GoogleFonts.inter(
                color: const Color(0xFFEAF4FF),
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      );
    },
  );
}

Widget _demoScenarioPicker({
  required String label,
  String? selectedValue,
  required ValueChanged<String> onSelected,
  required List<_DemoScenarioOption> options,
  bool isApplied = true,
}) {
  _DemoScenarioOption? activeOption;
  for (final option in options) {
    if (option.value == selectedValue) {
      activeOption = option;
      break;
    }
  }
  final triggerLabel = activeOption == null
      ? label
      : '$label: ${activeOption.label}';
  return PopupMenuButton<String>(
    onSelected: onSelected,
    color: const Color(0xFF101923),
    itemBuilder: (context) {
      return options
          .map((option) {
            final selected = option.value == selectedValue;
            return PopupMenuItem<String>(
              value: option.value,
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
                decoration: BoxDecoration(
                  color: selected ? const Color(0x2234D399) : null,
                  borderRadius: BorderRadius.circular(8),
                  border: selected
                      ? Border.all(color: const Color(0xAA34D399))
                      : null,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 18,
                      child: selected
                          ? const Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: Color(0xFF34D399),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            option.label,
                            style: GoogleFonts.inter(
                              color: const Color(0xFFEAF4FF),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            option.detail,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF9AB1CF),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          })
          .toList(growable: false);
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1B2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF35506F)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.layers_clear_rounded,
            size: 16,
            color: Color(0xFF8FD1FF),
          ),
          const SizedBox(width: 6),
          Text(
            triggerLabel,
            style: GoogleFonts.inter(
              color: const Color(0xFFEAF4FF),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (activeOption != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isApplied
                    ? const Color(0x2234D399)
                    : const Color(0x22F59E0B),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isApplied
                      ? const Color(0xAA34D399)
                      : const Color(0xAAF59E0B),
                ),
              ),
              child: Text(
                isApplied ? 'Applied' : 'Pending',
                style: GoogleFonts.inter(
                  color: const Color(0xFFEAF4FF),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          const SizedBox(width: 6),
          const Icon(
            Icons.expand_more_rounded,
            size: 16,
            color: Color(0xFF8FD1FF),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showTalkTrackDialog(
  BuildContext context, {
  required String title,
  required List<String> lines,
  required Color accent,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: const Color(0xFF121A24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: accent.withValues(alpha: 0.7)),
        ),
        child: SizedBox(
          width: _responsiveDialogWidth(dialogContext, maxWidth: 620),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.26),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Icon(
                        Icons.campaign_rounded,
                        size: 16,
                        color: accent.withValues(alpha: 0.95),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.rajdhani(
                          color: const Color(0xFFEAF4FF),
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < lines.length; i++) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFEAF4FF),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            lines[i],
                            style: GoogleFonts.inter(
                              color: const Color(0xFFCCE4FF),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (i != lines.length - 1) const SizedBox(height: 8),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: accent.withValues(alpha: 0.8),
                      foregroundColor: const Color(0xFFEAF4FF),
                    ),
                    child: Text(
                      'Continue',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<bool> _confirmIncompleteReadiness(
  BuildContext context, {
  required String entityLabel,
  required List<_PreviewGate> gates,
  required Color accent,
}) async {
  final blockers = gates.where((gate) => !gate.ready).toList(growable: false);
  if (blockers.isEmpty) return true;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: const Color(0xFF121A24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: accent.withValues(alpha: 0.65)),
        ),
        title: Text(
          'Create $entityLabel With Missing Inputs?',
          style: GoogleFonts.inter(
            color: const Color(0xFFEAF4FF),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: SizedBox(
          width: _responsiveDialogWidth(context, maxWidth: 580),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The following readiness gates are incomplete:',
                style: GoogleFonts.inter(
                  color: const Color(0xFFBFD7F2),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              for (final gate in blockers.take(6)) ...[
                Text(
                  '• ${gate.label} (Step ${gate.step + 1})',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFFFDDAA),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              const SizedBox(height: 6),
              Text(
                'Select "Review Missing" to jump back and complete inputs, or "Create Anyway" to continue.',
                style: GoogleFonts.inter(
                  color: const Color(0xFF9AB1CF),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            icon: const Icon(Icons.visibility_rounded, size: 16),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF8FD1FF),
            ),
            label: Text(
              'Review Missing',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800),
            ),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.warning_amber_rounded, size: 16),
            style: FilledButton.styleFrom(
              backgroundColor: accent.withValues(alpha: 0.78),
              foregroundColor: const Color(0xFFEAF4FF),
            ),
            label: Text(
              'Create Anyway',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

Widget _demoPaceMeter({
  required DateTime startedAt,
  required int targetSeconds,
  required Color accent,
  required bool compact,
  VoidCallback? onRecover,
  String recoverLabel = 'Recover Pace',
}) {
  return StreamBuilder<int>(
    stream: Stream.periodic(const Duration(seconds: 1), (tick) => tick),
    initialData: 0,
    builder: (context, snapshot) {
      final elapsed = DateTime.now().difference(startedAt).inSeconds;
      final progress = (elapsed / targetSeconds).clamp(0.0, 1.0);
      final bool ahead = elapsed <= (targetSeconds * 0.8).round();
      final bool onTrack = elapsed <= targetSeconds;
      final delaySeconds = elapsed - targetSeconds;
      final statusLabel = ahead ? 'Ahead' : (onTrack ? 'On Track' : 'Behind');
      final statusColor = ahead
          ? const Color(0xFF34D399)
          : (onTrack ? const Color(0xFF8FD1FF) : const Color(0xFFF59E0B));
      final mm = (elapsed ~/ 60).toString().padLeft(2, '0');
      final ss = (elapsed % 60).toString().padLeft(2, '0');
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0A121B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.timer_rounded,
                  size: 14,
                  color: Color(0xFF8FD1FF),
                ),
                const SizedBox(width: 6),
                Text(
                  'Demo Pace',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEAF4FF),
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  '$mm:$ss / ${targetSeconds}s',
                  style: GoogleFonts.robotoMono(
                    color: const Color(0xFFEAF4FF),
                    fontSize: compact ? 10.5 : 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 5,
                value: progress,
                backgroundColor: const Color(0xFF1A2A3B),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.65),
                    ),
                  ),
                  child: Text(
                    statusLabel,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFEAF4FF),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (!onTrack) ...[
                  const SizedBox(width: 6),
                  Text(
                    '+${delaySeconds}s',
                    style: GoogleFonts.robotoMono(
                      color: const Color(0xFFFBBF24),
                      fontSize: compact ? 10 : 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
            if (!onTrack && onRecover != null) ...[
              const SizedBox(height: 7),
              FilledButton.icon(
                onPressed: onRecover,
                icon: const Icon(Icons.flash_on_rounded, size: 15),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF9A4D08),
                  foregroundColor: const Color(0xFFEAF4FF),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                ),
                label: Text(
                  recoverLabel,
                  style: GoogleFonts.inter(
                    fontSize: compact ? 10.5 : 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              'Target: keep onboarding within ${targetSeconds}s for live demo impact.',
              style: GoogleFonts.inter(
                color: const Color(0xFF9AB1CF),
                fontSize: compact ? 10 : 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _demoCoachCard({
  required BuildContext context,
  required Color accent,
  required int currentStep,
  required List<_DemoCoachCue> cues,
  required bool compact,
}) {
  if (cues.isEmpty) return const SizedBox.shrink();
  final clamped = currentStep.clamp(0, cues.length - 1);
  final cue = cues[clamped];
  final copyText =
      'Stage: ${cue.stage}\nNarration: ${cue.narration}\nProof: ${cue.proofPoint}';
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
    decoration: BoxDecoration(
      color: const Color(0xFF0A121C),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: accent.withValues(alpha: 0.55)),
    ),
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: Column(
        key: ValueKey<String>('${cue.stage}-$clamped'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.theater_comedy_rounded,
                size: 14,
                color: accent.withValues(alpha: 0.95),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Presenter Cue • ${clamped + 1}/${cues.length}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEAF4FF),
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withValues(alpha: 0.65)),
                ),
                child: Text(
                  cue.stage,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEAF4FF),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            cue.narration,
            style: GoogleFonts.inter(
              color: const Color(0xFFCCE4FF),
              fontSize: compact ? 10.5 : 11.5,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Proof: ${cue.proofPoint}',
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: compact ? 10 : 10.5,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: copyText));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF0F1419),
                    behavior: SnackBarBehavior.floating,
                    content: Text(
                      'Presenter cue copied.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFEAF4FF),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.content_copy_rounded, size: 15),
              style: TextButton.styleFrom(
                foregroundColor: accent.withValues(alpha: 0.95),
                visualDensity: VisualDensity.compact,
              ),
              label: Text(
                'Copy Cue',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _onboardingLivePreview({
  required BuildContext context,
  required String title,
  required Color accent,
  required List<String> lines,
  required List<_PreviewGate> gates,
  required double completion,
  required bool compact,
  required Map<String, dynamic> payload,
  required String sqlTable,
  List<String> sqlConflictColumns = const [],
  List<String> sqlExtraStatements = const [],
  int Function()? onAutoFillMissing,
  String autoFillLabel = 'Auto-Fill Missing',
  ValueChanged<int>? onJumpToStep,
}) {
  final pct = (completion.clamp(0.0, 1.0) * 100).round();
  final formattedPayload = _prettyJson(payload);
  final sqlUpsert = _buildUpsertSql(
    table: sqlTable,
    payload: payload,
    conflictColumns: sqlConflictColumns,
  );
  final filteredSqlExtras = sqlExtraStatements
      .where((statement) => statement.trim().isNotEmpty)
      .toList(growable: false);
  final sqlBundle = [sqlUpsert, ...filteredSqlExtras].join('\n\n');
  final sqlActionLabel = filteredSqlExtras.isEmpty
      ? 'Copy SQL Upsert'
      : 'Copy SQL Bundle';
  final readyCount = gates.where((gate) => gate.ready).length;
  final gateTotal = gates.length;
  final blockers = gates.where((gate) => !gate.ready).toList(growable: false);
  final nextBlocker = blockers.isEmpty ? null : blockers.first;
  final gatesByStep = <int, List<_PreviewGate>>{};
  for (final gate in gates) {
    gatesByStep.putIfAbsent(gate.step, () => <_PreviewGate>[]).add(gate);
  }
  final sortedSteps = gatesByStep.keys.toList()..sort();
  final demoReady = gateTotal == 0
      ? completion >= 0.9
      : readyCount == gateTotal;
  final verdictLabel = demoReady ? 'Demo Ready' : 'Needs Inputs';
  final blockersText = blockers.isEmpty
      ? 'None'
      : blockers.map((gate) => gate.label).join(', ');
  final gateStatus = gates
      .map(
        (gate) =>
            '- [${gate.ready ? 'x' : ' '}] ${gate.label} (Step ${gate.step + 1})',
      )
      .join('\n');
  final highlights = lines.map((line) => '- $line').join('\n');
  final clientUpdateText =
      '$title\n'
      'Status: $verdictLabel ($readyCount/$gateTotal readiness gates complete)\n'
      'Configured:\n$highlights\n\n'
      'Outstanding: ${blockersText == 'None' ? 'None' : blockersText}\n'
      'Next: ${nextBlocker == null ? 'Proceed to create this record.' : 'Complete "${nextBlocker.label}" in Step ${nextBlocker.step + 1}.'}';
  final briefText =
      '$title\n'
      'Readiness: $verdictLabel ($readyCount/$gateTotal)\n'
      'Blockers: $blockersText\n\n'
      'Gate Status:\n$gateStatus\n\n'
      'Highlights:\n$highlights\n\n'
      'Payload:\n$formattedPayload';
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
    decoration: BoxDecoration(
      color: const Color(0xFF0A111A),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: accent.withValues(alpha: 0.55)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.preview_rounded,
              size: 14,
              color: accent.withValues(alpha: 0.95),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  color: const Color(0xFFEAF4FF),
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '$pct%',
              style: GoogleFonts.inter(
                color: const Color(0xFFCCE4FF),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 5,
            value: completion.clamp(0.0, 1.0),
            backgroundColor: const Color(0xFF1A2A3B),
            valueColor: AlwaysStoppedAnimation<Color>(
              accent.withValues(alpha: 0.9),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _readinessStatusChip(
              label: verdictLabel,
              ready: demoReady,
              accent: accent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Readiness gates: $readyCount/$gateTotal',
                style: GoogleFonts.inter(
                  color: const Color(0xFFBFD7F2),
                  fontSize: compact ? 10.5 : 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (nextBlocker != null && onJumpToStep != null)
              TextButton.icon(
                onPressed: () => onJumpToStep(nextBlocker.step),
                icon: const Icon(Icons.play_arrow_rounded, size: 15),
                style: TextButton.styleFrom(
                  foregroundColor: accent.withValues(alpha: 0.95),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
                label: Text(
                  'Resolve Next',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: gates
              .map((gate) => _previewGateChip(gate: gate, accent: accent))
              .toList(growable: false),
        ),
        if (sortedSteps.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: sortedSteps
                .map((step) {
                  final stepGates = gatesByStep[step]!;
                  final stepReady = stepGates
                      .where((gate) => gate.ready)
                      .length;
                  return _stepReadinessChip(
                    step: step,
                    ready: stepReady,
                    total: stepGates.length,
                    accent: accent,
                    onPressed: onJumpToStep == null
                        ? null
                        : () => onJumpToStep(step),
                  );
                })
                .toList(growable: false),
          ),
        ],
        if (blockers.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: blockers
                .take(4)
                .map(
                  (gate) => _blockerChip(
                    gate: gate,
                    accent: accent,
                    onPressed: onJumpToStep == null
                        ? null
                        : () => onJumpToStep(gate.step),
                  ),
                )
                .toList(growable: false),
          ),
          if (onAutoFillMissing != null) ...[
            const SizedBox(height: 7),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () {
                  final filledCount = onAutoFillMissing();
                  final message = filledCount <= 0
                      ? 'No missing fields to auto-fill.'
                      : filledCount == 1
                      ? '1 field auto-filled for demo flow.'
                      : '$filledCount fields auto-filled for demo flow.';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF0F1419),
                      behavior: SnackBarBehavior.floating,
                      content: Text(
                        message,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFEAF4FF),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.auto_fix_high_rounded, size: 15),
                style: FilledButton.styleFrom(
                  backgroundColor: accent.withValues(alpha: 0.88),
                  foregroundColor: const Color(0xFFEAF4FF),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                label: Text(
                  autoFillLabel,
                  style: GoogleFonts.inter(
                    fontSize: 10.6,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: clientUpdateText),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF0F1419),
                      behavior: SnackBarBehavior.floating,
                      content: Text(
                        'Client update copied.',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFEAF4FF),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_rounded, size: 15),
                style: TextButton.styleFrom(
                  foregroundColor: accent.withValues(alpha: 0.95),
                  visualDensity: VisualDensity.compact,
                ),
                label: Text(
                  'Copy Client Update',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: briefText));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF0F1419),
                      behavior: SnackBarBehavior.floating,
                      content: Text(
                        'Demo brief copied.',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFEAF4FF),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.summarize_rounded, size: 15),
                style: TextButton.styleFrom(
                  foregroundColor: accent.withValues(alpha: 0.95),
                  visualDensity: VisualDensity.compact,
                ),
                label: Text(
                  'Copy Demo Brief',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: sqlBundle));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF0F1419),
                      behavior: SnackBarBehavior.floating,
                      content: Text(
                        filteredSqlExtras.isEmpty
                            ? 'SQL upsert copied.'
                            : 'SQL bundle copied.',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFEAF4FF),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.storage_rounded, size: 15),
                style: TextButton.styleFrom(
                  foregroundColor: accent.withValues(alpha: 0.95),
                  visualDensity: VisualDensity.compact,
                ),
                label: Text(
                  sqlActionLabel,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < lines.length; i++) ...[
          Text(
            lines[i],
            style: GoogleFonts.inter(
              color: const Color(0xFFBFD7F2),
              fontSize: compact ? 10.5 : 11,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          if (i != lines.length - 1) const SizedBox(height: 4),
        ],
        const SizedBox(height: 8),
        Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            iconColor: accent.withValues(alpha: 0.95),
            collapsedIconColor: const Color(0xFF8EA4C2),
            title: Text(
              'Payload JSON Preview',
              style: GoogleFonts.inter(
                color: const Color(0xFFEAF4FF),
                fontSize: compact ? 10.5 : 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF09111A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2D4A66)),
                ),
                child: SelectableText(
                  formattedPayload,
                  style: GoogleFonts.robotoMono(
                    color: const Color(0xFFCFE3F7),
                    fontSize: compact ? 9.5 : 10,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: formattedPayload),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF0F1419),
                        behavior: SnackBarBehavior.floating,
                        content: Text(
                          'Payload JSON copied.',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFEAF4FF),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.content_copy_rounded, size: 15),
                  style: TextButton.styleFrom(
                    foregroundColor: accent.withValues(alpha: 0.95),
                    visualDensity: VisualDensity.compact,
                  ),
                  label: Text(
                    'Copy JSON',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _readinessStatusChip({
  required String label,
  required bool ready,
  required Color accent,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: ready ? const Color(0x2234D399) : accent.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: ready ? const Color(0xAA34D399) : accent.withValues(alpha: 0.55),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          ready ? Icons.verified_rounded : Icons.warning_amber_rounded,
          size: 13,
          color: ready ? const Color(0xFF34D399) : const Color(0xFFFFDDAA),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(0xFFEAF4FF),
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

Widget _blockerChip({
  required _PreviewGate gate,
  required Color accent,
  VoidCallback? onPressed,
}) {
  return ActionChip(
    onPressed: onPressed,
    backgroundColor: const Color(0x332A1E1E),
    side: BorderSide(color: accent.withValues(alpha: 0.55)),
    avatar: const Icon(
      Icons.error_outline_rounded,
      size: 14,
      color: Color(0xFFFFDDAA),
    ),
    label: Text(
      onPressed == null ? gate.label : '${gate.label} (Step ${gate.step + 1})',
      style: GoogleFonts.inter(
        color: const Color(0xFFFFE6BE),
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
      ),
    ),
    labelPadding: const EdgeInsets.symmetric(horizontal: 2),
  );
}

Widget _stepReadinessChip({
  required int step,
  required int ready,
  required int total,
  required Color accent,
  VoidCallback? onPressed,
}) {
  final complete = total > 0 && ready == total;
  return ActionChip(
    onPressed: onPressed,
    backgroundColor: complete
        ? const Color(0x2234D399)
        : accent.withValues(alpha: 0.16),
    side: BorderSide(
      color: complete
          ? const Color(0xAA34D399)
          : accent.withValues(alpha: 0.55),
    ),
    avatar: Icon(
      complete ? Icons.task_alt_rounded : Icons.tune_rounded,
      size: 14,
      color: complete ? const Color(0xFF34D399) : const Color(0xFF8FD1FF),
    ),
    label: Text(
      'Step ${step + 1}: $ready/$total',
      style: GoogleFonts.inter(
        color: const Color(0xFFEAF4FF),
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
      ),
    ),
    labelPadding: const EdgeInsets.symmetric(horizontal: 2),
  );
}

Widget _previewGateChip({required _PreviewGate gate, required Color accent}) {
  final ready = gate.ready;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: ready ? const Color(0x2234D399) : accent.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: ready ? const Color(0xAA34D399) : accent.withValues(alpha: 0.45),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          ready ? Icons.check_circle_rounded : Icons.pending_rounded,
          size: 13,
          color: ready ? const Color(0xFF34D399) : const Color(0xFF8FD1FF),
        ),
        const SizedBox(width: 5),
        Text(
          gate.label,
          style: GoogleFonts.inter(
            color: const Color(0xFFEAF4FF),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

Widget _stepSummary({
  required int currentStep,
  required List<String> labels,
  ValueChanged<int>? onStepTap,
  List<_PreviewGate> readinessGates = const [],
}) {
  final activeIndex = currentStep.clamp(0, labels.length - 1);
  final progress = (activeIndex + 1) / labels.length;
  final gatesByStep = <int, List<_PreviewGate>>{};
  for (final gate in readinessGates) {
    gatesByStep.putIfAbsent(gate.step, () => <_PreviewGate>[]).add(gate);
  }
  final readySteps = labels.asMap().entries.where((entry) {
    final stepGates = gatesByStep[entry.key];
    if (stepGates == null || stepGates.isEmpty) return false;
    return stepGates.every((gate) => gate.ready);
  }).length;
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    decoration: BoxDecoration(
      color: const Color(0xFF0B131E),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF35506F)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF3C79BB),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Step ${activeIndex + 1}/${labels.length}',
                style: GoogleFonts.inter(
                  color: const Color(0xFFEAF4FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                labels[activeIndex],
                style: GoogleFonts.inter(
                  color: const Color(0xFFEAF4FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Ready $readySteps/${labels.length}',
              style: GoogleFonts.inter(
                color: const Color(0xFFBFD7F2),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < labels.length; i++)
              () {
                final stepGates = gatesByStep[i];
                final hasStepGates = stepGates != null && stepGates.isNotEmpty;
                final stepReadyCount = hasStepGates
                    ? stepGates.where((gate) => gate.ready).length
                    : 0;
                final stepTotal = stepGates?.length ?? 0;
                final stepComplete =
                    hasStepGates && stepReadyCount == stepTotal;
                final state = i == activeIndex
                    ? _SummaryChipState.active
                    : (stepComplete || i < activeIndex)
                    ? _SummaryChipState.done
                    : _SummaryChipState.pending;
                final readinessMeta = hasStepGates
                    ? '$stepReadyCount/$stepTotal'
                    : null;
                return _summaryChip(
                  number: i + 1,
                  label: labels[i],
                  state: state,
                  readinessMeta: readinessMeta,
                  onPressed: onStepTap == null ? null : () => onStepTap(i),
                );
              }(),
          ],
        ),
        if (onStepTap != null) ...[
          const SizedBox(height: 6),
          Text(
            'Tap any stage chip to jump directly.',
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 9),
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          tween: Tween<double>(begin: 0, end: progress),
          builder: (context, value, _) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: value,
                backgroundColor: const Color(0xFF1A2A3B),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF5FAAFF),
                ),
              ),
            );
          },
        ),
      ],
    ),
  );
}

Widget _stepPanel({
  required List<Widget> children,
  CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.stretch,
}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF0B121A),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF32506F)),
    ),
    child: Column(crossAxisAlignment: crossAxisAlignment, children: children),
  );
}

StepState _stepStateFor({required int stepIndex, required int currentStep}) {
  if (stepIndex < currentStep) return StepState.complete;
  if (stepIndex == currentStep) return StepState.editing;
  return StepState.indexed;
}

Widget _stepTitle(
  String label, {
  required int stepIndex,
  required int currentStep,
}) {
  final done = stepIndex < currentStep;
  final active = stepIndex == currentStep;
  final Color background;
  final Color border;
  final Color text;
  if (done) {
    background = const Color(0x2234D399);
    border = const Color(0xAA34D399);
    text = const Color(0xFFCCFFE8);
  } else if (active) {
    background = const Color(0xFF1E3652);
    border = const Color(0xFF5FAAFF);
    text = const Color(0xFFEAF4FF);
  } else {
    background = const Color(0xFF1F2D3D);
    border = const Color(0xFF6F88A5);
    text = const Color(0xFFE6F2FF);
  }
  final icon = done
      ? Icons.check_circle_rounded
      : (active ? Icons.play_circle_fill_rounded : Icons.circle_outlined);
  final iconColor = done
      ? const Color(0xFF7EF2C3)
      : (active ? const Color(0xFF9FD6FF) : const Color(0xFFD3E6FA));
  return AnimatedScale(
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOutCubic,
    scale: done ? 1.02 : 1.0,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: Icon(icon, key: ValueKey(icon), size: 14, color: iconColor),
          ),
          const SizedBox(width: 6),
          Text(
            '${stepIndex + 1}. $label',
            style: GoogleFonts.inter(
              color: text,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    ),
  );
}

ThemeData _onboardingStepperTheme(BuildContext context) {
  final base = Theme.of(context);
  return base.copyWith(
    disabledColor: const Color(0xFFBCD2EA),
    dividerColor: const Color(0xFF33506D),
    hintColor: const Color(0xFFBCD2EA),
    canvasColor: const Color(0xFF161B22),
    colorScheme: base.colorScheme.copyWith(
      primary: const Color(0xFF3C79BB),
      onPrimary: const Color(0xFFEAF4FF),
      onSurface: const Color(0xFFEAF4FF),
      surface: const Color(0xFF161B22),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: const Color(0xFFEAF4FF),
      displayColor: const Color(0xFFEAF4FF),
    ),
  );
}

ButtonStyle _onboardingPrimaryActionStyle({
  required Color accent,
  required bool isFinalStep,
  required bool readyForCreate,
}) {
  final background = isFinalStep
      ? (readyForCreate ? const Color(0xFF0F766E) : const Color(0xFFB45309))
      : accent;
  return FilledButton.styleFrom(
    backgroundColor: background,
    foregroundColor: const Color(0xFFEAF4FF),
    elevation: 0.6,
    minimumSize: const Size(172, 42),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );
}

ButtonStyle _onboardingSecondaryActionStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFFE2F1FF),
    backgroundColor: const Color(0xFF162333),
    side: const BorderSide(color: Color(0xFF4C6683)),
    minimumSize: const Size(112, 42),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );
}

ButtonStyle _onboardingMissingStepActionStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFFFFE1B8),
    backgroundColor: const Color(0xFF2A1D12),
    side: const BorderSide(color: Color(0xFFB3742C)),
    minimumSize: const Size(178, 42),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );
}

Widget _creationPulseBanner({
  required bool visible,
  required Color accent,
  required String label,
}) {
  return AnimatedSwitcher(
    duration: const Duration(milliseconds: 260),
    switchInCurve: Curves.easeOutBack,
    switchOutCurve: Curves.easeInCubic,
    transitionBuilder: (child, animation) {
      return SizeTransition(
        sizeFactor: animation,
        axisAlignment: -1,
        child: FadeTransition(opacity: animation, child: child),
      );
    },
    child: visible
        ? Container(
            key: ValueKey(label),
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.35),
                  const Color(0xFF0F1A28),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent.withValues(alpha: 0.75)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_rounded,
                  size: 16,
                  color: Color(0xFF7EF2C3),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFEAF4FF),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          )
        : const SizedBox.shrink(key: ValueKey('creation-pulse-hidden')),
  );
}

enum _SummaryChipState { done, active, pending }

Widget _summaryChip({
  required int number,
  required String label,
  required _SummaryChipState state,
  String? readinessMeta,
  VoidCallback? onPressed,
}) {
  final Color background;
  final Color border;
  final Color text;
  switch (state) {
    case _SummaryChipState.done:
      background = const Color(0x2234D399);
      border = const Color(0xAA34D399);
      text = const Color(0xFFCCFFE8);
      break;
    case _SummaryChipState.active:
      background = const Color(0x333C79BB);
      border = const Color(0xFF5FAAFF);
      text = const Color(0xFFEAF4FF);
      break;
    case _SummaryChipState.pending:
      background = const Color(0xFF1F2D3D);
      border = const Color(0xFF6F88A5);
      text = const Color(0xFFE6F2FF);
      break;
  }
  final done = state == _SummaryChipState.done;
  final icon = done
      ? Icons.check_circle_rounded
      : state == _SummaryChipState.active
      ? Icons.adjust_rounded
      : Icons.circle_outlined;
  final iconColor = done
      ? const Color(0xFF7EF2C3)
      : state == _SummaryChipState.active
      ? const Color(0xFF9FD6FF)
      : const Color(0xFFD3E6FA);
  final content = Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return ScaleTransition(
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: Icon(icon, key: ValueKey(icon), size: 13, color: iconColor),
      ),
      const SizedBox(width: 5),
      Text(
        '$number. $label',
        style: GoogleFonts.inter(
          color: text,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      if (readinessMeta != null) ...[
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border.withValues(alpha: 0.6)),
          ),
          child: Text(
            readinessMeta,
            style: GoogleFonts.inter(
              color: const Color(0xFFEAF4FF),
              fontSize: 9.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ],
  );
  return AnimatedSlide(
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOutCubic,
    offset: done ? const Offset(0, -0.02) : Offset.zero,
    child: AnimatedScale(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      scale: done ? 1.02 : 1.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: onPressed == null
            ? content
            : Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: onPressed,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 1.5,
                      vertical: 1,
                    ),
                    child: content,
                  ),
                ),
              ),
      ),
    ),
  );
}

double _responsiveDialogWidth(BuildContext context, {double maxWidth = 760}) {
  return math.max(
    320,
    math.min(maxWidth, MediaQuery.sizeOf(context).width - 24),
  );
}

String _timeStamp(DateTime value) {
  final hh = value.hour.toString().padLeft(2, '0');
  final mm = value.minute.toString().padLeft(2, '0');
  final ss = value.second.toString().padLeft(2, '0');
  return '$hh:$mm:$ss';
}

String _prettyJson(Map<String, dynamic> payload) {
  final cleaned = <String, dynamic>{};
  for (final entry in payload.entries) {
    final value = entry.value;
    if (value == null) continue;
    if (value is String && value.trim().isEmpty) continue;
    cleaned[entry.key] = value;
  }
  return const JsonEncoder.withIndent('  ').convert(cleaned);
}

String _buildUpsertSql({
  required String table,
  required Map<String, dynamic> payload,
  List<String> conflictColumns = const [],
}) {
  final cleaned = <String, dynamic>{};
  for (final entry in payload.entries) {
    final value = entry.value;
    if (value == null) continue;
    if (value is String && value.trim().isEmpty) continue;
    cleaned[entry.key] = value;
  }
  if (cleaned.isEmpty) {
    return '-- No non-empty fields available to generate SQL.';
  }
  final columns = cleaned.keys.toList(growable: false);
  final insertColumns = columns.map(_sqlIdentifier).join(', ');
  final insertValues = columns
      .map((column) => _sqlLiteral(cleaned[column]))
      .join(', ');
  final tableId = _sqlIdentifier(table);
  final insertBase =
      'INSERT INTO $tableId ($insertColumns)\nVALUES ($insertValues)';
  if (conflictColumns.isEmpty) {
    return '$insertBase;';
  }
  final setColumns = columns
      .where((column) => !conflictColumns.contains(column))
      .toList(growable: false);
  final conflictExpr = conflictColumns.map(_sqlIdentifier).join(', ');
  if (setColumns.isEmpty) {
    return '$insertBase\nON CONFLICT ($conflictExpr) DO NOTHING;';
  }
  final updates = setColumns
      .map((column) {
        final id = _sqlIdentifier(column);
        return '$id = EXCLUDED.$id';
      })
      .join(', ');
  return '$insertBase\nON CONFLICT ($conflictExpr) DO UPDATE SET $updates;';
}

String _buildEmployeeAssignmentUpsertSql({
  required String clientId,
  required String employeeCode,
  required String siteId,
}) {
  final resolvedClientId = clientId.trim();
  final resolvedEmployeeCode = employeeCode.trim();
  final resolvedSiteId = siteId.trim();
  if (resolvedClientId.isEmpty ||
      resolvedEmployeeCode.isEmpty ||
      resolvedSiteId.isEmpty) {
    return '';
  }
  final clientLit = _sqlLiteral(resolvedClientId);
  final employeeCodeLit = _sqlLiteral(resolvedEmployeeCode);
  final siteLit = _sqlLiteral(resolvedSiteId);
  return 'INSERT INTO "employee_site_assignments" '
      '("client_id", "employee_id", "site_id", "is_primary", "assignment_status")\n'
      'SELECT $clientLit, e."id", $siteLit, TRUE, \'active\'\n'
      'FROM "employees" e\n'
      'WHERE e."client_id" = $clientLit AND e."employee_code" = $employeeCodeLit\n'
      'ON CONFLICT ("employee_id", "site_id") DO UPDATE SET '
      '"client_id" = EXCLUDED."client_id", '
      '"is_primary" = EXCLUDED."is_primary", '
      '"assignment_status" = EXCLUDED."assignment_status";';
}

String _sqlIdentifier(String raw) {
  final escaped = raw.replaceAll('"', '""');
  return '"$escaped"';
}

String _sqlLiteral(Object? value) {
  if (value == null) return 'NULL';
  if (value is bool) return value ? 'TRUE' : 'FALSE';
  if (value is num) return value.toString();
  if (value is List || value is Map) {
    final json = jsonEncode(value);
    final escaped = json.replaceAll("'", "''");
    return "'$escaped'::jsonb";
  }
  final escaped = value.toString().replaceAll("'", "''");
  return "'$escaped'";
}

class _TacticalMapGridPainter extends CustomPainter {
  final Color accent;

  const _TacticalMapGridPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0x223C79BB)
      ..strokeWidth = 1;
    final majorPaint = Paint()
      ..color = accent.withValues(alpha: 0.26)
      ..strokeWidth = 1.2;
    const columns = 8;
    const rows = 5;

    for (var i = 1; i < columns; i++) {
      final x = size.width * (i / columns);
      final paint = i % 2 == 0 ? majorPaint : gridPaint;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var i = 1; i < rows; i++) {
      final y = size.height * (i / rows);
      final paint = i % 2 == 0 ? majorPaint : gridPaint;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final routePaint = Paint()
      ..color = const Color(0x447EF2C3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final route = Path()
      ..moveTo(size.width * 0.08, size.height * 0.74)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.58,
        size.width * 0.42,
        size.height * 0.61,
      )
      ..quadraticBezierTo(
        size.width * 0.59,
        size.height * 0.64,
        size.width * 0.87,
        size.height * 0.41,
      );
    canvas.drawPath(route, routePaint);

    final perimeterPaint = Paint()
      ..color = const Color(0x228FD1FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final perimeter = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.06,
        size.height * 0.08,
        size.width * 0.88,
        size.height * 0.82,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(perimeter, perimeterPaint);
  }

  @override
  bool shouldRepaint(covariant _TacticalMapGridPainter oldDelegate) {
    return oldDelegate.accent != accent;
  }
}

class _PartnerActionSummary {
  final String dispatchId;
  final String partnerLabel;
  final PartnerDispatchStatus latestStatus;
  final DateTime latestOccurredAt;
  final int actionCount;
  final Map<PartnerDispatchStatus, DateTime> firstOccurrenceByStatus;

  const _PartnerActionSummary({
    required this.dispatchId,
    required this.partnerLabel,
    required this.latestStatus,
    required this.latestOccurredAt,
    required this.actionCount,
    required this.firstOccurrenceByStatus,
  });
}

Widget _textField(TextEditingController controller, String label) {
  return TextField(
    controller: controller,
    style: GoogleFonts.inter(
      color: const Color(0xFFEAF4FF),
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
    cursorColor: const Color(0xFF8FD1FF),
    decoration: _onboardingInputDecoration(label),
  );
}

Widget _dropdownField({
  required String label,
  required String value,
  required List<String> items,
  required ValueChanged<String?> onChanged,
  Map<String, String>? labels,
}) {
  return InputDecorator(
    decoration: _onboardingInputDecoration(label),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        iconEnabledColor: const Color(0xFF9FD6FF),
        dropdownColor: const Color(0xFF111A24),
        items: items
            .map(
              (item) => DropdownMenuItem<String>(
                value: item,
                child: Text(
                  labels?[item] ?? item,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEAF4FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
            .toList(growable: false),
        onChanged: onChanged,
        style: GoogleFonts.inter(
          color: const Color(0xFFEAF4FF),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

InputDecoration _onboardingInputDecoration(String label) {
  const borderColor = Color(0xFF4C6683);
  const focusedColor = Color(0xFF67C5FF);
  return InputDecoration(
    labelText: label,
    labelStyle: GoogleFonts.inter(
      color: const Color(0xFFC8DDF5),
      fontSize: 12,
      fontWeight: FontWeight.w700,
    ),
    floatingLabelStyle: GoogleFonts.inter(
      color: const Color(0xFFEAF4FF),
      fontSize: 12,
      fontWeight: FontWeight.w800,
    ),
    filled: true,
    fillColor: const Color(0xFF111A24),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: focusedColor, width: 1.4),
    ),
  );
}

String _dateOnly(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
