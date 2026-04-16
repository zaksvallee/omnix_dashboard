import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import '../application/system_flow_service.dart';
import '../domain/authority/onyx_route.dart';
import 'components/onyx_incident_lifecycle_view.dart';
import 'components/onyx_system_flow_widgets.dart';

export '../domain/authority/onyx_route.dart';

import 'layout_breakpoints.dart';
import 'organization_page.dart';
import 'theme/onyx_design_tokens.dart';

const _appShellBackgroundColor = OnyxDesignTokens.backgroundPrimary;
const _appShellSurfaceColor = OnyxDesignTokens.cardSurface;
const _appShellAltSurfaceColor = OnyxDesignTokens.backgroundSecondary;
const _appShellBorderColor = OnyxDesignTokens.borderSubtle;
const _appShellTitleColor = OnyxDesignTokens.textPrimary;
const _appShellBodyColor = OnyxDesignTokens.textSecondary;
const _appShellMutedColor = OnyxDesignTokens.textMuted;
const _appShellAccentSky = OnyxDesignTokens.accentSky;

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
                            borderSide: const BorderSide(
                              color: _appShellBorderColor,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: _appShellBorderColor,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: OnyxColorTokens.brand,
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
                                            color: OnyxColorTokens.brand,
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
  final int elevatedRiskCount;
  final int liveAlarmCount;
  final List<OnyxIntelTickerItem> intelTickerItems;
  final OnyxIncidentLifecycleSnapshot incidentLifecycleSnapshot;
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
    this.elevatedRiskCount = 0,
    this.liveAlarmCount = 0,
    this.intelTickerItems = const [],
    this.incidentLifecycleSnapshot = const OnyxIncidentLifecycleSnapshot(
      incidentReference: 'INC-STANDBY',
      summary:
          'No active lifecycle in focus. Awaiting the next verified incident.',
      active: false,
      entries: <OnyxIncidentLifecycleEntry>[],
    ),
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
                  elevatedRiskCount: widget.elevatedRiskCount,
                  liveAlarmCount: widget.liveAlarmCount,
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
                            side: const BorderSide(color: _appShellBorderColor),
                          ),
                          child: InkWell(
                            onTap: () => Scaffold.of(innerContext).openDrawer(),
                            borderRadius: BorderRadius.circular(10),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.menu_rounded,
                                size: 20,
                                color: OnyxColorTokens.brand,
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

        return _wrapShellShortcuts(
          context: context,
          child: Scaffold(
            backgroundColor: _appShellBackgroundColor,
            body: Row(
              children: [
                _Sidebar(
                  width: OnyxSpacingTokens.navRailWidth,
                  iconOnly: true,
                  currentRoute: widget.currentRoute,
                  activeIncidentCount: widget.activeIncidentCount,
                  aiActionCount: widget.aiActionCount,
                  complianceIssuesCount: widget.complianceIssuesCount,
                  tacticalSosAlerts: widget.tacticalSosAlerts,
                  elevatedRiskCount: widget.elevatedRiskCount,
                  liveAlarmCount: widget.liveAlarmCount,
                  guardsOnlineCount: widget.guardsOnlineCount,
                  operatorLabel: widget.operatorLabel,
                  onRouteChanged: widget.onRouteChanged,
                ),
                Expanded(
                  child: Container(
                    color: _appShellBackgroundColor,
                    child: Column(
                      children: [
                        _ShellTopBar(
                          currentRoute: widget.currentRoute,
                          activeIncidentCount: widget.activeIncidentCount,
                          aiActionCount: widget.aiActionCount,
                          guardsOnlineCount: widget.guardsOnlineCount,
                          complianceIssuesCount: widget.complianceIssuesCount,
                          tacticalSosAlerts: widget.tacticalSosAlerts,
                          elevatedRiskCount: widget.elevatedRiskCount,
                          liveAlarmCount: widget.liveAlarmCount,
                          operatorLabel: widget.operatorLabel,
                          operatorRoleLabel: widget.operatorRoleLabel,
                          operatorShiftLabel: widget.operatorShiftLabel,
                          onRouteChanged: widget.onRouteChanged,
                          incidentLifecycleSnapshot:
                              widget.incidentLifecycleSnapshot,
                          demoAutopilotStatusLabel:
                              widget.demoAutopilotStatusLabel,
                          onStopDemoAutopilot: widget.onStopDemoAutopilot,
                          onSkipDemoAutopilot: widget.onSkipDemoAutopilot,
                          onToggleDemoAutopilotPause:
                              widget.onToggleDemoAutopilotPause,
                          demoAutopilotPaused: widget.demoAutopilotPaused,
                        ),
                        _StatusBanner(
                          activeIncidentCount: widget.activeIncidentCount,
                          aiActionCount: widget.aiActionCount,
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
  final int complianceIssuesCount;
  final int tacticalSosAlerts;
  final int elevatedRiskCount;
  final int liveAlarmCount;
  final String operatorLabel;
  final String operatorRoleLabel;
  final String operatorShiftLabel;
  final ValueChanged<OnyxRoute> onRouteChanged;
  final OnyxIncidentLifecycleSnapshot incidentLifecycleSnapshot;
  final String demoAutopilotStatusLabel;
  final VoidCallback? onStopDemoAutopilot;
  final VoidCallback? onSkipDemoAutopilot;
  final VoidCallback? onToggleDemoAutopilotPause;
  final bool demoAutopilotPaused;

  const _ShellTopBar({
    required this.currentRoute,
    required this.activeIncidentCount,
    required this.aiActionCount,
    required this.guardsOnlineCount,
    required this.complianceIssuesCount,
    required this.tacticalSosAlerts,
    required this.elevatedRiskCount,
    required this.liveAlarmCount,
    required this.operatorLabel,
    required this.operatorRoleLabel,
    required this.operatorShiftLabel,
    required this.onRouteChanged,
    required this.incidentLifecycleSnapshot,
    this.demoAutopilotStatusLabel = '',
    this.onStopDemoAutopilot,
    this.onSkipDemoAutopilot,
    this.onToggleDemoAutopilotPause,
    this.demoAutopilotPaused = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: OnyxSpacingTokens.topBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        border: Border(bottom: BorderSide(color: OnyxColorTokens.divider)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showAutopilot = demoAutopilotStatusLabel.trim().isNotEmpty;
          final showExtendedAutopilotControls = constraints.maxWidth >= 1440;
          final showCompactAutopilotControls =
              showAutopilot && !showExtendedAutopilotControls;
          final autopilotChipWidth = showExtendedAutopilotControls
              ? 248.0
              : constraints.maxWidth >= 1280
              ? 196.0
              : 160.0;
          final totalAlerts = activeIncidentCount + aiActionCount;
          final systemSnapshot = OnyxSystemStateService.deriveSnapshot(
            activeIncidentCount: activeIncidentCount,
            aiActionCount: aiActionCount,
            guardsOnlineCount: guardsOnlineCount,
            complianceIssuesCount: complianceIssuesCount,
            tacticalSosAlerts: tacticalSosAlerts,
            elevatedRiskCount: elevatedRiskCount,
            liveAlarmCount: liveAlarmCount,
          );
          final systemState = systemSnapshot.state;
          final shellFlow = OnyxFlowIndicatorService.shellFlow(
            snapshot: systemSnapshot,
            incidentReference: incidentLifecycleSnapshot.incidentReference,
          );
          final compactSystemState = constraints.maxWidth < 1500;
          final showFlowBreadcrumb = constraints.maxWidth >= 1760;
          final compactLifecycleButton = constraints.maxWidth < 1320;

          // Dynamic status chip
          final Color statusFg;
          final Color statusBg;
          final Color statusBorder;
          final String statusLabel;
          if (activeIncidentCount > 0) {
            statusFg = OnyxDesignTokens.redCritical;
            statusBg = OnyxDesignTokens.redSurface;
            statusBorder = OnyxDesignTokens.redBorder;
            statusLabel = 'ALARM';
          } else if (aiActionCount > 0) {
            statusFg = OnyxDesignTokens.amberWarning;
            statusBg = OnyxDesignTokens.amberSurface;
            statusBorder = OnyxDesignTokens.amberBorder;
            statusLabel = 'ALERT';
          } else {
            statusFg = OnyxDesignTokens.greenNominal;
            statusBg = OnyxDesignTokens.cardSurface;
            statusBorder = OnyxDesignTokens.borderSubtle;
            statusLabel = 'READY';
          }

          return Row(
            children: [
              // Logo mark
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: OnyxColorTokens.brand,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: Colors.white,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              // Page name
              Text(
                currentRoute.shellHeaderLabel,
                style: _appShellTextStyle(
                  color: _appShellTitleColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OnyxGlobalSystemStateChip(
                    state: systemState,
                    detail: OnyxSystemStateService.detailFor(systemSnapshot),
                    compact: compactSystemState,
                  ),
                ),
              ),
              if (showFlowBreadcrumb) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: 360,
                  child: OnyxFlowBreadcrumb(
                    flow: shellFlow,
                    compact: true,
                    showTitle: false,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              // Quick search field
              GestureDetector(
                onTap: () => _showQuickJumpDialog(context),
                child: Container(
                  width: 300,
                  height: 34,
                  decoration: BoxDecoration(
                    color: OnyxColorTokens.backgroundPrimary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: OnyxColorTokens.borderSubtle),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        size: 13,
                        color: _appShellMutedColor,
                      ),
                      const SizedBox(width: 7),
                      const Expanded(
                        child: Text(
                          'Quick jump',
                          style: TextStyle(
                            fontFamily: OnyxDesignTokens.fontFamily,
                            color: _appShellMutedColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Text(
                        '⌘K',
                        style: TextStyle(
                          fontFamily: OnyxDesignTokens.fontFamily,
                          color: _appShellMutedColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (compactLifecycleButton)
                _TopBarActionIcon(
                  onPressed: () => showOnyxIncidentLifecycleDialog(
                    context: context,
                    snapshot: incidentLifecycleSnapshot,
                  ),
                  icon: Icons.timeline_rounded,
                  foregroundColor: OnyxColorTokens.accentPurple,
                  borderColor: OnyxColorTokens.accentPurple.withValues(
                    alpha: 0.20,
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => showOnyxIncidentLifecycleDialog(
                    context: context,
                    snapshot: incidentLifecycleSnapshot,
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    foregroundColor: OnyxColorTokens.accentPurple,
                    side: BorderSide(
                      color: OnyxColorTokens.accentPurple.withValues(
                        alpha: 0.20,
                      ),
                    ),
                    textStyle: _appShellTextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  icon: const Icon(Icons.timeline_rounded, size: 14),
                  label: const Text('Lifecycle'),
                ),
              const Spacer(),
              // Autopilot controls
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
                        side: const BorderSide(
                          color: OnyxDesignTokens.redBorder,
                        ),
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
                      side: const BorderSide(
                        color: OnyxDesignTokens.borderStrong,
                      ),
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
                      side: const BorderSide(
                        color: OnyxDesignTokens.borderStrong,
                      ),
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
                const SizedBox(width: 10),
              ],
              // Operator chip
              if (operatorLabel.trim().isNotEmpty) ...[
                _OperatorSessionChip(
                  operatorLabel: operatorLabel,
                  roleLabel: operatorRoleLabel,
                  shiftLabel: operatorShiftLabel,
                ),
                const SizedBox(width: 8),
              ],
              // Dynamic status chip
              _TopChip(
                label: statusLabel,
                foreground: statusFg,
                background: statusBg,
                border: statusBorder,
              ),
              const SizedBox(width: 8),
              // Notification bell with count badge
              _NotificationBell(
                count: totalAlerts,
                onPressed: () => _showShellStatusSnack(context),
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
  final bool iconOnly;
  final OnyxRoute currentRoute;
  final int activeIncidentCount;
  final int aiActionCount;
  final int guardsOnlineCount;
  final int complianceIssuesCount;
  final int tacticalSosAlerts;
  final int elevatedRiskCount;
  final int liveAlarmCount;
  final String operatorLabel;
  final ValueChanged<OnyxRoute> onRouteChanged;

  const _Sidebar({
    required this.width,
    this.iconOnly = false,
    required this.currentRoute,
    required this.activeIncidentCount,
    required this.aiActionCount,
    required this.guardsOnlineCount,
    required this.complianceIssuesCount,
    required this.tacticalSosAlerts,
    this.elevatedRiskCount = 0,
    this.liveAlarmCount = 0,
    this.operatorLabel = '',
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

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'OP';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (iconOnly) return _buildIconRail(context);
    return _buildLabelSidebar(context);
  }

  Widget _buildIconRail(BuildContext context) {
    final allItems = OnyxRouteSection.values
        .expand((s) => s.routes.map(_navItemForRoute))
        .toList(growable: false);
    final initials = _initials(operatorLabel);

    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        border: Border(right: BorderSide(color: OnyxColorTokens.divider)),
      ),
      child: Column(
        children: [
          // Logo box
          Container(
            width: width,
            height: OnyxSpacingTokens.topBarHeight,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: OnyxColorTokens.divider),
              ),
            ),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: OnyxColorTokens.brand,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: Colors.white,
                size: 17,
              ),
            ),
          ),
          // Nav items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              children: [for (final item in allItems) _iconNavItem(item)],
            ),
          ),
          // Operator avatar
          Container(
            width: width,
            height: 56,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: OnyxColorTokens.divider)),
            ),
            child: PopupMenuButton<String>(
              key: const ValueKey('app-shell-operator-menu'),
              tooltip: operatorLabel.trim().isEmpty
                  ? 'Operator'
                  : operatorLabel,
              position: PopupMenuPosition.over,
              color: _appShellSurfaceColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: _appShellBorderColor),
              ),
              onSelected: (value) {
                if (value == 'organization') {
                  openOrganizationPage(context);
                }
              },
              itemBuilder: (context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'organization',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.account_tree_rounded,
                        size: 16,
                        color: OnyxColorTokens.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Organization chart',
                        style: _appShellTextStyle(
                          color: _appShellTitleColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: OnyxColorTokens.brand,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontFamily: OnyxDesignTokens.fontFamily,
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconNavItem(_NavItemModel item) {
    final isActive = item.route == currentRoute;
    return Tooltip(
      message: item.label,
      preferBelow: false,
      child: InkWell(
        onTap: () => onRouteChanged(item.route),
        hoverColor: OnyxColorTokens.backgroundPrimary,
        child: Container(
          width: width,
          height: 48,
          decoration: BoxDecoration(
            color: isActive ? OnyxColorTokens.cyanSurface : Colors.transparent,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (isActive)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 3, color: OnyxColorTokens.brand),
                ),
              Center(
                child: Icon(
                  item.icon,
                  size: 20,
                  color: isActive ? OnyxColorTokens.brand : _appShellMutedColor,
                ),
              ),
              if (item.badge != null)
                Positioned(
                  top: 6,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: item.badgeColor ?? OnyxColorTokens.accentRed,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${item.badge}',
                      style: const TextStyle(
                        fontFamily: OnyxDesignTokens.fontFamily,
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabelSidebar(BuildContext context) {
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
        color: OnyxColorTokens.backgroundSecondary,
        border: Border(right: BorderSide(color: OnyxColorTokens.divider)),
      ),
      child: Column(
        children: [
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: OnyxColorTokens.divider),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    color: OnyxColorTokens.brand,
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
                    _labelNavItem(
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

  Widget _labelNavItem(
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
              ? OnyxColorTokens.brand.withValues(alpha: 0.10)
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
                  child: Container(width: 3, color: OnyxColorTokens.brand),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 15,
                      color: isActive
                          ? OnyxColorTokens.brand
                          : _appShellMutedColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _appShellTextStyle(
                          color: isActive
                              ? _appShellTitleColor
                              : _appShellBodyColor,
                          fontSize: 12,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w500,
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
                          color: (badgeColor ?? OnyxColorTokens.brand)
                              .withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: (badgeColor ?? OnyxColorTokens.brand)
                                .withValues(alpha: 0.45),
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

class _NotificationBell extends StatelessWidget {
  final int count;
  final VoidCallback onPressed;

  const _NotificationBell({required this.count, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        OutlinedButton(
          key: const ValueKey('app-shell-status-button'),
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(38, 38),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            foregroundColor: OnyxDesignTokens.textPrimary,
            side: BorderSide(
              color: OnyxDesignTokens.borderStrong.withValues(alpha: 0.52),
            ),
            backgroundColor: OnyxDesignTokens.cardSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Icon(Icons.notifications_none_rounded, size: 16),
        ),
        if (count > 0)
          Positioned(
            top: -2,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: OnyxDesignTokens.redCritical,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontFamily: OnyxDesignTokens.fontFamily,
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StatusBanner extends StatefulWidget {
  final int activeIncidentCount;
  final int aiActionCount;

  const _StatusBanner({
    required this.activeIncidentCount,
    required this.aiActionCount,
  });

  @override
  State<_StatusBanner> createState() => _StatusBannerState();
}

class _StatusBannerState extends State<_StatusBanner> {
  Timer? _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.activeIncidentCount == 0 && widget.aiActionCount == 0) {
      return const SizedBox.shrink();
    }
    final isRed = widget.activeIncidentCount > 0;
    final bg = isRed
        ? OnyxColorTokens.redSurface
        : OnyxColorTokens.amberSurface;
    final fg = isRed ? OnyxColorTokens.accentRed : OnyxColorTokens.accentAmber;
    final label = isRed
        ? '⚠  ${widget.activeIncidentCount} ACTIVE ALARM${widget.activeIncidentCount == 1 ? '' : 'S'}'
        : '⚡  ${widget.aiActionCount} AI ACTION${widget.aiActionCount == 1 ? '' : 'S'} PENDING';
    final hh = _now.hour.toString().padLeft(2, '0');
    final mm = _now.minute.toString().padLeft(2, '0');
    final ss = _now.second.toString().padLeft(2, '0');

    return Container(
      height: 40,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: OnyxDesignTokens.fontFamily,
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const Spacer(),
          Text(
            '$hh:$mm:$ss',
            style: TextStyle(
              fontFamily: OnyxDesignTokens.fontFamily,
              color: fg.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ],
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
        minimumSize: const Size(38, 38),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        foregroundColor: foregroundColor,
        side: BorderSide(color: borderColor.withValues(alpha: 0.52)),
        backgroundColor: OnyxDesignTokens.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Stack(clipBehavior: Clip.none, children: [Icon(icon, size: 16)]),
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
                color: OnyxDesignTokens.cyanInteractive,
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
            color: OnyxDesignTokens.cyanInteractive,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _appShellTextStyle(
                color: OnyxDesignTokens.cyanInteractive,
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
              color: OnyxDesignTokens.cyanInteractive,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _appShellTextStyle(
                  color: OnyxDesignTokens.cyanInteractive,
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
    final color = source == 'all' ? _appShellAccentSky : _tickerColor(source);
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
      return _appShellAccentSky;
    }
    if (source == 'system') {
      return _appShellAccentSky;
    }
    return OnyxDesignTokens.purpleAdmin;
  }
}
