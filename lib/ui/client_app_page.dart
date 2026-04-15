import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../application/client_delivery_message_formatter.dart';
import '../domain/events/decision_created.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/incident_closed.dart';
import '../domain/events/intelligence_received.dart';
import '../domain/events/response_arrived.dart';
import 'layout_breakpoints.dart';
import 'onyx_surface.dart';
import 'theme/onyx_design_tokens.dart';
import 'ui_action_logger.dart';

const _clientPanelColor = OnyxColorTokens.backgroundSecondary;
const _clientPanelTint = OnyxColorTokens.surfaceElevated;
const _clientPanelMuted = OnyxColorTokens.surfaceElevated;
const _clientSelectedPanelColor = OnyxColorTokens.cyanSurface;
const _clientBorderColor = OnyxColorTokens.borderSubtle;
const _clientStrongBorderColor = OnyxColorTokens.cyanBorder;
const _clientTitleColor = OnyxColorTokens.textPrimary;
const _clientBodyColor = OnyxColorTokens.textSecondary;
const _clientMutedColor = OnyxColorTokens.textMuted;
const _clientAccentBlue = OnyxColorTokens.accentPurple;
const _clientInfoAccent = OnyxColorTokens.accentSky;
const _clientInfoAccentStrong = OnyxColorTokens.accentCyanTrue;
const _clientInfoBorder = OnyxColorTokens.accentBlue;
const _clientInfoBorderSoft = OnyxColorTokens.cyanBorder;
const _clientInfoSurface = OnyxColorTokens.cyanSurface;
const _clientWarningAccent = OnyxColorTokens.accentAmber;
const _clientWarningBorder = OnyxColorTokens.amberBorder;
const _clientWarningSurface = OnyxColorTokens.amberSurface;
const _clientSuccessAccent = OnyxColorTokens.accentGreen;
const _clientSuccessBorder = OnyxColorTokens.greenBorder;
const _clientSuccessSurface = OnyxColorTokens.greenSurface;
const _clientAdminAccent = OnyxColorTokens.accentPurple;
const _clientAdminBorder = OnyxColorTokens.purpleBorder;
const _clientAdminSurface = OnyxColorTokens.purpleSurface;
const _clientPriorityAccent = OnyxColorTokens.accentRed;
const _clientPriorityBorder = OnyxColorTokens.redBorder;
const _clientActionSurface = OnyxColorTokens.surfaceElevated;
const _clientActionSurfaceStrong = OnyxColorTokens.backgroundSecondary;
const _clientActionBorder = OnyxColorTokens.borderSubtle;
const _clientActionBorderStrong = OnyxColorTokens.cyanBorder;
const _clientActionMuted = OnyxColorTokens.textSecondary;
const _clientActionDisabled = OnyxColorTokens.textDisabled;
final _clientShadowColor = OnyxColorTokens.backgroundPrimary.withValues(
  alpha: 0.08,
);
final _clientShadowStrongColor = OnyxColorTokens.backgroundPrimary.withValues(
  alpha: 0.12,
);

enum ClientAppLocale { en, zu, af }

extension ClientAppLocaleParser on ClientAppLocale {
  static ClientAppLocale fromCode(String raw) {
    return switch (raw.trim().toLowerCase()) {
      'zu' || 'zul' || 'isizulu' => ClientAppLocale.zu,
      'af' || 'afr' || 'afrikaans' => ClientAppLocale.af,
      _ => ClientAppLocale.en,
    };
  }
}

enum ClientPushDeliveryProvider { inApp, telegram }

extension ClientPushDeliveryProviderParser on ClientPushDeliveryProvider {
  static ClientPushDeliveryProvider fromCode(String raw) {
    final normalized = raw.trim().toLowerCase().replaceAll('-', '_');
    return switch (normalized) {
      'telegram' => ClientPushDeliveryProvider.telegram,
      _ => ClientPushDeliveryProvider.inApp,
    };
  }

  String get code {
    return switch (this) {
      ClientPushDeliveryProvider.inApp => 'in_app',
      ClientPushDeliveryProvider.telegram => 'telegram',
    };
  }
}

enum ClientAppComposerPrefillType { update, advisory, closure, dispatch }

class ClientAppComposerPrefill {
  final String id;
  final String text;
  final String originalDraftText;
  final ClientAppComposerPrefillType type;
  final String commandLabel;
  final String commandMessage;
  final String commandDetail;
  final bool autofocus;

  const ClientAppComposerPrefill({
    required this.id,
    required this.text,
    this.originalDraftText = '',
    this.type = ClientAppComposerPrefillType.update,
    this.commandLabel = 'AGENT HANDOFF',
    this.commandMessage = 'Agent draft is staged in the control composer.',
    this.commandDetail =
        'Review, adapt, and send from the live scoped lane without leaving the controller flow.',
    this.autofocus = true,
  });
}

class ClientAppEvidenceReturnReceipt {
  final String auditId;
  final String clientId;
  final String siteId;
  final String label;
  final String headline;
  final String detail;
  final String room;
  final Color accent;

  const ClientAppEvidenceReturnReceipt({
    required this.auditId,
    required this.clientId,
    required this.siteId,
    required this.label,
    required this.headline,
    required this.detail,
    this.room = '',
    this.accent = OnyxColorTokens.accentCyanTrue,
  });

  bool matchesScope(String candidateClientId, String candidateSiteId) {
    return clientId.trim() == candidateClientId.trim() &&
        siteId.trim() == candidateSiteId.trim();
  }
}

class ClientAppPage extends StatefulWidget {
  final String clientId;
  final String siteId;
  final ClientAppLocale locale;
  final List<DispatchEvent> events;
  final bool backendSyncEnabled;
  final ClientAppViewerRole viewerRole;
  final String initialSelectedRoom;
  final Map<String, String> initialSelectedRoomByRole;
  final bool initialShowAllRoomItems;
  final Map<String, bool> initialShowAllRoomItemsByRole;
  final String? initialExpandedIncidentReference;
  final bool initialHasTouchedIncidentExpansion;
  final Map<String, String> initialSelectedIncidentReferenceByRole;
  final Map<String, String> initialExpandedIncidentReferenceByRole;
  final Map<String, bool> initialHasTouchedIncidentExpansionByRole;
  final Map<String, String> initialFocusedIncidentReferenceByRole;
  final List<ClientAppMessage> initialManualMessages;
  final List<ClientAppAcknowledgement> initialAcknowledgements;
  final List<ClientAppPushDeliveryItem> initialPushQueue;
  final ClientPushDeliveryProvider pushDeliveryProvider;
  final String telegramHealthLabel;
  final String? telegramHealthDetail;
  final bool telegramFallbackActive;
  final String pushSyncStatusLabel;
  final DateTime? pushSyncLastSyncedAtUtc;
  final String? pushSyncFailureReason;
  final int pushSyncRetryCount;
  final List<ClientPushSyncAttempt> pushSyncHistory;
  final Future<void> Function()? onRetryPushSync;
  final String backendProbeStatusLabel;
  final DateTime? backendProbeLastRunAtUtc;
  final String? backendProbeFailureReason;
  final List<ClientBackendProbeAttempt> backendProbeHistory;
  final Future<void> Function()? onRunBackendProbe;
  final Future<void> Function()? onClearBackendProbeHistory;
  final String laneVoiceProfileLabel;
  final String laneVoiceProfileSignal;
  final Future<void> Function(String? profileSignal)? onSetLaneVoiceProfile;
  final int learnedApprovalStyleCount;
  final String learnedApprovalStyleExample;
  final Future<void> Function()? onClearLearnedLaneStyle;
  final Future<void> Function(String originalDraftText, String approvedText)?
  onRecordApprovedDraftLearning;
  final Future<String?> Function(
    String clientId,
    String siteId,
    String room,
    String currentDraftText,
  )?
  onAiAssistComposerDraft;
  final ClientAppComposerPrefill? initialComposerPrefill;
  final VoidCallback? onInitialComposerPrefillConsumed;
  final ClientAppEvidenceReturnReceipt? evidenceReturnReceipt;
  final ValueChanged<String>? onConsumeEvidenceReturnReceipt;
  final void Function(
    ClientAppViewerRole viewerRole,
    Map<String, String> selectedRoomByRole,
    Map<String, bool> showAllRoomItemsByRole,
    Map<String, String> selectedIncidentReferenceByRole,
    Map<String, String> expandedIncidentReferenceByRole,
    Map<String, bool> hasTouchedIncidentExpansionByRole,
    Map<String, String> focusedIncidentReferenceByRole,
    List<ClientAppMessage> messages,
    List<ClientAppAcknowledgement> acknowledgements,
  )?
  onClientStateChanged;
  final void Function(List<ClientAppPushDeliveryItem> pushQueue)?
  onPushQueueChanged;

  const ClientAppPage({
    super.key,
    required this.clientId,
    required this.siteId,
    this.locale = ClientAppLocale.en,
    required this.events,
    this.backendSyncEnabled = false,
    this.viewerRole = ClientAppViewerRole.client,
    this.initialSelectedRoom = 'Residents',
    this.initialSelectedRoomByRole = const {},
    this.initialShowAllRoomItems = false,
    this.initialShowAllRoomItemsByRole = const {},
    this.initialExpandedIncidentReference,
    this.initialHasTouchedIncidentExpansion = false,
    this.initialSelectedIncidentReferenceByRole = const {},
    this.initialExpandedIncidentReferenceByRole = const {},
    this.initialHasTouchedIncidentExpansionByRole = const {},
    this.initialFocusedIncidentReferenceByRole = const {},
    this.initialManualMessages = const [],
    this.initialAcknowledgements = const [],
    this.initialPushQueue = const [],
    this.pushDeliveryProvider = ClientPushDeliveryProvider.inApp,
    this.telegramHealthLabel = 'disabled',
    this.telegramHealthDetail,
    this.telegramFallbackActive = false,
    this.pushSyncStatusLabel = 'Push sync idle',
    this.pushSyncLastSyncedAtUtc,
    this.pushSyncFailureReason,
    this.pushSyncRetryCount = 0,
    this.pushSyncHistory = const [],
    this.onRetryPushSync,
    this.backendProbeStatusLabel = 'idle',
    this.backendProbeLastRunAtUtc,
    this.backendProbeFailureReason,
    this.backendProbeHistory = const [],
    this.onRunBackendProbe,
    this.onClearBackendProbeHistory,
    this.laneVoiceProfileLabel = 'Auto',
    this.laneVoiceProfileSignal = '',
    this.onSetLaneVoiceProfile,
    this.learnedApprovalStyleCount = 0,
    this.learnedApprovalStyleExample = '',
    this.onClearLearnedLaneStyle,
    this.onRecordApprovedDraftLearning,
    this.onAiAssistComposerDraft,
    this.initialComposerPrefill,
    this.onInitialComposerPrefillConsumed,
    this.evidenceReturnReceipt,
    this.onConsumeEvidenceReturnReceipt,
    this.onClientStateChanged,
    this.onPushQueueChanged,
  });

  @override
  State<ClientAppPage> createState() => _ClientAppPageState();
}

class _ClientCommandReceipt {
  final String label;
  final String message;
  final String detail;
  final Color accent;

  const _ClientCommandReceipt({
    required this.label,
    required this.message,
    required this.detail,
    required this.accent,
  });
}

class _ClientAppPageState extends State<ClientAppPage> {
  static const int _maxNotificationRows = 12;
  static const int _maxPushQueueRows = 6;
  static const int _maxIncidentFeedRows = 8;
  static const int _maxChatRows = 40;
  static const int _maxRoomRows = 12;
  static const double _spaceXs = 6;
  static const double _spaceSm = 8;
  static const double _spaceMd = 10;
  static const double _spaceLg = 12;
  static const _defaultCommandReceipt = _ClientCommandReceipt(
    label: 'INCIDENT READY',
    message: 'Thread handoffs and delivery actions stay pinned in this rail.',
    detail:
        'Open-thread pivots keep reporting whether a scoped incident is available so operators never hit dead chrome.',
    accent: _clientInfoAccent,
  );

  final TextEditingController _chatController = TextEditingController();
  final FocusNode _chatFocusNode = FocusNode();
  final GlobalKey _chatComposerKey = GlobalKey();
  final GlobalKey _chatThreadKey = GlobalKey();
  bool _showComposerLandingHighlight = false;
  bool _aiAssistComposerBusy = false;
  bool _laneVoiceProfileBusy = false;
  bool _laneLearnedStyleBusy = false;
  String? _draftOpenedMessageKey;
  String? _reviewedDraftOriginalText;
  String? _sentNotificationMessageKey;
  String? _sentThreadMessageKey;
  String? _threadLandingMessageKey;
  String? _selectedPushMessageKey;
  String? _selectedNotificationMessageKey;
  _ClientSystemMessageType? _composedSystemType;
  String _lastAppliedComposerPrefillId = '';
  String? _focusedIncidentReference;
  String? _selectedIncidentReference;
  _ClientCommandReceipt _commandReceipt = _defaultCommandReceipt;
  ClientAppEvidenceReturnReceipt? _activeEvidenceReturnReceipt;
  late List<ClientAppMessage> _manualMessages;
  late List<ClientAppAcknowledgement> _acknowledgements;
  late ClientAppViewerRole _viewerRole;
  late Map<String, String> _selectedRoomByRole;
  late Map<String, bool> _showAllRoomItemsByRole;
  late Map<String, String> _selectedIncidentReferenceByRole;
  late Map<String, String> _expandedIncidentReferenceByRole;
  late Map<String, bool> _hasTouchedIncidentExpansionByRole;
  late Map<String, String> _focusedIncidentReferenceByRole;
  late final Map<String, String> _chatSourceFilterByRole;
  late final Map<String, String> _chatProviderFilterByRole;
  bool get _phoneLayout => isHandsetLayout(context);
  bool get _desktopEmbeddedScroll => allowEmbeddedPanelScroll(context);

  @override
  void initState() {
    super.initState();
    _manualMessages = List<ClientAppMessage>.from(widget.initialManualMessages);
    _acknowledgements = List<ClientAppAcknowledgement>.from(
      widget.initialAcknowledgements,
    );
    _viewerRole = widget.viewerRole;
    _selectedRoomByRole = {...widget.initialSelectedRoomByRole};
    _showAllRoomItemsByRole = {...widget.initialShowAllRoomItemsByRole};
    _selectedRoomByRole.putIfAbsent(
      _viewerRole.name,
      () => widget.initialSelectedRoom,
    );
    _showAllRoomItemsByRole.putIfAbsent(
      _viewerRole.name,
      () => widget.initialShowAllRoomItems,
    );
    _selectedIncidentReferenceByRole = {
      ...widget.initialSelectedIncidentReferenceByRole,
    };
    _expandedIncidentReferenceByRole = {
      ...widget.initialExpandedIncidentReferenceByRole,
    };
    _hasTouchedIncidentExpansionByRole = {
      ...widget.initialHasTouchedIncidentExpansionByRole,
    };
    _focusedIncidentReferenceByRole = {
      ...widget.initialFocusedIncidentReferenceByRole,
    };
    _chatSourceFilterByRole = {
      for (final role in ClientAppViewerRole.values) role.name: 'all',
    };
    _chatProviderFilterByRole = {
      for (final role in ClientAppViewerRole.values) role.name: 'all',
    };
    if (widget.initialExpandedIncidentReference != null) {
      _expandedIncidentReferenceByRole.putIfAbsent(
        ClientAppViewerRole.client.name,
        () => widget.initialExpandedIncidentReference!,
      );
    }
    _hasTouchedIncidentExpansionByRole.putIfAbsent(
      ClientAppViewerRole.client.name,
      () => widget.initialHasTouchedIncidentExpansion,
    );
    _restoreSelectedIncidentForRole(_viewerRole);
    _restoreFocusedIncidentForRole(_viewerRole);
    _applyIncomingComposerPrefill(widget.initialComposerPrefill);
    _ingestEvidenceReturnReceipt(widget.evidenceReturnReceipt);
  }

  @override
  void didUpdateWidget(covariant ClientAppPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final scopeChanged =
        oldWidget.clientId != widget.clientId ||
        oldWidget.siteId != widget.siteId;
    if (scopeChanged) {
      _manualMessages = List<ClientAppMessage>.from(
        widget.initialManualMessages,
      );
      _acknowledgements = List<ClientAppAcknowledgement>.from(
        widget.initialAcknowledgements,
      );
      _viewerRole = widget.viewerRole;
      _selectedRoomByRole = {...widget.initialSelectedRoomByRole};
      _showAllRoomItemsByRole = {...widget.initialShowAllRoomItemsByRole};
      _selectedRoomByRole.putIfAbsent(
        _viewerRole.name,
        () => widget.initialSelectedRoom,
      );
      _showAllRoomItemsByRole.putIfAbsent(
        _viewerRole.name,
        () => widget.initialShowAllRoomItems,
      );
      _selectedIncidentReferenceByRole = {
        ...widget.initialSelectedIncidentReferenceByRole,
      };
      _expandedIncidentReferenceByRole = {
        ...widget.initialExpandedIncidentReferenceByRole,
      };
      _hasTouchedIncidentExpansionByRole = {
        ...widget.initialHasTouchedIncidentExpansionByRole,
      };
      _focusedIncidentReferenceByRole = {
        ...widget.initialFocusedIncidentReferenceByRole,
      };
      if (widget.initialExpandedIncidentReference != null) {
        _expandedIncidentReferenceByRole.putIfAbsent(
          ClientAppViewerRole.client.name,
          () => widget.initialExpandedIncidentReference!,
        );
      }
      _hasTouchedIncidentExpansionByRole.putIfAbsent(
        ClientAppViewerRole.client.name,
        () => widget.initialHasTouchedIncidentExpansion,
      );
      _activeEvidenceReturnReceipt = null;
      _restoreSelectedIncidentForRole(_viewerRole);
      _restoreFocusedIncidentForRole(_viewerRole);
      _applyIncomingComposerPrefill(widget.initialComposerPrefill);
      _ingestEvidenceReturnReceipt(widget.evidenceReturnReceipt);
      return;
    }

    if (_sameClientAppMessages(
          _manualMessages,
          oldWidget.initialManualMessages,
        ) &&
        !_sameClientAppMessages(
          oldWidget.initialManualMessages,
          widget.initialManualMessages,
        )) {
      _manualMessages = List<ClientAppMessage>.from(
        widget.initialManualMessages,
      );
    }
    if (_sameClientAppAcknowledgements(
          _acknowledgements,
          oldWidget.initialAcknowledgements,
        ) &&
        !_sameClientAppAcknowledgements(
          oldWidget.initialAcknowledgements,
          widget.initialAcknowledgements,
        )) {
      _acknowledgements = List<ClientAppAcknowledgement>.from(
        widget.initialAcknowledgements,
      );
    }

    final nextPrefill = widget.initialComposerPrefill;
    final previousPrefillId = oldWidget.initialComposerPrefill?.id.trim() ?? '';
    final nextPrefillId = nextPrefill?.id.trim() ?? '';
    if (nextPrefill != null &&
        nextPrefillId.isNotEmpty &&
        nextPrefillId != previousPrefillId) {
      _applyIncomingComposerPrefill(nextPrefill);
    }
    if (oldWidget.evidenceReturnReceipt?.auditId !=
        widget.evidenceReturnReceipt?.auditId) {
      _ingestEvidenceReturnReceipt(
        widget.evidenceReturnReceipt,
        useSetState: true,
      );
    }
  }

  @override
  void dispose() {
    _chatController.dispose();
    _chatFocusNode.dispose();
    super.dispose();
  }

