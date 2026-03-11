import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../application/report_generation_service.dart';
import '../domain/events/report_generated.dart';
import '../domain/store/in_memory_event_store.dart';
import '../presentation/reports/report_preview_page.dart';
import 'onyx_surface.dart';

class ClientIntelligenceReportsPage extends StatefulWidget {
  final InMemoryEventStore store;
  final String selectedClient;
  final String selectedSite;

  const ClientIntelligenceReportsPage({
    super.key,
    required this.store,
    required this.selectedClient,
    required this.selectedSite,
  });

  @override
  State<ClientIntelligenceReportsPage> createState() =>
      _ClientIntelligenceReportsPageState();
}

class _ClientIntelligenceReportsPageState
    extends State<ClientIntelligenceReportsPage> {
  bool _isGenerating = false;
  bool _isRefreshing = false;
  List<_ReceiptRow> _receipts = const [];

  _OutputMode _outputMode = _OutputMode.pdf;
  String _selectedScope = 'Sandton Estate North';
  DateTime _startDate = DateTime.utc(2024, 3, 1);
  DateTime _endDate = DateTime.utc(2024, 3, 10);

  bool _includeTimeline = true;
  bool _includeDispatchSummary = true;
  bool _includeCheckpointCompliance = true;
  bool _includeAiDecisionLog = false;
  bool _includeGuardMetrics = false;

  ReportGenerationService get _service =>
      ReportGenerationService(store: widget.store);

  @override
  void initState() {
    super.initState();
    _loadReceipts();
  }

  Future<void> _loadReceipts() async {
    setState(() => _isRefreshing = true);
    final rows = <_ReceiptRow>[];
    final reportEvents =
        widget.store
            .allEvents()
            .whereType<ReportGenerated>()
            .where(
              (event) =>
                  event.clientId == widget.selectedClient &&
                  event.siteId == widget.selectedSite,
            )
            .toList()
          ..sort((a, b) => b.sequence.compareTo(a.sequence));

    for (final event in reportEvents) {
      final replayVerified = await _service.verifyReportHash(event);
      rows.add(_ReceiptRow(event: event, replayVerified: replayVerified));
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _receipts = rows;
      _isRefreshing = false;
    });
  }

  Future<void> _generateReport() async {
    setState(() => _isGenerating = true);
    final generated = await _service.generatePdfReport(
      clientId: widget.selectedClient,
      siteId: widget.selectedSite,
      nowUtc: DateTime.now().toUtc(),
    );
    final replayMatches = await _service.verifyReportHash(
      generated.receiptEvent,
    );
    await _loadReceipts();
    if (!mounted) {
      return;
    }
    setState(() => _isGenerating = false);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportPreviewPage(
          bundle: generated.bundle,
          initialPdfBytes: generated.pdfBytes,
          receiptEvent: generated.receiptEvent,
          replayMatches: replayMatches,
        ),
      ),
    );
  }

  Future<void> _openReceipt(_ReceiptRow row) async {
    final regenerated = await _service.regenerateFromReceipt(row.event);
    final replayMatches = await _service.verifyReportHash(row.event);
    if (!mounted) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportPreviewPage(
          bundle: regenerated.bundle,
          initialPdfBytes: regenerated.pdfBytes,
          receiptEvent: row.event,
          replayMatches: replayMatches,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final verifiedCount = _receipts.where((row) => row.replayVerified).length;
    final pendingCount = _receipts.length - verifiedCount;
    final replayState = _isRefreshing
        ? 'RUNNING'
        : pendingCount == 0 && _receipts.isNotEmpty
        ? 'VERIFIED'
        : 'READY';

    return OnyxPageScaffold(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1540),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  OnyxPageHeader(
                    title: 'CLIENT INTELLIGENCE REPORTS',
                    subtitle:
                        '${widget.selectedClient} • ${widget.selectedSite}',
                    actions: [
                      _actionButton(
                        label: _isGenerating
                            ? 'Generating...'
                            : 'Preview Report',
                        icon: Icons.picture_as_pdf_rounded,
                        onTap: _isGenerating ? null : _generateReport,
                      ),
                      _actionButton(
                        label: _isRefreshing
                            ? 'Refreshing...'
                            : 'Refresh Replay Verification',
                        icon: Icons.verified_rounded,
                        onTap: _isRefreshing ? null : _loadReceipts,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _kpiBand(
                    totalReceipts: _receipts.length,
                    verifiedCount: verifiedCount,
                    pendingCount: pendingCount,
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 1240;
                      final controls = Column(
                        children: [
                          OnyxSectionCard(
                            title: 'Deterministic Generation',
                            subtitle:
                                'Generate PDF from projection snapshots, append a receipt, and verify replay-safe integrity before delivery.',
                            child: _buildDeterministicControls(),
                          ),
                          const SizedBox(height: 8),
                          OnyxSectionCard(
                            title: 'Generation Lanes',
                            subtitle:
                                'Keep generation, replay, and operator review distinct during report handling.',
                            child: Column(
                              children: [
                                _generationLane(
                                  color: const Color(0xFF63BDFF),
                                  icon: Icons.description_rounded,
                                  title: 'Generate',
                                  detail: 'Create PDF and receipt pair.',
                                  status: 'READY',
                                  actionText: 'Generate Now',
                                  onTap: _isGenerating ? null : _generateReport,
                                ),
                                const SizedBox(height: 8),
                                _generationLane(
                                  color: const Color(0xFF59D79B),
                                  icon: Icons.verified_rounded,
                                  title: 'Verify',
                                  detail:
                                      'Re-open receipts and confirm hash chain replay.',
                                  status: replayState,
                                  actionText: 'Refresh Replay Verification',
                                  onTap: _isRefreshing ? null : _loadReceipts,
                                ),
                                const SizedBox(height: 8),
                                _generationLane(
                                  color: const Color(0xFFF6C067),
                                  icon: Icons.visibility_rounded,
                                  title: 'Review',
                                  detail:
                                      'Open regenerated preview before release.',
                                  status: _receipts.isEmpty ? 'IDLE' : 'READY',
                                  actionText: _receipts.isEmpty
                                      ? 'No Receipt Selected'
                                      : 'Open Latest Receipt',
                                  onTap: _receipts.isEmpty
                                      ? null
                                      : () => _openReceipt(_receipts.first),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          OnyxSectionCard(
                            title: 'Report Configuration',
                            subtitle:
                                'Select the operational sections included in each generated client report.',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _toggle(
                                  label: 'Include incident timeline',
                                  value: _includeTimeline,
                                  onChanged: (value) =>
                                      setState(() => _includeTimeline = value),
                                ),
                                _toggle(
                                  label: 'Include dispatch summary',
                                  value: _includeDispatchSummary,
                                  onChanged: (value) => setState(
                                    () => _includeDispatchSummary = value,
                                  ),
                                ),
                                _toggle(
                                  label: 'Include checkpoint compliance',
                                  value: _includeCheckpointCompliance,
                                  onChanged: (value) => setState(
                                    () => _includeCheckpointCompliance = value,
                                  ),
                                ),
                                _toggle(
                                  label: 'Include AI decision log',
                                  value: _includeAiDecisionLog,
                                  onChanged: (value) => setState(
                                    () => _includeAiDecisionLog = value,
                                  ),
                                ),
                                _toggle(
                                  label: 'Include guard performance metrics',
                                  value: _includeGuardMetrics,
                                  onChanged: (value) => setState(
                                    () => _includeGuardMetrics = value,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                      final history = OnyxSectionCard(
                        title: 'Receipt History',
                        subtitle:
                            'Open generated receipts to regenerate reports and confirm replay integrity.',
                        child: _buildReceiptHistory(),
                      );

                      if (stacked) {
                        return Column(
                          children: [
                            controls,
                            const SizedBox(height: 8),
                            history,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: controls),
                          const SizedBox(width: 8),
                          Expanded(flex: 7, child: history),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _kpiBand({
    required int totalReceipts,
    required int verifiedCount,
    required int pendingCount,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _kpiCard(
            label: 'TOTAL RECEIPTS',
            value: '$totalReceipts',
            accent: const Color(0xFF63BDFF),
            icon: Icons.description_rounded,
          ),
          _kpiCard(
            label: 'VERIFIED REPORTS',
            value: '$verifiedCount',
            accent: const Color(0xFF59D79B),
            icon: Icons.verified_rounded,
          ),
          _kpiCard(
            label: 'PENDING VERIFICATION',
            value: '$pendingCount',
            accent: const Color(0xFFF6C067),
            icon: Icons.pending_actions_rounded,
          ),
          _kpiCard(
            label: 'OUTPUT MODE',
            value: _outputMode.label,
            accent: const Color(0xFFE8F1FF),
            icon: Icons.download_rounded,
          ),
        ];

        if (constraints.maxWidth < 1180) {
          return Wrap(spacing: 8, runSpacing: 8, children: cards);
        }

        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i < cards.length - 1) const SizedBox(width: 8),
            ],
          ],
        );
      },
    );
  }

  Widget _kpiCard({
    required String label,
    required String value,
    required Color accent,
    required IconData icon,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 108, minWidth: 220),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A2B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF223244)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 3,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const Spacer(),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF16273D),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF7D93B1),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.rajdhani(
              color: accent,
              fontSize: 34,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeterministicControls() {
    final scopes = <String>[
      'Sandton Estate North',
      'Waterfall Estate Main',
      'Blue Ridge Security',
      'Midrand Industrial Park',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Client / Site'),
        const SizedBox(height: 4),
        _dropdownField(
          value: _selectedScope,
          items: scopes,
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() => _selectedScope = value);
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _dateField(
                label: 'Start Date',
                date: _startDate,
                onTap: () => _pickDate(
                  initial: _startDate,
                  first: DateTime.utc(2020, 1, 1),
                  last: _endDate,
                  onSelected: (picked) => setState(() => _startDate = picked),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _dateField(
                label: 'End Date',
                date: _endDate,
                onTap: () => _pickDate(
                  initial: _endDate,
                  first: _startDate,
                  last: DateTime.now().toUtc().add(const Duration(days: 365)),
                  onSelected: (picked) => setState(() => _endDate = picked),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _fieldLabel('Output Format'),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final mode in _OutputMode.values) ...[
              Expanded(
                child: _outputModeChip(
                  label: mode.label,
                  selected: _outputMode == mode,
                  onTap: () => setState(() => _outputMode = mode),
                ),
              ),
              if (mode != _OutputMode.values.last) const SizedBox(width: 6),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildReceiptHistory() {
    final hasLiveReceipts = _receipts.isNotEmpty;
    final rows = hasLiveReceipts ? _receipts : _sampleReceipts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              hasLiveReceipts ? 'Live Receipts' : 'Sample Receipts',
              style: GoogleFonts.inter(
                color: const Color(0xFF8EA4C2),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            _pillActionButton(
              label: 'Export All',
              icon: Icons.download_rounded,
              buttonKey: const ValueKey('reports-export-all-button'),
              onTap: () => _exportAllReceipts(rows),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          const OnyxEmptyState(label: 'No ReportGenerated receipts yet.')
        else
          for (var i = 0; i < rows.length; i++) ...[
            _receiptCard(rows[i], hasLiveReceipts: hasLiveReceipts),
            if (i < rows.length - 1) const SizedBox(height: 8),
          ],
      ],
    );
  }

  Widget _generationLane({
    required Color color,
    required IconData icon,
    required String title,
    required String detail,
    required String status,
    required String actionText,
    required VoidCallback? onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF10233A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.rajdhani(
                        color: const Color(0xFFE8F1FF),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      detail,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8EA4C2),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _statusChip(status),
            ],
          ),
          const SizedBox(height: 8),
          _pillActionButton(
            label: actionText,
            icon: Icons.play_arrow_rounded,
            onTap: onTap,
          ),
        ],
      ),
    );
  }

  Widget _receiptCard(_ReceiptRow row, {required bool hasLiveReceipts}) {
    final statusLabel = row.replayVerified ? 'VERIFIED' : 'PENDING';
    final statusColor = row.replayVerified
        ? const Color(0xFF59D79B)
        : const Color(0xFFF6C067);

    final clientName = _humanizeClient(row.event.clientId);
    final siteName = _humanizeSite(row.event.siteId);
    final period = _periodFromMonth(row.event.month);
    final generatedAt = _formatUtc(row.event.occurredAt);
    final fileSize =
        '${(1.6 + (row.event.eventCount / 1400)).toStringAsFixed(1)} MB';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF10233A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.45)),
      ),
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
                      clientName,
                      style: GoogleFonts.rajdhani(
                        color: const Color(0xFFE8F1FF),
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      siteName,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8EA4C2),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.inter(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _receiptMeta('Report ID', row.event.eventId),
              _receiptMeta('File Size', fileSize),
              _receiptMeta('Period', period),
              _receiptMeta('Events', '${row.event.eventCount}'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Generated: $generatedAt',
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _pillActionButton(
                  label: 'Preview',
                  icon: Icons.visibility_rounded,
                  onTap: hasLiveReceipts ? () => _openReceipt(row) : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _pillActionButton(
                  label: 'Download',
                  icon: Icons.download_rounded,
                  onTap: hasLiveReceipts ? () => _openReceipt(row) : null,
                  filled: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _receiptMeta(String label, String value) {
    return SizedBox(
      width: 170,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA4C2),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: GoogleFonts.inter(
              color: const Color(0xFFD9E7FA),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.inter(
        color: const Color(0xFF8EA4C2),
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _dropdownField({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      key: ValueKey<String>(value),
      initialValue: value,
      onChanged: onChanged,
      iconEnabledColor: const Color(0xFF8EA4C2),
      dropdownColor: const Color(0xFF0E1A2B),
      style: GoogleFonts.inter(
        color: const Color(0xFFE8F1FF),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: const Color(0xFF0A0E14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF223244)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF3C79BB)),
        ),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 4),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0E14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF223244)),
            ),
            child: Text(
              _formatDate(date),
              style: GoogleFonts.inter(
                color: const Color(0xFFE8F1FF),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _outputModeChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0x2230C8FF) : const Color(0xFF0A0E14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF3FA7D6) : const Color(0xFF223244),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: selected
                  ? const Color(0xFF63BDFF)
                  : const Color(0xFF8EA4C2),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _toggle({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return CheckboxListTile(
      value: value,
      onChanged: (next) => onChanged(next ?? false),
      dense: true,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      activeColor: const Color(0xFF3FA7D6),
      checkColor: const Color(0xFF040A16),
      title: Text(
        label,
        style: GoogleFonts.inter(
          color: const Color(0xFFD9E7FA),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _statusChip(String label) {
    Color color;
    switch (label) {
      case 'VERIFIED':
      case 'READY':
        color = const Color(0xFF59D79B);
        break;
      case 'RUNNING':
        color = const Color(0xFF63BDFF);
        break;
      case 'PENDING':
        color = const Color(0xFFF6C067);
        break;
      default:
        color = const Color(0xFF8EA4C2);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _pillActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    Key? buttonKey,
    bool filled = false,
  }) {
    return TextButton.icon(
      key: buttonKey,
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        backgroundColor: filled
            ? const Color(0xFF2A5D95)
            : const Color(0xFF132947),
        foregroundColor: const Color(0xFFE8F1FF),
        disabledBackgroundColor: const Color(0xFF101A28),
        disabledForegroundColor: const Color(0xFF5E738F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: const BorderSide(color: Color(0xFF2A4768)),
        ),
      ),
      icon: Icon(icon, size: 15),
      label: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  void _exportAllReceipts(List<_ReceiptRow> rows) {
    if (rows.isEmpty) {
      _showReceiptActionFeedback('No receipts available to export.');
      return;
    }
    final payload = rows
        .map(
          (row) => <String, Object?>{
            'eventId': row.event.eventId,
            'clientId': row.event.clientId,
            'siteId': row.event.siteId,
            'occurredAtUtc': row.event.occurredAt.toUtc().toIso8601String(),
            'month': row.event.month,
            'eventCount': row.event.eventCount,
            'replayVerified': row.replayVerified,
          },
        )
        .toList(growable: false);
    final encoded = const JsonEncoder.withIndent('  ').convert(payload);
    Clipboard.setData(ClipboardData(text: encoded));
    _showReceiptActionFeedback(
      'Exported ${rows.length} receipt records to clipboard.',
    );
  }

  void _showReceiptActionFeedback(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: const Color(0xFF194E87),
        foregroundColor: const Color(0xFFE8F1FF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: const BorderSide(color: Color(0xFF2A4768)),
        ),
      ),
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Future<void> _pickDate({
    required DateTime initial,
    required DateTime first,
    required DateTime last,
    required ValueChanged<DateTime> onSelected,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: 'Select report date',
    );
    if (picked == null) {
      return;
    }
    onSelected(DateTime.utc(picked.year, picked.month, picked.day));
  }

  String _humanizeClient(String clientId) {
    final normalized = clientId.replaceAll('_', '-').toUpperCase();
    if (normalized == 'CLIENT-001') {
      return 'Sandton Estate HOA';
    }
    return normalized;
  }

  String _humanizeSite(String siteId) {
    final normalized = siteId.replaceAll('_', '-').toUpperCase();
    if (normalized == 'SITE-SANDTON') {
      return 'Sandton Estate North';
    }
    return normalized;
  }

  String _periodFromMonth(String month) {
    final parts = month.split('-');
    if (parts.length != 2) {
      return month;
    }
    final year = int.tryParse(parts[0]);
    final monthIndex = int.tryParse(parts[1]);
    if (year == null ||
        monthIndex == null ||
        monthIndex < 1 ||
        monthIndex > 12) {
      return month;
    }
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${monthNames[monthIndex - 1]} $year';
  }

  String _formatUtc(DateTime dateTime) {
    final value = dateTime.toUtc();
    final yy = value.year.toString().padLeft(4, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$yy-$mm-$dd $hh:$min UTC';
  }

  String _formatDate(DateTime dateTime) {
    final yy = dateTime.year.toString().padLeft(4, '0');
    final mm = dateTime.month.toString().padLeft(2, '0');
    final dd = dateTime.day.toString().padLeft(2, '0');
    return '$yy-$mm-$dd';
  }

  List<_ReceiptRow> get _sampleReceipts => [
    _ReceiptRow(
      event: ReportGenerated(
        eventId: 'RPT-2024-03-10-001',
        sequence: 0,
        version: 1,
        occurredAt: DateTime.utc(2024, 3, 10, 22, 15),
        clientId: 'Sandton Estate HOA',
        siteId: 'Sandton Estate North',
        month: '2024-03',
        contentHash: 'sample',
        pdfHash: 'sample',
        eventRangeStart: 1,
        eventRangeEnd: 1247,
        eventCount: 1247,
        reportSchemaVersion: 1,
        projectionVersion: 1,
      ),
      replayVerified: true,
    ),
    _ReceiptRow(
      event: ReportGenerated(
        eventId: 'RPT-2024-03-10-002',
        sequence: 0,
        version: 1,
        occurredAt: DateTime.utc(2024, 3, 10, 22, 10),
        clientId: 'Waterfall Security Board',
        siteId: 'Waterfall Estate Main',
        month: '2024-03',
        contentHash: 'sample',
        pdfHash: 'sample',
        eventRangeStart: 1,
        eventRangeEnd: 1856,
        eventCount: 1856,
        reportSchemaVersion: 1,
        projectionVersion: 1,
      ),
      replayVerified: true,
    ),
    _ReceiptRow(
      event: ReportGenerated(
        eventId: 'RPT-2024-03-09-002',
        sequence: 0,
        version: 1,
        occurredAt: DateTime.utc(2024, 3, 9, 23, 40),
        clientId: 'Midrand Industrial Trust',
        siteId: 'Midrand Industrial Park',
        month: '2024-03',
        contentHash: 'sample',
        pdfHash: 'sample',
        eventRangeStart: 1,
        eventRangeEnd: 1134,
        eventCount: 1134,
        reportSchemaVersion: 1,
        projectionVersion: 1,
      ),
      replayVerified: false,
    ),
  ];
}

class _ReceiptRow {
  final ReportGenerated event;
  final bool replayVerified;

  const _ReceiptRow({required this.event, required this.replayVerified});
}

enum _OutputMode {
  pdf('PDF'),
  excel('EXCEL'),
  json('JSON');

  const _OutputMode(this.label);
  final String label;
}
