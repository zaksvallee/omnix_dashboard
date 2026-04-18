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
}
