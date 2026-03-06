import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../ui/onyx_surface.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return OnyxPageScaffold(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1540),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const OnyxPageHeader(
                  title: 'Reports Command Hub',
                  subtitle:
                      'Deterministic reporting, replay verification, and export readiness for client-facing intelligence packs.',
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1260
                        ? 3
                        : constraints.maxWidth >= 860
                        ? 2
                        : 1;
                    const spacing = 8.0;
                    final itemWidth =
                        (constraints.maxWidth - ((columns - 1) * spacing)) /
                        columns;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        SizedBox(
                          width: itemWidth,
                          child: const OnyxSummaryStat(
                            label: 'Report Modes',
                            value: '3',
                            accent: Color(0xFF63BDFF),
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: const OnyxSummaryStat(
                            label: 'Integrity State',
                            value: 'Ready',
                            accent: Color(0xFF59D79B),
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: const OnyxSummaryStat(
                            label: 'Export Paths',
                            value: 'PDF',
                            accent: Color(0xFFF6C067),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final stackVertically = constraints.maxWidth < 1360;

                      final generationFlowCard = OnyxSectionCard(
                        title: 'Report Generation Flow',
                        subtitle:
                            'Operational PDF generation, receipt hashing, and replay-safe validation are grouped here as one guided output path.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: const [
                                _LaneBadge(
                                  label: 'Build',
                                  detail: 'PDF bundle + receipt hash',
                                  accent: Color(0xFF63BDFF),
                                ),
                                _LaneBadge(
                                  label: 'Verify',
                                  detail: 'Replay-safe integrity check',
                                  accent: Color(0xFF59D79B),
                                ),
                                _LaneBadge(
                                  label: 'Release',
                                  detail: 'Client export handoff',
                                  accent: Color(0xFFF6C067),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _flowRow(
                              icon: Icons.picture_as_pdf_rounded,
                              title: 'Generate Deterministic PDF',
                              detail:
                                  'Build client intelligence reports from the current projection snapshot and preserve the exact content hash.',
                              accent: const Color(0xFF63BDFF),
                            ),
                            const SizedBox(height: 8),
                            _flowRow(
                              icon: Icons.verified_rounded,
                              title: 'Replay Verification',
                              detail:
                                  'Rebuild the same report from its receipt and confirm byte-level content integrity before delivery.',
                              accent: const Color(0xFF59D79B),
                            ),
                            const SizedBox(height: 10),
                            _flowRow(
                              icon: Icons.outbox_rounded,
                              title: 'Client Distribution',
                              detail:
                                  'Prepare export-ready report bundles for downstream client delivery, audit retention, and print review.',
                              accent: const Color(0xFFF6C067),
                            ),
                          ],
                        ),
                      );

                      final outputModulesCard = OnyxSectionCard(
                        title: 'Output Modules',
                        subtitle:
                            'The report system is organized into reusable output lanes so preview, audit, and delivery stay separate.',
                        child: LayoutBuilder(
                          builder: (context, moduleConstraints) {
                            final moduleColumns =
                                moduleConstraints.maxWidth >= 900 ? 3 : 1;
                            const spacing = 8.0;
                            final cardWidth =
                                (moduleConstraints.maxWidth -
                                    ((moduleColumns - 1) * spacing)) /
                                moduleColumns;
                            return Wrap(
                              spacing: spacing,
                              runSpacing: spacing,
                              children: [
                                SizedBox(
                                  width: cardWidth,
                                  child: const _ReportModeCard(
                                    icon: Icons.visibility_rounded,
                                    title: 'Preview',
                                    detail:
                                        'Inspect generated output before distribution.',
                                    accent: Color(0xFF63BDFF),
                                  ),
                                ),
                                SizedBox(
                                  width: cardWidth,
                                  child: const _ReportModeCard(
                                    icon: Icons.history_rounded,
                                    title: 'Receipts',
                                    detail:
                                        'Track replay receipts and integrity proofs.',
                                    accent: Color(0xFF59D79B),
                                  ),
                                ),
                                SizedBox(
                                  width: cardWidth,
                                  child: const _ReportModeCard(
                                    icon: Icons.share_rounded,
                                    title: 'Delivery',
                                    detail:
                                        'Prepare client-safe delivery and export.',
                                    accent: Color(0xFFF6C067),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      );

                      final readinessBoardCard = OnyxSectionCard(
                        title: 'Readiness Board',
                        subtitle:
                            'Use this board as the operator-facing checkpoint before generating or distributing any report.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _readinessTile(
                              title: 'Projection snapshot available',
                              detail:
                                  'Current reporting inputs are present for deterministic generation.',
                              color: const Color(0xFF59D79B),
                            ),
                            const SizedBox(height: 8),
                            _readinessTile(
                              title: 'Replay verification supported',
                              detail:
                                  'Receipts can be reopened and regenerated for integrity proof.',
                              color: const Color(0xFF63BDFF),
                            ),
                            const SizedBox(height: 8),
                            _readinessTile(
                              title: 'Client delivery surface pending',
                              detail:
                                  'Distribution workflow is staged and ready for client-surface handoff.',
                              color: const Color(0xFFF6C067),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF0B182B),
                                    Color(0xFF091423),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFF17324F),
                                ),
                              ),
                              child: Text(
                                'This hub now acts as the operator-facing command layer for generation, verification, and distribution readiness. The deeper preview and receipt-harness flows inherit the same structure below.',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF9BB0CE),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (stackVertically) {
                        return ListView(
                          children: [
                            generationFlowCard,
                            const SizedBox(height: 6),
                            outputModulesCard,
                            const SizedBox(height: 6),
                            readinessBoardCard,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 7,
                            child: Column(
                              children: [
                                Expanded(child: generationFlowCard),
                                const SizedBox(height: 6),
                                Expanded(child: outputModulesCard),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(flex: 4, child: readinessBoardCard),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _flowRow({
    required IconData icon,
    required String title,
    required String detail,
    required Color accent,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1830),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF193554)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.45)),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFE6F1FF),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF93A9C8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _readinessTile({
    required String title,
    required String detail,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B182C), Color(0xFF091424)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8DA3C1),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LaneBadge extends StatelessWidget {
  final String label;
  final String detail;
  final Color accent;

  const _LaneBadge({
    required this.label,
    required this.detail,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B182B), Color(0xFF091423)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: GoogleFonts.inter(
              color: const Color(0xFF91A7C7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final Color accent;

  const _ReportModeCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1830),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF193554)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent),
          const SizedBox(height: 6),
          Text(
            title,
            style: GoogleFonts.inter(
              color: const Color(0xFFE6F1FF),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: GoogleFonts.inter(
              color: const Color(0xFF93A9C8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
