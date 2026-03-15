import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../domain/events/decision_created.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/execution_completed.dart';
import '../domain/events/execution_denied.dart';
import '../domain/events/guard_checked_in.dart';
import '../domain/events/incident_closed.dart';
import '../domain/events/intelligence_received.dart';
import '../domain/events/patrol_completed.dart';
import '../domain/events/response_arrived.dart';
import '../application/monitoring_scene_review_store.dart';
import 'onyx_surface.dart';
import 'ui_action_logger.dart';

class EventsReviewPage extends StatefulWidget {
  final List<DispatchEvent> events;
  final Map<String, MonitoringSceneReviewRecord> sceneReviewByIntelligenceId;
  final String? initialSourceFilter;
  final String? initialProviderFilter;
  final String? initialSelectedEventId;

  const EventsReviewPage({
    super.key,
    required this.events,
    this.sceneReviewByIntelligenceId = const {},
    this.initialSourceFilter,
    this.initialProviderFilter,
    this.initialSelectedEventId,
  });

  @override
  State<EventsReviewPage> createState() => _EventsReviewPageState();
}

class _SeededDispatchEvent extends DispatchEvent {
  final String summary;
  final String clientId;
  final String regionId;
  final String siteId;

  const _SeededDispatchEvent({
    required super.eventId,
    required super.sequence,
    required super.version,
    required super.occurredAt,
    required this.summary,
    required this.clientId,
    required this.regionId,
    required this.siteId,
  });

  @override
  DispatchEvent copyWithSequence(int sequence) {
    return _SeededDispatchEvent(
      eventId: eventId,
      sequence: sequence,
      version: version,
      occurredAt: occurredAt,
      summary: summary,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
    );
  }
}

class _EventsReviewPageState extends State<EventsReviewPage> {
  static const String _filterAll = 'ALL';
  static const String _sourceFilterAll = 'ALL SOURCES';
  static const String _providerFilterAll = 'ALL PROVIDERS';
  static const String _identityPolicyFilterAll = 'ALL POLICIES';
  static const String _identityPolicyFilterFlagged = 'FLAGGED MATCH';
  static const String _identityPolicyFilterTemporary = 'TEMPORARY APPROVAL';
  static const String _identityPolicyFilterAllowlisted = 'ALLOWLISTED MATCH';
  static const List<String> _filterOptions = [
    'ALL',
    'INCIDENT CREATED',
    'DISPATCH SENT',
    'AI DECISION',
    'ALARM TRIGGERED',
  ];

  String _activeFilter = _filterAll;
  String _activeSourceFilter = _sourceFilterAll;
  String _activeProviderFilter = _providerFilterAll;
  String _activeIdentityPolicyFilter = _identityPolicyFilterAll;
  String _lastActionFeedback = '';
  DispatchEvent? _selectedEvent;
  final Map<String, GlobalKey> _rowKeys = <String, GlobalKey>{};
  String _lastAutoEnsuredEventId = '';

  @override
  void initState() {
    super.initState();
    _activeSourceFilter = _normalizeSourceFilter(widget.initialSourceFilter);
    _activeProviderFilter = _normalizeProviderFilter(
      widget.initialProviderFilter,
    );
  }

