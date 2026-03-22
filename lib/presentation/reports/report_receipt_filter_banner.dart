import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../application/report_receipt_scene_filter.dart';

class ReportReceiptFilterBanner extends StatelessWidget {
  final ReportReceiptSceneFilter filter;
  final int filteredRows;
  final int totalRows;
  final VoidCallback onShowAll;
  final VoidCallback? onOpenFocusedReceipt;
  final VoidCallback? onCopyFocusedReceipt;

  const ReportReceiptFilterBanner({
    super.key,
    required this.filter,
    required this.filteredRows,
    required this.totalRows,
    required this.onShowAll,
    this.onOpenFocusedReceipt,
    this.onCopyFocusedReceipt,
  });

  @override
  Widget build(BuildContext context) {
    final title = Text(
      '${filter.viewingLabel} ($filteredRows/$totalRows)',
      style: GoogleFonts.inter(
        color: const Color(0xFFE8F1FF),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
    final actions = Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        if (filter.isLatestActionFilter && onOpenFocusedReceipt != null)
          TextButton(
            onPressed: onOpenFocusedReceipt,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE8F1FF),
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Open Focused Receipt'),
          ),
        if (filter.isLatestActionFilter && onCopyFocusedReceipt != null)
          TextButton(
            onPressed: onCopyFocusedReceipt,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE8F1FF),
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Copy Focused Receipt'),
          ),
        TextButton(
          onPressed: onShowAll,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF8FCBFF),
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Show All'),
        ),
      ],
    );

    return Container(
      key: const ValueKey('report-receipt-filter-banner-shell'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: filter.bannerBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: filter.bannerBorderColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useStackedLayout =
              constraints.maxWidth < 760 &&
              (onOpenFocusedReceipt != null || onCopyFocusedReceipt != null);
          if (useStackedLayout) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 6),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: title),
              actions,
            ],
          );
        },
      ),
    );
  }
}
