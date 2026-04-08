import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/domain/authority/onyx_route.dart';

void main() {
  group('OnyxRoute', () {
    test('uses unique non-empty trimmed paths and labels', () {
      final paths = OnyxRoute.values.map((route) => route.path).toList();
      final labels = OnyxRoute.values.map((route) => route.label).toList();
      final normalizedLabels = labels
          .map((label) => label.toLowerCase())
          .toList(growable: false);

      expect(paths.length, paths.toSet().length);
      expect(labels.length, labels.toSet().length);
      expect(normalizedLabels.length, normalizedLabels.toSet().length);
      expect(paths.every((path) => path.startsWith('/')), isTrue);
      expect(labels.every((label) => label.trim().isNotEmpty), isTrue);
      expect(labels.every((label) => label == label.trim()), isTrue);
    });

    test('uses canonical normalized route paths', () {
      for (final route in OnyxRoute.values) {
        expect(route.path.startsWith('/'), isTrue);
        expect(route.path, matches(_onyxRoutePathPattern));
        expect(route.path.contains('?'), isFalse);
        expect(route.path.contains('#'), isFalse);
        if (route.path != '/') {
          expect(route.path.endsWith('/'), isFalse);
        }
      }
    });

    test('uses uppercase non-empty shell header labels', () {
      final shellHeaderLabels = OnyxRoute.values
          .map((route) => route.shellHeaderLabel)
          .toList(growable: false);

      expect(shellHeaderLabels.length, shellHeaderLabels.toSet().length);
      for (final route in OnyxRoute.values) {
        expect(route.shellHeaderLabel, isNotEmpty);
        expect(route.shellHeaderLabel, route.shellHeaderLabel.trim());
        expect(route.shellHeaderLabel, route.shellHeaderLabel.toUpperCase());
      }
    });

    test('uses route labels for autopilot labels except dashboard', () {
      final autopilotLabels = OnyxRoute.values
          .map((route) => route.autopilotLabel)
          .toList(growable: false);
      final normalizedAutopilotLabels = autopilotLabels
          .map((label) => label.toLowerCase())
          .toList(growable: false);
      final autopilotKeys = OnyxRoute.values
          .map((route) => route.autopilotKey)
          .toList(growable: false);

      expect(autopilotLabels.length, autopilotLabels.toSet().length);
      expect(
        normalizedAutopilotLabels.length,
        normalizedAutopilotLabels.toSet().length,
      );
      expect(autopilotKeys.length, autopilotKeys.toSet().length);
      for (final route in OnyxRoute.values) {
        expect(
          route.autopilotLabel,
          _expectedAutopilotLabels[route] ?? route.label,
        );
        expect(route.autopilotLabel, route.autopilotLabel.trim());
        expect(route.autopilotLabel.trim(), isNotEmpty);
        expect(route.autopilotKey, route.name.toLowerCase());
        expect(route.autopilotKey, matches(_onyxRouteAutopilotKeyPattern));
      }
    });

    test('uses non-empty autopilot narration for every route', () {
      for (final route in OnyxRoute.values) {
        expect(route.autopilotNarration, route.autopilotNarration.trim());
        expect(route.autopilotNarration.trim(), isNotEmpty);
      }
    });

    test('uses expected shell badge metadata', () {
      for (final entry in _expectedShellBadges.entries) {
        expect(entry.key.shellBadgeKind, entry.value.kind);
        expect(entry.key.shellBadgeColor, entry.value.color);
      }

      for (final route in OnyxRoute.values) {
        expect(route.shellBadgeKind == null, route.shellBadgeColor == null);
      }

      for (final route in OnyxRoute.values.where(
        (route) => !_expectedShellBadges.containsKey(route),
      )) {
        expect(route.shellBadgeKind, isNull);
        expect(route.shellBadgeColor, isNull);
      }
    });

    test('uses expected agent focus source metadata', () {
      for (final entry in _expectedAgentFocusSources.entries) {
        expect(entry.key.agentFocusSource, entry.value);
      }

      for (final route in OnyxRoute.values.where(
        (route) => !_expectedAgentFocusSources.containsKey(route),
      )) {
        expect(route.agentFocusSource, OnyxRouteAgentFocusSource.operations);
      }
    });

    test('uses expected agent scope source metadata', () {
      for (final entry in _expectedCustomAgentScopes.entries) {
        expect(entry.key.agentScopeSource, entry.value);
      }

      for (final route in OnyxRoute.values.where(
        (route) => !_expectedCustomAgentScopes.containsKey(route),
      )) {
        expect(route.agentScopeSource, OnyxRouteAgentScopeSource.selectedScope);
      }
    });

    test('uses expected shell intel ticker visibility metadata', () {
      for (final route in _routesWithoutShellIntelTicker) {
        expect(route.showsShellIntelTicker, isFalse);
      }

      for (final route in OnyxRoute.values.where(
        (route) => !_routesWithoutShellIntelTicker.contains(route),
      )) {
        expect(route.showsShellIntelTicker, isTrue);
      }
    });

    test('route sections expose titles and owned routes in enum order', () {
      final titles = OnyxRouteSection.values
          .map((section) => section.title)
          .toList(growable: false);

      expect(
        titles,
        isNotEmpty,
      );
      expect(titles.length, titles.toSet().length);

      for (var index = 0; index < OnyxRouteSection.values.length; index++) {
        final section = OnyxRouteSection.values[index];
        final expectedRoutes = OnyxRoute.values
            .where((route) => route.section == section)
            .toList(growable: false);
        expect(section.routes, expectedRoutes);
        expect(section.title, isNotEmpty);
        expect(section.title, section.title.trim());
        expect(section.title, section.title.toUpperCase());
        expect(section.routes, isNotEmpty);
      }
    });

    test('route sections cover every route exactly once', () {
      final sectionRoutes = OnyxRouteSection.values
          .expand((section) => section.routes)
          .toList();

      expect(sectionRoutes.length, OnyxRoute.values.length);
      expect(sectionRoutes.length, sectionRoutes.toSet().length);
      expect(sectionRoutes.toSet(), OnyxRoute.values.toSet());
      expect(
        OnyxRouteSection.values.every((section) => section.title.isNotEmpty),
        isTrue,
      );
      expect(
        OnyxRouteSection.values.every((section) => section.routes.isNotEmpty),
        isTrue,
      );
    });

    test('route sections expose unmodifiable route lists', () {
      final commandCenterRoutes = OnyxRouteSection.commandCenter.routes;

      expect(
        () => commandCenterRoutes.add(OnyxRoute.dashboard),
        throwsUnsupportedError,
      );
    });

    test(
      'fromLocation resolves exact, nested, query, and hash route paths',
      () {
        for (final route in OnyxRoute.values) {
          expect(OnyxRoute.fromLocation(route.path), route);
          expect(OnyxRoute.fromLocation('${route.path}/'), route);
          expect(OnyxRoute.fromLocation('${route.path}/details'), route);
          expect(OnyxRoute.fromLocation('${route.path}?tab=summary'), route);
          expect(OnyxRoute.fromLocation('${route.path}/?tab=summary'), route);
          expect(OnyxRoute.fromLocation('${route.path}#focus'), route);
          expect(OnyxRoute.fromLocation('${route.path}/#focus'), route);
        }
      },
    );

    test('fromLocation falls back to dashboard for unknown paths', () {
      expect(OnyxRoute.fromLocation('/unknown'), OnyxRoute.dashboard);
      expect(OnyxRoute.fromLocation('/dashboarder'), OnyxRoute.dashboard);
      expect(OnyxRoute.fromLocation('/dashboard//details'), OnyxRoute.dashboard);
      expect(OnyxRoute.fromLocation('/clientship'), OnyxRoute.dashboard);
      expect(
        OnyxRoute.fromLocation('/admin-panel?tab=ops'),
        OnyxRoute.dashboard,
      );
      expect(
        OnyxRoute.fromLocation('/clients//history?tab=open'),
        OnyxRoute.dashboard,
      );
      expect(OnyxRoute.fromLocation('/'), OnyxRoute.dashboard);
    });
  });
}

