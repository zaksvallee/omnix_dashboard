import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../domain/authority/onyx_route.dart';
import '../domain/events/decision_created.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/execution_completed.dart';
import '../domain/events/execution_denied.dart';
import '../domain/events/guard_checked_in.dart';
import '../domain/events/incident_closed.dart';
import '../domain/events/patrol_completed.dart';
import '../domain/events/response_arrived.dart';
import '../domain/projection/operations_health_projection.dart';
import 'onyx_surface.dart';
import 'theme/onyx_design_tokens.dart';

class SitesPage extends StatefulWidget {
  final List<DispatchEvent> events;

  const SitesPage({super.key, required this.events});

  @override
  State<SitesPage> createState() => _SitesPageState();
}

enum _SitePosture { strong, atRisk, critical }

class _SitesPageState extends State<SitesPage> {
  String? _selectedSiteKey;

  @override
  Widget build(BuildContext context) {
    final projection = OperationsHealthProjection.build(widget.events);
    final allSites = _buildSiteDrillSnapshots(widget.events, projection)
        .where((site) {
          final id = site.siteId.trim().toLowerCase();
          return id.isNotEmpty && id != 'site-unknown';
        })
        .toList(growable: false);

    if (allSites.isEmpty) {
      return const OnyxPageScaffold(
        child: OnyxEmptyState(
          label: 'No sites available in the current projection.',
        ),
      );
    }

    final selectedSite = _resolveSelectedSite(allSites);
    final strongCount = allSites
        .where((site) => _sitePosture(site) == _SitePosture.strong)
        .length;
    final atRiskCount = allSites
        .where((site) => _sitePosture(site) == _SitePosture.atRisk)
        .length;
    final criticalCount = allSites
        .where((site) => _sitePosture(site) == _SitePosture.critical)
        .length;

    return OnyxPageScaffold(
      child: OnyxViewportWorkspaceLayout(
        padding: const EdgeInsets.all(16),
        maxWidth: 1540,
        spacing: 12,
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderRow(context),
            const SizedBox(height: 12),
            _buildPostureSummaryBar(
              totalCount: allSites.length,
              strongCount: strongCount,
              atRiskCount: atRiskCount,
              criticalCount: criticalCount,
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 1100;
            final roster = _buildRosterPanel(
              sites: allSites,
              selectedSite: selectedSite,
            );
            final detail = _buildDetailPanel(
              context,
              selectedSite: selectedSite,
            );

            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  roster,
                  const SizedBox(height: 12),
                  detail,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 300, child: roster),
                const SizedBox(width: 12),
                Expanded(child: detail),
              ],
            );
          },
        ),
      ),
    );
  }

  _SiteDrillSnapshot _resolveSelectedSite(List<_SiteDrillSnapshot> sites) {
    final selectedKey = _selectedSiteKey;
    if (selectedKey != null) {
      for (final site in sites) {
        if (site.siteKey == selectedKey) {
          return site;
        }
      }
    }

    final first = sites.first;
    _selectedSiteKey = first.siteKey;
    return first;
  }

  Widget _buildHeaderRow(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sites & deployment',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: OnyxColorTokens.textPrimary,
              ),
            ),
            Text(
              'Site management, watch posture, and operational readiness',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: OnyxColorTokens.textSecondary,
              ),
            ),
          ],
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: () => _navigateToRoute(context, OnyxRoute.tactical),
          icon: const Icon(Icons.map_rounded, size: 16),
          label: const Text('View tactical'),
          style: OutlinedButton.styleFrom(
            foregroundColor: OnyxColorTokens.textSecondary,
            side: const BorderSide(color: OnyxColorTokens.borderSubtle),
            minimumSize: const Size(0, 34),
            textStyle: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPostureSummaryBar({
    required int totalCount,
    required int strongCount,
    required int atRiskCount,
    required int criticalCount,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        border: Border.all(color: OnyxColorTokens.divider),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          Text(
            'SITE POSTURE:',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: OnyxColorTokens.textMuted,
              letterSpacing: 0.7,
            ),
          ),
          _posturePill('$totalCount Total', OnyxColorTokens.textSecondary),
          _posturePill('$strongCount Strong', OnyxColorTokens.accentGreen),
          if (atRiskCount > 0)
            _posturePill('$atRiskCount At-Risk', OnyxColorTokens.accentAmber),
          if (criticalCount > 0)
            _posturePill('$criticalCount Critical', OnyxColorTokens.accentRed),
        ],
      ),
    );
  }

  Widget _buildRosterPanel({
    required List<_SiteDrillSnapshot> sites,
    required _SiteDrillSnapshot? selectedSite,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        border: Border.all(color: OnyxColorTokens.divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(
                  'SITE ROSTER',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: OnyxColorTokens.textMuted,
                    letterSpacing: 0.7,
                  ),
                ),
                const Spacer(),
                Text(
                  '${sites.length} sites',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: OnyxColorTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: OnyxColorTokens.divider, height: 1),
          ListView.builder(
            shrinkWrap: true,
            primary: false,
            itemCount: sites.length,
            itemBuilder: (context, index) {
              final site = sites[index];
              return _siteRosterRow(
                site,
                isSelected: selectedSite?.siteKey == site.siteKey,
                onTap: () => setState(() => _selectedSiteKey = site.siteKey),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _siteRosterRow(
    _SiteDrillSnapshot site, {
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final activeCams = _siteActiveCameras(site);
    final totalCams = _siteTotalCameras(site);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? OnyxColorTokens.cyanSurface
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? OnyxColorTokens.brand : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  site.siteId,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: OnyxColorTokens.textMuted,
                  ),
                ),
                const Spacer(),
                _postureBadge(site),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              _siteDisplayName(site.siteId),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: OnyxColorTokens.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.people_alt_rounded,
                  size: 12,
                  color: OnyxColorTokens.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  '${site.guardsEngaged} guards',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: OnyxColorTokens.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.videocam_rounded,
                  size: 12,
                  color: OnyxColorTokens.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  '$activeCams/$totalCams cams',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: OnyxColorTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailPanel(
    BuildContext context, {
    required _SiteDrillSnapshot? selectedSite,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        border: Border.all(color: OnyxColorTokens.divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: selectedSite == null
          ? _emptyDetailState()
          : _siteDetailContent(context, selectedSite),
    );
  }

  Widget _emptyDetailState() {
    return SizedBox(
      height: 520,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: OnyxColorTokens.brand.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: OnyxColorTokens.borderSubtle),
              ),
              child: const Icon(
                Icons.business_rounded,
                color: OnyxColorTokens.brand,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Select a site',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: OnyxColorTokens.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose a site from the roster to inspect posture and operations.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: OnyxColorTokens.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _siteDetailContent(BuildContext context, _SiteDrillSnapshot site) {
    final activeCams = _siteActiveCameras(site);
    final totalCams = _siteTotalCameras(site);
    final avgResponseSeconds = site.averageResponseMinutes > 0
        ? (site.averageResponseMinutes * 60).round()
        : 0;
    final watchStatus = _watchStatus(site);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: OnyxColorTokens.brand.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: OnyxColorTokens.borderSubtle),
              ),
              child: const Icon(
                Icons.business_rounded,
                color: OnyxColorTokens.brand,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _siteDisplayName(site.siteId),
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: OnyxColorTokens.textPrimary,
                  ),
                ),
                Text(
                  site.siteId,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: OnyxColorTokens.textSecondary,
                  ),
                ),
              ],
            ),
            const Spacer(),
            _postureBadge(site),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 920) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _siteStatCard(
                          'GUARDS ON-SITE',
                          site.guardsEngaged.toString(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _siteStatCard(
                          'CAMERAS ACTIVE',
                          '$activeCams/$totalCams',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _siteStatCard(
                          '24H INCIDENTS',
                          site.decisions.toString(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _siteStatCard(
                          'AVG RESPONSE',
                          '${avgResponseSeconds}s',
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child: _siteStatCard(
                    'GUARDS ON-SITE',
                    site.guardsEngaged.toString(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _siteStatCard(
                    'CAMERAS ACTIVE',
                    '$activeCams/$totalCams',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _siteStatCard('24H INCIDENTS', site.decisions.toString()),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _siteStatCard(
                    'AVG RESPONSE',
                    '${avgResponseSeconds}s',
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: OnyxColorTokens.backgroundSecondary,
            border: Border.all(color: OnyxColorTokens.divider),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.visibility_rounded,
                    size: 16,
                    color: OnyxColorTokens.brand,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'WATCH HEALTH STATUS',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: OnyxColorTokens.textMuted,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Camera feed and verification state',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: OnyxColorTokens.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: watchStatus.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: watchStatus.border),
                ),
                child: Row(
                  children: [
                    Icon(watchStatus.icon, size: 16, color: watchStatus.accent),
                    const SizedBox(width: 8),
                    Text(
                      watchStatus.headline,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: watchStatus.accent,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: watchStatus.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        watchStatus.badgeLabel,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: watchStatus.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: watchStatus.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: watchStatus.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      watchStatus.detailIcon,
                      size: 16,
                      color: watchStatus.accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            watchStatus.detailTitle,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: watchStatus.accent,
                            ),
                          ),
                          Text(
                            watchStatus.detailBody,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: OnyxColorTokens.textSecondary,
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
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: OnyxColorTokens.backgroundSecondary,
            border: Border.all(color: OnyxColorTokens.divider),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.settings_rounded,
                    size: 16,
                    color: OnyxColorTokens.brand,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'SITE OPERATIONS',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: OnyxColorTokens.textMuted,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Management and operational controls',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: OnyxColorTokens.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _siteOpButton(
                      context,
                      Icons.map_rounded,
                      'Tactical map',
                      () => _navigateToRoute(context, OnyxRoute.tactical),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _siteOpButton(
                      context,
                      Icons.settings_rounded,
                      'Site settings',
                      () {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _siteOpButton(
                      context,
                      Icons.people_alt_rounded,
                      'Guard roster',
                      () => _navigateToRoute(context, OnyxRoute.guards),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _siteOpButton(
                      context,
                      Icons.videocam_rounded,
                      'Camera feed',
                      () => _navigateToRoute(context, OnyxRoute.aiQueue),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _siteOpButton(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onPressed,
  ) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: OnyxColorTokens.textSecondary,
        side: const BorderSide(color: OnyxColorTokens.divider),
        minimumSize: const Size(double.infinity, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          const Icon(Icons.chevron_right_rounded, size: 16),
        ],
      ),
    );
  }

  Widget _posturePill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _postureBadge(_SiteDrillSnapshot site) {
    final posture = _sitePosture(site);
    final color = switch (posture) {
      _SitePosture.strong => OnyxColorTokens.accentGreen,
      _SitePosture.atRisk => OnyxColorTokens.accentAmber,
      _SitePosture.critical => OnyxColorTokens.accentRed,
    };
    final label = switch (posture) {
      _SitePosture.strong => 'STRONG',
      _SitePosture.atRisk => 'AT-RISK',
      _SitePosture.critical => 'CRITICAL',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _siteStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundPrimary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: OnyxColorTokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: OnyxColorTokens.textMuted,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: OnyxColorTokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  _WatchStatus _watchStatus(_SiteDrillSnapshot site) {
    final posture = _sitePosture(site);
    final watchAvailable = _siteWatchAvailable(site);

    if (posture == _SitePosture.critical) {
      return const _WatchStatus(
        surface: OnyxColorTokens.redSurface,
        border: OnyxColorTokens.redBorder,
        accent: OnyxColorTokens.accentRed,
        icon: Icons.warning_rounded,
        headline: 'Watch degraded',
        badgeLabel: 'CRITICAL',
        detailIcon: Icons.error_rounded,
        detailTitle: 'Critical site posture',
        detailBody:
            'Active failures or severe watch pressure need immediate intervention and escalation.',
      );
    }

    if (!watchAvailable || posture == _SitePosture.atRisk) {
      return const _WatchStatus(
        surface: OnyxColorTokens.amberSurface,
        border: OnyxColorTokens.amberBorder,
        accent: OnyxColorTokens.accentAmber,
        icon: Icons.remove_red_eye_rounded,
        headline: 'Watch under review',
        badgeLabel: 'AT-RISK',
        detailIcon: Icons.info_rounded,
        detailTitle: 'At-risk site posture',
        detailBody:
            'Recent site signals need closer review to keep watch continuity and response readiness tight.',
      );
    }

    return const _WatchStatus(
      surface: OnyxColorTokens.greenSurface,
      border: OnyxColorTokens.greenBorder,
      accent: OnyxColorTokens.accentGreen,
      icon: Icons.wifi_rounded,
      headline: 'Watch available',
      badgeLabel: 'AVAILABLE',
      detailIcon: Icons.check_circle_rounded,
      detailTitle: 'Strong site posture',
      detailBody:
          'All systems operational. Guards present. Watch available. No immediate concerns.',
    );
  }

  bool _siteWatchAvailable(_SiteDrillSnapshot site) {
    return site.failedCount == 0 &&
        site.healthStatus != 'CRITICAL' &&
        (site.guardsEngaged > 0 ||
            site.guardCheckIns > 0 ||
            site.patrolsCompleted > 0 ||
            site.recentEvents.isNotEmpty);
  }

  _SitePosture _sitePosture(_SiteDrillSnapshot site) {
    if (site.healthStatus == 'CRITICAL' || site.failedCount > 0) {
      return _SitePosture.critical;
    }
    if (site.healthStatus == 'WARNING' ||
        site.deniedCount > 0 ||
        site.activeDispatches > 0) {
      return _SitePosture.atRisk;
    }
    return _SitePosture.strong;
  }

  int _siteActiveCameras(_SiteDrillSnapshot site) {
    return 0;
  }

  int _siteTotalCameras(_SiteDrillSnapshot site) {
    return 0;
  }

  String _siteDisplayName(String raw) {
    final normalized = raw.trim().replaceAll('_', '-');
    return normalized
        .split('-')
        .where((segment) => segment.trim().isNotEmpty)
        .map((segment) {
          final word = segment.trim();
          if (word == word.toUpperCase()) {
            return word;
          }
          return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
        })
        .join(' ');
  }

  void _navigateToRoute(BuildContext context, OnyxRoute route) {
    try {
      Navigator.of(context).pushNamed(route.path);
    } catch (_) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: OnyxColorTokens.backgroundPrimary,
          content: Text(
            '${route.label} opens from the controller shell.',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: OnyxColorTokens.accentSky,
            ),
          ),
        ),
      );
    }
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
            ? 'CONFIRMED'
            : 'FAILED';
        if (event.success) {
          acc.executed += 1;
          acc.recentTrace.add(
            _trace(event.occurredAt, 'CONFIRMED ${event.dispatchId}'),
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

  String _formatUtc(DateTime dt) {
    final z = dt.toUtc().toIso8601String();
    return z.length > 19 ? '${z.substring(0, 19)}Z' : z;
  }
}

class _WatchStatus {
  final Color surface;
  final Color border;
  final Color accent;
  final IconData icon;
  final String headline;
  final String badgeLabel;
  final IconData detailIcon;
  final String detailTitle;
  final String detailBody;

  const _WatchStatus({
    required this.surface,
    required this.border,
    required this.accent,
    required this.icon,
    required this.headline,
    required this.badgeLabel,
    required this.detailIcon,
    required this.detailTitle,
    required this.detailBody,
  });
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