  void _applyIncomingComposerPrefill(ClientAppComposerPrefill? prefill) {
    if (prefill == null) {
      return;
    }
    final prefillId = prefill.id.trim();
    final normalizedText = prefill.text.trim();
    if (prefillId.isEmpty ||
        normalizedText.isEmpty ||
        prefillId == _lastAppliedComposerPrefillId) {
      return;
    }
    _lastAppliedComposerPrefillId = prefillId;
    _composedSystemType = _systemTypeFromComposerPrefill(prefill.type);
    _reviewedDraftOriginalText = prefill.originalDraftText.trim().isEmpty
        ? normalizedText
        : prefill.originalDraftText.trim();
    _chatController.text = normalizedText;
    _chatController.selection = TextSelection.collapsed(
      offset: _chatController.text.length,
    );
    _commandReceipt = _ClientCommandReceipt(
      label: prefill.commandLabel.trim().isEmpty
          ? 'AGENT HANDOFF'
          : prefill.commandLabel.trim(),
      message: prefill.commandMessage.trim().isEmpty
          ? 'Agent draft is staged in the control composer.'
          : prefill.commandMessage.trim(),
      detail: prefill.commandDetail.trim().isEmpty
          ? 'Review, adapt, and send from the live scoped lane without leaving the controller flow.'
          : prefill.commandDetail.trim(),
      accent: _clientInfoAccentStrong,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (prefill.autofocus) {
        _focusChatComposer();
      }
      _scheduleAiAssistForControlComposerPrefill();
      widget.onInitialComposerPrefillConsumed?.call();
    });
  }

  void _ingestEvidenceReturnReceipt(
    ClientAppEvidenceReturnReceipt? receipt, {
    bool useSetState = false,
  }) {
    if (receipt == null) {
      return;
    }
    final normalizedRoom = receipt.room.trim();

    void apply() {
      _activeEvidenceReturnReceipt = receipt;
      if (normalizedRoom.isNotEmpty) {
        _selectedRoomByRole = <String, String>{
          ..._selectedRoomByRole,
          _viewerRole.name: normalizedRoom,
        };
      }
      _commandReceipt = _ClientCommandReceipt(
        label: receipt.label.trim().isEmpty
            ? 'EVIDENCE RETURN'
            : receipt.label.trim(),
        message: receipt.headline.trim().isEmpty
            ? 'Returned to the client room from evidence.'
            : receipt.headline.trim(),
        detail: receipt.detail.trim().isEmpty
            ? 'The signed room handoff was verified in the ledger. Resume the same lane from here.'
            : receipt.detail.trim(),
        accent: receipt.accent,
      );
    }

    if (useSetState) {
      setState(apply);
    } else {
      apply();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.onConsumeEvidenceReturnReceipt?.call(receipt.auditId);
    });
  }

  _ClientSystemMessageType _systemTypeFromComposerPrefill(
    ClientAppComposerPrefillType type,
  ) {
    return switch (type) {
      ClientAppComposerPrefillType.advisory =>
        _ClientSystemMessageType.advisory,
      ClientAppComposerPrefillType.closure => _ClientSystemMessageType.closure,
      ClientAppComposerPrefillType.dispatch =>
        _ClientSystemMessageType.dispatch,
      ClientAppComposerPrefillType.update => _ClientSystemMessageType.update,
    };
  }

  @override
  Widget build(BuildContext context) {
    final viewerChannel = _viewerRole.acknowledgementChannel;
    final clientEvents = _currentClientEvents();

    final notifications = _buildNotifications(clientEvents);
    final incidentFeed = _buildIncidentFeed(clientEvents);
    final computedPushQueue = _buildPushQueue(notifications);
    final pushQueue = _mergeComputedAndStoredPushQueue(
      computedPushQueue,
      _mergeStoredPushQueueWithAcknowledgements(widget.initialPushQueue),
    );
    final selectedIncidentGroup = _selectedIncidentGroup(incidentFeed);
    final rooms = _buildRooms(notifications);
    final selectedRoom = _selectedRoomFor(_viewerRole);
    final showAllRoomItems = _showAllRoomItemsFor(_viewerRole);
    final activeRoom = rooms.firstWhere(
      (room) => room.key == selectedRoom,
      orElse: () => rooms.first,
    );
    final filterScopeLabel = showAllRoomItems
        ? _localizedFilterScopeAllNotifications(activeRoom.displayName)
        : _localizedFilterScopePending(activeRoom.displayName);
    final visibleNotifications = showAllRoomItems
        ? notifications
        : notifications
              .where(
                (item) => !item.hasAcknowledgementFor(
                  activeRoom.acknowledgementChannel,
                ),
              )
              .toList(growable: false);
    final visibleNotificationRows = visibleNotifications
        .take(_maxNotificationRows)
        .toList(growable: false);
    final hiddenNotificationRows =
        visibleNotifications.length - visibleNotificationRows.length;
    final chatMessages = _buildChatMessages(visibleNotifications);
    final activeDispatches = _activeDispatchCount(clientEvents);
    final unreadNotifications = notifications
        .where((item) => item.priority)
        .length;
    final pendingAcknowledgements = notifications
        .where((item) => !item.hasAcknowledgementFor(viewerChannel))
        .length;
    final pushReadyCount = pushQueue
        .where((item) => item.status == ClientPushDeliveryStatus.queued)
        .length;

    Widget buildSyncBanner() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _clientPanelColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.backendSyncEnabled
                ? OnyxColorTokens.borderSubtle
                : _clientBorderColor,
          ),
          boxShadow: [
            BoxShadow(
              color: _clientShadowColor,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  widget.backendSyncEnabled
                      ? Icons.cloud_done_rounded
                      : Icons.storage_rounded,
                  size: 16,
                  color: widget.backendSyncEnabled
                      ? _clientAccentBlue
                      : _clientMutedColor,
                ),
                const SizedBox(width: _spaceSm),
                Expanded(
                  child: Text(
                    widget.backendSyncEnabled
                        ? _localizedConversationSyncLive
                        : _localizedConversationSyncLocal,
                    style: GoogleFonts.inter(
                      color: _clientTitleColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    softWrap: true,
                  ),
                ),
              ],
            ),
            if (!widget.backendSyncEnabled) ...[
              const SizedBox(height: _spaceXs),
              Text(
                _localizedRunWithLocalDefines,
                style: GoogleFonts.inter(
                  color: _clientMutedColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      );
    }

    Widget buildRoleSelector() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _localizedLanguageLabel,
            style: GoogleFonts.inter(
              color: _clientMutedColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: ClientAppViewerRole.values
                .map((role) => _viewerRoleChip(role))
                .toList(growable: false),
          ),
        ],
      );
    }

    Widget buildMetricsRow() {
      return LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1680
              ? 6
              : constraints.maxWidth >= 1200
              ? 3
              : constraints.maxWidth >= 760
              ? 2
              : 1;
          const spacing = 10.0;
          final cardWidth =
              (constraints.maxWidth - ((columns - 1) * spacing)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              SizedBox(
                width: cardWidth,
                child: _metricCard(
                  _viewerRole.alertsMetricLabelForLocale(widget.locale),
                  unreadNotifications.toString(),
                  _clientWarningAccent,
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _metricCard(
                  _localizedActiveIncidentsLabel,
                  activeDispatches.toString(),
                  _clientPriorityAccent,
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _metricCard(
                  _localizedEstateRoomsLabel,
                  rooms.length.toString(),
                  _clientSuccessAccent,
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _metricCard(
                  _viewerRole.chatMetricLabelForLocale(widget.locale),
                  '${chatMessages.length} updates',
                  _clientInfoAccent,
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _metricCard(
                  _viewerRole.pendingMetricLabelForLocale(widget.locale),
                  pendingAcknowledgements.toString(),
                  _clientAdminAccent,
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _metricCard(
                  _localizedPushQueueReadyLabel,
                  pushReadyCount.toString(),
                  _clientPriorityAccent,
                ),
              ),
            ],
          );
        },
      );
    }

    return OnyxPageScaffold(
      child: LayoutBuilder(
        builder: (context, viewport) {
          const contentPadding = EdgeInsets.fromLTRB(10, 10, 10, 14);
          final useScrollFallback =
              isHandsetLayout(context) ||
              viewport.maxHeight < 720 ||
              viewport.maxWidth < 980;
          final boundedDesktopSurface =
              !useScrollFallback &&
              viewport.hasBoundedHeight &&
              viewport.maxHeight.isFinite;
          final ultrawideSurface = isUltrawideLayout(
            context,
            viewportWidth: viewport.maxWidth,
          );
          final surfaceMaxWidth = commandSurfaceMaxWidth(
            context,
            compactDesktopWidth: 1540,
            viewportWidth: viewport.maxWidth,
            widescreenFillFactor: ultrawideSurface ? 1 : 0.96,
          );

          final communicationsWorkspace = _communicationsWorkspace(
            rooms: rooms,
            activeRoom: activeRoom,
            filterScopeLabel: filterScopeLabel,
            showAllRoomItems: showAllRoomItems,
            visibleNotificationRows: visibleNotificationRows,
            visibleNotificationCount: visibleNotifications.length,
            hiddenNotificationRows: hiddenNotificationRows,
            chatMessages: chatMessages,
            unreadNotifications: unreadNotifications,
            pendingAcknowledgements: pendingAcknowledgements,
            pushReadyCount: pushReadyCount,
            incidentFeed: incidentFeed,
            selectedIncidentGroup: selectedIncidentGroup,
          );
          final deliveryWorkspace = _deliveryIncidentWorkspace(
            notifications: notifications,
            pushQueue: pushQueue,
            pushReadyCount: pushReadyCount,
            incidentFeed: incidentFeed,
            selectedIncidentGroup: selectedIncidentGroup,
          );
          final communicationsCard = boundedDesktopSurface
              ? communicationsWorkspace
              : OnyxSectionCard(
                  title: 'TALK / REPLY / SEND',
                  subtitle:
                      'Read the lane, answer fast, and keep the handoff close.',
                  child: communicationsWorkspace,
                );
          final deliveryCard = boundedDesktopSurface
              ? deliveryWorkspace
              : OnyxSectionCard(
                  title: 'DELIVERY / INCIDENT',
                  subtitle:
                      'Keep delivery, sync, and incident handoff in one lane.',
                  child: deliveryWorkspace,
                );

          Widget buildHeader() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stackedHeader = constraints.maxWidth < 1240;
                    final titleBlock = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_localizedSurfaceTitle(_viewerRole)} — ${widget.clientId} / ${widget.siteId}',
                          style: GoogleFonts.inter(
                            color: _clientTitleColor,
                            fontSize: _phoneLayout ? 23 : 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: _spaceSm),
                        Text(
                          _localizedSurfaceSubtitle(_viewerRole),
                          style: GoogleFonts.inter(
                            color: _clientMutedColor,
                            fontSize: _phoneLayout ? 12 : 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                    final syncBanner = buildSyncBanner();
                    if (stackedHeader) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          titleBlock,
                          const SizedBox(height: 8),
                          syncBanner,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: titleBlock),
                        const SizedBox(width: 8),
                        SizedBox(width: 304, child: syncBanner),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                if (_activeEvidenceReturnReceipt != null) ...[
                  _evidenceReturnBanner(_activeEvidenceReturnReceipt!),
                  const SizedBox(height: 10),
                ],
                buildRoleSelector(),
                const SizedBox(height: 10),
                buildMetricsRow(),
              ],
            );
          }

          Widget buildBody() {
            return LayoutBuilder(
              builder: (context, constraints) {
                final workspaceWidth = constraints.maxWidth;
                final splitWorkspace =
                    boundedDesktopSurface &&
                    isWidescreenLayout(context, viewportWidth: workspaceWidth);
                final workspaceGap = ultrawideSurface ? 10.0 : 8.0;
                if (splitWorkspace) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 5, child: communicationsCard),
                      SizedBox(width: workspaceGap),
                      Expanded(flex: 6, child: deliveryCard),
                    ],
                  );
                }
                if (boundedDesktopSurface) {
                  return ListView.separated(
                    itemCount: 2,
                    itemBuilder: (context, index) {
                      return index == 0 ? communicationsCard : deliveryCard;
                    },
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    communicationsCard,
                    const SizedBox(height: 10),
                    deliveryCard,
                  ],
                );
              },
            );
          }

          return OnyxViewportWorkspaceLayout(
            padding: contentPadding,
            maxWidth: surfaceMaxWidth,
            spacing: 10,
            lockToViewport: boundedDesktopSurface,
            header: buildHeader(),
            body: buildBody(),
          );
        },
      ),
    );
  }

  Widget _metricCard(String label, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: _clientPanelColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _clientBorderColor),
        boxShadow: [
          BoxShadow(
            color: _clientShadowColor,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 3,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              color: _clientMutedColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              color: accent,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _evidenceReturnBanner(ClientAppEvidenceReturnReceipt receipt) {
    final normalizedRoom = receipt.room.trim();
    return Container(
      key: const ValueKey('client-app-evidence-return-banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            receipt.accent.withValues(alpha: 0.18),
            _clientActionSurface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: receipt.accent.withValues(alpha: 0.42)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            receipt.label,
            style: GoogleFonts.inter(
              color: receipt.accent,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.05,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            receipt.headline,
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          if (normalizedRoom.isNotEmpty) ...[
            const SizedBox(height: 8),
            _pill('ROOM $normalizedRoom', receipt.accent, receipt.accent),
          ],
          const SizedBox(height: 8),
          Text(
            receipt.detail,
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewerRoleChip(ClientAppViewerRole role) {
    final selected = role == _viewerRole;
    final roleLabel = role.displayLabelForLocale(widget.locale);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey(
            'client-viewer-role-chip-${role.name}-${widget.locale.name}-${_phoneLayout ? 'phone' : 'desk'}',
          ),
          onTap: () => _setViewerRole(role),
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              color: selected ? _clientSelectedPanelColor : _clientPanelColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? _clientStrongBorderColor : _clientBorderColor,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: _clientShadowColor,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: _phoneLayout ? 44 : 36),
              child: Padding(
                padding: _phoneLayout
                    ? const EdgeInsets.symmetric(horizontal: 14, vertical: 11)
                    : const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Text(
                  roleLabel,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    color: selected ? _clientTitleColor : _clientBodyColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel({
    required String title,
    required String subtitle,
    Widget? subtitleAction,
    Widget? headerAction,
    required Widget child,
    bool shellless = false,
  }) {
    if (shellless) {
      return child;
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _clientPanelColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _clientBorderColor),
        boxShadow: [
          BoxShadow(
            color: _clientShadowColor,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 3,
            decoration: BoxDecoration(
              color: _clientAccentBlue,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final action = headerAction;
              final stacked = action != null && constraints.maxWidth < 760;
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: _clientTitleColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    action,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.inter(
                        color: _clientTitleColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  headerAction ?? const SizedBox.shrink(),
                ],
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              color: _clientMutedColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitleAction != null) ...[
            const SizedBox(height: 4),
            subtitleAction,
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _communicationsWorkspace({
    required List<_ClientRoom> rooms,
    required _ClientRoom activeRoom,
    required String filterScopeLabel,
    required bool showAllRoomItems,
    required List<_ClientNotification> visibleNotificationRows,
    required int visibleNotificationCount,
    required int hiddenNotificationRows,
    required List<_ClientChatMessage> chatMessages,
    required int unreadNotifications,
    required int pendingAcknowledgements,
    required int pushReadyCount,
    required List<_ClientIncidentFeedGroup> incidentFeed,
    required _ClientIncidentFeedGroup? selectedIncidentGroup,
  }) {
    final contextRail = _communicationsContextRail(
      activeRoom: activeRoom,
      unreadNotifications: unreadNotifications,
      pendingAcknowledgements: pendingAcknowledgements,
      pushReadyCount: pushReadyCount,
      incidentFeed: incidentFeed,
      selectedIncidentGroup: selectedIncidentGroup,
      showAllRoomItems: showAllRoomItems,
    );
    Widget buildChatPanel({required bool shellless}) {
      final title = _viewerRole.chatPanelTitleForLocale(widget.locale);
      final subtitle = _chatPanelSubtitle(
        showAllRoomItems: showAllRoomItems,
        roomDisplayName: activeRoom.displayName,
      );
      final body = _chatPanel(
        chatMessages,
        incidentFeed: incidentFeed,
        selectedIncidentGroup: selectedIncidentGroup,
      );
      if (!shellless) {
        return Container(
          key: const ValueKey('client-comms-workspace-panel-chat'),
          child: _panel(title: title, subtitle: subtitle, child: body),
        );
      }
      return Container(
        key: const ValueKey('client-comms-workspace-panel-chat'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                color: _clientTitleColor,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            body,
          ],
        ),
      );
    }

    Widget buildRoomsPanel({required bool shellless}) {
      final title = _viewerRole.roomsPanelTitleForLocale(widget.locale);
      final subtitle = _roomsPanelSubtitle(
        showAllRoomItems: showAllRoomItems,
        roomDisplayName: activeRoom.displayName,
      );
      final body = _roomsList(
        rooms,
        activeRoom: activeRoom,
        showAllRoomItems: showAllRoomItems,
        incidentFeed: incidentFeed,
        selectedIncidentGroup: selectedIncidentGroup,
      );
      if (!shellless) {
        return Container(
          key: const ValueKey('client-comms-workspace-panel-rooms'),
          child: _panel(title: title, subtitle: subtitle, child: body),
        );
      }
      return Container(
        key: const ValueKey('client-comms-workspace-panel-rooms'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                color: _clientTitleColor,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            body,
          ],
        ),
      );
    }

    Widget buildNotificationsPanel({required bool shellless}) {
      final title = _viewerRole.notificationsPanelTitleForLocale(widget.locale);
      final subtitle = _notificationsPanelSubtitle(
        showAllRoomItems: showAllRoomItems,
        roomDisplayName: activeRoom.displayName,
      );
      final body = _notificationsList(
        visibleNotificationRows,
        totalCount: visibleNotificationCount,
        hiddenCount: hiddenNotificationRows,
        roomDisplayName: activeRoom.displayName,
        showAllRoomItems: showAllRoomItems,
        incidentFeed: incidentFeed,
        selectedIncidentGroup: selectedIncidentGroup,
      );
      if (!shellless) {
        return Container(
          key: const ValueKey('client-comms-workspace-panel-notifications'),
          child: _panel(title: title, subtitle: subtitle, child: body),
        );
      }
      return Container(
        key: const ValueKey('client-comms-workspace-panel-notifications'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                color: OnyxColorTokens.accentSky,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            body,
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1360;
        final medium = constraints.maxWidth >= 980;
        final chatPanel = buildChatPanel(shellless: medium);
        final roomsPanel = buildRoomsPanel(shellless: medium);
        final notificationsPanel = buildNotificationsPanel(shellless: medium);
        if (wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _communicationsFocusBanner(
                rooms: rooms,
                activeRoom: activeRoom,
                filterScopeLabel: filterScopeLabel,
                showAllRoomItems: showAllRoomItems,
                unreadNotifications: unreadNotifications,
                pendingAcknowledgements: pendingAcknowledgements,
                pushReadyCount: pushReadyCount,
                incidentFeed: incidentFeed,
                selectedIncidentGroup: selectedIncidentGroup,
                summaryOnly: true,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 304, child: roomsPanel),
                  const SizedBox(width: 12),
                  Expanded(child: chatPanel),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 296,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        notificationsPanel,
                        const SizedBox(height: 12),
                        contextRail,
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        }
        if (medium) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _communicationsFocusBanner(
                rooms: rooms,
                activeRoom: activeRoom,
                filterScopeLabel: filterScopeLabel,
                showAllRoomItems: showAllRoomItems,
                unreadNotifications: unreadNotifications,
                pendingAcknowledgements: pendingAcknowledgements,
                pushReadyCount: pushReadyCount,
                incidentFeed: incidentFeed,
                selectedIncidentGroup: selectedIncidentGroup,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 304, child: roomsPanel),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        chatPanel,
                        const SizedBox(height: 12),
                        notificationsPanel,
                        const SizedBox(height: 12),
                        contextRail,
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _communicationsFocusBanner(
              rooms: rooms,
              activeRoom: activeRoom,
              filterScopeLabel: filterScopeLabel,
              showAllRoomItems: showAllRoomItems,
              unreadNotifications: unreadNotifications,
              pendingAcknowledgements: pendingAcknowledgements,
              pushReadyCount: pushReadyCount,
              incidentFeed: incidentFeed,
              selectedIncidentGroup: selectedIncidentGroup,
            ),
            const SizedBox(height: 12),
            roomsPanel,
            const SizedBox(height: 12),
            notificationsPanel,
            const SizedBox(height: 12),
            chatPanel,
            const SizedBox(height: 12),
            contextRail,
          ],
        );
      },
    );
  }

  Widget _communicationsFocusBanner({
    required List<_ClientRoom> rooms,
    required _ClientRoom activeRoom,
    required String filterScopeLabel,
    required bool showAllRoomItems,
    required int unreadNotifications,
    required int pendingAcknowledgements,
    required int pushReadyCount,
    required List<_ClientIncidentFeedGroup> incidentFeed,
    required _ClientIncidentFeedGroup? selectedIncidentGroup,
    bool summaryOnly = false,
  }) {
    return Container(
      key: const ValueKey('client-comms-focus-banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_clientPanelTint, _clientPanelColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _clientStrongBorderColor),
        boxShadow: [
          BoxShadow(
            color: _clientShadowStrongColor,
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final roomPivots = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: rooms
                .map(
                  (room) => _bannerRoomPivot(
                    room,
                    selected: room.key == activeRoom.key,
                  ),
                )
                .toList(growable: false),
          );
          final openThreadAction = _bannerActionChip(
            key: const ValueKey('client-comms-banner-open-thread'),
            label: selectedIncidentGroup == null
                ? 'Open first thread'
                : 'Reopen ${selectedIncidentGroup.referenceLabel}',
            accent: _clientInfoAccent,
            onTap: selectedIncidentGroup == null
                ? () => _openFirstAvailableIncidentThread(incidentFeed)
                : () => _reopenSelectedIncidentThread(incidentFeed),
          );
          final composerAction = _bannerActionChip(
            key: const ValueKey('client-comms-banner-focus-composer'),
            label: 'Jump to Composer',
            accent: _clientAdminAccent,
            onTap: _focusChatComposer,
          );
          final scopeAction = _bannerActionChip(
            key: const ValueKey('client-comms-toggle-scope'),
            label: showAllRoomItems
                ? _localizedShowPendingLabel
                : _localizedShowAllLabel,
            accent: _clientWarningAccent,
            selected: showAllRoomItems,
            onTap: _toggleShowAllRoomItems,
          );
          final sentMessageAction = _sentThreadMessageKey == null
              ? null
              : _bannerActionChip(
                  key: const ValueKey('client-comms-banner-view-sent-message'),
                  label: _viewSentMessageLabel(),
                  accent: _clientSuccessAccent,
                  onTap: _showSentMessageInThread,
                );
          final actionPivots = summaryOnly
              ? const SizedBox.shrink()
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    openThreadAction,
                    composerAction,
                    ...?sentMessageAction == null
                        ? null
                        : <Widget>[sentMessageAction],
                    scopeAction,
                  ],
                );
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!summaryOnly) ...[
                Text(
                  'CLIENT COMMS FOCUS',
                  style: GoogleFonts.inter(
                    color: _clientAccentBlue,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                'Focus lane: ${activeRoom.displayName}',
                style: GoogleFonts.inter(
                  color: _clientTitleColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                filterScopeLabel,
                style: GoogleFonts.inter(
                  color: _clientBodyColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _pill(
                    'Unread $unreadNotifications',
                    _clientWarningAccent,
                    _clientWarningBorder,
                  ),
                  _pill(
                    'Pending $pendingAcknowledgements',
                    _clientAdminAccent,
                    _clientAdminBorder,
                  ),
                  _pill(
                    'Push Ready $pushReadyCount',
                    _clientPriorityAccent,
                    _clientPriorityBorder,
                  ),
                  if (selectedIncidentGroup != null)
                    _pill(
                      'Thread ${selectedIncidentGroup.referenceLabel}',
                      _clientInfoAccent,
                      _clientInfoBorder,
                    ),
                ],
              ),
              if (!summaryOnly) ...[const SizedBox(height: 10), roomPivots],
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [details, const SizedBox(height: 12), actionPivots],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: details),
              const SizedBox(width: 16),
              SizedBox(
                width: 280,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [actionPivots],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _bannerRoomPivot(_ClientRoom room, {required bool selected}) {
    final accent = selected
        ? _clientAccentBlue
        : room.unread > 0
        ? _clientWarningBorder
        : _clientBodyColor;
    return InkWell(
      key: ValueKey('client-comms-banner-room-${room.key}'),
      onTap: () => _setSelectedRoom(room.key),
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _clientSelectedPanelColor : _clientPanelMuted,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? _clientStrongBorderColor : _clientBorderColor,
          ),
        ),
        child: Text(
          '${room.displayName} ${room.unread}',
          style: GoogleFonts.inter(
            color: accent,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _bannerActionChip({
    required Key key,
    required String label,
    required Color accent,
    required VoidCallback? onTap,
    bool selected = false,
  }) {
    final enabled = onTap != null;
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.14) : _clientPanelColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.52)
                : enabled
                ? _clientStrongBorderColor
                : _clientBorderColor,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: enabled
                ? (selected ? accent : _clientTitleColor)
                : _clientMutedColor,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _communicationsContextRail({
    required _ClientRoom activeRoom,
    required int unreadNotifications,
    required int pendingAcknowledgements,
    required int pushReadyCount,
    required List<_ClientIncidentFeedGroup> incidentFeed,
    required _ClientIncidentFeedGroup? selectedIncidentGroup,
    required bool showAllRoomItems,
  }) {
    return Container(
      key: const ValueKey('client-comms-workspace-panel-context'),
      padding: const EdgeInsets.all(10),
      decoration: onyxWorkspaceSurfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Room Command Rail',
            style: GoogleFonts.inter(
              color: _clientTitleColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_showDesktopCommandReceipt) ...[
            _workspaceCommandReceiptCard(
              const ValueKey('client-comms-command-receipt'),
              shellless: true,
            ),
          ],
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Incident focus',
                style: GoogleFonts.inter(
                  color: _clientAccentBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                selectedIncidentGroup == null
                    ? 'No active thread selected'
                    : 'Thread ${selectedIncidentGroup.referenceLabel}',
                style: GoogleFonts.inter(
                  color: _clientTitleColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (selectedIncidentGroup != null) ...[
                const SizedBox(height: 4),
                Text(
                  selectedIncidentGroup.latestEntry.headline,
                  style: GoogleFonts.inter(
                    color: _clientBodyColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              _contextActionButton(
                key: const ValueKey('client-comms-open-thread'),
                label: selectedIncidentGroup == null
                    ? 'Open first incident'
                    : 'Reopen ${selectedIncidentGroup.referenceLabel}',
                onTap: selectedIncidentGroup == null
                    ? () => _openFirstAvailableIncidentThread(incidentFeed)
                    : () => _reopenSelectedIncidentThread(incidentFeed),
              ),
              const SizedBox(height: 5),
              _contextActionButton(
                key: const ValueKey('client-comms-focus-composer'),
                label: 'Jump to Composer',
                onTap: _focusChatComposer,
              ),
              if (_sentThreadMessageKey != null) ...[
                const SizedBox(height: 5),
                _contextActionButton(
                  key: const ValueKey('client-comms-view-sent-message'),
                  label: _viewSentMessageLabel(),
                  onTap: _showSentMessageInThread,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _deliveryIncidentWorkspace({
    required List<_ClientNotification> notifications,
    required List<ClientAppPushDeliveryItem> pushQueue,
    required int pushReadyCount,
    required List<_ClientIncidentFeedGroup> incidentFeed,
    required _ClientIncidentFeedGroup? selectedIncidentGroup,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1260;
        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _deliverySystemsPanel(
                notifications: notifications,
                pushQueue: pushQueue,
                incidentFeed: incidentFeed,
                selectedIncidentGroup: selectedIncidentGroup,
              ),
              const SizedBox(height: _spaceLg),
              _incidentFeedWorkspacePanel(
                incidentFeed: incidentFeed,
                selectedIncidentGroup: selectedIncidentGroup,
              ),
            ],
          );
        }
        final selectedDelivery = _selectedPushDeliveryItem(pushQueue);
        final selectedNotification = _notificationForPushQueueItem(
          notifications,
          selectedDelivery,
        );
        Widget buildDeliveryQueuePanel({required bool shellless}) {
          final title = _localizedPushDeliveryQueueTitle;
          const subtitle =
              'Select a queued or acknowledged delivery to inspect route, provider, and thread handoff.';
          final body = _deliveryQueueRail(
            pushQueue,
            selectedNotification: selectedNotification,
            incidentFeed: incidentFeed,
            selectedIncidentGroup: selectedIncidentGroup,
            shellless: shellless,
          );
          if (!shellless) {
            return Container(
              key: const ValueKey('client-delivery-workspace-panel-queue'),
              child: _panel(title: title, subtitle: subtitle, child: body),
            );
          }
          return Container(
            key: const ValueKey('client-delivery-workspace-panel-queue'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: _clientTitleColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                body,
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 272,
                  child: buildDeliveryQueuePanel(shellless: true),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    key: const ValueKey(
                      'client-delivery-workspace-panel-board',
                    ),
                    child: _panel(
                      title: 'Delivery Systems Board',
                      subtitle:
                          'Sync pressure, backend probe health, and the selected delivery stay in one systems board.',
                      shellless: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _deliveryIncidentWorkspaceBanner(
                            pushQueue: pushQueue,
                            pushReadyCount: pushReadyCount,
                            selectedDelivery: selectedDelivery,
                            incidentFeed: incidentFeed,
                            selectedIncidentGroup: selectedIncidentGroup,
                            summaryOnly: true,
                            shellless: true,
                          ),
                          _pushSyncStatusStrip(shellless: true),
                          const SizedBox(height: 8),
                          _backendProbeHistoryList(
                            widget.backendProbeHistory,
                            shellless: true,
                          ),
                          const SizedBox(height: 8),
                          _pushSyncHistoryList(
                            widget.pushSyncHistory,
                            shellless: true,
                          ),
                          const SizedBox(height: 8),
                          _selectedDeliveryBoard(
                            selectedDelivery: selectedDelivery,
                            selectedNotification: selectedNotification,
                            incidentFeed: incidentFeed,
                            selectedIncidentGroup: selectedIncidentGroup,
                            shellless: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 304,
                  child: Container(
                    key: const ValueKey(
                      'client-delivery-workspace-panel-incident',
                    ),
                    child: _incidentFeedWorkspacePanel(
                      incidentFeed: incidentFeed,
                      selectedIncidentGroup: selectedIncidentGroup,
                      shellless: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _deliveryIncidentWorkspaceBanner({
    required List<ClientAppPushDeliveryItem> pushQueue,
    required int pushReadyCount,
    required ClientAppPushDeliveryItem? selectedDelivery,
    required List<_ClientIncidentFeedGroup> incidentFeed,
    required _ClientIncidentFeedGroup? selectedIncidentGroup,
    bool summaryOnly = false,
    bool shellless = false,
  }) {
    if (shellless && summaryOnly) {
      return const SizedBox.shrink(
        key: ValueKey('client-delivery-workspace-status-banner'),
      );
    }
    final bannerChild = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!shellless) ...[
          Text(
            'DELIVERY COMMAND WORKSPACE',
            style: GoogleFonts.inter(
              color: _clientAccentBlue,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 3),
        ],
        if (!summaryOnly) ...[
          Text(
            selectedDelivery == null
                ? 'Delivery telemetry is active while incident-thread handoff remains available.'
                : '${selectedDelivery.title} is pinned in the systems board while the incident rail stays live.',
            style: GoogleFonts.inter(
              color: _clientTitleColor,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
        ],
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _pill(
              'Queue ${pushQueue.length}',
              _clientWarningAccent,
              _clientWarningBorder,
            ),
            _pill(
              'Ready $pushReadyCount',
              _clientPriorityAccent,
              _clientPriorityBorder,
            ),
            _pill(
              'Incidents ${incidentFeed.length}',
              _clientInfoAccent,
              _clientInfoBorder,
            ),
            if (selectedIncidentGroup != null)
              _pill(
                'Thread ${selectedIncidentGroup.referenceLabel}',
                _clientAdminAccent,
                _clientAdminBorder,
              ),
          ],
        ),
        if (!summaryOnly) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _bannerActionChip(
                key: const ValueKey('client-delivery-workspace-retry-sync'),
                label: 'Retry Push Sync',
                accent: _clientInfoAccent,
                onTap: widget.onRetryPushSync == null
                    ? null
                    : () {
                        unawaited(_retryPushSyncSafely());
                      },
              ),
              _bannerActionChip(
                key: const ValueKey('client-delivery-workspace-run-probe'),
                label: 'Run Backend Probe',
                accent: _clientSuccessAccent,
                onTap: widget.onRunBackendProbe == null
                    ? null
                    : () {
                        unawaited(_runBackendProbeSafely());
                      },
              ),
              _bannerActionChip(
                key: const ValueKey('client-delivery-workspace-open-thread'),
                label: selectedIncidentGroup == null
                    ? 'Open first incident'
                    : 'Reopen ${selectedIncidentGroup.referenceLabel}',
                accent: _clientAdminAccent,
                onTap: selectedIncidentGroup == null
                    ? () => _openFirstAvailableIncidentThread(incidentFeed)
                    : () => _reopenSelectedIncidentThread(incidentFeed),
              ),
            ],
          ),
        ],
      ],
    );
    if (shellless) {
      return KeyedSubtree(
        key: const ValueKey('client-delivery-workspace-status-banner'),
        child: bannerChild,
      );
    }
    return Container(
      key: const ValueKey('client-delivery-workspace-status-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_clientPanelTint, _clientPanelColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _clientStrongBorderColor),
        boxShadow: [
          BoxShadow(
            color: _clientShadowStrongColor,
            blurRadius: 16,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: bannerChild,
    );
  }

  Widget _deliverySystemsPanel({
    required List<_ClientNotification> notifications,
    required List<ClientAppPushDeliveryItem> pushQueue,
    required List<_ClientIncidentFeedGroup> incidentFeed,
    required _ClientIncidentFeedGroup? selectedIncidentGroup,
  }) {
    final selectedDelivery = _selectedPushDeliveryItem(pushQueue);
    final selectedNotification = _notificationForPushQueueItem(
      notifications,
      selectedDelivery,
    );
    return _panel(
      title: _localizedPushDeliveryQueueTitle,
      subtitle: _localizedPushDeliveryQueueSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pushSyncStatusStrip(),
          const SizedBox(height: _spaceMd),
          _backendProbeHistoryList(widget.backendProbeHistory),
          const SizedBox(height: _spaceMd),
          _pushSyncHistoryList(widget.pushSyncHistory),
          const SizedBox(height: _spaceMd),
          _selectedDeliveryBoard(
            selectedDelivery: selectedDelivery,
            selectedNotification: selectedNotification,
            incidentFeed: incidentFeed,
            selectedIncidentGroup: selectedIncidentGroup,
            includeQueueRail: true,
            pushQueue: pushQueue,
          ),
        ],
      ),
    );
  }

  Widget _incidentFeedWorkspacePanel({
    required List<_ClientIncidentFeedGroup> incidentFeed,
    required _ClientIncidentFeedGroup? selectedIncidentGroup,
    bool shellless = false,
  }) {
    final title = _viewerRole.incidentFeedPanelTitleForLocale(widget.locale);
    final subtitle = _viewerRole.incidentFeedPanelSubtitleForLocale(
      widget.locale,
    );
    final expandedReference = _expandedIncidentReferenceFor(_viewerRole);
    final selectedExpanded =
        selectedIncidentGroup != null &&
        expandedReference != null &&
        expandedReference == selectedIncidentGroup.referenceLabel;
    final subtitleAction = selectedIncidentGroup == null
        ? null
        : shellless
        ? Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              TextButton(
                onPressed: () => _reopenSelectedIncidentThread(incidentFeed),
                style: _inlineHandoffButtonStyle(_clientInfoAccent),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(_viewerRole.selectedIncidentHeaderIcon, size: 14),
                    Text(
                      _viewerRole.selectedIncidentHeaderLabel(
                        selectedIncidentGroup.referenceLabel,
                      ),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                key: const ValueKey('incident-feed-toggle-expansion-action'),
                onPressed: () => _toggleIncidentFeedExpansion(
                  selectedIncidentGroup.referenceLabel,
                ),
                style: _inlineHandoffButtonStyle(_clientAdminAccent),
                child: Text(
                  _viewerRole.incidentToggleActionLabel(selectedExpanded),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          )
        : TextButton(
            onPressed: () => _reopenSelectedIncidentThread(incidentFeed),
            style: _inlineHandoffButtonStyle(_clientInfoAccent),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(_viewerRole.selectedIncidentHeaderIcon, size: 14),
                Text(
                  _viewerRole.selectedIncidentHeaderLabel(
                    selectedIncidentGroup.referenceLabel,
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
    final headerAction = selectedIncidentGroup == null
        ? TextButton(
            key: const ValueKey('incident-feed-open-first-action'),
            onPressed: () => _openFirstAvailableIncidentThread(incidentFeed),
            style: _inlineHandoffButtonStyle(
              _clientInfoAccent,
              disabledForegroundColor: _clientActionDisabled,
            ),
            child: Text(
              _viewerRole.noSelectedIncidentLabel,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        : null;
    final panelBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_showDesktopCommandReceipt) ...[
          _workspaceCommandReceiptCard(
            const ValueKey('client-delivery-command-receipt'),
            shellless: true,
          ),
        ],
        _incidentCommandDeck(
          incidentFeed: incidentFeed,
          selectedIncidentGroup: selectedIncidentGroup,
          shellless: shellless,
        ),
        if (!shellless) const SizedBox(height: _spaceMd),
        _incidentFeedList(incidentFeed),
      ],
    );

    if (shellless) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  headerAction != null && constraints.maxWidth < 760;
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: _clientTitleColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    headerAction,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.inter(
                        color: _clientTitleColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  headerAction ?? const SizedBox.shrink(),
                ],
              );
            },
          ),
          if (subtitleAction != null) ...[
            const SizedBox(height: 4),
            subtitleAction,
          ],
          const SizedBox(height: 8),
          panelBody,
        ],
      );
    }

    return _panel(
      title: title,
      subtitle: subtitle,
      shellless: false,
      subtitleAction: subtitleAction,
      headerAction: headerAction,
      child: panelBody,
    );
  }

  Widget _incidentCommandDeck({
    required List<_ClientIncidentFeedGroup> incidentFeed,
    required _ClientIncidentFeedGroup? selectedIncidentGroup,
    bool shellless = false,
  }) {
    if (shellless) {
      return const SizedBox.shrink(
        key: ValueKey('client-incident-command-deck'),
      );
    }
    final roomKey = _selectedRoomFor(_viewerRole);
    final showAllRoomItems = _showAllRoomItemsFor(_viewerRole);
    final expandedReference = _expandedIncidentReferenceFor(_viewerRole);
    final selectedReference =
        _selectedIncidentReferenceByRole[_viewerRole.name] ??
        selectedIncidentGroup?.referenceLabel;
    final selectedExpanded =
        expandedReference != null && expandedReference == selectedReference;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!shellless) ...[
          Text(
            'INCIDENT COMMAND RAIL',
            style: GoogleFonts.inter(
              color: _clientAccentBlue,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 5),
        ],
        if (!shellless) ...[
          Text(
            selectedIncidentGroup == null
                ? 'The incident rail is armed. Open the first ready thread or widen scope without leaving the workspace.'
                : 'Thread ${selectedIncidentGroup.referenceLabel} is holding the live incident focus while review, expansion, and composer pivots stay within reach.',
            style: GoogleFonts.inter(
              color: _clientTitleColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _pill(
              'Lane ${_roomDisplayNameForKey(roomKey)}',
              _clientInfoAccent,
              _clientInfoBorder,
            ),
            if (!shellless)
              _pill(
                showAllRoomItems
                    ? _localizedShowAllLabel
                    : _localizedShowPendingLabel,
                _clientWarningAccent,
                _clientWarningBorder,
              ),
            _pill(
              'Threads ${incidentFeed.length}',
              _clientAdminAccent,
              _clientAdminBorder,
            ),
            if (selectedIncidentGroup != null)
              _pill(
                'Focus ${selectedIncidentGroup.referenceLabel}',
                _clientPriorityAccent,
                _clientPriorityBorder,
              ),
          ],
        ),
        if (!shellless) ...[
          const SizedBox(height: 10),
          Text(
            'Recommended next move',
            style: GoogleFonts.inter(
              color: _clientAccentBlue,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 5),
        ] else if (selectedIncidentGroup != null)
          const SizedBox(height: 8),
        if (!shellless || selectedIncidentGroup != null)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (!shellless)
                _bannerActionChip(
                  key: const ValueKey('client-incident-command-primary-action'),
                  label: selectedIncidentGroup == null
                      ? 'Open first incident'
                      : _viewerRole.incidentFeedActionLabel,
                  accent: _clientInfoAccent,
                  onTap: selectedIncidentGroup == null
                      ? () => _openFirstAvailableIncidentThread(incidentFeed)
                      : () => _showIncidentFeedDetail(selectedIncidentGroup),
                ),
              if (selectedIncidentGroup != null)
                _bannerActionChip(
                  key: const ValueKey(
                    'client-incident-command-toggle-expansion',
                  ),
                  label: selectedExpanded
                      ? _viewerRole.incidentToggleActionLabel(true)
                      : _viewerRole.incidentToggleActionLabel(false),
                  accent: _clientAdminAccent,
                  selected: selectedExpanded,
                  onTap: () => _toggleIncidentFeedExpansion(
                    selectedIncidentGroup.referenceLabel,
                  ),
                ),
              if (!shellless) ...[
                _bannerActionChip(
                  key: const ValueKey('client-incident-command-focus-composer'),
                  label: 'Jump to Composer',
                  accent: _clientSuccessAccent,
                  onTap: _focusChatComposer,
                ),
                _bannerActionChip(
                  key: const ValueKey('client-incident-command-toggle-scope'),
                  label: showAllRoomItems
                      ? _localizedShowPendingLabel
                      : _localizedShowAllLabel,
                  accent: _clientWarningAccent,
                  selected: showAllRoomItems,
                  onTap: _toggleShowAllRoomItems,
                ),
              ],
            ],
          ),
      ],
    );
    return Container(
      key: const ValueKey('client-incident-command-deck'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _clientPanelTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _clientStrongBorderColor),
      ),
      child: content,
    );
  }

  Widget _deliveryQueueRail(
    List<ClientAppPushDeliveryItem> items, {
    required _ClientNotification? selectedNotification,
    required List<_ClientIncidentFeedGroup> incidentFeed,
    required _ClientIncidentFeedGroup? selectedIncidentGroup,
    bool shellless = false,
  }) {
    if (items.isEmpty) {
      return _deliveryRecoveryDeck(
        key: const ValueKey('client-delivery-queue-empty-recovery'),
        eyebrow: 'QUEUE READY',
        title: 'No delivery is hot right now.',
        summary:
            'The queue is quiet. Retry sync, run a probe, or reopen the linked incident thread from here.',
        accent: _clientWarningAccent,
        metrics: [
          _pill('Queue 0', _clientWarningAccent, _clientWarningBorder),
          _pill(
            'Incidents ${incidentFeed.length}',
            _clientInfoAccent,
            _clientInfoBorder,
          ),
        ],
        actions: _deliveryRecoveryActions(
          incidentFeed: incidentFeed,
          selectedIncidentGroup: selectedIncidentGroup,
          includeComposer: false,
        ),
      );
    }
    final selectedDelivery = _selectedPushDeliveryItem(items);
    final queuedCount = items
        .where((item) => item.status == ClientPushDeliveryStatus.queued)
        .length;
    final deliveredCount = items.length - queuedCount;
    final visibleItems = items.take(_maxPushQueueRows).toList(growable: false);
    final hiddenItems = items.length - visibleItems.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _deliveryQueueCommandDeck(
          selectedDelivery: selectedDelivery,
          selectedNotification: selectedNotification,
          totalCount: items.length,
          queuedCount: queuedCount,
          deliveredCount: deliveredCount,
          incidentFeed: incidentFeed,
          selectedIncidentGroup: selectedIncidentGroup,
          shellless: shellless,
        ),
        if (!shellless) const SizedBox(height: 12),
        for (final item in visibleItems) ...[
          _deliveryQueueCard(
            item,
            isSelected:
                _selectedPushDeliveryItem(items)?.messageKey == item.messageKey,
            selectedNotification:
                selectedDelivery?.messageKey == item.messageKey
                ? selectedNotification
                : null,
          ),
          const SizedBox(height: 10),
        ],
        if (hiddenItems > 0)
          OnyxTruncationHint(
            visibleCount: visibleItems.length,
            totalCount: items.length,
            subject: 'queue rows',
            color: _clientActionMuted,
          ),
      ],
    );
  }

  Widget _deliveryQueueCommandDeck({
    required ClientAppPushDeliveryItem? selectedDelivery,
    required _ClientNotification? selectedNotification,
    required int totalCount,
    required int queuedCount,
    required int deliveredCount,
    required List<_ClientIncidentFeedGroup> incidentFeed,
    required _ClientIncidentFeedGroup? selectedIncidentGroup,
    bool shellless = false,
  }) {
    if (shellless) {
      return const SizedBox.shrink(
        key: ValueKey('client-delivery-queue-command-deck'),
      );
    }
    final openThread = selectedIncidentGroup == null
        ? () => _openFirstAvailableIncidentThread(incidentFeed)
        : () => _reopenSelectedIncidentThread(incidentFeed);
    final canSendNow =
        selectedNotification != null &&
        _canSendNotificationActionNow(selectedNotification.systemType);
    final primaryLabel = selectedNotification == null
        ? (selectedIncidentGroup == null
              ? 'Open first incident'
              : 'Reopen ${selectedIncidentGroup.referenceLabel}')
        : canSendNow
        ? _notificationSendNowLabelFor(selectedNotification.systemType)
        : _notificationActionLabelFor(selectedNotification.systemType);
    final primaryAccent = selectedNotification == null
        ? _clientInfoAccent
        : canSendNow
        ? _clientSuccessAccent
        : selectedNotification.systemType.textColor;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!shellless) ...[
          Text(
            'Priority',
            style: GoogleFonts.inter(
              color: _clientWarningBorder,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 5),
        ],
        if (!shellless) ...[
          Text(
            selectedDelivery == null
                ? 'Pick the next delivery row or reopen the linked incident thread.'
                : '${selectedDelivery.title} is the live queue focus. Sync, thread handoff, and alert actions stay one tap away.',
            style: GoogleFonts.inter(
              color: _clientTitleColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _pill('Queue $totalCount', _clientAdminAccent, _clientAdminBorder),
            _pill(
              'Queued $queuedCount',
              _clientWarningAccent,
              _clientWarningBorder,
            ),
            _pill(
              'Delivered $deliveredCount',
              _clientSuccessAccent,
              _clientSuccessBorder,
            ),
            if (selectedDelivery != null)
              _pill(
                selectedDelivery.targetChannel.displayLabel,
                _clientInfoAccent,
                _clientInfoBorder,
              ),
            if (selectedIncidentGroup != null)
              _pill(
                'Thread ${selectedIncidentGroup.referenceLabel}',
                _clientPriorityAccent,
                _clientPriorityBorder,
              ),
          ],
        ),
        if (!shellless) ...[
          const SizedBox(height: 10),
          Text(
            'NEXT MOVE',
            style: GoogleFonts.inter(
              color: _clientWarningBorder,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _bannerActionChip(
                key: const ValueKey('client-delivery-queue-primary-action'),
                label: primaryLabel,
                accent: primaryAccent,
                onTap: selectedNotification == null
                    ? openThread
                    : canSendNow
                    ? () => _sendNotificationAction(selectedNotification)
                    : () => _focusDraftNotificationAction(selectedNotification),
              ),
              _bannerActionChip(
                key: const ValueKey('client-delivery-queue-open-thread'),
                label: selectedIncidentGroup == null
                    ? 'Open first incident'
                    : 'Reopen ${selectedIncidentGroup.referenceLabel}',
                accent: _clientInfoAccent,
                onTap: openThread,
              ),
              if (widget.onRetryPushSync != null)
                _bannerActionChip(
                  key: const ValueKey('client-delivery-queue-retry-sync'),
                  label: _localizedRetryPushSyncLabel,
                  accent: _clientInfoAccent,
                  onTap: () {
                    unawaited(_retryPushSyncSafely());
                  },
                ),
              if (widget.onRunBackendProbe != null)
                _bannerActionChip(
                  key: const ValueKey('client-delivery-queue-run-probe'),
                  label: _localizedRunBackendProbeLabel,
                  accent: _clientSuccessAccent,
                  onTap: () {
                    unawaited(_runBackendProbeSafely());
                  },
                ),
            ],
          ),
        ],
      ],
    );
    return Container(
      key: const ValueKey('client-delivery-queue-command-deck'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _clientPanelTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _clientStrongBorderColor),
      ),
      child: content,
    );
  }

  Widget _deliveryQueueCard(
    ClientAppPushDeliveryItem item, {
    required bool isSelected,
    required _ClientNotification? selectedNotification,
  }) {
    final accent = item.status == ClientPushDeliveryStatus.queued
        ? _clientPriorityAccent
        : _clientSuccessAccent;
    return InkWell(
      key: ValueKey('client-delivery-queue-item-${item.messageKey}'),
      onTap: () => _selectPushDeliveryItem(item.messageKey),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? _clientSelectedPanelColor : _clientPanelColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _clientStrongBorderColor : _clientBorderColor,
          ),
          boxShadow: [
            BoxShadow(
              color: _clientShadowStrongColor,
              blurRadius: 10,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 5,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _pill(
                  item.status == ClientPushDeliveryStatus.queued
                      ? _localizedQueuedStatus
                      : _localizedDeliveredStatus,
                  accent,
                  _clientBorderColor,
                ),
                _pill(
                  item.targetChannel.displayLabel,
                  _clientInfoAccent,
                  _clientBorderColor,
                ),
                _pill(
                  _localizedDeliveryProviderLabel(item.deliveryProvider),
                  _clientAdminAccent,
                  _clientAdminBorder,
                ),
                if (isSelected && !_desktopEmbeddedScroll)
                  _pill('Current focus', _clientInfoAccent, _clientInfoBorder),
                Text(
                  item.timeLabel,
                  style: GoogleFonts.inter(
                    color: _clientAccentBlue,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              style: GoogleFonts.inter(
                color: _clientTitleColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item.body,
              style: GoogleFonts.inter(
                color: _clientBodyColor,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isSelected && !_desktopEmbeddedScroll) ...[
              const SizedBox(height: 8),
              Text(
                selectedNotification == null
                    ? 'Recommended next move: reopen the linked incident thread from the queue rail.'
                    : 'Recommended next move: ${_canSendNotificationActionNow(selectedNotification.systemType) ? _notificationSendNowLabelFor(selectedNotification.systemType) : _notificationActionLabelFor(selectedNotification.systemType)}',
                style: GoogleFonts.inter(
                  color: _clientWarningBorder,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  ClientAppPushDeliveryItem? _selectedPushDeliveryItem(
    List<ClientAppPushDeliveryItem> items,
  ) {
    if (items.isEmpty) {
      return null;
    }
    for (final item in items) {
      if (item.messageKey == _selectedPushMessageKey) {
        return item;
      }
    }
    return items.first;
  }

  _ClientNotification? _notificationForPushQueueItem(
    List<_ClientNotification> notifications,
    ClientAppPushDeliveryItem? item,
  ) {
    if (item == null) {
      return null;
    }
    for (final notification in notifications) {
      if (notification.messageKey == item.messageKey) {
        return notification;
      }
    }
    return null;
  }

  _ClientNotification _selectedNotificationItem(
    List<_ClientNotification> items,
  ) {
    for (final item in items) {
      if (item.messageKey == _selectedNotificationMessageKey) {
        return item;
      }
    }
    return items.first;
  }

  void _selectNotificationItem(String messageKey) {
    if (_selectedNotificationMessageKey == messageKey) {
      return;
    }
    setState(() {
      _selectedNotificationMessageKey = messageKey;
    });
    logUiAction(
      'client_app.select_notification_item',
      context: {'message_key': messageKey, 'role': _viewerRole.name},
    );
  }

  void _selectPushDeliveryItem(String messageKey) {
    if (_selectedPushMessageKey == messageKey) {
      return;
    }
    setState(() {
      _selectedPushMessageKey = messageKey;
    });
    logUiAction(
      'client_app.select_delivery_item',
      context: {'message_key': messageKey, 'role': _viewerRole.name},
    );
  }

  Widget _selectedDeliveryBoard({
    required ClientAppPushDeliveryItem? selectedDelivery,
    required _ClientNotification? selectedNotification,
    required List<_ClientIncidentFeedGroup> incidentFeed,
    required _ClientIncidentFeedGroup? selectedIncidentGroup,
    bool includeQueueRail = false,
    List<ClientAppPushDeliveryItem> pushQueue = const [],
    bool shellless = false,
  }) {
    final openThread = selectedIncidentGroup == null
        ? () => _openFirstAvailableIncidentThread(incidentFeed)
        : () => _reopenSelectedIncidentThread(incidentFeed);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!shellless) ...[
          Text(
            'SELECTED DELIVERY',
            style: GoogleFonts.inter(
              color: _clientInfoAccent,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 5),
        ],
        if (includeQueueRail) ...[
          _deliveryQueueRail(
            pushQueue,
            selectedNotification: selectedNotification,
            incidentFeed: incidentFeed,
            selectedIncidentGroup: selectedIncidentGroup,
          ),
          const SizedBox(height: _spaceMd),
        ],
        if (selectedDelivery == null)
          _deliveryRecoveryDeck(
            key: const ValueKey('client-delivery-selected-empty-recovery'),
            eyebrow: 'BOARD READY',
            title: 'Nothing is pinned right now.',
            summary:
                'Delivery telemetry is live. Reopen a thread, retry sync, run a probe, or jump back into the composer.',
            accent: _clientInfoAccent,
            metrics: [
              _pill(
                'Queue ${pushQueue.length}',
                _clientWarningAccent,
                _clientWarningBorder,
              ),
              _pill(
                'Incidents ${incidentFeed.length}',
                _clientInfoAccent,
                _clientInfoBorder,
              ),
              if (selectedIncidentGroup != null)
                _pill(
                  'Thread ${selectedIncidentGroup.referenceLabel}',
                  _clientAdminAccent,
                  _clientAdminBorder,
                ),
            ],
            actions: _deliveryRecoveryActions(
              incidentFeed: incidentFeed,
              selectedIncidentGroup: selectedIncidentGroup,
              includeComposer: true,
            ),
          )
        else ...[
          Text(
            selectedDelivery.title,
            style: GoogleFonts.inter(
              color: _clientTitleColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            selectedDelivery.body,
            style: GoogleFonts.inter(
              color: _clientBodyColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _pill(
                selectedDelivery.targetChannel.displayLabel,
                _clientInfoAccent,
                _clientBorderColor,
              ),
              _pill(
                _localizedDeliveryProviderLabel(
                  selectedDelivery.deliveryProvider,
                ),
                _clientAdminAccent,
                _clientAdminBorder,
              ),
              _pill(
                selectedDelivery.status == ClientPushDeliveryStatus.queued
                    ? _localizedQueuedStatus
                    : _localizedDeliveredStatus,
                selectedDelivery.status == ClientPushDeliveryStatus.queued
                    ? _clientPriorityAccent
                    : _clientSuccessAccent,
                _clientBorderColor,
              ),
              _pill(
                selectedDelivery.timeLabel,
                _clientWarningAccent,
                _clientWarningBorder,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (selectedNotification != null)
                OutlinedButton(
                  key: const ValueKey('client-delivery-open-draft'),
                  onPressed: () =>
                      _focusDraftNotificationAction(selectedNotification),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: selectedNotification.systemType.textColor,
                    side: BorderSide(
                      color: selectedNotification.systemType.borderColor,
                    ),
                  ),
                  child: Text(
                    _notificationActionLabelFor(
                      selectedNotification.systemType,
                    ),
                  ),
                ),
              if (selectedNotification != null &&
                  _canSendNotificationActionNow(
                    selectedNotification.systemType,
                  ))
                TextButton(
                  key: const ValueKey('client-delivery-send-now'),
                  onPressed: () =>
                      _sendNotificationAction(selectedNotification),
                  child: Text(
                    _notificationSendNowLabelFor(
                      selectedNotification.systemType,
                    ),
                  ),
                ),
              if (!shellless)
                OutlinedButton(
                  key: const ValueKey('client-delivery-open-thread'),
                  onPressed: openThread,
                  child: Text(
                    selectedIncidentGroup == null
                        ? 'Open First Incident'
                        : 'Reopen ${selectedIncidentGroup.referenceLabel}',
                  ),
                ),
              if (!shellless && widget.onRetryPushSync != null)
                OutlinedButton(
                  key: const ValueKey('client-delivery-retry-sync'),
                  onPressed: () {
                    unawaited(_retryPushSyncSafely());
                  },
                  child: Text(_localizedRetryPushSyncLabel),
                ),
              if (!shellless && widget.onRunBackendProbe != null)
                OutlinedButton(
                  key: const ValueKey('client-delivery-run-probe'),
                  onPressed: () {
                    unawaited(_runBackendProbeSafely());
                  },
                  child: Text(_localizedRunBackendProbeLabel),
                ),
              if (_sentNotificationMessageKey == selectedDelivery.messageKey &&
                  _sentThreadMessageKey != null)
                TextButton(
                  key: const ValueKey('client-delivery-view-thread'),
                  onPressed: _showSentMessageInThread,
                  child: Text(_viewSentMessageLabel()),
                ),
            ],
          ),
          if (selectedNotification != null &&
              !_canSendNotificationActionNow(
                selectedNotification.systemType,
              )) ...[
            const SizedBox(height: 6),
            Text(
              _draftRequiredHintFor(selectedNotification.systemType),
              style: GoogleFonts.inter(
                color: _clientBodyColor,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ],
    );
    if (shellless) {
      return KeyedSubtree(
        key: const ValueKey('client-delivery-workspace-selected-card'),
        child: content,
      );
    }
    return Container(
      key: const ValueKey('client-delivery-workspace-selected-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _clientPanelColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _clientBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [content],
      ),
    );
  }

  Widget _deliveryRecoveryDeck({
    required Key key,
    required String eyebrow,
    required String title,
    required String summary,
    required Color accent,
    required List<Widget> metrics,
    required List<Widget> actions,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _clientPanelTint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: GoogleFonts.inter(
              color: accent,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(
              color: _clientTitleColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            summary,
            style: GoogleFonts.inter(
              color: _clientBodyColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          if (metrics.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: metrics),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: actions),
          ],
        ],
      ),
    );
  }

  List<Widget> _deliveryRecoveryActions({
    required List<_ClientIncidentFeedGroup> incidentFeed,
    required _ClientIncidentFeedGroup? selectedIncidentGroup,
    required bool includeComposer,
  }) {
    return [
      _bannerActionChip(
        key: const ValueKey('client-delivery-recovery-open-thread'),
        label: selectedIncidentGroup == null
            ? 'Open first incident'
            : 'Reopen ${selectedIncidentGroup.referenceLabel}',
        accent: _clientInfoAccent,
        onTap: selectedIncidentGroup == null
            ? () => _openFirstAvailableIncidentThread(incidentFeed)
            : () => _reopenSelectedIncidentThread(incidentFeed),
      ),
      if (widget.onRetryPushSync != null)
        _bannerActionChip(
          key: const ValueKey('client-delivery-recovery-retry-sync'),
          label: 'Retry Push Sync',
          accent: _clientWarningAccent,
          onTap: () {
            unawaited(_retryPushSyncSafely());
          },
        ),
      if (widget.onRunBackendProbe != null)
        _bannerActionChip(
          key: const ValueKey('client-delivery-recovery-run-probe'),
          label: 'Run Backend Probe',
          accent: _clientSuccessAccent,
          onTap: () {
            unawaited(_runBackendProbeSafely());
          },
        ),
      if (includeComposer)
        _bannerActionChip(
          key: const ValueKey('client-delivery-recovery-focus-composer'),
          label: 'Jump to Composer',
          accent: _clientAdminAccent,
          onTap: _focusChatComposer,
        ),
    ];
  }

  Widget _contextActionButton({
    required Key key,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: _clientActionSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _clientBorderColor),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: _clientTitleColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  bool get _showDesktopCommandReceipt => true;

  void _showClientCommandFeedback(
    String message, {
    String label = 'INCIDENT HANDOFF',
    String? detail,
    Color accent = _clientInfoAccent,
  }) {
    if (!mounted) {
      return;
    }
    setState(() {
      _commandReceipt = _ClientCommandReceipt(
        label: label,
        message: message,
        detail:
            detail ??
            'The latest workspace command remains pinned in the incident rail.',
        accent: accent,
      );
    });
  }

  Future<void> _retryPushSyncSafely() async {
    final callback = widget.onRetryPushSync;
    if (callback == null) {
      return;
    }
    try {
      await callback();
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showClientCommandFeedback(
        'Push sync retry could not complete right now.',
        label: 'DELIVERY RECOVERY',
        detail:
            'The current delivery lane stayed open. Retry the sync again without losing the selected incident context.',
        accent: _clientWarningAccent,
      );
    }
  }

  Future<void> _runBackendProbeSafely() async {
    final callback = widget.onRunBackendProbe;
    if (callback == null) {
      return;
    }
    try {
      await callback();
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showClientCommandFeedback(
        'Backend probe could not complete right now.',
        label: 'DELIVERY RECOVERY',
        detail:
            'The workspace stayed in place. Retry the backend probe again without resetting the current delivery rail.',
        accent: _clientWarningAccent,
      );
    }
  }

  Widget _workspaceCommandReceiptCard(Key key, {bool shellless = false}) {
    if (shellless) {
      return Text(
        _commandReceipt.message,
        key: key,
        style: GoogleFonts.inter(
          color: _clientTitleColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      );
    }
    final receipt = _commandReceipt;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!shellless) ...[
          Text(
            'LATEST COMMAND',
            style: GoogleFonts.inter(
              color: receipt.accent,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 5),
        ],
        ...[
          Text(
            receipt.label,
            style: GoogleFonts.inter(
              color: _clientTitleColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            receipt.message,
            style: GoogleFonts.inter(
              color: _clientTitleColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 5),
        Text(
          receipt.detail,
          style: GoogleFonts.inter(
            color: _clientBodyColor,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ],
    );
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: receipt.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: receipt.accent.withValues(alpha: 0.34)),
      ),
      child: content,
    );
  }

  Widget _notificationsList(
    List<_ClientNotification> items, {
    required int totalCount,
    required int hiddenCount,
    required String roomDisplayName,
    required bool showAllRoomItems,
    required List<_ClientIncidentFeedGroup> incidentFeed,
    required _ClientIncidentFeedGroup? selectedIncidentGroup,
  }) {
    if (items.isEmpty) {
      return _deliveryRecoveryDeck(
        key: const ValueKey('client-notifications-empty-recovery'),
        eyebrow: 'ALERT RAIL READY',
        title: _viewerRole.notificationsEmptyLabel,
        summary:
            'This lane is quiet right now. Widen scope, reopen an incident thread, or jump back into drafting from here.',
        accent: _clientWarningAccent,
        metrics: [
          _pill('Lane $roomDisplayName', _clientInfoAccent, _clientInfoBorder),
          _pill(
            showAllRoomItems
                ? _localizedShowAllLabel
                : _localizedShowPendingLabel,
            _clientWarningAccent,
            _clientWarningBorder,
          ),
          _pill('Alerts $totalCount', _clientAdminAccent, _clientAdminBorder),
        ],
        actions: _communicationsRecoveryActions(
          prefix: 'client-notifications-empty',
          incidentFeed: incidentFeed,
          selectedIncidentGroup: selectedIncidentGroup,
          includeResetFilters: false,
        ),
      );
    }
    final selectedNotification = _selectedNotificationItem(items);
    final embeddedScroll = _desktopEmbeddedScroll;
    final list = ListView.separated(
      itemCount: items.length,
      shrinkWrap: !embeddedScroll,
      primary: embeddedScroll,
      physics: embeddedScroll ? null : const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final item = items[index];
        return _notificationRowCard(
          item,
          selected: selectedNotification.messageKey == item.messageKey,
        );
      },
      separatorBuilder: (_, _) => const SizedBox(height: 10),
    );
    if (embeddedScroll) {
      return SizedBox(
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _notificationsCommandDeck(
              selectedNotification: selectedNotification,
              totalCount: totalCount,
              hiddenCount: hiddenCount,
              showAllRoomItems: showAllRoomItems,
              incidentFeed: incidentFeed,
              selectedIncidentGroup: selectedIncidentGroup,
              shellless: embeddedScroll,
            ),
            Expanded(child: list),
            if (hiddenCount > 0) ...[
              const SizedBox(height: 8),
              OnyxTruncationHint(
                visibleCount: items.length,
                totalCount: totalCount,
                subject: 'notifications',
                color: _clientActionMuted,
              ),
            ],
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _notificationsCommandDeck(
          selectedNotification: selectedNotification,
          totalCount: totalCount,
          hiddenCount: hiddenCount,
          showAllRoomItems: showAllRoomItems,
          incidentFeed: incidentFeed,
          selectedIncidentGroup: selectedIncidentGroup,
          shellless: embeddedScroll,
        ),
        const SizedBox(height: 12),
        list,
        if (hiddenCount > 0) ...[
          const SizedBox(height: 8),
          OnyxTruncationHint(
            visibleCount: items.length,
            totalCount: totalCount,
            subject: 'notifications',
            color: _clientActionMuted,
          ),
        ],
      ],
    );
  }

  Widget _notificationsCommandDeck({
    required _ClientNotification selectedNotification,
    required int totalCount,
    required int hiddenCount,
    required bool showAllRoomItems,
    required List<_ClientIncidentFeedGroup> incidentFeed,
    required _ClientIncidentFeedGroup? selectedIncidentGroup,
    bool shellless = false,
  }) {
    if (shellless) {
      return const SizedBox.shrink(
        key: ValueKey('client-notifications-command-deck'),
      );
    }
    final canSendNow = _canSendNotificationActionNow(
      selectedNotification.systemType,
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!shellless) ...[
          Text(
            'Priority',
            style: GoogleFonts.inter(
              color: _clientWarningAccent,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 6),
        ],
        if (!shellless) ...[
          Text(
            '${selectedNotification.title} is the live alert focus. Draft, send, or pivot the lane without leaving this rail.',
            style: GoogleFonts.inter(
              color: _clientTitleColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _pill(
              selectedNotification.systemType.label,
              selectedNotification.systemType.textColor,
              selectedNotification.systemType.borderColor,
              icon: selectedNotification.systemType.icon,
            ),
            if (!shellless)
              _pill(
                selectedNotification.priority ? 'Priority' : 'Info',
                selectedNotification.priority
                    ? _clientPriorityAccent
                    : _clientInfoAccent,
                selectedNotification.priority
                    ? _clientPriorityBorder
                    : _clientBorderColor,
              ),
            if (!shellless)
              _pill(
                'Alerts $totalCount',
                _clientAdminAccent,
                _clientAdminBorder,
              ),
            if (!shellless)
              _pill(
                showAllRoomItems
                    ? _localizedShowAllLabel
                    : _localizedShowPendingLabel,
                _clientWarningAccent,
                _clientWarningBorder,
              ),
            if (!shellless)
              _pill(
                _notificationTargetBadgeLabel(),
                _clientInfoAccent,
                _clientInfoBorder,
              ),
            if (hiddenCount > 0 && !shellless)
              _pill(
                'Hidden $hiddenCount',
                _clientSuccessAccent,
                _clientSuccessBorder,
              ),
          ],
        ),
        if (!shellless) ...[
          const SizedBox(height: 12),
          Text(
            'NEXT MOVE',
            style: GoogleFonts.inter(
              color: _clientWarningAccent,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _bannerActionChip(
                key: const ValueKey('client-notifications-primary-action'),
                label: canSendNow
                    ? _notificationSendNowLabelFor(
                        selectedNotification.systemType,
                      )
                    : _notificationActionLabelFor(
                        selectedNotification.systemType,
                      ),
                accent: canSendNow
                    ? _clientSuccessAccent
                    : selectedNotification.systemType.textColor,
                onTap: canSendNow
                    ? () => _sendNotificationAction(selectedNotification)
                    : () => _focusDraftNotificationAction(selectedNotification),
              ),
              _bannerActionChip(
                key: const ValueKey('client-notifications-open-thread-action'),
                label: selectedIncidentGroup == null
                    ? 'Open first incident'
                    : 'Reopen ${selectedIncidentGroup.referenceLabel}',
                accent: _clientInfoAccent,
                onTap: selectedIncidentGroup == null
                    ? () => _openFirstAvailableIncidentThread(incidentFeed)
                    : () => _reopenSelectedIncidentThread(incidentFeed),
              ),
              _bannerActionChip(
                key: const ValueKey('client-notifications-toggle-scope'),
                label: showAllRoomItems
                    ? _localizedShowPendingLabel
                    : _localizedShowAllLabel,
                accent: _clientWarningAccent,
                selected: showAllRoomItems,
                onTap: _toggleShowAllRoomItems,
              ),
            ],
          ),
        ],
        if (!shellless) ...[
          const SizedBox(height: 10),
          Text(
            selectedNotification.body,
            style: GoogleFonts.inter(
              color: _clientBodyColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
    return Container(
      key: const ValueKey('client-notifications-command-deck'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _clientPanelTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _clientBorderColor),
        boxShadow: [
          BoxShadow(
            color: _clientShadowColor,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: content,
    );
  }

  Widget _notificationRowCard(
    _ClientNotification item, {
    required bool selected,
  }) {
    return InkWell(
      key: ValueKey('client-notification-row-${item.messageKey}'),
      onTap: () => _selectNotificationItem(item.messageKey),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? _clientSelectedPanelColor : _clientPanelColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? _clientStrongBorderColor
                : item.priority
                ? item.systemType.priorityBorderColor
                : _clientBorderColor,
          ),
          boxShadow: [
            BoxShadow(
              color: _clientShadowColor,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _pill(
                  item.systemType.label,
                  item.systemType.textColor,
                  item.systemType.borderColor,
                ),
                _pill(
                  item.priority ? 'Priority' : 'Info',
                  item.priority ? _clientPriorityAccent : _clientInfoAccent,
                  item.priority ? _clientPriorityBorder : _clientBorderColor,
                ),
                _pill(
                  _notificationTargetBadgeLabel(),
                  _clientInfoAccent,
                  _clientInfoBorder,
                ),
                if (selected && !_desktopEmbeddedScroll)
                  _pill('Current focus', _clientInfoAccent, _clientInfoBorder),
                Text(
                  item.timeLabel,
                  style: GoogleFonts.inter(
                    color: _clientMutedColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  item.systemType.icon,
                  size: 14,
                  color: item.systemType.textColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.title,
                    style: GoogleFonts.inter(
                      color: _clientTitleColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              item.body,
              style: GoogleFonts.inter(
                color: _clientBodyColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: [
                _notificationPrimaryAction(
                  item,
                  label: _notificationActionLabelFor(item.systemType),
                ),
                if (_canSendNotificationActionNow(item.systemType))
                  _notificationSendNowAction(item),
              ],
            ),
            if (_sentNotificationMessageKey == item.messageKey) ...[
              const SizedBox(height: 4),
              TextButton(
                onPressed: _showSentMessageInThread,
                style: _inlineHandoffButtonStyle(item.systemType.textColor),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _notificationSentLabelFor(item.systemType),
                      style: GoogleFonts.inter(
                        color: _clientInfoAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _viewSentMessageLabel(),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!_canSendNotificationActionNow(item.systemType)) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    _draftRequiredHintFor(item.systemType),
                    style: GoogleFonts.inter(
                      color: _clientBodyColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _focusDraftNotificationAction(item),
                    style: _inlineHandoffButtonStyle(item.systemType.textColor),
                    child: Text(
                      _draftReadyLabelFor(item.systemType),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_draftOpenedMessageKey == item.messageKey)
                    Text(
                      _draftOpenedLabelFor(item.systemType),
                      style: GoogleFonts.inter(
                        color: _clientInfoAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            _acknowledgementControls(item.messageKey, item.acknowledgements),
          ],
        ),
      ),
    );
  }

  List<Widget> _communicationsRecoveryActions({
    required String prefix,
    required List<_ClientIncidentFeedGroup> incidentFeed,
    required _ClientIncidentFeedGroup? selectedIncidentGroup,
    required bool includeResetFilters,
  }) {
    return [
      _bannerActionChip(
        key: ValueKey('$prefix-open-thread'),
        label: selectedIncidentGroup == null
            ? 'Open first incident'
            : 'Reopen ${selectedIncidentGroup.referenceLabel}',
        accent: _clientInfoAccent,
        onTap: selectedIncidentGroup == null
            ? () => _openFirstAvailableIncidentThread(incidentFeed)
            : () => _reopenSelectedIncidentThread(incidentFeed),
      ),
      _bannerActionChip(
        key: ValueKey('$prefix-focus-composer'),
        label: 'Jump to Composer',
        accent: _clientAdminAccent,
        onTap: _focusChatComposer,
      ),
      _bannerActionChip(
        key: ValueKey('$prefix-toggle-scope'),
        label: _showAllRoomItemsFor(_viewerRole)
            ? _localizedShowPendingLabel
            : _localizedShowAllLabel,
        accent: _clientWarningAccent,
        selected: _showAllRoomItemsFor(_viewerRole),
        onTap: _toggleShowAllRoomItems,
      ),
      if (includeResetFilters)
        _bannerActionChip(
          key: ValueKey('$prefix-reset-filters'),
          label: 'Reset Filters',
          accent: _clientSuccessAccent,
          onTap: _resetChatFilters,
        ),
    ];
  }

  Widget _pushSyncStatusStrip({bool shellless = false}) {
    final lastSyncedLabel = widget.pushSyncLastSyncedAtUtc == null
        ? 'none'
        : _timeLabel(widget.pushSyncLastSyncedAtUtc!.toUtc());
    final telegramDetail = (widget.telegramHealthDetail ?? '').trim();
    final failureReason = (widget.pushSyncFailureReason ?? '').trim();
    final humanizedFailureReason = _humanizedScopedCommsSummary(failureReason);
    final probeFailureReason = (widget.backendProbeFailureReason ?? '').trim();
    final probeLastRunLabel = widget.backendProbeLastRunAtUtc == null
        ? 'none'
        : _timeLabel(widget.backendProbeLastRunAtUtc!.toUtc());
    final telemetryActions = <Widget>[
      if (widget.onRetryPushSync != null)
        _bannerActionChip(
          key: const ValueKey('client-delivery-telemetry-retry-sync'),
          label: _localizedRetryPushSyncLabel,
          accent: _clientInfoAccent,
          onTap: () {
            unawaited(_retryPushSyncSafely());
          },
        ),
      if (widget.onRunBackendProbe != null)
        _bannerActionChip(
          key: const ValueKey('client-delivery-telemetry-run-probe'),
          label: _localizedRunBackendProbeLabel,
          accent: _clientSuccessAccent,
          onTap: () {
            unawaited(_runBackendProbeSafely());
          },
        ),
      if (widget.onClearBackendProbeHistory != null)
        _bannerActionChip(
          key: const ValueKey('client-delivery-telemetry-clear-probe'),
          label: _localizedClearProbeHistoryButton,
          accent: _clientWarningAccent,
          onTap: _confirmClearBackendProbeHistory,
        ),
    ];
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!shellless) ...[
          Text(
            'DELIVERY TELEMETRY',
            style: GoogleFonts.inter(
              color: _clientInfoAccent,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 4),
        ],
        if (!shellless) ...[
          Text(
            'Push sync, Telegram bridge, and backend probe health stay pinned while the delivery board shifts below.',
            style: GoogleFonts.inter(
              color: _clientBodyColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _pill(
              'Telegram ${widget.telegramHealthLabel.toUpperCase()}',
              _clientInfoAccent,
              _clientInfoBorder,
            ),
            _pill(
              'Sync ${_humanizedPushSyncStatusLabel(widget.pushSyncStatusLabel)}',
              _clientWarningAccent,
              _clientWarningBorder,
            ),
            _pill(
              'Retries ${widget.pushSyncRetryCount}',
              _clientAdminAccent,
              _clientAdminBorder,
            ),
            _pill(
              'Probe ${widget.backendProbeStatusLabel}',
              _clientSuccessAccent,
              _clientSuccessBorder,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _localizedTelegramStatusLine(
            widget.telegramHealthLabel.toUpperCase(),
          ),
          style: GoogleFonts.inter(
            color: _clientInfoAccent,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (widget.telegramFallbackActive) ...[
          const SizedBox(height: 4),
          Text(
            _localizedTelegramFallbackActive,
            style: GoogleFonts.inter(
              color: _clientWarningAccent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (telegramDetail.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            _humanizedScopedCommsSummary(telegramDetail),
            style: GoogleFonts.inter(
              color: _clientBodyColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          _localizedPushSyncStatusLine(
            _humanizedPushSyncStatusLabel(widget.pushSyncStatusLabel),
          ),
          style: GoogleFonts.inter(
            color: _clientInfoAccent,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _localizedLastSyncRetriesLine(
            lastSyncedLabel,
            widget.pushSyncRetryCount,
          ),
          style: GoogleFonts.inter(
            color: _clientBodyColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _localizedBackendProbeStatusLine(
            widget.backendProbeStatusLabel,
            probeLastRunLabel,
          ),
          style: GoogleFonts.inter(
            color: _clientBodyColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (failureReason.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            _localizedFailureLine(humanizedFailureReason),
            style: GoogleFonts.inter(
              color: _clientPriorityAccent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (probeFailureReason.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            _localizedProbeFailureLine(probeFailureReason),
            style: GoogleFonts.inter(
              color: _clientPriorityAccent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (telemetryActions.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: telemetryActions),
        ],
      ],
    );
    if (shellless) {
      return KeyedSubtree(
        key: const ValueKey('client-delivery-telemetry-strip'),
        child: content,
      );
    }
    return Container(
      key: const ValueKey('client-delivery-telemetry-strip'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _clientPanelColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _clientBorderColor),
        boxShadow: [
          BoxShadow(
            color: _clientShadowColor,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: content,
    );
  }

  Future<void> _confirmClearBackendProbeHistory() async {
    if (widget.onClearBackendProbeHistory == null) {
      return;
    }
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _clientPanelColor,
          title: Text(
            _localizedClearProbeHistoryTitle,
            style: GoogleFonts.inter(
              color: _clientTitleColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            _localizedClearProbeHistoryBody,
            style: GoogleFonts.inter(
              color: _clientBodyColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: Text(
                _localizedCancelLabel,
                style: GoogleFonts.inter(
                  color: _clientInfoAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(
                _localizedClearLabel,
                style: GoogleFonts.inter(
                  color: _clientWarningAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
    if (!mounted || shouldClear != true) {
      return;
    }
    await widget.onClearBackendProbeHistory!.call();
  }

  Widget _pushSyncHistoryList(
    List<ClientPushSyncAttempt> history, {
    bool shellless = false,
  }) {
    if (history.isEmpty) {
      return _deliveryRecoveryDeck(
        key: const ValueKey('client-delivery-push-sync-empty-recovery'),
        eyebrow: 'SYNC READY',
        title: _localizedPushSyncHistoryEmpty,
        summary:
            'No sync attempts are recorded yet. Force a sync cycle or run a backend probe from here.',
        accent: _clientInfoAccent,
        metrics: [
          _pill(
            'Sync ${_humanizedPushSyncStatusLabel(widget.pushSyncStatusLabel)}',
            _clientWarningAccent,
            _clientWarningBorder,
          ),
          _pill(
            'Retries ${widget.pushSyncRetryCount}',
            _clientAdminAccent,
            _clientAdminBorder,
          ),
        ],
        actions: [
          if (widget.onRetryPushSync != null)
            _bannerActionChip(
              key: const ValueKey('client-delivery-push-sync-empty-retry-sync'),
              label: _localizedRetryPushSyncLabel,
              accent: _clientInfoAccent,
              onTap: () {
                unawaited(_retryPushSyncSafely());
              },
            ),
          if (widget.onRunBackendProbe != null)
            _bannerActionChip(
              key: const ValueKey('client-delivery-push-sync-empty-run-probe'),
              label: _localizedRunBackendProbeLabel,
              accent: _clientSuccessAccent,
              onTap: () {
                unawaited(_runBackendProbeSafely());
              },
            ),
        ],
      );
    }
    final rows = history.take(5).toList(growable: false);
    final hiddenRows = history.length - rows.length;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!shellless) ...[
          Text(
            _localizedPushSyncHistoryTitle,
            style: GoogleFonts.inter(
              color: _clientInfoAccent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
        ],
        ...rows.map(
          (attempt) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              _pushSyncHistorySummaryLine(attempt),
              style: GoogleFonts.inter(
                color: _clientActionMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        if (hiddenRows > 0)
          OnyxTruncationHint(
            visibleCount: rows.length,
            totalCount: history.length,
            subject: 'sync attempts',
            color: _clientActionMuted,
          ),
      ],
    );
    if (shellless) {
      return KeyedSubtree(
        key: const ValueKey('client-delivery-push-sync-history-card'),
        child: content,
      );
    }
    return Container(
      key: const ValueKey('client-delivery-push-sync-history-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: onyxPanelSurfaceDecoration(),
      child: content,
    );
  }

  String _pushSyncHistorySummaryLine(ClientPushSyncAttempt attempt) {
    final reason = (attempt.failureReason ?? '').trim();
    final prefix =
        '${_timeLabel(attempt.occurredAt)} • ${_humanizedPushSyncHistoryStatus(attempt.status)} • queue:${attempt.queueSize}';
    if (reason.isEmpty) {
      return prefix;
    }
    return '$prefix • ${_humanizedScopedCommsSummary(reason)}';
  }

  String _humanizedScopedCommsSummary(String raw) {
    return ClientDeliveryMessageFormatter.humanizeScopedCommsSummary(raw);
  }

  String _humanizedPushSyncHistoryStatus(String status) {
    final normalized = status.trim().toLowerCase();
    return switch (normalized) {
      '' => 'standing by',
      'idle' => 'standing by',
      'ok' => 'synced',
      'failed' => 'needs review',
      'syncing' => 'sync in flight',
      'degraded' => 'delivery under watch',
      'sms-fallback-ok' => 'sms fallback sent',
      'telegram-blocked' => 'telegram blocked',
      'telegram-failed' => 'telegram failed',
      'voip-staged' => 'voip staged',
      'voip-failed' => 'voip needs review',
      _ => status,
    };
  }

  Widget _backendProbeHistoryList(
    List<ClientBackendProbeAttempt> history, {
    bool shellless = false,
  }) {
    if (history.isEmpty) {
      return _deliveryRecoveryDeck(
        key: const ValueKey('client-delivery-backend-probe-empty-recovery'),
        eyebrow: 'PROBE READY',
        title: _localizedBackendProbeHistoryEmpty,
        summary:
            'No probe runs are recorded yet. Start a backend probe to validate delivery health or clear stale notes.',
        accent: _clientSuccessAccent,
        metrics: [
          _pill(
            'Probe ${widget.backendProbeStatusLabel}',
            _clientSuccessAccent,
            _clientSuccessBorder,
          ),
          _pill(
            widget.backendProbeLastRunAtUtc == null
                ? 'Last none'
                : 'Last ${_timeLabel(widget.backendProbeLastRunAtUtc!.toUtc())}',
            _clientAdminAccent,
            _clientAdminBorder,
          ),
        ],
        actions: [
          if (widget.onRunBackendProbe != null)
            _bannerActionChip(
              key: const ValueKey(
                'client-delivery-backend-probe-empty-run-probe',
              ),
              label: _localizedRunBackendProbeLabel,
              accent: _clientSuccessAccent,
              onTap: () {
                unawaited(_runBackendProbeSafely());
              },
            ),
          if (widget.onClearBackendProbeHistory != null)
            _bannerActionChip(
              key: const ValueKey(
                'client-delivery-backend-probe-empty-clear-history',
              ),
              label: _localizedClearProbeHistoryButton,
              accent: _clientWarningAccent,
              onTap: _confirmClearBackendProbeHistory,
            ),
        ],
      );
    }
    final rows = history.take(5).toList(growable: false);
    final hiddenRows = history.length - rows.length;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!shellless) ...[
          Text(
            _localizedBackendProbeHistoryTitle,
            style: GoogleFonts.inter(
              color: _clientSuccessAccent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
        ],
        ...rows.map(
          (attempt) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              attempt.summaryLine,
              style: GoogleFonts.inter(
                color: _clientActionMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        if (hiddenRows > 0)
          OnyxTruncationHint(
            visibleCount: rows.length,
            totalCount: history.length,
            subject: 'backend probes',
            color: _clientActionMuted,
          ),
      ],
    );
    if (shellless) {
      return KeyedSubtree(
        key: const ValueKey('client-delivery-backend-probe-history-card'),
        child: content,
      );
    }
    return Container(
      key: const ValueKey('client-delivery-backend-probe-history-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: onyxPanelSurfaceDecoration(),
      child: content,
    );
  }

  Widget _roomsList(
    List<_ClientRoom> rooms, {
    required _ClientRoom activeRoom,
    required bool showAllRoomItems,
    required List<_ClientIncidentFeedGroup> incidentFeed,
    required _ClientIncidentFeedGroup? selectedIncidentGroup,
  }) {
    final visibleRooms = rooms.take(_maxRoomRows).toList(growable: false);
    final hiddenRooms = rooms.length - visibleRooms.length;
    final embeddedScroll = _desktopEmbeddedScroll;
    final list = ListView.separated(
      itemCount: visibleRooms.length,
      shrinkWrap: !embeddedScroll,
      primary: embeddedScroll,
      physics: embeddedScroll ? null : const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final room = visibleRooms[index];
        final selected = room.key == _selectedRoomFor(_viewerRole);
        return InkWell(
          key: ValueKey('client-room-${room.key}'),
          onTap: () => _setSelectedRoom(room.key),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected ? _clientSelectedPanelColor : _clientPanelColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? _clientStrongBorderColor : _clientBorderColor,
              ),
              boxShadow: [
                BoxShadow(
                  color: _clientShadowStrongColor,
                  blurRadius: 10,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        room.displayName,
                        style: GoogleFonts.inter(
                          color: _clientTitleColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _pill(
                      '${room.unread} unread',
                      _clientInfoAccent,
                      _clientBorderColor,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  room.summary,
                  style: GoogleFonts.inter(
                    color: _clientBodyColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _pill(
                      room.acknowledgementChannel.displayLabel,
                      _roomChannelAccent(room.acknowledgementChannel),
                      _clientBorderColor,
                    ),
                    if (selected && !_desktopEmbeddedScroll)
                      _pill(
                        'Current focus',
                        _clientInfoAccent,
                        _clientInfoBorder,
                      ),
                  ],
                ),
                if (selected && !embeddedScroll) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Recommended next move',
                    style: GoogleFonts.inter(
                      color: _clientInfoAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _bannerActionChip(
                        key: ValueKey('client-room-${room.key}-primary-action'),
                        label: selectedIncidentGroup == null
                            ? 'Open first incident'
                            : 'Reopen ${selectedIncidentGroup.referenceLabel}',
                        accent: _clientInfoAccent,
                        onTap: selectedIncidentGroup == null
                            ? () => _openFirstAvailableIncidentThread(
                                incidentFeed,
                              )
                            : () => _reopenSelectedIncidentThread(incidentFeed),
                      ),
                      _bannerActionChip(
                        key: ValueKey('client-room-${room.key}-scope-action'),
                        label: showAllRoomItems
                            ? _localizedShowPendingLabel
                            : _localizedShowAllLabel,
                        accent: _clientWarningAccent,
                        selected: showAllRoomItems,
                        onTap: _toggleShowAllRoomItems,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
      separatorBuilder: (_, _) => const SizedBox(height: 10),
    );
    if (embeddedScroll) {
      return SizedBox(
        height: 360,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: list),
            if (hiddenRooms > 0) ...[
              const SizedBox(height: 8),
              OnyxTruncationHint(
                visibleCount: visibleRooms.length,
                totalCount: rooms.length,
                subject: 'rooms',
                hiddenDescriptor: 'additional rooms',
                color: _clientActionMuted,
              ),
            ],
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _roomRailCommandDeck(
          activeRoom: activeRoom,
          showAllRoomItems: showAllRoomItems,
          incidentFeed: incidentFeed,
          selectedIncidentGroup: selectedIncidentGroup,
          roomCount: rooms.length,
          shellless: embeddedScroll,
        ),
        const SizedBox(height: 12),
        list,
        if (hiddenRooms > 0) ...[
          const SizedBox(height: 8),
          OnyxTruncationHint(
            visibleCount: visibleRooms.length,
            totalCount: rooms.length,
            subject: 'rooms',
            hiddenDescriptor: 'additional rooms',
            color: _clientActionMuted,
          ),
        ],
      ],
    );
  }

  Widget _roomRailCommandDeck({
    required _ClientRoom activeRoom,
    required bool showAllRoomItems,
    required List<_ClientIncidentFeedGroup> incidentFeed,
    required _ClientIncidentFeedGroup? selectedIncidentGroup,
    required int roomCount,
    bool shellless = false,
  }) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!shellless) ...[
          Text(
            'ROOM COMMAND RAIL',
            style: GoogleFonts.inter(
              color: _clientAccentBlue,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 5),
        ],
        if (!shellless) ...[
          Text(
            '${activeRoom.displayName} is holding the live lane while comms, alerts, and thread handoff stay within reach.',
            style: GoogleFonts.inter(
              color: _clientTitleColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _pill('Rooms $roomCount', _clientInfoAccent, _clientInfoBorder),
            _pill(
              'Unread ${activeRoom.unread}',
              _roomChannelAccent(activeRoom.acknowledgementChannel),
              _clientBorderColor,
            ),
            _pill(
              showAllRoomItems
                  ? _localizedShowAllLabel
                  : _localizedShowPendingLabel,
              _clientWarningAccent,
              _clientWarningBorder,
            ),
            if (selectedIncidentGroup != null)
              _pill(
                'Thread ${selectedIncidentGroup.referenceLabel}',
                _clientAdminAccent,
                _clientAdminBorder,
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _bannerActionChip(
              key: const ValueKey('client-room-rail-open-thread'),
              label: selectedIncidentGroup == null
                  ? 'Open first incident'
                  : 'Reopen ${selectedIncidentGroup.referenceLabel}',
              accent: _clientInfoAccent,
              onTap: selectedIncidentGroup == null
                  ? () => _openFirstAvailableIncidentThread(incidentFeed)
                  : () => _reopenSelectedIncidentThread(incidentFeed),
            ),
            _bannerActionChip(
              key: const ValueKey('client-room-rail-focus-composer'),
              label: 'Jump to Composer',
              accent: _clientAdminAccent,
              onTap: _focusChatComposer,
            ),
            _bannerActionChip(
              key: const ValueKey('client-room-rail-toggle-scope'),
              label: showAllRoomItems
                  ? _localizedShowPendingLabel
                  : _localizedShowAllLabel,
              accent: _clientWarningAccent,
              selected: showAllRoomItems,
              onTap: _toggleShowAllRoomItems,
            ),
          ],
        ),
      ],
    );
    if (shellless) {
      return KeyedSubtree(
        key: const ValueKey('client-room-rail-command-deck'),
        child: content,
      );
    }
    return Container(
      key: const ValueKey('client-room-rail-command-deck'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _clientPanelTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _clientStrongBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [content],
      ),
    );
  }

  Widget _incidentFeedList(List<_ClientIncidentFeedGroup> items) {
    if (items.isEmpty) {
      return _incidentFeedEmptyRecovery(items);
    }
    final visibleItems = items
        .take(_maxIncidentFeedRows)
        .toList(growable: false);
    final expandedReference =
        _expandedIncidentReferenceFor(_viewerRole) ??
        (_hasTouchedIncidentExpansionFor(_viewerRole)
            ? null
            : visibleItems.first.referenceLabel);
    final selectedReference =
        _selectedIncidentReference ??
        (_viewerRole == ClientAppViewerRole.client ? null : expandedReference);
    final embeddedScroll = _desktopEmbeddedScroll;
    final list = ListView.separated(
      itemCount: visibleItems.length,
      shrinkWrap: !embeddedScroll,
      primary: embeddedScroll,
      physics: embeddedScroll ? null : const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final group = visibleItems[index];
        final item = group.latestEntry;
        final expanded = expandedReference == group.referenceLabel;
        final selected = selectedReference == group.referenceLabel;
        final focused = _focusedIncidentReference == group.referenceLabel;
        return FocusableActionDetector(
          onShowFocusHighlight: (hasFocus) {
            setState(() {
              if (hasFocus) {
                _focusedIncidentReference = group.referenceLabel;
                _focusedIncidentReferenceByRole[_viewerRole.name] =
                    group.referenceLabel;
              } else if (_focusedIncidentReference == group.referenceLabel) {
                _focusedIncidentReference = null;
                _focusedIncidentReferenceByRole.remove(_viewerRole.name);
              }
            });
            _emitClientStateChanged();
          },
          child: InkWell(
            key: ValueKey('client-incident-row-${group.referenceLabel}'),
            onTap: () => _toggleIncidentFeedExpansion(group.referenceLabel),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected || expanded || focused
                    ? _clientSelectedPanelColor
                    : _clientPanelColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _incidentRowBorderColor(
                    expanded: expanded,
                    selected: selected,
                    focused: focused,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _pill(
                        _viewerRole.incidentStatusDisplayLabel(
                          item.statusLabel,
                        ),
                        item.accent,
                        item.borderColor,
                      ),
                      if (_viewerRole == ClientAppViewerRole.client) ...[
                        Text(
                          _viewerRole.incidentReferenceDisplayLabel(
                            group.referenceLabel,
                          ),
                          style: GoogleFonts.inter(
                            color: _clientInfoAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        _pill(
                          _viewerRole.incidentCountLabel(group.entries.length),
                          _clientAdminAccent,
                          _clientAdminBorder,
                        ),
                      ] else
                        _pill(
                          _viewerRole.incidentReferenceCountDisplayLabel(
                            group.referenceLabel,
                            group.entries.length,
                          ),
                          _clientAdminAccent,
                          _clientAdminBorder,
                        ),
                      if (selected)
                        _pill(
                          _viewerRole.selectedIncidentLabel,
                          _clientInfoAccent,
                          _clientInfoBorderSoft,
                        ),
                      if (expanded)
                        _pill(
                          _viewerRole.expandedIncidentLabel,
                          _clientAdminAccent,
                          _clientAdminBorder,
                        ),
                      if (focused)
                        _pill(
                          _viewerRole.focusedIncidentLabel,
                          _clientInfoAccent,
                          _clientInfoAccentStrong,
                        ),
                      Text(
                        _viewerRole.incidentTimeDisplayLabel(item.timeLabel),
                        style: GoogleFonts.inter(
                          color: _clientAccentBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _viewerRole.incidentHeadlineDisplay(
                      statusLabel: item.statusLabel,
                      referenceLabel: item.referenceLabel,
                      headline: item.headline,
                      detail: item.detail,
                    ),
                    style: GoogleFonts.inter(
                      color: _clientTitleColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _viewerRole.incidentDetailDisplay(
                      statusLabel: item.statusLabel,
                      referenceLabel: item.referenceLabel,
                      headline: item.headline,
                      detail: item.detail,
                    ),
                    style: GoogleFonts.inter(
                      color: _clientBodyColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildIncidentActionStrip(group, expanded),
                  if (expanded) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _clientPanelTint,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _clientBorderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: group.entries
                            .map(_incidentMilestoneLine)
                            .toList(growable: false),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
      separatorBuilder: (_, _) => const SizedBox(height: 10),
    );
    if (embeddedScroll) {
      return SizedBox(height: 220, child: list);
    }
    return list;
  }

  Widget _chatPanel(
    List<_ClientChatMessage> messages, {
    required List<_ClientIncidentFeedGroup> incidentFeed,
    required _ClientIncidentFeedGroup? selectedIncidentGroup,
  }) {
    final selectedSource = _chatSourceFilterFor(_viewerRole);
    final sourceOptions = <String>{
      'all',
      ...messages
          .map((message) => message.messageSource.trim())
          .where((value) => value.isNotEmpty),
    }.toList(growable: false)..sort();
    final providerOptions = <String>{
      'all',
      ...messages
          .where(
            (message) =>
                selectedSource == 'all' ||
                message.messageSource.trim() == selectedSource,
          )
          .map((message) => message.messageProvider.trim())
          .where((value) => value.isNotEmpty),
    }.toList(growable: false)..sort();
    final selectedProvider =
        providerOptions.contains(_chatProviderFilterFor(_viewerRole))
        ? _chatProviderFilterFor(_viewerRole)
        : 'all';
    final filtered = messages
        .where(
          (message) =>
              (selectedSource == 'all' ||
                  message.messageSource.trim() == selectedSource) &&
              (selectedProvider == 'all' ||
                  message.messageProvider.trim() == selectedProvider),
        )
        .toList(growable: false);
    final visibleMessages = filtered.take(_maxChatRows).toList(growable: false);
    final roomDisplayName = _activeRoomLabel();
    final quickActionTemplates = _viewerRole.quickActionTemplatesFor(
      _selectedRoomFor(_viewerRole),
    );
    final embeddedThreadScroll = _desktopEmbeddedScroll;
    final threadList = visibleMessages.isEmpty
        ? _deliveryRecoveryDeck(
            key: const ValueKey('client-chat-empty-recovery'),
            eyebrow: messages.isEmpty ? 'THREAD READY' : 'FILTERS ACTIVE',
            title: messages.isEmpty
                ? _viewerRole.chatEmptyLabel
                : 'No messages match the selected source/provider filters.',
            summary: messages.isEmpty
                ? 'This lane is quiet, but the thread shell stays hot so you can reopen incident context, widen scope, or jump straight into composition.'
                : 'The current source/provider filters narrowed this thread to zero rows. Reset filters or widen lane scope to bring the thread back into view.',
            accent: _clientInfoAccent,
            metrics: [
              _pill(
                'Lane $roomDisplayName',
                _clientInfoAccent,
                _clientInfoBorder,
              ),
              _pill(
                _showAllRoomItemsFor(_viewerRole)
                    ? _localizedShowAllLabel
                    : _localizedShowPendingLabel,
                _clientWarningAccent,
                _clientWarningBorder,
              ),
              _pill(
                'Source ${_messageSourceLabel(selectedSource)}',
                _clientAdminAccent,
                _clientAdminBorder,
              ),
              _pill(
                'Provider ${_messageProviderLabel(selectedProvider)}',
                _clientSuccessAccent,
                _clientSuccessBorder,
              ),
            ],
            actions: _communicationsRecoveryActions(
              prefix: 'client-chat-empty',
              incidentFeed: incidentFeed,
              selectedIncidentGroup: selectedIncidentGroup,
              includeResetFilters: messages.isNotEmpty,
            ),
          )
        : ListView.separated(
            itemCount: visibleMessages.length,
            shrinkWrap: !embeddedThreadScroll,
            primary: embeddedThreadScroll,
            physics: embeddedThreadScroll
                ? null
                : const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final message = visibleMessages[index];
              final highlightedThreadMessage =
                  message.messageKey == _threadLandingMessageKey;
              final incomingSystemType = message.outgoing
                  ? null
                  : message.systemType;
              final incomingBubbleFillColor = _clientPanelColor;
              final incomingBubbleBorderColor =
                  incomingSystemType?.cardBorderColor ?? _clientBorderColor;
              final incomingBubbleMetaColor =
                  incomingSystemType?.textColor ?? _clientMutedColor;
              return Align(
                alignment: message.outgoing
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 320),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: message.outgoing
                        ? (highlightedThreadMessage
                              ? _threadLandingBubbleFillColor()
                              : _viewerRole.outgoingBubbleFillColor)
                        : incomingBubbleFillColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: message.outgoing
                          ? (highlightedThreadMessage
                                ? _threadLandingBubbleBorderColor()
                                : _viewerRole.outgoingBubbleBorderColor)
                          : incomingBubbleBorderColor,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (incomingSystemType != null) ...[
                        _pill(
                          incomingSystemType.label,
                          incomingSystemType.textColor,
                          incomingSystemType.borderColor,
                          icon: incomingSystemType.icon,
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        _chatMessageMetaLabel(message),
                        style: GoogleFonts.inter(
                          color: message.outgoing
                              ? (highlightedThreadMessage
                                    ? _threadLandingBubbleMetaColor()
                                    : _viewerRole.outgoingBubbleMetaColor)
                              : incomingBubbleMetaColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        message.body,
                        style: GoogleFonts.inter(
                          color: message.outgoing
                              ? _clientTitleColor
                              : _clientTitleColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (!message.outgoing) ...[
                        const SizedBox(height: 6),
                        _acknowledgementControls(
                          message.messageKey,
                          message.acknowledgements,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
            separatorBuilder: (_, _) => const SizedBox(height: 10),
          );
    return Column(
      children: [
        if (_viewerRole == ClientAppViewerRole.control) ...[
          _laneVoiceControlStrip(),
          const SizedBox(height: 6),
        ],
        if (!embeddedThreadScroll)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _clientPanelTint,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _clientBorderColor),
            ),
            child: Text(
              'Room Focus: ${_activeRoomLabel()}',
              style: GoogleFonts.inter(
                color: _clientTitleColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sourceOptions
                .map(
                  (source) => ChoiceChip(
                    label: Text(
                      _messageSourceLabel(source),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    selected: selectedSource == source,
                    onSelected: (_) => _setChatSourceFilter(source),
                    selectedColor: _clientSelectedPanelColor,
                    side: BorderSide(
                      color: selectedSource == source
                          ? _clientStrongBorderColor
                          : _clientBorderColor,
                    ),
                    labelStyle: GoogleFonts.inter(
                      color: selectedSource == source
                          ? _clientAccentBlue
                          : _clientBodyColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    backgroundColor: _clientPanelColor,
                  ),
                )
                .toList(growable: false),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: providerOptions
                .map(
                  (provider) => ChoiceChip(
                    label: Text(
                      _messageProviderLabel(provider),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    selected: selectedProvider == provider,
                    onSelected: (_) => _setChatProviderFilter(provider),
                    selectedColor: _clientSelectedPanelColor,
                    side: BorderSide(
                      color: selectedProvider == provider
                          ? _clientStrongBorderColor
                          : _clientBorderColor,
                    ),
                    labelStyle: GoogleFonts.inter(
                      color: selectedProvider == provider
                          ? _clientAccentBlue
                          : _clientBodyColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    backgroundColor: _clientPanelColor,
                  ),
                )
                .toList(growable: false),
          ),
        ),
        if (_threadLandingMessageKey != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: _pill(
              _threadJumpedLabel(),
              _clientInfoAccent,
              _clientInfoAccent,
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (embeddedThreadScroll)
          SizedBox(key: _chatThreadKey, height: 276, child: threadList)
        else
          SizedBox(
            key: _chatThreadKey,
            width: double.infinity,
            child: threadList,
          ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 820;
            final composerField = TextField(
              controller: _chatController,
              focusNode: _chatFocusNode,
              style: GoogleFonts.inter(color: _clientTitleColor),
              decoration: InputDecoration(
                hintText: _viewerRole.chatComposerHintFor(
                  _selectedRoomFor(_viewerRole),
                ),
                hintStyle: GoogleFonts.inter(
                  color: _clientMutedColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                contentPadding: _phoneLayout
                    ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
                    : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: _chatComposerFillColor(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _chatComposerBorderColor()),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _chatComposerBorderColor()),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: _chatComposerFocusedBorderColor(),
                  ),
                ),
              ),
            );
            final composerActions = Column(
              crossAxisAlignment: stacked
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: [
                _composerStatusBadge(),
                if (_showComposerLearnedStyleCue) ...[
                  const SizedBox(height: 8),
                  _composerLearnedStyleCue(),
                ],
                const SizedBox(height: 8),
                if (widget.onAiAssistComposerDraft != null) ...[
                  OutlinedButton(
                    key: const ValueKey('client-chat-ai-assist-action'),
                    onPressed: _aiAssistComposerBusy
                        ? null
                        : _aiAssistClientMessage,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _clientInfoBorder,
                      side: const BorderSide(color: _clientActionBorder),
                      backgroundColor: _clientActionSurface,
                      minimumSize: Size(0, _phoneLayout ? 44 : 38),
                      padding: _phoneLayout
                          ? const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            )
                          : const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                      tapTargetSize: _phoneLayout
                          ? MaterialTapTargetSize.padded
                          : MaterialTapTargetSize.shrinkWrap,
                      visualDensity: _phoneLayout
                          ? VisualDensity.standard
                          : VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _aiAssistComposerBusy ? 'AI ASSISTING...' : 'AI ASSIST',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                FilledButton(
                  key: const ValueKey('client-chat-send-action'),
                  onPressed: _sendClientMessage,
                  style: FilledButton.styleFrom(
                    backgroundColor: _clientInfoAccentStrong,
                    foregroundColor: _clientTitleColor,
                    minimumSize: Size(0, _phoneLayout ? 44 : 38),
                    padding: _phoneLayout
                        ? const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          )
                        : const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                    tapTargetSize: _phoneLayout
                        ? MaterialTapTargetSize.padded
                        : MaterialTapTargetSize.shrinkWrap,
                    visualDensity: _phoneLayout
                        ? VisualDensity.standard
                        : VisualDensity.compact,
                    elevation: 0,
                    shadowColor: _clientShadowColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _chatSendButtonLabel(),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            );
            final composerSurface = stacked
                ? Column(
                    key: _chatComposerKey,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      composerField,
                      const SizedBox(height: 10),
                      composerActions,
                    ],
                  )
                : Row(
                    key: _chatComposerKey,
                    children: [
                      Expanded(child: composerField),
                      const SizedBox(width: 10),
                      composerActions,
                    ],
                  );
            return _chatComposerCommandDeck(
              roomDisplayName: roomDisplayName,
              showAllRoomItems: _showAllRoomItemsFor(_viewerRole),
              selectedSourceLabel: _messageSourceLabel(selectedSource),
              selectedProviderLabel: _messageProviderLabel(selectedProvider),
              quickActionTemplates: quickActionTemplates,
              incidentFeed: incidentFeed,
              selectedIncidentGroup: selectedIncidentGroup,
              composerSurface: composerSurface,
              shellless: embeddedThreadScroll,
            );
          },
        ),
      ],
    );
  }

  Widget _chatComposerCommandDeck({
    required String roomDisplayName,
    required bool showAllRoomItems,
    required String selectedSourceLabel,
    required String selectedProviderLabel,
    required List<String> quickActionTemplates,
    required List<_ClientIncidentFeedGroup> incidentFeed,
    required _ClientIncidentFeedGroup? selectedIncidentGroup,
    required Widget composerSurface,
    bool shellless = false,
  }) {
    final composedType = _composedSystemType ?? _ClientSystemMessageType.update;
    final hasDraftText = _chatController.text.trim().isNotEmpty;
    final recommendedTemplate = quickActionTemplates.first;
    final primaryActionLabel = hasDraftText
        ? _chatSendButtonLabel()
        : 'Load recommended draft';
    final primaryActionAccent = hasDraftText
        ? _clientSuccessAccent
        : _clientInfoAccent;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!shellless) ...[
          Text(
            'COMPOSER COMMAND DECK',
            style: GoogleFonts.inter(
              color: _clientInfoAccent,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 5),
        ],
        if (!shellless) ...[
          Text(
            hasDraftText
                ? '$roomDisplayName has a staged ${composedType.label.toLowerCase()} ready for review and send.'
                : '$roomDisplayName is hot. Load the recommended draft, adjust posture, and push the next operator update from one surface.',
            style: GoogleFonts.inter(
              color: _clientBodyColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _pill(
              'Lane $roomDisplayName',
              _clientInfoAccent,
              _clientInfoBorder,
            ),
            _pill(
              showAllRoomItems
                  ? _localizedShowAllLabel
                  : _localizedShowPendingLabel,
              _clientWarningAccent,
              _clientWarningBorder,
            ),
            _pill(
              'Source $selectedSourceLabel',
              _clientAdminAccent,
              _clientAdminBorder,
            ),
            _pill(
              'Provider $selectedProviderLabel',
              _clientSuccessAccent,
              _clientSuccessBorder,
            ),
            _pill(
              'Posture ${composedType.label}',
              composedType.textColor,
              composedType.borderColor,
              icon: composedType.icon,
            ),
            if (selectedIncidentGroup != null)
              _pill(
                'Thread ${selectedIncidentGroup.referenceLabel}',
                _clientPriorityAccent,
                _clientPriorityBorder,
              ),
          ],
        ),
        if (!shellless) ...[
          const SizedBox(height: 12),
          Text(
            'Recommended next move',
            style: GoogleFonts.inter(
              color: _clientInfoAccent,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
        ] else
          const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!shellless)
              _bannerActionChip(
                key: const ValueKey('client-chat-command-deck-primary-action'),
                label: primaryActionLabel,
                accent: primaryActionAccent,
                onTap: hasDraftText
                    ? () {
                        _sendClientMessage();
                      }
                    : () => _loadRecommendedChatDraft(recommendedTemplate),
              ),
            if (!shellless)
              _bannerActionChip(
                key: const ValueKey('client-chat-command-deck-open-thread'),
                label: selectedIncidentGroup == null
                    ? 'Open first incident'
                    : 'Reopen ${selectedIncidentGroup.referenceLabel}',
                accent: _clientAdminAccent,
                onTap: selectedIncidentGroup == null
                    ? () => _openFirstAvailableIncidentThread(incidentFeed)
                    : () => _reopenSelectedIncidentThread(incidentFeed),
              ),
            if (!shellless)
              _bannerActionChip(
                key: const ValueKey('client-chat-command-deck-focus-composer'),
                label: 'Jump to Composer',
                accent: _clientInfoAccent,
                onTap: _focusChatComposer,
              ),
            if (!shellless)
              _bannerActionChip(
                key: const ValueKey('client-chat-command-deck-toggle-scope'),
                label: showAllRoomItems
                    ? _localizedShowPendingLabel
                    : _localizedShowAllLabel,
                accent: _clientWarningAccent,
                selected: showAllRoomItems,
                onTap: _toggleShowAllRoomItems,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Quick drafts',
          style: GoogleFonts.inter(
            color: _clientMutedColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var index = 0; index < quickActionTemplates.length; index += 1)
              OutlinedButton(
                key: ValueKey('client-chat-quick-action-$index'),
                onPressed: () => _applyQuickAction(quickActionTemplates[index]),
                style: _compactOutlinedActionStyle(
                  foregroundColor: index == 0
                      ? _clientAccentBlue
                      : _clientBodyColor,
                  sideColor: index == 0
                      ? _clientStrongBorderColor
                      : _clientBorderColor,
                  backgroundColor: index == 0
                      ? _clientSelectedPanelColor
                      : _clientPanelColor,
                ),
                child: Text(
                  quickActionTemplates[index],
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _manualIncidentTypeSelector(),
        const SizedBox(height: 12),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _clientPanelMuted,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _showComposerLandingHighlight
                  ? _clientStrongBorderColor
                  : _clientBorderColor,
            ),
          ),
          child: composerSurface,
        ),
      ],
    );
    if (shellless) {
      return KeyedSubtree(
        key: const ValueKey('client-chat-composer-command-deck'),
        child: content,
      );
    }
    return Container(
      key: const ValueKey('client-chat-composer-command-deck'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _clientPanelTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _clientBorderColor),
        boxShadow: [
          BoxShadow(
            color: _clientShadowColor,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: content,
    );
  }

  Widget _laneVoiceControlStrip() {
    final activeSignal = widget.laneVoiceProfileSignal.trim().toLowerCase();
    final canAdjust = widget.onSetLaneVoiceProfile != null;
    final hasPinnedVoice = activeSignal.isNotEmpty;
    final hasLearnedStyle = widget.learnedApprovalStyleCount > 0;
    final options = <({String label, String? signal})>[
      (label: 'Auto', signal: null),
      (label: 'Concise', signal: 'concise-updates'),
      (label: 'Reassuring', signal: 'reassurance-forward'),
      (label: 'Validation-heavy', signal: 'validation-heavy'),
    ];

    return Container(
      key: const ValueKey('client-lane-voice-strip'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _clientPanelTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _clientBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.tune_rounded,
                size: 15,
                color: _clientInfoAccent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Lane voice: ${widget.laneVoiceProfileLabel}',
                  style: GoogleFonts.inter(
                    color: _clientTitleColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (_laneVoiceProfileBusy)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _clientInfoAccent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Shape ONYX toward the tone this lane needs before you review or send the next reply.',
            style: GoogleFonts.inter(
              color: _clientBodyColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ONYX mode: ${_laneOnyxModeLabel(hasPinnedVoice: hasPinnedVoice, hasLearnedStyle: hasLearnedStyle)}',
            style: GoogleFonts.inter(
              color: _clientTitleColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (hasPinnedVoice)
                _laneVoiceStatusChip(
                  icon: Icons.tune_rounded,
                  label: 'Pinned voice ${widget.laneVoiceProfileLabel}',
                  accent: _clientInfoAccent,
                ),
              if (hasLearnedStyle)
                _laneVoiceStatusChip(
                  icon: Icons.school_rounded,
                  label:
                      'Learned approvals (${widget.learnedApprovalStyleCount})',
                  accent: _clientInfoAccentStrong,
                ),
              if (!hasPinnedVoice && !hasLearnedStyle)
                _laneVoiceStatusChip(
                  icon: Icons.auto_mode_rounded,
                  label: 'No pinned or learned override active',
                  accent: _clientMutedColor,
                ),
            ],
          ),
          if (widget.learnedApprovalStyleExample.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _clientPanelColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _clientBorderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Learned approval style',
                    style: GoogleFonts.inter(
                      color: _clientAccentBlue,
                      fontSize: 10.8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.learnedApprovalStyleExample.trim(),
                    style: GoogleFonts.inter(
                      color: _clientTitleColor,
                      fontSize: 11.2,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (hasLearnedStyle) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed:
                  widget.onClearLearnedLaneStyle == null ||
                      _laneLearnedStyleBusy
                  ? null
                  : _clearLearnedLaneStyle,
              style: OutlinedButton.styleFrom(
                foregroundColor: _clientInfoAccent,
                side: const BorderSide(color: _clientActionBorderStrong),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              icon: _laneLearnedStyleBusy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _clientInfoAccent,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded, size: 14),
              label: Text(
                'Clear Learned Style',
                style: GoogleFonts.inter(
                  fontSize: 10.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options
                .map((option) {
                  final optionSignal = (option.signal ?? '')
                      .trim()
                      .toLowerCase();
                  final selected = optionSignal == activeSignal;
                  return ChoiceChip(
                    label: Text(
                      option.label,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    selected: selected,
                    onSelected: !canAdjust || _laneVoiceProfileBusy
                        ? null
                        : (_) => _setLaneVoiceProfile(option.signal),
                    selectedColor: _clientInfoSurface,
                    side: BorderSide(
                      color: selected
                          ? _clientStrongBorderColor
                          : _clientBorderColor,
                    ),
                    labelStyle: GoogleFonts.inter(
                      color: selected ? _clientAccentBlue : _clientBodyColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    backgroundColor: _clientPanelColor,
                  );
                })
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  Future<void> _setLaneVoiceProfile(String? profileSignal) async {
    if (widget.onSetLaneVoiceProfile == null || _laneVoiceProfileBusy) {
      return;
    }
    final currentSignal = widget.laneVoiceProfileSignal.trim().toLowerCase();
    final nextSignal = (profileSignal ?? '').trim().toLowerCase();
    if (currentSignal == nextSignal) {
      return;
    }
    setState(() {
      _laneVoiceProfileBusy = true;
    });
    try {
      await widget.onSetLaneVoiceProfile!(profileSignal);
    } finally {
      if (mounted) {
        setState(() {
          _laneVoiceProfileBusy = false;
        });
      }
    }
  }

  Future<void> _clearLearnedLaneStyle() async {
    if (widget.onClearLearnedLaneStyle == null || _laneLearnedStyleBusy) {
      return;
    }
    setState(() {
      _laneLearnedStyleBusy = true;
    });
    try {
      await widget.onClearLearnedLaneStyle!.call();
    } finally {
      if (mounted) {
        setState(() {
          _laneLearnedStyleBusy = false;
        });
      }
    }
  }

  String _laneOnyxModeLabel({
    required bool hasPinnedVoice,
    required bool hasLearnedStyle,
  }) {
    if (hasPinnedVoice && hasLearnedStyle) {
      return 'Pinned voice + learned approvals';
    }
    if (hasPinnedVoice) {
      return 'Pinned voice';
    }
    if (hasLearnedStyle) {
      return 'Learned approvals';
    }
    return 'Auto';
  }

  Widget _laneVoiceStatusChip({
    required IconData icon,
    required String label,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: accent),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              color: accent,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _manualIncidentTypeSelector() {
    final selectedType = _composedSystemType ?? _ClientSystemMessageType.update;
    return Column(
      key: const ValueKey('client-chat-incident-type-selector'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _composedSystemType == _ClientSystemMessageType.dispatch
              ? 'Incident Type: Dispatch review active'
              : 'Incident Type',
          style: GoogleFonts.inter(
            color: _clientMutedColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              const [
                    _ClientSystemMessageType.update,
                    _ClientSystemMessageType.advisory,
                    _ClientSystemMessageType.closure,
                  ]
                  .map((type) {
                    final selected = selectedType == type;
                    return OutlinedButton(
                      onPressed: () => _setComposedSystemType(type),
                      style: _compactOutlinedActionStyle(
                        foregroundColor: selected
                            ? type.textColor
                            : _clientBodyColor,
                        sideColor: selected
                            ? type.borderColor
                            : _clientBorderColor,
                        backgroundColor: selected
                            ? _clientSelectedPanelColor
                            : _clientPanelColor,
                      ),
                      child: Text(
                        type.label,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  })
                  .toList(growable: false),
        ),
      ],
    );
  }

  Widget _composerStatusBadge() {
    final type = _composedSystemType ?? _ClientSystemMessageType.update;
    final label = switch (type) {
      _ClientSystemMessageType.dispatch => _localizedTemplate(
        key: 'composerStatusReadyDispatchReview',
        fallback: 'Ready: Dispatch review',
      ),
      _ClientSystemMessageType.advisory => _localizedTemplate(
        key: 'composerStatusReadyAdvisory',
        fallback: 'Ready: Advisory',
      ),
      _ClientSystemMessageType.closure => _localizedTemplate(
        key: 'composerStatusReadyClosure',
        fallback: 'Ready: Closure',
      ),
      _ClientSystemMessageType.update => _localizedTemplate(
        key: 'composerStatusReadyUpdate',
        fallback: 'Ready: Update',
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _clientPanelColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: type.cardBorderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icon, size: 14, color: type.textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: type.textColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _composerLearnedStyleCue() {
    final example = widget.learnedApprovalStyleExample.trim();
    return Container(
      key: const ValueKey('client-composer-learned-style-cue'),
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _clientPanelMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _clientBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.school_rounded,
                size: 14,
                color: _clientInfoAccentStrong,
              ),
              const SizedBox(width: 6),
              Text(
                'Uses learned approval style',
                style: GoogleFonts.inter(
                  color: _clientTitleColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'This prefill is leaning on approved lane wording from earlier operator edits.',
            style: GoogleFonts.inter(
              color: _clientBodyColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          if (example.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Latest learned pattern: "$example"',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: _clientTitleColor,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String get _laneVoiceProfileSignalNormalized =>
      widget.laneVoiceProfileSignal.trim().toLowerCase();

  bool get _hasPinnedLaneVoiceProfile =>
      _laneVoiceProfileSignalNormalized.isNotEmpty;

  bool get _showComposerLearnedStyleCue {
    if (_viewerRole != ClientAppViewerRole.control ||
        widget.learnedApprovalStyleCount <= 0) {
      return false;
    }
    return _composedSystemType != null ||
        _draftOpenedMessageKey != null ||
        _chatController.text.trim().isNotEmpty;
  }

  String _withLaneVoiceLabel(String baseLabel) {
    if (_viewerRole != ClientAppViewerRole.control ||
        !_hasPinnedLaneVoiceProfile) {
      return baseLabel;
    }
    return '$baseLabel • ${widget.laneVoiceProfileLabel}';
  }

  String _chatSendButtonLabel() {
    final roomKey = _selectedRoomFor(_viewerRole);
    final roomLabel = _roomDisplayNameForKey(roomKey);
    final type = _composedSystemType ?? _ClientSystemMessageType.update;
    if (type == _ClientSystemMessageType.update) {
      return _viewerRole.chatSendLabelFor(roomKey);
    }
    return switch ((_viewerRole, type)) {
      (ClientAppViewerRole.client, _ClientSystemMessageType.advisory) =>
        _localizedTemplate(
          key: 'chatSendClientAdvisory',
          fallback: 'Send Advisory to {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.client, _ClientSystemMessageType.closure) =>
        _localizedTemplate(
          key: 'chatSendClientClosure',
          fallback: 'Send Closure to {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.client, _ClientSystemMessageType.dispatch) =>
        _localizedTemplate(
          key: 'chatSendClientDispatchReview',
          fallback: 'Send Dispatch Review to {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.control, _ClientSystemMessageType.advisory) =>
        _localizedTemplate(
          key: 'chatSendControlAdvisory',
          fallback: 'Log Advisory for {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.control, _ClientSystemMessageType.closure) =>
        _localizedTemplate(
          key: 'chatSendControlClosure',
          fallback: 'Log Closure for {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.control, _ClientSystemMessageType.dispatch) =>
        _localizedTemplate(
          key: 'chatSendControlDispatchReview',
          fallback: 'Log Dispatch Review for {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.resident, _ClientSystemMessageType.advisory) =>
        _localizedTemplate(
          key: 'chatSendResidentAdvisory',
          fallback: 'Post Advisory to {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.resident, _ClientSystemMessageType.closure) =>
        _localizedTemplate(
          key: 'chatSendResidentClosure',
          fallback: 'Post Closure to {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.resident, _ClientSystemMessageType.dispatch) =>
        _localizedTemplate(
          key: 'chatSendResidentDispatchReview',
          fallback: 'Post Dispatch Review to {room}',
          tokens: {'room': roomLabel},
        ),
      (_, _) => _viewerRole.chatSendLabelFor(roomKey),
    };
  }

  Widget _pill(
    String label,
    Color textColor,
    Color borderColor, {
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: borderColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon, size: 11, color: textColor)],
          Text(
            label,
            style: GoogleFonts.inter(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _acknowledgementStatus(ClientAppAcknowledgement acknowledgement) {
    return Text(
      '${acknowledgement.displayLabel} by ${acknowledgement.acknowledgedBy} at '
      '${_timeLabel(acknowledgement.acknowledgedAt)}',
      style: GoogleFonts.inter(
        color: _clientSuccessAccent,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  bool _sameClientAppMessages(
    List<ClientAppMessage> left,
    List<ClientAppMessage> right,
  ) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      final a = left[index];
      final b = right[index];
      if (a.author != b.author ||
          a.body != b.body ||
          a.occurredAt != b.occurredAt ||
          a.roomKey != b.roomKey ||
          a.viewerRole != b.viewerRole ||
          a.incidentStatusLabel != b.incidentStatusLabel ||
          a.messageSource != b.messageSource ||
          a.messageProvider != b.messageProvider) {
        return false;
      }
    }
    return true;
  }

  bool _sameClientAppAcknowledgements(
    List<ClientAppAcknowledgement> left,
    List<ClientAppAcknowledgement> right,
  ) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      final a = left[index];
      final b = right[index];
      if (a.messageKey != b.messageKey ||
          a.channel != b.channel ||
          a.acknowledgedBy != b.acknowledgedBy ||
          a.acknowledgedAt != b.acknowledgedAt) {
        return false;
      }
    }
    return true;
  }

  Widget _acknowledgementControls(
    String messageKey,
    List<ClientAppAcknowledgement> acknowledgements,
  ) {
    ClientAppAcknowledgement? findInList(
      ClientAppAcknowledgementChannel channel,
    ) {
      for (final acknowledgement in acknowledgements) {
        if (acknowledgement.channel == channel) {
          return acknowledgement;
        }
      }
      return null;
    }

    final clientAck = findInList(ClientAppAcknowledgementChannel.client);
    final controlAck = findInList(ClientAppAcknowledgementChannel.control);
    final residentAck = findInList(ClientAppAcknowledgementChannel.resident);
    final viewerChannel = _viewerRole.acknowledgementChannel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (clientAck != null) _acknowledgementStatus(clientAck),
        if (controlAck != null) ...[
          if (clientAck != null) const SizedBox(height: 4),
          _acknowledgementStatus(controlAck),
        ],
        if (residentAck != null) ...[
          if (clientAck != null || controlAck != null)
            const SizedBox(height: 4),
          _acknowledgementStatus(residentAck),
        ],
        Wrap(
          spacing: 10,
          runSpacing: 4,
          children: [
            if (viewerChannel == ClientAppAcknowledgementChannel.client &&
                clientAck == null)
              _acknowledgementAction(
                label: 'Client Ack',
                onTap: () => _acknowledgeMessage(
                  messageKey,
                  ClientAppAcknowledgementChannel.client,
                ),
              ),
            if (viewerChannel == ClientAppAcknowledgementChannel.control &&
                controlAck == null)
              _acknowledgementAction(
                label: 'Control Ack',
                onTap: () => _acknowledgeMessage(
                  messageKey,
                  ClientAppAcknowledgementChannel.control,
                ),
              ),
            if (viewerChannel == ClientAppAcknowledgementChannel.resident &&
                residentAck == null)
              _acknowledgementAction(
                label: 'Resident Seen',
                onTap: () => _acknowledgeMessage(
                  messageKey,
                  ClientAppAcknowledgementChannel.resident,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _acknowledgementAction({
    required String label,
    required VoidCallback onTap,
  }) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: _phoneLayout
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
            : EdgeInsets.zero,
        minimumSize: Size(0, _phoneLayout ? 40 : 0),
        tapTargetSize: _phoneLayout
            ? MaterialTapTargetSize.padded
            : MaterialTapTargetSize.shrinkWrap,
        foregroundColor: _clientInfoAccent,
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _notificationPrimaryAction(
    _ClientNotification item, {
    required String label,
  }) {
    return OutlinedButton(
      onPressed: () => _draftNotificationAction(item),
      style: OutlinedButton.styleFrom(
        foregroundColor: item.systemType.textColor,
        side: BorderSide(color: item.systemType.borderColor),
        backgroundColor: _clientActionSurface,
        minimumSize: Size(0, _phoneLayout ? 42 : 36),
        padding: _phoneLayout
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
            : const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        tapTargetSize: _phoneLayout
            ? MaterialTapTargetSize.padded
            : MaterialTapTargetSize.shrinkWrap,
        visualDensity: _phoneLayout
            ? VisualDensity.standard
            : VisualDensity.compact,
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _notificationSendNowAction(_ClientNotification item) {
    return TextButton(
      onPressed: () => _sendNotificationAction(item),
      style: TextButton.styleFrom(
        padding: _phoneLayout
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
            : EdgeInsets.zero,
        minimumSize: Size(0, _phoneLayout ? 40 : 0),
        tapTargetSize: _phoneLayout
            ? MaterialTapTargetSize.padded
            : MaterialTapTargetSize.shrinkWrap,
        foregroundColor: item.systemType.textColor,
      ),
      child: Text(
        _notificationSendNowLabelFor(item.systemType),
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Future<void> _sendClientMessage() async {
    final text = _chatController.text.trim();
    final systemType = _composedSystemType;
    final originalDraftText = _reviewedDraftOriginalText?.trim() ?? '';
    _sendManualMessageText(text, systemType: systemType, clearComposer: true);
    if (_viewerRole == ClientAppViewerRole.control &&
        systemType == _ClientSystemMessageType.dispatch &&
        originalDraftText.isNotEmpty &&
        text.isNotEmpty &&
        widget.onRecordApprovedDraftLearning != null) {
      try {
        await widget.onRecordApprovedDraftLearning!(originalDraftText, text);
      } catch (_) {
        if (!mounted) {
          return;
        }
        _showClientCommandFeedback(
          'Dispatch review sent, but approval-style learning was not saved.',
          label: 'LEARNING RETRY',
          detail:
              'The message still went out. Retry the learning pass later without blocking the active lane.',
          accent: _clientWarningAccent,
        );
      }
    }
  }

  Future<void> _aiAssistClientMessage() async {
    final assist = widget.onAiAssistComposerDraft;
    if (assist == null || _aiAssistComposerBusy) {
      return;
    }
    final currentDraftText = _chatController.text.trim();
    final room = _selectedRoomFor(_viewerRole);
    setState(() {
      _aiAssistComposerBusy = true;
    });
    try {
      final assistedDraft = await assist(
        widget.clientId,
        widget.siteId,
        room,
        currentDraftText,
      );
      final normalizedAssistedDraft = assistedDraft?.trim() ?? '';
      if (!mounted || normalizedAssistedDraft.isEmpty) {
        return;
      }
      setState(() {
        if (_reviewedDraftOriginalText == null && currentDraftText.isNotEmpty) {
          _reviewedDraftOriginalText = currentDraftText;
        }
        _chatController.text = normalizedAssistedDraft;
        _chatController.selection = TextSelection.collapsed(
          offset: _chatController.text.length,
        );
      });
      _focusChatComposer();
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showClientCommandFeedback(
        'AI assist could not refine this draft right now.',
        label: 'AI ASSIST',
        detail:
            'The current draft stayed in the composer unchanged so you can edit or send it manually.',
        accent: _clientWarningAccent,
      );
    } finally {
      if (mounted) {
        setState(() {
          _aiAssistComposerBusy = false;
        });
      }
    }
  }

  bool get _shouldAutoAssistControlComposerPrefill =>
      _viewerRole == ClientAppViewerRole.control &&
      widget.onAiAssistComposerDraft != null &&
      !_aiAssistComposerBusy &&
      _chatController.text.trim().isNotEmpty;

  void _scheduleAiAssistForControlComposerPrefill() {
    if (!_shouldAutoAssistControlComposerPrefill) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_shouldAutoAssistControlComposerPrefill) {
        return;
      }
      unawaited(_aiAssistClientMessage());
    });
  }

  void _applyQuickAction(
    String template, {
    _ClientSystemMessageType? systemType,
    String? reviewedDraftOriginalText,
  }) {
    setState(() {
      _composedSystemType = systemType ?? _composedSystemType;
      _reviewedDraftOriginalText = reviewedDraftOriginalText;
      _chatController.text = template;
      _chatController.selection = TextSelection.collapsed(
        offset: _chatController.text.length,
      );
    });
  }

  void _loadRecommendedChatDraft(String template) {
    _applyQuickAction(template);
    _focusChatComposer();
    _scheduleAiAssistForControlComposerPrefill();
  }

  void _draftNotificationAction(_ClientNotification item) {
    final draftText = _notificationActionDraftFor(item);
    _applyQuickAction(
      draftText,
      systemType: item.systemType,
      reviewedDraftOriginalText: draftText,
    );
    _scheduleAiAssistForControlComposerPrefill();
  }

  void _setComposedSystemType(_ClientSystemMessageType type) {
    setState(() {
      _composedSystemType = type;
      _reviewedDraftOriginalText = null;
    });
  }

  void _focusDraftNotificationAction(_ClientNotification item) {
    _draftNotificationAction(item);
    _triggerComposerLandingHighlight(item.messageKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final composerContext = _chatComposerKey.currentContext;
      if (composerContext != null) {
        Scrollable.ensureVisible(
          composerContext,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: 1,
        );
      }
      _chatFocusNode.requestFocus();
    });
  }

  void _focusChatComposer() {
    if (mounted) {
      setState(() {
        _showComposerLandingHighlight = true;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final composerContext = _chatComposerKey.currentContext;
      if (composerContext != null) {
        Scrollable.ensureVisible(
          composerContext,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: 1,
        );
      }
      _chatFocusNode.requestFocus();
    });
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showComposerLandingHighlight = false;
      });
    });
  }

  void _triggerComposerLandingHighlight(String messageKey) {
    if (mounted) {
      setState(() {
        _showComposerLandingHighlight = true;
        _draftOpenedMessageKey = messageKey;
      });
    }
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showComposerLandingHighlight = false;
        if (_draftOpenedMessageKey == messageKey) {
          _draftOpenedMessageKey = null;
        }
      });
    });
  }

  void _triggerNotificationSentConfirmation(String messageKey) {
    if (mounted) {
      setState(() {
        _sentNotificationMessageKey = messageKey;
      });
    }
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) {
        return;
      }
      setState(() {
        if (_sentNotificationMessageKey == messageKey) {
          _sentNotificationMessageKey = null;
        }
      });
    });
  }

  void _showSentMessageInThread() {
    final messageKey = _sentThreadMessageKey;
    if (messageKey == null) {
      return;
    }
    _triggerThreadLandingHighlight(messageKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final chatThreadContext = _chatThreadKey.currentContext;
      if (chatThreadContext != null) {
        Scrollable.ensureVisible(
          chatThreadContext,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: 0.45,
        );
      }
    });
  }

  void _triggerThreadLandingHighlight(String messageKey) {
    if (mounted) {
      setState(() {
        _threadLandingMessageKey = messageKey;
      });
    }
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) {
        return;
      }
      setState(() {
        if (_threadLandingMessageKey == messageKey) {
          _threadLandingMessageKey = null;
        }
      });
    });
  }

  Color _chatComposerFillColor() {
    return _showComposerLandingHighlight
        ? _clientSelectedPanelColor
        : _clientPanelColor;
  }

  Color _chatComposerBorderColor() {
    return _showComposerLandingHighlight
        ? _clientStrongBorderColor
        : _clientBorderColor;
  }

  Color _chatComposerFocusedBorderColor() {
    return _showComposerLandingHighlight
        ? _clientAccentBlue
        : _clientActionBorderStrong;
  }

  Color _threadLandingBubbleFillColor() {
    return _clientSelectedPanelColor;
  }

  Color _threadLandingBubbleBorderColor() {
    return _clientStrongBorderColor;
  }

  Color _threadLandingBubbleMetaColor() {
    return _clientAccentBlue;
  }

  ButtonStyle _inlineHandoffButtonStyle(
    Color foregroundColor, {
    Color? disabledForegroundColor,
  }) {
    return ButtonStyle(
      padding: WidgetStateProperty.all(
        _phoneLayout
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      minimumSize: WidgetStateProperty.all(Size(0, _phoneLayout ? 40 : 0)),
      tapTargetSize: _phoneLayout
          ? MaterialTapTargetSize.padded
          : MaterialTapTargetSize.shrinkWrap,
      alignment: Alignment.centerLeft,
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return disabledForegroundColor ?? foregroundColor;
        }
        return foregroundColor;
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return _clientActionSurfaceStrong;
        }
        if (states.contains(WidgetState.pressed)) {
          return _clientInfoSurface;
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return _clientActionSurface;
        }
        return _clientActionSurface;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return null;
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return _clientActionSurface;
        }
        if (states.contains(WidgetState.pressed)) {
          return _clientInfoSurface;
        }
        return null;
      }),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: _clientActionBorder),
        ),
      ),
    );
  }

  ButtonStyle _compactOutlinedActionStyle({
    required Color foregroundColor,
    required Color sideColor,
    required Color backgroundColor,
  }) {
    return OutlinedButton.styleFrom(
      foregroundColor: foregroundColor,
      side: BorderSide(color: sideColor),
      backgroundColor: backgroundColor,
      minimumSize: Size(0, _phoneLayout ? 44 : 36),
      padding: _phoneLayout
          ? const EdgeInsets.symmetric(horizontal: 14, vertical: 11)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      tapTargetSize: _phoneLayout
          ? MaterialTapTargetSize.padded
          : MaterialTapTargetSize.shrinkWrap,
      visualDensity: _phoneLayout
          ? VisualDensity.standard
          : VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      shadowColor: _clientShadowColor,
    );
  }

  Future<void> _showIncidentFeedDetail(_ClientIncidentFeedGroup group) {
    logUiAction(
      'client_app.reopen_selected_incident',
      context: {
        'reference_label': group.referenceLabel,
        'role': _viewerRole.name,
      },
    );
    return showDialog<void>(
      context: context,
      builder: (context) {
        final latest = group.latestEntry;
        return AlertDialog(
          backgroundColor: _clientPanelColor,
          title: Text(
            _viewerRole.incidentDetailTitle,
            style: GoogleFonts.inter(
              color: _clientTitleColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailLine(
                _viewerRole.incidentReferenceLabel,
                group.referenceLabel,
              ),
              _detailLine(
                _viewerRole.incidentStatusLabel,
                _viewerRole.incidentStatusDisplayLabel(latest.statusLabel),
              ),
              _detailLine(_viewerRole.incidentOccurredLabel, latest.timeLabel),
              _detailLine(
                _viewerRole.incidentHeadlineLabel,
                _viewerRole.incidentHeadlineDisplay(
                  statusLabel: latest.statusLabel,
                  referenceLabel: latest.referenceLabel,
                  headline: latest.headline,
                  detail: latest.detail,
                ),
              ),
              _detailLine(
                _viewerRole.incidentDetailSummaryLabel,
                _viewerRole.incidentDetailDisplay(
                  statusLabel: latest.statusLabel,
                  referenceLabel: latest.referenceLabel,
                  headline: latest.headline,
                  detail: latest.detail,
                ),
              ),
              _detailLine(
                _viewerRole.incidentEventsLabel,
                _viewerRole.incidentCountLabel(group.entries.length),
              ),
              const SizedBox(height: 4),
              Text(
                _viewerRole.incidentMilestonesLabel,
                style: GoogleFonts.inter(
                  color: _clientMutedColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ...group.entries.map(_incidentMilestoneLine),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                _localizedCloseLabel,
                style: GoogleFonts.inter(
                  color: _clientInfoAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _detailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: GoogleFonts.inter(
                color: _clientMutedColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: GoogleFonts.inter(
                color: _clientTitleColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _incidentMilestoneLine(_ClientIncidentFeedEntry entry) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _clientPanelTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _clientBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _viewerRole.incidentMilestoneLineLabel(
              entry.statusLabel,
              entry.timeLabel,
            ),
            style: GoogleFonts.inter(
              color: _clientMutedColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _viewerRole.incidentHeadlineDisplay(
              statusLabel: entry.statusLabel,
              referenceLabel: entry.referenceLabel,
              headline: entry.headline,
              detail: entry.detail,
            ),
            style: GoogleFonts.inter(
              color: _clientTitleColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentActionStrip(
    _ClientIncidentFeedGroup group,
    bool expanded,
  ) {
    if (_viewerRole == ClientAppViewerRole.client) {
      return Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            expanded
                ? _viewerRole.incidentCollapseHint
                : _viewerRole.incidentExpandHint,
            style: GoogleFonts.inter(
              color: _clientMutedColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextButton(
            onPressed: () => _showIncidentFeedDetail(group),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: _clientInfoAccent,
            ),
            child: Text(
              _viewerRole.incidentFeedActionLabel,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _clientPanelMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _clientBorderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () => _toggleIncidentFeedExpansion(group.referenceLabel),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: _clientMutedColor,
            ),
            child: Text(
              _viewerRole.incidentToggleActionLabel(expanded),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            width: 1,
            height: 14,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            color: _clientBorderColor,
          ),
          TextButton(
            onPressed: () => _showIncidentFeedDetail(group),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: _clientInfoAccent,
            ),
            child: Text(
              _viewerRole.incidentFeedActionLabel,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _incidentFeedEmptyRecovery(List<_ClientIncidentFeedGroup> items) {
    final showAllRoomItems = _showAllRoomItemsFor(_viewerRole);
    final roomKey = _selectedRoomFor(_viewerRole);
    return Container(
      key: const ValueKey('client-incident-feed-empty-recovery'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _clientPanelTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _clientBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INCIDENT WORKSPACE READY',
            style: GoogleFonts.inter(
              color: _clientAccentBlue,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _viewerRole.incidentFeedEmptyLabel,
            style: GoogleFonts.inter(
              color: _clientTitleColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Keep the lane anchored by checking the current scope, opening the first ready thread, or jumping back to the composer.',
            style: GoogleFonts.inter(
              color: _clientBodyColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(
                'Lane ${_roomDisplayNameForKey(roomKey)}',
                _clientInfoAccent,
                _clientInfoBorder,
              ),
              _pill(
                showAllRoomItems
                    ? _localizedShowAllLabel
                    : _localizedShowPendingLabel,
                _clientWarningAccent,
                _clientWarningBorder,
              ),
              _pill(
                'Threads ${items.length}',
                _clientAdminAccent,
                _clientAdminBorder,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _bannerActionChip(
                key: const ValueKey('client-incident-feed-empty-open-first'),
                label: 'Open first incident',
                accent: _clientInfoAccent,
                onTap: () => _openFirstAvailableIncidentThread(items),
              ),
              _bannerActionChip(
                key: const ValueKey(
                  'client-incident-feed-empty-focus-composer',
                ),
                label: 'Jump to Composer',
                accent: _clientAdminAccent,
                onTap: _focusChatComposer,
              ),
              _bannerActionChip(
                key: const ValueKey('client-incident-feed-empty-toggle-scope'),
                label: showAllRoomItems
                    ? _localizedShowPendingLabel
                    : _localizedShowAllLabel,
                accent: _clientWarningAccent,
                selected: showAllRoomItems,
                onTap: _toggleShowAllRoomItems,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _incidentRowBorderColor({
    required bool expanded,
    required bool selected,
    required bool focused,
  }) {
    if (_viewerRole == ClientAppViewerRole.client) {
      return _clientBorderColor;
    }
    if (focused) {
      return _clientInfoAccentStrong;
    }
    if (selected) {
      return _clientInfoBorderSoft;
    }
    if (expanded) {
      return _clientInfoBorder;
    }
    return _clientBorderColor;
  }

  String _threadJumpedLabel() {
    return switch (_viewerRole) {
      ClientAppViewerRole.client => _localizedTemplate(
        key: 'threadJumpedClient',
        fallback: 'Latest reply in view',
      ),
      ClientAppViewerRole.control => _localizedTemplate(
        key: 'threadJumpedControl',
        fallback: 'Latest log entry in view',
      ),
      ClientAppViewerRole.resident => _localizedTemplate(
        key: 'threadJumpedResident',
        fallback: 'Latest resident reply in view',
      ),
    };
  }

  String _viewSentMessageLabel() {
    return switch (_viewerRole) {
      ClientAppViewerRole.client => _localizedTemplate(
        key: 'viewSentMessageClient',
        fallback: 'View in Thread',
      ),
      ClientAppViewerRole.control => _localizedTemplate(
        key: 'viewSentMessageControl',
        fallback: 'View Log Entry',
      ),
      ClientAppViewerRole.resident => _localizedTemplate(
        key: 'viewSentMessageResident',
        fallback: 'View Resident Reply',
      ),
    };
  }

  bool _canSendNotificationActionNow(_ClientSystemMessageType type) {
    return type != _ClientSystemMessageType.dispatch;
  }

  String _draftRequiredHintFor(_ClientSystemMessageType type) {
    final roomLabel = _activeRoomDisplayName();
    return switch ((_viewerRole, type)) {
      (ClientAppViewerRole.client, _ClientSystemMessageType.dispatch) =>
        _localizedTemplate(
          key: 'draftRequiredClientDispatch',
          fallback:
              'Give this dispatch reply a quick client review before it goes to {room}.',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.control, _ClientSystemMessageType.dispatch) =>
        _localizedTemplate(
          key: 'draftRequiredControlDispatch',
          fallback:
              'Give this dispatch reply a quick review before it goes to {room}.',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.resident, _ClientSystemMessageType.dispatch) =>
        _localizedTemplate(
          key: 'draftRequiredResidentDispatch',
          fallback:
              'Give this dispatch update a quick review before it goes to {room}.',
          tokens: {'room': roomLabel},
        ),
      (_, _) => _localizedTemplate(
        key: 'draftRequiredDefault',
        fallback: 'Give this draft a quick review before sending.',
      ),
    };
  }

  String _draftReadyLabelFor(_ClientSystemMessageType type) {
    final roomLabel = _activeRoomDisplayName();
    final baseLabel = switch ((_viewerRole, type)) {
      (ClientAppViewerRole.client, _ClientSystemMessageType.dispatch) =>
        _localizedTemplate(
          key: 'draftReadyClientDispatch',
          fallback: 'Review client draft for {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.control, _ClientSystemMessageType.dispatch) =>
        _localizedTemplate(
          key: 'draftReadyControlDispatch',
          fallback: 'Review dispatch draft for {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.resident, _ClientSystemMessageType.dispatch) =>
        _localizedTemplate(
          key: 'draftReadyResidentDispatch',
          fallback: 'Review update draft for {room}',
          tokens: {'room': roomLabel},
        ),
      (_, _) => _localizedTemplate(
        key: 'draftReadyDefault',
        fallback: 'Draft ready for review',
      ),
    };
    return _withLaneVoiceLabel(baseLabel);
  }

  String _draftOpenedLabelFor(_ClientSystemMessageType type) {
    final roomLabel = _activeRoomDisplayName();
    final baseLabel = switch ((_viewerRole, type)) {
      (ClientAppViewerRole.client, _ClientSystemMessageType.dispatch) =>
        _localizedTemplate(
          key: 'draftOpenedClientDispatch',
          fallback: 'Client review draft is open for {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.control, _ClientSystemMessageType.dispatch) =>
        _localizedTemplate(
          key: 'draftOpenedControlDispatch',
          fallback: 'Dispatch draft is open for {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.resident, _ClientSystemMessageType.dispatch) =>
        _localizedTemplate(
          key: 'draftOpenedResidentDispatch',
          fallback: 'Update draft is open for {room}',
          tokens: {'room': roomLabel},
        ),
      (_, _) => _localizedTemplate(
        key: 'draftOpenedDefault',
        fallback: 'Draft is open',
      ),
    };
    return _withLaneVoiceLabel(baseLabel);
  }

  String _activeRoomDisplayName() {
    return _roomDisplayNameForKey(_selectedRoomFor(_viewerRole));
  }

  String _notificationTargetBadgeLabel() {
    final roomLabel = _activeRoomDisplayName();
    if (_showAllRoomItemsFor(_viewerRole)) {
      return '$_localizedTargetCurrentLanePrefix: $roomLabel';
    }
    return '$_localizedTargetPrefix: $roomLabel';
  }

  String _chatPanelSubtitle({
    required bool showAllRoomItems,
    required String roomDisplayName,
  }) {
    final baseSubtitle = _viewerRole.chatPanelSubtitleForLocale(widget.locale);
    if (showAllRoomItems) {
      return '$baseSubtitle ${_localizedShowingAllThreadMessagesCurrentLane(roomDisplayName)}';
    }
    return '$baseSubtitle ${_localizedShowingPendingThreadMessages(roomDisplayName)}';
  }

  String _notificationsPanelSubtitle({
    required bool showAllRoomItems,
    required String roomDisplayName,
  }) {
    final baseSubtitle = _viewerRole.notificationsPanelSubtitleForLocale(
      widget.locale,
    );
    if (showAllRoomItems) {
      return '$baseSubtitle ${_localizedShowingAllNotificationsCurrentLane(roomDisplayName)}';
    }
    return '$baseSubtitle ${_localizedShowingPendingNotifications(roomDisplayName)}';
  }

  String _roomsPanelSubtitle({
    required bool showAllRoomItems,
    required String roomDisplayName,
  }) {
    final baseSubtitle = _viewerRole.roomsPanelSubtitleForLocale(widget.locale);
    if (showAllRoomItems) {
      return '$baseSubtitle ${_localizedCurrentLaneAllMessageActivity(roomDisplayName)}';
    }
    return '$baseSubtitle ${_localizedCurrentLanePendingActivityFocus(roomDisplayName)}';
  }

  String _notificationSentLabelFor(_ClientSystemMessageType type) {
    final roomLabel = _activeRoomDisplayName();
    return switch ((_viewerRole, type)) {
      (ClientAppViewerRole.client, _ClientSystemMessageType.advisory) =>
        _localizedTemplate(
          key: 'notificationSentClientAdvisory',
          fallback: 'Advisory sent to {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.client, _ClientSystemMessageType.closure) =>
        _localizedTemplate(
          key: 'notificationSentClientClosure',
          fallback: 'Closure sent to {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.client, _) => _localizedTemplate(
        key: 'notificationSentClientDefault',
        fallback: 'Update sent to {room}',
        tokens: {'room': roomLabel},
      ),
      (ClientAppViewerRole.control, _ClientSystemMessageType.advisory) =>
        _localizedTemplate(
          key: 'notificationSentControlAdvisory',
          fallback: 'Advisory log posted to {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.control, _ClientSystemMessageType.closure) =>
        _localizedTemplate(
          key: 'notificationSentControlClosure',
          fallback: 'Closure log posted to {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.control, _) => _localizedTemplate(
        key: 'notificationSentControlDefault',
        fallback: 'Update log posted to {room}',
        tokens: {'room': roomLabel},
      ),
      (ClientAppViewerRole.resident, _ClientSystemMessageType.advisory) =>
        _localizedTemplate(
          key: 'notificationSentResidentAdvisory',
          fallback: 'Community alert posted to {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.resident, _ClientSystemMessageType.closure) =>
        _localizedTemplate(
          key: 'notificationSentResidentClosure',
          fallback: 'Closure reply posted to {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.resident, _) => _localizedTemplate(
        key: 'notificationSentResidentDefault',
        fallback: 'Update request posted to {room}',
        tokens: {'room': roomLabel},
      ),
    };
  }

  String _manualIncidentStatusLabelFor(_ClientSystemMessageType? type) {
    return switch (type) {
      _ClientSystemMessageType.advisory => 'Advisory',
      _ClientSystemMessageType.closure => 'Closed',
      _ClientSystemMessageType.dispatch => 'Opened',
      _ => 'Update',
    };
  }

  void _sendNotificationAction(_ClientNotification item) {
    _sentThreadMessageKey = _sendManualMessageText(
      _notificationActionDraftFor(item),
      systemType: item.systemType,
    );
    _triggerNotificationSentConfirmation(item.messageKey);
  }

  String? _sendManualMessageText(
    String text, {
    _ClientSystemMessageType? systemType,
    bool clearComposer = false,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    late final String messageKey;
    setState(() {
      final message = ClientAppMessage(
        author: _viewerRole.outgoingAuthorLabel,
        body: trimmed,
        occurredAt: DateTime.now().toUtc(),
        roomKey: _selectedRoomFor(_viewerRole),
        viewerRole: _viewerRole.name,
        incidentStatusLabel: _manualIncidentStatusLabelFor(systemType),
      );
      messageKey = _manualMessageKey(message);
      _manualMessages.insert(0, message);
      _composedSystemType = null;
      _reviewedDraftOriginalText = null;
      if (clearComposer) {
        _chatController.clear();
      }
    });
    _emitClientStateChanged();
    return messageKey;
  }

  String _notificationActionLabelFor(_ClientSystemMessageType type) {
    final roomLabel = _activeRoomDisplayName();
    return switch ((_viewerRole, type)) {
      (ClientAppViewerRole.client, _ClientSystemMessageType.dispatch) =>
        _localizedTemplate(
          key: 'notificationActionClientDispatch',
          fallback: 'Request ETA for {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.client, _ClientSystemMessageType.advisory) =>
        _localizedTemplate(
          key: 'notificationActionClientAdvisory',
          fallback: 'Review Advisory for {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.client, _ClientSystemMessageType.closure) =>
        _localizedTemplate(
          key: 'notificationActionClientClosure',
          fallback: 'Review Closure for {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.client, _) => _localizedTemplate(
        key: 'notificationActionClientDefault',
        fallback: 'Review Update for {room}',
        tokens: {'room': roomLabel},
      ),
      (ClientAppViewerRole.control, _ClientSystemMessageType.dispatch) =>
        _localizedTemplate(
          key: 'notificationActionControlDispatch',
          fallback: 'Open Dispatch for {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.control, _ClientSystemMessageType.advisory) =>
        _localizedTemplate(
          key: 'notificationActionControlAdvisory',
          fallback: 'Draft Advisory Log for {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.control, _ClientSystemMessageType.closure) =>
        _localizedTemplate(
          key: 'notificationActionControlClosure',
          fallback: 'Draft Closure Log for {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.control, _) => _localizedTemplate(
        key: 'notificationActionControlDefault',
        fallback: 'Draft Update Log for {room}',
        tokens: {'room': roomLabel},
      ),
      (ClientAppViewerRole.resident, _ClientSystemMessageType.dispatch) =>
        _localizedTemplate(
          key: 'notificationActionResidentDispatch',
          fallback: 'View Alert for {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.resident, _ClientSystemMessageType.advisory) =>
        _localizedTemplate(
          key: 'notificationActionResidentAdvisory',
          fallback: 'Draft Community Alert for {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.resident, _ClientSystemMessageType.closure) =>
        _localizedTemplate(
          key: 'notificationActionResidentClosure',
          fallback: 'Draft Closure Reply for {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.resident, _) => _localizedTemplate(
        key: 'notificationActionResidentDefault',
        fallback: 'Draft Update Request for {room}',
        tokens: {'room': roomLabel},
      ),
    };
  }

  String _notificationSendNowLabelFor(_ClientSystemMessageType type) {
    final roomLabel = _activeRoomDisplayName();
    return switch ((_viewerRole, type)) {
      (ClientAppViewerRole.client, _ClientSystemMessageType.advisory) =>
        _localizedTemplate(
          key: 'notificationSendNowClientAdvisory',
          fallback: 'Send Advisory to {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.client, _ClientSystemMessageType.closure) =>
        _localizedTemplate(
          key: 'notificationSendNowClientClosure',
          fallback: 'Send Closure to {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.client, _) => _localizedTemplate(
        key: 'notificationSendNowClientDefault',
        fallback: 'Send Update to {room}',
        tokens: {'room': roomLabel},
      ),
      (ClientAppViewerRole.control, _ClientSystemMessageType.advisory) =>
        _localizedTemplate(
          key: 'notificationSendNowControlAdvisory',
          fallback: 'Log Advisory Now for {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.control, _ClientSystemMessageType.closure) =>
        _localizedTemplate(
          key: 'notificationSendNowControlClosure',
          fallback: 'Log Closure Now for {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.control, _) => _localizedTemplate(
        key: 'notificationSendNowControlDefault',
        fallback: 'Log Update Now for {room}',
        tokens: {'room': roomLabel},
      ),
      (ClientAppViewerRole.resident, _ClientSystemMessageType.advisory) =>
        _localizedTemplate(
          key: 'notificationSendNowResidentAdvisory',
          fallback: 'Post Advisory to {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.resident, _ClientSystemMessageType.closure) =>
        _localizedTemplate(
          key: 'notificationSendNowResidentClosure',
          fallback: 'Post Closure to {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.resident, _) => _localizedTemplate(
        key: 'notificationSendNowResidentDefault',
        fallback: 'Post Update to {room}',
        tokens: {'room': roomLabel},
      ),
    };
  }

  String _notificationActionDraftFor(_ClientNotification item) {
    final roomLabel = _activeRoomDisplayName();
    return switch ((_viewerRole, item.systemType)) {
      (ClientAppViewerRole.client, _ClientSystemMessageType.dispatch) =>
        _localizedTemplate(
          key: 'notificationDraftClientDispatch',
          fallback: 'Please share the latest ETA for {title} in {room}.',
          tokens: {'title': item.title.toLowerCase(), 'room': roomLabel},
        ),
      (ClientAppViewerRole.client, _ClientSystemMessageType.advisory) =>
        _localizedTemplate(
          key: 'notificationDraftClientAdvisory',
          fallback: 'Advisory reviewed and ready to send to {room}.',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.client, _ClientSystemMessageType.closure) =>
        _localizedTemplate(
          key: 'notificationDraftClientClosure',
          fallback: 'Closure update reviewed and ready to send to {room}.',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.client, _) => _localizedTemplate(
        key: 'notificationDraftClientDefault',
        fallback: 'Update reviewed for {room}. Ready for the next step.',
        tokens: {'room': roomLabel},
      ),
      (ClientAppViewerRole.control, _ClientSystemMessageType.dispatch) =>
        _controlLaneVoiceDraft(
          roomLabel: roomLabel,
          autoText: _localizedTemplate(
            key: 'notificationDraftControlDispatch',
            fallback:
                'Control is checking the dispatch response for {room} now.',
            tokens: {'room': roomLabel},
          ),
          conciseText: 'Checking dispatch response for $roomLabel now.',
          reassuringText:
              'Control is on it for $roomLabel and is checking the dispatch response now.',
          validationHeavyText:
              'Control is checking the dispatch response for $roomLabel now and will share the next verified position update.',
        ),
      (ClientAppViewerRole.control, _ClientSystemMessageType.advisory) =>
        _controlLaneVoiceDraft(
          roomLabel: roomLabel,
          autoText: _localizedTemplate(
            key: 'notificationDraftControlAdvisory',
            fallback: 'Control is shaping the advisory update for {room}.',
            tokens: {'room': roomLabel},
          ),
          conciseText: 'Advisory update being shaped for $roomLabel.',
          reassuringText:
              'Control is shaping a calm advisory update for $roomLabel now.',
          validationHeavyText:
              'Control is shaping the advisory update for $roomLabel with the key verified details.',
        ),
      (ClientAppViewerRole.control, _ClientSystemMessageType.closure) =>
        _controlLaneVoiceDraft(
          roomLabel: roomLabel,
          autoText: _localizedTemplate(
            key: 'notificationDraftControlClosure',
            fallback: 'Control is shaping the closure update for {room}.',
            tokens: {'room': roomLabel},
          ),
          conciseText: 'Closure update being shaped for $roomLabel.',
          reassuringText:
              'Control is shaping a steady closure update for $roomLabel now.',
          validationHeavyText:
              'Control is shaping the closure update for $roomLabel with the confirmed close-out details.',
        ),
      (ClientAppViewerRole.control, _) => _localizedTemplate(
        key: 'notificationDraftControlDefault',
        fallback: _controlLaneVoiceDraft(
          roomLabel: roomLabel,
          autoText:
              'Control is shaping the next operational update for {room}.',
          conciseText: 'Shaping the next operational update for $roomLabel.',
          reassuringText:
              'Control is shaping the next steady operational update for $roomLabel.',
          validationHeavyText:
              'Control is shaping the next operational update for $roomLabel with the verified details first.',
        ),
        tokens: {'room': roomLabel},
      ),
      (ClientAppViewerRole.resident, _ClientSystemMessageType.dispatch) =>
        _localizedTemplate(
          key: 'notificationDraftResidentDispatch',
          fallback:
              'Resident has seen the alert in {room} and is waiting for guidance.',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.resident, _ClientSystemMessageType.advisory) =>
        _localizedTemplate(
          key: 'notificationDraftResidentAdvisory',
          fallback: 'Resident is preparing a community alert for {room}.',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.resident, _ClientSystemMessageType.closure) =>
        _localizedTemplate(
          key: 'notificationDraftResidentClosure',
          fallback: 'Resident is preparing a closure reply for {room}.',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.resident, _) => _localizedTemplate(
        key: 'notificationDraftResidentDefault',
        fallback: 'Resident is preparing an update request for {room}.',
        tokens: {'room': roomLabel},
      ),
    };
  }

  String _controlLaneVoiceDraft({
    required String roomLabel,
    required String autoText,
    required String conciseText,
    required String reassuringText,
    required String validationHeavyText,
  }) {
    return switch (_laneVoiceProfileSignalNormalized) {
      'concise-updates' => conciseText,
      'reassurance-forward' => reassuringText,
      'validation-heavy' => validationHeavyText,
      _ => autoText.replaceAll('{room}', roomLabel),
    };
  }

  List<_ClientNotification> _buildNotifications(List<DispatchEvent> events) {
    final items = <_ClientNotification>[];
    for (final event in events.take(10)) {
      switch (event) {
        case DecisionCreated():
          final notification = _dispatchCreatedNotificationCopy(event);
          final messageKey = _notificationMessageKeyForValues(
            occurredAt: event.occurredAt,
            title: notification.title,
            body: notification.body,
          );
          items.add(
            _ClientNotification(
              messageKey: messageKey,
              title: notification.title,
              body: notification.body,
              occurredAt: event.occurredAt,
              systemType: _ClientSystemMessageType.dispatch,
              priority: true,
              acknowledgements: _acknowledgementsForMessage(messageKey),
            ),
          );
        case ResponseArrived():
          final notification = _responseArrivedNotificationCopy(event);
          final messageKey = _notificationMessageKeyForValues(
            occurredAt: event.occurredAt,
            title: notification.title,
            body: notification.body,
          );
          items.add(
            _ClientNotification(
              messageKey: messageKey,
              title: notification.title,
              body: notification.body,
              occurredAt: event.occurredAt,
              systemType: _ClientSystemMessageType.update,
              acknowledgements: _acknowledgementsForMessage(messageKey),
            ),
          );
        case IncidentClosed():
          final notification = _incidentClosedNotificationCopy(event);
          final messageKey = _notificationMessageKeyForValues(
            occurredAt: event.occurredAt,
            title: notification.title,
            body: notification.body,
          );
          items.add(
            _ClientNotification(
              messageKey: messageKey,
              title: notification.title,
              body: notification.body,
              occurredAt: event.occurredAt,
              systemType: _ClientSystemMessageType.closure,
              acknowledgements: _acknowledgementsForMessage(messageKey),
            ),
          );
        case IntelligenceReceived():
          final messageKey = _notificationMessageKeyForValues(
            occurredAt: event.occurredAt,
            title: event.headline,
            body: event.summary,
          );
          items.add(
            _ClientNotification(
              messageKey: messageKey,
              title: event.headline,
              body: event.summary,
              occurredAt: event.occurredAt,
              systemType: _ClientSystemMessageType.advisory,
              priority: event.riskScore >= 70,
              acknowledgements: _acknowledgementsForMessage(messageKey),
            ),
          );
        default:
          break;
      }
    }
    return items;
  }

  List<ClientAppPushDeliveryItem> _buildPushQueue(
    List<_ClientNotification> notifications,
  ) {
    final items =
        notifications
            .map((notification) {
              final targetChannel = _pushTargetChannelForNotification(
                notification,
              );
              final delivered = notification.hasAcknowledgementFor(
                targetChannel,
              );
              return ClientAppPushDeliveryItem(
                messageKey: notification.messageKey,
                title: notification.title,
                body: notification.body,
                occurredAt: notification.occurredAt,
                targetChannel: targetChannel,
                deliveryProvider: widget.pushDeliveryProvider,
                priority: notification.priority,
                status: delivered
                    ? ClientPushDeliveryStatus.acknowledged
                    : ClientPushDeliveryStatus.queued,
              );
            })
            .toList(growable: false)
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return items;
  }

  List<ClientAppPushDeliveryItem> _mergeStoredPushQueueWithAcknowledgements(
    List<ClientAppPushDeliveryItem> storedQueue,
  ) {
    final merged =
        storedQueue
            .map((item) {
              final acknowledged =
                  _findAcknowledgement(item.messageKey, item.targetChannel) !=
                  null;
              return ClientAppPushDeliveryItem(
                messageKey: item.messageKey,
                title: item.title,
                body: item.body,
                occurredAt: item.occurredAt,
                targetChannel: item.targetChannel,
                deliveryProvider: item.deliveryProvider,
                priority: item.priority,
                status: acknowledged
                    ? ClientPushDeliveryStatus.acknowledged
                    : item.status,
              );
            })
            .toList(growable: false)
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return merged;
  }

  List<ClientAppPushDeliveryItem> _mergeComputedAndStoredPushQueue(
    List<ClientAppPushDeliveryItem> computedQueue,
    List<ClientAppPushDeliveryItem> storedQueue,
  ) {
    if (computedQueue.isEmpty) {
      return storedQueue;
    }
    if (storedQueue.isEmpty) {
      return computedQueue;
    }
    final byMessageKey = <String, ClientAppPushDeliveryItem>{
      for (final item in storedQueue) item.messageKey: item,
      for (final item in computedQueue) item.messageKey: item,
    };
    final merged = byMessageKey.values.toList(growable: false)
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return merged;
  }

  ClientAppAcknowledgementChannel _pushTargetChannelForNotification(
    _ClientNotification notification,
  ) {
    return switch (notification.systemType) {
      _ClientSystemMessageType.dispatch =>
        ClientAppAcknowledgementChannel.client,
      _ClientSystemMessageType.advisory =>
        ClientAppAcknowledgementChannel.resident,
      _ClientSystemMessageType.closure =>
        ClientAppAcknowledgementChannel.client,
      _ClientSystemMessageType.update =>
        ClientAppAcknowledgementChannel.control,
    };
  }

  List<_ClientIncidentFeedGroup> _buildIncidentFeed(
    List<DispatchEvent> events,
  ) {
    final items = <_ClientIncidentFeedEntry>[];
    for (final event in events.take(8)) {
      switch (event) {
        case DecisionCreated():
          final notification = _dispatchCreatedNotificationCopy(event);
          items.add(
            _ClientIncidentFeedEntry(
              referenceLabel: event.dispatchId,
              headline: notification.title,
              detail: notification.body,
              occurredAt: event.occurredAt,
              statusLabel: 'Opened',
              accent: _clientInfoAccent,
              borderColor: _clientInfoBorder,
            ),
          );
        case ResponseArrived():
          final notification = _responseArrivedNotificationCopy(event);
          items.add(
            _ClientIncidentFeedEntry(
              referenceLabel: event.dispatchId,
              headline: notification.title,
              detail: notification.body,
              occurredAt: event.occurredAt,
              statusLabel: 'On Site',
              accent: _clientSuccessAccent,
              borderColor: _clientSuccessBorder,
            ),
          );
        case IncidentClosed():
          final notification = _incidentClosedNotificationCopy(event);
          items.add(
            _ClientIncidentFeedEntry(
              referenceLabel: event.dispatchId,
              headline: notification.title,
              detail: notification.body,
              occurredAt: event.occurredAt,
              statusLabel: 'Closed',
              accent: _clientWarningAccent,
              borderColor: _clientWarningBorder,
            ),
          );
        case IntelligenceReceived():
          items.add(
            _ClientIncidentFeedEntry(
              referenceLabel: event.intelligenceId,
              headline: event.headline,
              detail: event.summary,
              occurredAt: event.occurredAt,
              statusLabel: event.riskScore >= 70 ? 'Advisory' : 'Intel',
              accent: event.riskScore >= 70
                  ? _clientPriorityAccent
                  : _clientAdminAccent,
              borderColor: event.riskScore >= 70
                  ? _clientPriorityBorder
                  : _clientAdminBorder,
            ),
          );
        default:
          break;
      }
    }
    items.addAll(_buildManualIncidentFeedEntries());
    final grouped = <String, List<_ClientIncidentFeedEntry>>{};
    for (final item in items) {
      grouped
          .putIfAbsent(item.referenceLabel, () => <_ClientIncidentFeedEntry>[])
          .add(item);
    }
    final groups =
        grouped.entries
            .map(
              (entry) => _ClientIncidentFeedGroup(
                referenceLabel: entry.key,
                entries: (List<_ClientIncidentFeedEntry>.from(entry.value)
                  ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt))),
              ),
            )
            .toList(growable: false)
          ..sort(
            (a, b) =>
                b.latestEntry.occurredAt.compareTo(a.latestEntry.occurredAt),
          );
    return groups;
  }

  ({String title, String body}) _dispatchCreatedNotificationCopy(
    DecisionCreated event,
  ) {
    final siteLabel = _clientSiteLabel(event.siteId);
    return (
      title: 'Security response activated',
      body: 'A response team is moving to $siteLabel now.',
    );
  }

  ({String title, String body}) _responseArrivedNotificationCopy(
    ResponseArrived event,
  ) {
    final siteLabel = _clientSiteLabel(event.siteId);
    return (
      title: 'Responder on site',
      body: 'Our officer has arrived at $siteLabel and is assessing now.',
    );
  }

  ({String title, String body}) _incidentClosedNotificationCopy(
    IncidentClosed event,
  ) {
    final siteLabel = _clientSiteLabel(event.siteId);
    final resolution = _clientResolutionLabel(event.resolutionType);
    return (
      title: 'Incident resolved',
      body: 'The incident at $siteLabel has been resolved as $resolution.',
    );
  }

  String _clientSiteLabel(String raw) {
    final cleaned = raw
        .trim()
        .replaceFirst(RegExp(r'^(CLIENT|SITE|REGION)-'), '')
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) {
      return 'your site';
    }
    return cleaned
        .split(' ')
        .where((token) => token.trim().isNotEmpty)
        .map((token) {
          final lower = token.toLowerCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }

  String _clientResolutionLabel(String raw) {
    final cleaned = raw
        .trim()
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
    return cleaned.isEmpty ? 'resolved' : cleaned;
  }

  List<_ClientIncidentFeedEntry> _buildManualIncidentFeedEntries() {
    return _manualMessages
        .where((message) => message.viewerRole == _viewerRole.name)
        .map(_manualIncidentFeedEntryFor)
        .toList(growable: false);
  }

  _ClientIncidentFeedEntry _manualIncidentFeedEntryFor(
    ClientAppMessage message,
  ) {
    final statusLabel = message.incidentStatusLabel;
    return _ClientIncidentFeedEntry(
      referenceLabel: _roomDisplayNameForKey(message.roomKey),
      headline: _manualIncidentHeadlineFor(message.author, statusLabel),
      detail: message.body,
      occurredAt: message.occurredAt,
      statusLabel: statusLabel,
      accent: _manualIncidentAccentFor(statusLabel, message.author),
      borderColor: _manualIncidentBorderColorFor(statusLabel, message.author),
    );
  }

  String _manualIncidentHeadlineFor(String author, String statusLabel) {
    return switch (statusLabel) {
      'Advisory' => '$author advisory',
      'Closed' => '$author closure',
      'Opened' => '$author dispatch review',
      _ => '$author update',
    };
  }

  Color _manualIncidentAccentFor(String statusLabel, String author) {
    return switch (statusLabel) {
      'Advisory' => _clientPriorityAccent,
      'Closed' => _clientWarningAccent,
      'Opened' => _clientInfoAccent,
      _ => switch (author) {
        'Control' => _clientSuccessAccent,
        'Resident' => _clientWarningAccent,
        _ => _clientInfoAccent,
      },
    };
  }

  Color _manualIncidentBorderColorFor(String statusLabel, String author) {
    return switch (statusLabel) {
      'Advisory' => _clientPriorityBorder,
      'Closed' => _clientWarningBorder,
      'Opened' => _clientInfoBorder,
      _ => switch (author) {
        'Control' => _clientSuccessBorder,
        'Resident' => _clientWarningBorder,
        _ => _clientInfoBorder,
      },
    };
  }

  List<_ClientRoom> _buildRooms(List<_ClientNotification> notifications) {
    final residentPending = _pendingAcknowledgementsFor(
      notifications,
      ClientAppAcknowledgementChannel.resident,
    );
    final clientPending = _pendingAcknowledgementsFor(
      notifications,
      ClientAppAcknowledgementChannel.client,
    );
    final controlPending = _pendingAcknowledgementsFor(
      notifications,
      ClientAppAcknowledgementChannel.control,
    );
    return [
      _ClientRoom(
        key: 'Residents',
        displayName: _viewerRole.roomLabelFor(
          ClientAppAcknowledgementChannel.resident,
        ),
        acknowledgementChannel: ClientAppAcknowledgementChannel.resident,
        unread: residentPending,
        summary:
            'Resident-read notices and community updates awaiting receipt.',
      ),
      _ClientRoom(
        key: 'Trustees',
        displayName: _viewerRole.roomLabelFor(
          ClientAppAcknowledgementChannel.client,
        ),
        acknowledgementChannel: ClientAppAcknowledgementChannel.client,
        unread: clientPending,
        summary:
            'Client-side acknowledgements pending on escalations and updates.',
      ),
      _ClientRoom(
        key: 'Security Desk',
        displayName: _viewerRole.roomLabelFor(
          ClientAppAcknowledgementChannel.control,
        ),
        acknowledgementChannel: ClientAppAcknowledgementChannel.control,
        unread: controlPending,
        summary:
            'Control acknowledgements pending on dispatch and site actions.',
      ),
    ];
  }

  Color _roomChannelAccent(ClientAppAcknowledgementChannel channel) {
    return switch (channel) {
      ClientAppAcknowledgementChannel.client => _clientAdminAccent,
      ClientAppAcknowledgementChannel.control => _clientInfoAccent,
      ClientAppAcknowledgementChannel.resident => _clientWarningAccent,
    };
  }

  List<_ClientChatMessage> _buildChatMessages(
    List<_ClientNotification> notifications,
  ) {
    final systemMessages = notifications
        .take(4)
        .map(
          (item) => _ClientChatMessage(
            messageKey: item.messageKey,
            author: 'ONYX',
            body: '${item.title}: ${item.body}',
            occurredAt: item.occurredAt,
            systemType: item.systemType,
            acknowledgements: item.acknowledgements,
            messageSource: 'system',
            messageProvider: 'eventstore',
          ),
        )
        .toList(growable: false);
    final selectedRoom = _selectedRoomFor(_viewerRole);
    final showAllRoomItems = _showAllRoomItemsFor(_viewerRole);
    final manualMessages = _manualMessages
        .where(
          (message) =>
              message.viewerRole == _viewerRole.name &&
              (showAllRoomItems || message.roomKey == selectedRoom),
        )
        .map(
          (message) => _ClientChatMessage(
            messageKey: _manualMessageKey(message),
            author: message.author,
            body: message.body,
            occurredAt: message.occurredAt,
            roomKey: message.roomKey,
            systemType: null,
            acknowledgements: const [],
            messageSource: message.messageSource,
            messageProvider: message.messageProvider,
          ),
        )
        .toList(growable: false);
    final messages = [...manualMessages, ...systemMessages]
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return messages;
  }

  String _chatMessageMetaLabel(_ClientChatMessage message) {
    if (!message.outgoing ||
        message.roomKey == null ||
        message.roomKey!.isEmpty) {
      return '${message.author} • ${message.timeLabel}';
    }
    return '${message.author} • ${_roomDisplayNameForKey(message.roomKey!)} • ${message.timeLabel}';
  }

  String _chatSourceFilterFor(ClientAppViewerRole role) {
    return _chatSourceFilterByRole[role.name] ?? 'all';
  }

  String _chatProviderFilterFor(ClientAppViewerRole role) {
    return _chatProviderFilterByRole[role.name] ?? 'all';
  }

  String _messageSourceLabel(String source) {
    return switch (source.trim().toLowerCase()) {
      'all' => 'All Sources',
      'in_app' => 'In-App',
      'telegram' => 'Telegram',
      'system' => 'System',
      _ => source.trim().isEmpty ? 'Unknown Source' : source.trim(),
    };
  }

  String _messageProviderLabel(String provider) {
    final normalized = provider.trim().toLowerCase();
    return switch (normalized) {
      'all' => 'All Providers',
      'in_app' => 'In-App',
      'telegram' => 'Telegram Bot',
      'eventstore' => 'EventStore',
      'openai' => 'OpenAI',
      _ => normalized.isEmpty ? 'Unknown Provider' : provider.trim(),
    };
  }

  void _setChatSourceFilter(String source) {
    if (_chatSourceFilterFor(_viewerRole) == source) {
      return;
    }
    setState(() {
      _chatSourceFilterByRole[_viewerRole.name] = source;
    });
  }

  void _setChatProviderFilter(String provider) {
    if (_chatProviderFilterFor(_viewerRole) == provider) {
      return;
    }
    setState(() {
      _chatProviderFilterByRole[_viewerRole.name] = provider;
    });
  }

  void _resetChatFilters() {
    if (_chatSourceFilterFor(_viewerRole) == 'all' &&
        _chatProviderFilterFor(_viewerRole) == 'all') {
      return;
    }
    setState(() {
      _chatSourceFilterByRole[_viewerRole.name] = 'all';
      _chatProviderFilterByRole[_viewerRole.name] = 'all';
    });
  }

  String _roomDisplayNameForKey(String roomKey) {
    return _viewerRole.roomLabelForKey(roomKey);
  }

  void _setSelectedRoom(String roomName) {
    if (_selectedRoomFor(_viewerRole) == roomName) {
      return;
    }
    setState(() {
      _selectedRoomByRole[_viewerRole.name] = roomName;
      _showAllRoomItemsByRole[_viewerRole.name] = false;
      _selectedNotificationMessageKey = null;
    });
    _emitClientStateChanged();
  }

  void _toggleShowAllRoomItems() {
    setState(() {
      _showAllRoomItemsByRole[_viewerRole.name] = !_showAllRoomItemsFor(
        _viewerRole,
      );
    });
    _emitClientStateChanged();
  }

  Future<void> _reopenSelectedIncidentThread(
    List<_ClientIncidentFeedGroup> items,
  ) {
    final group = _selectedIncidentGroup(items);
    if (group == null) {
      logUiAction('client_app.reopen_selected_incident_missing');
      return Future<void>.value();
    }
    logUiAction(
      'client_app.reopen_selected_incident',
      context: {
        'reference_label': group.referenceLabel,
        'role': _viewerRole.name,
      },
    );
    setState(() {
      _selectedIncidentReference = group.referenceLabel;
      _selectedIncidentReferenceByRole[_viewerRole.name] = group.referenceLabel;
      _hasTouchedIncidentExpansionByRole[_viewerRole.name] = true;
      _expandedIncidentReferenceByRole[_viewerRole.name] = group.referenceLabel;
    });
    _emitClientStateChanged();
    _showClientCommandFeedback(
      'Reopened ${group.referenceLabel} incident thread.',
      label: 'THREAD REOPEN',
      detail:
          'The selected incident remains pinned across the comms and delivery rails while the detail dialog opens.',
      accent: _clientInfoAccent,
    );
    return _showIncidentFeedDetail(group);
  }

  Future<void> _openFirstAvailableIncidentThread(
    List<_ClientIncidentFeedGroup> items,
  ) {
    if (items.isEmpty) {
      logUiAction(
        'client_app.open_first_incident_missing',
        context: {'role': _viewerRole.name},
      );
      _showClientCommandFeedback(
        'No incident thread is ready for this lane yet.',
        label: 'INCIDENT HANDOFF',
        detail:
            'Open-thread controls stay live so operators can confirm when the current lane does not have a scoped incident available.',
        accent: _clientAdminAccent,
      );
      return Future<void>.value();
    }
    final first = items.first;
    logUiAction(
      'client_app.open_first_incident',
      context: {
        'reference_label': first.referenceLabel,
        'role': _viewerRole.name,
      },
    );
    setState(() {
      _selectedIncidentReference = first.referenceLabel;
      _selectedIncidentReferenceByRole[_viewerRole.name] = first.referenceLabel;
      _hasTouchedIncidentExpansionByRole[_viewerRole.name] = true;
      _expandedIncidentReferenceByRole[_viewerRole.name] = first.referenceLabel;
      _focusedIncidentReference = first.referenceLabel;
      _focusedIncidentReferenceByRole[_viewerRole.name] = first.referenceLabel;
    });
    _emitClientStateChanged();
    _showClientCommandFeedback(
      'Opening ${first.referenceLabel} incident thread.',
      label: 'INCIDENT HANDOFF',
      detail:
          'The first scoped incident is now pinned for both the comms shell and the delivery workspace.',
      accent: _clientInfoAccent,
    );
    return _showIncidentFeedDetail(first);
  }

  void _toggleIncidentFeedExpansion(String referenceLabel) {
    setState(() {
      _hasTouchedIncidentExpansionByRole[_viewerRole.name] = true;
      _selectedIncidentReference = referenceLabel;
      _selectedIncidentReferenceByRole[_viewerRole.name] = referenceLabel;
      final currentReference = _expandedIncidentReferenceFor(_viewerRole);
      if (currentReference == referenceLabel) {
        _expandedIncidentReferenceByRole.remove(_viewerRole.name);
      } else {
        _expandedIncidentReferenceByRole[_viewerRole.name] = referenceLabel;
      }
    });
    _emitClientStateChanged();
  }

  void _setViewerRole(ClientAppViewerRole role) {
    if (_viewerRole == role) {
      return;
    }
    setState(() {
      _viewerRole = role;
      _selectedRoomByRole.putIfAbsent(role.name, () => 'Residents');
      _showAllRoomItemsByRole.putIfAbsent(role.name, () => false);
      _hasTouchedIncidentExpansionByRole.putIfAbsent(role.name, () => false);
      _chatSourceFilterByRole.putIfAbsent(role.name, () => 'all');
      _chatProviderFilterByRole.putIfAbsent(role.name, () => 'all');
      _restoreSelectedIncidentForRole(role);
      _restoreFocusedIncidentForRole(role);
    });
    _emitClientStateChanged();
  }

  String get _localizedConversationSyncLive {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'conversationSyncLive',
      fallback: 'Conversation Sync: Supabase + local fallback',
    );
  }

  String get _localizedConversationSyncLocal {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'conversationSyncLocal',
      fallback: 'Conversation Sync: Local cache only',
    );
  }

  String get _localizedRunWithLocalDefines {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'runWithLocalDefines',
      fallback: 'Run with local defines: ./scripts/run_onyx_chrome_local.sh',
    );
  }

  String get _localizedLanguageLabel {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'languageLabel',
      fallback: 'Language: English',
    );
  }

  String _localizedTemplate({
    required String key,
    required String fallback,
    Map<String, String> tokens = const {},
  }) {
    var text = ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: key,
      fallback: fallback,
    );
    for (final entry in tokens.entries) {
      text = text.replaceAll('{${entry.key}}', entry.value);
    }
    return text;
  }

  String get _localizedCloseLabel {
    return _localizedTemplate(key: 'closeLabel', fallback: 'Close');
  }

  String get _localizedActiveIncidentsLabel {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'activeIncidents',
      fallback: 'Active Incidents',
    );
  }

  String get _localizedEstateRoomsLabel {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'estateRooms',
      fallback: 'Estate Rooms',
    );
  }

  String get _localizedPushQueueReadyLabel {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'pushQueueReady',
      fallback: 'Push Queue Ready',
    );
  }

  String get _localizedPushDeliveryQueueTitle {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'pushDeliveryQueueTitle',
      fallback: 'Push Delivery Queue',
    );
  }

  String get _localizedPushDeliveryQueueSubtitle {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'pushDeliveryQueueSubtitle',
      fallback:
          'Push-ready incident alerts prepared for mobile delivery with acknowledgement tracking.',
    );
  }

  String get _localizedShowPendingLabel {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'showPending',
      fallback: 'Show pending',
    );
  }

  String get _localizedShowAllLabel {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'showAll',
      fallback: 'Show all',
    );
  }

  String get _localizedTargetPrefix {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'targetPrefix',
      fallback: 'Target',
    );
  }

  String get _localizedTargetCurrentLanePrefix {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'targetCurrentLanePrefix',
      fallback: 'Target (current lane)',
    );
  }

  String get _localizedBridgeInAppLabel {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'bridgeInApp',
      fallback: 'In-app',
    );
  }

  String get _localizedBridgeTelegramLabel {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'bridgeTelegram',
      fallback: 'Telegram',
    );
  }

  String _localizedDeliveryProviderLabel(ClientPushDeliveryProvider provider) {
    return switch (provider) {
      ClientPushDeliveryProvider.inApp => _localizedBridgeInAppLabel,
      ClientPushDeliveryProvider.telegram => _localizedBridgeTelegramLabel,
    };
  }

  String _localizedFilterScopeAllNotifications(String roomDisplayName) {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'filterScopeAllNotifications',
      fallback: 'Showing all notifications • current lane: {room}',
    ).replaceAll('{room}', roomDisplayName);
  }

  String _localizedFilterScopePending(String roomDisplayName) {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'filterScopePending',
      fallback: 'Showing pending: {room}',
    ).replaceAll('{room}', roomDisplayName);
  }

  String _localizedShowingAllThreadMessagesCurrentLane(String roomDisplayName) {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'showingAllThreadMessagesCurrentLane',
      fallback: 'Showing all thread messages • current lane: {room}',
    ).replaceAll('{room}', roomDisplayName);
  }

  String _localizedShowingPendingThreadMessages(String roomDisplayName) {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'showingPendingThreadMessages',
      fallback: 'Showing pending thread messages for {room}.',
    ).replaceAll('{room}', roomDisplayName);
  }

  String _localizedShowingAllNotificationsCurrentLane(String roomDisplayName) {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'showingAllNotificationsCurrentLane',
      fallback: 'Showing all notifications • current lane: {room}',
    ).replaceAll('{room}', roomDisplayName);
  }

  String _localizedShowingPendingNotifications(String roomDisplayName) {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'showingPendingNotifications',
      fallback: 'Showing pending notifications for {room}.',
    ).replaceAll('{room}', roomDisplayName);
  }

  String _localizedCurrentLaneAllMessageActivity(String roomDisplayName) {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'currentLaneAllMessageActivity',
      fallback: 'Current lane: {room} • all message activity visible.',
    ).replaceAll('{room}', roomDisplayName);
  }

  String _localizedCurrentLanePendingActivityFocus(String roomDisplayName) {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'currentLanePendingActivityFocus',
      fallback: 'Current lane: {room} • lane-pending activity in focus.',
    ).replaceAll('{room}', roomDisplayName);
  }

  String get _localizedQueuedStatus {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'queuedStatus',
      fallback: 'Queued',
    );
  }

  String get _localizedDeliveredStatus {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'deliveredStatus',
      fallback: 'Delivered',
    );
  }

  String _localizedPushSyncStatusLine(String status) {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'pushSyncStatusLine',
      fallback: 'Push Sync: {status}',
    ).replaceAll('{status}', status);
  }

  String _humanizedPushSyncStatusLabel(String status) {
    final normalized = status.trim().toLowerCase();
    return switch (normalized) {
      '' => 'standing by',
      'idle' || 'push sync idle' => 'standing by',
      'syncing' => 'sync in flight',
      'failed' => 'needs review',
      'degraded' => 'delivery under watch',
      'ok' || 'synced' || 'ready' => 'synced',
      _ => status,
    };
  }

  String _localizedTelegramStatusLine(String status) {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'telegramStatusLine',
      fallback: 'Telegram: {status}',
    ).replaceAll('{status}', status);
  }

  String get _localizedTelegramFallbackActive {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'telegramFallbackActive',
      fallback: 'Telegram fallback is active.',
    );
  }

  String _localizedLastSyncRetriesLine(String lastSync, int retries) {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'lastSyncRetriesLine',
      fallback: 'Last Sync: {lastSync} • Retries: {retries}',
    ).replaceAll('{lastSync}', lastSync).replaceAll('{retries}', '$retries');
  }

  String _localizedBackendProbeStatusLine(String status, String lastRun) {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'backendProbeStatusLine',
      fallback: 'Backend Probe: {status} • Last Run: {lastRun}',
    ).replaceAll('{status}', status).replaceAll('{lastRun}', lastRun);
  }

  String _localizedFailureLine(String reason) {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'failureLine',
      fallback: 'Failure: {reason}',
    ).replaceAll('{reason}', reason);
  }

  String _localizedProbeFailureLine(String reason) {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'probeFailureLine',
      fallback: 'Probe Failure: {reason}',
    ).replaceAll('{reason}', reason);
  }

  String get _localizedRetryPushSyncLabel {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'retryPushSync',
      fallback: 'Retry Push Sync',
    );
  }

  String get _localizedRunBackendProbeLabel {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'runBackendProbe',
      fallback: 'Run Backend Probe',
    );
  }

  String get _localizedClearProbeHistoryButton {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'clearProbeHistoryButton',
      fallback: 'Clear Probe History',
    );
  }

  String get _localizedClearProbeHistoryTitle {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'clearProbeHistoryTitle',
      fallback: 'Clear Probe History?',
    );
  }

  String get _localizedClearProbeHistoryBody {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'clearProbeHistoryBody',
      fallback:
          'This removes recorded backend probe attempts from this client surface.',
    );
  }

  String get _localizedCancelLabel {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'cancelLabel',
      fallback: 'Cancel',
    );
  }

  String get _localizedClearLabel {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'clearLabel',
      fallback: 'Clear',
    );
  }

  String get _localizedPushSyncHistoryEmpty {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'pushSyncHistoryEmpty',
      fallback: 'Push Sync History: no attempts yet.',
    );
  }

  String get _localizedPushSyncHistoryTitle {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'pushSyncHistoryTitle',
      fallback: 'Push Sync History',
    );
  }

  String get _localizedBackendProbeHistoryEmpty {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'backendProbeHistoryEmpty',
      fallback: 'Backend Probe History: no runs yet.',
    );
  }

  String get _localizedBackendProbeHistoryTitle {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'backendProbeHistoryTitle',
      fallback: 'Backend Probe History',
    );
  }

  String _localizedSurfaceTitle(ClientAppViewerRole role) {
    return role.surfaceTitleForLocale(widget.locale);
  }

  String _localizedSurfaceSubtitle(ClientAppViewerRole role) {
    return role.surfaceSubtitleForLocale(widget.locale);
  }

  void _emitClientStateChanged() {
    final acknowledgements = List<ClientAppAcknowledgement>.from(
      _acknowledgements,
    )..sort((a, b) => b.acknowledgedAt.compareTo(a.acknowledgedAt));
    widget.onClientStateChanged?.call(
      _viewerRole,
      Map<String, String>.from(_selectedRoomByRole),
      Map<String, bool>.from(_showAllRoomItemsByRole),
      Map<String, String>.from(_selectedIncidentReferenceByRole),
      Map<String, String>.from(_expandedIncidentReferenceByRole),
      Map<String, bool>.from(_hasTouchedIncidentExpansionByRole),
      Map<String, String>.from(_focusedIncidentReferenceByRole),
      List<ClientAppMessage>.from(_manualMessages),
      acknowledgements,
    );
    final notifications = _buildNotifications(_currentClientEvents());
    final pushQueue = _mergeComputedAndStoredPushQueue(
      _buildPushQueue(notifications),
      _mergeStoredPushQueueWithAcknowledgements(widget.initialPushQueue),
    );
    widget.onPushQueueChanged?.call(pushQueue);
  }

  List<DispatchEvent> _currentClientEvents() {
    final normalizedClientId = widget.clientId.trim();
    final normalizedSiteId = widget.siteId.trim();
    final clientEvents = widget.events.where((event) {
      return switch (event) {
        DecisionCreated e =>
          e.clientId.trim() == normalizedClientId &&
              e.siteId.trim() == normalizedSiteId,
        ResponseArrived e =>
          e.clientId.trim() == normalizedClientId &&
              e.siteId.trim() == normalizedSiteId,
        IncidentClosed e =>
          e.clientId.trim() == normalizedClientId &&
              e.siteId.trim() == normalizedSiteId,
        IntelligenceReceived e =>
          e.clientId.trim() == normalizedClientId &&
              e.siteId.trim() == normalizedSiteId,
        _ => false,
      };
    }).toList()..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return clientEvents;
  }

  String _selectedRoomFor(ClientAppViewerRole role) {
    return _selectedRoomByRole[role.name] ?? 'Residents';
  }

  bool _showAllRoomItemsFor(ClientAppViewerRole role) {
    return _showAllRoomItemsByRole[role.name] == true;
  }

  _ClientIncidentFeedGroup? _selectedIncidentGroup(
    List<_ClientIncidentFeedGroup> items,
  ) {
    if (items.isEmpty) {
      return null;
    }
    final explicitReference =
        _selectedIncidentReferenceByRole[_viewerRole.name];
    final effectiveReference =
        (explicitReference != null && explicitReference.isNotEmpty)
        ? explicitReference
        : _expandedIncidentReferenceFor(_viewerRole) ??
              (_hasTouchedIncidentExpansionFor(_viewerRole)
                  ? null
                  : items.first.referenceLabel);
    if (effectiveReference == null || effectiveReference.isEmpty) {
      return null;
    }
    for (final group in items) {
      if (group.referenceLabel == effectiveReference) {
        return group;
      }
    }
    return null;
  }

  void _restoreSelectedIncidentForRole(ClientAppViewerRole role) {
    final selectedReference = _selectedIncidentReferenceByRole[role.name];
    if (selectedReference != null && selectedReference.isNotEmpty) {
      _selectedIncidentReference = selectedReference;
      return;
    }
    _selectedIncidentReference = null;
  }

  void _restoreFocusedIncidentForRole(ClientAppViewerRole role) {
    final focusedReference = _focusedIncidentReferenceByRole[role.name];
    if (focusedReference != null && focusedReference.isNotEmpty) {
      _focusedIncidentReference = focusedReference;
      return;
    }
    final expandedReference = _expandedIncidentReferenceFor(role);
    if (expandedReference != null && expandedReference.isNotEmpty) {
      _focusedIncidentReference = expandedReference;
      _focusedIncidentReferenceByRole[role.name] = expandedReference;
      return;
    }
    _focusedIncidentReference = null;
  }

  String? _expandedIncidentReferenceFor(ClientAppViewerRole role) {
    return _expandedIncidentReferenceByRole[role.name];
  }

  bool _hasTouchedIncidentExpansionFor(ClientAppViewerRole role) {
    return _hasTouchedIncidentExpansionByRole[role.name] == true;
  }

  String _activeRoomLabel() {
    return switch (_selectedRoomFor(_viewerRole)) {
      'Trustees' => _viewerRole.roomLabelFor(
        ClientAppAcknowledgementChannel.client,
      ),
      'Security Desk' => _viewerRole.roomLabelFor(
        ClientAppAcknowledgementChannel.control,
      ),
      _ => _viewerRole.roomLabelFor(ClientAppAcknowledgementChannel.resident),
    };
  }

  void _acknowledgeMessage(
    String messageKey,
    ClientAppAcknowledgementChannel channel,
  ) {
    if (_findAcknowledgement(messageKey, channel) != null) {
      return;
    }
    setState(() {
      _acknowledgements.insert(
        0,
        ClientAppAcknowledgement(
          messageKey: messageKey,
          channel: channel,
          acknowledgedBy: channel.defaultActor,
          acknowledgedAt: DateTime.now().toUtc(),
        ),
      );
    });
    _emitClientStateChanged();
  }

  List<ClientAppAcknowledgement> _acknowledgementsForMessage(
    String messageKey,
  ) {
    return _acknowledgements
        .where((acknowledgement) => acknowledgement.messageKey == messageKey)
        .toList(growable: false);
  }

  int _pendingAcknowledgementsFor(
    List<_ClientNotification> notifications,
    ClientAppAcknowledgementChannel channel,
  ) {
    return notifications
        .where((notification) => !notification.hasAcknowledgementFor(channel))
        .length;
  }

  ClientAppAcknowledgement? _findAcknowledgement(
    String messageKey,
    ClientAppAcknowledgementChannel channel,
  ) {
    for (final acknowledgement in _acknowledgements) {
      if (acknowledgement.messageKey == messageKey &&
          acknowledgement.channel == channel) {
        return acknowledgement;
      }
    }
    return null;
  }

  String _notificationMessageKeyForValues({
    required DateTime occurredAt,
    required String title,
    required String body,
  }) {
    return 'system:'
        '${occurredAt.toUtc().millisecondsSinceEpoch}:'
        '$title:'
        '$body';
  }

  String _manualMessageKey(ClientAppMessage message) {
    return 'client:'
        '${message.occurredAt.toUtc().millisecondsSinceEpoch}:'
        '${message.author}:'
        '${message.viewerRole}:'
        '${message.roomKey}:'
        '${message.body}';
  }

  int _activeDispatchCount(List<DispatchEvent> events) {
    final opened = <String>{};
    final closed = <String>{};
    for (final event in events) {
      switch (event) {
        case DecisionCreated():
          opened.add(event.dispatchId);
        case IncidentClosed():
          closed.add(event.dispatchId);
        default:
          break;
      }
    }
    return opened.difference(closed).length;
  }
}

class _ClientNotification {
  final String messageKey;
  final String title;
  final String body;
  final DateTime occurredAt;
  final _ClientSystemMessageType systemType;
  final bool priority;
  final List<ClientAppAcknowledgement> acknowledgements;

  const _ClientNotification({
    required this.messageKey,
    required this.title,
    required this.body,
    required this.occurredAt,
    required this.systemType,
    this.priority = false,
    this.acknowledgements = const [],
  });

  String get timeLabel => _timeLabel(occurredAt);
  bool hasAcknowledgementFor(ClientAppAcknowledgementChannel channel) {
    return acknowledgements.any(
      (acknowledgement) => acknowledgement.channel == channel,
    );
  }
}

class _ClientRoom {
  final String key;
  final String displayName;
  final ClientAppAcknowledgementChannel acknowledgementChannel;
  final int unread;
  final String summary;

  const _ClientRoom({
    required this.key,
    required this.displayName,
    required this.acknowledgementChannel,
    required this.unread,
    required this.summary,
  });
}

class _ClientChatMessage {
  final String messageKey;
  final String author;
  final String body;
  final DateTime occurredAt;
  final String? roomKey;
  final _ClientSystemMessageType? systemType;
  final String messageSource;
  final String messageProvider;
  final List<ClientAppAcknowledgement> acknowledgements;

  const _ClientChatMessage({
    required this.messageKey,
    required this.author,
    required this.body,
    required this.occurredAt,
    this.roomKey,
    required this.systemType,
    this.messageSource = 'in_app',
    this.messageProvider = 'in_app',
    this.acknowledgements = const [],
  });

  String get timeLabel => _timeLabel(occurredAt);
  bool get outgoing => author != 'ONYX';
}

class _ClientIncidentFeedEntry {
  final String referenceLabel;
  final String headline;
  final String detail;
  final DateTime occurredAt;
  final String statusLabel;
  final Color accent;
  final Color borderColor;

  const _ClientIncidentFeedEntry({
    required this.referenceLabel,
    required this.headline,
    required this.detail,
    required this.occurredAt,
    required this.statusLabel,
    required this.accent,
    required this.borderColor,
  });

  String get timeLabel => _timeLabel(occurredAt);
}

class _ClientIncidentFeedGroup {
  final String referenceLabel;
  final List<_ClientIncidentFeedEntry> entries;

  const _ClientIncidentFeedGroup({
    required this.referenceLabel,
    required this.entries,
  });

  _ClientIncidentFeedEntry get latestEntry => entries.first;
}

enum ClientPushDeliveryStatus { queued, acknowledged }

class ClientAppPushDeliveryItem {
  final String messageKey;
  final String title;
  final String body;
  final DateTime occurredAt;
  final String? clientId;
  final String? siteId;
  final ClientAppAcknowledgementChannel targetChannel;
  final ClientPushDeliveryProvider deliveryProvider;
  final bool priority;
  final ClientPushDeliveryStatus status;

  const ClientAppPushDeliveryItem({
    required this.messageKey,
    required this.title,
    required this.body,
    required this.occurredAt,
    this.clientId,
    this.siteId,
    required this.targetChannel,
    this.deliveryProvider = ClientPushDeliveryProvider.inApp,
    required this.priority,
    required this.status,
  });

  String get timeLabel => _timeLabel(occurredAt);

  factory ClientAppPushDeliveryItem.fromJson(Map<String, Object?> json) {
    final occurredAtValue = json['occurredAt']?.toString();
    return ClientAppPushDeliveryItem(
      messageKey: json['messageKey']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      occurredAt:
          DateTime.tryParse(occurredAtValue ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      clientId:
          (json['clientId'] ?? json['target_client_id'])
                  ?.toString()
                  .trim()
                  .isEmpty ??
              true
          ? null
          : (json['clientId'] ?? json['target_client_id'])!.toString().trim(),
      siteId:
          (json['siteId'] ?? json['target_site_id'])
                  ?.toString()
                  .trim()
                  .isEmpty ??
              true
          ? null
          : (json['siteId'] ?? json['target_site_id'])!.toString().trim(),
      targetChannel: ClientAppAcknowledgementChannel.values.firstWhere(
        (value) => value.name == json['targetChannel']?.toString(),
        orElse: () => ClientAppAcknowledgementChannel.client,
      ),
      deliveryProvider: ClientPushDeliveryProviderParser.fromCode(
        json['deliveryProvider']?.toString() ??
            json['delivery_provider']?.toString() ??
            'in_app',
      ),
      priority: json['priority'] == true,
      status: ClientPushDeliveryStatus.values.firstWhere(
        (value) => value.name == json['status']?.toString(),
        orElse: () => ClientPushDeliveryStatus.queued,
      ),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'messageKey': messageKey,
      'title': title,
      'body': body,
      'occurredAt': occurredAt.toUtc().toIso8601String(),
      if ((clientId ?? '').trim().isNotEmpty) 'clientId': clientId!.trim(),
      if ((siteId ?? '').trim().isNotEmpty) 'siteId': siteId!.trim(),
      'targetChannel': targetChannel.name,
      'deliveryProvider': deliveryProvider.code,
      'priority': priority,
      'status': status.name,
    };
  }
}

class ClientPushSyncAttempt {
  final DateTime occurredAt;
  final String status;
  final String? failureReason;
  final int queueSize;

  const ClientPushSyncAttempt({
    required this.occurredAt,
    required this.status,
    this.failureReason,
    required this.queueSize,
  });

  String get summaryLine {
    final reason = (failureReason ?? '').trim();
    if (reason.isEmpty) {
      return '${_timeLabel(occurredAt)} • $status • queue:$queueSize';
    }
    return '${_timeLabel(occurredAt)} • $status • queue:$queueSize • $reason';
  }

  factory ClientPushSyncAttempt.fromJson(Map<String, Object?> json) {
    final occurredAtValue = json['occurredAt']?.toString();
    return ClientPushSyncAttempt(
      occurredAt:
          DateTime.tryParse(occurredAtValue ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      status: json['status']?.toString() ?? 'unknown',
      failureReason: json['failureReason']?.toString(),
      queueSize: (json['queueSize'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'occurredAt': occurredAt.toUtc().toIso8601String(),
      'status': status,
      'failureReason': failureReason,
      'queueSize': queueSize,
    };
  }
}

class ClientBackendProbeAttempt {
  final DateTime occurredAt;
  final String status;
  final String? failureReason;

  const ClientBackendProbeAttempt({
    required this.occurredAt,
    required this.status,
    this.failureReason,
  });

  String get summaryLine {
    final reason = (failureReason ?? '').trim();
    if (reason.isEmpty) {
      return '${_timeLabel(occurredAt)} • $status';
    }
    return '${_timeLabel(occurredAt)} • $status • $reason';
  }

  factory ClientBackendProbeAttempt.fromJson(Map<String, Object?> json) {
    final occurredAtValue = json['occurredAt']?.toString();
    return ClientBackendProbeAttempt(
      occurredAt:
          DateTime.tryParse(occurredAtValue ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      status: json['status']?.toString() ?? 'unknown',
      failureReason: json['failureReason']?.toString(),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'occurredAt': occurredAt.toUtc().toIso8601String(),
      'status': status,
      'failureReason': failureReason,
    };
  }
}

class ClientPushSyncState {
  final String statusLabel;
  final DateTime? lastSyncedAtUtc;
  final String? failureReason;
  final int retryCount;
  final List<ClientPushSyncAttempt> history;
  final List<String> telegramDeliveredMessageKeys;
  final String backendProbeStatusLabel;
  final DateTime? backendProbeLastRunAtUtc;
  final String? backendProbeFailureReason;
  final List<ClientBackendProbeAttempt> backendProbeHistory;

  const ClientPushSyncState({
    required this.statusLabel,
    this.lastSyncedAtUtc,
    this.failureReason,
    required this.retryCount,
    required this.history,
    this.telegramDeliveredMessageKeys = const <String>[],
    required this.backendProbeStatusLabel,
    this.backendProbeLastRunAtUtc,
    this.backendProbeFailureReason,
    required this.backendProbeHistory,
  });

  const ClientPushSyncState.idle()
    : statusLabel = 'idle',
      lastSyncedAtUtc = null,
      failureReason = null,
      retryCount = 0,
      history = const [],
      telegramDeliveredMessageKeys = const <String>[],
      backendProbeStatusLabel = 'idle',
      backendProbeLastRunAtUtc = null,
      backendProbeFailureReason = null,
      backendProbeHistory = const [];

  factory ClientPushSyncState.fromJson(Map<String, Object?> json) {
    final rawHistory = json['history'];
    final rawBackendProbeHistory = json['backendProbeHistory'];
    final rawTelegramDeliveredMessageKeys =
        json['telegramDeliveredMessageKeys'];
    return ClientPushSyncState(
      statusLabel: json['status']?.toString().trim().isNotEmpty == true
          ? json['status']!.toString()
          : 'idle',
      lastSyncedAtUtc: DateTime.tryParse(
        json['lastSyncedAtUtc']?.toString() ?? '',
      )?.toUtc(),
      failureReason: json['failureReason']?.toString(),
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
      history: rawHistory is List
          ? rawHistory
                .whereType<Map>()
                .map(
                  (item) => ClientPushSyncAttempt.fromJson(
                    item.map((key, value) => MapEntry(key.toString(), value)),
                  ),
                )
                .take(20)
                .toList(growable: false)
          : const [],
      telegramDeliveredMessageKeys: rawTelegramDeliveredMessageKeys is List
          ? rawTelegramDeliveredMessageKeys
                .map((item) => item?.toString().trim() ?? '')
                .where((item) => item.isNotEmpty)
                .take(200)
                .toList(growable: false)
          : const <String>[],
      backendProbeStatusLabel:
          json['backendProbeStatus']?.toString().trim().isNotEmpty == true
          ? json['backendProbeStatus']!.toString()
          : 'idle',
      backendProbeLastRunAtUtc: DateTime.tryParse(
        json['backendProbeLastRunAtUtc']?.toString() ?? '',
      )?.toUtc(),
      backendProbeFailureReason: json['backendProbeFailureReason']?.toString(),
      backendProbeHistory: rawBackendProbeHistory is List
          ? rawBackendProbeHistory
                .whereType<Map>()
                .map(
                  (item) => ClientBackendProbeAttempt.fromJson(
                    item.map((key, value) => MapEntry(key.toString(), value)),
                  ),
                )
                .take(20)
                .toList(growable: false)
          : const [],
    );
  }

  Map<String, Object?> toJson() {
    return {
      'status': statusLabel,
      'lastSyncedAtUtc': lastSyncedAtUtc?.toIso8601String(),
      'failureReason': failureReason,
      'retryCount': retryCount,
      'history': history.map((entry) => entry.toJson()).toList(growable: false),
      'telegramDeliveredMessageKeys': telegramDeliveredMessageKeys,
      'backendProbeStatus': backendProbeStatusLabel,
      'backendProbeLastRunAtUtc': backendProbeLastRunAtUtc?.toIso8601String(),
      'backendProbeFailureReason': backendProbeFailureReason,
      'backendProbeHistory': backendProbeHistory
          .map((entry) => entry.toJson())
          .toList(growable: false),
    };
  }
}

enum _ClientSystemMessageType {
  dispatch(
    'Dispatch',
    Icons.flash_on_rounded,
    _clientInfoBorder,
    _clientInfoBorder,
    _clientInfoSurface,
    _clientInfoBorder,
    _clientPriorityBorder,
  ),
  advisory(
    'Advisory',
    Icons.campaign_rounded,
    _clientWarningBorder,
    _clientWarningBorder,
    _clientWarningSurface,
    _clientWarningBorder,
    _clientWarningBorder,
  ),
  closure(
    'Closure',
    Icons.check_circle_rounded,
    _clientSuccessBorder,
    _clientSuccessBorder,
    _clientSuccessSurface,
    _clientSuccessBorder,
    _clientSuccessBorder,
  ),
  update(
    'Update',
    Icons.sync_rounded,
    _clientAdminBorder,
    _clientAdminBorder,
    _clientAdminSurface,
    _clientAdminBorder,
    _clientAdminBorder,
  );

  final String label;
  final IconData icon;
  final Color textColor;
  final Color borderColor;
  final Color cardFillColor;
  final Color cardBorderColor;
  final Color priorityBorderColor;

  const _ClientSystemMessageType(
    this.label,
    this.icon,
    this.textColor,
    this.borderColor,
    this.cardFillColor,
    this.cardBorderColor,
    this.priorityBorderColor,
  );
}

class ClientAppAcknowledgement {
  final String messageKey;
  final ClientAppAcknowledgementChannel channel;
  final String acknowledgedBy;
  final DateTime acknowledgedAt;

  const ClientAppAcknowledgement({
    required this.messageKey,
    required this.channel,
    required this.acknowledgedBy,
    required this.acknowledgedAt,
  });

  factory ClientAppAcknowledgement.fromJson(Map<String, Object?> json) {
    final acknowledgedAtValue = json['acknowledgedAt']?.toString();
    return ClientAppAcknowledgement(
      messageKey: json['messageKey']?.toString() ?? '',
      channel: ClientAppAcknowledgementChannel.values.firstWhere(
        (value) => value.name == json['channel']?.toString(),
        orElse: () => ClientAppAcknowledgementChannel.client,
      ),
      acknowledgedBy: json['acknowledgedBy']?.toString() ?? '',
      acknowledgedAt:
          DateTime.tryParse(acknowledgedAtValue ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'messageKey': messageKey,
      'channel': channel.name,
      'acknowledgedBy': acknowledgedBy,
      'acknowledgedAt': acknowledgedAt.toUtc().toIso8601String(),
    };
  }

  String get displayLabel => channel.displayLabel;
}

enum ClientAppAcknowledgementChannel {
  client('Client Ack', 'Client'),
  control('Control Ack', 'Control'),
  resident('Resident Seen', 'Resident');

  final String displayLabel;
  final String defaultActor;

  const ClientAppAcknowledgementChannel(this.displayLabel, this.defaultActor);
}

enum ClientAppViewerRole {
  client(ClientAppAcknowledgementChannel.client),
  control(ClientAppAcknowledgementChannel.control),
  resident(ClientAppAcknowledgementChannel.resident);

  final ClientAppAcknowledgementChannel acknowledgementChannel;

  const ClientAppViewerRole(this.acknowledgementChannel);

  String get displayLabel {
    return switch (this) {
      ClientAppViewerRole.client => 'Client View',
      ClientAppViewerRole.control => 'Control View',
      ClientAppViewerRole.resident => 'Resident View',
    };
  }

  String displayLabelForLocale(ClientAppLocale locale) {
    return ClientAppLocaleText.roleText(
      locale: locale,
      key: 'displayLabel',
      role: this,
      fallback: displayLabel,
    );
  }

  String get surfaceTitle {
    return switch (this) {
      ClientAppViewerRole.client => 'Client Ops App',
      ClientAppViewerRole.control => 'Security Desk Console',
      ClientAppViewerRole.resident => 'Resident Estate Feed',
    };
  }

  String surfaceTitleForLocale(ClientAppLocale locale) {
    return ClientAppLocaleText.roleText(
      locale: locale,
      key: 'surfaceTitle',
      role: this,
      fallback: surfaceTitle,
    );
  }

  String get surfaceSubtitle {
    return switch (this) {
      ClientAppViewerRole.client =>
        'Push alerts, estate chatrooms, incident visibility, and direct client comms in one operational surface.',
      ClientAppViewerRole.control =>
        'Control-facing alerts, acknowledgements, and dispatch updates for active site response.',
      ClientAppViewerRole.resident =>
        'Resident-facing safety updates, acknowledgement prompts, and community incident awareness.',
    };
  }

  String surfaceSubtitleForLocale(ClientAppLocale locale) {
    return ClientAppLocaleText.roleText(
      locale: locale,
      key: 'surfaceSubtitle',
      role: this,
      fallback: surfaceSubtitle,
    );
  }

  String get notificationsPanelTitle {
    return switch (this) {
      ClientAppViewerRole.client => 'Push Notifications',
      ClientAppViewerRole.control => 'Control Alerts',
      ClientAppViewerRole.resident => 'Safety Updates',
    };
  }

  String notificationsPanelTitleForLocale(ClientAppLocale locale) {
    return ClientAppLocaleText.roleText(
      locale: locale,
      key: 'notificationsPanelTitle',
      role: this,
      fallback: notificationsPanelTitle,
    );
  }

  String get notificationsPanelSubtitle {
    return switch (this) {
      ClientAppViewerRole.client =>
        'Alarm triggers, arrivals, closures, and intelligence advisories.',
      ClientAppViewerRole.control =>
        'Operational alarms, dispatch state changes, and response-critical updates.',
      ClientAppViewerRole.resident =>
        'Resident-facing incident notices, estate alerts, and safety advisories.',
    };
  }

  String notificationsPanelSubtitleForLocale(ClientAppLocale locale) {
    return ClientAppLocaleText.roleText(
      locale: locale,
      key: 'notificationsPanelSubtitle',
      role: this,
      fallback: notificationsPanelSubtitle,
    );
  }

  String get roomsPanelTitle {
    return switch (this) {
      ClientAppViewerRole.client => 'Estate Rooms',
      ClientAppViewerRole.control => 'Audience Channels',
      ClientAppViewerRole.resident => 'Estate Channels',
    };
  }

  String roomsPanelTitleForLocale(ClientAppLocale locale) {
    return ClientAppLocaleText.roleText(
      locale: locale,
      key: 'roomsPanelTitle',
      role: this,
      fallback: roomsPanelTitle,
    );
  }

  String get incidentFeedPanelTitle {
    return switch (this) {
      ClientAppViewerRole.client => 'Incident Feed',
      ClientAppViewerRole.control => 'Active Incident Timeline',
      ClientAppViewerRole.resident => 'Safety Timeline',
    };
  }

  String incidentFeedPanelTitleForLocale(ClientAppLocale locale) {
    return ClientAppLocaleText.roleText(
      locale: locale,
      key: 'incidentFeedPanelTitle',
      role: this,
      fallback: incidentFeedPanelTitle,
    );
  }

  String get incidentFeedPanelSubtitle {
    return switch (this) {
      ClientAppViewerRole.client =>
        'Chronological dispatch, arrival, closure, and advisory milestones.',
      ClientAppViewerRole.control =>
        'Operational incident milestones and advisory checkpoints in one timeline.',
      ClientAppViewerRole.resident =>
        'Resident-safe timeline of alerts, responses, and resolved incidents.',
    };
  }

  String incidentFeedPanelSubtitleForLocale(ClientAppLocale locale) {
    return ClientAppLocaleText.roleText(
      locale: locale,
      key: 'incidentFeedPanelSubtitle',
      role: this,
      fallback: incidentFeedPanelSubtitle,
    );
  }

  String get incidentFeedEmptyLabel {
    return switch (this) {
      ClientAppViewerRole.client =>
        'Incident milestones will appear here as this lane updates.',
      ClientAppViewerRole.control =>
        'Active incident milestones will appear here as control updates the lane.',
      ClientAppViewerRole.resident =>
        'Safety timeline updates will appear here as this lane progresses.',
    };
  }

  String get incidentFeedActionLabel {
    return switch (this) {
      ClientAppViewerRole.client => 'Open Incident',
      ClientAppViewerRole.control => 'Open Thread',
      ClientAppViewerRole.resident => 'Open Safety Detail',
    };
  }

  String get incidentExpandHint {
    return switch (this) {
      ClientAppViewerRole.client => 'Tap to expand',
      ClientAppViewerRole.control => 'Tap to expand thread',
      ClientAppViewerRole.resident => 'Tap to expand safety thread',
    };
  }

  String get incidentCollapseHint {
    return switch (this) {
      ClientAppViewerRole.client => 'Tap to collapse',
      ClientAppViewerRole.control => 'Tap to collapse thread',
      ClientAppViewerRole.resident => 'Tap to collapse safety thread',
    };
  }

  String incidentToggleActionLabel(bool expanded) {
    return switch ((this, expanded)) {
      (ClientAppViewerRole.client, true) => 'Collapse',
      (ClientAppViewerRole.client, false) => 'Expand',
      (ClientAppViewerRole.control, true) => 'Collapse Thread',
      (ClientAppViewerRole.control, false) => 'Expand Thread',
      (ClientAppViewerRole.resident, true) => 'Collapse Safety',
      (ClientAppViewerRole.resident, false) => 'Expand Safety',
    };
  }

  String get selectedIncidentLabel {
    return switch (this) {
      ClientAppViewerRole.client => 'Selected',
      ClientAppViewerRole.control => 'Active Thread',
      ClientAppViewerRole.resident => 'Active Safety',
    };
  }

  String get expandedIncidentLabel {
    return switch (this) {
      ClientAppViewerRole.client => 'Expanded',
      ClientAppViewerRole.control => 'Expanded Thread',
      ClientAppViewerRole.resident => 'Expanded Safety',
    };
  }

  String get focusedIncidentLabel {
    return switch (this) {
      ClientAppViewerRole.client => 'Focused',
      ClientAppViewerRole.control => 'Desk Focus',
      ClientAppViewerRole.resident => 'Safety Focus',
    };
  }

  String get reopenSelectedIncidentLabel {
    return switch (this) {
      ClientAppViewerRole.client => 'Reopen Selected',
      ClientAppViewerRole.control => 'Reopen Thread',
      ClientAppViewerRole.resident => 'Reopen Safety',
    };
  }

  String reopenSelectedIncidentLabelFor(String referenceLabel) {
    return switch (this) {
      ClientAppViewerRole.client => 'Reopen $referenceLabel',
      ClientAppViewerRole.control => 'Reopen Thread $referenceLabel',
      ClientAppViewerRole.resident => 'Reopen Safety $referenceLabel',
    };
  }

  String get noSelectedIncidentLabel {
    return switch (this) {
      ClientAppViewerRole.client => 'Choose an Incident',
      ClientAppViewerRole.control => 'Choose a Thread',
      ClientAppViewerRole.resident => 'Choose a Safety Lane',
    };
  }

  String selectedIncidentHeaderLabel(String referenceLabel) {
    return switch (this) {
      ClientAppViewerRole.client => 'Selected Thread • $referenceLabel',
      ClientAppViewerRole.control => 'Active Thread • $referenceLabel',
      ClientAppViewerRole.resident => 'Active Safety • $referenceLabel',
    };
  }

  IconData get selectedIncidentHeaderIcon {
    return switch (this) {
      ClientAppViewerRole.client => Icons.bookmark_added_outlined,
      ClientAppViewerRole.control => Icons.track_changes,
      ClientAppViewerRole.resident => Icons.shield_outlined,
    };
  }

  String get incidentDetailTitle {
    return switch (this) {
      ClientAppViewerRole.client => 'Incident Detail',
      ClientAppViewerRole.control => 'Control Incident Thread',
      ClientAppViewerRole.resident => 'Safety Detail',
    };
  }

  String get incidentReferenceLabel {
    return switch (this) {
      ClientAppViewerRole.client => 'Reference',
      ClientAppViewerRole.control => 'Dispatch Thread',
      ClientAppViewerRole.resident => 'Safety Thread',
    };
  }

  String incidentReferenceDisplayLabel(String referenceLabel) {
    return switch (this) {
      ClientAppViewerRole.client => referenceLabel,
      ClientAppViewerRole.control => 'Thread $referenceLabel',
      ClientAppViewerRole.resident => 'Safety Thread $referenceLabel',
    };
  }

  String incidentReferenceCountDisplayLabel(String referenceLabel, int count) {
    return '${incidentReferenceDisplayLabel(referenceLabel)} • ${incidentCountLabel(count)}';
  }

  String get incidentStatusLabel {
    return switch (this) {
      ClientAppViewerRole.client => 'Latest Status',
      ClientAppViewerRole.control => 'Latest Milestone',
      ClientAppViewerRole.resident => 'Latest Safety Status',
    };
  }

  String get incidentOccurredLabel {
    return switch (this) {
      ClientAppViewerRole.client => 'Occurred',
      ClientAppViewerRole.control => 'Logged',
      ClientAppViewerRole.resident => 'Updated',
    };
  }

  String get incidentHeadlineLabel {
    return switch (this) {
      ClientAppViewerRole.client => 'Headline',
      ClientAppViewerRole.control => 'Operational Summary',
      ClientAppViewerRole.resident => 'Safety Summary',
    };
  }

  String get incidentDetailSummaryLabel {
    return switch (this) {
      ClientAppViewerRole.client => 'Detail',
      ClientAppViewerRole.control => 'Operational Detail',
      ClientAppViewerRole.resident => 'Safety Detail',
    };
  }

  String get incidentEventsLabel {
    return switch (this) {
      ClientAppViewerRole.client => 'Events',
      ClientAppViewerRole.control => 'Timeline Events',
      ClientAppViewerRole.resident => 'Safety Events',
    };
  }

  String incidentCountLabel(int count) {
    final noun = switch (this) {
      ClientAppViewerRole.client => count == 1 ? 'event' : 'events',
      ClientAppViewerRole.control => count == 1 ? 'milestone' : 'milestones',
      ClientAppViewerRole.resident => count == 1 ? 'update' : 'updates',
    };
    return '$count $noun';
  }

  String get incidentMilestonesLabel {
    return switch (this) {
      ClientAppViewerRole.client => 'Thread Milestones',
      ClientAppViewerRole.control => 'Operational Milestones',
      ClientAppViewerRole.resident => 'Safety Milestones',
    };
  }

  String incidentMilestoneLineLabel(String statusLabel, String timeLabel) {
    final displayStatus = incidentStatusDisplayLabel(statusLabel);
    final displayTime = incidentTimeDisplayLabel(timeLabel);
    final prefix = switch (this) {
      ClientAppViewerRole.client => null,
      ClientAppViewerRole.control => 'Milestone',
      ClientAppViewerRole.resident => 'Safety Update',
    };
    if (prefix == null) {
      return '$displayStatus • $displayTime';
    }
    return '$prefix: $displayStatus • $displayTime';
  }

  String incidentTimeDisplayLabel(String timeLabel) {
    return switch (this) {
      ClientAppViewerRole.client => timeLabel,
      ClientAppViewerRole.control => 'Logged $timeLabel',
      ClientAppViewerRole.resident => 'Updated $timeLabel',
    };
  }

  String incidentStatusDisplayLabel(String statusLabel) {
    return switch ((this, statusLabel)) {
      (ClientAppViewerRole.client, _) => statusLabel,
      (ClientAppViewerRole.control, 'Opened') => 'Dispatched',
      (ClientAppViewerRole.control, 'On Site') => 'Responder On Site',
      (ClientAppViewerRole.control, 'Closed') => 'Resolved',
      (ClientAppViewerRole.control, 'Advisory') => 'Advisory Signal',
      (ClientAppViewerRole.control, 'Intel') => 'Intel Signal',
      (ClientAppViewerRole.resident, 'Opened') => 'Security Responding',
      (ClientAppViewerRole.resident, 'On Site') => 'Security On Site',
      (ClientAppViewerRole.resident, 'Closed') => 'Resolved',
      (ClientAppViewerRole.resident, 'Advisory') => 'Safety Advisory',
      (ClientAppViewerRole.resident, 'Intel') => 'Safety Alert',
      (_, _) => statusLabel,
    };
  }

  String incidentHeadlineDisplay({
    required String statusLabel,
    required String referenceLabel,
    required String headline,
    required String detail,
  }) {
    return switch ((this, statusLabel)) {
      (ClientAppViewerRole.client, _) => headline,
      (ClientAppViewerRole.control, _) => headline,
      (ClientAppViewerRole.resident, 'Opened') =>
        'Security responding at ${_incidentSiteLabel(referenceLabel, headline, detail)}',
      (ClientAppViewerRole.resident, 'On Site') =>
        'Security on site at ${_incidentSiteLabel(referenceLabel, headline, detail)}',
      (ClientAppViewerRole.resident, 'Closed') => 'Incident resolved',
      (ClientAppViewerRole.resident, 'Advisory') => 'Safety advisory issued',
      (ClientAppViewerRole.resident, 'Intel') => 'Safety update received',
      (_, _) => headline,
    };
  }

  String incidentDetailDisplay({
    required String statusLabel,
    required String referenceLabel,
    required String headline,
    required String detail,
  }) {
    return switch ((this, statusLabel)) {
      (ClientAppViewerRole.client, _) => detail,
      (ClientAppViewerRole.control, _) => detail,
      (ClientAppViewerRole.resident, 'Opened') =>
        'Security has been notified and updates are in progress.',
      (ClientAppViewerRole.resident, 'On Site') =>
        'Security is on site and assessing the situation now.',
      (ClientAppViewerRole.resident, 'Closed') =>
        'Security marked the incident as resolved.',
      (ClientAppViewerRole.resident, 'Advisory') => detail,
      (ClientAppViewerRole.resident, 'Intel') => detail,
      (_, _) => detail,
    };
  }

  String _incidentSiteLabel(
    String referenceLabel,
    String headline,
    String detail,
  ) {
    if (headline.startsWith('Dispatch opened for ')) {
      return headline.replaceFirst('Dispatch opened for ', '');
    }
    final movingToMatch = RegExp(
      r'moving to (.+?) now[.]?$',
      caseSensitive: false,
    ).firstMatch(detail.trim());
    if (movingToMatch != null) {
      return movingToMatch.group(1)!.trim();
    }
    final arrivedAtMatch = RegExp(
      r'arrived at (.+?) and',
      caseSensitive: false,
    ).firstMatch(detail.trim());
    if (arrivedAtMatch != null) {
      return arrivedAtMatch.group(1)!.trim();
    }
    final reachedIndex = detail.lastIndexOf(' reached ');
    if (reachedIndex >= 0) {
      return detail.substring(reachedIndex + ' reached '.length);
    }
    return referenceLabel;
  }

  String get roomsPanelSubtitle {
    return switch (this) {
      ClientAppViewerRole.client =>
        'Residents, trustees, and control channels.',
      ClientAppViewerRole.control =>
        'View pending acknowledgement lanes across residents, trustees, and desk response.',
      ClientAppViewerRole.resident =>
        'Resident, trustee, and control streams aligned to estate communication.',
    };
  }

  String roomsPanelSubtitleForLocale(ClientAppLocale locale) {
    return ClientAppLocaleText.roleText(
      locale: locale,
      key: 'roomsPanelSubtitle',
      role: this,
      fallback: roomsPanelSubtitle,
    );
  }

  String get chatPanelTitle {
    return switch (this) {
      ClientAppViewerRole.client => 'Direct Client Chat',
      ClientAppViewerRole.control => 'Desk Coordination Thread',
      ClientAppViewerRole.resident => 'Resident Message Thread',
    };
  }

  String chatPanelTitleForLocale(ClientAppLocale locale) {
    return ClientAppLocaleText.roleText(
      locale: locale,
      key: 'chatPanelTitle',
      role: this,
      fallback: chatPanelTitle,
    );
  }

  String get chatPanelSubtitle {
    return switch (this) {
      ClientAppViewerRole.client =>
        'Secure client thread with operational updates.',
      ClientAppViewerRole.control =>
        'Control-side coordination with mirrored ONYX updates and acknowledgements.',
      ClientAppViewerRole.resident =>
        'Resident-facing message stream with mirrored estate safety updates.',
    };
  }

  String chatPanelSubtitleForLocale(ClientAppLocale locale) {
    return ClientAppLocaleText.roleText(
      locale: locale,
      key: 'chatPanelSubtitle',
      role: this,
      fallback: chatPanelSubtitle,
    );
  }

  String get alertsMetricLabel {
    return switch (this) {
      ClientAppViewerRole.client => 'Unread Alerts',
      ClientAppViewerRole.control => 'Open Alerts',
      ClientAppViewerRole.resident => 'New Safety Alerts',
    };
  }

  String alertsMetricLabelForLocale(ClientAppLocale locale) {
    return ClientAppLocaleText.roleText(
      locale: locale,
      key: 'alertsMetricLabel',
      role: this,
      fallback: alertsMetricLabel,
    );
  }

  String get chatMetricLabel {
    return switch (this) {
      ClientAppViewerRole.client => 'Direct Chat',
      ClientAppViewerRole.control => 'Desk Thread',
      ClientAppViewerRole.resident => 'Message Thread',
    };
  }

  String chatMetricLabelForLocale(ClientAppLocale locale) {
    return ClientAppLocaleText.roleText(
      locale: locale,
      key: 'chatMetricLabel',
      role: this,
      fallback: chatMetricLabel,
    );
  }

  String get notificationsEmptyLabel {
    return switch (this) {
      ClientAppViewerRole.client =>
        'Client notifications will appear here when this lane updates.',
      ClientAppViewerRole.control =>
        'Control alerts are quiet in this lane right now.',
      ClientAppViewerRole.resident =>
        'Safety updates are quiet in this lane right now.',
    };
  }

  String get chatEmptyLabel {
    return switch (this) {
      ClientAppViewerRole.client =>
        'Direct chat will appear here once this lane starts talking.',
      ClientAppViewerRole.control =>
        'Desk coordination is quiet in this lane right now.',
      ClientAppViewerRole.resident =>
        'Resident messages will appear here once this lane becomes active.',
    };
  }

  String chatComposerHintFor(String roomKey) {
    return switch ((this, roomKey)) {
      (ClientAppViewerRole.client, 'Trustees') =>
        'Send an update to the trustee board...',
      (ClientAppViewerRole.client, 'Security Desk') =>
        'Request a security desk update...',
      (ClientAppViewerRole.client, _) => 'Send secure client update...',
      (ClientAppViewerRole.control, 'Trustees') =>
        'Log a trustee escalation update...',
      (ClientAppViewerRole.control, 'Security Desk') =>
        'Log a desk coordination update...',
      (ClientAppViewerRole.control, _) =>
        'Log a resident-lane control update...',
      (ClientAppViewerRole.resident, 'Trustees') => 'Write to estate admin...',
      (ClientAppViewerRole.resident, 'Security Desk') =>
        'Share a security-team request...',
      (ClientAppViewerRole.resident, _) =>
        'Share a resident response update...',
    };
  }

  String chatSendLabelFor(String roomKey) {
    return switch ((this, roomKey)) {
      (ClientAppViewerRole.client, 'Trustees') => 'Send to Trustees',
      (ClientAppViewerRole.client, 'Security Desk') => 'Send to Desk',
      (ClientAppViewerRole.client, _) => 'Send',
      (ClientAppViewerRole.control, 'Trustees') => 'Send Escalation',
      (ClientAppViewerRole.control, 'Security Desk') => 'Log Desk Update',
      (ClientAppViewerRole.control, _) => 'Log Resident Update',
      (ClientAppViewerRole.resident, 'Trustees') => 'Send to Admin',
      (ClientAppViewerRole.resident, 'Security Desk') => 'Send to Security',
      (ClientAppViewerRole.resident, _) => 'Post Reply',
    };
  }

  List<String> quickActionTemplatesFor(String roomKey) {
    final roomLabel = roomLabelForKey(roomKey);
    return switch ((this, roomKey)) {
      (ClientAppViewerRole.client, 'Trustees') => [
        'Trustee review requested for $roomLabel',
        'Need board approval for $roomLabel',
        'Escalating to $roomLabel',
      ],
      (ClientAppViewerRole.client, 'Security Desk') => [
        'Requesting desk update for $roomLabel',
        'Awaiting desk response for $roomLabel',
        'Client informed in $roomLabel',
      ],
      (ClientAppViewerRole.client, _) => [
        'Confirm receipt for $roomLabel',
        'Please share ETA for $roomLabel',
        'Client informed in $roomLabel',
      ],
      (ClientAppViewerRole.control, 'Trustees') => [
        'Trustee board informed for $roomLabel',
        'Awaiting trustee confirmation for $roomLabel',
        'Escalation logged for $roomLabel',
      ],
      (ClientAppViewerRole.control, 'Security Desk') => [
        'Desk investigating in $roomLabel',
        'Control team notified for $roomLabel',
        'Awaiting guard confirmation for $roomLabel',
      ],
      (ClientAppViewerRole.control, _) => [
        'Resident feed monitored for $roomLabel',
        'Community alert issued for $roomLabel',
        'Awaiting resident acknowledgement for $roomLabel',
      ],
      (ClientAppViewerRole.resident, 'Trustees') => [
        'Escalate to estate admin for $roomLabel',
        'Awaiting estate admin reply for $roomLabel',
        'Admin update requested for $roomLabel',
      ],
      (ClientAppViewerRole.resident, 'Security Desk') => [
        'Contacting security team for $roomLabel',
        'Awaiting security response for $roomLabel',
        'Security team informed in $roomLabel',
      ],
      (ClientAppViewerRole.resident, _) => [
        'Resident acknowledged for $roomLabel',
        'Community informed in $roomLabel',
        'Requesting update for $roomLabel',
      ],
    };
  }

  String roomLabelForKey(String roomKey) {
    return switch (roomKey) {
      'Trustees' => roomLabelFor(ClientAppAcknowledgementChannel.client),
      'Security Desk' => roomLabelFor(ClientAppAcknowledgementChannel.control),
      _ => roomLabelFor(ClientAppAcknowledgementChannel.resident),
    };
  }

  String roomLabelFor(ClientAppAcknowledgementChannel channel) {
    return switch ((this, channel)) {
      (ClientAppViewerRole.client, ClientAppAcknowledgementChannel.resident) =>
        'Residents',
      (ClientAppViewerRole.client, ClientAppAcknowledgementChannel.client) =>
        'Trustees',
      (ClientAppViewerRole.client, ClientAppAcknowledgementChannel.control) =>
        'Security Desk',
      (ClientAppViewerRole.control, ClientAppAcknowledgementChannel.resident) =>
        'Resident Feed',
      (ClientAppViewerRole.control, ClientAppAcknowledgementChannel.client) =>
        'Trustee Board',
      (ClientAppViewerRole.control, ClientAppAcknowledgementChannel.control) =>
        'Desk Ops',
      (
        ClientAppViewerRole.resident,
        ClientAppAcknowledgementChannel.resident,
      ) =>
        'Community',
      (ClientAppViewerRole.resident, ClientAppAcknowledgementChannel.client) =>
        'Estate Admin',
      (ClientAppViewerRole.resident, ClientAppAcknowledgementChannel.control) =>
        'Security Team',
    };
  }

  String get outgoingAuthorLabel {
    return switch (this) {
      ClientAppViewerRole.client => 'Client',
      ClientAppViewerRole.control => 'Control',
      ClientAppViewerRole.resident => 'Resident',
    };
  }

  Color get outgoingBubbleFillColor {
    return switch (this) {
      ClientAppViewerRole.client => _clientInfoSurface,
      ClientAppViewerRole.control => _clientSuccessSurface,
      ClientAppViewerRole.resident => _clientWarningSurface,
    };
  }

  Color get outgoingBubbleBorderColor {
    return switch (this) {
      ClientAppViewerRole.client => _clientInfoAccentStrong,
      ClientAppViewerRole.control => _clientSuccessAccent,
      ClientAppViewerRole.resident => _clientWarningAccent,
    };
  }

  Color get outgoingBubbleMetaColor {
    return switch (this) {
      ClientAppViewerRole.client => _clientInfoBorder,
      ClientAppViewerRole.control => _clientSuccessBorder,
      ClientAppViewerRole.resident => _clientWarningBorder,
    };
  }

  String get pendingMetricLabel {
    return switch (this) {
      ClientAppViewerRole.client => 'Client Acks Pending',
      ClientAppViewerRole.control => 'Control Acks Pending',
      ClientAppViewerRole.resident => 'Resident Seen Pending',
    };
  }

  String pendingMetricLabelForLocale(ClientAppLocale locale) {
    return ClientAppLocaleText.roleText(
      locale: locale,
      key: 'pendingMetricLabel',
      role: this,
      fallback: pendingMetricLabel,
    );
  }
}

class ClientAppLocaleText {
  static const Map<ClientAppLocale, Map<String, String>> _general = {
    ClientAppLocale.zu: {
      'conversationSyncLive':
          'Ukuvumelanisa ingxoxo: Supabase + ukuwa emuva kwendawo',
      'conversationSyncLocal': 'Ukuvumelanisa ingxoxo: i-cache yendawo kuphela',
      'runWithLocalDefines':
          'Qalisa ngama-define endawo: ./scripts/run_onyx_chrome_local.sh',
      'languageLabel': 'Ulimi: isiZulu',
      'activeIncidents': 'Izehlakalo Ezisebenzayo',
      'estateRooms': 'Amakamelo Esiza',
      'pushQueueReady': 'Uluhlu lwe-Push lulungile',
      'pushDeliveryQueueTitle': 'Ulayini Wokulethwa kwe-Push',
      'pushDeliveryQueueSubtitle':
          'Izexwayiso zezehlakalo ezilungele i-push ezilungiselelwe ukulethwa kweselula nokulandelela ukuvunywa.',
      'showPending': 'Khombisa okulindile',
      'showAll': 'Khombisa konke',
      'targetPrefix': 'Okuqondiwe',
      'targetCurrentLanePrefix': 'Okuqondiwe (umzila wamanje)',
      'bridgePrefix': 'Ibhuloho',
      'bridgeInApp': 'Ngaphakathi kohlelo',
      'bridgeTelegram': 'Telegram',
      'filterScopeAllNotifications':
          'Kuboniswa zonke izaziso • umzila wamanje: {room}',
      'filterScopePending': 'Kuboniswa okulindile: {room}',
      'showingAllThreadMessagesCurrentLane':
          'Kuboniswa yonke imilayezo yochungechunge • umzila wamanje: {room}',
      'showingPendingThreadMessages':
          'Kuboniswa imilayezo yochungechunge elindile ye-{room}.',
      'showingAllNotificationsCurrentLane':
          'Kuboniswa zonke izaziso • umzila wamanje: {room}',
      'showingPendingNotifications': 'Kuboniswa izaziso ezilindile ze-{room}.',
      'currentLaneAllMessageActivity':
          'Umzila wamanje: {room} • wonke umsebenzi wemilayezo uyabonakala.',
      'currentLanePendingActivityFocus':
          'Umzila wamanje: {room} • kugxilwe emsebenzini olindile womzila.',
      'noPushNotificationsQueuedYet':
          'Azikho izaziso ze-push ezikulayini okwamanje.',
      'queuedStatus': 'Kulindile',
      'deliveredStatus': 'Kulethiwe',
      'telegramStatusLine': 'Telegram: {status}',
      'telegramFallbackActive': 'I-telegram fallback iyasebenza.',
      'pushSyncStatusLine': 'Ukuvumelanisa i-Push: {status}',
      'lastSyncRetriesLine':
          'Ukuvumelanisa kokugcina: {lastSync} • Ukuzama futhi: {retries}',
      'backendProbeStatusLine':
          'Ukuhlola i-Backend: {status} • Ukuqalisa kokugcina: {lastRun}',
      'failureLine': 'Ukuhluleka: {reason}',
      'probeFailureLine': 'Ukuhluleka kokuhlola: {reason}',
      'retryPushSync': 'Phinda ukuvumelanisa i-Push',
      'runBackendProbe': 'Qalisa ukuhlola i-Backend',
      'clearProbeHistoryButton': 'Sula Umlando Wokuhlola',
      'clearProbeHistoryTitle': 'Sula Umlando Wokuhlola?',
      'clearProbeHistoryBody':
          'Lokhu kususa imizamo yokuhlola i-backend eqoshiwe kule ndawo yekhasimende.',
      'cancelLabel': 'Khansela',
      'clearLabel': 'Sula',
      'closeLabel': 'Vala',
      'composerStatusReadyDispatchReview':
          'Kulungele: ukubuyekezwa kokuthunyelwa',
      'composerStatusReadyAdvisory': 'Kulungele: isixwayiso',
      'composerStatusReadyClosure': 'Kulungele: ukuvalwa',
      'composerStatusReadyUpdate': 'Kulungele: isibuyekezo',
      'threadJumpedClient': 'Kugxunyekwe empendulweni yakamuva',
      'threadJumpedControl': 'Kugxunyekwe kwirekhodi lakamuva',
      'threadJumpedResident': 'Kugxunyekwe empendulweni yakamuva yomhlali',
      'viewSentMessageClient': 'Buka Ochungechungeni',
      'viewSentMessageControl': 'Buka Irekhodi',
      'viewSentMessageResident': 'Buka Impendulo Yomhlali',
      'chatSendClientAdvisory': 'Thumela Isixwayiso ku-{room}',
      'chatSendClientClosure': 'Thumela Ukuvalwa ku-{room}',
      'chatSendClientDispatchReview':
          'Thumela Ukubuyekezwa Kokuthunyelwa ku-{room}',
      'chatSendControlAdvisory': 'Faka ilogi yesixwayiso ku-{room}',
      'chatSendControlClosure': 'Faka ilogi yokuvalwa ku-{room}',
      'chatSendControlDispatchReview':
          'Faka ilogi yokubuyekezwa kokuthunyelwa ku-{room}',
      'chatSendResidentAdvisory': 'Thumela Isixwayiso Somphakathi ku-{room}',
      'chatSendResidentClosure': 'Thumela Ukuvalwa ku-{room}',
      'chatSendResidentDispatchReview':
          'Thumela Ukubuyekezwa Kokuthunyelwa ku-{room}',
      'draftRequiredClientDispatch':
          'Izimpendulo zokuthunyelwa ze-{room} zidinga ukubuyekezwa kwekhasimende ngaphambi kokuthumela.',
      'draftRequiredControlDispatch':
          'Izimpendulo zokuthunyelwa ze-{room} kufanele zibuyekezwe ngaphambi kokuthumela.',
      'draftRequiredResidentDispatch':
          'Izibuyekezo zokuthunyelwa ze-{room} zidinga ukubuyekezwa ngaphambi kokuthumela.',
      'draftRequiredDefault':
          'Kudingeka ukubuyekezwa kohlaka ngaphambi kokuthumela.',
      'draftReadyClientDispatch': 'Vula ukubuyekezwa kwekhasimende ku-{room}',
      'draftReadyControlDispatch': 'Vula uhlaka lokuthunyelwa ku-{room}',
      'draftReadyResidentDispatch': 'Vula uhlaka lwesibuyekezo ku-{room}',
      'draftReadyDefault': 'Uhlaka selulungele',
      'draftOpenedClientDispatch':
          'Uhlaka lokubuyekezwa kwekhasimende luvuliwe ku-{room}',
      'draftOpenedControlDispatch': 'Uhlaka lokuthunyelwa luvuliwe ku-{room}',
      'draftOpenedResidentDispatch':
          'Uhlaka lwesibuyekezo sokuthunyelwa luvuliwe ku-{room}',
      'draftOpenedDefault': 'Uhlaka luvuliwe',
      'notificationActionClientDispatch': 'Cela i-ETA ye-{room}',
      'notificationActionClientAdvisory': 'Buyekeza isixwayiso se-{room}',
      'notificationActionClientClosure': 'Buyekeza ukuvalwa kwe-{room}',
      'notificationActionClientDefault': 'Buyekeza isibuyekezo se-{room}',
      'notificationActionControlDispatch': 'Vula ukuthunyelwa kwe-{room}',
      'notificationActionControlAdvisory': 'Dala ilogi yesixwayiso ye-{room}',
      'notificationActionControlClosure': 'Dala ilogi yokuvalwa ye-{room}',
      'notificationActionControlDefault': 'Dala ilogi yesibuyekezo ye-{room}',
      'notificationActionResidentDispatch': 'Buka isexwayiso se-{room}',
      'notificationActionResidentAdvisory':
          'Dala isixwayiso somphakathi se-{room}',
      'notificationActionResidentClosure': 'Dala impendulo yokuvalwa ye-{room}',
      'notificationActionResidentDefault':
          'Dala isicelo sesibuyekezo se-{room}',
      'notificationSendNowClientAdvisory': 'Thumela Isixwayiso ku-{room}',
      'notificationSendNowClientClosure': 'Thumela Ukuvalwa ku-{room}',
      'notificationSendNowClientDefault': 'Thumela Isibuyekezo ku-{room}',
      'notificationSendNowControlAdvisory':
          'Faka ilogi yesixwayiso manje ku-{room}',
      'notificationSendNowControlClosure':
          'Faka ilogi yokuvalwa manje ku-{room}',
      'notificationSendNowControlDefault':
          'Faka ilogi yesibuyekezo manje ku-{room}',
      'notificationSendNowResidentAdvisory':
          'Thumela Isixwayiso Somphakathi ku-{room}',
      'notificationSendNowResidentClosure': 'Thumela Ukuvalwa ku-{room}',
      'notificationSendNowResidentDefault': 'Thumela Isibuyekezo ku-{room}',
      'notificationSentClientAdvisory': 'Isixwayiso sithunyelwe ku-{room}',
      'notificationSentClientClosure': 'Ukuvalwa kuthunyelwe ku-{room}',
      'notificationSentClientDefault': 'Isibuyekezo sithunyelwe ku-{room}',
      'notificationSentControlAdvisory':
          'Ilogi yesixwayiso ithunyelwe ku-{room}',
      'notificationSentControlClosure': 'Ilogi yokuvalwa ithunyelwe ku-{room}',
      'notificationSentControlDefault':
          'Ilogi yesibuyekezo ithunyelwe ku-{room}',
      'notificationSentResidentAdvisory':
          'Isixwayiso somphakathi sithunyelwe ku-{room}',
      'notificationSentResidentClosure':
          'Impendulo yokuvalwa ithunyelwe ku-{room}',
      'notificationSentResidentDefault':
          'Isicelo sesibuyekezo sithunyelwe ku-{room}',
      'notificationDraftClientDispatch':
          'Sicela wabelane nge-ETA yakamuva ye-{title} ku-{room}.',
      'notificationDraftClientAdvisory':
          'Ikhasimende libuyekeze isixwayiso futhi selikulungele ukwabelana ngaso ku-{room}.',
      'notificationDraftClientClosure':
          'Ikhasimende libuyekeze ukuvalwa kwe-{room} futhi liqinisekisile ukuthola.',
      'notificationDraftClientDefault':
          'Ikhasimende libuyekeze lesi sibuyekezo se-{room} futhi lilindele isinyathelo esilandelayo.',
      'notificationDraftControlDispatch':
          'Ukulawula kubuyekeza impendulo yokuthunyelwa ye-{room}.',
      'notificationDraftControlAdvisory':
          'Ukulawula kudala ilogi yesixwayiso ye-{room}.',
      'notificationDraftControlClosure':
          'Ukulawula kudala ilogi yokuvalwa ye-{room}.',
      'notificationDraftControlDefault':
          'Ukulawula kudala ilogi yesibuyekezo sokusebenza ye-{room}.',
      'notificationDraftResidentDispatch':
          'Umhlali ubukile isexwayiso se-{room} futhi ulindele isiqondiso.',
      'notificationDraftResidentAdvisory':
          'Umhlali udala isixwayiso somphakathi se-{room} manje.',
      'notificationDraftResidentClosure':
          'Umhlali udala impendulo yokuvalwa ye-{room}.',
      'notificationDraftResidentDefault':
          'Umhlali udala isicelo sesibuyekezo se-{room}.',
      'pushSyncHistoryEmpty':
          'Umlando wokuvumelanisa i-Push: awukho okwamanje.',
      'pushSyncHistoryTitle': 'Umlando wokuvumelanisa i-Push',
      'backendProbeHistoryEmpty':
          'Umlando wokuhlola i-Backend: awekho ama-run okwamanje.',
      'backendProbeHistoryTitle': 'Umlando wokuhlola i-Backend',
    },
    ClientAppLocale.af: {
      'conversationSyncLive':
          'Gesprek-sinkronisering: Supabase + plaaslike terugval',
      'conversationSyncLocal': 'Gesprek-sinkronisering: slegs plaaslike kas',
      'runWithLocalDefines':
          'Begin met plaaslike definisies: ./scripts/run_onyx_chrome_local.sh',
      'languageLabel': 'Taal: Afrikaans',
      'activeIncidents': 'Aktiewe Voorvalle',
      'estateRooms': 'Landgoed-kamers',
      'pushQueueReady': 'Stootry gereed',
      'pushDeliveryQueueTitle': 'Stootaflewering-waglys',
      'pushDeliveryQueueSubtitle':
          'Stootgereed voorvalwaarskuwings voorberei vir mobiele aflewering met bevestigingnasporing.',
      'showPending': 'Wys hangend',
      'showAll': 'Wys alles',
      'targetPrefix': 'Teiken',
      'targetCurrentLanePrefix': 'Teiken (huidige baan)',
      'bridgePrefix': 'Brug',
      'bridgeInApp': 'In-toep',
      'bridgeTelegram': 'Telegram',
      'filterScopeAllNotifications':
          'Wys alle kennisgewings • huidige baan: {room}',
      'filterScopePending': 'Wys hangend: {room}',
      'showingAllThreadMessagesCurrentLane':
          'Wys alle draadboodskappe • huidige baan: {room}',
      'showingPendingThreadMessages':
          'Wys hangende draadboodskappe vir {room}.',
      'showingAllNotificationsCurrentLane':
          'Wys alle kennisgewings • huidige baan: {room}',
      'showingPendingNotifications': 'Wys hangende kennisgewings vir {room}.',
      'currentLaneAllMessageActivity':
          'Huidige baan: {room} • alle boodskapaktiwiteit sigbaar.',
      'currentLanePendingActivityFocus':
          'Huidige baan: {room} • fokus op baan-hangende aktiwiteit.',
      'noPushNotificationsQueuedYet': 'Geen stootkennisgewings tans in ry nie.',
      'queuedStatus': 'In ry',
      'deliveredStatus': 'Afgelewer',
      'telegramStatusLine': 'Telegram: {status}',
      'telegramFallbackActive': 'Telegram-rugsteun is aktief.',
      'pushSyncStatusLine': 'Stoot-sinkronisering: {status}',
      'lastSyncRetriesLine':
          'Laaste sinkronisering: {lastSync} • Herprobeer: {retries}',
      'backendProbeStatusLine':
          'Agterkantsonde: {status} • Laaste lopie: {lastRun}',
      'failureLine': 'Mislukking: {reason}',
      'probeFailureLine': 'Sonde-mislukking: {reason}',
      'retryPushSync': 'Herprobeer stoot-sinkronisering',
      'runBackendProbe': 'Begin agterkantsonde',
      'clearProbeHistoryButton': 'Maak sondegeskiedenis skoon',
      'clearProbeHistoryTitle': 'Maak sondegeskiedenis skoon?',
      'clearProbeHistoryBody':
          'Dit verwyder aangetekende agterkantsonde-pogings van hierdie kliëntoppervlak.',
      'cancelLabel': 'Kanselleer',
      'clearLabel': 'Maak skoon',
      'closeLabel': 'Sluit',
      'composerStatusReadyDispatchReview': 'Gereed: ontplooiing-oorsig',
      'composerStatusReadyAdvisory': 'Gereed: advies',
      'composerStatusReadyClosure': 'Gereed: afsluiting',
      'composerStatusReadyUpdate': 'Gereed: opdatering',
      'threadJumpedClient': 'Gespring na nuutste antwoord',
      'threadJumpedControl': 'Gespring na nuutste loginskrywing',
      'threadJumpedResident': 'Gespring na nuutste inwonerantwoord',
      'viewSentMessageClient': 'Bekyk in draad',
      'viewSentMessageControl': 'Bekyk loginskrywing',
      'viewSentMessageResident': 'Bekyk inwonerantwoord',
      'chatSendClientAdvisory': 'Stuur advies na {room}',
      'chatSendClientClosure': 'Stuur afsluiting na {room}',
      'chatSendClientDispatchReview': 'Stuur ontplooiing-oorsig na {room}',
      'chatSendControlAdvisory': 'Teken advies vir {room}',
      'chatSendControlClosure': 'Teken afsluiting vir {room}',
      'chatSendControlDispatchReview': 'Teken ontplooiing-oorsig vir {room}',
      'chatSendResidentAdvisory': 'Plaas advies na {room}',
      'chatSendResidentClosure': 'Plaas afsluiting na {room}',
      'chatSendResidentDispatchReview': 'Plaas ontplooiing-oorsig na {room}',
      'draftRequiredClientDispatch':
          'Ontplooiingsantwoorde vir {room} vereis kliënt-oorsig voor stuur.',
      'draftRequiredControlDispatch':
          'Ontplooiingsantwoorde vir {room} moet hersien word voor stuur.',
      'draftRequiredResidentDispatch':
          'Ontplooiingsopdaterings vir {room} vereis oorsig voor stuur.',
      'draftRequiredDefault': 'Konsep-oorsig is nodig voor stuur.',
      'draftReadyClientDispatch': 'Open kliënt-oorsig vir {room}',
      'draftReadyControlDispatch': 'Open ontplooiing-konsep vir {room}',
      'draftReadyResidentDispatch': 'Open opdatering-konsep vir {room}',
      'draftReadyDefault': 'Konsep gereed',
      'draftOpenedClientDispatch': 'Kliënt-oorsigkonsep vir {room} is oop',
      'draftOpenedControlDispatch': 'Ontplooiing-konsep vir {room} is oop',
      'draftOpenedResidentDispatch':
          'Ontplooiing-opdatering-konsep vir {room} is oop',
      'draftOpenedDefault': 'Konsep geopen',
      'notificationActionClientDispatch': 'Versoek ETA vir {room}',
      'notificationActionClientAdvisory': 'Hersien advies vir {room}',
      'notificationActionClientClosure': 'Hersien afsluiting vir {room}',
      'notificationActionClientDefault': 'Hersien opdatering vir {room}',
      'notificationActionControlDispatch': 'Open ontplooiing vir {room}',
      'notificationActionControlAdvisory': 'Stel advieslog op vir {room}',
      'notificationActionControlClosure': 'Stel afsluitingslog op vir {room}',
      'notificationActionControlDefault': 'Stel opdateringslog op vir {room}',
      'notificationActionResidentDispatch': 'Bekyk waarskuwing vir {room}',
      'notificationActionResidentAdvisory':
          'Stel gemeenskapsadvies op vir {room}',
      'notificationActionResidentClosure':
          'Stel afsluitingsantwoord op vir {room}',
      'notificationActionResidentDefault':
          'Stel opdateringsversoek op vir {room}',
      'notificationSendNowClientAdvisory': 'Stuur advies na {room}',
      'notificationSendNowClientClosure': 'Stuur afsluiting na {room}',
      'notificationSendNowClientDefault': 'Stuur opdatering na {room}',
      'notificationSendNowControlAdvisory': 'Teken advies nou vir {room}',
      'notificationSendNowControlClosure': 'Teken afsluiting nou vir {room}',
      'notificationSendNowControlDefault': 'Teken opdatering nou vir {room}',
      'notificationSendNowResidentAdvisory': 'Plaas advies na {room}',
      'notificationSendNowResidentClosure': 'Plaas afsluiting na {room}',
      'notificationSendNowResidentDefault': 'Plaas opdatering na {room}',
      'notificationSentClientAdvisory': 'Advies gestuur na {room}',
      'notificationSentClientClosure': 'Afsluiting gestuur na {room}',
      'notificationSentClientDefault': 'Opdatering gestuur na {room}',
      'notificationSentControlAdvisory': 'Advieslog geplaas na {room}',
      'notificationSentControlClosure': 'Afsluitingslog geplaas na {room}',
      'notificationSentControlDefault': 'Opdateringslog geplaas na {room}',
      'notificationSentResidentAdvisory': 'Gemeenskapsadvies geplaas na {room}',
      'notificationSentResidentClosure':
          'Afsluitingsantwoord geplaas na {room}',
      'notificationSentResidentDefault': 'Opdateringsversoek geplaas na {room}',
      'notificationDraftClientDispatch':
          'Deel asseblief die nuutste ETA vir {title} in {room}.',
      'notificationDraftClientAdvisory':
          'Kliënt het die advies hersien en is gereed om dit met {room} te deel.',
      'notificationDraftClientClosure':
          'Kliënt het die afsluitingsopdatering vir {room} hersien en ontvangs bevestig.',
      'notificationDraftClientDefault':
          'Kliënt het hierdie opdatering vir {room} hersien en wag op die volgende stap.',
      'notificationDraftControlDispatch':
          'Beheer hersien ontplooiingsreaksie vir {room}.',
      'notificationDraftControlAdvisory':
          'Beheer stel die adviesloginskrywing vir {room} op.',
      'notificationDraftControlClosure':
          'Beheer stel die afsluitingslog vir {room} op.',
      'notificationDraftControlDefault':
          'Beheer stel die operasionele opdateringslog vir {room} op.',
      'notificationDraftResidentDispatch':
          'Inwoner het die waarskuwing in {room} gesien en wag op leiding.',
      'notificationDraftResidentAdvisory':
          'Inwoner stel nou n gemeenskapsadvies vir {room} op.',
      'notificationDraftResidentClosure':
          'Inwoner stel n afsluitingsantwoord vir {room} op.',
      'notificationDraftResidentDefault':
          'Inwoner stel n opdateringsversoek vir {room} op.',
      'pushSyncHistoryEmpty':
          'Stoot-sinkronisering geskiedenis: nog geen pogings.',
      'pushSyncHistoryTitle': 'Stoot-sinkronisering geskiedenis',
      'backendProbeHistoryEmpty':
          'Agterkantsonde geskiedenis: nog geen lopies.',
      'backendProbeHistoryTitle': 'Agterkantsonde geskiedenis',
    },
  };

  static const Map<
    ClientAppLocale,
    Map<String, Map<ClientAppViewerRole, String>>
  >
  _role = {
    ClientAppLocale.zu: {
      'displayLabel': {
        ClientAppViewerRole.client: 'Umbono Wekhasimende',
        ClientAppViewerRole.control: 'Umbono Wokulawula',
        ClientAppViewerRole.resident: 'Umbono Wesakhamuzi',
      },
      'surfaceTitle': {
        ClientAppViewerRole.client: 'Uhlelo Lwamakhasimende',
        ClientAppViewerRole.control: 'Ikhonsoli Yedeski Lokuphepha',
        ClientAppViewerRole.resident: 'Okuphakelayo Kwezakhamuzi',
      },
      'surfaceSubtitle': {
        ClientAppViewerRole.client:
            'Izaziso, amakamelo engxoxo, ukubonakala kwezehlakalo, nokuxhumana okuqondile kwamakhasimende endaweni eyodwa.',
        ClientAppViewerRole.control:
            'Izaziso zedeski lokulawula, ukuvunywa, nezibuyekezo zokuthunyelwa zesiza esisebenzayo.',
        ClientAppViewerRole.resident:
            'Izibuyekezo zokuphepha zezakhamuzi, ukuvunywa, kanye nokwazisa umphakathi ngezehlakalo.',
      },
      'notificationsPanelTitle': {
        ClientAppViewerRole.client: 'Izaziso ze-Push',
        ClientAppViewerRole.control: 'Izaziso Zokulawula',
        ClientAppViewerRole.resident: 'Izibuyekezo Zokuphepha',
      },
      'notificationsPanelSubtitle': {
        ClientAppViewerRole.client:
            'Ukuvuselelwa kwama-alamu, ukufika, ukuvalwa, nezixwayiso zobuhlakani.',
        ClientAppViewerRole.control:
            'Ama-alamu okusebenza, izinguquko zesimo sokuthunyelwa, nezibuyekezo ezibalulekile.',
        ClientAppViewerRole.resident:
            'Izaziso zezehlakalo kubahlali, izexwayiso zesiza, nezixwayiso zokuphepha.',
      },
      'roomsPanelTitle': {
        ClientAppViewerRole.client: 'Amakamelo Esiza',
        ClientAppViewerRole.control: 'Iziteshi Zezithameli',
        ClientAppViewerRole.resident: 'Iziteshi Zomphakathi',
      },
      'incidentFeedPanelTitle': {
        ClientAppViewerRole.client: 'Okuphakelayo Kwezehlakalo',
        ClientAppViewerRole.control: 'Umugqa Wesikhathi Wezehlakalo',
        ClientAppViewerRole.resident: 'Umugqa Wesikhathi Wokuphepha',
      },
      'incidentFeedPanelSubtitle': {
        ClientAppViewerRole.client:
            'Umugqa wesikhathi wokuthunyelwa, ukufika, ukuvalwa, nezixwayiso.',
        ClientAppViewerRole.control:
            'Izigaba zokusebenza nezingxenye zexwayiso emugqeni wesikhathi owodwa.',
        ClientAppViewerRole.resident:
            'Umugqa wesikhathi ophephile wezixwayiso, izimpendulo, nezehlakalo ezixazululiwe.',
      },
      'chatPanelTitle': {
        ClientAppViewerRole.client: 'Ingxoxo Eqondile Yekhasimende',
        ClientAppViewerRole.control: 'Ingxoxo Yokuxhumanisa Ideski',
        ClientAppViewerRole.resident: 'Uchungechunge Lwemilayezo Yezakhamuzi',
      },
      'chatPanelSubtitle': {
        ClientAppViewerRole.client:
            'Uchungechunge oluphephile lokubuyekeza ukusebenza.',
        ClientAppViewerRole.control:
            'Ukuxhumanisa kolawulo nokubuyekeza kwe-ONYX nezivumelwano.',
        ClientAppViewerRole.resident:
            'Uchungechunge lwemilayezo kubahlali oluhambisana nezibuyekezo zokuphepha.',
      },
      'alertsMetricLabel': {
        ClientAppViewerRole.client: 'Izexwayiso Ezingakafundwa',
        ClientAppViewerRole.control: 'Izexwayiso Ezivuliwe',
        ClientAppViewerRole.resident: 'Izexwayiso Ezintsha Zokuphepha',
      },
      'chatMetricLabel': {
        ClientAppViewerRole.client: 'Ingxoxo Eqondile',
        ClientAppViewerRole.control: 'Uchungechunge Ledeski',
        ClientAppViewerRole.resident: 'Uchungechunge Lwemilayezo',
      },
      'pendingMetricLabel': {
        ClientAppViewerRole.client: 'Ukuvunywa Kwekhasimende Okulindile',
        ClientAppViewerRole.control: 'Ukuvunywa Kolawulo Okulindile',
        ClientAppViewerRole.resident: 'Okuveziwe Kubahlali Okulindile',
      },
      'roomsPanelSubtitle': {
        ClientAppViewerRole.client:
            'Abahlali, abaphathiswa, neziteshi zedeski lokuphepha.',
        ClientAppViewerRole.control:
            'Buka imigudu yokuvuma elindile kubahlali, abaphathiswa, nasedeski.',
        ClientAppViewerRole.resident:
            'Ukuhamba kwemiyalezo kwabahlali, abaphathiswa, nolawulo.',
      },
    },
    ClientAppLocale.af: {
      'displayLabel': {
        ClientAppViewerRole.client: 'Kliënt-aansig',
        ClientAppViewerRole.control: 'Beheer-aansig',
        ClientAppViewerRole.resident: 'Inwoner-aansig',
      },
      'surfaceTitle': {
        ClientAppViewerRole.client: 'Kliënt Operasies',
        ClientAppViewerRole.control: 'Sekuriteitstoonbank Konsole',
        ClientAppViewerRole.resident: 'Inwoner Landgoedvoer',
      },
      'surfaceSubtitle': {
        ClientAppViewerRole.client:
            'Drukwaarskuwings, landgoed-kletskamers, voorvalsigbaarheid en direkte kliëntkommunikasie op een oppervlak.',
        ClientAppViewerRole.control:
            'Beheergerigte waarskuwings, bevestigings en ontplooiingsopdaterings vir aktiewe terreinreaksie.',
        ClientAppViewerRole.resident:
            'Inwonergerigte veiligheidsopdaterings, bevestigings en gemeenskapsbewustheid van voorvalle.',
      },
      'notificationsPanelTitle': {
        ClientAppViewerRole.client: 'Stootkennisgewings',
        ClientAppViewerRole.control: 'Beheerwaarskuwings',
        ClientAppViewerRole.resident: 'Veiligheidsopdaterings',
      },
      'notificationsPanelSubtitle': {
        ClientAppViewerRole.client:
            'Alarmsnellers, aankomste, afsluitings en intelligensie-kennisgewings.',
        ClientAppViewerRole.control:
            'Operasionele alarms, ontplooiingstatusveranderings en reaksie-kritieke opdaterings.',
        ClientAppViewerRole.resident:
            'Inwonergerigte voorvalkennisgewings, landgoedwaarskuwings en veiligheidsadvies.',
      },
      'roomsPanelTitle': {
        ClientAppViewerRole.client: 'Landgoed-kamers',
        ClientAppViewerRole.control: 'Teikenkanaal-groepe',
        ClientAppViewerRole.resident: 'Landgoed-kanale',
      },
      'incidentFeedPanelTitle': {
        ClientAppViewerRole.client: 'Voorvalvoer',
        ClientAppViewerRole.control: 'Aktiewe Voorvaltydlyn',
        ClientAppViewerRole.resident: 'Veiligheidstydlyn',
      },
      'incidentFeedPanelSubtitle': {
        ClientAppViewerRole.client:
            'Chronologiese ontplooiing, aankoms, afsluiting en adviesmylpale.',
        ClientAppViewerRole.control:
            'Operasionele voorvalmylpale en advieskontrolepunte op een tydlyn.',
        ClientAppViewerRole.resident:
            'Inwonerveilige tydlyn van waarskuwings, reaksies en opgeloste voorvalle.',
      },
      'chatPanelTitle': {
        ClientAppViewerRole.client: 'Direkte Kliëntklets',
        ClientAppViewerRole.control: 'Toonbank-koördinasiedraad',
        ClientAppViewerRole.resident: 'Inwoner-boodskapdraad',
      },
      'chatPanelSubtitle': {
        ClientAppViewerRole.client:
            'Veilige kliëntdraad met operasionele opdaterings.',
        ClientAppViewerRole.control:
            'Beheer-kant koördinasie met gespieëlde ONYX-opdaterings en bevestigings.',
        ClientAppViewerRole.resident:
            'Inwonergerigte boodskapstroom met gespieëlde veiligheidsopdaterings.',
      },
      'alertsMetricLabel': {
        ClientAppViewerRole.client: 'Ongeleesde Waarskuwings',
        ClientAppViewerRole.control: 'Oop Waarskuwings',
        ClientAppViewerRole.resident: 'Nuwe Veiligheidswaarskuwings',
      },
      'chatMetricLabel': {
        ClientAppViewerRole.client: 'Direkte Klets',
        ClientAppViewerRole.control: 'Toonbankdraad',
        ClientAppViewerRole.resident: 'Boodskapdraad',
      },
      'pendingMetricLabel': {
        ClientAppViewerRole.client: 'Kliënt-bevestigings hangende',
        ClientAppViewerRole.control: 'Beheer-bevestigings hangende',
        ClientAppViewerRole.resident: 'Inwoner gesien hangende',
      },
      'roomsPanelSubtitle': {
        ClientAppViewerRole.client: 'Inwoners, trustees en beheerkanaalstrome.',
        ClientAppViewerRole.control:
            'Sien hangende bevestigingsbane oor inwoners, trustees en toonbankreaksie.',
        ClientAppViewerRole.resident:
            'Inwoner-, trustee- en beheerstrome vir landgoedkommunikasie.',
      },
    },
  };

  static String generalText({
    required ClientAppLocale locale,
    required String key,
    required String fallback,
  }) {
    return _general[locale]?[key] ?? fallback;
  }

  static String roleText({
    required ClientAppLocale locale,
    required String key,
    required ClientAppViewerRole role,
    required String fallback,
  }) {
    return _role[locale]?[key]?[role] ?? fallback;
  }

  static Set<String> generalKeysForLocale(ClientAppLocale locale) {
    final keys = _general[locale]?.keys;
    if (keys == null) {
      return const <String>{};
    }
    return Set<String>.unmodifiable(keys);
  }

  static Set<String> roleKeysForLocale(ClientAppLocale locale) {
    final keys = _role[locale]?.keys;
    if (keys == null) {
      return const <String>{};
    }
    return Set<String>.unmodifiable(keys);
  }

  static Set<ClientAppViewerRole> rolesForLocaleKey(
    ClientAppLocale locale,
    String key,
  ) {
    final roles = _role[locale]?[key]?.keys;
    if (roles == null) {
      return const <ClientAppViewerRole>{};
    }
    return Set<ClientAppViewerRole>.unmodifiable(roles);
  }
}

class ClientAppMessage {
  final String author;
  final String body;
  final DateTime occurredAt;
  final String roomKey;
  final String viewerRole;
  final String incidentStatusLabel;
  final String messageSource;
  final String messageProvider;

  ClientAppMessage({
    required this.author,
    required this.body,
    required this.occurredAt,
    this.roomKey = 'Residents',
    this.viewerRole = 'client',
    this.incidentStatusLabel = 'Update',
    this.messageSource = 'in_app',
    this.messageProvider = 'in_app',
  });

  factory ClientAppMessage.fromJson(Map<String, Object?> json) {
    final occurredAtValue = json['occurredAt']?.toString();
    return ClientAppMessage(
      author: json['author']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      roomKey: json['roomKey']?.toString() ?? 'Residents',
      viewerRole: json['viewerRole']?.toString() ?? 'client',
      incidentStatusLabel: json['incidentStatusLabel']?.toString() ?? 'Update',
      messageSource: json['messageSource']?.toString() ?? 'in_app',
      messageProvider: json['messageProvider']?.toString() ?? 'in_app',
      occurredAt:
          DateTime.tryParse(occurredAtValue ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'author': author,
      'body': body,
      'roomKey': roomKey,
      'viewerRole': viewerRole,
      'incidentStatusLabel': incidentStatusLabel,
      'messageSource': messageSource,
      'messageProvider': messageProvider,
      'occurredAt': occurredAt.toUtc().toIso8601String(),
    };
  }
}

class ClientAppDraft {
  final ClientAppViewerRole viewerRole;
  final String selectedRoom;
  final Map<String, String> selectedRoomByRole;
  final Map<String, bool> showAllRoomItemsByRole;
  final String? expandedIncidentReference;
  final bool hasTouchedIncidentExpansion;
  final Map<String, String> selectedIncidentReferenceByRole;
  final Map<String, String> expandedIncidentReferenceByRole;
  final Map<String, bool> hasTouchedIncidentExpansionByRole;
  final Map<String, String> focusedIncidentReferenceByRole;
  final List<ClientAppMessage> _legacyManualMessages;
  final List<ClientAppAcknowledgement> _legacyAcknowledgements;

  const ClientAppDraft({
    this.viewerRole = ClientAppViewerRole.client,
    required this.selectedRoom,
    this.selectedRoomByRole = const {},
    this.showAllRoomItemsByRole = const {},
    this.expandedIncidentReference,
    this.hasTouchedIncidentExpansion = false,
    this.selectedIncidentReferenceByRole = const {},
    this.expandedIncidentReferenceByRole = const {},
    this.hasTouchedIncidentExpansionByRole = const {},
    this.focusedIncidentReferenceByRole = const {},
    List<ClientAppMessage> legacyManualMessages = const [],
    List<ClientAppAcknowledgement> legacyAcknowledgements = const [],
  }) : _legacyManualMessages = legacyManualMessages,
       _legacyAcknowledgements = legacyAcknowledgements;

  factory ClientAppDraft.fromJson(Map<String, Object?> json) {
    final rawMessages = json['manualMessages'];
    final rawAcknowledgements = json['acknowledgements'];
    final rawSelectedRoomByRole = json['selectedRoomByRole'];
    final rawShowAllByRole = json['showAllRoomItemsByRole'];
    final rawSelectedIncidentByRole = json['selectedIncidentReferenceByRole'];
    final rawExpandedIncidentByRole = json['expandedIncidentReferenceByRole'];
    final rawTouchedExpansionByRole = json['hasTouchedIncidentExpansionByRole'];
    final rawFocusedIncidentByRole = json['focusedIncidentReferenceByRole'];
    final manualMessages = rawMessages is List
        ? rawMessages
              .whereType<Map>()
              .map(
                (item) => ClientAppMessage.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .where((message) => message.body.trim().isNotEmpty)
              .toList(growable: false)
        : const <ClientAppMessage>[];
    final acknowledgements = rawAcknowledgements is List
        ? rawAcknowledgements
              .whereType<Map>()
              .map(
                (item) => ClientAppAcknowledgement.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .where((item) => item.messageKey.trim().isNotEmpty)
              .toList(growable: false)
        : const <ClientAppAcknowledgement>[];
    final selectedRoomByRole = rawSelectedRoomByRole is Map
        ? rawSelectedRoomByRole.map(
            (key, value) =>
                MapEntry(key.toString(), value?.toString() ?? 'Residents'),
          )
        : <String, String>{
            ClientAppViewerRole.client.name:
                json['selectedRoom']?.toString() ?? 'Residents',
          };
    final showAllRoomItemsByRole = rawShowAllByRole is Map
        ? rawShowAllByRole.map(
            (key, value) => MapEntry(key.toString(), value == true),
          )
        : <String, bool>{
            ClientAppViewerRole.client.name: json['showAllRoomItems'] == true,
          };
    final selectedIncidentReferenceByRole = rawSelectedIncidentByRole is Map
        ? (() {
            final map = rawSelectedIncidentByRole.map(
              (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
            );
            map.removeWhere((key, value) => value.trim().isEmpty);
            return map;
          })()
        : const <String, String>{};
    final expandedIncidentReferenceByRole = rawExpandedIncidentByRole is Map
        ? (() {
            final map = rawExpandedIncidentByRole.map(
              (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
            );
            map.removeWhere((key, value) => value.trim().isEmpty);
            return map;
          })()
        : <String, String>{
            if ((json['expandedIncidentReference']?.toString() ?? '')
                .trim()
                .isNotEmpty)
              ClientAppViewerRole.client.name:
                  json['expandedIncidentReference']!.toString(),
          };
    final hasTouchedIncidentExpansionByRole = rawTouchedExpansionByRole is Map
        ? rawTouchedExpansionByRole.map(
            (key, value) => MapEntry(key.toString(), value == true),
          )
        : <String, bool>{
            ClientAppViewerRole.client.name:
                json['hasTouchedIncidentExpansion'] == true,
          };
    final focusedIncidentReferenceByRole = rawFocusedIncidentByRole is Map
        ? (() {
            final map = rawFocusedIncidentByRole.map(
              (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
            );
            map.removeWhere((key, value) => value.trim().isEmpty);
            return map;
          })()
        : const <String, String>{};
    return ClientAppDraft(
      viewerRole: ClientAppViewerRole.values.firstWhere(
        (value) => value.name == json['viewerRole']?.toString(),
        orElse: () => ClientAppViewerRole.client,
      ),
      selectedRoom: json['selectedRoom']?.toString() ?? 'Residents',
      selectedRoomByRole: selectedRoomByRole,
      showAllRoomItemsByRole: showAllRoomItemsByRole,
      expandedIncidentReference:
          json['expandedIncidentReference']?.toString().trim().isEmpty == true
          ? null
          : json['expandedIncidentReference']?.toString(),
      hasTouchedIncidentExpansion: json['hasTouchedIncidentExpansion'] == true,
      selectedIncidentReferenceByRole: selectedIncidentReferenceByRole,
      expandedIncidentReferenceByRole: expandedIncidentReferenceByRole,
      hasTouchedIncidentExpansionByRole: hasTouchedIncidentExpansionByRole,
      focusedIncidentReferenceByRole: focusedIncidentReferenceByRole,
      legacyManualMessages: manualMessages,
      legacyAcknowledgements: acknowledgements,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'viewerRole': viewerRole.name,
      'selectedRoom': selectedRoom,
      'selectedRoomByRole': selectedRoomByRole,
      'showAllRoomItems': showAllRoomItems,
      'showAllRoomItemsByRole': showAllRoomItemsByRole,
      'expandedIncidentReference': expandedIncidentReference,
      'hasTouchedIncidentExpansion': hasTouchedIncidentExpansion,
      'selectedIncidentReferenceByRole': selectedIncidentReferenceByRole,
      'expandedIncidentReferenceByRole': expandedIncidentReferenceByRole,
      'hasTouchedIncidentExpansionByRole': hasTouchedIncidentExpansionByRole,
      'focusedIncidentReferenceByRole': focusedIncidentReferenceByRole,
    };
  }

  List<ClientAppMessage> get legacyManualMessages {
    return List<ClientAppMessage>.unmodifiable(_legacyManualMessages);
  }

  List<ClientAppAcknowledgement> get legacyAcknowledgements {
    return List<ClientAppAcknowledgement>.unmodifiable(_legacyAcknowledgements);
  }

  bool get showAllRoomItems => showAllRoomItemsFor(ClientAppViewerRole.client);

  String selectedRoomFor(ClientAppViewerRole role) {
    return selectedRoomByRole[role.name] ?? selectedRoom;
  }

  String? expandedIncidentReferenceFor(ClientAppViewerRole role) {
    return expandedIncidentReferenceByRole[role.name] ??
        expandedIncidentReference;
  }

  String? selectedIncidentReferenceFor(ClientAppViewerRole role) {
    return selectedIncidentReferenceByRole[role.name];
  }

  bool hasTouchedIncidentExpansionFor(ClientAppViewerRole role) {
    return hasTouchedIncidentExpansionByRole[role.name] ??
        hasTouchedIncidentExpansion;
  }

  bool showAllRoomItemsFor(ClientAppViewerRole role) {
    return showAllRoomItemsByRole[role.name] == true;
  }
}

String _timeLabel(DateTime value) {
  final utc = value.toUtc();
  final hour = utc.hour.toString().padLeft(2, '0');
  final minute = utc.minute.toString().padLeft(2, '0');
  return '$hour:$minute UTC';
}
