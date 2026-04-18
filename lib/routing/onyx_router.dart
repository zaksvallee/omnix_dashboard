part of '../main.dart';

/// Phase 1 ONYX router scaffold.
///
/// Serves two flavours of routes:
///   - `/` — Zara Home (ambient surface, no AppShell chrome).
///   - `<OnyxRoute.path>` for every enum value — wrapped in a ShellRoute that
///     renders AppShell chrome and delegates the body to the existing
///     `_buildRouteBuilders` map.
///
/// Only one page is considered fully migrated in Phase 1 (Alarms). Phase 2
/// will convert the remaining `_route = X` setState call sites to
/// `_router.go(path)` following the recipe in
/// docs/migrations/router-migration-recipe.md.
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
                // Phase 1: the router's in-shell children delegate to the
                // legacy `_route`-driven dispatcher. That keeps every
                // non-migrated `setState(() { _route = X; })` call site
                // working — setState pings the refresh notifier, the
                // ListenableBuilder rebuilds, the dispatcher picks the
                // current `_route` and returns its widget. Phase 2 migrates
                // those call sites to `_router.go(X.path)` one at a time;
                // Phase 3 flips the dispatcher to dispatch from the URL and
                // retires `_route`.
                builder: (context, state) => ListenableBuilder(
                  listenable: _routerRefreshNotifier,
                  builder: (ctx, _) => _buildPage(store.allEvents()),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Returns the `OnyxRoute` whose `path` matches the router's current URL,
  /// or `null` if the current URL is outside the enum (e.g. the Zara Home
  /// root `/`). Used by `_OnyxAppState._syncRouteFromRouter` to keep the
  /// legacy `_route` field in lockstep with the URL during the Phase 1–2
  /// transition.
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

  /// Returns the URI the router is currently showing. Used by
  /// `_syncRouteFromRouter` to parse Events scope-rail origin params.
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
