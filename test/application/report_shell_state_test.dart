import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/report_output_mode.dart';
import 'package:omnix_dashboard/application/report_preview_surface.dart';
import 'package:omnix_dashboard/application/report_receipt_scene_filter.dart';
import 'package:omnix_dashboard/application/report_shell_state.dart';

void main() {
  test('report shell state defaults to all receipts', () {
    const state = ReportShellState();

    expect(state.receiptFilter, ReportReceiptSceneFilter.all);
    expect(state.outputMode, ReportOutputMode.pdf);
    expect(state.previewSurface, ReportPreviewSurface.route);
  });

  test('report shell state copyWith updates receipt filter', () {
    const state = ReportShellState();

    final next = state.copyWith(
      receiptFilter: ReportReceiptSceneFilter.escalation,
    );

    expect(next.receiptFilter, ReportReceiptSceneFilter.escalation);
    expect(state.receiptFilter, ReportReceiptSceneFilter.all);
  });

  test('report shell state copyWith updates output mode', () {
    const state = ReportShellState();

    final next = state.copyWith(outputMode: ReportOutputMode.json);

    expect(next.outputMode, ReportOutputMode.json);
    expect(state.outputMode, ReportOutputMode.pdf);
  });

  test('report shell state copyWith updates selected receipt focus', () {
    const state = ReportShellState();

    final next = state.copyWith(selectedReceiptEventId: 'RPT-001');

    expect(next.selectedReceiptEventId, 'RPT-001');
    expect(state.selectedReceiptEventId, isNull);
  });

  test('report shell state copyWith trims selected receipt focus', () {
    const state = ReportShellState();

    final next = state.copyWith(selectedReceiptEventId: '  RPT-001  ');

    expect(next.selectedReceiptEventId, 'RPT-001');
  });

  test('report shell state copyWith can clear selected receipt focus', () {
    const state = ReportShellState(selectedReceiptEventId: 'RPT-001');

    final next = state.copyWith(clearSelectedReceiptEventId: true);

    expect(next.selectedReceiptEventId, isNull);
  });

  test('report shell state copyWith clears blank selected receipt focus', () {
    const state = ReportShellState(selectedReceiptEventId: 'RPT-001');

    final next = state.copyWith(selectedReceiptEventId: '   ');

    expect(next.selectedReceiptEventId, isNull);
  });

  test('report shell state copyWith updates preview receipt target', () {
    const state = ReportShellState();

    final next = state.copyWith(previewReceiptEventId: 'RPT-001');

    expect(next.previewReceiptEventId, 'RPT-001');
    expect(state.previewReceiptEventId, isNull);
  });

  test('report shell state copyWith trims preview receipt target', () {
    const state = ReportShellState();

    final next = state.copyWith(previewReceiptEventId: '  RPT-001  ');

    expect(next.previewReceiptEventId, 'RPT-001');
  });

  test('report shell state copyWith can clear preview receipt target', () {
    const state = ReportShellState(previewReceiptEventId: 'RPT-001');

    final next = state.copyWith(clearPreviewReceiptEventId: true);

    expect(next.previewReceiptEventId, isNull);
  });

  test('report shell state copyWith clears blank preview receipt target', () {
    const state = ReportShellState(previewReceiptEventId: 'RPT-001');

    final next = state.copyWith(previewReceiptEventId: '   ');

    expect(next.previewReceiptEventId, isNull);
  });

  test('report shell state copyWith updates preview surface', () {
    const state = ReportShellState();

    final next = state.copyWith(previewSurface: ReportPreviewSurface.dock);

    expect(next.previewSurface, ReportPreviewSurface.dock);
    expect(state.previewSurface, ReportPreviewSurface.route);
  });
}
