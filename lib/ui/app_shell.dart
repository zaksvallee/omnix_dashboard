import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

import 'layout_breakpoints.dart';

enum OnyxRoute {
  dashboard,
  aiQueue,
  tactical,
  governance,
  clients,
  sites,
  guards,
  dispatches,
  events,
  ledger,
  reports,
  admin,
}

class OnyxIntelTickerItem {
  final String id;
  final String? eventId;
  final String sourceType;
  final String provider;
  final String headline;
  final DateTime occurredAtUtc;

  const OnyxIntelTickerItem({
    required this.id,
    this.eventId,
    required this.sourceType,
    required this.provider,
    required this.headline,
    required this.occurredAtUtc,
  });
}

class AppShell extends StatefulWidget {
  final Widget child;
  final OnyxRoute currentRoute;
  final ValueChanged<OnyxRoute> onRouteChanged;
  final ValueChanged<OnyxIntelTickerItem>? onIntelTickerTap;
  final int activeIncidentCount;
  final int aiActionCount;
  final int guardsOnlineCount;
  final int complianceIssuesCount;
  final int tacticalSosAlerts;
  final List<OnyxIntelTickerItem> intelTickerItems;
  final String demoAutopilotStatusLabel;
  final VoidCallback? onStopDemoAutopilot;
  final VoidCallback? onSkipDemoAutopilot;
  final VoidCallback? onToggleDemoAutopilotPause;
  final bool demoAutopilotPaused;

