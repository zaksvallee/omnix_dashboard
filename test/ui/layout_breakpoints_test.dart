import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/ui/layout_breakpoints.dart';

void main() {
  Future<bool?> evaluateAtSize(WidgetTester tester, Size size) async {
    bool? result;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData(size: size),
          child: Builder(
            builder: (context) {
              result = allowEmbeddedPanelScroll(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return result;
  }

  testWidgets('allowEmbeddedPanelScroll true on large desktop viewport', (
    tester,
  ) async {
    final result = await evaluateAtSize(tester, const Size(1366, 900));
    expect(result, isTrue);
  });

  testWidgets('allowEmbeddedPanelScroll false on short-height viewport', (
    tester,
  ) async {
    final result = await evaluateAtSize(tester, const Size(1366, 720));
    expect(result, isFalse);
  });

  testWidgets('allowEmbeddedPanelScroll false on handset width', (
    tester,
  ) async {
    final result = await evaluateAtSize(tester, const Size(820, 1280));
    expect(result, isFalse);
  });
}
