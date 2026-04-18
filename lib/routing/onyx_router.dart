part of '../main.dart';

/// ONYX router configuration.
///
/// Serves two flavours of routes:
///   - `/` — Zara Home (ambient surface, no AppShell chrome).
///   - `<OnyxRoute.path>` for every enum value — wrapped in a ShellRoute
///     that renders AppShell chrome and delegates the body to the
///     matching `_buildXxxRoute` method via the `_buildRouteBuilders`
///     registry.
///
/// `_routerRefreshNotifier` (defined on `_OnyxAppState`) is fired on every
/// `setState`. It's threaded into GoRouter as `refreshListenable` AND each
/// route builder is wrapped in a `ListenableBuilder` listening to it. Both
/// jobs are necessary: `MaterialApp.router` short-circuits parent rebuilds
/// when its `routerConfig` is unchanged, so without this bridge any
/// setState mutation to a non-routing field (events scope, ops focus,
/// dispatch selection, Telegram queue updates, etc.) would not propagate
/// into the router-mounted page widgets. The bridge is permanent
/// architecture, not a transition artefact — its retirement requires a
/// larger refactor to consume state via Provider/InheritedWidget.
const String _zaraHomeRouterPath = '/';

extension _OnyxAppRouter on _OnyxAppState {
  /// Resolves the initial URL the router should open on boot.
  /// Tests and deep-link entry harnesses supply `initialRouteOverride`;
  /// everything else lands at Zara Home.
  String _resolveInitialRouterLocation() {
    final override = widget.initialRouteOverride;
    if (override != null) {
      return override.path;
    }
    return _zaraHomeRouterPath;
  }

  GoRouter _buildOnyxRouter() {
    return GoRouter(
      initialLocation: _resolveInitialRouterLocation(),
      navigatorKey: _navigatorKey,
      refreshListenable: _routerRefreshNotifier,
      routes: <RouteBase>[
        GoRoute(
          path: _zaraHomeRouterPath,
          name: 'zaraHome',
          builder: (context, state) => ListenableBuilder(
            listenable: _routerRefreshNotifier,
            builder: (ctx, _) => _buildZaraHomeRoute(store.allEvents()),
          ),
        ),
        ShellRoute(
          builder: (context, state, child) => ListenableBuilder(
            listenable: _routerRefreshNotifier,
            builder: (ctx, _) =>
                _buildControllerShell(ctx, child, store.allEvents()),
          ),
          routes: <RouteBase>[
            for (final route in OnyxRoute.values)
              GoRoute(
                path: route.path,
                name: route.name,
                builder: (context, state) => ListenableBuilder(
                  listenable: _routerRefreshNotifier,
                  builder: (ctx, _) => _buildRouterPage(route),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Builds the page widget for the given OnyxRoute by looking up the
  /// matching builder in the registry. Replaces the retired
  /// `_buildPage` dispatcher (which read the long-gone `_route` field).
  Widget _buildRouterPage(OnyxRoute route) {
    final events = store.allEvents();
    final summary = _morningSovereignReportHistory.length > 1
        ? _globalReadinessTomorrowUrgencySummary(
            _globalReadinessIntentsForReport(
              _morningSovereignReportHistory[1],
            ),
          )
        : '';
    final builders = _buildRouteBuilders(events, summary);
    return builders[route]?.call() ?? const SizedBox.shrink();
  }

  /// Returns the `OnyxRoute` whose `path` matches the router's current URL,
  /// or `null` if the current URL is outside the enum (e.g. the Zara Home
  /// root `/`). Wrapped by `_OnyxAppState._activeRoute()` for read sites
  /// that need a non-nullable OnyxRoute.
  OnyxRoute? _routeFromCurrentRouter() {
    final configuration = _router.routerDelegate.currentConfiguration;
    final currentPath = configuration.uri.path;
    for (final candidate in OnyxRoute.values) {
      if (candidate.path == currentPath) {
        return candidate;
      }
    }
    return null;
  }

  /// Returns the URI the router is currently showing. Read by
  /// `_buildEventsRoute` to parse the `?origin=…&label=…` scope-rail
  /// query params on every render.
  Uri _currentRouterUri() =>
      _router.routerDelegate.currentConfiguration.uri;
}

// ── Events scope-rail URL encoding ──────────────────────────────────────────
//
// Events deep-links carry optional `origin` + `label` query parameters that
// drive the scope-rail back-link chip:
//
//   /events                                   → no chip (navRail)
//   /events?origin=ledger&label=OB-2441       → "← LEDGER: OB-2441" chip
//   /events?origin=governance                 → "← GOVERNANCE" chip (no label)
//
// `origin` values correspond to `ZaraEventsRouteSource.name` for ledger,
// aiQueue, dispatches, reports, governance, liveOps. navRail and unknown are
// represented by the param being absent. Unrecognised values fall back to
// navRail. `label` is URL-encoded/decoded via `Uri.queryParameters` automatically.
//
// Scoped event IDs (`_eventsScopedEventIds`, `_eventsSelectedEventId`,
// `_eventsScopedMode`) stay in-memory during the Phase 3 transition. Hard-reload
// at a scoped URL loses the scope details but preserves the origin chip + the
// back-link — acceptable, and strictly better than pre-migration behaviour where
// hard-reload dropped the chip entirely.

/// Parses `origin` from an Events URI into a `ZaraEventsRouteSource`. Returns
/// `null` when the param is missing or unrecognised; callers treat that as
/// navRail / unknown (no origin chip).
ZaraEventsRouteSource? _eventsOriginFromUri(Uri uri) {
  final raw = uri.queryParameters['origin']?.trim() ?? '';
  if (raw.isEmpty) return null;
  for (final candidate in ZaraEventsRouteSource.values) {
    if (candidate == ZaraEventsRouteSource.navRail ||
        candidate == ZaraEventsRouteSource.unknown) {
      continue;
    }
    if (candidate.name == raw) return candidate;
  }
  return null;
}

/// Extracts and trims the `label` query param from an Events URI.
String _eventsOriginLabelFromUri(Uri uri) =>
    (uri.queryParameters['label'] ?? '').trim();

/// Composes the `/events` URL for a given origin + label. navRail / unknown
/// / null source produce the bare `/events` path (no query params).
String _eventsRouterLocation({
  ZaraEventsRouteSource? source,
  String label = '',
}) {
  final effectiveSource =
      source == ZaraEventsRouteSource.navRail ||
          source == ZaraEventsRouteSource.unknown
      ? null
      : source;
  final trimmedLabel = label.trim();
  if (effectiveSource == null && trimmedLabel.isEmpty) {
    return OnyxRoute.events.path;
  }
  final params = <String, String>{};
  if (effectiveSource != null) {
    params['origin'] = effectiveSource.name;
  }
  if (trimmedLabel.isNotEmpty) {
    params['label'] = trimmedLabel;
  }
  return Uri(path: OnyxRoute.events.path, queryParameters: params).toString();
}
