import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

String _appShellRouteLabel(OnyxRoute route) {
  return switch (route) {
    OnyxRoute.dashboard => 'Command',
    OnyxRoute.aiQueue => 'AI Queue',
    OnyxRoute.tactical => 'Tactical',
    OnyxRoute.governance => 'Governance',
    OnyxRoute.clients => 'Clients',
    OnyxRoute.sites => 'Sites',
    OnyxRoute.guards => 'Guards',
    OnyxRoute.dispatches => 'Dispatches',
    OnyxRoute.events => 'Events',
    OnyxRoute.ledger => 'OB Log',
    OnyxRoute.reports => 'Reports',
    OnyxRoute.admin => 'Admin',
  };
}

String _appShellHeaderLabel(OnyxRoute route) {
  return switch (route) {
    OnyxRoute.dashboard => 'COMMAND',
    OnyxRoute.aiQueue => 'AI QUEUE',
    OnyxRoute.tactical => 'TRACK',
    OnyxRoute.governance => 'GOVERNANCE',
    OnyxRoute.clients => 'CLIENTS',
    OnyxRoute.sites => 'SITES',
    OnyxRoute.guards => 'GUARDS',
    OnyxRoute.dispatches => 'ALARMS',
    OnyxRoute.events => 'EVENTS',
    OnyxRoute.ledger => 'LEDGER',
    OnyxRoute.reports => 'REPORTS',
    OnyxRoute.admin => 'ADMIN',
  };
}

