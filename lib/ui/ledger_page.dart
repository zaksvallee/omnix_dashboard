import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../application/report_entry_context.dart';
import '../domain/crm/reporting/report_section_configuration.dart';
import '../domain/events/decision_created.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/execution_completed.dart';
import '../domain/events/execution_denied.dart';
import '../domain/events/guard_checked_in.dart';
import '../domain/events/incident_closed.dart';
import '../domain/events/patrol_completed.dart';
import '../domain/events/report_generated.dart';
import '../domain/events/response_arrived.dart';
import 'layout_breakpoints.dart';
import 'onyx_surface.dart';

class LedgerPage extends StatefulWidget {
  final String clientId;
  final bool supabaseEnabled;
  final List<DispatchEvent> events;

  const LedgerPage({
    super.key,
    required this.clientId,
    required this.supabaseEnabled,
    required this.events,
  });

  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  static const int _maxTimelineRows = 60;

  List<Map<String, dynamic>> _rows = [];
  late List<_LedgerTimelineRow> _fallbackRows;
  String? _verificationResult;
  String? _runtimeConfigHint;

  @override
  void initState() {
    super.initState();
    _fallbackRows = _buildFallbackRows(widget.events, widget.clientId);
    _loadLedger();
  }

  Future<void> _loadLedger() async {
    if (!widget.supabaseEnabled) {
      if (!mounted) return;
      setState(() {
        _rows = const [];
        _runtimeConfigHint =
            'Supabase disabled. Running EventStore fallback timeline. '
            'Run with local defines: ./scripts/run_onyx_chrome_local.sh';
      });
      return;
    }

    final client = Supabase.instance.client;
    final data = await client
        .from('client_evidence_ledger')
        .select()
        .eq('client_id', widget.clientId)
        .order('created_at', ascending: true);

    if (!mounted) return;
    setState(() {
      _rows = List<Map<String, dynamic>>.from(data);
      _runtimeConfigHint = null;
      _verificationResult = null;
    });
  }

  Future<void> _verifyChain() async {
    if (_rows.isEmpty) {
      if (_fallbackRows.isEmpty) {
        setState(() => _verificationResult = 'No evidence rows available.');
        return;
      }

      var ordered = true;
      for (int i = 1; i < _fallbackRows.length; i++) {
        if (_fallbackRows[i - 1].sequence <= _fallbackRows[i].sequence) {
          ordered = false;
          break;
        }
      }

      setState(() {
        _verificationResult = ordered
            ? 'In-memory evidence ordering VERIFIED'
            : 'In-memory evidence ordering FAILED';
      });
      return;
    }

    String? previousHash;
    for (final row in _rows) {
      final canonicalJson = row['canonical_json'];
      final storedHash = row['hash'];
      final combined = previousHash == null
          ? canonicalJson
          : canonicalJson + previousHash;
      final computedHash = sha256
          .convert(Uint8List.fromList(utf8.encode(combined)))
          .toString();

      if (computedHash != storedHash) {
        setState(() => _verificationResult = 'Chain integrity FAILED');
        return;
      }
      previousHash = storedHash;
    }

    setState(() => _verificationResult = 'Chain integrity VERIFIED');
  }

