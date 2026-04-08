import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../ui/components/onyx_status_banner.dart';
import '../ui/onyx_surface.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final verifiedReportCount = kDebugMode ? 2 : 0;
    final pendingReportCount = kDebugMode ? 1 : 0;
    final failedReportCount = kDebugMode ? 1 : 0;
    return OnyxPageScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1540),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heroHeader(context),
                const SizedBox(height: 8),
                OnyxPageHeader(
                  title: 'Reports Command Hub',
                  subtitle: 'Intelligence and operational reports.',
                  icon: Icons.description_rounded,
                  iconColor: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 8),
                OnyxStatusBanner(
                  message: pendingReportCount > 0
                      ? '$pendingReportCount reports pending'
                      : 'No reports pending',
                  severity: pendingReportCount > 0
                      ? OnyxSeverity.info
                      : OnyxSeverity.success,
                ),
                const SizedBox(height: 8),
                _statusSummaryBar(
                  verifiedReportCount: verifiedReportCount,
                  pendingReportCount: pendingReportCount,
                  failedReportCount: failedReportCount,
                ),
                const SizedBox(height: 8),
                _overviewGrid(),
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stackVertically = constraints.maxWidth < 1500;

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
                              color: const Color(0xFF0E1A2B),
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
                      return Column(
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
                              generationFlowCard,
                              const SizedBox(height: 6),
                              outputModulesCard,
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(flex: 4, child: readinessBoardCard),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF161B34), Color(0xFF111626)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2A3150)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 920;
          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reports & Documentation',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFF6FBFF),
                            fontSize: compact ? 22 : 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sovereign reporting, incident documentation, and evidence compilation.',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF95A9C7),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _heroChip('Report View', 'Workbench'),
                  _heroChip('Preview', 'Ready'),
                  _heroChip('Verification', 'Receipts Online'),
                  _heroChip('Scope', 'Internal + Partner'),
                ],
              ),
            ],
          );
          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.end,
            children: [
              _heroActionButton(
                key: const ValueKey('reports-view-governance-button'),
                icon: Icons.open_in_new,
                label: 'View Governance',
                accent: const Color(0xFF93C5FD),
                onPressed: () => _showGovernanceLinkDialog(context),
              ),
              _heroActionButton(
                key: const ValueKey('reports-generate-report-button'),
                icon: Icons.auto_awesome_outlined,
                label: 'Generate New Report',
                accent: const Color(0xFFA78BFA),
                onPressed: () => _showGenerateReportDialog(context),
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                const SizedBox(height: 16),
                actions,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: titleBlock),
              const SizedBox(width: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: actions,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _heroChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x14000000),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x33000000)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: GoogleFonts.inter(
                color: const Color(0xFF8EA4C2),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: GoogleFonts.inter(
                color: const Color(0xFFE8F1FF),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroActionButton({
    required Key key,
    required IconData icon,
    required String label,
    required Color accent,
    required VoidCallback onPressed,
  }) {
    return FilledButton.tonalIcon(
      key: key,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: accent.withValues(alpha: 0.12),
        foregroundColor: accent,
        side: BorderSide(color: accent.withValues(alpha: 0.28)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        textStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _statusSummaryBar({
    required int verifiedReportCount,
    required int pendingReportCount,
    required int failedReportCount,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1524),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF25304A)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'REPORT STATUS',
            style: GoogleFonts.inter(
              color: const Color(0x669BB0CE),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          _statusPill(
            icon: Icons.check_circle_outline,
            label: '$verifiedReportCount Verified',
            accent: const Color(0xFF34D399),
          ),
          _statusPill(
            icon: Icons.schedule,
            label: '$pendingReportCount Pending',
            accent: const Color(0xFFF6C067),
          ),
          _statusPill(
            icon: Icons.error_outline,
            label: '$failedReportCount Failed',
            accent: const Color(0xFFF87171),
          ),
          _statusPill(
            icon: Icons.groups_rounded,
            label: 'Partner Scope Ready',
            accent: const Color(0xFFA78BFA),
          ),
        ],
      ),
    );
  }

  Widget _statusPill({
    required IconData icon,
    required String label,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1200
            ? 4
            : constraints.maxWidth >= 760
            ? 2
            : 1;
        final aspectRatio = columns == 4
            ? 1.9
            : columns == 2
            ? 2.35
            : 2.5;
        return GridView.count(
          key: const ValueKey('reports-overview-grid'),
          crossAxisCount: columns,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: aspectRatio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: const [
            _ReportOverviewCard(
              title: 'Morning Sovereign',
              value: '12',
              detail: 'Incidents linked into the current internal report pack.',
              icon: Icons.wb_twilight_outlined,
              accent: Color(0xFF63BDFF),
            ),
            _ReportOverviewCard(
              title: 'Evidence Chain',
              value: '89',
              detail: 'Evidence items ready for receipt hashing and preview.',
              icon: Icons.account_tree_outlined,
              accent: Color(0xFF59D79B),
            ),
            _ReportOverviewCard(
              title: 'Partner Scope',
              value: '3',
              detail: 'Partner handoff outputs are verified and queued.',
              icon: Icons.groups_rounded,
              accent: Color(0xFFA78BFA),
            ),
            _ReportOverviewCard(
              title: 'Preview State',
              value: 'Ready',
              detail: 'Preview, receipts, and delivery modules are available.',
              icon: Icons.visibility_outlined,
              accent: Color(0xFFF6C067),
            ),
          ],
        );
      },
    );
  }

  void _showGovernanceLinkDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111827),
          title: Text(
            'Governance Link Ready',
            style: GoogleFonts.inter(
              color: const Color(0xFFF6FBFF),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Use Governance to review blockers, sovereign readiness, and partner-chain context before finalizing report distribution.',
            style: GoogleFonts.inter(
              color: const Color(0xFFD6E2F2),
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showGenerateReportDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111827),
          title: Text(
            'Generate New Report',
            style: GoogleFonts.inter(
              color: const Color(0xFFF6FBFF),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dialogLane(
                title: 'Morning Sovereign',
                detail: 'Build the current internal shift report with receipt verification.',
                accent: const Color(0xFF63BDFF),
              ),
              const SizedBox(height: 10),
              _dialogLane(
                title: 'Incident Pack',
                detail: 'Prepare a scoped incident report with linked evidence and replay context.',
                accent: const Color(0xFF59D79B),
              ),
              const SizedBox(height: 10),
              _dialogLane(
                title: 'Partner Scope',
                detail: 'Generate a partner-facing handoff report with delivery-safe sections.',
                accent: const Color(0xFFA78BFA),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Report generation staged for command review.',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                  ),
                );
              },
              child: const Text('Start Generation'),
            ),
          ],
        );
      },
    );
  }

  Widget _dialogLane({
    required String title,
    required String detail,
    required Color accent,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: accent,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: GoogleFonts.inter(
              color: const Color(0xFFD6E2F2),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
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
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F3855)),
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
        color: const Color(0xFF0E1A2B),
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
        color: const Color(0xFF0E1A2B),
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

class _ReportOverviewCard extends StatelessWidget {
  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final Color accent;

  const _ReportOverviewCard({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const Spacer(),
              Text(
                value,
                style: GoogleFonts.robotoMono(
                  color: const Color(0xFFF4F8FF),
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              color: const Color(0xFF93A5BF),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: const Color(0xFFD5E1F2),
              fontSize: 12,
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
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F3855)),
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
