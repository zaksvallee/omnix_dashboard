import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import '../domain/authority/onyx_route.dart';

export '../domain/authority/onyx_route.dart';

import 'layout_breakpoints.dart';
import 'theme/onyx_design_tokens.dart';

const _appShellBackgroundColor = OnyxDesignTokens.backgroundPrimary;
const _appShellSurfaceColor = OnyxDesignTokens.cardSurface;
const _appShellAltSurfaceColor = OnyxDesignTokens.backgroundSecondary;
const _appShellBorderColor = OnyxDesignTokens.borderSubtle;
const _appShellTitleColor = OnyxDesignTokens.textPrimary;
const _appShellBodyColor = OnyxDesignTokens.textSecondary;
const _appShellMutedColor = OnyxDesignTokens.textMuted;
const _appShellAccentSky = OnyxDesignTokens.accentSky;
const _appShellAccentBlue = OnyxDesignTokens.accentBlue;

TextStyle _appShellTextStyle({
  Color? color,
  double? fontSize,
  FontWeight? fontWeight,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: OnyxDesignTokens.fontFamily,
    color: color,
    fontSize: fontSize,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
  );
}

Future<void> _showAppShellQuickJumpDialog({
  required BuildContext context,
  required OnyxRoute currentRoute,
  required ValueChanged<OnyxRoute> onRouteChanged,
}) async {
  final routes = OnyxRouteSection.values
      .expand((section) => section.routes)
      .map((route) => (route: route, label: route.label))
      .toList(growable: false);
  final queryNotifier = ValueNotifier<String>('');
  OnyxRoute? selection;
  try {
    selection = await showDialog<OnyxRoute>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: _appShellSurfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: _appShellBorderColor),
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
                        style: _appShellTextStyle(
                          color: _appShellTitleColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const ValueKey('app-shell-quick-jump-input'),
                        autofocus: true,
                        onChanged: (value) => queryNotifier.value = value,
                        style: _appShellTextStyle(
                          color: _appShellTitleColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search routes',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: _appShellMutedColor,
                          ),
                          filled: true,
                          fillColor: _appShellAltSurfaceColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _appShellBorderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _appShellBorderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _appShellAccentBlue),
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
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final entry = filtered[index];
                              final active = entry.route == currentRoute;
                              return InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => Navigator.of(
                                  dialogContext,
                                ).pop(entry.route),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: active
                                        ? OnyxDesignTokens.cyanSurface
                                        : _appShellAltSurfaceColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: active
                                          ? OnyxDesignTokens.cyanBorder
                                          : _appShellBorderColor,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          entry.label,
                                          style: _appShellTextStyle(
                                            color: _appShellTitleColor,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (active)
                                        Text(
                                          'Current',
                                          style: _appShellTextStyle(
                                            color: _appShellAccentBlue,
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
  } finally {
    queryNotifier.dispose();
  }
  if (context.mounted && selection != null && selection != currentRoute) {
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
              backgroundColor: _appShellBackgroundColor,
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
                    decoration: const BoxDecoration(
                      color: _appShellBackgroundColor,
                    ),
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
                          color: _appShellSurfaceColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(
                              color: _appShellBorderColor,
                            ),
                          ),
                          child: InkWell(
                            onTap: () => Scaffold.of(innerContext).openDrawer(),
                            borderRadius: BorderRadius.circular(10),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.menu_rounded,
                                size: 20,
                                color: _appShellAccentBlue,
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
            backgroundColor: _appShellBackgroundColor,
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
                    decoration: const BoxDecoration(
                      color: _appShellBackgroundColor,
                    ),
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
                            widget.currentRoute.showsShellIntelTicker)
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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: _appShellSurfaceColor,
        border: Border(bottom: BorderSide(color: _appShellBorderColor)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showAutopilot = demoAutopilotStatusLabel.trim().isNotEmpty;
          final showOperatorChip =
              constraints.maxWidth >= (showAutopilot ? 1600 : 1320);
          final showExtendedAutopilotControls = constraints.maxWidth >= 1440;
          final showCompactAutopilotControls =
              showAutopilot && !showExtendedAutopilotControls;
          final autopilotChipWidth = showExtendedAutopilotControls
              ? 248.0
              : constraints.maxWidth >= 1280
              ? 196.0
              : 160.0;

          return Row(
            children: [
              IconButton(
                onPressed: onToggleSidebar,
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  backgroundColor: _appShellAltSurfaceColor,
                  side: const BorderSide(color: _appShellBorderColor),
                ),
                icon: Icon(
                  sidebarOpen ? Icons.close_rounded : Icons.menu_rounded,
                  size: 18,
                  color: _appShellAccentBlue,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                currentRoute.shellHeaderLabel,
                style: _appShellTextStyle(
                  color: _appShellTitleColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  currentRoute.autopilotNarration,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _appShellTextStyle(
                    color: _appShellBodyColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _TopBarActionIcon(
                buttonKey: const ValueKey('app-shell-quick-jump-icon'),
                onPressed: () => _showQuickJumpDialog(context),
                icon: Icons.search_rounded,
                foregroundColor: _appShellAccentSky,
                borderColor: OnyxDesignTokens.borderStrong,
              ),
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
                      foregroundColor: OnyxDesignTokens.redCritical,
                      borderColor: OnyxDesignTokens.redBorder,
                    )
                  else
                    OutlinedButton(
                      onPressed: onStopDemoAutopilot,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(56, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        foregroundColor: OnyxDesignTokens.redCritical,
                        side: const BorderSide(color: OnyxDesignTokens.redBorder),
                        textStyle: _appShellTextStyle(
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
                      foregroundColor: _appShellAccentSky,
                      side: const BorderSide(color: OnyxDesignTokens.borderStrong),
                      textStyle: _appShellTextStyle(
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
                      foregroundColor: _appShellAccentSky,
                      side: const BorderSide(color: OnyxDesignTokens.borderStrong),
                      textStyle: _appShellTextStyle(
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
                    foregroundColor: _appShellAccentSky,
                    borderColor: OnyxDesignTokens.borderStrong,
                  ),
                ],
                if (showCompactAutopilotControls &&
                    onSkipDemoAutopilot != null) ...[
                  const SizedBox(width: 5),
                  _TopBarActionIcon(
                    onPressed: onSkipDemoAutopilot!,
                    icon: Icons.skip_next_rounded,
                    foregroundColor: _appShellAccentSky,
                    borderColor: OnyxDesignTokens.borderStrong,
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
                label: 'READY',
                foreground: OnyxDesignTokens.greenNominal,
                background: OnyxDesignTokens.greenSurface,
                border: OnyxDesignTokens.greenBorder,
              ),
              const SizedBox(width: 10),
              _TopBarActionIcon(
                buttonKey: const ValueKey('app-shell-status-button'),
                onPressed: () => _showShellStatusSnack(context),
                icon: Icons.notifications_none_rounded,
                foregroundColor: OnyxDesignTokens.textPrimary,
                borderColor: OnyxDesignTokens.borderStrong,
                showAlertDot: activeIncidentCount > 0 || aiActionCount > 0,
              ),
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
        backgroundColor: _appShellSurfaceColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _appShellBorderColor),
        ),
        content: Text(
          'Ready. ${activeIncidentCount.toString()} live incidents, $aiActionCount AI moves, $guardsOnlineCount guards on floor.',
          style: _appShellTextStyle(
            color: _appShellTitleColor,
            fontWeight: FontWeight.w700,
          ),
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

  int? _badgeForRoute(OnyxRoute route) {
    final kind = route.shellBadgeKind;
    if (kind == null) {
      return null;
    }

    return switch (kind) {
      OnyxRouteShellBadgeKind.activeIncidents =>
        activeIncidentCount > 0 ? activeIncidentCount : null,
      OnyxRouteShellBadgeKind.aiActions =>
        aiActionCount > 0 ? aiActionCount : null,
      OnyxRouteShellBadgeKind.tacticalSosAlerts =>
        tacticalSosAlerts > 0 ? tacticalSosAlerts : null,
      OnyxRouteShellBadgeKind.complianceIssues =>
        complianceIssuesCount > 0 ? complianceIssuesCount : null,
    };
  }

  _NavItemModel _navItemForRoute(OnyxRoute route) {
    return _NavItemModel(
      label: route.label,
      icon: route.icon,
      route: route,
      badge: _badgeForRoute(route),
      badgeColor: route.shellBadgeColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final navSections = OnyxRouteSection.values
        .map(
          (section) => _NavSection(
            title: section.title,
            items: section.routes.map(_navItemForRoute).toList(growable: false),
          ),
        )
        .toList(growable: false);

    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: _appShellSurfaceColor,
        border: Border(right: BorderSide(color: _appShellBorderColor)),
      ),
      child: Column(
        children: [
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _appShellBorderColor)),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    color: _appShellAccentBlue,
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: _appShellTitleColor,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'ONYX',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _appShellTextStyle(
                      color: _appShellTitleColor,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
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
                      style: _appShellTextStyle(
                        color: _appShellMutedColor,
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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isActive
              ? _appShellAccentBlue.withValues(alpha: 0.10)
              : Colors.transparent,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              if (isActive)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 3, color: _appShellAccentBlue),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 15,
                      color: isActive ? _appShellAccentBlue : _appShellMutedColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _appShellTextStyle(
                          color: isActive ? _appShellTitleColor : _appShellBodyColor,
                          fontSize: 12,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
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
                          style: _appShellTextStyle(
                            color: badgeColor ?? _appShellAccentSky,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
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
        style: _appShellTextStyle(
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
        side: BorderSide(color: borderColor.withValues(alpha: 0.52)),
        backgroundColor: OnyxDesignTokens.cardSurface,
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
                  color: OnyxDesignTokens.redCritical,
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

class _OperatorSessionChip extends StatefulWidget {
  final String operatorLabel;
  final String roleLabel;
  final String shiftLabel;

  const _OperatorSessionChip({
    required this.operatorLabel,
    required this.roleLabel,
    required this.shiftLabel,
  });

  @override
  State<_OperatorSessionChip> createState() => _OperatorSessionChipState();
}

class _OperatorSessionChipState extends State<_OperatorSessionChip> {
  static final _appLaunchTime = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatElapsed(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }

  Color _sessionDotColour(Duration d) {
    if (d.inHours < 8) return const Color(0xFF2ECC71);
    if (d.inHours < 12) return const Color(0xFFEF9F27);
    return const Color(0xFFE24B4A);
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(_appLaunchTime);
    final normalizedOperator = widget.operatorLabel.trim();
    final normalizedRole = widget.roleLabel.trim();
    final normalizedShift = widget.shiftLabel.trim();
    final hasSessionDetail =
        normalizedRole.isNotEmpty || normalizedShift.isNotEmpty;
    final dotColour = _sessionDotColour(elapsed);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _appShellAltSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _appShellBorderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColour, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(
            normalizedOperator.isEmpty ? 'OPERATOR-01' : normalizedOperator,
            style: _appShellTextStyle(
              color: _appShellTitleColor,
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
              style: _appShellTextStyle(
                color: _appShellMutedColor,
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
              style: _appShellTextStyle(
                color: _appShellAccentBlue,
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
              style: _appShellTextStyle(
                color: _appShellMutedColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(width: 10),
          _OperatorSessionSeparator(),
          const SizedBox(width: 10),
          Text(
            _formatElapsed(elapsed),
            style: _appShellTextStyle(
              color: _appShellMutedColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
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
      style: _appShellTextStyle(
        color: _appShellMutedColor,
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
        color: OnyxDesignTokens.cyanSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: OnyxDesignTokens.cyanBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_mode_rounded,
            size: 11,
            color: _appShellAccentBlue,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _appShellTextStyle(
                color: _appShellAccentBlue,
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
      color: OnyxDesignTokens.cardSurface.withValues(alpha: 0.97),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _appShellBorderColor),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.auto_mode_rounded,
              size: 14,
              color: _appShellAccentBlue,
            ),
            const SizedBox(width: 6),
            Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _appShellTextStyle(
                color: _appShellAccentBlue,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (togglePauseAction != null)
              _mobileActionIcon(
                onTap: togglePauseAction,
                icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                color: _appShellAccentSky,
              ),
            if (skipAction != null)
              _mobileActionIcon(
                onTap: skipAction,
                icon: Icons.skip_next_rounded,
                color: _appShellAccentSky,
              ),
            if (stopAction != null)
              _mobileActionIcon(
                onTap: stopAction,
                icon: Icons.stop_circle_outlined,
                color: OnyxDesignTokens.redCritical,
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
  static const _userInteractionResetTimeout = Duration(seconds: 5);
  static const _tickerBackground = OnyxDesignTokens.backgroundSecondary;
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
  Timer? _userInteractionResetTimer;
  bool _hovering = false;
  bool _userInteracting = false;
  String _sourceFilter = 'all';

  @override
  void initState() {
    super.initState();
    _reconcileSourceFilter();
    _syncAutoScrollState();
  }

  @override
  void didUpdateWidget(covariant _ShellIntelTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final itemsChanged =
        oldWidget.items.length != widget.items.length ||
        oldWidget.items != widget.items;
    final filterChanged = _reconcileSourceFilter();
    if (itemsChanged || filterChanged) {
      _syncAutoScrollState();
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _userInteractionResetTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  bool _reconcileSourceFilter() {
    final activeFilter = _resolvedActiveFilter();
    if (activeFilter == _sourceFilter) {
      return false;
    }
    _sourceFilter = activeFilter;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    return true;
  }

  String _resolvedActiveFilter() {
    final availableFilters = _availableFilters(_sourceCounts());
    if (availableFilters.contains(_sourceFilter)) {
      return _sourceFilter;
    }
    return 'all';
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

  void _markUserInteracting() {
    _userInteracting = true;
    _userInteractionResetTimer?.cancel();
    _userInteractionResetTimer = Timer(_userInteractionResetTimeout, () {
      _userInteracting = false;
    });
  }

  void _clearUserInteraction() {
    _userInteractionResetTimer?.cancel();
    _userInteractionResetTimer = null;
    _userInteracting = false;
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
    // Section 4: hide ticker entirely when any item contains broken placeholder text
    const brokenPhrases = [
      'missing key',
      'placeholder',
      'replace the placeholder',
    ];
    final hasBrokenItems = widget.items.any((item) {
      final lower = item.headline.toLowerCase();
      return brokenPhrases.any(lower.contains);
    });
    if (hasBrokenItems) return const SizedBox.shrink();

    final sourceCounts = _sourceCounts();
    final availableFilters = _availableFilters(sourceCounts);
    final activeFilter = _resolvedActiveFilter();
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
          border: Border(bottom: BorderSide(color: _appShellBorderColor)),
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
                        style: _appShellTextStyle(
                          color: _appShellMutedColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    NotificationListener<UserScrollNotification>(
                      onNotification: (notification) {
                        if (notification.direction == ScrollDirection.idle) {
                          _clearUserInteraction();
                        } else {
                          _markUserInteracting();
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
                                color: OnyxDesignTokens.glassSurface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: OnyxDesignTokens.glassBorder,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$source • $provider • $hh:$mm',
                                    style: _appShellTextStyle(
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
                                      style: _appShellTextStyle(
                                        color: _appShellTitleColor,
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
                            colors: [_tickerBackground, Colors.transparent],
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
                            colors: [Colors.transparent, _tickerBackground],
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
        ? _appShellAccentSky
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
              ? OnyxDesignTokens.glassSurface
              : OnyxDesignTokens.cardSurface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? OnyxDesignTokens.glassHighlight
                : _appShellBorderColor,
          ),
        ),
        child: Text(
          '${_sourceLabel(source)} • $count',
          style: _appShellTextStyle(
            color: selected
                ? color
                : Color.lerp(_appShellBodyColor, color, 0.2),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Color _tickerColor(String sourceType) {
    final source = _normalizeSource(sourceType);
    if (source == 'radio') {
      return OnyxDesignTokens.cyanInteractive;
    }
    if (source == 'news') {
      return _appShellAccentSky;
    }
    if (source == 'wearable') {
      return OnyxDesignTokens.greenNominal;
    }
    if (source == 'hardware') {
      return OnyxDesignTokens.cyanInteractive;
    }
    if (source == 'dvr') {
      return OnyxDesignTokens.redCritical;
    }
    if (source == 'community') {
      return _appShellAccentBlue;
    }
    if (source == 'system') {
      return _appShellAccentSky;
    }
    return OnyxDesignTokens.purpleAdmin;
  }
}
