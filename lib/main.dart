import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ui/app_shell.dart';
import 'ui/dashboard_page.dart';
import 'ui/dispatch_page.dart';
import 'ui/events_page.dart';
import 'ui/ledger_page.dart';

import 'application/dispatch_application_service.dart';
import 'domain/store/in_memory_event_store.dart';
import 'engine/execution/execution_engine.dart';
import 'domain/intelligence/risk_policy.dart';
import 'domain/evidence/client_ledger_service.dart';
import 'domain/authority/operator_context.dart';
import 'infrastructure/events/supabase_client_ledger_repository.dart';

import 'domain/events/guard_checked_in.dart';
import 'domain/events/patrol_completed.dart';
import 'domain/events/response_arrived.dart';
import 'domain/events/incident_closed.dart';
import 'domain/events/decision_created.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  runApp(const OnyxApp());
}

class OnyxApp extends StatefulWidget {
  const OnyxApp({super.key});

  @override
  State<OnyxApp> createState() => _OnyxAppState();
}

class _OnyxAppState extends State<OnyxApp> {
  final store = InMemoryEventStore();
  late final DispatchApplicationService service;

  OnyxRoute _route = OnyxRoute.dashboard;

  final Map<String, Map<String, List<String>>> _tenantStructure = {
    'CLIENT-001': {
      'REGION-GAUTENG': ['SITE-SANDTON'],
      'REGION-WESTERN-CAPE': ['SITE-CAPE-TOWN'],
    },
  };

  String _selectedClient = 'CLIENT-001';
  String _selectedRegion = 'REGION-GAUTENG';
  String _selectedSite = 'SITE-SANDTON';

  @override
  void initState() {
    super.initState();

    final supabase = Supabase.instance.client;
    final repository = SupabaseClientLedgerRepository(supabase);

    final operator = OperatorContext(
      operatorId: 'OPERATOR-01',
      allowedRegions: {'REGION-GAUTENG'},
      allowedSites: {'SITE-SANDTON'},
    );

    service = DispatchApplicationService(
      store: store,
      engine: ExecutionEngine(),
      policy: RiskPolicy(escalationThreshold: 70),
      ledgerService: ClientLedgerService(repository),
      operator: operator,
    );

    _seedDemoData();
  }

  void _seedDemoData() {
    const clientId = 'CLIENT-001';
    const regionId = 'REGION-GAUTENG';
    const siteId = 'SITE-SANDTON';
    const guardId = 'GUARD-1';

    final now = DateTime.now().toUtc();

    for (int i = 0; i < 8; i++) {
      store.append(
        GuardCheckedIn(
          eventId: 'GCI-$i',
          sequence: 0,
          version: 1,
          occurredAt: now.subtract(Duration(hours: 8 - i)),
          guardId: guardId,
          clientId: clientId,
          regionId: regionId,
          siteId: siteId,
        ),
      );
    }

    for (int i = 0; i < 6; i++) {
      store.append(
        PatrolCompleted(
          eventId: 'PAT-$i',
          sequence: 0,
          version: 1,
          occurredAt: now.subtract(Duration(hours: 6 - i)),
          guardId: guardId,
          routeId: 'R1',
          clientId: clientId,
          regionId: regionId,
          siteId: siteId,
          durationSeconds: 600 + (i * 60),
        ),
      );
    }

    for (int i = 0; i < 5; i++) {
      final decisionTime = now.subtract(Duration(hours: 4 - i));
      final dispatchId = 'DSP-$i';

      store.append(
        DecisionCreated(
          eventId: 'DEC-$i',
          sequence: 0,
          version: 1,
          occurredAt: decisionTime,
          clientId: clientId,
          regionId: regionId,
          siteId: siteId,
          dispatchId: dispatchId,
        ),
      );

      final responseDelayMinutes = i.isEven ? 8 : 14;

      store.append(
        ResponseArrived(
          eventId: 'ARR-$i',
          sequence: 0,
          version: 1,
          occurredAt:
              decisionTime.add(Duration(minutes: responseDelayMinutes)),
          dispatchId: dispatchId,
          guardId: guardId,
          clientId: clientId,
          regionId: regionId,
          siteId: siteId,
        ),
      );

      store.append(
        IncidentClosed(
          eventId: 'CLOSE-$i',
          sequence: 0,
          version: 1,
          occurredAt:
              decisionTime.add(Duration(minutes: 25 + i * 3)),
          dispatchId: dispatchId,
          resolutionType: 'resolved',
          clientId: clientId,
          regionId: regionId,
          siteId: siteId,
        ),
      );
    }

    // DEBUG
    debugPrint("Seed complete. Event count: ${store.allEvents().length}");
  }

  void _onClientChanged(String client) {
    final regions = _tenantStructure[client]!;
    final newRegion = regions.keys.first;
    final newSite = regions[newRegion]!.first;

    setState(() {
      _selectedClient = client;
      _selectedRegion = newRegion;
      _selectedSite = newSite;
    });
  }

  void _onRegionChanged(String region) {
    final sites = _tenantStructure[_selectedClient]![region]!;

    setState(() {
      _selectedRegion = region;
      _selectedSite = sites.first;
    });
  }

  void _onSiteChanged(String site) {
    setState(() {
      _selectedSite = site;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AppShell(
        currentRoute: _route,
        onRouteChanged: (r) => setState(() => _route = r),
        child: _buildPage(),
      ),
    );
  }

  Widget _buildPage() {
    switch (_route) {
      case OnyxRoute.dashboard:
        return DashboardPage(
          selectedClient: _selectedClient,
          selectedRegion: _selectedRegion,
          selectedSite: _selectedSite,
          onClientChanged: _onClientChanged,
          onRegionChanged: _onRegionChanged,
          onSiteChanged: _onSiteChanged,
          eventStore: store,
        );

      case OnyxRoute.dispatches:
        return DispatchPage(
          clientId: _selectedClient,
          regionId: _selectedRegion,
          siteId: _selectedSite,
          onGenerate: () {
            setState(() {
              service.processIntelligenceDemo(
                clientId: _selectedClient,
                regionId: _selectedRegion,
                siteId: _selectedSite,
              );
            });
          },
          events: store.allEvents(),
          onExecute: (dispatchId) {
            setState(() {
              service.execute(
                clientId: _selectedClient,
                regionId: _selectedRegion,
                siteId: _selectedSite,
                dispatchId: dispatchId,
              );
            });
          },
        );

      case OnyxRoute.events:
        return EventsPage(events: store.allEvents());

      case OnyxRoute.ledger:
        return LedgerPage(clientId: _selectedClient);
    }
  }
}
