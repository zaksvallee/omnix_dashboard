import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/report_output_mode.dart';
import 'package:omnix_dashboard/application/report_preview_surface.dart';
import 'package:omnix_dashboard/application/report_receipt_scene_filter.dart';
import 'package:omnix_dashboard/application/report_shell_binding.dart';
import 'package:omnix_dashboard/application/report_shell_state.dart';

void main() {
  test('report shell binding seeds from shell state and round-trips back', () {
    const shellState = ReportShellState(
      receiptFilter: ReportReceiptSceneFilter.escalation,
      outputMode: ReportOutputMode.json,
      selectedReceiptEventId: 'RPT-1',
      previewReceiptEventId: 'RPT-2',
      previewSurface: ReportPreviewSurface.dock,
    );

    final binding = ReportShellBinding.fromShellState(shellState);
    final nextShellState = binding.toShellState(const ReportShellState());

    expect(nextShellState.receiptFilter, ReportReceiptSceneFilter.escalation);
    expect(nextShellState.outputMode, ReportOutputMode.json);
    expect(nextShellState.selectedReceiptEventId, 'RPT-1');
    expect(nextShellState.previewReceiptEventId, 'RPT-2');
    expect(nextShellState.previewSurface, ReportPreviewSurface.dock);
  });

  test(
    'report shell binding normalizes receipt ids when seeding from shell state',
    () {
      const shellState = ReportShellState(
        selectedReceiptEventId: '  RPT-1  ',
        previewReceiptEventId: '   ',
      );

      final binding = ReportShellBinding.fromShellState(shellState);

      expect(binding.selectedReceiptEventId, 'RPT-1');
      expect(binding.previewReceiptEventId, isNull);
    },
  );

  test('report shell binding syncs external widget updates', () {
    const oldShellState = ReportShellState(
      receiptFilter: ReportReceiptSceneFilter.all,
      outputMode: ReportOutputMode.pdf,
      selectedReceiptEventId: 'RPT-1',
      previewReceiptEventId: 'RPT-1',
      previewSurface: ReportPreviewSurface.route,
    );
    const newShellState = ReportShellState(
      receiptFilter: ReportReceiptSceneFilter.reviewed,
      outputMode: ReportOutputMode.excel,
      selectedReceiptEventId: null,
      previewReceiptEventId: 'RPT-2',
      previewSurface: ReportPreviewSurface.dock,
    );

    final binding = ReportShellBinding.fromShellState(oldShellState);
    final nextBinding = binding.syncFromWidget(
      oldShellState: oldShellState,
      newShellState: newShellState,
    );

    expect(nextBinding.receiptFilter, ReportReceiptSceneFilter.reviewed);
    expect(nextBinding.outputMode, ReportOutputMode.excel);
    expect(nextBinding.selectedReceiptEventId, isNull);
    expect(nextBinding.previewReceiptEventId, 'RPT-2');
    expect(nextBinding.previewSurface, ReportPreviewSurface.dock);
  });

  test('report shell binding copyWith trims and clears receipt ids', () {
    const binding = ReportShellBinding(
      receiptFilter: ReportReceiptSceneFilter.all,
      outputMode: ReportOutputMode.pdf,
      selectedReceiptEventId: 'RPT-1',
      previewReceiptEventId: 'RPT-2',
      previewSurface: ReportPreviewSurface.route,
    );

    final trimmed = binding.copyWith(
      selectedReceiptEventId: '  RPT-9  ',
      previewReceiptEventId: ' RPT-8 ',
    );
    expect(trimmed.selectedReceiptEventId, 'RPT-9');
    expect(trimmed.previewReceiptEventId, 'RPT-8');

    final cleared = binding.copyWith(
      selectedReceiptEventId: '   ',
      previewReceiptEventId: ' ',
    );
    expect(cleared.selectedReceiptEventId, isNull);
    expect(cleared.previewReceiptEventId, isNull);
  });

  test(
    'report shell binding ignores stale parent rebuild values that match local state',
    () {
      const oldShellState = ReportShellState(
        receiptFilter: ReportReceiptSceneFilter.all,
        outputMode: ReportOutputMode.pdf,
        selectedReceiptEventId: 'RPT-1',
        previewReceiptEventId: 'RPT-1',
        previewSurface: ReportPreviewSurface.route,
      );
      const staleParentState = ReportShellState(
        receiptFilter: ReportReceiptSceneFilter.reviewed,
        outputMode: ReportOutputMode.json,
        selectedReceiptEventId: 'RPT-9',
        previewReceiptEventId: 'RPT-9',
        previewSurface: ReportPreviewSurface.dock,
      );
      const localBinding = ReportShellBinding(
        receiptFilter: ReportReceiptSceneFilter.reviewed,
        outputMode: ReportOutputMode.json,
        selectedReceiptEventId: 'RPT-9',
        previewReceiptEventId: 'RPT-9',
        previewSurface: ReportPreviewSurface.dock,
      );

      final nextBinding = localBinding.syncFromWidget(
        oldShellState: oldShellState,
        newShellState: staleParentState,
      );

      expect(nextBinding, equals(localBinding));
    },
  );

  test(
    'report shell binding syncFromWidget can clear preview target without clearing focus',
    () {
      const oldShellState = ReportShellState(
        receiptFilter: ReportReceiptSceneFilter.all,
        outputMode: ReportOutputMode.pdf,
        selectedReceiptEventId: 'RPT-2',
        previewReceiptEventId: 'RPT-2',
        previewSurface: ReportPreviewSurface.route,
      );
      const newShellState = ReportShellState(
        receiptFilter: ReportReceiptSceneFilter.all,
        outputMode: ReportOutputMode.pdf,
        selectedReceiptEventId: 'RPT-2',
        previewReceiptEventId: null,
        previewSurface: ReportPreviewSurface.route,
      );

      final binding = ReportShellBinding.fromShellState(oldShellState);
      final nextBinding = binding.syncFromWidget(
        oldShellState: oldShellState,
        newShellState: newShellState,
      );

      expect(nextBinding.selectedReceiptEventId, 'RPT-2');
      expect(nextBinding.previewReceiptEventId, isNull);
    },
  );

  test('report shell binding toggles receipt filters back to all', () {
    const binding = ReportShellBinding(
      receiptFilter: ReportReceiptSceneFilter.reviewed,
      outputMode: ReportOutputMode.pdf,
      selectedReceiptEventId: null,
      previewReceiptEventId: null,
      previewSurface: ReportPreviewSurface.route,
    );

    expect(
      binding
          .toggledReceiptFilter(ReportReceiptSceneFilter.reviewed)
          .receiptFilter,
      ReportReceiptSceneFilter.all,
    );
    expect(
      binding
          .toggledReceiptFilter(ReportReceiptSceneFilter.pending)
          .receiptFilter,
      ReportReceiptSceneFilter.pending,
    );
  });

  test('report shell binding updates workspace focus and preview clearing', () {
    const binding = ReportShellBinding(
      receiptFilter: ReportReceiptSceneFilter.all,
      outputMode: ReportOutputMode.pdf,
      selectedReceiptEventId: null,
      previewReceiptEventId: null,
      previewSurface: ReportPreviewSurface.route,
    );

    final focused = binding.withReceiptWorkspaceFocus('RPT-9');
    expect(focused.selectedReceiptEventId, 'RPT-9');
    expect(focused.previewReceiptEventId, 'RPT-9');

    final trimmedFocus = binding.withReceiptWorkspaceFocus('  RPT-9  ');
    expect(trimmedFocus.selectedReceiptEventId, 'RPT-9');
    expect(trimmedFocus.previewReceiptEventId, 'RPT-9');

    final clearedFocus = focused.withReceiptWorkspaceFocus(null);
    expect(clearedFocus.selectedReceiptEventId, isNull);
    expect(clearedFocus.previewReceiptEventId, isNull);

    final clearedBlankFocus = focused.withReceiptWorkspaceFocus('   ');
    expect(clearedBlankFocus.selectedReceiptEventId, isNull);
    expect(clearedBlankFocus.previewReceiptEventId, isNull);

    final clearedPreview = focused.clearingPreviewTarget();
    expect(clearedPreview.selectedReceiptEventId, 'RPT-9');
    expect(clearedPreview.previewReceiptEventId, isNull);
  });

  test(
    'report shell binding prunes stale receipt context against available ids',
    () {
      const binding = ReportShellBinding(
        receiptFilter: ReportReceiptSceneFilter.all,
        outputMode: ReportOutputMode.pdf,
        selectedReceiptEventId: 'RPT-1',
        previewReceiptEventId: 'RPT-2',
        previewSurface: ReportPreviewSurface.route,
      );

      final unchanged = binding.prunedToReceiptIds(const {'RPT-1', 'RPT-2'});
      expect(unchanged, same(binding));

      final pruned = binding.prunedToReceiptIds(const {'RPT-2'});
      expect(pruned.selectedReceiptEventId, isNull);
      expect(pruned.previewReceiptEventId, 'RPT-2');
    },
  );

  test('report shell binding prunes against normalized receipt ids', () {
    const binding = ReportShellBinding(
      receiptFilter: ReportReceiptSceneFilter.all,
      outputMode: ReportOutputMode.pdf,
      selectedReceiptEventId: '  RPT-1  ',
      previewReceiptEventId: ' RPT-2 ',
      previewSurface: ReportPreviewSurface.route,
    );

    final unchanged = binding.prunedToReceiptIds(const {'  RPT-1 ', 'RPT-2  '});
    expect(unchanged, same(binding));

    final pruned = binding.prunedToReceiptIds(const {' RPT-1 '});
    expect(pruned.selectedReceiptEventId, '  RPT-1  ');
    expect(pruned.previewReceiptEventId, isNull);
  });
}
