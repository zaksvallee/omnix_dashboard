import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../application/report_preview_surface.dart';

class ReportPreviewTargetBanner extends StatelessWidget {
  final String eventId;
  final ReportPreviewSurface previewSurface;
  final Color surfaceLabelColor;
  final VoidCallback? onOpen;
  final VoidCallback? onCopy;
  final VoidCallback onClear;
  final Key? openButtonKey;
  final Key? copyButtonKey;
  final Key? clearButtonKey;

  const ReportPreviewTargetBanner({
    super.key,
    required this.eventId,
    required this.previewSurface,
    required this.surfaceLabelColor,
    this.onOpen,
    this.onCopy,
    required this.onClear,
    this.openButtonKey,
    this.copyButtonKey,
    this.clearButtonKey,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedEventId = eventId.trim();
    final targetLabel = normalizedEventId.isEmpty
        ? 'Pending target'
        : normalizedEventId;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF10233A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A587D)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Preview target: $targetLabel',
              style: GoogleFonts.inter(
                color: const Color(0xFFE8F1FF),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            previewSurface == ReportPreviewSurface.dock ? 'Docked' : 'Route',
            style: GoogleFonts.inter(
              color: surfaceLabelColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          if (onOpen != null) ...[
            TextButton(
              key: openButtonKey,
              onPressed: onOpen,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFE8F1FF),
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Open'),
            ),
            const SizedBox(width: 4),
          ],
          if (onCopy != null) ...[
            TextButton(
              key: copyButtonKey,
              onPressed: onCopy,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFE8F1FF),
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Copy'),
            ),
            const SizedBox(width: 4),
          ],
          TextButton(
            key: clearButtonKey,
            onPressed: onClear,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF8FCBFF),
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
