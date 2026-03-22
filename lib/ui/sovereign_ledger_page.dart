import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../application/report_entry_context.dart';
import '../application/monitoring_scene_review_store.dart';
import '../domain/crm/reporting/report_section_configuration.dart';
import '../domain/events/decision_created.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/execution_completed.dart';
import '../domain/events/execution_denied.dart';
import '../domain/events/guard_checked_in.dart';
import '../domain/events/incident_closed.dart';
import '../domain/events/intelligence_received.dart';
import '../domain/events/partner_dispatch_status_declared.dart';
import '../domain/events/patrol_completed.dart';
import '../domain/events/report_generated.dart';
import '../domain/events/response_arrived.dart';
import '../domain/events/vehicle_visit_review_recorded.dart';
import 'layout_breakpoints.dart';
import 'onyx_surface.dart';
import 'ui_action_logger.dart';

class SovereignLedgerPage extends StatefulWidget {
  final String clientId;
  final String? initialScopeClientId;
  final String? initialScopeSiteId;
  final List<DispatchEvent> events;
  final String initialFocusReference;
  final Map<String, MonitoringSceneReviewRecord> sceneReviewByIntelligenceId;
  final void Function(List<String> eventIds, String? selectedEventId)?
  onOpenEventsForScope;

  const SovereignLedgerPage({
    super.key,
    required this.clientId,
    this.initialScopeClientId,
    this.initialScopeSiteId,
    required this.events,
    this.initialFocusReference = '',
    this.sceneReviewByIntelligenceId = const {},
    this.onOpenEventsForScope,
  });

  @override
  State<SovereignLedgerPage> createState() => _SovereignLedgerPageState();
}

enum _LedgerFocusState { none, exact, scopeBacked, seeded }

class _LedgerCommandReceipt {
  final String label;
  final String message;
  final String detail;
  final Color accent;

  const _LedgerCommandReceipt({
    required this.label,
    required this.message,
    required this.detail,
    required this.accent,
  });
}

class _SovereignLedgerPageState extends State<SovereignLedgerPage> {
  static const _defaultCommandReceipt = _LedgerCommandReceipt(
    label: 'LEDGER READY',
    message: 'Verification and export actions stay pinned in this rail.',
    detail:
        'Lane pivots, continuity checks, and export handoffs remain visible while you keep reviewing the selected ledger entry.',
    accent: Color(0xFF8FD1FF),
  );
  String? _selectedEntryId;
  _ChainIntegrity _integrity = _ChainIntegrity.pending;
  _LedgerLaneFilter _laneFilter = _LedgerLaneFilter.all;
  _LedgerWorkspaceView _workspaceView = _LedgerWorkspaceView.caseFile;
  _LedgerCommandReceipt _commandReceipt = _defaultCommandReceipt;
  bool _desktopWorkspaceActive = false;

