import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'layout_breakpoints.dart';
import 'onyx_surface.dart';
import 'theme/onyx_design_tokens.dart';

const _vipSurfaceColor = Color(0xFF13131E);
const _vipSurfaceAltColor = Color(0xFF1A1A2E);
const _vipBorderColor = Color(0x269D4BFF);
const _vipStrongBorderColor = Color(0x4D9D4BFF);
const _vipTitleColor = Color(0xFFE8E8F0);
const _vipBodyColor = Color(0x80FFFFFF);
const _vipMutedColor = Color(0x4DFFFFFF);

class VipDetailFact {
  final IconData icon;
  final String title;
  final String label;

  const VipDetailFact({
    required this.icon,
    required this.title,
    required this.label,
  });
}

class VipScheduledDetail {
  final String title;
  final String subtitle;
  final String badgeLabel;
  final Color badgeBackground;
  final Color badgeForeground;
  final Color badgeBorder;
  final List<VipDetailFact> facts;

  const VipScheduledDetail({
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.badgeBackground,
    required this.badgeForeground,
    required this.badgeBorder,
    required this.facts,
  });
}

class VipAutoAuditReceipt {
  final String auditId;
  final String label;
  final String headline;
  final String detail;
  final Color accent;

  const VipAutoAuditReceipt({
    required this.auditId,
    required this.label,
    required this.headline,
    required this.detail,
    required this.accent,
  });
}

class VipProtectionPage extends StatelessWidget {
  final VoidCallback? onCreateDetail;
  final List<VipScheduledDetail> scheduledDetails;
  final ValueChanged<VipScheduledDetail>? onReviewScheduledDetail;
  final VipAutoAuditReceipt? latestAutoAuditReceipt;
  final VoidCallback? onOpenLatestAudit;

  const VipProtectionPage({
    super.key,
    this.onCreateDetail,
    this.scheduledDetails = const <VipScheduledDetail>[],
    this.onReviewScheduledDetail,
    this.latestAutoAuditReceipt,
    this.onOpenLatestAudit,
  });

  static const List<VipScheduledDetail> defaultScheduledDetails =
      <VipScheduledDetail>[];

