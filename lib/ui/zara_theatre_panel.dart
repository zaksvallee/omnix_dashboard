import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../application/zara/theatre/zara_action.dart';
import '../application/zara/theatre/zara_scenario.dart';
import '../application/zara/theatre/zara_theatre_orchestrator.dart';
import 'theme/onyx_design_tokens.dart';

class ZaraTheatrePanel extends StatefulWidget {
  final ZaraTheatreOrchestrator orchestrator;

  const ZaraTheatrePanel({super.key, required this.orchestrator});

  @override
  State<ZaraTheatrePanel> createState() => _ZaraTheatrePanelState();
}

class _ZaraTheatrePanelState extends State<ZaraTheatrePanel>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _submitInput() async {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.orchestrator.activeScenario == null) {
      return;
    }
    await widget.orchestrator.submitControllerInput(text);
    if (!mounted) {
      return;
    }
    _controller.clear();
  }

  Future<void> _editAction(ZaraAction action) async {
    final payload = action.payload;
    final initialText = payload is ZaraClientMessagePayload
        ? payload.draftText
        : action.label;
    final editController = TextEditingController(text: initialText);
    try {
      final edited = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: OnyxColorTokens.backgroundSecondary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(OnyxRadiusTokens.lg),
              side: BorderSide(
                color: OnyxColorTokens.brand.withValues(alpha: 0.24),
              ),
            ),
            title: Text(
              'Edit ${action.label}',
              style: GoogleFonts.inter(
                color: OnyxColorTokens.textPrimary,
                fontSize: OnyxTypographyTokens.titleMd,
                fontWeight: OnyxTypographyTokens.semibold,
              ),
            ),
            content: SizedBox(
              width: 460,
              child: TextField(
                controller: editController,
                autofocus: true,
                maxLines: 6,
                style: GoogleFonts.inter(
                  color: OnyxColorTokens.textPrimary,
                  fontSize: OnyxTypographyTokens.bodyMd,
                ),
                decoration: InputDecoration(
                  hintText: 'Tell Zara how to refine this action…',
                  hintStyle: GoogleFonts.inter(
                    color: OnyxColorTokens.textMuted,
                    fontSize: OnyxTypographyTokens.bodySm,
                  ),
                  filled: true,
                  fillColor: OnyxColorTokens.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(OnyxRadiusTokens.md),
                    borderSide: BorderSide(
                      color: OnyxColorTokens.brand.withValues(alpha: 0.18),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(OnyxRadiusTokens.md),
                    borderSide: BorderSide(
                      color: OnyxColorTokens.brand.withValues(alpha: 0.18),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(OnyxRadiusTokens.md),
                    borderSide: const BorderSide(color: OnyxColorTokens.brand),
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.textSecondary,
                    fontWeight: OnyxTypographyTokens.medium,
                  ),
                ),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop(editController.text.trim());
                },
                style: FilledButton.styleFrom(
                  backgroundColor: OnyxColorTokens.brand,
                  foregroundColor: OnyxColorTokens.textPrimary,
                ),
                child: const Text('Apply'),
              ),
            ],
          );
        },
      );
      if (edited == null || edited.trim().isEmpty) {
        return;
      }
      await widget.orchestrator.submitControllerInput(
        'Update ${action.label} to say: ${edited.trim()}',
      );
    } finally {
      editController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.orchestrator, _pulseController]),
      builder: (context, _) {
        final scenario = widget.orchestrator.activeScenario;
        return Container(
          padding: const EdgeInsets.all(OnyxSpacingTokens.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                OnyxColorTokens.backgroundSecondary,
                OnyxColorTokens.surfaceElevated,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(OnyxRadiusTokens.panel),
            border: Border.all(
              color: OnyxColorTokens.brand.withValues(alpha: 0.24),
            ),
            boxShadow: [
              BoxShadow(
                color: OnyxColorTokens.brand.withValues(alpha: 0.12),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _speechZone(scenario),
              const SizedBox(height: OnyxSpacingTokens.lg),
              _actionsZone(scenario),
              const SizedBox(height: OnyxSpacingTokens.lg),
              _inputZone(scenario),
            ],
          ),
        );
      },
    );
  }

  Widget _speechZone(ZaraScenario? scenario) {
    final speech = scenario?.summary.trim().isNotEmpty == true
        ? scenario!.summary.trim()
        : 'Zara Theatre is standing by for the next command scenario.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(OnyxSpacingTokens.lg),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundPrimary.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(OnyxRadiusTokens.lg),
        border: Border.all(
          color: OnyxColorTokens.brand.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: OnyxColorTokens.brand.withValues(alpha: 0.12),
              border: Border.all(
                color: OnyxColorTokens.brand.withValues(alpha: 0.34),
              ),
              boxShadow: [
                BoxShadow(
                  color: OnyxColorTokens.brand.withValues(
                    alpha: 0.18 * _pulseController.value,
                  ),
                  blurRadius: 18,
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: OnyxColorTokens.brand,
              size: 24,
            ),
          ),
          const SizedBox(width: OnyxSpacingTokens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'ZARA THEATRE',
                      style: GoogleFonts.inter(
                        color: OnyxColorTokens.brand,
                        fontSize: OnyxTypographyTokens.labelMd,
                        fontWeight: OnyxTypographyTokens.bold,
                        letterSpacing: OnyxTypographyTokens.trackingCaps,
                      ),
                    ),
                    const SizedBox(width: OnyxSpacingTokens.sm),
                    _speakingDots(),
                  ],
                ),
                const SizedBox(height: OnyxSpacingTokens.sm),
                Text(
                  speech,
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.textPrimary,
                    fontSize: OnyxTypographyTokens.titleMd,
                    fontWeight: FontWeight.w500,
                    height: 1.55,
                  ),
                ),
                if (scenario?.clarificationRequest.trim().isNotEmpty ==
                    true) ...[
                  const SizedBox(height: OnyxSpacingTokens.sm),
                  Text(
                    scenario!.clarificationRequest,
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.accentAmber,
                      fontSize: OnyxTypographyTokens.bodySm,
                      fontWeight: OnyxTypographyTokens.medium,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _speakingDots() {
    return Row(
      children: List<Widget>.generate(3, (index) {
        final phase = (_pulseController.value + (index * 0.22)) % 1.0;
        return Container(
          margin: EdgeInsets.only(right: index == 2 ? 0 : OnyxSpacingTokens.xs),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: OnyxColorTokens.brand.withValues(
              alpha: 0.35 + (phase * 0.55),
            ),
          ),
        );
      }),
    );
  }

  Widget _actionsZone(ZaraScenario? scenario) {
    final actions = scenario?.proposedActions ?? const <ZaraAction>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PROPOSED ACTIONS',
          style: GoogleFonts.inter(
            color: OnyxColorTokens.textMuted,
            fontSize: OnyxTypographyTokens.labelMd,
            fontWeight: OnyxTypographyTokens.bold,
            letterSpacing: OnyxTypographyTokens.trackingCaps,
          ),
        ),
        const SizedBox(height: OnyxSpacingTokens.sm),
        if (actions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(OnyxSpacingTokens.md),
            decoration: BoxDecoration(
              color: OnyxColorTokens.backgroundPrimary.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(OnyxRadiusTokens.lg),
              border: Border.all(color: OnyxColorTokens.divider),
            ),
            child: Text(
              'No active actions yet. Zara will surface the next scenario here.',
              style: GoogleFonts.inter(
                color: OnyxColorTokens.textSecondary,
                fontSize: OnyxTypographyTokens.bodySm,
              ),
            ),
          )
        else
          ...actions.map(_actionCard),
      ],
    );
  }

  Widget _actionCard(ZaraAction action) {
    final accent = _actionAccent(action);
    final complete = action.state == ZaraActionState.completed;
    final failed = action.state == ZaraActionState.failed;
    final rejected = action.state == ZaraActionState.rejected;
    final awaitingConfirmation =
        action.confirmRequired &&
        !complete &&
        !failed &&
        !rejected &&
        action.state != ZaraActionState.executing;
    final summary = action.resolutionSummary.trim().isNotEmpty
        ? action.resolutionSummary.trim()
        : action.label;
    return Container(
      margin: const EdgeInsets.only(bottom: OnyxSpacingTokens.sm),
      padding: const EdgeInsets.all(OnyxSpacingTokens.md),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundPrimary.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(OnyxRadiusTokens.lg),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.16),
                ),
                alignment: Alignment.center,
                child: Icon(
                  complete
                      ? Icons.check_rounded
                      : failed
                      ? Icons.error_outline_rounded
                      : rejected
                      ? Icons.close_rounded
                      : Icons.bolt_rounded,
                  size: 15,
                  color: accent,
                ),
              ),
              const SizedBox(width: OnyxSpacingTokens.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary,
                      style: GoogleFonts.inter(
                        color: OnyxColorTokens.textPrimary,
                        fontSize: OnyxTypographyTokens.bodyLg,
                        fontWeight: OnyxTypographyTokens.semibold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _actionStateLabel(action),
                      style: GoogleFonts.inter(
                        color: accent,
                        fontSize: OnyxTypographyTokens.labelMd,
                        fontWeight: OnyxTypographyTokens.medium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (awaitingConfirmation) ...[
            const SizedBox(height: OnyxSpacingTokens.sm),
            Wrap(
              spacing: OnyxSpacingTokens.xs,
              runSpacing: OnyxSpacingTokens.xs,
              children: [
                FilledButton(
                  onPressed: () => widget.orchestrator.confirmAction(action.id),
                  style: FilledButton.styleFrom(
                    backgroundColor: OnyxColorTokens.brand,
                    foregroundColor: OnyxColorTokens.textPrimary,
                  ),
                  child: const Text('Confirm'),
                ),
                OutlinedButton(
                  onPressed: () => _editAction(action),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: OnyxColorTokens.textSecondary,
                    side: BorderSide(
                      color: OnyxColorTokens.brand.withValues(alpha: 0.24),
                    ),
                  ),
                  child: const Text('Edit'),
                ),
                TextButton(
                  onPressed: () => widget.orchestrator.rejectAction(action.id),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      color: OnyxColorTokens.textMuted,
                      fontWeight: OnyxTypographyTokens.medium,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _actionStateLabel(ZaraAction action) {
    return switch (action.state) {
      ZaraActionState.awaitingConfirmation =>
        'Awaiting controller confirmation',
      ZaraActionState.autoExecuting => 'Auto-executing',
      ZaraActionState.completed => 'Completed',
      ZaraActionState.executing => 'Executing now',
      ZaraActionState.failed => 'Execution failed',
      ZaraActionState.proposed =>
        action.confirmRequired
            ? 'Pending controller decision'
            : 'Queued for Zara',
      ZaraActionState.rejected => 'Cancelled',
    };
  }

  Color _actionAccent(ZaraAction action) {
    return switch (action.state) {
      ZaraActionState.completed => OnyxColorTokens.accentGreen,
      ZaraActionState.failed => OnyxColorTokens.accentRed,
      ZaraActionState.rejected => OnyxColorTokens.textMuted,
      ZaraActionState.executing ||
      ZaraActionState.autoExecuting => OnyxColorTokens.accentAmber,
      _ => OnyxColorTokens.brand,
    };
  }

  Widget _inputZone(ZaraScenario? scenario) {
    final hasScenario = scenario != null;
    final isParsing =
        widget.orchestrator.activeScenario?.isParsingControllerInput == true;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(OnyxSpacingTokens.md),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundPrimary.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(OnyxRadiusTokens.lg),
        border: Border.all(
          color: OnyxColorTokens.brand.withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isParsing) ...[
            Text(
              'Zara is considering…',
              style: GoogleFonts.inter(
                color: OnyxColorTokens.accentAmber,
                fontSize: OnyxTypographyTokens.labelLg,
                fontWeight: OnyxTypographyTokens.medium,
              ),
            ),
            const SizedBox(height: OnyxSpacingTokens.sm),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: hasScenario && !isParsing,
                  minLines: 1,
                  maxLines: 3,
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.textPrimary,
                    fontSize: OnyxTypographyTokens.bodyMd,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Respond to Zara…',
                    hintStyle: GoogleFonts.inter(
                      color: OnyxColorTokens.textMuted,
                      fontSize: OnyxTypographyTokens.bodySm,
                    ),
                    filled: true,
                    fillColor: OnyxColorTokens.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(OnyxRadiusTokens.md),
                      borderSide: BorderSide(
                        color: OnyxColorTokens.brand.withValues(alpha: 0.18),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(OnyxRadiusTokens.md),
                      borderSide: BorderSide(
                        color: OnyxColorTokens.brand.withValues(alpha: 0.18),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(OnyxRadiusTokens.md),
                      borderSide: const BorderSide(
                        color: OnyxColorTokens.brand,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _submitInput(),
                ),
              ),
              const SizedBox(width: OnyxSpacingTokens.sm),
              FilledButton(
                onPressed: hasScenario && !isParsing ? _submitInput : null,
                style: FilledButton.styleFrom(
                  backgroundColor: OnyxColorTokens.brand,
                  foregroundColor: OnyxColorTokens.textPrimary,
                  minimumSize: const Size(52, OnyxSpacingTokens.jumbo),
                ),
                child: const Icon(Icons.send_rounded, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
