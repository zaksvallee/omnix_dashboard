import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../ui/onyx_surface.dart';

class ReportPreviewDockCard extends StatelessWidget {
  final String eventId;
  final String detail;
  final String? title;
  final String? subtitle;
  final String? contextTitle;
  final String? contextDetail;
  final List<Widget> statusPills;
  final Widget primaryAction;
  final Widget secondaryAction;
  final Widget? tertiaryAction;
  final Widget? quaternaryAction;

  const ReportPreviewDockCard({
    super.key,
    required this.eventId,
    required this.detail,
    this.title,
    this.subtitle,
    this.contextTitle,
    this.contextDetail,
    required this.statusPills,
    required this.primaryAction,
    required this.secondaryAction,
    this.tertiaryAction,
    this.quaternaryAction,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedEventId = eventId.trim();
    final normalizedDetail = detail.trim();
    final normalizedTitle = title?.trim() ?? '';
    final normalizedSubtitle = subtitle?.trim() ?? '';
    final normalizedContextTitle = contextTitle?.trim() ?? '';
    final normalizedContextDetail = contextDetail?.trim() ?? '';
    final hasContext =
        normalizedContextTitle.isNotEmpty || normalizedContextDetail.isNotEmpty;
    return OnyxSectionCard(
      title: normalizedTitle.isEmpty ? 'Preview Dock' : normalizedTitle,
      subtitle: normalizedSubtitle.isEmpty
          ? 'Shell-driven preview target held in the report workspace.'
          : normalizedSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasContext) ...[
            Container(
              key: const ValueKey('report-preview-dock-context-banner'),
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF102337),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF29425F)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (normalizedContextTitle.isNotEmpty)
                    Text(
                      normalizedContextTitle,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8FD1FF),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  if (normalizedContextDetail.isNotEmpty) ...[
                    if (normalizedContextTitle.isNotEmpty)
                      const SizedBox(height: 4),
                    Text(
                      normalizedContextDetail,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFE8F1FF),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
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
          Wrap(spacing: 8, runSpacing: 8, children: statusPills),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(width: 220, child: primaryAction),
              SizedBox(width: 220, child: secondaryAction),
              if (tertiaryAction != null)
                SizedBox(width: 220, child: tertiaryAction!),
              if (quaternaryAction != null)
                SizedBox(width: 220, child: quaternaryAction!),
            ],
          ),
        ],
      ),
    );
  }
}
