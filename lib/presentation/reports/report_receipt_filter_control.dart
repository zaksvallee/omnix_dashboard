import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../application/report_generation_service.dart';
import '../../application/report_receipt_scene_filter.dart';

class ReportReceiptFilterControl extends StatelessWidget {
  final Key? dropdownKey;
  final ReportReceiptSceneFilter value;
  final ValueChanged<ReportReceiptSceneFilter> onChanged;
  final Iterable<ReportReceiptSceneReviewSummary?> summaries;
  final AlignmentGeometry? alignment;
  final Color iconEnabledColor;
  final Color textColor;
  final VoidCallback? onOpenFocusedReceipt;

  const ReportReceiptFilterControl({
    super.key,
    this.dropdownKey,
    required this.value,
    required this.onChanged,
    required this.summaries,
    this.alignment,
    required this.iconEnabledColor,
    required this.textColor,
    this.onOpenFocusedReceipt,
  });

  @override
  Widget build(BuildContext context) {
    final summaryList = summaries.toList(growable: false);
    final isActive = value != ReportReceiptSceneFilter.all;
    final selectedLabels = ReportReceiptSceneFilter.values
        .map(
          (filter) => filter == ReportReceiptSceneFilter.all
              ? filter.countLabel(summaryList)
              : filter.statusLabel,
        )
        .toList(growable: false);
    final backgroundColor = isActive
        ? value.activeBackgroundColor
        : const Color(0xFF10233A);
    final borderColor = isActive
        ? value.activeBorderColor
        : const Color(0xFF2A4768);
    final canOpenFocusedReceipt =
        value.isLatestActionFilter && onOpenFocusedReceipt != null;
    final control = Container(
      key: const ValueKey('report-receipt-filter-control-shell'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonHideUnderline(
            child: DropdownButton<ReportReceiptSceneFilter>(
              key: dropdownKey,
              value: value,
              onChanged: (next) {
                if (next != null) {
                  onChanged(next);
                }
              },
              dropdownColor: const Color(0xFF10233A),
              borderRadius: BorderRadius.circular(14),
              iconEnabledColor: iconEnabledColor,
              style: GoogleFonts.inter(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              items: ReportReceiptSceneFilter.values
                  .map(
                    (filter) => DropdownMenuItem<ReportReceiptSceneFilter>(
                      value: filter,
                      child: Text(filter.countLabel(summaryList)),
                    ),
                  )
                  .toList(growable: false),
              selectedItemBuilder: (context) => selectedLabels
                  .map((label) => Text(label))
                  .toList(growable: false),
            ),
          ),
          if (canOpenFocusedReceipt) ...[
            const SizedBox(width: 2),
            IconButton(
              key: const ValueKey('report-receipt-filter-control-open-focused'),
              onPressed: onOpenFocusedReceipt,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: const EdgeInsets.all(4),
              splashRadius: 16,
              iconSize: 16,
              color: textColor,
              tooltip: 'Open Focused Receipt',
              icon: const Icon(Icons.open_in_new_rounded),
            ),
          ],
        ],
      ),
    );

    if (alignment == null) {
      return control;
    }
    return Align(alignment: alignment!, child: control);
  }
}
