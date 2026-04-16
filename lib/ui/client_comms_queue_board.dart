import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../application/system_flow_service.dart';
import 'components/onyx_system_flow_widgets.dart';
import 'theme/onyx_design_tokens.dart';

// ── Colour aliases ─────────────────────────────────────────────────────────
const _bg = OnyxColorTokens.backgroundPrimary;
const _surface = OnyxColorTokens.backgroundSecondary;
const _titleColor = OnyxColorTokens.textPrimary;
const _bodyColor = OnyxColorTokens.textSecondary;
const _mutedColor = OnyxColorTokens.textMuted;
const _dividerColor = OnyxColorTokens.divider;
const _borderColor = OnyxDesignTokens.borderSubtle;

// ── Data models ────────────────────────────────────────────────────────────

enum ClientCommsQueueSeverity { high, medium, low }

class ClientCommsQueueItem {
  final String id;
  final String clientName;
  final String siteName;
  final String incidentLabel;
  final String incidentReference;
  final ClientCommsQueueSeverity severity;
  final String generatedAtLabel;
  final String context;
  final String draftMessage;

  const ClientCommsQueueItem({
    required this.id,
    required this.clientName,
    required this.siteName,
    required this.incidentLabel,
    this.incidentReference = '',
    required this.severity,
    required this.generatedAtLabel,
    required this.context,
    required this.draftMessage,
  });

  ClientCommsQueueItem copyWith({String? draftMessage}) {
    return ClientCommsQueueItem(
      id: id,
      clientName: clientName,
      siteName: siteName,
      incidentLabel: incidentLabel,
      incidentReference: incidentReference,
      severity: severity,
      generatedAtLabel: generatedAtLabel,
      context: context,
      draftMessage: draftMessage ?? this.draftMessage,
    );
  }
}

class ClientCommsHistoryEntry {
  final String incidentId;
  final String preview;
  final String timestamp;
  final bool delivered;
  final String? statusLabel;
  final String? eventId;
  final String? incidentReference;

  const ClientCommsHistoryEntry({
    required this.incidentId,
    required this.preview,
    required this.timestamp,
    this.delivered = true,
    this.statusLabel,
    this.eventId,
    this.incidentReference,
  });
}

// ── Board widget ───────────────────────────────────────────────────────────

class ClientCommsQueueBoard extends StatelessWidget {
  final List<ClientCommsQueueItem> items;
  final VoidCallback onToggleDetailedWorkspace;
  final String? latestSentFollowUpAuthor;
  final String? latestSentFollowUpBody;
  final DateTime? latestSentFollowUpOccurredAtUtc;
  final bool latestSentFollowUpUrgent;
  final bool preparingLatestSentFollowUpReply;
  final VoidCallback? onPrepareLatestSentFollowUpReply;
  final String? focusedItemId;
  final String? focusedResumeActionLabel;
  final ValueChanged<ClientCommsQueueItem>? onResumeDetailedWorkspaceForItem;
  final ValueChanged<ClientCommsQueueItem> onSend;
  final ValueChanged<ClientCommsQueueItem> onEdit;
  final ValueChanged<ClientCommsQueueItem> onReject;
  final ValueChanged<String>? onOpenAgentForIncident;
  // Right panel extras
  final String? learnedStyleLabel;
  final String? learnedStyleSource;
  final String selectedTone;
  final ValueChanged<String>? onToneChanged;
  final List<ClientCommsHistoryEntry> messageHistory;
  final String? lastDraftTimestampLabel;
  final ClientCommsHistoryEntry? lastCommunication;
  final VoidCallback? onViewLastCommunication;
  final VoidCallback? onOpenLiveFeeds;

