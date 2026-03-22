import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../domain/events/decision_created.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/incident_closed.dart';
import '../domain/events/intelligence_received.dart';
import '../domain/events/response_arrived.dart';
import 'layout_breakpoints.dart';
import 'onyx_surface.dart';
import 'ui_action_logger.dart';

class ClientsPage extends StatefulWidget {
  final String clientId;
  final String siteId;
  final List<DispatchEvent> events;
  final Future<void> Function()? onRetryPushSync;
  final void Function(String room, String clientId, String siteId)?
  onOpenClientRoomForScope;
  final void Function(List<String> eventIds, String? selectedEventId)?
  onOpenEventsForScope;

  const ClientsPage({
    super.key,
    required this.clientId,
    required this.siteId,
    required this.events,
    this.onRetryPushSync,
    this.onOpenClientRoomForScope,
    this.onOpenEventsForScope,
  });

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  final GlobalKey _messageHistoryKey = GlobalKey();

  String? _selectedClientId;
  String? _selectedSiteId;
  int _pushRetryCount = 0;
  String _pushSyncStatus = 'push idle';
  String _backendProbeStatus = 'healthy';
  String _voipStageStatus = 'staged';
  String _selectedPinnedVoice = 'Auto';

  @override
  void initState() {
    super.initState();
    _selectedClientId = widget.clientId;
    _selectedSiteId = widget.siteId;
  }

  @override
  void dispose() => super.dispose();

