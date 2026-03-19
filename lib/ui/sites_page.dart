import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../domain/events/decision_created.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/execution_completed.dart';
import '../domain/events/execution_denied.dart';
import '../domain/events/guard_checked_in.dart';
import '../domain/events/incident_closed.dart';
import '../domain/events/patrol_completed.dart';
import '../domain/events/response_arrived.dart';
import '../domain/projection/operations_health_projection.dart';
import 'layout_breakpoints.dart';
import 'onyx_surface.dart';

class SitesPage extends StatefulWidget {
  final List<DispatchEvent> events;

  const SitesPage({super.key, required this.events});

  @override
  State<SitesPage> createState() => _SitesPageState();
}

class _SitesPageState extends State<SitesPage> {
  static const int _maxRosterRows = 12;
  static const double _spaceXs = 6;
  static const double _spaceSm = 8;

  int _selectedIndex = 0;
  bool get _desktopEmbeddedScroll => allowEmbeddedPanelScroll(context);

  @override
  Widget build(BuildContext context) {
    final projection = OperationsHealthProjection.build(widget.events);
    final sites = _buildSiteDrillSnapshots(widget.events, projection);

    if (sites.isEmpty) {
      return const OnyxPageScaffold(
        child: OnyxEmptyState(
          label: 'No sites available in the current projection.',
        ),
      );
    }

    final activeDispatches = sites.fold<int>(
      0,
      (total, site) => total + site.activeDispatches,
    );
    final averageHealth =
        sites.fold<double>(0, (total, site) => total + site.healthScore) /
        sites.length;

    if (_selectedIndex >= sites.length) {
      _selectedIndex = sites.length - 1;
    }

    final selected = sites[_selectedIndex];

    return OnyxPageScaffold(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1540),
            child: ListView(
              children: [
                _heroHeader(context, sites: sites),
                const SizedBox(height: _spaceSm),
                _postureSummaryBar(sites),
                const SizedBox(height: _spaceSm),
                _overviewGrid(
                  sites: sites,
                  activeDispatches: activeDispatches,
                  averageHealth: averageHealth,
                ),
                const SizedBox(height: _spaceSm),
                const OnyxPageHeader(
                  title: 'Site Command Grid',
                  subtitle:
                      'Estate-wide posture, dispatch exposure, and site-level operational pressure.',
                ),
                const SizedBox(height: _spaceSm),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final maxWidth = constraints.maxWidth;
                    final statWidth = maxWidth < 520
                        ? maxWidth
                        : maxWidth < 760
                        ? (maxWidth - 8) / 2
                        : 236.0;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          width: statWidth,
                          child: OnyxSummaryStat(
                            label: 'Visible Sites',
                            value: sites.length.toString(),
                            accent: const Color(0xFF63BDFF),
                          ),
                        ),
                        SizedBox(
                          width: statWidth,
                          child: OnyxSummaryStat(
                            label: 'Active Dispatches',
                            value: activeDispatches.toString(),
                            accent: const Color(0xFF59D79B),
                          ),
                        ),
                        SizedBox(
                          width: statWidth,
                          child: OnyxSummaryStat(
                            label: 'Average Health',
                            value: averageHealth.toStringAsFixed(1),
                            accent: const Color(0xFFF6C067),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: _spaceSm),
                OnyxSectionCard(
                  title: 'Site Operations Workspace',
                  subtitle:
                      'Review site posture on the left, then inspect operational detail for the selected site.',
                  padding: const EdgeInsets.all(10),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final stackVertically = constraints.maxWidth < 1320;
                      final allowEmbeddedWorkspace = _desktopEmbeddedScroll;

                      if (stackVertically) {
                        if (!allowEmbeddedWorkspace) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _siteRoster(
                                sites,
                                selected,
                                embeddedScroll: false,
                              ),
                              const SizedBox(height: _spaceXs),
                              _siteDetail(selected, embeddedScroll: false),
                            ],
                          );
                        }
                        return SizedBox(
                          height: 640,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                height: 216,
                                child: _siteRoster(sites, selected),
                              ),
                              const SizedBox(height: _spaceXs),
                              Expanded(child: _siteDetail(selected)),
                            ],
                          ),
                        );
                      }

                      if (!allowEmbeddedWorkspace) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 268,
                              child: _siteRoster(
                                sites,
                                selected,
                                embeddedScroll: false,
                              ),
                            ),
                            const SizedBox(width: _spaceSm),
                            Expanded(
                              child: _siteDetail(
                                selected,
                                embeddedScroll: false,
                              ),
                            ),
                          ],
                        );
                      }

                      return SizedBox(
                        height: 508,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 268,
                              child: _siteRoster(
                                sites,
                                selected,
                                embeddedScroll: true,
                              ),
                            ),
                            const SizedBox(width: _spaceSm),
                            Expanded(
                              child: _siteDetail(
                                selected,
                                embeddedScroll: true,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroHeader(
    BuildContext context, {
    required List<_SiteDrillSnapshot> sites,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10263C), Color(0xFF0E1728)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF274563)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 920;
          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF06B6D4), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Icons.business_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sites & Deployment',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFF6FBFF),
                            fontSize: compact ? 22 : 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Site management, watch posture, and operational readiness.',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF95A9C7),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _heroChip('Sites', '${sites.length}'),
                  _heroChip('Roster', 'Deployment Ready'),
                  _heroChip(
                    'Focus',
                    sites[_selectedIndex.clamp(0, sites.length - 1)].siteId,
                  ),
                  _heroChip('Watch', 'Posture Summary'),
                ],
              ),
            ],
          );
          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.end,
            children: [
              _heroActionButton(
                key: const ValueKey('sites-view-tactical-button'),
                icon: Icons.open_in_new,
                label: 'View Tactical',
                accent: const Color(0xFF93C5FD),
                onPressed: () => _showTacticalLinkDialog(context),
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                const SizedBox(height: 16),
                actions,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: titleBlock),
              const SizedBox(width: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: actions,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _heroChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x14000000),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x33000000)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: GoogleFonts.inter(
                color: const Color(0xFF8EA4C2),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: GoogleFonts.inter(
                color: const Color(0xFFE8F1FF),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroActionButton({
    required Key key,
    required IconData icon,
    required String label,
    required Color accent,
    required VoidCallback onPressed,
  }) {
    return FilledButton.tonalIcon(
      key: key,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: accent.withValues(alpha: 0.12),
        foregroundColor: accent,
        side: BorderSide(color: accent.withValues(alpha: 0.28)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        textStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _postureSummaryBar(List<_SiteDrillSnapshot> sites) {
    final strongCount = sites.where((site) => site.healthStatus == 'STRONG').length;
    final atRiskCount = sites.where((site) => site.healthStatus == 'AT RISK').length;
    final criticalCount = sites.where((site) => site.healthStatus == 'CRITICAL').length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1728),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF253A55)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'SITE POSTURE',
            style: GoogleFonts.inter(
              color: const Color(0x669BB0CE),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          _statusPill(
            icon: Icons.check_circle_outline,
            label: '$strongCount Strong',
            accent: const Color(0xFF34D399),
          ),
          _statusPill(
            icon: Icons.warning_amber_rounded,
            label: '$atRiskCount At-Risk',
            accent: const Color(0xFFF6C067),
          ),
          if (criticalCount > 0)
            _statusPill(
              icon: Icons.error_outline,
              label: '$criticalCount Critical',
              accent: const Color(0xFFF87171),
            ),
        ],
      ),
    );
  }

  Widget _statusPill({
    required IconData icon,
    required String label,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
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
  }

  Widget _overviewGrid({
    required List<_SiteDrillSnapshot> sites,
    required int activeDispatches,
    required double averageHealth,
  }) {
    final selected = sites[_selectedIndex.clamp(0, sites.length - 1)];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1200
            ? 4
            : constraints.maxWidth >= 760
            ? 2
            : 1;
        final aspectRatio = columns == 4
            ? 1.95
            : columns == 2
            ? 2.35
            : 2.55;
        return GridView.count(
          key: const ValueKey('sites-overview-grid'),
          crossAxisCount: columns,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: aspectRatio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _overviewCard(
              title: 'Visible Sites',
              value: '${sites.length}',
              detail: 'Deployment footprint currently surfaced in the roster.',
              icon: Icons.apartment_rounded,
              accent: const Color(0xFF63BDFF),
            ),
            _overviewCard(
              title: 'Active Dispatches',
              value: '$activeDispatches',
              detail: 'Open response activity attached to the visible site set.',
              icon: Icons.local_shipping_outlined,
              accent: const Color(0xFF59D79B),
            ),
            _overviewCard(
              title: 'Average Health',
              value: averageHealth.toStringAsFixed(1),
              detail: 'Composite posture score across the current site footprint.',
              icon: Icons.health_and_safety_outlined,
              accent: const Color(0xFFF6C067),
            ),
            _overviewCard(
              title: 'Selected Site',
              value: selected.siteId,
              detail: '${selected.clientId} / ${selected.regionId} is active in the workspace.',
              icon: Icons.visibility_outlined,
              accent: const Color(0xFFA78BFA),
            ),
          ],
        );
      },
    );
  }

  Widget _overviewCard({
    required String title,
    required String value,
    required String detail,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: GoogleFonts.robotoMono(
                    color: const Color(0xFFF4F8FF),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              color: const Color(0xFF93A5BF),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: const Color(0xFFD5E1F2),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  void _showTacticalLinkDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111827),
          title: Text(
            'Tactical Link Ready',
            style: GoogleFonts.inter(
              color: const Color(0xFFF6FBFF),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Use Tactical to inspect watch posture, limited coverage, responder context, and map-driven site actions for the selected deployment.',
            style: GoogleFonts.inter(
              color: const Color(0xFFD6E2F2),
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _siteRoster(
    List<_SiteDrillSnapshot> sites,
    _SiteDrillSnapshot selected, {
    bool embeddedScroll = true,
  }) {
    final visibleSites = sites.take(_maxRosterRows).toList(growable: false);
    final hiddenSites = sites.length - visibleSites.length;
    final list = ListView.separated(
      padding: const EdgeInsets.all(_spaceSm),
      itemCount: visibleSites.length,
      shrinkWrap: !embeddedScroll,
      primary: embeddedScroll,
      physics: embeddedScroll ? null : const NeverScrollableScrollPhysics(),
      separatorBuilder: (context, index) => const SizedBox(height: _spaceXs),
      itemBuilder: (context, index) {
        final site = visibleSites[index];
        final isSelected = site.siteKey == selected.siteKey;
        final statusColor = _statusColor(site.healthStatus);

        return InkWell(
          onTap: () => setState(() => _selectedIndex = index),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: onyxSelectableRowSurfaceDecoration(
              isSelected: isSelected,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  site.siteId,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFE7F0FF),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${site.clientId} / ${site.regionId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF93AACE),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _tinyPill(
                      'Health ${site.healthScore.toStringAsFixed(1)}',
                      statusColor,
                    ),
                    _tinyPill(
                      'Active ${site.activeDispatches}',
                      const Color(0xFF4EB8FF),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return Container(
      decoration: onyxWorkspaceSurfaceDecoration(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, _spaceSm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 3,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3C79BB),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: _spaceXs),
                      Text(
                        'Site Roster',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.rajdhani(
                          color: const Color(0xFFDCEAFF),
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: _spaceSm),
                Text(
                  '${sites.length} total',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF86A2C8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF223244)),
          if (embeddedScroll)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: list),
                  if (hiddenSites > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                      child: OnyxTruncationHint(
                        visibleCount: visibleSites.length,
                        totalCount: sites.length,
                        subject: 'sites',
                        hiddenDescriptor: 'additional sites',
                        color: const Color(0xFF86A2C8),
                      ),
                    ),
                ],
              ),
            )
          else ...[
            list,
            if (hiddenSites > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: OnyxTruncationHint(
                  visibleCount: visibleSites.length,
                  totalCount: sites.length,
                  subject: 'sites',
                  hiddenDescriptor: 'additional sites',
                  color: const Color(0xFF86A2C8),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _siteDetail(_SiteDrillSnapshot site, {bool embeddedScroll = true}) {
    final statusColor = _statusColor(site.healthStatus);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 3,
          decoration: BoxDecoration(
            color: const Color(0xFF3C79BB),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                '${site.clientId} / ${site.regionId} / ${site.siteId}',
                style: GoogleFonts.inter(
                  color: const Color(0xFFE7F0FF),
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: statusColor.withValues(alpha: 0.15),
                border: Border.all(color: statusColor.withValues(alpha: 0.8)),
              ),
              child: Text(
                '${site.healthStatus} • ${site.healthScore.toStringAsFixed(1)}',
                style: GoogleFonts.rajdhani(
                  color: statusColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _metricCard(
              'Decisions',
              site.decisions.toString(),
              const Color(0xFF58B7FF),
            ),
            _metricCard(
              'Executed',
              site.executedCount.toString(),
              const Color(0xFF4CDD8A),
            ),
            _metricCard(
              'Denied',
              site.deniedCount.toString(),
              const Color(0xFFF6B24A),
            ),
            _metricCard(
              'Failed',
              site.failedCount.toString(),
              const Color(0xFFFF6A78),
            ),
            _metricCard(
              'Active',
              site.activeDispatches.toString(),
              const Color(0xFF7CA2FF),
            ),
            _metricCard(
              'Check-Ins',
              site.guardCheckIns.toString(),
              const Color(0xFF68CBFF),
            ),
            _metricCard(
              'Patrols',
              site.patrolsCompleted.toString(),
              const Color(0xFF65D5A5),
            ),
            _metricCard(
              'Avg Response',
              '${site.averageResponseMinutes.toStringAsFixed(1)} min',
              const Color(0xFF8FD0FF),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 860;
            final outcomePanel = _panel(
              'Dispatch Outcome Mix',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ratioBar(
                    'Executed',
                    site.executedCount,
                    site.decisions,
                    const Color(0xFF45D58D),
                  ),
                  _ratioBar(
                    'Denied',
                    site.deniedCount,
                    site.decisions,
                    const Color(0xFFF0B24C),
                  ),
                  _ratioBar(
                    'Failed',
                    site.failedCount,
                    site.decisions,
                    const Color(0xFFFF6A78),
                  ),
                  _ratioBar(
                    'Still Active',
                    site.activeDispatches,
                    site.decisions,
                    const Color(0xFF6FB5FF),
                  ),
                ],
              ),
            );
            final pulsePanel = _panel(
              'Operational Pulse',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _textLine('Guards Engaged', site.guardsEngaged.toString()),
                  _textLine(
                    'Avg Patrol Duration',
                    '${site.averagePatrolMinutes.toStringAsFixed(1)} min',
                  ),
                  _textLine('Last Event UTC', _formatUtc(site.lastEventAtUtc)),
                  _textLine(
                    'Recent Event Count',
                    site.recentEvents.length.toString(),
                  ),
                  _textLine(
                    'Denied Reason Trend',
                    site.deniedReasons.isEmpty
                        ? 'No denials recorded'
                        : site.deniedReasons.first,
                  ),
                ],
              ),
            );
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [outcomePanel, const SizedBox(height: 8), pulsePanel],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: outcomePanel),
                const SizedBox(width: 8),
                Expanded(child: pulsePanel),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        _panel(
          'Recent Site Event Trace',
          site.recentEvents.isEmpty
              ? Text(
                  'No event trace available.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8EA4C2),
                    fontSize: 13,
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  primary: false,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: site.recentEvents.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final row = site.recentEvents[index];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 5),
                          child: Icon(
                            Icons.circle,
                            size: 7,
                            color: Color(0xFF4AAAFF),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            row,
                            style: GoogleFonts.inter(
                              color: const Color(0xFFD2E2FA),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
        if (site.traceEventCount > site.recentEvents.length)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: OnyxTruncationHint(
              visibleCount: site.recentEvents.length,
              totalCount: site.traceEventCount,
              subject: 'site events',
              hiddenDescriptor: 'older events',
            ),
          ),
      ],
    );
    return Container(
      decoration: onyxWorkspaceSurfaceDecoration(),
      child: embeddedScroll
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: content,
            )
          : Padding(padding: const EdgeInsets.all(10), child: content),
    );
  }

  Widget _ratioBar(String label, int value, int total, Color color) {
    final ratio = total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  color: const Color(0xFF9FB5D4),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '$value/$total',
                style: GoogleFonts.inter(
                  color: const Color(0xFFD4E3F8),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: ratio,
              backgroundColor: const Color(0xFF1A283A),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _textLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: GoogleFonts.inter(
                color: const Color(0xFF8EA4C2),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: GoogleFonts.inter(
                color: const Color(0xFFD7E5F8),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panel(String title, Widget child, {bool expandChild = false}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: onyxPanelSurfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFF3C79BB),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFE4EEFF),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          if (expandChild) Expanded(child: child) else child,
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value, Color accent) {
    return Container(
      width: 164,
      padding: const EdgeInsets.all(9),
      decoration: onyxPanelSurfaceDecoration(radius: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 3,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 5),
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
              color: accent,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tinyPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.8)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'CRITICAL':
        return const Color(0xFFFF6575);
      case 'WARNING':
        return const Color(0xFFF6B24A);
      case 'STABLE':
        return const Color(0xFF47D49B);
      default:
        return const Color(0xFF40C6FF);
    }
  }

  String _formatUtc(DateTime dt) {
    final z = dt.toUtc().toIso8601String();
    return z.length > 19 ? '${z.substring(0, 19)}Z' : z;
  }

  List<_SiteDrillSnapshot> _buildSiteDrillSnapshots(
    List<DispatchEvent> events,
    OperationsHealthSnapshot projection,
  ) {
    final bySite = <String, _SiteAccumulator>{};
    final decisionTimes = <String, DateTime>{};
    final decisionSite = <String, String>{};
    final terminalDispatches = <String, String>{};

    for (final event in events) {
      final siteKey = _siteKeyFromEvent(event);
      if (siteKey == null) continue;

      final acc = bySite.putIfAbsent(siteKey, () => _SiteAccumulator(siteKey));
      acc.lastEventAtUtc = acc.lastEventAtUtc.isAfter(event.occurredAt)
          ? acc.lastEventAtUtc
          : event.occurredAt;

      if (event is DecisionCreated) {
        decisionTimes[event.dispatchId] = event.occurredAt;
        decisionSite[event.dispatchId] = siteKey;
        acc.decisions += 1;
        acc.recentTrace.add(
          _trace(event.occurredAt, 'DECISION ${event.dispatchId} created'),
        );
      } else if (event is ExecutionCompleted) {
        terminalDispatches[event.dispatchId] = event.success
            ? 'EXECUTED'
            : 'FAILED';
        if (event.success) {
          acc.executed += 1;
          acc.recentTrace.add(
            _trace(event.occurredAt, 'EXECUTED ${event.dispatchId}'),
          );
        } else {
          acc.failed += 1;
          acc.recentTrace.add(
            _trace(event.occurredAt, 'FAILED ${event.dispatchId}'),
          );
        }
      } else if (event is ExecutionDenied) {
        terminalDispatches[event.dispatchId] = 'DENIED';
        acc.denied += 1;
        acc.deniedReasons.add(event.reason);
        acc.recentTrace.add(
          _trace(
            event.occurredAt,
            'DENIED ${event.dispatchId} (${event.reason})',
          ),
        );
      } else if (event is GuardCheckedIn) {
        acc.checkIns += 1;
        acc.guards.add(event.guardId);
        acc.recentTrace.add(
          _trace(event.occurredAt, 'GUARD CHECK-IN ${event.guardId}'),
        );
      } else if (event is PatrolCompleted) {
        acc.patrols += 1;
        acc.guards.add(event.guardId);
        acc.patrolDurationSeconds += event.durationSeconds;
        acc.recentTrace.add(
          _trace(event.occurredAt, 'PATROL ${event.routeId} completed'),
        );
      } else if (event is IncidentClosed) {
        acc.incidents += 1;
        acc.recentTrace.add(
          _trace(
            event.occurredAt,
            'INCIDENT ${event.dispatchId} closed (${event.resolutionType})',
          ),
        );
      } else if (event is ResponseArrived) {
        acc.guards.add(event.guardId);
        final decisionAt = decisionTimes[event.dispatchId];
        if (decisionAt != null) {
          acc.responseDeltaMinutes.add(
            event.occurredAt.difference(decisionAt).inMilliseconds / 60000.0,
          );
        }
        acc.recentTrace.add(
          _trace(
            event.occurredAt,
            'RESPONSE ${event.dispatchId} by ${event.guardId}',
          ),
        );
      }
    }

    for (final entry in decisionSite.entries) {
      final siteKey = entry.value;
      final dispatchId = entry.key;
      final state = terminalDispatches[dispatchId];
      if (state == null) {
        bySite[siteKey]?.active += 1;
      }
    }

    final projectionBySite = {
      for (final site in projection.sites)
        '${site.clientId}|${site.regionId}|${site.siteId}': site,
    };

    final snapshots = <_SiteDrillSnapshot>[];
    for (final acc in bySite.values) {
      final parts = acc.siteKey.split('|');
      if (parts.length != 3) continue;

      final projectionSite = projectionBySite[acc.siteKey];
      final avgResponse = acc.responseDeltaMinutes.isEmpty
          ? (projectionSite?.averageResponseMinutes ?? 0.0)
          : acc.responseDeltaMinutes.reduce((a, b) => a + b) /
                acc.responseDeltaMinutes.length;

      final avgPatrol = acc.patrols == 0
          ? 0.0
          : (acc.patrolDurationSeconds / acc.patrols) / 60.0;

      snapshots.add(
        _SiteDrillSnapshot(
          siteKey: acc.siteKey,
          clientId: parts[0],
          regionId: parts[1],
          siteId: parts[2],
          decisions: acc.decisions,
          executedCount: projectionSite?.executedCount ?? acc.executed,
          deniedCount: projectionSite?.deniedCount ?? acc.denied,
          failedCount: projectionSite?.failedCount ?? acc.failed,
          activeDispatches: projectionSite?.activeDispatches ?? acc.active,
          guardCheckIns: projectionSite?.guardCheckIns ?? acc.checkIns,
          patrolsCompleted: projectionSite?.patrolsCompleted ?? acc.patrols,
          incidentsClosed: projectionSite?.incidentsClosed ?? acc.incidents,
          averageResponseMinutes: avgResponse,
          averagePatrolMinutes: avgPatrol,
          guardsEngaged: acc.guards.length,
          deniedReasons: acc.deniedReasons.reversed.take(3).toList(),
          healthScore: projectionSite?.healthScore ?? 0.0,
          healthStatus: projectionSite?.healthStatus ?? 'STABLE',
          lastEventAtUtc: acc.lastEventAtUtc,
          traceEventCount: acc.recentTrace.length,
          recentEvents: acc.recentTrace.reversed.take(10).toList(),
        ),
      );
    }

    snapshots.sort((a, b) {
      final scoreSort = a.healthScore.compareTo(b.healthScore);
      if (scoreSort != 0) return scoreSort;
      return b.lastEventAtUtc.compareTo(a.lastEventAtUtc);
    });

    return snapshots;
  }

  String? _siteKeyFromEvent(DispatchEvent event) {
    if (event is DecisionCreated) {
      return '${event.clientId}|${event.regionId}|${event.siteId}';
    }
    if (event is ExecutionCompleted) {
      return '${event.clientId}|${event.regionId}|${event.siteId}';
    }
    if (event is ExecutionDenied) {
      return '${event.clientId}|${event.regionId}|${event.siteId}';
    }
    if (event is GuardCheckedIn) {
      return '${event.clientId}|${event.regionId}|${event.siteId}';
    }
    if (event is PatrolCompleted) {
      return '${event.clientId}|${event.regionId}|${event.siteId}';
    }
    if (event is ResponseArrived) {
      return '${event.clientId}|${event.regionId}|${event.siteId}';
    }
    if (event is IncidentClosed) {
      return '${event.clientId}|${event.regionId}|${event.siteId}';
    }
    return null;
  }

  String _trace(DateTime ts, String message) {
    final z = _formatUtc(ts);
    return '$z • $message';
  }
}

class _SiteAccumulator {
  final String siteKey;

  int decisions = 0;
  int executed = 0;
  int denied = 0;
  int failed = 0;
  int active = 0;
  int checkIns = 0;
  int patrols = 0;
  int incidents = 0;
  int patrolDurationSeconds = 0;
  final List<double> responseDeltaMinutes = [];
  final Set<String> guards = {};
  final List<String> deniedReasons = [];
  final List<String> recentTrace = [];
  DateTime lastEventAtUtc = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  _SiteAccumulator(this.siteKey);
}

class _SiteDrillSnapshot {
  final String siteKey;
  final String clientId;
  final String regionId;
  final String siteId;
  final int decisions;
  final int executedCount;
  final int deniedCount;
  final int failedCount;
  final int activeDispatches;
  final int guardCheckIns;
  final int patrolsCompleted;
  final int incidentsClosed;
  final double averageResponseMinutes;
  final double averagePatrolMinutes;
  final int guardsEngaged;
  final List<String> deniedReasons;
  final double healthScore;
  final String healthStatus;
  final DateTime lastEventAtUtc;
  final int traceEventCount;
  final List<String> recentEvents;

  const _SiteDrillSnapshot({
    required this.siteKey,
    required this.clientId,
    required this.regionId,
    required this.siteId,
    required this.decisions,
    required this.executedCount,
    required this.deniedCount,
    required this.failedCount,
    required this.activeDispatches,
    required this.guardCheckIns,
    required this.patrolsCompleted,
    required this.incidentsClosed,
    required this.averageResponseMinutes,
    required this.averagePatrolMinutes,
    required this.guardsEngaged,
    required this.deniedReasons,
    required this.healthScore,
    required this.healthStatus,
    required this.lastEventAtUtc,
    required this.traceEventCount,
    required this.recentEvents,
  });
}
