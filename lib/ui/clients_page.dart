import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../domain/events/decision_created.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/incident_closed.dart';
import '../domain/events/intelligence_received.dart';
import '../domain/events/response_arrived.dart';
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
  final ScrollController _scrollController = ScrollController();
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
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1540),
            child: ListView(
              controller: _scrollController,
              children: [
                _heroHeader(
                  currentClient: currentClient,
                  currentSite: currentSite,
                  unreadAlerts: unreadAlerts,
                  pendingAsks: pendingAsks,
                  directUpdates: directUpdates,
                ),
                const SizedBox(height: 8),
                _activeLanesSection(
                  currentClient: currentClient,
                  currentSite: currentSite,
                  clients: clients,
                  sites: availableSites,
                  pendingAsks: pendingAsks,
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 1220;
                    final primary = Column(
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
                    final side = Column(
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
                    if (stacked) {
                      return Column(
                        children: [primary, const SizedBox(height: 8), side],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: primary),
                        const SizedBox(width: 8),
                        Expanded(flex: 1, child: side),
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

  Widget _heroHeader({
    required _ClientOption currentClient,
    required _SiteOption currentSite,
    required int unreadAlerts,
    required int pendingAsks,
    required int directUpdates,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 980;
        final chips = Wrap(
          spacing: 8,
          runSpacing: 8,
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
              label: '$unreadAlerts Unread Alert${unreadAlerts == 1 ? '' : 's'}',
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
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF0891B2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x332563EB),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.business_center_rounded,
                  size: 30,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Client Communications',
                      style: GoogleFonts.rajdhani(
                        color: const Color(0xFFEAF4FF),
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lane management, incident visibility, and direct client notification status.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF93A9C6),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    chips,
                  ],
                ),
              ),
            ],
          ),
        );
        final snapshotCard = Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF223244)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lane Snapshot',
                style: GoogleFonts.inter(
                  color: const Color(0xFFEAF4FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${currentClient.name} • ${currentSite.name}',
                style: GoogleFonts.inter(
                  color: const Color(0xFF9BB0CE),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$directUpdates total updates in the visible incident feed',
                style: GoogleFonts.inter(
                  color: const Color(0xFF8FD1FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF111722), Color(0xFF0D1117)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF223244)),
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [titleBlock]),
                    const SizedBox(height: 14),
                    snapshotCard,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleBlock,
                    const SizedBox(width: 16),
                    SizedBox(width: 260, child: snapshotCard),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: foreground,
          fontSize: 10.5,
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
      borderRadius: BorderRadius.circular(10),
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
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0x14FFFFFF),
                shape: BoxShape.circle,
              ),
              child: Icon(_feedIcon(row.type), color: rowColor, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.title,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFEAF1FB),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    row.description,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF9BB0CE),
                      fontSize: 12,
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
                fontSize: 11,
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(8),
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
                  fontSize: 12,
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
                    fontSize: 10,
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
    final laneCards = <({
      String title,
      String subtitle,
      String room,
      bool active,
      int pending,
    })>[
      (
        title: currentClient.name,
        subtitle: currentClient.code,
        room: '# ROOM-${currentSite.code}',
        active: true,
        pending: pendingAsks,
      ),
      for (final client in clients.where((client) => client.id != currentClient.id).take(2))
        (
          title: client.name,
          subtitle: client.code,
          room:
              '# ROOM-${sites.firstWhere((site) => site.clientId == client.id, orElse: () => currentSite).code}',
          active: false,
          pending: 0,
        ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACTIVE LANES',
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 920;
              final width = stacked
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 16) / 3;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final lane in laneCards)
                    Container(
                      width: width,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: lane.active
                            ? const Color(0xFF15263C)
                            : const Color(0xFF0D1117),
                        borderRadius: BorderRadius.circular(16),
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
                                  lane.title,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFFF8FBFF),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (lane.pending > 0)
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0x1AF59E0B),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0x66F59E0B),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${lane.pending}',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFFFBBF24),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            lane.subtitle,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF95A6BE),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x331A0F3F),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0x665E31A6),
                              ),
                            ),
                            child: Text(
                              lane.room,
                              style: GoogleFonts.robotoMono(
                                color: const Color(0xFFC084FC),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ROOM & THREAD CONTEXT',
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFEAF4FF),
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'Active communication channels',
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
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
                    setState(() {
                      _selectedClientId = value;
                      final nextSites = sites
                          .where((site) => site.clientId == value)
                          .toList(growable: false);
                      if (nextSites.isNotEmpty) {
                        _selectedSiteId = nextSites.first.id;
                      }
                    });
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
                    setState(() => _selectedSiteId = value);
                  },
                ),
              ];
              if (stacked) {
                return Column(
                  children: [
                    selectors[0],
                    const SizedBox(height: 8),
                    selectors[1],
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: selectors[0]),
                  const SizedBox(width: 8),
                  Expanded(child: selectors[1]),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
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
                  children: [
                    roomCard,
                    const SizedBox(height: 8),
                    threadCard,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: roomCard),
                  const SizedBox(width: 8),
                  Expanded(child: threadCard),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF123140),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1F617C)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thread Active',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF5DE1FF),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'All messages are scoped to the active incident thread. Client responses route to ${currentClient.name}.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9ED9E8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
                      if (i != children.length - 1) const SizedBox(height: 8),
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: children[0]),
                  const SizedBox(width: 8),
                  Expanded(child: children[1]),
                  const SizedBox(width: 8),
                  Expanded(child: children[2]),
                ],
              );
            },
          ),
          if (!roomRoutingAvailable) ...[
            const SizedBox(height: 10),
            Text(
              'Room routing is view-only in this session.',
              style: GoogleFonts.inter(
                color: const Color(0xFF6B7A90),
                fontSize: 10,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 11,
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
                fontSize: 13,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: mono
                ? GoogleFonts.robotoMono(
                    color: accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  )
                : GoogleFonts.inter(
                    color: accent,
                    fontSize: 14,
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COMMUNICATION CHANNELS',
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFEAF4FF),
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            _selectedClientId ?? '',
            style: GoogleFonts.inter(
              color: const Color(0xFF7F91AA),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
          const SizedBox(height: 14),
          if (voipStaged || voipReady)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF3A210E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF80511D)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    voipReady ? 'VoIP Call Active' : 'VoIP Call Staged',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFFBBF24),
                      fontSize: 15,
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
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 620;
                      final placeCall = _channelActionButton(
                        key: const ValueKey('clients-place-call-now-action'),
                        label: voipReady ? 'Call In Progress' : 'Place Call Now',
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
                            const SizedBox(height: 10),
                            cancelStage,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: placeCall),
                          const SizedBox(width: 10),
                          Expanded(child: cancelStage),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          if (voipStaged || voipReady) const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: backendProbeHealthy
                  ? const Color(0xFF123425)
                  : const Color(0xFF22181A),
              borderRadius: BorderRadius.circular(16),
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
                    fontSize: 15,
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
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                InkWell(
                  key: const ValueKey('clients-retry-push-sync-action'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: !pushRetryAvailable
                      ? null
                      : () async {
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
                          await widget.onRetryPushSync!.call();
                        },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: pushRetryAvailable
                          ? const Color(0xFF5A340D)
                          : const Color(0xFF1B222B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: pushRetryAvailable
                            ? const Color(0xFF9A5B14)
                            : const Color(0xFF30363D),
                      ),
                    ),
                    child: Text(
                      pendingAsks > 0 ? 'Review Draft Queue' : 'Retry Push Sync',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: pushRetryAvailable
                            ? const Color(0xFFFBBF24)
                            : const Color(0xFF6B7A90),
                        fontSize: 12,
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: filled
              ? enabled
                    ? const Color(0xFF5A340D)
                    : const Color(0xFF1B222B)
              : const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(12),
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
            fontSize: 12,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: foreground, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              color: foreground,
              fontSize: 12,
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MESSAGE HISTORY',
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFEAF4FF),
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Recent client communications',
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
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
              fontSize: 44,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            'Awaiting review',
            style: GoogleFonts.inter(
              color: const Color(0xFFB7A56C),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            key: const ValueKey('clients-review-drafts-action'),
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              if (reviewEventId != null && widget.onOpenEventsForScope != null) {
                logUiAction(
                  'clients.review_pending_drafts',
                  context: {
                    'event_id': reviewEventId,
                    'client_id': _selectedClientId,
                    'site_id': _selectedSiteId,
                  },
                );
                widget.onOpenEventsForScope!.call(
                  <String>[reviewEventId],
                  reviewEventId,
                );
                return;
              }
              _scrollToMessageHistory();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF3A2A11),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF7E5B1D)),
              ),
              child: Text(
                'REVIEW DRAFTS',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: const Color(0xFFFBBF24),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF11161D),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A3645)),
            ),
            child: Text(
              '$activeIncidents active lane${activeIncidents == 1 ? '' : 's'}',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: const Color(0xFFC7D2DE),
                fontSize: 12,
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF24142F),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF5E31A6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"Reassuring with ETAs"',
              style: GoogleFonts.inter(
                color: const Color(0xFFEBC8FF),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'AI-detected from approval history',
              style: GoogleFonts.inter(
                color: const Color(0xFFA88BC4),
                fontSize: 12,
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
          _voiceOption(
            'Concise',
            selected: _selectedPinnedVoice == 'Concise',
          ),
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
      borderRadius: BorderRadius.circular(12),
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
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF123140) : const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? const Color(0xFF1F617C)
                : const Color(0xFF223244),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: selected
                ? const Color(0xFF5DE1FF)
                : const Color(0xFFC7D2DE),
            fontSize: 12,
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 18),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.inter(
                  color: const Color(0xFFEAF4FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
