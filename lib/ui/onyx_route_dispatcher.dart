part of '../main.dart';

extension _OnyxRouteDispatcher on _OnyxAppState {
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
