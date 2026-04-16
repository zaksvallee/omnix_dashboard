// lib/domain/authority/onyx_route.dart

import 'package:flutter/material.dart';

enum OnyxRouteSection {
  commandCenter('COMMAND CENTER'),
  operations('OPERATIONS'),
  governance('GOVERNANCE'),
  evidence('EVIDENCE'),
  system('SYSTEM');

  final String title;

  const OnyxRouteSection(this.title);

  List<OnyxRoute> get routes => _onyxRouteSectionRoutes[this]!;
}

enum OnyxRouteShellBadgeKind {
  activeIncidents,
  aiActions,
  tacticalSosAlerts,
  complianceIssues,
}

enum OnyxRouteAgentFocusSource { operations, aiQueue }

enum OnyxRouteAgentScopeSource {
  selectedScope,
  operationsRoute,
  aiQueueFocus,
  tacticalRoute,
  clientsRoute,
  dispatchRoute,
}

/// Authoritative ONYX route enum.
/// This is the ONLY route definition allowed in the system.
enum OnyxRoute {
  dashboard(
    '/dashboard',
    'Command',
    Icons.bolt_rounded,
    OnyxRouteSection.commandCenter,
    'COMMAND',
    'Operational overview.',
    autopilotLabel: 'Operations',
    shellBadgeKind: OnyxRouteShellBadgeKind.activeIncidents,
    shellBadgeColor: Color(0xFFEF4444),
    agentScopeSource: OnyxRouteAgentScopeSource.operationsRoute,
    showsShellIntelTicker: false,
  ),
  agent(
    '/agent',
    'Agent',
    Icons.auto_awesome_rounded,
    OnyxRouteSection.commandCenter,
    'AGENT',
    'Local-first controller brain with specialist agent handoffs.',
  ),
  aiQueue(
    '/ai-queue',
    'AI Queue',
    Icons.videocam_rounded,
    OnyxRouteSection.commandCenter,
    'AI QUEUE',
    'AI-powered surveillance and alert review.',
    shellBadgeKind: OnyxRouteShellBadgeKind.aiActions,
    shellBadgeColor: Color(0xFF22D3EE),
    agentFocusSource: OnyxRouteAgentFocusSource.aiQueue,
    agentScopeSource: OnyxRouteAgentScopeSource.aiQueueFocus,
  ),
  tactical(
    '/tactical',
    'Track',
    Icons.map_rounded,
    OnyxRouteSection.commandCenter,
    'TRACK',
    'Verify units, geofence, and site posture.',
    shellBadgeKind: OnyxRouteShellBadgeKind.tacticalSosAlerts,
    shellBadgeColor: Color(0xFFEF4444),
    agentScopeSource: OnyxRouteAgentScopeSource.tacticalRoute,
  ),
  vip(
    '/vip',
    'VIP',
    Icons.shield_outlined,
    OnyxRouteSection.operations,
    'VIP',
    'Quiet convoy posture and upcoming VIP details.',
  ),
  intel(
    '/intel',
    'Intel',
    Icons.trending_up_rounded,
    OnyxRouteSection.operations,
    'INTEL',
    'Threat posture and intelligence watch.',
  ),
  governance(
    '/governance',
    'Governance',
    Icons.shield_rounded,
    OnyxRouteSection.governance,
    'GOVERNANCE',
    'Show compliance and readiness controls.',
    shellBadgeKind: OnyxRouteShellBadgeKind.complianceIssues,
    shellBadgeColor: Color(0xFF60A5FA),
  ),
  clients(
    '/clients',
    'Clients',
    Icons.chat_bubble_rounded,
    OnyxRouteSection.operations,
    'COMMS',
    'Client-facing confidence and Client Comms desk.',
    agentScopeSource: OnyxRouteAgentScopeSource.clientsRoute,
  ),
  sites(
    '/sites',
    'Sites',
    Icons.apartment_rounded,
    OnyxRouteSection.operations,
    'SITES',
    'Deployment footprint and zone definitions.',
  ),
  guards(
    '/guards-workforce',
    'Guards',
    Icons.badge_rounded,
    OnyxRouteSection.operations,
    'GUARDS',
    'Operational readiness intelligence for the workforce layer.',
  ),
  dispatches(
    '/dispatches',
    'Dispatches',
    Icons.send_rounded,
    OnyxRouteSection.commandCenter,
    'DISPATCHES',
    'Execute with focused dispatch context.',
    agentScopeSource: OnyxRouteAgentScopeSource.dispatchRoute,
  ),
  alarms(
    '/alarms',
    'Alarms',
    Icons.warning_amber_rounded,
    OnyxRouteSection.commandCenter,
    'ALARMS',
    'Monitor active alarms and dispatch armed response.',
    shellBadgeKind: OnyxRouteShellBadgeKind.activeIncidents,
    shellBadgeColor: Color(0xFFEF4444),
  ),
  events(
    '/events',
    'Events',
    Icons.timeline_rounded,
    OnyxRouteSection.operations,
    'EVENTS',
    'Replay immutable incident timeline.',
  ),
  ledger(
    '/ledger',
    'OB Log',
    Icons.menu_book_rounded,
    OnyxRouteSection.evidence,
    'LEDGER',
    'Review clean operational records and linked continuity.',
  ),
  reports(
    '/reports',
    'Reports',
    Icons.summarize_rounded,
    OnyxRouteSection.evidence,
    'REPORTS',
    'Review export proof and generated reports.',
  ),
  admin(
    '/admin',
    'Admin',
    Icons.settings_rounded,
    OnyxRouteSection.system,
    'ADMIN',
    'Manage runtime controls and system settings.',
  );

