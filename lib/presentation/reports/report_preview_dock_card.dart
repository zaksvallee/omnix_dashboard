import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../ui/onyx_surface.dart';

class ReportPreviewDockCard extends StatelessWidget {
  final String eventId;
  final String detail;
  final List<Widget> statusPills;
  final Widget primaryAction;
  final Widget secondaryAction;
  final Widget? tertiaryAction;

  const ReportPreviewDockCard({
    super.key,
    required this.eventId,
    required this.detail,
    required this.statusPills,
    required this.primaryAction,
    required this.secondaryAction,
    this.tertiaryAction,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedEventId = eventId.trim();
    final normalizedDetail = detail.trim();
    return OnyxSectionCard(
      title: 'Preview Dock',
      subtitle: 'Shell-driven preview target held in the report workspace.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            normalizedEventId.isEmpty ? 'Pending target' : normalizedEventId,
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFE8F1FF),
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            normalizedDetail.isEmpty
                ? 'Awaiting receipt detail.'
                : normalizedDetail,
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: statusPills,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(width: 220, child: primaryAction),
              SizedBox(width: 220, child: secondaryAction),
              if (tertiaryAction != null)
                SizedBox(width: 220, child: tertiaryAction!),
            ],
          ),
        ],
      ),
    );
  }
}