  @override
  Widget build(BuildContext context) {
    final model = _deriveClientSiteModel(widget.events);
    final clients = model.clients.isEmpty ? _fallbackClients : model.clients;
    final sites = model.sites.isEmpty ? _fallbackSites : model.sites;

    if (_selectedClientId == null ||
        !clients.any((c) => c.id == _selectedClientId)) {
      _selectedClientId = clients.first.id;
    }

    var availableSites = sites
        .where((site) => site.clientId == _selectedClientId)
        .toList(growable: false);
    if (availableSites.isEmpty) {
      availableSites = sites;
    }

    if (_selectedSiteId == null ||
        !availableSites.any((site) => site.id == _selectedSiteId)) {
      _selectedSiteId = availableSites.first.id;
    }

    final currentClient = clients.firstWhere(
      (client) => client.id == _selectedClientId,
    );
    final currentSite = availableSites.firstWhere(
      (site) => site.id == _selectedSiteId,
    );

    final feedRows = _incidentFeedRows(
      events: widget.events,
      selectedClientId: _selectedClientId!,
      selectedSiteId: _selectedSiteId!,
    );
    final rows = feedRows.isEmpty ? _fallbackFeed : feedRows;

    final unreadAlerts = rows
        .where((row) => row.status != _FeedStatus.info)
        .length;
    final activeIncidents = widget.events
        .whereType<DecisionCreated>()
        .where(
          (event) =>
              event.clientId == _selectedClientId &&
              event.siteId == _selectedSiteId,
        )
        .length;
    final directUpdates = rows.length;
    final pendingAsks = rows
        .where((row) => row.type == _FeedType.update)
        .length;
    final pushSyncLower = _pushSyncStatus.toLowerCase();
    final backendProbeLower = _backendProbeStatus.toLowerCase();
    final voipStageLower = _voipStageStatus.toLowerCase();
    final telegramBlocked = pushSyncLower.contains('blocked');
    final smsFallbackActive = pushSyncLower.contains('fallback');
    final voipReady =
        voipStageLower.contains('dialing') ||
        voipStageLower.contains('ready') ||
        voipStageLower.contains('connected');
    final voipStaged = voipStageLower.contains('staged');
    final pushNeedsReview =
        pushSyncLower.contains('retry') || pushSyncLower.contains('review');
    final pushIdle =
        pushSyncLower.contains('idle') &&
        !pushNeedsReview &&
        !telegramBlocked &&
        !smsFallbackActive;
    String? reviewEventId;
    for (final row in rows) {
      if (row.type == _FeedType.update && row.eventId != null) {
        reviewEventId = row.eventId;
        break;
      }
    }

    return OnyxPageScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final desktopWorkspace = constraints.maxWidth >= 1240;
          final stacked = constraints.maxWidth < 1220;
          final boundedDesktopSurface =
              desktopWorkspace && allowEmbeddedPanelScroll(context);
          final ultrawideSurface = isUltrawideLayout(
            context,
            viewportWidth: constraints.maxWidth,
          );
          final widescreenSurface = isWidescreenLayout(
            context,
            viewportWidth: constraints.maxWidth,
          );
          final surfaceMaxWidth = ultrawideSurface || widescreenSurface
              ? constraints.maxWidth
              : 1760.0;
          final communicationsBoard = Column(
            children: [
              _roomThreadContextCard(
                currentClient: currentClient,
                currentSite: currentSite,
                clients: clients,
                sites: sites,
                availableSites: availableSites,
              ),
              const SizedBox(height: 8),
              _communicationChannelsCard(
                telegramBlocked: telegramBlocked,
                smsFallbackActive: smsFallbackActive,
                voipReady: voipReady,
                voipStaged: voipStaged,
                pushNeedsReview: pushNeedsReview,
                pushIdle: pushIdle,
                backendProbeHealthy:
                    backendProbeLower.contains('healthy') ||
                    backendProbeLower.contains('ok'),
                pendingAsks: pendingAsks,
              ),
              const SizedBox(height: 8),
              _messageHistoryCard(rows),
            ],
          );
          final contextRail = Column(
            children: [
              _pendingDraftsCard(
                pendingAsks: pendingAsks,
                activeIncidents: activeIncidents,
                reviewEventId: reviewEventId,
              ),
              const SizedBox(height: 8),
              _learnedStyleCard(),
              const SizedBox(height: 8),
              _pinnedVoiceCard(),
            ],
          );

          final body = desktopWorkspace
              ? _clientsDesktopWorkspace(
                  currentClient: currentClient,
                  currentSite: currentSite,
                  clients: clients,
                  sites: sites,
                  pendingAsks: pendingAsks,
                  unreadAlerts: unreadAlerts,
                  directUpdates: directUpdates,
                  activeIncidents: activeIncidents,
                  reviewEventId: reviewEventId,
                  pushRetryAvailable: widget.onRetryPushSync != null,
                  roomRoutingAvailable: widget.onOpenClientRoomForScope != null,
                  communicationsBoard: communicationsBoard,
                  contextRail: contextRail,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _activeLanesSection(
                      currentClient: currentClient,
                      currentSite: currentSite,
                      clients: clients,
                      sites: availableSites,
                      pendingAsks: pendingAsks,
                    ),
                    const SizedBox(height: 8),
                    stacked
                        ? Column(
                            children: [
                              communicationsBoard,
                              const SizedBox(height: 8),
                              contextRail,
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: communicationsBoard),
                              const SizedBox(width: 8),
                              Expanded(flex: 1, child: contextRail),
                            ],
                          ),
                  ],
                );

          return OnyxViewportWorkspaceLayout(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            maxWidth: surfaceMaxWidth,
            spacing: 8,
            lockToViewport: boundedDesktopSurface,
            header: _heroHeader(
              currentClient: currentClient,
              currentSite: currentSite,
              unreadAlerts: unreadAlerts,
              pendingAsks: pendingAsks,
              directUpdates: directUpdates,
            ),
            body: body,
          );
        },
      ),
    );
  }

  Widget _clientsDesktopWorkspace({
    required _ClientOption currentClient,
    required _SiteOption currentSite,
    required List<_ClientOption> clients,
    required List<_SiteOption> sites,
    required int pendingAsks,
    required int unreadAlerts,
    required int directUpdates,
    required int activeIncidents,
    required String? reviewEventId,
    required bool pushRetryAvailable,
    required bool roomRoutingAvailable,
    required Widget communicationsBoard,
    required Widget contextRail,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final workspaceWidth = constraints.maxWidth;
        final ultrawideWorkspace = workspaceWidth >= 2600;
        final widescreenWorkspace = workspaceWidth >= 2000;
        final railGap = ultrawideWorkspace ? 10.0 : 6.0;
        final leftRailWidth = ultrawideWorkspace
            ? 326.0
            : widescreenWorkspace
            ? 306.0
            : 292.0;
        final rightRailWidth = ultrawideWorkspace
            ? 308.0
            : widescreenWorkspace
            ? 292.0
            : 280.0;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: leftRailWidth,
              child: _clientsWorkspacePanel(
                key: const ValueKey('clients-workspace-panel-rail'),
                title: 'Client Ops Rail',
                subtitle:
                    'Keep lane selection, active room state, and live communications handoffs visible while the message board stays anchored.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _clientsWorkspaceStatusBanner(
                      currentClient: currentClient,
                      currentSite: currentSite,
                      unreadAlerts: unreadAlerts,
                      pendingAsks: pendingAsks,
                      directUpdates: directUpdates,
                      activeIncidents: activeIncidents,
                      reviewEventId: reviewEventId,
                      pushRetryAvailable: pushRetryAvailable,
                      roomRoutingAvailable: roomRoutingAvailable,
                    ),
                    const SizedBox(height: 10),
                    _activeLanesSection(
                      currentClient: currentClient,
                      currentSite: currentSite,
                      clients: clients,
                      sites: sites,
                      pendingAsks: pendingAsks,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'COMMAND ACTIONS',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8EA4C2),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _clientsWorkspaceActionButton(
                      key: const ValueKey('clients-workspace-open-review'),
                      label: 'Review Draft Queue',
                      enabled: true,
                      onTap: () => _reviewPendingDrafts(reviewEventId),
                    ),
                    const SizedBox(height: 8),
                    _clientsWorkspaceActionButton(
                      key: const ValueKey(
                        'clients-workspace-open-residents-room',
                      ),
                      label: 'Open Residents Room',
                      enabled: roomRoutingAvailable,
                      onTap: roomRoutingAvailable
                          ? () => _openClientRoom('Residents')
                          : null,
                    ),
                    const SizedBox(height: 8),
                    _clientsWorkspaceActionButton(
                      key: const ValueKey('clients-workspace-retry-sync'),
                      label: pendingAsks > 0
                          ? 'Review Or Retry Push Sync'
                          : 'Retry Push Sync',
                      enabled: pushRetryAvailable,
                      onTap: pushRetryAvailable ? _retryPushSync : null,
                    ),
                    const SizedBox(height: 8),
                    _clientsWorkspaceActionButton(
                      key: const ValueKey('clients-workspace-open-history'),
                      label: 'Jump To Message History',
                      enabled: true,
                      onTap: _scrollToMessageHistory,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: railGap),
            Expanded(
              child: _clientsWorkspacePanel(
                key: const ValueKey('clients-workspace-panel-board'),
                title: 'Communications Board',
                subtitle:
                    'Selected room context, channel posture, and the live incident feed stay together in one command surface.',
                child: communicationsBoard,
              ),
            ),
            SizedBox(width: railGap),
            SizedBox(
              width: rightRailWidth,
              child: _clientsWorkspacePanel(
                key: const ValueKey('clients-workspace-panel-context'),
                title: 'Draft & Voice Rail',
                subtitle:
                    'Pending reviews, learned tone, and pinned delivery posture remain visible while lane context changes.',
                child: Column(
                  children: [
                    _clientsWorkspaceSnapshot(
                      pendingAsks: pendingAsks,
                      unreadAlerts: unreadAlerts,
                      activeIncidents: activeIncidents,
                    ),
                    const SizedBox(height: 8),
                    contextRail,
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _clientsWorkspacePanel({
    Key? key,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          key: key,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF111A26),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF223548)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 12,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.rajdhani(
                    color: const Color(0xFFEAF4FF),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF92A6C1),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                onyxBoundedPanelBody(
                  context: context,
                  constraints: constraints,
                  child: child,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _clientsWorkspaceStatusBanner({
    required _ClientOption currentClient,
    required _SiteOption currentSite,
    required int unreadAlerts,
    required int pendingAsks,
    required int directUpdates,
    required int activeIncidents,
    required String? reviewEventId,
    required bool pushRetryAvailable,
    required bool roomRoutingAvailable,
  }) {
    return Container(
      key: const ValueKey('clients-workspace-status-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1117),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x332B425F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACTIVE COMMUNICATIONS',
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            currentClient.name,
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFEAF4FF),
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${currentClient.code} / ${currentSite.code}',
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _clientsWorkspaceChip(
                label: 'Alerts',
                value: '$unreadAlerts',
                accent: unreadAlerts > 0
                    ? const Color(0xFFFBBF24)
                    : const Color(0xFF8EA4C2),
              ),
              _clientsWorkspaceChip(
                label: 'Drafts',
                value: '$pendingAsks',
                accent: pendingAsks > 0
                    ? const Color(0xFFFBBF24)
                    : const Color(0xFF8EA4C2),
              ),
              _clientsWorkspaceChip(
                label: 'Feed',
                value: '$directUpdates',
                accent: const Color(0xFF67E8F9),
              ),
              _clientsWorkspaceChip(
                label: 'Incidents',
                value: '$activeIncidents',
                accent: activeIncidents > 0
                    ? const Color(0xFF34D399)
                    : const Color(0xFF8EA4C2),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _clientsWorkspaceStatusAction(
                key: const ValueKey('clients-workspace-banner-open-review'),
                label: 'Review Draft Queue',
                accent: pendingAsks > 0
                    ? const Color(0xFFFBBF24)
                    : const Color(0xFF8FD1FF),
                enabled: true,
                onTap: () => _reviewPendingDrafts(reviewEventId),
              ),
              _clientsWorkspaceStatusAction(
                key: const ValueKey(
                  'clients-workspace-banner-open-residents-room',
                ),
                label: 'Open Residents Room',
                accent: const Color(0xFF67E8F9),
                enabled: roomRoutingAvailable,
                onTap: roomRoutingAvailable
                    ? () => _openClientRoom('Residents')
                    : null,
              ),
              _clientsWorkspaceStatusAction(
                key: const ValueKey('clients-workspace-banner-retry-sync'),
                label: pushRetryAvailable
                    ? 'Review Or Retry Push Sync'
                    : 'Push Sync View Only',
                accent: const Color(0xFFC084FC),
                enabled: pushRetryAvailable,
                onTap: pushRetryAvailable ? _retryPushSync : null,
              ),
              _clientsWorkspaceStatusAction(
                key: const ValueKey('clients-workspace-banner-open-history'),
                label: 'Jump To Message History',
                accent: const Color(0xFF34D399),
                enabled: true,
                onTap: _scrollToMessageHistory,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _clientsWorkspaceStatusAction({
    required Key key,
    required String label,
    required Color accent,
    required bool enabled,
    required VoidCallback? onTap,
  }) {
    return OutlinedButton(
      key: key,
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: enabled ? accent : const Color(0xFF6B7A90),
        side: BorderSide(
          color: enabled
              ? accent.withValues(alpha: 0.34)
              : const Color(0xFF25313F),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _clientsWorkspaceSnapshot({
    required int pendingAsks,
    required int unreadAlerts,
    required int activeIncidents,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1117),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x332B425F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WORKSPACE SNAPSHOT',
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          _clientsWorkspaceSnapshotRow('Pending approvals', '$pendingAsks'),
          const SizedBox(height: 5),
          _clientsWorkspaceSnapshotRow('Unread alerts', '$unreadAlerts'),
          const SizedBox(height: 5),
          _clientsWorkspaceSnapshotRow(
            'Active lane incidents',
            '$activeIncidents',
          ),
          const SizedBox(height: 5),
          _clientsWorkspaceSnapshotRow(
            'Pinned voice',
            'Voice • $_selectedPinnedVoice',
          ),
        ],
      ),
    );
  }

  Widget _clientsWorkspaceSnapshotRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            color: const Color(0xFFEAF4FF),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _clientsWorkspaceChip({
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: RichText(
        text: TextSpan(
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
                color: accent,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _clientsWorkspaceActionButton({
    Key? key,
    required String label,
    required VoidCallback? onTap,
    required bool enabled,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        key: key,
        onPressed: enabled ? onTap : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFEAF2FF),
          side: BorderSide(
            color: enabled ? const Color(0xFF304256) : const Color(0xFF25313F),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _heroHeader({
    required _ClientOption currentClient,
    required _SiteOption currentSite,
    required int unreadAlerts,
    required int pendingAsks,
    required int directUpdates,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1180;
        final chips = Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _heroChip(
              label: currentClient.code,
              foreground: const Color(0xFF8FD1FF),
              background: const Color(0x1A8FD1FF),
              border: const Color(0x668FD1FF),
            ),
            _heroChip(
              label: currentSite.code,
              foreground: const Color(0xFF22D3EE),
              background: const Color(0x1A22D3EE),
              border: const Color(0x6622D3EE),
            ),
            _heroChip(
              label: '$pendingAsks Pending Ask${pendingAsks == 1 ? '' : 's'}',
              foreground: pendingAsks > 0
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF9AB1CF),
              background: pendingAsks > 0
                  ? const Color(0x1AF59E0B)
                  : const Color(0x1A94A3B8),
              border: pendingAsks > 0
                  ? const Color(0x66F59E0B)
                  : const Color(0x6694A3B8),
            ),
            _heroChip(
              label:
                  '$unreadAlerts Unread Alert${unreadAlerts == 1 ? '' : 's'}',
              foreground: unreadAlerts > 0
                  ? const Color(0xFFF87171)
                  : const Color(0xFF9AB1CF),
              background: unreadAlerts > 0
                  ? const Color(0x1AF87171)
                  : const Color(0x1A94A3B8),
              border: unreadAlerts > 0
                  ? const Color(0x66F87171)
                  : const Color(0x6694A3B8),
            ),
          ],
        );
        final titleBlock = Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF0891B2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x332563EB),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.business_center_rounded,
                  size: 22,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Client Communications',
                      style: GoogleFonts.rajdhani(
                        color: const Color(0xFFEAF4FF),
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lane management, incident visibility, and direct client notification status.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF93A9C6),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    chips,
                  ],
                ),
              ),
            ],
          ),
        );
        final snapshotCard = Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF223244)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lane Snapshot',
                style: GoogleFonts.inter(
                  color: const Color(0xFFEAF4FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${currentClient.name} • ${currentSite.name}',
                style: GoogleFonts.inter(
                  color: const Color(0xFF9BB0CE),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$directUpdates total updates in the visible incident feed',
                style: GoogleFonts.inter(
                  color: const Color(0xFF8FD1FF),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF111722), Color(0xFF0D1117)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF223244)),
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [titleBlock]),
                    const SizedBox(height: 10),
                    snapshotCard,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleBlock,
                    const SizedBox(width: 12),
                    SizedBox(width: 240, child: snapshotCard),
                  ],
                ),
        );
      },
    );
  }

  Widget _heroChip({
    required String label,
    required Color foreground,
    required Color background,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _feedRow(_FeedRow row) {
    final rowColor = _feedColor(row.status);
    final canOpenEvent =
        row.eventId != null && widget.onOpenEventsForScope != null;
    return InkWell(
      key: ValueKey('clients-incident-row-${row.title}-${row.timestampLabel}'),
      borderRadius: BorderRadius.circular(9),
      onTap: !canOpenEvent
          ? null
          : () {
              logUiAction(
                'client_app.reopen_selected_incident',
                context: {
                  'role': 'client',
                  'reference_label': row.title,
                  'source': 'clients_incident_feed',
                  'event_id': row.eventId,
                },
              );
              widget.onOpenEventsForScope!.call([row.eventId!], row.eventId);
            },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0x14FFFFFF),
                shape: BoxShape.circle,
              ),
              child: Icon(_feedIcon(row.type), color: rowColor, size: 15),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.title,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFEAF1FB),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    row.description,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF9BB0CE),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              row.timestampLabel,
              style: GoogleFonts.inter(
                color: const Color(0x668EA4C2),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roomButton(
    String label,
    Color iconColor, {
    required bool enabled,
    String? unreadLabel,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: ValueKey('clients-room-$label'),
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        child: Row(
          children: [
            Icon(Icons.circle, size: 8, color: iconColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color: enabled
                      ? const Color(0xFFEAF1FB)
                      : const Color(0xFF6B7A90),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (unreadLabel != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0x1AEF4444),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0x66EF4444)),
                ),
                child: Text(
                  unreadLabel,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFFF7D8A),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0x669BB0CE),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeLanesSection({
    required _ClientOption currentClient,
    required _SiteOption currentSite,
    required List<_ClientOption> clients,
    required List<_SiteOption> sites,
    required int pendingAsks,
  }) {
    final currentMetrics = _laneMetrics(
      clientId: currentClient.id,
      siteId: currentSite.id,
    );
    final laneCards =
        <
          ({
            _ClientOption client,
            _SiteOption site,
            bool active,
            int pendingDrafts,
            int alerts,
            int feedCount,
            int incidents,
          })
        >[
          (
            client: currentClient,
            site: currentSite,
            active: true,
            pendingDrafts: pendingAsks,
            alerts: currentMetrics.alerts,
            feedCount: currentMetrics.feedCount,
            incidents: currentMetrics.incidents,
          ),
          for (final client
              in clients
                  .where((client) => client.id != currentClient.id)
                  .take(2))
            () {
              final laneSite = sites.firstWhere(
                (site) => site.clientId == client.id,
                orElse: () => currentSite,
              );
              final metrics = _laneMetrics(
                clientId: client.id,
                siteId: laneSite.id,
              );
              return (
                client: client,
                site: laneSite,
                active: false,
                pendingDrafts: metrics.pendingDrafts,
                alerts: metrics.alerts,
                feedCount: metrics.feedCount,
                incidents: metrics.incidents,
              );
            }(),
        ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACTIVE LANES',
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 920;
              final width = stacked
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 12) / 3;
              return Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final lane in laneCards)
                    InkWell(
                      key: ValueKey(
                        'clients-active-lane-card-${lane.client.id}-${lane.site.id}',
                      ),
                      onTap: () => _selectClientSite(
                        lane.client.id,
                        lane.site.id,
                        source: 'active_lane_card',
                      ),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: width,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: lane.active
                              ? const Color(0xFF15263C)
                              : const Color(0xFF0D1117),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: lane.active
                                ? const Color(0xFF1F7AE0)
                                : const Color(0xFF223244),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    lane.client.name,
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFFF8FBFF),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: lane.active
                                        ? const Color(0x1A1F7AE0)
                                        : const Color(0x14000000),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: lane.active
                                          ? const Color(0x661F7AE0)
                                          : const Color(0xFF223244),
                                    ),
                                  ),
                                  child: Text(
                                    lane.active ? 'ACTIVE' : 'OPEN LANE',
                                    style: GoogleFonts.inter(
                                      color: lane.active
                                          ? const Color(0xFF8FD1FF)
                                          : const Color(0xFF9BB0CE),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (lane.pendingDrafts > 0) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: const Color(0x1AF59E0B),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0x66F59E0B),
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${lane.pendingDrafts}',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFFBBF24),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${lane.client.code} • ${lane.site.name}',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF95A6BE),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x331A0F3F),
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: const Color(0x665E31A6),
                                ),
                              ),
                              child: Text(
                                '# ROOM-${lane.site.code}',
                                style: GoogleFonts.robotoMono(
                                  color: const Color(0xFFC084FC),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _clientsWorkspaceChip(
                                  label: 'Feed',
                                  value: '${lane.feedCount}',
                                  accent: const Color(0xFF67E8F9),
                                ),
                                _clientsWorkspaceChip(
                                  label: 'Alerts',
                                  value: '${lane.alerts}',
                                  accent: lane.alerts > 0
                                      ? const Color(0xFFFBBF24)
                                      : const Color(0xFF8EA4C2),
                                ),
                                _clientsWorkspaceChip(
                                  label: 'Incidents',
                                  value: '${lane.incidents}',
                                  accent: lane.incidents > 0
                                      ? const Color(0xFF34D399)
                                      : const Color(0xFF8EA4C2),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              lane.active
                                  ? 'This lane is currently driving the client communications workspace.'
                                  : 'Tap to switch the workspace, thread context, and message feed to this lane.',
                              style: GoogleFonts.inter(
                                color: lane.active
                                    ? const Color(0xFF9ED9E8)
                                    : const Color(0xFF8EA4C2),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _roomThreadContextCard({
    required _ClientOption currentClient,
    required _SiteOption currentSite,
    required List<_ClientOption> clients,
    required List<_SiteOption> sites,
    required List<_SiteOption> availableSites,
  }) {
    final roomRoutingAvailable = widget.onOpenClientRoomForScope != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ROOM & THREAD CONTEXT',
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFEAF4FF),
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'Active communication channels',
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 940;
              final selectors = [
                _selectorSurface(
                  label: 'CLIENT',
                  value: _selectedClientId!,
                  items: [
                    for (final client in clients)
                      DropdownMenuItem<String>(
                        value: client.id,
                        child: Text('${client.name} (${client.code})'),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    final nextSites = sites
                        .where((site) => site.clientId == value)
                        .toList(growable: false);
                    if (nextSites.isEmpty) return;
                    _selectClientSite(
                      value,
                      nextSites.first.id,
                      source: 'client_selector',
                    );
                  },
                ),
                _selectorSurface(
                  label: 'SITE',
                  value: _selectedSiteId!,
                  items: [
                    for (final site in availableSites)
                      DropdownMenuItem<String>(
                        value: site.id,
                        child: Text('${site.name} (${site.code})'),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    _selectClientSite(
                      _selectedClientId!,
                      value,
                      source: 'site_selector',
                    );
                  },
                ),
              ];
              if (stacked) {
                return Column(
                  children: [
                    selectors[0],
                    const SizedBox(height: 6),
                    selectors[1],
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: selectors[0]),
                  const SizedBox(width: 6),
                  Expanded(child: selectors[1]),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 940;
              final roomId = 'ROOM-${currentSite.code}';
              final threadId = 'THREAD-${currentSite.code}';
              final roomCard = _contextPill(
                label: 'ROOM ID',
                value: '# $roomId',
                accent: const Color(0xFFC084FC),
                mono: true,
              );
              final threadCard = _contextPill(
                label: 'ACTIVE THREAD',
                value: '# $threadId',
                accent: const Color(0xFF22D3EE),
                mono: true,
              );
              if (stacked) {
                return Column(
                  children: [roomCard, const SizedBox(height: 8), threadCard],
                );
              }
              return Row(
                children: [
                  Expanded(child: roomCard),
                  const SizedBox(width: 6),
                  Expanded(child: threadCard),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF123140),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1F617C)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thread Active',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF5DE1FF),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'All messages are scoped to the active incident thread. Client responses route to ${currentClient.name}.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9ED9E8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 760;
              final children = [
                _roomButton(
                  'Residents',
                  const Color(0xFF22D3EE),
                  enabled: roomRoutingAvailable,
                  onTap: () => _openClientRoom('Residents'),
                ),
                _roomButton(
                  'Trustees',
                  const Color(0xFFC084FC),
                  enabled: roomRoutingAvailable,
                  onTap: () => _openClientRoom('Trustees'),
                ),
                _roomButton(
                  'Security Desk',
                  const Color(0xFF10B981),
                  unreadLabel: '2 unread',
                  enabled: roomRoutingAvailable,
                  onTap: () => _openClientRoom('Security Desk'),
                ),
              ];
              if (stacked) {
                return Column(
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      children[i],
                      if (i != children.length - 1) const SizedBox(height: 6),
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: children[0]),
                  const SizedBox(width: 6),
                  Expanded(child: children[1]),
                  const SizedBox(width: 6),
                  Expanded(child: children[2]),
                ],
              );
            },
          ),
          if (!roomRoutingAvailable) ...[
            const SizedBox(height: 8),
            Text(
              'Room routing is view-only in this session.',
              style: GoogleFonts.inter(
                color: const Color(0xFF6B7A90),
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _selectorSurface({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF0D1117),
              iconEnabledColor: const Color(0xFF9BB0CE),
              style: GoogleFonts.inter(
                color: const Color(0xFFEAF1FB),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _contextPill({
    required String label,
    required String value,
    required Color accent,
    bool mono = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: mono
                ? GoogleFonts.robotoMono(
                    color: accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  )
                : GoogleFonts.inter(
                    color: accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _communicationChannelsCard({
    required bool telegramBlocked,
    required bool smsFallbackActive,
    required bool voipReady,
    required bool voipStaged,
    required bool pushNeedsReview,
    required bool pushIdle,
    required bool backendProbeHealthy,
    required int pendingAsks,
  }) {
    final pushRetryAvailable = widget.onRetryPushSync != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COMMUNICATION CHANNELS',
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFEAF4FF),
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            _selectedClientId ?? '',
            style: GoogleFonts.inter(
              color: const Color(0xFF7F91AA),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _channelChip(
                label: telegramBlocked ? 'Telegram Blocked' : 'Telegram Ready',
                icon: Icons.check_circle_rounded,
                foreground: telegramBlocked
                    ? const Color(0xFFF87171)
                    : const Color(0xFF34D399),
                background: telegramBlocked
                    ? const Color(0x1AF87171)
                    : const Color(0x1A10B981),
                border: telegramBlocked
                    ? const Color(0x66F87171)
                    : const Color(0x6610B981),
              ),
              _channelChip(
                label: smsFallbackActive ? 'SMS Fallback' : 'SMS Idle',
                icon: Icons.sms_outlined,
                foreground: smsFallbackActive
                    ? const Color(0xFFFBBF24)
                    : const Color(0xFF8EA4C2),
                background: smsFallbackActive
                    ? const Color(0x1AF59E0B)
                    : const Color(0x1494A3B8),
                border: smsFallbackActive
                    ? const Color(0x66F59E0B)
                    : const Color(0x3394A3B8),
              ),
              _channelChip(
                label: voipStaged
                    ? 'VoIP Staging'
                    : voipReady
                    ? 'VoIP Ready'
                    : 'VoIP Idle',
                icon: Icons.phone_forwarded_rounded,
                foreground: voipStaged
                    ? const Color(0xFFFBBF24)
                    : voipReady
                    ? const Color(0xFF34D399)
                    : const Color(0xFF8EA4C2),
                background: voipStaged
                    ? const Color(0x1AF59E0B)
                    : voipReady
                    ? const Color(0x1A10B981)
                    : const Color(0x1494A3B8),
                border: voipStaged
                    ? const Color(0x66F59E0B)
                    : voipReady
                    ? const Color(0x6610B981)
                    : const Color(0x3394A3B8),
              ),
              _channelChip(
                label: pushNeedsReview
                    ? 'Push Review'
                    : pushIdle
                    ? 'Push Idle'
                    : 'Push Healthy',
                icon: Icons.notifications_active_outlined,
                foreground: pushNeedsReview
                    ? const Color(0xFFFBBF24)
                    : pushIdle
                    ? const Color(0xFF8EA4C2)
                    : const Color(0xFF8EA4C2),
                background: pushNeedsReview
                    ? const Color(0x1AF59E0B)
                    : pushIdle
                    ? const Color(0x1494A3B8)
                    : const Color(0x1494A3B8),
                border: pushNeedsReview
                    ? const Color(0x66F59E0B)
                    : pushIdle
                    ? const Color(0x3394A3B8)
                    : const Color(0x3394A3B8),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (voipStaged || voipReady)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF3A210E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF80511D)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    voipReady ? 'VoIP Call Active' : 'VoIP Call Staged',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFFBBF24),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    voipReady
                        ? 'Voice call is actively engaging the client escalation path.'
                        : 'Voice call queued for high-priority incident escalation. Ready to dial.',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFD7B47C),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 620;
                      final placeCall = _channelActionButton(
                        key: const ValueKey('clients-place-call-now-action'),
                        label: voipReady
                            ? 'Call In Progress'
                            : 'Place Call Now',
                        accent: const Color(0xFFFBBF24),
                        filled: true,
                        enabled: !voipReady,
                        onTap: voipReady
                            ? null
                            : () {
                                setState(() {
                                  _voipStageStatus = 'dialing';
                                  _backendProbeStatus = 'healthy';
                                  _pushSyncStatus = 'call engaged';
                                });
                                logUiAction(
                                  'clients.place_voip_call',
                                  context: {
                                    'client_id': _selectedClientId,
                                    'site_id': _selectedSiteId,
                                  },
                                );
                              },
                      );
                      final cancelStage = _channelActionButton(
                        key: const ValueKey('clients-cancel-stage-action'),
                        label: voipReady ? 'End Call' : 'Cancel Stage',
                        accent: const Color(0xFF9AA7B8),
                        filled: false,
                        onTap: () {
                          setState(() {
                            _voipStageStatus = 'idle';
                            _pushSyncStatus = 'push idle';
                          });
                          logUiAction(
                            'clients.cancel_voip_stage',
                            context: {
                              'client_id': _selectedClientId,
                              'site_id': _selectedSiteId,
                            },
                          );
                        },
                      );
                      if (stacked) {
                        return Column(
                          children: [
                            placeCall,
                            const SizedBox(height: 8),
                            cancelStage,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: placeCall),
                          const SizedBox(width: 8),
                          Expanded(child: cancelStage),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          if (voipStaged || voipReady) const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: backendProbeHealthy
                  ? const Color(0xFF123425)
                  : const Color(0xFF22181A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: backendProbeHealthy
                    ? const Color(0xFF1D7A55)
                    : const Color(0xFF6B2B30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Backend Probe',
                  style: GoogleFonts.inter(
                    color: backendProbeHealthy
                        ? const Color(0xFF34D399)
                        : const Color(0xFFF87171),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  backendProbeHealthy
                      ? 'Healthy • Last probe 5s ago'
                      : 'Backend status is $_backendProbeStatus. Push sync is ${_pushSyncStatus.toLowerCase()}.',
                  style: GoogleFonts.inter(
                    color: backendProbeHealthy
                        ? const Color(0xFF9CE5C8)
                        : const Color(0xFFD7A1A8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  key: const ValueKey('clients-retry-push-sync-action'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: !pushRetryAvailable ? null : _retryPushSync,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: pushRetryAvailable
                          ? const Color(0xFF5A340D)
                          : const Color(0xFF1B222B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: pushRetryAvailable
                            ? const Color(0xFF9A5B14)
                            : const Color(0xFF30363D),
                      ),
                    ),
                    child: Text(
                      pendingAsks > 0
                          ? 'Review Draft Queue'
                          : 'Retry Push Sync',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: pushRetryAvailable
                            ? const Color(0xFFFBBF24)
                            : const Color(0xFF6B7A90),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
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

  Widget _channelActionButton({
    required Key key,
    required String label,
    required Color accent,
    required bool filled,
    required VoidCallback? onTap,
    bool enabled = true,
  }) {
    return InkWell(
      key: key,
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: filled
              ? enabled
                    ? const Color(0xFF5A340D)
                    : const Color(0xFF1B222B)
              : const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: filled
                ? enabled
                      ? const Color(0xFF9A5B14)
                      : const Color(0xFF30363D)
                : const Color(0xFF30363D),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: enabled ? accent : const Color(0xFF6B7A90),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _channelChip({
    required String label,
    required IconData icon,
    required Color foreground,
    required Color background,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: foreground, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageHistoryCard(List<_FeedRow> rows) {
    return Container(
      key: _messageHistoryKey,
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MESSAGE HISTORY',
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFEAF4FF),
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Recent client communications',
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          for (final row in rows) ...[_feedRow(row), const SizedBox(height: 8)],
        ],
      ),
    );
  }

  Widget _pendingDraftsCard({
    required int pendingAsks,
    required int activeIncidents,
    required String? reviewEventId,
  }) {
    return _railCard(
      title: 'PENDING AI DRAFTS',
      icon: Icons.chat_bubble_outline_rounded,
      accent: const Color(0xFFFBBF24),
      child: Column(
        children: [
          Text(
            '$pendingAsks',
            style: GoogleFonts.inter(
              color: const Color(0xFFFBBF24),
              fontSize: 36,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            'Awaiting review',
            style: GoogleFonts.inter(
              color: const Color(0xFFB7A56C),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            key: const ValueKey('clients-review-drafts-action'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => _reviewPendingDrafts(reviewEventId),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF3A2A11),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF7E5B1D)),
              ),
              child: Text(
                'REVIEW DRAFTS',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: const Color(0xFFFBBF24),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF11161D),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF2A3645)),
            ),
            child: Text(
              '$activeIncidents active lane${activeIncidents == 1 ? '' : 's'}',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: const Color(0xFFC7D2DE),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _learnedStyleCard() {
    return _railCard(
      title: 'LEARNED STYLE',
      icon: Icons.auto_graph_rounded,
      accent: const Color(0xFFC084FC),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF24142F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF5E31A6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"Reassuring with ETAs"',
              style: GoogleFonts.inter(
                color: const Color(0xFFEBC8FF),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'AI-detected from approval history',
              style: GoogleFonts.inter(
                color: const Color(0xFFA88BC4),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pinnedVoiceCard() {
    return _railCard(
      title: 'PINNED VOICE',
      icon: Icons.shield_outlined,
      accent: const Color(0xFF8FD1FF),
      child: Column(
        children: [
          _voiceOption('Auto', selected: _selectedPinnedVoice == 'Auto'),
          const SizedBox(height: 8),
          _voiceOption('Concise', selected: _selectedPinnedVoice == 'Concise'),
          const SizedBox(height: 8),
          _voiceOption(
            'Reassuring',
            selected: _selectedPinnedVoice == 'Reassuring',
          ),
          const SizedBox(height: 8),
          _voiceOption('Formal', selected: _selectedPinnedVoice == 'Formal'),
        ],
      ),
    );
  }

  Widget _voiceOption(String label, {bool selected = false}) {
    return InkWell(
      key: ValueKey('clients-pinned-voice-$label'),
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        setState(() => _selectedPinnedVoice = label);
        logUiAction(
          'clients.select_pinned_voice',
          context: {
            'voice': label,
            'client_id': _selectedClientId,
            'site_id': _selectedSiteId,
          },
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF123140) : const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF1F617C) : const Color(0xFF223244),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: selected ? const Color(0xFF5DE1FF) : const Color(0xFFC7D2DE),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _railCard({
    required String title,
    required IconData icon,
    required Color accent,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEAF4FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  void _openClientRoom(String room) {
    final callback = widget.onOpenClientRoomForScope;
    if (callback == null) return;
    logUiAction(
      'clients.open_room',
      context: {
        'room': room,
        'client_id': _selectedClientId,
        'site_id': _selectedSiteId,
      },
    );
    callback(room, _selectedClientId!, _selectedSiteId!);
  }

  Future<void> _retryPushSync() async {
    final callback = widget.onRetryPushSync;
    if (callback == null) return;
    setState(() {
      _pushRetryCount += 1;
      _pushSyncStatus = 'retry in flight';
      _backendProbeStatus = 'healthy';
    });
    logUiAction(
      'clients.retry_push_sync',
      context: {
        'retries': _pushRetryCount,
        'client_id': _selectedClientId,
        'site_id': _selectedSiteId,
      },
    );
    await callback();
  }

  void _selectClientSite(
    String clientId,
    String siteId, {
    required String source,
  }) {
    if (_selectedClientId == clientId && _selectedSiteId == siteId) {
      return;
    }
    setState(() {
      _selectedClientId = clientId;
      _selectedSiteId = siteId;
    });
    logUiAction(
      'clients.select_lane',
      context: {'client_id': clientId, 'site_id': siteId, 'source': source},
    );
  }

  ({int pendingDrafts, int alerts, int feedCount, int incidents}) _laneMetrics({
    required String clientId,
    required String siteId,
  }) {
    var rows = _incidentFeedRows(
      events: widget.events,
      selectedClientId: clientId,
      selectedSiteId: siteId,
    );
    if (rows.isEmpty &&
        clientId == _selectedClientId &&
        siteId == _selectedSiteId) {
      rows = _fallbackFeed;
    }
    return (
      pendingDrafts: rows.where((row) => row.type == _FeedType.update).length,
      alerts: rows.where((row) => row.status != _FeedStatus.info).length,
      feedCount: rows.length,
      incidents: widget.events
          .whereType<DecisionCreated>()
          .where(
            (event) => event.clientId == clientId && event.siteId == siteId,
          )
          .length,
    );
  }

  void _reviewPendingDrafts(String? reviewEventId) {
    if (reviewEventId != null && widget.onOpenEventsForScope != null) {
      logUiAction(
        'clients.review_pending_drafts',
        context: {
          'event_id': reviewEventId,
          'client_id': _selectedClientId,
          'site_id': _selectedSiteId,
        },
      );
      widget.onOpenEventsForScope!.call(<String>[reviewEventId], reviewEventId);
      return;
    }
    _scrollToMessageHistory();
  }

  void _scrollToMessageHistory() {
    final context = _messageHistoryKey.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }
}

enum _FeedType { dispatch, arrival, update, resolution }

enum _FeedStatus { info, success, warning }

class _FeedRow {
  final _FeedType type;
  final _FeedStatus status;
  final String title;
  final String description;
  final String timestampLabel;
  final String? eventId;

  const _FeedRow({
    required this.type,
    required this.status,
    required this.title,
    required this.description,
    required this.timestampLabel,
    this.eventId,
  });
}

class _ClientOption {
  final String id;
  final String name;
  final String code;

  const _ClientOption({
    required this.id,
    required this.name,
    required this.code,
  });
}

class _SiteOption {
  final String id;
  final String name;
  final String code;
  final String clientId;

  const _SiteOption({
    required this.id,
    required this.name,
    required this.code,
    required this.clientId,
  });
}

class _ClientSiteModel {
  final List<_ClientOption> clients;
  final List<_SiteOption> sites;

  const _ClientSiteModel({required this.clients, required this.sites});
}

const List<_ClientOption> _fallbackClients = [
  _ClientOption(
    id: 'CLIENT-001',
    name: 'Northern Residential Portfolio',
    code: 'NRP-OPS',
  ),
  _ClientOption(
    id: 'CLIENT-002',
    name: 'Blue Ridge Operations',
    code: 'BLR-OPS',
  ),
  _ClientOption(
    id: 'CLIENT-003',
    name: 'Centurion Commerce Campus',
    code: 'CNT-CAMP',
  ),
];

const List<_SiteOption> _fallbackSites = [
  _SiteOption(
    id: 'SITE-SANDTON',
    name: 'North Residential Cluster',
    code: 'SITE-SANDTON',
    clientId: 'CLIENT-001',
  ),
  _SiteOption(
    id: 'SITE-WTF-MAIN',
    name: 'Central Access Gate',
    code: 'SITE-WTF-MAIN',
    clientId: 'CLIENT-001',
  ),
  _SiteOption(
    id: 'SITE-BLR',
    name: 'Blue Ridge Response Hub',
    code: 'SITE-BLR',
    clientId: 'CLIENT-002',
  ),
];

const List<_FeedRow> _fallbackFeed = [
  _FeedRow(
    type: _FeedType.arrival,
    status: _FeedStatus.success,
    title: 'Responder On Site',
    description: 'Response unit arrived for DSP-4 and is checking the lane.',
    timestampLabel: '19:47 UTC',
  ),
  _FeedRow(
    type: _FeedType.dispatch,
    status: _FeedStatus.info,
    title: 'Dispatch Activated',
    description: 'DSP-4 opened for the North Residential Cluster.',
    timestampLabel: '19:38 UTC',
  ),
  _FeedRow(
    type: _FeedType.arrival,
    status: _FeedStatus.success,
    title: 'Responder On Site',
    description: 'Response unit arrived for DSP-3 and is checking the lane.',
    timestampLabel: '18:53 UTC',
  ),
  _FeedRow(
    type: _FeedType.dispatch,
    status: _FeedStatus.info,
    title: 'Dispatch Activated',
    description: 'DSP-3 opened for the North Residential Cluster.',
    timestampLabel: '18:38 UTC',
  ),
  _FeedRow(
    type: _FeedType.arrival,
    status: _FeedStatus.success,
    title: 'Responder On Site',
    description: 'Response unit arrived for DSP-2 and is checking the lane.',
    timestampLabel: '17:47 UTC',
  ),
  _FeedRow(
    type: _FeedType.dispatch,
    status: _FeedStatus.info,
    title: 'Dispatch Activated',
    description: 'DSP-2 opened for the North Residential Cluster.',
    timestampLabel: '17:38 UTC',
  ),
];

_ClientSiteModel _deriveClientSiteModel(List<DispatchEvent> events) {
  final clientsById = <String, _ClientOption>{};
  final sitesById = <String, _SiteOption>{};

  for (final event in events) {
    final clientId = _eventClientId(event);
    final siteId = _eventSiteId(event);
    if (clientId.isNotEmpty && !clientsById.containsKey(clientId)) {
      clientsById[clientId] = _ClientOption(
        id: clientId,
        name: _humanizeName(clientId, prefix: 'CLIENT-'),
        code: clientId,
      );
    }
    if (siteId.isNotEmpty && !sitesById.containsKey(siteId)) {
      sitesById[siteId] = _SiteOption(
        id: siteId,
        name: _humanizeName(siteId, prefix: 'SITE-'),
        code: siteId,
        clientId: clientId.isEmpty ? 'CLIENT-UNKNOWN' : clientId,
      );
    }
  }

  final clients = clientsById.values.toList(growable: false)
    ..sort((a, b) => a.id.compareTo(b.id));
  final sites = sitesById.values.toList(growable: false)
    ..sort((a, b) => a.id.compareTo(b.id));
  return _ClientSiteModel(clients: clients, sites: sites);
}

List<_FeedRow> _incidentFeedRows({
  required List<DispatchEvent> events,
  required String selectedClientId,
  required String selectedSiteId,
}) {
  final rows = <_FeedRow>[];
  final scoped =
      events
          .where(
            (event) =>
                _eventClientId(event) == selectedClientId &&
                _eventSiteId(event) == selectedSiteId,
          )
          .toList(growable: false)
        ..sort((a, b) => b.sequence.compareTo(a.sequence));

  for (final event in scoped) {
    if (event is ResponseArrived) {
      rows.add(
        _FeedRow(
          type: _FeedType.arrival,
          status: _FeedStatus.success,
          title: 'Officer Arrived',
          description: '${event.guardId} arrived for ${event.dispatchId}.',
          timestampLabel: _utc(event.occurredAt),
          eventId: event.eventId,
        ),
      );
      continue;
    }
    if (event is DecisionCreated) {
      rows.add(
        _FeedRow(
          type: _FeedType.dispatch,
          status: _FeedStatus.info,
          title: 'Dispatch Created',
          description: '${event.dispatchId} opened for ${event.siteId}.',
          timestampLabel: _utc(event.occurredAt),
          eventId: event.eventId,
        ),
      );
      continue;
    }
    if (event is IntelligenceReceived) {
      rows.add(
        _FeedRow(
          type: _FeedType.update,
          status: _FeedStatus.warning,
          title: 'Client Advisory',
          description: event.headline,
          timestampLabel: _utc(event.occurredAt),
          eventId: event.eventId,
        ),
      );
      continue;
    }
    if (event is IncidentClosed) {
      rows.add(
        _FeedRow(
          type: _FeedType.resolution,
          status: _FeedStatus.success,
          title: 'Incident Resolved',
          description: '${event.dispatchId} closed for ${event.siteId}.',
          timestampLabel: _utc(event.occurredAt),
          eventId: event.eventId,
        ),
      );
      continue;
    }
  }

  return rows;
}

String _eventClientId(DispatchEvent event) {
  if (event is DecisionCreated) return event.clientId;
  if (event is ResponseArrived) return event.clientId;
  if (event is IntelligenceReceived) return event.clientId;
  if (event is IncidentClosed) return event.clientId;
  return '';
}

String _eventSiteId(DispatchEvent event) {
  if (event is DecisionCreated) return event.siteId;
  if (event is ResponseArrived) return event.siteId;
  if (event is IntelligenceReceived) return event.siteId;
  if (event is IncidentClosed) return event.siteId;
  return '';
}

String _humanizeName(String raw, {required String prefix}) {
  final stripped = raw.replaceFirst(prefix, '');
  final words = stripped
      .replaceAll('_', '-')
      .split('-')
      .where((part) => part.isNotEmpty)
      .map((part) {
        final lower = part.toLowerCase();
        return '${lower[0].toUpperCase()}${lower.substring(1)}';
      })
      .toList(growable: false);
  if (words.isEmpty) return raw;
  return words.join(' ');
}

String _utc(DateTime value) {
  final utc = value.toUtc();
  final hh = utc.hour.toString().padLeft(2, '0');
  final mm = utc.minute.toString().padLeft(2, '0');
  return '$hh:$mm UTC';
}

IconData _feedIcon(_FeedType type) {
  switch (type) {
    case _FeedType.dispatch:
      return Icons.shield_outlined;
    case _FeedType.arrival:
      return Icons.check_circle_outline_rounded;
    case _FeedType.update:
      return Icons.warning_amber_rounded;
    case _FeedType.resolution:
      return Icons.task_alt_rounded;
  }
}

Color _feedColor(_FeedStatus status) {
  switch (status) {
    case _FeedStatus.info:
      return const Color(0xFF22D3EE);
    case _FeedStatus.success:
      return const Color(0xFF10B981);
    case _FeedStatus.warning:
      return const Color(0xFFF59E0B);
  }
}
