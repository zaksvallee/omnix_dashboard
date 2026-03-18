import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/main.dart';
import 'package:omnix_dashboard/ui/app_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onyx app opens scoped reports from cleared dispatch action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? openedDispatchId;
    String? openedClientId;
    String? openedSiteId;

    await tester.pumpWidget(
      OnyxApp(
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.dispatches,
        onDispatchReportRouteOpened: (dispatchId, clientId, siteId) {
          openedDispatchId = dispatchId;
          openedClientId = clientId;
          openedSiteId = siteId;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DISPATCH COMMAND'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'VIEW REPORT').first);
    await tester.pumpAndSettle();

    expect(openedDispatchId, 'DSP-4');
    expect(openedClientId, 'CLIENT-MS-VALLEE');
    expect(openedSiteId, 'SITE-MS-VALLEE-RESIDENCE');
  });

  testWidgets('onyx app routes generate dispatch through shell callback', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var generateTriggeredCount = 0;

    await tester.pumpWidget(
      OnyxApp(
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.dispatches,
        onDispatchGenerateTriggered: () {
          generateTriggeredCount += 1;
        },
      ),
    );
    await tester.pumpAndSettle();

    final generateButton = find.widgetWithText(
      FilledButton,
      'Generate Dispatch',
    );
    await tester.ensureVisible(generateButton);
    await tester.tap(generateButton);
    await tester.pumpAndSettle();

    expect(generateTriggeredCount, 1);
  });

  testWidgets('onyx app derives dispatch scope from incident route seed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? openedClientId;
    String? openedSiteId;
    String? openedFocusReference;

    await tester.pumpWidget(
      OnyxApp(
        supabaseReady: false,
        initialRouteOverride: OnyxRoute.dispatches,
        initialDispatchIncidentReferenceOverride: 'DSP-4',
        onDispatchRouteOpened: (clientId, siteId, focusReference) {
          openedClientId = clientId;
          openedSiteId = siteId;
          openedFocusReference = focusReference;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DISPATCH COMMAND'), findsOneWidget);
    expect(openedClientId, 'CLIENT-MS-VALLEE');
    expect(openedSiteId, 'SITE-MS-VALLEE-RESIDENCE');
    expect(openedFocusReference, 'DSP-4');
    expect(find.textContaining('Focus Linked: DSP-4'), findsOneWidget);
  });
}