  final String path;
  final String label;
  final IconData icon;
  final OnyxRouteSection section;
  final String shellHeaderLabel;
  final String autopilotLabel;
  final String autopilotNarration;
  final OnyxRouteShellBadgeKind? shellBadgeKind;
  final Color? shellBadgeColor;
  final OnyxRouteAgentFocusSource agentFocusSource;
  final OnyxRouteAgentScopeSource agentScopeSource;
  final bool showsShellIntelTicker;

  const OnyxRoute(
    this.path,
    this.label,
    this.icon,
    this.section,
    this.shellHeaderLabel,
    this.autopilotNarration, {
    String? autopilotLabel,
    this.shellBadgeKind,
    this.shellBadgeColor,
    this.agentFocusSource = OnyxRouteAgentFocusSource.operations,
    this.agentScopeSource = OnyxRouteAgentScopeSource.selectedScope,
    this.showsShellIntelTicker = true,
  }) : autopilotLabel = autopilotLabel ?? label;

  String get autopilotKey => name.toLowerCase();

  bool matchesLocation(String location) {
    return _matchesNormalizedLocation(_normalizeOnyxRouteLocation(location));
  }

  bool _matchesNormalizedLocation(String normalizedLocation) {
    if (normalizedLocation == path) {
      return true;
    }
    if (!normalizedLocation.startsWith('$path/')) {
      return false;
    }

    final nestedPath = normalizedLocation.substring(path.length + 1);
    return nestedPath.isNotEmpty &&
        !nestedPath.startsWith('/') &&
        !nestedPath.contains('//');
  }

  /// Resolve enum from GoRouter location
  static OnyxRoute fromLocation(String location) {
    final normalizedLocation = _normalizeOnyxRouteLocation(location);
    final exactRoute = _onyxRouteByPath[normalizedLocation];
    if (exactRoute != null) {
      return exactRoute;
    }
    return _onyxRoutes.firstWhere(
      (route) => route._matchesNormalizedLocation(normalizedLocation),
      orElse: () => OnyxRoute.dashboard,
    );
  }
}

final List<OnyxRouteSection> _onyxRouteSections = _buildOnyxRouteSections();

final List<OnyxRoute> _onyxRoutes = _buildOnyxRoutes();