final Map<OnyxRoute, String> _expectedAutopilotLabels = <OnyxRoute, String>{
  OnyxRoute.dashboard: 'Operations',
};

final Map<OnyxRoute, OnyxRouteAgentFocusSource> _expectedAgentFocusSources =
    <OnyxRoute, OnyxRouteAgentFocusSource>{
      OnyxRoute.aiQueue: OnyxRouteAgentFocusSource.aiQueue,
    };

final Map<OnyxRoute, ({
  OnyxRouteShellBadgeKind kind,
  Color color,
})> _expectedShellBadges = <OnyxRoute, ({
  OnyxRouteShellBadgeKind kind,
  Color color,
})>{
  OnyxRoute.dashboard: (
    kind: OnyxRouteShellBadgeKind.activeIncidents,
    color: Color(0xFFEF4444),
  ),
  OnyxRoute.aiQueue: (
    kind: OnyxRouteShellBadgeKind.aiActions,
    color: Color(0xFF22D3EE),
  ),
  OnyxRoute.tactical: (
    kind: OnyxRouteShellBadgeKind.tacticalSosAlerts,
    color: Color(0xFFEF4444),
  ),
  OnyxRoute.governance: (
    kind: OnyxRouteShellBadgeKind.complianceIssues,
    color: Color(0xFF60A5FA),
  ),
};

final Map<OnyxRoute, OnyxRouteAgentScopeSource> _expectedCustomAgentScopes =
    <OnyxRoute, OnyxRouteAgentScopeSource>{
      OnyxRoute.dashboard: OnyxRouteAgentScopeSource.operationsRoute,
      OnyxRoute.aiQueue: OnyxRouteAgentScopeSource.aiQueueFocus,
      OnyxRoute.tactical: OnyxRouteAgentScopeSource.tacticalRoute,
      OnyxRoute.clients: OnyxRouteAgentScopeSource.clientsRoute,
      OnyxRoute.dispatches: OnyxRouteAgentScopeSource.dispatchRoute,
};

final Set<OnyxRoute> _routesWithoutShellIntelTicker = <OnyxRoute>{
  OnyxRoute.dashboard,
};

final RegExp _onyxRoutePathPattern = RegExp(
  r'^/(?:[a-z0-9-]+(?:/[a-z0-9-]+)*)?$',
);

final RegExp _onyxRouteAutopilotKeyPattern = RegExp(r'^[a-z0-9]+$');