  @override
  Widget build(BuildContext context) {
    final hasScheduledDetails = scheduledDetails.isNotEmpty;

    return OnyxPageScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final ultrawideSurface = isUltrawideLayout(
            context,
            viewportWidth: constraints.maxWidth,
          );
          final surfaceMaxWidth = commandSurfaceMaxWidth(
            context,
            compactDesktopWidth: 1500,
            viewportWidth: constraints.maxWidth,
            widescreenFillFactor: ultrawideSurface ? 1 : 0.95,
          );

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: surfaceMaxWidth),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'VIP Protection',
                          style: GoogleFonts.inter(
                            color: OnyxColorTokens.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: hasScheduledDetails
                                ? OnyxColorTokens.cyanSurface
                                : OnyxColorTokens.greenSurface,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: hasScheduledDetails
                                  ? OnyxColorTokens.cyanBorder
                                  : OnyxColorTokens.greenBorder,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: hasScheduledDetails
                                      ? OnyxColorTokens.accentCyanTrue
                                      : OnyxColorTokens.accentGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                hasScheduledDetails
                                    ? '${scheduledDetails.length} active'
                                    : 'No active details',
                                style: GoogleFonts.inter(
                                  color: hasScheduledDetails
                                      ? OnyxColorTokens.accentCyanTrue
                                      : OnyxColorTokens.accentGreen,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (latestAutoAuditReceipt != null) ...[
                      const SizedBox(height: 18),
                      _VipAuditReceipt(
                        receipt: latestAutoAuditReceipt!,
                        onOpenLatestAudit: onOpenLatestAudit,
                      ),
                    ],
                    const SizedBox(height: 18),
                    if (!hasScheduledDetails) ...[
                      _VipEmptyState(
                        onCreateDetail: () {
                          if (onCreateDetail != null) {
                            onCreateDetail!.call();
                            return;
                          }
                          _showVipCreateDetailDialog(context);
                        },
                      ),
                      const SizedBox(height: 18),
                    ],
                    _VipScheduledPanel(
                      details: scheduledDetails,
                      onReviewDetail: (detail) {
                        if (onReviewScheduledDetail != null) {
                          onReviewScheduledDetail!(detail);
                          return;
                        }
                        _showVipScheduleDetailDialog(context, detail);
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VipAuditReceipt extends StatelessWidget {
  final VipAutoAuditReceipt receipt;
  final VoidCallback? onOpenLatestAudit;

  const _VipAuditReceipt({required this.receipt, this.onOpenLatestAudit});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('vip-latest-audit-panel'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: _vipSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _vipBorderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LATEST COMMAND',
            style: GoogleFonts.inter(
              color: _vipMutedColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: receipt.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: receipt.accent.withValues(alpha: 0.45)),
            ),
            child: Text(
              receipt.label,
              style: GoogleFonts.inter(
                color: receipt.accent,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            receipt.headline,
            style: GoogleFonts.inter(
              color: _vipTitleColor,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 0.96,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            receipt.detail,
            style: GoogleFonts.inter(
              color: _vipBodyColor,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
          if (onOpenLatestAudit != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('vip-view-latest-audit-button'),
              onPressed: onOpenLatestAudit,
              icon: const Icon(Icons.verified_rounded, size: 16),
              label: const Text('View Audit'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF63E6A1),
                side: const BorderSide(color: Color(0xFF63E6A1)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                textStyle: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _showVipCreateDetailDialog(BuildContext context) async {
  final principalController = TextEditingController();
  final corridorController = TextEditingController();
  final startTimeController = TextEditingController(text: 'Tomorrow 07:30');
  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          key: const ValueKey('vip-create-detail-dialog'),
          backgroundColor: _vipSurfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: _vipBorderColor),
          ),
          title: Text(
            'Package Desk',
            style: GoogleFonts.inter(
              color: _vipTitleColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Open the package desk to line up the protectee, corridor, and handoff before assigning the convoy package.',
                  style: GoogleFonts.inter(color: _vipBodyColor, height: 1.45),
                ),
                const SizedBox(height: 16),
                _VipDraftField(
                  key: const ValueKey('vip-detail-principal-field'),
                  label: 'Protectee',
                  hintText: 'Principal name or code',
                  controller: principalController,
                ),
                const SizedBox(height: 12),
                _VipDraftField(
                  key: const ValueKey('vip-detail-corridor-field'),
                  label: 'Route Corridor',
                  hintText: 'Origin -> destination',
                  controller: corridorController,
                ),
                const SizedBox(height: 12),
                _VipDraftField(
                  key: const ValueKey('vip-detail-start-time-field'),
                  label: 'Start Time',
                  hintText: 'Tomorrow 07:30',
                  controller: startTimeController,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('vip-stage-detail-submit-button'),
              onPressed: () {
                final principal = principalController.text.trim().isEmpty
                    ? 'Protectee'
                    : principalController.text.trim();
                final corridor = corridorController.text.trim().isEmpty
                    ? 'selected corridor'
                    : corridorController.text.trim();
                final startTime = startTimeController.text.trim().isEmpty
                    ? 'next watch window'
                    : startTimeController.text.trim();
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  SnackBar(
                    content: Text(
                      'Staged VIP detail for $principal on $corridor at $startTime.',
                    ),
                  ),
                );
              },
              child: const Text('Stage Detail'),
            ),
          ],
        );
      },
    );
  } finally {
    principalController.dispose();
    corridorController.dispose();
    startTimeController.dispose();
  }
}

class _VipEmptyState extends StatelessWidget {
  final VoidCallback onCreateDetail;

  const _VipEmptyState({required this.onCreateDetail});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('vip-empty-state'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 36),
      decoration: BoxDecoration(
        color: _vipSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _vipStrongBorderColor),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _vipStrongBorderColor),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Color(0xFF9D4BFF),
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Live VIP Run',
            style: GoogleFonts.inter(
              color: _vipTitleColor,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Board clear. Stage the next package before movement starts.',
            style: GoogleFonts.inter(
              color: _vipBodyColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const ValueKey('vip-create-detail-button'),
            onPressed: onCreateDetail,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Open Package Desk'),
            style: FilledButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF9D4BFF),
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              textStyle: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VipDraftField extends StatelessWidget {
  final String label;
  final String hintText;
  final TextEditingController controller;

  const _VipDraftField({
    super.key,
    required this.label,
    required this.hintText,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: GoogleFonts.inter(color: _vipTitleColor),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        hintStyle: GoogleFonts.inter(color: _vipMutedColor),
        labelStyle: GoogleFonts.inter(color: _vipBodyColor),
        filled: true,
        fillColor: _vipSurfaceAltColor,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _vipBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF218B5A)),
        ),
      ),
    );
  }
}

class _VipScheduledPanel extends StatelessWidget {
  final List<VipScheduledDetail> details;
  final ValueChanged<VipScheduledDetail> onReviewDetail;

  const _VipScheduledPanel({
    required this.details,
    required this.onReviewDetail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('vip-scheduled-panel'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: _vipSurfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _vipBorderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _vipBorderColor)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  color: Color(0xFF54C8FF),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NEXT MOVES',
                        style: GoogleFonts.inter(
                          color: _vipTitleColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.9,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Packages waiting for package review and route handoff',
                        style: GoogleFonts.inter(
                          color: _vipMutedColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: details.isEmpty
                ? const _VipNoScheduledDetailsState()
                : Column(
                    children: [
                      for (var i = 0; i < details.length; i++) ...[
                        _VipScheduleCard(
                          key: ValueKey(
                            'vip-schedule-${_vipKeySegment(details[i].title)}',
                          ),
                          detail: details[i],
                          onReviewDetail: () => onReviewDetail(details[i]),
                        ),
                        if (i != details.length - 1) const SizedBox(height: 12),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _VipScheduleCard extends StatelessWidget {
  final VipScheduledDetail detail;
  final VoidCallback onReviewDetail;

  const _VipScheduleCard({
    super.key,
    required this.detail,
    required this.onReviewDetail,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onReviewDetail,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: Color.lerp(_vipSurfaceColor, detail.badgeForeground, 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: detail.badgeForeground.withValues(alpha: 0.26),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: detail.badgeBackground,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: detail.badgeBorder),
                    ),
                    child: Text(
                      detail.badgeLabel,
                      style: GoogleFonts.inter(
                        color: detail.badgeForeground,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detail.title,
                          style: GoogleFonts.inter(
                            color: _vipTitleColor,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            height: 0.96,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          detail.subtitle,
                          style: GoogleFonts.inter(
                            color: _vipBodyColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _vipSurfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: detail.badgeForeground.withValues(alpha: 0.24),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Priority',
                      style: GoogleFonts.inter(
                        color: detail.badgeForeground,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'OPEN PACKAGE REVIEW',
                      style: GoogleFonts.inter(
                        color: _vipMutedColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 760;
                  final children = detail.facts
                      .map((fact) => _VipScheduleFactTile(fact: fact))
                      .toList(growable: false);
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < children.length; i++) ...[
                          children[i],
                          if (i != children.length - 1)
                            const SizedBox(height: 10),
                        ],
                      ],
                    );
                  }
                  return Row(
                    children: [
                      for (var i = 0; i < children.length; i++) ...[
                        Expanded(child: children[i]),
                        if (i != children.length - 1) const SizedBox(width: 16),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: onReviewDetail,
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('OPEN PACKAGE REVIEW'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2A6F8A),
                    side: const BorderSide(color: Color(0xFFBED8F2)),
                    backgroundColor: const Color(0xFFEAF4FF),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    textStyle: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VipScheduleFactTile extends StatelessWidget {
  final VipDetailFact fact;

  const _VipScheduleFactTile({required this.fact});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(fact.icon, color: const Color(0xFF7E93AE), size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            fact.label,
            style: GoogleFonts.inter(
              color: _vipTitleColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _VipNoScheduledDetailsState extends StatelessWidget {
  const _VipNoScheduledDetailsState();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('vip-no-scheduled-details-state'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: _vipSurfaceAltColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _vipBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No packages are queued.',
            style: GoogleFonts.inter(
              color: _vipTitleColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Stage the next movement package to line up convoy, escort, and handoff.',
            style: GoogleFonts.inter(
              color: _vipBodyColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showVipScheduleDetailDialog(
  BuildContext context,
  VipScheduledDetail detail,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        key: const ValueKey('vip-schedule-detail-dialog'),
        backgroundColor: _vipSurfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _vipBorderColor),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              detail.title,
              style: GoogleFonts.inter(
                color: _vipTitleColor,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                height: 0.96,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              detail.subtitle,
              style: GoogleFonts.inter(
                color: _vipBodyColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: detail.badgeBackground,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: detail.badgeBorder),
                ),
                child: Text(
                  detail.badgeLabel,
                  style: GoogleFonts.inter(
                    color: detail.badgeForeground,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Open the package review, confirm the assignment facts, then hand the package off to the protection team.',
                style: GoogleFonts.inter(
                  color: _vipBodyColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < detail.facts.length; i++) ...[
                _VipDialogNote(
                  icon: detail.facts[i].icon,
                  label: detail.facts[i].title,
                  value: detail.facts[i].label,
                ),
                if (i != detail.facts.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Acknowledge'),
          ),
        ],
      );
    },
  );
}

class _VipDialogNote extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _VipDialogNote({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _vipSurfaceAltColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _vipBorderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF5BE2A3), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: _vipTitleColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    color: _vipBodyColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
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
}

String _vipKeySegment(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
