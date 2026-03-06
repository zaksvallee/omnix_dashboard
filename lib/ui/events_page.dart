import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../domain/events/decision_created.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/execution_completed.dart';
import '../domain/events/execution_denied.dart';
import '../domain/events/guard_checked_in.dart';
import '../domain/events/incident_closed.dart';
import '../domain/events/intelligence_received.dart';
import '../domain/events/patrol_completed.dart';
import '../domain/events/report_generated.dart';
import '../domain/events/response_arrived.dart';
import 'onyx_surface.dart';

class EventsPage extends StatefulWidget {
  final List<DispatchEvent> events;

  const EventsPage({super.key, required this.events});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  static const int _maxTimelineRows = 50;
  static const int _maxDetailRows = 24;
  static const double _spaceXs = 6;
  static const double _spaceSm = 8;
  static const double _spaceMd = 10;
  String _typeFilter = _allValue;
  String _siteFilter = _allValue;
  String _guardFilter = _allValue;
  _TimeWindow _timeWindow = _TimeWindow.last24h;
  bool _showAdvancedFilters = false;
  DispatchEvent? _selected;

  static const _allValue = 'ALL';

  @override
  Widget build(BuildContext context) {
    final timeline = [...widget.events]
      ..sort((a, b) => b.sequence.compareTo(a.sequence));
    final forensicRows = timeline.map(_toForensicRow).toList();

    final allTypes = _distinctValues(forensicRows.map((r) => r.info.label));
    final allSites = _distinctValues(forensicRows.map((r) => r.siteId));
    final allGuards = _distinctValues(forensicRows.map((r) => r.guardId));

    final filtered = forensicRows.where(_matchesFilters).toList();
    final visibleRows = filtered.take(_maxTimelineRows).toList(growable: false);
    final hiddenRows = filtered.length - visibleRows.length;
    final selected = visibleRows.isEmpty
        ? null
        : _selected != null
        ? visibleRows.firstWhere(
            (r) => r.event.eventId == _selected!.eventId,
            orElse: () => visibleRows.first,
          )
        : visibleRows.first;

    if (selected != null && _selected?.eventId != selected.event.eventId) {
      _selected = selected.event;
    } else if (selected == null && _selected != null) {
      _selected = null;
    }

    return Scaffold(
      endDrawer: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 1120 || selected == null) {
            return const SizedBox.shrink();
          }
          return Drawer(
            width: 320,
            backgroundColor: const Color(0xFF081426),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: _selectedDetailPane(selected),
              ),
            ),
          );
        },
      ),
      body: OnyxPageScaffold(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1540),
              child: LayoutBuilder(
                builder: (context, viewport) {
                  final useScrollFallback = viewport.maxHeight < 720;

                  Widget timelinePane({
                    required bool showSideDrawer,
                    required bool useExpandedList,
                  }) {
                    final timelineList = visibleRows.isEmpty
                        ? _emptyState()
                        : ListView.separated(
                            shrinkWrap: !useExpandedList,
                            primary: useExpandedList,
                            physics: useExpandedList
                                ? null
                                : const NeverScrollableScrollPhysics(),
                            itemCount: visibleRows.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: _spaceSm),
                            itemBuilder: (context, index) {
                              final row = visibleRows[index];
                              final event = row.event;
                              final info = row.info;
                              final isSelected =
                                  _selected?.eventId == event.eventId;

                              return InkWell(
                                onTap: () {
                                  setState(() => _selected = event);
                                  if (!showSideDrawer) {
                                    Scaffold.of(context).openEndDrawer();
                                  }
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: onyxForensicRowDecoration(
                                    isSelected: isSelected,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(top: 2),
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: info.color,
                                        ),
                                      ),
                                      const SizedBox(width: _spaceMd),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    info.label,
                                                    style: GoogleFonts.rajdhani(
                                                      color: info.color,
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  "UTC ${event.occurredAt.toIso8601String()}",
                                                  style: GoogleFonts.inter(
                                                    color: const Color(
                                                      0xFF89A0BE,
                                                    ),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  textAlign: TextAlign.end,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: [
                                                _pill("SEQ ${event.sequence}"),
                                                if (row.siteId != null)
                                                  _pill(row.siteId!),
                                                if (row.guardId != null)
                                                  _pill(row.guardId!),
                                                if (isSelected)
                                                  _pill(
                                                    "SELECTED",
                                                    color: const Color(
                                                      0xFF9FD9FF,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: _spaceXs),
                                            Text(
                                              info.summary,
                                              style: GoogleFonts.inter(
                                                color: const Color(0xFFE4EEFF),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                height: 1.35,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              "Event ID ${event.eventId}",
                                              style: GoogleFonts.inter(
                                                color: const Color(0xFF7289AA),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );

                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: onyxForensicSurfaceCardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 3,
                            decoration: BoxDecoration(
                              color: const Color(0xFF3C79BB),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(height: _spaceSm),
                          Text(
                            "Timeline Feed",
                            style: GoogleFonts.rajdhani(
                              color: const Color(0xFFE6F0FF),
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Newest first, with summary-first cards instead of raw dense rows • ${filtered.length} filtered.",
                            style: GoogleFonts.inter(
                              color: const Color(0xFF7E95B4),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: _spaceSm),
                          if (useExpandedList)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: timelineList),
                                  if (hiddenRows > 0) ...[
                                    const SizedBox(height: _spaceSm),
                                    OnyxTruncationHint(
                                      visibleCount: visibleRows.length,
                                      totalCount: filtered.length,
                                      subject: 'event rows',
                                      hiddenDescriptor: 'additional rows',
                                      color: const Color(0xFF8FA8CA),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                timelineList,
                                if (hiddenRows > 0) ...[
                                  const SizedBox(height: _spaceSm),
                                  OnyxTruncationHint(
                                    visibleCount: visibleRows.length,
                                    totalCount: filtered.length,
                                    subject: 'event rows',
                                    hiddenDescriptor: 'additional rows',
                                    color: const Color(0xFF8FA8CA),
                                  ),
                                ],
                              ],
                            ),
                        ],
                      ),
                    );
                  }

                  Widget mainLayout() {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final showSideDrawer = constraints.maxWidth >= 1120;
                        final sidePaneWidth = constraints.maxWidth >= 1480
                            ? 340.0
                            : 300.0;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: timelinePane(
                                showSideDrawer: showSideDrawer,
                                useExpandedList: !useScrollFallback,
                              ),
                            ),
                            if (showSideDrawer) ...[
                              const SizedBox(width: _spaceMd),
                              SizedBox(
                                width: sidePaneWidth,
                                child: selected == null
                                    ? _emptyDetailPane()
                                    : _selectedDetailPane(selected),
                              ),
                            ],
                          ],
                        );
                      },
                    );
                  }

                  if (useScrollFallback) {
                    return ListView(
                      children: [
                        const OnyxPageHeader(
                          title: 'Event Review',
                          subtitle:
                              'Readable forensic timeline with a calmer detail surface and faster filter triage.',
                        ),
                        const SizedBox(height: _spaceSm),
                        _summaryStrip(
                          totalCount: forensicRows.length,
                          filteredCount: filtered.length,
                          latestSequence: timeline.isEmpty
                              ? null
                              : timeline.first.sequence,
                        ),
                        const SizedBox(height: _spaceXs),
                        _filterBar(
                          allTypes: allTypes,
                          allSites: allSites,
                          allGuards: allGuards,
                          filteredCount: filtered.length,
                        ),
                        const SizedBox(height: _spaceXs),
                        mainLayout(),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const OnyxPageHeader(
                        title: 'Event Review',
                        subtitle:
                            'Readable forensic timeline with a calmer detail surface and faster filter triage.',
                      ),
                      const SizedBox(height: 8),
                      _summaryStrip(
                        totalCount: forensicRows.length,
                        filteredCount: filtered.length,
                        latestSequence: timeline.isEmpty
                            ? null
                            : timeline.first.sequence,
                      ),
                      const SizedBox(height: 6),
                      _filterBar(
                        allTypes: allTypes,
                        allSites: allSites,
                        allGuards: allGuards,
                        filteredCount: filtered.length,
                      ),
                      const SizedBox(height: 6),
                      Expanded(child: mainLayout()),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterBar({
    required List<String> allTypes,
    required List<String> allSites,
    required List<String> allGuards,
    required int filteredCount,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF081326), Color(0xFF0A172C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF193758)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFF3C79BB),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  "Forensic Filters",
                  style: GoogleFonts.rajdhani(
                    color: const Color(0xFFE6F0FF),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _pill("$filteredCount visible"),
              const SizedBox(width: 8),
              _pill("${_activeFilterCount()} active"),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _typeFilter = _allValue;
                    _siteFilter = _allValue;
                    _guardFilter = _allValue;
                    _timeWindow = _TimeWindow.last24h;
                  });
                },
                child: Text(
                  "Reset Filters",
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9FD9FF),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: _showAdvancedFilters,
              onExpansionChanged: (expanded) {
                setState(() => _showAdvancedFilters = expanded);
              },
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              iconColor: const Color(0xFF8FD1FF),
              collapsedIconColor: const Color(0xFF7EA5CB),
              title: Text(
                "Advanced Filters",
                style: GoogleFonts.inter(
                  color: const Color(0xFF8FD1FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              children: [
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _dropdown(
                      label: "Type",
                      value: _typeFilter,
                      options: [_allValue, ...allTypes],
                      onChanged: (v) => setState(() => _typeFilter = v),
                    ),
                    _dropdown(
                      label: "Site",
                      value: _siteFilter,
                      options: [_allValue, ...allSites],
                      onChanged: (v) => setState(() => _siteFilter = v),
                    ),
                    _dropdown(
                      label: "Guard",
                      value: _guardFilter,
                      options: [_allValue, ...allGuards],
                      onChanged: (v) => setState(() => _guardFilter = v),
                    ),
                    _dropdown(
                      label: "Window",
                      value: _timeWindow.label,
                      options: _TimeWindow.values.map((v) => v.label).toList(),
                      onChanged: (v) {
                        setState(() {
                          _timeWindow = _TimeWindow.values.firstWhere(
                            (entry) => entry.label == v,
                          );
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 170, maxWidth: 260),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF8FA4C5),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0E1A33),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF263B64)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                dropdownColor: const Color(0xFF081326),
                style: GoogleFonts.inter(
                  color: const Color(0xFFE5EFFF),
                  fontSize: 12,
                ),
                items: options
                    .map(
                      (option) => DropdownMenuItem<String>(
                        value: option,
                        child: Text(option),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailDrawer(_ForensicRow row) {
    final details = _detailsFor(row.event);
    final visibleDetails = details.take(_maxDetailRows).toList(growable: false);
    final hiddenDetails = details.length - visibleDetails.length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF081426),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF18345F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Selected Event",
            style: GoogleFonts.rajdhani(
              color: const Color(0xFFE8F1FF),
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Focused detail view with a cleaner field stack and grouped metadata.",
            style: GoogleFonts.inter(
              color: const Color(0xFF7D93B1),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _detailHero(row),
          const SizedBox(height: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ListView.separated(
                    itemCount: visibleDetails.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = visibleDetails[index];
                      return _kv(item.$1, item.$2);
                    },
                  ),
                ),
                if (hiddenDetails > 0) ...[
                  const SizedBox(height: 8),
                  OnyxTruncationHint(
                    visibleCount: visibleDetails.length,
                    totalCount: details.length,
                    subject: 'detail rows',
                    color: const Color(0xFF8EA5C6),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1930),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1A355A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            key,
            style: GoogleFonts.inter(
              color: const Color(0xFF8EA5C6),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.inter(
              color: const Color(0xFFE6F0FF),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF081426),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF18345F)),
      ),
      child: Center(
        child: Text(
          "No events match current forensic filters.",
          style: GoogleFonts.inter(
            color: const Color(0xFF9DB1CF),
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  bool _matchesFilters(_ForensicRow row) {
    if (_typeFilter != _allValue && row.info.label != _typeFilter) {
      return false;
    }
    if (_siteFilter != _allValue && row.siteId != _siteFilter) {
      return false;
    }
    if (_guardFilter != _allValue && row.guardId != _guardFilter) {
      return false;
    }

    final threshold = _timeWindow.threshold(DateTime.now().toUtc());
    if (threshold != null && row.event.occurredAt.isBefore(threshold)) {
      return false;
    }

    return true;
  }

  _ForensicRow _toForensicRow(DispatchEvent event) {
    final info = _describe(event);

    String? siteId;
    String? guardId;

    if (event is DecisionCreated) {
      siteId = event.siteId;
    } else if (event is ExecutionCompleted) {
      siteId = event.siteId;
    } else if (event is ExecutionDenied) {
      siteId = event.siteId;
    } else if (event is GuardCheckedIn) {
      siteId = event.siteId;
      guardId = event.guardId;
    } else if (event is PatrolCompleted) {
      siteId = event.siteId;
      guardId = event.guardId;
    } else if (event is ResponseArrived) {
      siteId = event.siteId;
      guardId = event.guardId;
    } else if (event is IncidentClosed) {
      siteId = event.siteId;
    } else if (event is ReportGenerated) {
      siteId = event.siteId;
    } else if (event is IntelligenceReceived) {
      siteId = event.siteId;
    }

    return _ForensicRow(
      event: event,
      info: info,
      siteId: siteId,
      guardId: guardId,
    );
  }

  List<String> _distinctValues(Iterable<String?> values) {
    return values.whereType<String>().toSet().toList()
      ..sort((a, b) => a.compareTo(b));
  }

  List<(String, String)> _detailsFor(DispatchEvent event) {
    final base = <(String, String)>[
      ("eventId", event.eventId),
      ("sequence", event.sequence.toString()),
      ("version", event.version.toString()),
      ("occurredAtUtc", event.occurredAt.toIso8601String()),
    ];

    if (event is DecisionCreated) {
      return [
        ...base,
        ("eventType", "DecisionCreated"),
        ("dispatchId", event.dispatchId),
        ("clientId", event.clientId),
        ("regionId", event.regionId),
        ("siteId", event.siteId),
      ];
    }
    if (event is ExecutionCompleted) {
      return [
        ...base,
        ("eventType", "ExecutionCompleted"),
        ("dispatchId", event.dispatchId),
        ("clientId", event.clientId),
        ("regionId", event.regionId),
        ("siteId", event.siteId),
        ("success", event.success.toString()),
      ];
    }
    if (event is ExecutionDenied) {
      return [
        ...base,
        ("eventType", "ExecutionDenied"),
        ("dispatchId", event.dispatchId),
        ("clientId", event.clientId),
        ("regionId", event.regionId),
        ("siteId", event.siteId),
        ("operatorId", event.operatorId),
        ("reason", event.reason),
      ];
    }
    if (event is GuardCheckedIn) {
      return [
        ...base,
        ("eventType", "GuardCheckedIn"),
        ("guardId", event.guardId),
        ("clientId", event.clientId),
        ("regionId", event.regionId),
        ("siteId", event.siteId),
      ];
    }
    if (event is PatrolCompleted) {
      return [
        ...base,
        ("eventType", "PatrolCompleted"),
        ("guardId", event.guardId),
        ("routeId", event.routeId),
        ("clientId", event.clientId),
        ("regionId", event.regionId),
        ("siteId", event.siteId),
        ("durationSeconds", event.durationSeconds.toString()),
      ];
    }
    if (event is ResponseArrived) {
      return [
        ...base,
        ("eventType", "ResponseArrived"),
        ("dispatchId", event.dispatchId),
        ("guardId", event.guardId),
        ("clientId", event.clientId),
        ("regionId", event.regionId),
        ("siteId", event.siteId),
      ];
    }
    if (event is IncidentClosed) {
      return [
        ...base,
        ("eventType", "IncidentClosed"),
        ("dispatchId", event.dispatchId),
        ("resolutionType", event.resolutionType),
        ("clientId", event.clientId),
        ("regionId", event.regionId),
        ("siteId", event.siteId),
      ];
    }
    if (event is ReportGenerated) {
      return [
        ...base,
        ("eventType", "ReportGenerated"),
        ("clientId", event.clientId),
        ("siteId", event.siteId),
        ("month", event.month),
        ("contentHash", event.contentHash),
        ("pdfHash", event.pdfHash),
        ("eventRangeStart", event.eventRangeStart.toString()),
        ("eventRangeEnd", event.eventRangeEnd.toString()),
        ("eventCount", event.eventCount.toString()),
        ("reportSchemaVersion", event.reportSchemaVersion.toString()),
        ("projectionVersion", event.projectionVersion.toString()),
      ];
    }
    if (event is IntelligenceReceived) {
      return [
        ...base,
        ("eventType", "IntelligenceReceived"),
        ("intelligenceId", event.intelligenceId),
        ("provider", event.provider),
        ("externalId", event.externalId),
        ("clientId", event.clientId),
        ("regionId", event.regionId),
        ("siteId", event.siteId),
        ("riskScore", event.riskScore.toString()),
        ("headline", event.headline),
        ("summary", event.summary),
        ("canonicalHash", event.canonicalHash),
      ];
    }

    return [...base, ("eventType", event.runtimeType.toString())];
  }

  _EventInfo _describe(DispatchEvent event) {
    if (event is DecisionCreated) {
      return _EventInfo(
        label: 'DECISION',
        color: const Color(0xFF6BC6FF),
        summary:
            '${event.clientId}/${event.siteId} dispatch ${event.dispatchId} created',
      );
    }
    if (event is ExecutionCompleted) {
      return _EventInfo(
        label: event.success ? 'EXECUTION' : 'FAILED EXECUTION',
        color: event.success
            ? const Color(0xFF4ED4A3)
            : const Color(0xFFFF6676),
        summary:
            '${event.clientId}/${event.siteId} dispatch ${event.dispatchId}',
      );
    }
    if (event is ExecutionDenied) {
      return _EventInfo(
        label: 'DENIED',
        color: const Color(0xFFFFB44D),
        summary:
            '${event.clientId}/${event.siteId} dispatch ${event.dispatchId} denied by ${event.operatorId}',
      );
    }
    if (event is GuardCheckedIn) {
      return _EventInfo(
        label: 'GUARD CHECK-IN',
        color: const Color(0xFF2FD6FF),
        summary:
            '${event.guardId} checked in at ${event.clientId}/${event.siteId}',
      );
    }
    if (event is PatrolCompleted) {
      return _EventInfo(
        label: 'PATROL COMPLETED',
        color: const Color(0xFF65E8CF),
        summary:
            '${event.guardId} completed ${event.routeId} in ${event.durationSeconds}s at ${event.siteId}',
      );
    }
    if (event is ResponseArrived) {
      return _EventInfo(
        label: 'RESPONSE ARRIVED',
        color: const Color(0xFF74D1FF),
        summary:
            '${event.guardId} arrived for ${event.dispatchId} at ${event.siteId}',
      );
    }
    if (event is IncidentClosed) {
      return _EventInfo(
        label: 'INCIDENT CLOSED',
        color: const Color(0xFF9FE06A),
        summary:
            '${event.dispatchId} closed (${event.resolutionType}) at ${event.siteId}',
      );
    }
    if (event is ReportGenerated) {
      return _EventInfo(
        label: 'REPORT GENERATED',
        color: const Color(0xFFAD8DFF),
        summary:
            '${event.clientId}/${event.siteId} ${event.month} hash ${event.contentHash.substring(0, 12)}... range ${event.eventRangeStart}-${event.eventRangeEnd}',
      );
    }
    if (event is IntelligenceReceived) {
      return _EventInfo(
        label: 'INTEL RECEIVED',
        color: const Color(0xFFFFA34D),
        summary:
            '${event.provider}/${event.externalId} risk ${event.riskScore} at ${event.clientId}/${event.siteId}',
      );
    }

    return _EventInfo(
      label: 'EVENT',
      color: const Color(0xFF93A8C9),
      summary: event.eventId,
    );
  }

  Widget _pill(String text, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A33),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF263B64)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: color ?? const Color(0xFF9DB1CF),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _summaryStrip({
    required int totalCount,
    required int filteredCount,
    required int? latestSequence,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000 ? 3 : 1;
        const spacing = 12.0;
        final cardWidth =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: cardWidth,
              child: _summaryStat(
                label: "Visible Events",
                value: filteredCount.toString(),
                accent: const Color(0xFF7FD0FF),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _summaryStat(
                label: "Total Events",
                value: totalCount.toString(),
                accent: const Color(0xFF9DB4FF),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _summaryStat(
                label: "Latest Sequence",
                value: latestSequence?.toString() ?? "N/A",
                accent: const Color(0xFF8CF1C3),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _summaryStat({
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0C182B), Color(0xFF091528)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1B395E)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 3,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF7D93B1),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.rajdhani(
              color: accent,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  int _activeFilterCount() {
    var count = 0;
    if (_typeFilter != _allValue) count += 1;
    if (_siteFilter != _allValue) count += 1;
    if (_guardFilter != _allValue) count += 1;
    if (_timeWindow != _TimeWindow.last24h) count += 1;
    return count;
  }

  Widget _selectedDetailPane(_ForensicRow row) {
    return _detailDrawer(row);
  }

  Widget _emptyDetailPane() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: onyxForensicSurfaceCardDecoration(),
      child: Center(
        child: Text(
          "Select an event to inspect detailed metadata.",
          style: GoogleFonts.inter(
            color: const Color(0xFF8FA4C5),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _detailHero(_ForensicRow row) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E1C31), Color(0xFF0B172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF224267)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 3,
            decoration: BoxDecoration(
              color: row.info.color.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: row.info.color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  row.info.label,
                  style: GoogleFonts.rajdhani(
                    color: row.info.color,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill("SEQ ${row.event.sequence}"),
              _pill("v${row.event.version}"),
              if (row.siteId != null) _pill(row.siteId!),
              if (row.guardId != null) _pill(row.guardId!),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            row.info.summary,
            style: GoogleFonts.inter(
              color: const Color(0xFFDCE9FF),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ForensicRow {
  final DispatchEvent event;
  final _EventInfo info;
  final String? siteId;
  final String? guardId;

  const _ForensicRow({
    required this.event,
    required this.info,
    required this.siteId,
    required this.guardId,
  });
}

class _EventInfo {
  final String label;
  final Color color;
  final String summary;

  const _EventInfo({
    required this.label,
    required this.color,
    required this.summary,
  });
}

enum _TimeWindow {
  last1h('Last 1h', Duration(hours: 1)),
  last6h('Last 6h', Duration(hours: 6)),
  last24h('Last 24h', Duration(hours: 24)),
  last7d('Last 7d', Duration(days: 7)),
  all('All time', null);

  final String label;
  final Duration? range;

  const _TimeWindow(this.label, this.range);

  DateTime? threshold(DateTime nowUtc) {
    if (range == null) return null;
    return nowUtc.subtract(range!);
  }
}
