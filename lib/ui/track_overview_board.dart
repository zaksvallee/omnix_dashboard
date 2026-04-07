import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _trackShellBackground = Color(0xFF09121B);
const _trackShellRailBackground = Color(0xFF060D15);
const _trackPanelBackground = Color(0xFF0F1824);
const _trackPanelBackgroundAlt = Color(0xFF121F2D);
const _trackPanelBorder = Color(0xFF223246);
const _trackMapFrame = Color(0xFF0C1620);
const _trackTopBarBackground = Color(0xFF0A121B);
const _trackOverlaySurface = Color(0xF0182230);
const _trackOverlayBorder = Color(0xFF2B3B4F);
const _trackTextPrimary = Color(0xFFF4F7FB);
const _trackTextSecondary = Color(0xFFA5B4C5);
const _trackTextMuted = Color(0xFF6C7D91);
const _trackBlue = Color(0xFF4F7CFF);
const _trackGreen = Color(0xFF3AD29F);
const _trackAmber = Color(0xFFF4B44B);
const _trackRed = Color(0xFFF87373);

class TrackOverviewBoard extends StatefulWidget {
  final VoidCallback onOpenDetailedWorkspace;
  final DateTime Function()? now;

  const TrackOverviewBoard({
    super.key,
    required this.onOpenDetailedWorkspace,
    this.now,
  });

  @override
  State<TrackOverviewBoard> createState() => _TrackOverviewBoardState();
}

enum _TrackSiteStatus { secure, alarm }

class _TrackSiteSummary {
  final String id;
  final String name;
  final String clientLabel;
  final int guards;
  final int incidents;
  final String lastSeen;
  final _TrackSiteStatus status;
  final double x;
  final double y;

  const _TrackSiteSummary({
    required this.id,
    required this.name,
    required this.clientLabel,
    required this.guards,
    required this.incidents,
    required this.lastSeen,
    required this.status,
    required this.x,
    required this.y,
  });
}

class _TrackGuardSummary {
  final String id;
  final String name;
  final String officer;
  final String statusLabel;
  final String siteId;
  final String clientLabel;
  final double x;
  final double y;

  const _TrackGuardSummary({
    required this.id,
    required this.name,
    required this.officer,
    required this.statusLabel,
    required this.siteId,
    required this.clientLabel,
    required this.x,
    required this.y,
  });
}

class _TrackCameraSummary {
  final String id;
  final String siteId;
  final String clientLabel;
  final double x;
  final double y;

  const _TrackCameraSummary({
    required this.id,
    required this.siteId,
    required this.clientLabel,
    required this.x,
    required this.y,
  });
}

class _TrackIncidentSummary {
  final String id;
  final String siteId;
  final String clientLabel;
  final String label;
  final String severityLabel;
  final double x;
  final double y;

  const _TrackIncidentSummary({
    required this.id,
    required this.siteId,
    required this.clientLabel,
    required this.label,
    required this.severityLabel,
    required this.x,
    required this.y,
  });
}

const List<_TrackSiteSummary> _trackSites = [
  _TrackSiteSummary(
    id: 'SE-01',
    name: 'Sandton Estate North',
    clientLabel: 'Sandton Corp',
    guards: 2,
    incidents: 6,
    lastSeen: '22:23',
    status: _TrackSiteStatus.secure,
    x: 0.62,
    y: 0.17,
  ),
  _TrackSiteSummary(
    id: 'MV-02',
    name: 'Melrose Valley Residence',
    clientLabel: 'Melrose Arch Holdings',
    guards: 3,
    incidents: 5,
    lastSeen: '22:27',
    status: _TrackSiteStatus.secure,
    x: 0.56,
    y: 0.39,
  ),
  _TrackSiteSummary(
    id: 'RT-03',
    name: 'Rosebank Tower',
    clientLabel: 'Rosebank Properties',
    guards: 1,
    incidents: 9,
    lastSeen: '17:03',
    status: _TrackSiteStatus.secure,
    x: 0.43,
    y: 0.62,
  ),
  _TrackSiteSummary(
    id: 'HP-04',
    name: 'Hyde Park Plaza',
    clientLabel: 'Hyde Park Estates',
    guards: 1,
    incidents: 4,
    lastSeen: '22:32',
    status: _TrackSiteStatus.secure,
    x: 0.32,
    y: 0.49,
  ),
  _TrackSiteSummary(
    id: 'MO-05',
    name: 'Morningside Office Park',
    clientLabel: 'Morningside Group',
    guards: 2,
    incidents: 3,
    lastSeen: '19:29',
    status: _TrackSiteStatus.alarm,
    x: 0.66,
    y: 0.31,
  ),
  _TrackSiteSummary(
    id: 'BB-06',
    name: 'Bryanston Business Center',
    clientLabel: 'Bryanston Securities',
    guards: 4,
    incidents: 0,
    lastSeen: '02:35',
    status: _TrackSiteStatus.secure,
    x: 0.26,
    y: 0.27,
  ),
];

