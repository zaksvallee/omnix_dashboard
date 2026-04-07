import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _queuePanelColor = Color(0xFFFFFFFF);
const _queueBorderColor = Color(0xFFD7E1EC);
const _queueStrongBorderColor = Color(0xFFBFD0EA);
const _queueTitleColor = Color(0xFF142235);
const _queueBodyColor = Color(0xFF6A7D93);
const _queueMutedColor = Color(0xFF516882);

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

class ClientCommsQueueBoard extends StatelessWidget {
  final List<ClientCommsQueueItem> items;
  final VoidCallback onToggleDetailedWorkspace;
  final bool showDetailedWorkspace;
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

  const ClientCommsQueueBoard({
    super.key,
    required this.items,
    required this.onToggleDetailedWorkspace,
    required this.showDetailedWorkspace,
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
  });

  @override
  Widget build(BuildContext context) {
    final urgentCount =
        items
            .where((item) => item.severity == ClientCommsQueueSeverity.high)
            .length +
        (latestSentFollowUpUrgent ? 1 : 0);
    return Column(
      key: const ValueKey('clients-simple-queue-board'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pendingStrip(totalCount: items.length, urgentCount: urgentCount),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Client Communications',
                style: GoogleFonts.inter(
                  color: _queueTitleColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 0.96,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'AI-generated messages awaiting approval',
                style: GoogleFonts.inter(
                  color: _queueBodyColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if ((latestSentFollowUpBody ?? '').trim().isNotEmpty) ...[
          _latestSentFollowUpCard(),
          const SizedBox(height: 12),
        ],
        if (items.isEmpty)
          _emptyQueueState()
        else
          for (var i = 0; i < items.length; i++) ...[
            _queueCard(items[i]),
            if (i != items.length - 1) const SizedBox(height: 12),
          ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            key: const ValueKey('clients-toggle-detailed-workspace'),
            onPressed: onToggleDetailedWorkspace,
            icon: Icon(
              showDetailedWorkspace
                  ? Icons.visibility_off_rounded
                  : Icons.open_in_new_rounded,
              size: 15,
            ),
            label: Text(
              showDetailedWorkspace
                  ? 'Hide Detailed Workspace'
                  : 'Open Detailed Workspace',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF365E94),
              side: const BorderSide(color: _queueStrongBorderColor),
              backgroundColor: _queuePanelColor,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              textStyle: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _pendingStrip({required int totalCount, required int urgentCount}) {
    final headline = totalCount == 1
        ? '1 PENDING MESSAGE'
        : '$totalCount PENDING MESSAGES';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0CDD1)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.chat_bubble_outline_rounded,
            color: Color(0xFFCC5B67),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              headline,
              style: GoogleFonts.inter(
                color: const Color(0xFF8C3B43),
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0x1AFCA5A5),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0x55FCA5A5)),
            ),
            child: Text(
              urgentCount == 1 ? '1 Urgent' : '$urgentCount Urgent',
              style: GoogleFonts.inter(
                color: const Color(0xFFFECACA),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyQueueState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFF3FBF7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCFE6DA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Queue clear',
            style: GoogleFonts.inter(
              color: const Color(0xFF215D47),
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'There are no pending client approvals right now.',
            style: GoogleFonts.inter(
              color: const Color(0xFF4E816A),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _latestSentFollowUpCard() {
    final author = (latestSentFollowUpAuthor ?? '').trim();
    final body = (latestSentFollowUpBody ?? '').trim();
    final occurredAtUtc = latestSentFollowUpOccurredAtUtc;
    final urgent = latestSentFollowUpUrgent;
    final metadata = <String>[
      if (author.isNotEmpty) author,
      if (occurredAtUtc != null) _formatOccurredAtLabel(occurredAtUtc),
    ].join('  •  ');
    return Container(
      key: const ValueKey('clients-latest-sent-follow-up-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: urgent ? const Color(0xFFFFF2F2) : const Color(0xFFF2F8FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: urgent ? const Color(0xFFF0CDD1) : const Color(0xFFC9DCF6),
        ),
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
                    color: urgent
                        ? const Color(0xFF8C3B43)
                        : const Color(0xFF365E94),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              if (urgent)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x1AFCA5A5),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0x55FCA5A5)),
                  ),
                  child: Text(
                    'HIGH PRIORITY',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFCC5B67),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: GoogleFonts.inter(
              color: _queueTitleColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            metadata.isEmpty
                ? urgent
                      ? 'Already sent live to the client. Control reply recommended now.'
                      : 'Already sent live to the client. Controllers can track the promise here without opening the approval queue.'
                : urgent
                ? '$metadata  •  Already sent live to the client. Control reply recommended now.'
                : '$metadata  •  Already sent live to the client.',
            style: GoogleFonts.inter(
              color: _queueBodyColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          if (onPrepareLatestSentFollowUpReply != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _actionButton(
                    key: const ValueKey(
                      'clients-latest-sent-follow-up-prepare-reply',
                    ),
                    label: preparingLatestSentFollowUpReply
                        ? 'PREPARING AI DRAFT...'
                        : (urgent
                              ? 'PREPARE URGENT REPLY'
                              : 'PREPARE REPLY'),
                    foreground: urgent
                        ? const Color(0xFF8C3B43)
                        : const Color(0xFF365E94),
                    background: _queuePanelColor,
                    border: urgent
                        ? const Color(0xFFF0CDD1)
                        : _queueStrongBorderColor,
                    onPressed: preparingLatestSentFollowUpReply
                        ? null
                        : () => onPrepareLatestSentFollowUpReply!.call(),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _queueCard(ClientCommsQueueItem item) {
    final palette = _paletteFor(item.severity);
    final normalizedIncidentReference = item.incidentReference.trim();
    final normalizedFocusedItemId = (focusedItemId ?? '').trim();
    final isFocused =
        normalizedFocusedItemId.isNotEmpty &&
        normalizedFocusedItemId == item.id;
    final canResumeDetailedWorkspace =
        isFocused && onResumeDetailedWorkspaceForItem != null;
    final canOpenAgent =
        onOpenAgentForIncident != null &&
        normalizedIncidentReference.isNotEmpty;
    final agentActionKey = ValueKey(
      'clients-open-agent-${normalizedIncidentReference.isEmpty ? item.id : normalizedIncidentReference}',
    );
    return Container(
      key: ValueKey('clients-simple-card-${item.id}'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: palette.accent.withValues(alpha: 0.18),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isFocused) ...[
              Container(
                key: ValueKey('clients-simple-card-focus-${item.id}'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: palette.accent.withValues(alpha: 0.42),
                  ),
                ),
                child: Text(
                  'FOCUSED DRAFT',
                  style: GoogleFonts.inter(
                    color: palette.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      Text(
                        item.clientName,
                        style: GoogleFonts.inter(
                          color: _queueTitleColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: palette.accent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: palette.accent.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Text(
                          _severityLabel(item.severity),
                          style: GoogleFonts.inter(
                            color: palette.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        item.siteName,
                        style: GoogleFonts.inter(
                          color: _queueBodyColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '•',
                        style: GoogleFonts.inter(
                          color: const Color(0x666A7D93),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        item.incidentLabel,
                        style: GoogleFonts.robotoMono(
                          color: _queueMutedColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
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
                      'Generated',
                      style: GoogleFonts.inter(
                        color: _queueBodyColor,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.generatedAtLabel,
                      style: GoogleFonts.inter(
                        color: _queueTitleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _labeledField(label: 'CONTEXT', body: item.context),
            const SizedBox(height: 12),
            _labeledField(
              label: 'AI-GENERATED MESSAGE',
              body: item.draftMessage,
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 860;
                final sendButton = _actionButton(
                  key: ValueKey('clients-send-draft-${item.id}'),
                  label: 'SEND',
                  foreground: const Color(0xFF215D47),
                  background: const Color(0xFF53D594),
                  border: const Color(0xFF6FE0A8),
                  onPressed: () => onSend(item),
                );
                final askAgentButton = !canOpenAgent
                    ? null
                    : _actionButton(
                        key: agentActionKey,
                        label: 'ASK AGENT',
                        foreground: const Color(0xFF7C3AED),
                        background: _queuePanelColor,
                        border: const Color(0xFFD8C6FB),
                        onPressed: () => onOpenAgentForIncident!(
                          normalizedIncidentReference,
                        ),
                      );
                final resumeDetailedWorkspaceButton =
                    !canResumeDetailedWorkspace
                    ? null
                    : _actionButton(
                        key: ValueKey(
                          'clients-resume-detailed-workspace-${item.id}',
                        ),
                        label: (focusedResumeActionLabel ?? '').trim().isEmpty
                            ? 'RESUME DETAILED COMMS'
                            : focusedResumeActionLabel!.trim(),
                        foreground: const Color(0xFF365E94),
                        background: _queuePanelColor,
                        border: _queueStrongBorderColor,
                        onPressed: () =>
                            onResumeDetailedWorkspaceForItem!(item),
                      );
                final editButton = _actionButton(
                  key: ValueKey('clients-edit-draft-${item.id}'),
                  label: 'EDIT',
                  foreground: const Color(0xFF365E94),
                  background: _queuePanelColor,
                  border: _queueStrongBorderColor,
                  onPressed: () => onEdit(item),
                );
                final rejectButton = _actionButton(
                  key: ValueKey('clients-reject-draft-${item.id}'),
                  label: 'REJECT',
                  foreground: const Color(0xFFAF4E57),
                  background: _queuePanelColor,
                  border: const Color(0xFFF0CDD1),
                  onPressed: () => onReject(item),
                );
                if (stacked) {
                  return Column(
                    children: [
                      SizedBox(width: double.infinity, child: sendButton),
                      if (resumeDetailedWorkspaceButton != null) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: resumeDetailedWorkspaceButton,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (askAgentButton != null) ...[
                            Expanded(child: askAgentButton),
                            const SizedBox(width: 10),
                          ],
                          Expanded(child: editButton),
                          const SizedBox(width: 10),
                          Expanded(child: rejectButton),
                        ],
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(flex: 5, child: sendButton),
                    if (resumeDetailedWorkspaceButton != null) ...[
                      const SizedBox(width: 10),
                      Expanded(flex: 4, child: resumeDetailedWorkspaceButton),
                    ],
                    if (askAgentButton != null) ...[
                      const SizedBox(width: 10),
                      Expanded(child: askAgentButton),
                    ],
                    const SizedBox(width: 10),
                    Expanded(child: editButton),
                    const SizedBox(width: 10),
                    Expanded(child: rejectButton),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _labeledField({required String label, required String body}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: _queueBodyColor,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _queuePanelColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _queueBorderColor),
          ),
          child: Text(
            body,
            style: GoogleFonts.inter(
              color: _queueTitleColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required Key key,
    required String label,
    required Color foreground,
    required Color background,
    required Color border,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      key: key,
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: background,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
        textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800),
      ),
      child: Text(label),
    );
  }

  _QueuePalette _paletteFor(ClientCommsQueueSeverity severity) {
    return switch (severity) {
      ClientCommsQueueSeverity.high => const _QueuePalette(
        surface: Color(0xFFFFF2F2),
        border: Color(0xFFF0CDD1),
        accent: Color(0xFFCC5B67),
      ),
      ClientCommsQueueSeverity.medium => const _QueuePalette(
        surface: Color(0xFFFFF7EA),
        border: Color(0xFFF1D9A7),
        accent: Color(0xFF9A6A19),
      ),
      ClientCommsQueueSeverity.low => const _QueuePalette(
        surface: Color(0xFFF3FBF7),
        border: Color(0xFFCFE6DA),
        accent: Color(0xFF2D7A5F),
      ),
    };
  }

  String _severityLabel(ClientCommsQueueSeverity severity) {
    return switch (severity) {
      ClientCommsQueueSeverity.high => 'HIGH',
      ClientCommsQueueSeverity.medium => 'MEDIUM',
      ClientCommsQueueSeverity.low => 'LOW',
    };
  }

  String _formatOccurredAtLabel(DateTime occurredAtUtc) {
    final local = occurredAtUtc.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _QueuePalette {
  final Color surface;
  final Color border;
  final Color accent;

  const _QueuePalette({
    required this.surface,
    required this.border,
    required this.accent,
  });
}