List<OnyxRoute> _buildOnyxRoutes() {
  final routesByLabel = <String, OnyxRoute>{};
  final routesByNormalizedLabel = <String, OnyxRoute>{};
  final routesByShellHeaderLabel = <String, OnyxRoute>{};
  final routesByAutopilotLabel = <String, OnyxRoute>{};
  final routesByNormalizedAutopilotLabel = <String, OnyxRoute>{};
  final routesByAutopilotKey = <String, OnyxRoute>{};
  for (final route in OnyxRoute.values) {
    if ((route.shellBadgeKind == null) != (route.shellBadgeColor == null)) {
      throw StateError(
        'ONYX route ${route.name} must set shellBadgeKind and shellBadgeColor together.',
      );
    }
    if (route.label.trim().isEmpty || route.label != route.label.trim()) {
      throw StateError(
        'ONYX route ${route.name} must use a non-empty trimmed label.',
      );
    }
    if (route.shellHeaderLabel.trim().isEmpty ||
        route.shellHeaderLabel != route.shellHeaderLabel.trim() ||
        route.shellHeaderLabel != route.shellHeaderLabel.toUpperCase()) {
      throw StateError(
        'ONYX route ${route.name} must use a non-empty trimmed uppercase shell header label.',
      );
    }
    if (route.autopilotLabel.trim().isEmpty ||
        route.autopilotLabel != route.autopilotLabel.trim()) {
      throw StateError(
        'ONYX route ${route.name} must use a non-empty trimmed autopilot label.',
      );
    }
    if (!_onyxRouteAutopilotKeyPattern.hasMatch(route.autopilotKey)) {
      throw StateError(
        'ONYX route ${route.name} must use a lowercase alphanumeric autopilot key.',
      );
    }
    if (route.autopilotNarration.trim().isEmpty ||
        route.autopilotNarration != route.autopilotNarration.trim()) {
      throw StateError(
        'ONYX route ${route.name} must use a non-empty trimmed autopilot narration.',
      );
    }

    final existingRoute = routesByLabel[route.label];
    if (existingRoute != null) {
      throw StateError(
        'Duplicate ONYX route label "${route.label}" for '
        '${existingRoute.name} and ${route.name}.',
      );
    }
    routesByLabel[route.label] = route;

    final normalizedLabel = route.label.toLowerCase();
    final existingNormalizedLabelRoute =
        routesByNormalizedLabel[normalizedLabel];
    if (existingNormalizedLabelRoute != null) {
      throw StateError(
        'Duplicate ONYX route label ignoring case "${route.label}" for '
        '${existingNormalizedLabelRoute.name} and ${route.name}.',
      );
    }
    routesByNormalizedLabel[normalizedLabel] = route;

    final existingShellHeaderRoute =
        routesByShellHeaderLabel[route.shellHeaderLabel];
    if (existingShellHeaderRoute != null) {
      throw StateError(
        'Duplicate ONYX shell header label "${route.shellHeaderLabel}" for '
        '${existingShellHeaderRoute.name} and ${route.name}.',
      );
    }
    routesByShellHeaderLabel[route.shellHeaderLabel] = route;

    final existingAutopilotRoute = routesByAutopilotLabel[route.autopilotLabel];
    if (existingAutopilotRoute != null) {
      throw StateError(
        'Duplicate ONYX autopilot label "${route.autopilotLabel}" for '
        '${existingAutopilotRoute.name} and ${route.name}.',
      );
    }
    routesByAutopilotLabel[route.autopilotLabel] = route;

    final normalizedAutopilotLabel = route.autopilotLabel.toLowerCase();
    final existingNormalizedAutopilotRoute =
        routesByNormalizedAutopilotLabel[normalizedAutopilotLabel];
    if (existingNormalizedAutopilotRoute != null) {
      throw StateError(
        'Duplicate ONYX autopilot label ignoring case '
        '"${route.autopilotLabel}" for '
        '${existingNormalizedAutopilotRoute.name} and ${route.name}.',
      );
    }
    routesByNormalizedAutopilotLabel[normalizedAutopilotLabel] = route;

    final existingAutopilotKeyRoute = routesByAutopilotKey[route.autopilotKey];
    if (existingAutopilotKeyRoute != null) {
      throw StateError(
        'Duplicate ONYX autopilot key "${route.autopilotKey}" for '
        '${existingAutopilotKeyRoute.name} and ${route.name}.',
      );
    }
    routesByAutopilotKey[route.autopilotKey] = route;
  }

  return List<OnyxRoute>.unmodifiable(OnyxRoute.values);
}

