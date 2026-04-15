import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'layout_breakpoints.dart';
import 'onyx_surface.dart';
import 'theme/onyx_design_tokens.dart';

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

  void _createNewVipDetail(BuildContext context) {
    if (onCreateDetail != null) {
      onCreateDetail!.call();
      return;
    }
    _showVipCreateDetailDialog(context);
  }

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
                    // Page header with CTA
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'VIP protection',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: OnyxColorTokens.textPrimary,
                              ),
                            ),
                            Text(
                              'High-value convoy tracking and close protection',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: OnyxColorTokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('New VIP detail'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: OnyxColorTokens.accentPurple,
                            foregroundColor: OnyxColorTokens.textPrimary,
                            minimumSize: const Size(0, 34),
                            textStyle: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: () => _createNewVipDetail(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (!hasScheduledDetails) ...[
                      _VipEmptyState(
                        onCreateDetail: () => _createNewVipDetail(context),
                      ),
                      const SizedBox(height: 18),
                    ],
                    // Scheduled VIP Details section
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          size: 14,
                          color: OnyxColorTokens.accentPurple,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'SCHEDULED VIP DETAILS',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: OnyxColorTokens.textMuted,
                            letterSpacing: 0.7,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Upcoming protection assignments',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: OnyxColorTokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (scheduledDetails.isEmpty)
                      _vipNoScheduledEmpty()
                    else
                      for (final detail in scheduledDetails)
                        _vipDetailCard(
                          detail: detail,
                          onReview: () {
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

  Widget _vipNoScheduledEmpty() {
    return Container(
      key: const ValueKey('vip-no-scheduled-details-state'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OnyxColorTokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No packages are queued.',
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Stage the next movement package to line up convoy, escort, and handoff.',
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vipDetailCard({
    required VipScheduledDetail detail,
    required VoidCallback onReview,
  }) {
    final labelUpper = detail.badgeLabel.toUpperCase();
    final isToday = labelUpper == 'TODAY';
    final isTomorrow = labelUpper == 'TOMORROW';
    final badgeLabel = isToday
        ? 'TODAY'
        : isTomorrow
        ? 'TOMORROW'
        : detail.badgeLabel;
    final badgeColor = isToday
        ? OnyxColorTokens.accentRed
        : isTomorrow
        ? OnyxColorTokens.accentAmber
        : OnyxColorTokens.accentPurple;

    // Pull the first three facts as time window / officers / route info,
    // mapping to the original VipDetailFact data rather than renaming fields.
    final facts = detail.facts;
    final timeFact = facts.isNotEmpty ? facts[0] : null;
    final officersFact = facts.length > 1 ? facts[1] : null;
    final routeFact = facts.length > 2 ? facts[2] : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onReview,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          key: ValueKey('vip-schedule-${_vipKeySegment(detail.title)}'),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: OnyxColorTokens.backgroundSecondary,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: OnyxColorTokens.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      detail.title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: OnyxColorTokens.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: badgeColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      badgeLabel,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: badgeColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                detail.subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: OnyxColorTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (timeFact != null) ...[
                    Icon(
                      timeFact.icon,
                      size: 13,
                      color: OnyxColorTokens.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeFact.label,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: OnyxColorTokens.textSecondary,
                      ),
                    ),
                  ],
                  if (officersFact != null) ...[
                    const SizedBox(width: 16),
                    Icon(
                      officersFact.icon,
                      size: 13,
                      color: OnyxColorTokens.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      officersFact.label,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: OnyxColorTokens.textSecondary,
                      ),
                    ),
                  ],
                  if (routeFact != null) ...[
                    const SizedBox(width: 16),
                    Icon(
                      routeFact.icon,
                      size: 13,
                      color: OnyxColorTokens.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      routeFact.label,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: OnyxColorTokens.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
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
          backgroundColor: OnyxColorTokens.backgroundSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: OnyxColorTokens.borderSubtle),
          ),
          title: Text(
            'Package Desk',
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textPrimary,
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
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.textSecondary,
                    height: 1.45,
                  ),
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
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OnyxColorTokens.divider),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: OnyxColorTokens.greenSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: OnyxColorTokens.greenBorder),
            ),
            child: Icon(
              Icons.shield_rounded,
              color: OnyxColorTokens.accentGreen,
              size: 32,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No active VIP details',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: OnyxColorTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'All VIP protection details have been completed.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: OnyxColorTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            key: const ValueKey('vip-create-detail-button'),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Create new VIP detail'),
            style: ElevatedButton.styleFrom(
              backgroundColor: OnyxColorTokens.accentGreen,
              foregroundColor: OnyxColorTokens.textPrimary,
              minimumSize: const Size(0, 40),
              textStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: onCreateDetail,
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
      style: GoogleFonts.inter(color: OnyxColorTokens.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        hintStyle: GoogleFonts.inter(color: OnyxColorTokens.textMuted),
        labelStyle: GoogleFonts.inter(color: OnyxColorTokens.textSecondary),
        filled: true,
        fillColor: OnyxColorTokens.surfaceElevated,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: OnyxColorTokens.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: OnyxColorTokens.accentGreen),
        ),
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
        backgroundColor: OnyxColorTokens.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: OnyxColorTokens.borderSubtle),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              detail.title,
              style: GoogleFonts.inter(
                color: OnyxColorTokens.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              detail.subtitle,
              style: GoogleFonts.inter(
                color: OnyxColorTokens.textSecondary,
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
                  color: OnyxColorTokens.textSecondary,
                  fontSize: 13,
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
        color: OnyxColorTokens.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OnyxColorTokens.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: OnyxColorTokens.accentGreen, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.textSecondary,
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
