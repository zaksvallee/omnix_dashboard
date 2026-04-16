import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme/onyx_design_tokens.dart';

// ── Colour aliases ─────────────────────────────────────────────────────────
const _alarmBg = OnyxColorTokens.backgroundPrimary;
const _alarmSurface = OnyxColorTokens.backgroundSecondary;
const _alarmTitle = OnyxDesignTokens.textPrimary;
const _alarmBody = OnyxDesignTokens.textSecondary;
const _alarmMuted = OnyxDesignTokens.textMuted;
const _alarmDivider = OnyxColorTokens.divider;
const _alarmBorder = OnyxDesignTokens.borderSubtle;

// ── Enums ──────────────────────────────────────────────────────────────────

enum _AlarmStatus { detected, verified, dispatched, onSite, secured, closed }

enum _AlarmPriority { p1, p2, p3, p4 }

// ── Data model ─────────────────────────────────────────────────────────────

class _AlarmRecord {
  final String id;
  final String eventUid;
  final String clientId;
  final String siteId;
  final String incidentType;
  final _AlarmPriority priority;
  final _AlarmStatus status;
  final DateTime signalReceivedAt;
  final DateTime? triageTime;
  final DateTime? dispatchTime;
  final String? controllerNotes;
  final String? fieldReport;
  final Map<String, dynamic> metadata;

  const _AlarmRecord({
    required this.id,
    required this.eventUid,
    required this.clientId,
    required this.siteId,
    required this.incidentType,
    required this.priority,
    required this.status,
    required this.signalReceivedAt,
    this.triageTime,
    this.dispatchTime,
    this.controllerNotes,
    this.fieldReport,
    this.metadata = const {},
  });