Future<void> _showAppShellQuickJumpDialog({
  required BuildContext context,
  required OnyxRoute currentRoute,
  required ValueChanged<OnyxRoute> onRouteChanged,
}) async {
  final routes = <({OnyxRoute route, String label})>[
    (route: OnyxRoute.dashboard, label: 'Command'),
    (route: OnyxRoute.aiQueue, label: 'AI Queue'),
    (route: OnyxRoute.tactical, label: 'Tactical'),
    (route: OnyxRoute.governance, label: 'Governance'),
    (route: OnyxRoute.clients, label: 'Clients'),
    (route: OnyxRoute.sites, label: 'Sites'),
    (route: OnyxRoute.guards, label: 'Guards'),
    (route: OnyxRoute.dispatches, label: 'Dispatches'),
    (route: OnyxRoute.events, label: 'Events'),
    (route: OnyxRoute.ledger, label: 'OB Log'),
    (route: OnyxRoute.reports, label: 'Reports'),
    (route: OnyxRoute.admin, label: 'Admin'),
  ];
  final selection = await showDialog<OnyxRoute>(
    context: context,
    builder: (dialogContext) {
      final queryNotifier = ValueNotifier<String>('');
      return Dialog(
        backgroundColor: const Color(0xFF101722),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF233244)),
        ),
        child: SizedBox(
          width: 420,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: ValueListenableBuilder<String>(
              valueListenable: queryNotifier,
              builder: (context, query, _) {
                final normalizedQuery = query.trim().toLowerCase();
                final filtered = routes
                    .where((entry) {
                      if (normalizedQuery.isEmpty) return true;
                      return entry.label.toLowerCase().contains(
                        normalizedQuery,
                      );
                    })
                    .toList(growable: false);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick jump',
                      style: GoogleFonts.rajdhani(
                        color: const Color(0xFFEAF4FF),
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      key: const ValueKey('app-shell-quick-jump-input'),
                      autofocus: true,
                      onChanged: (value) => queryNotifier.value = value,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFEAF4FF),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search routes',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF7D93B3),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0A0F17),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF253548),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF253548),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF22D3EE),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Flexible(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 320),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final entry = filtered[index];
                            final active = entry.route == currentRoute;
                            return InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () =>
                                  Navigator.of(dialogContext).pop(entry.route),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: active
                                      ? const Color(0x1A22D3EE)
                                      : const Color(0xFF0B1119),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: active
                                        ? const Color(0x8822D3EE)
                                        : const Color(0xFF223244),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        entry.label,
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFFEAF4FF),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (active)
                                      Text(
                                        'Current',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF67E8F9),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
  );
  if (selection != null && selection != currentRoute) {
    onRouteChanged(selection);
  }
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
  final String operatorLabel;
  final String operatorRoleLabel;
  final String operatorShiftLabel;
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
    this.operatorLabel = '',
    this.operatorRoleLabel = '',
    this.operatorShiftLabel = '',
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

  Widget _wrapShellShortcuts({
    required BuildContext context,
    required Widget child,
  }) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
            _showAppShellQuickJumpDialog(
              context: context,
              currentRoute: widget.currentRoute,
              onRouteChanged: widget.onRouteChanged,
            ),
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
            _showAppShellQuickJumpDialog(
              context: context,
              currentRoute: widget.currentRoute,
              onRouteChanged: widget.onRouteChanged,
            ),
      },
      child: Focus(autofocus: true, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final handsetLayout = isHandsetLayout(context);
        final mobileLayout = constraints.maxWidth < 980 || handsetLayout;
        if (mobileLayout) {
          return _wrapShellShortcuts(
            context: context,
            child: Scaffold(
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
            ),
          );
        }

        const sidebarWidth = 228.0;
        return _wrapShellShortcuts(
          context: context,
          child: Scaffold(
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
                          operatorLabel: widget.operatorLabel,
                          operatorRoleLabel: widget.operatorRoleLabel,
                          operatorShiftLabel: widget.operatorShiftLabel,
                          onRouteChanged: widget.onRouteChanged,
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
                        if (widget.intelTickerItems.isNotEmpty &&
                            widget.currentRoute != OnyxRoute.dashboard)
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
  final String operatorLabel;
  final String operatorRoleLabel;
  final String operatorShiftLabel;
  final ValueChanged<OnyxRoute> onRouteChanged;
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
    required this.operatorLabel,
    required this.operatorRoleLabel,
    required this.operatorShiftLabel,
    required this.onRouteChanged,
    this.demoAutopilotStatusLabel = '',
    this.onStopDemoAutopilot,
    this.onSkipDemoAutopilot,
    this.onToggleDemoAutopilotPause,
    this.demoAutopilotPaused = false,
    required this.sidebarOpen,
    required this.onToggleSidebar,
  });

  String _routeLabel() => _appShellRouteLabel(currentRoute);
  String _headerLabel() => _appShellHeaderLabel(currentRoute);

  String _timeLabel() {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0D14),
        border: Border(bottom: BorderSide(color: Color(0x22FFFFFF))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showAutopilot = demoAutopilotStatusLabel.trim().isNotEmpty;
          final showOperatorChip =
              constraints.maxWidth >= (showAutopilot ? 1640 : 1180);
          final showExtendedAutopilotControls = constraints.maxWidth >= 1460;
          final showCompactAutopilotControls =
              showAutopilot && !showExtendedAutopilotControls;
          final showQuickJump =
              constraints.maxWidth >= (showAutopilot ? 1560 : 1360);
          final showClockText = constraints.maxWidth >= 1180;
          final autopilotChipWidth = showExtendedAutopilotControls
              ? 272.0
              : constraints.maxWidth >= 1280
              ? 208.0
              : 160.0;
          final quickJumpWidth = constraints.maxWidth >= 1540
              ? 340.0
              : constraints.maxWidth >= 1320
              ? 288.0
              : 224.0;

          return Row(
            children: [
              IconButton(
                onPressed: onToggleSidebar,
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF111823),
                  side: const BorderSide(color: Color(0xFF233244)),
                ),
                icon: Icon(
                  sidebarOpen ? Icons.close_rounded : Icons.menu_rounded,
                  size: 18,
                  color: const Color(0xFFD3E3F8),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _headerLabel(),
                style: GoogleFonts.rajdhani(
                  color: const Color(0xFFF4F7FC),
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(width: 18),
              if (showQuickJump) ...[
                SizedBox(
                  width: quickJumpWidth,
                  child: _QuickJumpField(
                    onOpen: () => _showQuickJumpDialog(context),
                  ),
                ),
                const SizedBox(width: 14),
              ] else ...[
                _TopBarActionIcon(
                  buttonKey: const ValueKey('app-shell-quick-jump-icon'),
                  onPressed: () => _showQuickJumpDialog(context),
                  icon: Icons.search_rounded,
                  foregroundColor: const Color(0xFFBFDBFE),
                  borderColor: const Color(0xFF35506F),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    _routeLabel(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF7F93AF),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              const Spacer(),
              if (showAutopilot) ...[
                SizedBox(
                  width: autopilotChipWidth,
                  child: _AutopilotChip(label: demoAutopilotStatusLabel),
                ),
                if (onStopDemoAutopilot != null) ...[
                  const SizedBox(width: 5),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        foregroundColor: const Color(0xFFFCA5A5),
                        side: const BorderSide(color: Color(0xFF7F1D1D)),
                        textStyle: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: const Text('Stop'),
                    ),
                ],
                if (showExtendedAutopilotControls &&
                    onToggleDemoAutopilotPause != null) ...[
                  const SizedBox(width: 5),
                  OutlinedButton(
                    onPressed: onToggleDemoAutopilotPause,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(66, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      foregroundColor: const Color(0xFFBFDBFE),
                      side: const BorderSide(color: Color(0xFF35506F)),
                      textStyle: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: Text(demoAutopilotPaused ? 'Resume' : 'Pause'),
                  ),
                ],
                if (showExtendedAutopilotControls &&
                    onSkipDemoAutopilot != null) ...[
                  const SizedBox(width: 5),
                  OutlinedButton(
                    onPressed: onSkipDemoAutopilot,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(56, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      foregroundColor: const Color(0xFF93C5FD),
                      side: const BorderSide(color: Color(0xFF35506F)),
                      textStyle: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: const Text('Next'),
                  ),
                ],
                if (showCompactAutopilotControls &&
                    onToggleDemoAutopilotPause != null) ...[
                  const SizedBox(width: 5),
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
                  const SizedBox(width: 5),
                  _TopBarActionIcon(
                    onPressed: onSkipDemoAutopilot!,
                    icon: Icons.skip_next_rounded,
                    foregroundColor: const Color(0xFF93C5FD),
                    borderColor: const Color(0xFF35506F),
                  ),
                ],
                const SizedBox(width: 12),
              ],
              if (showOperatorChip && operatorLabel.trim().isNotEmpty) ...[
                _OperatorSessionChip(
                  operatorLabel: operatorLabel,
                  roleLabel: operatorRoleLabel,
                  shiftLabel: operatorShiftLabel,
                ),
                const SizedBox(width: 12),
              ],
              _TopChip(
                label: 'SYSTEMS NOMINAL',
                foreground: const Color(0xFF34D399),
                background: const Color(0x1221A86B),
                border: const Color(0x4034D399),
              ),
              const SizedBox(width: 10),
              _TopBarActionIcon(
                buttonKey: const ValueKey('app-shell-status-button'),
                onPressed: () => _showShellStatusSnack(context),
                icon: Icons.notifications_none_rounded,
                foregroundColor: const Color(0xFFE4ECF8),
                borderColor: const Color(0xFF273446),
                showAlertDot: activeIncidentCount > 0 || aiActionCount > 0,
              ),
              if (showClockText) ...[
                const SizedBox(width: 14),
                Text(
                  _timeLabel(),
                  style: GoogleFonts.robotoMono(
                    color: const Color(0xFFD7E6FA),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _showShellStatusSnack(BuildContext context) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          'Systems nominal. ${activeIncidentCount.toString()} active incidents, $aiActionCount AI actions, $guardsOnlineCount guards online.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showQuickJumpDialog(BuildContext context) {
    return _showAppShellQuickJumpDialog(
      context: context,
      currentRoute: currentRoute,
      onRouteChanged: onRouteChanged,
    );
  }
}

class _QuickJumpField extends StatelessWidget {
  final VoidCallback onOpen;

  const _QuickJumpField({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0A0F17),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: const ValueKey('app-shell-quick-jump-field'),
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF233244)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    size: 16,
                    color: Color(0xFF7D93B3),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Quick jump... (⌘K)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: const Color(0x7AAFC0D9),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
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
            label: 'Command',
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
            label: 'Tactical',
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
            label: 'Governance',
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
            label: 'OB Log',
            icon: Icons.menu_book_rounded,
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
            label: 'Admin',
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
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0x22FFFFFF))),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    color: const Color(0xFF2563EB),
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: Color(0xFFFFFFFF),
                    size: 14,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ONYX',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFE7F0FF),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      Text(
                        'Sovereign Platform',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF8CA6CC),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(8, 7, 8, 5),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xFF0E1A2B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x22FFFFFF)),
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _sidebarStatusPill(
                  label: 'LIVE',
                  color: const Color(0xFF10B981),
                ),
                _sidebarStatusPill(
                  label: '$aiActionCount ACTIVE',
                  color: const Color(0xFF22D3EE),
                ),
                _sidebarStatusPill(
                  label: '$guardsOnlineCount On Shift',
                  color: const Color(0xFFDBEAFE),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
              children: [
                for (final section in navSections) ...[
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 6,
                      right: 6,
                      bottom: 5,
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
                  const SizedBox(height: 6),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarStatusPill({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
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
              size: 15,
              color: isActive
                  ? const Color(0xFF22D3EE)
                  : const Color(0x99FFFFFF),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: isActive
                      ? const Color(0xFFE6F2FF)
                      : const Color(0xB3FFFFFF),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
                    fontSize: 9.5,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _TopBarActionIcon extends StatelessWidget {
  final Key? buttonKey;
  final VoidCallback onPressed;
  final IconData icon;
  final Color foregroundColor;
  final Color borderColor;
  final bool showAlertDot;

  const _TopBarActionIcon({
    this.buttonKey,
    required this.onPressed,
    required this.icon,
    required this.foregroundColor,
    required this.borderColor,
    this.showAlertDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      key: buttonKey,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(38, 38),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        foregroundColor: foregroundColor,
        side: BorderSide(color: borderColor),
        backgroundColor: const Color(0xFF111823),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, size: 16),
          if (showAlertDot)
            const Positioned(
              top: -2,
              right: -4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
                child: SizedBox(width: 8, height: 8),
              ),
            ),
        ],
      ),
    );
  }
}

class _OperatorSessionChip extends StatelessWidget {
  final String operatorLabel;
  final String roleLabel;
  final String shiftLabel;

  const _OperatorSessionChip({
    required this.operatorLabel,
    required this.roleLabel,
    required this.shiftLabel,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedOperator = operatorLabel.trim();
    final normalizedRole = roleLabel.trim();
    final normalizedShift = shiftLabel.trim();
    final hasSessionDetail =
        normalizedRole.isNotEmpty || normalizedShift.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF121923),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF273446)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFB16EFF),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            normalizedOperator,
            style: GoogleFonts.inter(
              color: const Color(0xFFE9F0FA),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (!hasSessionDetail) ...[
            const SizedBox(width: 10),
            _OperatorSessionSeparator(),
            const SizedBox(width: 10),
            Text(
              'OPERATOR',
              style: GoogleFonts.inter(
                color: const Color(0xFF8FA8CA),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (normalizedRole.isNotEmpty) ...[
            const SizedBox(width: 10),
            _OperatorSessionSeparator(),
            const SizedBox(width: 10),
            Text(
              normalizedRole.toUpperCase(),
              style: GoogleFonts.inter(
                color: const Color(0xFFC889FF),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (normalizedShift.isNotEmpty) ...[
            const SizedBox(width: 10),
            _OperatorSessionSeparator(),
            const SizedBox(width: 10),
            Text(
              'Shift: $normalizedShift',
              style: GoogleFonts.inter(
                color: const Color(0xFFBCC8D9),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OperatorSessionSeparator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      '•',
      style: GoogleFonts.inter(
        color: const Color(0xFF69798F),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _AutopilotChip extends StatelessWidget {
  final String label;

  const _AutopilotChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x332563EB),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0x664C6FFF)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_mode_rounded,
            size: 11,
            color: Color(0xFF93C5FD),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: const Color(0xFFBFDBFE),
                fontSize: 9.5,
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
        height: 58,
        padding: const EdgeInsets.fromLTRB(7, 4, 7, 4),
        decoration: const BoxDecoration(
          color: _tickerBackground,
          border: Border(bottom: BorderSide(color: Color(0x1FFFFFFF))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 20,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: availableFilters.length,
                separatorBuilder: (_, _) => const SizedBox(width: 5),
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
            const SizedBox(height: 3),
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
                                horizontal: 7,
                                vertical: 5,
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
                                        fontSize: 10.5,
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