const List<_TrackGuardSummary> _trackGuards = [
  _TrackGuardSummary(
    id: 'ALPHA-1',
    name: 'Alpha-1',
    officer: 'Sophia Anderson',
    statusLabel: 'AVAILABLE',
    siteId: 'SE-01',
    clientLabel: 'Sandton Corp',
    x: 0.61,
    y: 0.20,
  ),
  _TrackGuardSummary(
    id: 'BRAVO-2',
    name: 'Bravo-2',
    officer: 'David Johnson',
    statusLabel: 'PATROL',
    siteId: 'MV-02',
    clientLabel: 'Melrose Arch Holdings',
    x: 0.54,
    y: 0.44,
  ),
  _TrackGuardSummary(
    id: 'ECHO-3',
    name: 'Echo-3',
    officer: 'John Smith',
    statusLabel: 'EN ROUTE',
    siteId: 'MO-05',
    clientLabel: 'Morningside Group',
    x: 0.63,
    y: 0.33,
  ),
  _TrackGuardSummary(
    id: 'WHISKEY-1',
    name: 'Whiskey-1',
    officer: 'James Johnson',
    statusLabel: 'PATROL',
    siteId: 'BB-06',
    clientLabel: 'Bryanston Securities',
    x: 0.28,
    y: 0.30,
  ),
  _TrackGuardSummary(
    id: 'YANKEE-1',
    name: 'Yankee-1',
    officer: 'Sophia Lee',
    statusLabel: 'ONSITE',
    siteId: 'RT-03',
    clientLabel: 'Rosebank Properties',
    x: 0.46,
    y: 0.58,
  ),
  _TrackGuardSummary(
    id: 'ZULU-1',
    name: 'Zulu-1',
    officer: 'Emma Anderson',
    statusLabel: 'AVAILABLE',
    siteId: 'HP-04',
    clientLabel: 'Hyde Park Estates',
    x: 0.34,
    y: 0.52,
  ),
];

const List<_TrackCameraSummary> _trackCameras = [
  _TrackCameraSummary(
    id: 'CAM-01',
    siteId: 'SE-01',
    clientLabel: 'Sandton Corp',
    x: 0.58,
    y: 0.13,
  ),
  _TrackCameraSummary(
    id: 'CAM-02',
    siteId: 'SE-01',
    clientLabel: 'Sandton Corp',
    x: 0.66,
    y: 0.15,
  ),
  _TrackCameraSummary(
    id: 'CAM-03',
    siteId: 'MV-02',
    clientLabel: 'Melrose Arch Holdings',
    x: 0.52,
    y: 0.36,
  ),
  _TrackCameraSummary(
    id: 'CAM-04',
    siteId: 'MV-02',
    clientLabel: 'Melrose Arch Holdings',
    x: 0.57,
    y: 0.47,
  ),
  _TrackCameraSummary(
    id: 'CAM-05',
    siteId: 'RT-03',
    clientLabel: 'Rosebank Properties',
    x: 0.40,
    y: 0.58,
  ),
  _TrackCameraSummary(
    id: 'CAM-06',
    siteId: 'HP-04',
    clientLabel: 'Hyde Park Estates',
    x: 0.29,
    y: 0.44,
  ),
  _TrackCameraSummary(
    id: 'CAM-07',
    siteId: 'MO-05',
    clientLabel: 'Morningside Group',
    x: 0.69,
    y: 0.28,
  ),
  _TrackCameraSummary(
    id: 'CAM-08',
    siteId: 'BB-06',
    clientLabel: 'Bryanston Securities',
    x: 0.21,
    y: 0.21,
  ),
];

const List<_TrackIncidentSummary> _trackIncidents = [
  _TrackIncidentSummary(
    id: 'INC-MO-1',
    siteId: 'MO-05',
    clientLabel: 'Morningside Group',
    label: 'Perimeter Alarm',
    severityLabel: 'ALARM',
    x: 0.68,
    y: 0.30,
  ),
  _TrackIncidentSummary(
    id: 'INC-SE-1',
    siteId: 'SE-01',
    clientLabel: 'Sandton Corp',
    label: 'Priority Dispatch',
    severityLabel: 'ALERT',
    x: 0.65,
    y: 0.22,
  ),
  _TrackIncidentSummary(
    id: 'INC-HP-1',
    siteId: 'HP-04',
    clientLabel: 'Hyde Park Estates',
    label: 'Loitering Vehicle',
    severityLabel: 'WATCH',
    x: 0.31,
    y: 0.54,
  ),
];

const List<String> _trackClients = [
  'All Clients',
  'Sandton Corp',
  'Melrose Arch Holdings',
  'Rosebank Properties',
  'Hyde Park Estates',
  'Morningside Group',
  'Bryanston Securities',
];

class _TrackOverviewBoardState extends State<TrackOverviewBoard> {
  late final ScrollController _leftRailScrollController;
  late final TextEditingController _searchController;
  Timer? _clockTimer;
  bool _showSites = true;
  bool _showGuards = true;
  bool _showIncidents = true;
  bool _showCameras = false;
  String _selectedClient = _trackClients.first;
  String? _selectedSiteId = 'MO-05';
  String _searchQuery = '';
  late DateTime _clockNow;
  List<_TrackSiteSummary> _visibleSites = const <_TrackSiteSummary>[];
  List<_TrackGuardSummary> _visibleGuards = const <_TrackGuardSummary>[];
  List<_TrackCameraSummary> _visibleCameras = const <_TrackCameraSummary>[];
  List<_TrackIncidentSummary> _visibleIncidents =
      const <_TrackIncidentSummary>[];

