part of '../main.dart';

extension _OnyxRouteBuilders on _OnyxAppState {
  Map<OnyxRoute, OnyxRouteBuilder> _buildRouteBuilders(
    List<DispatchEvent> events,
    String previousTomorrowUrgencySummary,
  ) {
    return <OnyxRoute, OnyxRouteBuilder>{
      OnyxRoute.dashboard: () =>
          _buildDashboardRoute(events, previousTomorrowUrgencySummary),
      OnyxRoute.agent: () => _buildAgentRoute(events),
      OnyxRoute.aiQueue: () =>
          _buildAiQueueRoute(events, previousTomorrowUrgencySummary),
      OnyxRoute.dispatches: () => _buildDispatchesRoute(events),
      OnyxRoute.alarms: _buildAlarmsRoute,
      OnyxRoute.tactical: () => _buildTacticalRoute(events),
      OnyxRoute.vip: _buildVipRoute,
      OnyxRoute.intel: () => _buildIntelRoute(events),
      OnyxRoute.clients: () => _buildClientsRoute(events),
      OnyxRoute.guards: () => _buildGuardsRoute(events),
      OnyxRoute.sites: () => _buildSitesRoute(events),
      OnyxRoute.events: () => _buildEventsRoute(events),
      OnyxRoute.governance: () => _buildGovernanceRoute(events),
      OnyxRoute.ledger: () => _buildLedgerRoute(events),
      OnyxRoute.reports: _buildReportsRoute,
      OnyxRoute.admin: () => _buildAdminRoute(events),
    };
  }
}
