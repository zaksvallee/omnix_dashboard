part of '../main.dart';

extension _OnyxRouteDispatcher on _OnyxAppState {
  /// `_route`-driven page renderer. The in-shell GoRoute builders in
  /// `onyx_router.dart` delegate here so the 74 legacy
  /// `setState(() { _route = X; })` call sites continue to work during
  /// Phase 2 migration — a setState rebuilds the AppShell, and this
  /// dispatcher returns the widget for whatever `_route` is current.
  /// Phase 3 retires this helper once every call site has been migrated
  /// to `_router.go(path)`.
  Widget _buildPage(List<DispatchEvent> events) {
    return buildOnyxRouteRegistry(
      sections: buildOnyxRouteRegistrySections(
        builders: _buildRouteBuilders(
          events,
          _morningSovereignReportHistory.length > 1
              ? _globalReadinessTomorrowUrgencySummary(
                  _globalReadinessIntentsForReport(
                    _morningSovereignReportHistory[1],
                  ),
                )
              : '',
        ),
      ),
    ).build(_route);
  }
}