  @override
  Widget build(BuildContext context) {
    final scopeClientId = (widget.initialScopeClientId ?? '').trim();
    final scopeSiteId = (widget.initialScopeSiteId ?? '').trim();
    final hasScopeFocus = scopeClientId.isNotEmpty && scopeSiteId.isNotEmpty;
    final entries = _buildLedgerEntries(
      widget.events,
      clientId: scopeClientId,
      siteId: scopeSiteId,
      sceneReviewByIntelligenceId: widget.sceneReviewByIntelligenceId,
    );
    var list = entries.isEmpty ? _fallbackEntries : entries;
    final focusReference = widget.initialFocusReference.trim();
    final hasFocusReference = focusReference.isNotEmpty;
    var focusState = _LedgerFocusState.none;
    if (hasFocusReference) {
      final focusResolution = _resolveFocusSelection(
        entries: list,
        focusReference: focusReference,
      );
      if (focusResolution.entryId != null) {
        _selectedEntryId = focusResolution.entryId;
        focusState = focusResolution.state;
      } else {
        list = _injectFocusedLedgerEntry(
          entries: list,
          focusReference: focusReference,
        );
        final seededFocusId = _resolveFocusEntryId(
          entries: list,
          focusReference: focusReference,
        );
        if (seededFocusId != null) {
          _selectedEntryId = seededFocusId;
        }
        focusState = _LedgerFocusState.seeded;
      }
    }

    final effectiveLane = _effectiveLaneForEntries(list);
    final filteredEntries = list
        .where((entry) => _matchesLaneFilter(entry, effectiveLane))
        .toList(growable: false);
    final selectedPool = filteredEntries.isEmpty ? list : filteredEntries;
    _selectedEntryId ??= selectedPool.first.id;
    if (!selectedPool.any((entry) => entry.id == _selectedEntryId)) {
      _selectedEntryId = selectedPool.first.id;
    }
    final selected = selectedPool.firstWhere(
      (entry) => entry.id == _selectedEntryId,
      orElse: () => selectedPool.first,
    );
    final linkedEntries = _linkedEntriesForSelected(list, selected);

    final verifiedEntries = list.where((entry) => entry.verified).length;
    final pendingEntries = list.length - verifiedEntries;

    return OnyxPageScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final desktopWorkspace = constraints.maxWidth >= 1240;
          final boundedDesktopSurface =
              desktopWorkspace && allowEmbeddedPanelScroll(context);
          final ultrawideSurface = isUltrawideLayout(
            context,
            viewportWidth: constraints.maxWidth,
          );
          final widescreenSurface = isWidescreenLayout(
            context,
            viewportWidth: constraints.maxWidth,
          );
          final surfaceMaxWidth = ultrawideSurface
              ? constraints.maxWidth
              : widescreenSurface
              ? constraints.maxWidth * 0.94
              : 1760.0;

          final workspaceSection = OnyxSectionCard(
            title: 'Ledger Workspace',
            subtitle:
                'Lane-driven review for evidence continuity, report receipts, scene posture, and focus-linked handoff actions.',
            flexibleChild: boundedDesktopSurface,
            child: LayoutBuilder(
              builder: (context, workspaceConstraints) {
                final useThreeColumnLayout =
                    workspaceConstraints.maxWidth >= 1260;
                final useTwoColumnLayout = workspaceConstraints.maxWidth >= 900;
                final useEmbeddedPanels =
                    useTwoColumnLayout && allowEmbeddedPanelScroll(context);
                _desktopWorkspaceActive = useTwoColumnLayout;
                final workspace = _ledgerWorkspace(
                  entries: list,
                  filteredEntries: filteredEntries,
                  selected: selected,
                  linkedEntries: linkedEntries,
                  effectiveLane: effectiveLane,
                  hiddenEntries: list.length - filteredEntries.length,
                  useEmbeddedPanels: useEmbeddedPanels,
                  useThreeColumnLayout: useThreeColumnLayout,
                );
                if (!useTwoColumnLayout) {
                  return workspace;
                }
                if (boundedDesktopSurface && useEmbeddedPanels) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _workspaceStatusBanner(
                        context,
                        entries: list,
                        filteredEntries: filteredEntries,
                        selected: selected,
                        linkedEntries: linkedEntries,
                        effectiveLane: effectiveLane,
                      ),
                      const SizedBox(height: 10),
                      Expanded(child: workspace),
                    ],
                  );
                }
                final workspaceShell = useEmbeddedPanels
                    ? SizedBox(
                        height: useThreeColumnLayout ? 736 : 680,
                        child: workspace,
                      )
                    : workspace;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _workspaceStatusBanner(
                      context,
                      entries: list,
                      filteredEntries: filteredEntries,
                      selected: selected,
                      linkedEntries: linkedEntries,
                      effectiveLane: effectiveLane,
                    ),
                    const SizedBox(height: 12),
                    workspaceShell,
                  ],
                );
              },
            ),
          );

          final body = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _integritySummaryBar(
                verifiedEntries: verifiedEntries,
                pendingEntries: pendingEntries,
              ),
              if (hasFocusReference) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _focusBannerBackground(focusState),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _focusBannerBorder(focusState)),
                  ),
                  child: Text(
                    'Focus ${_focusBannerLabel(focusState)} • $focusReference',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFEAF1FB),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              if (hasScopeFocus) ...[
                const SizedBox(height: 10),
                Container(
                  key: const ValueKey('ledger-scope-banner'),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x141C3C57),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x4435506F)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scope focus active',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF8FD1FF),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$scopeClientId/$scopeSiteId',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFEAF1FB),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              _workspaceCommandBar(list),
              const SizedBox(height: 10),
              if (boundedDesktopSurface)
                Expanded(child: workspaceSection)
              else
                workspaceSection,
            ],
          );

          return OnyxViewportWorkspaceLayout(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            maxWidth: surfaceMaxWidth,
            spacing: 10,
            lockToViewport: boundedDesktopSurface,
            header: _heroHeader(
              entries: list,
              selected: selected,
              totalEntries: list.length,
              verifiedEntries: verifiedEntries,
            ),
            body: body,
          );
        },
      ),
    );
  }

  Widget _heroHeader({
    required List<_LedgerEntryView> entries,
    required _LedgerEntryView selected,
    required int totalEntries,
    required int verifiedEntries,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF241238), Color(0xFF111827)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF433267)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1080;
          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFA78BFA), Color(0xFF7C3AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Icons.account_tree_outlined,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sovereign Ledger',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFF6FBFF),
                            fontSize: compact ? 22 : 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Evidence continuity, verification state, and immutable event-chain review for the current focus.',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF95A9C7),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _heroChip('Integrity', _integrity.label),
                  _heroChip('Entries', '$totalEntries'),
                  _heroChip('Verified', '$verifiedEntries'),
                  _heroChip(
                    'Focus',
                    (selected.dispatchId ?? '').trim().isNotEmpty
                        ? selected.dispatchId!
                        : selected.id,
                  ),
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
                key: const ValueKey('ledger-hero-view-events-button'),
                icon: Icons.open_in_new,
                label: 'View Events',
                accent: const Color(0xFF93C5FD),
                onPressed: () => _openEventsForSelectedEntry(selected),
              ),
              _heroActionButton(
                key: const ValueKey('ledger-hero-verify-button'),
                icon: Icons.verified_rounded,
                label: 'Verify Chain',
                accent: const Color(0xFF59D79B),
                onPressed: () => _runIntegrityCheck(
                  entries,
                  action: 'ledger.hero_verify_chain',
                  extraContext: const {'from_hero': true},
                ),
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [titleBlock, const SizedBox(height: 16), actions],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: titleBlock),
              const SizedBox(width: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  void _openEventsForSelectedEntry(_LedgerEntryView selected) {
    final eventId = (selected.payload['eventId'] ?? '').toString().trim();
    if (widget.onOpenEventsForScope != null && eventId.isNotEmpty) {
      widget.onOpenEventsForScope!(<String>[eventId], eventId);
      logUiAction(
        'ledger.hero_view_events',
        context: {'entry_id': selected.id, 'event_id': eventId},
      );
      return;
    }
    logUiAction('ledger.hero_view_events', context: {'entry_id': selected.id});
    _showActionMessage(
      'Open Event Review to inspect ${eventId.isEmpty ? selected.id : eventId}.',
    );
  }

  void _openEntryInEventReview(_LedgerEntryView selected) {
    final eventId = (selected.payload['eventId'] ?? '').toString().trim();
    if (widget.onOpenEventsForScope != null && eventId.isNotEmpty) {
      widget.onOpenEventsForScope!(<String>[eventId], eventId);
      logUiAction(
        'ledger.view_in_event_review',
        context: {'entry_id': selected.id, 'event_id': eventId},
      );
      return;
    }
    logUiAction(
      'ledger.view_in_event_review',
      context: {'entry_id': selected.id},
    );
    _showActionMessage(
      'Open Event Review to inspect ${eventId.isEmpty ? selected.id : eventId}.',
    );
  }

  String? _resolveFocusEntryId({
    required List<_LedgerEntryView> entries,
    required String focusReference,
  }) {
    for (final entry in entries) {
      final payloadEventId = (entry.payload['eventId'] ?? '').toString().trim();
      final payloadIntelligenceId = (entry.payload['intelligenceId'] ?? '')
          .toString()
          .trim();
      final payloadDispatchId = (entry.payload['dispatchId'] ?? '')
          .toString()
          .trim();
      if (entry.id == focusReference ||
          (entry.dispatchId ?? '').trim() == focusReference ||
          payloadEventId == focusReference ||
          payloadIntelligenceId == focusReference ||
          payloadDispatchId == focusReference) {
        return entry.id;
      }
    }
    return null;
  }

  ({String? entryId, _LedgerFocusState state}) _resolveFocusSelection({
    required List<_LedgerEntryView> entries,
    required String focusReference,
  }) {
    final exactEntryId = _resolveFocusEntryId(
      entries: entries,
      focusReference: focusReference,
    );
    if (exactEntryId != null) {
      return (entryId: exactEntryId, state: _LedgerFocusState.exact);
    }
    final focusScope = _scopeForFocusReference(focusReference);
    if (focusScope != null) {
      for (final entry in entries) {
        if (_entryMatchesScope(
          entry,
          clientId: focusScope.$1,
          siteId: focusScope.$2,
        )) {
          return (entryId: entry.id, state: _LedgerFocusState.scopeBacked);
        }
      }
    }
    return (entryId: null, state: _LedgerFocusState.seeded);
  }

  (String, String)? _scopeForFocusReference(String focusReference) {
    final normalizedReference = focusReference.trim();
    if (normalizedReference.isEmpty) {
      return null;
    }
    DispatchEvent? matchedEvent;
    for (final event in widget.events) {
      final dispatchId = (_eventDispatchId(event) ?? '').trim();
      final matchesDispatch =
          dispatchId.isNotEmpty &&
          (dispatchId == normalizedReference ||
              'INC-$dispatchId' == normalizedReference);
      final matchesEventId = event.eventId.trim() == normalizedReference;
      final matchesIntelligenceId =
          event is IntelligenceReceived &&
          event.intelligenceId.trim() == normalizedReference;
      if (!matchesDispatch && !matchesEventId && !matchesIntelligenceId) {
        continue;
      }
      if (matchedEvent == null ||
          event.occurredAt.isAfter(matchedEvent.occurredAt)) {
        matchedEvent = event;
      }
    }
    if (matchedEvent == null) {
      return null;
    }
    final clientId = _eventClientId(matchedEvent).trim();
    final siteId = _eventSiteId(matchedEvent).trim();
    if (clientId.isEmpty || siteId.isEmpty) {
      return null;
    }
    return (clientId, siteId);
  }

  bool _entryMatchesScope(
    _LedgerEntryView entry, {
    required String clientId,
    required String siteId,
  }) {
    final entryClientId = (entry.payload['clientId'] ?? '').toString().trim();
    final entrySiteId = (entry.payload['siteId'] ?? '').toString().trim();
    return entryClientId == clientId && entrySiteId == siteId;
  }

  String _focusBannerLabel(_LedgerFocusState state) {
    return switch (state) {
      _LedgerFocusState.none => 'IDLE',
      _LedgerFocusState.exact => 'LINKED',
      _LedgerFocusState.scopeBacked => 'SCOPE-BACKED',
      _LedgerFocusState.seeded => 'SEEDED',
    };
  }

  Color _focusBannerBackground(_LedgerFocusState state) {
    return switch (state) {
      _LedgerFocusState.none => const Color(0x22192331),
      _LedgerFocusState.exact => const Color(0x2234D399),
      _LedgerFocusState.scopeBacked => const Color(0x223C79BB),
      _LedgerFocusState.seeded => const Color(0x333C79BB),
    };
  }

  Color _focusBannerBorder(_LedgerFocusState state) {
    return switch (state) {
      _LedgerFocusState.none => const Color(0x66435A76),
      _LedgerFocusState.exact => const Color(0x6634D399),
      _LedgerFocusState.scopeBacked => const Color(0x665FAAFF),
      _LedgerFocusState.seeded => const Color(0x665FAAFF),
    };
  }

  List<_LedgerEntryView> _injectFocusedLedgerEntry({
    required List<_LedgerEntryView> entries,
    required String focusReference,
  }) {
    if (entries.isEmpty) return entries;
    var maxSequence = 0;
    for (final entry in entries) {
      if (entry.sequence > maxSequence) {
        maxSequence = entry.sequence;
      }
    }
    final previousHash = entries.first.hash;
    final timestamp = DateTime.now().toUtc();
    final payload = <String, dynamic>{
      'eventId': focusReference,
      'sequence': maxSequence + 1,
      'version': 2,
      'type': 'SEEDED_LEDGER_FOCUS',
      'clientId': widget.clientId,
      'regionId': 'REGION-GAUTENG',
      'siteId': (widget.initialScopeSiteId ?? '').trim().isEmpty
          ? 'UNSCOPED-LANE'
          : widget.initialScopeSiteId!.trim(),
      'occurredAt': timestamp.toIso8601String(),
      'summary': 'Focused lane is waiting for the live ledger feed to arrive.',
      'dispatchId': null,
      'seededFocus': true,
    };
    final hash = sha256
        .convert(utf8.encode('${jsonEncode(payload)}|$previousHash'))
        .toString();
    final seeded = _LedgerEntryView(
      id: 'LED-SEED-$focusReference',
      sequence: maxSequence + 1,
      type: 'INCIDENT',
      title: 'Focused lane is waiting for the live ledger feed to arrive.',
      site: (widget.initialScopeSiteId ?? '').trim().isEmpty
          ? 'Focused Lane'
          : widget.initialScopeSiteId!.trim(),
      dispatchId: null,
      timestamp: timestamp,
      hash: hash,
      previousHash: previousHash,
      verified: true,
      typeColor: _typeColor('INCIDENT'),
      payload: payload,
    );
    return [seeded, ...entries];
  }

  Widget _integritySummaryBar({
    required int verifiedEntries,
    required int pendingEntries,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF101820),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'CHAIN INTEGRITY:',
            style: GoogleFonts.inter(
              color: const Color(0xFF7F91A8),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          _statusPill(
            icon: Icons.verified_rounded,
            label: '$verifiedEntries Verified',
            accent: _ChainIntegrity.intact.color,
          ),
          _statusPill(
            icon: Icons.schedule_rounded,
            label: '$pendingEntries Pending',
            accent: _ChainIntegrity.pending.color,
          ),
          _statusPill(
            icon: Icons.filter_alt_outlined,
            label:
                'Incident: ${widget.initialFocusReference.trim().isEmpty ? "Global" : widget.initialFocusReference.trim()}',
            accent: const Color(0xFF9CA3AF),
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

  Widget _workspaceCommandBar(List<_LedgerEntryView> entries) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: onyxWorkspaceSurfaceDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 960;
          final title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ledger Commands',
                style: GoogleFonts.rajdhani(
                  color: const Color(0xFFE6F0FF),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Quick integrity and export actions stay in reach while the main workspace handles review and continuity.',
                style: GoogleFonts.inter(
                  color: const Color(0xFF8EA5C6),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ],
          );
          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              FilledButton.tonalIcon(
                key: const ValueKey('ledger-context-verify-chain'),
                onPressed: () =>
                    _runIntegrityCheck(entries, action: 'ledger.verify_chain'),
                icon: const Icon(Icons.verified_rounded, size: 18),
                label: const Text('VERIFY CHAIN'),
              ),
              FilledButton.tonalIcon(
                key: const ValueKey('ledger-context-export-ledger'),
                onPressed: () => _exportLedger(entries),
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: const Text('EXPORT LEDGER'),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF101A2B),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFF223244)),
                ),
                child: Text(
                  'SOURCE ONYX CORE',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8FD1FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 12), actions],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: title),
              const SizedBox(width: 16),
              Flexible(child: actions),
            ],
          );
        },
      ),
    );
  }

  Widget _workspaceStatusBanner(
    BuildContext context, {
    required List<_LedgerEntryView> entries,
    required List<_LedgerEntryView> filteredEntries,
    required _LedgerEntryView selected,
    required List<_LedgerEntryView> linkedEntries,
    required _LedgerLaneFilter effectiveLane,
  }) {
    final reportEntry = _firstEntryForLane(entries, _LedgerLaneFilter.reports);
    final intelligenceEntry = _firstEntryForLane(
      entries,
      _LedgerLaneFilter.intelligence,
    );
    final attentionEntry = _firstEntryForLane(
      entries,
      _LedgerLaneFilter.attention,
    );
    return Container(
      key: const ValueKey('ledger-workspace-status-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _workspaceStatusPill(
                icon: Icons.filter_list_rounded,
                label: '${filteredEntries.length} Visible',
                accent: const Color(0xFF59D79B),
              ),
              _workspaceStatusPill(
                icon: Icons.radar_outlined,
                label: 'Lane ${effectiveLane.label}',
                accent: effectiveLane.accent,
              ),
              _workspaceStatusPill(
                icon: Icons.dashboard_customize_outlined,
                label: 'View ${_workspaceView.label}',
                accent: _workspaceView.accent,
              ),
              _workspaceStatusPill(
                icon: Icons.flag_outlined,
                label: 'Focus ${selected.id}',
                accent: selected.typeColor,
              ),
              _workspaceStatusPill(
                icon: Icons.link_outlined,
                label: '${linkedEntries.length} Linked',
                accent: linkedEntries.isEmpty
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF22D3EE),
              ),
              _workspaceStatusPill(
                icon: Icons.verified_outlined,
                label: _integrity.label,
                accent: _integrity.color,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _workspaceStatusAction(
                key: const ValueKey('ledger-workspace-banner-open-all'),
                label: 'All Entries',
                selected: effectiveLane == _LedgerLaneFilter.all,
                accent: _LedgerLaneFilter.all.accent,
                onTap: () =>
                    _setLedgerLaneFilter(_LedgerLaneFilter.all, entries),
              ),
              _workspaceStatusAction(
                key: const ValueKey('ledger-workspace-banner-open-reports'),
                label: 'Reports Lane',
                selected: effectiveLane == _LedgerLaneFilter.reports,
                accent: _LedgerLaneFilter.reports.accent,
                onTap: reportEntry == null
                    ? null
                    : () => _setLedgerLaneFilter(
                        _LedgerLaneFilter.reports,
                        entries,
                      ),
              ),
              _workspaceStatusAction(
                key: const ValueKey('ledger-workspace-banner-open-attention'),
                label: 'Attention Lane',
                selected: effectiveLane == _LedgerLaneFilter.attention,
                accent: _LedgerLaneFilter.attention.accent,
                onTap: attentionEntry == null
                    ? null
                    : () => _setLedgerLaneFilter(
                        _LedgerLaneFilter.attention,
                        entries,
                      ),
              ),
              _workspaceStatusAction(
                key: const ValueKey('ledger-workspace-banner-open-case-file'),
                label: 'Case File',
                selected: _workspaceView == _LedgerWorkspaceView.caseFile,
                accent: _LedgerWorkspaceView.caseFile.accent,
                onTap: () =>
                    _setLedgerWorkspaceView(_LedgerWorkspaceView.caseFile),
              ),
              _workspaceStatusAction(
                key: const ValueKey('ledger-workspace-banner-open-evidence'),
                label: 'Evidence View',
                selected: _workspaceView == _LedgerWorkspaceView.evidence,
                accent: _LedgerWorkspaceView.evidence.accent,
                onTap: () =>
                    _setLedgerWorkspaceView(_LedgerWorkspaceView.evidence),
              ),
              _workspaceStatusAction(
                key: const ValueKey('ledger-workspace-banner-open-chain'),
                label: 'Chain View',
                selected: _workspaceView == _LedgerWorkspaceView.chain,
                accent: _LedgerWorkspaceView.chain.accent,
                onTap: () =>
                    _setLedgerWorkspaceView(_LedgerWorkspaceView.chain),
              ),
              _workspaceStatusAction(
                key: const ValueKey('ledger-workspace-banner-verify-chain'),
                label: 'Verify Chain',
                selected: false,
                accent: const Color(0xFF59D79B),
                onTap: () =>
                    _runIntegrityCheck(entries, action: 'ledger.verify_chain'),
              ),
              _workspaceStatusAction(
                key: const ValueKey('ledger-workspace-banner-open-events'),
                label: 'Open Events',
                selected: false,
                accent: const Color(0xFF93C5FD),
                onTap: () => _openEventsForSelectedEntry(selected),
              ),
              _workspaceStatusAction(
                key: const ValueKey(
                  'ledger-workspace-banner-open-intelligence',
                ),
                label: 'AI Evidence',
                selected: effectiveLane == _LedgerLaneFilter.intelligence,
                accent: _LedgerLaneFilter.intelligence.accent,
                onTap: intelligenceEntry == null
                    ? null
                    : () => _setLedgerLaneFilter(
                        _LedgerLaneFilter.intelligence,
                        entries,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'The selected ledger focus stays pinned while lane pivots, case-board swaps, integrity reruns, and event handoffs stay available from the workspace shell.',
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ledgerWorkspace({
    required List<_LedgerEntryView> entries,
    required List<_LedgerEntryView> filteredEntries,
    required _LedgerEntryView selected,
    required List<_LedgerEntryView> linkedEntries,
    required _LedgerLaneFilter effectiveLane,
    required int hiddenEntries,
    required bool useEmbeddedPanels,
    required bool useThreeColumnLayout,
  }) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final ultrawideWorkspace = viewportWidth >= 2600;
    final widescreenWorkspace = viewportWidth >= 2000;
    final railGap = ultrawideWorkspace ? 12.0 : 10.0;
    final laneRailWidth = ultrawideWorkspace
        ? 336.0
        : widescreenWorkspace
        ? 324.0
        : 320.0;
    final contextRailWidth = ultrawideWorkspace
        ? 312.0
        : widescreenWorkspace
        ? 304.0
        : 296.0;

    if (useThreeColumnLayout && useEmbeddedPanels) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: laneRailWidth,
            child: _ledgerLaneRail(
              entries: entries,
              filteredEntries: filteredEntries,
              effectiveLane: effectiveLane,
              useExpandedBody: true,
            ),
          ),
          SizedBox(width: railGap),
          Expanded(
            flex: 2,
            child: _selectedEntryBoard(
              entries: entries,
              selected: selected,
              linkedEntries: linkedEntries,
              useExpandedBody: true,
            ),
          ),
          SizedBox(width: railGap),
          SizedBox(
            width: contextRailWidth,
            child: _ledgerContextRail(
              entries: entries,
              filteredEntries: filteredEntries,
              selected: selected,
              linkedEntries: linkedEntries,
              hiddenEntries: hiddenEntries,
              useExpandedBody: true,
            ),
          ),
        ],
      );
    }

    if (useEmbeddedPanels) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: laneRailWidth,
            child: _ledgerLaneRail(
              entries: entries,
              filteredEntries: filteredEntries,
              effectiveLane: effectiveLane,
              useExpandedBody: true,
            ),
          ),
          SizedBox(width: railGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _selectedEntryBoard(
                    entries: entries,
                    selected: selected,
                    linkedEntries: linkedEntries,
                    useExpandedBody: true,
                  ),
                ),
                SizedBox(height: railGap),
                SizedBox(
                  height: ultrawideWorkspace ? 244 : 228,
                  child: _ledgerContextRail(
                    entries: entries,
                    filteredEntries: filteredEntries,
                    selected: selected,
                    linkedEntries: linkedEntries,
                    hiddenEntries: hiddenEntries,
                    useExpandedBody: false,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ledgerLaneRail(
          entries: entries,
          filteredEntries: filteredEntries,
          effectiveLane: effectiveLane,
          useExpandedBody: false,
        ),
        const SizedBox(height: 12),
        _selectedEntryBoard(
          entries: entries,
          selected: selected,
          linkedEntries: linkedEntries,
          useExpandedBody: false,
        ),
        const SizedBox(height: 12),
        _ledgerContextRail(
          entries: entries,
          filteredEntries: filteredEntries,
          selected: selected,
          linkedEntries: linkedEntries,
          hiddenEntries: hiddenEntries,
          useExpandedBody: false,
        ),
      ],
    );
  }

  Widget _ledgerLaneRail({
    required List<_LedgerEntryView> entries,
    required List<_LedgerEntryView> filteredEntries,
    required _LedgerLaneFilter effectiveLane,
    required bool useExpandedBody,
  }) {
    final list = filteredEntries.isEmpty
        ? _emptyLaneState()
        : ListView.separated(
            shrinkWrap: !useExpandedBody,
            primary: useExpandedBody,
            physics: useExpandedBody
                ? null
                : const NeverScrollableScrollPhysics(),
            itemCount: filteredEntries.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final entry = filteredEntries[index];
              return _entryCard(
                entry,
                isSelected: entry.id == _selectedEntryId,
              );
            },
          );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: onyxWorkspaceSurfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ledger Lanes',
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFE6F0FF),
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Shift between the full chain, receipt-heavy rows, AI evidence, continuity milestones, and items that need operator attention.',
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA5C6),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _LedgerLaneFilter.values
                .map((lane) => _laneChip(lane, entries, effectiveLane))
                .toList(),
          ),
          const SizedBox(height: 12),
          if (useExpandedBody) Expanded(child: list) else list,
        ],
      ),
    );
  }

  Widget _emptyLaneState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: onyxSelectableRowSurfaceDecoration(isSelected: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No entries in this lane yet.',
            style: GoogleFonts.inter(
              color: const Color(0xFFE6F0FF),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Return to the full ledger stream to recover the wider continuity stack.',
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA5C6),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          if (_laneFilter != _LedgerLaneFilter.all) ...[
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              key: const ValueKey('ledger-empty-reset-lane'),
              onPressed: () =>
                  _setLedgerLaneFilter(_LedgerLaneFilter.all, const []),
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text('Reset Lane'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _laneChip(
    _LedgerLaneFilter lane,
    List<_LedgerEntryView> entries,
    _LedgerLaneFilter effectiveLane,
  ) {
    final selected = lane == effectiveLane;
    final matchingEntries = entries
        .where((entry) => _matchesLaneFilter(entry, lane))
        .toList(growable: false);
    return InkWell(
      key: ValueKey('ledger-lane-filter-${lane.key}'),
      onTap: () => _setLedgerLaneFilter(lane, entries),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? lane.accent.withValues(alpha: 0.16)
              : const Color(0xFF0B1930),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? lane.accent.withValues(alpha: 0.42)
                : const Color(0xFF223244),
          ),
        ),
        child: Text(
          '${lane.label} ${matchingEntries.length}',
          style: GoogleFonts.inter(
            color: selected ? lane.accent : const Color(0xFF9AB1CF),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _entryCard(_LedgerEntryView entry, {required bool isSelected}) {
    final eventId = (entry.payload['eventId'] ?? '').toString().trim();
    final reportConfiguration = _reportConfigurationPayloadForEntry(entry);
    final sceneReview = _sceneReviewPayloadForEntry(entry);
    return InkWell(
      key: ValueKey('ledger-entry-card-${entry.id}'),
      onTap: () => _focusEntry(entry),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: onyxSelectableRowSurfaceDecoration(isSelected: isSelected),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: entry.typeColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFE6F0FF),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$eventId • ${_clock(entry.timestamp)} UTC',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF8EA5C6),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x129FD9FF),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0x409FD9FF)),
                    ),
                    child: Text(
                      'FOCUS',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF9FD9FF),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
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
                _typeChip(entry.type, entry.typeColor),
                if (entry.verified)
                  _typeChip('VERIFIED', const Color(0xFF10B981)),
                if ((entry.site ?? '').trim().isNotEmpty)
                  _pill('Site ${entry.site!}'),
                if ((entry.dispatchId ?? '').trim().isNotEmpty)
                  _pill('Dispatch ${entry.dispatchId!}'),
                if (reportConfiguration != null)
                  _pill(
                    ((reportConfiguration['tracked'] ?? false) as bool)
                        ? 'Receipt Tracked'
                        : 'Legacy config',
                  ),
                if (sceneReview != null) _pill('Scene Review'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF111822),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF2A374A)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: const Color(0xFF9BB0CE),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _selectedEntryBoard({
    required List<_LedgerEntryView> entries,
    required _LedgerEntryView selected,
    required List<_LedgerEntryView> linkedEntries,
    required bool useExpandedBody,
  }) {
    final panel = switch (_workspaceView) {
      _LedgerWorkspaceView.caseFile => SingleChildScrollView(
        key: const ValueKey('ledger-workspace-panel-case-file'),
        child: _caseFilePanel(selected),
      ),
      _LedgerWorkspaceView.evidence => SingleChildScrollView(
        key: const ValueKey('ledger-workspace-panel-evidence'),
        child: _evidencePanel(selected, linkedEntries),
      ),
      _LedgerWorkspaceView.chain => SingleChildScrollView(
        key: const ValueKey('ledger-workspace-panel-chain'),
        child: _chainPanel(selected, entries),
      ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: onyxWorkspaceSurfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selected Entry',
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFE7F1FF),
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'A full fidelity case board for the active ledger entry, including report receipts, scene evidence, and cryptographic continuity.',
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA5C5),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          _entryFocusBanner(selected),
          const SizedBox(height: 10),
          _entryWorkspaceActions(selected),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _LedgerWorkspaceView.values
                .map((view) => _workspaceChip(view))
                .toList(),
          ),
          const SizedBox(height: 12),
          if (useExpandedBody) Expanded(child: panel) else panel,
        ],
      ),
    );
  }

  Widget _entryFocusBanner(_LedgerEntryView selected) {
    final summary = (selected.payload['summary'] ?? selected.title)
        .toString()
        .trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            selected.typeColor.withValues(alpha: 0.18),
            const Color(0xFF101A2B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected.typeColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACTIVE LEDGER FOCUS',
            style: GoogleFonts.inter(
              color: selected.typeColor,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            selected.id,
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFF4F8FF),
              fontSize: 30,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            summary,
            style: GoogleFonts.inter(
              color: const Color(0xFFD8E4F5),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill('Lane ${_preferredLaneForEntry(selected).label}'),
              _pill('Sequence #${selected.sequence}'),
              if ((selected.site ?? '').trim().isNotEmpty)
                _pill('Site ${selected.site!}'),
              if ((selected.dispatchId ?? '').trim().isNotEmpty)
                _pill('Dispatch ${selected.dispatchId!}'),
              _pill('Integrity ${selected.verified ? "Verified" : "Pending"}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _workspaceChip(_LedgerWorkspaceView view) {
    final selected = _workspaceView == view;
    return InkWell(
      key: ValueKey('ledger-workspace-view-${view.key}'),
      onTap: () => _setLedgerWorkspaceView(view),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? view.accent.withValues(alpha: 0.16)
              : const Color(0xFF0B1930),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? view.accent.withValues(alpha: 0.45)
                : const Color(0xFF223244),
          ),
        ),
        child: Text(
          view.label,
          style: GoogleFonts.inter(
            color: selected ? view.accent : const Color(0xFF9DB1CF),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _entryWorkspaceActions(_LedgerEntryView selected) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonalIcon(
          key: const ValueKey('ledger-entry-view-event-review'),
          onPressed: () => _openEntryInEventReview(selected),
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: const Text('VIEW IN EVENT REVIEW'),
        ),
        FilledButton.tonalIcon(
          key: const ValueKey('ledger-entry-export-data'),
          onPressed: () => _exportEntryData(selected),
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('EXPORT ENTRY DATA'),
        ),
      ],
    );
  }

  Widget _caseFilePanel(_LedgerEntryView selected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _detailCard(
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
                          'Ledger Entry',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF8EA4C2),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selected.id,
                          style: GoogleFonts.inter(
                            color: const Color(0xFFEAF1FB),
                            fontSize: 37,
                            fontWeight: FontWeight.w700,
                            height: 0.95,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 6,
                    children: [
                      _typeChip(selected.type, selected.typeColor),
                      if (selected.verified)
                        _typeChip('VERIFIED', const Color(0xFF10B981)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                selected.title,
                style: GoogleFonts.inter(
                  color: const Color(0xFFD9E7FA),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              const Divider(color: Color(0x332A374A), height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _kvMini('SEQUENCE', '#${selected.sequence}')),
                  const SizedBox(width: 18),
                  Expanded(
                    child: _kvMini(
                      'TIMESTAMP (UTC)',
                      _fullTimestamp(selected.timestamp),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _detailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _blockTitle('CONTEXT'),
              const SizedBox(height: 8),
              if (selected.site != null) _contextRow('Site', selected.site!),
              if (selected.dispatchId != null)
                _contextRow('Dispatch ID', selected.dispatchId!),
              _contextRow('Type', selected.type),
            ],
          ),
        ),
        if (_reportConfigurationPayloadForEntry(selected) != null) ...[
          const SizedBox(height: 8),
          _detailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _blockTitle('REPORT CONFIGURATION'),
                const SizedBox(height: 8),
                _contextRow(
                  'Config',
                  ((_reportConfigurationPayloadForEntry(selected)!['tracked'] ??
                              false)
                          as bool)
                      ? 'Tracked'
                      : 'Legacy',
                ),
                _contextRow(
                  'Branding',
                  (_reportConfigurationPayloadForEntry(
                            selected,
                          )!['branding_mode_label'] ??
                          '')
                      .toString(),
                ),
                _contextRow(
                  'Branding Source',
                  (_reportConfigurationPayloadForEntry(
                            selected,
                          )!['branding_source_label'] ??
                          '')
                      .toString(),
                ),
                _contextRow(
                  'Branding Summary',
                  (_reportConfigurationPayloadForEntry(
                            selected,
                          )!['branding_summary'] ??
                          '')
                      .toString(),
                ),
                _contextRow(
                  'Summary',
                  (_reportConfigurationPayloadForEntry(selected)!['summary'] ??
                          '')
                      .toString(),
                ),
                _contextRow(
                  'Included',
                  (_reportConfigurationPayloadForEntry(
                            selected,
                          )!['included_sections_label'] ??
                          '')
                      .toString(),
                ),
                _contextRow(
                  'Omitted',
                  (_reportConfigurationPayloadForEntry(
                            selected,
                          )!['omitted_sections_label'] ??
                          '')
                      .toString(),
                ),
              ],
            ),
          ),
        ],
        if (_sceneReviewPayloadForEntry(selected) != null) ...[
          const SizedBox(height: 8),
          _detailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _blockTitle('SCENE REVIEW'),
                const SizedBox(height: 8),
                _contextRow(
                  'Source',
                  (_sceneReviewPayloadForEntry(selected)!['source_label'] ?? '')
                      .toString(),
                ),
                _contextRow(
                  'Posture',
                  (_sceneReviewPayloadForEntry(selected)!['posture_label'] ??
                          '')
                      .toString(),
                ),
                if (((_sceneReviewPayloadForEntry(
                              selected,
                            )!['decision_label'] ??
                            '')
                        .toString()
                        .trim())
                    .isNotEmpty)
                  _contextRow(
                    'Action',
                    (_sceneReviewPayloadForEntry(selected)!['decision_label'] ??
                            '')
                        .toString(),
                  ),
                _contextRow(
                  'Reviewed At',
                  (_sceneReviewPayloadForEntry(selected)!['reviewed_at_utc'] ??
                          '')
                      .toString(),
                ),
                _contextRow(
                  'Summary',
                  (_sceneReviewPayloadForEntry(selected)!['summary'] ?? '')
                      .toString(),
                ),
                if (((_sceneReviewPayloadForEntry(
                              selected,
                            )!['decision_summary'] ??
                            '')
                        .toString()
                        .trim())
                    .isNotEmpty)
                  _contextRow(
                    'Decision Detail',
                    (_sceneReviewPayloadForEntry(
                              selected,
                            )!['decision_summary'] ??
                            '')
                        .toString(),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        _detailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _blockTitle('CRYPTOGRAPHIC CHAIN'),
              const SizedBox(height: 8),
              _hashBlock(
                'Current Hash',
                selected.hash,
                const Color(0xFF10B981),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 14,
                  color: Color(0x668EA4C2),
                ),
              ),
              const SizedBox(height: 6),
              _hashBlock(
                'Previous Hash',
                selected.previousHash,
                const Color(0xFF22D3EE),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _detailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _blockTitle('VERIFICATION STATUS'),
              const SizedBox(height: 8),
              _verifyLine(
                'Hash integrity verified',
                'Entry matches cryptographic signature',
              ),
              _verifyLine(
                'Chain linkage confirmed',
                'Previous hash reference is valid',
              ),
              _verifyLine(
                'Timestamp sequence valid',
                'Entry follows chronological order',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _evidencePanel(
    _LedgerEntryView selected,
    List<_LedgerEntryView> linkedEntries,
  ) {
    final payload = selected.payload;
    final sceneReview = _sceneReviewPayloadForEntry(selected);
    final reportConfiguration = _reportConfigurationPayloadForEntry(selected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _detailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _blockTitle('EVIDENCE SNAPSHOT'),
              const SizedBox(height: 8),
              _contextRow(
                'Event ID',
                (payload['eventId'] ?? selected.id).toString(),
              ),
              _contextRow('Client', (payload['clientId'] ?? '').toString()),
              _contextRow('Site', (payload['siteId'] ?? '').toString()),
              if ((payload['provider'] ?? '').toString().trim().isNotEmpty)
                _contextRow('Provider', payload['provider'].toString()),
              if ((payload['sourceType'] ?? '').toString().trim().isNotEmpty)
                _contextRow('Source', payload['sourceType'].toString()),
              if ((payload['riskScore'] ?? '').toString().trim().isNotEmpty)
                _contextRow('Risk Score', payload['riskScore'].toString()),
              if ((payload['evidenceRecordHash'] ?? '')
                  .toString()
                  .trim()
                  .isNotEmpty)
                _contextRow(
                  'Evidence Hash',
                  payload['evidenceRecordHash'].toString(),
                ),
            ],
          ),
        ),
        if (sceneReview != null) ...[
          const SizedBox(height: 8),
          _detailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _blockTitle('SCENE REVIEW'),
                const SizedBox(height: 8),
                _contextRow(
                  'Source',
                  (sceneReview['source_label'] ?? '').toString(),
                ),
                _contextRow(
                  'Posture',
                  (sceneReview['posture_label'] ?? '').toString(),
                ),
                if ((sceneReview['decision_label'] ?? '')
                    .toString()
                    .trim()
                    .isNotEmpty)
                  _contextRow(
                    'Action',
                    (sceneReview['decision_label'] ?? '').toString(),
                  ),
                _contextRow(
                  'Decision Detail',
                  (sceneReview['decision_summary'] ??
                          sceneReview['summary'] ??
                          '')
                      .toString(),
                ),
              ],
            ),
          ),
        ],
        if (reportConfiguration != null) ...[
          const SizedBox(height: 8),
          _detailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _blockTitle('REPORT RECEIPT'),
                const SizedBox(height: 8),
                _contextRow(
                  'Config',
                  ((reportConfiguration['tracked'] ?? false) as bool)
                      ? 'Tracked'
                      : 'Legacy',
                ),
                _contextRow(
                  'Brand Source',
                  (reportConfiguration['branding_source_label'] ?? '')
                      .toString(),
                ),
                _contextRow(
                  'Included',
                  (reportConfiguration['included_sections_label'] ?? '')
                      .toString(),
                ),
                _contextRow(
                  'Omitted',
                  (reportConfiguration['omitted_sections_label'] ?? '')
                      .toString(),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        _detailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _blockTitle('LINKED CONTINUITY'),
              const SizedBox(height: 8),
              if (linkedEntries.isEmpty)
                Text(
                  'No adjacent ledger entries share this dispatch or site scope.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8EA5C6),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                )
              else
                ...linkedEntries.map(_linkedEntryMiniCard),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _outlineButton(
          'COPY ENTRY EXPORT',
          onTap: () => _exportEntryData(selected),
        ),
      ],
    );
  }

  Widget _chainPanel(
    _LedgerEntryView selected,
    List<_LedgerEntryView> entries,
  ) {
    final hasScopeLane =
        _preferredLaneForEntry(selected) != _LedgerLaneFilter.all;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _detailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _blockTitle('CHAIN STATUS'),
              const SizedBox(height: 8),
              _contextRow('Integrity', _integrity.label),
              _contextRow('Sequence', '#${selected.sequence}'),
              _contextRow(
                'Next Reference',
                selected.previousHash == 'GENESIS' ? 'GENESIS' : 'HASH LINKED',
              ),
              _contextRow(
                'Lane',
                hasScopeLane
                    ? _preferredLaneForEntry(selected).label
                    : 'All Entries',
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _detailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _blockTitle('CRYPTOGRAPHIC CHAIN'),
              const SizedBox(height: 8),
              _hashBlock(
                'Current Hash',
                selected.hash,
                const Color(0xFF10B981),
              ),
              const SizedBox(height: 6),
              _hashBlock(
                'Previous Hash',
                selected.previousHash,
                const Color(0xFF22D3EE),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _detailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _blockTitle('VERIFICATION RUNBOOK'),
              const SizedBox(height: 8),
              _verifyLine(
                'Integrity replay is available',
                'Rerun the chain to confirm this entry still links to the adjacent ledger stack.',
              ),
              _verifyLine(
                'Operator export is available',
                'Copy the selected entry or the full ledger without leaving the current workspace.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _outlineButton(
          'RERUN INTEGRITY CHECK',
          onTap: () {
            _runIntegrityCheck(
              entries,
              action: 'ledger.workspace_verify_chain',
            );
          },
        ),
      ],
    );
  }

  Widget _ledgerContextRail({
    required List<_LedgerEntryView> entries,
    required List<_LedgerEntryView> filteredEntries,
    required _LedgerEntryView selected,
    required List<_LedgerEntryView> linkedEntries,
    required int hiddenEntries,
    required bool useExpandedBody,
  }) {
    final latestReport = _firstEntryForLane(entries, _LedgerLaneFilter.reports);
    final attentionEntry = _firstEntryForLane(
      entries,
      _LedgerLaneFilter.attention,
    );
    final continuityCard = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: onyxPanelSurfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _blockTitle('CONTINUITY STATUS'),
          const SizedBox(height: 8),
          _contextMetric(
            'Integrity',
            _integrity.label,
            accent: _integrity.color,
          ),
          _contextMetric(
            'Visible',
            '${filteredEntries.length}',
            accent: const Color(0xFF59D79B),
          ),
          _contextMetric(
            'Hidden',
            '$hiddenEntries',
            accent: hiddenEntries > 0
                ? const Color(0xFFF6C067)
                : const Color(0xFF8EA5C6),
          ),
          _contextMetric(
            'Focus',
            _preferredLaneForEntry(selected).label,
            accent: _preferredLaneForEntry(selected).accent,
          ),
        ],
      ),
    );
    final actionsCard = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: onyxPanelSurfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _blockTitle('WORKSPACE ACTIONS'),
          const SizedBox(height: 8),
          _outlineButton(
            'VERIFY CHAIN',
            onTap: () =>
                _runIntegrityCheck(entries, action: 'ledger.verify_chain'),
          ),
          const SizedBox(height: 6),
          _outlineButton('EXPORT LEDGER', onTap: () => _exportLedger(entries)),
          const SizedBox(height: 6),
          _contextActionButton(
            key: const ValueKey('ledger-context-focus-reports'),
            label: 'FOCUS REPORT RECEIPTS',
            enabled: latestReport != null,
            onTap: () {
              if (latestReport == null) {
                _showActionMessage(
                  'No report receipts are visible in the current ledger scope.',
                );
                return;
              }
              _focusEntry(latestReport, lane: _LedgerLaneFilter.reports);
            },
          ),
          const SizedBox(height: 6),
          _contextActionButton(
            key: const ValueKey('ledger-context-focus-attention'),
            label: 'FOCUS ATTENTION',
            enabled: attentionEntry != null,
            onTap: () {
              if (attentionEntry == null) {
                _showActionMessage(
                  'No attention items are visible in the current ledger scope.',
                );
                return;
              }
              _focusEntry(attentionEntry, lane: _LedgerLaneFilter.attention);
            },
          ),
          if (_laneFilter != _LedgerLaneFilter.all) ...[
            const SizedBox(height: 6),
            _contextActionButton(
              key: const ValueKey('ledger-context-reset-lane'),
              label: 'SHOW ALL ENTRIES',
              onTap: () => _setLedgerLaneFilter(_LedgerLaneFilter.all, entries),
            ),
          ],
        ],
      ),
    );
    final linkedScopeCard = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: onyxPanelSurfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _blockTitle('LINKED SCOPE'),
          const SizedBox(height: 8),
          if (linkedEntries.isEmpty)
            Text(
              'No adjacent rows share the active dispatch or site scope.',
              style: GoogleFonts.inter(
                color: const Color(0xFF8EA5C6),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            )
          else
            ...linkedEntries.map(_linkedEntryMiniCard),
        ],
      ),
    );
    final body = useExpandedBody
        ? SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                continuityCard,
                const SizedBox(height: 10),
                actionsCard,
                const SizedBox(height: 10),
                linkedScopeCard,
              ],
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              continuityCard,
              const SizedBox(height: 10),
              actionsCard,
              const SizedBox(height: 10),
              linkedScopeCard,
            ],
          );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: onyxWorkspaceSurfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Continuity Rail',
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFE6F0FF),
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Integrity actions, lane pivots, and linked continuity anchors for the current selection.',
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA5C6),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          if (_desktopWorkspaceActive) ...[
            _workspaceCommandReceiptCard(),
            const SizedBox(height: 12),
          ],
          if (useExpandedBody) Expanded(child: body) else body,
        ],
      ),
    );
  }

  Widget _workspaceCommandReceiptCard() {
    final receipt = _commandReceipt;
    return Container(
      key: const ValueKey('ledger-workspace-command-receipt'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: receipt.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: receipt.accent.withValues(alpha: 0.34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LATEST COMMAND',
            style: GoogleFonts.inter(
              color: receipt.accent,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            receipt.label,
            style: GoogleFonts.inter(
              color: const Color(0xFFEAF4FF),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            receipt.message,
            style: GoogleFonts.inter(
              color: const Color(0xFFEAF4FF),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            receipt.detail,
            style: GoogleFonts.inter(
              color: const Color(0xFF9AB1CF),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _contextMetric(String label, String value, {required Color accent}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0xFF8EA5C6),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: accent.withValues(alpha: 0.34)),
            ),
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contextActionButton({
    required Key key,
    required String label,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return InkWell(
      key: key,
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF0D1117) : const Color(0xFF10161F),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? const Color(0xFF2A374A) : const Color(0xFF1C2532),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: enabled ? const Color(0xFFD9E7FA) : const Color(0xFF6F829A),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Widget _linkedEntryMiniCard(_LedgerEntryView entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        key: ValueKey('ledger-linked-entry-${entry.id}'),
        onTap: () => _focusEntry(entry, lane: _preferredLaneForEntry(entry)),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: onyxSelectableRowSurfaceDecoration(isSelected: false),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.title,
                style: GoogleFonts.inter(
                  color: const Color(0xFFE6F0FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _typeChip(entry.type, entry.typeColor),
                  _pill(entry.id),
                  if ((entry.dispatchId ?? '').trim().isNotEmpty)
                    _pill('Dispatch ${entry.dispatchId!}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: child,
    );
  }

  Widget _typeChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _blockTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        color: const Color(0xFF9BB0CE),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.7,
      ),
    );
  }

  Widget _kvMini(String key, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          key,
          style: GoogleFonts.inter(
            color: const Color(0xFF8EA4C2),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            color: const Color(0xFFEAF1FB),
            fontSize: 30,
            fontWeight: FontWeight.w700,
            height: 0.95,
          ),
        ),
      ],
    );
  }

  Widget _contextRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              key,
              style: GoogleFonts.inter(
                color: const Color(0xFF9BB0CE),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                color: const Color(0xFFEAF1FB),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hashBlock(String label, String hash, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(0xFF8EA4C2),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0E14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF223244)),
          ),
          child: Text(
            hash,
            style: GoogleFonts.robotoMono(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _verifyLine(String title, String detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.circle, size: 6, color: Color(0xFF10B981)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEAF1FB),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  detail,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9BB0CE),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _outlineButton(String label, {Key? key, required VoidCallback onTap}) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2A374A)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: const Color(0xFFD9E7FA),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Widget _workspaceStatusPill({
    required IconData icon,
    required String label,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF111F33),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFFE8F1FF),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _workspaceStatusAction({
    required Key key,
    required String label,
    required bool selected,
    required Color accent,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: !enabled
              ? const Color(0xFF1D2937)
              : selected
              ? accent.withValues(alpha: 0.2)
              : const Color(0xFF111F33),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: !enabled
                ? const Color(0xFF314154)
                : selected
                ? accent.withValues(alpha: 0.75)
                : accent.withValues(alpha: 0.35),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: !enabled ? const Color(0xFF8EA4C2) : const Color(0xFFEAF1FB),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  void _exportLedger(List<_LedgerEntryView> entries) {
    final payload = entries.map(_entryToJson).toList(growable: false);
    final pretty = const JsonEncoder.withIndent('  ').convert(payload);
    Clipboard.setData(ClipboardData(text: pretty));
    logUiAction('ledger.export_all', context: {'entries': entries.length});
    _showActionMessage(
      'Ledger export copied (${entries.length} entries).',
      label: 'EXPORT LEDGER',
      detail:
          'The full continuity payload is on the clipboard while the active ledger selection stays in place.',
      accent: const Color(0xFF8FD1FF),
    );
  }

  void _setLedgerLaneFilter(
    _LedgerLaneFilter lane,
    List<_LedgerEntryView> entries,
  ) {
    if (_laneFilter == lane) {
      return;
    }
    final matchingEntries = entries
        .where((entry) => _matchesLaneFilter(entry, lane))
        .toList(growable: false);
    setState(() {
      _laneFilter = lane;
      if (matchingEntries.isNotEmpty &&
          !matchingEntries.any((entry) => entry.id == _selectedEntryId)) {
        _selectedEntryId = matchingEntries.first.id;
      }
    });
  }

  void _setLedgerWorkspaceView(_LedgerWorkspaceView view) {
    if (_workspaceView == view) {
      return;
    }
    setState(() {
      _workspaceView = view;
    });
  }

  void _focusEntry(
    _LedgerEntryView entry, {
    _LedgerLaneFilter? lane,
    _LedgerWorkspaceView? view,
  }) {
    setState(() {
      _selectedEntryId = entry.id;
      if (lane != null) {
        _laneFilter = lane;
      }
      if (view != null) {
        _workspaceView = view;
      }
    });
  }

  void _runIntegrityCheck(
    List<_LedgerEntryView> entries, {
    required String action,
    Map<String, Object?> extraContext = const {},
  }) {
    final intact = _verifyChain(entries);
    setState(() {
      _integrity = intact
          ? _ChainIntegrity.intact
          : _ChainIntegrity.compromised;
    });
    logUiAction(
      action,
      context: <String, Object?>{
        'entries': entries.length,
        'result': intact ? 'intact' : 'compromised',
        ...extraContext,
      },
    );
    _showActionMessage(
      intact
          ? 'Chain verification returned intact.'
          : 'Chain verification detected a continuity mismatch.',
      label: 'VERIFY CHAIN',
      detail:
          'Continuity state remains pinned in the ledger rail so operators can keep reviewing linked entries.',
      accent: intact ? const Color(0xFF59D79B) : const Color(0xFFFCA5A5),
    );
  }

  void _exportEntryData(_LedgerEntryView entry) {
    final pretty = const JsonEncoder.withIndent(
      '  ',
    ).convert(_entryToJson(entry));
    Clipboard.setData(ClipboardData(text: pretty));
    logUiAction('ledger.export_entry', context: {'entry_id': entry.id});
    _showActionMessage(
      'Entry export copied (${entry.id}).',
      label: 'EXPORT ENTRY',
      detail:
          'The focused ledger row payload is on the clipboard while its case-board context stays pinned.',
      accent: entry.typeColor,
    );
  }

  Map<String, Object?> _entryToJson(_LedgerEntryView entry) {
    return {
      'id': entry.id,
      'sequence': entry.sequence,
      'type': entry.type,
      'title': entry.title,
      'timestamp_utc': entry.timestamp.toIso8601String(),
      'verified': entry.verified,
      'hash': entry.hash,
      'previous_hash': entry.previousHash,
      'site': entry.site,
      'dispatch_id': entry.dispatchId,
      'payload': entry.payload,
    };
  }

  Map<String, Object?>? _sceneReviewPayloadForEntry(_LedgerEntryView entry) {
    final payload = entry.payload['sceneReview'];
    if (payload is! Map) {
      return null;
    }
    final mapped = payload.map(
      (key, value) => MapEntry(key.toString(), value as Object?),
    );
    if ((mapped['source_label'] ?? '').toString().trim().isEmpty &&
        (mapped['summary'] ?? '').toString().trim().isEmpty) {
      return null;
    }
    return mapped;
  }

  Map<String, Object?>? _reportConfigurationPayloadForEntry(
    _LedgerEntryView entry,
  ) {
    final payload = entry.payload['reportConfiguration'];
    if (payload is! Map) {
      return null;
    }
    final mapped = payload.map(
      (key, value) => MapEntry(key.toString(), value as Object?),
    );
    final summary = (mapped['summary'] ?? '').toString().trim();
    if (summary.isEmpty) {
      return null;
    }
    return mapped;
  }

  _LedgerLaneFilter _effectiveLaneForEntries(List<_LedgerEntryView> entries) {
    if (entries.any((entry) => _matchesLaneFilter(entry, _laneFilter))) {
      return _laneFilter;
    }
    return _LedgerLaneFilter.all;
  }

  bool _matchesLaneFilter(_LedgerEntryView entry, _LedgerLaneFilter lane) {
    switch (lane) {
      case _LedgerLaneFilter.all:
        return true;
      case _LedgerLaneFilter.reports:
        return entry.type == 'REPORT';
      case _LedgerLaneFilter.intelligence:
        return entry.type == 'AI ACTION' ||
            (entry.payload['intelligenceId'] ?? '')
                .toString()
                .trim()
                .isNotEmpty ||
            _sceneReviewPayloadForEntry(entry) != null;
      case _LedgerLaneFilter.continuity:
        return entry.type == 'DISPATCH' ||
            entry.type == 'CHECKPOINT' ||
            entry.type == 'REVIEW' ||
            entry.type == 'GUARD ACTION' ||
            (entry.dispatchId ?? '').trim().isNotEmpty;
      case _LedgerLaneFilter.attention:
        return entry.type == 'INCIDENT' ||
            entry.type == 'ALARM' ||
            _sceneReviewPayloadForEntry(entry) != null ||
            _reportConfigurationPayloadForEntry(entry) != null ||
            !entry.verified;
    }
  }

  _LedgerLaneFilter _preferredLaneForEntry(_LedgerEntryView entry) {
    if (_matchesLaneFilter(entry, _LedgerLaneFilter.reports)) {
      return _LedgerLaneFilter.reports;
    }
    if (_matchesLaneFilter(entry, _LedgerLaneFilter.intelligence)) {
      return _LedgerLaneFilter.intelligence;
    }
    if (_matchesLaneFilter(entry, _LedgerLaneFilter.attention)) {
      return _LedgerLaneFilter.attention;
    }
    if (_matchesLaneFilter(entry, _LedgerLaneFilter.continuity)) {
      return _LedgerLaneFilter.continuity;
    }
    return _LedgerLaneFilter.all;
  }

  _LedgerEntryView? _firstEntryForLane(
    List<_LedgerEntryView> entries,
    _LedgerLaneFilter lane,
  ) {
    for (final entry in entries) {
      if (_matchesLaneFilter(entry, lane)) {
        return entry;
      }
    }
    return null;
  }

  List<_LedgerEntryView> _linkedEntriesForSelected(
    List<_LedgerEntryView> entries,
    _LedgerEntryView selected,
  ) {
    final dispatchId = (selected.dispatchId ?? '').trim();
    final site = (selected.site ?? '').trim();
    final eventId = (selected.payload['eventId'] ?? '').toString().trim();
    return entries
        .where((entry) {
          if (entry.id == selected.id) {
            return false;
          }
          final entryDispatchId = (entry.dispatchId ?? '').trim();
          final entrySite = (entry.site ?? '').trim();
          final entryEventId = (entry.payload['eventId'] ?? '')
              .toString()
              .trim();
          return (dispatchId.isNotEmpty && entryDispatchId == dispatchId) ||
              (site.isNotEmpty && entrySite == site) ||
              (eventId.isNotEmpty && entryEventId == eventId);
        })
        .take(3)
        .toList(growable: false);
  }

  void _showActionMessage(
    String message, {
    String label = 'LEDGER ACTION',
    String? detail,
    Color accent = const Color(0xFF8FD1FF),
  }) {
    if (_desktopWorkspaceActive) {
      setState(() {
        _commandReceipt = _LedgerCommandReceipt(
          label: label,
          message: message,
          detail:
              detail ??
              'The latest ledger command remains pinned in the continuity rail.',
          accent: accent,
        );
      });
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }
}

enum _ChainIntegrity { intact, pending, compromised }

enum _LedgerLaneFilter { all, reports, intelligence, continuity, attention }

extension on _LedgerLaneFilter {
  String get key {
    switch (this) {
      case _LedgerLaneFilter.all:
        return 'all';
      case _LedgerLaneFilter.reports:
        return 'reports';
      case _LedgerLaneFilter.intelligence:
        return 'intelligence';
      case _LedgerLaneFilter.continuity:
        return 'continuity';
      case _LedgerLaneFilter.attention:
        return 'attention';
    }
  }

  String get label {
    switch (this) {
      case _LedgerLaneFilter.all:
        return 'All';
      case _LedgerLaneFilter.reports:
        return 'Reports';
      case _LedgerLaneFilter.intelligence:
        return 'AI Evidence';
      case _LedgerLaneFilter.continuity:
        return 'Continuity';
      case _LedgerLaneFilter.attention:
        return 'Attention';
    }
  }

  Color get accent {
    switch (this) {
      case _LedgerLaneFilter.all:
        return const Color(0xFF9FD9FF);
      case _LedgerLaneFilter.reports:
        return const Color(0xFFC084FC);
      case _LedgerLaneFilter.intelligence:
        return const Color(0xFF22D3EE);
      case _LedgerLaneFilter.continuity:
        return const Color(0xFF34D399);
      case _LedgerLaneFilter.attention:
        return const Color(0xFFF87171);
    }
  }
}

enum _LedgerWorkspaceView { caseFile, evidence, chain }

extension on _LedgerWorkspaceView {
  String get key {
    switch (this) {
      case _LedgerWorkspaceView.caseFile:
        return 'case-file';
      case _LedgerWorkspaceView.evidence:
        return 'evidence';
      case _LedgerWorkspaceView.chain:
        return 'chain';
    }
  }

  String get label {
    switch (this) {
      case _LedgerWorkspaceView.caseFile:
        return 'Case File';
      case _LedgerWorkspaceView.evidence:
        return 'Evidence';
      case _LedgerWorkspaceView.chain:
        return 'Chain';
    }
  }

  Color get accent {
    switch (this) {
      case _LedgerWorkspaceView.caseFile:
        return const Color(0xFF9FD9FF);
      case _LedgerWorkspaceView.evidence:
        return const Color(0xFF59D79B);
      case _LedgerWorkspaceView.chain:
        return const Color(0xFFC084FC);
    }
  }
}

extension on _ChainIntegrity {
  String get label {
    switch (this) {
      case _ChainIntegrity.intact:
        return 'INTACT';
      case _ChainIntegrity.pending:
        return 'PENDING';
      case _ChainIntegrity.compromised:
        return 'COMPROMISED';
    }
  }

  Color get color {
    switch (this) {
      case _ChainIntegrity.intact:
        return const Color(0xFF10B981);
      case _ChainIntegrity.pending:
        return const Color(0xFFF59E0B);
      case _ChainIntegrity.compromised:
        return const Color(0xFFEF4444);
    }
  }
}

class _LedgerEntryView {
  final String id;
  final int sequence;
  final String type;
  final String title;
  final String? site;
  final String? dispatchId;
  final DateTime timestamp;
  final String hash;
  final String previousHash;
  final bool verified;
  final Color typeColor;
  final Map<String, dynamic> payload;

  const _LedgerEntryView({
    required this.id,
    required this.sequence,
    required this.type,
    required this.title,
    required this.site,
    required this.dispatchId,
    required this.timestamp,
    required this.hash,
    required this.previousHash,
    required this.verified,
    required this.typeColor,
    required this.payload,
  });
}

final List<_LedgerEntryView> _fallbackEntries = [
  _LedgerEntryView(
    id: 'LED-8842',
    sequence: 8842,
    type: 'AI ACTION',
    title: 'AI approved dispatch for breach detection',
    site: 'Sandton Estate',
    dispatchId: 'DSP-2441',
    timestamp: DateTime.utc(2024, 3, 10, 22, 14, 32),
    hash: 'a3d4f8e9c2b1a5d6e7f8g9h0i1j2k3l4',
    previousHash: 'b1c2d3e4f5g6h7i8j9k0l1m2n3o4p5q6',
    verified: true,
    typeColor: Color(0xFFC084FC),
    payload: {
      'decision': 'APPROVE_DISPATCH',
      'confidence': 0.94,
      'incidentId': 'INC-8829-QX',
    },
  ),
  _LedgerEntryView(
    id: 'LED-8841',
    sequence: 8841,
    type: 'INCIDENT',
    title: 'P1-CRITICAL breach detection incident created',
    site: 'Sandton Estate',
    dispatchId: null,
    timestamp: DateTime.utc(2024, 3, 10, 22, 14, 28),
    hash: 'b1c2d3e4f5g6h7i8j9k0l1m2n3o4p5q6',
    previousHash: 'c2d3e4f5g6h7i8j9k0l1m2n3o4p5q6r7',
    verified: true,
    typeColor: Color(0xFFEF4444),
    payload: {'priority': 'P1-CRITICAL', 'type': 'Breach Detection'},
  ),
];

List<_LedgerEntryView> _buildLedgerEntries(
  List<DispatchEvent> events, {
  String? clientId,
  String? siteId,
  Map<String, MonitoringSceneReviewRecord> sceneReviewByIntelligenceId =
      const {},
}) {
  if (events.isEmpty) {
    return const [];
  }

  final normalizedClientId = (clientId ?? '').trim();
  final normalizedSiteId = (siteId ?? '').trim();
  final sorted = [...events]..sort((a, b) => a.sequence.compareTo(b.sequence));
  var previousHash = 'GENESIS';
  final built = <_LedgerEntryView>[];

  for (final event in sorted) {
    if (normalizedClientId.isNotEmpty &&
        normalizedSiteId.isNotEmpty &&
        (_eventClientId(event).trim() != normalizedClientId ||
            _eventSiteId(event).trim() != normalizedSiteId)) {
      continue;
    }
    final payload = _ledgerPayloadForEvent(
      event,
      sceneReviewByIntelligenceId: sceneReviewByIntelligenceId,
    );

    final hash = sha256
        .convert(utf8.encode('${jsonEncode(payload)}|$previousHash'))
        .toString();

    built.add(
      _LedgerEntryView(
        id: 'LED-${event.sequence}',
        sequence: event.sequence,
        type: _ledgerType(event),
        title: _eventTitle(event),
        site: _eventSiteId(event),
        dispatchId: _eventDispatchId(event),
        timestamp: event.occurredAt.toUtc(),
        hash: hash,
        previousHash: previousHash,
        verified: true,
        typeColor: _typeColor(_ledgerType(event)),
        payload: payload,
      ),
    );

    previousHash = hash;
  }

  final newestFirst = built.reversed.toList(growable: false);
  return newestFirst;
}

Map<String, Object?> _ledgerPayloadForEvent(
  DispatchEvent event, {
  required Map<String, MonitoringSceneReviewRecord> sceneReviewByIntelligenceId,
}) {
  final payload = <String, Object?>{
    'eventId': event.eventId,
    'sequence': event.sequence,
    'version': event.version,
    'type': _rawEventType(event),
    'clientId': _eventClientId(event),
    'regionId': _eventRegionId(event),
    'siteId': _eventSiteId(event),
    'occurredAt': event.occurredAt.toUtc().toIso8601String(),
    'summary': _eventTitle(event),
  };
  if (event is IntelligenceReceived) {
    payload['intelligenceId'] = event.intelligenceId;
    payload['provider'] = event.provider;
    payload['sourceType'] = event.sourceType;
    payload['riskScore'] = event.riskScore;
    if ((event.cameraId ?? '').trim().isNotEmpty) {
      payload['cameraId'] = event.cameraId!.trim();
    }
    if ((event.objectLabel ?? '').trim().isNotEmpty) {
      payload['objectLabel'] = event.objectLabel!.trim();
    }
    if (event.objectConfidence != null) {
      payload['objectConfidence'] = event.objectConfidence;
    }
    if ((event.evidenceRecordHash ?? '').trim().isNotEmpty) {
      payload['evidenceRecordHash'] = event.evidenceRecordHash!.trim();
    }
    final review = sceneReviewByIntelligenceId[event.intelligenceId.trim()];
    if (review != null) {
      payload['sceneReview'] = <String, Object?>{
        'source_label': review.sourceLabel,
        'posture_label': review.postureLabel,
        if (review.decisionLabel.trim().isNotEmpty)
          'decision_label': review.decisionLabel,
        if (review.decisionSummary.trim().isNotEmpty)
          'decision_summary': review.decisionSummary,
        'summary': review.summary,
        'reviewed_at_utc': review.reviewedAtUtc.toIso8601String(),
        if (review.evidenceRecordHash.trim().isNotEmpty)
          'evidence_record_hash': review.evidenceRecordHash,
      };
    }
  } else if (event is ReportGenerated) {
    final tracked = _hasTrackedReportSectionConfiguration(event);
    final included = _includedReportSectionLabels(event.sectionConfiguration);
    final omitted = _omittedReportSectionLabels(event.sectionConfiguration);
    payload['month'] = event.month;
    payload['contentHash'] = event.contentHash;
    payload['pdfHash'] = event.pdfHash;
    payload['eventRangeStart'] = event.eventRangeStart;
    payload['eventRangeEnd'] = event.eventRangeEnd;
    payload['eventCount'] = event.eventCount;
    payload['reportSchemaVersion'] = event.reportSchemaVersion;
    payload['projectionVersion'] = event.projectionVersion;
    payload['reportConfiguration'] = <String, Object?>{
      'tracked': tracked,
      'summary': _reportSectionConfigurationDetail(event),
      'investigation_context_label': _reportInvestigationContextLabel(event),
      'investigation_context_key': event.investigationContextKey.trim().isEmpty
          ? 'routine_review'
          : event.investigationContextKey.trim(),
      'branding_mode_label': _reportBrandingModeLabel(event),
      'branding_summary': _reportBrandingDetail(event),
      'branding_source_label': _reportBrandingSourceLabel(event),
      'included_sections': included,
      'omitted_sections': omitted,
      'included_sections_label': tracked
          ? (included.isEmpty ? 'None' : included.join(', '))
          : 'Legacy receipt',
      'omitted_sections_label': tracked
          ? (omitted.isEmpty ? 'None' : omitted.join(', '))
          : 'Not captured',
      'includeTimeline': event.includeTimeline,
      'includeDispatchSummary': event.includeDispatchSummary,
      'includeCheckpointCompliance': event.includeCheckpointCompliance,
      'includeAiDecisionLog': event.includeAiDecisionLog,
      'includeGuardMetrics': event.includeGuardMetrics,
    };
  }
  return payload;
}

bool _verifyChain(List<_LedgerEntryView> entries) {
  for (var i = 0; i < entries.length; i++) {
    final current = entries[i];
    final next = i + 1 < entries.length ? entries[i + 1] : null;
    if (next == null) {
      continue;
    }
    if (current.previousHash != next.hash &&
        current.previousHash != 'GENESIS') {
      return false;
    }
  }
  return true;
}

String _ledgerType(DispatchEvent event) {
  if (event is DecisionCreated) return 'INCIDENT';
  if (event is ResponseArrived) return 'DISPATCH';
  if (event is PartnerDispatchStatusDeclared) return 'DISPATCH';
  if (event is VehicleVisitReviewRecorded) return 'REVIEW';
  if (event is GuardCheckedIn) return 'CHECKPOINT';
  if (event is ExecutionDenied) return 'ALARM';
  if (event is IntelligenceReceived) return 'AI ACTION';
  if (event is PatrolCompleted) return 'GUARD ACTION';
  if (event is ExecutionCompleted) return 'DISPATCH';
  if (event is IncidentClosed) return 'INCIDENT';
  if (event is ReportGenerated) return 'REPORT';
  return 'SYSTEM';
}

Color _typeColor(String type) {
  switch (type) {
    case 'INCIDENT':
      return const Color(0xFFEF4444);
    case 'DISPATCH':
      return const Color(0xFF10B981);
    case 'CHECKPOINT':
      return const Color(0xFF22D3EE);
    case 'REVIEW':
      return const Color(0xFF38BDF8);
    case 'ALARM':
      return const Color(0xFFF59E0B);
    case 'AI ACTION':
      return const Color(0xFFC084FC);
    case 'GUARD ACTION':
      return const Color(0xFF3B82F6);
    case 'REPORT':
      return const Color(0xFFC084FC);
    default:
      return const Color(0xFF9BB0CE);
  }
}

String _eventTitle(DispatchEvent event) {
  if (event is DecisionCreated) {
    return '${event.clientId}/${event.siteId} dispatch ${event.dispatchId} created';
  }
  if (event is ResponseArrived) {
    return '${event.guardId} arrived for ${event.dispatchId}';
  }
  if (event is PartnerDispatchStatusDeclared) {
    return '${event.partnerLabel} declared ${event.status.name} for ${event.dispatchId}';
  }
  if (event is VehicleVisitReviewRecorded) {
    if (!event.reviewed && event.statusOverride.trim().isEmpty) {
      return '${event.vehicleLabel} review cleared';
    }
    if (event.statusOverride.trim().isNotEmpty) {
      return '${event.vehicleLabel} marked ${event.effectiveStatusLabel}';
    }
    return '${event.vehicleLabel} marked reviewed';
  }
  if (event is GuardCheckedIn) {
    return '${event.guardId} checkpoint scan completed';
  }
  if (event is IntelligenceReceived) {
    return event.headline;
  }
  if (event is ExecutionCompleted) {
    return event.success
        ? 'Armed response dispatch initiated'
        : '${event.dispatchId} execution failed';
  }
  if (event is ExecutionDenied) {
    return 'Perimeter alarm activation detected';
  }
  if (event is PatrolCompleted) {
    return '${event.guardId} completed route ${event.routeId}';
  }
  if (event is IncidentClosed) {
    return '${event.dispatchId} closed for ${event.siteId}';
  }
  if (event is ReportGenerated) {
    final tracked = _hasTrackedReportSectionConfiguration(event);
    final omitted = _omittedReportSectionLabels(event.sectionConfiguration);
    final brandingHeadline = _reportBrandingHeadline(event);
    final investigationHeadline = _reportInvestigationHeadline(event);
    final configSummary = !tracked
        ? 'legacy receipt config'
        : omitted.isEmpty
        ? 'all sections included'
        : '${omitted.length} sections omitted';
    return '${event.siteId} ${event.month} • $configSummary${brandingHeadline == null ? '' : ' • $brandingHeadline'}${investigationHeadline == null ? '' : ' • $investigationHeadline'} • range ${event.eventRangeStart}-${event.eventRangeEnd}';
  }
  return event.eventId;
}

String? _eventDispatchId(DispatchEvent event) {
  if (event is DecisionCreated) return event.dispatchId;
  if (event is ResponseArrived) return event.dispatchId;
  if (event is PartnerDispatchStatusDeclared) return event.dispatchId;
  if (event is VehicleVisitReviewRecorded) return event.primaryEventId;
  if (event is ExecutionCompleted) return event.dispatchId;
  if (event is ExecutionDenied) return event.dispatchId;
  if (event is IncidentClosed) return event.dispatchId;
  if (event is ReportGenerated) return null;
  return null;
}

String _rawEventType(DispatchEvent event) =>
    event.runtimeType.toString().toUpperCase();

String _eventClientId(DispatchEvent event) {
  if (event is DecisionCreated) return event.clientId;
  if (event is ResponseArrived) return event.clientId;
  if (event is PartnerDispatchStatusDeclared) return event.clientId;
  if (event is VehicleVisitReviewRecorded) return event.clientId;
  if (event is GuardCheckedIn) return event.clientId;
  if (event is ExecutionCompleted) return event.clientId;
  if (event is ExecutionDenied) return event.clientId;
  if (event is IntelligenceReceived) return event.clientId;
  if (event is PatrolCompleted) return event.clientId;
  if (event is IncidentClosed) return event.clientId;
  if (event is ReportGenerated) return event.clientId;
  return 'CLIENT-UNKNOWN';
}

String _eventRegionId(DispatchEvent event) {
  if (event is DecisionCreated) return event.regionId;
  if (event is ResponseArrived) return event.regionId;
  if (event is PartnerDispatchStatusDeclared) return event.regionId;
  if (event is VehicleVisitReviewRecorded) return event.regionId;
  if (event is GuardCheckedIn) return event.regionId;
  if (event is ExecutionCompleted) return event.regionId;
  if (event is ExecutionDenied) return event.regionId;
  if (event is IntelligenceReceived) return event.regionId;
  if (event is PatrolCompleted) return event.regionId;
  if (event is IncidentClosed) return event.regionId;
  if (event is ReportGenerated) return 'REGION-UNKNOWN';
  return 'REGION-UNKNOWN';
}

String _eventSiteId(DispatchEvent event) {
  if (event is DecisionCreated) return event.siteId;
  if (event is ResponseArrived) return event.siteId;
  if (event is PartnerDispatchStatusDeclared) return event.siteId;
  if (event is VehicleVisitReviewRecorded) return event.siteId;
  if (event is GuardCheckedIn) return event.siteId;
  if (event is ExecutionCompleted) return event.siteId;
  if (event is ExecutionDenied) return event.siteId;
  if (event is IntelligenceReceived) return event.siteId;
  if (event is PatrolCompleted) return event.siteId;
  if (event is IncidentClosed) return event.siteId;
  if (event is ReportGenerated) return event.siteId;
  return 'SITE-UNKNOWN';
}

bool _hasTrackedReportSectionConfiguration(ReportGenerated event) {
  return event.reportSchemaVersion >= 3;
}

List<String> _includedReportSectionLabels(
  ReportSectionConfiguration configuration,
) {
  return <String>[
    if (configuration.includeTimeline) 'Incident Timeline',
    if (configuration.includeDispatchSummary) 'Dispatch Summary',
    if (configuration.includeCheckpointCompliance) 'Checkpoint Compliance',
    if (configuration.includeAiDecisionLog) 'AI Decision Log',
    if (configuration.includeGuardMetrics) 'Guard Metrics',
  ];
}

List<String> _omittedReportSectionLabels(
  ReportSectionConfiguration configuration,
) {
  return <String>[
    if (!configuration.includeTimeline) 'Incident Timeline',
    if (!configuration.includeDispatchSummary) 'Dispatch Summary',
    if (!configuration.includeCheckpointCompliance) 'Checkpoint Compliance',
    if (!configuration.includeAiDecisionLog) 'AI Decision Log',
    if (!configuration.includeGuardMetrics) 'Guard Metrics',
  ];
}

String _reportSectionConfigurationDetail(ReportGenerated event) {
  if (!_hasTrackedReportSectionConfiguration(event)) {
    return 'Legacy receipt. Per-section report configuration was not captured for this generated report.';
  }
  final included = _includedReportSectionLabels(event.sectionConfiguration);
  final omitted = _omittedReportSectionLabels(event.sectionConfiguration);
  final includedLabel = included.isEmpty ? 'None' : included.join(', ');
  final omittedLabel = omitted.isEmpty ? 'None' : omitted.join(', ');
  return 'Included: $includedLabel. Omitted: $omittedLabel.';
}

String _reportBrandingModeLabel(ReportGenerated event) {
  if (!event.brandingConfiguration.isConfigured) {
    return 'Standard ONYX';
  }
  return event.brandingUsesOverride ? 'Custom Override' : 'Default Partner';
}

String _reportBrandingSourceLabel(ReportGenerated event) {
  final sourceLabel = event.brandingConfiguration.sourceLabel.trim();
  if (sourceLabel.isEmpty) {
    return event.brandingConfiguration.isConfigured
        ? 'Configured partner branding'
        : 'ONYX';
  }
  return sourceLabel;
}

String? _reportBrandingHeadline(ReportGenerated event) {
  if (!event.brandingConfiguration.isConfigured) {
    return null;
  }
  return event.brandingUsesOverride
      ? 'custom branding override'
      : 'default partner branding';
}

String _reportBrandingDetail(ReportGenerated event) {
  if (!event.brandingConfiguration.isConfigured) {
    return 'Branding: standard ONYX identity.';
  }
  final sourceLabel = event.brandingConfiguration.sourceLabel.trim();
  if (event.brandingUsesOverride) {
    return sourceLabel.isNotEmpty
        ? 'Branding: custom override from default partner lane $sourceLabel.'
        : 'Branding: custom override was used for this receipt.';
  }
  return sourceLabel.isNotEmpty
      ? 'Branding: default partner lane $sourceLabel.'
      : 'Branding: configured partner label was used.';
}

ReportEntryContext? _reportInvestigationContext(ReportGenerated event) {
  return ReportEntryContext.fromStorageValue(event.investigationContextKey);
}

String? _reportInvestigationHeadline(ReportGenerated event) {
  return switch (_reportInvestigationContext(event)) {
    ReportEntryContext.governanceBrandingDrift => 'governance handoff',
    null => null,
  };
}

String _reportInvestigationContextLabel(ReportGenerated event) {
  return switch (_reportInvestigationContext(event)) {
    ReportEntryContext.governanceBrandingDrift => 'Governance Handoff',
    null => 'Routine Review',
  };
}

String _clock(DateTime value) {
  final utc = value.toUtc();
  var h = utc.hour;
  final m = utc.minute.toString().padLeft(2, '0');
  final s = utc.second.toString().padLeft(2, '0');
  final suffix = h >= 12 ? 'PM' : 'AM';
  h = h % 12;
  if (h == 0) h = 12;
  return '$h:$m:$s $suffix';
}

String _fullTimestamp(DateTime value) {
  final utc = value.toUtc();
  return '${utc.month}/${utc.day}/${utc.year}, ${_clock(utc)}';
}
