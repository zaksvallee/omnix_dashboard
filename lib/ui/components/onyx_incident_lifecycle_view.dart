import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../application/event_sourcing_service.dart';
import '../../application/system_flow_service.dart';
import '../theme/onyx_design_tokens.dart';
import 'onyx_system_flow_widgets.dart';

Future<void> showOnyxIncidentLifecycleDialog({
  required BuildContext context,
  required OnyxIncidentLifecycleSnapshot snapshot,
  OnyxEventSourcingSnapshot? eventSourcingSnapshot,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: OnyxColorTokens.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: OnyxColorTokens.accentPurple.withValues(alpha: 0.18),
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _OnyxIncidentLifecycleView(
              snapshot: snapshot,
              eventSourcingSnapshot: eventSourcingSnapshot,
            ),
          ),
        ),
      );
    },
  );
}

class _OnyxIncidentLifecycleView extends StatelessWidget {
  final OnyxIncidentLifecycleSnapshot snapshot;
  final OnyxEventSourcingSnapshot? eventSourcingSnapshot;

  const _OnyxIncidentLifecycleView({
    required this.snapshot,
    required this.eventSourcingSnapshot,
  });

  @override
  Widget build(BuildContext context) {
    final entries = snapshot.entries;
    final replayFrames = eventSourcingSnapshot?.replayFrames ?? const [];
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'INCIDENT LIFECYCLE',
                      style: GoogleFonts.inter(
                        color: OnyxColorTokens.textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      snapshot.incidentReference,
                      style: GoogleFonts.inter(
                        color: OnyxColorTokens.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      snapshot.summary,
                      style: GoogleFonts.inter(
                        color: OnyxColorTokens.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      (snapshot.active
                              ? OnyxColorTokens.accentPurple
                              : OnyxColorTokens.accentGreen)
                          .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        (snapshot.active
                                ? OnyxColorTokens.accentPurple
                                : OnyxColorTokens.accentGreen)
                            .withValues(alpha: 0.22),
                  ),
                ),
                child: Text(
                  snapshot.active ? 'ACTIVE' : 'SEALED',
                  style: GoogleFonts.inter(
                    color: snapshot.active
                        ? OnyxColorTokens.accentPurple
                        : OnyxColorTokens.accentGreen,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.close_rounded,
                  color: OnyxColorTokens.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OnyxFlowBreadcrumb(
            flow: OnyxFlowBreadcrumbData(
              chainLabel: 'Signal → Verified → Decision → Dispatch → Resolved',
              sourceLabel:
                  'Lifecycle view → Full operational memory for ${snapshot.incidentReference}',
              nextActionLabel: snapshot.active
                  ? 'Next action → Keep response and client confirmation synchronized'
                  : 'Next action → Review the sealed chain or reopen in Queue if needed',
              referenceLabel: snapshot.incidentReference,
            ),
            accent: OnyxColorTokens.accentPurple,
          ),
          if (eventSourcingSnapshot != null) ...[
            const SizedBox(height: 12),
            _EventStoreAuditStrip(snapshot: eventSourcingSnapshot!),
          ],
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: OnyxColorTokens.backgroundPrimary,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: OnyxColorTokens.divider),
            ),
            child: TabBar(
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: OnyxColorTokens.accentPurple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              labelColor: OnyxColorTokens.accentPurple,
              unselectedLabelColor: OnyxColorTokens.textMuted,
              labelStyle: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
              tabs: const [
                Tab(text: 'TIMELINE'),
                Tab(text: 'REPLAY'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              children: [
                entries.isEmpty
                    ? _EmptyLifecycleState(
                        message:
                            'No lifecycle entries yet. Zara is standing by for the next verified incident.',
                      )
                    : ListView.separated(
                        itemCount: entries.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          return _LifecycleEntryCard(entry: entries[index]);
                        },
                      ),
                replayFrames.isEmpty
                    ? _EmptyLifecycleState(
                        message:
                            'Replay checkpoints will appear here once EventStore accumulates auditable command decisions.',
                      )
                    : ListView.separated(
                        itemCount: replayFrames.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          return _ReplayFrameCard(frame: replayFrames[index]);
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLifecycleState extends StatelessWidget {
  final String message;

  const _EmptyLifecycleState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          color: OnyxColorTokens.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EventStoreAuditStrip extends StatelessWidget {
  final OnyxEventSourcingSnapshot snapshot;

  const _EventStoreAuditStrip({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final latestTime = snapshot.latestOccurredAtUtc == null
        ? 'Awaiting events'
        : _formatLifecycleTime(snapshot.latestOccurredAtUtc!);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OnyxColorTokens.accentPurple.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: OnyxColorTokens.accentPurple.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OnyxEventStoreStatusChip(snapshot: snapshot),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  snapshot.deterministicSummary,
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _LifecyclePill(
                label: '${snapshot.eventCount} events',
                accent: OnyxColorTokens.accentPurple,
              ),
              _LifecyclePill(
                label: 'SEQ ${snapshot.latestSequence}',
                accent: OnyxColorTokens.accentPurple,
              ),
              _LifecyclePill(
                label: snapshot.latestSemanticLabel,
                accent: OnyxColorTokens.accentGreen,
              ),
              _LifecyclePill(
                label: latestTime,
                accent: OnyxColorTokens.textMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReplayFrameCard extends StatelessWidget {
  final EventDrivenPageState frame;

  const _ReplayFrameCard({required this.frame});

  @override
  Widget build(BuildContext context) {
    final accent = _surfaceAccent(frame.surface);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OnyxColorTokens.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _LifecyclePill(
                label: _surfaceLabel(frame.surface),
                accent: accent,
              ),
              _LifecyclePill(
                label: frame.record.semanticLabel,
                accent: OnyxColorTokens.accentPurple,
              ),
              _LifecyclePill(
                label: 'SEQ ${frame.sequence}',
                accent: OnyxColorTokens.textMuted,
              ),
              _LifecyclePill(
                label: _stateLabel(frame.state),
                accent: _stateAccent(frame.state),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            frame.question,
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            frame.primaryAnswer,
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            frame.supportingAnswer,
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  frame.reference,
                  style: GoogleFonts.inter(
                    color: accent.withValues(alpha: 0.82),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _formatLifecycleTime(frame.occurredAtUtc),
                style: GoogleFonts.inter(
                  color: OnyxColorTokens.textDisabled,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _surfaceLabel(OnyxReplaySurface surface) {
    return switch (surface) {
      OnyxReplaySurface.intel => 'INTEL',
      OnyxReplaySurface.track => 'TRACK',
      OnyxReplaySurface.queue => 'QUEUE',
      OnyxReplaySurface.dispatch => 'DISPATCH',
      OnyxReplaySurface.comms => 'COMMS',
      OnyxReplaySurface.guards => 'GUARDS',
      OnyxReplaySurface.shell => 'SYSTEM',
    };
  }

  Color _surfaceAccent(OnyxReplaySurface surface) {
    return switch (surface) {
      OnyxReplaySurface.intel => OnyxColorTokens.accentSky,
      OnyxReplaySurface.track => OnyxColorTokens.accentAmber,
      OnyxReplaySurface.queue => OnyxColorTokens.accentPurple,
      OnyxReplaySurface.dispatch => OnyxColorTokens.accentRed,
      OnyxReplaySurface.comms => OnyxColorTokens.accentGreen,
      OnyxReplaySurface.guards => OnyxColorTokens.accentGreen,
      OnyxReplaySurface.shell => OnyxColorTokens.textMuted,
    };
  }

  String _stateLabel(OnyxGlobalSystemState state) {
    return switch (state) {
      OnyxGlobalSystemState.nominal => 'NOMINAL',
      OnyxGlobalSystemState.elevatedWatch => 'ELEVATED WATCH',
      OnyxGlobalSystemState.activeIncident => 'ACTIVE INCIDENT',
      OnyxGlobalSystemState.critical => 'CRITICAL',
    };
  }

  Color _stateAccent(OnyxGlobalSystemState state) {
    return switch (state) {
      OnyxGlobalSystemState.nominal => OnyxColorTokens.accentGreen,
      OnyxGlobalSystemState.elevatedWatch => OnyxColorTokens.accentAmber,
      OnyxGlobalSystemState.activeIncident => OnyxColorTokens.accentPurple,
      OnyxGlobalSystemState.critical => OnyxColorTokens.accentRed,
    };
  }
}

class _LifecycleEntryCard extends StatelessWidget {
  final OnyxIncidentLifecycleEntry entry;

  const _LifecycleEntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final accent = switch (entry.actor) {
      OnyxIncidentLifecycleActor.zara => OnyxColorTokens.accentPurple,
      OnyxIncidentLifecycleActor.client => OnyxColorTokens.accentGreen,
      OnyxIncidentLifecycleActor.officer => OnyxColorTokens.accentGreen,
      OnyxIncidentLifecycleActor.dispatch => OnyxColorTokens.accentRed,
      OnyxIncidentLifecycleActor.system => OnyxColorTokens.textMuted,
    };
    final actorLabel = switch (entry.actor) {
      OnyxIncidentLifecycleActor.zara => 'ZARA',
      OnyxIncidentLifecycleActor.client => 'CLIENT',
      OnyxIncidentLifecycleActor.officer => 'OFFICER',
      OnyxIncidentLifecycleActor.dispatch => 'DISPATCH',
      OnyxIncidentLifecycleActor.system => 'SYSTEM',
    };
    final stageLabel = switch (entry.stage) {
      OnyxIncidentLifecycleStage.detection => 'DETECTION',
      OnyxIncidentLifecycleStage.verification => 'VERIFICATION',
      OnyxIncidentLifecycleStage.decision => 'DECISION',
      OnyxIncidentLifecycleStage.dispatch => 'DISPATCH',
      OnyxIncidentLifecycleStage.confirmation => 'CONFIRMATION',
      OnyxIncidentLifecycleStage.resolution => 'RESOLUTION',
      OnyxIncidentLifecycleStage.recorded => 'RECORDED',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OnyxColorTokens.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: entry.major ? 12 : 8,
            height: entry.major ? 12 : 8,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: Border.all(color: accent.withValues(alpha: 0.4)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _LifecyclePill(label: stageLabel, accent: accent),
                    _LifecyclePill(label: actorLabel, accent: accent),
                    _LifecyclePill(
                      label: entry.reference,
                      accent: OnyxColorTokens.accentPurple,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  entry.title,
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.detail,
                  style: GoogleFonts.inter(
                    color: OnyxColorTokens.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatLifecycleTime(entry.occurredAtUtc),
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textDisabled,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LifecyclePill extends StatelessWidget {
  final String label;
  final Color accent;

  const _LifecyclePill({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: accent == OnyxColorTokens.textMuted
              ? OnyxColorTokens.textSecondary
              : accent,
          fontSize: 8,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

String _formatLifecycleTime(DateTime utc) {
  final local = utc.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