  factory _AlarmRecord.fromRow(Map<String, dynamic> row) {
    _AlarmStatus parseStatus(String? s) => switch (s) {
      'verified' => _AlarmStatus.verified,
      'dispatched' => _AlarmStatus.dispatched,
      'on_site' => _AlarmStatus.onSite,
      'secured' => _AlarmStatus.secured,
      'closed' => _AlarmStatus.closed,
      _ => _AlarmStatus.detected,
    };
    _AlarmPriority parsePriority(String? s) => switch (s) {
      'p1' => _AlarmPriority.p1,
      'p2' => _AlarmPriority.p2,
      'p4' => _AlarmPriority.p4,
      _ => _AlarmPriority.p3,
    };
    return _AlarmRecord(
      id: row['id']?.toString() ?? '',
      eventUid: row['event_uid']?.toString() ?? '',
      clientId: row['client_id']?.toString() ?? '',
      siteId: row['site_id']?.toString() ?? '',
      incidentType: row['incident_type']?.toString() ?? 'breach',
      priority: parsePriority(row['priority']?.toString()),
      status: parseStatus(row['status']?.toString()),
      signalReceivedAt: _parseTimestamp(row['signal_received_at']),
      triageTime: _parseTimestampOrNull(row['triage_time']),
      dispatchTime: _parseTimestampOrNull(row['dispatch_time']),
      controllerNotes: row['controller_notes']?.toString(),
      fieldReport: row['field_report']?.toString(),
      metadata: (row['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }

  static DateTime _parseTimestamp(dynamic v) {
    if (v == null) return DateTime.now().toUtc();
    if (v is DateTime) return v.toUtc();
    return DateTime.tryParse(v.toString())?.toUtc() ?? DateTime.now().toUtc();
  }

  static DateTime? _parseTimestampOrNull(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v.toUtc();
    return DateTime.tryParse(v.toString())?.toUtc();
  }

  String get humanSiteId {
    final raw = siteId.trim();
    final cleaned = raw
        .replaceFirst(RegExp(r'^(SITE|CLIENT|REGION)-', caseSensitive: false), '')
        .replaceAll(RegExp(r'[-_]+'), ' ')
        .trim();
    if (cleaned.isEmpty) return raw;
    return cleaned
        .split(' ')
        .map((t) => t.isEmpty ? t : '${t[0].toUpperCase()}${t.substring(1).toLowerCase()}')
        .join(' ');
  }

  String get humanClientId {
    final raw = clientId.trim();
    final cleaned = raw
        .replaceFirst(RegExp(r'^(CLIENT|SITE)-', caseSensitive: false), '')
        .replaceAll(RegExp(r'[-_]+'), ' ')
        .trim();
    if (cleaned.isEmpty) return raw;
    return cleaned
        .split(' ')
        .map((t) => t.isEmpty ? t : '${t[0].toUpperCase()}${t.substring(1).toLowerCase()}')
        .join(' ');
  }

  String get triggerType {
    return switch (incidentType) {
      'breach' => 'Perimeter Breach',
      'fire' => 'Fire Alarm',
      'medical' => 'Medical Emergency',
      'panic' => 'Panic Button',
      'loitering' => 'Loitering Detected',
      'technical_failure' => 'Technical Failure',
      _ => incidentType.replaceAll('_', ' ').toUpperCase(),
    };
  }

  String get triggeredLabel {
    final now = DateTime.now().toUtc();
    final diff = now.difference(signalReceivedAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    final h = signalReceivedAt.hour.toString().padLeft(2, '0');
    final m = signalReceivedAt.minute.toString().padLeft(2, '0');
    return 'Triggered $h:$m';
  }

  String get shortId {
    final uid = eventUid.trim();
    if (uid.isEmpty) return id.substring(0, 8).toUpperCase();
    return uid.length > 12 ? uid.substring(0, 12).toUpperCase() : uid.toUpperCase();
  }

  bool get isActive =>
      status != _AlarmStatus.secured && status != _AlarmStatus.closed;

  int get callAttempts => (metadata['call_attempts'] as int?) ?? 0;
}

// ── Page ───────────────────────────────────────────────────────────────────

class AlarmsPage extends StatefulWidget {
  final bool supabaseReady;
  final VoidCallback? onOpenDispatches;
  final ValueChanged<String>? onOpenAlarmDetail;
  final int cameraCount;
  final int guardCount;
  final String signalHealthLabel;
  final String? lastIncidentReference;
  final String? lastIncidentTitle;
  final String? lastIncidentStatusLabel;
  final String? lastIncidentTimestampLabel;
  final VoidCallback? onRunSystemCheck;
  final VoidCallback? onOpenLiveFeeds;

  const AlarmsPage({
    super.key,
    this.supabaseReady = false,
    this.onOpenDispatches,
    this.onOpenAlarmDetail,
    this.cameraCount = 0,
    this.guardCount = 0,
    this.signalHealthLabel = 'Stable',
    this.lastIncidentReference,
    this.lastIncidentTitle,
    this.lastIncidentStatusLabel,
    this.lastIncidentTimestampLabel,
    this.onRunSystemCheck,
    this.onOpenLiveFeeds,
  });

  @override
  State<AlarmsPage> createState() => _AlarmsPageState();
}

class _AlarmsPageState extends State<AlarmsPage> {
  List<_AlarmRecord> _alarms = const [];
  bool _loading = true;
  String? _error;
  RealtimeChannel? _realtimeChannel;

  // Per-alarm officer selection (alarmId → chosen officer)
  final Map<String, String?> _selectedOfficers = {};

  // Busy state for dispatch actions
  final Set<String> _busyAlarms = {};

  static const _officers = <String>[
    'Delta-1 — J. van der Merwe',
    'Bravo-2 — T. Nkosi',
    'Alpha-3 — M. Patel',
    'Charlie-1 — S. Williams',
    'Echo-4 — K. Dlamini',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.supabaseReady) {
      _loadAlarms();
      _subscribeRealtime();
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  void didUpdateWidget(covariant AlarmsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.supabaseReady && widget.supabaseReady) {
      _loadAlarms();
      _subscribeRealtime();
    }
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadAlarms() async {
    try {
      final rows = await Supabase.instance.client
          .from('incidents')
          .select()
          .not('status', 'in', '("secured","closed")')
          .order('signal_received_at', ascending: false)
          .limit(50);
      if (!mounted) return;
      setState(() {
        _alarms = (rows as List)
            .map((r) => _AlarmRecord.fromRow(r as Map<String, dynamic>))
            .toList(growable: false);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _subscribeRealtime() {
    _realtimeChannel = Supabase.instance.client
        .channel('alarms-page-incidents')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'incidents',
          callback: (_) => _loadAlarms(),
        )
        .subscribe();
  }

  Future<void> _dispatchNow(String alarmId, String officer) async {
    if (_busyAlarms.contains(alarmId)) return;
    setState(() => _busyAlarms.add(alarmId));
    try {
      await Supabase.instance.client.from('incidents').update({
        'status': 'dispatched',
        'dispatch_time': DateTime.now().toUtc().toIso8601String(),
        'controller_notes': 'Dispatched $officer via Alarms dashboard.',
      }).eq('id', alarmId);
      await _loadAlarms();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dispatch failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyAlarms.remove(alarmId));
    }
  }

  Future<void> _markFalseAlarm(String alarmId) async {
    if (_busyAlarms.contains(alarmId)) return;
    setState(() => _busyAlarms.add(alarmId));
    try {
      await Supabase.instance.client.from('incidents').update({
        'status': 'secured',
        'resolution_time': DateTime.now().toUtc().toIso8601String(),
        'controller_notes': 'False alarm — cleared by operator via Alarms dashboard.',
      }).eq('id', alarmId);
      await _loadAlarms();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyAlarms.remove(alarmId));
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _alarmBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: const BoxDecoration(
        color: _alarmBg,
        border: Border(bottom: BorderSide(color: _alarmDivider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Alarm monitoring',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _alarmTitle,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Armed response dispatch and tracking',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: _alarmBody,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (!_loading && _alarms.isNotEmpty)
            _statusChip(
              '${_alarms.length} ACTIVE',
              OnyxDesignTokens.redCritical,
              OnyxColorTokens.redSurface,
              OnyxColorTokens.redBorder,
            ),
          if (!_loading && _alarms.isEmpty)
            _nominalStatusBadge(),
        ],
      ),
    );
  }

  Widget _nominalStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: OnyxColorTokens.accentGreen.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: OnyxColorTokens.accentGreen.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: OnyxColorTokens.accentGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'ALL SYSTEMS NOMINAL',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: OnyxColorTokens.accentGreen,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, Color fg, Color bg, Color border) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: OnyxDesignTokens.cyanInteractive),
      );
    }
    if (_error != null) {
      return _buildErrorState();
    }
    if (_alarms.isEmpty) {
      return _buildEmptyState();
    }
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _alarms.length,
      itemBuilder: (context, index) => _buildAlarmCard(_alarms[index]),
    );
  }

  Widget _buildEmptyState() {
    final signalLabel = widget.signalHealthLabel.trim().isEmpty
        ? 'Stable'
        : widget.signalHealthLabel.trim();
    final signalNominal = signalLabel.toLowerCase() == 'stable';
    final hasLastIncident = (widget.lastIncidentTitle ?? '').trim().isNotEmpty;
    final lastIncidentReference = (widget.lastIncidentReference ?? '').trim();
    final canReviewLastIncident = hasLastIncident || lastIncidentReference.isNotEmpty;

    VoidCallback? reviewLastIncidentCallback() {
      if (!canReviewLastIncident) {
        return null;
      }
      return () {
        final detail = widget.onOpenAlarmDetail;
        if (detail != null && lastIncidentReference.isNotEmpty) {
          detail(lastIncidentReference);
          return;
        }
        widget.onOpenDispatches?.call();
      };
    }

    final onReviewLastIncident = reviewLastIncidentCallback();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _nominalZaraPresenceBlock(),
          const SizedBox(height: 14),
          _sectionLabel('SYSTEM STATUS'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusStatChip(
                label: 'CAMERAS',
                value: '${widget.cameraCount} active',
                valueColor: OnyxColorTokens.accentGreen,
              ),
              _statusStatChip(
                label: 'GUARDS',
                value: '${widget.guardCount} on duty',
                valueColor: OnyxColorTokens.accentGreen,
              ),
              _statusStatChip(
                label: 'SIGNAL',
                value: signalLabel,
                valueColor: signalNominal
                    ? OnyxColorTokens.accentGreen
                    : OnyxColorTokens.accentAmber,
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Center(child: _MonitoringHeartbeat()),
          const SizedBox(height: 14),
          _lastEventBlock(onReviewLastIncident),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _quickActionButton(
                label: 'Run System Check',
                onTap: widget.onRunSystemCheck,
              ),
              _quickActionButton(
                label: 'Review Last Incident',
                onTap: onReviewLastIncident,
              ),
              _quickActionButton(
                label: 'Open Live Feeds',
                accent: OnyxColorTokens.accentSky,
                onTap: widget.onOpenLiveFeeds,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _nominalZaraPresenceBlock() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: OnyxColorTokens.accentPurple.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: OnyxColorTokens.accentPurple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: OnyxColorTokens.accentPurple.withValues(alpha: 0.35),
              ),
            ),
            child: Center(
              child: Text(
                'Z',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: OnyxColorTokens.accentPurple,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ZARA · MONITORING',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: OnyxColorTokens.accentPurple.withValues(alpha: 0.60),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                _presenceLine(
                  dotColor: OnyxColorTokens.accentGreen,
                  text: 'All sites secure. No active threats detected.',
                ),
                const SizedBox(height: 5),
                _presenceLine(
                  dotColor: OnyxColorTokens.accentGreen,
                  text: 'Perimeter integrity confirmed across all zones.',
                ),
                const SizedBox(height: 5),
                _presenceLine(
                  dotColor: OnyxColorTokens.accentPurple,
                  text: 'Standing by. Alert threshold active.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _presenceLine({required Color dotColor, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: OnyxColorTokens.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        color: OnyxColorTokens.textDisabled,
        letterSpacing: 1.3,
      ),
    );
  }

  Widget _statusStatChip({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: OnyxColorTokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: OnyxColorTokens.textDisabled,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _lastEventBlock(VoidCallback? onReviewLastIncident) {
    final hasLastIncident = (widget.lastIncidentTitle ?? '').trim().isNotEmpty;
    final timestamp = (widget.lastIncidentTimestampLabel ?? '').trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: OnyxColorTokens.backgroundSecondary,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: OnyxColorTokens.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LAST ACTIVITY',
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: OnyxColorTokens.textDisabled,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                if (hasLastIncident) ...[
                  Text(
                    (widget.lastIncidentTitle ?? '').trim(),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: OnyxColorTokens.textMuted,
                    ),
                  ),
                  if ((widget.lastIncidentStatusLabel ?? '').trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        (widget.lastIncidentStatusLabel ?? '').trim(),
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w400,
                          color: OnyxColorTokens.textDisabled,
                        ),
                      ),
                    ),
                ] else
                  Text(
                    'No recent incidents',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: OnyxColorTokens.textDisabled,
                    ),
                  ),
              ],
            ),
          ),
          if (hasLastIncident)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timestamp,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: OnyxColorTokens.textDisabled,
                  ),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: onReviewLastIncident,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      'View incident →',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: OnyxColorTokens.accentPurple.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _quickActionButton({
    required String label,
    required VoidCallback? onTap,
    Color accent = OnyxColorTokens.textMuted,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: OnyxColorTokens.backgroundSecondary,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: accent == OnyxColorTokens.accentSky
                  ? OnyxColorTokens.accentSky.withValues(alpha: 0.18)
                  : OnyxColorTokens.divider,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: onTap == null
                  ? OnyxColorTokens.textDisabled
                  : accent == OnyxColorTokens.accentSky
                  ? OnyxColorTokens.accentSky.withValues(alpha: 0.55)
                  : OnyxColorTokens.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 48,
            color: OnyxDesignTokens.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            'Could not load alarms',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _alarmTitle,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _error ?? 'Unknown error',
            style: GoogleFonts.inter(fontSize: 12, color: _alarmBody),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _loadAlarms,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ── Alarm card ────────────────────────────────────────────────────────────

  Widget _buildAlarmCard(_AlarmRecord alarm) {
    final severityColor = _severityColor(alarm.priority);
    final isPending =
        alarm.status == _AlarmStatus.detected ||
        alarm.status == _AlarmStatus.verified;
    final isBusy = _busyAlarms.contains(alarm.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _alarmSurface,
        borderRadius: OnyxRadiusTokens.radiusMd,
        border: Border(
          left: BorderSide(color: severityColor, width: 3),
          top: BorderSide(color: _alarmDivider),
          right: BorderSide(color: _alarmDivider),
          bottom: BorderSide(color: _alarmDivider),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                _StatusDot(color: severityColor, pulsing: isPending),
                const SizedBox(width: 8),
                Text(
                  alarm.shortId,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _alarmTitle,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 10),
                _statusBadge(alarm.status),
                const Spacer(),
                Text(
                  alarm.triggerType,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _alarmBody,
                  ),
                ),
                const Spacer(),
                Text(
                  alarm.triggeredLabel,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _alarmMuted,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: _alarmDivider),

          // ── Site + Client ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(child: _dataCell('SITE', alarm.humanSiteId)),
                const SizedBox(width: 16),
                Expanded(child: _dataCell('CLIENT', alarm.humanClientId)),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── AI Call Status panel ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: _buildCallStatusPanel(alarm),
          ),

          const SizedBox(height: 12),

          // ── Dispatch section (pending only) ───────────────────────────────
          if (isPending)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildDispatchSection(alarm, isBusy),
            )
          else
            const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildCallStatusPanel(_AlarmRecord alarm) {
    final callStatus = _callStatusLabel(alarm.status);
    final callColor = _callStatusColor(alarm.status);
    final lastAttemptLabel = alarm.triageTime != null
        ? () {
            final t = alarm.triageTime!.toLocal();
            final h = t.hour.toString().padLeft(2, '0');
            final m = t.minute.toString().padLeft(2, '0');
            return 'Last attempt: $h:$m';
          }()
        : 'No attempt yet';
    final hasResponse = alarm.fieldReport != null &&
        alarm.fieldReport!.trim().isNotEmpty;
    final transcript = alarm.controllerNotes?.trim();
    final hasTranscript = transcript != null && transcript.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _alarmBg,
        borderRadius: OnyxRadiusTokens.radiusSm,
        border: Border.all(color: callColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: icon + label + attempts count
          Row(
            children: [
              Icon(Icons.phone_rounded, color: callColor, size: 18),
              const SizedBox(width: 8),
              Text(
                'AI CALL STATUS',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _alarmMuted,
                  letterSpacing: 0.7,
                ),
              ),
              const Spacer(),
              Text(
                'ATTEMPTS',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _alarmMuted,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${alarm.callAttempts}',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: callColor,
                  height: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Last attempt time
          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 14,
                color: _alarmMuted,
              ),
              const SizedBox(width: 4),
              Text(
                lastAttemptLabel,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _alarmBody,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Call status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: callColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: callColor.withValues(alpha: 0.25)),
            ),
            child: Text(
              callStatus,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: callColor,
              ),
            ),
          ),
          // Client response + transcript (when available)
          if (hasResponse) ...[
            const SizedBox(height: 8),
            _clientResponseBadge(alarm.fieldReport!),
          ],
          if (hasTranscript) ...[
            const SizedBox(height: 6),
            Text(
              '"$transcript"',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: _alarmBody,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 8),
          // Next action
          Text(
            'NEXT ACTION',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _alarmMuted,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _nextAction(alarm.status),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _alarmBody,
            ),
          ),
        ],
      ),
    );
  }

  Widget _clientResponseBadge(String response) {
    final isEmergency = response.toLowerCase().contains('real') ||
        response.toLowerCase().contains('emergency') ||
        response.toLowerCase().contains('confirmed');
    final color = isEmergency
        ? OnyxDesignTokens.redCritical
        : OnyxDesignTokens.greenNominal;
    final bg = isEmergency
        ? OnyxColorTokens.redSurface
        : OnyxColorTokens.greenSurface;
    final border = isEmergency
        ? OnyxColorTokens.redBorder
        : OnyxColorTokens.greenBorder;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        response.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildDispatchSection(_AlarmRecord alarm, bool isBusy) {
    final selectedOfficer = _selectedOfficers[alarm.id];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Officer dropdown
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: _alarmBg,
            borderRadius: OnyxRadiusTokens.radiusSm,
            border: Border.all(color: _alarmBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedOfficer,
              isExpanded: true,
              dropdownColor: OnyxColorTokens.backgroundSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              hint: Text(
                'Choose officer to dispatch…',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: _alarmMuted,
                ),
              ),
              style: GoogleFonts.inter(
                fontSize: 13,
                color: _alarmTitle,
                fontWeight: FontWeight.w500,
              ),
              items: _officers
                  .map(
                    (o) => DropdownMenuItem(
                      value: o,
                      child: Text(o),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (v) => setState(() => _selectedOfficers[alarm.id] = v),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Action buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isBusy || selectedOfficer == null
                    ? null
                    : () => _dispatchNow(alarm.id, selectedOfficer),
                icon: isBusy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: OnyxColorTokens.textPrimary,
                        ),
                      )
                    : const Icon(Icons.warning_amber_rounded, size: 16),
                label: const Text('DISPATCH NOW'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: OnyxDesignTokens.redCritical,
                  foregroundColor: OnyxColorTokens.textPrimary,
                  disabledBackgroundColor:
                      OnyxColorTokens.redSurface,
                  disabledForegroundColor: OnyxDesignTokens.textMuted,
                  minimumSize: const Size(0, 44),
                  textStyle: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: OnyxRadiusTokens.radiusSm,
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: isBusy ? null : () {},
              icon: const Icon(Icons.phone_rounded, size: 15),
              label: const Text('CALL CLIENT'),
              style: OutlinedButton.styleFrom(
                foregroundColor: OnyxDesignTokens.cyanInteractive,
                minimumSize: const Size(0, 44),
                side: const BorderSide(color: OnyxColorTokens.cyanBorder),
                textStyle: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: OnyxRadiusTokens.radiusSm,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: isBusy ? null : () => _markFalseAlarm(alarm.id),
              style: OutlinedButton.styleFrom(
                foregroundColor: _alarmBody,
                minimumSize: const Size(0, 44),
                side: BorderSide(color: _alarmDivider),
                textStyle: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: OnyxRadiusTokens.radiusSm,
                ),
              ),
              child: const Text('FALSE ALARM'),
            ),
          ],
        ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _dataCell(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: _alarmMuted,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value.isEmpty ? '—' : value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _alarmTitle,
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(_AlarmStatus status) {
    final (label, fg, bg, border) = switch (status) {
      _AlarmStatus.detected => (
        'DETECTED',
        OnyxDesignTokens.amberWarning,
        OnyxColorTokens.amberSurface,
        OnyxColorTokens.amberBorder,
      ),
      _AlarmStatus.verified => (
        'VERIFIED',
        OnyxDesignTokens.amberWarning,
        OnyxColorTokens.amberSurface,
        OnyxColorTokens.amberBorder,
      ),
      _AlarmStatus.dispatched => (
        'DISPATCHED',
        OnyxDesignTokens.accentTeal,
        OnyxColorTokens.greenSurface,
        OnyxColorTokens.greenBorder,
      ),
      _AlarmStatus.onSite => (
        'ON SITE',
        OnyxDesignTokens.accentTeal,
        OnyxColorTokens.greenSurface,
        OnyxColorTokens.greenBorder,
      ),
      _AlarmStatus.secured => (
        'SECURED',
        OnyxDesignTokens.textMuted,
        OnyxDesignTokens.surfaceInset,
        OnyxDesignTokens.borderSubtle,
      ),
      _AlarmStatus.closed => (
        'CLOSED',
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

  Color _severityColor(_AlarmPriority priority) => switch (priority) {
    _AlarmPriority.p1 => OnyxDesignTokens.redCritical,
    _AlarmPriority.p2 => OnyxDesignTokens.amberWarning,
    _AlarmPriority.p3 => OnyxDesignTokens.cyanInteractive,
    _AlarmPriority.p4 => OnyxDesignTokens.textMuted,
  };

  Color _callStatusColor(_AlarmStatus status) => switch (status) {
    _AlarmStatus.detected => OnyxDesignTokens.amberWarning,
    _AlarmStatus.verified => OnyxDesignTokens.cyanInteractive,
    _AlarmStatus.dispatched || _AlarmStatus.onSite => OnyxDesignTokens.greenNominal,
    _ => OnyxDesignTokens.textMuted,
  };

  String _callStatusLabel(_AlarmStatus status) => switch (status) {
    _AlarmStatus.detected => 'CALLING',
    _AlarmStatus.verified => 'COMPLETED',
    _AlarmStatus.dispatched || _AlarmStatus.onSite => 'COMPLETED',
    _ => 'CLOSED',
  };

  String _nextAction(_AlarmStatus status) => switch (status) {
    _AlarmStatus.detected =>
      'Awaiting client verification. Select an officer and dispatch if confirmed real.',
    _AlarmStatus.verified =>
      'Client verified. Dispatch armed response now.',
    _AlarmStatus.dispatched =>
      'Response unit en route. Monitor ETA and maintain comms.',
    _AlarmStatus.onSite =>
      'Unit on site. Await all-clear or escalation signal.',
    _ =>
      'Alarm resolved. No further action required.',
  };
}

// ── Status dot with optional pulse animation ──────────────────────────────

class _StatusDot extends StatefulWidget {
  final Color color;
  final bool pulsing;

  const _StatusDot({required this.color, this.pulsing = false});

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.pulsing) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulsing && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.pulsing && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.pulsing) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
        ),
      );
    }
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.5),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    );
  }
}

class _MonitoringHeartbeat extends StatefulWidget {
  const _MonitoringHeartbeat();

  @override
  State<_MonitoringHeartbeat> createState() => _MonitoringHeartbeatState();
}

class _MonitoringHeartbeatState extends State<_MonitoringHeartbeat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 1.0, end: 0.40).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: _opacity,
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: OnyxColorTokens.accentGreen,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'LIVE MONITORING ACTIVE',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: OnyxColorTokens.textDisabled,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}