  const ClientCommsQueueBoard({
    super.key,
    required this.items,
    required this.onToggleDetailedWorkspace,
    this.latestSentFollowUpAuthor,
    this.latestSentFollowUpBody,
    this.latestSentFollowUpOccurredAtUtc,
    this.latestSentFollowUpUrgent = false,
    this.preparingLatestSentFollowUpReply = false,
    this.onPrepareLatestSentFollowUpReply,
    this.focusedItemId,
    this.focusedResumeActionLabel,
    this.onResumeDetailedWorkspaceForItem,
    required this.onSend,
    required this.onEdit,
    required this.onReject,
    this.onOpenAgentForIncident,
    this.learnedStyleLabel,
    this.learnedStyleSource,
    this.selectedTone = 'Auto',
    this.onToneChanged,
    this.messageHistory = const [],
    this.lastDraftTimestampLabel,
    this.lastCommunication,
    this.onViewLastCommunication,
    this.onOpenLiveFeeds,
  });

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('clients-simple-queue-board'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHeader(),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumn = constraints.maxWidth >= 860;
            if (twoColumn) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: _leftColumn()),
                  const SizedBox(width: 16),
                  SizedBox(width: 240, child: _rightColumn()),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _leftColumn(),
                const SizedBox(height: 16),
                _rightColumn(),
              ],
            );
          },
        ),
      ],
    );
  }

  // ── Page header ───────────────────────────────────────────────────────────

  Widget _pageHeader() {
    return SizedBox(
      height: 40,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Client communications',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _titleColor,
            letterSpacing: -0.3,
          ),
        ),
      ),
    );
  }

  // ── Left column ───────────────────────────────────────────────────────────

  Widget _leftColumn() {
    final idleState = items.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!idleState && (latestSentFollowUpBody ?? '').trim().isNotEmpty) ...[
          _latestSentFollowUpCard(),
          const SizedBox(height: 12),
        ],
        if (idleState)
          _idleControlSurface()
        else
          for (var i = 0; i < items.length; i++) ...[
            _queueCard(items[i]),
            if (i != items.length - 1) const SizedBox(height: 12),
          ],
        if (!idleState && messageHistory.isNotEmpty) ...[
          const SizedBox(height: 20),
          _messageHistorySection(),
        ],
      ],
    );
  }

  // ── Right column ──────────────────────────────────────────────────────────

  Widget _rightColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pendingCountCard(),
        if (learnedStyleLabel != null &&
            learnedStyleLabel!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          _learnedStyleCard(),
        ],
        const SizedBox(height: 12),
        _toneSelectorCard(),
      ],
    );
  }

  // ── Pending count card ────────────────────────────────────────────────────

  Widget _pendingCountCard() {
    final hasDrafts = items.isNotEmpty;
    final lastDraftLabel = (lastDraftTimestampLabel ?? '').trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: OnyxRadiusTokens.radiusMd,
        border: Border.all(color: _dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PENDING AI DRAFTS',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _bodyColor,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 8),
          if (hasDrafts) ...[
            Text(
              '${items.length}',
              style: GoogleFonts.inter(
                fontSize: 40,
                fontWeight: FontWeight.w700,
                color: OnyxDesignTokens.amberWarning,
                height: 1.0,
              ),
            ),
            Text(
              'AWAITING REVIEW',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _bodyColor,
                letterSpacing: 0.5,
              ),
            ),
          ] else
            Text(
              'Draft Queue: Clear',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: OnyxDesignTokens.greenNominal,
                letterSpacing: 0.2,
              ),
            ),
          const SizedBox(height: 6),
          Text(
            'Last draft: ${lastDraftLabel.isEmpty ? 'No drafts yet' : lastDraftLabel}',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: _mutedColor,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: items.isEmpty ? null : onToggleDetailedWorkspace,
              style: ElevatedButton.styleFrom(
                backgroundColor: OnyxDesignTokens.amberWarning,
                foregroundColor: Colors.white,
                disabledBackgroundColor: OnyxColorTokens.amberSurface,
                disabledForegroundColor: _mutedColor,
                minimumSize: const Size(double.infinity, 36),
                elevation: 0,
                textStyle: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: OnyxRadiusTokens.radiusSm,
                ),
              ),
              child: const Text('REVIEW DRAFTS'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Learned style card ────────────────────────────────────────────────────

  Widget _learnedStyleCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: OnyxRadiusTokens.radiusMd,
        border: Border.all(color: _dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.trending_up_rounded,
                size: 14,
                color: OnyxDesignTokens.brand,
              ),
              const SizedBox(width: 6),
              Text(
                'LEARNED STYLE',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _bodyColor,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            learnedStyleLabel ?? '',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _titleColor,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            learnedStyleSource ?? 'AI-detected from approval history',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: _bodyColor,
            ),
          ),
        ],
      ),
    );
  }

  // ── Tone selector ─────────────────────────────────────────────────────────

  Widget _toneSelectorCard() {
    const tones = <String>['Auto', 'Concise', 'Reassuring', 'Formal'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: OnyxRadiusTokens.radiusMd,
        border: Border.all(color: _dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TONE CONTROL',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _bodyColor,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: OnyxColorTokens.accentPurple.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: OnyxColorTokens.accentPurple.withValues(alpha: 0.35),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Z',
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.accentPurple,
                    fontSize: 6,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _zaraToneLine(),
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.accentPurple.withValues(alpha: 0.55),
                    fontSize: 9,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final tone in tones) ...[
            _toneOption(tone),
            if (tone != tones.last) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Widget _toneOption(String tone) {
    final selected = selectedTone == tone;
    return GestureDetector(
      onTap: () => onToneChanged?.call(tone),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? OnyxDesignTokens.brand.withValues(alpha: 0.1) : _bg,
          borderRadius: OnyxRadiusTokens.radiusSm,
          border: Border.all(
            color: selected
                ? OnyxDesignTokens.brand.withValues(alpha: 0.3)
                : _dividerColor,
          ),
        ),
        child: Text(
          tone,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? _titleColor : _bodyColor,
          ),
        ),
      ),
    );
  }

  // ── Message history ───────────────────────────────────────────────────────

  Widget _messageHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MESSAGE HISTORY',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _bodyColor,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 8),
        for (final entry in messageHistory) ...[
          _historyRow(entry),
          const Divider(height: 1, thickness: 1, color: _dividerColor),
        ],
      ],
    );
  }

  Widget _historyRow(ClientCommsHistoryEntry entry) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                entry.incidentId,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _bodyColor,
                ),
              ),
              const SizedBox(width: 12),
              _statusBadge(delivered: entry.delivered),
              const Spacer(),
              Text(
                entry.timestamp,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: _bodyColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            entry.preview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: _bodyColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge({required bool delivered}) {
    final label = delivered ? 'DELIVERED' : 'DRAFT';
    final fg = delivered
        ? OnyxDesignTokens.greenNominal
        : OnyxDesignTokens.amberWarning;
    final bg = delivered
        ? OnyxColorTokens.greenSurface
        : OnyxColorTokens.amberSurface;
    final border = delivered
        ? OnyxColorTokens.greenBorder
        : OnyxColorTokens.amberBorder;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  // ── Latest sent follow-up card ────────────────────────────────────────────

  Widget _latestSentFollowUpCard() {
    final author = (latestSentFollowUpAuthor ?? '').trim();
    final body = (latestSentFollowUpBody ?? '').trim();
    final occurredAtUtc = latestSentFollowUpOccurredAtUtc;
    final urgent = latestSentFollowUpUrgent;
    final timePart = occurredAtUtc != null ? _formatTime(occurredAtUtc) : '';
    final meta = <String>[
      if (author.isNotEmpty) author,
      if (timePart.isNotEmpty) timePart,
    ].join('  •  ');

    final accent = urgent
        ? OnyxDesignTokens.redCritical
        : OnyxDesignTokens.cyanInteractive;
    final surfaceColor = urgent
        ? OnyxColorTokens.redSurface
        : OnyxColorTokens.cyanSurface;
    final borderColor = urgent
        ? OnyxColorTokens.redBorder
        : OnyxColorTokens.cyanBorder;

    return Container(
      key: const ValueKey('clients-latest-sent-follow-up-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: OnyxRadiusTokens.radiusMd,
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'LATEST SENT FOLLOW-UP',
                  style: GoogleFonts.inter(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              if (urgent)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: OnyxColorTokens.redSurface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: OnyxColorTokens.redBorder),
                  ),
                  child: Text(
                    'HIGH PRIORITY',
                    style: GoogleFonts.inter(
                      color: OnyxDesignTokens.redCritical,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: GoogleFonts.inter(
              color: _titleColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '$meta  •  Already sent live.',
              style: GoogleFonts.inter(
                color: _bodyColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ],
          if (onPrepareLatestSentFollowUpReply != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const ValueKey(
                  'clients-latest-sent-follow-up-prepare-reply',
                ),
                onPressed: preparingLatestSentFollowUpReply
                    ? null
                    : onPrepareLatestSentFollowUpReply,
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(color: borderColor),
                  minimumSize: const Size(0, 36),
                  textStyle: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: OnyxRadiusTokens.radiusSm,
                  ),
                ),
                child: Text(
                  preparingLatestSentFollowUpReply
                      ? 'PREPARING AI DRAFT…'
                      : (urgent ? 'PREPARE URGENT REPLY' : 'PREPARE REPLY'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _idleControlSurface() {
    final lastIncidentRef = (lastCommunication?.incidentReference ?? '').trim();
    final flow = OnyxFlowIndicatorService.dispatchToClient(
      sourceLabel: lastIncidentRef.isEmpty
          ? 'Last dispatch lane is clear'
          : 'Last dispatch → $lastIncidentRef',
      nextActionLabel: 'Draft and deliver the next client update when needed',
      referenceLabel: lastIncidentRef.isEmpty ? null : lastIncidentRef,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _zaraCommunicationStateCard(),
        const SizedBox(height: 10),
        OnyxFlowIndicator(flow: flow),
        const SizedBox(height: 10),
        _idleStatusRow(),
        const SizedBox(height: 10),
        _lastCommunicationSection(),
        const SizedBox(height: 12),
        _sectionLabel('READINESS'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: const [
            _ReadinessChip(label: 'Client contact channels active'),
            _ReadinessChip(label: 'Message templates loaded'),
            _ReadinessChip(label: 'Escalation scripts available'),
            _ReadinessChip(label: 'Auto-draft enabled'),
          ],
        ),
        const SizedBox(height: 12),
        _sectionLabel('QUICK ACTIONS'),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _idleActionButton(
                label: 'Draft client update',
                foreground: OnyxColorTokens.accentPurple.withValues(
                  alpha: 0.70,
                ),
                border: OnyxColorTokens.accentPurple.withValues(alpha: 0.22),
                onTap: onToggleDetailedWorkspace,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _idleActionButton(
                label: 'Review last communication',
                foreground: _mutedColor,
                border: _dividerColor,
                onTap: onViewLastCommunication,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _idleActionButton(
                label: 'Open live feeds',
                foreground: OnyxColorTokens.accentSky.withValues(alpha: 0.55),
                border: OnyxColorTokens.accentSky.withValues(alpha: 0.18),
                onTap: onOpenLiveFeeds,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Queue card ─────────────────────────────────────────────────────────────

  Widget _queueCard(ClientCommsQueueItem item) {
    final severityColor = _severityColor(item.severity);
    final normalizedRef = item.incidentReference.trim();
    final normalizedFocusId = (focusedItemId ?? '').trim();
    final isFocused =
        normalizedFocusId.isNotEmpty && normalizedFocusId == item.id;
    final canResumeWorkspace =
        isFocused && onResumeDetailedWorkspaceForItem != null;
    final canOpenAgent =
        onOpenAgentForIncident != null && normalizedRef.isNotEmpty;

    return Container(
      key: ValueKey('clients-simple-card-${item.id}'),
      margin: const EdgeInsets.only(bottom: 0),
      decoration: BoxDecoration(
        color: _surface,
        border: Border(
          left: BorderSide(color: severityColor, width: 3),
          top: BorderSide(color: _dividerColor),
          right: BorderSide(color: _dividerColor),
          bottom: BorderSide(color: _dividerColor),
        ),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: severityColor.withValues(alpha: 0.14),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: severityColor,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  item.clientName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _titleColor,
                  ),
                ),
                const SizedBox(width: 8),
                _priorityBadge(item.severity),
                const Spacer(),
                Text(
                  item.incidentLabel,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _bodyColor,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Generated ${item.generatedAtLabel}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: _bodyColor,
                  ),
                ),
              ],
            ),

            if (isFocused) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: severityColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  'FOCUSED DRAFT',
                  style: GoogleFonts.inter(
                    color: severityColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // ── Context box ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: OnyxRadiusTokens.radiusSm,
                border: Border.all(color: _dividerColor),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: _bodyColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'CONTEXT',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _bodyColor,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.context,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: _bodyColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── AI message label ──────────────────────────────────────────
            Text(
              'AI-GENERATED MESSAGE',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _bodyColor,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(height: 6),

            // ── Message box ───────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: OnyxRadiusTokens.radiusSm,
                border: Border.all(color: _borderColor),
              ),
              child: Text(
                item.draftMessage,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: _titleColor,
                  height: 1.5,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Action row ────────────────────────────────────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 520;
                final sendBtn = _sendButton(item);
                final editBtn = _editButton(item);
                final rejectBtn = _rejectButton(item);
                final resumeBtn = canResumeWorkspace
                    ? _resumeButton(item)
                    : null;
                final agentBtn = canOpenAgent
                    ? _agentButton(normalizedRef)
                    : null;

                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      sendBtn,
                      if (resumeBtn != null) ...[
                        const SizedBox(height: 8),
                        resumeBtn,
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (agentBtn != null) ...[
                            Expanded(child: agentBtn),
                            const SizedBox(width: 8),
                          ],
                          Expanded(child: editBtn),
                          const SizedBox(width: 8),
                          Expanded(child: rejectBtn),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(flex: 5, child: sendBtn),
                    if (resumeBtn != null) ...[
                      const SizedBox(width: 8),
                      Expanded(flex: 4, child: resumeBtn),
                    ],
                    if (agentBtn != null) ...[
                      const SizedBox(width: 8),
                      Expanded(child: agentBtn),
                    ],
                    const SizedBox(width: 8),
                    Expanded(child: editBtn),
                    const SizedBox(width: 8),
                    Expanded(child: rejectBtn),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Action buttons ────────────────────────────────────────────────────────

  Widget _sendButton(ClientCommsQueueItem item) {
    return ElevatedButton.icon(
      key: ValueKey('clients-send-draft-${item.id}'),
      onPressed: () => onSend(item),
      icon: const Icon(Icons.send_rounded, size: 16),
      label: const Text('SEND'),
      style: ElevatedButton.styleFrom(
        backgroundColor: OnyxDesignTokens.statusSuccess,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 40),
        elevation: 0,
        textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: OnyxRadiusTokens.radiusSm),
      ),
    );
  }

  Widget _editButton(ClientCommsQueueItem item) {
    return OutlinedButton.icon(
      key: ValueKey('clients-edit-draft-${item.id}'),
      onPressed: () => onEdit(item),
      icon: const Icon(Icons.edit_outlined, size: 14),
      label: const Text('EDIT'),
      style: OutlinedButton.styleFrom(
        foregroundColor: _bodyColor,
        minimumSize: const Size(0, 40),
        side: BorderSide(color: _borderColor),
        textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: OnyxRadiusTokens.radiusSm),
      ),
    );
  }

  Widget _rejectButton(ClientCommsQueueItem item) {
    return OutlinedButton.icon(
      key: ValueKey('clients-reject-draft-${item.id}'),
      onPressed: () => onReject(item),
      icon: const Icon(Icons.close_rounded, size: 14),
      label: const Text('REJECT'),
      style: OutlinedButton.styleFrom(
        foregroundColor: _bodyColor,
        minimumSize: const Size(0, 40),
        side: BorderSide(color: _dividerColor),
        textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: OnyxRadiusTokens.radiusSm),
      ),
    );
  }

  Widget _resumeButton(ClientCommsQueueItem item) {
    final label = (focusedResumeActionLabel ?? '').trim().isEmpty
        ? 'RESUME WORKSPACE'
        : focusedResumeActionLabel!.trim();
    return OutlinedButton(
      key: ValueKey('clients-resume-detailed-workspace-${item.id}'),
      onPressed: () => onResumeDetailedWorkspaceForItem!(item),
      style: OutlinedButton.styleFrom(
        foregroundColor: OnyxDesignTokens.cyanInteractive,
        minimumSize: const Size(0, 40),
        side: const BorderSide(color: OnyxColorTokens.cyanBorder),
        textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: OnyxRadiusTokens.radiusSm),
      ),
      child: Text(label),
    );
  }

  Widget _agentButton(String incidentRef) {
    return OutlinedButton(
      key: ValueKey('clients-open-agent-$incidentRef'),
      onPressed: () => onOpenAgentForIncident!(incidentRef),
      style: OutlinedButton.styleFrom(
        foregroundColor: OnyxDesignTokens.accentPurple,
        minimumSize: const Size(0, 40),
        side: const BorderSide(color: OnyxColorTokens.purpleBorder),
        textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: OnyxRadiusTokens.radiusSm),
      ),
      child: const Text('ASK AGENT'),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _priorityBadge(ClientCommsQueueSeverity severity) {
    final (label, fg, bg, border) = switch (severity) {
      ClientCommsQueueSeverity.high => (
        'HIGH',
        OnyxDesignTokens.redCritical,
        OnyxColorTokens.redSurface,
        OnyxColorTokens.redBorder,
      ),
      ClientCommsQueueSeverity.medium => (
        'MEDIUM',
        OnyxDesignTokens.amberWarning,
        OnyxColorTokens.amberSurface,
        OnyxColorTokens.amberBorder,
      ),
      ClientCommsQueueSeverity.low => (
        'LOW',
        OnyxDesignTokens.textMuted,
        OnyxDesignTokens.surfaceInset,
        OnyxDesignTokens.borderSubtle,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Color _severityColor(ClientCommsQueueSeverity severity) => switch (severity) {
    ClientCommsQueueSeverity.high => OnyxDesignTokens.redCritical,
    ClientCommsQueueSeverity.medium => OnyxDesignTokens.amberWarning,
    ClientCommsQueueSeverity.low => OnyxDesignTokens.textMuted,
  };

  Widget _zaraCommunicationStateCard() {
    final lines = OnyxZaraContinuityService.communicationsStatusLines(
      lastIncidentReference: lastCommunication?.incidentReference,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: OnyxRadiusTokens.radiusMd,
        border: Border.all(
          color: OnyxColorTokens.accentPurple.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: OnyxColorTokens.accentPurple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: OnyxColorTokens.accentPurple.withValues(alpha: 0.35),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              'Z',
              style: GoogleFonts.inter(
                color: OnyxColorTokens.accentPurple,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ZARA · COMMUNICATIONS',
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.accentPurple.withValues(alpha: 0.60),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 5),
                _stateLine(lines[0]),
                const SizedBox(height: 5),
                _stateLine(lines[1]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stateLine(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 4),
          decoration: const BoxDecoration(
            color: OnyxColorTokens.accentGreen,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: _bodyColor,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _idleStatusRow() {
    final lastDraftLabel = (lastDraftTimestampLabel ?? '').trim();
    return Row(
      children: [
        Expanded(
          child: _statusChip(
            label: 'DRAFT QUEUE',
            value: 'Clear',
            valueColor: OnyxDesignTokens.greenNominal,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statusChip(
            label: 'LAST DRAFT',
            value: lastDraftLabel.isEmpty ? 'No drafts yet' : lastDraftLabel,
            valueColor: _mutedColor,
            valueSize: 11,
            valueWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statusChip(
            label: 'CHANNELS',
            value: 'Active',
            valueColor: OnyxDesignTokens.greenNominal,
          ),
        ),
      ],
    );
  }

  Widget _statusChip({
    required String label,
    required String value,
    required Color valueColor,
    double valueSize = 12,
    FontWeight valueWeight = FontWeight.w700,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: _mutedColor,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: valueColor,
              fontSize: valueSize,
              fontWeight: valueWeight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _lastCommunicationSection() {
    final entry = lastCommunication;
    if (entry == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Text(
            'No previous communications',
            style: GoogleFonts.inter(
              color: _mutedColor,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }
    final statusLine = (entry.statusLabel ?? '').trim().isNotEmpty
        ? entry.statusLabel!.trim()
        : (entry.delivered ? 'Sent · Client acknowledged' : 'Draft pending');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _dividerColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 2,
              color: OnyxColorTokens.accentGreen.withValues(alpha: 0.40),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LAST COMMUNICATION',
                            style: GoogleFonts.inter(
                              color: _mutedColor,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.preview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: _mutedColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            statusLine,
                            style: GoogleFonts.inter(
                              color: OnyxColorTokens.textDisabled,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          entry.timestamp,
                          style: GoogleFonts.inter(
                            color: OnyxColorTokens.textDisabled,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: onViewLastCommunication,
                          child: Text(
                            'View →',
                            style: GoogleFonts.inter(
                              color: OnyxColorTokens.accentPurple.withValues(
                                alpha: 0.55,
                              ),
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        color: OnyxColorTokens.textDisabled,
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.3,
      ),
    );
  }

  Widget _idleActionButton({
    required String label,
    required Color foreground,
    required Color border,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: foreground,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _zaraToneLine() {
    return OnyxZaraContinuityService.communicationsToneLine(selectedTone);
  }

  String _formatTime(DateTime utc) {
    final local = utc.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _ReadinessChip extends StatelessWidget {
  final String label;

  const _ReadinessChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: OnyxColorTokens.accentGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: GoogleFonts.inter(
              color: _mutedColor,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
