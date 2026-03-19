import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/ui/video_fleet_scope_health_card.dart';

void main() {
  testWidgets('shared fleet card renders all optional sections', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoFleetScopeHealthCard(
            title: 'MS Vallee Residence',
            endpointLabel: '192.168.8.105',
            lastSeenLabel: ': 21:14 UTC',
            titleStyle: const TextStyle(fontSize: 13),
            endpointStyle: const TextStyle(fontSize: 10),
            lastSeenStyle: const TextStyle(fontSize: 11),
            noteStyle: const TextStyle(fontSize: 11),
            latestStyle: const TextStyle(fontSize: 11),
            statusDetailStyle: const TextStyle(fontSize: 10),
            primaryChips: const [
              Chip(label: Text('Status LIVE')),
              Chip(label: Text('Watch ACTIVE')),
            ],
            secondaryChips: const [
              Chip(label: Text('Risk High')),
              Chip(label: Text('Camera 1')),
            ],
            actionChildren: [
              TextButton(
                onPressed: () {
                  tapped = true;
                },
                child: const Text('Dispatch'),
              ),
            ],
            noteText:
                'Recent site activity is present, but no scope-linked incident reference is available yet.',
            latestText: 'Latest: 21:14 UTC • Vehicle motion',
            statusDetailText: 'One remote camera feed is stale.',
            onTap: () {
              tapped = true;
            },
            decoration: const BoxDecoration(color: Colors.black12),
            constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MS Vallee Residence'), findsOneWidget);
    expect(find.text('192.168.8.105'), findsOneWidget);
    expect(find.text('Last seen: 21:14 UTC'), findsOneWidget);
    expect(find.text('One remote camera feed is stale.'), findsOneWidget);
    expect(
      find.text(
        'Recent site activity is present, but no scope-linked incident reference is available yet.',
      ),
      findsOneWidget,
    );
    expect(find.text('Latest: 21:14 UTC • Vehicle motion'), findsOneWidget);
    expect(find.text('Status LIVE'), findsOneWidget);
    expect(find.text('Watch ACTIVE'), findsOneWidget);
    expect(find.text('Risk High'), findsOneWidget);
    expect(find.text('Camera 1'), findsOneWidget);
    expect(find.text('Dispatch'), findsOneWidget);

    await tester.tap(find.text('MS Vallee Residence'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });

  testWidgets('shared fleet card omits optional blocks when unset', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoFleetScopeHealthCard(
            title: 'Beta Watch',
            endpointLabel: '192.168.8.106',
            lastSeenLabel: 'idle',
            titleStyle: const TextStyle(fontSize: 13),
            endpointStyle: const TextStyle(fontSize: 10),
            lastSeenStyle: const TextStyle(fontSize: 11),
            noteStyle: const TextStyle(fontSize: 11),
            latestStyle: const TextStyle(fontSize: 11),
            statusDetailStyle: const TextStyle(fontSize: 10),
            primaryChips: const [],
            secondaryChips: const [],
            actionChildren: const [],
            decoration: const BoxDecoration(color: Colors.black12),
            constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Beta Watch'), findsOneWidget);
    expect(find.text('192.168.8.106'), findsOneWidget);
    expect(find.text('Last seen idle'), findsOneWidget);
    expect(find.textContaining('Latest:'), findsNothing);
    expect(find.text('Dispatch'), findsNothing);
  });
}