List<OnyxRouteSection> _buildOnyxRouteSections() {
  final sectionsByTitle = <String, OnyxRouteSection>{};
  for (final section in OnyxRouteSection.values) {
    if (section.title.trim().isEmpty ||
        section.title != section.title.trim() ||
        section.title != section.title.toUpperCase()) {
      throw StateError(
        'ONYX route section ${section.name} must use a non-empty trimmed uppercase title.',
      );
    }

    final existingSection = sectionsByTitle[section.title];
    if (existingSection != null) {
      throw StateError(
        'Duplicate ONYX route section title "${section.title}" for '
        '${existingSection.name} and ${section.name}.',
      );
    }
    sectionsByTitle[section.title] = section;
  }

  return List<OnyxRouteSection>.unmodifiable(OnyxRouteSection.values);
}

final RegExp _onyxRoutePathPattern = RegExp(
  r'^/(?:[a-z0-9-]+(?:/[a-z0-9-]+)*)?$',
);

final RegExp _onyxRouteAutopilotKeyPattern = RegExp(r'^[a-z0-9]+$');

final Map<String, OnyxRoute> _onyxRouteByPath = _buildOnyxRouteByPath();

final Map<OnyxRouteSection, List<OnyxRoute>> _onyxRouteSectionRoutes =
    _buildOnyxRouteSectionRoutes();

Map<String, OnyxRoute> _buildOnyxRouteByPath() {
  final routesByPath = <String, OnyxRoute>{};
  for (final route in _onyxRoutes) {
    final normalizedPath = _normalizeOnyxRouteLocation(route.path);
    if (normalizedPath != route.path) {
      throw StateError(
        'ONYX route path "${route.path}" for ${route.name} must already be '
        'normalized as "$normalizedPath".',
      );
    }
    if (!_onyxRoutePathPattern.hasMatch(route.path)) {
      throw StateError(
        'ONYX route path "${route.path}" for ${route.name} must use '
        'slash-separated lowercase alphanumeric or hyphen segments.',
      );
    }

    final existingRoute = routesByPath[normalizedPath];
    if (existingRoute != null) {
      throw StateError(
        'Duplicate ONYX route path "$normalizedPath" for '
        '${existingRoute.name} and ${route.name}.',
      );
    }
    routesByPath[normalizedPath] = route;
  }
  return Map<String, OnyxRoute>.unmodifiable(routesByPath);
}

Map<OnyxRouteSection, List<OnyxRoute>> _buildOnyxRouteSectionRoutes() {
  final routesBySection = <OnyxRouteSection, List<OnyxRoute>>{
    for (final section in _onyxRouteSections)
      section: List<OnyxRoute>.unmodifiable(
        _onyxRoutes.where((route) => route.section == section),
      ),
  };

  for (final section in _onyxRouteSections) {
    if (routesBySection[section]!.isEmpty) {
      throw StateError(
        'ONYX route section ${section.title} must include at least one route.',
      );
    }
  }

  return Map<OnyxRouteSection, List<OnyxRoute>>.unmodifiable(routesBySection);
}

String _normalizeOnyxRouteLocation(String location) {
  var end = location.length;
  final queryIndex = location.indexOf('?');
  if (queryIndex >= 0 && queryIndex < end) {
    end = queryIndex;
  }
  final hashIndex = location.indexOf('#');
  if (hashIndex >= 0 && hashIndex < end) {
    end = hashIndex;
  }

  var normalized = location.substring(0, end);
  if (normalized.length > 1 && normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}
