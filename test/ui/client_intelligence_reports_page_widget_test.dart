import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/store/in_memory_event_store.dart';
import 'package:omnix_dashboard/ui/client_intelligence_reports_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('client reports export all button is actionable', (tester) async {
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          clipboardText = args['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ClientIntelligenceReportsPage(
          store: InMemoryEventStore(),
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final exportAllButton = find.byKey(
      const ValueKey('reports-export-all-button'),
    );
    await tester.ensureVisible(exportAllButton);
    await tester.tap(exportAllButton);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Exported 3 receipt records to clipboard.'),
      findsWidgets,
    );
    expect(clipboardText, isNotNull);
    expect(clipboardText, contains('"eventId": "RPT-2024-03-10-001"'));
  });

  testWidgets('sample receipt preview and download actions are actionable', (
    tester,
  ) async {
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          clipboardText = args['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ClientIntelligenceReportsPage(
          store: InMemoryEventStore(),
          selectedClient: 'CLIENT-001',
          selectedSite: 'SITE-SANDTON',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final previewButton = find.byKey(
      const ValueKey('report-receipt-preview-RPT-2024-03-10-001'),
    );
    await tester.ensureVisible(previewButton);
    await tester.tap(previewButton);
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Sample receipt preview unavailable. Generate a live report first.',
      ),
      findsWidgets,
    );

    final downloadButton = find.byKey(
      const ValueKey('report-receipt-download-RPT-2024-03-10-001'),
    );
    await tester.ensureVisible(downloadButton);
    await tester.tap(downloadButton);
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Sample receipt metadata copied for RPT-2024-03-10-001.',
      ),
      findsWidgets,
    );
    expect(clipboardText, isNotNull);
    expect(clipboardText, contains('"eventId": "RPT-2024-03-10-001"'));
  });
}
