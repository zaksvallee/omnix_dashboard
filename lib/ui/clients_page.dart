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
  String? _selectedClientId;
  String? _selectedSiteId;
  int _pushRetryCount = 0;
  String _pushSyncStatus = 'ok';
  String _backendProbeStatus = 'idle';

  @override
  void initState() {
    super.initState();
    _selectedClientId = widget.clientId;
    _selectedSiteId = widget.siteId;
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

    return OnyxPageScaffold(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1540),
            child: ListView(
              children: [
                OnyxPageHeader(
                  title:
                      'Client Operations — ${currentClient.code} / ${currentSite.code}',
                  subtitle:
                      'Push alerts, estate rooms, incident visibility, and direct client communications.',
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 920;
                    if (compact) {
                      return Column(
                        children: [
                          _selectorField(
                            label: 'Client',
                            value: _selectedClientId!,
                            items: [
                              for (final client in clients)
                                DropdownMenuItem<String>(
                                  value: client.id,
                                  child: Text(
                                    '${client.name} (${client.code})',
                                  ),
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
                          const SizedBox(height: 8),
                          _selectorField(
                            label: 'Site',
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
                        ],
                      );
                    }

                    return Row(
                      children: [
                        SizedBox(
                          width: 320,
                          child: _selectorField(
                            label: 'Client',
                            value: _selectedClientId!,
                            items: [
                              for (final client in clients)
                                DropdownMenuItem<String>(
                                  value: client.id,
                                  child: Text(
                                    '${client.name} (${client.code})',
                                  ),
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
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 320,
                          child: _selectorField(
                            label: 'Site',
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
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final cardWidth = width < 740
                        ? width
                        : width < 1140
                        ? (width - 8) / 2
                        : (width - 24) / 4;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _metricCard(
                          width: cardWidth,
                          label: 'Unread Alerts',
                          value: '$unreadAlerts',
                          valueColor: const Color(0xFFEAF1FB),
                          icon: Icons.notifications_none_rounded,
                          iconColor: const Color(0xFFFBBF24),
                          iconBg: const Color(0x1AF59E0B),
                        ),
                        _metricCard(
                          width: cardWidth,
                          label: 'Active Incidents',
                          value: '$activeIncidents',
                          valueColor: const Color(0xFFEF4444),
                          icon: Icons.shield_outlined,
                          iconColor: const Color(0xFFEF4444),
                          iconBg: const Color(0x1AEF4444),
                        ),
                        _metricCard(
                          width: cardWidth,
                          label: 'Direct Chat',
                          value: '$directUpdates updates',
                          valueColor: const Color(0xFF22D3EE),
                          icon: Icons.chat_bubble_outline_rounded,
                          iconColor: const Color(0xFF22D3EE),
                          iconBg: const Color(0x1A22D3EE),
                        ),
                        _metricCard(
                          width: cardWidth,
                          label: 'Client Asks Pending',
                          value: '$pendingAsks',
                          valueColor: const Color(0xFFEAF1FB),
                          icon: Icons.error_outline_rounded,
                          iconColor: const Color(0xFFC084FC),
                          iconBg: const Color(0x1AC084FC),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 1220;
                    final feed = _incidentFeedCard(rows);
                    final side = Column(
                      children: [
                        _pushDeliveryQueueCard(),
                        const SizedBox(height: 8),
                        _estateRoomsCard(),
                      ],
                    );
                    if (stacked) {
                      return Column(
                        children: [feed, const SizedBox(height: 8), side],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: feed),
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

  Widget _selectorField({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF30363D)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF0D1117),
              iconEnabledColor: const Color(0xFF9BB0CE),
              style: GoogleFonts.inter(
                color: const Color(0xFFEAF1FB),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _metricCard({
    required double width,
    required String label,
    required String value,
    required Color valueColor,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9BB0CE),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    color: valueColor,
                    fontSize: 35,
                    height: 0.95,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 19),
          ),
        ],
      ),
    );
  }

  Widget _incidentFeedCard(List<_FeedRow> rows) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Incident Feed',
            style: GoogleFonts.inter(
              color: const Color(0xFFEAF1FB),
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Chronological dispatch, arrival, and advisory milestones.',
            style: GoogleFonts.inter(
              color: const Color(0xFF9BB0CE),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          for (final row in rows) ...[_feedRow(row), const SizedBox(height: 8)],
        ],
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

  Widget _pushDeliveryQueueCard() {
    final pushRetryAvailable = widget.onRetryPushSync != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Push Delivery Queue',
            style: GoogleFonts.inter(
              color: const Color(0xFFEAF1FB),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Push-only alerts prepared for mobile delivery with acknowledgment tracking.',
            style: GoogleFonts.inter(
              color: const Color(0xFF9BB0CE),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _statusLine(
            'Push Sync:',
            _statusPill(
              _pushSyncStatus,
              _pushSyncStatus == 'ok'
                  ? const Color(0xFF10B981)
                  : const Color(0xFFF59E0B),
              _pushSyncStatus == 'ok'
                  ? const Color(0x1A10B981)
                  : const Color(0x1AF59E0B),
            ),
          ),
          const SizedBox(height: 6),
          _statusLine(
            'Backend Probe:',
            _statusPill(
              _backendProbeStatus,
              _backendProbeStatus == 'idle'
                  ? const Color(0xFF9BB0CE)
                  : const Color(0xFFF59E0B),
              _backendProbeStatus == 'idle'
                  ? const Color(0x1A9BB0CE)
                  : const Color(0x1AF59E0B),
            ),
          ),
          const SizedBox(height: 6),
          _statusLine(
            'Retries:',
            Text(
              '$_pushRetryCount',
              style: GoogleFonts.inter(
                color: const Color(0xFFEAF1FB),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            key: const ValueKey('clients-retry-push-sync-action'),
            borderRadius: BorderRadius.circular(8),
            onTap: !pushRetryAvailable
                ? null
                : () async {
                    setState(() {
                      _pushRetryCount += 1;
                      _pushSyncStatus = 'retry in flight';
                      _backendProbeStatus = 'queued for delivery check';
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: pushRetryAvailable
                    ? const Color(0x1A3B82F6)
                    : const Color(0x149BB0CE),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: pushRetryAvailable
                      ? const Color(0x4D3B82F6)
                      : const Color(0x3330363D),
                ),
              ),
              child: Text(
                'Retry Push Sync',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: pushRetryAvailable
                      ? const Color(0xFF63BDFF)
                      : const Color(0xFF6B7A90),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _estateRoomsCard() {
    final roomRoutingAvailable = widget.onOpenClientRoomForScope != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Estate Rooms',
                style: GoogleFonts.inter(
                  color: const Color(0xFFEAF1FB),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1117),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: const Icon(
                  Icons.apartment_rounded,
                  color: Color(0x339BB0CE),
                  size: 30,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Residents, trustees, and control channels in one client surface.',
            style: GoogleFonts.inter(
              color: const Color(0xFF9BB0CE),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!roomRoutingAvailable) ...[
            const SizedBox(height: 8),
            Text(
              'Room routing is view-only in this session.',
              style: GoogleFonts.inter(
                color: const Color(0xFF6B7A90),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          _roomButton(
            'Residents',
            const Color(0xFF22D3EE),
            enabled: roomRoutingAvailable,
            onTap: () => _openClientRoom('Residents'),
          ),
          const SizedBox(height: 6),
          _roomButton(
            'Trustees',
            const Color(0xFFC084FC),
            enabled: roomRoutingAvailable,
            onTap: () => _openClientRoom('Trustees'),
          ),
          const SizedBox(height: 6),
          _roomButton(
            'Security Desk',
            const Color(0xFF10B981),
            unreadLabel: '2 unread',
            enabled: roomRoutingAvailable,
            onTap: () => _openClientRoom('Security Desk'),
          ),
        ],
      ),
    );
  }

  Widget _statusLine(String label, Widget right) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(0xFF9BB0CE),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        right,
      ],
    );
  }

  Widget _statusPill(String text, Color color, Color background) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
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