  @override
  void didUpdateWidget(covariant EventsReviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sourceChanged =
        oldWidget.initialSourceFilter != widget.initialSourceFilter;
    final providerChanged =
        oldWidget.initialProviderFilter != widget.initialProviderFilter;
    final selectedChanged =
        oldWidget.initialSelectedEventId != widget.initialSelectedEventId;
    if (sourceChanged || providerChanged || selectedChanged) {
      final normalizedSource = _normalizeSourceFilter(
        widget.initialSourceFilter,
      );
      final normalizedProvider = _normalizeProviderFilter(
        widget.initialProviderFilter,
      );
      if (normalizedSource != _activeSourceFilter ||
          normalizedProvider != _activeProviderFilter) {
        setState(() {
          _activeSourceFilter = normalizedSource;
          _activeProviderFilter = normalizedProvider;
        });
      }
      if (selectedChanged &&
          (widget.initialSelectedEventId ?? '').trim().isNotEmpty) {
        _lastAutoEnsuredEventId = '';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestedSelectedId = (widget.initialSelectedEventId ?? '').trim();
    final hasFocusedFallback =
        requestedSelectedId.isNotEmpty &&
        !widget.events.any((event) => event.eventId == requestedSelectedId);
    final timelineSource = _timelineWithFocusedFallback(
      baseEvents: widget.events,
      focusedEventId: requestedSelectedId,
    );
    final timeline = [...timelineSource]
      ..sort((a, b) => b.sequence.compareTo(a.sequence));
    final filteredByType = _activeFilter == _filterAll
        ? timeline
        : timeline
              .where((event) => _eventTypeLabel(event) == _activeFilter)
              .toList(growable: false);
    final filtered = _activeSourceFilter == _sourceFilterAll
        ? filteredByType
        : filteredByType
              .where((event) {
                if (event is! IntelligenceReceived) return false;
                return _normalizeSourceFilter(event.sourceType) ==
                    _activeSourceFilter;
              })
              .toList(growable: false);
    final providerFiltered = _activeProviderFilter == _providerFilterAll
        ? filtered
        : filtered
              .where((event) {
                if (event is! IntelligenceReceived) return false;
                return _normalizeProviderFilter(event.provider) ==
                    _activeProviderFilter;
              })
              .toList(growable: false);
    final identityPolicyOptions = _identityPolicyFilterOptions(
      providerFiltered,
    );
    final identityPolicyFiltered =
        _activeIdentityPolicyFilter == _identityPolicyFilterAll
        ? providerFiltered
        : providerFiltered
              .where((event) {
                if (event is! IntelligenceReceived) return false;
                return _eventIdentityPolicyFilterLabel(event) ==
                    _activeIdentityPolicyFilter;
              })
              .toList(growable: false);
    DispatchEvent? requestedSelectedEvent;
    if (requestedSelectedId.isNotEmpty) {
      for (final event in identityPolicyFiltered) {
        if (event.eventId == requestedSelectedId) {
          requestedSelectedEvent = event;
          break;
        }
      }
    }
    final requestedSelectionFound = requestedSelectedEvent != null;
    final requestedSelectionMissing =
        requestedSelectedId.isNotEmpty && !requestedSelectionFound;

    final selected = identityPolicyFiltered.isEmpty
        ? null
        : requestedSelectionFound
        ? requestedSelectedEvent
        : _selectedEvent != null
        ? identityPolicyFiltered.firstWhere(
            (event) => event.eventId == _selectedEvent!.eventId,
            orElse: () => identityPolicyFiltered.first,
          )
        : identityPolicyFiltered.first;
    _selectedEvent = selected;
    if (selected != null && requestedSelectionFound) {
      _scheduleEnsureVisible(selected.eventId);
    }

    final visibleEvents = identityPolicyFiltered.length;
    final totalEvents = timeline.length;
    final latestSequence = timeline.isEmpty
        ? 'N/A'
        : '#${timeline.first.sequence}';

    return OnyxPageScaffold(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1540),
            child: ListView(
              children: [
                Text(
                  'EVENT REVIEW',
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
                        : (maxWidth - 16) / 3;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _metricCard(
                          width: cardWidth,
                          label: 'VISIBLE EVENTS',
                          value: '$visibleEvents',
                          icon: Icons.monitor_heart_outlined,
                        ),
                        _metricCard(
                          width: cardWidth,
                          label: 'TOTAL EVENTS',
                          value: _withCommas(totalEvents),
                          icon: Icons.tag_rounded,
                        ),
                        _metricCard(
                          width: cardWidth,
                          label: 'LATEST SEQUENCE',
                          value: latestSequence,
                          icon: Icons.chevron_right_rounded,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                _filterStrip(identityPolicyOptions),
                if (hasFocusedFallback) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x223C79BB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x665FAAFF)),
                    ),
                    child: Text(
                      'Seeded placeholder loaded for $requestedSelectedId. This row will be replaced automatically once live ingest publishes the same event ID.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFEAF1FB),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                if (requestedSelectionMissing) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x221F3A5A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x6635506F)),
                    ),
                    child: Text(
                      'Focused reference $requestedSelectedId is not in the current event stream yet. Keep this tab open and ingest/poll to auto-link when it arrives.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFEAF1FB),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 1240;
                    if (stacked) {
                      return Column(
                        children: [
                          _timelinePane(
                            events: identityPolicyFiltered,
                            bounded: false,
                          ),
                          const SizedBox(height: 8),
                          _detailPane(selected: selected, bounded: false),
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
                            child: _timelinePane(
                              events: identityPolicyFiltered,
                              bounded: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 6,
                            child: _detailPane(
                              selected: selected,
                              bounded: true,
                            ),
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

  List<DispatchEvent> _timelineWithFocusedFallback({
    required List<DispatchEvent> baseEvents,
    required String focusedEventId,
  }) {
    if (focusedEventId.trim().isEmpty ||
        baseEvents.any((event) => event.eventId == focusedEventId)) {
      return baseEvents;
    }
    var maxSequence = 0;
    for (final event in baseEvents) {
      if (event.sequence > maxSequence) {
        maxSequence = event.sequence;
      }
    }
    return [
      _SeededDispatchEvent(
        eventId: focusedEventId,
        sequence: maxSequence + 1,
        version: 2,
        occurredAt: DateTime.now().toUtc(),
        summary: 'Seeded demo incident reference awaiting live ingest.',
        clientId: 'DEMO-CLT',
        regionId: 'REGION-GAUTENG',
        siteId: 'DEMO-SITE',
      ),
      ...baseEvents,
    ];
  }

  Widget _metricCard({
    required double width,
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
                    color: const Color(0xFFEAF1FB),
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
            child: Icon(icon, color: const Color(0xFF22D3EE), size: 18),
          ),
        ],
      ),
    );
  }

  Widget _filterStrip(List<String> identityPolicyOptions) {
    final sourceOptions = _sourceFilterOptions();
    final providerOptions = _providerFilterOptions();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0E141C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2B3A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.filter_alt_outlined,
                color: Color(0xFF7D93B1),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'FORENSIC FILTERS:',
                style: GoogleFonts.inter(
                  color: const Color(0xFF7D93B1),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => setState(() {
                  _activeFilter = _filterAll;
                  _activeSourceFilter = _sourceFilterAll;
                  _activeProviderFilter = _providerFilterAll;
                  _activeIdentityPolicyFilter = _identityPolicyFilterAll;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111822),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF2A374A)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.replay_rounded,
                        color: Color(0xFF9BB0CE),
                        size: 13,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'RESET',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF9BB0CE),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in _filterOptions)
                _filterChip(
                  label: option,
                  selected: _activeFilter == option,
                  onTap: () => setState(() => _activeFilter = option),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final source in sourceOptions)
                _filterChip(
                  label: source,
                  selected: _activeSourceFilter == source,
                  onTap: () => setState(() {
                    _activeSourceFilter = source;
                    _activeProviderFilter = _providerFilterAll;
                  }),
                ),
            ],
          ),
          if (providerOptions.length > 1 ||
              _activeProviderFilter != _providerFilterAll) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final provider in providerOptions)
                  _filterChip(
                    label: provider,
                    selected:
                        _activeProviderFilter ==
                        _normalizeProviderFilter(provider),
                    onTap: () => setState(
                      () => _activeProviderFilter = _normalizeProviderFilter(
                        provider,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (identityPolicyOptions.length > 1 ||
              _activeIdentityPolicyFilter != _identityPolicyFilterAll) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final policy in identityPolicyOptions)
                  _filterChip(
                    label: policy,
                    selected: _activeIdentityPolicyFilter == policy,
                    onTap: () =>
                        setState(() => _activeIdentityPolicyFilter = policy),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _timelinePane({
    required List<DispatchEvent> events,
    required bool bounded,
  }) {
    final list = Column(
      children: [
        for (var i = 0; i < events.length; i++) ...[
          _timelineRow(
            event: events[i],
            selected: _selectedEvent?.eventId == events[i].eventId,
            showConnector: i < events.length - 1,
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
      child: events.isEmpty
          ? const OnyxEmptyState(label: 'No events match the current filters.')
          : bounded
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: list,
            )
          : Padding(padding: const EdgeInsets.all(10), child: list),
    );
  }

  Widget _timelineRow({
    required DispatchEvent event,
    required bool selected,
    required bool showConnector,
  }) {
    final typeColor = _eventColor(event);
    return InkWell(
      onTap: () => setState(() => _selectedEvent = event),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        key: _rowKeyForEvent(event.eventId),
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
              width: 38,
              child: Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFF293340),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${event.sequence}',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFD9E7FA),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (showConnector)
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      width: 1,
                      height: 26,
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
                        child: Text(
                          '${_eventTypeLabel(event)}  •  ${event.eventId}',
                          style: GoogleFonts.inter(
                            color: typeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        _clock12(event.occurredAt),
                        style: GoogleFonts.inter(
                          color: const Color(0x808EA4C2),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _eventSummary(event),
                    style: GoogleFonts.inter(
                      color: const Color(0xFFEAF1FB),
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _eventMetaLine(event),
                    style: GoogleFonts.inter(
                      color: const Color(0xFF9BB0CE),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
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

  Widget _detailPane({
    required DispatchEvent? selected,
    required bool bounded,
  }) {
    final content = selected == null
        ? const OnyxEmptyState(label: 'Select an event to view details.')
        : _detailBody(selected);

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

  Widget _detailBody(DispatchEvent selected) {
    final sceneReview = selected is IntelligenceReceived
        ? widget.sceneReviewByIntelligenceId[selected.intelligenceId.trim()]
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EVENT DETAIL',
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
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EVENT ID',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF8EA4C2),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selected.eventId,
                          key: const ValueKey('events-selected-event-id'),
                          style: GoogleFonts.inter(
                            color: const Color(0xFFEAF1FB),
                            fontSize: 37,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 24,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0x1A10B981),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0x6610B981)),
                    ),
                  ),
                ],
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
                      'TIMESTAMP',
                      _fullTimestamp(selected.occurredAt),
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
              Text(
                'CONTEXT',
                style: GoogleFonts.inter(
                  color: const Color(0xFF9BB0CE),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 8),
              _contextRow('Site', _eventSiteId(selected)),
              if (selected is IntelligenceReceived) ...[
                _contextRow('Provider', selected.provider),
                _contextRow('Source', selected.sourceType),
                if ((selected.cameraId ?? '').trim().isNotEmpty)
                  _contextRow('Camera', selected.cameraId!.trim()),
                if ((selected.zone ?? '').trim().isNotEmpty)
                  _contextRow('Zone', selected.zone!.trim()),
                if ((selected.objectLabel ?? '').trim().isNotEmpty)
                  _contextRow(
                    'Detection',
                    _eventSignalLabel(
                      selected.objectLabel,
                      selected.objectConfidence,
                    ),
                  ),
                if ((selected.faceMatchId ?? '').trim().isNotEmpty)
                  _contextRow(
                    'Face Match',
                    _eventSignalLabel(
                      selected.faceMatchId,
                      selected.faceConfidence,
                    ),
                  ),
                if ((selected.plateNumber ?? '').trim().isNotEmpty)
                  _contextRow(
                    'Plate Match',
                    _eventSignalLabel(
                      selected.plateNumber,
                      selected.plateConfidence,
                    ),
                  ),
              ],
              if (_guardLabel(selected).isNotEmpty)
                _contextRow('Guard', _guardLabel(selected)),
              _contextRow('Summary', _eventSummary(selected)),
            ],
          ),
        ),
        if (sceneReview != null) ...[
          const SizedBox(height: 8),
          _detailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SCENE REVIEW',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9BB0CE),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 8),
                _contextRow('Source', sceneReview.sourceLabel),
                _contextRow('Posture', sceneReview.postureLabel),
                if (_sceneReviewIdentityPolicy(sceneReview) != null)
                  _contextRow(
                    'Identity Policy',
                    _sceneReviewIdentityPolicy(sceneReview)!,
                  ),
                if (sceneReview.decisionLabel.trim().isNotEmpty)
                  _contextRow('Action', sceneReview.decisionLabel),
                _contextRow(
                  'Reviewed At',
                  _fullTimestamp(sceneReview.reviewedAtUtc),
                ),
                _contextRow('Summary', sceneReview.summary),
                if (sceneReview.decisionSummary.trim().isNotEmpty)
                  _contextRow('Decision Detail', sceneReview.decisionSummary),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        _detailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PAYLOAD DATA',
                style: GoogleFonts.inter(
                  color: const Color(0xFF9BB0CE),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0E14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF223244)),
                ),
                child: Text(
                  const JsonEncoder.withIndent(
                    '  ',
                  ).convert(_eventPayload(selected)),
                  style: GoogleFonts.robotoMono(
                    color: const Color(0xFFD9E7FA),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _detailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VERSION INFO',
                style: GoogleFonts.inter(
                  color: const Color(0xFF9BB0CE),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 8),
              _contextRow('Schema Version', 'v2.1.0'),
              _contextRow('Event Source', 'ONYX Core'),
              _contextRow(
                'Chain Position',
                'Verified',
                valueColor: const Color(0xFF10B981),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _outlineAction(
          'VIEW IN LEDGER',
          actionKey: const ValueKey('events-view-ledger-action'),
          onTap: () {
            logUiAction(
              'events.view_in_ledger',
              context: {'event_id': selected.eventId},
            );
            _showActionMessage(
              'Open Sovereign Ledger to inspect ${selected.eventId}.',
            );
          },
        ),
        const SizedBox(height: 6),
        _outlineAction(
          'EXPORT EVENT DATA',
          actionKey: const ValueKey('events-export-data-action'),
          onTap: () => _exportEventData(selected),
        ),
        const SizedBox(height: 6),
        Text(
          'Selected Event',
          style: GoogleFonts.inter(
            color: const Color(0x668EA4C2),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (_lastActionFeedback.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            _lastActionFeedback,
            key: const ValueKey('events-last-action-feedback'),
            style: GoogleFonts.inter(
              color: const Color(0xFF63BDFF),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
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

  Widget _kvMini(String label, String value) {
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
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            color: const Color(0xFFEAF1FB),
            fontSize: 30,
            height: 0.95,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _contextRow(String key, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              key,
              style: GoogleFonts.inter(
                color: const Color(0xFF9BB0CE),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                color: valueColor ?? const Color(0xFFEAF1FB),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _outlineAction(
    String text, {
    required VoidCallback onTap,
    Key? actionKey,
  }) {
    return InkWell(
      key: actionKey,
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
          text,
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

  void _exportEventData(DispatchEvent event) {
    final payloadJson = const JsonEncoder.withIndent(
      '  ',
    ).convert(_eventPayload(event));
    Clipboard.setData(ClipboardData(text: payloadJson));
    logUiAction(
      'events.export_event_data',
      context: {'event_id': event.eventId},
    );
    _showActionMessage('Event payload copied for ${event.eventId}.');
  }

  void _showActionMessage(String message) {
    if (mounted) {
      setState(() {
        _lastActionFeedback = message;
      });
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

  GlobalKey _rowKeyForEvent(String eventId) {
    return _rowKeys.putIfAbsent(
      eventId,
      () => GlobalKey(debugLabel: 'event-row-$eventId'),
    );
  }

  void _scheduleEnsureVisible(String eventId) {
    if (_lastAutoEnsuredEventId == eventId) {
      return;
    }
    _lastAutoEnsuredEventId = eventId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = _rowKeys[eventId];
      final context = key?.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: 0.16,
      );
    });
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0x1A22D3EE) : const Color(0xFF111822),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? const Color(0x803EA2FF) : const Color(0xFF2A374A),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: selected ? const Color(0xFF22D3EE) : const Color(0xFF9BB0CE),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  List<String> _sourceFilterOptions() {
    final sources = widget.events
        .whereType<IntelligenceReceived>()
        .map((event) => _normalizeSourceFilter(event.sourceType))
        .where((source) => source != _sourceFilterAll)
        .toSet();
    final ordered = <String>[_sourceFilterAll];
    const preferred = <String>[
      'NEWS',
      'HARDWARE',
      'DVR',
      'RADIO',
      'WEARABLE',
      'COMMUNITY',
      'SYSTEM',
    ];
    for (final source in preferred) {
      if (sources.remove(source)) {
        ordered.add(source);
      }
    }
    final remaining = sources.toList()..sort();
    ordered.addAll(remaining);
    return ordered;
  }

  List<String> _providerFilterOptions() {
    final providersByKey = <String, String>{};
    for (final event in widget.events.whereType<IntelligenceReceived>()) {
      final source = _normalizeSourceFilter(event.sourceType);
      if (_activeSourceFilter != _sourceFilterAll &&
          source != _activeSourceFilter) {
        continue;
      }
      final provider = event.provider.trim();
      if (provider.isEmpty) continue;
      final key = _normalizeProviderFilter(provider);
      if (key == _providerFilterAll) continue;
      providersByKey.putIfAbsent(key, () => provider);
    }
    final orderedProviders = providersByKey.values.toList(growable: false)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return <String>[_providerFilterAll, ...orderedProviders];
  }

  List<String> _identityPolicyFilterOptions(List<DispatchEvent> events) {
    final policies =
        events
            .whereType<IntelligenceReceived>()
            .map(_eventIdentityPolicyFilterLabel)
            .whereType<String>()
            .where((policy) => policy != _identityPolicyFilterAll)
            .toSet()
            .toList(growable: false)
          ..sort();
    return <String>[_identityPolicyFilterAll, ...policies];
  }

  String _normalizeSourceFilter(String? sourceType) {
    final normalized = sourceType?.trim().toUpperCase() ?? '';
    if (normalized.isEmpty || normalized == 'ALL') {
      return _sourceFilterAll;
    }
    if (normalized == 'CCTV') {
      return 'HARDWARE';
    }
    if (normalized == 'DVR') {
      return 'DVR';
    }
    return normalized;
  }

  String _normalizeProviderFilter(String? provider) {
    final normalized = provider?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty || normalized == 'all') {
      return _providerFilterAll;
    }
    return normalized;
  }

  String? _eventIdentityPolicyFilterLabel(IntelligenceReceived event) {
    final review =
        widget.sceneReviewByIntelligenceId[event.intelligenceId.trim()];
    if (review == null) {
      return null;
    }
    final policy = _sceneReviewIdentityPolicy(review);
    if (policy == 'Flagged match') {
      return _identityPolicyFilterFlagged;
    }
    if (policy == 'Temporary approval') {
      return _identityPolicyFilterTemporary;
    }
    if (policy == 'Allowlisted match') {
      return _identityPolicyFilterAllowlisted;
    }
    return null;
  }
}

Map<String, dynamic> _eventPayload(DispatchEvent event) {
  return {
    'eventId': event.eventId,
    'sequence': event.sequence,
    'version': event.version,
    'type': _eventTypeLabel(event),
    'clientId': _eventClientId(event),
    'regionId': _eventRegionId(event),
    'siteId': _eventSiteId(event),
    'occurredAt': event.occurredAt.toUtc().toIso8601String(),
    'summary': _eventSummary(event),
    if (event is IntelligenceReceived) ...{
      'provider': event.provider,
      'sourceType': event.sourceType,
      'cameraId': event.cameraId,
      'zone': event.zone,
      'objectLabel': event.objectLabel,
      'objectConfidence': event.objectConfidence,
      'faceMatchId': event.faceMatchId,
      'faceConfidence': event.faceConfidence,
      'plateNumber': event.plateNumber,
      'plateConfidence': event.plateConfidence,
      'headline': event.headline,
      'detailSummary': event.summary,
    },
  };
}

String _eventSignalLabel(String? label, double? confidence) {
  final normalized = (label ?? '').trim();
  if (normalized.isEmpty) {
    return 'unknown';
  }
  final confidenceLabel = _eventConfidenceLabel(confidence);
  if (confidenceLabel == null) {
    return normalized;
  }
  return '$normalized • $confidenceLabel';
}

String? _eventConfidenceLabel(double? confidence) {
  if (confidence == null) {
    return null;
  }
  return '${confidence.toStringAsFixed(1)}%';
}

String? _sceneReviewIdentityPolicy(MonitoringSceneReviewRecord review) {
  final posture = review.postureLabel.trim().toLowerCase();
  final decisionSummary = review.decisionSummary.trim().toLowerCase();
  if (decisionSummary.contains('one-time approval') ||
      decisionSummary.contains('one time approval')) {
    return 'Temporary approval';
  }
  if (posture.contains('known allowed identity') ||
      decisionSummary.contains('allowlisted for this site')) {
    return 'Allowlisted match';
  }
  if (posture.contains('identity match concern') ||
      decisionSummary.contains('was flagged') ||
      decisionSummary.contains('watchlist context') ||
      decisionSummary.contains('unauthorized or watchlist context')) {
    return 'Flagged match';
  }
  return null;
}

String _eventTypeLabel(DispatchEvent event) {
  if (event is _SeededDispatchEvent) return 'INCIDENT CREATED';
  if (event is IntelligenceReceived) return 'AI DECISION';
  if (event is DecisionCreated) return 'INCIDENT CREATED';
  if (event is ResponseArrived) return 'OFFICER ARRIVED';
  if (event is GuardCheckedIn) return 'CHECKPOINT COMPLETED';
  if (event is ExecutionDenied) return 'ALARM TRIGGERED';
  if (event is ExecutionCompleted) return 'DISPATCH SENT';
  if (event is PatrolCompleted) return 'PATROL COMPLETED';
  if (event is IncidentClosed) return 'INCIDENT CLOSED';
  return event.runtimeType.toString().toUpperCase();
}

String _eventSummary(DispatchEvent event) {
  if (event is _SeededDispatchEvent) return event.summary;
  if (event is IntelligenceReceived) return event.headline;
  if (event is DecisionCreated) {
    return '${event.clientId}/${event.siteId} dispatch ${event.dispatchId} created';
  }
  if (event is ResponseArrived) {
    return '${event.guardId} arrived for ${event.dispatchId}';
  }
  if (event is GuardCheckedIn) {
    return '${event.guardId} checkpoint scan completed';
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
  return event.eventId;
}

String _eventMetaLine(DispatchEvent event) {
  final site = _eventSiteId(event);
  final guard = _guardLabel(event);
  if (guard.isEmpty) {
    return '◎ $site';
  }
  return '◎ $site  •  ♢ $guard';
}

Color _eventColor(DispatchEvent event) {
  if (event is _SeededDispatchEvent) return const Color(0xFF5FAAFF);
  if (event is DecisionCreated) return const Color(0xFFEF4444);
  if (event is ExecutionCompleted) return const Color(0xFF10B981);
  if (event is ResponseArrived) return const Color(0xFF22D3EE);
  if (event is GuardCheckedIn) return const Color(0xFF3B82F6);
  if (event is ExecutionDenied) return const Color(0xFFF59E0B);
  if (event is IntelligenceReceived) return const Color(0xFFC084FC);
  if (event is IncidentClosed) return const Color(0xFF10B981);
  return const Color(0xFF9BB0CE);
}

String _guardLabel(DispatchEvent event) {
  if (event is ResponseArrived) return event.guardId;
  if (event is GuardCheckedIn) return event.guardId;
  if (event is PatrolCompleted) return event.guardId;
  return '';
}

String _eventSiteId(DispatchEvent event) {
  if (event is _SeededDispatchEvent) return event.siteId;
  if (event is DecisionCreated) return event.siteId;
  if (event is ResponseArrived) return event.siteId;
  if (event is GuardCheckedIn) return event.siteId;
  if (event is ExecutionCompleted) return event.siteId;
  if (event is ExecutionDenied) return event.siteId;
  if (event is IntelligenceReceived) return event.siteId;
  if (event is PatrolCompleted) return event.siteId;
  if (event is IncidentClosed) return event.siteId;
  return 'SITE-UNKNOWN';
}

String _eventClientId(DispatchEvent event) {
  if (event is _SeededDispatchEvent) return event.clientId;
  if (event is DecisionCreated) return event.clientId;
  if (event is ResponseArrived) return event.clientId;
  if (event is GuardCheckedIn) return event.clientId;
  if (event is ExecutionCompleted) return event.clientId;
  if (event is ExecutionDenied) return event.clientId;
  if (event is IntelligenceReceived) return event.clientId;
  if (event is PatrolCompleted) return event.clientId;
  if (event is IncidentClosed) return event.clientId;
  return 'CLIENT-UNKNOWN';
}

String _eventRegionId(DispatchEvent event) {
  if (event is _SeededDispatchEvent) return event.regionId;
  if (event is DecisionCreated) return event.regionId;
  if (event is ResponseArrived) return event.regionId;
  if (event is GuardCheckedIn) return event.regionId;
  if (event is ExecutionCompleted) return event.regionId;
  if (event is ExecutionDenied) return event.regionId;
  if (event is IntelligenceReceived) return event.regionId;
  if (event is PatrolCompleted) return event.regionId;
  if (event is IncidentClosed) return event.regionId;
  return 'REGION-UNKNOWN';
}

String _clock12(DateTime value) {
  final local = value.toUtc();
  var hour = local.hour;
  final minute = local.minute.toString().padLeft(2, '0');
  final second = local.second.toString().padLeft(2, '0');
  final suffix = hour >= 12 ? 'PM' : 'AM';
  hour = hour % 12;
  if (hour == 0) hour = 12;
  return '$hour:$minute:$second $suffix';
}

String _fullTimestamp(DateTime value) {
  final local = value.toUtc();
  final month = local.month;
  final day = local.day;
  final year = local.year;
  return '$month/$day/$year, ${_clock12(local)}';
}

String _withCommas(int value) {
  final s = value.toString();
  if (s.length <= 3) return s;
  final chars = s.split('');
  final buffer = StringBuffer();
  for (var i = 0; i < chars.length; i++) {
    buffer.write(chars[i]);
    final remaining = chars.length - i - 1;
    if (remaining > 0 && remaining % 3 == 0) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}