  @override
  Widget build(BuildContext context) {
    final showSupabaseRows = _rows.isNotEmpty;
    final sourceLabel = showSupabaseRows ? 'Supabase' : 'EventStore';
    final totalRows = showSupabaseRows ? _rows.length : _fallbackRows.length;
    final rowCount = totalRows > _maxTimelineRows
        ? _maxTimelineRows
        : totalRows;
    final hiddenRows = totalRows - rowCount;

    return OnyxPageScaffold(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ListView(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1540),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _heroHeader(context),
                    const SizedBox(height: 12),
                    _integritySummaryBar(
                      sourceLabel: sourceLabel,
                      rowCount: rowCount,
                    ),
                    const SizedBox(height: 12),
                    _overviewGrid(
                      sourceLabel: sourceLabel,
                      rowCount: rowCount,
                      totalRows: totalRows,
                    ),
                    const SizedBox(height: 12),
                    OnyxPageHeader(
                      title: 'Evidence Ledger — ${widget.clientId}',
                      subtitle:
                          'Operational trace, evidence continuity, and replay-safe integrity checks.',
                      actions: [
                        ElevatedButton.icon(
                          onPressed: _verifyChain,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF194E87),
                            foregroundColor: const Color(0xFFE6F2FF),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.verified_rounded),
                          label: Text(
                            'Verify Chain',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 1280
                            ? 3
                            : constraints.maxWidth >= 860
                            ? 2
                            : 1;
                        const spacing = 10.0;
                        final cardWidth =
                            (constraints.maxWidth - ((columns - 1) * spacing)) /
                            columns;
                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: [
                            SizedBox(
                              width: cardWidth,
                              child: OnyxSummaryStat(
                                label: 'Ledger Source',
                                value: sourceLabel,
                                accent: const Color(0xFF63BDFF),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: OnyxSummaryStat(
                                label: 'Visible Rows',
                                value: rowCount.toString(),
                                accent: const Color(0xFF59D79B),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: OnyxSummaryStat(
                                label: 'Integrity State',
                                value: _verificationResult == null
                                    ? 'Pending'
                                    : _verificationResult!.contains('VERIFIED')
                                    ? 'Verified'
                                    : 'Failed',
                                accent: _verificationResult == null
                                    ? const Color(0xFF8CA5C8)
                                    : _verificationResult!.contains('VERIFIED')
                                    ? const Color(0xFF59D79B)
                                    : const Color(0xFFFF8D9A),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    if (_runtimeConfigHint != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: const Color(0xFF0E1A2B),
                          border: Border.all(color: const Color(0xFFF0C36C)),
                        ),
                        child: Text(
                          _runtimeConfigHint!,
                          style: GoogleFonts.inter(
                            color: const Color(0xFFFADFA4),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    if (_verificationResult != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: const Color(0xFF0E1A2B),
                          border: Border.all(
                            color: _verificationResult!.contains('VERIFIED')
                                ? const Color(0xFF46DBA2)
                                : const Color(0xFFFF7686),
                          ),
                        ),
                        child: Text(
                          _verificationResult!,
                          style: GoogleFonts.inter(
                            color: _verificationResult!.contains('VERIFIED')
                                ? const Color(0xFF8FF3C9)
                                : const Color(0xFFFF9AA7),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    OnyxSectionCard(
                      title: 'Ledger Timeline',
                      subtitle:
                          'Review evidence continuity, hashes, and fallback trace rows in one audit surface.',
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final embeddedTimelineScroll =
                              constraints.maxWidth >= 1280 &&
                              allowEmbeddedPanelScroll(context);
                          final timelineHeight = constraints.maxWidth >= 1280
                              ? 460.0
                              : 390.0;
                          final timeline = showSupabaseRows
                              ? _buildSupabaseLedger(
                                  visibleRows: rowCount,
                                  hiddenRows: hiddenRows,
                                  totalRows: totalRows,
                                  embeddedScroll: embeddedTimelineScroll,
                                )
                              : _buildFallbackTimeline(
                                  visibleRows: rowCount,
                                  hiddenRows: hiddenRows,
                                  totalRows: totalRows,
                                  embeddedScroll: embeddedTimelineScroll,
                                );
                          if (!embeddedTimelineScroll) {
                            return timeline;
                          }
                          return SizedBox(
                            height: timelineHeight,
                            child: timeline,
                          );
                        },
                      ),
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

  Widget _heroHeader(BuildContext context) {
    final integrityLabel = _verificationResult == null
        ? 'Pending'
        : _verificationResult!.contains('VERIFIED')
        ? 'Verified'
        : 'Failed';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF12342E), Color(0xFF0E1D1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF295147)),
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
                        colors: [Color(0xFF10B981), Color(0xFF14B8A6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Icons.account_tree_outlined,
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
                          'Sovereign Ledger',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFF6FBFF),
                            fontSize: compact ? 22 : 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Immutable event chain, provenance tracking, and integrity verification.',
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
                  _heroChip('Client', widget.clientId),
                  _heroChip(
                    'Source',
                    widget.supabaseEnabled ? 'Supabase + Fallback' : 'EventStore',
                  ),
                  _heroChip('Integrity', integrityLabel),
                  _heroChip('Verification', 'Replay Safe'),
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
                key: const ValueKey('ledger-view-events-button'),
                icon: Icons.open_in_new,
                label: 'View Events',
                accent: const Color(0xFF93C5FD),
                onPressed: () => _showEventsLinkDialog(context),
              ),
              _heroActionButton(
                key: const ValueKey('ledger-verify-chain-hero-button'),
                icon: Icons.verified_rounded,
                label: 'Verify Chain',
                accent: const Color(0xFF34D399),
                onPressed: _verifyChain,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        textStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _integritySummaryBar({
    required String sourceLabel,
    required int rowCount,
  }) {
    final integrityLabel = _verificationResult == null
        ? 'Pending'
        : _verificationResult!.contains('VERIFIED')
        ? 'Verified'
        : 'Failed';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1F1C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF25413A)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'CHAIN INTEGRITY',
            style: GoogleFonts.inter(
              color: const Color(0x669BB0CE),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          _statusPill(
            icon: Icons.storage_rounded,
            label: sourceLabel,
            accent: const Color(0xFF63BDFF),
          ),
          _statusPill(
            icon: Icons.format_list_numbered_rounded,
            label: '$rowCount Visible',
            accent: const Color(0xFF59D79B),
          ),
          _statusPill(
            icon: Icons.verified_outlined,
            label: integrityLabel,
            accent: integrityLabel == 'Verified'
                ? const Color(0xFF34D399)
                : integrityLabel == 'Failed'
                ? const Color(0xFFF87171)
                : const Color(0xFFF6C067),
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

  Widget _overviewGrid({
    required String sourceLabel,
    required int rowCount,
    required int totalRows,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1200
            ? 4
            : constraints.maxWidth >= 760
            ? 2
            : 1;
        final aspectRatio = columns == 4
            ? 1.95
            : columns == 2
            ? 2.35
            : 2.55;
        return GridView.count(
          key: const ValueKey('ledger-overview-grid'),
          crossAxisCount: columns,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: aspectRatio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _overviewCard(
              title: 'Ledger Source',
              value: sourceLabel,
              detail: 'Evidence rows are loaded from the active ledger source.',
              icon: Icons.storage_rounded,
              accent: const Color(0xFF63BDFF),
            ),
            _overviewCard(
              title: 'Visible Rows',
              value: '$rowCount',
              detail: '$totalRows total ledger rows are available for audit review.',
              icon: Icons.view_list_outlined,
              accent: const Color(0xFF59D79B),
            ),
            _overviewCard(
              title: 'Integrity State',
              value: _verificationResult == null
                  ? 'Pending'
                  : _verificationResult!.contains('VERIFIED')
                  ? 'Verified'
                  : 'Failed',
              detail: 'Replay-safe verification can be rerun from the hero or header actions.',
              icon: Icons.verified_outlined,
              accent: _verificationResult == null
                  ? const Color(0xFFF6C067)
                  : _verificationResult!.contains('VERIFIED')
                  ? const Color(0xFF34D399)
                  : const Color(0xFFF87171),
            ),
            _overviewCard(
              title: 'Chain Mode',
              value: widget.supabaseEnabled ? 'Hybrid' : 'Fallback',
              detail: widget.supabaseEnabled
                  ? 'Supabase-backed verification with local fallback support.'
                  : 'EventStore-backed fallback timeline with in-memory ordering checks.',
              icon: Icons.account_tree_outlined,
              accent: const Color(0xFFA78BFA),
            ),
          ],
        );
      },
    );
  }

  Widget _overviewCard({
    required String title,
    required String value,
    required String detail,
    required IconData icon,
    required Color accent,
  }) {
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
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: GoogleFonts.robotoMono(
                    color: const Color(0xFFF4F8FF),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
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

  void _showEventsLinkDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111827),
          title: Text(
            'Events Link Ready',
            style: GoogleFonts.inter(
              color: const Color(0xFFF6FBFF),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Use Events to inspect the forensic timeline, selected event payloads, and the upstream chain that feeds this ledger view.',
            style: GoogleFonts.inter(
              color: const Color(0xFFD6E2F2),
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSupabaseLedger({
    required int visibleRows,
    required int hiddenRows,
    required int totalRows,
    required bool embeddedScroll,
  }) {
    final visible = _rows.take(visibleRows).toList(growable: false);
    return ListView.separated(
      itemCount: visible.length + (hiddenRows > 0 ? 1 : 0),
      shrinkWrap: !embeddedScroll,
      primary: embeddedScroll,
      physics: embeddedScroll ? null : const NeverScrollableScrollPhysics(),
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (hiddenRows > 0 && index == visible.length) {
          return _hiddenRowsHint(
            visibleRows: visibleRows,
            totalRows: totalRows,
          );
        }
        final row = visible[index];
        final hash = (row['hash'] ?? '').toString();
        final prev = (row['previous_hash'] ?? '').toString();
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: _timelineRowDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 3,
                decoration: BoxDecoration(
                  color: const Color(0xFF63BDFF),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Dispatch ${row['dispatch_id']}',
                style: GoogleFonts.inter(
                  color: const Color(0xFFE5EFFF),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ledgerPill(
                    'Hash ${hash.isEmpty ? '-' : _short(hash)}',
                    const Color(0xFF9FD7FF),
                    const Color(0xFF2A5E97),
                  ),
                  _ledgerPill(
                    'Prev ${prev.isEmpty ? '-' : _short(prev)}',
                    const Color(0xFFC8D5EA),
                    const Color(0xFF425B80),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFallbackTimeline({
    required int visibleRows,
    required int hiddenRows,
    required int totalRows,
    required bool embeddedScroll,
  }) {
    if (_fallbackRows.isEmpty) {
      return Center(
        child: Text(
          'No ledger rows loaded.',
          style: GoogleFonts.inter(color: const Color(0xFF8EA4C2)),
        ),
      );
    }

    final visible = _fallbackRows.take(visibleRows).toList(growable: false);
    return ListView.separated(
      itemCount: visible.length + (hiddenRows > 0 ? 1 : 0),
      shrinkWrap: !embeddedScroll,
      primary: embeddedScroll,
      physics: embeddedScroll ? null : const NeverScrollableScrollPhysics(),
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (hiddenRows > 0 && index == visible.length) {
          return _hiddenRowsHint(
            visibleRows: visibleRows,
            totalRows: totalRows,
          );
        }
        final row = visible[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: _timelineRowDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 3,
                decoration: BoxDecoration(
                  color: row.color.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    row.type,
                    style: GoogleFonts.rajdhani(
                      color: row.color,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF122442),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFF2A4C7A)),
                    ),
                    child: Text(
                      'SEQ ${row.sequence}',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFA8BEE0),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                row.title,
                style: GoogleFonts.inter(
                  color: const Color(0xFFE5EFFF),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (row.configurationPillLabel != null)
                    _ledgerPill(
                      row.configurationPillLabel!,
                      row.configurationPillTextColor ?? const Color(0xFFA8BEE0),
                      row.configurationPillBorderColor ??
                          const Color(0xFF2A4C7A),
                    ),
                  _ledgerPill(
                    'Event ${row.eventId}',
                    const Color(0xFFA8BEE0),
                    const Color(0xFF2A4C7A),
                  ),
                  _ledgerPill(
                    'UTC ${_shortUtc(row.occurredAt)}',
                    const Color(0xFF8FD1FF),
                    const Color(0xFF35679B),
                  ),
                ],
              ),
              if ((row.detailSummary ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  row.detailSummary!,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9CB2D1),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _hiddenRowsHint({required int visibleRows, required int totalRows}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _timelineRowDecoration(),
      child: OnyxTruncationHint(
        visibleCount: visibleRows,
        totalCount: totalRows,
        subject: 'ledger rows',
        hiddenDescriptor: 'older rows',
        color: const Color(0xFF90A9CB),
        fontSize: 12,
      ),
    );
  }

  String _short(String v) => v.length <= 24 ? v : '${v.substring(0, 24)}...';

  Widget _ledgerPill(String text, Color textColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: borderColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  BoxDecoration _timelineRowDecoration() {
    return BoxDecoration(
      color: const Color(0xFF0E1A2B),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF223244)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x10000000),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    );
  }

  String _shortUtc(DateTime dt) {
    final z = dt.toUtc().toIso8601String();
    return z.length > 19 ? '${z.substring(0, 19)}Z' : z;
  }

  List<_LedgerTimelineRow> _buildFallbackRows(
    List<DispatchEvent> events,
    String clientId,
  ) {
    final rows = <_LedgerTimelineRow>[];

    for (final event in events.reversed) {
      if (event is DecisionCreated && event.clientId == clientId) {
        rows.add(
          _LedgerTimelineRow(
            eventId: event.eventId,
            sequence: event.sequence,
            occurredAt: event.occurredAt,
            type: 'DECISION',
            title:
                '${event.clientId}/${event.siteId} dispatch ${event.dispatchId} created',
            color: const Color(0xFF68C9FF),
          ),
        );
      } else if (event is ExecutionCompleted && event.clientId == clientId) {
        rows.add(
          _LedgerTimelineRow(
            eventId: event.eventId,
            sequence: event.sequence,
            occurredAt: event.occurredAt,
            type: event.success ? 'EXECUTION' : 'EXECUTION FAILED',
            title: '${event.dispatchId} at ${event.siteId}',
            color: event.success
                ? const Color(0xFF5BDEA1)
                : const Color(0xFFFF7B88),
          ),
        );
      } else if (event is ExecutionDenied && event.clientId == clientId) {
        rows.add(
          _LedgerTimelineRow(
            eventId: event.eventId,
            sequence: event.sequence,
            occurredAt: event.occurredAt,
            type: 'EXECUTION DENIED',
            title: '${event.dispatchId} denied (${event.reason})',
            color: const Color(0xFFF4B658),
          ),
        );
      } else if (event is GuardCheckedIn && event.clientId == clientId) {
        rows.add(
          _LedgerTimelineRow(
            eventId: event.eventId,
            sequence: event.sequence,
            occurredAt: event.occurredAt,
            type: 'CHECK-IN',
            title: '${event.guardId} at ${event.siteId}',
            color: const Color(0xFF6DC7FF),
          ),
        );
      } else if (event is PatrolCompleted && event.clientId == clientId) {
        rows.add(
          _LedgerTimelineRow(
            eventId: event.eventId,
            sequence: event.sequence,
            occurredAt: event.occurredAt,
            type: 'PATROL',
            title: '${event.guardId} route ${event.routeId} at ${event.siteId}',
            color: const Color(0xFF68DDA3),
          ),
        );
      } else if (event is ResponseArrived && event.clientId == clientId) {
        rows.add(
          _LedgerTimelineRow(
            eventId: event.eventId,
            sequence: event.sequence,
            occurredAt: event.occurredAt,
            type: 'RESPONSE',
            title: '${event.guardId} for ${event.dispatchId}',
            color: const Color(0xFF6EC7FF),
          ),
        );
      } else if (event is IncidentClosed && event.clientId == clientId) {
        rows.add(
          _LedgerTimelineRow(
            eventId: event.eventId,
            sequence: event.sequence,
            occurredAt: event.occurredAt,
            type: 'INCIDENT CLOSED',
            title: '${event.dispatchId} (${event.resolutionType})',
            color: const Color(0xFFA5E86E),
          ),
        );
      } else if (event is ReportGenerated && event.clientId == clientId) {
        final tracked = _hasTrackedReportSectionConfiguration(event);
        final omittedSections = _omittedReportSectionLabels(
          event.sectionConfiguration,
        );
        final brandingHeadline = _reportBrandingHeadline(event);
        rows.add(
          _LedgerTimelineRow(
            eventId: event.eventId,
            sequence: event.sequence,
            occurredAt: event.occurredAt,
            type: 'REPORT GENERATED',
            title:
                '${event.siteId} ${event.month} • ${_reportSectionConfigurationHeadline(event)}${brandingHeadline == null ? '' : ' • $brandingHeadline'}${_reportInvestigationHeadline(event) == null ? '' : ' • ${_reportInvestigationHeadline(event)}'} • range ${event.eventRangeStart}-${event.eventRangeEnd}',
            color: const Color(0xFFC79CFF),
            configurationPillLabel: tracked
                ? event.brandingUsesOverride
                      ? 'Custom Branding'
                      : omittedSections.isEmpty
                      ? 'Tracked Config'
                      : '${omittedSections.length} Sections Omitted'
                : 'Legacy Config',
            configurationPillTextColor: event.brandingUsesOverride
                ? const Color(0xFFFADFA4)
                : tracked
                ? omittedSections.isEmpty
                      ? const Color(0xFF8FF3C9)
                      : const Color(0xFFFADFA4)
                : const Color(0xFFA8BEE0),
            configurationPillBorderColor: event.brandingUsesOverride
                ? const Color(0xFF8A6A2A)
                : tracked
                ? omittedSections.isEmpty
                      ? const Color(0xFF2D7D63)
                      : const Color(0xFF8A6A2A)
                : const Color(0xFF425B80),
            detailSummary:
                '${_reportBrandingDetail(event)} ${_reportSectionConfigurationDetail(event)} ${_reportInvestigationDetail(event)}',
          ),
        );
      }
    }

    return rows;
  }
}

class _LedgerTimelineRow {
  final String eventId;
  final int sequence;
  final DateTime occurredAt;
  final String type;
  final String title;
  final Color color;
  final String? configurationPillLabel;
  final Color? configurationPillTextColor;
  final Color? configurationPillBorderColor;
  final String? detailSummary;

  const _LedgerTimelineRow({
    required this.eventId,
    required this.sequence,
    required this.occurredAt,
    required this.type,
    required this.title,
    required this.color,
    this.configurationPillLabel,
    this.configurationPillTextColor,
    this.configurationPillBorderColor,
    this.detailSummary,
  });
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

String _reportSectionConfigurationHeadline(ReportGenerated event) {
  if (!_hasTrackedReportSectionConfiguration(event)) {
    return 'legacy receipt config';
  }
  final omitted = _omittedReportSectionLabels(event.sectionConfiguration);
  if (omitted.isEmpty) {
    return 'all sections included';
  }
  return '${omitted.length} sections omitted';
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

String _reportInvestigationDetail(ReportGenerated event) {
  return switch (_reportInvestigationContext(event)) {
    ReportEntryContext.governanceBrandingDrift =>
      'Investigation: this receipt was generated from a Governance branding-drift handoff.',
    null => 'Investigation: routine report review.',
  };
}
