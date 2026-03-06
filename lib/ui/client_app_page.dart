import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../domain/events/decision_created.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/incident_closed.dart';
import '../domain/events/intelligence_received.dart';
import '../domain/events/response_arrived.dart';
import 'onyx_surface.dart';

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
    this.onClientStateChanged,
    this.onPushQueueChanged,
  });

  @override
  State<ClientAppPage> createState() => _ClientAppPageState();
}

class _ClientAppPageState extends State<ClientAppPage> {
  static const int _maxNotificationRows = 12;
  static const int _maxPushQueueRows = 6;
  static const int _maxIncidentFeedRows = 8;
  static const int _maxChatRows = 40;
  static const int _maxRoomRows = 12;

  final TextEditingController _chatController = TextEditingController();
  final FocusNode _chatFocusNode = FocusNode();
  final GlobalKey _chatComposerKey = GlobalKey();
  final GlobalKey _chatThreadKey = GlobalKey();
  bool _showComposerLandingHighlight = false;
  String? _draftOpenedMessageKey;
  String? _sentNotificationMessageKey;
  String? _sentThreadMessageKey;
  String? _threadLandingMessageKey;
  _ClientSystemMessageType? _composedSystemType;
  String? _focusedIncidentReference;
  String? _selectedIncidentReference;
  late final List<ClientAppMessage> _manualMessages;
  late final List<ClientAppAcknowledgement> _acknowledgements;
  late ClientAppViewerRole _viewerRole;
  late Map<String, String> _selectedRoomByRole;
  late Map<String, bool> _showAllRoomItemsByRole;
  late Map<String, String> _selectedIncidentReferenceByRole;
  late Map<String, String> _expandedIncidentReferenceByRole;
  late Map<String, bool> _hasTouchedIncidentExpansionByRole;
  late Map<String, String> _focusedIncidentReferenceByRole;

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
  }

  @override
  void dispose() {
    _chatController.dispose();
    _chatFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewerChannel = _viewerRole.acknowledgementChannel;
    final clientEvents = _currentClientEvents();

    final notifications = _buildNotifications(clientEvents);
    final incidentFeed = _buildIncidentFeed(clientEvents);
    final computedPushQueue = _buildPushQueue(notifications);
    final pushQueue = computedPushQueue.isNotEmpty
        ? computedPushQueue
        : _mergeStoredPushQueueWithAcknowledgements(widget.initialPushQueue);
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

    return OnyxPageScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1540),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_localizedSurfaceTitle(_viewerRole)} — ${widget.clientId} / ${widget.siteId}',
                  style: GoogleFonts.rajdhani(
                    color: const Color(0xFFE5F1FF),
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _localizedSurfaceSubtitle(_viewerRole),
                  style: GoogleFonts.inter(
                    color: const Color(0xFF93A8C9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF0C2342).withValues(alpha: 0.9),
                        const Color(0xFF09172E).withValues(alpha: 0.94),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: widget.backendSyncEnabled
                          ? const Color(0xFF3D8BFF).withValues(alpha: 0.45)
                          : const Color(0xFF35506F).withValues(alpha: 0.38),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.backendSyncEnabled
                                ? Icons.cloud_done_rounded
                                : Icons.storage_rounded,
                            size: 16,
                            color: widget.backendSyncEnabled
                                ? const Color(0xFF8FD1FF)
                                : const Color(0xFF93A8C9),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.backendSyncEnabled
                                ? _localizedConversationSyncLive
                                : _localizedConversationSyncLocal,
                            style: GoogleFonts.inter(
                              color: const Color(0xFFD6E8FF),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      if (!widget.backendSyncEnabled) ...[
                        const SizedBox(height: 6),
                        Text(
                          _localizedRunWithLocalDefines,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF93A8C9),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _localizedLanguageLabel,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF7FA2CF),
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
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1500
                        ? 6
                        : constraints.maxWidth >= 1200
                        ? 3
                        : constraints.maxWidth >= 760
                        ? 2
                        : 1;
                    const spacing = 12.0;
                    final cardWidth =
                        (constraints.maxWidth - ((columns - 1) * spacing)) /
                        columns;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _metricCard(
                            _viewerRole.alertsMetricLabelForLocale(
                              widget.locale,
                            ),
                            unreadNotifications.toString(),
                            const Color(0xFFFFD6A5),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _metricCard(
                            _localizedActiveIncidentsLabel,
                            activeDispatches.toString(),
                            const Color(0xFFFFA7B8),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _metricCard(
                            _localizedEstateRoomsLabel,
                            rooms.length.toString(),
                            const Color(0xFF9FD8AC),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _metricCard(
                            _viewerRole.chatMetricLabelForLocale(widget.locale),
                            '${chatMessages.length} updates',
                            const Color(0xFF8FD1FF),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _metricCard(
                            _viewerRole.pendingMetricLabelForLocale(
                              widget.locale,
                            ),
                            pendingAcknowledgements.toString(),
                            const Color(0xFFC9B8FF),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _metricCard(
                            _localizedPushQueueReadyLabel,
                            pushReadyCount.toString(),
                            const Color(0xFFFFB5C6),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                _panel(
                  title: _localizedPushDeliveryQueueTitle,
                  subtitle: _localizedPushDeliveryQueueSubtitle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _pushSyncStatusStrip(),
                      const SizedBox(height: 10),
                      _backendProbeHistoryList(widget.backendProbeHistory),
                      const SizedBox(height: 10),
                      _pushSyncHistoryList(widget.pushSyncHistory),
                      const SizedBox(height: 10),
                      _pushQueueList(pushQueue),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _panel(
                  title: _viewerRole.incidentFeedPanelTitleForLocale(
                    widget.locale,
                  ),
                  subtitle: _viewerRole.incidentFeedPanelSubtitleForLocale(
                    widget.locale,
                  ),
                  subtitleAction: selectedIncidentGroup == null
                      ? null
                      : TextButton(
                          onPressed: () =>
                              _reopenSelectedIncidentThread(incidentFeed),
                          style: _inlineHandoffButtonStyle(
                            const Color(0xFF8FD1FF),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _viewerRole.selectedIncidentHeaderIcon,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
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
                  headerAction: selectedIncidentGroup == null
                      ? TextButton(
                          onPressed: null,
                          style: _inlineHandoffButtonStyle(
                            const Color(0xFF8FD1FF),
                            disabledForegroundColor: const Color(0xFF5B7294),
                          ),
                          child: Text(
                            _viewerRole.noSelectedIncidentLabel,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : null,
                  child: _incidentFeedList(incidentFeed),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        filterScopeLabel,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF8FD1FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _toggleShowAllRoomItems,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: const Color(0xFF8FD1FF),
                      ),
                      child: Text(
                        showAllRoomItems
                            ? _localizedShowPendingLabel
                            : _localizedShowAllLabel,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1400
                        ? 3
                        : constraints.maxWidth >= 980
                        ? 2
                        : 1;
                    const spacing = 12.0;
                    final cardWidth =
                        (constraints.maxWidth - ((columns - 1) * spacing)) /
                        columns;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _panel(
                            title: _viewerRole.notificationsPanelTitleForLocale(
                              widget.locale,
                            ),
                            subtitle: _notificationsPanelSubtitle(
                              showAllRoomItems: showAllRoomItems,
                              roomDisplayName: activeRoom.displayName,
                            ),
                            child: _notificationsList(
                              visibleNotificationRows,
                              totalCount: visibleNotifications.length,
                              hiddenCount: hiddenNotificationRows,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _panel(
                            title: _viewerRole.roomsPanelTitleForLocale(
                              widget.locale,
                            ),
                            subtitle: _roomsPanelSubtitle(
                              showAllRoomItems: showAllRoomItems,
                              roomDisplayName: activeRoom.displayName,
                            ),
                            child: _roomsList(rooms),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _panel(
                            title: _viewerRole.chatPanelTitleForLocale(
                              widget.locale,
                            ),
                            subtitle: _chatPanelSubtitle(
                              showAllRoomItems: showAllRoomItems,
                              roomDisplayName: activeRoom.displayName,
                            ),
                            child: _chatPanel(chatMessages),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metricCard(String label, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1A2D), Color(0xFF0A1628)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF183657)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 8),
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
              color: const Color(0xFF8EA7C8),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.rajdhani(
              color: accent,
              fontSize: 30,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewerRoleChip(ClientAppViewerRole role) {
    final selected = role == _viewerRole;
    return OutlinedButton(
      onPressed: () => _setViewerRole(role),
      style: OutlinedButton.styleFrom(
        foregroundColor: selected
            ? const Color(0xFF021229)
            : const Color(0xFFAFC8EB),
        backgroundColor: selected
            ? const Color(0xFF8FD1FF)
            : const Color(0xFF09172D),
        side: BorderSide(
          color: selected ? const Color(0xFF8FD1FF) : const Color(0xFF21456E),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: selected ? 2 : 0,
        shadowColor: const Color(0x14000000),
      ),
      child: Text(
        role.displayLabelForLocale(widget.locale),
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _panel({
    required String title,
    required String subtitle,
    Widget? subtitleAction,
    Widget? headerAction,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF081326), Color(0xFF0A172C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF193758)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x15000000),
            blurRadius: 18,
            offset: Offset(0, 10),
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
              color: const Color(0xFF3C79BB),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFE5F1FF),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              headerAction ?? const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA7C8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitleAction != null) ...[
            const SizedBox(height: 4),
            subtitleAction,
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _notificationsList(
    List<_ClientNotification> items, {
    required int totalCount,
    required int hiddenCount,
  }) {
    if (items.isEmpty) {
      return _emptyBox(_viewerRole.notificationsEmptyLabel);
    }
    return SizedBox(
      height: 360,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        item.systemType.cardFillColor,
                        item.systemType.cardFillColor.withValues(alpha: 0.82),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: item.priority
                          ? item.systemType.priorityBorderColor
                          : item.systemType.cardBorderColor,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 10,
                        offset: Offset(0, 6),
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
                            item.priority
                                ? const Color(0xFFFFD3D8)
                                : const Color(0xFFB9D9FF),
                            item.priority
                                ? const Color(0xFF8A3D4A)
                                : const Color(0xFF274E7E),
                          ),
                          _pill(
                            _notificationTargetBadgeLabel(),
                            const Color(0xFFCBE6FF),
                            const Color(0xFF35679B),
                          ),
                          Text(
                            item.timeLabel,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF7FA8D5),
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
                                color: const Color(0xFFE5F1FF),
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
                          color: const Color(0xFF9AB4D8),
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
                          style: _inlineHandoffButtonStyle(
                            item.systemType.textColor,
                          ),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                _notificationSentLabelFor(item.systemType),
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFB9E2FF),
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
                                color: const Color(0xFF9AB4D8),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  _focusDraftNotificationAction(item),
                              style: _inlineHandoffButtonStyle(
                                item.systemType.textColor,
                              ),
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
                                  color: const Color(0xFFB9E2FF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      _acknowledgementControls(
                        item.messageKey,
                        item.acknowledgements,
                      ),
                    ],
                  ),
                );
              },
              separatorBuilder: (_, _) => const SizedBox(height: 10),
            ),
          ),
          if (hiddenCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Showing ${items.length} of $totalCount notifications. $hiddenCount older rows hidden.',
              style: GoogleFonts.inter(
                color: const Color(0xFF87A5C8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pushQueueList(List<ClientAppPushDeliveryItem> items) {
    if (items.isEmpty) {
      return _emptyBox(_localizedNoPushNotificationsQueuedYet);
    }
    final visibleItems = items.take(_maxPushQueueRows).toList(growable: false);
    final hiddenItems = items.length - visibleItems.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...visibleItems.map(
          (item) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0B182C),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: item.status == ClientPushDeliveryStatus.queued
                    ? const Color(0xFFB94C63)
                    : const Color(0xFF2D6A46),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFE5F1FF),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.body,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF9DB3CF),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$_localizedTargetPrefix: ${item.targetChannel.displayLabel} • ${item.timeLabel}',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF7FA2C9),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: item.status == ClientPushDeliveryStatus.queued
                        ? const Color(0x332D6A46)
                        : const Color(0x331F5E83),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: item.status == ClientPushDeliveryStatus.queued
                          ? const Color(0xFF9FD8AC)
                          : const Color(0xFF8FD1FF),
                    ),
                  ),
                  child: Text(
                    item.status == ClientPushDeliveryStatus.queued
                        ? _localizedQueuedStatus
                        : _localizedDeliveredStatus,
                    style: GoogleFonts.inter(
                      color: item.status == ClientPushDeliveryStatus.queued
                          ? const Color(0xFF9FD8AC)
                          : const Color(0xFF8FD1FF),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hiddenItems > 0)
          Text(
            'Showing ${visibleItems.length} of ${items.length} queue rows. $hiddenItems older rows hidden.',
            style: GoogleFonts.inter(
              color: const Color(0xFF87A5C8),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  Widget _pushSyncStatusStrip() {
    final lastSyncedLabel = widget.pushSyncLastSyncedAtUtc == null
        ? 'none'
        : _timeLabel(widget.pushSyncLastSyncedAtUtc!.toUtc());
    final failureReason = (widget.pushSyncFailureReason ?? '').trim();
    final probeFailureReason = (widget.backendProbeFailureReason ?? '').trim();
    final probeLastRunLabel = widget.backendProbeLastRunAtUtc == null
        ? 'none'
        : _timeLabel(widget.backendProbeLastRunAtUtc!.toUtc());
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1423),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1D3551)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _localizedPushSyncStatusLine(widget.pushSyncStatusLabel),
            style: GoogleFonts.inter(
              color: const Color(0xFF8FD1FF),
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
              color: const Color(0xFF9DB3CF),
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
              color: const Color(0xFF9DB3CF),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (failureReason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _localizedFailureLine(failureReason),
              style: GoogleFonts.inter(
                color: const Color(0xFFFFB5C6),
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
                color: const Color(0xFFFFB5C6),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (widget.onRetryPushSync != null) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: () async {
                await widget.onRetryPushSync!.call();
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: const Color(0xFF8FD1FF),
              ),
              child: Text(
                _localizedRetryPushSyncLabel,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          if (widget.onRunBackendProbe != null) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: () async {
                await widget.onRunBackendProbe!.call();
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: const Color(0xFF9FD8AC),
              ),
              child: Text(
                _localizedRunBackendProbeLabel,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          if (widget.onClearBackendProbeHistory != null) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: () async {
                final shouldClear = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) {
                    return AlertDialog(
                      backgroundColor: const Color(0xFF0A1423),
                      title: Text(
                        _localizedClearProbeHistoryTitle,
                        style: GoogleFonts.rajdhani(
                          color: const Color(0xFFE5F1FF),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      content: Text(
                        _localizedClearProbeHistoryBody,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF9DB3CF),
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
                              color: const Color(0xFF8FD1FF),
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
                              color: const Color(0xFFFFD6A5),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
                if (shouldClear == true) {
                  await widget.onClearBackendProbeHistory!.call();
                }
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: const Color(0xFFFFD6A5),
              ),
              child: Text(
                _localizedClearProbeHistoryButton,
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

  Widget _pushSyncHistoryList(List<ClientPushSyncAttempt> history) {
    if (history.isEmpty) {
      return Text(
        _localizedPushSyncHistoryEmpty,
        style: GoogleFonts.inter(
          color: const Color(0xFF7FA2C9),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    final rows = history.take(5).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _localizedPushSyncHistoryTitle,
          style: GoogleFonts.inter(
            color: const Color(0xFF8FD1FF),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        ...rows.map(
          (attempt) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              attempt.summaryLine,
              style: GoogleFonts.inter(
                color: const Color(0xFF9DB3CF),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _backendProbeHistoryList(List<ClientBackendProbeAttempt> history) {
    if (history.isEmpty) {
      return Text(
        _localizedBackendProbeHistoryEmpty,
        style: GoogleFonts.inter(
          color: const Color(0xFF7FA2C9),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    final rows = history.take(5).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _localizedBackendProbeHistoryTitle,
          style: GoogleFonts.inter(
            color: const Color(0xFF9FD8AC),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        ...rows.map(
          (attempt) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              attempt.summaryLine,
              style: GoogleFonts.inter(
                color: const Color(0xFF9DB3CF),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _roomsList(List<_ClientRoom> rooms) {
    final visibleRooms = rooms.take(_maxRoomRows).toList(growable: false);
    final hiddenRooms = rooms.length - visibleRooms.length;
    return SizedBox(
      height: 360,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView.separated(
              itemCount: visibleRooms.length,
              itemBuilder: (context, index) {
                final room = visibleRooms[index];
                final selected = room.key == _selectedRoomFor(_viewerRole);
                return InkWell(
                  onTap: () => _setSelectedRoom(room.key),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: selected
                            ? const [Color(0xFF14345A), Color(0xFF102947)]
                            : const [Color(0xFF0E1C34), Color(0xFF0A1628)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF3E7BFF)
                            : const Color(0xFF1F416A),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x10000000),
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
                                  color: const Color(0xFFE5F1FF),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            _pill(
                              '${room.unread} unread',
                              const Color(0xFFB9D9FF),
                              const Color(0xFF274E7E),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          room.summary,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF9AB4D8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              separatorBuilder: (_, _) => const SizedBox(height: 10),
            ),
          ),
          if (hiddenRooms > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Showing ${visibleRooms.length} of ${rooms.length} rooms. $hiddenRooms additional rooms hidden.',
              style: GoogleFonts.inter(
                color: const Color(0xFF87A5C8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _incidentFeedList(List<_ClientIncidentFeedGroup> items) {
    if (items.isEmpty) {
      return _emptyBox(_viewerRole.incidentFeedEmptyLabel);
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
    return SizedBox(
      height: 220,
      child: ListView.separated(
        itemCount: visibleItems.length,
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
              onTap: () => _toggleIncidentFeedExpansion(group.referenceLabel),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1B33),
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
                              color: const Color(0xFFB9D9FF),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          _pill(
                            _viewerRole.incidentCountLabel(
                              group.entries.length,
                            ),
                            const Color(0xFFC9B8FF),
                            const Color(0xFF6950A8),
                          ),
                        ] else
                          _pill(
                            _viewerRole.incidentReferenceCountDisplayLabel(
                              group.referenceLabel,
                              group.entries.length,
                            ),
                            const Color(0xFFC9B8FF),
                            const Color(0xFF6950A8),
                          ),
                        if (selected)
                          _pill(
                            _viewerRole.selectedIncidentLabel,
                            const Color(0xFFAEDBFF),
                            const Color(0xFF4A86C7),
                          ),
                        if (expanded)
                          _pill(
                            _viewerRole.expandedIncidentLabel,
                            const Color(0xFFD7CCFF),
                            const Color(0xFF5F4AA8),
                          ),
                        if (focused)
                          _pill(
                            _viewerRole.focusedIncidentLabel,
                            const Color(0xFFD7F0FF),
                            const Color(0xFF5EA8FF),
                          ),
                        Text(
                          _viewerRole.incidentTimeDisplayLabel(item.timeLabel),
                          style: GoogleFonts.inter(
                            color: const Color(0xFF7FA8D5),
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
                        color: const Color(0xFFE5F1FF),
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
                        color: const Color(0xFF9AB4D8),
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
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0B182B), Color(0xFF091423)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF17324F)),
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
      ),
    );
  }

  Widget _chatPanel(List<_ClientChatMessage> messages) {
    final visibleMessages = messages.take(_maxChatRows).toList(growable: false);
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D1A2E), Color(0xFF0A1425)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1D3A61)),
          ),
          child: Text(
            'Room Focus: ${_activeRoomLabel()}',
            style: GoogleFonts.inter(
              color: const Color(0xFFE5F1FF),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (_threadLandingMessageKey != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: _pill(
              _threadJumpedLabel(),
              const Color(0xFFB9E2FF),
              const Color(0xFF8FD1FF),
            ),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          key: _chatThreadKey,
          height: 276,
          child: visibleMessages.isEmpty
              ? _emptyBox(_viewerRole.chatEmptyLabel)
              : ListView.separated(
                  itemCount: visibleMessages.length,
                  itemBuilder: (context, index) {
                    final message = visibleMessages[index];
                    final highlightedThreadMessage =
                        message.messageKey == _threadLandingMessageKey;
                    final incomingSystemType = message.outgoing
                        ? null
                        : message.systemType;
                    final incomingBubbleFillColor =
                        incomingSystemType?.cardFillColor ??
                        const Color(0xFF0D1B33);
                    final incomingBubbleBorderColor =
                        incomingSystemType?.cardBorderColor ??
                        const Color(0xFF1F416A);
                    final incomingBubbleMetaColor =
                        incomingSystemType?.textColor ??
                        const Color(0xFF7FA8D5);
                    return Align(
                      alignment: message.outgoing
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 320),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: message.outgoing
                              ? (highlightedThreadMessage
                                    ? _threadLandingBubbleFillColor()
                                    : _viewerRole.outgoingBubbleFillColor)
                              : incomingBubbleFillColor,
                          borderRadius: BorderRadius.circular(14),
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
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              message.body,
                              style: GoogleFonts.inter(
                                color: const Color(0xFFE5F1FF),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (!message.outgoing) ...[
                              const SizedBox(height: 8),
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
                ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _viewerRole
              .quickActionTemplatesFor(_selectedRoomFor(_viewerRole))
              .map(
                (template) => OutlinedButton(
                  onPressed: () => _applyQuickAction(template),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB9D9FF),
                    side: const BorderSide(color: Color(0xFF274E7E)),
                    backgroundColor: const Color(0xFF0B182C),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    shadowColor: const Color(0x10000000),
                  ),
                  child: Text(
                    template,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 12),
        _manualIncidentTypeSelector(),
        const SizedBox(height: 12),
        Row(
          key: _chatComposerKey,
          children: [
            Expanded(
              child: TextField(
                controller: _chatController,
                focusNode: _chatFocusNode,
                style: GoogleFonts.inter(color: const Color(0xFFE5F1FF)),
                decoration: InputDecoration(
                  hintText: _viewerRole.chatComposerHintFor(
                    _selectedRoomFor(_viewerRole),
                  ),
                  hintStyle: GoogleFonts.inter(
                    color: const Color(0xFF6D86AA),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
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
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _composerStatusBadge(),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _sendClientMessage,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1F66FF),
                    foregroundColor: const Color(0xFFEAF3FF),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    elevation: 0,
                    shadowColor: const Color(0x14000000),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _chatSendButtonLabel(),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _manualIncidentTypeSelector() {
    final selectedType = _composedSystemType ?? _ClientSystemMessageType.update;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _composedSystemType == _ClientSystemMessageType.dispatch
              ? 'Incident Type: Dispatch review active'
              : 'Incident Type',
          style: GoogleFonts.inter(
            color: const Color(0xFF8EA7C8),
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
                      style: OutlinedButton.styleFrom(
                        foregroundColor: selected
                            ? type.textColor
                            : const Color(0xFFB9D9FF),
                        side: BorderSide(
                          color: selected
                              ? type.borderColor
                              : const Color(0xFF274E7E),
                        ),
                        backgroundColor: selected
                            ? type.cardFillColor
                            : const Color(0xFF0D1B33),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        shadowColor: const Color(0x10000000),
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
        gradient: LinearGradient(
          colors: [
            type.cardFillColor,
            type.cardFillColor.withValues(alpha: 0.82),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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

  Widget _emptyBox(String label) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1A2E), Color(0xFF0A1425)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1D3A61)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: const Color(0xFF9AB4D8),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: textColor),
            const SizedBox(width: 4),
          ],
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
        color: const Color(0xFFBFF0C8),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
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
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: const Color(0xFF8FD1FF),
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
        backgroundColor: const Color(0x0AFFFFFF),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        visualDensity: VisualDensity.compact,
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
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: item.systemType.textColor,
      ),
      child: Text(
        _notificationSendNowLabelFor(item.systemType),
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  void _sendClientMessage() {
    final text = _chatController.text.trim();
    _sendManualMessageText(
      text,
      systemType: _composedSystemType,
      clearComposer: true,
    );
  }

  void _applyQuickAction(
    String template, {
    _ClientSystemMessageType? systemType,
  }) {
    setState(() {
      _composedSystemType = systemType ?? _composedSystemType;
      _chatController.text = template;
      _chatController.selection = TextSelection.collapsed(
        offset: _chatController.text.length,
      );
    });
  }

  void _draftNotificationAction(_ClientNotification item) {
    _applyQuickAction(
      _notificationActionDraftFor(item),
      systemType: item.systemType,
    );
  }

  void _setComposedSystemType(_ClientSystemMessageType type) {
    setState(() {
      _composedSystemType = type;
    });
  }

  void _focusDraftNotificationAction(_ClientNotification item) {
    _draftNotificationAction(item);
    _triggerComposerLandingHighlight(item.messageKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
        ? const Color(0xFF13284A)
        : const Color(0xFF0D1B33);
  }

  Color _chatComposerBorderColor() {
    return _showComposerLandingHighlight
        ? const Color(0xFF8FD1FF)
        : const Color(0xFF1F416A);
  }

  Color _chatComposerFocusedBorderColor() {
    return _showComposerLandingHighlight
        ? const Color(0xFFB9E2FF)
        : const Color(0xFF3E7BFF);
  }

  Color _threadLandingBubbleFillColor() {
    return const Color(0xFF13284A);
  }

  Color _threadLandingBubbleBorderColor() {
    return const Color(0xFF8FD1FF);
  }

  Color _threadLandingBubbleMetaColor() {
    return const Color(0xFFB9E2FF);
  }

  ButtonStyle _inlineHandoffButtonStyle(
    Color foregroundColor, {
    Color? disabledForegroundColor,
  }) {
    return ButtonStyle(
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      minimumSize: WidgetStateProperty.all(const Size(0, 0)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      alignment: Alignment.centerLeft,
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return disabledForegroundColor ?? foregroundColor;
        }
        return foregroundColor;
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return const Color(0x081A3658);
        }
        if (states.contains(WidgetState.pressed)) {
          return const Color(0x1A8FD1FF);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return const Color(0x142C5078);
        }
        return const Color(0x0F1A3658);
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return null;
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return const Color(0x142C5078);
        }
        if (states.contains(WidgetState.pressed)) {
          return const Color(0x1A8FD1FF);
        }
        return null;
      }),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0x33274E7E)),
        ),
      ),
    );
  }

  Future<void> _showIncidentFeedDetail(_ClientIncidentFeedGroup group) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        final latest = group.latestEntry;
        return AlertDialog(
          backgroundColor: const Color(0xFF081325),
          title: Text(
            _viewerRole.incidentDetailTitle,
            style: GoogleFonts.inter(
              color: const Color(0xFFE5F1FF),
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
                  color: const Color(0xFF8EA7C8),
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
                  color: const Color(0xFF8FD1FF),
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
                color: const Color(0xFF8EA7C8),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: GoogleFonts.inter(
                color: const Color(0xFFE5F1FF),
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
        color: const Color(0xFF0D1B33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F416A)),
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
              color: const Color(0xFF8EA7C8),
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
              color: const Color(0xFFE5F1FF),
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
              color: const Color(0xFF8EA7C8),
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
              foregroundColor: const Color(0xFF8FD1FF),
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
        color: const Color(0xFF0A1630),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF1F416A)),
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
              foregroundColor: const Color(0xFF8EA7C8),
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
            color: const Color(0xFF1F416A),
          ),
          TextButton(
            onPressed: () => _showIncidentFeedDetail(group),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: const Color(0xFF8FD1FF),
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

  Color _incidentRowBorderColor({
    required bool expanded,
    required bool selected,
    required bool focused,
  }) {
    if (_viewerRole == ClientAppViewerRole.client) {
      return const Color(0xFF1F416A);
    }
    if (focused) {
      return const Color(0xFF5EA8FF);
    }
    if (selected) {
      return const Color(0xFF4A86C7);
    }
    if (expanded) {
      return const Color(0xFF35679B);
    }
    return const Color(0xFF1F416A);
  }

  String _threadJumpedLabel() {
    return switch (_viewerRole) {
      ClientAppViewerRole.client => _localizedTemplate(
        key: 'threadJumpedClient',
        fallback: 'Jumped to latest reply',
      ),
      ClientAppViewerRole.control => _localizedTemplate(
        key: 'threadJumpedControl',
        fallback: 'Jumped to latest log entry',
      ),
      ClientAppViewerRole.resident => _localizedTemplate(
        key: 'threadJumpedResident',
        fallback: 'Jumped to latest resident reply',
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
              'Dispatch responses for {room} require client review before sending.',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.control, _ClientSystemMessageType.dispatch) =>
        _localizedTemplate(
          key: 'draftRequiredControlDispatch',
          fallback:
              'Dispatch responses for {room} must be reviewed before sending.',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.resident, _ClientSystemMessageType.dispatch) =>
        _localizedTemplate(
          key: 'draftRequiredResidentDispatch',
          fallback:
              'Dispatch updates for {room} require review before sending.',
          tokens: {'room': roomLabel},
        ),
      (_, _) => _localizedTemplate(
        key: 'draftRequiredDefault',
        fallback: 'Draft review required before sending.',
      ),
    };
  }

  String _draftReadyLabelFor(_ClientSystemMessageType type) {
    final roomLabel = _activeRoomDisplayName();
    return switch ((_viewerRole, type)) {
      (ClientAppViewerRole.client, _ClientSystemMessageType.dispatch) =>
        _localizedTemplate(
          key: 'draftReadyClientDispatch',
          fallback: 'Open Client Review for {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.control, _ClientSystemMessageType.dispatch) =>
        _localizedTemplate(
          key: 'draftReadyControlDispatch',
          fallback: 'Open Dispatch Draft for {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.resident, _ClientSystemMessageType.dispatch) =>
        _localizedTemplate(
          key: 'draftReadyResidentDispatch',
          fallback: 'Open Update Draft for {room}',
          tokens: {'room': roomLabel},
        ),
      (_, _) => _localizedTemplate(
        key: 'draftReadyDefault',
        fallback: 'Draft Ready',
      ),
    };
  }

  String _draftOpenedLabelFor(_ClientSystemMessageType type) {
    final roomLabel = _activeRoomDisplayName();
    return switch ((_viewerRole, type)) {
      (ClientAppViewerRole.client, _ClientSystemMessageType.dispatch) =>
        _localizedTemplate(
          key: 'draftOpenedClientDispatch',
          fallback: 'Client review draft opened for {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.control, _ClientSystemMessageType.dispatch) =>
        _localizedTemplate(
          key: 'draftOpenedControlDispatch',
          fallback: 'Dispatch draft opened for {room}',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.resident, _ClientSystemMessageType.dispatch) =>
        _localizedTemplate(
          key: 'draftOpenedResidentDispatch',
          fallback: 'Dispatch update draft opened for {room}',
          tokens: {'room': roomLabel},
        ),
      (_, _) => _localizedTemplate(
        key: 'draftOpenedDefault',
        fallback: 'Draft opened',
      ),
    };
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
          fallback:
              'Client reviewed the advisory and is ready to share it with {room}.',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.client, _ClientSystemMessageType.closure) =>
        _localizedTemplate(
          key: 'notificationDraftClientClosure',
          fallback:
              'Client reviewed the closure update for {room} and confirms receipt.',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.client, _) => _localizedTemplate(
        key: 'notificationDraftClientDefault',
        fallback:
            'Client reviewed this update for {room} and is awaiting the next step.',
        tokens: {'room': roomLabel},
      ),
      (ClientAppViewerRole.control, _ClientSystemMessageType.dispatch) =>
        _localizedTemplate(
          key: 'notificationDraftControlDispatch',
          fallback: 'Control reviewing dispatch response for {room}.',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.control, _ClientSystemMessageType.advisory) =>
        _localizedTemplate(
          key: 'notificationDraftControlAdvisory',
          fallback: 'Control drafting the advisory log entry for {room}.',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.control, _ClientSystemMessageType.closure) =>
        _localizedTemplate(
          key: 'notificationDraftControlClosure',
          fallback: 'Control drafting the closure log for {room}.',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.control, _) => _localizedTemplate(
        key: 'notificationDraftControlDefault',
        fallback: 'Control drafting the operational update log for {room}.',
        tokens: {'room': roomLabel},
      ),
      (ClientAppViewerRole.resident, _ClientSystemMessageType.dispatch) =>
        _localizedTemplate(
          key: 'notificationDraftResidentDispatch',
          fallback:
              'Resident has viewed the alert in {room} and is awaiting guidance.',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.resident, _ClientSystemMessageType.advisory) =>
        _localizedTemplate(
          key: 'notificationDraftResidentAdvisory',
          fallback: 'Resident is drafting a community alert for {room} now.',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.resident, _ClientSystemMessageType.closure) =>
        _localizedTemplate(
          key: 'notificationDraftResidentClosure',
          fallback: 'Resident is drafting a closure reply for {room}.',
          tokens: {'room': roomLabel},
        ),
      (ClientAppViewerRole.resident, _) => _localizedTemplate(
        key: 'notificationDraftResidentDefault',
        fallback: 'Resident is drafting an update request for {room}.',
        tokens: {'room': roomLabel},
      ),
    };
  }

  List<_ClientNotification> _buildNotifications(List<DispatchEvent> events) {
    final items = <_ClientNotification>[];
    for (final event in events.take(10)) {
      switch (event) {
        case DecisionCreated():
          final messageKey = _notificationMessageKeyForValues(
            occurredAt: event.occurredAt,
            title: 'Dispatch created',
            body: 'Response team activated for ${event.siteId}.',
          );
          items.add(
            _ClientNotification(
              messageKey: messageKey,
              title: 'Dispatch created',
              body: 'Response team activated for ${event.siteId}.',
              occurredAt: event.occurredAt,
              systemType: _ClientSystemMessageType.dispatch,
              priority: true,
              acknowledgements: _acknowledgementsForMessage(messageKey),
            ),
          );
        case ResponseArrived():
          final messageKey = _notificationMessageKeyForValues(
            occurredAt: event.occurredAt,
            title: 'Officer arrived',
            body: 'Guard ${event.guardId} reached ${event.siteId}.',
          );
          items.add(
            _ClientNotification(
              messageKey: messageKey,
              title: 'Officer arrived',
              body: 'Guard ${event.guardId} reached ${event.siteId}.',
              occurredAt: event.occurredAt,
              systemType: _ClientSystemMessageType.update,
              acknowledgements: _acknowledgementsForMessage(messageKey),
            ),
          );
        case IncidentClosed():
          final messageKey = _notificationMessageKeyForValues(
            occurredAt: event.occurredAt,
            title: 'Incident closed',
            body:
                'Dispatch ${event.dispatchId} closed as ${event.resolutionType}.',
          );
          items.add(
            _ClientNotification(
              messageKey: messageKey,
              title: 'Incident closed',
              body:
                  'Dispatch ${event.dispatchId} closed as ${event.resolutionType}.',
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
          items.add(
            _ClientIncidentFeedEntry(
              referenceLabel: event.dispatchId,
              headline: 'Dispatch opened for ${event.siteId}',
              detail: 'Response team activated and client updates started.',
              occurredAt: event.occurredAt,
              statusLabel: 'Opened',
              accent: const Color(0xFFB9D9FF),
              borderColor: const Color(0xFF2A5D91),
            ),
          );
        case ResponseArrived():
          items.add(
            _ClientIncidentFeedEntry(
              referenceLabel: event.dispatchId,
              headline: 'Responder on site',
              detail: 'Guard ${event.guardId} reached ${event.siteId}.',
              occurredAt: event.occurredAt,
              statusLabel: 'On Site',
              accent: const Color(0xFF9FD8AC),
              borderColor: const Color(0xFF2E6A3C),
            ),
          );
        case IncidentClosed():
          items.add(
            _ClientIncidentFeedEntry(
              referenceLabel: event.dispatchId,
              headline: 'Incident closed',
              detail: 'Resolved as ${event.resolutionType}.',
              occurredAt: event.occurredAt,
              statusLabel: 'Closed',
              accent: const Color(0xFFFFD6A5),
              borderColor: const Color(0xFF8C5B23),
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
                  ? const Color(0xFFFFD3D8)
                  : const Color(0xFFC9B8FF),
              borderColor: event.riskScore >= 70
                  ? const Color(0xFF8A3D4A)
                  : const Color(0xFF6950A8),
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
      'Advisory' => const Color(0xFFFFD3D8),
      'Closed' => const Color(0xFFFFD6A5),
      'Opened' => const Color(0xFFB9D9FF),
      _ => switch (author) {
        'Control' => const Color(0xFF9FD8AC),
        'Resident' => const Color(0xFFFFD6A5),
        _ => const Color(0xFFB9D9FF),
      },
    };
  }

  Color _manualIncidentBorderColorFor(String statusLabel, String author) {
    return switch (statusLabel) {
      'Advisory' => const Color(0xFF8A3D4A),
      'Closed' => const Color(0xFF8C5B23),
      'Opened' => const Color(0xFF2A5D91),
      _ => switch (author) {
        'Control' => const Color(0xFF2E6A3C),
        'Resident' => const Color(0xFF8C5B23),
        _ => const Color(0xFF2A5D91),
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
      return Future<void>.value();
    }
    setState(() {
      _selectedIncidentReference = group.referenceLabel;
      _selectedIncidentReferenceByRole[_viewerRole.name] = group.referenceLabel;
      _hasTouchedIncidentExpansionByRole[_viewerRole.name] = true;
      _expandedIncidentReferenceByRole[_viewerRole.name] = group.referenceLabel;
    });
    _emitClientStateChanged();
    return _showIncidentFeedDetail(group);
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

  String get _localizedNoPushNotificationsQueuedYet {
    return ClientAppLocaleText.generalText(
      locale: widget.locale,
      key: 'noPushNotificationsQueuedYet',
      fallback: 'No push notifications queued yet.',
    );
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
    final pushQueue = notifications.isNotEmpty
        ? _buildPushQueue(notifications)
        : _mergeStoredPushQueueWithAcknowledgements(widget.initialPushQueue);
    widget.onPushQueueChanged?.call(pushQueue);
  }

  List<DispatchEvent> _currentClientEvents() {
    final clientEvents = widget.events.where((event) {
      return switch (event) {
        DecisionCreated e => e.clientId == widget.clientId,
        ResponseArrived e => e.clientId == widget.clientId,
        IncidentClosed e => e.clientId == widget.clientId,
        IntelligenceReceived e => e.clientId == widget.clientId,
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
  final List<ClientAppAcknowledgement> acknowledgements;

  const _ClientChatMessage({
    required this.messageKey,
    required this.author,
    required this.body,
    required this.occurredAt,
    this.roomKey,
    required this.systemType,
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
  final ClientAppAcknowledgementChannel targetChannel;
  final bool priority;
  final ClientPushDeliveryStatus status;

  const ClientAppPushDeliveryItem({
    required this.messageKey,
    required this.title,
    required this.body,
    required this.occurredAt,
    required this.targetChannel,
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
      targetChannel: ClientAppAcknowledgementChannel.values.firstWhere(
        (value) => value.name == json['targetChannel']?.toString(),
        orElse: () => ClientAppAcknowledgementChannel.client,
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
      'targetChannel': targetChannel.name,
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
      backendProbeStatusLabel = 'idle',
      backendProbeLastRunAtUtc = null,
      backendProbeFailureReason = null,
      backendProbeHistory = const [];

  factory ClientPushSyncState.fromJson(Map<String, Object?> json) {
    final rawHistory = json['history'];
    final rawBackendProbeHistory = json['backendProbeHistory'];
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
    Color(0xFFB9D9FF),
    Color(0xFF2A5D91),
    Color(0xFF10233D),
    Color(0xFF2F5F94),
    Color(0xFF8A3D4A),
  ),
  advisory(
    'Advisory',
    Icons.campaign_rounded,
    Color(0xFFFFD9A8),
    Color(0xFF8A5A1C),
    Color(0xFF241A0D),
    Color(0xFF8A5A1C),
    Color(0xFFA85A1F),
  ),
  closure(
    'Closure',
    Icons.check_circle_rounded,
    Color(0xFFBFF0C8),
    Color(0xFF2E7D4E),
    Color(0xFF102017),
    Color(0xFF2E7D4E),
    Color(0xFF2E7D4E),
  ),
  update(
    'Update',
    Icons.sync_rounded,
    Color(0xFFD6CBFF),
    Color(0xFF6352A3),
    Color(0xFF171325),
    Color(0xFF6352A3),
    Color(0xFF7D57C5),
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
      ClientAppViewerRole.client => 'No incident milestones yet.',
      ClientAppViewerRole.control => 'No active incident milestones yet.',
      ClientAppViewerRole.resident => 'No safety timeline updates yet.',
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
      ClientAppViewerRole.client => 'No Incident Selected',
      ClientAppViewerRole.control => 'No Thread Selected',
      ClientAppViewerRole.resident => 'No Safety Selected',
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
      ClientAppViewerRole.client => 'No client notifications yet.',
      ClientAppViewerRole.control => 'No control alerts in the current lane.',
      ClientAppViewerRole.resident => 'No safety updates in the current lane.',
    };
  }

  String get chatEmptyLabel {
    return switch (this) {
      ClientAppViewerRole.client => 'No direct chat messages yet.',
      ClientAppViewerRole.control =>
        'No desk coordination messages in this lane.',
      ClientAppViewerRole.resident => 'No resident messages in this lane.',
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
      ClientAppViewerRole.client => const Color(0xFF123156),
      ClientAppViewerRole.control => const Color(0xFF173021),
      ClientAppViewerRole.resident => const Color(0xFF3B2416),
    };
  }

  Color get outgoingBubbleBorderColor {
    return switch (this) {
      ClientAppViewerRole.client => const Color(0xFF3E7BFF),
      ClientAppViewerRole.control => const Color(0xFF39C98A),
      ClientAppViewerRole.resident => const Color(0xFFF0A35A),
    };
  }

  Color get outgoingBubbleMetaColor {
    return switch (this) {
      ClientAppViewerRole.client => const Color(0xFF8FD1FF),
      ClientAppViewerRole.control => const Color(0xFF8CF1C3),
      ClientAppViewerRole.resident => const Color(0xFFFFD2A5),
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

  ClientAppMessage({
    required this.author,
    required this.body,
    required this.occurredAt,
    this.roomKey = 'Residents',
    this.viewerRole = 'client',
    this.incidentStatusLabel = 'Update',
  });

  factory ClientAppMessage.fromJson(Map<String, Object?> json) {
    final occurredAtValue = json['occurredAt']?.toString();
    return ClientAppMessage(
      author: json['author']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      roomKey: json['roomKey']?.toString() ?? 'Residents',
      viewerRole: json['viewerRole']?.toString() ?? 'client',
      incidentStatusLabel: json['incidentStatusLabel']?.toString() ?? 'Update',
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