  const AppShell({
    super.key,
    required this.child,
    required this.currentRoute,
    required this.onRouteChanged,
    this.onIntelTickerTap,
    this.activeIncidentCount = 0,
    this.aiActionCount = 0,
    this.guardsOnlineCount = 0,
    this.complianceIssuesCount = 0,
    this.tacticalSosAlerts = 0,
    this.intelTickerItems = const [],
    this.demoAutopilotStatusLabel = '',
    this.onStopDemoAutopilot,
    this.onSkipDemoAutopilot,
    this.onToggleDemoAutopilotPause,
    this.demoAutopilotPaused = false,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _sidebarOpen = true;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final handsetLayout = isHandsetLayout(context);
        final mobileLayout = constraints.maxWidth < 980 || handsetLayout;
        if (mobileLayout) {
          return Scaffold(
            backgroundColor: const Color(0xFF0C1220),
            drawer: Drawer(
              width: constraints.maxWidth < 420
                  ? constraints.maxWidth * 0.84
                  : 320,
              backgroundColor: Colors.transparent,
              child: _Sidebar(
                width: 320,
                currentRoute: widget.currentRoute,
                activeIncidentCount: widget.activeIncidentCount,
                aiActionCount: widget.aiActionCount,
                complianceIssuesCount: widget.complianceIssuesCount,
                tacticalSosAlerts: widget.tacticalSosAlerts,
                guardsOnlineCount: widget.guardsOnlineCount,
                onRouteChanged: (route) {
                  Navigator.of(context).maybePop();
                  widget.onRouteChanged(route);
                },
              ),
            ),
            body: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(color: Color(0xFF0C1220)),
                  child: widget.child,
                ),
                if (widget.demoAutopilotStatusLabel.trim().isNotEmpty)
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(50, 4, 8, 0),
                        child: _MobileAutopilotOverlay(
                          label: widget.demoAutopilotStatusLabel,
                          paused: widget.demoAutopilotPaused,
                          onStop: widget.onStopDemoAutopilot,
                          onSkip: widget.onSkipDemoAutopilot,
                          onTogglePause: widget.onToggleDemoAutopilotPause,
                        ),
                      ),
                    ),
                  ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6, top: 4),
                    child: Builder(
                      builder: (innerContext) => Material(
                        color: const Color(0xBF0A0D14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Color(0x33FFFFFF)),
                        ),
                        child: InkWell(
                          onTap: () => Scaffold.of(innerContext).openDrawer(),
                          borderRadius: BorderRadius.circular(10),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.menu_rounded,
                              size: 20,
                              color: Color(0xFFE7F0FF),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        const sidebarWidth = 252.0;
        return Scaffold(
          backgroundColor: const Color(0xFF0C1220),
          body: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                width: _sidebarOpen ? sidebarWidth : 0,
                child: ClipRect(
                  child: _sidebarOpen
                      ? _Sidebar(
                          width: sidebarWidth,
                          currentRoute: widget.currentRoute,
                          activeIncidentCount: widget.activeIncidentCount,
                          aiActionCount: widget.aiActionCount,
                          complianceIssuesCount: widget.complianceIssuesCount,
                          tacticalSosAlerts: widget.tacticalSosAlerts,
                          guardsOnlineCount: widget.guardsOnlineCount,
                          onRouteChanged: widget.onRouteChanged,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(color: Color(0xFF0C1220)),
                  child: Column(
                    children: [
                      _ShellTopBar(
                        currentRoute: widget.currentRoute,
                        activeIncidentCount: widget.activeIncidentCount,
                        aiActionCount: widget.aiActionCount,
                        guardsOnlineCount: widget.guardsOnlineCount,
                        demoAutopilotStatusLabel:
                            widget.demoAutopilotStatusLabel,
                        onStopDemoAutopilot: widget.onStopDemoAutopilot,
                        onSkipDemoAutopilot: widget.onSkipDemoAutopilot,
                        onToggleDemoAutopilotPause:
                            widget.onToggleDemoAutopilotPause,
                        demoAutopilotPaused: widget.demoAutopilotPaused,
                        sidebarOpen: _sidebarOpen,
                        onToggleSidebar: () {
                          setState(() {
                            _sidebarOpen = !_sidebarOpen;
                          });
                        },
                      ),
                      if (widget.intelTickerItems.isNotEmpty)
                        _ShellIntelTicker(
                          items: widget.intelTickerItems,
                          onItemTap: widget.onIntelTickerTap,
                        ),
                      Expanded(child: widget.child),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ShellTopBar extends StatelessWidget {
  final OnyxRoute currentRoute;
  final int activeIncidentCount;
  final int aiActionCount;
  final int guardsOnlineCount;
  final String demoAutopilotStatusLabel;
  final VoidCallback? onStopDemoAutopilot;
  final VoidCallback? onSkipDemoAutopilot;
  final VoidCallback? onToggleDemoAutopilotPause;
  final bool demoAutopilotPaused;
  final bool sidebarOpen;
  final VoidCallback onToggleSidebar;

  const _ShellTopBar({
    required this.currentRoute,
    required this.activeIncidentCount,
    required this.aiActionCount,
    required this.guardsOnlineCount,
    this.demoAutopilotStatusLabel = '',
    this.onStopDemoAutopilot,
    this.onSkipDemoAutopilot,
    this.onToggleDemoAutopilotPause,
    this.demoAutopilotPaused = false,
    required this.sidebarOpen,
    required this.onToggleSidebar,
  });

  String _routeLabel() {
    return switch (currentRoute) {
      OnyxRoute.dashboard => 'Live Operations',
      OnyxRoute.aiQueue => 'AI Queue',
      OnyxRoute.tactical => 'Tactical Map',
      OnyxRoute.governance => 'Governance',
      OnyxRoute.clients => 'Clients',
      OnyxRoute.sites => 'Sites',
      OnyxRoute.guards => 'Guards',
      OnyxRoute.dispatches => 'Dispatches',
      OnyxRoute.events => 'Events',
      OnyxRoute.ledger => 'Sovereign Ledger',
      OnyxRoute.reports => 'Reports',
      OnyxRoute.admin => 'Administration',
    };
  }

  String _timeLabel() {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCombatWindow = now.hour >= 22 || now.hour < 6;
    final windowLabel = isCombatWindow
        ? 'Combat Window Active'
        : 'Day Window Active';

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0D14),
        border: Border(bottom: BorderSide(color: Color(0x22FFFFFF))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showAutopilot = demoAutopilotStatusLabel.trim().isNotEmpty;
          final showAiChip =
              constraints.maxWidth >= (showAutopilot ? 1180 : 1080);
          final showGuardChip =
              constraints.maxWidth >= (showAutopilot ? 1460 : 1240);
          final showExtendedAutopilotControls = constraints.maxWidth >= 1460;
          final showCompactAutopilotControls =
              showAutopilot && !showExtendedAutopilotControls;
          final autopilotChipWidth = showExtendedAutopilotControls
              ? 320.0
              : constraints.maxWidth >= 1280
              ? 240.0
              : 180.0;

          return Row(
            children: [
              IconButton(
                onPressed: onToggleSidebar,
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0x14000000),
                  side: const BorderSide(color: Color(0x22FFFFFF)),
                ),
                icon: Icon(
                  sidebarOpen ? Icons.close_rounded : Icons.menu_rounded,
                  size: 18,
                  color: const Color(0xFFB6C7E3),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                _timeLabel(),
                style: GoogleFonts.inter(
                  color: const Color(0xFFD7E6FA),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              Container(width: 1, height: 16, color: const Color(0x22FFFFFF)),
              const SizedBox(width: 10),
              Text(
                windowLabel,
                style: GoogleFonts.inter(
                  color: isCombatWindow
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF8FB3DD),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _routeLabel(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9AB3D2),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              if (showAutopilot) ...[
                SizedBox(
                  width: autopilotChipWidth,
                  child: _AutopilotChip(label: demoAutopilotStatusLabel),
                ),
                if (onStopDemoAutopilot != null) ...[
                  const SizedBox(width: 6),
                  if (showCompactAutopilotControls)
                    _TopBarActionIcon(
                      onPressed: onStopDemoAutopilot!,
                      icon: Icons.stop_circle_outlined,
                      foregroundColor: const Color(0xFFFCA5A5),
                      borderColor: const Color(0xFF7F1D1D),
                    )
                  else
                    OutlinedButton(
                      onPressed: onStopDemoAutopilot,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(56, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        foregroundColor: const Color(0xFFFCA5A5),
                        side: const BorderSide(color: Color(0xFF7F1D1D)),
                        textStyle: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: const Text('Stop'),
                    ),
                ],
                if (showExtendedAutopilotControls &&
                    onToggleDemoAutopilotPause != null) ...[
                  const SizedBox(width: 6),
                  OutlinedButton(
                    onPressed: onToggleDemoAutopilotPause,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(66, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      foregroundColor: const Color(0xFFBFDBFE),
                      side: const BorderSide(color: Color(0xFF35506F)),
                      textStyle: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: Text(demoAutopilotPaused ? 'Resume' : 'Pause'),
                  ),
                ],
                if (showExtendedAutopilotControls &&
                    onSkipDemoAutopilot != null) ...[
                  const SizedBox(width: 6),
                  OutlinedButton(
                    onPressed: onSkipDemoAutopilot,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(56, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      foregroundColor: const Color(0xFF93C5FD),
                      side: const BorderSide(color: Color(0xFF35506F)),
                      textStyle: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: const Text('Next'),
                  ),
                ],
                if (showCompactAutopilotControls &&
                    onToggleDemoAutopilotPause != null) ...[
                  const SizedBox(width: 6),
                  _TopBarActionIcon(
                    onPressed: onToggleDemoAutopilotPause!,
                    icon: demoAutopilotPaused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    foregroundColor: const Color(0xFFBFDBFE),
                    borderColor: const Color(0xFF35506F),
                  ),
                ],
                if (showCompactAutopilotControls &&
                    onSkipDemoAutopilot != null) ...[
                  const SizedBox(width: 6),
                  _TopBarActionIcon(
                    onPressed: onSkipDemoAutopilot!,
                    icon: Icons.skip_next_rounded,
                    foregroundColor: const Color(0xFF93C5FD),
                    borderColor: const Color(0xFF35506F),
                  ),
                ],
                const SizedBox(width: 8),
              ],
              _TopChip(
                label: '$activeIncidentCount Active Incidents',
                foreground: const Color(0xFFF87171),
                background: const Color(0x33EF4444),
                border: const Color(0x66EF4444),
              ),
              if (showAiChip) ...[
                const SizedBox(width: 8),
                _TopChip(
                  label: '$aiActionCount AI Actions',
                  foreground: const Color(0xFF22D3EE),
                  background: const Color(0x3322D3EE),
                  border: const Color(0x6622D3EE),
                ),
              ],
              if (showGuardChip) ...[
                const SizedBox(width: 8),
                _TopChip(
                  label: '$guardsOnlineCount Guards Online',
                  foreground: const Color(0xFF10B981),
                  background: const Color(0x3310B981),
                  border: const Color(0x6610B981),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _NavItemModel {
  final String label;
  final IconData icon;
  final OnyxRoute route;
  final int? badge;
  final Color? badgeColor;

  const _NavItemModel({
    required this.label,
    required this.icon,
    required this.route,
    this.badge,
    this.badgeColor,
  });
}

class _NavSection {
  final String title;
  final List<_NavItemModel> items;

  const _NavSection({required this.title, required this.items});
}

class _Sidebar extends StatelessWidget {
  final double width;
  final OnyxRoute currentRoute;
  final int activeIncidentCount;
  final int aiActionCount;
  final int guardsOnlineCount;
  final int complianceIssuesCount;
  final int tacticalSosAlerts;
  final ValueChanged<OnyxRoute> onRouteChanged;

  const _Sidebar({
    required this.width,
    required this.currentRoute,
    required this.activeIncidentCount,
    required this.aiActionCount,
    required this.guardsOnlineCount,
    required this.complianceIssuesCount,
    required this.tacticalSosAlerts,
    required this.onRouteChanged,
  });

  @override
  Widget build(BuildContext context) {
    final navSections = <_NavSection>[
      _NavSection(
        title: 'COMMAND CENTER',
        items: [
          _NavItemModel(
            label: 'Live Operations',
            icon: Icons.bolt_rounded,
            route: OnyxRoute.dashboard,
            badge: activeIncidentCount > 0 ? activeIncidentCount : null,
            badgeColor: Color(0xFFEF4444),
          ),
          _NavItemModel(
            label: 'AI Queue',
            icon: Icons.psychology_alt_rounded,
            route: OnyxRoute.aiQueue,
            badge: aiActionCount > 0 ? aiActionCount : null,
            badgeColor: Color(0xFF22D3EE),
          ),
          _NavItemModel(
            label: 'Dispatches',
            icon: Icons.send_rounded,
            route: OnyxRoute.dispatches,
          ),
          _NavItemModel(
            label: 'Tactical Map',
            icon: Icons.map_rounded,
            route: OnyxRoute.tactical,
            badge: tacticalSosAlerts > 0 ? tacticalSosAlerts : null,
            badgeColor: Color(0xFFEF4444),
          ),
        ],
      ),
      _NavSection(
        title: 'OPERATIONS',
        items: [
          _NavItemModel(
            label: 'Clients',
            icon: Icons.chat_bubble_rounded,
            route: OnyxRoute.clients,
          ),
          _NavItemModel(
            label: 'Guards',
            icon: Icons.groups_rounded,
            route: OnyxRoute.guards,
          ),
          _NavItemModel(
            label: 'Sites',
            icon: Icons.apartment_rounded,
            route: OnyxRoute.sites,
          ),
          _NavItemModel(
            label: 'Events',
            icon: Icons.timeline_rounded,
            route: OnyxRoute.events,
          ),
        ],
      ),
      _NavSection(
        title: 'GOVERNANCE',
        items: [
          _NavItemModel(
            label: 'Compliance',
            icon: Icons.shield_rounded,
            route: OnyxRoute.governance,
            badge: complianceIssuesCount > 0 ? complianceIssuesCount : null,
            badgeColor: Color(0xFFF59E0B),
          ),
        ],
      ),
      _NavSection(
        title: 'EVIDENCE',
        items: [
          _NavItemModel(
            label: 'Sovereign Ledger',
            icon: Icons.verified_user_rounded,
            route: OnyxRoute.ledger,
          ),
          _NavItemModel(
            label: 'Reports',
            icon: Icons.summarize_rounded,
            route: OnyxRoute.reports,
          ),
        ],
      ),
      _NavSection(
        title: 'SYSTEM',
        items: [
          _NavItemModel(
            label: 'Administration',
            icon: Icons.settings_rounded,
            route: OnyxRoute.admin,
          ),
        ],
      ),
    ];

    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0D14),
        border: Border(right: BorderSide(color: Color(0x22FFFFFF))),
      ),
      child: Column(
        children: [
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0x22FFFFFF))),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: const Color(0xFF2563EB),
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: Color(0xFFFFFFFF),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ONYX',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFE7F0FF),
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    Text(
                      'Sovereign Platform',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8CA6CC),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0E1A2B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x22FFFFFF)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'System Status',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFD2E0F6),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _statusRow('EventStore', 'LIVE', const Color(0xFF10B981)),
                const SizedBox(height: 4),
                _statusRow(
                  'AI Engine',
                  '$aiActionCount ACTIVE',
                  const Color(0xFF22D3EE),
                ),
                const SizedBox(height: 4),
                _statusRow(
                  'Guards',
                  '$guardsOnlineCount On Shift',
                  const Color(0xFFDBEAFE),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
              children: [
                for (final section in navSections) ...[
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 6,
                      right: 6,
                      bottom: 6,
                    ),
                    child: Text(
                      section.title,
                      style: GoogleFonts.inter(
                        color: const Color(0x66FFFFFF),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  for (final item in section.items)
                    _navItem(
                      item.label,
                      item.icon,
                      item.route,
                      badge: item.badge,
                      badgeColor: item.badgeColor,
                    ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0x22FFFFFF))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ONYX Sovereign v4.3',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF7F96B6),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Controller: Admin-1',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF7F96B6),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Session: Active',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF10B981),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusRow(String label, String value, Color valueColor) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            color: valueColor,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _navItem(
    String label,
    IconData icon,
    OnyxRoute route, {
    int? badge,
    Color? badgeColor,
  }) {
    final isActive = route == currentRoute;
    return GestureDetector(
      onTap: () => onRouteChanged(route),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isActive ? const Color(0x3322D3EE) : const Color(0x14FFFFFF),
          border: Border.all(
            color: isActive ? const Color(0x4D22D3EE) : const Color(0x22FFFFFF),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive
                  ? const Color(0xFF22D3EE)
                  : const Color(0x99FFFFFF),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color: isActive
                      ? const Color(0xFFE6F2FF)
                      : const Color(0xB3FFFFFF),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (badgeColor ?? const Color(0xFF4A678B)).withValues(
                    alpha: 0.16,
                  ),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: (badgeColor ?? const Color(0xFF4A678B)).withValues(
                      alpha: 0.45,
                    ),
                  ),
                ),
                child: Text(
                  '$badge',
                  style: GoogleFonts.inter(
                    color: badgeColor ?? const Color(0xFF99B6DA),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopChip extends StatelessWidget {
  final String label;
  final Color foreground;
  final Color background;
  final Color border;

  const _TopChip({
    required this.label,
    required this.foreground,
    required this.background,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TopBarActionIcon extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final Color foregroundColor;
  final Color borderColor;

  const _TopBarActionIcon({
    required this.onPressed,
    required this.icon,
    required this.foregroundColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(34, 32),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        foregroundColor: foregroundColor,
        side: BorderSide(color: borderColor),
      ),
      child: Icon(icon, size: 15),
    );
  }
}

class _AutopilotChip extends StatelessWidget {
  final String label;

  const _AutopilotChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x332563EB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x664C6FFF)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_mode_rounded,
            size: 13,
            color: Color(0xFF93C5FD),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: const Color(0xFFBFDBFE),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileAutopilotOverlay extends StatelessWidget {
  final String label;
  final bool paused;
  final VoidCallback? onStop;
  final VoidCallback? onSkip;
  final VoidCallback? onTogglePause;

  const _MobileAutopilotOverlay({
    required this.label,
    this.paused = false,
    this.onStop,
    this.onSkip,
    this.onTogglePause,
  });

  @override
  Widget build(BuildContext context) {
    final stopAction = onStop;
    final skipAction = onSkip;
    final togglePauseAction = onTogglePause;
    return Material(
      color: const Color(0xE60A0D14),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x334C6FFF)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.auto_mode_rounded,
              size: 14,
              color: Color(0xFF93C5FD),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: const Color(0xFFBFDBFE),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (togglePauseAction != null)
              _mobileActionIcon(
                onTap: togglePauseAction,
                icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                color: const Color(0xFFBFDBFE),
              ),
            if (skipAction != null)
              _mobileActionIcon(
                onTap: skipAction,
                icon: Icons.skip_next_rounded,
                color: const Color(0xFF93C5FD),
              ),
            if (stopAction != null)
              _mobileActionIcon(
                onTap: stopAction,
                icon: Icons.stop_circle_outlined,
                color: const Color(0xFFFCA5A5),
              ),
          ],
        ),
      ),
    );
  }

  Widget _mobileActionIcon({
    required VoidCallback onTap,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

class _ShellIntelTicker extends StatefulWidget {
  final List<OnyxIntelTickerItem> items;
  final ValueChanged<OnyxIntelTickerItem>? onItemTap;

  const _ShellIntelTicker({required this.items, this.onItemTap});

  @override
  State<_ShellIntelTicker> createState() => _ShellIntelTickerState();
}

class _ShellIntelTickerState extends State<_ShellIntelTicker> {
  static const _autoScrollInterval = Duration(seconds: 4);
  static const _autoScrollDuration = Duration(milliseconds: 420);
  static const _tickerBackground = Color(0xFF09101B);
  static const _edgeFadeWidth = 22.0;
  static const _sourceFilterOrder = <String>[
    'all',
    'news',
    'hardware',
    'dvr',
    'radio',
    'wearable',
    'community',
    'system',
  ];

  late final ScrollController _scrollController = ScrollController();
  Timer? _autoScrollTimer;
  bool _hovering = false;
  bool _userInteracting = false;
  String _sourceFilter = 'all';

  @override
  void initState() {
    super.initState();
    _syncAutoScrollState();
  }

  @override
  void didUpdateWidget(covariant _ShellIntelTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length ||
        oldWidget.items != widget.items) {
      _syncAutoScrollState();
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncAutoScrollState() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    if (_filteredItems().length <= 1) {
      return;
    }
    _autoScrollTimer = Timer.periodic(_autoScrollInterval, (_) {
      _autoScrollTick();
    });
  }

  Future<void> _autoScrollTick() async {
    if (!mounted ||
        _hovering ||
        _userInteracting ||
        !_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final maxExtent = position.maxScrollExtent;
    if (maxExtent <= 0) {
      return;
    }
    final nextOffset = position.pixels + _nextAutoScrollStep(position);
    final target = nextOffset >= maxExtent ? 0.0 : nextOffset;
    await _scrollController.animateTo(
      target,
      duration: _autoScrollDuration,
      curve: Curves.easeOutCubic,
    );
  }

  double _nextAutoScrollStep(ScrollPosition position) {
    final viewport = position.viewportDimension;
    if (viewport <= 0) return 296.0;
    final computed = viewport * 0.58;
    if (computed < 220) return 220;
    if (computed > 420) return 420;
    return computed;
  }

  @override
  Widget build(BuildContext context) {
    final sourceCounts = _sourceCounts();
    final availableFilters = _availableFilters(sourceCounts);
    final activeFilter = availableFilters.contains(_sourceFilter)
        ? _sourceFilter
        : 'all';
    if (activeFilter != _sourceFilter) {
      _sourceFilter = activeFilter;
      _syncAutoScrollState();
    }
    final filteredItems = _filteredItems(activeFilter);

    return MouseRegion(
      onEnter: (_) {
        _hovering = true;
      },
      onExit: (_) {
        _hovering = false;
      },
      child: Container(
        height: 76,
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        decoration: const BoxDecoration(
          color: _tickerBackground,
          border: Border(bottom: BorderSide(color: Color(0x1FFFFFFF))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 24,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: availableFilters.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final source = availableFilters[index];
                  final selected = source == activeFilter;
                  final count = source == 'all'
                      ? widget.items.length
                      : (sourceCounts[source] ?? 0);
                  return _sourceFilterChip(
                    source: source,
                    count: count,
                    selected: selected,
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Stack(
                children: [
                  if (filteredItems.isEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'No ${_sourceLabel(activeFilter)} intelligence in ticker window.',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF8EA4C2),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    NotificationListener<UserScrollNotification>(
                      onNotification: (notification) {
                        if (notification.direction == ScrollDirection.idle) {
                          _userInteracting = false;
                        } else {
                          _userInteracting = true;
                        }
                        return false;
                      },
                      child: ListView.separated(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        itemCount: filteredItems.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          final color = _tickerColor(item.sourceType);
                          final hh = item.occurredAtUtc.hour.toString().padLeft(
                            2,
                            '0',
                          );
                          final mm = item.occurredAtUtc.minute
                              .toString()
                              .padLeft(2, '0');
                          final source = item.sourceType.trim().isEmpty
                              ? 'intel'
                              : item.sourceType.toUpperCase();
                          final provider = item.provider.trim().isEmpty
                              ? 'feed'
                              : item.provider;
                          return InkWell(
                            onTap: widget.onItemTap == null
                                ? null
                                : () => widget.onItemTap!(item),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.13),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: color.withValues(alpha: 0.42),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$source • $provider • $hh:$mm',
                                    style: GoogleFonts.inter(
                                      color: color,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 360,
                                    ),
                                    child: Text(
                                      item.headline,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFD9E8FD),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  IgnorePointer(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: _edgeFadeWidth,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [_tickerBackground, Color(0x0009101B)],
                          ),
                        ),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        width: _edgeFadeWidth,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Color(0x0009101B), _tickerBackground],
                          ),
                        ),
                      ),
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

  Map<String, int> _sourceCounts() {
    final counts = <String, int>{};
    for (final item in widget.items) {
      final source = _normalizeSource(item.sourceType);
      counts.update(source, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  List<String> _availableFilters(Map<String, int> counts) {
    final filters = <String>['all'];
    for (final source in _sourceFilterOrder) {
      if (source == 'all') continue;
      if ((counts[source] ?? 0) > 0) {
        filters.add(source);
      }
    }
    return filters;
  }

  List<OnyxIntelTickerItem> _filteredItems([String? source]) {
    final active = _normalizeSource(source ?? _sourceFilter);
    if (active == 'all') {
      return widget.items;
    }
    return widget.items
        .where((item) => _normalizeSource(item.sourceType) == active)
        .toList(growable: false);
  }

  String _normalizeSource(String sourceType) {
    final source = sourceType.trim().toLowerCase();
    return source.isEmpty ? 'system' : source;
  }

  String _sourceLabel(String sourceType) {
    final source = _normalizeSource(sourceType);
    if (source == 'all') return 'ALL';
    if (source == 'hardware') return 'CCTV';
    if (source == 'dvr') return 'DVR';
    return source.toUpperCase();
  }

  Widget _sourceFilterChip({
    required String source,
    required int count,
    required bool selected,
  }) {
    final color = source == 'all'
        ? const Color(0xFF93C5FD)
        : _tickerColor(source);
    return GestureDetector(
      onTap: () {
        if (_sourceFilter == source) return;
        setState(() {
          _sourceFilter = source;
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
        });
        _syncAutoScrollState();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.22)
              : const Color(0x12000000),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.65)
                : color.withValues(alpha: 0.32),
          ),
        ),
        child: Text(
          '${_sourceLabel(source)} • $count',
          style: GoogleFonts.inter(
            color: selected ? color : color.withValues(alpha: 0.78),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Color _tickerColor(String sourceType) {
    final source = sourceType.trim().toLowerCase();
    if (source == 'radio') {
      return const Color(0xFF22D3EE);
    }
    if (source == 'news') {
      return const Color(0xFFF59E0B);
    }
    if (source == 'wearable') {
      return const Color(0xFF10B981);
    }
    if (source == 'hardware') {
      return const Color(0xFFF59E0B);
    }
    if (source == 'dvr') {
      return const Color(0xFFFB7185);
    }
    if (source == 'community') {
      return const Color(0xFF3B82F6);
    }
    if (source == 'system') {
      return const Color(0xFF93C5FD);
    }
    return const Color(0xFFA78BFA);
  }
}