  @override
  void initState() {
    super.initState();
    _leftRailScrollController = ScrollController();
    _searchController = TextEditingController();
    _clockNow = _readNow();
    _applyFilters(clearSelection: false);
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _clockNow = _readNow();
      });
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _searchController.dispose();
    _leftRailScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final highlightedSite = _visibleSites.firstWhere(
      (site) => site.id == _selectedSiteId,
      orElse: () => _visibleSites.isNotEmpty ? _visibleSites.first : _trackSites.first,
    );
    final hasVisibleSites = _visibleSites.isNotEmpty;
    final effectiveHighlightedSite = hasVisibleSites ? highlightedSite : null;
    final highlightedGuards = _visibleGuards
        .where((guard) => guard.siteId == effectiveHighlightedSite?.id)
        .toList(growable: false);
    final highlightedIncidents = _visibleIncidents
        .where((incident) => incident.siteId == effectiveHighlightedSite?.id)
        .toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final railWidth = constraints.maxWidth >= 1550 ? 280.0 : 256.0;
        return Container(
          decoration: BoxDecoration(
            color: _trackShellBackground,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _trackPanelBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40040B12),
                blurRadius: 36,
                offset: Offset(0, 20),
              ),
            ],
          ),
          child: Row(
            children: [
              _buildShellRail(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _buildMapBoard(
                                highlightedSite: effectiveHighlightedSite,
                                sites: _visibleSites,
                                guards: _visibleGuards,
                                cameras: _visibleCameras,
                                incidents: _visibleIncidents,
                                highlightedGuards: highlightedGuards,
                                highlightedIncidents: highlightedIncidents,
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: railWidth,
                              child: _buildRightRail(
                                highlightedSite: effectiveHighlightedSite,
                                sites: _visibleSites,
                                guards: _visibleGuards,
                                incidents: _visibleIncidents,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShellRail() {
    Widget railIcon(IconData icon, {bool active = false}) {
      final accent = active ? _trackBlue : _trackTextMuted;
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: active
              ? _trackBlue.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.025),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? _trackBlue.withValues(alpha: 0.42)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Icon(icon, size: 18, color: accent),
      );
    }

    return Container(
      width: 56,
      decoration: const BoxDecoration(
        color: _trackShellRailBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(26),
          bottomLeft: Radius.circular(26),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: const Icon(
              Icons.shield_moon_outlined,
              color: _trackTextPrimary,
              size: 18,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: 20,
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          const SizedBox(height: 14),
          railIcon(Icons.bolt_rounded),
          const SizedBox(height: 12),
          railIcon(Icons.warning_amber_rounded),
          const SizedBox(height: 12),
          railIcon(Icons.location_on_outlined, active: true),
          const SizedBox(height: 12),
          railIcon(Icons.map_outlined),
          const SizedBox(height: 12),
          railIcon(Icons.query_stats_rounded),
          const Spacer(),
          railIcon(Icons.group_outlined),
          const SizedBox(height: 12),
          railIcon(Icons.verified_user_outlined),
          const SizedBox(height: 14),
          Container(
            width: 20,
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          const SizedBox(height: 14),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF7C5CFF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Center(
              child: Text(
                'ED',
                style: GoogleFonts.inter(
                  color: _trackTextPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: _trackTopBarBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(26),
          topRight: Radius.circular(26),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1480;
          final condensed = constraints.maxWidth < 1380;

          Widget titleBlock() {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _trackBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _trackBlue.withValues(alpha: 0.24),
                    ),
                  ),
                  child: const Icon(
                    Icons.track_changes_rounded,
                    color: _trackBlue,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TRACK',
                      style: GoogleFonts.inter(
                        color: _trackTextPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    if (!compact)
                      Text(
                        condensed
                            ? 'Overview shell'
                            : 'Overview shell • Johannesburg north grid',
                        style: GoogleFonts.inter(
                          color: _trackTextMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
            );
          }

          Widget searchBar() {
            return Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.028),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 13),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('track-search-field'),
                      controller: _searchController,
                      onChanged: _handleSearchChanged,
                      style: GoogleFonts.inter(
                        color: _trackTextPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                      cursorColor: _trackBlue,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: 'Search sites, code, or status',
                        hintStyle: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.38),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          Widget statusRow() {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!condensed) ...[
                  _buildTopPill(
                    icon: Icons.person_rounded,
                    label: 'Emily Davis',
                    accent: const Color(0xFF7C5CFF),
                  ),
                  const SizedBox(width: 8),
                  _buildTopPill(
                    icon: Icons.admin_panel_settings_outlined,
                    label: 'ADMIN',
                    accent: const Color(0xFF9A7BFF),
                  ),
                  const SizedBox(width: 8),
                ],
                if (!compact)
                  Text(
                    'Shift: ${_shiftDurationLabel(_clockNow)}',
                    style: GoogleFonts.inter(
                      color: _trackTextSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (!compact) const SizedBox(width: 14),
                _buildTopPill(
                  icon: Icons.check_circle_rounded,
                  label: condensed ? 'NOMINAL' : 'SYSTEMS NOMINAL',
                  accent: _trackGreen,
                ),
                if (!condensed) const SizedBox(width: 10),
                if (!condensed)
                  _buildTopPill(
                    icon: Icons.open_in_new_rounded,
                    label: 'OPEN WORKSPACE',
                    accent: _trackBlue,
                    onTap: widget.onOpenDetailedWorkspace,
                  ),
                if (!condensed) const SizedBox(width: 12),
                if (!condensed)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        color: Colors.white.withValues(alpha: 0.72),
                        size: 20,
                      ),
                      const Positioned(
                        right: -2,
                        top: -2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: _trackRed,
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox(width: 7, height: 7),
                        ),
                      ),
                    ],
                  ),
                if (!condensed) const SizedBox(width: 14),
                Text(
                  condensed ? _formatClock(_clockNow, includeSeconds: false) : _formatClock(_clockNow),
                  key: const ValueKey('track-live-clock'),
                  style: GoogleFonts.jetBrainsMono(
                    color: _trackTextPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            );
          }

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [titleBlock(), const Spacer(), statusRow()]),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: searchBar()),
                    if (condensed) ...[
                      const SizedBox(width: 10),
                      _buildTopPill(
                        icon: Icons.open_in_new_rounded,
                        label: 'WORKSPACE',
                        accent: _trackBlue,
                        onTap: widget.onOpenDetailedWorkspace,
                      ),
                    ],
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              titleBlock(),
              const SizedBox(width: 16),
              Expanded(child: searchBar()),
              const SizedBox(width: 12),
              statusRow(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopPill({
    required IconData icon,
    required String label,
    required Color accent,
    VoidCallback? onTap,
  }) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) {
      return pill;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: pill,
    );
  }

  DateTime _readNow() => widget.now?.call() ?? DateTime.now();

  void _handleSearchChanged(String value) {
    final normalized = value.trim();
    if (normalized == _searchQuery) {
      return;
    }
    setState(() {
      _searchQuery = normalized;
      _applyFilters();
    });
  }

  void _selectClient(String client) {
    if (_selectedClient == client) {
      return;
    }
    setState(() {
      _selectedClient = client;
      _applyFilters();
    });
  }

  void _applyFilters({bool clearSelection = true}) {
    final visibleSites = _trackSites.where(_matchesActiveFilters).toList(
      growable: false,
    );
    final siteIds = visibleSites.map((site) => site.id).toSet();
    _visibleSites = visibleSites;
    _visibleGuards = _trackGuards
        .where((guard) => siteIds.contains(guard.siteId))
        .toList(growable: false);
    _visibleCameras = _trackCameras
        .where((camera) => siteIds.contains(camera.siteId))
        .toList(growable: false);
    _visibleIncidents = _trackIncidents
        .where((incident) => siteIds.contains(incident.siteId))
        .toList(growable: false);
    if (clearSelection ||
        (_selectedSiteId != null &&
            !siteIds.contains(_selectedSiteId))) {
      _selectedSiteId = null;
    }
  }

  bool _matchesActiveFilters(_TrackSiteSummary site) {
    if (_selectedClient != 'All Clients' && site.clientLabel != _selectedClient) {
      return false;
    }
    final normalizedQuery = _searchQuery.toLowerCase();
    if (normalizedQuery.isEmpty) {
      return true;
    }
    final statusLabel = site.status == _TrackSiteStatus.alarm
        ? 'alarm'
        : 'secure';
    return site.name.toLowerCase().contains(normalizedQuery) ||
        site.id.toLowerCase().contains(normalizedQuery) ||
        statusLabel.contains(normalizedQuery);
  }

  String _shiftDurationLabel(DateTime now) {
    final shiftStart = DateTime(
      now.year,
      now.month,
      now.day,
      18,
    );
    final effectiveShiftStart = now.isBefore(shiftStart)
        ? shiftStart.subtract(const Duration(days: 1))
        : shiftStart;
    final elapsed = now.difference(effectiveShiftStart);
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes.remainder(60);
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }

  String _formatClock(DateTime now, {bool includeSeconds = true}) {
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    if (!includeSeconds) {
      return '$hour:$minute';
    }
    final second = now.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  Widget _buildMapBoard({
    required _TrackSiteSummary? highlightedSite,
    required List<_TrackSiteSummary> sites,
    required List<_TrackGuardSummary> guards,
    required List<_TrackCameraSummary> cameras,
    required List<_TrackIncidentSummary> incidents,
    required List<_TrackGuardSummary> highlightedGuards,
    required List<_TrackIncidentSummary> highlightedIncidents,
  }) {
    return Container(
      key: const ValueKey('track-live-map-board'),
      decoration: BoxDecoration(
        color: _trackMapFrame,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _trackPanelBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: _TrackStaticMapBackground(
                highlightedSite: highlightedSite,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF050A12).withValues(alpha: 0.06),
                      const Color(0xFF050A12).withValues(alpha: 0.18),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(
                        (highlightedSite?.x ?? 0.5) * 2 - 1,
                        (highlightedSite?.y ?? 0.5) * 2 - 1,
                      ),
                      radius: 0.62,
                      colors: [
                        _trackBlue.withValues(alpha: 0.16),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (highlightedSite != null)
              for (final guard in highlightedGuards)
                if (_showGuards)
                _TrackMapLink(
                  fromX: highlightedSite.x,
                  fromY: highlightedSite.y,
                  toX: guard.x,
                  toY: guard.y,
                  color: const Color(0xFF6FA8FF),
                ),
            if (highlightedSite != null)
              for (final incident in highlightedIncidents)
                if (_showIncidents)
                _TrackMapLink(
                  fromX: highlightedSite.x,
                  fromY: highlightedSite.y,
                  toX: incident.x,
                  toY: incident.y,
                  color: incident.severityLabel == 'ALARM'
                      ? _trackRed
                      : _trackAmber,
                ),
            for (final site in sites)
              if (_showSites)
                _TrackMapRangeRing(
                  x: site.x,
                  y: site.y,
                  color: site.status == _TrackSiteStatus.alarm
                      ? _trackRed
                      : _trackBlue,
                  selected: _selectedSiteId == site.id,
                ),
            for (final site in sites)
              if (_showSites)
                _TrackMapPin(
                  x: site.x,
                  y: site.y,
                  color: site.status == _TrackSiteStatus.alarm
                      ? _trackRed
                      : _trackBlue,
                  selected: _selectedSiteId == site.id,
                  icon: Icons.apartment_rounded,
                  onTap: () {
                    setState(() {
                      _selectedSiteId = site.id;
                    });
                  },
                ),
            for (final guard in guards)
              if (_showGuards)
                _TrackMapDot(
                  x: guard.x,
                  y: guard.y,
                  color: const Color(0xFF6FA8FF),
                ),
            for (final camera in cameras)
              if (_showCameras)
                _TrackMapStar(
                  x: camera.x,
                  y: camera.y,
                  color: const Color(0xFF89B9FF),
                ),
            for (final incident in incidents)
              if (_showIncidents)
                _TrackMapPin(
                  x: incident.x,
                  y: incident.y,
                  color: incident.severityLabel == 'ALARM'
                      ? _trackRed
                      : _trackAmber,
                  selected: false,
                  icon: Icons.warning_amber_rounded,
                  onTap: () {
                    setState(() {
                      _selectedSiteId = incident.siteId;
                    });
                  },
                ),
            Positioned(
              right: 16,
              top: 16,
              child: _buildMapCornerChip(
                icon: Icons.language_rounded,
                label: 'NORTH CLUSTER',
                value: 'LIVE GRID',
                accent: _trackBlue,
              ),
            ),
            Positioned(
              left: 16,
              top: 16,
              bottom: 16,
              child: SizedBox(
                width: 164,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Scrollbar(
                      controller: _leftRailScrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        key: const ValueKey('track-left-rail-scroll'),
                        controller: _leftRailScrollController,
                        primary: false,
                        padding: const EdgeInsets.only(right: 6),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFloatingCard(
                                key: const ValueKey('track-view-mode-card'),
                                title: 'View Mode',
                                subtitle: 'All Operations',
                                emphasized: true,
                                child: _buildModeButton(),
                              ),
                              const SizedBox(height: 8),
                              _buildFloatingCard(
                                key: const ValueKey('track-map-layers-card'),
                                title: 'MAP LAYERS',
                                child: Column(
                                  children: [
                                    _buildLayerButton(
                                      key: const ValueKey('track-layer-sites'),
                                      icon: Icons.apartment_rounded,
                                      label: 'Sites (${sites.length})',
                                      active: _showSites,
                                      tint: const Color(0xFF3D74D6),
                                      onTap: () {
                                        setState(() {
                                          _showSites = !_showSites;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    _buildLayerButton(
                                      key: const ValueKey('track-layer-guards'),
                                      icon: Icons.shield_outlined,
                                      label: 'Guards (${guards.length})',
                                      active: _showGuards,
                                      tint: const Color(0xFF2FA56D),
                                      onTap: () {
                                        setState(() {
                                          _showGuards = !_showGuards;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    _buildLayerButton(
                                      key: const ValueKey(
                                        'track-layer-incidents',
                                      ),
                                      icon: Icons.warning_amber_rounded,
                                      label: 'Incidents (${incidents.length})',
                                      active: _showIncidents,
                                      tint: const Color(0xFFB54C4C),
                                      onTap: () {
                                        setState(() {
                                          _showIncidents = !_showIncidents;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    _buildLayerButton(
                                      key: const ValueKey(
                                        'track-layer-cameras',
                                      ),
                                      icon: Icons.videocam_outlined,
                                      label: 'Cameras (${cameras.length})',
                                      active: _showCameras,
                                      tint: const Color(0xFF46576F),
                                      onTap: () {
                                        setState(() {
                                          _showCameras = !_showCameras;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildFloatingCard(
                                title: 'LIVE STATUS',
                                child: _buildLiveStatus(),
                              ),
                              const SizedBox(height: 8),
                              _buildFloatingCard(
                                key: const ValueKey('track-client-filter-card'),
                                title: 'CLIENT FILTER',
                                child: _buildClientFilter(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildSelectedSiteSpotlight(
                site: highlightedSite,
                guards: highlightedGuards,
                incidents: highlightedIncidents,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightRail({
    required _TrackSiteSummary? highlightedSite,
    required List<_TrackSiteSummary> sites,
    required List<_TrackGuardSummary> guards,
    required List<_TrackIncidentSummary> incidents,
  }) {
    return Container(
      key: const ValueKey('track-sites-rail'),
      decoration: BoxDecoration(
        color: _trackPanelBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _trackPanelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF17336B), Color(0xFF102244)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: const Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Live Tracking',
                            style: GoogleFonts.inter(
                              color: _trackTextPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Real-time asset locations',
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildOverviewMetric(
                        label: 'ALARMS',
                        value: '${incidents.length}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildOverviewMetric(
                        label: 'GUARDS',
                        value: '${guards.length}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildOverviewMetric(
                        label: 'FOCUS',
                        value: highlightedSite?.id ?? 'NONE',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const ValueKey('track-open-detailed-workspace-button'),
                    onPressed: widget.onOpenDetailedWorkspace,
                    icon: const Icon(Icons.open_in_new_rounded, size: 15),
                    label: const Text('Open Detailed Workspace'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _trackTextPrimary,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                      backgroundColor: Colors.white.withValues(alpha: 0.07),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      textStyle: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (incidents.isNotEmpty) ...[
                    _buildRailSectionHeader(
                      label: 'ACTIVE INCIDENTS',
                      count: incidents.length,
                    ),
                    const SizedBox(height: 8),
                    ...incidents.take(3).map(_buildIncidentCard),
                    const SizedBox(height: 12),
                  ],
                  _buildRailSectionHeader(label: 'SITES', count: sites.length),
                  const SizedBox(height: 8),
                  ...sites.map(_buildSiteCard),
                  const SizedBox(height: 12),
                  _buildRailSectionHeader(
                    key: const ValueKey('track-active-guards-rail'),
                    label: 'ACTIVE GUARDS',
                    count: guards.take(5).length,
                  ),
                  const SizedBox(height: 8),
                  ...guards.take(5).map(_buildGuardCard),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapCornerChip({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: accent),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: _trackTextMuted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    color: _trackTextPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedSiteSpotlight({
    required _TrackSiteSummary? site,
    required List<_TrackGuardSummary> guards,
    required List<_TrackIncidentSummary> incidents,
  }) {
    if (site == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _trackOverlayBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.search_off_rounded,
                  color: _trackTextMuted,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No sites match the current filter',
                      style: GoogleFonts.inter(
                        color: _trackTextPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Adjust the client or search filter to restore the live spotlight.',
                      style: GoogleFonts.inter(
                        color: _trackTextSecondary,
                        fontSize: 11,
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
    }
    final accent = site.status == _TrackSiteStatus.alarm
        ? _trackRed
        : _trackBlue;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final summaryBlock = Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    site.id,
                    style: GoogleFonts.jetBrainsMono(
                      color: _trackTextMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      site.status == _TrackSiteStatus.alarm
                          ? 'ALARM'
                          : 'SECURE',
                      style: GoogleFonts.inter(
                        color: accent,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                site.name,
                style: GoogleFonts.inter(
                  color: _trackTextPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                site.clientLabel,
                style: GoogleFonts.inter(
                  color: _trackTextSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );

        final metricWrap = Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: compact ? WrapAlignment.start : WrapAlignment.end,
          children: [
            _buildSpotlightMetric('Guards', '${guards.length}', _trackBlue),
            _buildSpotlightMetric(
              'Incidents',
              '${incidents.length}',
              incidents.isEmpty ? _trackGreen : _trackAmber,
            ),
            _buildSpotlightMetric('Last Seen', site.lastSeen, _trackTextMuted),
          ],
        );

        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: 0.28)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.14),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.34),
                              ),
                            ),
                            child: Icon(
                              Icons.apartment_rounded,
                              color: accent,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          summaryBlock,
                        ],
                      ),
                      const SizedBox(height: 12),
                      metricWrap,
                    ],
                  )
                : Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.34),
                          ),
                        ),
                        child: Icon(
                          Icons.apartment_rounded,
                          color: accent,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      summaryBlock,
                      const SizedBox(width: 12),
                      metricWrap,
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildRailSectionHeader({
    Key? key,
    required String label,
    required int count,
  }) {
    return Row(
      key: key,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: _trackTextMuted,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.78,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.jetBrainsMono(
              color: _trackTextSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewMetric({required String label, required String value}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: GoogleFonts.inter(
                color: _trackTextPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpotlightMetric(String label, String value, Color color) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: _trackTextMuted,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.inter(
                color: color == _trackTextMuted ? _trackTextPrimary : color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF143448), Color(0xFF102A37)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A536A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _trackGreen.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.bolt_rounded, size: 16, color: _trackGreen),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All Operations',
                  style: GoogleFonts.inter(
                    color: _trackTextPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Full system access and live fleet routing',
                  style: GoogleFonts.inter(
                    color: Colors.white70,
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
  }

  Widget _buildFloatingCard({
    Key? key,
    required String title,
    String? subtitle,
    required Widget child,
    bool emphasized = false,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: emphasized ? const Color(0xD0182C4A) : _trackOverlaySurface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: emphasized ? const Color(0xFF2F5679) : _trackOverlayBorder,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33040A12),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: emphasized ? const Color(0xFFC8DBFF) : _trackTextPrimary,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.55,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildLayerButton({
    required Key key,
    required IconData icon,
    required String label,
    required bool active,
    required Color tint,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: active
              ? tint.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.028),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? tint.withValues(alpha: 0.72)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: active
                    ? tint.withValues(alpha: 0.16)
                    : Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 14,
                color: active ? tint : _trackTextSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color: active ? _trackTextPrimary : _trackTextSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              active ? Icons.visibility_rounded : Icons.visibility_off_rounded,
              size: 14,
              color: active ? tint : _trackTextMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveStatus() {
    return Column(
      children: [
        _buildStatusRow('Active Alarms', '1', _trackRed),
        const SizedBox(height: 10),
        _buildStatusRow('Guards on Patrol', '8', _trackGreen),
        const SizedBox(height: 10),
        _buildStatusRow('En Route', '4', _trackAmber),
        const SizedBox(height: 10),
        _buildStatusRow('Sites Secure', '24/25', _trackBlue),
      ],
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.026),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: _trackTextSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.028),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.filter_alt_outlined,
                size: 15,
                color: _trackTextMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Filter Clients',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: _trackTextSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 118,
          child: SingleChildScrollView(
            child: Column(
              children: _trackClients
                  .map(
                    (client) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        key: ValueKey<String>(
                          'track-client-filter-${client.toLowerCase().replaceAll(' ', '-')}',
                        ),
                        onTap: () => _selectClient(client),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _selectedClient == client
                                ? _trackBlue.withValues(alpha: 0.16)
                                : Colors.white.withValues(alpha: 0.026),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedClient == client
                                  ? _trackBlue.withValues(alpha: 0.8)
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _selectedClient == client
                                      ? _trackBlue
                                      : Colors.white.withValues(alpha: 0.18),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  client,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: _selectedClient == client
                                        ? _trackTextPrimary
                                        : _trackTextSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIncidentCard(_TrackIncidentSummary incident) {
    final accent = incident.severityLabel == 'ALARM' ? _trackRed : _trackAmber;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          color: _trackPanelBackgroundAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.28)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 3,
              height: 42,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          incident.label,
                          style: GoogleFonts.inter(
                            color: _trackTextPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          incident.severityLabel,
                          style: GoogleFonts.inter(
                            color: accent,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${incident.siteId} • ${incident.clientLabel}',
                    style: GoogleFonts.inter(
                      color: _trackTextSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    incident.id,
                    style: GoogleFonts.jetBrainsMono(
                      color: accent,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSiteCard(_TrackSiteSummary site) {
    final isSelected = site.id == _selectedSiteId;
    final accent = site.status == _TrackSiteStatus.alarm
        ? _trackRed
        : _trackBlue;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedSiteId = site.id;
          });
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            color: isSelected
                ? accent.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? accent.withValues(alpha: 0.55)
                  : _trackPanelBorder,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      Icons.apartment_rounded,
                      size: 15,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          site.name,
                          style: GoogleFonts.inter(
                            color: _trackTextPrimary,
                            fontSize: 12.25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${site.id} • ${site.clientLabel}',
                          style: GoogleFonts.inter(
                            color: _trackTextSecondary,
                            fontSize: 10.25,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      site.status == _TrackSiteStatus.alarm
                          ? 'ALARM'
                          : 'SECURE',
                      style: GoogleFonts.inter(
                        color: accent,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.45,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _buildInlineMetric(
                      'Guards',
                      '${site.guards}',
                      _trackBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInlineMetric(
                      'Incidents',
                      '${site.incidents}',
                      site.incidents == 0 ? _trackGreen : _trackAmber,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Last ${site.lastSeen}',
                    style: GoogleFonts.jetBrainsMono(
                      color: _trackTextSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuardCard(_TrackGuardSummary guard) {
    final accent = switch (guard.statusLabel) {
      'PATROL' => _trackBlue,
      'ONSITE' => _trackGreen,
      'EN ROUTE' => _trackAmber,
      _ => const Color(0xFF6BD8B3),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _trackPanelBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(Icons.radio_rounded, size: 15, color: accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        guard.name,
                        style: GoogleFonts.inter(
                          color: _trackTextPrimary,
                          fontSize: 12.25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${guard.officer} • ${guard.siteId}',
                        style: GoogleFonts.inter(
                          color: _trackTextSecondary,
                          fontSize: 10.25,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    guard.statusLabel,
                    style: GoogleFonts.inter(
                      color: accent,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildInlineMetric('Callsign', guard.id, _trackBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInlineMetric(
                    'Client',
                    guard.clientLabel,
                    _trackTextMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: _trackTextMuted,
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.55,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: color == _trackTextMuted ? _trackTextPrimary : color,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _TrackStaticMapBackground extends StatelessWidget {
  final _TrackSiteSummary? highlightedSite;

  const _TrackStaticMapBackground({required this.highlightedSite});

  @override
  Widget build(BuildContext context) {
    return _TrackMapFallback(highlightedSite: highlightedSite);
  }
}

class _TrackMapFallback extends StatelessWidget {
  final _TrackSiteSummary? highlightedSite;

  const _TrackMapFallback({required this.highlightedSite});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF07111A), Color(0xFF0A1520), Color(0xFF091621)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: CustomPaint(
        painter: _TrackMapFallbackPainter(highlightedSite: highlightedSite),
      ),
    );
  }
}

class _TrackMapRangeRing extends StatelessWidget {
  final double x;
  final double y;
  final Color color;
  final bool selected;

  const _TrackMapRangeRing({
    required this.x,
    required this.y,
    required this.color,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final diameter = selected ? 90.0 : 62.0;
          return Stack(
            children: [
              Positioned(
                left: constraints.maxWidth * x - diameter / 2,
                top: constraints.maxHeight * y - diameter / 2,
                child: IgnorePointer(
                  child: Container(
                    width: diameter,
                    height: diameter,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color.withValues(alpha: selected ? 0.22 : 0.14),
                        width: selected ? 1.6 : 1.1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(
                            alpha: selected ? 0.14 : 0.08,
                          ),
                          blurRadius: selected ? 20 : 12,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TrackMapLink extends StatelessWidget {
  final double fromX;
  final double fromY;
  final double toX;
  final double toY;
  final Color color;

  const _TrackMapLink({
    required this.fromX,
    required this.fromY,
    required this.toX,
    required this.toY,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _TrackMapLinkPainter(
            fromX: fromX,
            fromY: fromY,
            toX: toX,
            toY: toY,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _TrackMapPin extends StatelessWidget {
  final double x;
  final double y;
  final Color color;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  const _TrackMapPin({
    required this.x,
    required this.y,
    required this.color,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Positioned(
                left: constraints.maxWidth * x - (selected ? 17 : 15),
                top: constraints.maxHeight * y - (selected ? 17 : 15),
                child: GestureDetector(
                  onTap: onTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: selected ? 34 : 30,
                    height: selected ? 34 : 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A1220),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: color.withValues(alpha: selected ? 0.92 : 0.62),
                        width: selected ? 2.2 : 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: selected ? 0.3 : 0.18),
                          blurRadius: selected ? 22 : 14,
                          spreadRadius: selected ? 1 : 0,
                        ),
                      ],
                    ),
                    child: Icon(icon, size: selected ? 18 : 16, color: color),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TrackMapDot extends StatelessWidget {
  final double x;
  final double y;
  final Color color;

  const _TrackMapDot({required this.x, required this.y, required this.color});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Positioned(
                left: constraints.maxWidth * x - 10,
                top: constraints.maxHeight * y - 10,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFF08101B),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withValues(alpha: 0.78),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.22),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TrackMapStar extends StatelessWidget {
  final double x;
  final double y;
  final Color color;

  const _TrackMapStar({required this.x, required this.y, required this.color});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Positioned(
                left: constraints.maxWidth * x - 10,
                top: constraints.maxHeight * y - 10,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFF08101B),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: color.withValues(alpha: 0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.22),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Icon(Icons.videocam_rounded, size: 13, color: color),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TrackMapFallbackPainter extends CustomPainter {
  final _TrackSiteSummary? highlightedSite;

  const _TrackMapFallbackPainter({required this.highlightedSite});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0x22385268)
      ..strokeWidth = 1;
    for (var row = 0; row <= 12; row++) {
      final y = size.height * row / 12;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (var column = 0; column <= 16; column++) {
      final x = size.width * column / 16;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    final districtPaint = Paint()..color = const Color(0x18253B52);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.06,
          size.height * 0.10,
          size.width * 0.22,
          size.height * 0.18,
        ),
        const Radius.circular(30),
      ),
      districtPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.62,
          size.height * 0.58,
          size.width * 0.24,
          size.height * 0.17,
        ),
        const Radius.circular(34),
      ),
      districtPaint,
    );

    final zonePaint = Paint()..color = const Color(0x141B3B31);
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * 0.54,
        size.height * 0.14,
        size.width * 0.14,
        size.height * 0.12,
      ),
      zonePaint,
    );
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * 0.18,
        size.height * 0.41,
        size.width * 0.19,
        size.height * 0.13,
      ),
      zonePaint,
    );

    final majorRoad = Paint()
      ..color = const Color(0xFF1C3A63)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final minorRoad = Paint()
      ..color = const Color(0xAA234B7C)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final tertiaryRoad = Paint()
      ..color = const Color(0x66365A85)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final vertical = Path()
      ..moveTo(size.width * 0.64, 0)
      ..lineTo(size.width * 0.60, size.height)
      ..moveTo(size.width * 0.46, 0)
      ..lineTo(size.width * 0.50, size.height);
    canvas.drawPath(vertical, majorRoad);

    final diagonal = Path()
      ..moveTo(size.width * 0.02, size.height * 0.70)
      ..lineTo(size.width * 0.96, size.height * 0.24)
      ..moveTo(size.width * 0.10, size.height * 0.16)
      ..lineTo(size.width * 0.72, size.height * 0.90)
      ..moveTo(size.width * 0.23, 0)
      ..lineTo(size.width * 0.84, size.height * 0.76);
    canvas.drawPath(diagonal, minorRoad);

    final localRoads = Path()
      ..moveTo(size.width * 0.10, size.height * 0.44)
      ..lineTo(size.width * 0.36, size.height * 0.40)
      ..lineTo(size.width * 0.54, size.height * 0.50)
      ..lineTo(size.width * 0.86, size.height * 0.46)
      ..moveTo(size.width * 0.26, size.height * 0.12)
      ..lineTo(size.width * 0.34, size.height * 0.88)
      ..moveTo(size.width * 0.72, size.height * 0.10)
      ..lineTo(size.width * 0.18, size.height * 0.82);
    canvas.drawPath(localRoads, tertiaryRoad);

    if (highlightedSite != null) {
      final focusCenter = Offset(
        size.width * highlightedSite!.x,
        size.height * highlightedSite!.y,
      );
      final focusGlow = Paint()
        ..shader =
            RadialGradient(
              colors: [
                (highlightedSite!.status == _TrackSiteStatus.alarm
                        ? _trackRed
                        : _trackBlue)
                    .withValues(alpha: 0.26),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(
                center: focusCenter,
                radius: size.longestSide * 0.22,
              ),
            );
      canvas.drawCircle(focusCenter, size.longestSide * 0.22, focusGlow);
    }
  }

  @override
  bool shouldRepaint(covariant _TrackMapFallbackPainter oldDelegate) =>
      oldDelegate.highlightedSite?.id != highlightedSite?.id ||
      oldDelegate.highlightedSite?.status != highlightedSite?.status;
}

class _TrackMapLinkPainter extends CustomPainter {
  final double fromX;
  final double fromY;
  final double toX;
  final double toY;
  final Color color;

  const _TrackMapLinkPainter({
    required this.fromX,
    required this.fromY,
    required this.toX,
    required this.toY,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final start = Offset(size.width * fromX, size.height * fromY);
    final end = Offset(size.width * toX, size.height * toY);
    final control = Offset(
      (start.dx + end.dx) / 2,
      (start.dy + end.dy) / 2 - 18,
    );
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final linePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0.04),
          color.withValues(alpha: 0.28),
          color.withValues(alpha: 0.12),
        ],
      ).createShader(Rect.fromPoints(start, end))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _TrackMapLinkPainter oldDelegate) {
    return oldDelegate.fromX != fromX ||
        oldDelegate.fromY != fromY ||
        oldDelegate.toX != toX ||
        oldDelegate.toY != toY ||
        oldDelegate.color != color;
  }
}
