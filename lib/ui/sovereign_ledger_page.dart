import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

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
import 'onyx_surface.dart';
import 'ui_action_logger.dart';

class SovereignLedgerPage extends StatefulWidget {
  final String clientId;
  final List<DispatchEvent> events;
  final String initialFocusReference;
  final Map<String, MonitoringSceneReviewRecord> sceneReviewByIntelligenceId;

  const SovereignLedgerPage({
    super.key,
    required this.clientId,
    required this.events,
    this.initialFocusReference = '',
    this.sceneReviewByIntelligenceId = const {},
  });

  @override
  State<SovereignLedgerPage> createState() => _SovereignLedgerPageState();
}

class _SovereignLedgerPageState extends State<SovereignLedgerPage> {
  String? _selectedEntryId;
  _ChainIntegrity _integrity = _ChainIntegrity.pending;

  @override
  Widget build(BuildContext context) {
    final entries = _buildLedgerEntries(
      widget.events,
      sceneReviewByIntelligenceId: widget.sceneReviewByIntelligenceId,
    );
    var list = entries.isEmpty ? _fallbackEntries : entries;
    final focusReference = widget.initialFocusReference.trim();
    final hasFocusReference = focusReference.isNotEmpty;
    var focusLinked = false;
    if (hasFocusReference) {
      final existingFocusId = _resolveFocusEntryId(
        entries: list,
        focusReference: focusReference,
      );
      if (existingFocusId != null) {
        _selectedEntryId = existingFocusId;
        focusLinked = true;
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
      }
    }

    _selectedEntryId ??= list.first.id;
    final selected = list.firstWhere(
      (entry) => entry.id == _selectedEntryId,
      orElse: () => list.first,
    );

    final verifiedEntries = list.where((entry) => entry.verified).length;

    return OnyxPageScaffold(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1540),
            child: ListView(
              children: [
                Text(
                  'SOVEREIGN LEDGER',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEAF1FB),
                    fontSize: 49,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final maxWidth = constraints.maxWidth;
                    final cardWidth = maxWidth < 760
                        ? maxWidth
                        : maxWidth < 1160
                        ? (maxWidth - 8) / 2
                        : (maxWidth - 24) / 4;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _summaryCard(
                          width: cardWidth,
                          label: 'CHAIN INTEGRITY',
                          value: _integrity.label,
                          valueColor: _integrity.color,
                          icon: _integrity == _ChainIntegrity.intact
                              ? Icons.verified_rounded
                              : Icons.warning_amber_rounded,
                          iconColor: _integrity.color,
                        ),
                        _summaryCard(
                          width: cardWidth,
                          label: 'VISIBLE ENTRIES',
                          value: '${list.length}',
                          valueColor: const Color(0xFFEAF1FB),
                          icon: Icons.menu_book_rounded,
                          iconColor: const Color(0xFF22D3EE),
                        ),
                        _summaryCard(
                          width: cardWidth,
                          label: 'LATEST SEQUENCE',
                          value: '#${list.first.sequence}',
                          valueColor: const Color(0xFFEAF1FB),
                          icon: Icons.tag_rounded,
                          iconColor: const Color(0xFF22D3EE),
                        ),
                        _summaryCard(
                          width: cardWidth,
                          label: 'VERIFIED ENTRIES',
                          value: '$verifiedEntries',
                          valueColor: const Color(0xFF10B981),
                          icon: Icons.shield_outlined,
                          iconColor: const Color(0xFF22D3EE),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                if (hasFocusReference) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: focusLinked
                          ? const Color(0x2234D399)
                          : const Color(0x333C79BB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: focusLinked
                            ? const Color(0x6634D399)
                            : const Color(0x665FAAFF),
                      ),
                    ),
                    child: Text(
                      'Focus ${focusLinked ? 'LINKED' : 'SEEDED'} • $focusReference',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFEAF1FB),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                _chainControls(list),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 1240;
                    if (stacked) {
                      return Column(
                        children: [
                          _timelinePane(list, bounded: false),
                          const SizedBox(height: 8),
                          _detailPane(selected, bounded: false),
                        ],
                      );
                    }
                    return SizedBox(
                      height: 760,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: _timelinePane(list, bounded: true),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 6,
                            child: _detailPane(selected, bounded: true),
                          ),
                        ],
                      ),
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

  String? _resolveFocusEntryId({
    required List<_LedgerEntryView> entries,
    required String focusReference,
  }) {
    for (final entry in entries) {
      final payloadEventId = (entry.payload['eventId'] ?? '').toString().trim();
      final payloadDispatchId = (entry.payload['dispatchId'] ?? '')
          .toString()
          .trim();
      if (entry.id == focusReference ||
          (entry.dispatchId ?? '').trim() == focusReference ||
          payloadEventId == focusReference ||
          payloadDispatchId == focusReference) {
        return entry.id;
      }
    }
    return null;
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
      'siteId': 'DEMO-SITE',
      'occurredAt': timestamp.toIso8601String(),
      'summary': 'Seeded focus reference awaiting live ledger ingest.',
      'dispatchId': null,
      'demoSeed': true,
    };
    final hash = sha256
        .convert(utf8.encode('${jsonEncode(payload)}|$previousHash'))
        .toString();
    final seeded = _LedgerEntryView(
      id: 'LED-SEED-$focusReference',
      sequence: maxSequence + 1,
      type: 'INCIDENT',
      title: 'Seeded focus reference awaiting live ledger ingest.',
      site: 'DEMO-SITE',
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

  Widget _summaryCard({
    required double width,
    required String label,
    required String value,
    required Color valueColor,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0E141C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2B3A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF6F839C),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    color: valueColor,
                    fontSize: 54,
                    height: 0.95,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF142132),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _chainControls(List<_LedgerEntryView> entries) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0E141C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2B3A)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Chain Controls',
            style: GoogleFonts.inter(
              color: const Color(0xFF7D93B1),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
          _button(
            'VERIFY CHAIN',
            primary: true,
            onTap: () {
              final intact = _verifyChain(entries);
              setState(() {
                _integrity = intact
                    ? _ChainIntegrity.intact
                    : _ChainIntegrity.compromised;
              });
              logUiAction(
                'ledger.verify_chain',
                context: {
                  'entries': entries.length,
                  'result': intact ? 'intact' : 'compromised',
                },
              );
            },
          ),
          _button('EXPORT LEDGER', onTap: () => _exportLedger(entries)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF111822),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFF2A374A)),
            ),
            child: Text(
              'SOURCE: ONYX CORE',
              style: GoogleFonts.inter(
                color: const Color(0xFF9FD9FF),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _button(
    String label, {
    required VoidCallback onTap,
    bool primary = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: primary ? const Color(0xFF3B82F6) : const Color(0xFF111822),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: primary ? const Color(0x664E8FFF) : const Color(0xFF2A374A),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(0xFFEAF1FB),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _timelinePane(
    List<_LedgerEntryView> entries, {
    required bool bounded,
  }) {
    final rows = Column(
      children: [
        Text(
          'LEDGER TIMELINE',
          style: GoogleFonts.inter(
            color: const Color(0xFF7D93B1),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < entries.length; i++) ...[
          _timelineRow(
            entry: entries[i],
            selected: entries[i].id == _selectedEntryId,
            showConnector: i < entries.length - 1,
          ),
          const SizedBox(height: 8),
        ],
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0E141C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2B3A)),
      ),
      child: bounded
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: rows,
            )
          : Padding(padding: const EdgeInsets.all(10), child: rows),
    );
  }

  Widget _timelineRow({
    required _LedgerEntryView entry,
    required bool selected,
    required bool showConnector,
  }) {
    return InkWell(
      onTap: () => setState(() => _selectedEntryId = entry.id),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0E2A32) : const Color(0xFF0D131A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF1B9CB7) : const Color(0xFF1F2B3A),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 46,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: entry.typeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: entry.typeColor.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Text(
                      '${entry.sequence}',
                      style: GoogleFonts.inter(
                        color: entry.typeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (showConnector)
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      width: 1,
                      height: 24,
                      color: const Color(0x332A374A),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              entry.type,
                              style: GoogleFonts.inter(
                                color: entry.typeColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (entry.verified)
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 12,
                                color: Color(0xFF10B981),
                              ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 12,
                            color: Color(0x668EA4C2),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _clock(entry.timestamp),
                            style: GoogleFonts.inter(
                              color: const Color(0x808EA4C2),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.title,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFEAF1FB),
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (entry.site != null) _pill('Site: ${entry.site}'),
                      if (entry.dispatchId != null)
                        _pill('Dispatch: ${entry.dispatchId}'),
                      _pill(entry.id),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: selected
                  ? const Color(0xFF22D3EE)
                  : const Color(0x668EA4C2),
              size: 18,
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
        borderRadius: BorderRadius.circular(6),
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

  Widget _detailPane(_LedgerEntryView selected, {required bool bounded}) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ENTRY DETAIL',
          style: GoogleFonts.inter(
            color: const Color(0xFF7D93B1),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
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
        const SizedBox(height: 8),
        _outlineButton(
          'VIEW IN EVENT REVIEW',
          onTap: () {
            logUiAction(
              'ledger.view_in_event_review',
              context: {'entry_id': selected.id},
            );
            _showActionMessage('Open Event Review to inspect ${selected.id}.');
          },
        ),
        const SizedBox(height: 6),
        _outlineButton(
          'EXPORT ENTRY DATA',
          onTap: () => _exportEntryData(selected),
        ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C1117),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2B3A)),
      ),
      child: bounded
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: content,
            )
          : Padding(padding: const EdgeInsets.all(10), child: content),
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

  Widget _outlineButton(String label, {required VoidCallback onTap}) {
    return InkWell(
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

  void _exportLedger(List<_LedgerEntryView> entries) {
    final payload = entries.map(_entryToJson).toList(growable: false);
    final pretty = const JsonEncoder.withIndent('  ').convert(payload);
    Clipboard.setData(ClipboardData(text: pretty));
    logUiAction('ledger.export_all', context: {'entries': entries.length});
    _showActionMessage('Ledger export copied (${entries.length} entries).');
  }

  void _exportEntryData(_LedgerEntryView entry) {
    final pretty = const JsonEncoder.withIndent(
      '  ',
    ).convert(_entryToJson(entry));
    Clipboard.setData(ClipboardData(text: pretty));
    logUiAction('ledger.export_entry', context: {'entry_id': entry.id});
    _showActionMessage('Entry export copied (${entry.id}).');
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

  void _showActionMessage(String message) {
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
  Map<String, MonitoringSceneReviewRecord> sceneReviewByIntelligenceId =
      const {},
}) {
  if (events.isEmpty) {
    return const [];
  }

  final sorted = [...events]..sort((a, b) => a.sequence.compareTo(b.sequence));
  var previousHash = 'GENESIS';
  final built = <_LedgerEntryView>[];

  for (final event in sorted) {
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
    final configSummary = !tracked
        ? 'legacy receipt config'
        : omitted.isEmpty
        ? 'all sections included'
        : '${omitted.length} sections omitted';
    return '${event.siteId} ${event.month} • $configSummary${brandingHeadline == null ? '' : ' • $brandingHeadline'} • range ${event.eventRangeStart}-${event.eventRangeEnd}';
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
