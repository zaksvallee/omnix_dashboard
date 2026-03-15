import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/ui/video_fleet_scope_health_panel.dart';
import 'package:omnix_dashboard/ui/video_fleet_scope_health_sections.dart';
import 'package:omnix_dashboard/ui/video_fleet_scope_health_view.dart';

void main() {
  testWidgets('shared fleet panel renders summary and grouped sections', (
    tester,
  ) async {
    final sections = VideoFleetScopeHealthSections.fromScopes(const [
      VideoFleetScopeHealthView(
        clientId: 'CLIENT-A',
        siteId: 'SITE-A',
        siteName: 'MS Vallee Residence',
        endpointLabel: '192.168.8.105',
        statusLabel: 'LIVE',
        watchLabel: 'ACTIVE',
        recentEvents: 2,
        lastSeenLabel: '21:14 UTC',
        freshnessLabel: 'Fresh',
        isStale: false,
        latestEventLabel: 'Vehicle motion',
        latestIncidentReference: 'INT-VALLEE-1',
        latestEventTimeLabel: '21:14 UTC',
        latestCameraLabel: 'Camera 1',
        latestRiskScore: 84,
      ),
      VideoFleetScopeHealthView(
        clientId: 'CLIENT-B',
        siteId: 'SITE-B',
        siteName: 'Beta Watch',
        endpointLabel: '192.168.8.106',
        statusLabel: 'WATCH READY',
        watchLabel: 'SCHEDULED',
        recentEvents: 0,
        lastSeenLabel: 'idle',
        freshnessLabel: 'Idle',
        isStale: false,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoFleetScopeHealthPanel(
            title: 'DVR FLEET HEALTH',
            titleStyle: const TextStyle(fontSize: 12),
            sectionLabelStyle: const TextStyle(fontSize: 10),
            sections: sections,
            summaryChildren: const [
              Chip(label: Text('Active 1')),
              Chip(label: Text('Gap 1')),
              Chip(label: Text('No Incident 1')),
            ],
            actionableChildren: const [Card(child: Text('Actionable Card'))],
            watchOnlyChildren: const [Card(child: Text('Watch-Only Card'))],
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: Colors.black12),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DVR FLEET HEALTH'), findsOneWidget);
    expect(find.text('Active 1'), findsOneWidget);
    expect(find.text('Gap 1'), findsOneWidget);
    expect(find.text('No Incident 1'), findsOneWidget);
    expect(
      find.text('ACTIONABLE (1) • Incident-backed fleet scopes'),
      findsOneWidget,
    );
    expect(
      find.text('WATCH-ONLY (1) • Watch scopes awaiting incident context'),
      findsOneWidget,
    );
    expect(find.text('Actionable Card'), findsOneWidget);
    expect(find.text('Watch-Only Card'), findsOneWidget);
  });

  testWidgets('shared fleet panel omits empty card wraps but keeps labels', (
    tester,
  ) async {
    final sections = VideoFleetScopeHealthSections.fromScopes(const [
      VideoFleetScopeHealthView(
        clientId: 'CLIENT-B',
        siteId: 'SITE-B',
        siteName: 'Beta Watch',
        endpointLabel: '192.168.8.106',
        statusLabel: 'WATCH READY',
        watchLabel: 'SCHEDULED',
        recentEvents: 0,
        lastSeenLabel: 'idle',
        freshnessLabel: 'Idle',
        isStale: false,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoFleetScopeHealthPanel(
            title: 'DVR FLEET HEALTH',
            titleStyle: const TextStyle(fontSize: 12),
            sectionLabelStyle: const TextStyle(fontSize: 10),
            sections: sections,
            summaryChildren: const [],
            actionableChildren: const [],
            watchOnlyChildren: const [],
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: Colors.black12),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('ACTIONABLE (0) • No incident-backed fleet scopes right now'),
      findsOneWidget,
    );
    expect(
      find.text('WATCH-ONLY (1) • Watch scopes awaiting incident context'),
      findsOneWidget,
    );
    expect(find.text('Actionable Card'), findsNothing);
    expect(find.text('Watch-Only Card'), findsNothing);
  });
}
